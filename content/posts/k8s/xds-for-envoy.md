+++
title = "Envoy xDS 协议介绍"
date = "2025-03-24"
lastmod = "2025-03-24"
subtitle = "Envoy 动态配置的 xDS 协议族、传输模式与控制面实现"
description = "梳理 Envoy xDS 协议族（LDS/RDS/CDS/EDS/SDS）与 SotW、Incremental、ADS 等传输模式，并以 Istio Pilot、Higress、go-control-plane 为例介绍控制面实现。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "envoy", "xds", "istio", "service-mesh", "higress"]
keywords = ["Envoy xDS", "xDS 协议", "LDS RDS CDS EDS", "ADS", "Istio Pilot", "go-control-plane"]
toc = true
draft = false
+++

xDS（Extensible Discovery Service，可扩展发现服务）是 Envoy 代理用来从控制面（Control Plane）获取动态配置的一组 gRPC/REST API 的统称。这里的 "x" 代表具体的资源类型，例如 Listener、Route、Cluster、Endpoint，分别对应 LDS、RDS、CDS、EDS。借助 xDS，Envoy 能够在不停机、不 reload 的情况下热更新监听器、路由表、上游集群、证书等几乎所有运行期配置，这正是 Istio、Higress 等服务网格与云原生网关实现毫秒级配置生效的底层基础。

本文先梳理 xDS 协议族的资源类型与传输模式，再以 Istio Pilot、Higress 以及 Envoy 官方的 go-control-plane 为例，介绍控制面的工程实现。

## xDS 协议族：从 LDS 到 SDS

Envoy 的每一类可动态下发的资源都对应一个 Discovery Service，组成 xDS 协议族。按照 [Envoy 官方文档](https://www.envoyproxy.io/docs/envoy/latest/api-docs/xds_protocol)的定义，v3 版本下的主要资源类型包括：

| 缩写 | 全称 | 对应资源（type URL） | 作用 |
| --- | --- | --- | --- |
| LDS | Listener Discovery Service | `envoy.config.listener.v3.Listener` | 下发监听器，决定 Envoy 如何接收下游连接 |
| RDS | Route Discovery Service | `envoy.config.route.v3.RouteConfiguration` | 下发 HTTP 路由表 |
| SRDS | Scoped Route Discovery Service | `ScopedRouteConfiguration` | 按作用域划分的路由（多租户场景） |
| VHDS | Virtual Host Discovery Service | `VirtualHost` | 增量下发虚拟主机（仅 Incremental） |
| CDS | Cluster Discovery Service | `envoy.config.cluster.v3.Cluster` | 下发上游集群定义 |
| EDS | Endpoint Discovery Service | `envoy.config.endpoint.v3.ClusterLoadAssignment` | 下发集群成员（具体的 Pod/IP） |
| SDS | Secret Discovery Service | `envoy.extensions.transport_sockets.tls.v3.Secret` | 下发 TLS 证书与密钥 |
| RTDS | Runtime Discovery Service | `envoy.service.runtime.v3.Runtime` | 下发运行时配置（特性开关等） |

资源类型用 type URL 区分，形如 `type.googleapis.com/envoy.config.<resource>.v3.<Resource>`。需要注意的是，v2 API 已经废弃，目前生产环境使用的都是 v3。

## 传输模式：SotW、Incremental 与 ADS

xDS 在传输层有「全量 vs 增量」和「分流 vs 聚合」两个正交维度，组合出四种 gRPC 模式，再加上 REST-JSON 轮询，覆盖了所有使用场景。

### State of the World（SotW）

最原始的「全量」模式：服务端每次都把当前订阅的所有资源完整下发，无论这些资源是否发生了变化。实现简单、易于调试，但在大规模网格下会造成明显的带宽与 CPU 浪费。

### Incremental xDS（Delta xDS）

增量模式下，服务端只下发「发生变化」的资源，并通过 `removed_resources` 字段通知客户端哪些资源被删除。请求侧用 `initial_resource_versions`、`resource_names_subscribe`、`resource_names_unsubscribe` 表达订阅意图。Delta 模式支持资源级版本、按需订阅，在大规模或频繁变更的场景下效率显著优于 SotW。Istio 从 1.22 版本开始将 Incremental xDS 作为默认推送方式。

### Aggregated Discovery Service（ADS）

ADS（聚合发现服务）将所有资源类型复用在**同一条 gRPC 双向流**上，仍然用 type URL 区分不同子流。聚合的意义在于：可以对多种资源的下发顺序进行编排，避免 Envoy 在收到 CDS 还没收到对应 EDS 时短暂丢流量。每个 Envoy 实例通常只建立一条 ADS 流，bootstrap 配置形如：

```yaml
dynamic_resources:
  cds_config: { ads: {} }
  lds_config: { ads: {} }
```

把「全量/增量」与「分流/聚合」组合，就得到四种 gRPC 变体：SotW、Incremental xDS、ADS（SotW 聚合）、Incremental ADS。需要强调的是，ADS 只在 gRPC 下可用，REST-JSON 不支持聚合。

### REST-JSON 轮询

非流式订阅方式，Envoy 通过 HTTP 长轮询（long polling）向管理服务器拉取配置，body 是 JSON 编码的 proto3 消息。适合无 gRPC 支持或调试场景，生产环境一般不推荐。

## 版本号、Nonce 与 ACK/NACK

xDS 通过 `version_info` 和 `nonce` 两个字段实现配置的可靠投递与确认：

- **version_info**：每个资源类型在客户端持有的版本号。服务端在 `DiscoveryResponse` 中下发新版本，客户端在下一次 `DiscoveryRequest` 中回传该版本，表示「我已经应用了这个版本」。
- **nonce**：每次响应的唯一标识，客户端的后续请求必须把 `response_nonce` 设置为最近一次收到的 nonce，以便服务端判断 ACK/NACK 对应的是哪一次响应。nonce 仅在当前流内有效，重连后会失效。
- **ACK**：客户端成功应用某次响应后，回发的请求中 `version_info` 等于服务端版本，且不带 `error_detail`。注意 ACK 仅表示资源本身校验通过，并不保证一定生效。
- **NACK**：如果资源非法，客户端在请求中填入 `error_detail` 字段，并把 `version_info` 回退到上一个正常版本，服务端据此判断被拒绝。

这套机制配合 ADS 的顺序保证，构成了 Envoy 数据面与控制面之间的「事务性」配置同步语义。

## xDS 的控制面实现

理解了协议，再来看业界典型的实现方式。

### Istio Pilot / Istiod

最典型的 xDS Server 实现就是 Istio 的控制面。早期 Istio 把 Pilot 拆成 pilot-discovery 和 pilot-agent 等多个二进制，从 1.5 起合并为统一的 `istiod`，但内部仍保留了 Pilot-Discovery 的结构。[Pilot 代码深度解析](https://www.zhaohuabing.com/post/2019-10-21-pilot-discovery-code-analysis/) 一文将其拆为三个子系统：

- **Config Controller**：管理 VirtualService、DestinationRule、Gateway 等 CRD 配置，支持 Kubernetes、MCP、Memory 等多种来源；
- **Service Controller**：管理服务注册表，来源可以是 Kubernetes、Consul、MCP 等；
- **Discovery Service**：运行 gRPC server，把上述配置转换为 xDS 结构后推送给 Envoy。

控制面的核心难点是「变更传播」。当服务或配置发生变化时，`ConfigUpdate` 回调会把 `PushRequest` 投递到一个 push channel，Pilot 用一套**debounce（去抖）机制**——同时设置最大延迟（max delay）和静默时间阈值（quiet time）——把短时间内的多次变更合并成一次推送，避免在频繁变更时把数据面打挂。客户端侧则通过 `StreamAggregatedResources`（ADS）双向流主动发起 `DiscoveryRequest`。

关于 Pilot 的更深入源码分析，可参考 [Istio Pilot 代码深度解析](https://www.zhaohuabing.com/post/2019-10-21-pilot-discovery-code-analysis/)。

### 关于 MCP 协议

为了把 Istio 与 Kubernetes 解耦——让非 K8s 环境也能向控制面推送配置——Istio 早期设计了 [MCP（Mesh Configuration Protocol）](https://docs.google.com/document/d/1o2-V4TLJ8fJACXdlsnxKxDv2Luryo48bAhR8ShxE5-k/edit?tab=t.0)。MCP 是一套基于 xDS 思路的「配置分发 API」，配置生产者（source）按集合（collection）订阅式地把资源配置推送给配置消费者（sink），同样使用 ACK/NACK 进行确认。

随着社区演进，Istio 开始用「xDS over xDS」（即 mcp-over-xds）的方式替代独立的 MCP 协议，MCP 在主线版本中逐步被弃用。但在 Higress 这类生态中，MCP 仍然作为一种实用的配置源协议存在。

### Higress：同时实现 xDS 和 MCP

[Higress](https://github.com/alibaba/higress) 是阿里开源的云原生 API 网关，构建在 Envoy 与 Istio 之上。它的控制面 Higress Controller 同时实现了 xDS 与 MCP 两种协议，整体分为 Discovery 与 Higress Core 两个子组件：

- **Discovery** 本质上就是 Istio Pilot-Discovery，负责把 Kubernetes Service、Gateway API 等配置转换成 Istio 模型，再以 xDS 形式下发给数据面的 Envoy。Discovery 内部用 Config Controller 抽象出四种配置源：**Kubernetes**（CRD）、**MCP**、**Memory**、**File**，配置源地址在 `higress-config` ConfigMap 的 `configSources` 中声明，例如 `xds://127.0.0.1:15051` 或 `k8s://`。
- **Higress Core** 则实现了 MCP 协议，作为 Discovery 的一个配置源。它内部包含六个控制器：Ingress、Gateway、McpBridge、Http2Rpc、WasmPlugin、ConfigmapMgr，分别负责把 Ingress、Gateway API、外部注册中心（Nacos/Eureka/Consul/Zookeeper/DNS）、HTTP-RPC 转换、Wasm 插件、全局配置等转换为 Istio CRD，再经由 MCP 喂给 Discovery。

数据面的 Higress Gateway 由 Pilot Agent 和 Envoy 组成，Pilot Agent 负责启动 Envoy 并通过 Unix Domain Socket 代理 xDS 请求。整个链路串联起来，外部注册中心的服务可以一路转换到 Istio CRD，再到 xDS，最终在 Envoy 上以 Listener / Router / Cluster / Endpoint 的形式生效。Higress 架构详见 [Higress 核心组件和原理](https://github.com/alibaba/higress/blob/main/docs/architecture.md)。

### go-control-plane：自己动手写一个 xDS Server

如果想亲手实现一个最小的 xDS Server，Envoy 官方维护的 [go-control-plane](https://github.com/envoyproxy/go-control-plane) 是最方便的起点。它本身不是完整的控制面，而是「实现控制面的公共基础设施」，提供三种缓存：

- **SnapshotCache**：基于快照的缓存，按 node id 维护一组一致的资源视图，支持 ADS 模式下的原子更新；
- **LinearCache**：针对单一 type URL 的最终一致缓存，只返回有变更的资源；
- **MuxCache**：缓存组合器，可以针对不同 type URL 混用不同缓存。

社区里一个不错的练手项目是 [my-xds](https://github.com/xujiyou/my-xds)，它用 go-control-plane 实现了一个类似 Istio Pilot 的最小 xDS Server，关键的几行代码大致是：

```go
// 用一组 cluster/listener 资源构造一个快照
snapshot, err := cache.NewSnapshot(
    version,
    map[string]types.Resource{
        resource.ClusterType:  clusters,
        resource.ListenerType: listeners,
    },
)
// 按 node id 写入 SnapshotCache，ADS 推流时会自动拿到
snapshotCache.SetSnapshot(context.Background(), "node1", snapshot)
```

服务端同时监听一个 gRPC 端口（示例中是 `9002`）和一个 HTTP Gateway 端口（`9001`），后者提供 REST 风格的发现接口（如 `POST /v2/discovery:clusters`）。生产场景下，snapshot 里的资源会从 Kubernetes API Server、配置中心或注册中心动态拉取，正如 Istio 所做的那样。

## 小结

xDS 是 Envoy 能够实现「配置即数据」的关键——所有运行期行为都抽象成可热下发的资源，由控制面集中管理。理解 xDS 时，可以从三个层次入手：

1. **资源类型层**：LDS / RDS / CDS / EDS / SDS 分别下发哪一类配置；
2. **传输层**：SotW、Incremental、ADS、REST-JSON 各自的取舍，以及 `version_info` / `nonce` / ACK / NACK 的可靠性语义；
3. **实现层**：Istio Pilot/ Istiod、Higress、go-control-plane 这些项目是如何把协议落到工程里的。

掌握了这套协议族，无论是阅读 Istio 源码、二次开发服务网格，还是自研一个基于 Envoy 的网关控制面，都会顺畅很多。

## 参考

- [Envoy xDS Protocol 官方文档](https://www.envoyproxy.io/docs/envoy/latest/api-docs/xds_protocol)
- [envoyproxy/go-control-plane（Go 实现）](https://github.com/envoyproxy/go-control-plane)
- [Envoy XDS 及 Istio 中的配置分发流程介绍（Jimmy Song）](https://jimmysong.io/blog/istio-delta-xds-for-envoy/)
- [Istio Pilot 代码深度解析（赵华兵）](https://www.zhaohuabing.com/post/2019-10-21-pilot-discovery-code-analysis/)
- [Higress 核心组件和原理](https://github.com/alibaba/higress/blob/main/docs/architecture.md)
- [my-xds：自己实现一个 Envoy xDS Server](https://github.com/xujiyou/my-xds)
- [MCP（Mesh Configuration Protocol）设计文档](https://docs.google.com/document/d/1o2-V4TLJ8fJACXdlsnxKxDv2Luryo48bAhR8ShxE5-k/edit?tab=t.0)
