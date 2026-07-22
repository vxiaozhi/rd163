+++
title = "Wagtail 介绍"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "基于 Django 的现代开源 CMS,以 StreamField 重塑结构化内容编辑"
description = "Wagtail 是基于 Python Web 框架 Django 构建的开源内容管理系统,以 StreamField、无头架构和出色的编辑体验著称。本文介绍其核心特性、适用场景与上手方式。"
author = "小智晖"
authors = ["小智晖"]
categories = ["cms"]
tags = ["cms", "wagtail", "django", "python", "streamfield", "headless"]
keywords = ["wagtail", "django cms", "python cms", "streamfield", "headless cms", "开源内容管理"]
toc = true
draft = false
+++

在 Python 的 Web 生态里,Django 已经足够成熟,但要做一套让非技术人员也能顺畅发布内容的网站,通常还需要一个内容管理系统(Content Management System,CMS)。Wagtail 就是这样一个基于 Django 构建的开源 CMS,由英国数字 agency Torchbox 于 2014 年开源,目前由社区维护,被 NASA、Google、Mozilla、MIT、UC Berkeley、NHS 等机构用于生产环境。

## 核心特性

### StreamField:结构化的自由排版

StreamField 是 Wagtail 区别于其它 Django CMS 最具代表性的设计。传统的富文本编辑器(如 TinyMCE、CKEditor)把内容存成一大段 HTML,排版灵活但容易失控;而 StreamField 把页面拆成一个个「块(block)」——例如标题、段落、图片、引用、视频——内容由编辑者像搭积木一样按需组合,底层则保存为结构化的 JSON 数据。

这样做的好处是双向的:

- 对编辑者:界面直观,拖拽排序,可以在同一页面里自由组合组件。
- 对开发者:渲染逻辑由模板控制,品牌一致性、响应式样式不会被破坏,也便于做无头(Headless)输出。

Wagtail 内置了 `CharBlock`、`RichTextBlock`、`ImageBlock`、`StructBlock` 等常用块,并支持嵌套,可以组合出复杂的版式。

### 基于 Django,面向开发者

Wagtail 不是一套封闭的系统,它本身就是 Django 应用。任何在 Django 中能做的事——自定义 Model、接入第三方 package、编写中间件、使用 ORM——在 Wagtail 中同样可以做。熟悉 Django 的开发者上手成本很低,Page 模型本质上就是 Django Model 的扩展。

### 图片与文档管理

Wagtail 内置图片库,底层使用自研的 Willow 库处理图像,支持缩放、裁剪、滤镜等操作,并通过 focal point(焦点)机制在裁剪时保留主体。文档则统一以 Document 模型管理,便于复用。

### 页面树与权限

Wagtail 用「页面树(Page Tree)」组织站点结构,支持拖拽调整层级、调度发布、工作流审核、多用户协作和细粒度权限控制,适合多人维护的大型站点。

### 搜索能力

内置搜索后端抽象,小站点可直接用数据库搜索;数据量增大后可平滑切换到 Elasticsearch 或 Solr,无需改动业务代码。

### 无头(Headless)与多语言

Wagtail 原生提供 REST API(自带 v2 实现,无需额外框架),也可通过第三方包 wagtail-grapple 接入 GraphQL,向前端输出内容,前端可自由选择 React、Vue、Next.js、Astro 等技术栈。多语言方面,官方维护的 Wagtail Localize 提供翻译工作流,可管理多语种内容发布。

## 与其它 CMS 的简单对比

| 维度 | Wagtail | WordPress | Strapi |
| --- | --- | --- | --- |
| 语言/框架 | Python / Django | PHP | Node.js |
| 类型 | 传统 + 无头 | 传统为主,REST/GraphQL 插件 | 原生无头 |
| 内容结构 | StreamField 结构化 | 自定义文章/区块 | 完全自定义 Content Type |
| 适合场景 | 中大型内容站、机构站 | 博客、营销站、电商 | 前后端分离项目 |

选择哪种方案,取决于团队技术栈和内容运营需求。若团队已在 Django 生态,且需要让非技术人员参与内容编辑,Wagtail 是顺理成章的选项。

## 快速上手

Wagtail 的安装非常直接,系统要求 Python 3,并依赖 libjpeg 和 zlib(供 Pillow 使用)。在虚拟环境中执行:

```bash
# 安装 Wagtail
pip install wagtail

# 生成项目骨架
wagtail start mysite

cd mysite
# 安装项目依赖
pip install -r requirements.txt

# 执行数据库迁移
python manage.py migrate

# 创建超级用户
python manage.py createsuperuser

# 启动开发服务器
python manage.py runserver
```

启动后访问 `http://127.0.0.1:8000/admin/` 即可进入管理后台,默认前端页面在 `http://127.0.0.1:8000/`。如果只是想快速体验,也可以克隆官方的 [Bakery Demo](https://github.com/wagtail/bakerydemo) 示例项目,内含一个完整的内容站点和多种 Page 类型示例。

如果是已有 Django 项目要集成 Wagtail,可以参考官方文档的「Integrating Wagtail into a Django project」章节,将 `wagtail`、`wagtail.admin`、`wagtail.documents`、`wagtail.images` 等加入 `INSTALLED_APPS`,并配置 URL 路由与数据库迁移即可。

## 适用场景

- 机构官网、大学门户、政府站点(大量结构化页面、需要审核工作流)
- 新闻与媒体类内容站(强依赖灵活排版与图片管理)
- 文档站、知识库(利用页面树组织层级)
- 需要前后端分离的项目(用 Wagtail 做内容后端,前端自行选型)

## 参考

- [Wagtail 官方网站](https://wagtail.org/)
- [Wagtail 官方文档](https://docs.wagtail.org/)
- [Wagtail GitHub 仓库](https://github.com/wagtail/wagtail)
- [StreamField 主题文档](https://docs.wagtail.org/en/stable/topics/pages.html#streamfield)
- [Wagtail Bakery Demo 示例项目](https://github.com/wagtail/bakerydemo)
- [Wagtail CMS 中文教程(gnu4cn/wagtailCMS-tutorial)](https://github.com/gnu4cn/wagtailCMS-tutorial)
