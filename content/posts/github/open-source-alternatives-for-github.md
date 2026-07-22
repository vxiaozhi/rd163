+++
title = "GitHub 开源替代方案"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "自托管 Git 平台选型：Gogs、Gitea、GitBucket 与其他主流方案"
description = "梳理可自托管的 GitHub 开源替代方案，对比 Gogs、Gitea、GitBucket、GitLab CE 与 Forgejo 的技术栈、特性与适用场景，帮助团队按需选型。"
author = "小智晖"
authors = ["小智晖"]
categories = ["github"]
tags = ["github", "gitea", "gogs", "gitbucket", "self-hosted", "git"]
keywords = ["GitHub 替代方案", "Gitea", "Gogs", "GitBucket", "自托管 Git", "开源代码托管"]
toc = true
draft = false
+++

当团队需要在内部网络部署一套代码托管平台，或希望对仓库、issue、CI/CD 流程拥有完整控制权时，自托管的 Git 服务就成了 GitHub 之外的常见选择。本文梳理几个主流的开源替代方案，重点介绍三个轻量级项目 Gogs、Gitea、GitBucket，并补充 GitLab CE 与 Forgejo 作为对照。

## 选型维度

在比较这些方案前，先约定几个常见的选型维度：

- **部署复杂度**：是否提供单一二进制、是否依赖外部数据库、最低内存要求。
- **资源占用**：能否运行在树莓派或低配 VPS 上。
- **生态兼容性**：REST API 是否兼容 GitHub，CI/CD 是否能复用 GitHub Actions。
- **维护活跃度**：社区规模、发版节奏、治理模式。
- **技术栈**：决定二次开发、插件扩展的门槛。

## Gogs：用 Go 实现的极简 Git 服务

[Gogs](https://github.com/gogs/gogs)（读音 `/gɑgz/`，常被解读为 **Go Git Service**）是用 Go 语言实现的轻量级自托管 Git 服务，官方口号是 "The painless way to host your own Git service"。它是最早一批对标 GitHub 的开源项目之一，在 Go 圈子里被广泛参考。

**技术栈**：根据仓库统计，Go 代码约占 67.6%，Go Template 约占 15.6%，其余为 TypeScript、Less、Shell 等。它通过单一二进制分发，可以跑在 Linux、macOS、Windows 以及 ARM 设备上，官方宣称最低 64 MiB 内存即可运行，适合树莓派之类的嵌入式场景。

**主要特性**：

- 仓库、组织、团队管理，支持基于角色的访问控制（RBAC）。
- Pull Request、Issue、Wiki、Webhook 与 Git Hook。
- 认证支持 LDAP、SMTP、PAM。
- 数据库支持 MySQL、PostgreSQL、SQLite3、TiDB。
- 与 Drone CI、Jenkins 等外部 CI 工具配合使用。

**许可证**：自 2014 年起采用 MIT License。

Gogs 的最大局限在于治理结构——仓库长期由单一维护者控制，发版节奏相对缓慢，这也是后续 Gitea fork 的直接原因。

## Gitea：社区驱动的 Gogs 分支

[Gitea](https://github.com/go-gitea/gitea) 于 2016 年 11 月从 Gogs fork 而来，并在同年 12 月发布 1.0 版本。fork 的初衷是把项目改造为社区驱动的开发模式，避免单点维护导致的瓶颈。经过多年迭代，Gitea 已经成为 Go 生态里最活跃的自托管 Git 平台之一。

**技术栈**：同样以 Go 为核心，HTTP 路由使用 [Chi](https://github.com/go-chi/chi)，前端使用 Vite 构建，支持 SQLite3、MySQL、PostgreSQL、TiDB、MS SQL Server 等多种数据库，官方提供单一二进制和 Docker 镜像。

**相比 Gogs 增强的能力**：

- **Gitea Actions**：内置的 CI/CD 系统，工作流语法与 GitHub Actions 兼容，可以复用市场上大量现成的 Action。
- **Package Registry**：支持 npm、Docker、Maven、NuGet、PyPI、Cargo、Helm 等 20 余种包格式。
- **项目看板**：Issue、Label、Milestone、Kanban、时间追踪、依赖关系。
- **更完整的 API**：提供 REST 与部分 GraphQL 能力，迁移工具支持从 GitHub/GitLab 批量导入仓库。
- **跨架构**：在 Linux、Windows、macOS、FreeBSD，以及 x86、arm64 上均可运行。

**许可证**：MIT License。

需要注意的是，2022 年 10 月 Gitea 的核心维护者成立了 Gitea Limited 并引入托管服务，社区担忧项目走向 open-core 模式，于是 [Codeberg](https://codeberg.org/) 在 2022 年 12 月 fork 出了 Forgejo（详见下文）。Gitea 本身的核心代码仍然以 MIT 协议开源，但治理结构已成为选型时需要考量的因素。

一个最小化的 Docker 启动示例：

```bash
docker run -d --name gitea \
  -p 3000:3000 -p 2222:22 \
  -v gitea-data:/data \
  gitea/gitea:latest
```

启动后访问 `http://localhost:3000` 完成初始化即可。

## GitBucket：Scala 实现的 JVM 系选择

[GitBucket](https://github.com/gitbucket/gitbucket) 是用 Scala 编写的 Git 平台，基于 [Scalatra](https://scalatra.org/) Web 框架，使用 sbt 构建，底层 Git 操作依赖 Apache JGit。它在 JVM 生态的团队里比较受欢迎，尤其是已经部署了 Jenkins、Sonatype Nexus 等基于 JVM 的工具链的场景。

**技术栈**：根据仓库统计，Scala 约占 64.5%，HTML 约占 26.4%，其余为 JavaScript、Shell、CSS、Java 等。它以 WAR 包形式分发，运行需要 Java 17：

```bash
java -jar gitbucket.war
```

也可以部署到任何兼容 Servlet 3.0 的容器（Jetty、Tomcat、JBoss 等）。默认数据存储在 `$HOME/.gitbucket` 目录下，升级时停服替换 WAR 文件即可。

**主要特性**：

- 通过 HTTP/HTTPS 与 SSH 访问的公共/私有仓库。
- 支持 Git LFS。
- 仓库浏览器、在线文件编辑、Issue、Pull Request、Wiki。
- 活动时间线与邮件通知。
- 账户与组管理，支持 LDAP。
- 插件系统，可通过 Jenkins 插件与 CI 流水线联动。
- 提供 GitHub 兼容的 REST API，便于迁移。

**许可证**：Apache License 2.0。

相比 Gogs/Gitea 的单一二进制，GitBucket 的运行时依赖 JVM，启动内存稍高，更适合有现成 Java 运维经验的团队。

## 其他值得关注的方案

### GitLab CE

[GitLab](https://gitlab.com/gitlab-org/gitlab) 是功能最完整的开源 DevOps 平台之一，Community Edition 采用 MIT 协议。它由 Dmytro Zaporozhets 在 2011 年用 Ruby on Rails 创建，除 Ruby 外还大量使用 Go 和 JavaScript。GitLab CE 内置了完整的 CI/CD（GitLab Runner）、容器仓库、安全扫描、看板等，是 GitHub Enterprise 的直接对标品。代价是部署相对重——依赖 PostgreSQL、Redis、Sidekiq、Gitaly、Workhorse 等多个组件，官方推荐使用 Omnibus 包或 Helm Chart 安装。

### Forgejo

[Forgejo](https://codeberg.org/forgejo/forgejo) 是 2022 年 12 月从 Gitea fork 出来的社区项目，由非营利组织 Codeberg e.V. 管理商标与域名。最初与 Gitea 保持同步，2024 年 2 月从 1.21 版本起正式分家，并在 2024 年 8 月把整体许可证从 MIT 切换到 GPLv3+。功能上与 Gitea 基本对齐，差异主要在治理与许可证方向，对"项目必须留在非营利社区手中"的团队更具吸引力。

## 横向对比

| 项目     | 主要语言 | 许可证         | 部署形态              | 内置 CI/CD            | API 兼容 GitHub |
| -------- | -------- | -------------- | --------------------- | --------------------- | --------------- |
| Gogs     | Go       | MIT            | 单一二进制            | 无（外接 Drone 等）   | 部分            |
| Gitea    | Go       | MIT            | 单一二进制 / Docker   | Gitea Actions         | 较完整          |
| GitBucket| Scala    | Apache 2.0     | WAR（JVM）            | 无（Jenkins 插件）    | 兼容            |
| GitLab CE| Ruby/Go  | MIT            | Omnibus / Helm Chart  | GitLab Runner         | 自有            |
| Forgejo  | Go       | GPLv3+（2024） | 单一二进制 / Docker   | Forgejo Actions       | 较完整          |

## 选型建议

- **个人/小团队、低配服务器或树莓派**：优先考虑 Gogs 或 Gitea，单一二进制即可启动，内存占用低。
- **需要 CI/CD 与包管理、希望复用 GitHub Actions 生态**：选 Gitea；若更看重社区治理与 copyleft 许可，选 Forgejo。
- **JVM 技术栈、已部署 Jenkins 的企业内部环境**：GitBucket 的 Scala/JVM 体系与 WAR 部署方式更贴合现有运维。
- **需要一站式 DevOps 平台（含高级 CI/CD、安全扫描、容器仓库）**：GitLab CE 功能最全，但要承担更高的运维成本。

## 参考

- [Gogs 官网](https://gogs.io) / [Gogs GitHub 仓库](https://github.com/gogs/gogs)
- [Gitea 官网](https://about.gitea.com/) / [Gitea GitHub 仓库](https://github.com/go-gitea/gitea) / [Gitea 文档](https://docs.gitea.com/)
- [GitBucket GitHub 仓库](https://github.com/gitbucket/gitbucket)
- [GitLab 项目](https://gitlab.com/gitlab-org/gitlab)
- [Forgejo（Codeberg）](https://codeberg.org/forgejo/forgejo)
- [Gitea — Wikipedia](https://en.wikipedia.org/wiki/Gitea) / [Forgejo — Wikipedia](https://en.wikipedia.org/wiki/Forgejo) / [GitLab — Wikipedia](https://en.wikipedia.org/wiki/GitLab)
