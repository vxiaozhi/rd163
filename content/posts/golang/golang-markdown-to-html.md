+++
title = "Markdown 转换为 HTML 的golang开源项目"
date = "2025-06-13"
lastmod = "2025-06-13"
subtitle = "Go 生态中六款 Markdown 转 HTML 工具库横评"
description = "盘点 Goldmark、Blackfriday、Lute、gomarkdown、md2html、markdownd 等六款 Go 语言 Markdown 转 HTML 开源项目的特点与用法，便于按需选型。"
author = "小智晖"
authors = ["小智晖"]
categories = ["golang"]
tags = ["golang", "markdown", "html", "goldmark", "开源项目"]
keywords = ["golang", "markdown", "markdown转html", "goldmark", "blackfriday", "lute"]
toc = true
draft = false
+++

在 Go 语言生态中，有不少优秀的开源项目可以将 Markdown 转换为 HTML。下面整理几款常见的工具和库，供选型参考。

## Goldmark

GitHub：<https://github.com/yuin/goldmark>

特点：

- 高性能，完全符合 CommonMark 标准。
- 原生支持扩展（如表格、任务列表、删除线、脚注、数学公式等）。
- 被许多知名项目采用，Hugo 自 v0.60.0 起将其作为默认 Markdown 渲染器。
- 仅依赖标准库，API 简洁，易于集成。
- 提供 Playground：<https://yuin.github.io/goldmark/playground/>

```go
import (
    "bytes"

    "github.com/yuin/goldmark"
)

md := goldmark.New()
var buf bytes.Buffer
if err := md.Convert([]byte("# Hello"), &buf); err != nil {
    panic(err)
}
html := buf.String()
```

## Blackfriday

GitHub：<https://github.com/russross/blackfriday>

特点：

- 老牌库，功能稳定，曾是 Go 社区使用最广泛的 Markdown 解析器之一。
- 支持表格、围栏代码块、自动链接、删除线等 GFM（GitHub Flavored Markdown）特性。
- 输出支持 HTML，社区另有 LaTeX 渲染器可用。
- 需注意：该仓库已进入低维护状态，最新版本 v2.1.0 发布于 2020 年 11 月，新项目建议优先考虑 Goldmark 或 gomarkdown。

```go
import "github.com/russross/blackfriday/v2"

output := blackfriday.Run([]byte("**bold text**"))
```

## Lute

GitHub：<https://github.com/88250/lute>

特点：

- 由国内开发者（B3log / 思源笔记作者）维护，对中文排版做了专门优化。
- 自动在中英文之间补加空格，并对常见的术语大小写做纠正（如 `github` → `GitHub`、`JAVA` → `Java`）。
- 完整实现 GFM 与 CommonMark 规范，零正则实现，性能优异。
- 内置代码语法高亮（基于 Chroma）、Emoji 解析、Markdown 格式化，并支持 HTML 转 Markdown。
- 同时提供 Go 与 JavaScript（通过 GopherJS 编译）两种调用方式。

```go
import "github.com/88250/lute"

luteEngine := lute.New()
html := luteEngine.MarkdownStr("demo", "## Heading")
```

## gomarkdown

GitHub：<https://github.com/gomarkdown/markdown>

特点：

- Fork 自 Blackfriday v2，由社区独立维护，持续修复 Bug 并添加新特性。
- 模块化设计，支持自定义渲染器，方便扩展输出格式。
- API 与 Blackfriday v2 基本兼容，迁移成本较低，适合不想切换到 Goldmark 的项目。

```go
import "github.com/gomarkdown/markdown"

html := markdown.ToHTML([]byte("`code`"), nil, nil)
```

## md2html

GitHub：<https://github.com/nocd5/md2html>

特点：

- 将 Markdown 转换为单一自包含 HTML 文件。
- 所有脚本和 CSS 都内嵌进文件，转换后无需联网即可离线浏览。
- 通过 `-e/--embed` 参数支持以 Base64 编码将本地图片嵌入 HTML，便于无外部资源的场景下分发文件。
- 额外提供自动生成目录（`-t`）、MathJax 数学公式（`-m`）、自定义 CSS（`-c`）、favicon 嵌入（`-f`）等能力。
- 底层使用 Goldmark 作为 Markdown 解析器。

## markdownd

GitHub：<https://github.com/aerth/markdownd>

定位：一款用 Go 编写的轻量级 Markdown 服务器。

特点：

- 默认优先将 `.md` 文件作为 `.html` 请求响应（如访问 `/index.html` 时先查找 `/index.md）。
- 若存在同名 `.html` 文件则直接返回。
- 支持静态文件托管（非 `.html`/`.md` 文件时作为下载提供）。
- 可选目录索引功能（默认关闭，使用 `-index=gen` 或 `-index=README.md` 开启）。
- 禁用符号链接与父级路径跳转（`../`），安全性较好。
- 支持原始 Markdown 源码请求（示例：`GET /index.md?raw`）。
- 可指定自定义索引页（参数示例：`-index README.md`）。
- 通过 `-toc` 参数自动生成目录结构。
- 通过 `-header`/`-footer` 参数实现主题化 HTML。
- 内置语法高亮功能（启用参数：`-syntax`）。

## 参考

- [CommonMark 规范](https://commonmark.org/)
- [GitHub Flavored Markdown 规范](https://github.github.com/gfm/)
- [Hugo 文档：配置 Markdown 渲染](https://gohugo.io/getting-started/configuration-markup/)
- [yuin/goldmark GitHub 仓库](https://github.com/yuin/goldmark)
- [gomarkdown/markdown GitHub 仓库](https://github.com/gomarkdown/markdown)
