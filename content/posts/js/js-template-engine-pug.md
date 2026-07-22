+++
title = "Pug：高性能 JavaScript 模板引擎入门"
date = "2025-06-11"
lastmod = "2025-06-11"
subtitle = "从 Jade 到 Pug，理解 Node.js 下缩进式模板引擎的设计与用法"
description = "Pug 是受 Haml 启发、基于缩进语法的高性能 Node.js 模板引擎。本文介绍其历史、安装方式、核心语法、API 与在 Express 中的集成。"
author = "小智晖"
authors = ["小智晖"]
categories = ["js"]
tags = ["js", "pug", "Node.js", "模板引擎", "Express"]
keywords = ["Pug", "Jade", "Node.js 模板引擎", "Express 视图引擎", "pug 语法"]
toc = true
draft = false
+++

Pug 是一款用 JavaScript 实现的高性能模板引擎（template engine），同时支持 Node.js 与浏览器环境，语法深受 Haml 启发。它通过缩进（indentation）而非闭合标签来组织 HTML 结构，让模板代码更简洁、更具可读性。官方仓库 [pugjs/pug](https://github.com/pugjs/pug) 的描述是「robust, elegant, feature rich template engine for Node.js」，目前最新稳定版本为 3.0.x，采用 MIT 协议开源。

## 曾用名 "Jade"

Pug 的前身叫 **Jade**。由于 "Jade" 是一个已被注册的商标，项目维护团队在讨论后将其更名为 "Pug"，从 2.0 版本起 `pug` 成为官方 npm 包名。

如果你的项目仍然依赖 `jade` 包，不必担心：官方保留了 `jade` 包名的占用权限，但所有新版本都只会在 `pug` 名下发布。由于更名恰好与「Jade 2.0.0」的开发同步推进，从 Jade 升级到 Pug 等同于一次主版本号升级流程，语法上有若干修改、弃用和删除，详细差异见官方 Issue [#2305](https://github.com/pugjs/pug/issues/2305)。

对新手而言，直接从 `pug` 包和新语法入手即可，无需关心历史包袱。

## 安装

Pug 提供两种安装方式：作为依赖库引入到 JavaScript 项目，或者作为全局命令行工具使用。

### 作为包安装

```bash
$ npm install pug
```

### 命令行工具

在已安装 Node.js 的环境下，可以全局安装 `pug-cli`：

```bash
$ npm install pug-cli -g
$ pug --help
```

命令行模式常用于把 `.pug` 文件预编译成 JavaScript 函数，便于在浏览器端直接调用：

```bash
$ pug --client --no-debug filename.pug
```

上述命令会生成 `filename.js`，其中包含已编译的模板函数。

## 核心语法

Pug 是一种对空白符敏感（whitespace-sensitive）的语法，用缩进表示嵌套关系，省去了 HTML 的尖括号与闭合标签。

### 一个完整示例

```pug
doctype html
html(lang="en")
  head
    title= pageTitle
    script(type='text/javascript').
      if (foo) bar(1 + 5);
  body
    h1 Pug - node template engine
    #container.col
      if youAreUsingPug
        p You are amazing
      else
        p Get on it!
      p.
        Pug is a terse and simple templating language with a
        strong focus on performance and powerful features.
```

它会被渲染为：

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>Pug</title>
    <script type="text/javascript">
      if (foo) bar(1 + 5);
    </script>
  </head>
  <body>
    <h1>Pug - node template engine</h1>
    <div id="container" class="col">
      <p>You are amazing</p>
      <p>
        Pug is a terse and simple templating language with a strong focus on
        performance and powerful features.
      </p>
    </div>
  </body>
</html>
```

### 几条关键约定

- `#container.col` 是 `div#container.col` 的简写，即带 `id="container"` 和 `class="col"` 的 `<div>`。
- 属性（attributes）写在括号内，值是合法的 JavaScript 表达式，例如 `a(href=url, class='btn')`。
- 文本可以用 `|` 前缀、行内 `=` 赋值，或紧接在标签后的 `.` 块文本。
- `//-` 是不会输出到 HTML 的注释，`//` 则会输出到结果中。

## JavaScript API

Pug 暴露了三个核心方法：`compile`、`render` 与 `renderFile`。

```javascript
const pug = require('pug');

// 1. compile：将 Pug 源码编译为可复用的函数
const fn = pug.compile('string of pug', options);
const html = fn(locals);

// 2. render：一次性编译并渲染
const html2 = pug.render('string of pug', { ...options, ...locals });

// 3. renderFile：从文件读取并渲染
const html3 = pug.renderFile('filename.pug', { ...options, ...locals });
```

常用 Options：

| 选项 | 含义 |
| --- | --- |
| `filename` | 用于异常信息和 `include` 解析，使用 include 时必填 |
| `compileDebug` | 为 `false` 时不附加调试信息，体积更小 |
| `pretty` | 是否给输出添加缩进美化，默认 `false`（生产环境建议保持默认） |

`compile` 在内部会把模板编译成 JavaScript 函数，因此首次调用比 `render` 有些额外开销，但后续调用非常快——适合缓存函数实例复用。

## 高级特性

除了基础语法，Pug 还提供了一系列用于模板复用和逻辑组织的特性。

### Mixins（混入）

Mixin 类似于可复用的函数，能够接收参数并在模板中反复调用：

```pug
mixin pet(name)
  span.pet= name

+pet('cat')
+pet('dog')
```

### Includes（包含）

`include` 把另一个 Pug（或纯文本）文件的内容原样插入当前位置，适合拆分头部、尾部等公共片段：

```pug
include ./includes/head.pug
```

### 模板继承（extends / block）

通过 `extends` 继承一个布局模板，再用 `block` 占位与覆写：

```pug
//- layout.pug
html
  head
    block title
  body
    block content

//- page.pug
extends ./layout.pug

block title
  title 首页
block content
  h1 欢迎光临
```

### 代码与控制流

Pug 支持直接在模板里写 JavaScript：用 `-` 表示不输出的代码，用 `=` 表示输出并转义的内容，`!=` 表示输出但不转义。`if/else`、`each`、`case` 等控制流语法一应俱全。

## 与 Express 集成

Pug 是 Express 默认推荐的服务端模板引擎之一。在 Express 5.x 中启用 Pug 只需两步：

```javascript
const express = require('express');
const app = express();

app.set('view engine', 'pug');
app.set('views', './views');

app.get('/', (req, res) => {
  res.render('index', { title: 'Hello', message: 'Hello from Pug!' });
});
```

随后将 `.pug` 模板放在 `views/` 目录下即可。Express 会在 `res.render` 时自动调用 `pug.renderFile`。

## 在浏览器中使用

Pug 也可以独立运行在浏览器中，官方提供了 standalone 版本。不过由于运行时编译体积较大，文档中明确建议：**优先在构建阶段把模板预编译成 JavaScript**，再在客户端直接调用编译后的函数。这也是前文 `pug --client` 命令的核心用途。

## 生态与其他语言实现

Pug 在社区中影响深远，围绕它衍生出丰富的工具链：

- **编辑器支持**：Emacs mode、Vim syntax、TextMate Bundle、VSCode 插件等。
- **格式化与转换**：[prettier-plugin-pug](https://github.com/prettier/plugin-pug)、[html2pug](https://github.com/izolate/html2pug)。
- **其他语言移植**：PHP、Java、Python、Ruby、C#（ASP.NET Core）等都有语法相近的 Pug 实现。
- **类似理念引擎**：Ruby 的 Haml 与 Slim、Scala 的 Scaml。

## 基于 Pug 开发的项目

- [app-privacy-policy-generator](https://github.com/nisrulz/app-privacy-policy-generator)：基于 Pug 的应用隐私政策生成器。

## 参考

- [Pug 官方文档（英文）](https://pugjs.org/)
- [Pug API Reference](https://pugjs.org/api/reference.html)
- [GitHub: pugjs/pug](https://github.com/pugjs/pug)
- [Pug 模板引擎中文文档](https://www.pugjs.cn/)
- [Express: Using template engines with Express](https://expressjs.com/en/5x/guide/using-template-engines/)
