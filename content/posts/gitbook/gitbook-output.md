+++
title = "Gitbook 输出格式"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "GitBook CLI 支持的几种图书输出方式"
description = "介绍 GitBook 命令行工具支持的静态网站、JSON、PDF/EPUB/MOBI 等输出格式，以及对应的 build、pdf、epub、mobi 命令与依赖。"
author = "小智晖"
authors = ["小智晖"]
categories = ["gitbook"]
tags = ["gitbook", "文档工具", "电子书"]
keywords = ["gitbook", "gitbook 输出格式", "gitbook pdf", "gitbook epub", "gitbook 静态网站", "ebook-convert"]
toc = true
draft = false
+++

GitBook 命令行工具（`gitbook-cli`）可以把 Markdown 或 AsciiDoc 写成的源文件，构建为多种可分发的内容形态。本篇先对几种常见的输出格式做整体介绍，具体的操作细节在后续文章展开。

> 说明：GitBook CLI（v3.2.3）目前已被官方标记为 **Deprecated（弃用）**，GitBook 团队已将重心转向 [gitbook.com](https://www.gitbook.com) 在线平台。CLI 仍可在本地使用，但不再活跃维护。下文内容面向旧版工具链，新项目建议评估其他文档生成工具（如 mdBook、Docusaurus、VitePress 等）。

## 支持的输出格式

从 GitBook 的命令行参数和内部生成器（generator）实现来看，输出后端实际只有三类：`website`、`json`、`ebook`。其中 `ebook` 又可细分为 PDF、EPUB、MOBI 三种文件格式。

| 输出格式 | 命令 | 典型用途 |
| --- | --- | --- |
| 静态网站（HTML） | `gitbook build` / `gitbook serve` | 部署到任意静态服务器或 GitHub Pages |
| JSON | `gitbook build --format=json` | 二次处理、导入其他系统 |
| PDF | `gitbook pdf` | 打印、离线阅读 |
| EPUB | `gitbook epub` | 通用电子书阅读器 |
| MOBI | `gitbook mobi` | Kindle 设备 |

## 静态网站（HTML）

这是 GitBook 的默认输出。`gitbook build` 会把整本书渲染成一个包含 HTML、CSS、JavaScript 与搜索索引（`search_index.json`）的静态站点，可以直接部署到 Nginx、GitHub Pages、对象存储等任意静态托管服务。

```bash
# 默认输出到 ./_book 目录
$ gitbook build

# 指定输出目录
$ gitbook build ./mybook --output=/tmp/gitbook-site

# 本地预览（默认监听 4000 端口，文件修改自动重载）
$ gitbook serve
```

详细用法见本系列的《Gitbook 输出为静态网站》一文。

## JSON

通过 `--format=json` 可以让 `gitbook build` 输出解析后的结构化 JSON 数据，而不是渲染好的 HTML。这种格式主要面向二次开发——例如自己实现一套渲染前端、做全文检索、或者把内容迁移到其他文档系统，一般不直接给最终读者使用。

```bash
$ gitbook build ./mybook --format=json --output=./mybook-json
```

## 电子书（PDF / EPUB / MOBI）

生成电子书需要外部工具 **ebook-convert**（来自开源电子书管理软件 [Calibre](https://calibre-ebook.com/)）。GitBook 在内部会调用它完成格式转换，如果没有安装，相关命令会报错。

安装 Calibre 后，需要把 `ebook-convert` 可执行文件加入系统 `PATH`。以 macOS 为例：

```bash
# 将 Calibre 自带的 ebook-convert 软链到 PATH 中
$ sudo ln -s /Applications/calibre.app/Contents/MacOS/ebook-convert /usr/local/bin
```

依赖就绪后，三种电子书格式的命令完全对称，第一个参数是书籍目录，第二个参数是输出文件路径：

```bash
# 生成 PDF
$ gitbook pdf ./ ./mybook.pdf

# 生成 EPUB
$ gitbook epub ./ ./mybook.epub

# 生成 MOBI（适用于 Kindle）
$ gitbook mobi ./ ./mybook.mobi
```

此外，可以为电子书配置封面：在书籍根目录放置 `cover.jpg`（推荐尺寸 1800×2360），可选再放一张 `cover_small.jpg`（200×262），GitBook 会将其嵌入到所有电子书格式中。

PDF 生成的更多细节见本系列的《Gitbook 输出PDF》一文。

## 格式选择建议

- **在线阅读 / 团队文档站点**：选静态网站，配合 GitHub Pages 等托管，更新和分享最方便。
- **离线分发 / 正式交付**：选 PDF，版式固定、便于打印。
- **电子阅读器**：根据设备选 EPUB（通用）或 MOBI（Kindle）。
- **需要程序化处理内容**：选 JSON，再自行编写渲染或导入逻辑。

## 参考

- [GitBook Legacy 源码仓库（legacy 分支）](https://github.com/GitbookIO/gitbook/tree/legacy)
- [GitBook Legacy 文档](https://github.com/GitbookIO/gitbook/blob/legacy/docs/README.md)
- [Generating eBooks and PDFs（官方文档）](https://github.com/GitbookIO/gitbook/blob/legacy/docs/ebook.md)
- [Calibre 官网](https://calibre-ebook.com/)
- [GitBook 官方平台（新版）](https://www.gitbook.com/)
