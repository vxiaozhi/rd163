+++
title = "Conda 的替代品"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Anaconda 商业授权收紧后的环境与包管理方案"
description = "梳理 Anaconda 商业授权变更背景,介绍 Miniforge、Mamba、micromamba、uv、Pixi 等 Conda 替代方案的特点与适用场景。"
author = "小智晖"
authors = ["小智晖"]
categories = ["python"]
tags = ["编程语言", "python", "conda", "包管理", "环境管理"]
keywords = ["conda", "miniforge", "mamba", "micromamba", "uv", "pixi"]
toc = true
draft = false
+++

## 背景：为什么需要替代品

长期以来，Anaconda Distribution 和 Miniconda 是 Python 数据科学与科学计算场景下最常用的发行版。然而自 2020 年起，Anaconda, Inc. 更新了其服务条款（Terms of Service）,对商业用途做出了限制:

> 员工及承包商（含关联方）人数达到或超过 **200 人**的组织，需要购买商业版（Business）授权才能合法地在内部业务中使用 Anaconda 的包仓库(主要是 `defaults` 频道)。

商业版定价约为 **$50/用户/月**;200 人以下的组织可以使用 Starter($15/用户/月)或免费版。学术机构与非营利研究机构通常可以申请豁免。需要注意的是:

- 受限的是 Anaconda, Inc. 维护的 `defaults` 频道及其打包产物，而非 conda 工具本身（conda 本体仍为 BSD 开源）。
- 社区维护的 [conda-forge](https://conda-forge.org/) 频道是独立项目，不受该条款约束。

因此,"换掉 Anaconda/Miniconda"在工程上的常见做法是:**保留 conda(或兼容工具),改用 conda-forge 作为唯一频道**,或者彻底迁移到非 conda 生态的工具。

## Miniforge:最贴近原体验的替代

[Miniforge](https://github.com/conda-forge/miniforge) 由 conda-forge 社区维护，定位与 Miniconda 类似，但有两点关键差异:

1. **默认频道只有 conda-forge**:开箱即用，不再拉取 Anaconda 的 `defaults` 频道，从源头上规避了商业授权问题。
2. **同时内置 conda 和 mamba**:自 2023 年 8 月的 23.3.1 版本起，Miniforge 已经在 base 环境中附带 mamba。原先的 `Mambaforge` 发行版已废弃，统一并入 Miniforge3。

支持的平台比较全:Linux(x86_64、aarch64、ppc64le)、macOS(Intel 与 Apple Silicon)、Windows(x86_64)。最新版 base 环境 Python 为 3.13。

对于"原来装 Miniconda，现在想无缝迁移"的团队，Miniforge 基本是首选，语法、工作流与 conda 完全一致。

## Mamba:更快版本的 conda

[Mamba](https://github.com/mamba-org/mamba) 是 conda 的 C++ 重新实现，核心改进有三:

- **并行下载**:多线程拉取仓库索引和包文件。
- **快速依赖求解**:使用 [libsolv](https://github.com/openSUSE/libsolv)——与 Red Hat / Fedora / openSUSE 的 RPM 包管理器相同的 SAT 求解库，解决了 conda 经典求解器在复杂依赖图下"转半天"甚至无解的老问题。
- **复用 conda 的 CLI 与事务逻辑**:命令行参数、安装/卸载、事务校验与 conda 高度一致，迁移成本低。

如果已经装了 Miniforge，直接用 `mamba install xxx` 替代 `conda install xxx` 即可享受加速;其余命令(`create`、`activate`、`list`)几乎一一对应。

值得一提的是，自 **conda 23.10.0**(2023 年 10 月)起，conda 本身已将 `conda-libmamba-solver` 设为默认求解器，也就是说新版 `conda` 在依赖求解这一环节已经用上了 libmamba，差距主要剩下"是否并行下载"和"是否需要单独安装"。

## micromamba:CI/CD 与容器的首选

micromamba 是 mamba 的**静态链接版本**,单一可执行文件，不依赖 Python、不需要 base 环境，体积小、启动快，非常适合 CI/CD 流水线和 Docker 镜像。安装命令（Linux/macOS）:

```bash
"${SHELL}" <(curl -L micro.mamba.pm)
```

Windows PowerShell:

```powershell
Invoke-Expression ((Invoke-WebRequest -Uri https://micro.mamba.pm/install.ps1 -UseBasicParsing).Content)
```

典型用法:

```bash
# 创建环境并安装包(用 -n 指定名字)
micromamba create -n myenv python=3.12 'pytest>=8.0'
micromamba run -n myenv pytest tests/

# 在 CI 里一行跑命令,免去 shell init
micromamba run -p /tmp/env pytest myproject/tests
```

`micromamba self-update` 可以原地升级自身，便于在镜像里维护。

## 跳出 conda 生态:uv 与 Pixi

如果项目主要依赖纯 PyPI 包，完全可以不使用 conda 系工具。

### uv

[uv](https://github.com/astral-sh/uv) 来自 Astral(Ruff 的作者),用 Rust 编写，号称比 pip 快 **10-100 倍**。它的定位非常激进——一个工具替代 `pip`、`pip-tools`、`pipx`、`poetry`、`pyenv`、`virtualenv`:

- `uv pip` 子命令是 pip 的 drop-in 替代，迁移成本低;
- `uv venv --python 3.12.0` 一键创建指定 Python 版本的虚拟环境;
- `uv init` / `uv add` / `uv lock` / `uv sync` 提供 Cargo 风格的项目管理与锁文件;
- `uvx <pkg>` 等价于 `pipx run`,临时运行 CLI 工具;
- 自带全局缓存，跨项目共享依赖，节省磁盘。

### Pixi

[Pixi](https://github.com/prefix-dev/pixi) 由 prefix.dev 团队开发，同样用 Rust 编写，底层基于 [rattler](https://github.com/conda/rattler)。它的特点是**同时打通 conda 生态与 PyPI**:既能装 conda-forge 上的二进制包（适合带原生依赖的 C++/R 库）,也能装纯 Python 包，并自带类似 Cargo 的 `pixi.toml` 项目工作流。对于同时需要 CUDA、GDAL、科学计算库这类"pip 装起来很痛苦"的场景，Pixi 是一个值得关注的现代选择。

## 如何选择

| 场景 | 推荐 |
|------|------|
| 团队从 Miniconda 无缝迁移、规避商业授权 | **Miniforge** |
| 想要更快的 conda 体验、习惯 conda CLI | **Mamba** 或新版 conda(已默认 libmamba) |
| CI/CD、Docker 镜像、最小依赖 | **micromamba** |
| 纯 Python 项目、追求极致速度 | **uv** |
| 混合 conda 包与 PyPI 包、现代化项目工作流 | **Pixi** |

实际项目中这些工具并非互斥：例如 base 用 Miniforge、CI 里用 micromamba、应用代码层用 uv 管理 PyPI 依赖，都是常见的组合。

## 参考

- [Anaconda Terms of Service / Pricing FAQ](https://www.anaconda.com/pricing)
- [Miniforge](https://github.com/conda-forge/miniforge)
- [Mamba](https://github.com/mamba-org/mamba) / [mamba 文档](https://mamba.readthedocs.io/)
- [micromamba 安装指南](https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html)
- [conda-libmamba-solver](https://github.com/conda/conda-libmamba-solver)
- [conda-forge](https://conda-forge.org/)
- [uv](https://github.com/astral-sh/uv)
- [Pixi](https://github.com/prefix-dev/pixi)
