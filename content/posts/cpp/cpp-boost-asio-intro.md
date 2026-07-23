+++
title = "Boost.Asio 简介"
date = "2025-04-08"
lastmod = "2025-04-08"
subtitle = "跨平台 C++ 异步 I/O 编程库的核心概念与用法"
description = "介绍 Boost.Asio 的设计理念、核心类(io_context、Timer、Socket)、事件循环方法及多线程编程思路,并附调试实践与参考应用。"
author = "小智晖"
authors = ["小智晖"]
categories = ["cpp", "网络编程"]
tags = ["cpp", "boost", "asio", "异步编程", "网络编程", "io_context"]
keywords = ["Boost.Asio", "C++ 异步 IO", "io_context", "steady_timer", "strand", "网络编程"]
toc = true
draft = false
+++

## 概述

Boost.Asio 是一个跨平台的、主要用于网络和其他一些底层输入/输出编程的 C++ 库。

Asio，即「异步 IO」(Asynchronous Input/Output),本是一个[独立的 C++ 网络程序库](http://think-async.com/Asio),似乎并不为人所知，后来因为被 Boost 相中，才声名鹊起。

从设计上来看，Asio 相似且重度依赖于 Boost，与 thread、bind、smart pointers 等结合时，体验顺滑。从使用上来看，依然是重组合而轻继承，一贯的 C++ 标准库风格。

### Boost.Asio 代码风格

Asio 为了可读性，将部分较复杂的类的声明和实现分成了两个头文件：在声明的头文件末尾 `include` 负责实现的头文件。`impl` 文件夹包含这些实现的头文件。另外，还有一个常见的关键词是 `detail`,不同操作系统下的各种具体代码会放在 `detail` 文件夹下。

例如,`scheduler.hpp` 包含 `scheduler.ipp`:

```cpp
...
#include <boost/asio/detail/pop_options.hpp>

#if defined(BOOST_ASIO_HEADER_ONLY)
# include <boost/asio/detail/impl/scheduler.ipp>
#endif // defined(BOOST_ASIO_HEADER_ONLY)

#endif // BOOST_ASIO_DETAIL_SCHEDULER_HPP
```

## 关键类

### io_context / io_service

Boost.Asio 中最核心的类是 `io_context`。它是这个库里面最重要的类，负责和操作系统打交道，等待所有异步操作的结束，然后为每一个异步操作调用其完成处理程序（handler）。

每个 Asio 程序都至少有一个 `io_context` 对象，它代表了操作系统的 I/O 服务(`io_context` 在 Boost 1.66 之前一直叫 `io_service`),把你的程序和这些服务链接起来。

`io_service` 其实就是 `io_context`,其存在只是为了向后兼容:

```cpp
#if !defined(BOOST_ASIO_NO_DEPRECATED)
/// Typedef for backwards compatibility.
typedef io_context io_service;
#endif // !defined(BOOST_ASIO_NO_DEPRECATED)
```

`io_context` 是线程安全的。多个线程可以同时调用 `io_context::run()`。大多数情况下，你可能在单线程中调用 `io_context::run()`,这个函数会等待所有异步操作完成之后再继续执行。然而，事实上你也可以在多个线程中调用 `io_context::run()`,这会阻塞所有调用了 `run()` 的线程。当任何一个异步事件完成时,`io_context` 会将相应的 handler 交给其中某个线程去执行。

### Timer

有了 `io_context` 还不足以完成 I/O 操作，用户一般也不跟 `io_context` 直接交互。

根据 I/O 操作的不同，Asio 提供了不同的 I/O 对象，比如 timer(定时器)、socket 等等。

Timer 是最简单的一种 I/O 对象，可以用来实现异步调用的超时机制。下面是最简单的用法:

```cpp
#include <boost/asio.hpp>
#include <chrono>
#include <iostream>

void Print(boost::system::error_code ec) {
  if (!ec) {
    std::cout << "Hello, world!" << std::endl;
  }
}

int main() {
  boost::asio::io_context ioc;
  boost::asio::steady_timer timer(ioc, std::chrono::seconds(3));
  timer.async_wait(&Print);
  ioc.run();
  return 0;
}
```

### Socket

Socket 也是一种 I/O 对象，这一点前面已经提及。相比于 timer,socket 更为常用，毕竟 Asio 是一个网络程序库。

需要注意:`tcp::socket` 类本身**不是**线程安全的。因此，要避免在某个线程里读一个 socket 时，同时在另外一个线程里对同一个 socket 进行写入操作（通常来说，这种并发访问同一对象的做法都不被推荐，在 Boost.Asio 中更应避免）。更准确地说：对同一个 socket 同时发起多个**同类型**的未完成异步操作(例如同时有两个 `async_read_some` 未完成)是不安全的;而一个 `async_read` 与一个 `async_write` 同时存在则是允许的。若要避免 handler 之间的竞态，可以使用 `strand` 串行化执行。

## 异步事件循环:run(), run_one(), poll(), poll_one()

为了实现事件循环,`io_context` 类提供了 4 个常用方法:`run()`、`run_one()`、`poll()` 和 `poll_one()`。虽然大多数时候使用 `run()` 就够了，但你还是有必要了解其他方法实现的功能。

- `run()`:会一直执行事件循环，直到没有更多的异步操作(或手动调用 `io_context::stop()`)。
- `run_one()`:最多执行和分发一个异步操作。如果没有等待的操作，方法立即返回 0;如果有等待操作，方法在第一个操作执行完毕之前处于阻塞状态，然后返回 1。
- `poll_one()`:以非阻塞的方式最多运行一个**已经就绪**的等待操作。如果至少有一个已就绪的操作,`poll_one` 会运行它并返回 1;否则立即返回 0。
- `poll()`:以非阻塞的方式运行所有**已经就绪**的等待操作。

## 多线程

在多线程下使用 Asio，通常有两种思路。

### 思路 1:每个线程一个 io_context

在多线程的场景下，每个线程都持有一个 `io_context`,并且每个线程都调用各自的 `io_context` 的 `run()` 方法。

特点:

- 在多核的机器上，这种方案可以充分利用多个 CPU 核心。
- 某个 socket 描述符并不会在多个线程之间共享，所以不需要引入同步机制。
- 在 event handler 中不能执行阻塞的操作，否则将会阻塞掉 `io_context` 所在的线程。

### 思路 2:多个线程共享一个 io_context

全局只分配一个 `io_context`,并且让这个 `io_context` 在多个线程之间共享，每个线程都调用全局的 `io_context` 的 `run()` 方法。

先分配一个全局 `io_context`,然后开启多个线程，每个线程都调用这个 `io_context` 的 `run()` 方法。这样，当某个异步事件完成时,`io_context` 就会将相应的 event handler 交给任意一个线程去执行。

然而这种方案在实际使用中，需要注意一些问题:

- 在 event handler 中允许执行阻塞的操作（例如数据库查询操作）。
- 线程数可以大于 CPU 核心数。譬如说，如果需要在 event handler 中执行阻塞的操作，为了提高程序的响应速度，这时就需要提高线程的数目。
- 由于多个线程同时运行事件循环（event loop）,所以会导致一个问题：一个 socket 描述符可能会在多个线程之间共享，容易出现竞态条件（race condition）。譬如说，如果某个 socket 的可读事件很快发生了两次，那么就会出现两个线程同时读同一个 socket 的问题（可以使用 strand 解决这个问题）。
- 无锁的同步方式:Asio 提供了 `strand`(新版推荐使用 `make_strand(io_context)` 或 `io_context::make_strand()`)。如果多个 event handler 通过同一个 strand 对象分发（dispatch）,那么这些 event handler 就会保证顺序地执行，而不会并发。

## 调试实践

捕获线程创建时机:

```gdb
break pthread_create
```

下面的调用栈来自 `websocketpp` 发起连接时触发 Asio 创建解析器后台线程的路径:

```text
- websocketpp::client<websocketpp::config::asio_client>::connect
    - websocketpp::transport::asio::endpoint<websocketpp::config::asio_client::transport_config>::async_connect
        - boost::asio::ip::basic_resolver
            - boost::asio::async_result<boost::asio::detail::wrapped_handler
                - boost::asio::ip::basic_resolver<boost::asio::ip::tcp, boost::asio::execution::any_executor
                    - boost::asio::detail::resolver_service<boost::asio::ip::tcp>::async_resolve
                        - boost::asio::detail::resolver_service_base::start_resolve_op
                            - boost::asio::detail::resolver_service_base::start_work_thread
                                - boost::asio::detail::posix_thread::posix_thread<boost::asio::detail::resolver_service_base::work_scheduler_runner>
                                    - boost::asio::detail::posix_thread::start_thread
```

查看 scheduler 创建:

```gdb
break boost::asio::detail::scheduler::scheduler
```

## 基于 Boost.Asio 的应用

- [websocketpp:C++ WebSocket header-only 库](https://github.com/zaphoyd/websocketpp):实现了 RFC 6455 WebSocket 协议，可基于 Boost.Asio 或独立的 Asio 作为底层传输。

## 参考

- [Boost.Asio C++ 网络编程（中文翻译）](https://mmoaay.gitbooks.io/boost-asio-cpp-network-programming-chinese/content/)
- [Boost.Asio 官方文档](https://www.boost.org/doc/libs/release/doc/html/boost_asio.html)
- [Boost 1.66 Release Notes(io_context 引入)](https://www.boost.org/users/history/version_1_66_0.html)
- [独立的 Asio 库（think-async.com）](http://think-async.com/Asio/)
