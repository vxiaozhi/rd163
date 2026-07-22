+++
title = "阿里千问系列模型"
date = "2025-03-08"
lastmod = "2025-03-08"
subtitle = "Qwen 系列模型与 QwQ-32B 推理模型速览"
description = "介绍阿里通义千问(Qwen)系列模型的官方资源、博客入口,以及如何通过 DashScope 兼容 OpenAI 接口调用 QwQ-32B 推理模型。"
author = "小智晖"
authors = ["小智晖"]
categories = ["AI", "qwenlm"]
tags = ["qwenlm", "千问", "Qwen", "QwQ-32B", "DashScope", "大语言模型"]
keywords = ["千问", "Qwen", "QwQ-32B", "DashScope", "阿里云", "推理模型"]
toc = true
draft = false
+++

## 简介

阿里通义千问（Qwen）系列模型由 QwenLM 团队维护，相关代码与文档均托管在 GitHub。

**GitHub 组织与仓库:**

- [QwenLM](https://github.com/QwenLM):Qwen 团队的官方 GitHub 组织,涵盖 Qwen、Qwen-VL、Qwen-Coder、Qwen-Agent 等多个仓库(后续随版本迭代持续新增 Qwen2/Qwen3 等系列)。

**官方博客:**

- [qwenlm.github.io](https://github.com/QwenLM/qwenlm.github.io):Qwen 团队早期的博客源码仓库（基于 Hugo 构建）。需要注意的是，该仓库已停止更新，最新的研究动态请前往 [qwen.ai/research](https://qwen.ai/research) 查看。

例如其中一篇代表性文章:

- [QwQ-32B:领略强化学习之力](https://qwenlm.github.io/zh/blog/qwq-32b/)

## API 调用示例

下面是一段简短的示例代码，展示如何通过 DashScope(兼容 OpenAI 接口)调用 QwQ-32B 推理模型:

```python
from openai import OpenAI
import os

# Initialize OpenAI client
client = OpenAI(
    # If the environment variable is not configured, replace with your API Key: api_key="sk-xxx"
    # How to get an API Key: https://help.aliyun.com/zh/model-studio/developer-reference/get-api-key
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url="https://dashscope.aliyuncs.com/compatible-mode/v1"
)

reasoning_content = ""
content = ""

is_answering = False

completion = client.chat.completions.create(
    model="qwq-32b",
    messages=[
        {"role": "user", "content": "Which is larger, 9.9 or 9.11?"}
    ],
    stream=True,
    # Uncomment the following line to return token usage in the last chunk
    # stream_options={
    #     "include_usage": True
    # }
)

print("\n" + "=" * 20 + "reasoning content" + "=" * 20 + "\n")

for chunk in completion:
    # If chunk.choices is empty, print usage
    if not chunk.choices:
        print("\nUsage:")
        print(chunk.usage)
    else:
        delta = chunk.choices[0].delta
        # Print reasoning content
        if hasattr(delta, 'reasoning_content') and delta.reasoning_content is not None:
            print(delta.reasoning_content, end='', flush=True)
            reasoning_content += delta.reasoning_content
        else:
            if delta.content != "" and is_answering is False:
                print("\n" + "=" * 20 + "content" + "=" * 20 + "\n")
                is_answering = True
            # Print content
            print(delta.content, end='', flush=True)
            content += delta.content
```

上述代码的关键点说明:

- **API Key**:`DASHSCOPE_API_KEY` 是阿里云百炼（DashScope）平台的密钥环境变量，可在阿里云控制台获取。
- **base_url**:`https://dashscope.aliyuncs.com/compatible-mode/v1` 是 DashScope 的 OpenAI 兼容模式接入地址。
- **model**:QwQ-32B 推理模型在接口中的参数值为 `qwq-32b`(小写)。
- **reasoning_content**:作为推理模型，QwQ-32B 会先输出思维链（reasoning content）,再给出最终回答，代码中分别对两者进行了打印与累加。

## 参考资料

- [QwenLM GitHub 组织](https://github.com/QwenLM)
- [QwQ-32B 官方博客：领略强化学习之力](https://qwenlm.github.io/zh/blog/qwq-32b/)
- [阿里云百炼：获取 API Key](https://help.aliyun.com/zh/model-studio/developer-reference/get-api-key)
- [Qwen 官方研究动态](https://qwen.ai/research)
