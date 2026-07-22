+++
title = "Gin 开发后台服务最佳实践"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Gin 后台服务脚手架与中间件选型"
description = "围绕 Gin 框架梳理后台服务开发涉及的脚手架项目、常用中间件与典型应用,对比 gin-vue-admin、go-gin-api、Gin-Admin 等方案并给出选型建议。"
author = "小智晖"
authors = ["小智晖"]
categories = ["golang"]
tags = ["编程语言", "golang", "gin", "web 框架", "后台开发"]
keywords = ["gin", "golang", "脚手架", "后台服务", "中间件", "RBAC"]
toc = true
draft = false
+++

[gin](https://github.com/gin-gonic/gin) 是一个由 Go 语言实现的 HTTP Web 框架，基于 httprouter，主打高性能与简洁的 API 设计，常用于构建 REST API 与微服务。

[gin 中文文档](https://github.com/skyhee/gin-doc-cn) 系统介绍了路由、无缝重启、中间件、数据库接入等常用方法，可作为入门与速查参考。

## 脚手架项目

GitHub 上 stars 数较高的几个 Gin 脚手架:

- [gin-vue-admin](https://github.com/flipped-aurora/gin-vue-admin):Vite + Vue3 + Gin 的全栈基础开发平台，支持 TS 与 JS 混用。集成了 JWT 鉴权、权限管理、动态路由、casbin 鉴权、显隐可控组件、分页封装、多点登录拦截、资源权限、上传下载、代码生成器、表单生成器以及可配置的导入导出等开发必备功能。
- [go-gin-api](https://github.com/xinliangnote/go-gin-api):基于 Gin 进行模块化设计的 API 框架，封装了常用功能，使用简单，致力于快速业务研发。支持 CORS 跨域、JWT 签名验证、zap 日志收集、panic 异常捕获、trace 链路追踪、prometheus 监控指标、swagger 文档生成、viper 配置文件解析、gorm 数据库组件、gormgen 代码生成工具、graphql 查询语言、errno 统一定义错误码、gRPC 调用、cron 定时任务等。前端采用 bootstrap + template 实现，并通过 `embed.FS` 嵌入到一个可执行文件中。
- [Go Gin Web Server](https://github.com/render-examples/go-gin-web-server):Render 平台提供的 Gin 部署示例，适合用作云端部署参考。
- [gin-boilerplate](https://github.com/Massad/gin-boilerplate):基于 Gin 的快速 RESTful API 脚手架，默认集成 PostgreSQL 数据库与基于 Redis 的 JWT 认证中间件。整体实现较为基础，未做日志封装，也未采用 `cmd`、`pkg` 等标准目录结构。
- [Gin-Admin](https://github.com/LyricTian/gin-admin):基于 Gin + GORM 2.0 + Casbin 2.0 + Wire DI 的轻量级、灵活、优雅且功能齐全的 RBAC 脚手架，代码可读性好，生态丰富。

其中 gin-vue-admin 和 go-gin-api 的 stars 数最多，但商业化痕迹较重。最终我选择使用 Gin-Admin。

## 中间件

- [gin-swagger](https://github.com/swaggo/gin-swagger):基于 Swagger 2.0 自动生成并展示 RESTful API 文档。
- [CORS](https://github.com/gin-contrib/cors):Gin 官方维护的跨域中间件。
- [sessions](https://github.com/gin-contrib/sessions):Gin 官方会话管理中间件。
- [gin-jwt](https://github.com/appleboy/gin-jwt):Gin 的 JWT 中间件。

## 基于 Gin 的应用

- [alist](https://github.com/AlistGo/alist):一个支持多存储的文件列表 / WebDAV 程序，使用 Gin 和 SolidJS 构建，支持本地存储、百度网盘以及各大云厂商的 COS 等。

## 参考

- [gin-gonic/gin 官方仓库](https://github.com/gin-gonic/gin)
- [Gin 官方文档](https://gin-gonic.com/docs/)
- [Gin 中文文档](https://github.com/skyhee/gin-doc-cn)
