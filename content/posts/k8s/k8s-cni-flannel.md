+++
title = "K8s 网络插件 Flannel"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Flannel 工作原理与 backend 实现"
description = "介绍 K8s CNI 规范及 Flannel 的设计思路、特点、backend 实现与 Calico 对比"
author = "小智晖"
authors = ["小智晖"]
categories = ["Kubernetes"]
tags = ["Kubernetes", "CNI", "Flannel", "网络"]
keywords = ["Flannel", "CNI", "Kubernetes 网络插件", "VXLAN", "host-gw", "覆盖网络"]
toc = true
draft = false
+++

## CNI（Container Network Interface）

CNI 全称为 Container Network Interface，是用来定义容器网络的一个规范。[containernetworking/cni](https://github.com/containernetworking/cni) 是一个 CNCF 的 CNI 实现项目，包括基本的 bridge、macvlan 等基本网络插件。

一般将 CNI 各种网络插件的可执行二进制文件放到 `/usr/libexec/cni/`，在 `/etc/cni/net.d/` 下创建配置文件，剩下的就交给 K8s 或者 containerd 了，我们不关心也不了解其实现。

比如：

```bash
# ls -lh /usr/libexec/cni/
总用量 133M
-rwxr-xr-x 1 root root 4.4M  8月 18 11:51 bandwidth
-rwxr-xr-x 1 root root 4.3M  3月  6  2021 bridge
-rwxr-x--- 1 root root  31M  8月 18 11:51 calico
-rwxr-x--- 1 root root  30M  8月 18 11:51 calico-ipam
-rwxr-xr-x 1 root root  12M  3月  6  2021 dhcp
-rwxr-xr-x 1 root root 5.6M  3月  6  2021 firewall
-rwxr-xr-x 1 root root 3.1M  8月 18 11:51 flannel
-rwxr-xr-x 1 root root 3.8M  3月  6  2021 host-device
-rwxr-xr-x 1 root root 3.9M  8月 18 11:51 host-local
-rwxr-xr-x 1 root root 4.0M  3月  6  2021 ipvlan
-rwxr-xr-x 1 root root 3.6M  8月 18 11:51 loopback
-rwxr-xr-x 1 root root 4.0M  3月  6  2021 macvlan
-rwxr-xr-x 1 root root 4.2M  8月 18 11:51 portmap
-rwxr-xr-x 1 root root 4.2M  3月  6  2021 ptp
-rwxr-xr-x 1 root root 2.7M  3月  6  2021 sample
-rwxr-xr-x 1 root root 3.2M  3月  6  2021 sbr
-rwxr-xr-x 1 root root 2.8M  3月  6  2021 static
-rwxr-xr-x 1 root root 3.7M  8月 18 11:51 tuning
-rwxr-xr-x 1 root root 4.0M  3月  6  2021 vlan

# ls -lh /etc/cni/net.d/
总用量 12K
-rw-r--r-- 1 root root  607 12月 23 09:39 10-calico.conflist
-rw-r----- 1 root root  292 12月 23 09:47 10-flannel.conflist
-rw------- 1 root root 2.6K 12月 23 09:39 calico-kubeconfig
```

**CNI 插件都是直接通过 exec 的方式调用，而不是通过 socket 这样的 C/S 方式，所有参数都是通过环境变量、标准输入输出来实现的。**

## Flannel 简介

Flannel 是 K8s 最常见的 CNI 网络插件之一（注：kubeadm 默认并不内置任何 CNI，需要用户自行安装），其内部实现了 CNI（Container Network Interface），主要用来解决容器跨主机网络通信问题。

Flannel 的设计目的就是为集群中的所有节点重新规划 IP 地址的使用规则，从而使得不同节点上的容器能够获得"同属一个内网"且"不重复的"IP 地址，并让属于不同节点上的容器能够直接通过内网 IP 通信。

Flannel 实质上是一种"覆盖网络（overlay network）"，也就是将 TCP 数据包装在另一种网络包里面进行路由转发和通信。目前已经支持 udp、vxlan、host-gw、WireGuard、IPIP、IPSec 等数据转发方式，默认的节点间数据通信方式是 **VXLAN**。

控制平面上，host 本地的 flanneld 负责从远端的 etcd 集群同步本地及其它 host 上的 subnet 信息，并为 Pod 分配 IP 地址。数据平面，flannel 通过 Backend（比如 VXLAN 封装）来实现 L3 Overlay，既可以选择一般的 TUN 设备又可以选择 VxLAN 设备。

## Flannel 特点

- Flannel 通过给每台宿主机分配一个子网的方式为容器提供虚拟网络，该虚拟网络可基于不同的 Backend 实现，并借助 etcd 维护网络的分配情况。
- 集群中的不同 Node 主机创建的 Docker 容器都具有全集群唯一的虚拟 IP 地址。
- 建立一个覆盖网络（overlay network），通过这个覆盖网络，将数据包原封不动地传递到目标容器。
- 覆盖网络是建立在另一个网络之上并由其基础设施支持的虚拟网络。覆盖网络通过将一个分组封装在另一个分组内来将网络服务与底层基础设施分离。在将封装的数据包转发到端点后，将其解封装。
- 创建一个新的虚拟网卡 flannel.1（VXLAN 模式）接收 docker 网桥的数据，通过维护路由表，对接收到的数据进行封包和转发。
- etcd 保证了所有 Node 上 flanneld 所看到的配置是一致的。同时每个 Node 上的 flanneld 监听 etcd 上的数据变化，实时感知集群中 Node 的变化。
- Flannel 利用各种 backend mechanism（例如 VXLAN、host-gw 等）跨主机转发容器间的网络流量，完成容器间的跨主机通信。

## Flannel backend

- **VXLAN（默认）**：利用内核的 VXLAN 模块实现一个三层的覆盖网络，通过 flannel.1 这个 VTEP（VXLAN Tunnel Endpoints）设备来进行封拆包，然后进行路由转发实现通信。VXLAN 在内核态实现，效率高，是 Flannel 推荐的默认 backend。Linux 上 Flannel 的 VXLAN 默认 UDP 端口为 **8472**（注意：IANA 标准 VXLAN 端口为 4789，Flannel 沿用了早期 Linux 内核的历史端口 8472）。
- **UDP**：基于 Linux TUN/TAP，主要是利用 tun 设备来模拟一个虚拟网络进行通信，使用 UDP 封装 IP 包来创建 overlay 网络。由于 UDP 封装在用户态实现，数据包会从内核态多次拷贝，效率较低，官方建议仅用于调试或非常老旧的、不支持 VXLAN 的内核。默认端口为 8285。
- **host-gw**：直接修改二层网络的路由信息，实现数据包的转发，从而省去中间封装层，通信效率更高，但要求各个节点之间是二层连通的。
- **WireGuard**：使用内核态 WireGuard 进行封装和加密，适合需要加密通信的场景。
- **IPIP / IPSec**：通过内核 IPIP 或 IPSec 封装，IPSec 可借助 Strongswan 提供加密传输。

## 与 Calico 对比

- Flannel 英文释义：法兰绒布
- Calico 英文释义：印花棉布

为什么要用布来为该插件起名呢？猜测是因为布是由一根根丝线织成的，密密麻麻犹如网状。这跟网络通信由一条条看不见的虚拟链路组成在结构上很相似，所以用代表布的单词来命名。

简言之：Flannel 相对简单，只关注 L3 覆盖网络的连通性，配置少、依赖少；Calico 则基于 BGP 实现更丰富的路由能力，并原生支持 NetworkPolicy 做网络隔离，适合对安全策略有更高要求的场景。

## 参考

- [flannel github](https://github.com/flannel-io/flannel)
- [flannel backends](https://github.com/flannel-io/flannel/blob/master/Documentation/backends.md)
- [白话 OSI 七层网络模型](https://www.freecodecamp.org/chinese/news/osi-model-networking-layers/)
- [K8s 指南-Flannel](https://kubernetes.feisky.xyz/extension/network/flannel)
- [云原生虚拟网络之 Flannel 工作原理](https://www.luozhiyun.com/archives/695)
- [循序渐进理解 CNI 机制与 Flannel 工作原理](https://blog.yingchi.io/posts/2020/8/k8s-flannel.html)
- [云原生虚拟网络之 VXLAN 协议](https://www.luozhiyun.com/archives/687)
- [k8s 网络之 Flannel 网络](https://www.cnblogs.com/goldsunshine/p/10740928.html)
- [flannel 网络架构](https://ggaaooppeenngg.github.io/zh-CN/2017/09/21/flannel-%E7%BD%91%E7%BB%9C%E6%9E%B6%E6%9E%84/)
- [理解 flannel 的三种容器网络方案原理](https://www.zhengwenfeng.com/pages/d9d0ce/)
- [kubernetes Flannel 网络剖析](https://plantegg.github.io/2022/01/19/kubernetes_Flannel%E7%BD%91%E7%BB%9C%E5%89%96%E6%9E%90/)
- [一文看懂 Flannel-UDP 在 kubernetes 中如何工作](https://cloud.tencent.com/developer/article/1793755)
- [Linux 下 VxLAN 实践](https://github.com/xujiyou/blog-data/blob/master/Linux/%E7%BD%91%E7%BB%9C/Linux%E4%B8%8BVxLAN%E5%AE%9E%E8%B7%B5.md)
- [Linux 虚拟网络设备之 Bridge](https://github.com/xujiyou/blog-data/blob/master/Linux/%E7%BD%91%E7%BB%9C/Linux%E8%99%9A%E6%8B%9F%E7%BD%91%E7%BB%9C%E8%AE%BE%E5%A4%87%E4%B9%8BBridge.md)
- [Linux 虚拟网络设备 veth-pair 详解，看这一篇就够了](https://www.cnblogs.com/bakari/p/10613710.html)
- [containernetworking/cni（CNCF 项目）](https://github.com/containernetworking/cni)