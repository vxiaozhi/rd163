+++
title = "K8s 网络插件 Cilium"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "基于 eBPF 的高性能网络、安全与可观测性方案"
description = "Cilium 是基于 eBPF/XDP 的 Kubernetes CNI 插件，提供网络、安全策略、负载均衡和 Hubble 可观测性，可完全替代 kube-proxy。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "cilium", "cni", "ebpf", "hubble"]
keywords = ["cilium", "ebpf", "cni", "kubernetes", "hubble", "kube-proxy"]
toc = true
draft = false
+++

## 简介

Cilium 是一个基于 eBPF 和 XDP 的高性能容器网络方案，代码开源在 [github.com/cilium/cilium](https://github.com/cilium/cilium)，目前已从 CNCF 毕业，是云原生网络领域事实上的标准之一。它通过在 Linux 内核中动态插入 eBPF 字节码，把网络转发、安全策略、负载均衡和可观测性逻辑下沉到内核态执行，无需修改应用代码或容器配置。

与传统基于 iptables 的 CNI 插件相比，Cilium 最大的特点是用 eBPF 程序接管了数据路径（datapath），避免了 iptables 在大规模服务场景下规则链线性匹配（O(n)）的性能瓶颈。

### 核心能力

- **网络连接**：提供跨 Pod、跨 Node、跨 Cluster 的扁平 L3 网络，支持 Overlay（VXLAN/Geneve）、原生路由（native routing）以及 BGP / L2 邻居发现等灵活路由方式。
- **安全策略**：L3/L4/L7 三层身份感知（identity-aware）策略。策略按使用方式可分为基于身份（security identity）、基于 CIDR、基于标签（label）三类，L7 可针对 HTTP method/path、gRPC、Kafka、DNS 等做细粒度过滤。
- **负载均衡**：内嵌基于 eBPF 哈希表的分布式负载均衡，可完全替代 `kube-proxy`。
- **可观测性**：通过 Hubble 提供实时服务依赖图、流日志和应用层指标。
- **加密**：节点间透明加密，支持 IPsec 与 WireGuard 两种方案。
- **多集群**：ClusterMesh 提供跨 Kubernetes 集群的服务发现、统一身份和连通性。

## eBPF 与 XDP

要理解 Cilium 的工作机制，需要先了解它赖以运行的两项内核技术：eBPF 与 XDP。

### eBPF（extended BPF）

eBPF（extended Berkeley Packet Filter）起源于经典的 BPF。原始 BPF（被追溯命名为 cBPF，classic BPF）只有两个 32 位寄存器，提供内核数据包过滤机制：用户态通过 `SO_ATTACH_FILTER` 这类 socket 选项把过滤器挂到 socket 上，只有满足条件的数据包才上送到用户空间。

eBPF 是对 cBPF 的扩展与重写，引入了十个 64 位寄存器并大幅丰富了指令集。它在内核中提供一个安全沙箱化的虚拟机，用户态把过滤/处理逻辑以字节码的形式通过 `bpf()` 系统调用传入内核，内核经过验证器（verifier）校验安全后 JIT 编译为本机指令执行。自 Linux 3.18 起，内核内置了 eBPF 虚拟机，cBPF 程序在加载时也会被透明地转换为 eBPF 表示。

需要注意的是，eBPF 的能力早已不局限于包过滤：通过 attach 到 tracepoint、kprobe、cgroup、socket、TC（Traffic Control）、XDP 等挂载点，它可以用于网络、安全、追踪、观测等多种场景。Cilium 正是把 eBPF 程序挂到 TC、XDP、socket、cgroup 等多个网络路径关键点上，组合出完整的容器网络数据平面。

> 原文提到「Linux 3.15 开始引入 eBPF」。准确的说法是 eBPF 的早期合入工作散落在多个内核版本，而 eBPF 虚拟机和 `bpf()` 系统调用通常以 Linux 3.18 为正式引入版本。

### XDP（eXpress Data Path）

XDP 是 Linux 内核网络栈中的一个 eBPF 挂载点，位于网卡驱动收包（RX）路径上最早的位置。挂载在 XDP 的 eBPF 程序在数据包刚到达网卡、尚未进入内核协议栈（`sk_buff` 分配）之前就会被执行，因此能获得最佳的数据包处理性能，常用于 DDoS 防护、L3/4 负载均衡、早期丢弃等场景。

XDP 通常有三种运行模式：

- **Native（驱动）模式**：eBPF 程序直接运行在网卡驱动中，性能最高，需要驱动支持。
- **Generic（skb）模式**：在内核协议栈早期执行，不依赖驱动支持，兼容性更好、性能略低。
- **Offloaded（卸载）模式**：eBPF 程序下放到支持此特性的网卡硬件（如部分 SmartNIC）执行。

Cilium 在南北向负载均衡（NodePort、LoadBalancer）等高吞吐场景下会利用 XDP 来加速转发，并支持 DSR（Direct Server Return）和 Maglev 一致性哈希。

## 核心特性详解

### kube-proxy 替代

Cilium 可以完全替代 `kube-proxy`，用 eBPF 接管所有 Kubernetes Service 类型的负载均衡（ClusterIP、NodePort、LoadBalancer、externalIPs、hostPort）。其工作机制包括：

- **Socket LB（cgroup hook）**：在 socket 层拦截 `connect()`、`sendmsg()`、`recvmsg()` 等系统调用，在数据包生成之前就把目标 Service IP 重写为后端 Pod IP，东西向流量因此无需逐包 NAT。
- **TC/接口级 BPF**：对于未经 socket 层的流量，在网卡接口上挂载 BPF 程序做逐包负载均衡。
- **XDP 加速**：对外部入口流量，可在驱动层执行负载均衡以获得极高吞吐。

替代 kube-proxy 的好处包括：避免 iptables 规则链的 O(n) 性能退化、支持 DSR 让后端直接回包给客户端从而保留源 IP、减少集群中需要维护的组件。

### Hubble 可观测性

Hubble 是构建在 Cilium 之上的可观测性层，基于 eBPF 透明采集网络流，无需修改应用。它提供：

- 单节点流可见性：Cilium agent 内默认安装 Hubble CLI，通过本地 Unix socket 查询。
- 集群级 / 多集群可见性：通过 Hubble Relay 聚合多节点流数据。
- 可视化：Hubble UI 自动绘制服务依赖图。

常用命令：

```bash
# 查看 Hubble 健康状态、流速率、已连接节点数
hubble status

# 实时观察网络流（-P 自动 port-forward Hubble Relay 到本地 4245）
hubble observe -P
```

### ClusterMesh

ClusterMesh 让多个 Kubernetes 集群在网络安全策略层面表现为一个整体：跨集群的服务自动发现、统一的身份模型（security identity），以及全局 Service 支持自动故障转移，适用于混合云和容灾场景。

### 加密与 Service Mesh

Cilium 支持基于身份的自动加密（IPsec 或 WireGuard），节点间所有 Pod 流量都可被透明加密而无需应用感知。在 Service Mesh 方面，Cilium 提供「无 sidecar」方案，并可作为 Kubernetes Gateway API 的合规数据面。

## 部署模式

Cilium 的数据平面主要有以下几种组网方式：

- **Overlay 模式**：基于 VXLAN 或 Geneve 封装，只要求节点之间 IP 可达，对底层网络没有特殊要求，是最通用的部署方式。
- **Native routing 模式**：直接使用宿主机的路由表转发，性能更好，可结合云厂商的路由能力或 BGP 守护进程使用。
- **BGP / L2 邻居发现**：在需要跨 L3 边界或对接物理网络时使用，常配合 native routing。

## 快速安装

推荐使用官方 `cilium` CLI 进行安装（会自动根据运行环境做适配）：

```bash
# 安装 cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --fail --remote-name-all \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin

# 一键安装（以具体版本号为准）
cilium install --version 1.19.6
```

安装完成后验证：

```bash
# 查看 Cilium / Operator / Hubble / Relay 状态
cilium status --wait

# 运行内置连通性测试
cilium connectivity test
```

也可以通过 Helm 安装：

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium --namespace kube-system
```

## 与其他 CNI 对比

与同为 Kubernetes 主流 CNI 的 Calico、Flannel 相比，Cilium 的差异主要体现在：

| 维度 | Cilium | Calico | Flannel |
| --- | --- | --- | --- |
| 数据平面 | eBPF | iptables / eBPF（可选） | 内核转发 |
| kube-proxy | 可完全替代 | 默认依赖 | 默认依赖 |
| L7 策略 | 原生支持 | 需 Felix + Istio 等 | 不支持 |
| 可观测性 | Hubble 内建 | 需第三方 | 无 |
| 复杂度 | 较高 | 中 | 低 |

如果集群规模较大、对 Service 转发性能和可观测性要求高、或者希望直接用 eBPF 数据面，Cilium 是更合适的选择；如果只追求简单和快速搭建，Flannel 仍然够用。

## 总结

Cilium 把 eBPF 与 XDP 这两项内核技术运用到了 Kubernetes 网络的几乎每个环节：从 Pod 间路由、Service 负载均衡、L3-L7 安全策略，到 Hubble 提供的可观测性和 ClusterMesh 的多集群连通。理解了 eBPF 多挂载点、XDP 早执行的特性，也就理解了 Cilium 为什么能在不修改应用的前提下做到「高性能 + 细粒度策略 + 全链路可观测」。

## 参考

- [Cilium 官方文档](https://docs.cilium.io/)
- [Cilium GitHub 仓库](https://github.com/cilium/cilium)
- [什么是 eBPF?](https://ebpf.io/what-is-ebpf/)
- [Cilium kube-proxy Replacement](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/)
- [Cilium Hubble](https://docs.cilium.io/en/stable/observability/hubble/)
- [网络插件 cilium（Kubernetes 指南）](https://kubernetes.feisky.xyz/extension/network/cilium)
- [腾讯云 Cilium-Overlay 模式介绍](https://cloud.tencent.com/document/product/457/77964)
