+++
title = "Open Graph Protocol（开放图谱协议）"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "让网页在社交分享中呈现富媒体预览的 Meta 标签协议"
description = "Open Graph Protocol 是 Facebook 提出的网页元信息标记协议，通过 og:title、og:type、og:image、og:url 等标签让网页在社交平台中获得富媒体卡片预览。本文梳理其核心属性、对象类型与实战要点。"
author = "小智晖"
authors = ["小智晖"]
categories = ["http"]
tags = ["http", "open-graph", "meta", "seo", "html", "社交分享"]
keywords = ["Open Graph", "OG 协议", "og:title", "og:image", "社交分享", "Meta 标签"]
toc = true
draft = false
+++

## 简介

Open Graph Protocol（开放图谱协议），简称 **OG 协议**，是一种网页元信息（Meta Information）标记协议，属于 Meta Tag（Meta 标签）范畴。它最早由 Facebook 在 2010 年的 F8 开发者大会上公布，目标是**为社交分享而生**：通过一组 `<meta>` 标签标准化网页的元数据使用，让社交媒体平台能够以丰富的"图形对象（Graph Object）"形式来表示被分享的页面内容，使其他网站的内容也能像平台原生内容一样被呈现，进而促进站点与社交平台之间的集成。

简而言之，OG 协议就是用来**标注页面类型并描述页面内容**的一套约定。它的设计灵感来自 Dublin Core、`link-rel canonical`、Microformats 和 RDFa。这些技术各有侧重，可以组合使用，但单独任何一种都无法提供足够的信息来"丰富地表示社交图中任意一个网页"。OG 协议建立在这些已有技术之上，以**开发人员使用的简单性**为关键目标，给出了一套可落地的实施方案。

## 基本用法

OG 协议的核心载体是放在 HTML `<head>` 内的 `<meta property="..." content="...">` 标签。为了让命名空间（namespace）合法生效，通常在 `<html>` 根节点声明 `prefix`：

```html
<html prefix="og: https://ogp.me/ns#">
<head>
  <meta property="og:title" content="The Rock" />
  <meta property="og:type" content="video.movie" />
  <meta property="og:url" content="https://www.imdb.com/title/tt0117500/" />
  <meta property="og:image" content="https://ia.media-imdb.com/images/rock.jpg" />
</head>
</html>
```

注意属性名使用的是 `property`（而非通用的 `name`），这是 RDFa 风格的写法。

## 四个必填属性

每个页面至少需要以下四个基本属性，才能构成一个有效的图对象：

| 属性 | 含义 |
| --- | --- |
| `og:title` | 对象在图中的标题 |
| `og:type` | 对象类型，如 `website`、`article`、`video.movie` |
| `og:image` | 代表该对象的图片 URL |
| `og:url` | 该对象的规范化 URL（canonical），将作为它在图中的永久 ID |

`og:type` 的取值决定了该对象可以附加哪些专属属性（见下文"对象类型"）。

## 常用可选属性

在四个必填项之外，常用的可选属性包括：

- `og:audio` —— 音频资源 URL
- `og:description` —— 一两句话的简要描述
- `og:determiner` —— 标题前的冠词，枚举值为 `a`、`an`、`the`、`""`、`auto`
- `og:locale` —— 语言区域，默认 `en_US`
- `og:locale:alternate` —— 其他可选语言区域（数组）
- `og:site_name` —— 站点名称
- `og:video` —— 视频 URL

示例：

```html
<meta property="og:audio" content="https://example.com/bond/theme.mp3" />
<meta property="og:description" content="Sean Connery found fame and fortune as James Bond." />
<meta property="og:site_name" content="IMDb" />
<meta property="og:video" content="https://example.com/bond/trailer.swf" />
```

## 结构化属性

部分属性支持以**冒号分隔的后缀**附加额外元数据。`og:image` 是最常用的结构化属性，可拆出 `url`、`secure_url`、`type`、`width`、`height`、`alt`：

```html
<meta property="og:image" content="http://example.com/ogp.jpg" />
<meta property="og:image:secure_url" content="https://secure.example.com/ogp.jpg" />
<meta property="og:image:type" content="image/jpeg" />
<meta property="og:image:width" content="400" />
<meta property="og:image:height" content="300" />
<meta property="og:image:alt" content="A shiny red apple with a bite taken out" />
```

显式给出 `width` 与 `height` 能让爬虫在不下载完整图片的情况下完成布局计算，**显著加快社交平台的卡片渲染速度**，建议生产环境尽量填写。

## 数组（多个值）

如果一个属性有多个值（如多张缩略图），可以通过**重复同名的 `<meta>` 标签**来表达。冲突时以自上而下第一个标签为准，结构化子属性则归属于它紧随其后的根标签：

```html
<meta property="og:image" content="https://example.com/rock.jpg" />
<meta property="og:image:width" content="300" />
<meta property="og:image:height" content="300" />
<meta property="og:image" content="https://example.com/rock2.jpg" />
<meta property="og:image" content="https://example.com/rock3.jpg" />
<meta property="og:image:height" content="1000" />
```

上例声明了三张图：第一张 300×300，第二张尺寸未指定，第三张高度 1000px。

## 对象类型（Object Types）

`og:type` 的取值分为若干"垂直（vertical）"分组，每组带独立的命名空间：

- **Music**（`music#`）：`music.song`、`music.album`、`music.playlist`、`music.radio_station`
- **Video**（`video#`）：`video.movie`、`video.episode`、`video.tv_show`、`video.other`
- **无垂直（全局）**：
  - `article`（`article#`）—— 支持 `article:published_time`、`article:modified_time`、`article:author`、`article:section`、`article:tag` 等
  - `book`（`book#`）—— 支持 `book:author`、`book:isbn`、`book:release_date` 等
  - `profile`（`profile#`）—— 支持 `profile:first_name`、`profile:last_name`、`profile:username`、`profile:gender`
  - `website`（`website#`）—— 通用站点类型，无额外专属属性

任何未显式标注的普通网页，默认即视为 `og:type = website`。博客类站点写文章详情页时常用 `article`，配合 `article:published_time` 等标签可获得更精准的预览。

## 数据类型

OG 协议定义了几种基础数据类型，便于消费方正确解析：

| 类型 | 说明 |
| --- | --- |
| Boolean | `true` / `false` / `1` / `0` |
| DateTime | ISO 8601 格式 |
| Enum | 受限字符串集合 |
| Float | 64 位有符号浮点 |
| Integer | 32 位有符号整数 |
| String | 无转义字符的 Unicode 字符串 |
| URL | 合法的 `http://` 或 `https://` 地址 |

## 实战要点

**1. 图片尺寸与体积。** 各社交平台对 `og:image` 的推荐尺寸略有不同，业界事实标准约为 **1200×630** 像素（1.91:1），单图小于 8 MB。尺寸不足或比例过宽时，平台可能裁剪或退化为纯文本预览。

**2. URL 使用绝对路径。** `og:image`、`og:url` 必须是可被公网爬虫访问的绝对 URL，且推荐 `https://`。相对路径在多数平台无法解析。

**3. 与 Twitter Cards 共存。** Twitter/X 的 `twitter:*` 卡片标签在缺失时会**回退到对应的 `og:*` 标签**，因此很多站点只在 OG 之上额外补一条 `twitter:card` 即可获得富卡片效果：

```html
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:site" content="@your_handle" />
```

**4. 缓存问题。** 平台抓取后会缓存预览，调整了 OG 标签却看不到效果时，通常需要用**带版本号的查询参数**（如 `?v=2`）强制重新抓取，或使用调试工具手动刷新缓存。

**5. 在 Hugo 中配置。** Hugo 内置模板默认会生成 `og:title`、`og:description`、`og:image` 等标签。在文章 front matter 中填好 `title`、`description` 与 `images` 字段，即可自动渲染。DoIt 等主题在此基础上扩展了更多社交属性。

## 常用调试工具

- [Facebook Sharing Debugger](https://developers.facebook.com/tools/debug/) —— Facebook 官方的 OG 调试器，可预览分享卡片并查看抓取到的原始标签
- [OpenGraph.xyz](https://www.opengraph.xyz/) —— 第三方 OG/Twitter 卡片预览，支持多平台对照
- [MetaTags.io](https://metatags.io/) —— 可视化预览与编辑，便于在发布前快速核对

> 说明：Twitter 原本的官方 [Card Validator](https://cards-dev.twitter.com/validator) 在 X 品牌更迭后已基本停用，可改用上述通用 OG 调试工具间接验证。

## 小结

Open Graph Protocol 用极其轻量的一组 `<meta>` 标签解决了"网页被分享时如何呈现"的问题。对博客和内容站点而言，写好四个必填属性、补齐 `og:image` 的 `width`/`height` 结构化子属性，再按需追加 `article:*` 或 `twitter:card`，就能覆盖绝大多数社交分享场景。配置完成后，记得用调试工具抓一次以确认缓存与渲染符合预期。

## 参考

- [The Open Graph Protocol 官方规范（ogp.me）](https://ogp.me/)
- [前端应该知道的：开放图谱协议（The Open Graph protocol）](https://segmentfault.com/a/1190000040863000)
- [Facebook Sharing Debugger](https://developers.facebook.com/tools/debug/)
- [OpenGraph.xyz 预览工具](https://www.opengraph.xyz/)
