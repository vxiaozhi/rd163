+++
title = "Docker Desktop 开源替代方案"
date = "2025-10-15"
lastmod = "2025-10-15"
subtitle = "Rancher Desktop、Podman Desktop 与 apple/container 三款开源方案横向对比"
description = "Docker Desktop 自 2021 年调整订阅条款后,大型企业使用需付费。本文横向对比 Rancher Desktop、Podman Desktop 与 apple/container 三款主流开源替代方案的特性与适用场景。"
author = "小智晖"
authors = ["小智晖"]
categories = ["docker"]
tags = ["docker", "rancher-desktop", "podman", "apple-container", "容器", "开源"]
keywords = ["Docker Desktop", "Rancher Desktop", "Podman Desktop", "apple container", "开源替代", "容器运行时"]
toc = true
draft = false
+++

Docker Desktop 一直是 macOS 和 Windows 上最便利的容器开发环境，但自 2021 年 8 月 31 日 Docker 调整订阅条款后，员工数 ≥ 250 人**或**年营收 ≥ 1000 万美元的企业必须购买付费订阅才能合规使用。Docker Engine 本身仍是 Apache 2.0 开源，但 Docker Desktop 这一桌面发行版不再免费。这一变化促使社区涌现出一批高质量的开源替代方案。

本文聚焦三款各具特色的桌面端开源方案:[Rancher Desktop](https://github.com/rancher-sandbox/rancher-desktop)、[Podman Desktop](https://github.com/podman-desktop/podman-desktop) 与 Apple 官方的 [apple/container](https://github.com/apple/container),并给出横向对比与选型建议。

## Rancher Desktop

[Rancher Desktop](https://github.com/rancher-sandbox/rancher-desktop) 由 Rancher(SUSE 旗下)以 Apache-2.0 协议开源，是一个用 TypeScript + Go 编写的 Electron 应用，目标是「在桌面端同时管理容器和 Kubernetes」。截至撰稿时 GitHub star 数约 7.2k。

**跨平台支持**。覆盖 Windows、macOS(含 Intel 与 Apple Silicon)与 Linux 三大平台;其中 macOS 和 Windows 通过 Lima/WSL2 运行一个轻量 Linux 虚拟机，Linux 则直接以原生进程方式运行。

**双容器运行时**。在 Preferences → Container Engine 中可在 `moby`(dockerd)与 `containerd` 之间切换:

- 选择 **moby/dockerd** 时，提供原生 `docker`、`docker-compose` CLI，暴露 `docker.sock`,与现有 Docker 工作流完全兼容;
- 选择 **containerd** 时，搭配 `nerdctl`(containerd 官方的 Docker 兼容 CLI)与 `nerdctl compose`,更贴近 Kubernetes 上游，但部分 Docker 专有 API 不可用。

注意切换运行时会清空已有的镜像和卷，因为两种运行时使用各自的存储。

**内置 k3s**。Rancher Desktop 内嵌 Rancher 的轻量级 Kubernetes 发行版 [k3s](https://github.com/k3s-io/k3s),可在本地一键拉起一个真正的 K8s 集群并自由选择版本，这对需要在本地调试 Helm Chart、Operator 或 CRD 的开发者非常友好。

此外，它还提供一个 Go 编写的 CLI 工具 `rdctl`,通过 HTTP API(目前标记为实验性)对应用进行脚本化控制。

## Podman Desktop

[Podman Desktop](https://github.com/podman-desktop/podman-desktop) 是一个面向容器与 Kubernetes 的图形化桌面应用，Apache-2.0 协议，隶属于 Linux Foundation 旗下的 LF Projects(注意:并非 CNCF 沙箱项目)。它本身不是容器引擎，而是为底层引擎提供统一的 dashboard 与工作流。

**真正的跨平台 GUI**。官方明确支持 Linux、macOS 与 Windows，提供 `.exe`、`.dmg`、Flatpak、AppImage 等多种安装包，Windows 还可 `winget install RedHat.Podman-Desktop`,macOS 可 `brew install --cask podman-desktop`。

**多引擎接入**。这是它区别于其他方案的关键——它能同时对接多种容器引擎:

- **Podman**:Red Hat 出品的 daemonless、rootless 容器引擎，命令行与 `docker` 高度兼容(`alias docker=podman` 几乎可以无缝切换);
- **Docker**:也可直接接管本机或远程的 Docker 引擎;
- **Lima** 与 **crc**(OpenShift Local)。

**Kubernetes 友好**。可在系统托盘里管理 Kubernetes context，把本地 Pod 推送到远端集群，或在本地直接以 Pod 方式运行工作负载。还内置 OCI 镜像仓库管理与代理配置，适合企业内网环境。

由于 Podman 引擎本身无守护进程且默认 rootless，在安全性上相较传统 dockerd 有天然优势，这也是大量团队从 Docker Desktop 迁移过来的首要理由。

## apple/container

[apple/container](https://github.com/apple/container) 是 Apple 于 2025 年开源的官方容器工具，与同名 `container` CLI 配套。仓库 97.9% 由 Swift 编写，Apache-2.0 协议，目前在 GitHub 上已有约 4.8 万 star。

它官方定义为「在 Mac 上以轻量级虚拟机方式创建和运行 Linux 容器」。每个容器实际上运行在一个极简的 Linux VM 中，具备独立内核与强隔离，但启动开销远低于传统完整 VM。

**关键约束**:

- **必须使用 Apple 芯片**。README 明确「需要一台搭载 Apple 芯片的 Mac 才能运行 `container`」;
- **仅支持 macOS 26 及以上**。它依赖该版本引入的虚拟化与网络新特性，旧版 macOS 无法运行。

**OCI 兼容**。它消费和产出的都是标准 OCI 镜像，可以 `pull`、`run`、`push` 与任意公共或私有镜像仓库交互，无需重新打包。底层由 Apple 同时开源的 [containerization](https://github.com/apple/containerization) Swift 包负责 VM/镜像/进程管理。

**常用命令**:

```bash
# 安装后启动系统服务
container system start

# 停止服务(升级或降级前执行)
container system stop

# 升级到最新版本
/usr/local/bin/update-container.sh

# 卸载并删除用户数据
/usr/local/bin/uninstall-container.sh -d
```

项目演进迅速,自 1.0.0 起已进入稳定阶段(截至撰稿时最新为 1.1.0),早期版本曾声明「1.0 之前不保证次要版本间无破坏性变更」,生产环境采用前仍建议关注其 release notes。

## 横向对比

| 维度 | Rancher Desktop | Podman Desktop | apple/container |
|---|---|---|---|
| 出品方 | Rancher(SUSE) | LF Projects / Red Hat 系 | Apple |
| 协议 | Apache-2.0 | Apache-2.0 | Apache-2.0 |
| Windows | 支持 | 支持 | 不支持 |
| macOS(Intel) | 支持 | 支持 | 不支持 |
| macOS(Apple Silicon) | 支持 | 支持 | 支持（需 macOS 26） |
| Linux | 支持 | 支持 | 不支持 |
| 容器运行时 | moby / containerd | Podman / Docker / Lima / crc | 轻量 VM(OCI 镜像) |
| 内置 Kubernetes | 是（k3s） | 上下文管理 + Pod 部署 | 否 |
| 是否图形界面 | 是（Electron） | 是 | 否（CLI 为主） |
| Docker CLI 兼容 | 是 | 是（Podman 兼容） | 部分（OCI 镜像兼容） |

## 选型建议

- **追求与 Docker Desktop 体验最接近、且需要本地 Kubernetes**:首选 **Rancher Desktop**,`moby` 运行时几乎可以无缝替换，内置 k3s 是额外加分项。
- **重视 rootless 安全、希望同时管理多引擎、或已在使用 RHEL 系技术栈**:选 **Podman Desktop**,GUI 完善，LF Projects 社区活跃，Podman 在企业 Linux 中也已广泛部署。
- **使用 Apple 芯片 Mac、且系统已升级到 macOS 26、想用最小开销跑 Linux 容器**:可以尝试 **apple/container**,作为 Apple 一方方案，未来与系统集成度最高，但目前尚不适合作为团队统一标准。

三款工具均以 Apache-2.0 开源，可放心用于商业场景。如果在企业内部做标准化，建议结合团队现有 OS、是否依赖 `docker.sock`、是否需要本地 K8s 这三个核心问题做一轮内部 PoC 后再决策。

## 参考

- [Rancher Desktop 官网](https://rancherdesktop.io) / [文档](https://docs.rancherdesktop.io) / [GitHub](https://github.com/rancher-sandbox/rancher-desktop)
- [Podman Desktop 官网](https://podman-desktop.io) / [GitHub](https://github.com/podman-desktop/podman-desktop)
- [Podman 官网](https://podman.io) / [GitHub](https://github.com/containers/podman)
- [apple/container GitHub](https://github.com/apple/container) / [containerization](https://github.com/apple/containerization) / [文档](https://apple.github.io/container/documentation/)
- [Docker Subscription Service Agreement FAQ](https://www.docker.com/legal/docker-subscription-service-agreement-faq)