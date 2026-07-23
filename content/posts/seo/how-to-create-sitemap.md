+++
title = "如何创建 XML 网站地图 (并向 Google 提交)"
date = "2025-01-24"
lastmod = "2025-01-24"
subtitle = "XML 网站地图的格式规范、生成方式与向 Google 提交流程"
description = "介绍网站地图(sitemap.xml / sitemap.txt)的标准格式,以及手动编写、在线工具生成、Jekyll 等静态站点插件生成三种创建方式,最后演示如何通过 Google Search Console 向搜索引擎提交。"
author = "小智晖"
authors = ["小智晖"]
categories = ["seo"]
tags = ["seo", "sitemap", "Google Search Console", "Jekyll"]
keywords = ["sitemap", "网站地图", "XML sitemap", "Google Search Console", "SEO", "Jekyll"]
toc = true
draft = false
+++

网站地图（SiteMap）是一个网站所有链接的容器。很多网站的链接层次比较深，爬虫很难抓取到，网站地图可以方便爬虫抓取网站页面，通过抓取这些页面，清晰了解网站的架构。网站地图一般存放在根目录下并命名为 `sitemap.xml`,为爬虫指路，增加网站重要内容页面的收录。简单来说，网站地图就是根据网站的结构、框架、内容生成的导航网页文件。此外，网站地图对提高用户体验也有好处，它们为网站访问者指明方向，帮助迷失的访问者找到他们想看的页面。

网站地图一般有两种记录方式:XML 格式文件或 TXT 格式文件。两种文件中通常包含该网站的所有链接，可以提交给爬虫去爬取，让搜索引擎更快地收录网站内容。

## sitemap 格式

XML 格式示例,`sitemap.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
   <url>
      <loc>http://www.example.com/</loc>
      <lastmod>2005-01-01</lastmod>
      <changefreq>monthly</changefreq>
      <priority>0.8</priority>
   </url>
   <url>
      <loc>http://www.example.com/catalog?item=12&amp;desc=vacation_hawaii</loc>
      <changefreq>weekly</changefreq>
   </url>
   <url>
      <loc>http://www.example.com/catalog?item=73&amp;desc=vacation_new_zealand</loc>
      <lastmod>2004-12-23</lastmod>
      <changefreq>weekly</changefreq>
   </url>
   <url>
      <loc>http://www.example.com/catalog?item=74&amp;desc=vacation_newfoundland</loc>
      <lastmod>2004-12-23T18:00:15+00:00</lastmod>
      <priority>0.3</priority>
   </url>
   <url>
      <loc>http://www.example.com/catalog?item=83&amp;desc=vacation_usa</loc>
      <lastmod>2004-11-23</lastmod>
   </url>
</urlset>
```

在 XML 格式中,`<loc>` 是必填字段，其余如 `<lastmod>`、`<changefreq>`、`<priority>` 都是可选字段。另外需要注意，XML 中的 URL 必须使用实体转义编码，例如 `&` 需要写作 `&amp;`。

TXT 格式示例,`sitemap.txt`:

```text
http://www.example.com/
http://www.example.com/catalog?item=12&desc=vacation_hawaii
http://www.example.com/catalog?item=73&desc=vacation_new_zealand
http://www.example.com/catalog?item=74&desc=vacation_newfoundland
http://www.example.com/catalog?item=83&desc=vacation_usa
```

TXT 格式每行一个完整的 URL，文件中不再做转义，直接写普通的 `&` 即可。

## 如何创建网站地图

### 方法 1 手动编写

参照上面的 XML 或 TXT 示例，按自己网站的页面手动编写即可。页面较少的小型站点可以采用这种方式。

### 方法 2 使用网站地图生成工具

使用流行的网站地图在线生成工具，例如:

- [xml-sitemaps.com](https://xml-sitemaps.com)
- [web-site-map.com](https://web-site-map.com)
- [xmlsitemapgenerator.org](https://xmlsitemapgenerator.org)
- [xsitemap.com](https://xsitemap.com)

### 方法 3 插件生成

常见的建站框架（如 WordPress、Jekyll）都会提供插件来生成 `sitemap.xml`。其中 WordPress 自 5.5 版本起已内置原生 XML sitemap 功能，无需额外插件即可使用。

以 Jekyll 为例，官方提供了 [Jekyll Sitemap Generator Plugin](https://github.com/jekyll/jekyll-sitemap)。Jekyll Sitemap 安装流程如下:

- Jekyll 版本需不低于 3.5.0，运行 `bundle exec jekyll -v` 查看版本。
- 在站点的 `Gemfile` 中添加 `gem 'jekyll-sitemap'`,然后执行 `bundle` 安装。
- 在站点的 `_config.yml` 中添加如下配置:

```yaml
url: "https://example.com" # 站点的主机名与协议
plugins:
  - jekyll-sitemap
```

- 完成后,`sitemap.xml` 会在网站构建时自动生成，访问 `https://example.com/sitemap.xml` 即可看到。

> 注意：如果使用 GitHub Pages,`jekyll-sitemap` 必须在 `_config.yml` 的 `plugins` 数组中显式声明，仅添加到 Gemfile 是不够的;同时 `_config.yml` 中不能设置 `safe: true`,否则所有插件都会失效。

## 提交 SiteMap 到 Google

首先，你需要知道网站地图的位置。

如果你使用了插件，那么网站地图通常会存放在 `domain.com/sitemap.xml`。

如果你的网站地图是手动生成的，那么请将它命名为类似 `sitemap.xml` 这样的文件名，然后上传到网站根目录。这样你就可以通过 `domain.com/sitemap.xml` 来访问它了。

接着，进入 [Google Search Console](https://search.google.com/search-console) > 左侧菜单「网站地图（Sitemaps）」> 在输入框中粘贴网站地图的地址 > 点击「提交（Submit）」。

## 参考

- [如何创建 XML 网站地图 - Ahrefs](https://ahrefs.com/blog/zh/how-to-create-a-sitemap/)
- [sitemaps.org 协议（官方规范）](https://www.sitemaps.org/protocol.html)
- [Jekyll Sitemap Generator Plugin (GitHub)](https://github.com/jekyll/jekyll-sitemap)
- [Google Search Console 帮助：管理网站地图](https://support.google.com/webmasters/answer/7451001)
