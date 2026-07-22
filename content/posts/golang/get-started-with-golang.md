+++
title = "Golang 入门"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从语言背景到服务端常用类库的开发实践"
description = "梳理 Go 语言的起源与核心特性,并归纳服务端开发常用的 RPC、可观测性类库与单例等实践模式。"
author = "小智晖"
authors = ["小智晖"]
categories = ["golang"]
tags = ["编程语言", "golang", "Go", "服务端开发", "可观测性", "rpc"]
keywords = ["golang", "Go 语言", "trpc-go", "opentelemetry", "prometheus", "sync.Once"]
toc = true
draft = false
+++

## 为什么是 Go

云风在 2010 年写下的一段话，至今仍是关于 Go (Go language，又称 Golang) 最朴素的注脚:

> 我发现我花了四年时间锤炼自己用 C 语言构建系统的能力，试图找到一个规范，可以更好的编写软件。结果发现只是对 Go 的模仿。缺乏语言层面的支持，只能是一个拙劣的模仿。

原文见 [云风的 BLOG: Go 语言初步](https://blog.codingnow.com/2010/11/go_prime.html)。彼时 Go 刚开源一年，这位资深 C 程序员在写过约两千行 Go 代码后感慨:`defer`、goroutine、channel、内建 string/slice 与 GC 这些"现代编程必须的东西",在 C 里要用尽各种约定与库去拙劣地模拟，而 Go 在语言层面就给出了答案。

## 语言概览

Go 由 Robert Griesemer、Rob Pike 和 Ken Thompson 于 2007 年在 Google 发起设计，2009 年正式对外开源，采用 BSD 风格许可证。它是一门静态类型、编译型、原生支持并发（first-class concurrency）的通用编程语言，官方仓库与文档站点见 [go.dev](https://go.dev)。

截至本文修订时，Go 的最新稳定版本是 **go1.26**(2026 年 2 月发布，最新补丁 go1.26.5 于 2026 年 7 月发布),发布节奏稳定为每年两次大版本（通常在 2 月和 8 月）。完整发布历史见 [go.dev/doc/devel/release](https://go.dev/doc/devel/release)。

Go 的几项标志性设计:

- **goroutine 与 channel**:轻量级用户态线程 + 基于 CSP(Communicating Sequential Processes)模型的通信原语，把"用通信来共享内存"作为并发编程的默认姿势。
- **interface 的隐式实现**:一个类型只要实现了接口定义的全部方法即视为实现该接口，无需 `implements` 关键字，契合 Unix 式的"组合优于继承"哲学。
- **工程化的工具链**:`go build` / `go run` / `go test` / `go fmt` / `go mod` 全部内建，开箱即用，社区代码风格高度一致。
- **快速编译**:依赖分析友好，大型项目秒级构建。

## 学习路线与资料

对于中文读者，推荐先按一条相对固定的路径建立整体认知，再按服务端方向深入:

- 官方入门:[A Tour of Go](https://go.dev/tour/) —— 在浏览器中跑通基本语法。
- 官方文档:[go.dev/doc](https://go.dev/doc/) 与标准库 [pkg.go.dev](https://pkg.go.dev/std)。
- 中文路线图参考:[TopGoer Go 学习路线图](https://www.topgoer.com/%E5%BC%80%E6%BA%90/go%E5%AD%A6%E4%B9%A0%E7%BA%BF%E8%B7%AF%E5%9B%BE.html)(注：该站点 TLS 证书偶尔过期，但内容持续维护)。
- 综合教程:[TopGoer Go 语言介绍](https://www.topgoer.com/)。

## 用 GoPlantUML 读源码

阅读 Go 标准库与优秀开源项目是进阶的关键。对于结构复杂的大型项目，先生成一张 UML 类图能极大降低认知成本。

[GoPlantUML V2](https://github.com/jfeliu007/goplantuml) 是一个开源命令行工具，它能解析 Go 源码并输出 PlantUML 文本，用于可视化包结构、类型依赖与函数调用关系。要求 Go 1.17 及以上版本。安装与基本用法:

```bash
go install github.com/jfeliu007/goplantuml/cmd/goplantuml@latest
goplantuml -recursive path/to/your/module > diagram.puml
```

`.puml` 文件可借助 PlantUML 渲染为图片，适合在阅读 `net/http`、`database/sql` 等标准库时先建立全局视图。

## 服务端开发常用类库

### RPC 框架

- [trpc-go](https://github.com/trpc-group/trpc-go):腾讯开源的 tRPC 框架的 Go 实现，定位为"可插拔、高性能的 RPC 框架"。其核心特性包括：单进程内可启动多服务监听多地址、所有组件（编解码、拦截器、注册中心、监控等）均可替换、接口全部可基于 `gomock` 做 mock 测试、默认支持 tRPC 与 HTTP 协议并可通过实现 `codec` 接口扩展任意协议。许可证为 Apache 2.0。
- 生态丰富的微服务场景也可考虑 [gRPC-Go](https://github.com/grpc/grpc-go) 与 [Kitex](https://github.com/cloudwego/kitex),按团队技术栈与协议兼容性选择。

### 可观测性（Observability）

可观测性是线上服务的基本盘，通常包含指标（metrics）、日志（logs）、链路（traces）三大支柱。

- [opentelemetry-go](https://github.com/open-telemetry/opentelemetry-go):CNCF OpenTelemetry 项目的官方 Go SDK，提供统一的 API/SDK 与各类 exporter，用于分布式追踪、指标与日志。配套的社区扩展库见 [opentelemetry-go-contrib](https://github.com/open-telemetry/opentelemetry-go-contrib),集成了 `net/http`、`gorm`、`gin` 等常用框架的自动埋点。
- [prometheus/client_golang](https://github.com/prometheus/client_golang):Prometheus 官方 Go 客户端。除了自定义 Counter/Gauge/Histogram 外，通过 `prometheus.NewGoCollector()` 会自动暴露 Go 运行时指标，包括 **goroutine 数目、内存用量、GC 统计、线程数** 等，默认随 HTTP `/metrics` 端点一起暴露。

## 开发实践：单例模式

Go 中实现单例（singleton）最地道的方式是借助 `sync.Once`。它保证传入的函数在整个程序生命周期内仅执行一次，且是并发安全的——比"加锁 + 双重检查"更简洁，也避免了双重检查在弱内存模型下容易写错的坑。

```go
package singleton

import "sync"

type singleton struct{}

var (
    instance *singleton
    once     sync.Once
)

// GetInstance 返回单例对象。
// sync.Once.Do 保证初始化函数在并发场景下也只会执行一次。
func GetInstance() *singleton {
    once.Do(func() {
        instance = &singleton{}
    })
    return instance
}
```

自 Go 1.21 起，标准库提供了泛型封装 `sync.OnceValue[T]`,可以进一步省掉手动声明变量:

```go
var getInstance = sync.OnceValue(func() *singleton {
    return &singleton{}
})

// 调用 getInstance() 即可,任意 goroutine 安全。
```

需要注意两点：一是 `sync.Once` 不能在首次使用后被拷贝（应总是以指针传递或作为包级变量）;二是若传入的函数 `f` 内部再次对同一个 `Once` 调用 `Do`,会导致死锁。

## 参考

- [Go 官方网站与文档](https://go.dev/doc/)
- [Go 发布历史](https://go.dev/doc/devel/release)
- [云风的 BLOG: Go 语言初步](https://blog.codingnow.com/2010/11/go_prime.html)
- [TopGoer Go 学习路线图](https://www.topgoer.com/%E5%BC%80%E6%BA%90/go%E5%AD%A6%E4%B9%A0%E7%BA%BF%E8%B7%AF%E5%9B%BE.html)
- [GoPlantUML V2](https://github.com/jfeliu007/goplantuml)
- [trpc-go](https://github.com/trpc-group/trpc-go)
- [opentelemetry-go](https://github.com/open-telemetry/opentelemetry-go)
- [prometheus/client_golang](https://github.com/prometheus/client_golang)
- [pkg.go.dev/sync](https://pkg.go.dev/sync)
