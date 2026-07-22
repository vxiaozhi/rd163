+++
title = "k8s 网络插件 Calico"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "基于 BGP 的纯三层 Kubernetes 网络与策略方案"
description = "Calico 是基于纯三层路由（BGP）的 Kubernetes CNI 插件，无需 Overlay 即可打通 Pod 网络，并通过 iptables 提供丰富的 NetworkPolicy。本文梳理其核心组件、IPIP 与 BGP 两种模式及不足。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "calico", "cni", "bgp", "ipip", "networkpolicy"]
keywords = ["calico", "cni", "bgp", "ipip", "networkpolicy", "kubernetes"]
toc = true
draft = false
+++

## 简介

Calico 是一个纯三层的数据中心网络方案（不需要 Overlay），与 OpenStack、Kubernetes、AWS、GCE 等 IaaS 和容器平台都有良好的集成。

Calico 在每一个计算节点上利用 Linux Kernel 实现了一个高效的 vRouter 来负责数据转发，而每个 vRouter 通过 BGP 协议把自己上运行的 workload 的路由信息向整个 Calico 网络内传播——小规模部署可以直接互联，大规模下可通过指定的 BGP Route Reflector 来完成集中式分发。这样保证最终所有 workload 之间的数据流量都是通过 IP 路由的方式完成互联的。Calico 节点组网可以直接利用数据中心的网络结构（无论是 L2 或者 L3），不需要额外的 NAT、隧道或 Overlay Network。

此外，Calico 基于 iptables 还提供了丰富而灵活的网络 Policy，通过各个节点上的 ACLs 来提供 Workload 的多租户隔离、安全组以及其他可达性限制等功能。

Calico 主要由 Felix、etcd、BGP Client 以及 BGP Route Reflector 组成：

- **Felix**：Calico Agent，跑在每台需要运行 Workload 的节点上，主要负责配置路由及 ACLs 等信息，确保 Endpoint 的连通状态。
- **etcd**：分布式键值存储，主要负责维护网络元数据一致性，确保 Calico 网络状态的准确性。在 Kubernetes 环境下也可以直接复用 K8s API 作为数据存储（即 "Kubernetes API data store" 模式），从而不再依赖独立 etcd。
- **BGP Client（BIRD）**：主要负责把 Felix 写入 Kernel 的路由信息分发到当前 Calico 网络，确保 Workload 间通信的有效性。
- **BGP Route Reflector（BIRD）**：大规模部署时使用，摒弃所有节点全互联（full-mesh）的模式，通过一个或多个 BGP Route Reflector 来完成集中式的路由分发。
- **calico-ipam**：主要用作 Kubernetes 的 CNI IPAM 插件，负责给 Pod 分配 IP。

## Calico 模式

### IPIP 模式

IPIP（IP-in-IP）是 Calico 历史上最经典的默认网络架构之一（注意：较新的 Calico 版本和托管 Kubernetes 服务已逐步把默认封装切换为 VXLAN，安装时以 manifest/operator 的实际配置为准），它其实也是一种 Overlay 的网络架构，但相比更常用的 VXLAN 模式更加轻量化。IP-in-IP 就是把一个 IP 数据包又套在一个 IP 包里，即把 IP 层封装到 IP 层的一个 tunnel，它的作用基本上相当于一个基于 IP 层的网桥。一般来说，普通的网桥是基于 MAC 层的，根本不需要 IP；而这个 IPIP 则是通过两端的路由建立一个 tunnel，把两个本来不通的网络通过点对点连接起来。

Calico 控制平面的设计原本要求物理网络是 L2 Fabric，这样 vRouter 间都是直接可达的，路由不需要把物理设备当做下一跳。为了支持 L3 Fabric，Calico 推出了 IP-in-IP 的选项。

### BGP 模式

BGP 模式是 Calico 常用的模式，也是它的王牌模式。需要说明的是，虽然 Calico 有 BGP 模式和 IPIP 模式之分，但并不意味着 IPIP 模式就不用建立 BGP 连接——IPIP 模式同样需要建立 BGP 连接（可以通过抓取 179 端口的报文验证），只不过建立 BGP 链接的目标比较清晰，就是对端 `tunl0` 对应的网卡。BGP 模式相对于 IPIP 模式的优点并不是简单的"可以跨节点通信"——IPIP 模式同样可以跨节点通信，只要两个节点能互相连通即可。BGP 的优点在于可以指定 BGP 的对端 Peer（一般是交换机），那么只要能接入这台交换机的 host 或 PC，都能通过路由的方式连通 Calico 其他节点上的容器。也就是说，BGP 的可扩展网络拓扑更灵活。

BGP 模式下数据包的路径单纯依靠路由进行转发，网络拓扑更自由；IP-in-IP 模式则多了一个封包的过程，因此也是一种 Overlay 的方式，封好的包再按照路由进行转发，到达目的节点后还有一个解包的过程，所以比 BGP 模式稍微低效一些。但由于封包比 VXLAN 添加的字段更少，因此比 VXLAN 更高效一些。总体而言，IP-in-IP 模式部署起来相对简单，两者各有利弊。

## Calico 的不足

- 既然是三层实现，原生不支持 VRF。
- 不支持多租户网络的隔离功能，在多租户场景下会有网络安全问题（需要借助 NetworkPolicy 做策略级隔离，或使用 Tigera Calico Enterprise 等商业方案）。

## 参考

- [网络插件 Calico - Kubernetes Handbook](https://kubernetes.feisky.xyz/extension/network/calico)
- [calico 配置步骤——IPIP 模式 vs BGP 模式](https://www.cnblogs.com/janeysj/p/14804986.html)
- [Calico 官方文档](https://docs.tigera.io/calico/latest/about/)
- [Calico GitHub 仓库](https://github.com/projectcalico/calico)
