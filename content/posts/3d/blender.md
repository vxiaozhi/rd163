+++
title = "Blender 简介"
date = "2025-01-10"
lastmod = "2025-01-10"
subtitle = "开源 3D 创作套件与服务端无头渲染实践"
description = "Blender 是基于 GPL 协议的开源 3D 创作套件，覆盖建模、动画、渲染全流程。本文介绍其核心能力、命令行无头渲染、Python 自动化与 Docker 部署实践。"
author = "小智晖"
authors = ["小智晖"]
categories = ["3d"]
tags = ["3d", "blender", "rendering", "docker", "python"]
keywords = ["Blender", "无头渲染", "Cycles", "EEVEE", "bpy", "Docker"]
toc = true
draft = false
+++

Blender 是一款免费开源（GPL-3.0 协议）的 3D 创作套件（3D creation suite），由 Blender Foundation 维护。它并非单一的建模工具，而是覆盖了整个 3D 制作管线：建模（modeling）、绑骨（rigging）、动画（animation）、模拟（simulation）、渲染（rendering）、合成（compositing）、运动跟踪（motion tracking）以及视频剪辑（video editing）。官方将其定位为"the free and open source 3D creation suite"。

项目主仓库托管在 [projects.blender.org](https://projects.blender.org/)，GitHub 上的 [blender/blender](https://github.com/blender/blender) 为只读镜像。源码以 C++ 为主（约 80%），Python 约占 15%——后者既是内置脚本接口，也是 addon（插件）生态的基础。Blender 每 2-3 个版本会发布一个 LTS（长期支持）版本，例如 Blender 4.2 LTS 引入了 EEVEE Next 渲染器重写与全新的 Extensions Platform（扩展平台，取代旧的 addon 体系）。

## 核心能力速览

- **建模**：内置多边形建模、雕刻（Sculpt）、曲线、网格编辑器与修改器栈（modifier stack）。
- **动画与绑骨**：骨骼系统（Armature）、形态键（Shape Keys）、非线性动画编辑器（NLA）。
- **渲染引擎**：
  - **Cycles**：基于物理的路径追踪渲染器（path tracer），支持 CPU 与 GPU（CUDA / OptiX / HIP / Metal / oneAPI）。
  - **EEVEE**（新一代称 EEVEE Next）：实时渲染器，适合预览与高性能场景。
  - **Workbench**：用于视图实时显示的轻量引擎。
- **Python API**：通过 `bpy` 模块暴露几乎全部功能，可编写脚本完成自动化、批量处理与自定义工具。

## 学习资源

入门建议从官方 [Blender Manual](https://docs.blender.org/manual/en/latest/) 与 [Blender Python API](https://docs.blender.org/api/current/) 入手。社区资源中，[puxiao/notes 的 Blender 基础教程](https://github.com/puxiao/notes/blob/master/Blender%E5%9F%BA%E7%A1%80%E6%95%99%E7%A8%8B.md) 是一份不错的中文起点，重点梳理了界面布局、视图导航与快捷键速查表（注意：它偏向 UI 与操作入门，不含建模或渲染流程实战）。

## 服务端渲染与无头模式

服务端渲染（server-side rendering）是 Blender 在自动化管线中最常见的场景——CI 生成缩略图、集群批量出帧、3D 文件预览等。Blender 原生支持无头（headless）运行，无需任何图形界面。

### 关键命令行参数

下面是 [Command Line Arguments](https://docs.blender.org/manual/en/latest/advanced/command_line/arguments.html) 文档中常用的渲染相关参数：

| 参数 | 长形式 | 说明 |
|------|--------|------|
| `-b` | `--background` | 后台运行（无 UI），常用于服务端渲染。后台模式下音频设备默认禁用，可通过 `--setaudio Default` 重新启用。 |
| `-f <frame>` | `--render-frame <frame>` | 渲染指定单帧，支持子帧（如 `-f 50.5`）。 |
| `-s <frame>` | `--render-start <frame>` | 起始帧（与 `-a` 配合）。 |
| `-e <frame>` | `--render-end <frame>` | 结束帧。 |
| `-j <step>` | `--render-jump <step>` | 帧步进。 |
| `-a` | `--render-anim` | 渲染动画范围。 |
| `-o <path>` | `--render-output <path>` | 输出路径，`//` 表示 .blend 文件所在目录。 |
| `-F <fmt>` | `--render-format <fmt>` | 输出格式，如 `PNG`、`JPEG`、`EXR`、`AVIJPEG`。 |
| `-x <bool>` | `--render-extension <bool>` | 是否自动添加文件扩展名。 |
| `-E <engine>` | `--engine <engine>` | 指定渲染引擎，如 `CYCLES`、`BLENDER_EEVEE_NEXT`。 |
| `-P <file>` | `--python <file>` | 启动后执行 Python 脚本。 |
| `-y` | `--enable-autoexec` | 允许 Python 脚本自动执行（默认出于安全考虑禁用）。 |

此外还有 `--cycles-device CPU|CUDA|OPTIX|HIP|METAL|ONEAPI`（指定渲染设备）与 `--threads <n>`（CPU 线程数）。

### 典型示例

渲染单帧到 PNG：

```bash
blender -b scene.blend -o //render_ -F PNG -x 1 -f 42
```

该命令打开 `scene.blend`、后台渲染第 42 帧，输出到 .blend 同级目录的 `render_0042.png`。

用 Cycles + OptiX 渲染一段动画：

```bash
blender -b scene.blend \
  -E CYCLES \
  --cycles-device OPTIX \
  -s 1 -e 100 -j 1 -a \
  -o //frames/#### -F PNG -x 1
```

## Python 自动化：bpy 与 Blenderless

### 内置 bpy 模块

`bpy` 是 Blender 内嵌的 Python 模块，仅在 Blender 自带的 Python 解释器中可用，**不能直接 `pip install bpy`** 用作普通第三方库（官方有一个实验性的 bpy wheel，但功能受限且版本同步滞后）。常规做法有两种：

1. 通过 Blender 启动器加载脚本：
   ```bash
   blender -b --python myscript.py
   ```
2. 调用 Blender 内置解释器：
   ```bash
   /path/to/blender/<version>/python/bin/python
   ```

一个最小示例——批量修改场景中所有网格的名称并导出截图：

```python
import bpy

for obj in bpy.data.objects:
    if obj.type == 'MESH':
        obj.name = f"Mesh_{obj.name}"

bpy.context.scene.render.filepath = "//preview.png"
bpy.context.scene.render.image_settings.file_format = 'PNG'
bpy.ops.render.render(write_still=True)
```

### Blenderless：封装无头渲染的 Python 库

如果觉得直接调 `bpy` 上手成本较高，可以使用 [Blenderless](https://github.com/oqton/blenderless)——一个为简化无头渲染而设计的 Python 包（GPL-3.0，作者 Oqton）。它把常用渲染流程封装为更易用的接口：

- 从 STL 等网格文件直接渲染成 PNG（可配置相机方位角 azimuth、仰角 elevation、旋转角 theta）；
- 通过 YAML 配置文件定义场景、相机、材质与预设；
- 生成相机环绕物体的 GIF 动画；
- 多网格合成场景、批量出图、把场景导出为 `.blend` 文件。

典型用途包括 3D 资源库的缩略图生成、机器学习数据集的多视角采集等。

## Docker 化部署

把 Blender 容器化可以让渲染环境与宿主机解耦，便于在 CI 或集群中复用。

**[linuxserver/docker-blender](https://github.com/linuxserver/docker-blender)** 是社区中知名度较高的镜像（Docker Hub：[linuxserver/blender](https://hub.docker.com/r/linuxserver/blender)）。但需要注意一个重要前提：**它面向浏览器内的交互式工作区，而非生产级无头渲染**——README 明确指出"this image does not support GPU rendering out of the box only accelerated workspace experience"，即仅加速工作区体验，开箱不支持 GPU 渲染。容器默认走 Wayland 栈，通过 `https://<host>:3001/` 访问图形界面，默认无鉴权且内置带免密 sudo 的终端，**不适合直接暴露到公网**。

如果目标是纯无头渲染（而非图形工作区），更合适的选择是面向 CLI 渲染的镜像，例如基于 `fredblgr/docker-blender` 的 NVIDIA GPU 镜像，或自行从官方 Blender Linux 包构建轻量镜像：

```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y \
    blender \
    libxrender1 libxi6 libxkbcommon0 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /work
ENTRYPOINT ["blender", "-b"]
```

调用示例：

```bash
docker run --rm \
  -v "$PWD":/work \
  -w /work \
  my-blender \
  scene.blend -o //out_ -F PNG -f 1
```

需要 GPU 加速时再加 `--gpus all` 与对应运行时（NVIDIA Container Toolkit）。

## 小结

Blender 的价值在于它既是面向艺术家的完整桌面工具，又能通过 `-b` 无头模式、`bpy` Python API 与容器化部署无缝融入工程化、自动化管线。选型时务必区分两类需求：**交互式图形工作区**适合 linuxserver/docker-blender 这类带 Web UI 的镜像；**批量无头渲染**则应回归 `blender -b` 命令行或自建轻量镜像，并按需启用 GPU。

## 参考

- [Blender 官网与下载](https://www.blender.org/)
- [Blender Manual — Command Line Arguments](https://docs.blender.org/manual/en/latest/advanced/command_line/arguments.html)
- [Blender Python API (bpy)](https://docs.blender.org/api/current/)
- [blender/blender — GitHub 镜像](https://github.com/blender/blender)
- [Blenderless — 无头渲染 Python 包](https://github.com/oqton/blenderless)
- [linuxserver/docker-blender](https://github.com/linuxserver/docker-blender)
- [puxiao/notes — Blender 基础教程（中文）](https://github.com/puxiao/notes/blob/master/Blender%E5%9F%BA%E7%A1%80%E6%95%99%E7%A8%8B.md)
