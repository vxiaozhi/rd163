+++
title = "Go 语言实现的命令行工具"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "以 doggo 为例,看 Go 生态下的现代命令行工具"
description = "介绍用 Go 语言编写的命令行工具,以 DNS 客户端 doggo 为例,涵盖安装、常用命令、传输协议与典型用法。"
author = "小智晖"
authors = ["小智晖"]
categories = ["command-line"]
tags = ["cmd", "go", "dns", "doggo"]
keywords = ["Go", "doggo", "DNS", "命令行工具", "DoH", "DoT"]
toc = true
draft = false
+++

Go 语言在命令行工具领域有着大量优质项目。得益于交叉编译简单、单文件分发、启动快、并发模型轻量等特性,Go 已成为现代 CLI 工具最常用的实现语言之一。本文以 DNS 查询工具 [doggo](https://github.com/mr-karan/doggo) 为例,介绍这类工具的设计思路与实际用法。

## 为什么 Go 适合写命令行工具

Go 在 CLI 场景下有几个天然优势:

- **静态编译,单二进制分发**:编译产物是一个不依赖外部库的可执行文件,跨平台交叉编译只需设置 `GOOS` / `GOARCH`,安装与升级对用户友好。
- **启动速度快**:没有虚拟机或解释器的预热过程,适合频繁调用的短命令。
- **标准库完备**:`net`、`net/http`、`crypto/tls`、`encoding/json`、`flag` 等包覆盖了网络、加解密、配置、参数解析等常见需求,第三方生态(`spf13/cobra`、`pflag`、`urfave/cli` 等)进一步补齐了子命令与帮助文本生成。
- **goroutine 并发**:批量查询、并行请求等场景实现简洁。

社区中知名的 Go 命令行工具包括 `fzf`、`caddy`、`hugo`、`lazygit`、`k9s`、`gh` 等,它们普遍呈现「安装即用、输出友好、可脚本化」的共同特征。

## doggo:面向人类的 DNS 客户端

[doggo](https://github.com/mr-karan/doggo) 是一个用 Go 编写的命令行 DNS 客户端,项目自述为 "command-line DNS client for humans"。它在功能上对标经典的 `dig` / `nslookup`,但针对可读性和现代 DNS 协议做了重写。项目名来源于早期用 Rust 编写的同类工具 [dog](https://github.com/ogham/dog),取 "dog + go" 之意。

### 核心特性

- **彩色表格化输出**:默认输出比 `dig` 更紧凑、更易读。
- **多协议支持**:UDP、TCP、DoH(DNS over HTTPS)、DoT(DNS over TLS)、DoQ(DNS over QUIC)、DNSCrypt。
- **JSON 输出**:通过 `--json` / `-J` 输出结构化数据,便于用 `jq` 等工具做脚本处理。
- **短输出模式**:`--short` 仅返回应答核心字段。
- **反向解析**:`-x` / `--reverse` 支持 PTR 反查。
- **EDNS 支持**:包含 NSID、Cookie、Padding、EDE,以及客户端子网(ECS,`--ecs`)。
- **IDN 支持**:国际化域名自动做 punycode 转换。
- **Globalping 集成**:`--gp-from` / `--gp-limit` 可从全球多地发起查询。

### 安装

doggo 已被主流包管理器收录,常见安装方式如下:

```bash
# macOS
brew install doggo

# Arch Linux
pacman -S doggo

# Windows (Scoop / Winget)
scoop install doggo
winget install doggo

# Nix
nix profile install nixpkgs#doggo

# Go 安装(需要本地 Go 环境)
go install github.com/mr-karan/doggo/cmd/doggo@latest

# Docker
docker pull ghcr.io/mr-karan/doggo:latest
```

也可从 [Releases 页面](https://github.com/mr-karan/doggo/releases)直接下载预编译二进制文件。

## 常用命令

### 基本查询

```bash
# 查询 A 记录
doggo example.com

# 指定记录类型
doggo MX github.com

# 同时查询多个域名或多个层级
doggo NS example.com example.com. com. . --short
```

### 指定上游解析器

通过 `@` 前缀指定上游服务器,未显式声明协议时默认走 UDP:

```bash
# UDP(默认)
doggo example.com @1.1.1.1

# TCP
doggo example.com @tcp://1.1.1.1

# DNS over HTTPS
doggo example.com @https://cloudflare-dns.com/dns-query

# DNS over TLS
doggo example.com @tls://1.1.1.1

# DNS over QUIC
doggo example.com @quic://dns.adguard.com

# DNSCrypt(通过 DNS Stamp)
doggo example.com @sdns://...
```

### JSON 输出与脚本化

```bash
# 取出所有 A 记录地址
doggo example.com --json | jq '.responses[0].answers[].address'

# MX 记录及其优先级
doggo MX gmail.com --json | jq -r '.responses[0].answers[] | "\(.address) \(.preference)"'

# 统计 AAAA 记录数量
doggo AAAA example.com --json | jq '.responses[0].answers | length'
```

### 反向解析

```bash
doggo --reverse 8.8.8.8
doggo --reverse 8.8.8.8 --short @1.1.1.1
```

### 多解析器对比

一次查询同时打到多个上游,便于排查解析差异:

```bash
doggo example.com @1.1.1.1 @8.8.8.8 @9.9.9.9
```

配合 `--strategy` 可控制 `all`(全部等待)、`first`(取最快)、`random`(随机)策略。

## 与 dig 的差异

| 维度 | `dig` | `doggo` |
| --- | --- | --- |
| 实现语言 | C | Go |
| 默认输出 | 文本、信息密度高,初学者不易解读 | 彩色表格,字段聚焦 |
| 现代协议 | 需配合 `+https`、`+tls` 等参数 | 内建 `@https://` / `@tls://` 等一等公民语法 |
| JSON | 不直接支持 | `--json` 原生支持 |
| 单文件分发 | 依赖系统 Bind 工具链 | 静态二进制 |

需要强调的是,`dig` 在排障与权威调试上依然更全面(`+trace`、`+dnssec` 详细输出等),doggo 的定位是日常查询与脚本化场景,二者互补而非替代。

## 典型使用场景

- **快速验证 DNS 解析结果**:替代 `dig` 在终端里查看 A / MX / TXT / CAA 记录。
- **DoH / DoT 调试**:在排查加密 DNS 配置(路由器、浏览器、系统级 DoH)时,直接用 `@https://...` 验证上游。
- **脚本与自动化**:结合 `jq` 解析 JSON 输出,接入监控、CI 或批量诊断脚本。
- **多地解析对比**:通过 Globalping 选项观察不同地理区域的 DNS 应答差异,常用于 CDN 与全球化业务排查。

## 参考

- [doggo GitHub 仓库](https://github.com/mr-karan/doggo)
- [doggo 官方文档](https://doggo.mrkaran.dev/docs/)
- [doggo CLI Reference](https://doggo.mrkaran.dev/docs/guide/reference)
- [doggo 使用示例](https://doggo.mrkaran.dev/docs/guide/examples)
- [dog — doggo 灵感来源(Rust 实现)](https://github.com/ogham/dog)
