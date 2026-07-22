+++
title = "DeepSeek 前端方案"
date = "2025-02-08"
lastmod = "2025-02-08"
subtitle = "DeepSeek 官方 API 兼容生态下的几款前端客户端选型与部署"
description = "汇总 Chatbox、Open WebUI、Lobe Chat 等几款主流前端项目接入 DeepSeek 的方式与部署示例,方便按需选型。"
author = "小智晖"
authors = ["小智晖"]
categories = ["deepseek"]
tags = ["deepseek", "前端", "open-webui", "lobe-chat", "chatbox", "自托管"]
keywords = ["deepseek", "deepseek 前端", "open-webui", "lobe chat", "chatbox", "自托管 llm"]
toc = true
draft = false
+++

DeepSeek 的 API（API base URL 为 `https://api.deepseek.com`）兼容 OpenAI 接口规范，模型 `deepseek-chat`、`deepseek-coder` 均支持 Function Calling、JSON Output 与 FIM（Fill in the Middle）补全，这意味着凡能接入 OpenAI 的前端项目，理论上都能"换 Base URL + 换 API Key"直接接入 DeepSeek。官方维护的 [awesome-deepseek-integration](https://github.com/deepseek-ai/awesome-deepseek-integration) 仓库按 Applications、Agent Frameworks、RAG Frameworks、IM Bots、IDE Extensions 等维度汇总了数百个可接入项目，是选型的第一入口。

在试用了其中多款前端之后，按"开箱即用的桌面客户端 → 功能完备的自托管 Web UI → 现代化的 AI Chat 框架 → 极简纯静态页面"四档整理如下。

## Chatbox：最简洁的桌面/移动客户端

仓库地址：[chatboxai/chatbox](https://github.com/chatboxai/chatbox)，官网 <https://chatboxai.app>，采用 GPL-3.0 协议（Community Edition）。

Chatbox 把自己定位为"desktop client for ChatGPT, Claude and other LLMs"，主要卖点：

- **全平台覆盖**：Windows 10+、macOS 11+（Intel/Apple Silicon）、Ubuntu 20.04+ 桌面端，以及 iOS、Android 原生 App 与 Web 版本，多端会话可同步。
- **多 Provider 接入**：OpenAI、Azure OpenAI、Claude、Gemini、Ollama 本地模型，以及任意 OpenAI 兼容 API（DeepSeek 只需填入自定义 Base URL 与 Key）。
- **本地优先**：对话数据默认落盘在本机，适合对隐私敏感的场景。
- **写作体验**：流式输出、Markdown/LaTeX 渲染、代码高亮、Prompt 库、消息引用、快捷键、暗色模式、多语言界面（含中文）。

适合个人开发者作为日常"开盖即用"的桌面客户端，不需要部署、不依赖 Docker。

## Open WebUI：功能最全的自托管平台

仓库地址：[open-webui/open-webui](https://github.com/open-webui/open-webui)，文档 <https://docs.openwebui.com>。

Open WebUI 早期叫 Ollama WebUI，现在已经演化为"extensible, feature-rich, and user-friendly self-hosted AI platform"，可同时连接 Ollama 本地模型与任意 OpenAI 兼容 API（含 LMStudio、GroqCloud、Mistral、OpenRouter、vLLM 以及 DeepSeek）。把它接到 DeepSeek 的典型 Docker 命令：

```bash
docker run -d -p 3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  --name open-webui --restart always \
  ghcr.io/open-webui/open-webui:main
```

启动后访问 `http://localhost:3000`，在管理后台的 Settings → Connections 中新增一个 OpenAI 兼容连接，Base URL 填 `https://api.deepseek.com/v1`，填入 API Key 即可。

相比其他前端，Open WebUI 的突出能力包括：

- **联网搜索（Web Search）**：内置 SearXNG、Brave Search、DuckDuckGo、Kagi、Perplexity、Bing 等数十种后端，结果直接注入对话上下文。
- **TTS / STT**：TTS 引擎支持 Azure、ElevenLabs、OpenAI、Transformers、浏览器 WebAPI；STT 支持 Local Whisper、OpenAI、Deepgram、Azure，可做语音通话。
- **RAG**：背后接入 9 种向量库与多种内容抽取引擎（Tika、Docling、Mistral OCR 等），支持 BM25 + 向量的混合检索与重排序。
- **扩展机制**：通过 Filters、Actions、Pipes、Tools、Skills 五类插件以及 MCP / MCPO / OpenAPI Tool Server 接入外部服务。
- **企业特性**：多用户 RBAC、LDAP/SSO、OpenTelemetry 可观测性、基于 Redis 的水平扩展。

适合需要多人共用、需要把 RAG 与联网搜索打包到一个内部平台的小团队。

## Lobe Chat：现代化的 AI Chat 框架

仓库地址：[lobehub/lobe-chat](https://github.com/lobehub/lobe-chat)。

Lobe Chat 走的是"开源、现代化设计"的 AI Chat 框架路线，UI/UX 做得很精致，功能上对标 ChatGPT + GPTs 生态：

- **TTS & STT 语音会话**：内置 `@lobehub/tts` 提供高质量的语音合成与识别。
- **文生图（Text to Image）**：可直接在对话中调用图像生成模型。
- **插件系统（Tools Calling / Function Calling）**：插件机制依赖模型的 Function Calling 能力，DeepSeek `deepseek-chat` / `deepseek-coder` 已支持该能力，官方支持最多 128 个函数并发调用。原理可参考 DeepSeek 官方公告 [DeepSeek API 升级，支持续写、FIM、Function Calling、JSON Output](https://api-docs.deepseek.com/zh-cn/news/news0725)。
- **助手市场（GPTs）**：可在 [lobehub/lobe-chat-agents](https://github.com/lobehub/lobe-chat-agents) 浏览和提交预设助手。
- **MCP 兼容插件**：兼容 MCP（Model Context Protocol），插件生态超过一万种。

官方推荐的部署方式已迁移到 Docker Compose（自动初始化数据库与存储目录）：

```bash
mkdir lobehub-db && cd lobehub-db
bash <(curl -fsSL https://lobe.li/setup.sh)
docker compose up -d
```

如果只想快速跑一个最小化实例，仍然可以用单条 `docker run`：

```bash
docker run -d -p 3210:3210 \
  -e OPENAI_API_KEY=sk-xxxx \
  -e OPENAI_PROXY_URL=https://api.deepseek.com/v1 \
  -e ACCESS_CODE=lobe66 \
  --name lobe-chat \
  lobehub/lobe-chat
```

这里的关键点是把 `OPENAI_PROXY_URL` 指向 DeepSeek 的兼容端点 `https://api.deepseek.com/v1`，`OPENAI_API_KEY` 填 DeepSeek 的 Key，`ACCESS_CODE` 是访问口令，避免裸暴露在公网。部署后访问 `http://localhost:3210`。

## 纯静态 HTML 页面

如果只是想最快地验证本地 Ollama 或一个 OpenAI 兼容接口能不能跑通，不需要后端、不需要 Docker，可以考虑：

- [Tifa-Deepsex-OllamaWebUI](https://github.com/Value99/Tifa-Deepsex-OllamaWebUI)：单页 HTML 静态前端，适合直接丢到任意静态托管。
- [ollama-simple-webui](https://github.com/Joburgess/ollama-simple-webui)：一个与 Ollama 交互的极简网页应用，用于本地快速联调。

这类项目适合做 Demo、做内网小工具或作为二次开发的起点，但通常缺少多用户、鉴权与持久化，不建议直接用于对外服务。

## 选型小结

| 需求场景 | 推荐 |
| --- | --- |
| 个人桌面日常使用，要简单 | Chatbox |
| 团队自托管、需要 RAG + 联网搜索 + 多用户 | Open WebUI |
| 看重 UI 体验、插件生态、助手市场 | Lobe Chat |
| 只是想联调一个 OpenAI 兼容接口 | 纯静态 HTML 页面 |

一个共性提醒：DeepSeek 的接口与 OpenAI 完全兼容，上述任意一个项目，只要把 Base URL 改成 `https://api.deepseek.com/v1`、API Key 换成 DeepSeek 的 Key，即可用 `deepseek-chat` / `deepseek-coder` 替换原本的 GPT 系列，几乎零额外改造成本。

## 参考

- [awesome-deepseek-integration](https://github.com/deepseek-ai/awesome-deepseek-integration) — DeepSeek 官方维护的生态整合清单
- [chatboxai/chatbox](https://github.com/chatboxai/chatbox) — 跨平台桌面/移动客户端
- [open-webui/open-webui](https://github.com/open-webui/open-webui) — 自托管 AI 平台
- [lobehub/lobe-chat](https://github.com/lobehub/lobe-chat) — 现代化 AI Chat 框架
- [DeepSeek API 升级公告（Function Calling / FIM / JSON Output）](https://api-docs.deepseek.com/zh-cn/news/news0725)
