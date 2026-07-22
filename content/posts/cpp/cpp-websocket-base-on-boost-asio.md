+++
title = "基于 boost.asio 的 WebSocket 类库:WebSocket++ 实践要点"
date = "2025-06-05"
lastmod = "2025-06-05"
subtitle = "WebSocket++ 的特性、协程模型陷阱与多连接管理实践"
description = "介绍基于 boost.asio 的 header-only WebSocket 类库 WebSocket++,梳理其在协程环境下的注意事项,以及用单 Client 管理多 Connection 的实践。"
author = "小智晖"
authors = ["小智晖"]
categories = ["cpp"]
tags = ["cpp", "websocket", "boost.asio", "websocketpp", "asio", "网络编程"]
keywords = ["websocketpp", "boost.asio", "websocket", "C++", "io_context", "网络编程"]
toc = true
draft = false
+++

在 C++ 项目中接入 WebSocket(RFC 6455)时，如果团队已经在使用 Boost，那么基于 `boost::asio` 的类库是阻力最小的选择。本文记录笔者在实际项目中使用 [WebSocket++](https://github.com/zaphoyd/websocketpp)(仓库命名 `websocketpp`)的一些关键特性与踩坑点，重点关注协程环境下的线程模型，以及多连接场景下的正确用法。

## WebSocket++ 概览

[WebSocket++](https://github.com/zaphoyd/websocketpp) 是一个由 Peter Petrov(zaphoyd)维护的 C++ WebSocket 库，当前最新版本为 **0.8.2**(2020-04-19 发布)。它的核心特点包括:

- **Header Only**:整个库以头文件形式提供，接入时只需包含 `<websocketpp/client.hpp>` 或 `<websocketpp/server.hpp>`,无需单独编译链接。
- **完整实现 RFC 6455**:支持 WebSocket 协议标准，同时附带对早期草案（Hixie 76、Hybi 00/07-17）的部分服务端兼容。
- **可插拔的传输层**:底层 IO 模块是可替换的，官方支持基于 **Asio(可以是 Boost.Asio 或 standalone Asio)**、原始 buffer、iostreams 等多种 transport policy。这也是它"基于 boost.asio"说法的由来。
- **跨平台**:支持 Posix / Windows、32/64 位、Intel / ARM / PPC。
- **支持 TLS(wss)、IPv6、显式代理**。
- **消息/事件驱动接口**:通过回调(`on_open`、`on_message`、`on_close`、`on_fail`)组织业务逻辑。
- **可基于 C++11 标准库或 Boost** 运行，依赖相当灵活。

需要留意的是:WebSocket++ 自 0.8.2 之后未再发布正式版本，虽然仓库未归档，issue/PR 也仍有人跟进，但本质上处于维护停滞状态。如果对新特性、CVE 修复有强烈诉求，需要评估是否改用 `boost::beast` 或其他实现。

## 协程 / Fiber 模式下的注意事项

WebSocket++ 的网络层委托给 `boost::asio`,`client` 内部持有一个 `io_context` 并通过 Asio 完成异步解析、握手和读写。Asio 在实现上为每个线程维护了上下文信息(内部通过 `call_stack` 这一线程局部链表来关联"当前线程 / 当前 `io_context` / 当前执行中的 handler"),这套机制对 1:N 的线程模型友好，但对 **M:N 协程（fiber）模型** 需要格外小心。

具体来说:

- **1:N 协程**(N 个协程跑在 1 个 OS 线程上，或 N 个 OS 线程上各自绑定固定 `io_context`):协程在哪个 OS 线程上挂起/恢复是确定的，线程局部状态一致，可以直接使用。
- **M:N 协程 + Fiber 迁移**(Boost.Fiber 等让协程在多个 worker 线程间迁移的调度器):一旦协程跨 OS 线程迁移，Asio 内部的线程局部上下文就可能错乱，出现 handler 在错误的 `io_context` 上派发、解析结果丢失、偶发性 crash 等问题。

实践建议:

1. 优先采用 **1:N 协程**,或将 fiber 调度算法配置为不允许跨线程迁移(`work_stealing` 关闭迁移等);
2. 如果必须使用 M:N，则在 fiber 切换点显式 `dispatch` 回绑定的 `strand` 或固定线程，确保 Asio handler 的执行线程一致;
3. 不要假设"协程天然单线程",Asio 的并发安全来自 executor/strand，而非协程本身。

## 多连接的正确姿势：单 Client + 多 Connection

这是一个被反复踩到的坑。WebSocket++ 的 `client`(endpoint)在 `get_connection(uri, ec)` 时，会通过 Asio 的 resolver 进行域名解析;在默认配置下,**每次 connect 触发的解析过程会引入额外的线程开销**。

如果业务方按照"每个远端一个 `client` 对象"来组织代码，即：每管理一个 Connection 就 new 一个 `client`,再 `get_connection` → `connect`,那么当连接数上升时，系统会出现:

- 线程数随连接数线性增长（解析线程 + Asio 内部 worker）;
- 上下文切换开销显著;
- 整体吞吐反而下降。

正确做法是:**用一个 `client` 对象管理多个 Connection**。`client` 本身设计上就是 endpoint,`io_context` 是共享的，多个 `connection_ptr` 在同一个事件循环上多路复用。官方仓库下两个例子演示了这个模式:

- [`scratch_client`](https://github.com/zaphoyd/websocketpp/tree/master/examples/scratch_client):一个最小化的命令行 REPL 客户端，演示了同一个 `client` 上发起、查询、关闭多个连接。
- [`utility_client`](https://github.com/zaphoyd/websocketpp/tree/master/examples/utility_client):在 `scratch_client` 基础上扩展，维护一个 `std::map<int, connection_metadata::ptr>` 来管理连接 ID 到 handle 的映射，并为每个连接独立绑定 `on_open` / `on_message` / `on_close` / `on_fail` 回调。

两个例子的共同骨架是:

```cpp
// 1. 配置 endpoint
m_endpoint.init_asio();          // 绑定 io_context
m_endpoint.start_perpetual();    // 防止 run() 在没有任务时退出

// 2. 在专用线程上跑事件循环
m_thread = websocketpp::lib::make_shared<websocketpp::lib::thread>(&client::run, &m_endpoint);

// 3. 每次连接复用同一个 endpoint
websocketpp::lib::error_code ec;
client::connection_ptr con = m_endpoint.get_connection(uri, ec);
if (ec) { /* 处理错误 */ }
m_endpoint.connect(con);
```

这样无论管理 10 个还是 1000 个 Connection，事件循环始终是同一组线程，资源占用稳定。

### 回调绑定：每连接独立 metadata

`utility_client` 的精髓在于，它没有用一组全局回调来处理所有连接的事件，而是为每条连接构造一个 `connection_metadata` 对象，然后用 `websocketpp::lib::bind` 把这个对象自己的成员函数绑给 Asio:

```cpp
m_endpoint.set_open_handler(websocketpp::lib::bind(
    &connection_metadata::on_open, metadata_ptr,
    websocketpp::lib::placeholders::_1));
```

这种写法天然地把"连接级状态"封装在 metadata 中，避免在多连接场景下用一个全局 map + 锁去分辨事件归属，代码更清晰也更易扩展。

## 小结

- WebSocket++ 是 header-only、基于 Asio 的成熟 WebSocket 库，适合已有 Boost 栈的项目;
- 在 Boost.Fiber / M:N 协程下要谨慎，优先用 1:N 协程避免 Asio 线程局部状态错乱;
- 多连接务必复用单个 `client` endpoint，参考 `scratch_client` / `utility_client` 的 `start_perpetual + 单独线程 + map 管理连接` 模式;
- 考虑到 WebSocket++ 自 2020 年起未再发版，新项目可同时评估 `boost::beast`(Beast)作为长期演进的备选方案。

## 参考

- [WebSocket++ GitHub 仓库](https://github.com/zaphoyd/websocketpp)
- [WebSocket++ 文档](https://docs.websocketpp.org/)
- [scratch_client 示例](https://github.com/zaphoyd/websocketpp/tree/master/examples/scratch_client)
- [utility_client 示例](https://github.com/zaphoyd/websocketpp/tree/master/examples/utility_client)
- [Boost.Asio 文档](https://www.boost.org/doc/libs/release/doc/html/boost_asio.html)
