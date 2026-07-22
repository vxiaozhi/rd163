+++
title = "Gitbook 基本安装"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从 Node.js 环境准备到 Gitbook CLI 的安装与校验"
description = "介绍 Gitbook 旧版命令行工具的安装前置条件、npm 全局安装步骤、版本校验方法,以及在新版 Node.js 下的兼容性注意事项与替代方案。"
author = "小智晖"
authors = ["小智晖"]
categories = ["gitbook"]
tags = ["gitbook", "nodejs", "npm", "cli", "文档工具"]
keywords = ["gitbook", "gitbook-cli", "nodejs", "npm 安装", "文档生成"]
toc = true
draft = false
+++

本文介绍 Gitbook 旧版命令行工具（Legacy CLI）的安装前置条件、安装步骤与版本校验方法，并补充当前在新版 Node.js 环境下的兼容性注意事项。Gitbook 的安装本质上是「准备 Node.js 运行时 → 通过 npm 安装 CLI → 校验版本」三步。

## 前置认知:Legacy CLI 与 GitBook.com 的关系

在动手之前，需要先厘清两个容易混淆的概念:

- **GitBook.com**:GitBook 公司推出的在线 SaaS 文档平台，目前为闭源商业产品，通过浏览器编辑器直接托管内容。
- **Gitbook Legacy CLI(旧版命令行工具)**:基于 Node.js 的开源工具链，使用 Git 和 Markdown 在本地构建电子书与文档站点，可输出 HTML 静态网站、PDF、EPUB、MOBI。

本文及后续几篇文章讨论的「Gitbook」均指后者——即旧版 CLI。需要特别说明的是，GitBook 官方在仓库 [GitbookIO/gitbook](https://github.com/GitbookIO/gitbook) 的 **legacy 分支** README 中已将旧版 CLI 明确标注为 **"Legacy GitBook (Deprecated)"**,CLI 工具([GitbookIO/gitbook-cli](https://github.com/GitbookIO/gitbook-cli))亦声明 **"the CLI is no longer under active development"**(不再积极开发)。其最后一个稳定版本停留在 **3.2.x**,对较新版本的 Node.js 兼容性较差。

> 尽管如此，大量历史项目、内网文档和教程仍基于 Legacy CLI，理解它的安装与使用依然有价值。若新项目希望沿用同一套工具链，建议直接使用其活跃 fork [HonKit](https://github.com/honkit/honkit)。

## Node.js 安装

![Node.js](../imgs/nodejs.png)

> Node.js 是一个基于 Chrome V8 JavaScript 运行时建立的平台，用来方便地搭建快速的、易于扩展的网络应用。
>
> Node.js 借助事件驱动、非阻塞 I/O 模型变得轻量和高效，非常适合运行在分布式设备上、数据密集型的实时应用。

Gitbook CLI 本身是一个 npm 包，因此第一步是准备 Node.js 运行时。

### 版本建议

由于 Legacy CLI 依赖的若干原生模块和旧版依赖链，与 Node.js 16 及以上版本存在兼容性问题(Node 17+ 默认禁用了 OpenSSL 旧算法，会触发 `ERR_OSSL_EVP_UNSUPPORTED` 一类错误)。实务中推荐的版本组合:

| 场景 | 推荐 Node.js 版本 |
| --- | --- |
| 与 Legacy CLI 最佳兼容 | **10.x / 12.x** |
| 必须使用较新 Node 时 | 配合 `NODE_OPTIONS=--openssl-legacy-provider` |
| 转向 HonKit | **14 及以上**(支持当前 LTS) |

截至本文更新时，Node.js 的活跃 LTS 版本为 **24.x (Krypton)**,维护期 LTS 为 **22.x (Jod)**,Current 为 26.x。建议使用 [nvm](https://github.com/nvm-sh/nvm)(Unix/macOS)或 [nvm-windows](https://github.com/coreybutler/nvm-windows)、[fnm](https://github.com/Schniz/fnm) 等版本管理工具在多个 Node 版本之间切换，以兼顾新旧工具链。

### 安装与校验

Node.js 的安装请参考官方下载页 [nodejs.org](https://nodejs.org/en/download) 或社区教程:

[在 Windows、Mac OS X 與 Linux 中安裝 Node.js 網頁應用程式開發環境](http://www.gtwang.org/2013/12/install-node-js-in-windows-mac-os-x-linux.html)

安装完成后，通过下面的命令验证 Node.js 及其包管理器 npm 是否就绪:

```bash
$ node -v
v12.22.12

$ npm -v
6.14.16
```

只要两条命令都能正常输出版本号，说明运行环境已经准备好，可以进入下一步。

## Gitbook CLI 安装

Gitbook CLI 通过 npm 全局安装。最规范的包名是 **`gitbook-cli`**(命令行入口),而不是直接安装 `gitbook` 核心库——CLI 会在首次运行时按需自动下载并管理对应版本的 `gitbook` 核心。

```bash
$ npm install -g gitbook-cli
```

> 原始资料中写作 `npm install gitbook -g`。这在新版 npm 中可能会因为缺少 `-g` 位置或包名差异报错，推荐使用 `npm install -g gitbook-cli` 的写法。

安装完成后，用下面的命令校验:

```bash
$ gitbook -V
CLI version: 2.3.2
GitBook version: 3.2.3
```

`gitbook -V`(大写 V)会同时输出 CLI 自身版本和当前使用的 GitBook 核心版本。看到类似输出即代表安装成功;首次执行时 CLI 会从远程拉取默认的 GitBook 核心版本到本地缓存目录 `~/.gitbook`,可以通过环境变量 `GITBOOK_DIR` 修改该缓存路径。

## 常用命令速览

安装完成后，以下命令构成了 Gitbook 的日常工作流(完整列表可执行 `gitbook -h` 查看):

| 命令 | 作用 |
| --- | --- |
| `gitbook init` | 根据 `SUMMARY.md` 自动生成章节目录与文件 |
| `gitbook install` | 安装 `book.json` 中声明的插件 |
| `gitbook serve [source]` | 构建并在本地起服务预览(默认 `http://localhost:4000`) |
| `gitbook build [source] [output]` | 构建为静态网站 |
| `gitbook pdf` / `epub` / `mobi` | 输出电子书(需额外安装 `calibre` 的 `ebook-convert`) |
| `gitbook ls` / `ls-remote` | 列出本地/远程可用 GitBook 版本 |
| `gitbook fetch 3.2.3` | 安装指定版本 |
| `gitbook update` / `uninstall` | 更新或卸载版本 |

需要注意的是，CLI 只管理 `>= 2.0.0` 的 GitBook 版本。

## 通过 book.json 声明插件

Gitbook 的扩展能力依赖插件机制。在书籍根目录创建 `book.json`,声明所需插件后再执行 `gitbook install`,CLI 会读取配置并自动从 npm 拉取对应的 `gitbook-plugin-*` 包:

```json
{
  "plugins": [
    "search",
    "sharing",
    "fontsettings",
    "theme-default",
    "copy-code-button",
    "alerts"
  ],
  "pluginsConfig": {
    "theme-default": {
      "showLevel": true
    }
  }
}
```

插件命名遵循 `gitbook-plugin-<name>` 约定，在 `plugins` 数组里只需写 `<name>` 部分。也可以直接用 npm 安装:`npm install gitbook-plugin-copy-code-button --save`。

## 常见问题

**安装或运行时报 `cb.apply is not a function`** 通常是 Node.js 版本过新导致的依赖不兼容，降到 Node 10–12 即可解决。

**构建时出现 `ERR_OSSL_EVP_UNSUPPORTED`** 是 Node 17+ 默认禁用了旧 OpenSSL 算法，临时方案是设置环境变量:

```bash
export NODE_OPTIONS=--openssl-legacy-provider
```

**`gitbook install` 卡住或失败** 多见于网络问题或 npm registry 不可达，可尝试切换镜像源(`npm config set registry https://registry.npmmirror.com`)。

## 现代替代方案

由于 Legacy CLI 已经停止维护，且与新版 Node.js 兼容性持续恶化，新项目建议考虑以下工具:

- **[HonKit](https://github.com/honkit/honkit)**:Legacy GitBook 的活跃 fork,TypeScript 重写，兼容绝大多数 `gitbook-plugin-*` 插件，迁移成本最低，要求 Node.js 14+。
- **[mdBook](https://github.com/rust-lang/mdBook)**:Rust 实现，零运行时依赖，构建极快。
- **[Docusaurus](https://docusaurus.io/)**:React 驱动，适合大型产品文档站。
- **[VitePress](https://vitepress.dev/)** / **[VuePress](https://vuepress.vuejs.org/)**:Vue 生态，配置简单，主题丰富。

选择时主要看团队技术栈、对旧 GitBook 插件的依赖程度以及输出格式需求。

## 小结

- Gitbook Legacy CLI 的安装分两步：先准备 Node.js 运行时（推荐 10.x / 12.x）,再执行 `npm install -g gitbook-cli`。
- 用 `gitbook -V` 同时校验 CLI 与核心版本;日常命令围绕 `init` / `install` / `serve` / `build` 展开。
- 由于官方已将该工具链标记为 Deprecated，新项目应优先考虑 HonKit 或 mdBook 等现代替代方案。

## 参考

- [GitbookIO/gitbook — GitHub](https://github.com/GitbookIO/gitbook)(Legacy Deprecated 分支)
- [GitbookIO/gitbook-cli — GitHub](https://github.com/GitbookIO/gitbook-cli)
- [HonKit — GitBook Legacy 的活跃 fork](https://github.com/honkit/honkit)
- [Node.js Release Schedule](https://github.com/nodejs/release)
- [nvm — Node Version Manager](https://github.com/nvm-sh/nvm)
