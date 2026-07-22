+++
title = "trpc/brpc/grpc 协议设计对比"
date = "2025-07-09"
lastmod = "2025-07-09"
subtitle = "三大国产与国际 RPC 框架的协议帧与通信模式解析"
description = "对比腾讯 tRPC、Apache bRPC(baidu_std)与 gRPC 的协议帧格式、流式通信实现与传输层选型,梳理各自设计取舍。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "trpc", "brpc", "grpc", "rpc", "协议设计", "protobuf"]
keywords = ["trpc", "brpc", "grpc", "baidu_std", "RPC 协议设计", "HTTP/2"]
toc = true
draft = false
+++

在微服务与高性能后端场景中，RPC(Remote Procedure Call，远程过程调用)框架的协议设计直接决定了吞吐、延迟、可观测性和生态兼容性。本文梳理三套具有代表性的 RPC 协议：腾讯开源的 **tRPC**、Apache **bRPC**(baidu_std)以及 Google 主导的 **gRPC**,从协议帧格式、通信模式和传输层三个维度做对比。

三者的共同点是都使用 **Protocol Buffers** 作为默认的 IDL(Interface Definition Language，接口定义语言)与序列化格式，差异主要体现在传输层选型和帧结构设计上。

## tRPC

tRPC 是腾讯基于多年大规模分布式服务实践开源的多语言 RPC 框架，仓库位于 [trpc-group/trpc](https://github.com/trpc-group/trpc),支持 C++、Go、Java、Python 等多种语言。需要注意，它与 TypeScript 社区中同名的 `@trpc/server`(一个端到端类型安全的 API 层)是完全不同的项目。

### 设计目标与传输层选型

根据官方《tRPC 协议设计》文档，tRPC 在协议层**没有选择 HTTP/HTTP2**,主要是出于性能考虑。其协议设计目标包括：前向兼容、高性能、可扩展，以及支持超时、多种序列化与压缩格式、链路追踪、消息染色（用于灰度与压测流量识别）、自定义元数据透传等能力。

协议分两层:**传输层（自定义协议头）** 和 **编码层（协议体，默认 Protobuf，可扩展）**。

### 16 字节固定帧头

每个 tRPC 数据帧都以一个固定的 16 字节头部开始:

| 偏移（字节） | 长度 | 字段 | 说明 |
|---|---|---|---|
| 1–2 | 2B | 魔数 | `0x0930`,标识 tRPC 帧起始 |
| 3 | 1B | 数据帧类型 | `0x00` = Unary,`0x01` = Streaming |
| 4 | 1B | 流帧类型 | `0x00`=Unary,`0x01`=Init,`0x02`=Data,`0x03`=Feedback,`0x04`=Close |
| 5–8 | 4B | 总数据长度 | Unary:帧头+包头部+包体;Stream:帧头+流帧 |
| 9–10 | 2B | 包头长度 | 仅 Unary 有效，流式恒为 0 |
| 11–14 | 4B | 请求 ID / 流 ID | Unary 为 request_id,Stream 为 stream_id |
| 15–16 | 2B | 保留 | 预留扩展 |

魔数 `0x0930` 跨两个字节存储，大端序读取。

### Unary 与 Streaming 两种模式

**Unary RPC** 的完整帧 = 固定头（16B）+ 变长请求/响应包头 + 变长包体。请求头(`RequestProtocol`)的关键字段包括:

- `version`:协议版本
- `call_type`:调用类型（unary、one-way 等）
- `request_id`:连接内唯一标识
- `timeout`:超时时间（毫秒）
- `caller` / `callee`:形如 `trpc.{app}.{server}.{service}` 的调用方/被调方标识
- `message_type`:标记 tracing、染色、灰度、鉴权等
- `trans_info`:`map<string, bytes>` 元数据透传，框架字段前缀 `trpc-`,业务字段前缀 `app-`
- `content_type` / `content_encoding`:序列化与压缩格式

响应头额外携带 `ret`(框架级错误码，见 `TrpcRetCode`)、`func_ret`(业务级错误码，0 表示成功)、`error_msg`。

**Streaming RPC** 通过固定头 + 流帧的方式承载，流帧分四种:

- **Init Frame**(`TrpcStreamInitMeta`):携带 `init_window_size` 流控窗口，完成握手。
- **Data Frame**:序列化后的业务消息体。
- **Feedback Frame**(`TrpcStreamFeedBackMeta`):通过 `window_size_increment` 反馈窗口增量，实现流控。
- **Close Frame**:分为 `TRPC_STREAM_CLOSE`(正常单向关闭)和 `TRPC_STREAM_RESET`(双向异常重置)。

在 `.proto` 文件中通过 `stream` 关键字声明服务端流、客户端流、双向流三种模式。

### 参考文档

- [tRPC 协议设计（官方）](https://github.com/trpc-group/trpc/blob/main/docs/zh/trpc_protocol_design.md)
- [trpc.proto 定义](https://github.com/trpc-group/trpc/blob/main/trpc/trpc.proto)

## gRPC

gRPC 是 Google 开源、基于 **HTTP/2** 的跨语言 RPC 框架，也是 CNCF 生态中事实标准之一。其协议规范见 [PROTOCOL-HTTP2.md](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md)。

### 四种通信模式

gRPC 通过 HTTP/2 的流（stream）抽象提供四种调用语义:

- **Unary RPC**:单一请求对应单一响应，语义最接近传统 HTTP 请求。
- **Server Streaming**:客户端发一个请求，服务端通过同一 HTTP/2 流返回多个响应。
- **Client Streaming**:客户端通过同一流发送多个请求，服务端汇总后返回一个响应。
- **Bidirectional Streaming**:全双工，双方可异步收发消息，依赖 HTTP/2 的流控机制。

### Length-Prefixed-Message 框架

gRPC 在 HTTP/2 DATA 帧内，用统一的 **Length-Prefixed-Message** 格式承载每条业务消息:

```
Compressed-Flag  Message-Length  Message
   1 byte          4 bytes BE     N bytes
```

- **Compressed-Flag**:1 字节无符号整数,`1` 表示按 Message-Encoding 压缩,`0` 表示未压缩。
- **Message-Length**:4 字节大端序无符号整数，表示后续消息体长度。
- **Message**:原始二进制 octets。

值得注意的两点：一是 **DATA 帧边界与 Length-Prefixed-Message 边界无任何对齐关系**,实现层不能按 HTTP/2 frame 切分消息;二是压缩上下文不跨消息边界，每条消息都使用独立的压缩上下文。

### 状态码与元数据

- 状态信息放在 **Trailers**(响应尾部 HEADERS 帧)中,`grpc-status` 为十进制 ASCII 数字，即使成功也必须发送。
- 路径格式严格为 `/{Service-Name}/{method}`,大小写敏感。
- `Content-Type` 必须以 `application/grpc` 开头(Protobuf 默认是 `application/grpc+proto`),否则服务端应返回 HTTP 415。
- 二进制元数据通过以 `-bin` 结尾的 header 名标识，值采用 Base64 编码。
- 超时通过 `grpc-timeout` header 表示，格式为「最多 8 位正整数 + 单位字符」(`H`/`M`/`S`/`m`/`u`/`n`)。

### 传输层要点

gRPC 强依赖 HTTP/2 的多路复用、头部压缩（HPACK）、流控等能力，使用 TLS 时要求 TLS 1.2 及以上。连接管理通过 `GOAWAY`(服务端不再接受新流)与 `PING`(活性探测与延迟估算)实现。HTTP/2 错误码到 gRPC 状态码有完整映射，例如 `REFUSED_STREAM → UNAVAILABLE`、`CANCEL → CANCELLED`。

### 参考文档

- [gRPC over HTTP/2 规范](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md)
- [HTTP/2 协议规范（RFC 9113）](https://httpwg.org/specs/rfc9113.html)

## bRPC

bRPC 是百度开源、以 C++ 编写的工业级 RPC 框架，现已捐赠给 Apache 软件基金会，仓库为 [apache/brpc](https://github.com/apache/brpc)。其名称含义为 "better RPC",常用于搜索、存储、机器学习、广告、推荐等对延迟敏感的系统。

### baidu_std 协议帧

baidu_std 是基于 TCP 的二进制 RPC 协议，以 Protobuf 作为数据交换格式，使用 Protobuf 内置的 RPC Service 机制完成调用。每条消息由 **12 字节固定头** + **body** 组成，body 又细分为 **metadata / data / attachment** 三段。

固定头结构如下:

| 偏移 | 长度 | 字段 | 说明 |
|---|---|---|---|
| 0–3 | 4B | 协议标识 | ASCII `PRPC` |
| 4–7 | 4B | body 总长度（不含 12B 头） | 大端序 |
| 8–11 | 4B | metadata 长度 | 大端序 |

**RpcMeta**(metadata 段)是一个 Protobuf 消息，核心字段:

```protobuf
message RpcMeta {
    optional RpcRequestMeta  request = 1;
    optional RpcResponseMeta response = 2;
    optional int32  compress_type    = 3;
    optional int64  correlation_id   = 4;
    optional int32  attachment_size  = 5;
    optional ChunkInfo chuck_info    = 6;
    optional bytes  authentication_data = 7;
}
```

- 请求包只填 `request`,响应包只填 `response`,实现侧通过字段是否存在区分包类型。
- `correlation_id` 由请求方设置，响应方原样回填，用于在连接内匹配请求与响应。
- `compress_type` 支持 0(无压缩)、1(Snappy)、2(gzip)。
- **attachment** 段用于承载不适合塞进 Protobuf 的大块二进制数据（如文件上传、转码流）,大小由 `attachment_size` 标识，位于 body 末尾。

服务名必须为 UpperCamelCase，长度不超过 64;方法名允许字母、数字、下划线，同样不超过 64。

### Streaming RPC

bRPC 的流式 RPC(见 [streaming_rpc.md](https://github.com/apache/brpc/blob/master/docs/cn/streaming_rpc.md))是为了解决两个问题：并行多段 RPC 之间的乱序问题，以及串行 RPC 的累积延迟问题。其设计类似 **用户态的 socket**:

- **Stream** 是建立在单条 TCP 连接上的用户态虚连，可多路复用（一个 TCP 上可有多个 Stream）,由 `StreamId` 唯一标识。
- 生命周期：客户端 `StreamCreate()` → 通过一次 RPC 协商（服务端可拒绝）→ 服务端 `StreamAccept()` 完成建立。这与 POSIX socket 的 `connect`/`accept` 模型一致。
- 通信是**全双工**的，任意一端都可写;消息按发送顺序严格到达，保留消息边界。
- 流控:`max_buf_size`(默认 2MB)限制对端未消费数据量，超限后 `StreamWrite()` 返回 `EAGAIN`,可通过同步/异步 `StreamWait()` 等待。

`StreamInputHandler` 回调包括 `on_received_messages`(批量消息到达，默认每批最多 128 条)、`on_idle_timeout`(超过 `idle_timeout_ms` 无活动)、`on_closed`。大消息会被自动切分以避免队头阻塞。

注意:Streaming RPC 必须建立在 `baidu_std` 协议之上;若对端是较老的服务端（不支持 streaming）,握手会直接失败。

### 参考文档

- [baidu_std 协议](https://github.com/apache/brpc/blob/master/docs/cn/baidu_std.md)
- [Wireshark 抓包解析 baidu_std](https://github.com/apache/brpc/blob/master/docs/cn/wireshark_baidu_std.md)
- [Streaming RPC 设计](https://github.com/apache/brpc/blob/master/docs/cn/streaming_rpc.md)
- [bRPC 发展历史](https://gist.github.com/baymaxium/fe6b83bab082d3f640fd12f9c610cdf0)

## 三者横向对比

| 维度 | tRPC | gRPC | bRPC |
|---|---|---|---|
| 传输层 | 自定义二进制帧（基于 TCP） | HTTP/2 | TCP(baidu_std) |
| 固定头 | 16 字节，魔数 `0x0930` | 依赖 HTTP/2 帧 + Length-Prefixed-Message | 12 字节，标识 `PRPC` |
| IDL | Protobuf | Protobuf(默认) | Protobuf |
| 通信模式 | Unary / Streaming(Init/Data/Feedback/Close) | Unary / Server / Client / Bidirectional Streaming | 请求-响应 + 全双工 Stream |
| 流控 | Feedback 帧的 `window_size_increment` | HTTP/2 流控 + WINDOW_UPDATE | `max_buf_size` + `EAGAIN` |
| 主要语言 | C++ / Go / Java / Python | 跨语言 | C++ 为主 |
| 生态背景 | 腾讯大规模实践 | Google / CNCF | 百度 / Apache |

设计取舍上看,**gRPC** 以 HTTP/2 为代价换来了极强的生态兼容（网关、代理、浏览器、跨语言工具链）,**tRPC** 与 **baidu_std** 则通过自定义二进制帧减少了 HTTP/2 的解析与帧开销，在延迟敏感的内部场景换取更高的吞吐。理解这三种协议的帧结构和流式语义，是排查线上 RPC 问题、做协议互通或自研网关的基础。
