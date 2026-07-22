+++
title = "Golang 内存泄露定位"
date = "2025-04-20"
lastmod = "2025-04-20"
subtitle = "pprof 与常见泄露场景排查指南"
description = "梳理 Go 常见的内存泄露场景（string/slice/goroutine/channel/time.Ticker 等），并介绍如何使用 pprof 定位内存泄露。"
author = "小智晖"
authors = ["小智晖"]
categories = ["Golang"]
tags = ["golang", "内存泄露", "pprof", "性能优化", "goroutine"]
keywords = ["golang", "内存泄露", "pprof", "goroutine 泄露", "slice 泄露", "GC"]
toc = true
draft = false
+++

Golang 作为自带垃圾回收（Garbage Collection，GC）机制的语言，可以自动管理内存。但在实际开发中，如果代码编写不当，仍然会出现内存泄漏的情况。

内存泄漏并不是指物理上的内存消失，而是指程序在申请内存后，未能及时释放不再使用的内存空间，导致这部分内存无法被再次使用。随着时间的推移，程序占用的内存不断增长，最终导致系统资源耗尽或程序崩溃。短期内的内存泄漏可能看不出什么影响，但日积月累，浪费的内存越来越多，可用内存空间不断减少，轻则影响程序性能，严重时会导致正在运行的程序突然崩溃。

## 内存泄漏场景

常见的内存泄漏场景，[go101](https://go101.org/article/memory-leaking.html) 进行了讨论，总结了如下几种：

- Kind of memory leaking caused by substrings
- Kind of memory leaking caused by subslices
- Kind of memory leaking caused by not resetting pointers in lost slice elements
- Real memory leaking caused by hanging goroutines
- Real memory leaking caused by not stopping time.Ticker values which are not used any more
- Real memory leaking caused by using finalizers improperly
- Kind of resource leaking by deferring function calls

[详解 Golang 内存泄露](https://zhuanlan.zhihu.com/p/679290686) 这篇文章也详细分析了几种常见的内存泄漏场景，包括：

- 全局变量
- 不恰当的内存池使用
- slice 引起的内存泄漏
- select 阻塞
- channel 阻塞
- goroutine 导致的内存泄漏

简单归纳一下：

- **临时性泄漏**：该释放的内存资源没有及时释放，但仍然有机会在更晚些时候被释放。即便如此，在内存资源紧张的情况下也会成为问题。这类泄漏主要是 string、slice 底层 buffer 的错误共享，导致无用数据对象无法及时释放，或者 defer 函数导致资源没有及时释放。
- **永久性泄漏**：在进程后续生命周期内，泄漏的内存都没有机会被回收。例如 goroutine 内部预期之外的 for 循环或 chan select-case 导致无法退出，造成协程栈及其引用的内存永久泄漏。

## 内存泄漏排查

### 借助 pprof 排查

Go 提供了 pprof 工具，方便对运行中的 Go 程序进行采样分析，支持对多种类型的指标进行采样。

集成 pprof 非常简单，只需要在工程中引入如下代码即可：

```go
import _ "net/http/pprof"

go func() {
    log.Println(http.ListenAndServe("localhost:6060", nil))
}()
```

然后在浏览器打开：

```text
http://localhost:6060/debug/pprof/
```

## 参考

- [go101 — Memory Leaking Scenarios](https://go101.org/article/memory-leaking.html)
- [详解 Golang 内存泄露](https://zhuanlan.zhihu.com/p/679290686)
- [Profiling Go Programs — The Go Blog](https://go.dev/blog/pprof)
- [Go Diagnostics Guide](https://go.dev/doc/diagnostics)
- [net/http/pprof 包文档](https://pkg.go.dev/net/http/pprof)
