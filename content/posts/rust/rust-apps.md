+++
title = "用 Rust 实现的应用有哪些？"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从编辑器、排版工具到运行时与命令行,盘点 Rust 写出的代表性项目"
description = "Rust 凭借内存安全、零成本抽象与极致性能,被越来越多的高性能工具与基础设施选为开发语言。本文按编辑器、排版、图像、运行时、命令行等场景,盘点一批用 Rust 实现的代表性开源应用。"
author = "小智晖"
authors = ["小智晖"]
categories = ["rust"]
tags = ["编程语言", "rust", "开源项目", "开发工具"]
keywords = ["rust", "rust 应用", "zed", "typst", "lapce", "ripgrep", "tauri"]
toc = true
draft = false
+++

Rust 是一门强调**内存安全（memory safety）**与**零成本抽象（zero-cost abstractions）**的系统级编程语言，同时具备 C/C++ 量级的运行性能与现代语言的人体工程学。正因为它既快又安全，越来越多追求性能、对延迟敏感或者需要在底层直接控制系统资源的工具，开始把 Rust 作为首选语言。本文按使用场景，盘点一批在生产环境中真实存在、且较有代表性的 Rust 实现的开源应用，方便选型与学习参考。

## 编辑器（Code Editors）

代码编辑器是对延迟极其敏感的一类应用——按键反馈需要尽快出现在屏幕上，多光标、大文件、语法高亮、语言服务器（LSP）等特性又会带来频繁的运算。Rust 的低运行时开销使其非常适合做这类「直面用户手感」的工具。

### Zed

[Zed](https://github.com/zed-industries/zed) 由 Atom 与 Tree-sitter 的原班团队创办的 Zed Industries 开发，仓库自我描述为「a high-performance, multiplayer code editor from the creators of Atom and Tree-sitter」，宣传语是「Code at the speed of thought」。仓库主语言为 Rust（约 97%）。

Zed 的几个特点：

- **自研 GPU 渲染框架 GPUI**：不依赖系统原生控件或 Electron，直接走 GPU 加速渲染，目标是一次按键响应进入亚毫秒级。
- **多人协作（multiplayer）**：内置实时协作编辑，不需要额外插件。
- **LSP 与 Tree-sitter**：原生支持语言服务器协议与 Tree-sitter 语法解析，提供补全、诊断、高亮等能力。
- **跨平台**：macOS、Linux、Windows 均提供支持。
- **许可协议**：以 GPL-3.0-or-later 为主，部分组件采用 Apache-2.0。

### Lapce

[Lapce](https://github.com/lapce/lapce) 仓库的自我描述是「Lightning-fast and Powerful Code Editor written in Rust」，读作 /læps/，使用 Apache-2.0 协议。

Lapce 的关键技术点：

- **UI 框架 Floem**：Lapce 团队自研的 Rust 响应式 UI 框架，仓库位于 `lapce/floem`。
- **Rope Science**：从 Xi-Editor 继承的 rope 数据结构思路，用于大文件的高效文本计算。
- **wgpu 渲染**：基于 wgpu 进行 GPU 渲染。
- **Vim 优先**：模态编辑（modal editing）是一等公民，内置 Vim-like 键位，可随时切换。
- **远程开发（Remote Development）**：内置远程开发能力，让本地编辑器驱动远端机器。
- **WASI 插件**：插件可以编译为 WASI 格式运行，支持 C、Rust、AssemblyScript 等语言。

### Helix

[Helix](https://github.com/helix-editor/helix) 自称「post-modern modal text editor」，受 Kakoune 与 Neovim 启发，采用 MPL-2.0 协议。它的编辑模型深受 Kakoune 影响——「先选择，再操作」的 selection-first 工作流，配合多光标（multiple selections），让大量重构操作可以一次完成。内置 LSP 支持与基于 Tree-sitter 的智能高亮，开箱即用，不需要像 Vim/Emacs 那样做大量配置。

## 排版系统（Typesetting）

### Typst

[Typst](https://github.com/typst/typst) 仓库的描述是「a new markup-based typesetting system that is designed to be as powerful as LaTeX while being much easier to learn and use」，主体由 Rust 编写，采用 Apache-2.0 协议。

它被社区视作现代 LaTeX 替代方案，核心特点包括：

- **标记语法 + 嵌入脚本**：以接近 Markdown 的标记书写正文，需要编程能力时用 `#` 进入 code mode 写函数与循环，比 LaTeX 的宏系统更直观。
- **原生数学公式**：例如 `$x^2 + y^2 = r^2$`，无需额外宏包。
- **增量编译极快**：Rust 实现加上增量编译，文档渲染通常在毫秒级，配合实时预览体验流畅。
- **包生态 Typst Universe**：可通过包注册中心引用代码高亮、引文、图表等扩展。

关于 Typst 的实战用法，本站另有一篇《Typst》专门介绍从环境配置到模板修改的完整流程。

## 图像编辑（Graphics Editing）

### Graphite

[Graphite](https://github.com/GraphiteEditor/Graphite) 是一款**免费、开源的矢量与栅格图形引擎**，仓库自我描述为「free, open source vector and raster graphics engine」，目前处于 Alpha 阶段，采用 Apache-2.0 协议。仓库主语言为 Rust（约 88%），前端使用 Svelte。

Graphite 的最大特色是**节点式（node-based）**的过程化图形引擎：

- 不同于 Photoshop、Illustrator 等传统图层式工具，Graphite 把每一个操作都建模为图中的一个节点，输入与输出可任意连接、回溯和参数化，类似于 Blender 的节点编辑器。
- 官方将其定位为「procedural toolbox for 2D content creation」，未来路线图涵盖平面设计、数字绘画、动效图形、桌面出版、视觉合成等。
- 既可以在线使用（浏览器内运行），也可以本地构建，源代码完全开源。

## 运行时与桌面框架（Runtime & Desktop Framework）

### Deno

[Deno](https://github.com/denoland/deno) 是一个面向 JavaScript、TypeScript 与 WebAssembly 的运行时，由 Node.js 原作者 Ryan Dahl 与 Bert Belder 共同发起，2018 年在 JSConf EU 上首次公开。仓库主语言为 Rust（约 63%），构建于 V8、Rust 与 Tokio 之上，采用 MIT 协议。

它对 Node.js 的几点改进：

- **默认安全**：除非显式授权，脚本无法访问文件、网络或环境变量等敏感能力。
- **原生 TypeScript**：可以直接运行 `.ts` 文件，无需预编译。
- **内置 Web API**：例如 `Deno.serve()`、`fetch` 等标准化的 Web API。
- **包生态 JSR**：与 npm 兼容的现代化注册中心。

### Tauri

[Tauri](https://github.com/tauri-apps/tauri) 是一个用 Rust 编写的跨平台桌面/移动应用框架，目标是「tiny, blazingly fast binaries for all major operating systems」。它和 Electron 的核心区别在于**不打包 Chromium**：通过 WRY 库调用系统自带的 WebView（macOS/iOS 的 WKWebView、Windows 的 WebView2、Linux 的 WebKitGTK、Android 的 System WebView），从而显著减小产物体积与内存占用。

Tauri 允许用任意能编译为 HTML/JS/CSS 的前端框架构建界面，后端逻辑用 Rust 实现，前端通过 API 与后端通信。内置能力包括：应用打包器（`.dmg`、`.deb`、`.rpm`、`.exe`、`.msi`、`.AppImage` 等）、自动更新、系统托盘、原生通知，覆盖 Windows 7+、macOS 10.15+、主流 Linux、iOS 9+ 与 Android 7+。

## 命令行工具（CLI）

Rust 写的命令行工具在「现代 Unix 工具链」中占有相当高的比例，下面几个几乎是开发者的标配。

### ripgrep

[ripgrep](https://github.com/BurntSushi/ripgrep)（命令名 `rg`）是「a line-oriented search tool that recursively searches the current directory for a regex pattern」，可看作 `grep` 的现代替代品，采用 MIT/UNLICENSE 双协议。它默认递归、默认尊重 `.gitignore`、默认跳过隐藏文件和二进制文件；正则引擎基于 Rust 的 `regex` crate，使用有限自动机、SIMD 与字面量优化，在保持 Unicode 开启的同时仍非常快。

### fd

[fd](https://github.com/sharkdp/fd) 是 `find` 的一个简洁、快速替代品，仓库描述为「a simple, fast and user-friendly alternative to `find`」，采用 MIT/Apache-2.0 双协议。它默认智能大小写、默认忽略隐藏文件与 `.gitignore`，并行遍历目录，并支持 `-x`/`-X` 对结果执行外部命令，配合 `fzf`、`bat` 等工具组合出非常顺手的查找—预览工作流。

### Ruff

[Ruff](https://github.com/astral-sh/ruff) 由 Astral 团队开发，仓库描述为「An extremely fast Python linter and code formatter, written in Rust」，采用 MIT 协议。它把 Flake8（含数十款插件）、Black、isort、pyupgrade、autoflake 等工具整合为一款工具，官方给出的对比数据是「比现有 linter 与 formatter 快 10–100 倍」，内置 900+ 条规则，支持自动修复与 `pyproject.toml` 配置，已成为 Python 生态里事实上的默认 lint 工具之一。

## JavaScript 工具链（JavaScript Toolchain）

近两年前端构建工具生态也在大规模「Rust 化」，几款重量级工具都用 Rust 重写或实现：

- **Oxc**（[oxc-project/oxc](https://github.com/oxc-project/oxc)）：The Oxidation Compiler，一套用 Rust 写的高性能 JS/TS 工具集合，涵盖 parser、linter（oxlint）、formatter（oxfmt）、transformer、minifier、resolver。
- **Rolldown**：Rust 实现的 Rollup 兼容打包器，是 Vite 即将采用的底层 bundler，由 Oxc 提供解析、转换与压缩能力。
- **Turbopack**：Vercel 用 Rust 实现的增量打包器，定位是 Webpack 的继任者，已内置于 Next.js，启动与热更新速度在大项目中有显著提升。

前端构建工具的整体演进脉络——从 esbuild、Rollup 到 Rolldown、Rspack、Turbopack、Farm——可参见本站《Web 前端框架》与《Vite 学习》两文的对比部分。

## 小结

从上面这份不完全清单可以看出，Rust 写出的应用大致集中在三类场景：

1. **延迟敏感、直面用户手感的工具**：代码编辑器（Zed、Lapce、Helix）、命令行工具（ripgrep、fd）。
2. **需要兼顾性能与安全的运行时与框架**：Deno、Tauri、Oxc、Rolldown。
3. **重计算、强类型需求的领域工具**：Typst（排版）、Graphite（图像编辑）、Ruff（Python lint）。

它们的共同点是：要么追求极致性能，要么需要长期稳定、低维护成本，要么需要在不牺牲运行速度的前提下提供现代语言的人体工程学——这恰好是 Rust 的舒适区。

如果你想用 Rust 自己做一个 Web 应用（前端 / 后端），可以继续阅读本站的相关文章：

- 《[使用 Rust 创建 Web 应用程序](../web/web-app-with-rust.md)》——梳理 Yew、Dioxus、Leptos、Sycamore 等前端框架的取舍。
- 《[Vite 入门](../web/get-started-with-vite.md)》——理解其底层已部分依赖 Rust 工具链的构建工具。

## 参考

- [Zed GitHub(zed-industries/zed)](https://github.com/zed-industries/zed)
- [Lapce GitHub(lapce/lapce)](https://github.com/lapce/lapce) / [Floem(lapce/floem)](https://github.com/lapce/floem)
- [Helix GitHub(helix-editor/helix)](https://github.com/helix-editor/helix)
- [Typst GitHub(typst/typst)](https://github.com/typst/typst) / [Typst 官网](https://typst.app)
- [Graphite GitHub(GraphiteEditor/Graphite)](https://github.com/GraphiteEditor/Graphite)
- [Deno GitHub(denoland/deno)](https://github.com/denoland/deno) / [Deno 官网](https://deno.com)
- [Tauri GitHub(tauri-apps/tauri)](https://github.com/tauri-apps/tauri)
- [ripgrep(BurntSushi/ripgrep)](https://github.com/BurntSushi/ripgrep)
- [fd(sharkdp/fd)](https://github.com/sharkdp/fd)
- [Ruff(astral-sh/ruff)](https://github.com/astral-sh/ruff)
- [Oxc(oxc-project/oxc)](https://github.com/oxc-project/oxc)