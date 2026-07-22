+++
title = "Linux LD_PRELOAD 技术介绍"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "利用环境变量优先加载动态库，实现函数劫持与零入侵增强"
description = "介绍 Linux LD_PRELOAD 环境变量的工作原理、动态库加载顺序、典型应用场景及安全注意事项。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "Linux", "LD_PRELOAD", "动态链接", "动态库劫持"]
keywords = ["LD_PRELOAD", "Linux 动态链接", "动态库劫持", "ld.so.preload", "函数 hook"]
toc = true
draft = false
+++

## LD_PRELOAD 介绍

LD_PRELOAD 是 Linux/Unix 系统的一个环境变量，它能够影响程序运行时的链接行为，允许在程序启动前指定优先加载的动态链接库。借助这个环境变量，可以在主程序与其依赖的动态链接库之间插入额外的动态库，甚至覆盖系统标准函数库中的实现。

具体来说，Linux 操作系统在加载动态链接库时，动态链接器（`ld-linux.so`）会先读取 `LD_PRELOAD` 环境变量和默认配置文件 `/etc/ld.so.preload`，并将其中列出的动态库文件进行预加载。即使目标程序本身并不依赖这些动态库，它们也会被强制加载，因为预加载的优先级高于通过 `LD_LIBRARY_PATH` 指定路径所查找到的库，因此能够先于用户程序调用的动态库载入到进程地址空间。

简单来说，LD_PRELOAD 拥有最高的加载优先级，我们可以利用它来完成一些有趣（也略带"黑科技"）的操作。

一般情况下，`ld-linux.so` 加载动态链接库的顺序大致如下（`LD_PRELOAD` 是预加载机制，严格意义上并不属于"查找顺序"，但它的效果优先于查找过程）：

```text
LD_PRELOAD > DT_RPATH > LD_LIBRARY_PATH > DT_RUNPATH > /etc/ld.so.cache > /lib > /usr/lib
```

> 说明：从动态链接器的视角看，`LD_PRELOAD` 与 `/etc/ld.so.preload` 属于"预加载"阶段，会先于正常的符号查找流程把指定库载入；后面的 `DT_RPATH`、`LD_LIBRARY_PATH`、`DT_RUNPATH`、`/etc/ld.so.cache`、`/lib` 与 `/usr/lib` 才是查找依赖库时的实际搜索顺序。

使用 LD_PRELOAD 可以实现一些特殊功能，例如：

- **动态库劫持**：用 LD_PRELOAD 拦截并替换程序中对某些函数的调用，将其改写为自定义实现，从而实现额外功能。
- **程序调试**：用 LD_PRELOAD 替换程序中的函数，注入调试信息。例如，在程序调用 `printf` 时改写为自定义版本，输出额外的上下文信息。
- **库版本控制**：用 LD_PRELOAD 强制程序使用指定版本的共享库，以避免在不同环境之间出现兼容性问题。

需要注意的是，使用 LD_PRELOAD 时要兼顾安全性与兼容性。为避免程序崩溃或产生意外行为，替换函数必须与被替换函数具有相同的函数原型和语义行为。同时，还要关注共享库与主程序之间的交互，避免因符号冲突或调用约定不一致引发问题。此外，出于安全考虑，对于设置了 SUID/SGID 位的可执行文件，动态链接器在安全执行模式下会忽略 `LD_PRELOAD` 中的斜线路径，仅允许加载位于标准搜索目录且同样设置了 SUID 位的库，以防止权限提升攻击。

## 其它类似技术

- [PLTHook](https://github.com/kubo/plthook)：该库提供了类似的函数替换能力，但其原理是直接修改 ELF 文件中的 Procedure Linkage Table（PLT，过程链接表）条目（在 Windows 平台上则修改 PE 文件的 IAT 条目），因此作用范围可以限定在某个具体的对象文件内。

## 应用场景

- **劫持 `whoami`**：可以用来演示用户态 rootkit 的基本思路，具体能用在哪些地方就不多说了。
- **劫持 `strcmp`**：这是经典的安全研究案例，通过拦截字符串比较函数来隐藏指定文件或进程名，同样不多展开。
- **劫持内存分配函数**：例如通过 LD_PRELOAD 让进程使用 tcmalloc 替代 glibc 默认的 `malloc/free`，从而获得更高的分配性能（需注意，tcmalloc 官方推荐通过编译期 `-ltcmalloc` 链接使用，LD_PRELOAD 主要用于对未重新编译的可执行程序进行堆分析或临时替换的场景）。
- **在 SO 中调用主进程的函数**：例如在代码覆盖率分析场景中，通过预加载的 SO 调用主进程里的 `__gcov_flush()`（GCC 8 起该函数已被废弃，推荐改用 `__gcov_dump()`）来强制刷新覆盖率数据，从而实现对被分析进程的零入侵。

## 参考

- [LD_PRELOAD 基础用法](https://ivanzz1001.github.io/records/post/linux/2018/04/08/linux-ld-preload)
- [LD_PRELOAD 的偷梁换柱之能](https://www.cnblogs.com/net66/p/5609026.html)
- [掌握 LD_PRELOAD 轻松进行程序修改和优化的绝佳方法](https://blog.csdn.net/Long_xu/article/details/128897509)
- [LD_PRELOAD 机制在安全领域的攻击面探析](https://xz.aliyun.com/t/13671)
- [干货 | Linux 下权限维持实战](https://cloud.tencent.com/developer/article/1895859)
- [Linux 通过 LD_PRELOAD 实现进程隐藏](https://jiushill.github.io/posts/906527f2.html)
- [ld.so(8) — Linux manual page](https://man7.org/linux/man-pages/man8/ld.so.8.html)
- [gperftools (tcmalloc)](https://github.com/gperftools/gperftools)
