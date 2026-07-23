+++
title = "C++协程介绍"
date = "2025-03-31"
lastmod = "2025-03-31"
subtitle = "协程与纤程的原理、Runtime 模型与选型依据"
description = "梳理 C++ 协程与纤程（M:N 协程）的区别、底层上下文切换原理、tRPC 的三种 Runtime 模型，以及基于 Little's Law 的同步/异步选型方法。"
author = "小智晖"
authors = ["小智晖"]
categories = ["cpp"]
tags = ["cpp", "协程", "纤程", "fiber", "coroutine", "tRPC"]
keywords = ["C++协程", "纤程", "M:N协程", "tRPC fiber", "上下文切换", "brpc"]
toc = true
draft = false
+++


## 协程（coroutine）与纤程（fiber）区别

### 协程（Coroutine）

N:1 协程。

协程是语言级别的特性（C++20 原生支持），由编译器生成状态机逻辑，通过 `co_await`、`co_yield` 等关键字实现隐式挂起和恢复，无需直接操作底层上下文。

N:1 协程即多个协程协作运行在一个系统线程上（当然系统线程可以有多个）。基于对系统调用 hook 的封装层次，可分为：非 hook、部分 hook、全面 hook。

N:1 协程的一大优点是，可以完全无锁编写同步风格代码，对于普通的互联网后台业务（IO-Bound 型）编程是很友好的。

但它也有一个明显的缺点：各个线程之间无法均衡任务，导致一个线程中的某个协程运行过久，会影响本线程的其他协程，因此不适合 CPU-Bound 型业务。

业界方案：

- [boost.context](https://github.com/boostorg/context)
- [Tencent Libco](https://github.com/Tencent/libco)
- [libtask](https://swtch.com/libtask/)
- [C++20 coroutine](/2025/04/06/cpp20-corouting-intro/)

### 纤程（Fiber）

通常指 M:N 协程（也称作纤程），其实现是支持在多个系统原生线程（`std::thread`）上调度运行多个用户态线程（fiber）。主要特性如下：

- 多个线程间竞争共享 fiber 队列，在精心设计下可以达到较低的调度延迟。目前调度组大小（组内线程数）限定为 8~15 之间。
- 为了减少竞争、提升多核扩展性，设计了多调度组机制，调度组个数以及大小可以配置。
- 与 pthread 良好的互操作性。

业界实现方案：

- Google：[marl](https://github.com/google/marl)（注：仓库已于 2026 年 4 月归档）
- Apache（原百度）：[brpc / bthread](https://github.com/apache/brpc)
- Tencent：[flare/fiber](https://github.com/Tencent/flare/tree/master/flare/fiber)
- Boost：[fiber](https://github.com/boostorg/fiber)
- 社区（yyzybb537）：[libgo](https://github.com/yyzybb537/libgo)


## 底层原理

### 如何实现上下文切换

要实现协程切换，底层必须实现两个函数，并且这两个函数通常是硬件平台相关的，需要对不同平台（x86_64 / ppc64le / aarch64）作不同实现：

- `make_fcontext` 创建一个上下文
- `jump_fcontext` 切换到另一个上下文

> 这两个函数对应 Boost.Context 的 fcontext API（`make_fcontext` / `jump_fcontext`）。

tRPC fiber 的实现，看代码注释应该是参照了 boost.fcontext 的实现，具体实现代码位于：

```text
trpc/runtime/threadmodel/fiber/detail/fcontext
```

### 如何对系统底层收发包函数进行替换

- [libunifex](https://github.com/facebookexperimental/libunifex)：libunifex 是 lib unified executors 的缩写，是 C++ sender/receiver 异步编程模型（对应 C++ 标准提案 P2300 / P0443）的一个原型实现。它提供了调度器、定时器，支持线程、协程、GPU、SIMD 等多种执行方式，并易于扩展。

## Runtime 类型

参考：[trpc-cpp Runtime 文档](https://github.com/trpc-group/trpc-cpp/blob/main/docs/zh/runtime.md)。

### fiber M:N 协程

优点：

- 采用协程同步编程方式，方便编写逻辑复杂的业务代码；
- 网络 IO 和业务处理逻辑可多核并行化，能充分利用多核，做到很低的长尾延时。

缺点：

- 为了不阻塞线程，可能需要使用特定的协程同步原语进行同步，代码侵入性较强；
- 由于协程数受系统限制，且协程调度存在额外开销，在 QPS 或连接数较大场景下性能表现不够好。

### default-separate：reactors + thread pool

优点：

- 各个 Handle 线程很自然地达到负载均衡。
- 各个任务天然隔离，适应任意类型的业务：IO-Bound（I/O 密集型）、CPU-Bound（计算密集型）等。

缺点：

- 一个请求/回复至少经过 2 个线程，会引入额外的调度延迟，在低延迟业务中有所不足。IO/Handle 之间的通知机制需要良好设计，避免过多唤醒的系统调用。
- 在高并发时，IO/Handle 之间的全局队列需要良好的设计，否则可能成为系统瓶颈。
- 需要考虑 CPU-Bound 或者阻塞逻辑对 continuation 的影响，否则业务编程困难。
- 在部分业务场景，合适的 IO/Handle 线程数量比例难以估算，配置困难。

### default-merge：reactors in threads

优点：

- 架构简洁可靠：全异步方案，逻辑统一，易于理解。
- 对于 NUMA 架构天然适配。
- 一个请求/回复只在一个线程处理，对于低延迟业务友好。
- 可以做到无锁编程。

缺点：

- 不允许阻塞代码，否则可能引起问题，所以业务开发门槛稍高；对于 CPU-Bound 业务同样不合适。
- 同一个线程中的各个任务容易互相干扰。


## 判断是否使用 M:N 协程的依据或场景

判断使用同步或异步的基本原则：计算 `qps * latency(in seconds)`（来源于 brpc 文档，即 Little's Law）。如果结果和 CPU 核数是同一数量级，就用同步，否则用异步。

举例：

- `qps = 2000`，`latency = 10ms`，计算结果 = `2000 * 0.01s = 20`。和常见的 32 核在同一个数量级，用同步。
- `qps = 100`，`latency = 5s`，计算结果 = `100 * 5s = 500`。和核数不在同一个数量级，用异步。
- `qps = 500`，`latency = 100ms`，计算结果 = `500 * 0.1s = 50`。基本在同一个数量级，可用同步；如果未来延时继续增长，考虑异步。

这个公式计算的是同时进行的平均请求数（即并发数，可以尝试证明一下），和线程数、CPU 核数是可比的。

- 当这个值远大于 CPU 核数时，说明大部分操作并不耗费 CPU，而是让大量线程阻塞着，使用异步可以明显节省线程资源（栈占用的内存）。
- 当这个值小于或和 CPU 核数差不多时，异步能节省的线程资源就很有限了，这时候简单易懂的同步代码更重要。
- 除此之外，还要看具体的业务场景：如果业务会面对大量的短/长连接，M:N 协程的实现性能通常比不上通用线程模型，不太适合。


## 参考文档

- [tRPC fiber 介绍](https://github.com/trpc-group/trpc-cpp/blob/main/docs/zh/fiber.md)
- [tRPC fiber 指南](https://github.com/trpc-group/trpc-cpp/blob/main/docs/zh/fiber_user_guide.md)
- [brpc client 文档（同步/异步与 Little's Law）](https://github.com/apache/brpc/blob/master/docs/cn/client.md)
- [Boost.Context 文档](https://www.boost.org/doc/libs/release/libs/context/doc/html/index.html)
