+++
title = "C/C++ 实现的服务器和服务器相关的库"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从 Web Server 到网络框架、无锁队列与可观测性库的整理"
description = "整理 C/C++ 实现的高性能服务器、网络框架、WebSocket 库、无锁队列与可观测性类库,涵盖 Nginx、HAProxy、Envoy、muduo、Seastar、OpenTelemetry 等。"
author = "小智晖"
authors = ["小智晖"]
categories = ["后端", "C/C++"]
tags = ["server", "cpp", "http-server", "network-library", "observability"]
keywords = ["C++ 服务器", "HTTP Server", "网络库", "muduo", "Seastar", "OpenTelemetry"]
toc = true
draft = false
+++

## HTTP Server

### NGINX

### HAProxy

### Envoy

### Apache HTTP Server

### Apache Traffic Server

- [Apache Traffic Server](https://github.com/apache/trafficserver)

Apache Traffic Server™ 是一种高性能 Web 代理缓存，它通过在网络边缘缓存经常访问的信息来提高网络效率和性能。这使内容在物理上更接近最终用户，同时实现更快的交付并减少带宽使用。Traffic Server 旨在通过最大化现有和可用带宽来改善企业、互联网服务提供商 (ISP)、骨干提供商和大型 Intranet 的内容交付。

Apache Traffic Server(ATS 或 TS)是一个高性能的、模块化的 HTTP 代理和缓存服务器，与 Nginx 和 Squid 类似。Traffic Server 最初是 Inktomi 公司的商业产品，该公司在 2003 年被 Yahoo 收购;2009 年 8 月 Yahoo 向 Apache 软件基金会（ASF）贡献了源代码，并于 2010 年 4 月成为 ASF 的顶级项目（Top-Level Project）。Apache Traffic Server 现在是一个开源项目，开发语言为 C++。

### Squid

- [Squid Web Proxy Cache](https://github.com/squid-cache/squid)
- 注意:GitHub 上并没有提供代码的发行版本，直接编译会失败。需要到其[官网](https://www.squid-cache.org/Versions/v6/)下载代码编译。

Squid 是一个高性能的代理缓存服务器，支持 FTP、HTTPS 和 HTTP 协议（早期版本也支持 gopher，但 gopher 相关代码在较新版本中已被移除）。与一般的代理缓存软件不同，Squid 使用一个单独的、非模块化的、I/O 驱动的进程来处理所有的客户端请求;作为应用层的代理服务软件，Squid 主要提供缓存加速、应用层过滤控制的功能。

### lighttpd2

- [lighttpd2](https://github.com/lighttpd/lighttpd2)

### Boa

- [Boa web server](https://github.com/gpg/boa)

### TinyWebServer

- [TinyWebServer —— Linux 下 C++ 轻量级 WebServer 服务器，助力初学者快速实践网络编程，搭建属于自己的服务器](https://github.com/qinguoyi/TinyWebServer)

---

## 类库

### 基础库

- [POCO (Portable Components) C++ Libraries](https://github.com/pocoproject/poco)
- [Abseil - C++ Common Libraries](https://github.com/abseil/abseil-cpp):Google 内部的 C++ 轮子库，各种基础能力都包含，值得学习。
- [Folly: Facebook Open-source Library](https://github.com/facebook/folly):Facebook 内部的轮子库，线程池、内存池、异步 IO、executor 等，应有尽有。

### Proxygen

- [Proxygen: Facebook's C++ HTTP Libraries](https://github.com/facebook/proxygen)

Proxygen 是 Facebook 开发的一个 C++ HTTP 库，包含一个易用的 HTTP 服务器，支持 HTTP/1.1、SPDY/3、SPDY/3.1、HTTP/2 以及 HTTP/3(基于 mvfst 提供的 IETF QUIC 实现)。

Proxygen 并非为了替换 Apache 或者 Nginx，该项目主要侧重于用 C++ 构建超级灵活的 HTTP 服务器，提供非常好的性能和灵活的配置;此外也是为了构建一个高性能的 C++ HTTP 框架，帮助更多人构建和部署高性能的 C++ HTTP 服务。Proxygen 这个名字是 oxygen 的谐音。

### muduo

- [muduo —— Event-driven network library for multi-threaded Linux server in C++11](https://github.com/chenshuo/muduo)

### Seastar

- [Seastar —— High performance server-side application framework](https://github.com/scylladb/seastar)

### WebSocket

- [WebSocket++](https://github.com/zaphoyd/websocketpp)
  - Header Only 的跨平台 WebSocket 库。
  - 网络 IO 基于 Boost.Asio 实现。
- [uWebSockets](https://github.com/uNetworking/uWebSockets)
- [libwebsockets](https://github.com/warmcat/libwebsockets):纯 C 实现。

更多 C++ WebSocket 库可参考:[C++ WebSocket 库](https://hanpfei.github.io/2019/10/25/cpp_websocket/)。

### 无锁队列

- [moodycamel::ConcurrentQueue](https://github.com/cameron314/concurrentqueue):C++11 实现的工业级（industrial-strength）无锁队列，多生产者多消费者，全部通过标准 C++11 原语实现，不依赖汇编。
- [atomic_queue](https://github.com/max0x7ba/atomic_queue):C++14 实现的并发无锁低延迟队列。

### 可观测性

[**The OpenTelemetry C++ Client**](https://github.com/open-telemetry/opentelemetry-cpp) 提供 Server 侧接入 OpenTelemetry 的类库。

- 历史：由 OpenTracing 和 OpenCensus 项目合并而成（2019 年正式合并）,是 CNCF 项目，旨在统一追踪（Tracing）、指标（Metrics）、日志（Logs）的观测性标准。2025 年 8 月，OpenTelemetry 已从 CNCF 孵化器毕业（Graduated）,成为 CNCF 的毕业项目。
- 状态：活跃开发，被视为未来可观测性工具的事实标准。C++ 客户端在 Tracing、Metrics、Logs 三种信号上均已达到 Stable 状态。
- 核心目标：提供全功能的 SDK(包括 API、数据采集、导出等),支持多信号。

该库是线程安全的，可参考 demo:

- [http demo](https://github.com/open-telemetry/opentelemetry-cpp/tree/main/examples/http)
- [multithreaded demo](https://github.com/open-telemetry/opentelemetry-cpp/tree/main/examples/multithreaded)

[**opentracing-cpp**](https://github.com/opentracing/opentracing-cpp)

- 历史:OpenTracing 是早期分布式追踪的标准（2016 年提出）,旨在提供统一的 API 规范，由第三方厂商实现具体库（如 Jaeger、LightStep 等）。
- 状态：仓库已于 2024 年 1 月归档（archived）,明确标注为 DEPRECATED,**不推荐新项目使用**。维护者已转向 OpenTelemetry。
- 核心目标：标准化追踪 API，解耦应用代码与具体追踪后端。

在分布式系统的可观测性（Observability）中，Tracing(追踪)、Logging(日志)、Metrics(指标)是三大核心支柱，它们相互补充，共同帮助开发者理解系统行为、诊断问题并优化性能。

- Tracing 是"纵向"分析（单个请求的生命周期）,Metrics 是"横向"统计（系统整体状态）,Logging 是"点状"记录（关键事件快照）。
- 三者结合能构建完整的可观测性体系:Metrics 告诉你"有问题" → Tracing 告诉你"哪里有问题" → Logging 告诉你"为什么有问题"。

## 参考

- [小白视角：一文读懂社长的 TinyWebServer](https://huixxi.github.io/2020/06/02/%E5%B0%8F%E7%99%BD%E8%A7%86%E8%A7%92%EF%BC%9A%E4%B8%80%E6%96%87%E8%AF%BB%E6%87%82%E7%A4%BE%E9%95%BF%E7%9A%84TinyWebServer/#more)
- [OpenTelemetry 官方文档](https://opentelemetry.io/docs/)
- [CNCF Projects - OpenTelemetry](https://www.cncf.io/projects/)
- [Proxygen README](https://github.com/facebook/proxygen/blob/main/README.md)