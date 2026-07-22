+++
title = "Linux GRE 隧道配置与原理"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Generic Routing Encapsulation 在 Linux 内核中的实现与运维实践"
description = "介绍 GRE(Generic Routing Encapsulation)协议原理与 Linux 下基于 iproute2 的隧道配置,涵盖点对点隧道、内核收发路径、持久化与常见排错。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "gre", "tunnel", "vpn", "networking", "iproute2"]
keywords = ["GRE", "Linux GRE", "GRE 隧道", "ip tunnel", "RFC 2784", "GRE over IPsec"]
toc = true
draft = false
+++

GRE(Generic Routing Encapsulation，通用路由封装)是一种轻量、通用的三层隧道协议，能够在一个网络层协议之上承载"任意"网络层协议的报文。它由 Cisco 提出，核心规范为 RFC 2784，后续被 RFC 2890(扩展 Key 与序号字段)和 RFC 9601 更新。Linux 内核原生支持 GRE(`ip_gre` 模块),配合 iproute2 工具集即可在两台主机之间建立点对点隧道，常用于跨网络打通私网、与 IPsec 组合提供带路由能力的 VPN，或在云网络（如早期 OpenStack Neutron + OVS）中承载租户流量。

## 协议原理

### 报文结构

GRE 报文由三部分组成:**Delivery Header(外层封装头，通常为 IPv4/IPv6)+ GRE Header + Payload(内层报文)**。

GRE Header 最小为 4 字节，结构如下（RFC 2784）:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|C|       Reserved0       | Ver |         Protocol Type         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|      Checksum (optional)      |       Reserved1 (optional)    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

关键字段含义:

- **C(Checksum Present)**:1 bit，置位表示后面携带 Checksum 与 Reserved1，共额外 4 字节。
- **Ver**:3 bit,RFC 2784 中 MUST 为 `0`;`1` 用于 PPTP(RFC 2637)。
- **Protocol Type**:2 字节，标识内层协议的 EtherType，例如 IPv4 为 `0x0800`,IPv6 为 `0x86DD`。
- **Checksum / Reserved1**:可选，仅当 C=1 时存在。

RFC 2890 在此基础上扩展了两个可选字段:**Key(4 字节，用于标识一条逻辑流量)** 与 **Sequence Number(4 字节，提供尽力而为的有序交付)**。注意 RFC 2890 明确指出 "Key 字段不参与任何形式的安全",需要 IPsec(ESP/AH)来保护 GRE 与载荷。

### IP 协议号

当外层为 IPv4 时，GRE 对应的 IP 协议号（Protocol Number）为 **47**。这是一个协议号而非端口号，在防火墙放行时需要按协议放行而不是按端口放行。

### 封装开销与 MTU

GRE 至少增加 4 字节 GRE Header + 20 字节 IPv4 外层头，共 **24 字节**。因此点对点 GRE 隧道接口的默认 MTU 通常设为 **1476**(1500 − 24)。若启用 checksum 或 key，开销还会增加，需要相应下调。

## Linux 内核中的 GRE

Linux 将 GRE 视为一个虚拟网络设备（tunnel device）,从内核视角看近似"第四层协议"。报文的发送与接收路径如下:

- **发送路径**:路由判定下一跳是隧道设备(如 `gre1`)后，通过 `ndo_start_xmit` 回调进入 `ipgre_tunnel_xmi()`。该函数构造新的外层 IP 头，填入 local/remote 地址，设置协议类型为 `IPPROTO_GRE`,然后将封装后的报文重新送回 IP 栈向外发送。
- **接收路径**:对端收到 IP 协议号为 47 的报文，内核将其交付 GRE 模块，由 `ipgre_rcv()` 根据外层地址与 key 匹配到对应的隧道，剥除外层头后将内层报文重新注入 IP 协议栈按普通报文转发。

GRE 的内核模块为 `ip_gre`,通常在新内核中按需自动加载;若未自动加载可手动 `modprobe ip_gre`。

## 点对点 GRE 隧道配置

### 拓扑示例

两台跨公网主机，通过 GRE 隧道互连私网:

| 主机 | 公网 IP | 隧道 IP |
|------|---------|---------|
| Host A | `198.51.100.10` | `10.0.0.1/30` |
| Host B | `203.0.113.20` | `10.0.0.2/30` |

### 在 Host A 上配置

```bash
# 创建 GRE 隧道接口
ip tunnel add gre1 mode gre \
    local 198.51.100.10 \
    remote 203.0.113.20 \
    ttl 64

# 配置隧道接口 IP 并启用
ip addr add 10.0.0.1/30 dev gre1
ip link set gre1 up
```

等价的 `ip link add ... type gre` 写法:

```bash
ip link add gre1 type gre \
    local 198.51.100.10 \
    remote 203.0.113.20 \
    ttl 64
ip addr add 10.0.0.1/30 dev gre1
ip link set gre1 up
```

### 在 Host B 上配置（对称）

```bash
ip tunnel add gre1 mode gre \
    local 203.0.113.20 \
    remote 198.51.100.10 \
    ttl 64
ip addr add 10.0.0.2/30 dev gre1
ip link set gre1 up
```

### 验证连通性

```bash
ping -I gre1 10.0.0.2        # 通过隧道 ping 对端
ip tunnel show               # 查看隧道列表
ip -d link show gre1         # 查看隧道详细信息
tcpdump -n -i any proto 47   # 抓取 GRE 报文(IP 协议号 47)
```

## 常用参数

`ip-tunnel(8)` 列出了 GRE 特有的参数，运维中较常用的几个:

| 参数 | 说明 |
|------|------|
| `local` / `remote` | 隧道两端的源/目的（外层）IP。 |
| `ttl` | 外层 IP 的 TTL，推荐设为 64，避免隧道报文在环路上无限循环。 |
| `key` / `ikey` / `okey` | 启用 Keyed GRE，用于在同一对外层 IP 间复用多条隧道;`key` 双向相同,`ikey`/`okey` 可分别设置。注意它不是安全凭证。 |
| `csum` / `icsum` / `ocsum` | 启用校验和，分别对应双向/接收/发送。 |
| `seq` / `iseq` / `oseq` | 序列号。man 手册明确警告:"It doesn't work. Don't use it." 实践中应避免使用。 |
| `tos` | 外层 IP 的 TOS/DSCP，可设为 `inherit` 继承内层报文。 |
| `nopmtudisc` | 关闭路径 MTU 发现;开启时设 `ignore-df` 可避免报文因 DF 位被丢弃。 |

### GRE over IPsec 的常见组合

GRE 自身不提供加密与认证，在跨不可信网络时通常与 IPsec 配合。常用方式是用 `key` 标识多条隧道，再用 IPsec transport 模式对 IP 协议 47 进行加密:

```bash
ip tunnel add gre1 mode gre \
    local 198.51.100.10 remote 203.0.113.20 \
    key 1234 ttl 64
```

这种"GRE over IPsec"组合相比纯 IPsec tunnel 模式的优势在于:GRE 接口是真实路由实体，可以运行动态路由协议（OSPF/BGP）、承载组播与广播。

### gretap:二层桥接

标准的 `gre` 是三层接口，只承载 IP 报文。如果需要在隧道上透传以太网帧（例如桥接两个二层网络）,可以使用 `gretap`:

```bash
ip link add gretap1 type gretap \
    local 198.51.100.10 remote 203.0.113.20
ip link set gretap1 up
# 之后可将 gretap1 加入 bridge,与其它二层口共同学习 MAC
```

## 持久化配置

手动 `ip` 命令在重启后会丢失，需写入发行版的网络配置。

### Debian/Ubuntu(`/etc/network/interfaces`)

```
auto gre1
iface gre1 inet static
    address 10.0.0.1
    netmask 255.255.255.252
    pre-up ip tunnel add gre1 mode gre \
        local 198.51.100.10 remote 203.0.113.20 ttl 64
    post-down ip tunnel del gre1
```

### systemd-networkd

`/etc/systemd/network/10-gre1.netdev`:

```
[NetDev]
Name=gre1
Kind=gre
MTUBytes=1476

[Tunnel]
Local=198.51.100.10
Remote=203.0.113.20
TTL=64
```

`/etc/systemd/network/10-gre1.network`:

```
[Match]
Name=gre1

[Address]
Address=10.0.0.1/30
```

## GRE vs VxLAN

GRE 与 VxLAN 都用于 overlay 网络，但定位不同。GRE 是有状态（point-to-point）的三层隧道，实现简单、开销小;VxLAN 则基于无状态的 UDP 封装，使用 24 位 VNI(VXLAN Network Identifier),配合组播或 EVPN 进行 VTEP 学习，可在大规模二层互联（如数据中心跨机架 VM 迁移）中替代受 4094 上限制约的 VLAN。在 Linux 上两者都由内核原生支持，选择哪种取决于是否需要大二层的多播/广播能力。

## 排错要点

- **不通先查外层**:确认两端的 `local`/`remote` 反向对称,`ping` 外层 IP 能通。
- **防火墙**:GRE 是 IP 协议 47，不是端口。iptables/nftables、云厂商安全组、运营商 NAT 都可能丢弃它。例如 iptables 放行写法为 `iptables -I INPUT -p 47 -j ACCEPT`。
- **NAT 穿透**:GRE 不易穿越 NAT，因为 NAT 设备通常不会维护协议 47 的会话表。需要穿越 NAT 时，优先考虑 GRE-over-UDP、WireGuard 或 OpenVPN。
- **MTU / 分片**:隧道接口默认 MTU 1476，若上层应用设置了 DF 位且报文过大，可能因 `icmp frag needed` 被丢弃。必要时调小内层 MTU 或开启 `nopmtudisc` + `ignore-df`。
- **Keyed GRE 不匹配**:用 `ip -d link show gre1` 核对 key/ikey/okey 是否与对端反向一致。

## 参考

- [RFC 2784 - Generic Routing Encapsulation](https://www.rfc-editor.org/rfc/rfc2784)
- [RFC 2890 - Key and Sequence Number Extensions to GRE](https://www.rfc-editor.org/rfc/rfc2890)
- [ip-tunnel(8) man page](https://man7.org/linux/man-pages/man8/ip-tunnel.8.html)
- [Linux内核之GRE处理分析](https://abcdxyzk.github.io/blog/2022/11/27/kernel-gre/)
- [linux 下创建GRE隧道](https://www.cnblogs.com/weifeng1463/p/6806204.html)
- [通用路由封装协议GRE](https://www.cnblogs.com/HByang/p/17351537.html)
- [GRE与VxLAN网络详解](https://www.cnblogs.com/xingyun/p/4620727.html)
