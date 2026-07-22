+++
title = "tproxy（透明代理）"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Linux 内核透明代理机制与同名工具辨析"
description = "解析 Linux TPROXY 的工作原理、iptables 配置与 IP_TRANSPARENT 套接字选项,并澄清两个易混淆的同名项目。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "proxy", "tproxy", "transparent-proxy", "iptables", "linux"]
keywords = ["tproxy", "transparent proxy", "iptables", "IP_TRANSPARENT", "透明代理", "linux"]
toc = true
draft = false
+++

## 什么是透明代理

[tproxy](https://www.kernel.org/doc/html/latest/networking/tproxy.html) 即 transparent（透明）proxy。这里的 transparent 有两层含义：

- **对 client（客户端）透明**：客户端无需任何额外配置，既不必修改请求地址，也不必采用代理协议与代理服务器协商。相比之下，socks 或 http 代理都需要在客户端显式设置代理地址，并在发起请求时通过代理协议告知代理服务器真实的目标地址。
- **对 server（服务端）透明**：服务端看到的是 client 端的地址，而非 proxy 的地址，仿佛请求从未经过中转。

换句话说，在一条透明的链路里，两端都不知道代理的存在。这与传统代理协议（如 HTTP CONNECT、SOCKS5）形成鲜明对比，后者要求应用感知代理并主动与之交互。

## 透明代理的实现思路

实现透明代理有两种典型方式：

1. **基于 NAT（Network Address Translation）的方案**：使用 iptables 的 `REDIRECT` 或 `DNAT` 目标改写数据包的目的地址，将流量转发到本地代理端口。这种方式实现简单，但会改写包头，代理无法直接获取原始目的地址。对 UDP 而言恢复原始地址尤其困难，对 TCP 也存在竞态问题。
2. **TPROXY 内核模块**：Linux 内核从 2.2 时代起就支持透明代理，当前实现位于 `xt_TPROXY` 模块中。它不依赖 NAT，在 mangle 表的 `PREROUTING` 链上把数据包打上 mark（标记）并交给本地 socket，从而完整保留原始的源地址和目的地址。

由于 TPROXY 不改写包头，代理进程可以直接从拦截到的 socket 上读到原始目的地址，再决定如何转发。这也是 Istio Ambient、Squid、V2Ray/Xray 等项目优先选择 TPROXY 的根本原因。

## TPROXY 的工作原理

根据 [Linux 内核文档](https://docs.kernel.org/networking/tproxy.html)，TPROXY 的运行依赖三个组件协同：iptables（或 nftables）、策略路由（policy routing），以及应用本身。

### 1. 用 iptables 拦截并打标

在 mangle 表的 `PREROUTING` 链上匹配目标端口，使用 `-j TPROXY` 把包交给代理：

```bash
iptables -t mangle -N DIVERT
iptables -t mangle -A PREROUTING -p tcp -m socket --transparent -j DIVERT
iptables -t mangle -A DIVERT -j MARK --set-mark 1
iptables -t mangle -A DIVERT -j ACCEPT

iptables -t mangle -A PREROUTING -p tcp --dport 80 -j TPROXY \
  --tproxy-mark 0x1/0x1 --on-port 50080
```

其中：

- `--tproxy-mark`：给匹配到的数据包打上 mark，用于后续策略路由；
- `--on-port`：指定本地代理进程监听的端口（这里是 50080）。

### 2. 用策略路由把流量交给本地

打了 mark 的包默认会被按正常路由表转发，必须显式把它导向 loopback（回环接口），内核才能把它送进本地 socket：

```bash
ip rule add fwmark 1 lookup 100
ip route add local 0.0.0.0/0 dev lo table 100
```

这两条命令的含义是：所有带 `fwmark 1` 的数据包查询路由表 100，而该表把所有 IPv4 地址都视为本地地址，于是包被送进 `lo` 接口。

### 3. 应用侧设置 IP_TRANSPARENT

应用不能像普通服务那样直接 `bind`——因为它要接收目的地址并非本机的连接。在创建监听 socket 前，必须开启 `IP_TRANSPARENT` 选项（C 示例）：

```c
int value = 1;
setsockopt(fd, SOL_IP, IP_TRANSPARENT, &value, sizeof(value));
```

在 Go 中等价于：

```go
syscall.SetsockoptInt(fd, syscall.SOL_IP, syscall.IP_TRANSPARENT, 1)
```

启用后，应用既能 bind 到非本机地址接收连接，也能以客户端原始的源地址对外发起连接（这一特性在二次代理场景下非常关键）。

### 内核配置依赖

TPROXY 不是默认开启的，需要内核启用相应选项：

- iptables 路径：`NETFILTER_XT_MATCH_SOCKET`、`NETFILTER_XT_TARGET_TPROXY`；
- nftables 路径（Linux 4.18+）：`NFT_SOCKET`、`NFT_TPROXY`；
- 还需要启用策略路由（policy routing）支持。

主流发行版默认内核一般都已经打开这些选项，云上定制内核则需自行确认。

## 典型应用场景

- **Squid 缓存代理**：在 `configure` 时加 `--enable-linux-netfilter`，并在监听端口上开启 `tproxy` 选项，即可对 80/443 流量做透明缓存与过滤。
- **Istio Ambient 模式**：从 1.18 版本开始引入的无 sidecar 模型，正是用 TPROXY 把 Pod 流量劫持到 `ztunnel`（端口 15001），再通过 HBONE 隧道（HTTP-Based Overlay Network Environment）做 mTLS 转发。由于不依赖 NAT，ztunnel 能直接拿到原始目的地址进行路由决策。
- **科学上网客户端**：V2Ray、Xray、Clash 等在透明网关部署时，常配合 TPROXY 拦截局域网内所有 TCP/UDP 流量并交给本地代理进程。
- **go-zero 调试**：在 [go-tproxy](https://github.com/KatelynHaworth/go-tproxy) 这类库的帮助下，可以方便地写出自己的透明代理工具。

## 注意辨析：两个同名 tproxy 项目

GitHub 上有两个名字都叫 tproxy 的项目，但意义截然不同，初学者很容易混淆：

### KatelynHaworth/go-tproxy:真正的透明代理库

[KatelynHaworth/go-tproxy](https://github.com/KatelynHaworth/go-tproxy) 是一个 Go 编写的 Linux Transparent Proxy 库，是对前面描述的内核 TPROXY 机制的封装。它屏蔽了 socket 选项与 iptables 细节，让用户态程序能够轻松透明代理流量，且不引入 conntrack（连接追踪）开销。仓库内附带了完整的 iptables + 路由配置示例，TCP 与 UDP 都已支持。

### kevwan/tproxy:TCP 连接分析工具

[kevwan/tproxy](https://github.com/kevwan/tproxy) 虽然名字也叫 tproxy，但**它实现的并不是透明代理**，而是一个用于代理和分析 TCP 连接的 CLI 工具。作者是 go-zero 框架的作者 Kevin Wan，最初用于观察 gRPC、MySQL 等连接池行为。主要特性包括：

- 协议感知解析（`-t`）：支持 http2、grpc、redis、mongodb；
- 模拟延迟（`-d`）与上下行限速（`-up`、`-down`），便于测试弱网；
- 连接统计（`-s`）与简洁模式（`-q`），可观察连接重传率、RTT 等。

典型用法：

```bash
# 监听本地 8088，转发到 8081，按 grpc 协议解析并加 100ms 延迟
tproxy -p 8088 -r localhost:8081 -t grpc -d 100ms

# 观察连接池行为
tproxy -p 3307 -r localhost:3306 -q -s
```

简言之，前者是“透明代理的基础设施”，后者是“排查 TCP 流量的瑞士军刀”，二者用途完全不同。看到任何 tproxy 资料时，先确认上下文指的是 Linux 内核机制还是某个同名工具，能避免很多误解。

## 小结

理解 tproxy 的关键在于三点：第一，它代表“对客户端和服务端都透明”的代理语义；第二，Linux 的 TPROXY 内核模块通过 iptables + 策略路由 + `IP_TRANSPARENT` socket 选项三件套，在不使用 NAT 的前提下完成了透明拦截；第三，社区里有多个同名项目，使用时务必区分清楚。掌握这些之后，再去阅读 Istio Ambient、Squid 或 V2Ray 的部署文档，会发现它们都建立在同一套机制之上。

## 参考

- [Transparent proxy support — Linux kernel documentation](https://docs.kernel.org/networking/tproxy.html)
- [tproxy(透明代理) — 赵华平的博客](https://www.zhaohuabing.com/learning-linux/docs/tproxy/)
- [透明代理（TPROXY） — V2Ray 指南](https://guide.v2fly.org/app/tproxy.html)
- [KatelynHaworth/go-tproxy: Linux Transparent Proxy library for Golang](https://github.com/KatelynHaworth/go-tproxy)
- [kevwan/tproxy: A cli tool to proxy and analyze TCP connections](https://github.com/kevwan/tproxy)
- [How Istio's Ambient Mode Transparent Proxy tproxy Works Under the Hood](https://jimmysong.io/blog/what-is-tproxy/)
