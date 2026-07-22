+++
title = "北极星（Polaris）"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "腾讯开源的一站式服务发现与治理平台"
description = "介绍腾讯开源服务治理平台北极星(Polaris)的核心能力、架构组件、数据面模式与部署方式,并梳理自建与托管两种落地路径。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "polaris", "polarismesh", "service-mesh", "service-discovery", "tencent", "微服务"]
keywords = ["北极星", "Polaris", "PolarisMesh", "服务治理", "服务发现", "腾讯开源"]
toc = true
draft = false
+++

在微服务与分布式架构里，服务实例动态扩缩容、跨语言调用、跨环境互通是常态，随之而来的服务注册发现、流量控制、故障容错、配置下发等问题都需要一个统一的治理面来承载。北极星（Polaris，项目代号 PolarisMesh）正是腾讯针对这一诉求开源的服务发现与治理平台，在腾讯内部已经支撑了百万级服务注册和十万亿级日接口调用，通用性与稳定性经过大规模验证。

本文整理北极星的应用场景、功能特性、系统组件、数据面接入方式以及部署路径，作为入门与选型参考。

## 简介

北极星是腾讯开源的云原生服务治理平台，定位为"一站式服务治理平台",覆盖传统上需要分别引入注册中心、服务网格、配置中心才能拼齐的能力。它面向分布式与微服务架构，提供以下五类标准能力:

- **服务管理**:服务注册与发现、健康检查。
- **流量控制**:可定制的路由、负载均衡、限流与访问控制。
- **故障容错**:服务级/接口级/实例级熔断与降级、实例隔离与切换。
- **配置管理**:配置版本管理、灰度发布、动态下发。
- **可观测性**:业务监控、流量监控、事件中心与操作记录。

北极星支持虚拟机、容器以及混合云环境，能够打通 Kubernetes 集群与非 K8s 服务之间的发现与治理。

## 核心特性

### 多语言、多框架接入

北极星提供多种数据面（data plane）接入方式，业务可以根据语言和侵入性偏好选择:

- **多语言 SDK**:Polaris-Java、Polaris-Go、Polaris-C/C++、Polaris-PHP、Polaris-Lua 等。
- **Java 框架集成**:基于 Polaris-Java 的 Spring Cloud、Spring Boot、Dubbo(注册/路由/熔断/限流)、gRPC Java。
- **Go 框架集成**:基于 Polaris-Go 的 Dubbo-Go、gRPC Go。
- **Java Agent**:无侵入的字节码增强方案，适合存量 Java 应用零改造接入。
- **Sidecar / 网格代理**:通过 Polaris-Sidecar 以代理模式接管流量，适合异构语言统一治理。
- **网关集成**:Spring Cloud Gateway、Nginx 等接入治理能力。

### 代理与无代理两种模式

北极星同时支持两种部署形态:

- **Proxyless(无代理)**:业务直接通过 SDK 或 Agent 完成服务发现与治理，无 sidecar 转发开销，延迟更低。
- **Proxy(代理)**:通过 sidecar 注入，以服务网格方式接管流量，对业务代码完全透明，便于异构技术栈统一管控。

配合 Polaris-Controller，可以在 Kubernetes 中实现 K8s 服务注册与 sidecar 自动注入，从而支持 K8s 与非 K8s 服务之间、跨多个 K8s 集群之间的统一治理。

### 故障容错粒度

熔断支持三个层级，粒度比常见的实例熔断更细:

- **服务级**:整个下游服务不可用时熔断。
- **接口级**:针对特定接口（方法）熔断。
- **实例级**:针对单个实例熔断并隔离切换。

这样可以避免因某个接口或实例的抖动拖垮整体调用链。

## 系统组件

北极星代码仓库(`polarismesh/polaris`,主要语言为 Go)按职责划分了若干核心模块，从控制面和数据面的角度可以归纳如下:

| 组件 | 角色 | 说明 |
| --- | --- | --- |
| Polaris-Server | 控制面 | 处理服务注册、发现、配置、规则下发，是北极星的核心服务。 |
| Polaris-Console | 控制面 | Web 管理控制台，提供服务、配置、规则的可视化管理与监控。 |
| Polaris-SDK | 数据面 | 多语言客户端 SDK，内嵌于业务进程，Proxyless 模式的主要载体。 |
| Polaris-Sidecar | 数据面 | 以 sidecar 形式运行的代理，Proxy 模式的载体。 |
| Polaris-Controller | 控制面 | Kubernetes Controller，实现 K8s 服务注册与 sidecar 自动注入。 |

从仓库源码组织上看，Polaris-Server 内部进一步划分为 `apiserver`(协议接入层，如 gRPC/HTTP)、`service`(核心服务逻辑)、`store`(持久化层)、`cache`(缓存层)、`config`(配置管理)、`namespace`(命名空间)、`auth`(鉴权)、`plugin`(插件体系，如存储、鉴权后端可扩展)等模块。这种分层设计使得存储后端、鉴权方式可以按需替换。

## 部署方式

北极星的部署有两条主流路径:**自建开源版本**和**使用腾讯云托管服务**。

### 自建开源版

社区提供 Docker 镜像(`polarismesh/polaris-server`,发布在 Docker Hub)以及二进制包，具体的安装步骤、端口规划、依赖组件清单随版本变化，建议以仓库 `release/` 目录的安装指南和 Releases 页面为准:

- 安装指南:<https://github.com/polarismesh/polaris/tree/main/release>
- Releases 页面:<https://github.com/polarismesh/polaris/releases>

自建模式适合对数据合规、定制化、成本敏感，且具备一定运维能力的团队，需要自行承担集群高可用、监控告警、版本升级等工作。

### 腾讯云托管（TSF Polaris）

腾讯云在 TSF(Tencent Service Framework，腾讯微服务平台)下提供了"注册配置治理中心 - Polaris"的托管形态，主打快速部署、高可用容灾、免运维、一键搭建北极星网格能力。创建实例的关键选项包括:

- **产品版本**:Enterprise(注册+配置+治理)、Basic(注册+配置)、Developer(单节点 1C1G，仅供试用)、Standard(多节点)。
- **开源版本**:控制台显示支持的开源内核版本（例如文档示例中为 1.9.0.1，实际以购买页为准）。
- **集群网络**:VPC 需与业务 VPC 一致，子网可以不一致。
- **规格**:按服务实例配额选择。

实例创建后，根据语言/框架选择接入方式:

- Java:Spring Cloud、Java Agent 或 polaris-Java SDK。
- Go:polaris-Go 或 gRPC-Go SDK。
- 其他：参考 TSF 控制台提供的接入文档与 Eureka 迁移指南。

托管模式适合希望快速落地、不想自建控制面的团队，但需注意网络连通性与计费方式（按量付费或包月）。

## 适用场景

结合社区文档与典型用户案例，北极星常用于以下场景:

- **多语言微服务统一治理**:同一套控制面同时支撑 Java、Go、C++ 等多语言业务，避免每种语言各搞一套注册中心。
- **K8s 与非 K8s 混合互通**:存量虚拟机业务与容器化业务统一发现，平滑迁移。
- **流量精细化管控**:灰度发布、按元数据路由、按接口粒度限流熔断。
- **存量 Java 应用零改造接入**:通过 Java Agent 方式，无需改动代码即可获得治理能力。

公开的采用方包括腾讯云、微信支付、腾讯视频、腾讯会议，以及贝壳找房、BOSS 直聘、OPPO 等外部公司，覆盖金融、房产、招聘、终端厂商等多个行业。

## 选型小结

如果你的团队面临"既要注册中心，又要配置中心，还要服务网格"的拼装成本问题，北极星"一站式"的定位值得作为候选。选型时可以重点考察:

- 业务语言与框架是否在官方 SDK/集成列表内。
- 是否需要 Proxy 模式（网格）还是 Proxyless(SDK/Agent)即可满足。
- 是否跨 K8s 与非 K8s 环境，需要 Polaris-Controller。
- 团队运维能力，决定自建开源版还是使用云托管。

## 参考

- [PolarisMesh 官网](https://polarismesh.cn/)
- [Polaris GitHub 仓库](https://github.com/polarismesh/polaris)
- [Polaris 安装指南（release 目录）](https://github.com/polarismesh/polaris/tree/main/release)
- [腾讯云 TSF Polaris 入门配置](https://cloud.tencent.com/document/product/1364/79800)