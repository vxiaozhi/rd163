+++
title = "GitBook 使用入门"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从安装到发布的开源文档工具链上手指南"
description = "介绍 GitBook Legacy CLI 的概念、安装、目录结构、常用命令与输出格式,帮助你快速搭建一本在线电子书或技术文档。"
author = "小智晖"
authors = ["小智晖"]
categories = ["gitbook"]
tags = ["gitbook", "文档工具", "markdown", "nodejs", "calibre"]
keywords = ["gitbook", "gitbook-cli", "markdown 电子书", "文档生成", "calibre"]
toc = true
draft = false
+++

> GitBook 是一个基于 Node.js 的命令行工具（Command Line Interface, CLI）,可使用 Git/GitHub 和 Markdown 来制作精美的电子书与技术文档。

本文是 GitBook 系列的开篇，面向第一次接触 GitBook 的读者，介绍它的定位、安装方式、目录结构和最常用的命令，帮助你从零搭出一本能在线阅读的电子书。后续章节会分别讲解[项目结构](../gitbook-intro)、[命令行速览](../gitbookcli)与[输出格式](../gitbook-output)。

## 关于 GitBook

GitBook 项目最早由 GitBook 团队开源，核心是一套基于 Markdown(或 AsciiDoc)写作、可以同时输出**静态网站**和**电子书**(PDF / ePub / Mobi)的工具链。它的典型用途包括:

- 编写技术文档与 API 手册
- 整理学习笔记或内部 Wiki
- 出版开源电子书、毕业论文、研究报告

需要注意一个重要事实:**GitBook 公司目前重心已转向其商业 SaaS 平台 [gitbook.com](https://www.gitbook.com),原先开源的 GitBook CLI 工具已被官方标记为 deprecated(弃用)。** 在 `GitbookIO/gitbook` 仓库 `legacy` 分支的 README 顶部，官方明确写道:

> As the efforts of the GitBook team are focused on the GitBook.com platform, the CLI is no longer under active development.

这意味着 CLI 工具本身不再获得新特性，但**仍可在本地正常使用**——大量历史项目、教程和插件生态都基于它构建。本文及后续系列文章介绍的命令均针对这套 legacy CLI(对应 npm 包 `gitbook`,最新版本 `3.2.3`)。如果是全新项目且希望长期维护，也可以考虑文末提到的 HonKit 等社区维护分支。

## 支持的输出格式

GitBook 的一大特点是同一份 Markdown 源文件可以导出多种格式:

| 格式 | 说明 | 依赖 |
| --- | --- | --- |
| 静态站点（Website） | 默认输出，生成 `_book/` 目录，可直接托管在 GitHub Pages、Netlify 等 | 无 |
| PDF | 适合打印或离线分发 | `ebook-convert`(Calibre 提供) |
| ePub / Mobi | 适配 Kindle、Apple Books 等阅读器 | `ebook-convert`(Calibre 提供) |
| 单页 HTML(Page) | 将整本书合并为单个 HTML 文件，常作为转 PDF/eBook 的中间产物 | 无 |
| JSON | 暴露书的结构化数据，便于调试或元数据提取 | 无 |

其中，导出 PDF/ePub/Mobi 需要安装 [Calibre](https://calibre-ebook.com/download),并确保其自带的 `ebook-convert` 命令在系统 `PATH` 中。各平台安装方式:

```bash
# Debian / Ubuntu
sudo apt-get install -y calibre

# macOS
brew install --cask calibre

# 验证
ebook-convert --version
```

## 环境准备与安装

GitBook CLI 是一个 Node.js 工具，先确保系统中已安装 Node.js(官方文档建议 v4.0 及以上，实测在 Node.js 10/12 上最为稳定;Node 16+ 上偶有依赖报错，需要时可借助 [nvm](https://github.com/nvm-sh/nvm) 切换版本):

```bash
node --version
npm --version
```

随后通过 npm 全局安装 `gitbook-cli`:

```bash
npm install -g gitbook-cli
```

`gitbook-cli` 本身只是一个"版本管理器",首次执行命令时会**自动下载**所需版本的 `gitbook` 核心。验证安装:

```bash
gitbook --version
```

如果显示类似 `CLI version: 2.3.2 / GitBook version: 3.2.3` 的输出，即安装成功。

## 五分钟创建第一本书

### 1. 初始化项目

在空目录中执行:

```bash
gitbook init ./mybook
cd mybook
```

`init` 会根据 `SUMMARY.md` 中描述的章节自动创建对应的目录与 Markdown 文件。若目录中没有 `SUMMARY.md`,它会先生成一个最小模板:

```
.
├── README.md      # 前言/简介(必需)
├── SUMMARY.md     # 目录结构(可选但强烈建议)
└── book.json      # 配置文件(可选)
```

### 2. 编写目录（SUMMARY.md）

`SUMMARY.md` 是 GitBook 的"骨架",决定了书的章节层级。一个简单的示例:

```markdown
# Summary

* [Introduction](README.md)
* [基本安装](howtouse/README.md)
    * [Node.js 安装](howtouse/nodejsinstall.md)
    * [GitBook 安装](howtouse/gitbookinstall.md)
* [图书输出](output/README.md)
    * [输出为静态网站](output/outfile.md)
    * [输出 PDF](output/pdfandebook.md)
```

写好 `SUMMARY.md` 后再次运行 `gitbook init`,GitBook 会补齐所有缺失的章节文件，无需手动逐个创建。

### 3. 本地预览

```bash
gitbook serve
```

该命令会先 `build` 一次，再启动一个本地 HTTP 服务，默认监听 `http://localhost:4000`,修改源文件后浏览器会自动刷新。

### 4. 构建静态站点

```bash
gitbook build
```

默认把构建产物输出到当前目录的 `_book/` 文件夹;若要指定输出目录:

```bash
gitbook build ./mybook --output=./public
```

`_book/` 里的文件可以直接拖到 GitHub Pages、Nginx 或任何静态托管服务上发布。

## 常用命令速查

除上述命令外,`gitbook-cli` 还提供以下子命令:

```text
build     [source_dir]                 构建一本书
serve     [source_dir]                 构建并启动本地预览
install   [source_dir]                 安装 book.json 中声明的插件
pdf       [source_dir] [output_file]   导出 PDF
epub      [source_dir] [output_file]   导出 ePub
mobi      [source_dir] [output_file]   导出 Mobi
init      [source_dir]                 根据 SUMMARY.md 创建文件
fetch     <version>                    下载并安装指定版本的 GitBook
ls                                     列出本地已安装的版本
ls-remote                              列出远程可用版本
uninstall <version>                    卸载某个版本
```

遇到难以理解的报错时，加上 `--log=debug --debug` 可以打印完整堆栈，便于定位问题:

```bash
gitbook build ./ --log=debug --debug
```

完整命令选项可通过 `gitbook -h` 或 `gitbook <command> -h` 查看。

## 项目地址与状态

- GitBook 官网（商业 SaaS 平台）:<https://www.gitbook.com>
- GitHub 仓库:<https://github.com/GitbookIO/gitbook>
- Legacy CLI 仓库:<https://github.com/GitbookIO/gitbook-cli>(与核心 CLI 是两个仓库)
- npm 包 [`gitbook`](https://www.npmjs.com/package/gitbook):最新稳定版 `3.2.3`(已标记 unsupported，但仍可安装使用)
- npm 包 [`gitbook-cli`](https://www.npmjs.com/package/gitbook-cli):最新版 `2.3.2`

## 关于 HonKit:仍在维护的 Fork

由于官方 CLI 不再更新，社区在原代码基础上分叉出了 [HonKit](https://github.com/honkit/honkit)。它延续了 GitBook 的目录结构、Markdown 语法与绝大多数插件兼容性，并补齐了对新版 Node.js(14+)的支持，内置文件缓存、用 TypeScript 重写、以 monorepo 组织。迁移成本很低——对于新项目，推荐优先评估 HonKit。

## 参考与延伸阅读

- 本系列参考仓库（GitBook 中文教程）:<https://github.com/tonydeng/gitbook-zh/tree/master/gitbook-howtouse>
- 在线阅读版:<https://tonydeng.github.io/gitbook-zh/gitbook-howtouse>
- GitBook Legacy 官方文档（快照）:<https://github.com/GitbookIO/gitbook/tree/legacy/docs>
- Calibre 下载:<https://calibre-ebook.com/download>
- HonKit 文档:<https://github.com/honkit/honkit>
