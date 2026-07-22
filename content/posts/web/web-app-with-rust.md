+++
title = "使用 Rust 创建 Web 应用程序"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Yew、Dioxus、Leptos、Sycamore 四大前端框架横向对比"
description = "梳理 Rust 在 WebAssembly 前端领域的四大主流框架,从渲染模型、语法、性能与生态等维度横向对比,并给出选型建议。"
author = "小智晖"
authors = ["小智晖"]
categories = ["web"]
tags = ["web", "rust", "wasm", "frontend", "webassembly"]
keywords = ["rust", "wasm", "前端框架", "yew", "leptos", "dioxus"]
toc = true
draft = false
+++

Rust 凭借零成本抽象、强类型系统和出色的 WebAssembly(Wasm)编译目标，正逐步成为前端开发的一个新选项。借助 `wasm-bindgen` 与 `wasm-pack` 等工具链，开发者可以将 Rust 代码编译为 Wasm 模块在浏览器中运行，从而在保留类型安全与高性能的同时绕开传统 JavaScript 生态的部分痛点。

目前 Rust 在 Web 前端领域已经形成了若干较为成熟的 UI 框架，其中最具代表性的四个是 [Yew](https://github.com/yewstack/yew)、[Dioxus](https://github.com/DioxusLabs/dioxus)、[Leptos](https://github.com/leptos-rs/leptos) 与 [Sycamore](https://github.com/sycamore-rs/sycamore)。它们都允许用 Rust 编写声明式 UI，但在渲染模型、语法风格与生态定位上差异明显。本文将对这四个框架进行横向梳理，并给出选型建议。

## 共同基础:WebAssembly 与工具链

无论选择哪个框架，Rust 前端项目都依赖以下几个共同的基础设施:

- **WebAssembly**:一种可移植的低级字节码格式，Rust 通过 `wasm32-unknown-unknown` 目标将代码编译为 `.wasm` 模块在浏览器执行。
- **`wasm-bindgen`**:Rust 与 JavaScript 之间的互操作层，负责类型映射与 JS 调用。
- **构建工具**:Yew/Leptos/Sycamore 常使用 [Trunk](https://github.com/trunk-rs/trunk)(`trunk serve` 启动开发服务器、`trunk build` 产出生产产物);Dioxus 自带 `dx` CLI(`dx serve`、`dx bundle`);Leptos 全栈场景则推荐 `cargo-leptos`。

理解这一点后，选型的核心就集中在 **渲染模型** 与 **框架定位** 上。

## 渲染模型:VDOM vs. 细粒度响应式

四个框架在渲染机制上可以分为两大阵营:

1. **虚拟 DOM(Virtual DOM,VDOM)**:组件函数在状态变更时重新执行，生成新的虚拟节点树，框架再与旧树做 diff，最后提交最小变更到真实 DOM。代表:**Yew**。优点是模型直观（对 React 开发者友好）,缺点是存在 diff 开销与重复执行开销。
2. **细粒度响应式（Fine-grained Reactivity）**:组件只运行一次，直接创建真实 DOM 节点并订阅响应式信号（Signal）;当某个信号变化时，只有与该信号绑定的那个 DOM 节点被更新，无需 diff。代表:**Leptos**、**Sycamore**,以及 Dioxus 在新版本中采用的 signals 模型。这种思路深受 [SolidJS](https://www.solidjs.com/) 启发，在渲染速度、内存占用和首屏时间上通常优于 VDOM 方案。

这一底层差异直接决定了下面各框架的性能特征。

## 四大框架对比

### Yew

- 仓库:[yewstack/yew](https://github.com/yewstack/yew),最新版本约 v0.23.x。
- 渲染模型:**虚拟 DOM**,通过最小化 DOM API 调用来提升性能，支持将任务卸载到 Web Worker，因此具备多线程前端能力。
- 语法:`html!` 宏，类似 JSX，熟悉 React 的开发者可以快速上手;早期版本受 Elm 架构影响较深，现已转向函数式组件。
- 特点：最成熟、应用案例最多、文档相对完善;但在闭包中需要显式 `.clone()`、事件回写样板代码较多。
- 生态：社区驱动维护，审核与 PR 处理较为稳健，但长期路线图相对平缓。

Yew 适合从 React/Elm 迁移过来、希望快速复用既有心智模型的团队。

### Dioxus

- 仓库:[DioxusLabs/dioxus](https://github.com/DioxusLabs/dioxus),最新版本约 v0.7.x。
- 渲染模型：基于 **Signals** 的状态管理（融合了 React、Solid、Svelte 的理念）,配合其自研的 block-DOM 渲染策略，在 Web 端的 hello world 体积约 50KB 级别。
- 语法:`rsx!` 宏，结构类似 JSX 但使用 Rust 原生 token(`h1 { "..." }`),由编译期宏展开为类型安全的构建器。
- 定位：明确以"Rust 版 React"自居，且最大卖点是 **跨平台**——同一份代码可编译到 Web、Desktop(WebView)、Mobile(iOS/Android，输出 `.ipa`/`.apk`)、Server(SSR + Hydration)。
- 工具链：自带 `dx` CLI，内置零配置、热重载、打包与 `dx bundle` 部署。

Dioxus 适合希望"一套代码多端运行"的团队，尤其是需要兼顾桌面/移动端的项目。代价是 WASM 二进制体积相对较大、内部使用了较多 `unsafe` 代码。

### Leptos

- 仓库:[leptos-rs/leptos](https://github.com/leptos-rs/leptos),最新版本约 v0.8.x。
- 渲染模型:**细粒度响应式**,组件函数只执行一次，信号变更时直接更新单个文本节点或属性，无 VDOM 开销。深受 SolidJS 启发。
- 语法：默认提供 JSX 风格的 `view!` 宏，也支持纯 Rust 的 builder 写法;信号（Signal）是 `Copy + 'static`,可以轻松 move 进闭包，使用体验干净。
- 定位:**全栈同构（Isomorphic）** 是其强项。内置 server functions、路由、HTTP 流式 SSR 与 hydration，支持有序/无序 HTML 流式渲染，并整合 `cargo-leptos` 工具链。
- 特点：完全安全的 Rust;在 js-framework-benchmark 中通常位列 Rust 框架第一梯队，渲染速度、内存占用、SSR 速度均表现突出;WASM 二进制相对较小。

Leptos 适合追求极致性能、需要 SSR/同构、且希望底层全部是 safe Rust 的项目。

### Sycamore

- 仓库:[sycamore-rs/sycamore](https://github.com/sycamore-rs/sycamore),最新版本约 v0.9.x。
- 渲染模型:**细粒度响应式**,同样深受 SolidJS 启发（官方致谢中明确提及）,无虚拟 DOM。
- 语法:`view!` 宏 + `#[component]` 属性，但模板风格与 Leptos 略有差异。
- 特点：比 Dioxus/Leptos 更早成熟，但发展节奏相对平稳;性能优于 Yew，在细粒度阵营中与 Leptos 接近;WASM 二进制体积较小。
- 配套：其最大生态红利是 **Perseus** 元框架（见下文）。

Sycamore 适合偏好简洁 API、追求小体积、并希望直接使用 Perseus 全栈方案的开发者。

## 全栈方案:Perseus 与 cargo-leptos

如果只看 UI 框架，功能依然停留在 SPA 层面。要把 Rust 推到完整的前端工程，还需要"元框架"来处理路由、数据获取与渲染策略:

- **Perseus**([framesurge/perseus](https://github.com/framesurge/perseus),约 v0.4.x):基于 Sycamore 构建的状态驱动 Web 开发框架，定位类似 WebAssembly 版的 Next.js。支持 **SSG**(构建时生成)、**SSR**(请求时渲染)、**Revalidation**(周期性或按规则更新)与 **ISR**(增量静态再生，按需构建),并允许任意策略组合使用。
- **cargo-leptos**:为 Leptos 定制的构建工具，把 SSR、hydration、客户端打包与发布串成一条流水线，适合构建同构全栈应用。
- **Dioxus 0.6+ 的内置全栈**:Dioxus 通过 Server Functions 与 axum 集成，直接提供 SSR、Suspense、SSG 与增量再生，无需外挂元框架。

可以看出,**渲染策略（SSG / SSR / ISR / 流式 SSR）已经成了新一代 Rust 前端框架的标配**,而不仅仅是 SPA 渲染。

## 横向对比表

| 维度 | Yew | Dioxus | Leptos | Sycamore |
|---|---|---|---|---|
| 渲染模型 | 虚拟 DOM | Signals + block-DOM | 细粒度响应式 | 细粒度响应式 |
| 语法 | `html!`(类 JSX) | `rsx!`(类 JSX,Rust token) | `view!`(类 JSX) | `view!` + `#[component]` |
| 主要启发 | React / Elm | React / Solid / Svelte | SolidJS | SolidJS |
| 安全性 | Safe Rust | 较多 `unsafe` | Safe Rust | 较多 `unsafe` |
| 平台覆盖 | Web | Web / Desktop / Mobile / Server | Web + 全栈 SSR | Web |
| WASM 体积 | 中等 | 较大 | 较小 | 较小 |
| 性能梯队 | 第二梯队 | 第一梯队（改进中） | 第一梯队 | 第一梯队 |
| 元框架 | (社区方案) | 内置 Server Functions | cargo-leptos | Perseus |

> 注：性能梯队参考 [js-framework-benchmark](https://krausest.github.io/js-framework-benchmark/current.html)(Chrome 130 测试结果),具体排名随版本迭代持续变化，以官方榜单为准。

## 选型建议

- **从 React 迁移、求稳**:选 **Yew**,心智模型最接近，生态最成熟。
- **一套代码多端运行（Web + 桌面 + 移动）**:选 **Dioxus**,跨平台能力独一档。
- **追求极致性能 + 全栈同构**:选 **Leptos**,渲染速度、SSR、安全 Rust 综合最佳。
- **偏好简洁 + 想直接用 Perseus**:选 **Sycamore**,与 Perseus 深度集成，小体积优势明显。

需要强调的是，Rust 前端生态整体仍在快速演进中——Dioxus 和 Leptos 的版本号还在 0.x,API 可能出现破坏性变更。在生产落地前，建议先在内部工具或非核心页面试点，并锁定具体版本与工具链。

## 参考

- [前端框架 Yew、Dioxus、Leptos、Sycamore 区别](https://juejin.cn/post/7282733743911354425)
- [Yew 官方仓库](https://github.com/yewstack/yew)
- [Dioxus 官方仓库](https://github.com/DioxusLabs/dioxus)
- [Leptos 官方仓库](https://github.com/leptos-rs/leptos)
- [Sycamore 官方仓库](https://github.com/sycamore-rs/sycamore)
- [Perseus 官方仓库](https://github.com/framesurge/perseus)
- [Trunk 构建工具](https://github.com/trunk-rs/trunk)
- [js-framework-benchmark 性能榜单](https://krausest.github.io/js-framework-benchmark/current.html)
