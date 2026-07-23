+++
title = "Python 协程简介"
date = "2025-04-13"
lastmod = "2025-04-13"
subtitle = "从概念、可等待对象到与 Go/JS 的横向对比"
description = "梳理 Python 协程的核心概念、async/await 与 asyncio 的基本用法，并与 Go、JS 等语言的并发模型做横向对比，附常用异步库清单。"
author = "小智晖"
authors = ["小智晖"]
categories = ["Python"]
tags = ["python", "coroutine", "asyncio", "异步编程", "并发"]
keywords = ["Python 协程", "asyncio", "async await", "异步编程", "可等待对象", "并发模型"]
toc = true
draft = false
+++

Python 在 3.5 版本中引入了协程相关的语法糖 `async` 和 `await`，在 Python 3.7 版本中又提供了 `asyncio.run()` 来运行一个协程。因此建议大家学习协程时直接使用 Python 3.7 及以上版本。

Python 官方提供了各版本的 asyncio 文档，详见[协程与任务官方文档](https://docs.python.org/zh-cn/3.13/library/asyncio-task.html)。

## 协程概念

网上有个关于洗衣机的例子写得挺直观，借用一下：

> 假设有 1 个洗衣房，里面有 10 台洗衣机，由 1 个洗衣工负责这 10 台洗衣机。那么洗衣房就相当于 1 个进程，洗衣工就相当于 1 个线程。
>
> 如果有 10 个洗衣工，就相当于 10 个线程——1 个进程是可以开多线程的，这就是多线程。

**那么协程呢？**

> 先别急。大家都知道洗衣机洗衣服需要等待时间。如果 10 个洗衣工 1 人负责 1 台洗衣机，效率固然会提高，但难道不觉得浪费资源吗？明明 1 个人就能做的事，却要 10 个人来做：只是把衣服放进去、打开开关，剩下就是等衣服洗好再拿出来。
>
> 就算很多人来洗衣服，1 个人也足以应付了：开好第一台洗衣机，在等待时去开第二台，再开第三台……直到有衣服洗好了，就回来把衣服取出来，接着再取另一台的（哪台先洗好就先取哪台，所以协程是无序的）。这就是计算机里的协程！洗衣机就是被执行的方法。

协程，又称微线程。

协程的作用是：在执行函数 A 时可以随时中断，转去执行函数 B，然后再中断函数 B、继续执行函数 A（可以自由切换）。

但这一过程并不是函数调用，整个过程看起来像多线程，实际上协程只在一个线程中执行。

协程很适合处理 I/O 密集型程序的效率问题。协程本质上是单线程，它无法同时利用单个 CPU 的多个核，因此对于 CPU 密集型程序，协程还需要和多进程配合使用。

## 可等待对象 await 的使用

可等待对象（awaitable）：如果一个对象可以在 `await` 语句中使用，那么它就是可等待对象。许多 asyncio API 都被设计为接受可等待对象。

可等待对象有三种主要类型：协程、任务 和 Future。

- 协程：Python 中的协程属于可等待对象，因此可以在其他协程中被等待。
- `time.sleep()`：Python 内置的 `sleep` 不是可等待对象，如果在协程中需要睡眠，应使用 `asyncio.sleep()`。
- 同理，socket 读写也会导致协程阻塞，应使用 `asyncio.open_connection()` 创建 socket。
- asyncio 提供了完善的异步 I/O 支持，可以用 `asyncio.run()` 调度一个 coroutine。
- 在一个 async 函数内部，通过 `await` 可以调用另一个 async 函数，这个调用看起来是串行执行的，但实际上由 asyncio 内部的事件循环控制。
- 在一个 async 函数内部，通过 `await asyncio.gather()` 可以并发执行若干个 async 函数。

## Python 与其他语言的协程对比

Go 的协程最大的优势在于它是语言内置的。从内存管理、GC 到网络库、syscall 以及对应的 runtime 实现的 M:N 调度，都做了很深的优化。同时经过多年的积淀，社区也基于内置的协程贡献了大量优秀的开源库，大家都遵循同一个并发模型（也就是 Go 推荐的模型）来编写代码，使用起来很顺手。

JS 基于回调的特性可以说是目前语言协程化做得最好的：因为没有阻塞调用，可以无痛地把一个回调风格的 API（如 `readFile`）包装成 Promise，再供 `async/await` 使用。任何回调风格的第三方库 API 都可以简单地用 `util.promisify` 变成可 `await` 的 Promise，而不需要从底层添加 API、并要求所有第三方库跟着改造。而且一个 API 可以同时以回调和 `await` 两种风格使用，可谓无缝升级。再借助 Babel，如今的 JS 项目已经把 `async/await` 用得飞起。

再反过来看很多语言的协程化进程：Python 为所有阻塞 API 在 asyncio 这个包里重新实现了一遍，但社区所有数据库驱动、网络请求库、HTTP server 库都需要为它重写，这个生态能不能火起来还是未知数。

现在唯一的期待就是 Rust 尽快从语言标准层面拥抱协程——这事儿语言官方越晚接受，社区就越伤筋动骨。

## 相关协程库

- [Web 框架 Sanic](https://github.com/sanic-org/sanic)：Python 异步 HTTP 框架。
- [aiohttp](https://github.com/aio-libs/aiohttp)：异步 HTTP 客户端/服务端框架。
- [FastAPI](https://fastapi.tiangolo.com/zh/async/)：基于 Starlette 和 Pydantic 的现代异步 Web 框架。
- [httpx](https://github.com/encode/httpx)：同时支持同步和异步 API 的 HTTP 客户端。
- [asyncpg](https://github.com/MagicStack/asyncpg)：高性能的 PostgreSQL 异步驱动。
- [Trio](https://github.com/python-trio/trio)：一个友好的 Python 异步并发与 I/O 库。
- [redis-py 异步示例](https://redis-py.readthedocs.io/en/stable/examples/asyncio_examples.html)：Redis 的 Python 异步调用示例。

## 参考

- [Python 官方文档：协程与任务（asyncio）](https://docs.python.org/zh-cn/3.13/library/asyncio-task.html)
- [PEP 492 – Coroutines with async and await syntax](https://peps.python.org/pep-0492/)
- [Python 3.7 What's New](https://docs.python.org/3/whatsnew/3.7.html)
