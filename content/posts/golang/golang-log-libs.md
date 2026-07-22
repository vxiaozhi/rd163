+++
title = "Golang 常用日志库"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从标准库 log、slog 到 zap、logrus、glog 的选型与实践"
description = "对比 Go 语言常用日志库(标准库 log/slog、uber-go/zap、sirupsen/logrus、golang/glog)的特性、性能与适用场景,附基础使用示例。"
author = "小智晖"
authors = ["小智晖"]
categories = ["golang"]
tags = ["编程语言", "golang", "log", "slog", "zap", "logrus"]
keywords = ["golang 日志库", "zap", "logrus", "slog", "glog", "结构化日志"]
toc = true
draft = false
+++

日志是服务可观测性的基石。Go 生态中,日志库大致经历了「标准库 `log` → 第三方结构化日志库(`logrus`、`zap`、`zerolog`) → 标准库 `log/slog`」三个阶段。本文梳理几款在工程中常见的 Go 日志库,介绍其定位、特性与基础用法,便于在实际选型时参考。

## 标准库 `log`:最朴素的日志

Go 标准库自带的 [`log`](https://pkg.go.dev/log) 包提供轻量的行式日志输出,API 简单(`log.Printf`、`log.Println`),默认在每条日志前加上时间戳。

它没有日志级别(Level)、没有结构化字段,适合脚本、CLI 工具或极简场景。对需要区分 `INFO`/`WARN`/`ERROR` 的后端服务而言,通常需要更高层的封装。

## `log/slog`:Go 1.21 引入的结构化日志标准

Go 1.21 起,官方在标准库中加入了 [`log/slog`](https://pkg.go.dev/log/slog),提供原生支持的结构化、分级日志。其核心特性包括:

- **结构化键值对**:日志以 key-value 形式输出,而非格式化字符串。
- **内置 Handler**:`TextHandler`(key=value)与 `JSONHandler`(JSON Lines),并支持自定义 `Handler` 接口。
- **级别过滤**:`Debug`、`Info`、`Warn`、`Error`,可通过 `LevelVar` 在运行时动态调整。
- **Context 友好**:`*Context` 系列方法便于与链路追踪、请求上下文配合。

```go
package main

import (
    "log/slog"
    "os"
)

func main() {
    logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
    logger.Info("user login",
        slog.String("user", "alice"),
        slog.Int("attempts", 3),
    )
}
```

输出形如:

```json
{"time":"2026-07-21T10:00:00.000Z","level":"INFO","msg":"user login","user":"alice","attempts":3}
```

对大多数新项目而言,`slog` 已是首选:无外部依赖、接口稳定、社区生态(Handler 适配器)日益完善。

## uber-go/zap:为性能而生

[`zap`](https://github.com/uber-go/zap) 是 Uber 开源的高性能结构化日志库,核心理念是通过「反射无关 + 零分配」编码器,把热路径(高频日志)的开销压到最低。

### 核心特性

- 两套 API:`Logger`(强类型字段,性能最高)与 `SugaredLogger`(printf 风格,易用)。
- 预置 `NewProduction()`、`NewDevelopment()`、`NewExample()` 构造器。
- 基准测试显示,带 10 个字段的日志约 656 ns/op、5 allocs/op,数量级领先于多数同类库。

### 安装与基本用法

```bash
go get -u go.uber.org/zap
```

```go
logger, _ := zap.NewProduction()
defer logger.Sync()

sugar := logger.Sugar()
sugar.Infow("failed to fetch URL",
    "url", url,
    "attempt", 3,
    "backoff", time.Second,
)

// 强类型版本,性能更优
logger.Info("failed to fetch URL",
    zap.String("url", url),
    zap.Int("attempt", 3),
    zap.Duration("backoff", time.Second),
)
```

适用场景:对延迟敏感、日志量巨大的服务(网关、中间件、广告/交易系统)。API 在 1.x 系列承诺不引入破坏性变更。截至本文撰写时,zap 最新版本为 v1.28.0。

## sirupsen/logrus:结构化日志的先行者

[`logrus`](https://github.com/sirupsen/logrus) 是 Go 社区最早流行的结构化日志库,API 与标准库 `log` 完全兼容,迁移成本低。其特色包括:

- 七个日志级别(Trace/Debug/Info/Warning/Error/Fatal/Panic)。
- `WithFields` 风格的结构化字段。
- Hooks 机制,可将日志同时分发到多个目的地。
- 内置 `TextFormatter` 与 `JSONFormatter`,支持自定义。

```go
logrus.WithFields(logrus.Fields{
    "animal": "walrus",
}).Info("A walrus appears")
```

需要注意:**logrus 目前处于维护模式**,官方只处理安全修复、Bug 和与 `log/slog` 的互操作性,不再新增功能。维护者明确建议新项目优先考虑 `zap`、`zerolog` 或 `slog`。对于已大量使用 logrus 的存量代码,可继续使用;新项目则应慎重。

## golang/glog:Google 内部日志包的导出版

[`glog`](https://github.com/golang/glog) 是 Google 内部同名 C++ 日志包的 Go 实现,提供分级(`Info`/`Warning`/`Error`/`Fatal`)日志和基于命令行标志的细粒度级别控制(如 `-v`、`-vmodule=file=2`)。

```go
glog.Info("Prepare to repel boarders")
glog.Fatalf("Initialization failed: %s", err)

if glog.V(2) {
    glog.Info("Starting transaction...")
}
```

仓库注明该代码「仅用于导出,本身不再开发,功能请求将被忽略」,但仍会跟随 Google 内部版本不定期同步(最新发布为 v1.2.5)。它更常见于 Kubernetes 生态早期组件或 Google 风格的服务中,新项目一般不首选。

## 其他相关项目

- **zerolog**:与 zap 同样主打零分配高性能,API 采用链式调用,JSON 优先,常作为 zap 的对照选项。
- **mix-go/logrus**:在 logrus 基础上增加了文件行号、中文时间格式、日志文件按天轮转、GORM SQL 格式化等增强。**该仓库已于 2021-03-18 归档,只读,不建议新项目使用**。

## 如何选型

| 需求 | 推荐 |
| --- | --- |
| 新项目、希望零外部依赖 | 标准库 `log/slog` |
| 高吞吐、对延迟敏感 | `zap` 或 `zerolog` |
| 存量 logrus 代码 | 继续用 `logrus`,或逐步迁移到 `slog` |
| Kubernetes / Google 风格服务 | `glog`(谨慎评估) |

总体趋势是收敛到标准库 `slog` 作为统一接口,第三方库则通过实现 `slog.Handler` 继续提供底层优化。新项目可直接基于 `slog` 开发,既保留性能切换空间,又避免被单一第三方库绑定。

## 参考

- [Go 标准库 `log/slog` 文档](https://pkg.go.dev/log/slog)
- [uber-go/zap GitHub 仓库](https://github.com/uber-go/zap)
- [sirupsen/logrus GitHub 仓库](https://github.com/sirupsen/logrus)
- [golang/glog GitHub 仓库](https://github.com/golang/glog)
- [Go 标准库 `log` 文档](https://pkg.go.dev/log)
