+++
title = "K8s 服务网格配置发现协议"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "MCP 与 xDS：服务网格控制面的配置分发协议"
description = "梳理 Istio 服务网格中用于配置分发的两类协议——基于订阅的 MCP（已废弃）和 Envoy 原生的 xDS 协议族，介绍其 source/sink 模型、ACK/NACK 机制与 v3 资源类型。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "service-mesh", "istio", "envoy", "xds", "mcp"]
keywords = ["服务网格", "MCP 协议", "xDS 协议", "Istio", "Envoy", "配置发现"]
toc = true
draft = false
+++

在服务网格场景下，控制面需要把监听器、路由、集群、端点、证书等配置高效、一致地下发到数据面（每个 sidecar 代理）。本文梳理 Istio 历史上使用过的两类配置分发协议：基于订阅的 **MCP** 与 Envoy 原生的 **xDS**。

> ⚠️ **重要说明**：MCP（Mesh Configuration Protocol）已被 Istio 官方废弃，[istio/api 仓库的 MCP 目录](https://github.com/istio/api/tree/master/mcp) README 明确写道："a now-deprecated configuration subscription API ... XDS is now used"，仓库中仅保留了少量兼容性 stub。当前 Istio 的配置下发已全面转向 xDS。本文仍保留 MCP 的描述，便于读者理解历史背景与设计思路。

## MCP

MCP（Mesh Configuration Protocol，网格配置协议）是基于订阅的配置分发 API，核心要点如下：

- 配置消费者（sink）向配置生产者（source）请求订阅某一类资源的更新；当资源被新增、更新或删除时，source 会把变更推送到 sink。
- sink 需要对每一条资源更新做显式确认：接受则返回 ACK，拒绝则返回 NACK（典型场景是资源配置非法、校验失败）。
- 只有在上一条更新被 ACK 或 NACK 之后，source 才会推送下一条更新；对每个资源集合，source 同时只允许有一个未完成的更新在途。
- MCP 由一对双向流 gRPC 服务组成：`ResourceSource` 与 `ResourceSink`，分别对应 source 主动推送和 sink 主动拉取两种模式。

MCP 的设计目标是把「配置生产者」与「配置消费者」解耦——例如 Galley 作为 source，Pilot、Citadel 等组件作为 sink。随着 Istio 1.5 把 Galley 合并进 Istiod，这套独立的双流协议被更直接的 xDS 通道取代。

## xDS

xDS（x Discovery Service）是 Envoy 代理用来从控制面获取动态配置的一组 gRPC/REST API 的统称，涵盖 REST 与 gRPC 两种传输方式。Envoy 通过文件系统，或向一台/多台管理服务器（management server）查询，来发现其各类动态资源。这些发现服务及其对应的 API 统称为 xDS。

订阅某类资源时，Envoy 可以通过三种方式发起请求：

1. **文件系统订阅**：指定要监视的文件系统路径；
2. **gRPC 流订阅**：启动一条 gRPC 双向流；
3. **REST-JSON 轮询**：周期性地向 REST-JSON URL 发起请求。

后两种方式都会发送一个携带 `DiscoveryRequest` proto 有效负载的请求，而所有方式最终都通过 `DiscoveryResponse` proto 有效负载把资源下发给 Envoy。

xDS API 中的每一类配置资源都有与之关联的资源类型，资源类型遵循统一的版本控制方案，且该版本与上述传输方式无关。

v3 版本支持的 xDS 资源类型如下（完整 type URL 形如 `type.googleapis.com/<resource>`）：

| 资源类型 | 说明 |
| --- | --- |
| `envoy.config.listener.v3.Listener` | 监听器（LDS） |
| `envoy.config.route.v3.RouteConfiguration` | HTTP 路由表（RDS） |
| `envoy.config.route.v3.ScopedRouteConfiguration` | 按作用域划分的路由（SRDS） |
| `envoy.config.route.v3.VirtualHost` | 虚拟主机（VHDS，仅增量模式） |
| `envoy.config.cluster.v3.Cluster` | 上游集群（CDS） |
| `envoy.config.endpoint.v3.ClusterLoadAssignment` | 集群成员/端点（EDS） |
| `envoy.extensions.transport_sockets.tls.v3.Secret` | TLS 证书与密钥（SDS） |
| `envoy.service.runtime.v3.Runtime` | 运行时配置（RTDS） |

> 注：v2 API 已废弃，生产环境应统一使用 v3。

## mcp-over-xds

社区曾探索「MCP over xDS」的设计思路：在 xDS（尤其是 Delta xDS）传输层之上承载 MCP 风格的资源，从而用一套协议同时服务控制面内部与控制面到数据面的配置分发，减少协议表面、复用 xDS 的增量与版本能力。详细设计见文末参考文档。随着 MCP 整体被废弃，这条演进路线也已并入原生 xDS。

## 参考

- [Istio MCP 协议源码（已废弃，仅保留 stub）](https://github.com/istio/api/tree/master/mcp)
- [MCP 协议讲解](https://rocdu.gitbook.io/deep-understanding-of-istio/7/1)
- [mcp-over-xds 讲解](https://rocdu.gitbook.io/deep-understanding-of-istio/7/4)
- [Istio 与 MCP Server 讲解与搭建演示](https://xie.infoq.cn/article/d6fda55bca526128a5bce617f)
- [MCP-over-xDS 设计文档（Google Doc）](https://docs.google.com/document/d/1lHjUzDY-4hxElWN7g6pz-_Ws7yIPt62tmX3iGs_uLyI/edit)
- [Pilot MCP 协议介绍（Nacos）](https://nacos.io/en-us/blog/pilot%20mcp.html)
- [Service Mesh 基础：Envoy 入门介绍与 xDS 协议](https://dun.163.com/news/p/eb1a80e497f14947b033f17b53e8869e)
- [xDS 概述（learning-xds）](https://skyao.io/learning-xds/docs/introduction/overview.html)
- [Envoy 官方 xDS 协议文档](https://www.envoyproxy.io/docs/envoy/latest/api-docs/xds_protocol)
