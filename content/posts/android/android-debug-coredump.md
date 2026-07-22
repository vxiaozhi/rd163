+++
title = "Android 应用程序中的 Coredump 抓取与分析"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从 Tombstone 到 Core Dump:Native 崩溃现场的全链路定位"
description = "梳理 Android Native 崩溃的两种现场抓取方式(Tombstone 与 Core Dump),以及使用 ndk-stack、addr2line、lldb 进行符号化与根因分析的实战流程。"
author = "小智晖"
authors = ["小智晖"]
categories = ["android"]
tags = ["android", "coredump", "tombstone", "ndk", "native", "调试"]
keywords = ["android", "coredump", "tombstone", "ndk-stack", "addr2line", "native crash"]
toc = true
draft = false
+++

在 Android 平台上，一旦业务进入音视频、图形渲染、JNI 桥接或自研 SDK 等领域，Native 层（C/C++）崩溃就成为无法回避的问题。与 Java 层崩溃不同，Native 崩溃抛出的是 `SIGSEGV`、`SIGABRT` 等信号（signals）,栈帧地址是一串十六进制数，直接看日志几乎读不出有用信息。要在这种环境下定位问题，必须先拿到"崩溃现场"——也就是本文要讨论的 **Coredump 与 Tombstone**。

本文先厘清两种现场抓取机制的区别与开启方法，再给出从一条裸地址定位到源码行的完整分析路径。

## 概念辨析:Tombstone vs Core Dump

很多人把 Tombstone 和 Core Dump 混为一谈，实际上它们是两套独立的机制:

- **Tombstone(墓碑)**:Android 系统自带的崩溃报告，由 `debuggerd` 守护进程及其后继 `crash_dump` 在进程收到致命信号时通过 `ptrace` 抓取。它是一份**纯文本**报告，包含构建指纹（build fingerprint）、ABI、崩溃线程的 PID/TID、信号类型与故障地址、寄存器、调用栈以及内存映射片段。文件统一存放在 `/data/tombstones/` 目录下，文件名形如 `tombstone_06`。AOSP 在 `system/core/debuggerd/` 下提供了一个名为 `crasher` 的测试程序，可用于复现各类崩溃。
- **Core Dump(核心转储)**:Linux 原生机制，由内核在进程崩溃时把进程的内存映像、寄存器状态等按 ELF 格式写入磁盘，通常用 `gdb` / `lldb` 加载分析。Core Dump 体积大，但保留的信息远比 Tombstone 完整，可以查看任意内存、变量、所有线程的完整栈。

关键事实:`RLIMIT_CORE` 控制的是**传统 Core Dump 文件**的大小上限,**不影响** Tombstone 的生成。Bionic libc 在进程启动时会把 `RLIMIT_CORE` 设为 0，这就是默认拿不到 Core Dump 的根本原因。Tombstone 走的是 `debuggerd` / `crash_dump` 的信号处理路径，与 `RLIMIT_CORE` 互相独立，二者可以共存。

| 维度 | Tombstone | Core Dump |
|------|-----------|-----------|
| 生成方 | `crash_dump`(用户态) | Linux 内核 |
| 格式 | 文本 | ELF |
| 存放位置 | `/data/tombstones/` | 由 `core_pattern` 决定 |
| 体积 | KB 级 | MB ~ GB 级 |
| 分析工具 | `ndk-stack` / `addr2line` | `gdb` / `lldb` |
| 默认开启 | 是（系统级） | 否(`RLIMIT_CORE = 0`) |

## Coredump 开启

### 1. 默认机制:Tombstone 自动生成

只要设备是 `userdebug` 或 `eng` 编译，或者应用是 debuggable 的，Tombstone 就会在 Native 崩溃时自动写入。普通用户机(`user` 编译)默认不写完整 Tombstone，只能看到 logcat 中的简短栈。

```bash
# 列出所有 tombstone
adb shell ls -l /data/tombstones/

# 查看指定 tombstone
adb shell cat /data/tombstones/tombstone_06
```

Tombstone 报告以一行星号分隔符作为标识:

```
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
```

这一行是 `ndk-stack` 识别崩溃段的起始标志，手动复制日志时**不可省略**,否则工具无法解析。

### 2. 手动开启传统 Core Dump

当 Tombstone 信息不够（例如需要查看崩溃时的全局变量、堆上对象、其它非崩溃线程的栈）,就需要打开 Core Dump。整体流程分为三步：放宽 `RLIMIT_CORE`、配置 `core_pattern`、保证目标目录可写。

```bash
# 1. 放宽 core 大小限制(需要在目标进程内生效,
#    或在 init.rc / 服务定义中用 rlimit core -1 -1)
adb root
adb shell "ulimit -c unlimited"

# 2. 设置 core_pattern,把内核生成的 core 写到指定目录
adb shell "mkdir -p /data/coredump && chmod 777 /data/coredump"
adb shell "echo '/data/coredump/core.%p' > /proc/sys/kernel/core_pattern"

# 3. 关闭 SELinux(仅调试机),避免写入被策略拦截
adb shell setenforce 0
```

文件名中的 `%p` 会被替换为崩溃进程的 PID，可选占位符还包括 `%e`(进程名)、`%t`(时间戳)、`%s`(信号)等，完整列表见 Linux 内核文档 `core(5)`。

需要注意:

- **`ulimit -c unlimited` 只对当前 shell 及其子进程生效**,真正业务进程通常由 `zygote` fork 而来，必须在进程内部调用 `setrlimit(RLIMIT_CORE, {RLIM_INFINITY, RLIM_INFINITY})`,或者在 `init.rc` 的服务定义里写 `rlimit core -1 -1`(`-1` 即 `RLIM_INFINITY`)。
- 若 `core_pattern` 以 `|` 开头(如 `|/system/bin/crash_dump %p`),内核会把 core 流式喂给这个程序而不是落盘——这正是 Android 默认配置走 `crash_dump` 生成 Tombstone 的原理。要拿原始 core 文件，必须把它改成纯路径。
- 触发崩溃后，用 `adb pull /data/coredump/core.<pid> ./` 把文件拉到开发机。

## Coredump 调试

无论手上是 Tombstone 还是 Core Dump，符号化（symbolization）——把裸地址翻译回源码文件和行号——都是分析的核心步骤。前提是要有一份**未 strip 的 `.so`**,即带调试符号的版本。

### 1. ndk-stack:最快的一键符号化

`ndk-stack` 是 NDK 自带的脚本，能把 logcat 或 Tombstone 文本里的调用栈自动替换成源码位置。它需要一个"符号目录",目录里要包含未 strip 的 `.so`:

- **ndk-build 项目**:`$PROJECT_PATH/obj/local/<abi>`
- **AGP(Android Gradle Plugin)项目**:`<module>/build/intermediates/cxx/<build-type>/<hash>/obj/<abi>`

```bash
# 方式 A:直接接管 logcat
adb logcat | $ANDROID_NDK/ndk-stack -sym $PROJECT_PATH/obj/local/arm64-v8a

# 方式 B:从已保存的日志文件解析
adb logcat > /tmp/crash.log
$ANDROID_NDK/ndk-stack -sym $PROJECT_PATH/obj/local/arm64-v8a -dump /tmp/crash.log
```

效果示例:

```
#00  pc 0000841e  /data/local/ndk-tests/crasher
              → Routine zoo in /tmp/foo/crasher/jni/zoo.c:13
```

### 2. addr2line:单条地址精确定位

如果只想翻译某一帧地址，NDK 自带的 `llvm-addr2line` 更直接:

```bash
$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-addr2line \
    -e obj/local/arm64-v8a/libtest.so -f -C -i 0x1234
```

参数含义:`-f` 显示函数名,`-C` 把 C++ 名修饰（demangle）还原成可读形式,`-i` 处理内联函数。Tombstone 里的 `pc` 值是相对 `.so` 的偏移，直接传给 `addr2line` 即可;若是 Core Dump 中读到的绝对地址，要先减去 `.so` 的加载基址(基址来自 `/proc/<pid>/maps` 或 Tombstone 中的 memory map 段)。

### 3. lldb / gdb:加载 Core Dump 深度调试

Core Dump 的最大价值在于可以用调试器像调试 live 进程一样查看崩溃时刻的完整状态。NDK 推荐 **LLDB**(Android Studio 默认集成):

```bash
# 用 lldb 加载 core 文件
$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/lldb
(lldb) target create --core ./core.12345
(lldb) target modules add obj/local/arm64-v8a/libtest.so
(lldb) bt          # 查看调用栈
(lldb) frame select 0
(lldb) v list      # 查看局部变量
(lldb) image lookup -a 0x00007aaaaaaaa123   # 查地址归属
```

`gdb` 的等价用法是 `gdb -core ./core.12345 libtest.so`,然后 `bt`、`info locals`、`info registers`。

### 4. Tombstone 关键字段解读

一段典型的 ARM64 Tombstone 头部如下:

```
Build fingerprint: 'google/raven/.../release-keys'
ABI: 'arm64'
Timestamp: 2025-01-12 10:23:45.123456789
pid: 12345, tid: 12346, name: RenderThread  >>> com.example.app <<<
signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x0000000000000000
backtrace:
  #00 pc 0x0000000000011234  /apex/.../libtest.so (do_render+84)
  #01 pc 0x0000000000011122  /apex/.../libtest.so (main+34)
```

关键字段含义:

- **pid / tid**:`pid` 是进程 ID,`tid` 是真正崩溃的线程 ID。多线程程序务必用 `tid` 对应的栈，别用主线程栈。
- **signal**:`SIGSEGV`(段错误)、`SIGABRT`(`abort()`,常见于 assert 失败或 C++ 异常未捕获)、`SIGBUS`(内存对齐)、`SIGFPE`(浮点错误，如除零)。
- **code**:进一步细分。例如 `SEGV_MAPERR` 指访问了未映射的地址（典型空指针）,`SEGV_ACCERR` 指权限不足（如写只读页）。
- **fault addr**:触发崩溃的内存地址。`0x0` 基本可判定为空指针解引用。
- **pc 与 `(symbol+offset)`**:PC 相对 `.so` 基址的偏移;括号内是 `crash_dump` 在设备上尽力解析出的符号，如果 `.so` 已 strip 则此处为空，需要回开发机用 `addr2line` 还原。

### 5. 生产环境的崩溃收集:Breakpad / Crashpad

Tombstone 与 Core Dump 都依赖 root 或 debuggable 设备，无法覆盖线上用户。生产环境通常集成第三方或开源方案:

- **Google Breakpad**:跨平台崩溃上报，客户端把崩溃现场写成 Microsoft Minidump 格式（几百 KB）,通过 `minidump_stackwalk` + 预先生成的 `.sym` 符号文件(`dump_syms` 生成)还原栈。Chromium、微信、Firefox 均在使用。
- **Crashpad**:Breakpad 的继任者，默认集成在 Chromium 中，支持更稳定的进程间崩溃捕获。
- **各大厂自研方案**:例如滴滴的 [rdebug](https://github.com/didi/rdebug) 在协程与 iOS 场景做了扩展(注:该项目现已 archived)。

集成 Breakpad 的核心是初始化一个 `ExceptionHandler`:

```cpp
#include "client/linux/handler/exception_handler.h"

static bool dump_callback(const google_breakpad::MinidumpDescriptor& d,
                          void* ctx, bool ok) { return ok; }

void init_breakpad() {
    google_breakpad::MinidumpDescriptor desc("/data/data/com.example/files");
    static google_breakpad::ExceptionHandler eh(
        desc, nullptr, dump_callback, nullptr, true, -1);
}
```

发布到 Google Play 时，需一并上传 native debug symbols 包(`.symbols.zip`),后台才能自动符号化线上 ANR 与 Native 崩溃。

## 实战检查清单

把日常排障流程收敛成一张清单，大多数 Native 崩溃都能按部就班定位:

1. **拿到现场**:优先看 `/data/tombstones/` 下的最新文件，信息不足再开 Core Dump。
2. **确认 ABI 与构建**:Tombstone 头部的 `ABI:` 字段必须和符号 `.so` 的架构一致，否则地址偏移对不上。
3. **准备未 strip 的 `.so`**:`ndk-stack` 用 `obj/local/<abi>`;AGP 用 `intermediates/cxx/.../obj/<abi>`。Release 包务必在打包时保留 debug symbols。
4. **符号化**:整段栈用 `ndk-stack`,单条地址用 `llvm-addr2line -f -C -i`。
5. **结合源码定位**:进入对应文件与行号，检查空指针、越界、UAF(use-after-free)、线程数据竞争。
6. **必要时上调试器**:Core Dump 用 `lldb --core` 查看完整变量与堆;或 `kill -3 <pid>` 触发 ANR `traces.txt` 看 ART 与 Native 混合栈。
7. **回填线上**:把符号化后的崩溃栈接入 Breakpad / Crashpad，持续监控复发率。

## 常见坑

- **符号被 strip**:这是 90% 拿不到行号的原因。Release 构建必须保留 unstripped `.so`,或额外产出 debug symbols 包。
- **PIE/PIC 偏移**:带位置无关代码的 `.so`,运行时基址随 ASLR 变化，务必用 `pc` 相对偏移而不是绝对地址喂给 `addr2line`。
- **混淆 / 优化**:`-O2` 及以上会内联、重排指令,`addr2line` 给出的行号可能是调用点附近而非精确行，这时用 `-i` 展开内联链。
- **多线程**:崩溃栈只是 `tid` 那一条，其它线程栈在 Tombstone 末尾或 Core Dump 中完整保留，死锁类问题往往要看非崩溃线程。
- **`user` 机无权限**:线上设备无 root，要么靠 Breakpad 自取 Minidump，要么等用户上传 Google Play 自动收集的报告。

## 参考

- [Android NDK 指南 — ndk-stack](https://developer.android.com/ndk/guides/ndk-stack)
- [AOSP — Diagnose native crashes](https://source.android.com/docs/core/tests/debug/native-crash)
- [Linux man pages — core(5)](https://man7.org/linux/man-pages/man5/core.5.html)
- [Google Breakpad — README](https://chromium.googlesource.com/breakpad/breakpad/+/master/README.md)
- [didi/rdebug](https://github.com/didi/rdebug)
- [Android 应用程序中的 Coredump 抓取与分析](https://cloud.baidu.com/article/3305315)
- [Android P 开启抓取 Coredump 功能](https://www.jianshu.com/p/7751fe02063d)