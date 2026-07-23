+++
title = "Strapi 介绍"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "开源 Headless CMS 的特性、安装与适用场景"
description = "Strapi 是一款开源的 Headless CMS，提供 RESTful 和 GraphQL API，本文介绍其主要特性、适用场景以及本地与 Docker 两种安装方式。"
author = "小智晖"
authors = ["小智晖"]
categories = ["cms"]
tags = ["cms", "strapi", "headless-cms", "graphql", "restful-api"]
keywords = ["strapi", "headless cms", "无头 cms", "graphql", "restful api", "内容管理系统"]
toc = true
draft = false
+++

Strapi 是一个开源的 Headless CMS（无头内容管理系统）。它允许开发者通过自定义的方式快速构建、管理和分发内容。Strapi 提供了一个强大的后端 API，同时支持 RESTful 和 GraphQL 两种接入方式，使得开发者可以方便地将内容分发到任何设备或服务，无论是网站、移动应用还是 IoT 设备。

Strapi 的主要特点包括：

- **灵活性与可扩展性**：通过自定义内容类型、API、插件等，Strapi 提供了极高的灵活性，可以满足各种业务需求。
- **易于使用的 API**：Strapi 提供了简洁、直观的 API，使得开发者可以轻松地与数据库进行交互。
- **内容管理界面**：Strapi 自带一个开箱即用的管理后台，让非技术人员也能方便地创建、编辑和发布内容。
- **多语言支持**：Strapi 原生支持国际化（i18n），可以管理中文、英语、法语、德语等多种语言的内容。
- **插件生态**：Strapi 具有高度的可扩展性，可以通过官方 Marketplace 上的插件或自定义模块来扩展功能。
- **社区活跃**：Strapi 拥有一个活跃的社区，提供了大量文档、示例和插件，方便开发人员解决问题和扩展功能。

主要适用场景：

- **多平台内容分发**：将同一份内容分发到 Web、H5、App 等不同平台。
- **定制化 CMS 需求**：通过插件和自定义模块实现高度定制。
- **快速开发 API**：管理界面可视化建模能够大大加快开发速度，尤其适合 MVP（最小可行产品）阶段。


## 安装

### Docker（非官方）

参考：

- [strapi-docker](https://github.com/strapi/strapi-docker)

```bash
docker run -it -p 1337:1337 -v `pwd`/project-name:/srv/app strapi/strapi
```

启动容器的过程中会安装 JS 依赖包，很可能会出现老依赖包无法下载的问题。

```text
$ docker run -it -p 1337:1337 -v `pwd`/project-strapi:/srv/app strapi/strapi
Unable to find image 'strapi/strapi:latest' locally
latest: Pulling from strapi/strapi
1e987daa2432: Pull complete
a0edb687a3da: Pull complete
6891892cc2ec: Pull complete
684eb726ddc5: Pull complete
b0af097f0da6: Pull complete
154aee36a7da: Pull complete
769e77dee537: Pull complete
44a6ee72a664: Pull complete
f374f834ba21: Pull complete
4959172eae3e: Pull complete
1eb96a0de363: Pull complete
4f4fb700ef54: Pull complete
02b141244aae: Pull complete
Digest: sha256:be2aa1b207c74474319873d2a343c572e17273f5c3017c308c4a21bd6e1992e9
Status: Downloaded newer image for strapi/strapi:latest
WARNING: The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8) and no specific platform was requested
Using strapi 3.6.8
No project found at /srv/app. Creating a new strapi project
Creating a project from the database CLI arguments.
Creating a new Strapi application at /srv/app.
Creating files.
⠹ Installing dependencies: warning url-loader@1.1.2: Invalid bin field for "url-loader".
```

> 注意：该 `strapi/strapi` 镜像**仅适用于 Strapi v3**，对应的 `strapi-docker` 仓库已于 2024 年 10 月 7 日归档（read-only），官方不再为 v4 及以上版本维护此镜像。新项目请改用命令行方式创建后，再自行编写 `Dockerfile` 打包，或参考社区方案 `strapi-tool-dockerize`。

这里开始思考一个问题：为什么要在运行过程中下载依赖？为什么官方不提供开箱即用的 Docker 部署方式？

继续看完下面的命令行安装方式就明白了。

### 命令行方式

参考：

- [使用 strapi 快速构建 API 和 CMS 管理系统](https://cloud.tencent.com/developer/article/2236257)

官方推荐的创建项目命令：

```bash
npx create-strapi@latest my-api --quickstart --ts
```

> 提示：旧命令 `npx create-strapi-app@latest` 仍然可用，体验与新命令一致；但在 Strapi 5 中，`--quickstart` 已被标记为废弃，推荐改用 `--non-interactive`。

Strapi 创建项目的方式，类似于 Boinic 平台，有「项目」的概念。项目创建后通常需要自定义修改项目代码，所以在项目创建阶段不适合直接用 Docker 部署——这也正是官方没有提供统一镜像的原因。

## 参考

- [Strapi 官方文档](https://docs.strapi.io/)
- [strapi-docker（已归档）](https://github.com/strapi/strapi-docker)
- [探索开源世界：7 款引人入胜的殿堂级 CMS，从 WordPress 到 Strapi](https://zhuanlan.zhihu.com/p/652732748)
- [Strapi 及其类似产品 & WordPress 的介绍与对比](https://juejin.cn/post/7221545548574261308)
