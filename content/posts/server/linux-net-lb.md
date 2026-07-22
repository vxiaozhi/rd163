+++
title = "Linux 网络负载均衡"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "四层与七层负载均衡原理、LVS 工作模式与 IPVS 调度算法"
description = "梳理 Linux 服务器负载均衡的核心概念:四层与七层均衡的区别、LVS 的 NAT/DR/TUN/FullNAT 工作模式、IPVS 调度算法与 ipvsadm/Keepalived 配合实践。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "load-balancing", "lvs", "ipvs", "network"]
keywords = ["负载均衡", "LVS", "IPVS", "四层负载均衡", "NAT DR TUN", "Keepalived"]
toc = true
draft = false
+++

## 什么是负载均衡

**负载均衡（Load Balancing）** 是指将大量并发请求或数据流量按某种策略分发到多台后端节点上分别处理，从而提升系统的整体吞吐能力、可用性与可扩展性。它的本质是在客户端和服务端之间引入一个"分发层",对外暴露统一入口，对内把流量调度到一组真实服务器。

按 OSI 模型的不同层次，业界通常把负载均衡分为两大类:

- **四层负载均衡（L4 Load Balancing）** :工作在传输层，基于 **IP + 端口** 做转发，只修改目标 IP/端口（或 MAC）,不解析应用层内容，行为更接近路由器，典型代表是 **LVS**。
- **七层负载均衡（L7 Load Balancing）** :工作在应用层，基于 **URL、Host、Cookie、HTTP Header** 等内容做决策，通常会终结客户端连接、再与后端建立新连接，行为更像代理服务器，典型代表是 **Nginx、HAProxy**。

一个直观的类比：四层负载均衡像银行的排号机，只负责把你"分到某个窗口";七层负载均衡像大堂经理，会根据你要办的业务再把你"领到具体的柜台"。两者并不互斥，实际大型架构往往是 **四层做入口分发 → 七层做内容路由 → 后端 RS(Real Server)处理请求**。

## LVS 与 IPVS

**LVS(Linux Virtual Server)** 是由章文嵩博士发起的 Linux 虚拟服务器项目，它通过内核模块 **IPVS(IP Virtual Server)** 实现四层负载均衡，是 Linux 内核（2.4 及以后）自带的负载均衡机制，性能高、稳定性好，广泛应用于国内外大型互联网站点。

理解 LVS，需要先熟悉几个核心术语:

| 术语 | 含义 |
|------|------|
| **DS / Director Server** | 负载均衡调度器，LVS 流量的入口 |
| **RS / Real Server** | 真实提供服务的后端服务器 |
| **VIP** | Director 对外提供的虚拟 IP，客户端访问的目标 IP |
| **DIP** | Director 用于与 RS 通信的 IP |
| **RIP** | Real Server 的真实 IP |
| **CIP** | Client IP，客户端的源 IP |

IPVS 工作在内核的 Netfilter INPUT 链上，对命中规则的连接按选定的调度算法和转发方式分发到后端 RS。用户态工具 **`ipvsadm`** 用于配置 IPVS 规则,**`Keepalived`** 则在 IPVS 之上提供健康检查与 VRRP 高可用。

## LVS 的三种工作模式

LVS 通过不同的"报文转发方式"形成几种典型模式，理解它们的差异是选型的关键。

### NAT 模式

NAT(Network Address Translation)模式基于 DNAT + SNAT 实现。Director 收到客户端请求后，把目标 IP 由 VIP 改写为某台 RS 的 RIP 并转发;RS 处理完返回响应时，响应报文必须再次经过 Director，由它把源 IP 从 RIP 改回 VIP。

- **特点**:请求和响应都经过 Director,Director 容易成为性能瓶颈;支持端口映射（VIP:80 可映射到 RIP:8080）;RS 的默认网关必须指向 DIP。
- **适用场景**:RS 规模不大、流量适中的场景。

### DR 模式（直接路由）

**DR(Direct Routing)** 是 LVS 的**默认转发方式**(`ipvsadm -g`),也是生产中最常用的模式。Director 收到请求时，只改写以太网帧的 **目标 MAC 地址**,把报文二层转发给选中的 RS;VIP 同时配置在 Director 和每台 RS 的 `lo`(loopback)接口上，因此 RS 能直接识别并处理 VIP 报文。响应报文由 RS 直接通过自己的网关返回客户端,**不再经过 Director**。

- **特点**:响应不经过 Director，吞吐高、性能好;但要求 Director 与 RS 处于 **同一个二层网络（同一广播域）**;不支持端口映射。
- **关键细节**:必须在 RS 上抑制 ARP 应答，避免多台机器同时回应 VIP 的 ARP 请求导致 IP 冲突，通常通过设置 `arp_ignore=1`、`arp_announce=2` 实现。

### TUN 模式（IP 隧道）

**TUN(IP Tunneling)** 模式使用 **IPIP** 隧道封装:Director 把原始 IP 报文外层再封装一个新的 IP 头（源 DIP、目的 RIP）发给 RS,RS 解封装后得到原始 VIP 报文进行处理。响应同样直接由 RS 返回客户端，不经过 Director。

- **特点**:Director 与 RS **可以跨网段**,只要三层可达即可，适合跨机房、异地节点;不支持端口映射;RS 需要支持 IPIP 隧道协议。
- **适用场景**:RS 地理分布较远、需要跨网络调度的环境。

### FullNAT 模式（扩展）

**FullNAT(Full Network Address Translation)** 是阿里巴巴在标准 NAT 基础上的扩展模式。它在 CIP↔VIP 与 LIP↔RIP 之间引入一个 **Local IP(LIP)**,同时做 SNAT 和 DNAT，使得 Director 与 RS **只要三层可达即可部署**,不再要求 RS 把 Director 配成网关。FullNAT 还引入 SYNPROXY 机制以缓解 SYN flood 攻击。

需要注意的是，FullNAT **未进入 Linux 主线内核**,需要单独打补丁，使用前需评估维护成本。

### 四种模式对比

| 维度 | NAT | DR | TUN | FullNAT |
|------|-----|----|-----|---------|
| 转发方式 | 改 IP(DNAT+SNAT) | 改 MAC | IP 隧道封装 | SNAT+DNAT+LIP |
| 响应是否过 DS | 是 | 否 | 否 | 是 |
| 网络要求 | 同子网，RS 网关指向 DS | 同二层广播域 | 三层可达即可 | 三层可达即可 |
| 端口映射 | 支持 | 不支持 | 不支持 | 支持 |
| RS 是否需特殊配置 | 否 | 抑制 ARP + VIP on lo | 支持 IPIP + VIP on lo | 否 |
| 是否进主线内核 | 是 | 是 | 是 | 否 |

## IPVS 调度算法

调度算法（Scheduler）决定了"新连接应该交给哪台 RS"。IPVS 内置了多种调度算法，可以在 `ipvsadm` 中通过 `-s` 指定，默认是 **`wlc`(加权最少连接)**:

| 算法 | 说明 |
|------|------|
| **rr** | 轮询（Round Robin）,依次把请求分给每台 RS |
| **wrr** | 加权轮询（Weighted RR）,按权重比例分配，权重高的分得多 |
| **lc** | 最少连接（Least Connection）,优先分给当前活跃连接最少的 RS |
| **wlc** | 加权最少连接，在 lc 基础上结合权重，默认算法 |
| **sh** | 源地址哈希（Source Hashing）,相同 CIP 持续命中同一 RS，实现会话保持 |
| **dh** | 目标地址哈希（Destination Hashing）,常用于缓存集群 |
| **lblc / lblcr** | 基于局部性的最少连接（带/不带复制）,适合 Cache 场景 |
| **sed** | 最短期望延迟（Shortest Expected Delay） |
| **nq** | Never Queue，有空闲 RS 立即分配，否则按 sed |
| **mh** | Maglev 哈希，Google 提出的一致性哈希算法 |

如果业务需要会话保持（同一用户始终命中同一台 RS）,`sh` 或 `-p` 持久化选项是常见选择。

## ipvsadm 配置示例

`ipvsadm` 是 IPVS 的用户态管理工具。常用参数:`-A` 增加虚拟服务、`-a` 添加 RS、`-t`/`-u` 指定 TCP/UDP、`-s` 指定调度算法、`-m`/`-g`/`-i` 指定 NAT/DR/TUN 转发方式、`-w` 指定权重、`-p` 开启持久化。

```bash
# 1. 在 Director 上添加一个 VIP:80 的 TCP 虚拟服务,使用 wrr 调度
ipvsadm -A -t 192.168.1.100:80 -s wrr

# 2. 以 DR 模式(-g)添加两台 Real Server,并设置权重
ipvsadm -a -t 192.168.1.100:80 -r 192.168.1.11:80 -g -w 1
ipvsadm -a -t 192.168.1.100:80 -r 192.168.1.12:80 -g -w 2

# 3. 查看规则与连接状态
ipvsadm -Ln
ipvsadm -Ln --stats

# 4. 开启持久化(同一客户端在 300s 内命中同一 RS)
ipvsadm -A -t 192.168.1.100:80 -s rr -p 300
```

DR 模式下，RS 侧还需要做两件事：把 VIP 绑定到 `lo:0`,以及抑制 ARP:

```bash
# 在每台 RS 上执行
ifconfig lo:0 192.168.1.100 netmask 255.255.255.255 broadcast 192.168.1.100 up
route add -host 192.168.1.100 dev lo:0

echo 1 > /proc/sys/net/ipv4/conf/all/arp_ignore
echo 1 > /proc/sys/net/ipv4/conf/lo/arp_ignore
echo 2 > /proc/sys/net/ipv4/conf/all/arp_announce
echo 2 > /proc/sys/net/ipv4/conf/lo/arp_announce
```

手动用 `ipvsadm` 维护规则过于繁琐，生产环境几乎都配合 **Keepalived** 自动管理。

## Keepalived:高可用 + 健康检查

**Keepalived** 是构建在 IPVS 之上的高可用与负载均衡框架，以单一守护进程同时提供三类能力:

- **VRRP(Virtual Router Redundancy Protocol)**:实现多台 Director 之间的主备/主主切换，主节点故障时 VIP 自动漂移到备节点，实现 LVS 自身的高可用。
- **Health Check(健康检查)**:对 RS 池做 L4(TCP 端口)到 L7(HTTP)的探测，自动剔除故障 RS、恢复时再加回，保证流量只发给健康节点。
- **IPVS 配置管理**:根据配置文件动态维护 IPVS 规则，免去手动维护 `ipvsadm` 规则的负担。

一个最简的 Keepalived 配置示意:

```conf
vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1
    virtual_ipaddress {
        192.168.1.100
    }
}

virtual_server 192.168.1.100 80 {
    delay_loop 6
    lb_algo wrr
    lb_kind DR
    protocol TCP

    real_server 192.168.1.11 80 {
        weight 1
        TCP_CHECK { connect_port 80 connect_timeout 3 }
    }
    real_server 192.168.1.12 80 {
        weight 2
        TCP_CHECK { connect_port 80 connect_timeout 3 }
    }
}
```

## 选型与实践小结

- **纯四层、超高吞吐**:优先 LVS/DR，配 Keepalived 做高可用。
- **需要内容路由、HTTPS 卸载、灰度**:用 Nginx/HAProxy 等七层负载均衡。
- **跨机房/异地多活**:可考虑 LVS/TUN 或 FullNAT，或叠加 GSLB 在 DNS 层调度。
- **常见组合**:`GSLB(选机房) → LVS(四层入口) → Nginx/HAProxy(七层路由) → RS`。

LVS 给了 Linux 一套内核级、性能稳定的四层负载均衡能力，理解它的三种工作模式、IPVS 调度算法以及与 Keepalived 的配合方式，是构建高可用服务架构的基础。

## 参考

- [负载均衡-lvs(tonydeng/sdn-handbook)](https://tonydeng.github.io/sdn-handbook/linux/loadbalance.html)
- [linux 负载均衡总结性说明（四层负载/七层负载）](https://www.cnblogs.com/kevingrace/p/6137881.html)
- [Linux 集群总结 + LVS(负载均衡器)原理及配置](https://cloud.tencent.com/developer/article/1644903)
- [Linux Virtual Server - Wikipedia](https://en.wikipedia.org/wiki/Linux_Virtual_Server)
- [ipvsadm(8) - Linux man page](https://www.mankier.com/8/ipvsadm)
- [Keepalived 官方网站](https://www.keepalived.org/)
- [黑石 5.0 - 网络架构设计](https://docs.qq.com/slide/DSHpBV1pmWEVvY05D)
