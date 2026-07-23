+++
title = "HttpAPI规范及生态组件"
date = "2025-02-19"
lastmod = "2025-02-19"
subtitle = "从 OpenAPI / RAML / API Blueprint 到 Swagger 生态的 API 管理实践"
description = "梳理 HTTP API 管理面临的标准不统一、文档维护难等问题,对比 OpenAPI、RAML、API Blueprint 三大业界规范及配套生态工具,并给出基于 Swagger 的 API 管理方案与常用命令备忘。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "openapi", "swagger", "http", "api-design"]
keywords = ["OpenAPI", "Swagger", "HTTP API", "API 规范", "API 文档", "RAML"]
toc = true
draft = false
+++

## 背景

随着业务的增多，越来越多的服务需要提供 HTTP 协议的 API 接口供第三方调用。由于 HTTP API 并不像 tRPC 等协议那样有一套通用的协议规范来约束接口，API 开发者通常需要提供一份独立的 API 文档来说明每个接口的详细参数。

例如 [腾讯云 API 文档](https://cloud.tencent.com/document/product/213/15692) 等，这些文档往往散落在各处，缺乏统一管理，而且每篇文档的撰写风格也不一致，无形中增加了 API 调用方的接入成本。

总结一下，现有的 API 管理体系普遍存在如下缺点:

- 标准不统一，管理混乱;
- 接口频繁变更，文档更新不及时;
- 开发者接入体验不友好;
- 人工编写文档耗时长。

## 业界规范

为了解决上述问题，业界制定了一些规范标准。这些规范定义了一个与语言无关的标准接口，允许人和计算机在不访问源代码、文档或开发者工具的前提下，就能发现并理解服务的功能。

最有名的包括 OpenAPI、RAML 和 API Blueprint。

### OpenAPI 规范

- [OpenAPI 官网](https://www.openapis.org/)
- [各版本 OpenAPI Specification 定义文档](https://github.com/OAI/OpenAPI-Specification/blob/main/versions/3.0.0.md)

OpenAPI 的前身是 Swagger，其官网也提供最新的 OpenAPI 规范定义:

- [Swagger 官网中的 OpenAPI Specification](https://swagger.io/specification/)

> 备注：截至本文写作时，OpenAPI Specification 的最新正式版本已迭代到 3.1.x / 3.2.0,3.0.0 是较早但仍在大量项目中使用的稳定版本，链接保留以供参考。

### RAML 规范

- [RAML 官网](https://raml.org/)
- [RAML 规范文档](https://github.com/raml-org/raml-spec/tree/master/versions)

### API Blueprint 规范

- [API Blueprint 官网](https://apiblueprint.org/)
- [API Blueprint 规范描述](https://github.com/apiaryio/api-blueprint/blob/master/API%20Blueprint%20Specification.md)

### REST API 设计规范参考

- [一把梭:REST API 全用 POST](https://coolshell.cn/articles/22173.html)
- [微软 API Guidelines](https://github.com/microsoft/api-guidelines/blob/vNext/Guidelines.md)
- [Google API Design Guide](https://cloud.google.com/apis/design?hl=zh-cn)

## 生态工具

有了 API 定义规范，就可以基于它衍生出一系列工具，包括代码生成、API 文档生成与展示、API 测试、API 模拟（Mock）等。

![API tools](/imgs/openapi-tools.drawio.png)

### 开源工具

| API 规范 | API 文档化 | API 代码生成 | API 测试 | API 可视化编辑 | 其它 |
|--------|--------|--------|--------|--------|--------|
| OpenAPI | [swagger-ui](https://github.com/swagger-api/swagger-ui)、[openapi-generator](https://github.com/OpenAPITools/openapi-generator)、[apicurio-studio](https://github.com/Apicurio/apicurio-studio)、[redoc](https://github.com/Redocly/redoc)、[elements](https://github.com/stoplightio/elements) | [swagger-codegen](https://github.com/swagger-api/swagger-codegen)、[openapi-generator](https://github.com/OpenAPITools/openapi-generator)、[scalar](https://github.com/scalar/scalar) | [swagger-ui](https://github.com/swagger-api/swagger-ui) | [swagger-editor](https://github.com/swagger-api/swagger-editor)、[apicurio-studio](https://github.com/Apicurio/apicurio-studio) | [swagger-faker](https://github.com/reeli/swagger-faker)、[go-swagger](https://github.com/go-swagger/go-swagger)、[从 go 源码生成 SPEC](https://github.com/go-swagger/go-swagger#generate-a-spec-from-source) |
| RAML | [raml2html](https://github.com/raml2html/raml2html) |  |  | [playground](https://github.com/raml-org/playground) | [webapi-parser](https://github.com/raml-org/webapi-parser) |
| API Blueprint |  |  | [dredd](https://github.com/apiaryio/dredd) |  | [drakov](https://github.com/Aconex/drakov) |

### 开源产品

#### YApi

YApi 是高效、易用、功能强大的 API 管理平台，旨在为开发、产品、测试人员提供更优雅的接口管理服务。它可以帮助开发者轻松创建、发布、维护 API，还提供了良好的交互体验：开发人员只需借助平台提供的接口数据写入工具以及简单的点击操作，即可完成接口管理。

- [GitHub 仓库](https://github.com/YMFE/yapi)

#### RAP

- [RAP:Web 接口管理工具，开源免费](https://github.com/thx/RAP)
- [rap2:阿里妈妈前端团队出品的开源接口管理工具 RAP 第二代](https://github.com/thx/rap2-delos)

### 商业化产品

#### 1. [国内] APIFox

功能较为强大，提供了 API 设计、开发、测试一体化协作平台。

[官网](https://apifox.com/)

APIhub 中收录了各大互联网公司常见产品的 API 文档，例如 [企业微信 API](https://qiyeweixin.apifox.cn/api-10061204)。

#### 2. [国外] RapidAPI

号称世界上最大的 API 中心。

[官网](https://rapidapi.com/)

#### 3. [国外] Stoplight

Stoplight 是一款全面的 API 开发平台，覆盖 API 设计、文档化、测试和发布等环节。它提供了直观、易用的界面，支持多种 API 设计语言和规范，例如 OpenAPI、Swagger 和 RAML 等。

[官网](https://stoplight.io/)

## 基于 Swagger 的 API 管理方案设计

### Swagger 生态组件

Swagger 是 OpenAPI 的前身，生态组件非常丰富。

![](/imgs/openapi-swagger.drawio.png)

例如「唐僧叨叨」的 API 文档就是基于 Swagger 实现的:

- [唐僧叨叨的 API](https://apidocs.botgate.cn/)

### 整体架构

![](/imgs/api-arch.drawio.png)

## Swagger 常用命令备忘

### API 可视化（以 Swagger UI 容器方式运行）

```bash
# 容器内监听 8080,这里映射到宿主机 80 端口
docker run --rm -p 80:8080 swaggerapi/swagger-ui
```

### 可视化编辑 API SPEC 文件

```bash
# swagger-editor 容器内默认监听 8080
docker run --rm -p 80:8080 swaggerapi/swagger-editor
```

### 由 OpenAPI/Swagger 文件生成 Markdown 文档

```bash
npm i -g openapi-to-md

# 基本用法:openapi-to-md <source> [destination]
# -s / --sort 表示对 paths 和引用按字母序排序,不是 source 的简写
openapi-to-md openapi.json api.md
```

## 参考

- [OpenAPI 官网](https://www.openapis.org/)
- [OpenAPI Specification(GitHub)](https://github.com/OAI/OpenAPI-Specification)
- [Swagger 官网 Specification](https://swagger.io/specification/)
- [openapi-to-md(npm)](https://www.npmjs.com/package/openapi-to-md)
- [swaggerapi/swagger-ui(Docker Hub)](https://hub.docker.com/r/swaggerapi/swagger-ui)
