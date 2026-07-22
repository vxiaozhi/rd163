+++
title = "ptrace 学习笔记"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "理解 Linux 进程跟踪系统调用的原理与常见用法"
description = "介绍 Linux ptrace 系统调用的基本模型、常用 request、选项与典型应用场景(strace、gdb、断点注入),并附可运行的示例代码。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "linux", "ptrace", "调试", "系统调用"]
keywords = ["ptrace", "Linux", "系统调用", "strace", "gdb", "进程调试"]
toc = true
draft = false
+++

`ptrace(2)` 是 Linux(以及多数现代 Unix)提供的一个系统调用,允许一个进程(**tracer**,跟踪者)观察、控制另一个进程(**tracee**,被跟踪者)的执行,并读写其内存与寄存器。它是 `strace`、`gdb` 等工具的底层基石(perf trace 走的是 perf_event_open tracepoint 路径,刻意避开 ptrace 的高开销),也是反调试、沙箱、热补丁等技术的实现入口。本文整理其工作模型、常用 request 与典型示例。

## 工作模型

ptrace 的跟踪关系本质上是「父-子」关系的延伸。tracee 一旦被标记,在收到信号、执行系统调用、单步执行等关键时刻会被内核暂停,并通过 `waitpid(2)` 通知 tracer 接管。tracer 再用具体的 ptrace request 读取或修改其状态。

建立跟踪关系有两种典型路径:

- **fork + TRACEME**:子进程在 `exec` 前自己调用 `PTRACE_TRACEME`,主动请求被父进程跟踪(`strace command`、`gdb run` 走的就是这条路)。
- **ATTACH**:tracer 对一个已经在运行的进程调用 `PTRACE_ATTACH`,目标进程收到一个 `SIGSTOP` 停下,关系建立(`strace -p <pid>`、`gdb attach <pid>` 走这条路)。

无论哪种方式,tracee 进入「停止态」后,tracer 都通过 `waitpid(pid, &status, ...)` 等待并用 `WIFSTOPPED` 判断停止原因,再决定下一步动作。

## 函数原型

```c
#include <sys/ptrace.h>

long ptrace(enum __ptrace_request request, pid_t pid,
            void *addr, void *data);
```

四个参数的语义随 `request` 变化:`request` 指定操作类型,`pid` 指定被跟踪进程,`addr` 与 `data` 在不同场景下表示地址、偏移或缓冲区指针。返回值在读取操作(如 `PTRACE_PEEKTEXT`)中承载读到的字,因此调用前应清零 `errno`,调用后再判断是否真的出错。

## 常用 request

按用途大致分为以下几类。

### 跟踪关系

| request | 用途 |
|---|---|
| `PTRACE_TRACEME` | 子进程声明「我要被父进程跟踪」,仅在 tracee 端调用。 |
| `PTRACE_ATTACH` | 向指定 `pid` 发送 `SIGSTOP` 并建立跟踪关系。 |
| `PTRACE_SEIZE` | Linux 3.4 起引入,类似 `ATTACH` 但不强制停止 tracee,配合 `PTRACE_INTERRUPT` 使用。 |
| `PTRACE_DETACH` | 重启 tracee 并解除跟踪关系。 |
| `PTRACE_KILL` | (已弃用)建议直接用 `kill(2)`/`tgkill(2)`。 |

### 执行控制

| request | 用途 |
|---|---|
| `PTRACE_CONT` | 让停止的 tracee 继续执行;`data` 非零时把该信号注入给它。 |
| `PTRACE_SYSCALL` | 让 tracee 继续执行,直到下一次系统调用进入或返回时停下。 |
| `PTRACE_SINGLESTEP` | 执行一条指令后再次停下(在 x86 上由 EFLAGS 的 TF 位实现)。 |

### 内存与寄存器

| request | 用途 |
|---|---|
| `PTRACE_PEEKTEXT` / `PTRACE_PEEKDATA` | 从 tracee 内存读取一个字;Linux 中二者等价(同一地址空间)。 |
| `PTRACE_POKETEXT` / `PTRACE_POKEDATA` | 向 tracee 内存写入一个字(断点注入的基础)。 |
| `PTRACE_PEEKUSER` / `PTRACE_POKEUSER` | 读写 tracee 的 USER 区(通用寄存器、调试寄存器等)。 |
| `PTRACE_GETREGS` / `PTRACE_SETREGS` | 一次性读写整套通用寄存器(通过 `struct user_regs_struct`)。 |
| `PTRACE_GETREGSET` / `PTRACE_SETREGSET` | 2.6.34 引入,基于 `struct iovec` 按架构描述符读写寄存器,支持多 ABI。 |

### 信号与事件

| request | 用途 |
|---|---|
| `PTRACE_GETSIGINFO` / `PTRACE_SETSIGINFO` | 读取或修改导致 tracee 停止的信号信息。 |
| `PTRACE_SETOPTIONS` | 设置一组 `PTRACE_O_*` 选项位掩码。 |
| `PTRACE_GETEVENTMSG` | 配合事件选项,取出新 fork 出来的子进程 PID、退出码等。 |

## 重要选项:PTRACE_O_*

通过 `PTRACE_SETOPTIONS` 设置,用来改变默认行为。最常用的几个:

- `PTRACE_O_TRACESYSGOOD`:系统调用停止时,`WIFSTOPPED` 返回的信号号为 `SIGTRAP | 0x80`(128),便于和断点产生的普通 `SIGTRAP` 区分。**生产代码几乎都要打开它**。
- `PTRACE_O_TRACEFORK` / `TRACEVFORK` / `TRACECLONE`:tracee 调用 `fork`/`vfork`/`clone` 时,自动把新产生的子进程也纳入跟踪。这是 `strace -f` 跟踪多线程/多进程程序的基础。
- `PTRACE_O_TRACEEXEC`:tracee 调用 `execve` 时停止,避免旧实现里那种额外的 `SIGTRAP`。
- `PTRACE_O_TRACEEXIT`:tracee 退出前停下,寄存器仍可读。
- `PTRACE_O_EXITKILL`:tracer 自身被杀掉时,内核代发 `SIGKILL` 给 tracee,常用于构建沙箱/jailer,防止被跟踪进程逃脱。

## 一个最小示例:跟踪系统调用

下面的程序 fork 一个子进程执行 `ls`,父进程用 `PTRACE_TRACEME` + `PTRACE_GETREGS` 读取每次系统调用入口的系统调用号。注意这是 **x86-64** 示例,寄存器通过 `struct user_regs_struct` 中的 `orig_rax` 字段获取。

```c
#include <stdio.h>
#include <unistd.h>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <sys/user.h>
#include <sys/reg.h>

int main(void) {
    pid_t child = fork();
    if (child == 0) {
        /* 子进程:申请被跟踪,然后 exec */
        ptrace(PTRACE_TRACEME, 0, NULL, NULL);
        execlp("ls", "ls", NULL);
        _exit(1);
    }

    /* 父进程:第一次 stop 由 execve 触发 */
    waitpid(child, NULL, 0);
    ptrace(PTRACE_SETOPTIONS, child, NULL, PTRACE_O_TRACESYSGOOD);

    int in_syscall = 0;
    while (1) {
        /* 每次进入/退出系统调用都停下 */
        ptrace(PTRACE_SYSCALL, child, NULL, NULL);
        int status;
        if (waitpid(child, &status, 0) < 0 || WIFEXITED(status))
            break;

        if (WIFSTOPPED(status) && WSTOPSIG(status) == (SIGTRAP | 0x80)) {
            struct user_regs_struct regs;
            ptrace(PTRACE_GETREGS, child, NULL, &regs);
            if (!in_syscall) {
                printf("syscall enter: nr = %lld\n", regs.orig_rax);
            } else {
                printf("syscall exit:  ret = %lld\n", regs.rax);
            }
            in_syscall = !in_syscall;
        }
    }
    return 0;
}
```

把它编译运行就能看到 `ls` 调用的每一次系统调用编号,例如 `execve(59)`、`brk(12)`、`mmap(9)`、`write(1)`……这其实就是 `strace` 工作原理的最小化版本。

> 32 位与 64 位差异:在 i386 上系统调用号放在 `%eax`、参数依次在 `%ebx/%ecx/%edx/%esi/%edi/%ebp`,USER 区偏移要按 4 字节计算(`4 * ORIG_EAX`);x86-64 上系统调用号在 `%orig_rax`、参数在 `%rdi/%rsi/%rdx/%r10/%r8/%r9`,偏移按 8 字节计算。从老的 32 位示例迁移到 64 位时,这两处必须一起改。

## 断点原理(gdb 是怎么停下来的)

软件断点的本质非常简单:

1. tracer 用 `PTRACE_PEEKTEXT` 读出目标地址的一条指令,记下来。
2. 把该指令的最低字节替换为 `0xCC`(x86 上的 `INT3`),用 `PTRACE_POKETEXT` 写回。
3. tracee 执行到这条指令时触发 `SIGTRAP`,被 ptrace 拦下并交给 tracer。
4. tracer 把原始指令写回,把 PC 倒回一个字节,然后可以继续 `PTRACE_SINGLESTEP` 一次再下回断点,或直接 `PTRACE_CONT`。

寄存器读写、`PTRACE_SINGLESTEP`、`PTRACE_POKETEXT` 这三件套,构成了所有「源码级调试器」的底层能力。

## 跟踪多线程程序

多线程程序的跟踪要点是「主线程 `attach` 之后,要不要跟踪它后续 `clone` 出来的兄弟线程」。如果设置 `PTRACE_O_TRACECLONE`,内核会在新线程被 `clone` 出来的瞬间发送 `PTRACE_EVENT_CLONE` 事件,tracer 通过 `PTRACE_GETEVENTMSG` 拿到新线程的 TID,然后在 `waitpid(-1, ...)` 中循环等待所有线程的事件。

如果不设置这个选项,有些情况下新线程会逃出跟踪范围,产生难以解释的信号丢失——这是写自己的 tracer 时最常踩的坑之一。

## 安全限制:Yama ptrace_scope

很多发行版默认启用 Yama LSM,通过 `/proc/sys/kernel/yama/ptrace_scope` 限制谁能 `PTRACE_ATTACH`:

- `0`:经典行为,同 UID 即可 attach。
- `1`(常见默认):仅允许跟踪自己的子孙进程;目标可通过 `prctl(PR_SET_PTRACER, pid)` 显式授权。
- `2`:只有具备 `CAP_SYS_PTRACE` 能力的进程才能 attach。
- `3`:完全禁用 attach,且写入后不可逆。

如果出现「`strace -p` 提示 Operation not permitted」却没看到明显的权限问题,通常就是被 Yama 拦下了——可以用 `echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope` 临时放开。

## 小结

ptrace 接口设计于上世纪八十年代,API 风格陈旧、性能也并不理想(每次系统调用都要切回 tracer 再回到 tracee),但它仍然是用户态做「进程级观察与控制」最通用的入口。理解了 `TRACEME`/`ATTACH` 模型、几类核心 request、`PTRACE_O_*` 选项,以及断点注入的基本原理,再去看 `strace`、`gdb` 的源码,或者写自己的调试器、沙箱、热补丁工具,就有了清晰的路线图。

## 参考

- [ptrace(2) — Linux Programmer's Manual](https://man7.org/linux/man-pages/man2/ptrace.2.html)
- [Yama LSM — Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/admin-guide/LSM/yama.html)
- [strace 项目(GitHub)](https://github.com/strace/strace)
- [ptrace学习笔记I — omasko's blog](https://omasko.github.io/2018/04/19/ptrace%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0I/)
- [ptrace理解 — 博客园](https://www.cnblogs.com/mysky007/p/11047943.html)
- [ptrace 跟踪多线程程序 — codeleading](https://www.codeleading.com/article/1771725337/)
