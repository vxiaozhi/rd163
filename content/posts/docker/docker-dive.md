+++
title = "dive"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "按层剖析 Docker 镜像、定位冗余空间的命令行利器"
description = "dive 是一个用 Go 编写的开源 CLI 工具,可以按层展开 Docker/OCI 镜像内容,计算镜像效率并发现冗余空间,还能集成到 CI 中对镜像体积做卡点。"
author = "小智晖"
authors = ["小智晖"]
categories = ["docker"]
tags = ["docker", "dive", "镜像优化", "ci"]
keywords = ["dive", "docker", "镜像分析", "镜像优化", "OCI"]
toc = true
draft = false
+++

在写 Dockerfile 时,我们经常会遇到一个问题:镜像构建出来后,只能看到一个最终体积,却不知道每一层(layer)到底加了什么、改了什么、又被覆盖或删除了什么。`docker history` 只能给出粗略的命令和尺寸,无法看到具体的文件变化。

[dive](https://github.com/wagoodman/dive) 就是为了解决这个问题。它由 Alex Goodman(wagoodman)开发,使用 Go 编写,以 MIT 协议开源,目前在 GitHub 上有超过 5.4 万个 star。它可以在终端里以交互式 UI 展开镜像,按层浏览文件树,并给出一个衡量「镜像浪费空间」的效率分。

## 核心能力

dive 的价值集中在四件事上。

**按层展开镜像**。选中某一层时,左侧会展示该层叠加所有前序层之后的完整文件树;右侧给出当前层以及「当前层 + 前序层累计」两种视角下的修改、新增、删除情况。

**变更标识**。在文件树中,被修改、新增、删除的文件会以不同颜色高亮,可以单独看当前层,也可以看聚合后的结果。这对排查「明明 `rm` 了为什么镜像没变小」这类问题非常直观。

**镜像效率评估(Efficiency)**。dive 会扫描所有层,统计被后续层覆盖、移动或未完整删除的文件,给出一个 0–100% 的效率分以及浪费的字节数。这个指标是它区别于 `docker history` 的关键。

**构建即分析**。`dive build` 会调用 Docker 构建镜像,构建完成后立刻进入分析界面,省去「先 build 再 dive」的两步操作。

## 安装

dive 是单文件二进制,常见平台的安装方式如下:

```bash
# macOS
brew install dive

# Arch Linux
pacman -S dive

# Ubuntu/Debian:从 GitHub Releases 下载 .deb 后安装
# https://github.com/wagoodman/dive/releases

# Windows
winget install --id wagoodman.dive
# 或
scoop install main/dive
# 或
choco install dive

# 通过 Go 安装(需要 Go 工具链)
go install github.com/wagoodman/dive@latest

# 直接用 Docker 运行(挂载 docker.sock)
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  wagoodman/dive:latest <image-tag>
```

截至 2025 年 3 月,dive 的最新稳定版本为 v0.13.1。

## 基本用法

分析一个已经存在的镜像:

```bash
dive nginx:alpine
```

构建并立即分析:

```bash
dive build -t my-app:latest .
```

分析一个导出好的 tar 包(无需连接 Docker daemon):

```bash
dive --source docker-archive image.tar
```

`--source` 支持三种来源:`docker`(默认,连接本地 Docker engine)、`docker-archive`(tar 文件)、`podman`(Linux 上连接 Podman engine)。

## 交互式 UI 快捷键

进入界面后,左右两栏之间用 `Tab` 切换;文件树支持常见的 Vim 风格导航:

- `Tab`:在「层列表」与「文件树」之间切换
- `Ctrl + F`:按文件名过滤
- `J` / `K` 或方向键:上下移动
- `Space`:折叠/展开目录
- `Ctrl + A` / `Ctrl + R` / `Ctrl + M` / `Ctrl + U`:分别切换显示新增、删除、修改、未变更的文件

熟练之后,定位冗余文件通常只需几秒钟。

## 一个典型的优化场景

假设有一个基于 Python 的镜像,体积异常大。用 dive 打开后,可能会看到类似下面的情况:

```text
Layer 12  COPY requirements.txt
Layer 13  RUN pip install -r requirements.txt
Layer 14  COPY . /app
Layer 15  RUN rm -rf /app/tests
```

在 Layer 15 上,虽然执行了 `rm -rf /app/tests`,但因为 `tests` 目录是在 Layer 14 写入的,它仍然作为只读层存在于镜像历史中,实际并没有让镜像变小——dive 会把这部分标为「wasted bytes」。

这时正确的做法通常是:在同一个 `RUN` 中清理,或者用 `.dockerignore` 在构建前就排除测试目录,dive 的效率分能直接反映出这种改动带来的收益。

## 集成到 CI

dive 提供了非交互式的 CI 模式,通过对镜像体积设阈值,把「镜像臃肿」变成一个可被流水线拦截的硬性指标。

启用方式是设置环境变量 `CI=true`(dive 启动时检测到该变量即进入 CI 模式)。

```bash
CI=true dive my-app:latest
```

在仓库根目录放置一个 `.dive-ci` 文件来定义阈值:

```yaml
rules:
  # 镜像效率低于 0.95 则失败
  lowestEfficiency: 0.95
  # 浪费空间超过 20MB 则失败
  highestWastedBytes: 20MB
  # 浪费空间占用户层比例超过 20% 则失败(不计基础层)
  highestUserWastedPercent: 0.20
```

三个规则的含义:

| 规则 | 类型 | 说明 |
|---|---|---|
| `lowestEfficiency` | 0–1 之间的比例 | 效率分低于该值时失败 |
| `highestWastedBytes` | 带单位的字节数(`B`/`KB`/`MB`/`GB`) | 浪费空间达到该值时失败 |
| `highestUserWastedPercent` | 0–1 之间的比例 | 浪费空间占用户层比例达到该值时失败(基础层不计入) |

如果配置文件不在根目录,可以用 `--ci-config` 指定路径。CI 模式下 dive 退出码为 0 表示通过,非 0 表示失败,可直接对接 GitHub Actions、GitLab CI 等流水线。

## 与 docker history 的区别

`docker history` 能给出每一层执行了什么命令、占多少空间,但看不到具体文件的变化;而且它的尺寸是各层「自描述」的尺寸,并不反映后续层覆盖带来的浪费。dive 弥补了这两点:

- 看到每一层实际新增、修改、删除了哪些文件
- 计算出被覆盖/未清理文件造成的真实浪费
- 支持 CI 卡点,而 `docker history` 只能靠人眼判断

## 小结

dive 是排查镜像体积问题最趁手的工具之一。交互式 UI 适合本地构建时的随手检查,CI 模式则能防止镜像随着时间的推移悄悄膨胀。配合 `.dockerignore`、多阶段构建(multi-stage build)和基础镜像选型,可以把镜像效率分稳定地维持在一个较高水平。

## 参考

- [wagoodman/dive — GitHub 仓库](https://github.com/wagoodman/dive)
- [dive Releases](https://github.com/wagoodman/dive/releases)
- [Docker 官方文档:镜像与层](https://docs.docker.com/engine/reference/glossary/#image)
