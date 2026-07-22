+++
title = "DeepSeek 模型发展时间线"
date = "2025-02-07"
lastmod = "2025-02-07"
subtitle = "从 DeepSeek LLM 到 R1 与 Janus-Pro 的关键节点梳理"
description = "按时间顺序梳理 DeepSeek 自 2023 年成立以来的主要模型发布与技术演进，涵盖 V2、V3、R1、Janus-Pro 等关键里程碑。"
author = "小智晖"
authors = ["小智晖"]
categories = ["deepseek"]
tags = ["deepseek", "llm", "大模型", "MoE", "强化学习", "开源模型"]
keywords = ["DeepSeek", "DeepSeek-V3", "DeepSeek-R1", "MoE 架构", "开源大模型", "模型时间线"]
toc = true
draft = false
+++

## 2023 年

2023 年 7 月，DeepSeek（深度求索）在杭州成立，由幻方量化创始人梁文锋创立，专注于通用人工智能（AGI）与大模型研发，并依托幻方积累的算力资源开展训练。

## 2024 年

### DeepSeek LLM 与 DeepSeek Coder（2024 年 1 月）

2024 年 1 月，DeepSeek 开源了首批模型：

- **DeepSeek LLM**：包括 7B 与 67B 的 base 与 chat 版本，从零开始在 2 万亿 token 上训练，在代码、数学与推理任务上超越 LLaMA-2 70B。
- **DeepSeek Coder**：包含 1.3B 至 33B 等多个规模，从零开始在 2 万亿 token（87% 代码 + 13% 自然语言）上训练，支持多种编程语言的代码生成、调试与数据分析任务。

### DeepSeek-V2（2024 年 5 月）

- 总参数达 2360 亿（每 token 激活 21B），采用 Multi-head Latent Attention（MLA）与 DeepSeekMoE 架构，支持 128K 上下文。
- 在实现更强性能的同时，训练成本降低 42.5%，KV 缓存减少 93.3%，最大生成吞吐量提高 5.76 倍，推理成本降至每百万 token 约 1 元人民币。

### DeepSeek-V2.5（2024 年 9 月）

- [DeepSeek-V2.5（Ollama）](https://ollama.com/library/deepseek-v2.5)

V2.5 将 V2-Chat 与 Coder-V2-Instruct 合并升级，保留了原有 Chat 模型的通用对话能力与 Coder 模型的代码处理能力，并更好地对齐了人类偏好，在写作任务、指令跟随等方面实现大幅提升。

### DeepSeek-R1-Lite-Preview（2024 年 11 月）

DeepSeek-R1-Lite-Preview 上线网页端，使用强化学习训练，推理过程包含大量反思与验证，思维链长度可达数万字。

### DeepSeek-V3（2024 年 12 月）

总参数达 6710 亿（每 token 激活 37B），采用 MoE 架构与 FP8 混合精度训练框架，在 14.8 万亿 token 上训练，官方披露的算力成本约为 557.6 万美元（2.788M H800 GPU 小时）。

## 2025 年

### DeepSeek-R1（2025 年 1 月）

- 2025 年 1 月 20 日，DeepSeek 发布 R1，性能对标 OpenAI o1 正式版，在数学、代码与推理任务上表现接近，并通过蒸馏与开源权重推动社区生态发展。
- 2025 年 1 月 27 日，DeepSeek 应用登顶苹果中国区与美国区 App Store 免费 App 下载榜，在美区下载榜上超越了 ChatGPT。
- 2025 年 1 月 31 日，DeepSeek-R1 作为 NVIDIA NIM 微服务预览版提供，可在单个 NVIDIA HGX H200 系统上达到每秒 3872 tokens 的吞吐量。

模型权重：

- [DeepSeek-R1（Hugging Face）](https://huggingface.co/deepseek-ai/DeepSeek-R1)

### Janus-Pro（2025 年 1 月）

DeepSeek Janus-Pro 于 2025 年 1 月 27 日开源，是一款统一多模态理解与生成的自回归模型，旨在通过解耦视觉编码路径来解决传统多模态模型中视觉编码器在理解与生成两种任务上的功能冲突。

技术特点：

- **视觉编码解耦**：采用独立路径分别处理多模态理解与生成任务，避免视觉编码器在两类任务中的功能冲突。
- **统一 Transformer 架构**：使用单一 Transformer 处理多模态任务，简化设计并保持扩展性。
- **优化的训练策略**：包括延长 ImageNet 数据训练、聚焦文生图数据训练并调整数据配比。
- **扩展的训练数据**：扩充数据规模与多样性，涵盖多模态理解与视觉生成。
- **高性能视觉编码器**：基于 SigLIP-L，支持高分辨率输入，可捕捉图像细节。
- **高效生成模块**：使用 LlamaGen Tokenizer（下采样率 16），生成更精细的图像。

Janus-Pro 系列：

- [Janus-Pro-1B](https://huggingface.co/deepseek-ai/Janus-Pro-1B)
- [Janus-Pro-7B](https://huggingface.co/deepseek-ai/Janus-Pro-7B)

### DeepSeek-V3-0324（2025 年 3 月）

DeepSeek-V3-0324 是 2024 年 12 月 26 日发布的初代 V3 的重要更新，于 2025 年 3 月 24 日发布（命名中的 "0324" 即为发布日期）。

主要亮点：

- 拥有 685B 参数（671B 主模型权重 + 14B Multi-Token Prediction 权重），采用 Mixture-of-Experts（MoE）架构。
- 已在 Hugging Face 上开源，模型权重全面开放。
- 在通用能力之外，进一步发力编码与推理领域。

模型权重：

- [DeepSeek-V3-0324（Hugging Face）](https://huggingface.co/deepseek-ai/DeepSeek-V3-0324)

### DeepSeek-R1-0528（2025 年 5 月）

DeepSeek-R1-0528 于 2025 年 5 月 28 日发布，仍以 2024 年 12 月发布的 DeepSeek V3 Base 作为基座，但在后训练阶段投入了更多算力，显著提升了模型的思维深度与推理能力。

更新后的 R1 在数学、编程与通用逻辑等多个基准测评中取得国内所有模型中首屈一指的成绩，整体表现接近 OpenAI o3 与 Google Gemini 2.5 Pro 等国际顶尖模型。

## 参考链接

- [DeepSeek 官方 API 文档与更新日志](https://api-docs.deepseek.com/updates/)
- [DeepSeek-V3 技术报告（arXiv:2412.19437）](https://arxiv.org/abs/2412.19437)
- [DeepSeek-V2 论文（arXiv:2405.04434）](https://arxiv.org/abs/2405.04434)
- [DeepSeek-R1 论文（arXiv:2501.12948）](https://arxiv.org/abs/2501.12948)
- [DeepSeek-R1 Now Live With NVIDIA NIM（NVIDIA 博客）](https://blogs.nvidia.com/blog/deepseek-r1-nim-microservice/)
- [Janus-Pro（GitHub）](https://github.com/deepseek-ai/Janus)
