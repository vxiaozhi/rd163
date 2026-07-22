+++
title = "vLLM"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "面向高吞吐场景的 LLM 推理与服务引擎"
description = "vLLM 是 UC Berkeley 开源的高吞吐、低显存占用的大语言模型推理与服务引擎，本文介绍其核心原理 PagedAttention、安装使用与分布式推理。"
author = "小智晖"
authors = ["小智晖"]
categories = ["llm"]
tags = ["LLM", "vLLM", "推理加速", "PagedAttention", "模型部署"]
keywords = ["vLLM", "PagedAttention", "LLM 推理", "KV Cache", "tensor parallel"]
toc = true
draft = false
+++

vLLM 是一个高吞吐、低显存占用的库，用于大语言模型（LLM）的推理（inference）与服务（serving），由加州大学伯克利分校 Sky Computing Lab 开源，与 HuggingFace 生态无缝集成。它最初作为 [SOSP 2023 论文](https://arxiv.org/abs/2309.06180) *Efficient Memory Management for Large Language Model Serving with PagedAttention* 的配套工程实现发布，目前是社区中最主流的 GPU 推理框架之一。

与 llama.cpp、chatglm.cpp 这类纯推理加速项目不同，vLLM 的定位是**服务端部署**：它专注于 GPU 上的高并发吞吐，并不提供 CPU 推理的极致压缩。如果你的场景是把大模型当作 API 服务对外提供、需要扛住多用户并发请求，vLLM 通常是首选；如果是在笔记本、嵌入式或纯 CPU 环境下运行量化模型，仍然是 llama.cpp 更合适。

## 核心技术

vLLM 的高吞吐主要来自以下几项设计。

### PagedAttention

传统推理框架在管理 KV Cache（Key-Value Cache，注意力的键值缓存）时，会为每条请求预分配一段**连续**显存。由于生成长度不可预知，这种连续分配会带来严重的内部碎片和外部碎片——论文实测显存浪费比例可达 60%–80%。

PagedAttention 借鉴操作系统**虚拟内存与分页（paging）**的思路，把 KV Cache 切成固定大小的 block（页），逻辑上连续的序列在物理显存上可以不连续。这样显存浪费率降到 4% 以下，单卡能同时承载的并发请求数大幅提升。它还支持 copy-on-write，便于实现 beam search、parallel sampling 等多路生成时的 KV 复用。

### Continuous Batching

传统静态批处理（static batching）需要等一个 batch 内所有序列都生成完毕才放入新请求，长尾请求会拖慢整批。Continuous batching（又称 iteration-level batching / 动态批处理）在**每一个解码步**都重新组批：完成的请求立即返回，新请求随时插入，从而显著提高 GPU 利用率。这一思路源自 OSDI 2022 的 Orca 系统。

### 其他工程优化

- **Prefix caching**：对相同系统提示词（system prompt）或上下文前缀的请求缓存其 KV，避免重复计算。
- **CUDA Graph**：通过捕获并重放 GPU 计算图减少 kernel launch 开销。
- **量化与高效 kernel**：支持 FP8、INT8/INT4、GPTQ、AWQ、GGUF 等多种量化方案，并集成 FlashAttention、FlashInfer 等注意力 kernel。
- **投机解码（speculative decoding）**：通过 draft model 或 n-gram 等方式并行验证多个 token，进一步提升解码吞吐。

## 性能

在官方的发布基准（vLLM blog）中，相比 HuggingFace Transformers（HF），vLLM 在并发服务场景下吞吐可高出 **14–24 倍**；相比 HuggingFace 的 Text Generation Inference（TGI），吞吐高出 **2.2–3.5 倍**。具体倍数与模型规模、请求长度分布、采样策略（如 parallel sampling）密切相关——多路采样场景下，得益于 PagedAttention 的 KV 复用，提升最为显著。

需要注意，这类基准都有具体的硬件与负载前提，实际收益仍需在自己的场景下实测。

## 安装

vLLM 仅支持 Linux，Python 3.9–3.12，对 NVIDIA GPU 的支持最为完善（AMD、Intel GPU 以及 TPU 等也有相应后端）。最简单的安装方式：

```bash
pip install vllm
```

如果需要自动匹配 CUDA 版本，官方推荐使用 `uv`：

```bash
uv pip install vllm --torch-backend=auto
```

## 离线批量推理

vLLM 提供 `LLM` 类用于离线推理，无需启动服务即可直接生成：

```python
from vllm import LLM, SamplingParams

# 加载模型
llm = LLM(model="facebook/opt-125m")

# 配置采样参数
sampling_params = SamplingParams(temperature=0.8, top_p=0.95, max_tokens=100)

prompts = [
    "San Francisco is a",
    "The capital of China is",
]

outputs = llm.generate(prompts, sampling_params)
for output in outputs:
    prompt = output.prompt
    generated = output.outputs[0].text
    print(f"Prompt: {prompt!r}, Generated: {generated!r}")
```

`llm.generate` 会把所有 prompt 放入引擎队列一次性高效批处理，返回 `RequestOutput` 列表。默认从 HuggingFace 下载模型；如需改用 ModelScope，可在初始化前设置环境变量 `export VLLM_USE_MODELSCOPE=True`。

## OpenAI 兼容服务

vLLM 可以直接作为实现了 OpenAI API 协议的服务端启动，便于作为 OpenAI 的 drop-in 替换：

```bash
vllm serve Qwen/Qwen2.5-1.5B-Instruct \
    --host 0.0.0.0 \
    --port 8000 \
    --api-key EMPTY
```

启动后即可用标准的 OpenAI 接口调用：

```bash
curl http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer EMPTY" \
    -d '{
        "model": "Qwen/Qwen2.5-1.5B-Instruct",
        "messages": [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "用一句话介绍 vLLM"}
        ]
    }'
```

这意味着所有已经接入 OpenAI SDK 的应用，只需要把 `base_url` 指向 vLLM 服务地址即可零成本迁移。

## 分布式推理

当单卡放不下模型时，vLLM 支持张量并行（tensor parallelism）与流水并行（pipeline parallelism），分布式运行时由 Ray 或 Python 原生 multiprocessing 管理：单机多卡默认走 multiprocessing，多机部署则需要 Ray。

单机多卡推理（以 4 卡为例）：

```python
from vllm import LLM

llm = LLM("facebook/opt-13b", tensor_parallel_size=4)
print(llm.generate("San Francisco is a"))
```

启动服务时则通过命令行参数指定：

```bash
# 单机 4 卡张量并行
vllm serve facebook/opt-13b --tensor-parallel-size 4

# 多机：每节点 4 卡张量并行，2 节点流水并行
vllm serve /path/to/model \
    --tensor-parallel-size 4 \
    --pipeline-parallel-size 2
```

选择策略的经验法则：模型放得下单卡就不用并行；放不下但能放进单机多卡就只用张量并行；单机放不下时再加流水并行。多机部署推荐使用官方提供的 `run_cluster.sh` 脚本拉起 Ray 集群，并配合 Infiniband 等高速互联网络以减少跨节点通信开销。

## 何时选择 vLLM

- 对外提供 LLM API 服务，需要扛高并发
- 有 NVIDIA / AMD GPU，追求最大吞吐
- 模型走 HuggingFace 生态，需要快速接入 OpenAI 兼容接口
- 需要张量并行 / 流水并行部署大模型

反过来，如果是纯 CPU 环境、显存极度受限、或者追求单用户低延迟而非并发吞吐，llama.cpp 这类项目通常更合适。两者并非互斥，实践中常常组合使用：vLLM 跑生产服务，llama.cpp 做本地实验。

## 参考

- [vLLM GitHub 仓库](https://github.com/vllm-project/vllm)
- [vLLM 官方文档](https://docs.vllm.ai/)
- [PagedAttention 论文 (arXiv:2309.06180)](https://arxiv.org/abs/2309.06180)
- [分布式推理文档](https://docs.vllm.ai/en/latest/serving/distributed_serving.html)
- [使用 vLLM 加速大语言模型推理](https://cloud.tencent.com/developer/article/2328353)
