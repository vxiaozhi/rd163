+++
title = "Higress 的 OCI 扩展插件"
date = "2025-03-29"
lastmod = "2025-03-29"
subtitle = "用 OCI 仓库管理 Higress 的 Wasm 插件"
description = "介绍 OCI 与 OCI Artifacts 的概念，以及如何使用 ORAS 客户端将 Higress Wasm 插件推送到 OCI 仓库进行管理。"
author = "小智晖"
authors = ["小智晖"]
categories = ["gateway"]
tags = ["gateway", "higress", "oci", "wasm", "oras"]
keywords = ["Higress", "OCI", "OCI Artifacts", "ORAS", "Wasm 插件", "OCI 仓库"]
toc = true
draft = false
+++

## OCI

OCI（Open Container Initiative，开放容器倡议）是一个轻量级、开放的治理组织，在 Linux 基金会的支持下成立，致力于围绕容器格式和运行时创建开放的行业标准。OCI 项目由 Docker、CoreOS（后被 Red Hat 收购，相应席位由 Red Hat 继承）以及容器行业的其他领导者于 2015 年 6 月启动。其技术委员会（Technical Oversight Board，TOB）成员随时间有所更迭，历史上曾包括 Red Hat、Microsoft、Docker、IBM、Google、SUSE 等，具体成员可查阅 [OCI Technical Oversight Board](https://github.com/opencontainers/tob)。

### OCI Artifacts

伴随着 image spec 与 distribution spec 的演化，人们逐步认识到：除了容器镜像（Container Images）之外，Registry 还能用来分发 Kubernetes Deployment 文件、Helm Charts、docker-compose、CNAB 等产物。它们可以共用同一套 API、同一套存储，将 Registry 当作一个云存储系统。这就催生了 OCI Artifacts 的概念——用户能够把所有产物都存储在兼容 OCI 的 Registry 中并进行分发。为此，Microsoft 将 oras 作为一个客户端实现捐赠给了社区，目前 oras 已是 CNCF（Cloud Native Computing Foundation）项目，包括 Harbor 在内的多个项目都在积极参与。

### OCI 仓库

- [Harbor](https://github.com/goharbor/harbor)：一个开源的可信云原生 Registry 项目，支持存储、签名和扫描内容。
- [distribution](https://github.com/distribution/distribution)：OCI 仓库的开源实现。

**distribution 基本用法**

启动一个本地 registry：

```bash
docker run -d -p 5000:5000 --name registry registry:2
```

然后就可以用 docker 命令像推拉普通镜像一样操作 OCI 仓库：

```bash
docker image tag ubuntu localhost:5000/myfirstimage
```

推送镜像：

```bash
docker push localhost:5000/myfirstimage
```

拉取镜像：

```bash
docker pull localhost:5000/myfirstimage
```

### OCI 客户端

- [ORAS CLI](https://github.com/oras-project/oras)
- [WASM to OCI](https://github.com/engineerd/wasm-to-oci)

**安装**

可参考[官方安装文档](https://oras.land/docs/installation)通过源码或包管理器安装，也可以在 macOS 上通过 Homebrew 安装：

```bash
brew install oras
```

拉取镜像（默认会拉取到当前文件夹，可通过 `-o` 参数指定存储位置）：

```bash
oras pull higress-registry.cn-hangzhou.cr.aliyuncs.com/plugins/ai-proxy:1.0.0
```

推送镜像到本地仓库：

```bash
oras push --insecure localhost:5000/ai_proxy:v1  \
    ./README.md:application/vnd.module.wasm.doc.v1+markdown \
    ./README_EN.md:application/vnd.module.wasm.doc.v1.en+markdown \
    ./README_dev.md:application/vnd.module.wasm.doc.v1.en+markdown \
    ./plugin.tar.gz:application/vnd.oci.image.layer.v1.tar+gzip
```

查看仓库是否推送成功：

```bash
# 列出仓库下的所有 repo
oras repo ls localhost:5000

# 查看指定 repo 的所有 tag
oras repo tags localhost:5000/ai_proxy
```

## Wasm 插件

Higress 使用 Wasm 插件来扩展网关功能，并采用 OCI 仓库来管理插件。

- [Wasm 插件镜像规范](https://higress.cn/docs/latest/user/wasm-image-spec/)：介绍插件格式、插件构建，以及使用 oras 命令推拉插件到 OCI 仓库。
- [使用 Go 语言开发 Wasm 插件并在本地用 Envoy 调试](https://higress.cn/docs/latest/user/wasm-go/)
- [支持的全部 Wasm 插件列表](https://github.com/higress-group/higress-console/blob/main/backend/sdk/src/main/resources/plugins/plugins.properties)

## 参考链接

- [Open Container Initiative](https://opencontainers.org/)
- [OCI Artifacts 官方说明](https://github.com/opencontainers/artifacts)
- [ORAS 官方文档](https://oras.land/)
- [Higress 官方文档](https://higress.cn/docs/latest/overview/what-is-higress/)
