+++
title = "VuePress 使用指南"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从实现原理到同类工具横向对比"
description = "介绍 VuePress 静态网站生成器的实现原理、开发与构建流程，并与 Nuxt、VitePress、Docsify/Docute、Hexo、GitBook 等同类工具进行横向对比。"
author = "小智晖"
authors = ["小智晖"]
categories = ["site", "建站"]
tags = ["VuePress", "静态网站生成器", "Markdown", "Vue", "文档"]
keywords = ["VuePress", "静态网站生成器", "VitePress", "Markdown", "Vue", "SSG"]
toc = true
draft = false
+++

本文基于 [VuePress 官方文档](https://vuepress.vuejs.org/zh/) 整理而成。

## 介绍

VuePress 是一个以 Markdown 为中心的静态网站生成器。你可以使用 Markdown 来书写内容（如文档、博客等），然后 VuePress 会帮助你生成一个静态网站来展示它们。

VuePress 诞生的初衷是为了支持 Vue.js 及其子项目的文档需求，不过现在它已经在帮助大量用户构建他们的文档、博客和其他静态网站。

## 实现原理

一个 VuePress 站点本质上是一个由 Vue 和 Vue Router 驱动的单页面应用（SPA）。

路由会根据 Markdown 文件的相对路径自动生成。每个 Markdown 文件都会通过 markdown-it 编译为 HTML，然后将其作为 Vue 组件的模板。因此，你可以在 Markdown 文件中直接使用 Vue 语法，便于嵌入一些动态内容。

在开发过程中，VuePress 会启动一个常规的开发服务器（dev-server），并将站点作为一个常规的 SPA 运行。如果你以前使用过 Vue，那么在使用时会感受到非常熟悉的开发体验。

在构建过程中，VuePress 会为站点创建一个服务端渲染（SSR）的版本，然后通过虚拟访问每一条路径来渲染对应的 HTML。这种做法的灵感来源于 Nuxt 的 `nuxt generate` 命令，以及其他的一些项目，比如 Gatsby。

## 与其它静态网站生成器的对比

### 1. Nuxt

Nuxt 是一套出色的 Vue SSR 框架，VuePress 能做的事情，Nuxt 实际上也同样能够胜任。但 Nuxt 是为构建应用程序而生的，而 VuePress 则更为轻量化，并且专注在以内容为中心的静态网站上。

### 2. VitePress

VitePress 是 VuePress 的"孪生兄弟"，最初同样由 Vue.js 作者 Evan You 创建。如今 VuePress 1.x 已被官方弃用，Vue 团队决定长期专注于 VitePress，而 VuePress 2 则交由 VuePress 社区团队维护。

VitePress 基于 Vite 与 Vue 3 构建，相比 VuePress 更轻、更快，但在灵活性和可配置性上作出了一些让步——它没有 VuePress 那样完整的插件系统，而是通过深度集成 Vite 的插件生态来提供扩展能力。当然，如果你没有进阶的定制化需求，VitePress 已经足够支持你将内容部署到线上。

这个比喻可能不是很恰当，但是你可以把 VuePress 和 VitePress 的关系看作 Laravel 和 Lumen。

### 3. Docsify / Docute

这两个项目同样都是基于 Vue，然而它们都是完全的运行时驱动，因此对 SEO 不够友好。如果你并不关注 SEO，同时也不想安装大量依赖，它们仍然是非常好的选择。

### 4. Hexo

Hexo 曾经驱动着 Vue 2.x 的文档。Hexo 最大的问题在于它的主题系统过于静态，并且过度依赖纯字符串模板，而我们十分希望能够利用 Vue 来处理布局和交互。同时，Hexo 在配置 Markdown 渲染方面的灵活性也不是最佳的。

### 5. GitBook

过去我们的子项目文档一直都在使用 GitBook。GitBook 最大的问题在于当文件很多时，每次编辑后的重新加载时间长得令人无法忍受。它的默认主题导航结构也比较有限制性，并且主题系统也不是 Vue 驱动的。GitBook 背后的团队如今也更专注于将其打造为商业产品，而不是开源工具。

## 参考

- [VuePress 官方文档（中文）](https://vuepress.vuejs.org/zh/)
- [VuePress 2 社区版文档](https://vuepress.github.io/zh/)
- [VitePress 官方文档](https://vitepress.dev/)
