+++
title = "Golang 模板"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从 text/template、html/template 到 pongo2、quicktemplate 的用法与选型"
description = "梳理 Go 语言模板引擎:标准库 text/template 与 html/template 的语法、上下文自动转义机制,以及 pongo2、quicktemplate 等第三方方案的特性与性能对比。"
author = "小智晖"
authors = ["小智晖"]
categories = ["golang"]
tags = ["编程语言", "golang", "template", "html/template", "xss"]
keywords = ["golang 模板", "html/template", "text/template", "pongo2", "quicktemplate", "自动转义"]
toc = true
draft = false
+++

模板引擎是 Web 开发里把数据渲染成文本（尤其是 HTML）的基础设施。Go 在标准库里直接提供了 [`text/template`](https://pkg.go.dev/text/template) 与 [`html/template`](https://pkg.go.dev/html/template) 两个包，接口一致但安全模型不同;生态中还有 [`pongo2`](https://github.com/flosch/pongo2)、[`quicktemplate`](https://github.com/valyala/quicktemplate) 等第三方方案。本文记录 Go 模板的标准库用法、最容易踩坑的「自动转义」机制，以及选型时的性能参考。

## 标准库:`text/template` 与 `html/template`

两个包的接口几乎相同，差别在于是否对输出做转义。

- **`text/template`**:生成纯文本,**不做任何转义**,适合邮件、配置文件、代码生成等非 HTML 场景。
- **`html/template`**:为生成 HTML 而设计,**根据上下文自动转义**(contextual auto-escaping),可以抵御 XSS(cross-site scripting)注入。官方明确建议：渲染 HTML 一律使用 `html/template`。

`html/template` 假定「模板作者可信，而传入 `Execute` 的数据不可信」。一旦 `Parse` 成功，得到的模板对象在执行时是注入安全的;若解析失败，返回的错误类型为 `ErrorCode`。

### 基本语法

模板用 `{{` 与 `}}` 作为动作（action）的分隔符，可以通过 `Delims(left, right)` 修改。常用动作包括:

| 动作 | 含义 |
|------|------|
| `{{.}}` | 输出当前「点」(dot，即当前作用域对象)的文本表示 |
| `{{.Field}}` / `{{.Key}}` | 访问结构体字段或 map 键 |
| `{{if pipeline}} T1 {{else}} T0 {{end}}` | 条件渲染;`false`、`0`、`nil`、空集合视为假 |
| `{{range pipeline}} T1 {{end}}` | 遍历 slice / array / map / channel，逐项将 `.` 设为当前元素 |
| `{{with pipeline}} T1 {{end}}` | 当 pipeline 非空时，把 `.` 设为其值并执行 T1 |
| `{{template "name" pipeline}}` | 调用已定义的具名模板，并把 `.` 设为 pipeline 的值 |
| `{{block "name" pipeline}} T1 {{end}}` | 定义一个具名模板并立即执行，支持被覆盖 |
| `{{/* comment */}}` | 注释 |

空白修剪:`{{-` 删除前面的空白,`-}}` 删除后面的空白。例如 `"{{23 -}} < {{- 45}}"` 的输出是 `"23<45"`。

变量用 `$var := pipeline` 声明,`$var = pipeline` 赋值。`range` 还可以同时取下标:`{{range $i, $v := pipeline}} ... {{end}}`。模板之间不会继承变量。

### 管道与内置函数

多个命令可以用 `|` 串成管道（pipeline）,前一个命令的返回值作为后一个命令的最后一个参数。例如 `{{"output" | printf "%q"}}`。

常用内置函数:`and`、`or`、`not`、`call`、`index`、`slice`、`len`、`printf`/`print`/`println`,以及比较函数 `eq`、`ne`、`lt`、`le`、`gt`、`ge`。还可以通过 `template.FuncMap` 注册自定义函数，但必须在 `Parse` 之前调用 `Funcs`。

### 常用 API

```go
import "html/template"

// 解析字符串模板
tmpl, err := template.New("name").Parse(body)
// 从文件解析
tmpl, err := template.ParseFiles("a.html", "b.html")
// 从 io/fs 解析(Go 1.16+)
tmpl, err := template.ParseFS(fsys, "templates/*.html")
// 执行
err = tmpl.Execute(w, data)
err = tmpl.ExecuteTemplate(w, "name", data)
// 失败即 panic,便于初始化
tmpl := template.Must(template.New("name").Parse(body))
```

## 自动转义：最容易踩的坑

`html/template` 在 **parse time(解析期)** 就会根据每个 `{{.}}` 出现的上下文，自动插入对应的转义函数。这是它的核心安全特性，但也是与 `text/template` 行为最不一致、最容易让人困惑的地方。

以官方文档的示例为例，假设传入数据为 `O'Reilly: How are <i>you</i>?`:

| 模板 | 输出 |
|------|------|
| `{{.}}` | `O'Reilly: How are &lt;i&gt;you&lt;/i&gt;?` |
| `<a title='{{.}}'>` | `O&#39;Reilly: How are you?` |
| `<a href="/{{.}}">` | `O&#39;Reilly: How are %3ci%3eyou%3c/i%3e?` |
| `<a onx='f("{{.}}")'>` | `O\x27Reilly: How are \x3ci\x3eyou...?` |

也就是说，同一个变量放在 HTML 正文、属性、URL、JavaScript 里，会得到四种不同的转义结果。

### href 查询参数被「过度转义」

一个典型场景是 `<a href="/search?q={{.}}">`:开发者通常期望 `{{.}}` 按 URL 查询参数编码，但 `html/template` 在解析期会把模板改写为:

```html
<!-- 用户写的 -->
<a href="/search?q={{.}}">"{{.}}"</a>

<!-- html/template 在 parse 时内部改写为 -->
<a href="/search?q={{. | urlescaper | attrescaper}}">{{. | htmlescaper}}</a>
```

结果渲染出来的字符串可能与预期不符（比如多个字符被 HTML 实体化）,StackOverflow 上有[相关讨论](https://stackoverflow.com/questions/44800093/go-rendering-url-rowquery-string-in-a-template-different-behaviours)。要在 URL 上下文里得到「预期」的输出，通常的做法是用 `template.URL` 类型告诉模板「这段已经是可信 URL」,或者在 Go 代码里先 `url.QueryEscape` 后再传给模板。

### 危险协议与 `#ZgotmplZ`

当 URL 上下文里出现 `javascript:`、`vbscript:` 这类危险协议时，模板会把它替换成占位符 `#ZgotmplZ`,从源头阻断通过 URL 触发脚本执行。

### 显式跳过转义:typed strings

如果某段内容确实是可信的（比如来自富文本编辑器并已自行消毒）,可以用以下类型包裹，模板将原样输出、不再转义:

| 类型 | 用途 |
|------|------|
| `template.HTML` | 可信 HTML 片段 |
| `template.HTMLAttr` | 可信 HTML 属性 |
| `template.CSS` | 可信 CSS |
| `template.JS` | 可信 JS 表达式 |
| `template.JSStr` | 可信 JS 字符串 |
| `template.URL` | 可信 URL |
| `template.Srcset` | 可信 srcset(Go 1.10+) |

官方文档明确警告：这些类型一旦被滥用，就等于关掉了 XSS 防线，内容必须来自可信来源。

参考:

- [Go 标准库:`html/template`](https://pkg.go.dev/html/template)
- [Go 标准库:`text/template`](https://pkg.go.dev/text/template)
- [Go 标准库:Go template 用法详解（骏马金龙）](https://www.cnblogs.com/f-ck-need-u/p/10053124.html)
- [Go 标准库：深入剖析 Go template(骏马金龙)](https://www.cnblogs.com/f-ck-need-u/p/10035768.html)

## 第三方方案

### pongo2

[pongo2](https://github.com/flosch/pongo2) 是一个 **Django 语法风格的模板引擎**(Django-syntax like template-engine for Go),对从 Python/Django 转到 Go 的开发者比较友好。

主要特性:

- 语法和特性集与 Django 模板兼容，内置大量 tag 与 filter(如 `for`、`if`、`block`、`extends`、`include`、`autoescape`、`macro`、`now` 等)。
- 支持 C 风格表达式、复杂的函数调用、自定义 filter/tag。
- 支持模板沙盒（sandboxing）,可按目录白名单/黑名单禁用某些 tag 或 filter。
- 支持 macros 与跨文件 import。
- MIT 协议。

需要注意的细节:date/time filter 使用 Go 的 `time` 格式而非 Django 格式;`stringformat` 用的是 Go 的 `fmt.Sprintf` 语法;`forloop` 字段首字母大写(如 `forloop.Counter`)。

选型建议：如果团队熟悉 Django 模板、希望「模板可在服务运行时改动」,pongo2 是一个相对合适的选择;但若团队没有 Django 背景且对性能敏感，标准库或 quicktemplate 通常更直接。

### quicktemplate

[quicktemplate](https://github.com/valyala/quicktemplate) 走的是另一条路线:**把 `.qtpl` 模板在编译期转换成 Go 代码**,再与业务代码一起编译进二进制。

核心思路:

- 用 `qtc` 编译器把模板编译成 `.go` 文件，模板成为程序的一部分,**无需在服务器上分发模板文件**。
- 没有运行时解析、反射,「hot path」零内存分配，据官方 benchmark，比 `html/template` 快 20 倍以上。
- 占位符默认 HTML 转义，JSON 字符串占位符还能防止 `</script>` 类型的 XSS。
- 模板语法贴近 Go，无需学习新语言;支持 `{% code %}` 块直接嵌入 Go 代码。

代价是模板**无法在运行时修改**,更适合模板稳定、对性能要求高的服务。

## 性能对比

[slinso/goTemplateBenchmark](https://github.com/slinso/goTemplateBenchmark) 对常见的 Go 模板引擎做了系统性的 benchmark，结论可以归纳为:

- **代码生成类**(Goh、Hero、Jade、Quicktemplate、Templ 等)在「简单模板」基准下大多能做到零分配、亚微秒级渲染，远超运行时解释执行的引擎。
- **运行时类**中，JetHTML 是最快的全功能引擎;标准库 `html/template` 与 `text/template` 性能居中，但仍是**唯一提供完整「上下文自动转义」**的方案。
- 仓库作者特别提醒:**不要为了追求极致性能而盲目换引擎**,从安全角度看 `html/template` 「开箱即用、够好」;真正有效的优化往往是**把渲染结果缓存起来**,只有在模板无法缓存时，才需要考虑代码生成类引擎。

换句话说，选型时应当先看「安全 / 可维护 / 是否需要运行时改模板」,再看性能。对绝大多数 Web 服务而言，标准库 `html/template` 已经足够;只有当 profiling 显示模板渲染确实是瓶颈、且模板结构稳定时，才值得迁移到 quicktemplate 这类方案。

## 小结

- 渲染 HTML 一律用 `html/template`,它会根据上下文自动转义，是抵御 XSS 的一线防线。
- `text/template` 适合纯文本场景（邮件、配置、代码生成）,不做转义。
- href/URL 查询参数、属性、JS 上下文的自动转义容易让人意外，必要时用 `template.URL` 等 typed string 显式声明可信内容。
- 第三方中，pongo2 适合 Django 语法偏好者;quicktemplate 以编译期生成换取性能，适合模板稳定且对性能敏感的服务。
- 选型优先考虑安全与可维护性，再考虑性能;缓存渲染结果往往比换引擎更划算。
