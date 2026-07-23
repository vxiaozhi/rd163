+++
title = "K8s CNI 网络插件"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "主流 Kubernetes CNI 插件清单与选型建议"
description = "本文汇总 Kubernetes 生态中主流的 CNI 网络插件（Antrea、Calico、Cilium、Flannel、Weave Net、Terway 等），并结合社区性能测评给出小规模、标准、高性能三类集群的选型建议。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "cni", "network", "kubernetes", "calico", "cilium"]
keywords = ["cni", "kubernetes", "网络插件", "calico", "cilium", "flannel"]
toc = true
draft = false
+++

Kubernetes 的网络模型要求每个 Pod 都拥有独立的 IP，并能在不同节点间互通。CNI（Container Network Interface）便是实现这一模型的标准接口，kubelet 在创建 Pod 时会调用配置好的 CNI 插件来完成网卡与 IP 的分配。下面整理了社区常见的 CNI 插件以及性能测评与选型建议。

## 主流 CNI 插件

社区中比较活跃、可生产使用的 CNI 插件主要有以下这些：

- [Antrea](https://github.com/antrea-io/antrea)：基于 Open vSwitch（OVS）的 CNI，与 VMware vSphere 生态结合紧密。
- [amazon-vpc-cni-k8s](https://github.com/aws/amazon-vpc-cni-k8s)：AWS 官方插件，直接复用 VPC 的 ENI 为 Pod 分配 IP，非 Overlay 方案。
- [Calico](https://github.com/projectcalico/calico)：纯三层（BGP）方案，支持丰富的 NetworkPolicy，是生产环境最常见的选择之一。
- [Canal](https://github.com/projectcalico/canal)：Flannel 负责网络打通、Calico 负责策略的组合方案。
- [Cilium](https://github.com/cilium/cilium)：基于 eBPF 的数据平面，可替代 kube-proxy，可观测性（Hubble）与 L7 策略能力突出。
- [Contiv-VPP](https://github.com/contiv/vpp)：基于 FD.io VPP 的用户态高性能数据平面。
- [Flannel](https://github.com/flannel-io/flannel)：最简单、最轻量的 Overlay 方案，k3s 等默认使用。
- [Kube-router](https://github.com/cloudnativelabs/kube-router)：使用 IPVS 做 Service Proxy、BGP 做路由，单二进制集成多种网络能力。
- [Kube-OVN](https://github.com/kubeovn/kube-ovn)：基于 OVN 的 SDN 方案，提供了丰富的 OVN 特性。
- [Weave Net](https://github.com/weaveworks/weave)：自带加密的 Mesh Overlay 方案，但上游公司 Weaveworks 已于 2024 年初停止运营，新部署不再推荐。
- [阿里云 Terway](https://github.com/AliyunContainerService/terway)：阿里云 ACK 自研 CNI，基于 ENI 直连 VPC，支持 eBPF 加速与 NetworkPolicy。

此外还有面向多网卡或特殊硬件场景的扩展插件：[Multus-CNI](https://github.com/k8snetworkplumbingwg/multus-cni)（Intel 主导，支持给一个 Pod 挂多块网卡）、[CNI-Genie](https://github.com/cni-genie/CNI-Genie)（华为，支持多 CNI 选择）、[galaxy](https://github.com/tkestack/galaxy)（腾讯 TKEStack）、以及 [sriov-cni](https://github.com/k8snetworkplumbingwg/sriov-cni)（为 Pod 提供 SR-IOV VF 与 DPDK 能力）。

## CNI 性能

ITNEXT 网站对不同 CNI 插件做过两份较为公开、被广泛引用的性能测评，分别针对 10Gbit/s 和 40Gbit/s 网络：

- [Benchmark results of Kubernetes network plugins (CNI) over 10Gbit/s network (Updated: August 2020)](https://itnext.io/benchmark-results-of-kubernetes-network-plugins-cni-over-10gbit-s-network-updated-august-2020-6e1b757b9e49)
- [Benchmark results of Kubernetes network plugins (CNI) over 40Gbit/s network [2024]](https://itnext.io/benchmark-results-of-kubernetes-network-plugins-cni-over-40gbit-s-network-2024-156f085a5e4e#89d8-90c23c8caeb4-reply)

根据测评结论，作者给出的选型建议如下：

- **小规模集群**：推荐使用 Kube-router（发展迅速），轻量级、高效，支持广泛的架构（amd64、arm64、riscv64 等）；如果追求稳定、省事，可以考虑 Flannel 或 Canal 作为替代方案。
- **标准集群**：Cilium 是首选，其次是 Calico 或 Antrea。Cilium 的优势在于可观测性、易于排查的 CLI、基于 eBPF 的 kube-proxy 替代方案，以及完善的文档。
- **高性能集群**：Calico 或 Calico VPP，在性能与流量加密方面表现突出。

需要说明的是，性能测评结果会随内核版本、CNI 版本、流量模型差异而变化，以上建议应结合自身场景做小规模验证后再落地。

## 参考

### 综合资料

- [CNCF Landscape](https://landscape.cncf.io/)
- [Kubernetes CNI 介绍 - Feisky's Notes](https://kubernetes.feisky.xyz/extension/network/cni)
- [CNI 规范定义（SPEC.md）](https://github.com/containernetworking/cni/blob/main/SPEC.md)
- [CNI 官方文档](https://www.cni.dev/)
- [Kubernetes CNI 插件选型和应用场景探讨 - KubeSphere](https://kubesphere.io/zh/blogs/kubernetes-cni/)
- [腾讯云容器网络概述](https://cloud.tencent.com/document/product/457/50353)
- [The Ultimate Guide To Using Calico, Flannel, Weave and Cilium - Platform9](https://platform9.com/blog/the-ultimate-guide-to-using-calico-flannel-weave-and-cilium/)

### 原理与深入

- [循序渐进理解 CNI 机制与 Flannel 工作原理](https://blog.yingchi.io/posts/2020/8/k8s-flannel.html)
- [深入浅出运维可观测工具（一）：聊聊 eBPF 的前世今生](https://cloudnative.to/blog/current-state-and-future-of-ebpf/)
- [酷壳 - EBPF 介绍](https://coolshell.cn/articles/22320.html)
- [Introducing the Calico eBPF dataplane - Tigera](https://www.tigera.io/blog/introducing-the-calico-ebpf-dataplane/)
- [What is Kube-Proxy and why move from iptables to eBPF? - Isovalent](https://isovalent.com/blog/post/why-replace-iptables-with-ebpf/)

### 多 CNI 与硬件扩展

- [Multi CNI：Intel 方案 Multus-CNI](https://github.com/k8snetworkplumbingwg/multus-cni)
- [Multi CNI：华为 CNI-Genie](https://github.com/cni-genie/CNI-Genie)
- [Multi CNI：腾讯 tkestack 的 galaxy](https://github.com/tkestack/galaxy)
- [sriov-cni：为 Pod 提供 SR-IOV 功能与 DPDK 驱动配置，提供具体的 VF 功能](https://github.com/k8snetworkplumbingwg/sriov-cni)

### 性能测评

- [Benchmark results of Kubernetes network plugins (CNI) over 10Gbit/s network (Updated: August 2020)](https://itnext.io/benchmark-results-of-kubernetes-network-plugins-cni-over-10gbit-s-network-updated-august-2020-6e1b757b9e49)
- [Benchmark results of Kubernetes network plugins (CNI) over 40Gbit/s network [2024]](https://itnext.io/benchmark-results-of-kubernetes-network-plugins-cni-over-40gbit-s-network-2024-156f085a5e4e#89d8-90c23c8caeb4-reply)
