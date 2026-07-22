+++
title = "K8s 多集群"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从 Federation 到 Karmada:多集群编排方案的演进与选型"
description = "梳理 Kubernetes 多集群的驱动力,对比 Federation v1/v2、Karmada、OCM、Cluster API、Submariner、Cilium Cluster Mesh 等主流方案的特点与适用场景。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "kubernetes", "多集群", "karmada", "kubefed", "devops"]
keywords = ["kubernetes", "多集群", "karmada", "kubefed", "federation", "cilium"]
toc = true
draft = false
+++

## 1. 为什么需要 K8s 多集群

在讨论方案之前，先厘清概念。所谓 K8s 多集群（Multi-Cluster）,顾名思义就是多个 Kubernetes 集群协同工作。企业或组织可能根据自身需求，出于隔离性、可用性、合规性或使用成本等考虑，将应用运行在一个或多个集群中。在更成熟的形态下，应用实际运行的集群能够动态调度，不同集群间的应用也应支持相互访问。

常见的驱动力包括:

- **故障隔离**:单一集群的故障域过大，多集群可避免全局雪崩。
- **多活与容灾**:跨地域（geo-redundant）部署，做到主备或 active-active。
- **合规与数据驻留**:金融、医疗等行业要求数据不出境或留在指定区域。
- **混合云/多云**:避免厂商锁定（vendor lock-in）,按成本或能力选择云厂商。
- **版本灰度**:在新版本集群上灰度验证，再整体切换。
- **边缘计算**:中心集群加边缘集群的分级管理。

## 2. 主流方案概览

K8s 多集群方案大致可分为三类:**应用分发编排**、**集群生命周期管理**、**跨集群网络互通**。下面按历史演进与生态分布逐一介绍。

### 2.1 Federation v1(已废弃)

Kubernetes Federation v1 是社区最早的联邦方案，它引入一个独立的联邦控制平面，把多个集群的 API server 聚合起来统一调度。但其设计存在硬伤：每种资源类型都需要在联邦控制面单独注册，扩展性差;调度能力薄弱;元数据同步链路复杂。该项目在 2018 年前后被社区废弃，并转向 v2。

### 2.2 Federation v2 / KubeFed(已归档)

KubeFed(Kubernetes Federation v2)改用 CRD(Custom Resource Definition)重新实现，引入 `KubeFedCluster`、`KubeFedConfig`、`FederatedDeployment` 等对象，通过 `EnableDirective` 通用地传播任意资源类型，并提供 `OverridePolicy` 做差异化配置。

然而 KubeFed 仍然缺乏真正的多集群调度器（scheduler）,故障转移（failover）能力有限，社区活跃度逐渐下降。Kubernetes SIG Multi-Cluster 已于 **2023 年 4 月 25 日将 `kubernetes-sigs/kubefed` 仓库归档**,正式宣告这一路线的终结。

### 2.3 Karmada(活跃，CNCF Incubating)

Karmada(取自 Kubernetes Armada 之意)由华为开源，是 Kubernetes Federation v1 和 v2 的延续，继承了早期版本的基本概念，但在架构上做了根本性升级:

- **K8s 原生 API**:直接复用 Kubernetes 原生 API，单集群应用到多集群可"零改造"迁移。
- **真正的调度器**:内置调度策略，支持按权重、亲和性（affinity）、拓扑分布（spread）在多集群间分发副本。
- **自动故障转移**:成员集群故障时自动重新调度，无需人工干预。
- **丰富的 Override 策略**:`OverridePolicy`、`ClusterOverridePolicy` 可针对不同集群做差异化渲染。
- **开放中立**:跨云厂商，避免厂商锁定。

Karmada 是目前社区最活跃的多集群应用编排项目之一，已是 CNCF 孵化（Incubating）项目，被互联网、金融、制造、电信、云服务商等多类企业联合采用。

一个最小化的 Karmada 分发策略(`PropagationPolicy`)示例，将 `nginx` Deployment 按 2:1 的权重分发到北京、上海两个集群:

```yaml
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: example-policy
  namespace: default
spec:
  resourceSelectors:
    - apiVersion: apps/v1
      kind: Deployment
      name: nginx
  placement:
    clusterAffinity:
      clusterNames:
        - cluster-beijing
        - cluster-shanghai
    replicaScheduling:
      replicaSchedulingType: Divided
      replicaDivisionPreference: Weighted
      weightPreference:
        staticWeightList:
          - targetCluster:
              clusterNames: [cluster-beijing]
            weight: 2
          - targetCluster:
              clusterNames: [cluster-shanghai]
            weight: 1
```

## 3. 其他相关项目

多集群生态不只有 Karmada，不同问题域有不同方案，选型时常常组合使用:

- **Cluster API(CAPI)**:Kubernetes SIG Cluster Lifecycle 子项目，用声明式 API 管理集群自身的**生命周期**(创建、升级、销毁)。它解决的是"如何把集群开起来",而不是"集群里跑什么",与 Karmada 互补。
- **Open Cluster Management(OCM)**:CNCF Sandbox 项目，采用 hub-spoke(中心-辐射)模型，强项在于策略治理、合规与安全管控，可与 Argo CD、Cluster API、Istio、Submariner 等集成。
- **Submariner**:CNCF Sandbox 项目，专注跨集群 **Pod/Service 三层互通**与服务发现，CNI 无关，支持重叠 CIDR(通过 Globalnet 控制器)。
- **Cilium Cluster Mesh**:基于 eBPF 的 Cilium 提供的集群网格能力，支持跨集群 Pod 互通、全局 Service 负载均衡与跨集群网络策略。默认可连接最多 **255 个集群**(可扩展到 511 个)。
- **Argo CD ApplicationSets**:GitOps 路线，通过模板把同一份应用清单下发到多个集群，适合"配置一致性优先"的场景。

简单选型参考：做**应用多活与跨云调度**选 Karmada;做**集群供给**选 Cluster API;做**跨集群治理**选 OCM;只关心**网络互通**选 Submariner 或 Cilium Cluster Mesh;**纯 GitOps 下发**用 Argo CD ApplicationSets。

## 4. 演进趋势

从 Federation v1 → v2 → Karmada，可以看到清晰的演进轨迹：从"聚合 API server"到"CRD 化",再到"原生 API + 调度器"。社区已基本放弃在 API server 层做联邦，转而把多集群视为"调度域"的扩展——保留单集群 API 的兼容性，只在调度与分发层引入多集群语义。这一思路与 Service Mesh、GitOps 等正交，可灵活组合。对绝大多数新场景而言，Federation 已是历史，Karmada 及周边网络/治理项目才是当下值得投入的方向。

## 参考

- [理解 K8s 多集群（上）:构建成熟可扩展云平台的核心要素](https://www.lenshood.dev/2023/03/09/k8s-multi-cluster-1/)
- [理解 K8s 多集群（下）:解决方案对比与演进趋势](https://www.lenshood.dev/2023/03/26/k8s-multi-cluster-2/)
- [初探几种常用的 Kubernetes 多集群方案](https://www.51cto.com/article/713672.html)
- [Karmada 官方网站](https://karmada.io/)
- [Karmada GitHub 仓库](https://github.com/karmada-io/karmada)
- [KubeFed 仓库（已归档）](https://github.com/kubernetes-sigs/kubefed)
- [Open Cluster Management](https://open-cluster-management.io/)
- [Submariner 官方网站](https://submariner.io/)
- [Cilium Cluster Mesh 文档](https://docs.cilium.io/en/stable/network/clustermesh/clustermesh/)
