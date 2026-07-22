+++
title = "LLM 工作流编排方案"
date = "2025-02-14"
lastmod = "2025-02-14"
subtitle = "从商业平台到开源引擎,LLM 应用编排方案选型指南"
description = "对比腾讯元器、字节扣子等商业平台与 Dify、RAGFlow、Haystack、FastGPT、QAnything 等开源方案,梳理 LLM 工作流编排的选型思路与适用场景。"
author = "小智晖"
authors = ["小智晖"]
categories = ["llm"]
tags = ["llm", "llmops", "ai-agent", "rag", "workflow"]
keywords = ["LLM 工作流编排", "Dify", "RAGFlow", "扣子 Coze", "LLMOps", "AI Agent"]
toc = true
draft = false
+++

单纯调用一个大语言模型（Large Language Model,LLM）的 API 只能解决一次性问答。当业务需要把"检索知识库 → 调用 LLM → 执行工具 → 分支判断 → 输出结构化结果"串联成一条流水线时，就需要**工作流编排**(Workflow Orchestration)。围绕 LLM 的编排能力，业界通常也称之为 LLMOps 平台或 AI Agent(智能体)平台。

本文按"商业平台"和"开源方案"两条线梳理主流的 LLM 工作流编排工具，并给出选型思路。

## 为什么需要工作流编排

直接写 Prompt 或调用 SDK 能完成简单任务，但生产环境通常要解决:

- **多步骤组合**:检索增强生成（Retrieval-Augmented Generation,RAG）、工具调用（Function Calling）、循环迭代，需要把多次 LLM 调用与外部动作按顺序拼接。
- **可视化协作**:非工程角色（产品、运营）也需要参与流程设计，拖拽式画布比代码更直观。
- **可观测性**:链路一长，调试和定位"哪一步出错"就需要日志、追踪、回放和评测。
- **模型与供应商解耦**:能在 OpenAI、Anthropic、本地模型（Ollama / vLLM）之间切换而不改业务代码。
- **复用与发布**:把一个工作流封装成 API、Bot 或嵌入式组件，供前端/第三方调用。

工作流编排平台的核心价值，就是把这些能力下沉为基础设施。

## 选型维度

不同团队关注点不同，可重点比较以下几项:

| 维度 | 说明 |
|------|------|
| 部署形态 | SaaS / 私有化 / Docker Compose / Kubernetes |
| 编排方式 | 可视化画布 / 代码框架 |
| 模型支持 | 是否兼容 OpenAI API、是否能接本地模型 |
| RAG 能力 | 文档解析、分块、向量库、重排（rerank） |
| 许可证 | Apache-2.0、MIT 等宽松协议 vs. 附加条款的"开源"协议 |
| 二次开发 | API 完整度、SDK、扩展点 |

下面分别看商业方案与开源方案。

## 商业方案

国内主流的两家商业平台都以"AI Agent 智能办公"为定位，主打低门槛、开箱即用。

### 腾讯元器

[腾讯元器](https://yuanqi.tencent.com/agent-shop)是腾讯推出的智能体开放平台，提供 Agent 商店、低代码搭建、知识库管理与发布到 QQ、微信等渠道的能力。适合个人开发者或希望快速试水、不打算自建基础设施的团队。

### 字节扣子

[扣子 Coze](https://www.coze.cn/home)是字节跳动推出的 AI Agent 智能办公平台，定位"用 AI 重塑生产力与工作效率"。扣子提供可视化**工作流**(Workflow)编辑器，支持 LLM 节点、代码节点、知识库节点、插件节点、条件判断等编排能力，并支持把工作流作为 Bot 技能或独立 API 对外提供。国内版站点 `coze.cn`,海外版为 `coze.com`。

商业平台的优势是上手快、托管省心，代价是数据要出域、流程被平台锁定、定制空间有限。对数据敏感或需要深度定制的场景，通常要转向开源方案。

## 开源方案

开源生态比商业平台丰富得多，大致可以分为两类:**一体化平台**(自带前后端、可视化画布、开箱即用)和**代码框架**(以 SDK 形式被嵌入到自有应用)。

### Dify —— 综合型 LLMOps 平台

[Dify](https://github.com/langgenius/dify) 是目前最热门的开源 LLM 应用开发平台之一，GitHub Star 数在 15 万级别（数据截至本文撰写时）。其定位是"open-source LLM app development platform",核心能力包括:

- **Workflow**:可视化画布，支持节点分支、循环、工具调用、知识检索。
- **RAG Pipeline**:覆盖文档摄入到检索全链路，支持 PDF / PPT 文本抽取，兼容 Qdrant、Weaviate、Milvus、pgvector 等向量库。
- **Agent 能力**:支持 Function Calling 与 ReAct 两种模式，内置 50+ 工具。
- **Prompt IDE**:带版本管理的提示词工程界面。
- **Backend-as-a-Service**:所有能力都对外暴露 REST API。

Dify 提供 Docker Compose / Kubernetes Helm / 云厂商 CDK 等多种部署方式。需要注意，它采用基于 Apache-2.0 的 **Dify Open Source License**,在商标使用与多租户 SaaS 场景上附加了限制，商用前建议通读 LICENSE。

### RAGFlow —— 偏重文档理解的 RAG 引擎

[RAGFlow](https://github.com/infiniflow/ragflow) 由 InfiniFlow 团队维护，Apache-2.0 协议，定位是"deep document understanding RAG engine"。强项在于对复杂格式文档（PDF、表格、扫描件、网页等）的高保真解析与可解释分块（template-based chunking）,并提供可视化引用溯源以降低幻觉。新版加入了 Agent 与 MCP(Model Context Protocol)支持。如果业务的核心痛点是"文档太乱、检索召回质量差",RAGFlow 值得优先评估。

### Haystack —— Python 编排框架

[Haystack](https://github.com/deepset-ai/haystack) 由德国公司 deepset 维护，Apache-2.0 协议，定位是生产级 LLM 编排框架。与 Dify 不同，它是**代码优先**的：用 Python 把组件拼装成 `Pipeline`,支持循环、分支、条件判断与原生异步，可通过 [Hayhooks](https://github.com/deepset-ai/hayhooks) 一键部署为 REST API 或 MCP server。Apple、Meta、NVIDIA、Netflix 等公司都在用。适合工程能力强、希望对每一步检索/路由/生成都有显式控制的团队。

### FastGPT —— 国产知识库 + 工作流平台

[FastGPT](https://github.com/labring/FastGPT) 是国内活跃的 AI Agent 构建平台，提供数据处理、RAG 检索与可视化工作流编排，支持知识库单点搜索测试、引用反馈编辑、全链路日志、应用评测，以及插件热更新和 AI 辅助生成工作流。需要注意的是它采用 **FastGPT Open Source License**:允许作为后台服务直接商用，但**不允许提供 SaaS 服务**,商用部署需保留版权信息或购买商业授权。

### QAnything —— 网易有道问答系统

[QAnything](https://github.com/netease-youdao/QAnything) 由网易有道开源，AGPL-3.0 协议，全名"Question and Answer based on Anything"。它的特色是**本地化部署**(默认可纯 CPU 跑 Docker)与**两阶段检索**(embedding + reranking，底层用自家的 [BCEmbedding](https://github.com/netease-youdao/BCEmbedding)),支持 PDF、Word、PPT、Excel、Markdown、图片、网页等格式，中英双语问答质量较好。适合对数据出域高度敏感、需要完全离线的场景。

### 补充：代码级编排框架

如果不想用一体化平台，也可以直接基于代码框架自建:

- [LangGraph](https://github.com/langchain-ai/langgraph)(MIT):LangChain 团队出品的状态机式编排框架，主打**持久化执行**(durable execution)、人工介入（human-in-the-loop）和长期记忆，适合长周期、有状态的 Agent。
- [LlamaIndex](https://github.com/run-llama/llama_index)(MIT):定位是 LLM 的"数据框架",强项是数据连接器与索引/检索抽象，适合自研 RAG 管道。

这两者都是 MIT 协议、社区庞大，但要求团队自己写前后端和运维体系。

## 如何选择

选型没有银弹，可以按几个典型场景快速归位:

- **想 30 分钟搭一个能用的 Bot，不在意数据托管**:扣子 / 元器。
- **要私有化部署、需要可视化画布、希望团队协作**:Dify(综合)、FastGPT(国产、知识库导向)。
- **文档解析和召回质量是核心痛点**:RAGFlow。
- **必须完全离线 / 数据高敏感**:QAnything。
- **工程团队愿意写代码，追求极致可控**:Haystack、LangGraph、LlamaIndex。

实操上，建议先拿一份自己的真实数据（尤其是最乱的那批 PDF）在 2-3 个候选平台上各跑一遍 RAG，看召回率和引用准确性，再做决定——纸面对比永远不如一次端到端 demo 直观。

## 参考

- 商业平台:[腾讯元器](https://yuanqi.tencent.com/agent-shop)、[扣子 Coze 国内版](https://www.coze.cn/home)、[Coze 海外版](https://www.coze.com)
- 开源一体化:Dify([GitHub](https://github.com/langgenius/dify))、RAGFlow([GitHub](https://github.com/infiniflow/ragflow))、FastGPT([GitHub](https://github.com/labring/FastGPT))、QAnything([GitHub](https://github.com/netease-youdao/QAnything))
- 代码框架:Haystack([GitHub](https://github.com/deepset-ai/haystack))、LangGraph([GitHub](https://github.com/langchain-ai/langgraph))、LlamaIndex([GitHub](https://github.com/run-llama/llama_index))
