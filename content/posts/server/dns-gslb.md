+++
title = "DNS 全局负载均衡（GSLB）介绍"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "跨地域多机房流量调度的 DNS 实现与关键策略"
description = "GSLB 通过 DNS 解析链路将用户请求调度到最优数据中心,本文梳理其工作原理、调度策略、就近性局限及典型实现方案。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "dns", "gslb", "load-balancing", "cdn", "network"]
keywords = ["GSLB", "DNS 负载均衡", "全局负载均衡", "智能 DNS", "EDNS Client Subnet", "就近性调度"]
toc = true
draft = false
+++

## 什么是 GSLB

**GSLB（Global Server Load Balancing，全局服务器负载均衡）** 是一种跨多个地理区域、多个数据中心进行流量调度与分发的技术。它在标准 DNS 解析链路中插入一层智能调度，根据用户来源、节点健康状态、链路质量等条件，将请求导向"最优"的服务节点。

理解 GSLB 通常需要先把它和本地负载均衡区分开:

- **LSLB（Local Server Load Balancing，本地负载均衡）** :在同一数据中心内，通过 LVS、Nginx、HAProxy、F5 等设备把流量分发到后端的若干台 RS(Real Server)。
- **GSLB(全局负载均衡)** :在多个数据中心/地域之间做流量分发，返回的可能是某个机房的入口 VIP，也可能是更下一层的 SLB 地址。

简而言之，SLB 解决"机房内挑哪台机器",GSLB 解决"挑哪个机房"。两者通常是分层组合的。

## 为什么需要 GSLB

GSLB 的适用前提是企业已经做了多机房、跨地域部署。典型场景包括:

- **多活与容灾**:单一数据中心可能因断电、光纤中断、自然灾害等整体不可用，GSLB 可将流量快速切换到健康的 IDC。
- **就近接入**:降低跨地域访问延迟，提升终端用户体验，这也是 CDN(Content Delivery Network)背后的核心机制。
- **流量均衡**:避免单机房过载，把负载合理分摊到多站点。
- **灰度与容量管理**:按比例将流量导入新机房或新版本。

## 工作原理：基于 DNS 的 GSLB

GSLB 的主流实现方式是 **基于 DNS**,其核心是在权威 DNS 位置由 GSLB 设备做出决策。一次完整的解析过程大致分为以下几步:

1. 用户在浏览器输入域名，向 **本地 DNS(Local DNS / LDNS)** 发起递归查询。
2. 本地 DNS 若缓存未命中，则向上递归，最终到达域名的 **权威 DNS(Authoritative DNS)**。
3. 权威 DNS 通过 `NS` 记录把该子域委派给一个或多个 GSLB 设备的地址。
4. 本地 DNS 向其中一台 GSLB 设备发起查询，超时会自动切换到其他地址。
5. GSLB 根据调度策略做出决策，返回一个或多个 **A/AAAA 记录**(即机房 VIP)。
6. 本地 DNS 缓存该结果（TTL 决定缓存时长）,并返回给用户，用户直接访问对应 IP。

```
用户 ──> Local DNS ──> 权威 DNS (NS 委派)
                              │
                              ▼
                        GSLB 决策引擎
                              │
                ┌─────────────┼─────────────┐
                ▼             ▼             ▼
            北京机房       上海机房       广州机房
           VIP-A         VIP-B         VIP-C
```

GSLB 与下游 SLB 衔接后，流量最终落到具体 RS，从而形成"GSLB → SLB → RS"的分层调度架构。

## 常见调度策略

GSLB 的"最优"由策略定义，实践中常组合多种策略:

| 策略类别 | 代表策略 | 说明 |
|---------|---------|------|
| 简单分发 | 轮询（Round Robin）、加权轮询 | 在节点能力相近时做粗粒度分流 |
| 静态就近性 | 基于地理 / 运营商 | 根据 Local DNS 的 IP 地理位置选择最近的 IDC，电信/联通/移动分别调度 |
| 动态就近性 | RTT 探测 | 主动探测各节点往返时延，选择延迟最低的节点 |
| 健康感知 | 健康检查 | ICMP / TCP 端口 / HTTP(S) 探测，自动剔除故障节点 |
| 负载/带宽感知 | 按 CPU、连接数、带宽利用率调度 | 让请求避开过载节点，提升资源利用率 |
| 会话保持 | Persistence | 让同一用户持续命中同一节点，适配有状态服务 |

健康检查是高可用底线：无论上层策略如何选，只要节点失联，GSLB 就应立即从候选集合中剔除对应 IP。

## 就近性探测的关键局限

静态/动态就近性的判断依据，通常是 **DNS 请求的源 IP 地址**,而 GSLB 看到的源 IP 是 **本地 DNS 服务器的地址**,不是终端用户地址。这会导致调度偏差:

- 4G/5G 移动用户使用了归属地的 Local DNS，实际位置与 Local DNS 位置不一致;
- 用户手动配置了 Google Public DNS(8.8.8.8)、Cloudflare(1.1.1.1)等公共解析器，GSLB 看到的"位置"是解析器出口，而非用户本身;
- 一些公共解析器（如早期的部分节点）不传递用户网段，导致跨地域调度错误。

对此，业界有两条主流补救路径。

### 方案一:EDNS Client Subnet(ECS)

**EDNS Client Subnet** 是 EDNS0(Extension Mechanisms for DNS)的一个选项（RFC 7871）。它允许递归解析器在代客户端发起查询时，把客户端所属的子网前缀携带在 DNS 报文中，权威 DNS / GSLB 据此做出更贴近真实用户的调度。

启用 ECS 后，GSLB 不再只能依赖 Local DNS 的位置，而是能看到用户网段，显著提升了 CDN 的地理调度精度。它的设计初衷正是"speeding up delivery of data from content delivery networks",让 DNS 负载均衡选择离客户端更近的服务地址。需要注意 ECS 会暴露用户前缀，带来一定的隐私权衡，且并非所有解析器和权威都启用。

### 方案二:HTTP 重定向

另一种思路是放弃在 DNS 层做最终决策:DNS 只做粗调度，用户请求真正到达某个机房后，该机房的 SLB 再结合用户真实来源 IP、Cookie 等做一次精细判断，如果发现自己不是最佳节点，就通过 **HTTP 302 重定向** 把用户引导到更合适的机房。这种方式精度更高，但增加了一次往返，适用于对调度精度敏感而对首次时延不极致的场景。

此外还有 **基于 IP 层（任播 / BGP 调度）** 的方案，通过 BGP 把同一个 IP 从多个机房宣告出去，由网络层路由就近接入。这种方式切换快、调度精确度受 BGP 路由限制，部署门槛较高。

## 典型实现方案

### 商业产品

- **F5 BIG-IP GTM(Global Traffic Manager)** :GSLB 领域的标杆产品，广泛用于大型企业多活架构。
- **Citrix NetScaler(现 NetScaler / TIBCO)** :内置 GSLB 模块，支持静态/动态就近性、健康检查、RTT 探测。
- **A10 Thunder GSLB** :提供多站点负载均衡与站点故障切换。
- **云厂商解析服务**:阿里云云解析 DNS、腾讯云 DNSPod、AWS Route 53 等，均提供智能线路解析、地理/运营商调度、健康检查与故障切换。

### 开源 / 自研方案

- **PowerDNS** :支持 Lua Record，可用脚本实现复杂的地理/权重/健康调度逻辑。
- **BIND + GeoIP/View** :利用 `view` + `acl` 把不同来源的查询映射到不同应答集合，实现地理 DNS。
- **CoreDNS** :插件化设计，常与 Kubernetes 配合，可通过 `geoip`、`rewrite` 等插件实现定制调度。
- **SmartDNS** :以"测速选最快 IP"为目标，适合本地解析加速场景（注意其核心目标是测速而非传统意义上的地理 DNS）。

选择商业方案还是自研，通常取决于机房规模、调度策略复杂度、容灾等级与运维能力。

## TTL 与故障切换的权衡

DNS 响应的 **TTL(Time To Live)** 直接决定故障切换的速度:GSLB 一旦发现某节点故障，新的解析结果能多快生效，取决于全网各级解析器的缓存何时过期。

- TTL 过大（如几百秒以上）:故障切换慢，用户持续访问故障 IP;
- TTL 过小（如几秒）:切换快，但权威 DNS 查询量大幅上升，且部分 Local DNS 不严格遵守极短 TTL。

工程实践中，关键业务常采用 **较短的 TTL(如 20~60 秒)** 并配合 ECS、HTTP 重定向等机制，在"切换时效"与"DNS 压力"之间寻找平衡。

## 小结

DNS GSLB 的核心价值，是在标准 DNS 解析链路之上叠加智能调度层，在多数据中心之间实现就近接入、流量均衡与故障切换。理解它有两点最关键:

1. **它通常基于 Local DNS 的位置决策**,而非用户真实位置，这是 ECS 和 HTTP 重定向方案产生的根本原因;
2. **它和 SLB 是分层关系**,GSLB 决定机房，SLB 决定机房内的机器，二者协同构成完整的多层负载均衡体系。

选型时，需要综合考虑调度精度、容灾切换时效、运维复杂度和成本，在商业产品与开源方案之间做出权衡。

## 参考

- [DNS 全局负载均衡（GSLB）基本原理](https://cloud.tencent.com/developer/article/2085462)
- [全局负载均衡 GSLB 学习笔记](https://jjayyyyyyy.github.io/2017/05/17/GSLB.html)
- [RFC 7871 - Client Subnet in DNS Queries (EDNS Client Subnet)](https://datatracker.ietf.org/doc/html/rfc7871)
- [EDNS Client Subnet - Wikipedia](https://en.wikipedia.org/wiki/EDNS_Client_Subnet)
- [SmartDNS - GitHub](https://github.com/pymumu/smartdns)
