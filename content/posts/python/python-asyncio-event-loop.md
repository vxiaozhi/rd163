+++
title = "Python asyncio 的事件循环机制"
date = "2025-09-07"
lastmod = "2025-09-07"
subtitle = "从 AbstractEventLoop 到 uvloop:理解事件循环的角色与替换方案"
description = "梳理 Python asyncio 事件循环的职责、内置实现(Selector/Proactor)、关键 API,以及 uvloop 等第三方替代方案的选型与用法。"
author = "小智晖"
authors = ["小智晖"]
categories = ["python"]
tags = ["python", "asyncio", "事件循环", "event loop", "uvloop", "异步编程"]
keywords = ["python", "asyncio", "event loop", "事件循环", "uvloop", "asyncio.run"]
toc = true
draft = false
+++

在使用 Python 的 asyncio 库实现异步编程时，协程（coroutine）与事件循环（event loop）这两个概念总是形影不离：协程只声明了「怎么挂起、怎么恢复」,而真正驱动这些协程不断推进的「调度器」,就是事件循环。理解事件循环的角色，是写出正确的异步代码、以及做性能选型（比如要不要换 uvloop）的前提。

## 事件循环到底在做什么

按照 [Python 官方文档](https://docs.python.org/3/library/asyncio-eventloop.html)的定义，事件循环是每一个 asyncio 应用的核心，它主要做三件事:

- 运行异步任务（asynchronous tasks）与回调（callbacks）;
- 执行网络 I/O 操作;
- 启动和管理子进程（subprocess）。

可以把事件循环想象成一个不断循环的「调度中枢」:它维护着一组就绪的任务、定时器和 I/O 监听，每一轮迭代都从就绪队列里取出可以推进的任务去执行;当任务遇到 `await` 挂起时，控制权交还回事件循环，它再去处理下一个就绪项。所有协程之所以能在单线程里表现出「并发」的效果，正是因为这个调度中枢不断在它们之间切换。

## Python 内置的两种事件循环实现

`asyncio.AbstractEventLoop` 是事件循环的抽象基类，它定义了一组事件循环应当实现的方法。CPython 标准库自带两种具体实现:

| 实现 | 底层机制 | 平台 |
|------|----------|------|
| `asyncio.SelectorEventLoop` | 基于 `selectors` 模块，自动选用平台最高效的 I/O 多路复用(Linux 上是 `epoll`、macOS/BSD 上是 `kqueue`) | Unix、Windows |
| `asyncio.ProactorEventLoop` | 基于 Windows 的 I/O Completion Ports(IOCP) | 仅 Windows |

从 Python 3.13 起，标准库新增了一个 `asyncio.EventLoop` 别名，它会自动指向当前平台上「最快的子类」——Unix 上是 `SelectorEventLoop`,Windows 上是 `ProactorEventLoop`。需要注意的是，Windows 上的 `SelectorEventLoop` 不支持子进程，如果要用 `asyncio.subprocess`,需要使用 `ProactorEventLoop`。

## `asyncio.run()`:推荐的程序入口

对应用层开发者，官方建议始终通过高级 API `asyncio.run()` 启动协程，而不要手动管理事件循环对象。这个函数自 Python 3.7 引入，签名是:

```python
asyncio.run(coro, *, debug=None, loop_factory=None)
```

它做了完整的一套生命周期管理：新建事件循环、运行传入的 awaitable、关闭事件循环、收尾异步生成器（async generators）、并关闭默认的 executor(默认 5 分钟超时)。文档明确指出，它是「asyncio 程序的主入口点」,理想情况下只调用一次。

```python
import asyncio

async def main():
    await asyncio.sleep(1)
    print("Hello, asyncio!")

asyncio.run(main())
```

`loop_factory` 参数（Python 3.12 加入）允许传入一个自定义的事件循环工厂，这是替代「事件循环策略（event loop policy）」的新方式。旧的 policy 系统自 Python 3.14 起进入弃用期，计划在 Python 3.16 移除。

## 事件循环的关键方法

虽然在应用代码里很少直接拿到 loop 对象，但了解它的几个核心方法有助于读懂框架源码和排查问题。常用的方法大致分三类。

**运行与停止**

- `loop.run_forever()`:一直跑直到调用 `loop.stop()`。
- `loop.run_until_complete(future)`:跑到 Future 或协程完成，返回结果。
- `loop.stop()` / `loop.close()`:`stop` 只是请求停止,`close` 释放底层资源，且不能在 loop 正在运行时调用。

**调度回调**

- `loop.call_soon(callback, *args)`:在事件循环下一次迭代时调用，这是最基础的「马上排到队尾」原语。
- `loop.call_later(delay, callback, *args)`:延迟 `delay` 秒后调用，基于单调时钟。
- `loop.call_at(when, callback, *args)`:在绝对时间戳 `when` 调用，与 `loop.time()` 共用同一时钟。
- `loop.call_soon_threadsafe(...)`:跨线程唤醒事件循环，这是从其他线程往 loop 投递任务的唯一安全方式。

**任务与执行器**

- `loop.create_task(coro)`:把协程包装成 `Task` 并立即调度，返回 Task 对象。
- `loop.create_future()`:在当前 loop 上创建一个 `Future`。
- `loop.run_in_executor(executor, func, *args)`:把阻塞函数扔到线程池或进程池执行，返回 awaitable 的 Future。这是 asyncio 与同步阻塞代码（包括 CPU 密集任务）协作的桥梁。

下面是一个用 `run_in_executor` 跑阻塞 I/O 和 CPU 密集任务的典型写法:

```python
import asyncio
import concurrent.futures

def blocking_io():
    with open('/dev/urandom', 'rb') as f:
        return f.read(100)

def cpu_bound():
    return sum(i * i for i in range(10 ** 7))

async def main():
    loop = asyncio.get_running_loop()

    # 默认线程池
    result = await loop.run_in_executor(None, blocking_io)

    # 自定义进程池,跑 CPU 密集任务
    with concurrent.futures.ProcessPoolExecutor() as pool:
        result = await loop.run_in_executor(pool, cpu_bound)

asyncio.run(main())
```

## 平台差异与信号处理

事件循环的一些能力与平台绑定。`loop.add_signal_handler(signum, callback, *args)` 和 `loop.remove_signal_handler(signum)` 在官方文档里被明确标注为 **仅 Unix 可用**;在 Windows 上注册信号需要走传统方案。这两个方法注册的回调由事件循环本身触发，因此可以安全地操作 loop，而 `signal.signal()` 注册的处理器则不能。

一个在 SIGINT/SIGTERM 时优雅退出的常见写法:

```python
import asyncio
import functools
import signal

def ask_exit(signame, loop):
    print(f"got signal {signame}: exit")
    loop.stop()

async def main():
    loop = asyncio.get_running_loop()
    for signame in {'SIGINT', 'SIGTERM'}:
        loop.add_signal_handler(
            getattr(signal, signame),
            functools.partial(ask_exit, signame, loop))
    await asyncio.sleep(3600)

asyncio.run(main())
```

## 第三方事件循环实现

由于 `AbstractEventLoop` 是抽象基类，只要按规范实现这套接口，就可以替换默认的事件循环。生态中两个常被提及的项目是 uvloop 和 trio，但它们的定位截然不同。

### uvloop:drop-in 替换

[uvloop](https://github.com/MagicStack/uvloop) 是 asyncio 内置事件循环的高性能替代品，使用 Cython 编写，底层基于 [libuv](https://libuv.org/)(Node.js 使用的同一个 C 异步 I/O 库)。它的特点:

- **drop-in replacement**:符合 asyncio 接口，业务代码无需改动。
- 官方基准下，asyncio 在 uvloop 上可达到 **2-4 倍**的吞吐提升。
- 需要 Python 3.8 及以上，PyPI 分类是 POSIX 和 macOS(在 Windows 上不提供预编译包)。
- 双授权:MIT 和 Apache 2.0。

自 uvloop 0.18 起官方推荐的用法是 `uvloop.run()`:

```python
import uvloop

async def main():
    ...

uvloop.run(main())
```

它内部只是把 `asyncio.run()` 配置成使用 uvloop，所有参数(例如 `debug=True`)都会透传。在 Python 3.11 之前则需要用 `asyncio.Runner(loop_factory=uvloop.new_event_loop)` 或 `uvloop.install()`。

[Sanic](https://github.com/sanic-org/sanic) 是 Python 生态里早期主打异步的高性能 Web 框架，其 README 明确写道「Sanic makes use of `uvloop` and `ujson` to help with performance」,安装时若环境支持就会自动带上 uvloop(可用 `SANIC_NO_UVLOOP=true` 关闭)。Sanic 当前最低要求 Python 3.10。

### trio:不是 asyncio 的「实现」

需要特别澄清一点：经常和 uvloop 并列提到的 [trio](https://github.com/python-trio/trio) **并不是** asyncio 事件循环的第三方实现，而是一个完全独立的异步并发库，它提出并实践了「结构化并发（structured concurrency）」的概念。trio 不复用 asyncio 的接口(`asyncio.run`、`Task` 等),自己的 API 体系(`trio.run`、nursery、cancel scopes)。它的设计目标是比 asyncio/Twisted 更简洁，灵感部分来自 Dave Beazley 的 Curio 项目，需要 Python 3.10 及以上。

所以严格来说，只有 uvloop 这一类「实现了 `AbstractEventLoop` 接口」的项目才能称为「asyncio 事件循环的第三方实现」;trio 与 asyncio 是平行的两套抽象。

## 参考

- [Event Loop — Python 官方文档](https://docs.python.org/3/library/asyncio-eventloop.html)
- [asyncio Runner — `asyncio.run()` 文档](https://docs.python.org/3/library/asyncio-runner.html)
- [FastAPI 文档中对 async / await 的介绍](https://fastapi.tiangolo.com/async/)
- [uvloop 项目](https://github.com/MagicStack/uvloop)
- [Sanic Web 框架](https://github.com/sanic-org/sanic)
- [trio 项目](https://github.com/python-trio/trio)
- [以定时器为例研究一手 Python asyncio 的协程事件循环调度](https://www.lipijin.com/python-asyncio-eventloop)
- [《asyncio 系列》1. 什么是 asyncio?如何基于单线程实现并发?事件循环又是怎么工作的?](https://www.cnblogs.com/traditional/p/17357782.html)
- [《asyncio 系列》2. 详解 asyncio 的协程、任务、future，以及事件循环](https://www.cnblogs.com/traditional/p/17363960.html)
- [《asyncio 系列》3. 详解 Socket(阻塞、非阻塞),以及和 asyncio 的搭配](https://www.cnblogs.com/traditional/p/17364391.html)
