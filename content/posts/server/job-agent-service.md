+++
title = "任务代理服务"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "CI/CD 自托管 Runner / Agent 开源方案对比"
description = "梳理 CI/CD 场景下「任务代理服务」的概念与两种主流开源实现:Buildkite Agent 与 GitHub Actions Runner,对比架构、协议、平台支持与选型建议。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "agent", "ci-cd", "buildkite", "github-actions", "runner"]
keywords = ["任务代理服务", "CI/CD Runner", "Buildkite Agent", "GitHub Actions Runner", "自托管 Runner", "buildkite-agent"]
toc = true
draft = false
+++

在落地 CI/CD 流水线时，团队迟早会撞到一类问题：控制面（SaaS 上的流水线定义、调度、日志查看）足够好用，但执行面却受限于厂商托管的运行环境——网络不通内网、镜像拉取慢、需要的 GPU 或特殊硬件拿不到、或者合规上代码不能出私网。这时通常的解法是把**作业执行**从云厂商剥离出来，放到自己的基础设施上，这就是所谓的**任务代理服务（Runner / Agent）**。

本文先把这个概念讲清楚，再横向对比两个可以直接拿来用的开源方案:[buildkite-agent](https://github.com/buildkite/agent) 和 [actions/runner](https://github.com/actions/runner)。

## 什么是任务代理服务

任务代理服务是一段常驻（或按需启动）在执行节点上的程序，它的工作可以拆成四步:

1. **拉取（Poll）**:轮询远端的控制面，问"有我这种标签的作业吗?"。控制面负责接收 Webhook、解析流水线定义、决定调度顺序，代理只负责"取活儿"。
2. **执行（Run）**:拿到作业后，在工作目录里 checkout 代码、按步骤执行 shell 命令或脚本。
3. **上报（Report）**:把每一步的退出码、stdout/stderr 实时回传给控制面，渲染成 Web 上看到的日志。
4. **收尾（Artifact）**:上传构建产物、缓存、meta-data，然后清理工作区（或者保留以便复用）。

这种"控制面 SaaS + 执行面自有"的架构被称作**混合模式（Hybrid Model）**。它的核心权衡是：把"调度复杂度"外包给云厂商，把"算力、网络、密钥"留在自己手里。与之相对的是**全托管（Managed）Runner**,例如 GitHub 默认提供的 Ubuntu/macOS/Windows Runner，你不需要维护任何机器，但环境是公开、共享、用完即焚的。

## 两个主流开源方案

### buildkite-agent

[buildkite/agent](https://github.com/buildkite/agent) 是 Buildkite 平台的开源执行器。Buildkite 本身是 SaaS(控制面在 `buildkite.com`),而 Agent 可以跑在你任意一台机器上。它的自我描述是"a small, reliable, and cross-platform build runner that makes it easy to run automated builds on your own infrastructure"。

几个值得注意的事实:

- **语言与协议**:用 Go 编写，体积很小，单一二进制。采用 **MIT License**。
- **平台支持**:Linux、macOS、Windows 全平台覆盖，架构上同时支持 `x86_64` 和 `arm64`。官方给出分层支持:Tier 1(linux/amd64、linux/arm64、windows/amd64，保证可用)、Tier 2(保证可构建)、Tier 3(社区维护)。
- **分发**:apt(Ubuntu/Debian)、Homebrew(macOS)、安装脚本、以及官方 Docker 镜像（Alpine 与 Ubuntu LTS 变体，带语义化版本标签）。
- **CLI 能力**:除了 `start` 启动常驻进程，还有 `annotate`(给构建打注释)、`artifact`(上传/下载产物)、`pipeline`(在运行时动态改写流水线)、`meta-data`(构建间键值存储)、`lock`(分布式锁)、`oidc`(签发 OIDC token 给云厂商做短期凭据)、`step`、`bootstrap` 等子命令。
- **可扩展点**:`Hooks`(生命周期钩子，比如 `environment`、`pre-command`、`post-command`)允许在作业各阶段插自定义脚本;`Plugins` 则把常用步骤(如 `docker-compose`、`docker`)打包复用。
- **遥测**:默认会上报特性使用统计，可用 `--no-feature-reporting` 关闭。
- **典型用户**:Shopify、Uber、Lyft、Slack、Canva、Pinterest 等都在用它跑超大规模的构建。

商业上 Buildkite 按"活跃用户 + Agent 数 + 托管分钟数"计费。自托管 Agent 在 Pro 套餐下前 10 个免费，超出按约 $3.50/agent/月计算（以 P95 计费，忽略尖峰）。

### actions/runner

[actions/runner](https://github.com/actions/runner) 是 GitHub Actions 官方的 Runner 应用，描述为"the application that runs a job from a GitHub Actions workflow"。和 buildkite-agent 不同的是，同一个二进制**既被 GitHub 用来跑它自己的托管 Runner(GitHub-hosted),也可以由你在自己机器上跑（self-hosted）**,两者代码一致，区别只在部署位置和维护方。

要点:

- **语言与协议**:主体用 **C#** 编写（占比约 96%）,其余是少量 JavaScript,MIT License。打包成 Linux / macOS / Windows 三平台的 tarball 与 zip，从 [Releases 页](https://github.com/actions/runner/releases)下载。
- **托管 vs 自托管**:GitHub-hosted Runner 由 GitHub 维护、补丁、扩容，用完即焚;self-hosted Runner 由你部署在物理机、虚拟机、容器或本地机房,**你需要自己负责 OS 与依赖更新**。
- **管理层级**:可以挂在三类作用域下——Repository(只服务单个仓库)、Organization(组织内多仓共享)、Enterprise(跨多个组织分配)。配合 **Runner Groups** 做隔离，用 **Labels** 让工作流定向路由到特定节点(如 `gpu`、`arm64`、`self-hosted`)。
- **工作方式**:启动后通过配置 token 注册到 GitHub，然后轮询作业;接收到 job 后，在工作目录执行 workflow 中定义的 steps。
- **配套项目**:[actions/runner-images](https://github.com/actions/runner-images) 维护 GitHub-hosted Runner 使用的 VM 镜像源码，想在自己的自托管 Runner 上复刻官方环境时可参考。在 Kubernetes 上跑弹性 Runner 时，社区主流方案是 [Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller)。
- **费用**:Runner 软件本身免费，自托管也不向 GitHub 付费（你自己承担机器成本）。

## 横向对比

| 维度 | buildkite-agent | actions/runner |
|------|-----------------|----------------|
| 控制面 | 仅 Buildkite SaaS | 仅 GitHub Actions |
| 实现语言 | Go | C# |
| 协议 | MIT | MIT |
| 平台 | Linux / macOS / Windows + arm64 | Linux / macOS / Windows |
| 部署形态 | 单二进制 / apt / brew / Docker | 解压 tarball / zip |
| 生态扩展 | Hooks + Plugins | Marketplace Actions + ARC |
| 与代码托管耦合 | 低（支持任意 Git 源） | 高（默认绑定 GitHub 仓库） |
| 商业成本 | Agent 数 / 用户数计费 | 软件免费，自托管零授权费 |

二者在概念上高度相似（都是"轮询 → 执行 → 上报 → 收尾"）,真正的差异在**生态绑定**:actions/runner 与 GitHub 仓库、Actions Marketplace、OIDC、Required reviews 等深度耦合，适合已经全面用 GitHub 的团队;buildkite-agent 更像"中性执行层",流水线定义和代码托管解耦，适合需要把同一套构建同时接到多个 Git 提供方、或者对内网执行有强约束的场景。

## 选型建议

- **团队已重度使用 GitHub，且流水线就是仓库内 `.github/workflows`**:优先 self-hosted Runner。从单台常驻机器起步，需求复杂后再上 ARC 做 K8s 弹性伸缩。
- **执行节点要跑在内网/合规域，或者构建需要在多 Git 提供方之间复用**:考虑 Buildkite Agent。它的流水线定义可以由任意脚本动态生成，跟代码托管平台解耦，适合做"统一执行底座"。
- **两个都要**:并不冲突。不少团队在 Buildkite 上跑重型集成测试、用 GitHub Actions 跑 PR 级别的轻量检查，各取所长。
- **更通用的备选**:除这两个之外，GitLab Runner(Go 编写，executor 模型丰富)、Jenkins Agent(传统 controller/agent 架构，插件生态最大)也都是成熟选择，只是它们对应的是 GitLab CI 与 Jenkins 这两套完整平台，不是"挂在第三方 SaaS 控制面上"的纯执行器。

## 落地时的几个注意点

无论选哪一种，自托管代理服务都要在团队内明确以下事项:

- **隔离与多租户**:同一个 Agent 不要同时跑不同敏感级别的作业，用 Runner Group / Queue 隔离;PR 来自 fork 时尤其要小心密钥泄露，默认应关闭 secrets 注入。
- **密钥管理**:尽量用 OIDC 换取云厂商的短期 STS 凭据(Buildkite 的 `agent oidc`、GitHub 的 `id-token: write`),避免在 Agent 上长存 AK/SK。
- **清理策略**:自托管 Runner 默认不在每次作业后重建实例，工作区会累积，需要定期 `clean` 或用容器化的 ephemeral runner。
- **更新与漏洞**:Runner 软件本身会自动升级（GitHub）或随包升级（Buildkite）,但 OS 层、Docker daemon、构建工具链的补丁是自己的责任。
- **可观测性**:Agent 进程挂掉、磁盘打满、网络抖动都会导致作业"假死",务必对 Agent 进程与所在节点加基础监控与告警。

## 参考

- [buildkite/agent — GitHub](https://github.com/buildkite/agent)
- [actions/runner — GitHub](https://github.com/actions/runner)
- [actions/runner-images — GitHub](https://github.com/actions/runner-images)
- [About self-hosted runners — GitHub Docs](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners)
- [Buildkite Docs](https://buildkite.com/docs)
- [Buildkite Pricing](https://buildkite.com/pricing)
