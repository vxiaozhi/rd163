+++
title = "Gitbook 简介"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Gitbook 项目的目录结构与 SUMMARY.md / README.md 的作用"
description = "介绍 Gitbook 项目的核心文件 README.md 与 SUMMARY.md,讲解目录初始化、Markdown 编写约定以及 gitbook init 命令的使用方法。"
author = "小智晖"
authors = ["小智晖"]
categories = ["gitbook"]
tags = ["gitbook", "markdown", "文档工具", "summary", "README"]
keywords = ["gitbook", "summary.md", "readme.md", "gitbook init", "目录结构"]
toc = true
draft = false
+++

## 图书项目结构

`README.md` 和 `SUMMARY.md` 是 Gitbook 项目中最核心的两个文件。其中 `README.md` 是 Gitbook 官方规定的**必需文件**,`SUMMARY.md` 虽然是可选的，但几乎是实际项目里不可或缺的"目录骨架"——一本最简单的 Gitbook 至少需要 `README.md`,而只要章节多于一篇，通常都会配上 `SUMMARY.md`。它们在一本书中承担不同的作用。

## README.md 与 SUMMARY 编写

### 使用语法

在 Gitbook 中，所有正文内容都使用 **Markdown** 语法编写(GitBook 默认采用 [GitHub Flavored Markdown](https://guides.github.com/features/mastering-markdown/),同时也支持 AsciiDoc)。

### README.md

`README.md` 是一本书的**前言/简介页**,读者打开书时默认看到的就是它。例如本书的 `README.md`:

```markdown
# Gitbook 使用入门

> GitBook 是一个基于 Node.js 的命令行工具,可使用 Github/Git 和 Markdown 来制作精美的电子书。

本书将简单介绍如何安装、编写、生成、发布一本在线图书。
```

### SUMMARY.md

`SUMMARY.md` 是一本书的**目录结构文件**,GitBook 会根据它生成侧边栏导航，并在 `gitbook init` 时按其中的链接自动创建对应的章节文件。其本质就是一个"列表 + 链接"的 Markdown 文件，例如本书的 `SUMMARY.md`:

```markdown
# Summary

* [Introduction](README.md)
* [基本安装](howtouse/README.md)
    * [Node.js 安装](howtouse/nodejsinstall.md)
    * [Gitbook 安装](howtouse/gitbookinstall.md)
    * [Gitbook 命令行速览](howtouse/gitbookcli.md)
* [图书项目结构](book/README.md)
    * [README.md 与 SUMMARY 编写](book/file.md)
    * [目录初始化](book/prjinit.md)
* [图书输出](output/README.md)
    * [输出为静态网站](output/outfile.md)
    * [输出 PDF](output/pdfandebook.md)
* [发布](publish/README.md)
    * [发布到 Github Pages](publish/gitpages.md)
* [结束](end/README.md)
```

`SUMMARY.md` 的语法规则可以归纳为:

- 顶层列表项表示**章节**(chapter),链接的标题即章节名，链接目标是该章节对应的 Markdown 文件。
- 在父章节下**嵌套一层列表**就会生成**子章节**(subchapter),缩进建议使用 4 个空格。
- 链接路径既可以是单个文件，也可以指向子目录中的文件(如 `howtouse/README.md`)。
- 通过 `---` 分隔线或三级标题(`### Part`),还可以把目录划分为多个"部分"(part),part 本身没有独立页面，只用于分组。

## 目录初始化

当 `SUMMARY.md` 编写完毕后，可以使用 Gitbook 的命令行工具，根据这份目录结构一键生成对应的目录与文件:

```bash
$ gitbook init

$ ls
README.md    SUMMARY.md    book    end    howtouse    output    publish

$ tree
.
├── LICENSE
├── README.md
├── SUMMARY.md
├── book
│   ├── README.md
│   ├── file.md
│   └── prjinit.md
├── howtouse
│   ├── Nodejsinstall.md
│   ├── README.md
│   ├── gitbookcli.md
│   └── gitbookinstall.md
├── output
│   ├── README.md
│   ├── outfile.md
│   └── pdfandebook.md
└── publish
    ├── README.md
    └── gitpages.md
```

可以看到,`gitbook init` 为我们生成了与 `SUMMARY.md` 中链接一一对应的目录与 Markdown 文件;对于已经存在的文件，它不会覆盖，只会补齐缺失的部分。

每个生成的章节目录中都会带有一个 `README.md`,用于作为该章的**章节首页**(即该章的说明与导览)。这也是 GitBook 推荐的组织方式：用 `目录名/README.md` 承载一章的入口，再用同目录下的其他 `.md` 文件展开各小节。

## 参考

- [GitBook Legacy 官方文档 — Pages and Summary](https://github.com/GitbookIO/gitbook/blob/legacy/docs/pages.md)
- [GitBook Legacy 官方文档 — Directory Structure](https://github.com/GitbookIO/gitbook/blob/legacy/docs/structure.md)
- [GitBook Legacy 官方文档 — Setup and Installation](https://github.com/GitbookIO/gitbook/blob/legacy/docs/setup.md)
- [GitbookIO/gitbook-cli — GitHub](https://github.com/GitbookIO/gitbook-cli)
- [GitHub Flavored Markdown 指南](https://guides.github.com/features/mastering-markdown/)