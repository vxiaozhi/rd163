+++
title = "Linux 网络命名空间"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "容器网络的内核基石:从 ip netns 到 veth 连通"
description = "介绍 Linux 网络命名空间(network namespace)的内核原理、常用 ip netns/unshare/nsenter 命令,以及通过 veth 对打通两个命名空间的完整示例。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "linux", "network", "namespace", "容器"]
keywords = ["网络命名空间", "network namespace", "ip netns", "veth", "nsenter", "容器网络"]
toc = true
draft = false
+++

网络命名空间（network namespace，常缩写为 netns）是 Linux 内核提供的一种资源隔离机制。它让不同进程看到完全独立的网络栈：网卡接口、路由表、防火墙规则、ARP 表、端口号乃至 `/proc/net` 与 `/sys/class/net` 的视图，彼此互不干扰。

网络命名空间是 Docker、Kubernetes、LXC 等容器技术能够"各自联网"的底层基石。理解它，几乎是理解容器网络的必经之路。本文整理核心概念、常用命令，以及一个用 veth 对连接两个命名空间的最小示例。

## 内核背景

Linux 的 namespace 体系是逐步构建起来的。最早出现的挂载命名空间（mount namespace）可追溯到内核 2.4.19(2002 年),而网络命名空间主要在 **内核 2.6.24(2008 年 1 月发布)** 合入。它与 PID 命名空间落在同一个版本，标志着 Linux 在容器化方向上具备了一组完整的"基础隔离原语"。

涉及的系统调用和标志位:

- `clone(CLONE_NEWNET)`:创建子进程时一并新建网络命名空间。
- `unshare(CLONE_NEWNET)`:让调用进程脱离当前网络命名空间，进入一个新的。
- `setns(fd, CLONE_NEWNET)`:把调用进程加入到一个已存在的命名空间,`fd` 指向 `/proc/<PID>/ns/net` 这个符号链接。

其他 namespace 类型同样按 `CLONE_NEW*` 命名，如 `CLONE_NEWPID`、`CLONE_NEWNS`、`CLONE_NEWUSER`、`CLONE_NEWCGROUP`、`CLONE_NEWTIME` 等。

## 一个新命名空间里有什么

新建一个网络命名空间后，它默认**只有一张 `lo`(loopback)回环网卡，且状态为 DOWN**。除此之外没有路由、没有 iptables 规则、没有任何对外通路。这意味着：任何想要联网的程序，都要先把 `lo` 拉起来，再通过其它手段（把物理/虚拟网卡挪进来、走 veth、走 macvlan 等）打通外部连接。

```bash
# 进入一个全新的网络命名空间
sudo unshare -n /bin/bash

# 命名空间内查看接口:只有 lo,且为 DOWN
ip link show
# 1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT group default qlen 1000

# 拉起回环口
ip link set lo up
```

需要注意,`unshare -n` 只隔离网络。如果想让进程同时拥有独立的 PID 树，需要追加 `--fork --pid`,即 `unshare -n --fork --pid /bin/bash`。

## 常用命令

`iproute2` 提供了非常友好的 `ip netns` 子命令，本质上是对 `unshare`/`nsenter` 的一层封装，并通过 **bind mount 到 `/var/run/netns/`** 让命名空间"持久化"(否则只有当还有进程引用时才存在)。

| 命令 | 作用 |
| --- | --- |
| `ip netns add NAME` | 新建持久化命名空间 |
| `ip netns list` | 列出已存在的命名空间 |
| `ip netns exec NAME CMD...` | 在指定命名空间内执行命令(底层用 `nsenter`) |
| `ip netns del NAME` | 删除命名空间（其中的网卡会自动销毁） |
| `ip netns identify PID` | 反查某个 PID 所在的命名空间名 |
| `ip netns pids NAME` | 列出位于该命名空间中的所有 PID |

与之相对的两个底层工具:

- `unshare` — 用于**新建**命名空间，底层是 `unshare(2)`。
- `nsenter` — 用于**进入**已存在的命名空间，底层是 `setns(2)`。

```bash
# 用 nsenter 通过 /proc 进入某个进程的网络命名空间
sudo nsenter -t <PID> -n /bin/bash

# 等价写法:直接通过符号链接
sudo nsenter --net=/proc/<PID>/ns/net /bin/bash
```

查看某个进程所属的命名空间，可以读 `/proc/<PID>/ns/net` 符号链接，冒号后的 inode 号是内核识别该命名空间的唯一标识:

```bash
ls -l /proc/<PID>/ns/net
# lrwxrwxrwx ... /proc/1234/ns/net -> net:[4026531956]
```

## 最小示例：用 veth 对打通两个命名空间

veth(virtual ethernet)是一对虚拟网卡，从一端塞进去的包会从另一端出来，像一根虚拟网线。把两端分别放进不同的网络命名空间，就构成了命名空间之间通信的最简模型。

下面演示创建 `ns1` 和 `ns2`,各放一张 veth，配置同网段 IP，然后用 `ping` 验证连通性。

```bash
# 1. 创建两个命名空间
sudo ip netns add ns1
sudo ip netns add ns2

# 2. 创建一对 veth:veth0 <--> veth1
sudo ip link add veth0 type veth peer name veth1

# 3. 把两端分别挪到两个命名空间
sudo ip link set veth0 netns ns1
sudo ip link set veth1 netns ns2

# 4. 在 ns1 内配 IP、拉起接口和回环
sudo ip netns exec ns1 ip addr add 10.0.0.1/24 dev veth0
sudo ip netns exec ns1 ip link set veth0 up
sudo ip netns exec ns1 ip link set lo up

# 5. 在 ns2 内做同样的事
sudo ip netns exec ns2 ip addr add 10.0.0.2/24 dev veth1
sudo ip netns exec ns2 ip link set veth1 up
sudo ip netns exec ns2 ip link set lo up

# 6. 验证连通性
sudo ip netns exec ns1 ping 10.0.0.2

# 7. 验证 TCP 服务
sudo ip netns exec ns1  nc -l 9000            # 起 TCP 服务
sudo ip netns exec ns2  nc 10.0.0.1 9000      # 从 ns2 连过来

# 8. 清理(网卡会随命名空间一并销毁)
sudo ip netns del ns1
sudo ip netns del ns2
```

如果两个命名空间处于**不同子网**(例如 `10.0.1.0/24` 和 `10.0.2.0/24`),默认路由表里只有各自的直连路由，无法直接互通。这时需要用 `ip route add` 给双方互相加一条指向对端子网的路由，把 veth 对端当作下一跳。

抓包调试同样可以在命名空间内进行，例如 `sudo ip netns exec ns1 tcpdump -ni veth0`,这对学习容器网络、排查 CNI 问题非常有用。

## 与容器网络的关系

Docker 默认的 bridge 网络模型，本质上就是把上述步骤工业化：在宿主机上创建一个 Linux bridge(如 `docker0`,典型地址 `172.17.0.1/16`),每启动一个容器就创建一对 veth，一端挪进容器的 netns 改名为 `eth0`,另一端挂在 `docker0` 上。同主机容器互访走 bridge 二层转发，出网走宿主机的 NAT(`iptables -t nat ... MASQUERADE`),并需要打开 `net.ipv4.ip_forward=1`。Kubernetes 的 CNI 插件（Calico、Flannel、Cilium 等）同样以 netns + veth 为基础，只是拓扑更复杂（叠加 overlay 或 BGP 路由）。

理解了上面这套最小模型，容器网络的"魔法"就剥去了一大半。

## 常见踩坑

- **回环口默认 DOWN**:新 netns 内的 `lo` 一定要 `ip link set lo up`,否则 `127.0.0.1` 都不通，很多程序启动就会失败。
- **无外网**:刚创建的命名空间没有默认路由，需要 veth + bridge + NAT 或 macvlan 才能出网。
- **命名空间生命周期**:不通过 `ip netns add` 持久化的命名空间，只在没有进程引用时自动销毁;`ip netns add` 的本质是把命名空间 bind mount 到 `/var/run/netns/` 下，从而保留一个引用。
- **权限**:创建网络命名空间通常需要 `CAP_SYS_ADMIN`(或 root);用户命名空间(`CLONE_NEWUSER`)从内核 3.8 起允许非特权用户使用，因此在用户命名空间内创建其它命名空间可以不需要 root，具体取决于 `kernel.unprivileged_userns_clone` 等系统参数。

## 参考

- [理解 Linux 网络命名空间 — 阳明的博客](https://www.qikqiak.com/post/learn-linux-net-namespace/)
- [linux 网络虚拟化:network namespace 简介 — Cizixs Walks](https://cizixs.com/2017/02/10/network-virtualization-network-namespace/)
- [一文吃透 Linux nsenter — Leon Hwang's Blogs](https://asphaltt.github.io/post/linux-how-nsenter-works/)
- Linux 手册页:`ip-netns(8)`、`unshare(1)`、`nsenter(1)`、`unshare(2)`、`setns(2)`、`clone(2)`
