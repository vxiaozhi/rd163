+++
title = "LLM 时代下的 AI 网关"
date = "2025-01-23"
lastmod = "2025-01-23"
subtitle = "为什么 LLM 应用需要专门的 AI 网关"
description = "梳理 LLM 应用在网关层的新需求、AI 网关的核心能力（内容安全、缓存、灰度路由、可观测等），并盘点常见的开源 AI 网关项目。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "gateway", "AI Gateway", "LLM", "Higress"]
keywords = ["AI 网关", "LLM 网关", "AI Gateway", "Higress", "灰度路由", "可观测性"]
toc = true
draft = false
+++

## AI 网关

AI Gateway（又称大模型网关、AI 网关）是位于应用与 AI/LLM 服务之间的一层流量管理组件，在开源社区已有较为成熟的技术实现。它在应用与模型服务之间承担统一入口的职责：无论调用的是预置模型还是自研模型，都可以经由网关完成路由、鉴权与调用，方便业务方在数据分析、应用开发等场景中接入 AI 能力。同时，AI 网关还提供配套工具，帮助监控模型调用性能，并为后续优化提供数据支撑。

除了基本的路由与转发，AI 网关的另一个特点是高度的灵活性和可扩展性。用户可以根据业务规模选择部署形态，并在网关层调整模型调用参数与策略，以满足不同的业务场景需求。

此外，借助权限管理、实时监控、缓存、重试、调用优先级调整等手段，AI 网关还能在保护数据隐私的同时，保障服务在高负载下的稳定、安全运行。

## AI 场景下的新需求

相比传统 Web 应用，LLM 应用在网关层的流量具有以下三大特征：

- **长连接**。AI 场景大量使用 WebSocket 和 SSE（Server-Sent Events）协议，长连接比例很高，因此要求网关在配置变更时对已有长连接无影响，避免中断业务。

- **高延时**。LLM 推理的响应延时远高于普通应用，这使得 AI 应用面对恶意攻击时较为脆弱，容易被构造慢请求进行异步并发攻击。攻击者的成本很低，但服务端的开销很高。

- **大带宽**。结合 LLM 上下文来回传输以及高延时的特性，AI 场景对带宽的消耗远超普通应用。如果网关没有较好的流式处理能力和内存回收机制，内存很容易快速上涨。

## 功能需求

### AI 内容安全

能够对大模型的请求/响应进行实时处理与内容封禁，保障 AI 应用的内容合法合规。

### AI 代理

支持对接不同模型提供商（provider），通过统一协议屏蔽底层差异。

### AI 缓存

LLM 结果缓存插件，默认配置即可直接用于 OpenAI 协议的结果缓存，同时支持流式和非流式响应的缓存。

### AI 提示词

在网关层对请求中的 Prompt 进行统一管理、改写与注入，便于做模板化和审计。

### AI JSON 格式化

约束大模型输出为合法的 JSON 结构，方便下游程序直接解析消费。

### AI Agent

一个可定制化的 API AI Agent，支持 HTTP method 类型为 GET 与 POST 的 API，支持多轮对话，并支持流式与非流式模式。

### AI 历史对话

在网关层管理多轮对话的上下文，避免业务侧自行维护会话状态。

### AI 意图识别

对用户输入进行意图分类，辅助路由到不同的模型或处理流程。

### AI RAG

在网关侧集成检索增强生成（RAG）能力，将检索结果与请求一并送入模型。

### AI 请求响应转换

对请求与响应体进行转换，例如字段映射、协议适配、内容改写等。

### 灰度路由

网关支持模型按比例灰度能力，便于用户在模型之间平滑迁移。如下图所示，请求流量将有 90% 被路由到 OpenAI，10% 被路由到 DeepSeek。

### API Key 二次分租

基于 API 网关的消费者鉴权能力，支持 API Key 的二次分租。使用者在对外提供服务时，可以屏蔽模型提供商的 API Key，而在网关上签发自己的 API Key 供下游使用，从而兼容历史调用方；除了能够控制消费者的调用权限和调用额度，配合可观测能力，还可以对每个消费者的 token 用量进行观测统计。

### 可观测性

在灰度的过程中，需要持续观测不同模型的 token 开销以及响应速度，来整体衡量切换效果。

网关具备开箱即用的 AI 可观测能力，提供全局、provider 维度、模型维度以及消费者维度的 token 消耗/延时等观测能力。

## 开源 AI 网关项目

以下是一些常见的开源项目，其中既有定位为 AI 网关的产品，也有相关的 LLM API 管理 / 应用开发平台：

- [Higress](https://github.com/alibaba/higress)：阿里巴巴开源的云原生 API 网关，基于 Istio + Envoy，是 CNCF 沙箱项目，原生支持 AI 网关能力（统一 LLM provider 接入、Token 限流、AI 可观测、MCP Server 托管等）。
- [Portkey AI Gateway](https://github.com/Portkey-AI/gateway)：轻量级 LLM 路由网关，支持 1600+ 模型，提供重试、降级、负载均衡、缓存与 Guardrails 等能力。
- [Kong](https://github.com/Kong/kong)：老牌云原生 API 网关，目前已演进为 API · LLM · MCP 综合网关，提供 60+ AI 相关特性。
- [One API](https://github.com/songquanpeng/one-api)：OpenAI 兼容的 LLM API 管理与 Key 分发系统，偏重多租户 Key 管理与二次分发。
- [Dify](https://github.com/langgenius/dify)：开源 LLM 应用开发平台，集成 Agent 工作流、RAG、模型管理与可观测，定位偏应用层而非纯粹的网关。

## 参考

- [DeepSeek-R1 来了，如何从 OpenAI 平滑迁移到 DeepSeek](https://mp.weixin.qq.com/s/0NokzM9SGPkAJgl0c9JiEA)
- [Welcome to Higress Plugin Hub](https://higress.cn/plugin/?spm=36971b57.2ef5001f.0.0.2a932c1frcJdvJ)
- [Higress GitHub 仓库](https://github.com/alibaba/higress)
- [Portkey AI Gateway 官网](https://portkey.ai/)
