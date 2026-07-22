+++
title = "Gitbook 输出为静态网站"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "用 gitbook serve 与 gitbook build 构建可部署的静态站点"
description = "介绍 Gitbook Legacy CLI 将 Markdown 书籍构建为静态网站的两种方式:本地预览(gitbook serve)与指定目录输出(gitbook build),并说明默认端口、_book 目录结构与部署注意事项。"
author = "小智晖"
authors = ["小智晖"]
categories = ["gitbook"]
tags = ["gitbook", "静态网站", "文档工具", "cli"]
keywords = ["gitbook", "gitbook 静态网站", "gitbook serve", "gitbook build", "_book", "gitbook 输出"]
toc = true
draft = false
+++

Gitbook Legacy CLI 的默认输出形态是**静态网站**(一组纯 HTML/CSS/JavaScript 文件)。只要本地的 `SUMMARY.md`、`book.json` 与各章节 Markdown 都已就绪，就可以用 CLI 自带的两条命令把它渲染成可以直接放到任意 Web 服务器上的静态站点。本文介绍这两种构建方式:`gitbook serve`(边预览边生成)与 `gitbook build`(只构建、不启动服务)。

> 前置说明：本文面向 Gitbook Legacy CLI(v3.2.x)。GitBook 官方已将旧版 CLI 标记为 **Deprecated(弃用)**,详见仓库 [GitbookIO/gitbook](https://github.com/GitbookIO/gitbook) legacy 分支与 [GitbookIO/gitbook-cli](https://github.com/GitbookIO/gitbook-cli)。若新项目希望沿用同一套工具链，可改用其活跃 fork [HonKit](https://github.com/honkit/honkit),把命令中的 `gitbook` 换成 `honkit` 即可。

## 方式一：本地预览时自动生成

`gitbook serve` 在做两件事——先把整本书构建成静态网站，再启动一个本地 HTTP 服务器对外提供访问。它适合在写作过程中实时查看效果，文件改动会自动触发重新构建并通过 LiveReload 刷新浏览器。

### 基本用法

```bash
$ gitbook serve ./{book_name}
```

`gitbook serve` 默认监听 **4000** 端口对外提供 HTTP 服务，并在 **35729** 端口启动 LiveReload 服务器。35729 是 LiveReload 协议的默认端口，与浏览器扩展或注入的客户端脚本配合，实现保存即刷新。

下面以预览本系列文档所在的书 `gitbook-howtouse` 为例:

```bash
$ gitbook serve gitbook-howtouse

Press CTRL+C to quit ...

Live reload server started on port: 35729
Starting build ...
Successfully built!

Starting server ...
Serving book on http://localhost:4000
```

输出最后一行的 `Serving book on http://localhost:4000` 就是预览地址，在浏览器中打开即可:

![gitbook serve preview](../imgs/gitbook_serve.png)

### 常用参数

`gitbook serve` 支持以下常用选项，可用于修改监听地址、端口与输出目录:

| 选项 | 默认值 | 含义 |
| --- | --- | --- |
| `--port` | `4000` | HTTP 服务器端口 |
| `--lrport` | `35729` | LiveReload 端口 |
| `--host` | `localhost` | 监听主机名 |
| `--output` / `-o` | `_book` | 静态站点输出目录 |

例如，端口被占用时可以临时换一个:

```bash
$ gitbook serve --port 8080
```

### 副产物:_book 目录

执行 `gitbook serve` 之后，书籍项目根目录会多出一个 `_book` 目录，里面就是被渲染出来的静态站点内容——`index.html`、各章节 HTML、GitBook 自带主题的静态资源(`gitbook/` 子目录)、图片目录，以及全文检索使用的 `search_index.json`。换句话说,`gitbook serve` 不仅是在预览，实际上已经完成了一次构建,`_book` 就是它的产物。

需要注意，默认情况下 `_book` 应写入 `.gitignore`,避免把生成物提交到源码仓库。

## 方式二：用 gitbook build 指定输出目录

`gitbook build` 与 `gitbook serve` 共用同一套构建逻辑，区别在于**它只构建、不启动本地服务器**,并且允许通过 `--output`(简写 `-o`)把产物写到任意指定目录。日常交付、CI/CD 流水线、部署到静态托管服务时，通常用这条命令。

### 基本用法

```bash
# 默认输出到当前书籍目录下的 _book/
$ gitbook build

# 指定书籍源目录与输出目录
$ gitbook build ./{book_name} --output=./{outputFolder}
```

下面把书构建到 `/tmp/gitbook`:

```bash
$ gitbook build --output=/tmp/gitbook
Starting build ...
Successfuly built !

$ ls /tmp/gitbook/
howtouse          search_index.json
book              imgs              output
gitbook           index.html        publish
```

可以看到 `gitbook build` 的产物结构与 `gitbook serve` 完全一致，区别只是位置由我们自己决定。

### 常用参数

| 选项 | 含义 |
| --- | --- |
| `--output` / `-o` | 输出目录，默认 `_book` |
| `--format` | 输出格式，默认 `website`,也可设为 `json` 用于二次处理 |
| `--log` | 日志级别:`debug` / `info` / `warn` / `error` |
| `--gitbook` | 强制使用某个 GitBook 版本（由 gitbook-cli 提供） |

## 两种方式怎么选

| 场景 | 推荐命令 |
| --- | --- |
| 写作时实时预览、改完自动刷新 | `gitbook serve` |
| 端口被占用或需要让局域网内其他人访问 | `gitbook serve --port 8080 --host 0.0.0.0` |
| 在 CI 中生成部署产物 | `gitbook build --output=./public` |
| 把站点打包后丢给阅读者或运维 | `gitbook build --output=./dist` 后再 `tar` 打包 |

## 部署到生产环境

无论用哪种方式得到的静态站点，本质上都是一组纯静态文件，可以直接打包发布。常见做法:

- **Nginx / Apache**:把 `_book`(或自定义输出目录)整体上传到服务器，让 Web 服务器把根目录指向它即可。
- **GitHub Pages**:把构建产物推送到仓库的 `gh-pages` 分支或 `docs/` 目录，在仓库设置中开启 Pages。
- **对象存储 + CDN**:上传到 S3、阿里云 OSS、腾讯云 COS 等，配合 CDN 加速分发。

部署时如果希望根路径就是站点根路径，无需额外配置;若部署到子路径(如 `https://example.com/docs/`),则需要在 `book.json` 中通过插件或主题配置调整资源引用的相对路径。

## 小结

- `gitbook serve` = 构建 + 启动本地服务，默认 4000 端口、LiveReload 35729 端口，适合写作预览。
- `gitbook build` = 只构建，可用 `--output` 指定产物目录，适合交付与部署。
- 两种方式的产物结构一致，都是包含 HTML、`gitbook/` 静态资源和 `search_index.json` 的静态站点。
- 部署时把它当成任意静态网站处理即可，目标可以是 Nginx、GitHub Pages 或对象存储。

## 参考

- [GitBook Legacy 源码仓库（legacy 分支）](https://github.com/GitbookIO/gitbook/tree/legacy)
- [GitBook Legacy 文档](https://github.com/GitbookIO/gitbook/blob/legacy/docs/README.md)
- [gitbook-cli 仓库（已停止积极维护）](https://github.com/GitbookIO/gitbook-cli)
- [HonKit —— GitBook Legacy 的活跃 fork](https://github.com/honkit/honkit)
- [GitBook 官方平台（新版 SaaS）](https://www.gitbook.com/)
