+++
title = "HTML5 语义化标签"
date = "2025-06-01"
lastmod = "2025-06-01"
subtitle = "article、section、nav、aside、main 的含义与用法"
description = "梳理 HTML5 新增语义化标签 article、section、nav、aside、main 的语义、使用场景与禁忌,并说明引入它们对 SEO 与可访问性的实际意义。"
author = "小智晖"
authors = ["小智晖"]
categories = ["html"]
tags = ["html", "html5", "语义化", "前端", "SEO", "可访问性"]
keywords = ["HTML5 语义化标签", "article", "section", "nav", "aside", "main"]
toc = true
draft = false
+++

## 语义化标签

在 [HTML5] 标准中，新增了若干用于增强页面语义的标签，常见的有 `article`、`section`、`nav`、`aside`、`main` 等。与大多数普通标签不同，浏览器在渲染这些标签时仅仅把它们当作普通的 `div` 块级元素处理，不会添加任何额外的展现逻辑;也就是说，这些标签的作用仅在于增强语义。对 Web 开发者而言，使用这些标签的实际意义主要有两点：搜索引擎优化（SEO）,以及提升页面的可访问性（accessibility）。

在元素分类上,`article`、`section`、`nav`、`aside` 被归为「分节内容」(Sectioning Content)。

### article

`article` 元素用于表示页面上某块具有**一定独立性**的内容，例如一篇文章、论坛上的一个帖子或评论、一篇博客、一个可交互的控件等。`article` 标签可以嵌套使用，嵌套时子 `article` 与父 `article` 在逻辑上必须存在相应的关联。例如，Web 开发者可以将一篇博客的正文与评论区作为父级 `article`,而将其中的每条评论作为子 `article`。

`article` 元素内部不应出现 `main` 元素——`main` 表示页面的主要内容，二者关系是 `article` 作为 `main` 的子元素而存在，而非反过来。

### section

`section` 元素表示页面或 Web 应用中的某一部分，不同的 `section` 之间在「主题」或「基调」上应有所区别，一般通过在 `section` 内放置标题元素(`h1`–`h6`)来定义这个主题。

一般来说,`section` 元素往往多个并排出现，彼此之间存在语义上的并列关系。例如，可以在一个 `article` 内部放置多个 `section`,用于表示文章的不同章节。

把 `section` 当作 `div` 使用是一种误用——除了承担 HTML 页面上可直接呈现的内容之外,`section` 的子元素不应再承担其它角色（纯粹用于样式、脚本或辅助标记等）。

### nav

`nav` 元素主要用于包含页面上的导航链接，因此在 `nav` 中直接包含 `ul` 或 `ol` 列表是一种非常常见的做法。不过 `nav` 中也可以不包含 `ul`/`ol`,例如可以在 `nav` 内放置一个段落(`p` 标签),并在其中嵌入若干链接(`a` 标签)。

与 `article` 一样,`nav` 元素内部不应出现 `main` 元素。

### aside

`aside` 元素一般用于表示页面上的侧边栏内容。但该元素仅在语义上表示「侧边栏」,浏览器在渲染时仍只会将其作为普通的 `div` 块级元素处理。`aside` 所包含的内容不是页面的主要内容，而是具有一定独立性的、对主内容的补充（如相关链接、广告、术语解释等）。如果要真正呈现侧边栏的视觉效果，Web 开发者仍需自行编写 CSS 实现。

### main

`<main>` 标签用于指定文档的主体内容。

`<main>` 标签中的内容在文档中应当是唯一的，不应包含在文档中重复出现的内容，例如侧边栏、导航栏、版权信息、站点标志或搜索表单（除非搜索功能本身是页面的主要目的）。

需要注意，在一个文档中 `<main>` 元素是唯一的，因此不能出现一个以上的 `<main>` 元素。`<main>` 元素也不能作为以下元素的后代:

- `article`
- `aside`
- `footer`
- `header`
- `nav`

## 为什么 HTML5 要引入新语义标签

在 HTML5 出现之前，我们通常采用 DIV + CSS 布局页面。这种布局方式不仅让文档结构不够清晰，也不利于搜索引擎爬虫对页面的抓取。为解决这些缺点，HTML5 新增了大量语义化标签。

## 引入语义化标签的优点

- 比 `<div>` 标签具有更丰富的含义，方便开发与维护;
- 搜索引擎能更方便地识别页面的各个部分，利于 SEO;
- 方便其他设备解析（如移动设备、屏幕阅读器等）,提升可访问性。

## 参考

- [HTML Living Standard — WHATWG](https://html.spec.whatwg.org/multipage/semantics.html)
- [HTML 元素参考 — MDN Web Docs](https://developer.mozilla.org/zh-CN/docs/Web/HTML/Element)
- [\<main\> — MDN Web Docs](https://developer.mozilla.org/zh-CN/docs/Web/HTML/Element/main)
