+++
title = "Vite 入门"
date = "2026-07-21"
lastmod = "2026-07-21"
subtitle = "下一代前端构建工具的设计理念与生态"
description = "Vite 通过原生 ESM 与依赖预打包显著提升开发体验。本文梳理其核心原理、上手流程,以及 Rolldown、Farm、Turbopack、Rspack 等 Rust 构建工具的演进方向。"
author = "小智晖"
authors = ["小智晖"]
categories = ["web"]
tags = ["web", "Vite", "构建工具", "esbuild", "Rollup", "Rolldown", "Rust"]
keywords = ["Vite", "esbuild", "Rollup", "Rolldown", "Rspack", "Turbopack"]
toc = true
draft = false
+++

> Next generation frontend tooling. It's fast!

- [Vite GitHub 仓库](https://github.com/vitejs/vite)

## 为什么快

- Vite 在启动时将应用中的模块区分为**依赖**(dependencies)与**源码**(source code)两类，从而改进了开发服务器的启动时间。依赖多为第三方库，变动不频繁，Vite 使用 esbuild 对其进行预打包;源码则按需通过原生 ESM 提供给浏览器。
- 在 Vite 中，HMR(热模块替换)是在原生 ESM 之上执行的。编辑某个文件时，Vite 只需要精确地使已编辑模块与其最近的 HMR 边界之间的链失活（大多数时候只是模块本身）,因此无论应用规模如何，HMR 始终能保持快速更新。

## 快速开始

安装:

```bash
npm install -D vite
```

通过脚手架创建项目:

```bash
npm create vite@latest
```

手动创建一个 `index.html` 作为入口:

```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
    <title>Hello Vite!</title>
  </head>
  <body>
    <p>Hello Vite!</p>
    <script type="module" src="/main.js"></script>
  </body>
</html>
```

启动开发服务器:

```bash
npx vite
```

生产构建:

```bash
npm run build
```

## 构建工具的演进

前端构建工具正逐渐从纯 JavaScript 实现向 Rust 实现演进，以追求更高的性能。

### 1. esbuild

- esbuild 仅在开发环境中用于预打包依赖与快速转译 TS/JSX;Vite **不会**在生产构建中使用 esbuild 作为打包工具。

### 2. Rollup

- Rollup 以产出体积小、tree-shaking 效果好著称，Vite 在生产构建中沿用 Rollup。其 Rust 替代品 Rolldown 已进入稳定阶段（详见下文）。

由于 Vite 在开发环境使用 esbuild、在生产环境使用 Rollup，两条管线在转译行为与插件体系上存在差异，偶尔会出现开发与线上行为不一致的情况，一旦出现往往意味着较高的排查成本。

- [Rollup GitHub 仓库](https://github.com/rollup/rollup)

### 3. Parcel

- [Parcel: The zero configuration build tool for the web](https://github.com/parcel-bundler/parcel)

### 4. Rust 实现的新一代工具

**Rolldown**

- [Rolldown: A JavaScript/TypeScript bundler written in Rust intended to serve as the future bundler used in Vite](https://github.com/rolldown/rolldown)

Vite 团队主导开发的 Rolldown 已经开源，使用 Rust 编写，定位为 Rollup 的替代品。它在追求本地级性能的同时保持与 Rollup 插件 API 的兼容性，最终目标是悄然在 Vite 内部切换到 Rolldown，对使用者的影响降到最小。

为了完成这次底层重构，Vite 团队规划了四个阶段:

1. 替换 esbuild(由 Rolldown 接管依赖预打包与转译);
2. 替换 Rollup(生产构建改用 Rolldown);
3. 使用 Rust 实现常用需求的内置转化（如 TS、JSX 编译）;
4. 使用 Rust 完全重构 Vite。

**Farm**

- [Farm: Extremely fast Vite-compatible web build tool written in Rust](https://github.com/farm-fe/farm)

针对 Vite 在大型应用下请求数爆炸、开发/生产行为不一致等痛点，Farm 使用 Rust 重新实现了对 CSS/TS/JS/Sass 的编译能力，可实现毫秒级启动，大部分场景下 HMR 可控制在 20ms 以内（官方 README 数据）。自 v0.13 起，Farm 可直接复用 Vite 插件。

**Turbopack**

- [Turbopack](https://github.com/vercel/turbopack) · [Next.js 文档](https://nextjs.org/docs/app/api-reference/turbopack)

Turbopack 同样是基于 Rust 构建的前端打包工具，由 Vercel 团队开发，深度集成于 Next.js(自 Next.js 16 起已成为默认打包器)。它建立在新的增量计算架构上，打包时只关注开发所需的最小资源，因此启动速度与 HMR 速度都具备极强的竞争力。Vercel 在 2022 年发布 Turbopack 时给出的数据显示：在 3000 个模块的应用上，Turbopack 冷启动约 1.8s,Vite 约 11.4s。需要注意这是 Vercel 一方公布的对比数据，且随版本迭代差距已显著缩小，实际表现建议以本地基准测试为准。

随着 Next.js 的成熟与普及，Turbopack 作为 webpack 的继任者也获得了更多关注。

**Rspack**

- [Rspack: The fast Rust-based web bundler with webpack-compatible API](https://github.com/web-infra-dev/rspack)

Rspack 是由字节跳动开源的项目打包工具。和 Turbopack 一样，它充分发挥了 Rust 的性能优势，在打包速度上有显著提升。

与 Turbopack 不同的是，Rspack 选择了优先兼容 webpack 生态的路线。一方面，这些兼容会带来一定的性能开销，但在实际业务中通常可以接受;另一方面，这也让 Rspack 能与上层框架和现有生态更好地集成，支持业务的渐进式迁移。

Rspack 的构建耗时大致是 webpack 的十分之一——若 webpack 需要 10 秒，Rspack 约 1 秒。但它最大的优势其实不是"快",而是对 webpack 的无缝替换：基本无需改动配置，直接将 `webpack.config.js` 改名为 `rspack.config.js` 即可运行。

Rspack 不仅兼容 webpack 的语法，还兼容其插件体系。据官方介绍，在下载量最高的 50 个 webpack 插件中，大部分可以直接使用，其余的也有替代方案。

## 服务端渲染（SSR）

Vite 为服务端渲染（Server-Side Rendering, SSR）提供了内建支持，不过其 SSR API 被定位为面向库与框架作者的低层 API,Vite 团队也正在以 Environment API 推进新一代 SSR 设计。

社区项目 [create-vite-extra](https://github.com/bluwy/create-vite-extra) 提供了 Vanilla、Vue、React、Preact、Svelte、Solid 等多种框架的 SSR 模板，可作为参考。也可以通过脚手架选择 `Others > create-vite-extra` 来拉取。

- [Vite SSR 指南](https://vite.dev/guide/ssr.html)

## SEO

(待补充)

## 应用案例

- [it-tools](https://github.com/CorentinTh/it-tools) —— 一组实用的开发者在线小工具集合，基于 Vite + Vue 构建。

## 参考资料

- [Vite 官方文档](https://vite.dev/)
- [Why Vite](https://vite.dev/guide/why.html)
- [Rolldown 官网](https://rolldown.rs/)
- [Rspack 官网](https://rspack.rs/)
- [Turbopack 文档](https://nextjs.org/docs/app/api-reference/turbopack)
