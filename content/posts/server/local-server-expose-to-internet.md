+++
title = "内网穿透工具"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "frp、nps、ngrok 选型与 frp 实战配置"
description = "对比 frp、nps、ngrok 三类常见内网穿透工具的特点与适用场景，并给出 frp 服务端/客户端的典型配置示例。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "内网穿透", "frp", "nps", "ngrok", "reverse-proxy"]
keywords = ["内网穿透", "frp", "nps", "ngrok", "反向代理", "NAT 穿透"]
toc = true
draft = false
+++

内网穿透（Intranet Penetration / NAT Traversal）用于把位于 NAT 或防火墙后面的本地服务（local server）暴露到公网，常用于在家自托管服务、临时 Webhook 调试、远程访问内网开发环境等场景。在没有公网 IP 的情况下，需要借助一台具有公网 IP 的中转节点反向代理流量。

本文先给出三类常见工具的选型结论，再以目前生态最活跃的 [frp](https://github.com/fatedier/frp) 为重点介绍架构与配置。

## 选型结论

- **需要二次开发（有 API 可调用）或多租户（每个客户端单独的 key）**：建议使用 [nps](https://github.com/ehang-io/nps)。nps 自带 Web 管理端和客户端密钥体系，原生支持多用户。
- **希望简单上手、没有多租户要求**：建议使用 [frp](https://github.com/fatedier/frp)。配置直白、文档完善、社区活跃，单文件二进制即可运行。
- **只想临时调试一次性接口、不想自建服务端**：使用托管型的 [ngrok](https://ngrok.com)。

## 主流工具对比

| 工具 | 开源协议 | 服务端自托管 | 多租户/Web 管理 | 维护状态 |
| --- | --- | --- | --- | --- |
| [frp](https://github.com/fatedier/frp) | Apache-2.0 | 是 | 有 Dashboard，偏运维观测 | 活跃 |
| [nps](https://github.com/ehang-io/nps) | GPL-3.0 | 是 | 内置 Web 管理端，支持多用户注册 | 已停更（最后发布 v0.26.10，2021 年 4 月） |
| [ngrok](https://ngrok.com) | 1.x 已归档；2.x/3.x 闭源 | 否（托管云服务） | 商业版有管理面 | 活跃 |

需要特别说明的是：

- **ngrok** 由 Alan Shreve（GitHub: inconshreveable）创建。1.x 版本（2013—2016 年开发）曾开源，仓库 [inconshreveable/ngrok](https://github.com/inconshreveable/ngrok) 已归档；自 2.x 起转为闭源的托管云服务，没有官方的自托管版本。
- **nps** 的最后一次发布停留在 2021 年，仓库长期未更新，新项目不建议直接采用；但因为其多租户和 Web 管理面在同类工具中较为完整，存量项目仍在大量使用。
- **frp** 名字本身并非缩写，作者 fatedier 将其定位为一款「快速反向代理」（fast reverse proxy）。

## frp 架构与核心概念

frp 采用经典的 C/S 反向代理架构：

- **frps**（server）：部署在具有公网 IP 的节点上，监听客户端连接与对外暴露的端口。
- **frpc**（client）：部署在内网机器上，主动连接 frps，注册若干「代理」（proxy）。

一个代理（proxy）描述了一条「内网服务 → frps 端口」的映射规则。frp 内置的代理类型包括 `tcp`、`udp`、`http`、`https`、`stcp`（带密钥的 TCP，用于受限分享）、`xtcp`（P2P 穿透）、`sudp`、`tcpmux` 等。

通过在公网节点上部署 frps，可以轻松地把内网服务穿透到公网，同时提供诸多专业特性：

- **多种传输协议**：客户端与服务端通信支持 TCP、KCP、QUIC、WebSocket、WSS（WebSocket over TLS）等多种协议，通过 `transport.protocol` 配置项切换。其中 KCP 在 UDP 上实现可靠传输，官方文档称可降低 30%—40% 的平均延迟，代价是多消耗 10%—20% 的带宽；QUIC 是基于 UDP 的新一代多路复用传输。
- **连接流式复用**：默认在单条 TCP 连接上承载多个请求（连接池，`transport.poolCount`），减少连接建立时间、降低请求延迟。
- **代理组的负载均衡**：将多个 `frpc` 注册的同名 `group` 代理视为一个后端池，按权重分发流量。
- **端口复用**：HTTP/HTTPS 虚拟主机端口（`vhostHTTPPort` / `vhostHTTPSPort`）可与 `bindPort` 共用同一端口，多个服务通过域名或路由区分共享同一个对外端口。
- **P2P 通信**：通过 `xtcp` 代理类型，流量可以不经过 frps 中转，直接在两端之间打洞，充分利用带宽资源（受 NAT 类型限制，不保证成功）。
- **客户端插件**：原生支持 `static_file`（静态文件服务）、`http2https`、`socks5`、`unix_domain_socket` 等插件，可独立完成某些工作。
- **服务端插件系统**：高度可扩展，便于结合自身需求做鉴权、计费等扩展。
- **UI 页面**：frps 与 frpc 均提供 Dashboard，便于观察连接、流量与代理状态。
- **TLS 与鉴权**：自 v0.50.0 起，frps 与 frpc 之间的连接默认启用 TLS；支持 Token、OIDC 等多种鉴权方式。

## frp 配置示例

frp 自 v0.52.0 起将配置文件格式由 INI 切换为 TOML，以下示例均采用 TOML。

### frps.toml（服务端）

```toml
# frps 与 frpc 通信端口
bindPort = 7000

# 如需启用 KCP / QUIC 传输，可额外监听 UDP 端口（可与 bindPort 同号）
# kcpBindPort = 7000
# quicBindPort = 7000

# HTTP / HTTPS 虚拟主机端口，多域名代理共享
vhostHTTPPort = 8080
vhostHTTPSPort = 8443

# 服务端 Dashboard（可选）
webServer.addr = "0.0.0.0"
webServer.port = 7500
webServer.user = "admin"
webServer.password = "change-me"

# 鉴权（推荐开启）
auth.method = "token"
auth.token = "a-long-random-string"
```

启动：`./frps -c ./frps.toml`

### frpc.toml（客户端）

以把本机 8080 端口的 HTTP 服务通过 frps 暴露为例：

```toml
serverAddr = "x.x.x.x"
serverPort = 7000

# 与服务端一致的鉴权 token
auth.method = "token"
auth.token = "a-long-random-string"

# 切换传输协议：tcp（默认）/ kcp / quic / websocket / wss
# transport.protocol = "kcp"

[[proxies]]
name = "my-http"
type = "http"
localIP = "127.0.0.1"
localPort = 8080
customDomains = ["dev.example.com"]
```

若要直接转发裸 TCP 端口（例如 SSH），则改为：

```toml
[[proxies]]
name = "ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 6000
```

启动：`./frpc -c ./frpc.toml`

配置完成后，访问 `http://dev.example.com`（需将域名解析到 frps 所在服务器）即可命中本机的 8080 端口；SSH 则可使用 `ssh -p 6000 user@x.x.x.x` 登录到内网机器。

## 安全注意事项

将内网服务暴露到公网本质上是扩大攻击面，部署时需要遵循最小权限原则：

- **务必开启鉴权**：设置足够强度的 `auth.token`，避免 frps 被他人白嫖。
- **Dashboard 端口不要直接暴露公网**，或至少修改默认账号密码（默认 `admin/admin` 仅作占位）。
- **最小化 `remotePort` 暴露面**：用不到的端口不要开放；HTTP/HTTPS 代理优先通过域名路由而非开放大量端口。
- **启用 TLS**：v0.50.0+ 默认开启 frpc↔frps 的 TLS，旧版本应显式 `transport.tls.enable = true`。
- **对敏感服务再加一层应用层鉴权**（Basic Auth、OAuth、VPN 等），不要只依赖 frp 自身。

## 适用场景

- 在没有公网 IP 的家用宽带上自托管博客、网盘、Home Assistant 等。
- 开发联调时把本地的 Webhook 回调地址暴露给第三方平台（支付、IM、GitHub）。
- 临时把本地端口分享给他人预览（结合 `stcp` + 访问者密钥更安全）。
- 远程登录公司/家里的内网开发机（SSH、RDP）。

## 参考

- [fatedier/frp — GitHub](https://github.com/fatedier/frp)
- [ehang-io/nps — GitHub](https://github.com/ehang-io/nps)
- [ngrok — 官方网站](https://ngrok.com)
- [inconshreveable/ngrok（1.x 归档）— GitHub](https://github.com/inconshreveable/ngrok)
- [frp vs ngrok vs ssh 隧道](https://wiki.kpromise.top/project-1/doc-6/)（作者原引，链接可访问性以实际为准）
- [内网穿透工具比较（ngrok、frp、lanproxy、goproxy、nps）](https://blog.csdn.net/a1035434631/article/details/108010819)（作者原引）