+++
title = "实时语音转文字"
date = "2025-08-23"
lastmod = "2025-08-23"
subtitle = "从 WebRTC 采集到 ASR 识别的开源方案与工程要点"
description = "梳理实时语音转文字（Real-time ASR）的技术链路，对比 fastrtc、LiveKit 等 RTC 框架与 FunASR 语音识别工具包，并拆解 IntraScribe 这类开源转录协作平台的实现原理与鉴权要点。"
author = "小智晖"
authors = ["小智晖"]
categories = ["rtc"]
tags = ["rtc", "ASR", "WebRTC", "fastrtc", "FunASR", "LiveKit"]
keywords = ["实时语音转文字", "FunASR", "fastrtc", "WebRTC", "Paraformer", "IntraScribe"]
toc = true
draft = false
+++

实时语音转文字（Real-time Automatic Speech Recognition，简称实时 ASR）是会议纪要、字幕生成、语音助手等场景的基础能力。与「先录音再转写」的离线模式不同，实时方案需要在用户说话的同时，把浏览器或终端采集到的音频流低延迟地送到识别引擎，并把识别结果以流式方式回传给前端。本文先梳理一条端到端链路涉及的核心组件，再介绍开源项目 IntraScribe 的实现思路，以及 fastrtc、FunASR 等关键框架的定位与用法。

## 实时语音转文字的技术链路

一条典型的实时转录链路可以拆成三段：

1. **音频采集与传输（RTC 层）**：浏览器通过 `getUserMedia` 拿到麦克风音频，再经由 WebRTC 或 WebSocket 把音频帧以低延迟送到服务端。WebRTC 适合端到端、抗弱网的实时音视频通信，WebSocket 则更适合自定义协议、内网部署或单向流式上传。
2. **语音活动检测与流式识别（ASR 层）**：服务端先用 VAD（Voice Activity Detection，语音端点检测）切出有效语音段，再把音频块喂给流式 ASR 模型，输出增量文本。
3. **后处理与落库（业务层）**：识别结果通常要做标点恢复（Punctuation Restoration）、时间戳对齐，必要时再做说话人分离（Speaker Diarization）和摘要生成，最后通过 SSE（Server-Sent Events）或 WebSocket 推送到前端协作编辑。

链路里的每一个环节都有成熟的开源组件可选，关键在于把它们拼成一个稳定、低延迟、可水平扩展的服务。

## 开源项目：IntraScribe

[IntraScribe](https://github.com/weynechen/intrascribe) 是一个本地优先（local-first）的语音转写与协作平台，面向企业内网、教育和政务等对数据合规要求较高的场景，提供完整的前后端代码，采用 MIT 协议。它的特点是数据可以完全留在内网，并支持实时转写、说话人分离、AI 摘要和多人协作编辑。

### 架构概览

IntraScribe 采用微服务架构，核心服务包括：

- **API Service（端口 8000）**：主业务逻辑、会话管理、AI 摘要集成（通过 LiteLLM）
- **STT Service（端口 8001）**：基于 FunASR 的语音转写服务，可选 GPU 加速
- **Diarization Service（端口 8002）**：基于 pyannote.audio 的说话人分离服务
- **Agent Service**：轻量级实时音频代理，连接 RTC 层与后端
- **nginx**：反向代理统一对外

服务间通过 Redis 进行消息传递和实时数据缓存，业务数据落 Supabase 提供的 PostgreSQL。前端基于 Next.js App Router + React + TypeScript + Tailwind CSS。

需要特别说明的是：IntraScribe 的 **RTC 层实际使用的是 LiveKit**（WebRTC 平台），而不是 fastrtc。浏览器通过 LiveKit 采集并传输音频，Agent Service 桥接 LiveKit 与后端 STT 服务，识别结果再通过 SSE 实时返回前端。会后还会用缓存的完整音频做一次带说话人分离的离线转写，以提升质量。

### 关键能力

- **隐私优先**：可在气隙（air-gapped）环境下完整运行
- **实时转写**：WebRTC 低延迟流式识别，附带标点清理与时间戳格式化
- **说话人分离**：前端可双击重命名说话人，改动同步回数据库
- **AI 摘要与标题生成**：基于 LiteLLM，使用模板化的结构化 Markdown 输出并带兜底策略
- **可编辑转写**：保留说话人与时间戳信息的同时允许前端修改片段

## RTC 框架：fastrtc 与 LiveKit

实时音频采集与传输有多种开源方案，下面两个是社区里较常见的选择。

### fastrtc：把 Python 函数变成实时音视频流

[fastrtc](https://github.com/gradio-app/fastrtc) 由 Gradio 团队（gradio-app）维护，MIT 协议，定位是「The Real-Time Communication Library for Python」——把任意 Python 函数变成基于 WebRTC 或 WebSocket 的实时音视频流。它的核心是 `Stream` 类：

```python
from fastrtc import Stream, ReplyOnPause
import numpy as np

def echo(audio_tuple):
    sample_rate, audio = audio_tuple
    # 业务逻辑：把音频交给 ASR、LLM、TTS 处理后回传
    yield (sample_rate, audio)

stream = Stream(
    handler=ReplyOnPause(echo),   # 内置暂停检测，自动切分说话轮次
    modality="audio",
    mode="send-receive",
)
```

`Stream` 提供三种运行方式：

- **`stream.ui.launch()`**：启动内置的 Gradio 调试 UI
- **`stream.mount(app)`**：挂载到 FastAPI 应用，同时暴露 WebRTC 与 WebSocket 两种端点，适合接入现有生产系统
- **`stream.fastphone()`**：提供一个临时电话号码拨入（仅音频，需 Hugging Face token）

`ReplyOnPause` 封装了 VAD 与轮次（turn-taking）逻辑，开发者只需实现「用户暂停后如何响应」的迭代器；音频以 `(sample_rate, np.ndarray)` 元组流转，工具函数 `audio_to_bytes`、`aggregate_bytes_to_16bit` 负责格式转换。若需要暂停检测与 TTS，可安装 `pip install "fastrtc[vad, tts]"`。

### LiveKit：生产级 WebRTC 平台

[LiveKit](https://github.com/livekit/livekit) 是基于 SFU（Selective Forwarding Unit）架构的 WebRTC 平台，提供完整的客户端 SDK（浏览器、iOS、Android、服务端）和可水平扩展的媒体服务器。相比 fastrtc 偏向「Python 函数 → 实时流」的快速原型，LiveKit 更接近通信基础设施，适合多参与方、大规模并发的会议型场景。IntraScribe 选择 LiveKit 正是出于这一考虑。

### 鉴权：在挂载的端点前加一层中间件

把 RTC 端点直接暴露到公网风险较高。无论是 fastrtc 的 `stream.mount(app)`，还是 LiveKit 的 API，都需要在不改源码的前提下补一层认证。以 fastrtc + FastAPI 为例，由于 `mount` 底层调用 `gr.mount_gradio_app` 注册路由，最可靠的做法是用 HTTP 中间件统一拦截：

```python
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

VALID_TOKENS = {"your-secret-token"}

class AuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # 文档类接口可放行
        if request.url.path.startswith(("/docs", "/openapi.json")):
            return await call_next(request)
        token = request.headers.get("X-API-Key", "")
        auth = request.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            token = auth.removeprefix("Bearer ").strip()
        if token not in VALID_TOKENS:
            return JSONResponse({"detail": "Unauthorized"}, status_code=401)
        return await call_next(request)

app = FastAPI()
app.add_middleware(AuthMiddleware)
stream.mount(app)   # 中间件必须在 mount 之前注册
```

中间件相比 `Depends()` 的优势在于：它能覆盖到 Gradio/RTC 注册的所有子路由和 WebSocket 握手。LiveKit 侧则推荐使用其内置的 Access Token（JWT）机制，按房间和参与者签发短期凭证。

## 语音识别：FunASR

[FunASR](https://github.com/modelscope/FunASR) 是阿里巴巴达摩院（ModelScope）开源的工业级语音识别工具包，MIT 协议，覆盖离线、流式和边缘部署三类场景。它的目标是把语音识别的全链路能力以统一接口提供出来。

### 核心能力

FunASR 不只是单纯的识别模型，而是一套完整工具链：

- **ASR（语音识别）**：核心转写能力，含流式与离线两种模式
- **VAD（语音端点检测）**：基于 FSMN-VAD 模型，切分有效语音段
- **标点恢复**：基于 CT-Punc 模型，给原始识别结果补上标点
- **时间戳预测**：句子级与词级时间戳，方便做字幕对齐
- **说话人分离**：基于 CAM++ 模型，判断「谁在什么时候说话」
- **情绪识别**：基于 emotion2vec+ 等模型

这些能力通过一个 `AutoModel` 调用串联起来——它会自动协调配置好的 ASR、VAD、说话人模型，并返回合并后的结果。FunASR 同时提供 OpenAI 兼容的 API Server 与 MCP Server，方便接入 AI Agent。

### 模型选型

FunASR 的 Model Zoo 涵盖多种规模与语种的模型，常见的几类：

- **Paraformer**：非自回归（Non-Autoregressive）端到端 ASR，通过 CIF（Continuous Integrate-and-Fire）机制并行预测 token，推理速度快，有对应的流式版本，适合中文/英文实时识别
- **SenseVoiceSmall**：约 234M 参数，支持中、英、粤、日、韩五种语言，附带情绪识别与音频事件检测，CPU 上可达约 17 倍实时率
- **Fun-ASR-Nano / Fun-ASR-MLT-Nano**：基于 LLM 的 ASR，分别覆盖中英日方言与 31 种语言，配合 vLLM 推理可达数百倍实时率
- **Qwen3-ASR / GLM-ASR-Nano**：多语种大模型 ASR，覆盖 50+ 语言

选型时主要在「延迟、精度、资源占用」三者之间权衡：边缘/弱硬件优先 SenseVoiceSmall 或 llama.cpp 运行时；服务端并发场景适合 Paraformer 流式版；追求多语种与极限精度则考虑 Nano 系列。

### 部署与服务化

FunASR 自带 WebSocket 流式服务端，可以用一条命令拉起完整的实时识别服务：

```bash
funasr-wss-server \
  --host 0.0.0.0 --port 10095 \
  --asr-model paraformer-zh-streaming \
  --vad-model fsmn-vad \
  --punc-model ct-punc
```

客户端 SDK（Python、JavaScript、Android、iOS）把麦克风音频切块后通过 WebSocket 上传，服务端边收边识别、边返回增量结果。IntraScribe 的 STT Service 本质上就是 FunASR 的一层封装，负责与 RTC 层对接、做格式转换与后处理。

## 云端部署的补充：TURN 服务器

WebRTC 在 NAT/防火墙穿透失败时需要 TURN（Traversal Using Relays around NAT）服务器中继媒体流量。fastrtc 文档列出了几条 TURN 部署路径：

- **Cloudflare Calls API**（推荐）：通过 Hugging Face token 或 Cloudflare API token 鉴权，HF 用户每月有 10GB 免费 WebRTC 流量额度
- **Twilio**：通过 `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` 环境变量配置
- **自建**：在 AWS 上用 CloudFormation 脚本部署 coturn 等开源 TURN 实现

无论选哪种，都要注意凭据只放环境变量，不要提交到代码仓库。

## 小结

实时语音转文字的本质是把 RTC 层（音频采集与传输）、ASR 层（识别与后处理）、业务层（协作与落库）三段能力拼成一条低延迟链路。对自建团队而言：

- **快速原型**：fastrtc + FunASR，几十行代码就能跑通浏览器麦克风 → 流式识别 → 结果回显
- **生产部署**：LiveKit（或类似 SFU）+ FunASR WebSocket 服务 + 独立的说话人分离服务，配合 Redis/PostgreSQL 做状态与存储，是 IntraScribe 这类项目的典型选型
- **安全加固**：在 RTC 端点前补一层鉴权中间件，TURN 凭据用环境变量管理

需要警惕的是，开源项目的技术栈更新较快，阅读本文时请以仓库 README 的最新说明为准——例如 IntraScribe 当前版本使用 LiveKit，而早期描述里提到的 fastrtc 在其代码中并未实际使用。

## 参考

- [IntraScribe - 本地优先语音转写与协作平台](https://github.com/weynechen/intrascribe)
- [fastrtc - Real-Time Communication Library for Python](https://github.com/gradio-app/fastrtc)
- [fastrtc 官方文档](https://www.fastrtc.org/)
- [FunASR - 工业级语音识别工具包](https://github.com/modelscope/FunASR)
- [LiveKit - 开源 WebRTC 平台](https://github.com/livekit/livekit)