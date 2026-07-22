+++
title = "C++ Promise/Future 模型"
date = "2025-04-06"
lastmod = "2025-04-06"
subtitle = "从 std::promise/std::future 到业界异步框架的演进"
description = "介绍 C++11 标准库 <future> 头文件中 Promise/Future 模型的核心组件，并梳理业界主流异步框架对该模型的扩展实践。"
author = "小智晖"
authors = ["小智晖"]
categories = ["C++"]
tags = ["cpp", "异步编程", "Promise", "Future", "并发"]
keywords = ["C++ Promise", "std::future", "std::promise", "异步编程", "并发", "std::packaged_task"]
toc = true
draft = false
+++

Promise/Future 是一种经典的异步抽象，正因为它提供了一套「标准化」的概念，因而衍生出许多可能性。这就如同工业史上的集装箱、软件界的 Docker——凭借「标准化」这一关键属性，不同组件可以简单地自由组合，从而大幅提升整体效率。

## C++11 中的 Promise/Future 模型

C++11 标准在 `<future>` 头文件中引入了一组与异步编程相关的类和函数。

`<future>` 头文件中主要包含以下几类组件：

- Providers（提供者）类：`std::promise`、`std::packaged_task`
- Futures（未来值）类：`std::future`、`std::shared_future`
- Providers 函数：`std::async()`
- 其他类型：`std::future_error`、`std::future_errc`、`std::future_status`、`std::launch`

### std::promise 类介绍

`promise` 对象可以保存某一类型 `T` 的值，该值可被 `future` 对象读取（可能在另一个线程中），因此 `promise` 也提供了一种线程同步的手段。在 `promise` 对象构造时，可以和一个共享状态（通常是 `std::future`）相关联，并可以在该共享状态上保存一个类型为 `T` 的值。

可以通过 `get_future` 来获取与该 `promise` 对象相关联的 `future` 对象，调用该函数之后，两个对象共享相同的共享状态（shared state）：

- `promise` 对象是异步 Provider，它可以在某一时刻设置共享状态的值；
- `future` 对象可以异步返回共享状态的值，或在必要时阻塞调用者，等待共享状态标志变为 ready，然后才能获取共享状态的值。

下面以一个简单的例子来说明上述关系：

```cpp
#include <iostream>       // std::cout
#include <functional>     // std::ref
#include <thread>         // std::thread
#include <future>         // std::promise, std::future

void print_int(std::future<int>& fut) {
    int x = fut.get(); // 获取共享状态的值
    std::cout << "value: " << x << '\n'; // 打印 value: 10
}

int main()
{
    std::promise<int> prom; // 生成一个 std::promise<int> 对象
    std::future<int> fut = prom.get_future(); // 与 future 关联
    std::thread t(print_int, std::ref(fut)); // 将 future 交给另一个线程 t
    prom.set_value(10); // 设置共享状态的值，此处与线程 t 保持同步
    t.join();
    return 0;
}
```

## 扩展 Promise/Future 模型

C++11 标准库提供的 `std::future` 没有提供注册回调的接口，导致其使用受限，通常只用来跨线程传值同步。

业界多种异步编程框架都基于或扩展了 Promise/Future 机制，例如：

- [tRPC-Cpp 自行设计的 Promise/Future](https://github.com/trpc-group/trpc-cpp/blob/main/docs/zh/future_promise_guide.md)
- [Seastar 源码阅读：future/promise 链式调用的实现](https://bobhan1.github.io/post/seastar-future-promise/)
- [Tencent flare 的 Promise/Future 模型](https://github.com/Tencent/flare/blob/master/flare/doc/future.md)

## 参考

- [std::promise — cppreference](https://en.cppreference.com/w/cpp/thread/promise)
- [std::future — cppreference](https://en.cppreference.com/w/cpp/thread/future)
- [std::packaged_task — cppreference](https://en.cppreference.com/w/cpp/thread/packaged_task)
- [std::async — cppreference](https://en.cppreference.com/w/cpp/thread/async)
