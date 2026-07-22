+++
title = "DeepSeek 联网搜索方案"
date = "2025-02-08"
lastmod = "2025-02-08"
subtitle = "用 Function Calling 把外部搜索引擎接入大模型,补齐实时信息"
description = "梳理 DeepSeek 接入联网搜索的整体思路,盘点 Open WebUI 支持的搜索引擎 API,并解析其内部调用链与一个最小可运行示例。"
author = "小智晖"
authors = ["小智晖"]
categories = ["deepseek"]
tags = ["deepseek", "联网搜索", "Function Calling", "Open WebUI", "RAG"]
keywords = ["deepseek", "联网搜索", "Function Calling", "Open WebUI", "搜索引擎 API", "RAG"]
toc = true
draft = false
+++

DeepSeek 的训练语料存在截止时间，模型本身并不知道"今天发生了什么"。要让它回答股价、新闻、最新文档这类实时问题，必须额外接一条通往互联网的通道。常见的做法不是去训练一个新模型，而是通过 **Function Calling(函数调用)** 让模型在需要时主动触发一次外部搜索，再把结果作为上下文喂回去，这本质上是一种轻量级的 RAG(Retrieval-Augmented Generation，检索增强生成)。

整体思路可参考:[基于 ChatGPT 开发 Agent 实现互联网内容搜索](https://zhuanlan.zhihu.com/p/673524057)。本文按这个思路，结合 DeepSeek 与 Open WebUI 的实现做一次系统梳理。

## 整体方案:Agent + Function Calling

一个最小的联网搜索 Agent 至少包含三个角色:

- **大模型（如 DeepSeek）**:负责理解用户意图，决定"要不要搜""搜什么",并把检索到的片段组织成自然语言回答。
- **搜索工具（Search Tool）**:一个普通的 HTTP 接口，输入 query，返回若干 `{title, url, snippet}` 结果。
- **编排层（Orchestrator）**:循环驱动模型与工具，负责把模型的函数调用请求翻译成真实的 HTTP 请求，再把返回值塞回对话。

DeepSeek 官方 API(`https://api.deepseek.com`)兼容 OpenAI 接口,`deepseek-chat` 等模型支持 `tools` 字段的函数调用。当模型判断需要联网时，会在响应里返回一个 `tool_calls`,编排层据此调用搜索 API，然后把结果以 `role: "tool"` 消息追加进上下文，让模型继续生成最终回答。这样，模型的训练数据限制就被绕过了。

关键点在于：模型并不"知道"如何联网，它只是按 JSON Schema 约定发出一个结构化调用，真正的网络请求由编排层完成。

## 搜索引擎 API 选型

选型决定了成本、稳定性与结果质量。下面以 Open WebUI 为参照——它在配置项 `WEB_SEARCH_ENGINE` 中支持多种后端。我按授权方式分成三类。

### 自建/免费开源

- **`searxng`**:SearXNG 是基于 AGPL 协议开源的元搜索引擎（metasearch engine）,由已停更的 searX 分叉而来。它本身不抓取网页，而是把查询转发给 Google、Bing、DuckDuckGo 等上游引擎再聚合结果，不收集用户数据。服务端软件，既可使用公共实例，也可自建私有实例，是成本最低、隐私可控的选择。Open WebUI 通过环境变量 `SEARXNG_QUERY_URL` 指向你的实例地址。

### 免费（有限额或限速）

- **`duckduckgo`**:DuckDuckGo 的 HTML 端点可以免 API Key 抓取，适合个人原型。缺点是没有官方 SLA，容易遇到限速或验证码，不建议用于生产。

### 商业收费

这一类需要注册账号、获取 API Key，通常按调用次数计费，但结果质量和稳定性都更好:

- `google_pse`:Google Programmable Search Engine，自定义站点范围的 Google 搜索。
- `brave`:Brave Search API，独立索引，隐私友好。
- `kagi`:Kagi 搜索，主打无广告、高质量。
- `mojeek`:独立索引的英国搜索引擎。
- `serpstack` / `serper` / `serply` / `searchapi` / `serpapi`:这一组是 SERP(Search Engine Results Page)代理服务，统一封装 Google/Bing 等结果，差异化主要在价格、并发与覆盖区域。
- `bing`:微软 Bing Search v7 API，需订阅密钥 `BING_SEARCH_V7_SUBSCRIPTION_KEY`。
- `exa`:面向 AI 的神经搜索，擅长语义召回。
- `jina`:Jina AI 提供的搜索 + Reader 链路，可直接返回页面正文。
- `tavily`:为 LLM Agent 量身定制的搜索 API，下文单独示例。

Open WebUI 新版本还陆续加入了 `bocha`、`linkup`、`firecrawl`、`perplexity`、`yacy`、`yandex` 等后端，可在 `backend/open_webui/retrieval/web/` 目录下查看完整模块列表。选型时建议优先考虑：是否需要 API Key、是否返回正文而非仅摘要、是否有并发或 QPS 限制、单价与免费额度。

## 示例:Tavily + DeepSeek 最小调用链

以 Tavily 为例，它的 endpoint 是 `POST https://api.tavily.com/search`,请求体里 `query` 必填，可选 `search_depth`(`basic`/`advanced`)、`max_results`、`include_answer` 等参数。`include_answer=true` 时会额外返回一段 LLM 生成的摘要，可省去一次模型推理。

一个把 Tavily 暴露给 DeepSeek 的工具定义大致如下:

```python
SEARCH_TOOL = {
    "type": "function",
    "function": {
        "name": "web_search",
        "description": "搜索互联网以获取最新信息。当用户问题涉及实时数据或你不确定的事实时调用。",
        "parameters": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "搜索关键词"}
            },
            "required": ["query"],
        },
    },
}
```

编排层的核心循环可以这样写（伪代码，省略错误处理）:

```python
from openai import OpenAI
import requests

client = OpenAI(api_key="YOUR_DEEPSEEK_KEY", base_url="https://api.deepseek.com")

def web_search(query: str) -> str:
    resp = requests.post(
        "https://api.tavily.com/search",
        json={"query": query, "max_results": 5, "include_answer": True},
        headers={"Authorization": "Bearer tvly-YOUR_API_KEY"},
        timeout=20,
    )
    data = resp.json()
    answer = data.get("answer", "")
    snippets = "\n".join(f"- [{r['title']}]({r['url']}): {r['content']}" for r in data["results"])
    return f"{answer}\n\n{snippets}"

messages = [{"role": "user", "content": "今天杭州天气怎么样?"}]

while True:
    resp = client.chat.completions.create(
        model="deepseek-chat",
        messages=messages,
        tools=[SEARCH_TOOL],
    )
    msg = resp.choices[0].message
    messages.append(msg)
    if not msg.tool_calls:
        print(msg.content)
        break
    for call in msg.tool_calls:
        args = __import__("json").loads(call.function.arguments)
        result = web_search(args["query"])
        messages.append({"role": "tool", "tool_call_id": call.id, "content": result})
```

这段代码完整展示了"模型决定搜索 → 编排层执行 → 结果回灌 → 模型总结"的闭环，把它替换成 `searxng` 或 `serper` 的 HTTP 调用，逻辑完全一致。

## Open WebUI 搜索流程代码解析

Open WebUI 把上述闭环封装在了 retrieval 模块里，关键调用链如下:

- `@app.post("/api/chat/completions")` — 对外的聊天入口
- `async def chat_completion()` — 组装请求、鉴权
  - `async def process_chat_payload()` — 处理消息负载，决定是否需要走 RAG
    - `async def chat_web_search_handler()` — 判断当前请求是否启用了联网搜索，选择引擎实现
      - `def process_web_search()` — 真正发起 HTTP 搜索，抓取摘要与正文，写入向量库供后续检索引用

阅读这条链路可以帮助理解:Open WebUI 的联网搜索并不是把原始网页直接塞给模型，而是先抓取、再切片、再做向量召回，最后把命中的片段作为上下文送入对话。也就是说,"搜索"和"召回"在工程上是两段独立的流水线，可以分别替换实现。

## 小结

把 DeepSeek 变成"能联网"的 Agent，核心是三件事：选一个合适的搜索引擎 API、用 Function Calling 把它挂到模型上、写好编排循环处理工具调用。如果是个人尝鲜,`searxng` 或 `duckduckgo` 足够;如果要做生产服务,`tavily`、`brave`、`serper` 这类付费 API 在稳定性与结果质量上更可靠。Open WebUI 已经把这条链路完整实现并抽象成可插拔的后端，是落地时值得直接复用的轮子。

## 参考

- [基于 ChatGPT 开发 Agent 实现互联网内容搜索](https://zhuanlan.zhihu.com/p/673524057)
- [DeepSeek API 文档](https://api-docs.deepseek.com/)
- [Open WebUI 源码:retrieval/web 模块](https://github.com/open-webui/open-webui/tree/main/backend/open_webui/retrieval/web)
- [Tavily API Reference](https://docs.tavily.com/documentation/api-reference/endpoint/search)
- [SearXNG 文档](https://docs.searxng.org/)
