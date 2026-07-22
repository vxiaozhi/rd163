+++
title = "Kubernetes Gateway API 简介"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "下一代 Kubernetes 流量入口 API：角色、能力与版本演进"
description = "对比 Ingress 的局限，介绍 Kubernetes Gateway API 的设计角色、协议能力、路由粒度与版本演进，帮助理解其作为新一代流量入口 API 的价值。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "gateway-api", "ingress", "kubernetes", "网络"]
keywords = ["Gateway API", "Kubernetes", "Ingress", "HTTPRoute", "API 网关", "流量路由"]
toc = true
draft = false
+++

## 背景

Kubernetes Gateway API 是 Kubernetes 社区（SIG-Network）在原有 Ingress 基础上设计的一套全新流量入口 API 规范，项目最早以 `service-apis` 的名义于 2019 年作为沙箱项目启动，后更名为 Gateway API。它以 CRD 形式安装到集群中，并不随 Kubernetes 核心版本直接发布。相比 Ingress，Gateway API 定位为下一代入口 API，提供了更丰富的能力：支持 HTTP 之外更多协议（如 TCP、UDP、TLS、gRPC 等），具备更强的扩展性，可以通过 CRD 灵活新增特定的 Gateway 类型（例如 AWS Gateway、Envoy Gateway 等），并支持更细粒度的流量路由规则，可以精确到服务级别；而 Ingress 的最小路由单元通常是路径，主要面向 HTTP 流量。

Gateway API 的意义和价值：

- 作为 Kubernetes 官方项目，Gateway API 能够与 Kubernetes 本身更好地集成，具备更强的可靠性和稳定性。
- 支持更丰富的流量协议，适用于服务网格等更复杂的场景，不仅限于 HTTP，可以作为 Kubernetes 的统一流量入口 API。
- 具有更好的扩展性，通过 CRD 可以轻松支持各种 Gateway 的自定义类型，更加灵活。
- 可以实现细粒度的流量控制，精确到服务级别的路由，提供更强大的流量管理能力。

综上所述，Gateway API 作为新一代的 Kubernetes 入口 API，拥有更广泛的应用场景、更强大的功能，以及更好的可靠性和扩展性。对于生产级的 Kubernetes 环境，Gateway API 是一个值得考虑的选择。本篇文章将深入解读 Kubernetes Gateway API 的概念、特性和用法，帮助读者深入理解并实际应用 Kubernetes Gateway API，发挥其在 Kubernetes 网络流量管理中的优势。

## 版本现状

Gateway API 采用 CRD 形式独立发布，版本与 Kubernetes 核心版本解耦。其版本发展现状简述如下：

- **v1beta1（2022 年 7 月，v0.5.0）**：Gateway API 进入 beta 阶段，`GatewayClass`、`Gateway`、`HTTPRoute` 三个核心资源升级到 `v1beta1`，标志着可以在生产中试用；当时 TCP、UDP、TLS 等协议的资源仍处于 alpha 阶段。

- **v1.0 GA（2023 年 10 月 31 日）**：首个正式 GA 版本发布，`GatewayClass`、`Gateway`、`HTTPRoute` 三个核心资源升级到稳定的 `v1` API，可正式用于生产环境；其余协议资源仍在 experimental 通道中持续完善。

- **v1.1 ~ v1.6(2024 ~ 2025)**：后续版本陆续将更多资源与能力（如 GAMMA 服务网格支持、`GRPCRoute`、`TCPRoute`、`UDPRoute` 等）推进至标准通道或 GA。截至撰写时，Gateway API 仍在持续迭代，功能不断完善。

## 可用场景

下面简单整理 HTTPRoute 的一些典型可用场景：

- **多版本部署**：如果应用程序存在多个版本，可以使用 HTTPRoute 将流量路由到不同版本，便于测试和逐步升级。例如，将一部分流量路由到新版本进行验证，同时保持旧版本继续运行。

- **A/B 测试**：HTTPRoute 可以通过权重分配来实现 A/B 测试，将流量路由到不同的后端服务，并为每个服务指定权重，从而对比不同版本的功能和性能。

- **动态路由**：HTTPRoute 支持基于路径、请求头、请求参数等条件的动态路由，可以根据请求的不同属性将流量路由到不同的后端服务，以满足差异化的需求。

- **重定向**：HTTPRoute 支持重定向能力，可以将某些请求重定向到另一个 URL，例如将旧 URL 重定向到新 URL。

## 参考

- [Kubernetes Gateway API（官方文档）](https://gateway-api.sigs.k8s.io/)
- [Gateway API GitHub 仓库](https://github.com/kubernetes-sigs/gateway-api)
- [Gateway API v1.0: GA Release（Kubernetes Blog, 2023-10-31）](https://kubernetes.io/blog/2023/10/31/gateway-api-ga/)
- [Kubernetes Gateway API 进入 Beta 阶段（Kubernetes Blog, 2022-07-13）](https://kubernetes.io/zh-cn/blog/2022/07/13/gateway-api-graduates-to-beta/)
- [Migrating from Ingress](https://gateway-api.sigs.k8s.io/guides/getting-started/migrating-from-ingress/)
