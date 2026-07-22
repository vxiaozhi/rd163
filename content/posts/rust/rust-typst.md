+++
title = "Typst"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "用 Typst 写简历:从环境配置、模板挑选到内容定制"
description = "Typst 是一款用 Rust 编写的新生代排版工具,定位为现代 LaTeX 替代方案。本文以制作简历为例,介绍 Typst 的编辑环境配置、模板挑选与内容定制的完整流程。"
author = "小智晖"
authors = ["小智晖"]
categories = ["rust"]
tags = ["编程语言", "rust", "typst", "排版", "LaTeX", "简历"]
keywords = ["typst", "typst 教程", "typst 简历", "LaTeX 替代", "Rust 排版", "Tinymist"]
toc = true
draft = false
+++

[Typst](https://github.com/typst/typst) 是一款专门为排版而生的新生代工具，主体用 Rust 编写，采用 Apache-2.0 协议。它完全摒弃了传统排版系统的历史包袱，着眼于现代化的功能与设计，成功克服了 LaTeX 等老牌方案的一些固有的不足。

在实际使用流程上，Typst 和 LaTeX 非常相似，可以归纳为三个步骤:

- 配置 Typst 的编辑环境
- 找一份 Typst 的简历模板
- 填充内容并修改模板

## 配置 Typst 的编辑环境

Typst 的环境配置比 LaTeX 简单非常多，大致有三条路线可选:

- **在线编辑器（Online Editor）**。Typst 官方提供了一个在线编辑器 [typst.app](https://typst.app),供用户免费使用，地位类似于 LaTeX 在线编辑器 [Overleaf](https://www.overleaf.com)。在线编辑器需要通过上传资源和下载文件来交互，对于想本地备份简历的同学来说不算方便，但开箱即用的特点对新手特别友好。

- **All in VS Code**。把全部开发依赖都交给 VS Code 管理，是当下流行的一种开发范式。在 VS Code 中推荐安装两个扩展：一个是 [Tinymist Typst](https://marketplace.visualstudio.com/items?itemName=myriad-dreamin.tinymist)(官方目前推荐的集成语言服务，提供智能提示、补全、实时预览，内置 Typst 编译器);另一个是 [vscode-pdf](https://marketplace.visualstudio.com/items?itemName=tomoki1207.pdf),用来在 VS Code 中直接预览生成的 PDF 文件。

  > 备注：早期社区流行的 Typst LSP 扩展([nvarner/typst-lsp](https://github.com/nvarner/typst-lsp))已于 2024 年 11 月归档停止维护，作者明确建议迁移至 Tinymist，新用户请直接安装 Tinymist。

- **Advanced(高级玩家)**。对于喜欢用顺手编辑器的同学,「编辑器 + 编译器 + PDF 阅读器」分离的组合能提供最大的自由度，并复用已有软件。Typst 的 CLI 编译器可通过官方仓库 [typst/typst](https://github.com/typst/typst) 自行安装配置，具体集成方式（Neovim、Helix、Emacs 等）可参考 Tinymist 的说明文档。

## 找一份 Typst 的简历模板

站在巨人的肩膀上是最便捷的达高方式。制作简历也可以基于网上开源的模板进行修改，从一个布局设计精美的模板开始，填入自己的内容即可。

GitHub 上有两个 awesome 项目收录了大量 Typst 模板:

- [awesome-typst](https://github.com/qjcg/awesome-typst)(英文版，由社区维护，持续更新)
- [Awesome Typst 列表中文版](https://github.com/typst-cn/awesome-typst-cn)(由 Typst 中文社区维护)

使用 Typst 的模板非常简单：最直接的方式是从 GitHub 克隆整个仓库，通过 typst.app 或 VS Code 打开整个文件夹，就能编辑使用了。相比 LaTeX 模板，Typst 不用再安装各种隐藏的宏包——相当于下载了一份 Python 开源代码，却不用安装各种第三方依赖就能直接运行。

## 填充内容并修改模板

在一个优秀的开源模板基础之上，填充内容对用户来说一般不成问题。

但常见的情况是：各种简历模板都是在满足原作者需求的前提下被开发出来的，而他人的需求并不总是契合自己的需求，因此定制化就成了制作简历中不可或缺的一环。

由于 Typst 诞生较晚，没有历史包袱，其原生语法相比 LaTeX 非常简单，语义化程度也很高。比如想在现有简历里增加一个 `Publication` 板块，只需要简单翻阅 [Typst 语法参考文档](https://typst.app/docs/reference/),很快就能摸索出正确的写法。

## 参考

- [Typst 官方仓库（typst/typst）](https://github.com/typst/typst)
- [Typst 在线编辑器 typst.app](https://typst.app)
- [Typst 官方文档与语法参考](https://typst.app/docs/reference/)
- [Tinymist Typst(VS Code 扩展)](https://marketplace.visualstudio.com/items?itemName=myriad-dreamin.tinymist) / [Tinymist 仓库](https://github.com/Myriad-Dreamin/tinymist)
- [awesome-typst(qjcg/awesome-typst)](https://github.com/qjcg/awesome-typst)
- [Awesome Typst 中文版（typst-cn/awesome-typst-cn）](https://github.com/typst-cn/awesome-typst-cn)
