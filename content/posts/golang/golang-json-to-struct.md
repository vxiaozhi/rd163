+++
title = "JSON 转 Go 结构体的几种方案"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "在线工具、CLI、IDE 集成与 struct tag 实践"
description = "汇总将 JSON 自动转换为 Go 结构体的常见方案(在线工具、命令行、IDE 内建功能),并梳理 encoding/json 的 struct tag 关键用法与 Go 1.24 的新特性。"
author = "小智晖"
authors = ["小智晖"]
categories = ["golang"]
tags = ["编程语言", "golang", "json", "struct", "工具"]
keywords = ["golang json 转 struct", "json to go struct", "transform.tools", "mholt json-to-go", "struct tag", "omitempty"]
toc = true
draft = false
+++

在对接 RESTful API 或解析配置文件时，把一段 JSON 示例手工逐字段翻译成 Go 的 `struct` 是一件繁琐且容易出错的事。好在社区已经提供了不少自动化方案，从浏览器里的在线工具，到本地命令行，再到 IDE 内建的转换功能，基本可以覆盖大多数场景。本文梳理几种常用方案，并补充 `encoding/json` 的 struct tag 关键用法，帮助你在不同情境下做出选择。

## 在线转换工具

在线工具的好处是开箱即用，无需安装，适合一次性转换或临时排查。

### transform.tools / JSON-to-Go

[transform.tools/json-to-go](https://transform.tools/json-to-go) 是一个多语言转换平台，作者是 [ritz078](https://github.com/ritz078),对应的开源仓库是 [ritz078/transform](https://github.com/ritz078/transform),截至撰写时约有 9.2k Star，采用 MIT 协议。

它的特点:

- 不仅支持把 JSON 转成 Go `struct`,还能转 TypeScript、Rust(serde)、Zod、ReScript、MobX-State-Tree 等多种目标格式，适合前后端跨语言协作。
- 界面左输入右输出，实时生成代码。
- 支持配置项，如是否生成 `omitempty`、是否将所有字段包成指针、是否使用嵌套结构等。

由于项目本身是 Next.js 应用，你可以一键部署到 Vercel 自用，也可以 fork 后定制。

### mholt 的 JSON-to-Go

[mholt.github.io/json-to-go](https://mholt.github.io/json-to-go/) 由 [Matt Holt](https://github.com/mholt) 维护，仓库地址 [mholt/json-to-go](https://github.com/mholt/json-to-go),约 4.6k Star。Matt Holt 同时也是 Caddy Web Server 的作者。

它的特点:

- 纯前端实现，逻辑非常精简，加载迅速。
- 支持扁平（flatten）、内联（inline）等选项，可生成嵌套或独立命名的子结构体。
- 与同作者的 [curl-to-Go](https://mholt.github.io/curl-to-go/) 是姊妹项目，搭配使用可以快速从 `curl` 命令得到完整的请求代码与类型定义。

很多第三方的转换站点（包括 VS Code 插件）底层都直接复用了这个库，可见其工程质量。

### json2struct.mervine.net

[json2struct.mervine.net](https://json2struct.mervine.net/) 由 [Josh Mervine](https://github.com/jmervine) 维护，仓库 [jmervine/gojson-http](https://github.com/jmervine/gojson-http),约 94 Star，基于更早的 [ChimeraCoder/gojson](https://github.com/ChimeraCoder/gojson) 库。功能相对朴素，适合作为前两个工具的补充对照。

## 命令行与库方案

若需要在脚本、CI 流水线或代码生成流程中批量处理 JSON，命令行工具更合适。

[m-zajac/json2go](https://github.com/m-zajac/json2go) 约 142 Star，同时提供 CLI、Go 库、Web 页面与 VS Code 插件，使用方式灵活:

```bash
go install github.com/m-zajac/json2go/cmd/json2go@latest
echo '{"x":1,"y":2}' | json2go
```

它的设计强调「生成的类型保证能正确反序列化原始输入」,因此对可空字段、缺失键、数组内混合类型等边界情况处理更细致，适合用于多个相似 JSON 样本合并出一个能涵盖全部变体的 `struct`。

## IDE 内建功能：无需第三方工具

如果你使用 JetBrains 系 IDE(GoLand 或带 Go 插件的 IntelliJ IDEA Ultimate),其实已经自带 JSON 转 struct 功能，无需切换到浏览器或安装 CLI。

操作流程:

1. 复制一段 JSON 到剪贴板。
2. 在 Go 文件的空白处执行粘贴(`Ctrl/Cmd + V`)。
3. IDE 会弹出提示「Convert JSON to Go type」,选择 **Yes** 并为新类型命名，即可生成对应的 `struct`。

该功能基于 IntelliJ 的内置解析逻辑，生成后会自动带上基础的 `json:"xxx"` tag，后续可手动调整。

VS Code 用户则可以借助前面提到的 [vsc-json2go](https://marketplace.visualstudio.com/items?itemName=m-zajac.vsc-json2go) 等扩展达到类似效果。

## struct tag:转换之后还要做什么

无论用哪种工具生成的 `struct`,实际接入到工程中通常都需要再调整 struct tag。Go 标准库 [`encoding/json`](https://pkg.go.dev/encoding/json) 通过反射读取字段 tag，语法形如:

```go
type User struct {
    ID    int    `json:"id"`
    Name  string `json:"name,omitempty"`
    Email string `json:"email,omitempty"`
    Token string `json:"-"`               // 始终忽略,不参与序列化
}
```

常见的几个选项:

- **重命名**:`json:"my_name"` 将字段在 JSON 中映射为指定键名。
- **`omitempty`**:当字段为「零值」(布尔 `false`、数值 `0`、空字符串、`nil` 指针/接口、长度为 0 的数组/切片/map)时，在 `Marshal` 输出中省略。
- **`-`**:完全跳过该字段，常用于敏感或仅内部使用的字段。
- **`string`**:把基本类型（整数、浮点数、布尔、字符串）在 JSON 里以引号包裹的字符串表示，常用于「数字过大需以字符串传输」的接口。

### Go 1.24 的 `omitzero`

`omitempty` 在处理 `time.Time`、嵌套结构体等场景时存在局限：零值的 `time.Time` 不会被识别为「空」,因此会序列化成 `"0001-01-01T00:00:00Z"`;嵌套零值结构体也会输出 `{}`。

Go 1.24(2025 年 2 月发布)在 `encoding/json` 中新增了 [`omitzero`](https://pkg.go.dev/encoding/json) 选项:

```go
type Order struct {
    CreatedAt time.Time `json:"created_at,omitzero"`
    Address   Address   `json:"address,omitzero"`
}
```

它的工作方式与 `omitempty` 不同：基于 Go 类型的零值判断，若类型实现了 `IsZero() bool` 方法，则使用该方法的结果。这样可以避免把 `time.Time` 改成 `*time.Time` 这种侵入式写法，也能让自定义类型灵活控制「何为零值」。

`omitempty` 与 `omitzero` 可以组合使用(`json:",omitempty,omitzero"`),任一条件满足即省略字段。

## 选型建议

面对一段未知的 JSON，可以按以下顺序选择工具:

1. **偶发的一次性转换**:直接用 transform.tools 或 mholt 的 JSON-to-Go，两秒出结果，带选项更全。
2. **API 调试与代码生成联动**:在 IDE 里直接粘贴，让 IDE 提示转换，生成的 `struct` 直接落到位。
3. **批量脚本 / 代码生成管线**:用 m-zajac/json2go 的 CLI 或库，结合模板生成完整客户端代码。
4. **跨语言协作**(同时要给前端出 TypeScript 类型):优先用 transform.tools，一次输入多端输出。

转换得到的 `struct` 只是起点，真正接入生产代码时，记得根据字段语义补全 `omitempty`/`omitzero`、按需拆分嵌套结构体，并为安全敏感字段加上 `json:"-"`。

## 参考

- [transform.tools — JSON to Go](https://transform.tools/json-to-go) / [ritz078/transform](https://github.com/ritz078/transform)
- [mholt/json-to-go](https://github.com/mholt/json-to-go) / [在线版本](https://mholt.github.io/json-to-go/)
- [jmervine/gojson-http](https://github.com/jmervine/gojson-http) / [在线版本](https://json2struct.mervine.net/)
- [m-zajac/json2go](https://github.com/m-zajac/json2go)
- [JetBrains Guide — Convert JSON to Go Types](https://www.jetbrains.com/guide/go/tips/json-to-go-struct-type/)
- [Go 标准库 encoding/json 文档](https://pkg.go.dev/encoding/json)
- [Go 1.24 Release Notes](https://go.dev/doc/go1.24)
