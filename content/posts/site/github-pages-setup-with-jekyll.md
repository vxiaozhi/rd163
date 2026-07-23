+++
title = "Github Pages + jekyll 搭建个人网站和博客"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "借助 GitHub Pages 默认集成的 Jekyll 零成本搭建个人博客"
description = "介绍如何利用 GitHub Pages 官方支持的 Jekyll 静态站点生成器,从主题选择、目录结构、文章格式到本地预览,搭建属于自己的个人网站与博客。"
author = "小智晖"
authors = ["小智晖"]
categories = ["site"]
tags = ["建站", "GitHub Pages", "Jekyll", "博客"]
keywords = ["GitHub Pages", "Jekyll", "个人博客", "静态网站", "建站"]
toc = true
draft = false
+++

Jekyll 是 GitHub Pages 官方支持的静态网站生成工具，最大的优势在于可以直接在 GitHub 上用 VS Code Online 编辑 Markdown 文件，提交后由 GitHub 自动完成 HTML 的生成与部署。除了 Jekyll，常见的替代方案还有:

- Hugo，参考:<https://github.com/erikluo/erikluo.github.io/tree/main/hugo_blog>
- VuePress，参考:<https://github.com/rd163/wmxiaozhi-articles/tree/main>
- 纯 JS 方案，在浏览器端动态将 Markdown 渲染成 HTML，参考:<https://erikluo.github.io/#/>

如果采用非 Jekyll 方案，需要在站点根目录下新建一个 `.nojekyll` 文件，以告知 GitHub Pages 跳过 Jekyll 处理、原样发布文件。

nojekyll 方案搭建参考:

- [GitHub Pages + jekyll 全面介绍极简搭建个人网站和博客](https://zhuanlan.zhihu.com/p/51240503)

实例参考:

- [Tw93 的个人博客](https://github.com/tw93/tw93.github.io)
- <https://github.com/Huxpro/huxpro.github.io>
- <https://github.com/qiubaiying/qiubaiying.github.io>

## 总结如下

### 设置主题

详细设置步骤及支持的默认主题参考:

- [Adding a theme to your GitHub Pages site using Jekyll](https://docs.github.com/en/pages/setting-up-a-github-pages-site-with-jekyll/adding-a-theme-to-your-github-pages-site-using-jekyll)
- [Supported themes](https://pages.github.com/themes/)

示例 `_config.yml` 如下:

```yaml
title: Minimal theme
logo: /assets/img/logo.png
description: Minimal is a theme for GitHub Pages.
show_downloads: true
google_analytics:
theme: jekyll-theme-minimal
```

> 注意：如果使用了 GitHub 内置主题(即在 `theme` 字段中填写内置主题名称),GitHub 会自动将你仓库的内容与内置主题合并，再编译生成静态网页。

### 站点目录结构

参考:[Jekyll 站点目录结构](https://jekyllrb.com/docs/structure/)

Jekyll 站点的目录结构通常如下，上述主题无一例外也都采用了类似的结构来组织文件:

```text
.
├── _config.yml
├── _data
│   └── members.yml
├── _drafts
│   ├── begin-with-the-crazy-ideas.md
│   └── on-simplicity-in-technology.md
├── _includes
│   ├── footer.html
│   └── header.html
├── _layouts
│   ├── default.html
│   └── post.html
├── _posts  # 这里存放的是你的文章,文件名格式必须为: YEAR-MONTH-DAY-title.MARKUP
│   ├── 2007-10-29-why-every-programmer-should-play-nethack.md
│   └── 2009-04-26-barcamp-boston-4-roundup.md
├── _sass
│   ├── _base.scss
│   └── _layout.scss
├── _site
├── .jekyll-cache
│   └── Jekyll
│       └── Cache
│           └── [...]
├── .jekyll-metadata
└── index.html # 也可以是带合法 front matter 的 index.md
```

其中 `_posts` 目录存放博客正文，文件名必须严格遵循 `YEAR-MONTH-DAY-title.MARKUP` 格式（四位年份-两位月份-两位日期-标题.扩展名）,否则 Jekyll 不会将其识别为文章。

### _layouts 模板配置

通过 `_layouts` 目录可定义页面模板(如 `default.html`、`post.html`),在文章 front matter 中用 `layout:` 字段引用，从而控制不同类型页面的整体渲染结构。

### 目录配置

可在 `_config.yml` 中通过 `defaults`、`include`、`exclude` 等字段统一管理各目录的默认 layout、permalink 与是否参与构建等行为，便于站点规模化后的组织。

### Markdown 格式

每篇文章头部需添加 YAML front matter，示例:

```yaml
---
layout:     post
title:      "Blender 简介"
subtitle:   "Blender 简介"
date:       2025-01-10
author:     "vxiaozhi"
header-img: "imgs/home-bg.jpg"
catalog: true
tags:
    - 3d
    - blender
---
```

### 本地预览

官方推荐的本地预览流程:

1. 执行 `script/bootstrap` 安装必要依赖;
2. 执行 `bundle exec jekyll serve` 启动预览服务;
3. 在浏览器访问 `localhost:4000` 预览效果。

由于 Jekyll 对 Ruby 版本有一定要求，推荐使用 Docker 方式运行，避免本地环境冲突:

```bash
# 建议使用 ruby 镜像,不要用 jekyll 镜像
# docker run -it --rm -p 4000:4000 -v $PWD:/app -w /app jekyll/jekyll bash

# Ruby 的具体使用版本可以在主题的 .github/workflows 目录下的 Action 配置中查看
docker run -it --rm -p 4000:4000 -v "$PWD:/app" -w /app ruby:3.2.0 bash
```

进入容器后执行:

```bash
gem install bundler jekyll
./script/bootstrap
bundle exec jekyll serve --host 0.0.0.0
```

如果使用 `jekyll/jekyll` 镜像，在 Ruby 版本与主题要求不一致时，可能报出类似下面的段错误:

```text
fde67d60000-7fde67d63000 rw-p 00000000 00:00 0
7ffc11a21000-7ffc12220000 rw-p 00000000 00:00 0                          [stack]
7ffc12244000-7ffc12247000 r--p 00000000 00:00 0                          [vvar]
7ffc12247000-7ffc12248000 r-xp 00000000 00:00 0                          [vdso]
ffffffffff600000-ffffffffff601000 r-xp 00000000 00:00 0                  [vsyscall]

/usr/jekyll/bin/bundle: line 34:   299 Aborted                 (core dumped) su-exec jekyll $exe "$@"
```

## 常用插件

- [Simple-Jekyll-Search](https://github.com/christian-fei/Simple-Jekyll-Search):轻量的客户端全文搜索组件。

## Liquid 模板语言技巧

参考:

- [Jekyll 中的配置和模板语法](https://gist.github.com/hellokaton/f88be58ef4ae0f3741bb36ab8daa53c5)

主要特点:

- Liquid 是一种服务器端模板语言，由 Shopify 开发并开源，广泛用于 Jekyll 等场景下的文本处理。
- 它由 **标签（Tags）**、**对象（Objects）** 和 **过滤器（Filters）** 三部分组成，可用来插入变量、循环遍历数据以及执行逻辑运算。
- 标签使用 `{% %}` 包裹，用于控制流程(如 `if`、`for`);对象使用 `{{ }}` 包裹，用于输出变量内容。
- 过滤器以管道符 `|` 表示，用于修改变量的输出格式，并且可以串联多个过滤器完成链式处理。

## 参考链接

- [GitHub Pages 官方文档](https://docs.github.com/en/pages)
- [Jekyll 官方文档](https://jekyllrb.com/docs/)
- [Jekyll 目录结构](https://jekyllrb.com/docs/structure/)
- [Liquid 模板语言文档](https://shopify.github.io/liquid/)
- [GitHub Pages 支持的主题列表](https://pages.github.com/themes/)