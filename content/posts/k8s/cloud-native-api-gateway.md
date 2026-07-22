+++
title = "云原生 API 网关"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从 Nginx 到 Envoy,主流云原生 API 网关的内核与选型"
description = "梳理云原生 API 网关的两条技术主线 —— 基于 Nginx 的 Apache APISIX、Kong、蓝鲸 API 网关,以及基于 Envoy/Istio 的 Higress,对比其架构、插件机制与适用场景。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "api-gateway", "nginx", "envoy", "apisix", "higress", "istio"]
keywords = ["云原生 API 网关", "Apache APISIX", "Higress", "Envoy", "Kong", "Wasm 插件"]
toc = true
draft = false
+++

在 Kubernetes 与微服务架构中，API 网关（API Gateway）是南北向流量的统一入口，承担路由、认证、限流、可观测、协议转换等职责。与 Kubernetes 原生的 `Ingress` 相比，API 网关通常提供更丰富的流量治理能力;而随着 [Gateway API](https://gateway-api.sigs.k8s.io/) 成为 Ingress 的继任者，网关也越来越多地以 `GatewayClass` 实现的身份接入集群。

市面上主流的云原生 API 网关，按数据面（Data Plane）的内核可以大致归为两条技术主线:

- **基于 Nginx** —— 以 Apache APISIX、Kong、蓝鲸 API 网关为代表，通过 OpenResty/Lua 在 Nginx 之上扩展出动态配置与插件机制;
- **基于 Envoy** —— 以阿里 Higress、Envoy Gateway 为代表，直接使用 Envoy 作为数据面，借助 xDS 实现毫秒级配置生效。

下文按这两条主线展开，分别介绍代表项目及其架构特征。

## 基于 Nginx 的网关

Nginx 本身就是一个高性能的 HTTP/反向代理服务器，事件驱动、单机 QPS 极高。但原生的 Nginx 路由配置是静态文件，修改后需要 `reload` 才能生效，这在需要频繁变更路由的云原生场景下并不友好。围绕这一痛点，社区演化出了多种「让 Nginx 动起来」的方案，典型做法是用 [OpenResty](https://openresty.org/) 在 Nginx 中嵌入 Lua 运行时，再外挂一个配置中心，把路由与插件元数据下沉为运行期可热加载的结构。

### Apache APISIX

[Apache APISIX](https://github.com/apache/apisix) 是 Apache 软件基金会顶级的云原生 API 网关，定位是「云原生 API 与 AI 网关」。它以 Nginx 为底层、以 [etcd](https://etcd.io/) 作为配置中心，核心逻辑用 Lua 编写。

APISIX 的架构同样遵循控制面/数据面分离:

- **控制面** 通过 Admin API(默认端口 `9180`)接收路由、上游、插件、证书等配置，并写入 etcd;
- **数据面** 由一组无状态的 APISIX 节点组成(代理端口默认 `9080`),它们从 etcd 订阅配置并在内存中生效，因此水平扩展时无需共享本地状态。

由于配置变更走 etcd watch 机制，APISIX 能够做到路由与插件的热更新——官方强调「无需重启即可持续更新配置与插件」。在协议层面，APISIX 支持 HTTP/HTTPS、TCP/UDP 代理、gRPC 与 gRPC transcoding、WebSocket、Dubbo、MQTT，以及基于 QUIC 的 HTTP/3;认证侧内置 key-auth、JWT、basic-auth、OIDC、Casbin 等多种策略。根据官方基准测试，在 AWS 8 核机器上 APISIX 的 QPS 可达 14 万，平均延迟约 0.2 ms。值得一提的是，APISIX 也提供多语言插件能力：除 Lua 外，还支持通过 RPC 编写 Java/Go/Python/Node.js 插件，或通过 Proxy-Wasm 用任意支持 Wasm SDK 的语言扩展。

### Kong

[Kong](https://github.com/Kong/kong) 是另一款历史悠久的开源 API 网关，同样构建在 OpenResty(即 Nginx + Lua)之上。Kong 以插件生态闻名，Plugin Hub 提供认证、限流、请求/响应转换、日志、监控等几十类插件，可通过 Lua、Go、JavaScript 编写自定义插件。

在部署形态上，Kong 支持三种模式:

- **传统数据库模式**:以 PostgreSQL 作为配置存储，Admin API 默认端口 `8001`,代理端口 `8000`,管理 UI(Kong Manager)端口 `8002`;
- **DB-less 声明式模式**:以本地 YAML 文件作为唯一配置来源，适合 Kubernetes 与 GitOps;
- **Hybrid 模式**:控制面与数据面分离，数据面节点不再直接访问数据库，从而适合多集群与跨网部署。

### 蓝鲸 API 网关（blueking-apigateway）

[蓝鲸 API 网关](https://github.com/TencentBlueKing/blueking-apigateway)是腾讯蓝鲸出品的高性能 API 托管服务，帮助企业以低成本、低风险的方式对内对外开放 API。它同样采用了控制面/数据面分离的架构，数据面基于 Apache APISIX 二次开发，通过一系列自研插件支持蓝鲸特有的鉴权、监控、发布等特性，从而继承 APISIX 动态、实时、高性能的特点。

蓝鲸 API 网关的核心子项目分布在多个仓库中:

- **蓝鲸 API 网关 - 控制面**([blueking-apigateway](https://github.com/TencentBlueKing/blueking-apigateway))
  - `dashboard`:控制面后端，提供 API 的配置、发布、监控、权限管理;
  - `dashboard-front`:控制面前端;
  - `core-api`:网关高性能核心 API;
  - `esb`:ESB(Enterprise Service Bus)组件服务;
  - `operator`:负责把网关配置转换并下发到数据面;
  - `mcp-proxy`:面向 MCP(Model Context Protocol)场景的代理服务。
- **蓝鲸 API 网关 - 数据面**([blueking-apigateway-apisix](https://github.com/TencentBlueKing/blueking-apigateway-apisix)):真正承担流量转发与安全防护的 APISIX 扩展版本。

功能层面，蓝鲸 API 网关提供完整的 API 生命周期管理、多环境（开发/测试/生产）发布、在线文档与客户端 SDK、蓝鲸应用与用户双重鉴权、IP 黑白名单、秒级限流、操作审计，以及基于 OpenTelemetry 的调用链路与告警能力。

## 基于 Envoy 的网关

[Envoy](https://github.com/envoyproxy/envoy) 最初由 Lyft 开发，目前是 CNCF 毕业项目，定位为「云原生高性能边缘/中间/服务代理」。与 Nginx 相比，Envoy 在三个方向上更适合作为新一代网关的底座:

- **xDS 动态配置**:通过 CDS/EDS/LDS/RDS 等一组发现服务，Envoy 可以在不重启进程的情况下更新监听器、集群、路由与端点，真正成为「可编程的数据面」;
- **L7 过滤器链**:网络过滤器与 HTTP 过滤器可自由组合，天然支持 HTTP/2、gRPC、TCP 等多协议的深度观测与改写;
- **开箱即用的可观测性**:内置指标、追踪、访问日志，与 Istio、Prometheus、SkyWalking 等生态契合度高。

Envoy 是 Istio 服务网格的默认数据面。基于 Envoy 的网关，既能复用 Istio 的控制面能力，也能以更平滑的方式把「入口网关」与「网格内部流量治理」统一到同一套技术栈。

### 阿里 Higress

[Higress](https://github.com/alibaba/higress) 是阿里开源、捐献给 CNCF 的云原生 API 网关（Sandbox 项目）,内核基于 **Istio + Envoy**。它的诞生背景正是为了解决传统 Nginx 类网关 `reload` 带来的长连接抖动，以及 gRPC/Dubbo 负载均衡能力薄弱等问题——在 Envoy 上，配置变更可以在毫秒级生效且不丢连接。

Higress 的扩展模型以 **Wasm(WebAssembly) 插件**为核心，支持用 Go、Rust、JavaScript 编写插件，并通过沙箱隔离实现插件崩溃不影响主进程、可「流量无损热升级」。官方维护了数十个开箱即用的通用插件，涵盖认证（key-auth、jwt-auth、hmac-auth、basic-auth、oidc）、流量管理、安全（WAF、IP/Cookie 维度的 CC 防护）,以及面向 AI 场景的 LLM 代理、Token 限流、语义缓存等。控制台 [higress-console](https://github.com/higress-group/higress-console) 提供可视化的路由、证书、插件管理。

Higress 同时扮演多种角色:

- **Kubernetes Ingress Controller**:兼容大量 ingress-nginx 注解，可平滑迁移;相比 ingress-nginx，资源开销显著下降、路由变更速度提升约一个数量级。
- **Gateway API 实现**:已支持 `GatewayClass`/`Gateway`/`HTTPRoute` 等资源，从 Ingress API 迁移路径平滑。
- **微服务网关**:对接 Nacos、ZooKeeper、Consul、Eureka 等注册中心，深度集成 Dubbo、Nacos、Sentinel。
- **AI 网关**:以统一协议对接主流 LLM 供应商，提供多模型负载均衡、Token 限流、缓存与可观测能力;同时支持 SSE 流式响应与 [MCP](https://modelcontextprotocol.io/) Server 托管，把 AI Agent 的工具调用纳入统一鉴权、限流与审计。

根据官方信息，Higress 在阿里内部有两年以上的生产验证，QPS 可达数十万级别。

## 选型参考

两条主线并非「谁取代谁」,而是各有侧重:

| 维度 | Nginx 系（APISIX/Kong/蓝鲸） | Envoy 系（Higress 等） |
|---|---|---|
| 数据面 | Nginx + OpenResty/Lua | Envoy |
| 配置生效 | 多依赖外部存储（etcd/Postgres）,热加载 | xDS 毫秒级下发，无 reload |
| 插件语言 | Lua 为主，辅以多语言 RPC / Wasm | Wasm(Go/Rust/JS) |
| 服务网格亲和度 | 一般，常作为独立入口 | 高，可与 Istio 控制面共用 |
| 生态成熟度 | 久经生产考验，社区庞大 | 借力 Envoy/Istio，演进活跃 |

实践中可这样取舍：如果团队已有 Nginx/OpenResty 沉淀，或看重插件生态与生产案例，APISIX、Kong、蓝鲸 API 网关都是稳妥之选;如果希望把入口网关与 Istio 服务网格统一到同一套数据面、追求毫秒级配置生效，或正在构建 AI/Agent 相关流量入口，Higress 这类基于 Envoy 的网关更值得评估。

无论选择哪种内核，都建议优先验证其对 [Gateway API](https://gateway-api.sigs.k8s.io/) 的支持程度——Gateway API 已成为 Kubernetes 流量入口事实上的新标准，选择能平滑迁移到 `Gateway`/`HTTPRoute` 资源的网关，可以在未来避免被特定实现绑定。

## 参考

- [Apache APISIX — GitHub](https://github.com/apache/apisix)
- [Kong Gateway — GitHub](https://github.com/Kong/kong)
- [蓝鲸 API 网关 - 控制面](https://github.com/TencentBlueKing/blueking-apigateway)
- [蓝鲸 API 网关 - 数据面（blueking-apigateway-apisix）](https://github.com/TencentBlueKing/blueking-apigateway-apisix)
- [Higress — GitHub](https://github.com/alibaba/higress)
- [Higress 官网](https://higress.io/en/)
- [higress-console — GitHub](https://github.com/higress-group/higress-console)
- [Envoy Proxy — GitHub](https://github.com/envoyproxy/envoy)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
