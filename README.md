# rd163 · 小智晖的博客

专注前沿技术解构的个人 R&D 研发日志,以极客研究精神沉淀全栈架构资产。

基于 [Hugo](https://gohugo.io/) 静态站点生成器 + [DoIt](https://github.com/HEIGE-PCloud/DoIt) 主题(中文社区最流行的 Hugo 主题 LoveIt 的官方维护分支)搭建。

## 目录结构

```
rd163/
├── config/_default/        # 站点配置(Hugo 多文件结构)
│   ├── hugo.toml           # 主配置(baseURL/语言/主题/时区)
│   ├── hugo.zh-cn.toml     # 中文语言配置
│   ├── params.toml         # 站点参数(主题/页脚/文章页/SEO 等)
│   ├── params.zh-cn.toml   # 中文参数(搜索/首页/社交)
│   ├── menu.zh-cn.toml     # 导航菜单
│   ├── markup.toml         # Markdown 解析与代码高亮
│   ├── permalinks.toml     # 文章永久链接
│   ├── taxonomies.toml     # 分类法(category/tag/series/author)
│   ├── outputs.toml        # 输出格式(HTML/RSS/JSON)
│   └── ...                 # pagination/sitemap/mediaTypes 等
├── archetypes/
│   └── default.md          # 新文章模板(`hugo new` 使用)
├── content/
│   ├── posts/<category>/   # 文章(按分类分子目录,251 篇)
│   └── about.md            # 关于页
├── static/
│   └── imgs/               # 博客图片资源(3377 张)
├── themes/DoIt/            # 主题(git submodule)
└── README.md
```

## 本地预览

依赖 **Hugo extended 版**(本机已安装于 `~/.local/bin/hugo`):

```bash
# 启动本地服务器(默认 http://localhost:1313)
hugo server --bind 0.0.0.0 --port 1313

# 构建静态站点到 public/
hugo --gc
```

## 写新文章

```bash
# 在 posts 下新建文章(会套用 archetypes/default.md 模板)
hugo new content posts/<分类>/<slug>.md
```

文章 front matter 示例:

```toml
+++
title = "文章标题"
date = 2025-07-21
lastmod = 2025-07-21
subtitle = "副标题"
description = "摘要描述"
author = "小智晖"
authors = ["小智晖"]
categories = ["golang"]
tags = ["go", "教程"]
toc = true
draft = false
+++
```

## 文章来源

首批 251 篇文章和个人简介迁移自原 Jekyll 博客 [`vxiaozhi.github.io`](https://github.com/vxiaozhi/vxiaozhi.github.io),迁移脚本逻辑:
- Jekyll front matter(`layout/title/subtitle/date/author/tags`)→ Hugo TOML
- `subtitle` → `description`
- 文章目录路径 `_posts/zh/<category>/` → `categories` 字段
- 本地图片引用(`/imgs/xxx`)保持不变(已迁移至 `static/imgs/`)

## 主题更新

DoIt 以 git submodule 形式引入,更新方式:

```bash
git submodule update --remote themes/DoIt
```
