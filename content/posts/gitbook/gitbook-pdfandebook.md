+++
title = "Gitbook 输出PDF"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "使用 gitbook pdf 命令导出 PDF 文件"
description = "介绍 GitBook CLI 导出 PDF 的命令、Calibre ebook-convert 依赖、book.json 配置与常见问题,并梳理 PhantomJS 老方案与 HonKit 等现代替代。"
author = "小智晖"
authors = ["小智晖"]
categories = ["gitbook"]
tags = ["gitbook", "文档工具", "电子书", "PDF"]
keywords = ["gitbook pdf", "gitbook 输出PDF", "ebook-convert", "calibre", "phantomjs", "honkit"]
toc = true
draft = false
+++

GitBook 命令行工具(`gitbook-cli`)支持把 Markdown 写成的书籍导出为 PDF 文件，便于打印、归档或在无网络环境下阅读。本篇整理 PDF 导出的命令、依赖、配置项以及常见问题。

> 说明:GitBook CLI(v3.2.3)已被官方标记为 **Deprecated(弃用)**,GitBook 团队已将重心转向 [gitbook.com](https://www.gitbook.com) 在线平台。CLI 仍可在本地使用，但不再活跃维护。下文内容面向旧版工具链，新项目建议评估其他文档生成工具。

## 基本命令

生成 PDF 的命令格式如下，第一个参数是书籍目录，第二个参数是输出文件路径:

```bash
$ gitbook pdf {book_name} {output.pdf}
```

如果已经在书籍的当前目录，可以使用相对路径:

```bash
$ gitbook pdf . ./book.pdf
```

执行成功后，会在指定路径生成一个 PDF 文件;若不指定输出文件名，默认在当前目录生成 `book.pdf`。

## 依赖:Calibre 与 ebook-convert

GitBook 3.x 内部并不直接渲染 PDF，而是先把书籍内容生成 HTML 中间格式，再调用外部命令 **`ebook-convert`** 完成最终的格式转换。`ebook-convert` 由开源电子书管理软件 [Calibre](https://calibre-ebook.com/) 提供，因此**必须先安装 Calibre** 才能使用 `gitbook pdf`。

如果未安装该依赖，执行时会报错:

```text
Error: "ebook-convert" was not found, install it or specify it in the book.json
```

各平台的安装方式如下:

- **macOS**:从 [calibre-ebook.com/download_mac](https://calibre-ebook.com/download_mac) 下载 `.dmg` 安装。CLI 工具位于 `/Applications/calibre.app/Contents/MacOS/`,需要软链或加入 `PATH`:

  ```bash
  $ sudo ln -s /Applications/calibre.app/Contents/MacOS/ebook-convert /usr/local/bin
  ```

- **Linux**:使用官方安装脚本,`ebook-convert` 会被放到 `/usr/bin/`,默认已在 `PATH` 中:

  ```bash
  $ sudo -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sh /dev/stdin
  ```

- **Windows**:从 [calibre-ebook.com/download_windows](https://calibre-ebook.com/download_windows) 下载安装包,默认安装目录 `C:\Program Files\Calibre2\`,需手动将该路径加入系统 `PATH`。

可以用下面的命令单独验证 `ebook-convert` 是否可用:

```bash
$ ebook-convert --version
```

## 关于老版本的 PhantomJS 方案

在更早的 GitBook 2.x 时代,PDF 渲染曾依赖 [PhantomJS](https://phantomjs.org/)(一个基于 QtWebKit 的无头浏览器),通过单独的 `gitbook-pdf` npm 包安装:

```bash
$ npm install gitbook-pdf -g
```

由于下载 PhantomJS 二进制包较慢,可以到其官网手动下载并按文档安装。**但 PhantomJS 自 2018 年起已宣布 *suspended until further notice*,项目实质上处于归档状态**,这套方案在现代系统上往往会因 SSL、glibc、Node 版本等原因失败,不再推荐使用。GitBook 3.x 已切换到基于 Calibre `ebook-convert` 的方案,不再需要 PhantomJS。

## 在 book.json 中配置 PDF 输出

通过书籍根目录的 `book.json` 可以自定义 PDF 的元信息和样式,常用字段如下:

```json
{
  "title": "我的书",
  "author": "小智晖",
  "pdf": {
    "pageNumbers": true,
    "fontFamily": "Noto Sans CJK SC",
    "fontSize": 12,
    "paperSize": "a4",
    "margin": {
      "top": 60,
      "bottom": 60,
      "left": 50,
      "right": 50
    }
  }
}
```

- `pageNumbers`:是否在页脚显示页码。
- `paperSize`:纸张大小,常用 `a4` 或 `letter`。
- `fontFamily`:字体族。中文字体尤其重要,否则容易出现方框乱码——Linux 上常指定 `Noto Sans CJK SC`、`WenQuanYi Zen Hei` 等。
- `margin`:页边距,单位为像素。

## 配置封面图

在书籍根目录放置 `cover.jpg` 即可为电子书设置封面,推荐尺寸 **1800×2360** 像素;可选再放一张 `cover_small.jpg`(200×262)用于缩略图。封面要求:无边框、书名清晰可见。GitBook 会将同一张封面嵌入到 PDF、EPUB、MOBI 三种格式中。

也可以使用官方的 `autocover` 插件根据书名自动生成简单封面:

```json
{
  "plugins": ["autocover"]
}
```

## 常见问题

**`ebook-convert` 找不到**:确认 Calibre 已安装,且 `ebook-convert` 在 `PATH` 中;用 `ebook-convert --version` 验证。

**中文乱码或方框**:在 `book.json` 的 `pdf.fontFamily` 中显式指定系统中已安装的中文字体;同时确认系统已安装该字体文件。

**Node 版本不兼容**:GitBook legacy(3.2.3)通常需要 Node.js 10/12,在 Node 16+ 上经常因 npm 内部依赖 OpenSSL 1.x 而报错(`ERR_OSSL_EVP_UNSUPPORTED` 等)。建议用 [nvm](https://github.com/nvm-sh/nvm) 切换到旧版本:

```bash
$ nvm install 10
$ nvm use 10
```

**生成过程中 `ebook-convert` 被 SIGSEGV 杀死**:通常是 Calibre 版本与系统库不匹配,升级或降级 Calibre 后重试。

## 现代替代方案

由于 GitBook CLI 已停止维护,新项目可以考虑以下工具:

- **[HonKit](https://github.com/honkit/honkit)**:GitBook Legacy 的社区 fork,命令兼容(`honkit pdf ./ ./book.pdf`),官方 Docker 镜像内置 `ebook-convert` 等依赖,是目前最平滑的迁移路径,支持 Node.js 14+。
- **mdBook + wkhtmltopdf / Puppeteer**:Rust 实现的轻量文档工具,常用于 Rust 官方文档。
- **VitePress / Docusaurus**:现代化的文档站点框架,再配合 Puppeteer 等工具做 PDF 导出。
- **Pandoc + LaTeX**:`pandoc book.md -o book.pdf`,适合纯写作场景。

## 参考

- [GitBook Legacy 源码仓库(legacy 分支)](https://github.com/GitbookIO/gitbook/tree/legacy)
- [Generating eBooks and PDFs(官方文档)](https://github.com/GitbookIO/gitbook/blob/legacy/docs/ebook.md)
- [Calibre 官网](https://calibre-ebook.com/)
- [PhantomJS 官网](https://phantomjs.org/)
- [HonKit 仓库](https://github.com/honkit/honkit)
