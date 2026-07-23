+++
title = "ComfyUI教程"
date = "2025-03-10"
lastmod = "2025-03-10"
subtitle = "从安装、模型下载到 GGUF 量化与 API 调用的实战入门"
description = "面向新手的 ComfyUI 入门教程,涵盖桌面版安装、扩展管理、模型下载、工作流加载、GGUF 量化模型使用与 API 调用,并附 Mac M1 实测数据。"
author = "小智晖"
authors = ["小智晖"]
categories = ["aigc"]
tags = ["ComfyUI", "StableDiffusion", "Flux", "GGUF", "AIGC"]
keywords = ["ComfyUI", "ComfyUI教程", "GGUF量化", "Flux schnell", "ComfyUI API", "StableDiffusion"]
toc = true
draft = false
+++

## 术语解释

- VAE:变分自动编码器（Variational Autoencoder）,负责图像在像素空间与潜空间之间的转换。
- CLIP 模型：全称 Contrastive Language-Image Pre-Training(对比式语言-图像预训练模型),用于将文本编码为模型可理解的特征。
- T5:Google 提出的文本编码器，FLUX 等模型用它来理解更复杂、更长的提示词。

## 安装

参考 GitHub 官方仓库，直接下载桌面安装包:

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI)

> 目前推荐使用官方桌面版（ComfyUI Desktop）,Windows / macOS / Linux 均有安装包，自带 Python 环境，免去手动配置的麻烦。

官方还提供了各模型的示例工作流与使用说明:

- [ComfyUI_examples](https://github.com/comfyanonymous/ComfyUI_examples)

## 安装扩展

- [ComfyUI-Manager](https://github.com/ltdrdata/ComfyUI-Manager):节点与模型管理器。官方桌面版（0.4.x 起）已默认内置该扩展，使用桌面版可跳过下面的手动安装步骤。

如果使用源码部署，可选用最直接的 Git clone 安装方法。

第 1 步，克隆仓库:

```bash
cd ~/Documents/ComfyUI/custom_nodes
git clone https://github.com/ltdrdata/ComfyUI-Manager comfyui-manager
```

第 2 步，重启 ComfyUI 即可在菜单中看到「Manager」按钮。

## 模型下载

有两种方式:

1. 通过 ComfyUI-Manager 下载模型（Manager -> Model Manager）。
2. 手动下载模型，然后将模型文件放入 `~/Documents/ComfyUI/models/checkpoints` 文件夹中。

## Workflow 加载

有以下几种方式:

1. 通过菜单 Workflow -> Browse Templates 浏览并加载内置模板。
2. 把包含工作流元数据的图片拖入工作流窗口，ComfyUI 会自动解析并打开对应工作流。可参考官方示例:[flux](https://comfyanonymous.github.io/ComfyUI_examples/flux/)。
3. 下载第三方 workflow(JSON 文件),然后拖入工作流窗口加载。

## GGUF 量化模型

默认的模型，例如 [FLUX.1-schnell](https://huggingface.co/black-forest-labs/FLUX.1-schnell),显存消耗较大。在 Mac M1 32G 上生成一张 1024×1024 的图片，大约耗时 7~8 分钟，内存加显存占用约 28G。

改用 GGUF 量化模型可以大幅降低显存消耗。使用 `flux-schnell-gguf-Q4` 量化模型后，生成一张 1024×1024 的图片，耗时减少到 3 分钟左右，内存加显存占用降到 8G 上下。

要使用 GGUF 量化模型，需要先安装 GGUF 插件:

- [ComfyUI-GGUF](https://github.com/city96/ComfyUI-GGUF)

### 安装步骤

下载 ComfyUI-GGUF 到 `~/Documents/ComfyUI/custom_nodes` 目录:

```bash
cd ~/Documents/ComfyUI/custom_nodes
git clone https://github.com/city96/ComfyUI-GGUF
```

安装依赖（具体的 Python 解释器路径可以在 ComfyUI 日志中查看）:

```bash
./.venv/bin/python -m pip install -r custom_nodes/ComfyUI-GGUF/requirements.txt
```

> Windows 便携版用户可在 `ComfyUI_windows_portable` 目录下使用内嵌解释器:
>
> ```powershell
> .\python_embeded\python.exe -s -m pip install -r .\ComfyUI\custom_nodes\ComfyUI-GGUF\requirements.txt
> ```

随后:

- 在 Manager 中点击 Update All Custom Nodes 更新插件。
- 重启 ComfyUI。

### 下载依赖模型

按以下目录结构放置模型文件:

- [FLUX.1-schnell-gguf](https://huggingface.co/city96/FLUX.1-schnell-gguf)(选择 Q4_K_S / Q4_1 等量化版本)放入 `ComfyUI/models/unet/` 目录。
- [FLUX.1-schnell VAE(ae.safetensors)](https://huggingface.co/black-forest-labs/FLUX.1-schnell/blob/main/ae.safetensors)放入 `ComfyUI/models/vae/` 目录。
- [clip-vit-large-patch14(pytorch_model.bin)](https://huggingface.co/openai/clip-vit-large-patch14/blob/main/pytorch_model.bin)放入 `ComfyUI/models/clip/` 目录。
- [t5-v1_1-xxl-encoder-bf16(model.safetensors)](https://huggingface.co/city96/t5-v1_1-xxl-encoder-bf16/blob/main/model.safetensors)放入 `ComfyUI/models/clip/` 目录。

> 备注:新版 ComfyUI 推荐将 `clip_l.safetensors` 和 `t5xxl` 系列文件统一放在 `models/text_encoders/` 目录;旧版则放在 `models/clip/`,两种目录都被支持。

### 加载 workflow

可以直接使用作者整理好的示例工作流:[flux_schnell_gguf.json](https://github.com/vxiaozhi/ComfyUI-GGUF/blob/main/flux_schnell_gguf.json)。

## 其它模型

**SDXL-Lightning**

在 [SDXL-Lightning Hugging Face](https://huggingface.co/ByteDance/SDXL-Lightning) 上不仅有模型下载,还贴心地提供了现成的 Workflow JSON 文件,直接拖到 ComfyUI 中即可使用。

## API 访问

由于 ComfyUI 没有官方的 API 文档,基于 ComfyUI 开发 Web 应用,会比 A1111 WebUI 那种在 FastAPI 加持下带有完整交互式 API 文档的项目更困难一些;而且 ComfyUI 不像 A1111 SDWebUI 那样对各类 pipeline 都做了较好的封装、基本可以直接调用。

ComfyUI 的 API 需要同时使用 HTTP 和 WebSocket 两种协议:

- WebSocket 接口用于接收任务状态与进度信息(实时推送)。
- HTTP 接口用于提交任务、查询任务结果、下载生成的图片。

此外,在使用 API 之前,需要在设置(齿轮图标)中开启「Dev Mode」,菜单中才会出现「Save(API Format)」选项,从而导出可被脚本调用的工作流 JSON。

可以参考这篇分析文章:[ComfyUI 开发指南](https://zhuanlan.zhihu.com/p/687537814)。

官方代码仓库也提供了几个示例脚本供参考:

- [basic_api_example.py](https://github.com/comfyanonymous/ComfyUI/blob/master/script_examples/basic_api_example.py):演示如何通过 HTTP 接口提交工作流并获取结果。
- [websockets_api_example.py](https://github.com/comfyanonymous/ComfyUI/blob/master/script_examples/websockets_api_example.py):在 HTTP 基础上加入 WebSocket,实时查询任务状态并下载结果。
- [websockets_api_example_ws_images.py](https://github.com/comfyanonymous/ComfyUI/blob/master/script_examples/websockets_api_example_ws_images.py):功能与前一个类似,但结果图像直接通过 WebSocket 以二进制流的形式返回,无需再单独 HTTP 下载。

## 参考链接

- [ComfyUI 官方仓库](https://github.com/comfyanonymous/ComfyUI)
- [ComfyUI 官方示例工作流](https://github.com/comfyanonymous/ComfyUI_examples)
- [ComfyUI-Manager](https://github.com/ltdrdata/ComfyUI-Manager)
- [ComfyUI-GGUF](https://github.com/city96/ComfyUI-GGUF)
- [FLUX.1-schnell GGUF 模型](https://huggingface.co/city96/FLUX.1-schnell-gguf)
