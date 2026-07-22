+++
title = "K8s 跨集群通信"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "不同集群间 Pod 互通的方案选型"
description = "按集群节点网络是否互通分类，梳理 VPC/HostPort、Submariner、Skupper、KubeSlice、Istio、Cilium Cluster Mesh 等跨集群 Pod 通信方案及其适用场景。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "kubernetes", "多集群", "网络", "devops"]
keywords = ["kubernetes", "跨集群", "pod 通信", "submariner", "cilium", "istio"]
toc = true
draft = false
+++

跨集群 Pod 通信（Cross-Cluster Pod-to-Pod Communication）是多集群架构里最常被问到的问题之一。按底层网络是否互通，可以分两种情况讨论。

## 场景分类

**不同集群间 Node 互通**

- 同一云服务商（如腾讯云）下的多个集群，底层 VPC 已经打通。
- 公司内部自建的多个集群，节点 IP 在同一路由域内可达。

**不同集群间 Node 不互通**

- 公司自建集群与公有云集群之间，节点网络没有直接路由。
- 不同云服务商之间的集群，例如腾讯云与阿里云之间，被公网或 NAT 隔离。

## 方案

### 不同集群间 Node 互通

节点网络已经可达时，主要靠底层网络或 Service 暴露方式解决，不需要额外的隧道或控制面：

- **VPC 对等连接 / 路由打通**：在云厂商控制台或底层网络上配置 VPC Peering、专线或路由，使 Pod CIDR 跨集群可路由。
- **HostPort**：在 Pod spec 中用 `hostPort` 把容器端口直接绑定到宿主机端口，对端集群通过 NodeIP:HostPort 访问。
- **NodePort / 随机 HostPort**：通过 `NodePort` 或 CNI 的端口映射能力（如 Calico 的 portmap 插件随机分配 HostPort）在节点上暴露端口，对端集群访问任一节点的对应端口即可。

### 不同集群间 Node 不互通

节点网络不可达时，需要引入额外的控制面或数据面来打通跨集群链路，常见方案：

- [Submariner](https://github.com/submariner-io/submariner)：CNCF Sandbox 项目，通过 IPsec/VXLAN/WireGuard 网关节点打通 Pod 与 Service，CNI 无关，支持重叠 CIDR（通过 Globalnet 控制器）。
- [Skupper](https://github.com/skupperproject/skupper)：基于应用层的虚拟网络（VAN），通过 AMQP 消息骨干实现服务级互联，无需底层网络互通，适合受限的混合云、多云场景。
- [KubeSlice](https://github.com/kubeslice/kubeslice)：在 Pod 中动态插入第二块网卡，构建跨集群的 overlay 网络，支持完整协议栈。
- [Istio 多集群](https://istio.io/latest/zh/docs/ops/configuration/traffic-management/multicluster/)：通过多主（Multi-Primary）或主从（Primary-Remote）架构、东西向网关（East-West Gateway）将多个集群纳入统一服务网格，提供流量治理、mTLS 与可观测性，但需 Sidecar。
- [Cilium Cluster Mesh](https://github.com/cilium/cilium)：基于 eBPF，默认最多可连接 255 个集群（通过 `maxConnectedClusters` 可扩展到 511），支持跨集群 Pod 互通、全局 Service 负载均衡与跨集群网络策略。

需要注意的是，这些方案并不互斥。例如可以用 Cilium 或 Submariner 打通网络层，再叠加 Istio 做流量治理，二者互补。具体如何选型，建议结合现有 CNI、对 Sidecar 的接受度、性能要求与可观测性需求综合判断（更完整的方案对比见同站 [《K8s 多集群》]({{< relref "k8s-multi-cluster.md" >}})）。

## 参考

- [Kubernetes 多集群通信的五种方案](https://www.cnblogs.com/cheyunhua/p/18227292)
- [Kubernetes 多集群网络解决方案 Submariner 中文入门指南](https://www.modb.pro/db/623405)
- [Istio 多集群实践](https://cloud.tencent.com/developer/article/2378172)
- [基于 Istio 实现多集群流量治理](https://www.cnblogs.com/huaweiyun/p/18127975)
- [Istio 多集群流量管理（官方文档）](https://istio.io/latest/zh/docs/ops/configuration/traffic-management/multicluster/)
- [多集群 Istio 服务网格的跨集群无缝访问指南](https://jimmysong.io/blog/seamless-cross-cluster-access-istio/)
- [Multi-cluster traffic failover with EastWest Gateways](https://docs.tetrate.io/service-bridge/howto/gateway/multi-cluster-traffic-routing-with-eastwest-gateway)
- [Setting up Cluster Mesh（Cilium 官方文档）](https://docs.cilium.io/en/stable/network/clustermesh/clustermesh/)
- [Cilium 多集群 Cluster Mesh 介绍](https://cloud.tencent.com/developer/article/2029179)
- [Submariner 官方网站](https://submariner.io/)
