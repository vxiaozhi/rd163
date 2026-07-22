+++
title = "JSON 可视化编辑工具盘点"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从节点图可视化到表单化 Schema 编辑,五款开源方案横向对比"
description = "盘点五款主流的 JSON / JSON Schema 可视化编辑开源工具,对比 JSON Crack、json-schema-editor-visual 等的定位、特性与适用场景。"
author = "小智晖"
authors = ["小智晖"]
categories = ["json"]
tags = ["json", "JSON Schema", "可视化", "前端工具", "开源"]
keywords = ["JSON 可视化", "JSON Crack", "JSON Schema 编辑器", "YApi", "可视化编辑"]
toc = true
draft = false
+++

JSON（JavaScript Object Notation）几乎是今天所有 Web API 和配置文件的默认载体。但当数据嵌套层级变深、字段数量变多，纯文本的 JSON 就开始「反人类」:括号配错一个、逗号漏掉一个、键名拼错一个，都需要肉眼在海量文本里排查。可视化编辑（visual editing）的核心思路，是把这棵抽象的语法树（AST）还原成可点选、可折叠、可校验的图形界面，让人而不是正则去理解结构。

本文按「可视化」的实现方式把常见开源工具分成三类：节点图可视化、表单化 Schema 编辑、树形编辑器，并逐个给出定位与适用场景。所有数据（Star 数、协议、状态）均取自 GitHub 仓库当前值。

## 一、节点图可视化:JSON Crack

[JSON Crack](https://github.com/AykutSarac/jsoncrack.com) 是目前同类项目里 Star 数最高、生态最完整的方案，GitHub Star 约 44.2K,Fork 3.5K，采用 Apache-2.0 协议，仓库持续活跃。它的卖点不是「编辑」,而是「看」——把 JSON、YAML、XML、CSV 等多种数据格式实时渲染成可缩放、可拖拽的交互式节点图（node graph）,父子关系一目了然。

核心能力:

- **多格式可视化**:除 JSON 外，支持 YAML、XML、CSV 的图形化展示。
- **格式互转**:JSON ↔ CSV、XML ↔ JSON 等。
- **代码生成**:一键从 JSON 生成 TypeScript interface、Golang struct、Kotlin data class、Rust serde 类型、JSON Schema。
- **校验与格式化**:对 JSON、YAML、CSV 做语法校验和美化。
- **高级查询**:支持 [jq](https://jqlang.github.io/jq/) 和 JSONPath 查询。
- **导出**:节点图可导出为 PNG / JPEG / SVG。
- **隐私优先**:所有解析与渲染均在浏览器本地完成，服务端不存储数据。

技术栈是 Next.js + React + TypeScript，以 Turborepo 组织 monorepo，同时提供 VS Code 扩展、Chrome 扩展和 npm 包 `jsoncrack-react`,可嵌入到自己的应用里。如果你面对的是一份庞大且陌生的 API 响应或配置文件，想快速建立结构认知，JSON Crack 是首选。

## 二、表单化 Schema 编辑

这一类工具的典型用法是：先定义 JSON Schema(数据结构契约),再基于 Schema 自动生成表单，让非技术人员通过填表来产出符合规范的 JSON。常见于低代码平台、组件配置面板、接口管理平台。

### wibetter/json-editor

[wibetter/json-editor](https://github.com/wibetter/json-editor) 自述「提供 JSON 与 JSON Schema 的可视化编辑能力」,内置三个互相配合的子包:

- **JSONEditor**:基于已定义的 Schema 把 JSON 数据渲染成表单，供最终用户填写配置。
- **SchemaEditor**:以表单方式设计 Schema 本身（定义字段名、类型、约束、展示控件）。
- **JSONUtils**:提供 schema↔JSON 互转、JSON 元数据分析等工具方法。

技术栈以 JavaScript + TypeScript 为主（代码里 TS 占比约 43%）,定位偏「组件配置可视化」,适合需要给运营、产品同学提供可视化配置后台的 B 端场景。在线 demo 见仓库 `online-demo/7.0.0/`。Star 数目前约 48，体量虽小，但「表单化 + Schema 驱动」的工程化思路在这个细分方向上非常典型。

### Open-Federation/json-schema-editor-visual

[json-schema-editor-visual](https://github.com/Open-Federation/json-schema-editor-visual) 是「高效、易用的 React 版 JSON Schema 编辑器」,Star 约 1.1K,Fork 231,MIT 协议，基于 React + Ant Design。它解决的痛点是：手写 JSON Schema 的 `properties` / `items` / `required` 嵌套极容易出错，而可视化编辑器能像编辑目录树一样编辑 Schema。

典型 API 很轻量:

```jsx
import JSONSchemaEditor from 'json-schema-editor-visual';

<JSONSchemaEditor
  data={schemaString}   // 初始 schema 字符串
  onChange={(newSchema) => console.log(newSchema)}
  showEditor={false}    // 是否同时展示源码编辑区
  lang="zh_CN"           // 支持 en_US / zh_CN
/>
```

值得说明的是，该仓库 demo 的作者（hellosean1025）与开源接口管理平台 [YApi](https://github.com/YMFE/yapi) 为同一作者，因此这个组件被广泛用作 YApi 风格接口定义中的 Schema 编辑器——这也是本文原稿标注「YApi 使用」的由来。如果团队在做接口平台或 Mock 平台，需要一个可嵌入的 Schema 设计器，这是绕不开的参考实现。

## 三、树形 / GUI 编辑器

### sempostma/json-gui

[json-gui](https://github.com/sempostma/json-gui) 是一个轻量的「JSON Viewer」,用 Jekyll 搭建的静态站点，在线地址 `json-gui.esstudio.site`。仓库语言以 CSS、JavaScript、HTML 为主，GPL-3.0 协议,**已于 2026 年 3 月归档为只读**。Star 约 19。功能上偏「查看」而非「编辑」,适合做一次性结构浏览，不建议在新项目里依赖。

### ogaoga/json-visual-editor

[JSON Visual Editor v2](https://github.com/ogaoga/json-visual-editor) 是基于 React + Redux Toolkit + TypeScript 的树形可视化编辑器，MIT 协议,**已于 2026 年 1 月归档**。最新版本 v2.0 发布于 2020 年 6 月，Star 约 115。作为学习 React 可视化编辑器实现的参考代码尚可（含 Cypress E2E 测试）,生产环境请选用仍在维护的替代品。

## 选型建议

按「想做什么」对号入座:

| 需求场景 | 推荐工具 | 理由 |
|---------|---------|------|
| 把大段 JSON / API 响应画成图，快速理解结构 | JSON Crack | 节点图体验最佳，生态最完整 |
| 在内部平台嵌入可视化 JSON 查看器 | JSON Crack(`jsoncrack-react` 包) | 提供 npm 包，可二次集成 |
| 给非技术人员做表单化配置后台 | wibetter/json-editor | SchemaEditor + JSONEditor 一套齐全 |
| 给接口平台做 JSON Schema 设计器 | json-schema-editor-visual | YApi 同作者，事实标准 |
| 纯查看、一次性浏览 | 任一已归档项目或在线 JSON Viewer | 不必引入长期依赖 |

一个通用原则:**「看结构」用节点图,「填数据」用表单化 Schema 编辑器,「改源码」用 IDE 的 JSON 语言服务**。三者解决的是不同层次的问题，常常需要组合使用——比如先用 JSON Crack 把陌生接口的结构画出来，再用 json-schema-editor-visual 把结构沉淀成 Schema，最后交给 JSONEditor 让业务方按表单填写数据。

## 参考

- [AykutSarac/jsoncrack.com](https://github.com/AykutSarac/jsoncrack.com) — Apache-2.0,44.2K Star
- [wibetter/json-editor](https://github.com/wibetter/json-editor) — JSON 与 JSON Schema 表单化编辑
- [Open-Federation/json-schema-editor-visual](https://github.com/Open-Federation/json-schema-editor-visual) — React 版 JSON Schema 编辑器，MIT,1.1K Star
- [YMFE/yapi](https://github.com/YMFE/yapi) — YApi 接口管理平台
- [sempostma/json-gui](https://github.com/sempostma/json-gui) — JSON Viewer,GPL-3.0，已归档
- [ogaoga/json-visual-editor](https://github.com/ogaoga/json-visual-editor) — React 树形编辑器，MIT，已归档
- [jq 官方文档](https://jqlang.github.io/jq/) — JSON Crack 内置的命令行 JSON 查询语言
