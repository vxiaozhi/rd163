+++
title = "SEO-向谷歌提交网站"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "把网址提交给 Google Search Console 以加快收录"
description = "介绍谷歌发现、抓取、处理、索引网页的流程,以及如何通过 Google Search Console 提交网站和站点地图、基础 SEO 技巧与禁止抓取的配置方法。"
author = "小智晖"
authors = ["小智晖"]
categories = ["seo"]
tags = ["seo", "Google Search Console", "索引", "robots.txt", "sitemap"]
keywords = ["谷歌收录", "Google Search Console", "提交网站", "站点地图", "SEO 入门", "robots.txt"]
toc = true
draft = false
+++

## 谷歌是如何找到并索引你的内容的？

Google 官方做过一支科普视频 [《How Search Works》](https://www.youtube.com/watch?v=BNHR6IQJGZs)。

谷歌会通过下面 4 个主要环节来查找并索引你的内容。

小提示：由于谷歌内部算法复杂，下面的流程在一定程度上做了简化。

### 步骤 1. 发现

发现是指谷歌得知你网站存在的过程。谷歌主要从站点地图中找到网站和页面，或者从已知页面中发现反向链接。

### 步骤 2. 抓取

抓取是指 Googlebot（俗称“蜘蛛”）程序访问并下载你页面的过程。

### 步骤 3. 处理

处理是指从抓取到的页面中提取关键信息并准备索引的过程，包括解析 HTML、提取正文与结构化数据等。

### 步骤 4. 索引

索引是指将已抓取页面中处理过的信息添加到搜索索引这座大型数据库中。这是一个由数万亿个网页组成的“数字图书馆”，谷歌就是从中提取搜索结果的。


## 为何提交很重要？

上面四个环节是按顺序进行的。你能做的就是把网站主动提交给谷歌，从而加快流程的第一部分：发现。

就像旅行一样，越早出发，就能越早到达目的地——在这里目的地就是“建立索引”。

除此之外，提交站点地图还有以下几个好处。

### 1. 它告诉谷歌哪些页面很重要

站点地图并不一定包含网站上的每个页面。它只列出重要页面，排除不重要或重复的页面。这有助于避免“因为内容重复而让错误版本的页面被索引”之类的问题。

### 2. 它告诉谷歌哪些页面是新增的

许多 CMS 会在你的站点地图中自动添加新页面，有些还会自动 Ping 通知谷歌。这样就省去了逐个手动提交新页面的时间。

### 3. 它会告诉谷歌有哪些孤岛页面

孤岛页面是指没有被网站上其他页面内链到的页面。除非它们具有来自其他网站已知页面的反向链接，否则谷歌不会通过抓取发现这些页面。提交站点地图可以一定程度上解决此问题，因为孤岛页面通常会包含在站点地图中——大多数 CMS 的页面都会被纳入其中。


## 提交网址

步骤如下：

- 进入 [Google Search Console](https://search.google.com/search-console)，选择“添加资源”。
- Google 会对输入的网址进行所有权验证。支持：HTML 文件上传、HTML 标记、Google Analytics、域名提供商 等多种验证方式，任选一种，按提示操作即可。
- 网站提交完成后，一般几天到几周内 Google 就会开始收录你的网站。你可以在 Google Search Console 中查看网站关键词的排名、搜索展示次数、点击量等数据。

如果想更快地推动单条 URL 的收录，可以在 Search Console 顶部的“网址检查（URL Inspection）”工具里输入该 URL，点击“请求编入索引”。


## SEO 技巧

### 1. 网站结构层次不要太深

### 2. 页面标题要准确

`<title>` 的作用是告诉用户和搜索引擎这个特定网页的主题是什么。网站上的每个页面最好都有唯一的专用标题，这有助于搜索引擎区分该页面与你网站上其他页面的差异。

```html
<title>小智晖的博客 | VXiaoZhi Blog</title>
```

### 3. 准确提炼 description

```html
<meta name="description" content="这里是 小智晖 的个人博客，与你一起发现更大的世界 | 要做一个有 swag 的程序员">
```

### 4. 优化你的图片，使用 alt 属性

### 5. 重要内容不要依赖 JS 动态输出

现代谷歌蜘蛛已经可以执行一部分 JavaScript，但对于关键文本、链接、结构化数据，仍建议直接渲染在 HTML 中，以保证被抓取和索引的稳定性。

### 6. 明智地使用链接 `<a>`

对于站内链接，可以加上 `title` 属性加以说明：

```html
<a href="/feature.html" title="功能" class="nav-link"></a>
```

对于外部链接，如果不想把权重传递过去（例如广告、评论区、不可信站点），可以加上 `rel="nofollow"`。注意：`nofollow` 只是告诉“蜘蛛”不要传递权重、不要把它当作排名信号，并非“爬过去就再也回不来”——蜘蛛依然会沿着链接抓取，只是不计入投票。对于付费或赞助链接，Google 更推荐使用 `rel="sponsored"`；对于用户生成内容（评论、论坛）则推荐 `rel="ugc"`。

```html
<a href="https://www.example.com/page.html" rel="nofollow">example</a>
```


## 禁止抓取

有两种方式可以用来限制 Google 爬虫抓取你的网站内容：

### 1. robots.txt

`robots.txt` 是放在网站根目录下的一个文本文件，用来告诉谷歌可以抓取和不能抓取哪些 URL。

例如，下面的 `robots.txt` 文件阻止了 Googlebot 抓取网站上的所有页面：

```text
User-agent: Googlebot
Disallow: /
```

需要注意：`robots.txt` 只能控制“是否抓取”，不能控制“是否索引”。如果想让某个页面不被索引，应当允许抓取（不被 Disallow），并在页面上使用 `noindex` 标记；否则谷歌看不到页面，也就读不到 `noindex` 指令了。

### 2. 给重要页面设置 noindex

如果页面上带有 `<meta name="robots" content="noindex">` 标记，或响应头中带有 `X-Robots-Tag: noindex`，谷歌就不会把该页面纳入搜索结果。

```html
<meta name="robots" content="noindex">
```

```
X-Robots-Tag: noindex
```


## 参考

- [Google Search Central：抓取与索引官方文档](https://developers.google.com/search/docs/crawling-indexing?hl=zh-cn)
- [Google Search Console 帮助：如何提交站点地图](https://support.google.com/webmasters/answer/183668)
- [Google 搜索运作方式（How Search Works）](https://www.google.com/search/howsearchworks/)
- [The Beginner's Guide to SEO — Moz](https://moz.com/beginners-guide-to-seo)