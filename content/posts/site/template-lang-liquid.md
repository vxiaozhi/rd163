+++
title = "模板编程语言 Liquid"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Shopify 出品的安全模板语言,语法要点与在 Jekyll 中的应用"
description = "Liquid 是 Shopify 用 Ruby 实现的开源模板语言,本文整理其对象、标签、过滤器三大核心概念,以及在 Jekyll 静态站点中的用法。"
author = "小智晖"
authors = ["小智晖"]
categories = ["site"]
tags = ["建站", "Liquid", "Jekyll", "模板语言", "Shopify"]
keywords = ["Liquid", "模板语言", "Jekyll", "Shopify", "静态站点"]
toc = true
draft = false
+++

Liquid 是一门开源的模板语言（template language）,由 Shopify 创造并用 Ruby 实现。它是 Shopify 主题（theme）的骨骼，负责把店铺后台的动态内容渲染成浏览器看到的 HTML。自 2006 年起，Liquid 就在 Shopify 的生产环境中使用，如今已被大量 Web 应用所采纳，其中最知名的莫过于 GitHub Pages 默认的静态站点生成器 Jekyll。

- [Liquid 官方文档](https://shopify.github.io/liquid/)
- [Shopify/liquid GitHub 仓库](https://github.com/Shopify/liquid)(MIT 协议，Ruby 实现)

## 为什么要有 Liquid

常规模板引擎（如 ERB、Jinja）允许在模板里嵌入任意代码，这给了主题开发者几乎无限的权限，但在「让第三方设计师把主题上传到店铺」这种场景下，这种权限是危险的：一个写崩的循环或一段恶意代码就能拖垮整台服务器。

Liquid 的设计目标之一就是**安全**(safe, non-evaling)。它只暴露一组受控的对象、标签和过滤器，模板里既不能执行任意 Ruby 代码，也不能直接访问数据库。再配合「编译期与渲染期分离、无状态」的实现，它非常适合面向终端用户（customer-facing）的灵活模板场景。

## 三大核心概念

Liquid 模板由三类元素组成，几乎所有语法都围绕它们展开。

### 对象（Objects）

对象负责**输出**。语法是用双花括号包裹变量名:

```liquid
{{ product.title }}
{{ page.title }}
```

渲染时,`{{ ... }}` 里的内容会被替换为变量的值。在 Jekyll 里，常见对象包括 `site`(整站配置和文章列表)、`page`(当前页面元数据)和 `content`(正文 HTML)。

### 标签（Tags）

标签负责**逻辑**。语法是 `{% ... %}`,不会产生直接输出，而是控制流程、定义变量或引入片段。标签按用途分为四类:

| 类别 | 常见标签 |
|------|----------|
| 控制流（Control flow） | `if` / `unless` / `elsif` / `else` / `case` / `when` |
| 迭代（Iteration） | `for` / `cycle` / `tablerow` / `break` / `continue` |
| 模板（Template） | `include` / `render` / `layout` / `section` / `block` |
| 变量（Variable） | `assign` / `capture` / `increment` / `decrement` |

一个典型的条件与循环组合:

```liquid
{% assign greeting = "Hello, Liquid!" %}

{% if site.posts.size > 0 %}
  <ul>
    {% for post in site.posts limit: 5 %}
      <li><a href="{{ post.url }}">{{ post.title }}</a></li>
    {% endfor %}
  </ul>
{% else %}
  <p>{{ greeting }} 暂无文章。</p>
{% endif %}
```

`assign` 用来定义变量,`capture` 则可以把一段渲染结果「捕获」成字符串变量，常用于拼接片段。

### 过滤器（Filters）

过滤器负责**变换**输出，通过管道符 `|` 串联，从左到右依次应用:

```liquid
{{ "liquid" | capitalize }}          <!-- Liquid -->
{{ "hello world" | upcase }}         <!-- HELLO WORLD -->
{{ product.price | times: 1.2 }}     <!-- 数值乘法 -->
{{ tags | join: ", " }}              <!-- 数组合并成字符串 -->
{{ article | date: "%Y-%m-%d" }}     <!-- 日期格式化 -->
```

官方文档列出了 47 个以上的内置过滤器，覆盖字符串、数值、数组、日期等类型，例如 `strip`、`truncate`、`split`、`sort`、`where`、`map`、`default` 等。多个过滤器可以链式调用:`{{ name | strip | upcase | default: "ANONYMOUS" }}`。

## 运算符与真假值

在控制流标签里，可以用以下运算符:

- 比较:`==`、`!=`、`>`、`<`、`>=`、`<=`
- 逻辑:`and`、`or`
- 包含:`contains`(只能判断字符串中是否含子串，或字符串数组中是否含某字符串)

需要特别留意两点：一是 **Liquid 不支持括号**,因此不能像普通编程语言那样改变 `and` / `or` 的优先级，官方文档说明多运算符时是「从右向左」求值;二是除了 `nil` 和 `false` 之外，其他一切(包括 `0`、空字符串、空数组)在条件判断里都被视为真值（truthy）。

## 空白控制

`{% ... %}` 和 `{{ ... }}` 周围的换行和空格默认会被保留，这在生成压缩 HTML 时容易留下多余空白。Liquid 提供了一种语法：在定界符内侧加一个连字符 `-`,即可去掉那一侧的空白。

```liquid
{%- assign x = "1" -%}
```

这一特性在生成 XML、JSON 等对空白敏感的输出时尤其有用。

## 在 Jekyll 中使用 Liquid

Jekyll 把 Liquid 选为默认模板语言。Jekyll 在标准 Liquid 之外，额外注入了一批**站点专用的过滤器和标签**,使得在文章模板里可以方便地处理日期、分组、Markdown 等。几个典型例子:

```liquid
<!-- 把文章日期格式化成 RFC-822,适合 RSS -->
{{ post.date | date_to_rfc822 }}

<!-- 转成 XML Schema 格式 -->
{{ post.date | date_to_xmlschema }}

<!-- 把 Markdown 字符串渲染成 HTML -->
{{ page.excerpt | markdownify }}

<!-- 按某属性分组,例如按年份归档 -->
{% assign entries = site.posts | group_by: "year" %}

<!-- 把数组拼成逗号分隔的句子 -->
{{ page.tags | array_to_sentence_string }}

<!-- 生成站内绝对/相对 URL -->
{{ "/about/" | relative_url }}
{{ "/assets/logo.png" | absolute_url }}
```

此外，Jekyll 还提供了 `slugify`(生成 URL 友好的 slug)、`jsonify`(序列化为 JSON)、`number_of_words`(统计字数)等实用过滤器，以及 `where` / `where_exp` 用于按条件筛选集合。完整列表见 [Jekyll Liquid Filters 文档](https://jekyllrb.com/docs/liquid/filters/) 与 [Jekyll Liquid Tags 文档](https://jekyllrb.com/docs/liquid/tags/)。

## 一点实践建议

- **小而专**:每个布局（layout）和片段（include）只做一件事，用 `{% include %}` / `{% render %}` 复用，避免单文件膨胀。
- **先 `assign` 再用**:复杂表达式先拆成命名变量，既好读也方便调试。
- **警惕真值判断**:别指望 `if arr` 能判断数组是否为空，要写 `if arr.size > 0`。
- **关心版本**:Liquid 主线目前由 Shopify/liquid 维护，使用前对照官方文档确认该版本支持的过滤器和标签。

## 参考

- [Liquid 官方文档](https://shopify.github.io/liquid/)
- [Shopify/liquid GitHub 仓库](https://github.com/Shopify/liquid)
- [Jekyll 官方文档：使用 Liquid](https://jekyllrb.com/docs/liquid/)
- [Jekyll Liquid Filters](https://jekyllrb.com/docs/liquid/filters/)
- [Jekyll Liquid Tags](https://jekyllrb.com/docs/liquid/tags/)
- [Jekyll 高级应用：深入掌握 Liquid 模板语言技巧](https://my.oschina.net/emacs_8901675/blog/17545437)
