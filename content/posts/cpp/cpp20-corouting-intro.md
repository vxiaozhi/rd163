+++
title = "c++20协程简介"
date = "2025-04-06"
lastmod = "2025-04-06"
subtitle = "C++20 协程的接口、无栈协程原理与开源生态"
description = "从 Awaitable 与 Promise 的接口入手，介绍 C++20 原生协程的最小实现，倒推无栈协程的运行原理（协程帧、暂停与重入），并梳理基于 C++20 协程的开源库与 Web 服务器示例。"
author = "小智晖"
authors = ["小智晖"]
categories = ["cpp"]
tags = ["cpp", "协程", "coroutine", "C++20", "无栈协程", "异步编程"]
keywords = ["C++20协程", "coroutine", "co_await", "promise_type", "无栈协程", "Awaitable"]
toc = true
draft = false
+++

## C++20 协程简介

参考：

- [协程及 C++ 20 原生协程研究报告](https://github.com/0voice/cpp_backend_awsome_blog/blob/main/%E3%80%90NO.241%E3%80%91%E5%8D%8F%E7%A8%8B%E5%8F%8Ac%2B%2B%2020%E5%8E%9F%E7%94%9F%E5%8D%8F%E7%A8%8B%E7%A0%94%E7%A9%B6%E6%8A%A5%E5%91%8A.md)
- [2021K+ 全球软件研发行业创新峰会：深入解析 C++20 协程（PDF）](https://0cch.com/uploads/2022/02/k+2021.pdf)

C++20 协程通过 Promise 和 Awaitable 接口的十余个函数，向程序员暴露出定制协程流程和行为的入口。实现一个最简单的协程，通常需要用到其中的 8 个（5 个 Promise 函数 + 3 个 Awaitable 函数）。下面先从 Awaitable 的 3 个函数说起。

如果希望写出形如 `co_await blabla;` 的调用形式，`blabla` 就必须实现 Awaitable。`co_await` 是 C++20 引入的新运算符。Awaitable 主要包含 3 个函数：

1. `await_ready`：返回该 Awaitable 实例是否已经就绪。协程开始时会调用此函数；若返回 `true`，表示期待的结果已经到手，协程无需挂起，因此大多数场景下它的实现都是 `return false`。
2. `await_suspend`：挂起 awaitable。该函数会传入一个 `coroutine_handle` 类型的参数，这是由编译器生成的句柄。在此函数中调用 `handle.resume()`，即可恢复协程。
3. `await_resume`：当协程被重新唤醒时会调用该函数，其返回值也就是 `co_await` 表达式的返回值。

函数的返回值需要满足 Promise 的规范。最简单的 Promise 如下：

```cpp
#include <coroutine>
#include <cstdlib>

struct Task
{
    struct promise_type {
        auto get_return_object() { return Task{}; }
        auto initial_suspend() { return std::suspend_never{}; }
        auto final_suspend() noexcept { return std::suspend_never{}; }
        void unhandled_exception() { std::terminate(); }
        void return_void() {}
    };
};
```

> 注：C++20 标准把 `suspend_never`、`suspend_always`、`coroutine_handle` 等组件放在 `<coroutine>` 头文件的 `std::` 命名空间下；早期 Coroutines TS 草案中位于 `<experimental/coroutine>` 的 `std::experimental::` 命名空间，迁移到正式标准时应一并替换。

## 无栈协程原理

参考某知乎答主的回答，可以从应用倒推原理：

1. 无栈协程既可以只开一个，也可以开几十万个，这说明它依赖动态内存分配，协程的局部变量是分配在堆空间的。
2. 无栈协程没有运行时栈，这意味着每个协程必须「知道自己是协程」。举例：当协程 a 引用一个局部变量 `local_v` 时，需要被编译为类似 `(*a_frame).local_v` 的形式，也就是从协程 a 占有的堆内存中取出 `local_v`；同一种协程的多个实例之间的堆内存互不相干。
3. 当协程 a 调用一个普通函数 b 时，函数 b 并不知道调用者 a 是不是协程，也只需遵循普通的函数调用约定，在栈上开辟栈帧。在概念上，除非函数 b 结束并返回到协程 a，否则协程 a 永远没有机会暂停。
4. 当普通函数 b 调用一个协程 c 时，函数 b 同样不需要知道 c 是不是协程。在 C++20 中，普通函数 b 只需调用 `c.resume()`，就好像这是一个普通函数。
5. 延续第 4 点，当 `c.resume()` 返回后，协程 c 可能已经结束，也可能只是被挂起了，这不重要。随后你也许希望调用 `d.resume()`、`e.resume()` 等等。实际上普通函数 b 在这里扮演了一个调度者的角色，决定着哪个协程应该运行，此时可将它视为「调度器」。这种「协程暂停 -> 回到调度器 -> 另一个协程运行 -> ……」的循环模式叫做「非对称协程」。另一种模式是「协程暂停 -> 另一个协程运行」，即 `c.resume()` 结束后并没有返回普通函数 b，而是直接切换到另一个协程，叫做「对称协程」。「对称协程」和「非对称协程」可以互相模拟，本质区别不大。

那么，如何用普通函数实现非对称协程？

1. 首先定义一个 `struct Frame`「协程帧」，负责存放协程的局部变量。这样每当新建一个协程时，只需整体分配一次堆空间。显然，由于不同协程内具有不同的局部变量，你需要对每一种协程都定义一个 Frame，于是代码里会出现 `A_Frame`、`B_Frame`、…… 你会觉得这种机械工作太过繁琐，为什么不让编译器来做呢？幸运的是，C++20 的编译器能够帮你准确无误地完成这些工作，真心建议放弃 C++11。
2. 堆空间有了，那如何实现「可暂停」？很简单：在每个暂停点直接 `return;` 即可。
3. 在暂停点 `return` 之后，又如何做到「可重入」？用 `switch case` 手动模拟即可。所以「协程帧」不仅要存放局部变量，还要存放 `switch case` 所依赖的状态值，用来表示「协程当前执行到哪一步」。
4. 协程最终结束后，如何返回值？同样写入协程帧即可。如果调用方需要用到返回值，到协程帧里读取就是了。由此看来，协程结束后不能立即回收协程帧的内存——毕竟调用方还要读取。
5. 如果协程内部要抛出异常怎么办？答案还是协程帧！我们强制让每个协程体都被一个 `try-catch` 包裹，当异常发生时将其写入协程帧，然后当作无事发生；只有当调用方查询协程帧时，才会发现并重新抛出这个异常。

至此，你拥有了一个可暂停、可重入、可并发几十万个的普通函数（以及它对应的协程帧结构体），你称之为「协程」。由于每次暂停都是直接 `return;` 回到上层调度器，所以它是「非对称的」。不过，协程帧的内存申请与释放时机都需要你非常小心地控制。

理解了以上原理，再去阅读 C++20 协程的相关文档，应该会容易许多。

## 基于 C++20 协程封装的库

C++20 的协程特性主要是为库作者设计的，因此接口看起来比较底层、复杂；但经过库作者的封装，使用起来会非常简单。以下是一些值得关注的开源库：

- [async_simple](https://github.com/alibaba/async_simple)：阿里巴巴开源的轻量级 C++ 异步框架，提供了基于 C++20 无栈协程（Lazy）、有栈协程（Uthread）以及 Future/Promise 等异步组件。
- [cppcoro - A coroutine library for C++](https://github.com/lewissbaker/cppcoro)：Lewis Baker 编写的经典协程库，注意它最初面向 Coroutines TS，仓库近两年更新较少，更适合作为学习参考。
- [Felspar Coro](https://github.com/Felspar/coro)：Coroutine library and toolkit for C++20。
- [librf - 协程库](https://github.com/tearshark/librf)：基于 C++ Coroutines 编写的无栈协程库。
- [concurrencpp, the C++ concurrency library](https://github.com/David-Haim/concurrencpp)：Modern concurrency for C++. Tasks, executors, timers and C++20 coroutines to rule them all.
- [Coro](https://github.com/adinosaur/Coro)：用 C 语言 `setjmp` 和 `longjmp` 实现的一个最基本的协程，适合用来理解协程的最小骨架。
- [UE5Coro](https://github.com/landelare/ue5coro)：A deeply-integrated C++20 coroutine plugin for Unreal Engine 5（同时兼容 UE4）。

基于 C++20 协程实现的 server 示例：

- [co-uring-WebServer](https://github.com/yunwei37/co-uring-WebServer)：用 C++20 编写的 Web 服务器，可处理静态资源，同时也包含一些学习 C++20 与 io_uring 的相关资料。

## 参考

- [C++20 协程支持（cppreference）](https://en.cppreference.com/w/cpp/coroutine)
- [C++ Coroutines: Understanding operator co_await — Lewis Baker](https://lewissbaker.github.io/2017/11/17/understanding-operator-co-await)
- [Asymmetric Transfer / Coroutine Theory（系列博客）— Lewis Baker](https://lewissbaker.github.io/)
