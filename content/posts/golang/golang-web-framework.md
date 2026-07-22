+++
title = "Golang web框架"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Go 主流 Web 框架与路由库梳理"
description = "整理 Gin、Fiber、Echo、Hertz 等主流 Go Web 框架,以及 mux、chi、fasthttp 等路由与网络库的特点,并附代表性开源项目。"
author = "小智晖"
authors = ["小智晖"]
categories = ["golang"]
tags = ["编程语言", "golang", "web 框架", "微服务", "HTTP"]
keywords = ["Go", "golang", "Web 框架", "Gin", "Fiber", "Hertz"]
toc = true
draft = false
+++

## Fiber

- [Fiber](https://github.com/gofiber/fiber):受 Express.js 启发的 Go Web 框架，底层基于 fasthttp，主打零内存分配与高性能。

基于 Fiber 的开源项目:

- [bark-server](https://github.com/Finb/bark-server):iOS 推送通知服务 Bark 的后端。

## Macaron

- [Macaron](https://github.com/go-macaron/macaron):高生产力、模块化的 Go Web 框架。目前已进入维护模式，不再新增功能，官方推荐其后继者 [Flamego](https://github.com/flamego/flamego)。

## Beego

- [Beego](https://github.com/beego/beego):老牌高性能 Go Web 框架，提供 ORM、缓存、日志、配置、任务等一整套模块。注：原作者仓库 `astaxie/beego` 已迁移至 `beego/beego` 组织，请使用新地址。

## Gin

- [Gin](https://github.com/gin-gonic/gin):使用最广泛的 Go Web 框架，采用 httprouter 改造的路由，性能高、API 简洁，中间件生态丰富。

## Echo

- [Echo](https://github.com/labstack/echo):高性能、极简的 Go Web 框架，自动 TLS、HTTP/2、可扩展中间件支持完善。

## Chi

- [chi](https://github.com/go-chi/chi):轻量、兼容 `net/http` 的路由库，API 与标准库无缝衔接，适合构建可组合的 HTTP 服务。

## Gorilla

- [gorilla/mux](https://github.com/gorilla/mux):强大的 HTTP 路由与请求匹配器，功能丰富。Gorilla 工具集曾在 2022 年底被归档，后由新的维护者团队接管并恢复维护。
- [gorilla/websocket](https://github.com/gorilla/websocket):Go 社区应用最广泛的 WebSocket 库。

## fasthttp

- [fasthttp](https://github.com/valyala/fasthttp):为极端性能优化的 HTTP 实现，吞吐量与内存占用均显著优于标准库 `net/http`,但 API 与 `net/http` 不兼容。

## httprouter

- [httprouter](https://github.com/julienschmidt/httprouter):基于 radix tree 的高性能路由，是众多 Go Web 框架（含 Gin）的底层路由原型。

## Hertz

Hertz(发音 [həːts],赫兹)是字节跳动开源的 Golang 微服务 HTTP 框架，由 [CloudWeGo](https://github.com/cloudwego) 社区维护。它最初 fork 自 fasthttp，在设计上参考了 Gin、Echo 等开源框架的优势，并结合字节跳动内部对高性能与可扩展性的诉求进行了重构与演进。其默认网络库使用 CloudWeGo 自研的 [Netpoll](https://github.com/cloudwego/netpoll)(基于 epoll),并保留了切换至 Go 标准网络库的能力，具有高易用性、高性能、高扩展性等特点，目前在字节跳动内部已大规模使用。

随着越来越多微服务选择使用 Golang，如果对性能有较高要求，同时又希望框架能够充分满足内部的可定制化需求，Hertz 会是一个不错的选择。

- [Hertz](https://github.com/cloudwego/hertz)

基于 Hertz 的开源项目:

- [Coze Studio](https://github.com/coze-dev/coze-studio):一站式 AI Agent 可视化开发工具，提供大模型接入、插件、RAG、工作流等能力，支持从零代码到低代码的开发模式，由字节跳动开源。
- [Coze Loop](https://github.com/coze-dev/coze-loop):面向开发者的 AI Agent 全生命周期平台，覆盖 Prompt 开发、调试、评估到监控的完整能力。

## 参考

- [CloudWeGo Hertz 官方文档](https://www.cloudwego.io/zh/docs/hertz/)
- [Gorilla Web Toolkit](https://gorilla.github.io/)
