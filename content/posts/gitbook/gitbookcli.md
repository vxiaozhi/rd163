+++
title = "GitBook CLI 命令行速览"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "GitBook 命令行工具的安装、常用命令与配置速查"
description = "整理 GitBook CLI 的安装方法、build/serve/install/pdf 等常用命令、book.json 配置与 SUMMARY.md 目录结构,并说明项目维护现状与常见坑。"
author = "小智晖"
authors = ["小智晖"]
categories = ["gitbook"]
tags = ["gitbook", "cli", "文档工具", "markdown", "nodejs"]
keywords = ["gitbook", "gitbook cli", "gitbook serve", "gitbook build", "book.json", "SUMMARY.md"]
toc = true
draft = false
+++

GitBook CLI 是 GitBook 官方早期提供的命令行工具，可以把一批 Markdown 文件组织成结构化的电子书或文档站点，支持生成静态网站、PDF、EPUB、MOBI 等多种格式。它在前端文档、API 手册、内部知识库等场景曾经非常流行。

需要先说明的是:GitBook 官方目前主推的是托管在 [gitbook.com](https://www.gitbook.com/) 的 SaaS 平台（现已转向 AI 文档方向）,而开源 CLI 工具 `gitbook-cli` [在 GitHub 仓库的 README 中明确标注为已停止维护（Deprecated）](https://github.com/GitbookIO/gitbook-cli)。它仍能用于老项目和离线场景，但新项目建议评估 [HonKit](https://github.com/honkit/honkit)(社区 fork)、[mdBook](https://rust-lang.github.io/mdBook/)、[VitePress](https://vitepress.dev/) 或 [Docusaurus](https://docusaurus.io/) 等替代方案。

## 安装

`gitbook-cli` 是一个 npm 包，通过 Node.js 全局安装:

```bash
$ npm install -g gitbook-cli
```

安装完成后可以查看版本号确认可用:

```bash
$ gitbook --version
```

CLI 内部会按需下载对应版本的 GitBook 内核(默认存放在 `~/.gitbook` 目录)。注意:

- CLI 仅支持 GitBook 内核 `>=2.0.0` 的版本。
- 可以通过 `--gitbook=<version>` 参数强制指定内核版本，例如 `gitbook build ./mybook --gitbook=2.0.1`。
- 也可以通过环境变量 `GITBOOK_DIR` 覆盖默认的内核存储目录。

## 常用命令

GitBook CLI 的核心命令分两类:**书籍构建/服务类** 与 **版本管理类**。

### 构建与本地预览

最常用的是 `serve` 与 `build`,前者在本地起一个带 LiveReload 热重载的预览服务，后者输出一份可部署的静态网站。

```bash
# 在本地 4000 端口预览(默认地址 http://localhost:4000)
$ gitbook serve ./{book_name}

# 输出静态网站到指定目录
$ gitbook build ./{book_name} --output=./{output_folder}
```

`serve` 适合写作时实时查看效果;`build` 生成的是纯静态资源(`_book/` 目录，可用 `--output` 修改),可以直接交给 Nginx、GitHub Pages、对象存储等托管。

### 初始化与插件

```bash
# 根据 SUMMARY.md 自动生成章节文件与目录骨架
$ gitbook init [source_dir]

# 安装 book.json 中声明的插件
$ gitbook install [source_dir]
```

`init` 会读取 `SUMMARY.md` 中引用的章节路径，把缺失的 Markdown 文件补出来，非常省心。`install` 类似 `npm install`,按 `book.json` 中 `plugins` 字段批量安装插件。

### 输出电子书（PDF / EPUB / MOBI）

```bash
$ gitbook pdf ./{book_name} ./book.pdf
$ gitbook epub ./{book_name} ./book.epub
$ gitbook mobi ./{book_name} ./book.mobi
```

这组命令背后依赖 [Calibre](https://calibre-ebook.com/) 提供的 `ebook-convert` 命令行工具，需要先把 Calibre 装好并确保 `ebook-convert` 在系统 `PATH` 中，否则会报错。生成 PDF 时 Calibre 版本与字体配置会影响排版效果。

### 版本管理类命令

```bash
$ gitbook ls               # 列出本地已安装的 GitBook 版本
$ gitbook ls-remote        # 列出 NPM 上可用的远程版本
$ gitbook fetch latest     # 拉取最新版本内核
$ gitbook fetch 2.1.0      # 拉取指定版本
$ gitbook update           # 更新到最新版本
$ gitbook uninstall 2.0.0  # 卸载某个版本
$ gitbook alias <path> <name>  # 把本地某个目录当作指定版本使用
```

### 查看帮助

```bash
$ gitbook -h

  Usage: gitbook [options] [command]

  Commands:

    build [options] [source_dir] Build a gitbook from a directory
    serve [options] [source_dir] Build then serve a gitbook from a directory
    install [options] [source_dir] Install plugins for a book
    pdf [options] [source_dir] Build a gitbook as a PDF
    epub [options] [source_dir] Build a gitbook as a ePub book
    mobi [options] [source_dir] Build a gitbook as a Mobi book
    init [source_dir]      Create files and folders based on contents of SUMMARY.md
    publish [source_dir]   Publish content to the associated gitbook.io book
    git:remote [source_dir] [book_id] Adds a git remote to a book repository

  Options:

    -h, --help     output usage information
    -V, --version  output the version number
```

其中 `publish` 与 `git:remote` 用于把书稿推送到 legacy gitbook.io 托管服务，该服务已不再接受新内容，日常写作基本用不到。

## 两个核心文件

GitBook 的目录结构与配置都靠两个文件驱动。

### `SUMMARY.md`:目录大纲

`SUMMARY.md` 是书的“骨架”,决定章节顺序与层级（缩进表示父子关系）。`gitbook init` 就是根据它来生成对应文件的。示例:

```markdown
# Summary

* [Introduction](README.md)
* [Getting Started](getting-started/README.md)
  * [Installation](getting-started/installation.md)
  * [Usage](getting-started/usage.md)
* [Advanced Topics](advanced/README.md)
```

### `book.json`:项目配置

`book.json` 放在书稿根目录，用来声明元信息、插件、输出选项等。常用字段:

```json
{
  "title": "My Book",
  "author": "Author Name",
  "language": "zh",
  "gitbook": ">=3.0.0",
  "plugins": ["highlight", "search", "-sharing"],
  "pluginsConfig": {
    "theme-default": { "showLevel": true }
  },
  "pdf": {
    "paperSize": "a4",
    "fontSize": 12
  }
}
```

几点说明:

- `plugins` 数组里前缀 `-` 表示禁用默认插件(如 `-sharing` 关闭分享按钮)。
- 修改 `plugins` 后，需要重新执行 `gitbook install`。
- `variables` 中可以放自定义变量，在模板里通过 `{{ book.variables.xxx }}` 引用。

## 常见坑与建议

GitBook CLI 虽然好用，但作为停维项目，在新环境下踩坑概率较高，记录几条实用经验。

**1. Node.js 版本不兼容。** GitBook 3.2.3 内核在 Node.js 12+ 上经常报 `cb.apply is not a function`、`graceful-fs` 之类错误，推荐使用 Node.js v10 LTS 这一档较旧版本，可以通过 [nvm](https://github.com/nvm-sh/nvm) 切换:

```bash
$ nvm install 10
$ nvm use 10
$ npm install -g gitbook-cli
```

**2. 电子书导出失败。** PDF/EPUB/MOBI 报 `You need to install ebook-convert` 时，本质是没装或没找到 Calibre。安装 [Calibre](https://calibre-ebook.com/) 后确认 `ebook-convert --version` 可执行即可。

**3. 想要新特性可以考虑迁移。** 如果项目对现代构建工具链、主题、组件化有要求，直接迁到 HonKit(GitBook 的社区维护分支，API 基本兼容)、VitePress 或 Docusaurus 通常更省心。

## 参考链接

- [gitbook-cli GitHub 仓库（已废弃）](https://github.com/GitbookIO/gitbook-cli)
- [GitBook 官方平台](https://www.gitbook.com/)
- [Calibre 官网](https://calibre-ebook.com/)
- [HonKit 社区维护分支](https://github.com/honkit/honkit)
