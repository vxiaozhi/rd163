+++
title = "K8s 网关介绍"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从 Ingress 到 Gateway API 的演进与核心资源模型"
description = "介绍 Kubernetes 网关的演进背景,以及 Gateway API 的设计理念、核心资源(GatewayClass/Gateway/HTTPRoute)与典型用法。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "gateway-api", "ingress", "networking"]
keywords = ["k8s 网关", "Gateway API", "HTTPRoute", "Ingress", "GatewayClass"]
toc = true
draft = false
+++

在 Kubernetes 中，把集群内服务暴露给外部用户访问，最早也最广泛使用的 API 是 Ingress。Ingress 解决了"以域名和路径将外部 HTTP/HTTPS 流量路由到集群内 Service"这一基本问题，但在长期实践中暴露出一些结构性短板：它只覆盖 HTTP/HTTPS，扩展能力几乎完全依赖各 Ingress Controller 自定义的 annotation，无法表达流量权重、请求头匹配、跨命名空间挂载等需求，也难以对应现实中"基础设施、集群运维、应用开发"三种角色的职责划分。

为了弥补这些不足，Kubernetes SIG-Network 牵头设计了 Gateway API。它并非对 Ingress 的简单升级，而是一套全新的、面向角色的、可移植且可扩展的 API 族。本文先梳理它要解决的问题，再介绍其设计理念、核心资源模型与典型用法。

## 设计理念

Gateway API 由 Kubernetes 官方以 CRD(Custom Resource Definition)形式发布，官网将其设计原则归纳为四点:

- **面向角色（Role-oriented）**:API 按照实际组织里的角色建模，明确区分三类使用者——基础设施提供商（Infrastructure Provider）、集群运维（Cluster Operator）和应用开发者（Application Developer）,每种角色关心不同的资源层级。
- **可移植（Portable）**:规范由社区统一制定，所有合规的控制器都遵循同一套 CRD，业务侧配置可在不同实现之间迁移。
- **表达力强（Expressive）**:原生支持基于请求头、路径、权重的匹配与路由，不再像 Ingress 那样依赖 annotation。
- **可扩展（Extensible）**:允许在多个层级挂接自定义资源，以支持厂商特有能力。

## 核心资源模型

Gateway API 通过三个稳定的资源层级把"基础设施"与"路由规则"解耦:

```
GatewayClass ──controls──> Gateway ◂──attaches── HTTPRoute / GRPCRoute / ...
```

### GatewayClass

`GatewayClass` 描述一组共享相同配置和控制器实现的 Gateway，概念上类似 Ingress 的 IngressClass 或 Pod 的 StorageClass。它由控制器提供商定义，指明由哪个控制器负责 reconcile。

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: example-class
spec:
  controllerName: example.com/gateway-controller
```

### Gateway

`Gateway` 是流量处理基础设施的一个实例，可以对应一台云负载均衡器，也可以是一个集群内的代理（如 Envoy）。它声明监听器（listener）的协议、端口、主机名，以及允许哪些 Route 挂接上来。

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: example-gateway
  namespace: example-namespace
spec:
  gatewayClassName: example-class
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "www.example.com"
    allowedRoutes:
      namespaces:
        from: Same
```

`allowedRoutes.namespaces.from` 默认为 `Same`,表示该 Gateway 只接受同命名空间下的 Route。这也是 Gateway API 跨命名空间能力的关键开关。

### HTTPRoute

`HTTPRoute` 描述 HTTP 请求从某个 Gateway listener 到后端 Service 的路由规则，典型字段是 `parentRefs`(挂接到哪个 Gateway)、`hostnames`(匹配域名)和 `rules`(匹配条件与后端)。

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: example-httproute
spec:
  parentRefs:
  - name: example-gateway
  hostnames:
  - "www.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /login
    backendRefs:
    - name: example-svc
      port: 8080
```

上述配置把 `Host: www.example.com` 且路径前缀为 `/login` 的请求转发到 `example-svc:8080`。

除 `HTTPRoute` 外，Standard Channel 还提供了 `GRPCRoute`,专门用于匹配 gRPC 方法（service/method）;TLS、TCP、UDP 等协议则通过 Experimental Channel 的 `TLSRoute`、`TCPRoute`、`UDPRoute` 提供。

## 与 Ingress 的对比

| 维度 | Ingress | Gateway API |
| --- | --- | --- |
| 角色模型 | 单一资源，角色边界模糊 | 分层资源，天然面向角色 |
| 表达力 | 依赖厂商 annotation | 原生支持 header、权重、跨命名空间等 |
| 协议覆盖 | 仅 HTTP/HTTPS | HTTP、gRPC，以及实验性 TLS/TCP/UDP |
| 跨命名空间 | 受限 | 通过 `allowedRoutes` 双向信任显式授权 |
| 扩展方式 | annotation | 多层 CRD 可挂接 |

需要强调的是，Gateway API 并不包含 Ingress 这个 kind，因此不是"开箱即用的替换",而是功能更强、可演进的新一代规范。

## 跨命名空间与角色分工

Gateway 与 Route 之间是"双向信任"关系:Gateway 通过 `allowedRoutes` 决定允许哪些 Route 挂接，Route 通过 `parentRefs` 引用要挂接的 Gateway。这种设计天然契合角色分工——集群运维统一管理 Gateway(对外暴露的端口与域名策略),各业务团队在自己命名空间里维护 HTTPRoute，只需被授权即可"挂上来"。

## 版本现状

Gateway API 的核心资源已于 **2023 年 10 月 31 日** 随 v1.0 发布正式 GA(General Availability),并在 KubeCon + CloudNativeCon North America 2023 期间宣布。 graduated 到 `v1`(stable)的三种资源是:

- `GatewayClass`
- `Gateway`
- `HTTPRoute`

GA 之后，API 表面具备向后兼容保证，但功能仍在通过 Experimental Channel 持续扩展。自 v1.0 起，CRD 内置 CEL 校验规则，在 Kubernetes 1.25+ 集群上可以选择不安装 Webhook(仅对 1.24 及以下推荐保留)。

## 主流实现

Gateway API 是规范，真正的流量处理由各厂商控制器完成。截至本文整理时，已通过一致性认证的控制器包括 Envoy Gateway、NGINX Gateway Fabric、Cilium、Istio、Gloo Gateway、GKE Gateway、Traefik、HAProxy Ingress 等;部分合规的还有 Contour、AWS Load Balancer Controller、Amazon VPC Lattice(EKS)、Kong Operator 等。在 Service Mesh 场景下，Istio、Cilium 也通过 GAMMA(Gateway API for Mesh Management and Administration)支持东西向流量。

## 小结

从 Ingress 到 Gateway API，体现的是 Kubernetes 在入口流量管理上的一次范式转变：把"基础设施"与"路由规则"分层、把不同角色的职责写进 API、把可移植性和扩展性放在首位。对生产级集群而言，在控制器选型、跨命名空间授权、灰度与 A/B 测试等场景下，Gateway API 都比 Ingress 更值得作为长期方案。后续文章会结合具体控制器（如 Envoy Gateway、Istio）展开实践细节。

## 参考

- [Services, Load Balancing, and Networking](https://kubernetes.io/docs/concepts/services-networking/)
- [Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/)
- [Gateway API Overview](https://gateway-api.sigs.k8s.io/)
- [Kubernetes Gateway API 深入解读和落地指南](https://cloudnative.to/blog/kubernetes-gateway-api-explained/)
- [实现了 K8s gateway 的控制器列表](https://gateway-api.sigs.k8s.io/implementations/)
- [Gateway API GA 公告（2023-10-31）](https://kubernetes.io/blog/2023/10/31/gateway-api-ga/)
- [Migrating from Ingress](https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/)
