+++
title = "静态网站生成工具"
date = "2025-03-25"
lastmod = "2025-03-25"
subtitle = "主流静态站点生成器与文档方案横向整理"
description = "整理 Jekyll、Hugo、Hexo、VuePress、Astro、Docusaurus、MkDocs、Sphinx 等主流静态网站生成工具的特点与代表应用案例，并附动态文档方案 docsify 与图床工具。"
author = "小智晖"
authors = ["小智晖"]
categories = ["site", "建站"]
tags = ["site", "静态网站生成器", "Jekyll", "Hugo", "Hexo", "VuePress", "Astro", "Docusaurus"]
keywords = ["静态网站生成器", "SSG", "Hugo", "Jekyll", "VuePress", "Astro", "Docusaurus", "文档工具"]
toc = true
draft = false
+++

下面整理常见的静态网站生成工具（Static Site Generator，SSG）与文档站点方案，记录它们的特点与代表性应用案例，便于横向对比与选型。

## 静态网站生成工具

### 1. Jekyll

Jekyll 是 GitHub Pages 官方支持的静态网站生成工具，基于 Ruby。最大优势是能在 GitHub 上直接编辑 Markdown，提交后由 GitHub 自动完成构建。详情见 [jekyllrb.com](https://jekyllrb.com/)。

### 2. Hugo

Hugo 是基于 Go 语言的静态网站生成工具，以构建速度极快著称。

应用案例：

- Kubernetes 官方文档 <https://github.com/kubernetes/website>（使用 Hugo + Docsy 主题）

### 3. Hexo

Hexo 是基于 Node.js 的博客框架，生成速度快，主题与插件生态丰富。

- 项目地址：<https://github.com/hexojs/hexo>

### 4. Gatsby

Gatsby 是基于 React 的站点框架，支持 SSG、DSG、SSR 等多种渲染方式，可按页选择。

### 5. VuePress

VuePress 是以 Markdown 为中心、由 Vue 驱动的静态网站生成器，常用于文档站点。

- [VuePress 官网](https://vuepress.vuejs.org/)
- [VuePress 中文文档](https://www.vuepress.cn/)
- [应用：codefather](https://github.com/liyupi/codefather)
- [应用：PicGo 文档](https://github.com/PicGo/PicGo-Doc)

### 6. Nuxt.js

Nuxt.js 是基于 Vue 的通用应用框架，支持 SSR 与静态站点生成（`nuxt generate`），可用于文档与博客。

### 7. Docusaurus

Docusaurus 由 Meta（Facebook）维护，专注构建开源项目文档站点，支持版本化文档、博客与国际化。

- 项目地址：<https://github.com/facebook/docusaurus>
- 官网：<https://docusaurus.io/>

应用案例：

- k3s 文档

### 8. Eleventy

Eleventy（11ty）是一款零客户端 JavaScript、模板语言无关的轻量静态站点生成器，基于 Node.js。

### 9. Publii

Publii 是一款跨平台桌面端的静态网站生成工具，适合非技术用户可视化编辑后导出静态站点。

### 10. Primo

Primo 是一款可视化、拖拽式的静态网站构建工具，内置内容管理与部署能力。

### 11. MkDocs

MkDocs 是一款面向项目文档的静态站点生成器，基于 Python，源文件使用 Markdown，单一 YAML 配置文件管理。

- 项目地址：<https://github.com/mkdocs/mkdocs>

### 12. Sphinx

Sphinx 是 Python 生态主流的文档生成工具，源文件使用 reStructuredText（也支持 MyST Markdown），可输出 HTML、PDF（LaTeX）、ePub 等多种格式。

- 官网：<https://www.sphinx-doc.org/en/master/>

应用案例：

- Ray 文档
- Python 官方 API 文档

### 13. GitBook

GitBook 早期为开源 CLI 工具，曾广泛用于开源项目文档。其老版本 CLI 已被官方标记为废弃（legacy），当前 GitBook 主营托管与商业化平台。

- 项目地址：<https://github.com/GitbookIO/gitbook>

### 14. Astro

Astro 是一款面向内容驱动网站（content-driven）的 Web 框架，官方定位为「The web framework for content-driven websites」。可使用 React、Vue、Svelte 等熟悉的框架编写 UI 组件，在构建时将整站渲染为静态 HTML，默认不向浏览器发送多余 JavaScript，从而获得较高的性能。

- 项目地址：<https://github.com/withastro/astro>

应用案例：

- [Higress 官网](https://github.com/higress-group/higress-group.github.io)（基于 Astro + Starlight）
- [潮流周刊](https://github.com/tw93/weekly)

## 动态生成文档网站

与上述「构建期生成静态 HTML」的工具不同，下面这类工具在浏览器端按需渲染 Markdown，无需构建过程。

### docsify

docsify 是一款运行时文档站点生成器，直接由浏览器实时渲染 Markdown，无静态生成的 HTML 文件，部署轻量。

- 项目地址：<https://github.com/docsifyjs/docsify>
- 官网：<https://docsify.js.org/#/zh-cn/>

## 免费开源图床工具

- [PicGo](https://github.com/Molunerfinn/PicGo)：基于 Vue-Cli + Electron 构建的图片上传工具。
- [PicX](https://github.com/XPoet/picx)：基于 GitHub API 开发的图床工具，提供图片上传托管、链接生成与图片工具箱。
- [jsDelivr](https://www.jsdelivr.com/)：面向开源项目的免费 CDN。
- [PicoShare](https://github.com/mtlynch/picoshare)：极简的图片与文件分享服务，便于自托管。

## 参考

- [主流静态站点生成器对比（知乎）](https://zhuanlan.zhihu.com/p/260957368)
- [Astro 官网](https://astro.build/)
- [VuePress 官方文档](https://vuepress.vuejs.org/)
- [Docusaurus 官网](https://docusaurus.io/)
- [Sphinx 官方文档](https://www.sphinx-doc.org/en/master/)
