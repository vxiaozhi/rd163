+++
title = "DeepSeek 部署方案"
date = "2025-02-07"
lastmod = "2026-07-23"
subtitle = "从本地到云端，汇总 DeepSeek-R1 的几种落地实践"
description = "汇总 DeepSeek-R1 的本地部署（Ollama、llama.cpp、SGLang、vLLM、Xinference）与主流云服务平台接入方案，附启动命令与调用示例。"
author = "小智晖"
authors = ["小智晖"]
categories = ["AI", "DeepSeek"]
tags = ["deepseek", "大模型", "部署", "ollama", "sglang", "vllm"]
keywords = ["deepseek", "deepseek-r1", "本地部署", "ollama", "vllm", "云服务"]
toc = true
draft = false
+++

DeepSeek 是近期非常火爆的开源大模型，国产大模型 DeepSeek 凭借其优异的性能和对硬件资源的友好性，受到了众多开发者的关注。

无奈在使用时，DeepSeek 官方总是提示「服务器繁忙，请稍后再试」，这可怎么办？

万幸的是，DeepSeek 是一个开源模型，这意味着我们可以将它部署在自己的电脑上随时使用，同时各个云厂商也提供了自己的托管方案。今天就跟大家分享一下 DeepSeek 部署的几种方案。

## 本地部署方案

### Ollama

首先需要安装 Ollama。Ollama 是一个用于本地管理和运行大模型的工具，能够简化模型的下载与调度操作。

进入 Ollama 官网（<https://ollama.com>），点击【Download】，选择适合自己系统的版本（Windows / macOS / Linux）。

以 `deepseek-r1` 为例，官方提供了如下几个版本：

```text
1.5b
7b
8b
14b
32b
70b
671b
```

> 说明:1.5b / 7b / 14b / 32b 基于 Qwen2.5 系列,8b 基于 Qwen3,70b 基于 Llama3.3,671b 为 DeepSeek-R1 原版(未蒸馏)。默认 `ollama run deepseek-r1`(`latest` 标签)拉取的是 **8b** 版本(DeepSeek-R1-0528-Qwen3-8B)。

启动 DeepSeek 模型：

```bash
ollama run deepseek-r1:14b
```

在 Apple M1 Pro / 32 GB 机器上运行 14b 模型毫无压力，可以达到大约 10 token/s 的速度。

如果需要对 API 进行加密，可参考：

- [How to secure the API with api key](https://github.com/ollama/ollama/issues/849)

### llama.cpp

- [llama.cpp](https://github.com/ggml-org/llama.cpp)：LLM inference in C/C++，项目已迁移至 `ggml-org` 组织下。

### SGLang

- [sglang](https://github.com/sgl-project/sglang)：SGLang is a fast serving framework for large language models and vision language models，由 LMSYS 开源组织维护。

参考启动命令（两节点分布式部署示例）。

ds1（主节点，node-rank 0）：

```bash
docker run -e GLOO_SOCKET_IFNAME=bond0 -e NCCL_SOCKET_IFNAME=bond0 -e NCCL_DEBUG=INFO --gpus all \
    --shm-size 128g \
    --network=host \
    -v /modelshare_readonly/deepseek-ai:/deepseek \
    --name sglang_multinode1 \
    -d \
    --restart always \
    -p 50000:50000 \
    --ipc=host \
    --privileged --device=/dev/infiniband:/dev/infiniband \
    lmsysorg/sglang:v0.4.2.post4-cu125-srt \
    python3 -m sglang.launch_server --model-path /deepseek/DeepSeek-R1 --served-model-name DeepSeek-R1 --enable-metrics --enable-dp-attention --enable-cache-report --tp 16 --dist-init-addr 192.168.253.81:20001 --nnodes 2 --node-rank 0 --trust-remote-code --host 0.0.0.0 --port 50000
```

ds2（从节点，node-rank 1）：

```bash
docker run -e GLOO_SOCKET_IFNAME=bond0 -e NCCL_SOCKET_IFNAME=bond0 -e NCCL_DEBUG=INFO --gpus all \
    --shm-size 128g \
    --network=host \
    -v /modelshare_readonly/deepseek-ai:/deepseek \
    --name sglang_multinode2 \
    -d \
    --restart always \
    -p 50000:50000 \
    --ipc=host \
    --privileged --device=/dev/infiniband:/dev/infiniband \
    lmsysorg/sglang:v0.4.2.post4-cu125-srt \
    python3 -m sglang.launch_server --model-path /deepseek/DeepSeek-R1 --served-model-name DeepSeek-R1 --enable-metrics --enable-dp-attention --enable-cache-report --tp 16 --dist-init-addr 192.168.253.81:20001 --nnodes 2 --node-rank 1 --trust-remote-code --host 0.0.0.0 --port 50000
```

### vLLM

- [vllm](https://github.com/vllm-project/vllm)：A high-throughput and memory-efficient inference and serving engine for LLMs。

### Xinference

- [inference](https://github.com/xorbitsai/inference)：Xinference 是由 Xorbits 开源的模型推理与部署平台，提供 OpenAI 兼容的 API，支持 LLM、Embedding、图像、音频等多类模型。

## 支持 DeepSeek 的云服务平台

### DeepSeek 官方

- [DeepSeek 官方](https://chat.deepseek.com/)

### 字节火山引擎

- [模型体验入口](https://console.volcengine.com/ark/region:ark+cn-beijing/experience/chat)
- [我的应用 - 我的 DeepSeek-R1 - 联网搜索版](https://console.volcengine.com/ark/region:ark+cn-beijing/assistant/detail?id=bot-20250226234543-fdsdl&templateType=InfoSource)

预置推理接入点调用示例：

```bash
curl https://ark.cn-beijing.volces.com/api/v3/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ARK_API_KEY" \
  -d '{
    "model": "deepseek-r1-250120",
    "messages": [
      {"role": "system", "content": "你是人工智能助手."},
      {"role": "user", "content": "常见的十字花科植物有哪些？"}
    ]
  }'
```

同时也支持自定义在线接入点（Endpoint）。

- [创建在线接入点](https://console.volcengine.com/ark/region:ark+cn-beijing/endpoint?config=%7B%7D)

示例代码如下，`ep-20250226225639-lbdsg` 即为 Endpoint ID：

```bash
curl https://ark.cn-beijing.volces.com/api/v3/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ARK_API_KEY" \
  -d '{
    "model": "ep-20250226225639-lbdsg",
    "messages": [
      {"role": "system", "content": "你是人工智能助手."},
      {"role": "user", "content": "常见的十字花科植物有哪些？"}
    ]
  }'
```

其它参考：

- [字节火山引擎](https://console.volcengine.com/ark/region:ark+cn-beijing/model?feature=&vendor=Bytedance&view=LIST_VIEW)
- [火山引擎控制台](https://console.volcengine.com/home)
- [ChatCompletions - 文本生成](https://www.volcengine.com/docs/82379/1298454)

### 阿里云百炼

- [阿里云百炼 模型广场](https://bailian.console.aliyun.com/?spm=5176.29597918.J__Xz0dtrgG-8e2H7vxPlPy.8.67b67ca0NBXQtk#/model-market)
- [DeepSeek-V3 API 示例](https://bailian.console.aliyun.com/?spm=5176.29597918.J__Xz0dtrgG-8e2H7vxPlPy.8.67b67ca0NBXQtk#/model-market/detail/deepseek-v3?tabKey=sdk)

### 腾讯云大模型知识引擎

- [DeepSeek 应用创建](https://cloud.tencent.com/document/product/1759/116006)

### 其它

- [硅基流动](https://siliconflow.cn/zh-cn/models)
- [openrouter](https://openrouter.ai/deepseek/deepseek-r1)
- [huggingface](https://huggingface.co/spaces/llamameta/DeepSeek-R1-Chat-Assistant-Web-Search)
- [replicate](https://replicate.com/deepseek-ai/deepseek-r1)

## 参考链接

- [Ollama - deepseek-r1 模型页](https://ollama.com/library/deepseek-r1)
- [SGLang 官方文档](https://sgl-project.github.io/)
- [vLLM 官方文档](https://docs.vllm.ai/)
- [DeepSeek 官方仓库](https://github.com/deepseek-ai/DeepSeek-R1)