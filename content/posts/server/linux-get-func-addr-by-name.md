+++
title = "Linux 中通过函数名字符串在 C/C++ 里获取并调用函数地址"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "区分符号位于动态库还是主可执行模块的两种解法"
description = "介绍在 Linux 下使用 dlopen/dlsym 通过函数名字符串动态获取函数地址的两种场景：符号位于 .so 动态库或主可执行模块,以及 -rdynamic / --export-dynamic 链接选项的作用。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "c/c++", "linux", "动态链接", "dlsym", "覆盖测试"]
keywords = ["dlsym", "dlopen", "-rdynamic", "导出动态符号", "函数名调用", "Linux"]
toc = true
draft = false
+++

在写服务端代码时，有时会遇到这样一个需求：手里只有一段字符串形式的函数名（比如从配置文件、RPC 路由表或测试 harness 里读出来）,却要据此拿到函数的内存地址并调用它。这在 C/C++ 这种编译期绑定（static binding）的语言里并不天然——编译器在编译期就把函数调用绑成了固定地址，符号信息默认只在链接阶段使用，运行期通常不可见。

好在 Linux/glibc 提供了 `<dlfcn.h>`(dynamic linking，动态链接)接口，可以让我们按名字查表拿到符号地址。整体上要分两种情况处理：函数实现在 `.so` 动态库里，或函数实现在主模块（可执行文件本身）里。这两种情况的查询 API 相同，但「能否查得到」背后的机制完全不同。

## 一、相关 API:dlopen / dlsym / dlerror / dlclose

无论是哪种情况，核心 API 都来自 `<dlfcn.h>`,链接时需要加 `-ldl`(在较新的 glibc 上 dl 系列已合并进 libc，但保留 `-ldl` 仍是可移植的写法)。

`dlopen` 用于加载一个共享对象（shared object）,原型是:

```c
#include <dlfcn.h>
void *dlopen(const char *path, int flags);
```

成功时返回一个不透明的 handle，失败返回 `NULL`,错误原因通过 `dlerror()` 获取。`flags` 至少要包含 `RTLD_LAZY` 或 `RTLD_NOW` 中的一个:

- `RTLD_LAZY`:延迟绑定（lazy binding）,只在被引用到的符号真正执行时才解析。
- `RTLD_NOW`:在 `dlopen` 返回前就把所有未定义符号解析完，失败则直接报错。
- `RTLD_GLOBAL`:本对象中的符号对之后加载的对象可见，可被全局解析。
- `RTLD_LOCAL`:默认值，与 `RTLD_GLOBAL` 相反。

一个特殊用法：传入 `path = NULL`,`dlopen` 返回的 handle 指向主程序（main program）本身——这是查询主模块符号时的关键入口。

`dlsym` 用于按名字查询符号地址:

```c
void *dlsym(void *restrict handle, const char *restrict symbol);
```

返回 `symbol` 对应的地址，失败返回 `NULL`。注意一个细节：因为符号的合法值本身也可能是 `NULL`,仅靠返回值判断是否出错并不可靠。标准用法是「先 `dlerror()` 清空错误，再 `dlsym`,再 `dlerror()` 看是否有错误」:

```c
dlerror();                       // 清空历史错误
void *p = dlsym(handle, "foo");
char *err = dlerror();
if (err != NULL) {
    /* 真的出错了 */
}
```

`dlsym` 还支持两个伪 handle(需要 `#define _GNU_SOURCE`):`RTLD_DEFAULT` 在所有全局可见的对象里查第一个匹配,`RTLD_NEXT` 在搜索顺序里查「下一个」同名符号——常用于 `LD_PRELOAD` 包装真实函数。`dlclose` 用于减少引用计数，归零时卸载对象。

## 二、情况 1:函数实现在 .so 中

这是最常见、最直接的场景。一个普通的动态库，只要符号没有被 `static` 修饰（即不是 internal linkage）,默认就是导出符号，会出现在 `.dynsym`(dynamic symbol table)里，对 `dlsym` 可见。

下面是一个典型示例：通过 `dlopen` 打开 `demo.so`,按名字拿到 `__gcov_dump` 函数地址并调用。`__gcov_dump` 是 GCC 覆盖率运行时库 libgcov 提供的接口，用于在运行期把覆盖率计数器主动写到 `.gcda` 文件里——常用于长跑服务、信号处理或 fuzzing harness 里及时落盘覆盖率数据。

```c
#include <stdio.h>
#include <dlfcn.h>

int main(void) {
    // 1. 打开动态链接库
    void *handle = dlopen("./demo.so", RTLD_LAZY);
    if (!handle) {
        fprintf(stderr, "无法打开动态链接库: %s\n", dlerror());
        return 1;
    }

    // 2. 获取函数地址
    void (*my_function)(void) = (void (*)(void))dlsym(handle, "__gcov_dump");
    if (!my_function) {
        fprintf(stderr, "无法获取函数地址: %s\n", dlerror());
        dlclose(handle);
        return 1;
    }
    fprintf(stderr, "gcov_dump addr: %p\n", (void *)my_function);

    // 3. 通过地址调用
    my_function();

    // 4. 关闭动态链接库
    dlclose(handle);
    return 0;
}
```

编译并运行:

```bash
gcc -o demo demo.c -ldl
./demo
```

如果 `demo.so` 编译时没有特意隐藏符号（默认 visibility 为 default）,就能顺利取到地址。可以用下面的命令核对符号是否真的导出:

```bash
nm -D demo.so | grep __gcov_dump
# 或
readelf --dyn-syms demo.so | grep __gcov_dump
```

C++ 有一个额外的坑:name mangling(名字修饰)会把 `void foo(int)` 变成类似 `_Z3fooi` 的符号,`dlsym` 用源码里的名字是查不到的。要么把要查询的函数用 `extern "C"` 包起来取消修饰，要么借助 `abi::__cxa_demangle`(或命令行 `c++filt`)拼出修饰后的名字再去查。

## 三、情况 2:函数实现在主模块中

主模块(编译成 `.out` / 可执行二进制的那个文件)的符号规则与 `.so` 不一样。一个 `.so` 中的非 `static` 全局符号默认就会进入 `.dynsym` 成为导出符号;但主模块并非如此——**默认情况下主模块根本不把自己的符号导出到 `.dynsym`**。这也是为什么很多人第一次用 `dlsym` 去查自己 `main.c` 里写的函数时，明明函数没被 `static` 修饰，却总是查不到。

主模块符号的「按需导出」逻辑由链接器 `ld` 完成：只有当其它被加载的模块(比如 `A.so`)实际引用了一个同名符号时，链接器才把这个符号加进主模块的 `.dynsym`。换句话说，主模块默认只导出「被别的东西需要」的符号。

要让主模块里的所有全局非隐藏符号都对 `dlsym` 可见，需要在链接时加:

```bash
gcc -rdynamic -o demo demo.c -ldl
# 等价写法:
gcc -Wl,--export-dynamic -o demo demo.c -ldl
```

`-rdynamic` 是 GCC 驱动层的简写，它会被翻译成链接器的 `--export-dynamic`(在 `ld` 里也叫 `-E`)。这个选项的作用是：把可执行文件里所有非隐藏（non-hidden）的全局符号都放进 `.dynsym`,使它们对运行期的 `dlsym` 可见。

一个最小可复现的示例:

```c
// main.c —— 编译时务必加 -rdynamic
#include <stdio.h>
#include <dlfcn.h>

void my_func(void) {
    printf("hello from main module\n");
}

int main(void) {
    // 用 NULL 拿到主程序自身的 handle
    void *h = dlopen(NULL, RTLD_NOW);
    if (!h) {
        fprintf(stderr, "dlopen failed: %s\n", dlerror());
        return 1;
    }

    void (*f)(void) = (void (*)(void))dlsym(h, "my_func");
    if (f) {
        f();
    } else {
        fprintf(stderr, "dlsym failed: %s\n", dlerror());
    }

    dlclose(h);
    return 0;
}
```

```bash
# 不加 -rdynamic,dlsym 会查不到
gcc -o demo_bad main.c -ldl && ./demo_bad
# 输出: dlsym failed: undefined symbol: my_func ...

# 加上 -rdynamic 就能找到
gcc -rdynamic -o demo_good main.c -ldl && ./demo_good
# 输出: hello from main module
```

可以这样核对差异:

```bash
# 没加 -rdynamic:my_func 不在 .dynsym 里
readelf --dyn-syms demo_bad | grep my_func    # 无输出

# 加了 -rdynamic:my_func 出现在 .dynsym 里
readelf --dyn-syms demo_good | grep my_func
```

### 几个容易踩的细节

- **static 函数不会被导出**:`-rdynamic` 只对非 `static`(非 internal linkage)的全局符号起作用。
- **`-fvisibility=hidden` 会覆盖 `-rdynamic`**:如果编译单元默认隐藏了可见性，需要单独把某个函数标成 `__attribute__((visibility("default")))` 才能重新导出。
- **PIE 可执行文件**:现代 GCC 默认开 PIE(position-independent executable),`-rdynamic` 依然有效，导出规则不变。
- **代价**:`-rdynamic` 会把所有全局符号都塞进 `.dynsym`,二进制体积变大、加载略慢，但对运行时性能没有影响。如果想精挑细选导出哪些符号，可以用链接器 version script(`--version-script`)配合 `-fvisibility=hidden`。
- **macOS 等价**:在 macOS 上对应的是 `-Wl,-export_dynamic`(一个下划线),或直接用 `-rdynamic`。
- **何时不需要**:`-rdynamic` 仅在「插件/动态库需要通过 `dlsym` 反向查找主程序里的符号」时才需要;如果只是主程序单向调用 `.so`,完全不用加。

## 小结

通过函数名字符串在 C/C++ 里动态调用函数，核心就是 `dlopen` / `dlsym` 这一对接口。从实现位置看:

| 场景 | 符号位置 | 默认对 dlsym 可见 | 需要的操作 |
|---|---|---|---|
| 符号在 .so 中 | `.dynsym` | 是（非 static 默认导出） | 直接 `dlopen` + `dlsym` |
| 符号在主模块中 | `.symtab` / `.dynsym` | 否（默认不导出） | 链接时加 `-rdynamic` 或 `--export-dynamic` |

理解了 `.dynsym` 的按需生成机制，就能解释清楚「为什么 so 里的函数一查就有、主程序里的函数却查不到」这个常见困惑。无论是做插件系统、RPC 路由、覆盖率工具，还是简单的函数名反射，这套思路都通用。

## 参考

- [dlopen(3) — Linux manual page](https://man7.org/linux/man-pages/man3/dlopen.3.html)
- [dlsym(3) — Linux manual page](https://man7.org/linux/man-pages/man3/dlsym.3.html)
- [GCC Manual — Options for Linking(-rdynamic)](https://gcc.gnu.org/onlinedocs/gcc/Link-Options.html)
- [LD (GNU linker) — Options(--export-dynamic / -E)](https://sourceware.org/binutils/docs/ld/Options.html)
- [通过函数名称字符串发起调用/函数名反射](https://blog.csdn.net/zhouguoqionghai/article/details/121703985)
