+++
title = "Webpack 入门教程"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从属概念到配置示例,理解这款老牌前端打包工具"
description = "Webpack 是前端工程化的奠基性打包工具,本文整理其核心概念、配置要点与上手资源。"
author = "小智晖"
authors = ["小智晖"]
categories = ["web"]
tags = ["web", "webpack", "前端工程化", "打包工具"]
keywords = ["webpack", "前端打包", "loader", "plugin", "前端工程化"]
toc = true
draft = false
+++

Webpack 是一款用于现代 JavaScript 应用的**静态模块打包器**(static module bundler)。它从一个或多个入口出发，递归地构建出整个应用的依赖关系图（dependency graph）,然后把每个模块组合成一个或多个 bundle(产物包)。尽管近两年 Vite、Turbopack、Rspack 等基于原生 ESM 或 Rust 的新工具快速崛起，Webpack 依然是大量线上项目和企业脚手架的主流选择，理解它的概念模型对前端工程化仍然必不可少。

## 一份经典的入门资料

关于 Webpack 的中文入门资料，最有名的莫过于阮一峰在 GitHub 上维护的 Webpack 示例集合:

- [webpack-demos](https://github.com/ruanyf/webpack-demos):仓库简介就一句 "a collection of simple demos of Webpack",通过 15 个由浅入深的小 demo，串起了从入口文件、多入口、Babel-loader、CSS-loader、Image loader、CSS Module、UglifyJs 压缩、HTML Webpack Plugin、环境变量、代码分割（CommonsChunkPlugin / bundle-loader）、Vendor chunk、externals 到 React Router 的完整脉络。

由于原仓库为英文，社区也有人将其翻译成了中文版本:

- [webpack-demos-cn](https://github.com/userkang/webpack-demos-cn)

此外，CSDN、博客园、掘金上也有大量对该仓库的解读文章。例如博客园上的转载:

- [阮一峰 Webpack 教程](https://www.cnblogs.com/luckyting/articles/11278171.html)

需要注意的是，这套 demo 最初是针对 **Webpack 1.x** 编写的，其中用到的 `require.ensure`、`CommonsChunkPlugin`、`module.loaders` 等语法在新版本中已经被废弃或替换。把它当作"概念导览"看非常合适，但配置 API 还请以官方文档为准。

## 核心概念

根据 [Webpack 官方文档](https://webpack.js.org/concepts/),要上手 Webpack 只需要先理解五个核心概念:**Entry、Output、Loaders、Plugins、Mode**。

### Entry(入口)

入口指示 Webpack 应该从哪个模块开始构建它的内部依赖图。默认值是 `./src/index.js`,可以在配置中手动指定:

```javascript
// webpack.config.js
module.exports = {
  entry: './src/index.js',
};
```

也支持多入口（常用于多页应用）:

```javascript
module.exports = {
  entry: {
    app: './src/app.js',
    admin: './src/admin.js',
  },
};
```

### Output(输出)

`output` 告诉 Webpack 把打包产物写到哪里以及如何命名。默认主输出文件是 `./dist/main.js`:

```javascript
const path = require('path');

module.exports = {
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: '[name].[contenthash].js',
    clean: true, // 构建前清理输出目录(webpack 5 内置)
  },
};
```

其中 `[name]`、`[contenthash]`、`[chunkhash]` 是常用的占位符，用于做多入口命名和长期缓存。

### Loaders(加载器)

开箱即用时，Webpack 原生只理解 JavaScript 和 JSON 文件。Loaders 让 Webpack 能够解析其他类型的文件（CSS、图片、TypeScript 等）,并把它们转换成可加入依赖图的有效模块。

```javascript
module.exports = {
  module: {
    rules: [
      { test: /\.css$/i, use: ['style-loader', 'css-loader'] },
      { test: /\.(js|mjs)$/i, exclude: /node_modules/, use: 'babel-loader' },
    ],
  },
};
```

两个关键属性:

- `test`:匹配哪些文件需要被转换;
- `use`:用哪个 loader 来转换。

多个 loader 时执行顺序是**从右到左、从下到上**,例如上面 CSS 的处理顺序是先 `css-loader`(解析 `@import` 和 `url()`),再 `style-loader`(把样式注入 `<style>` 标签)。

### Plugins(插件)

Loaders 用来转换单个文件，Plugins 则用来执行范围更广的任务:bundle 优化、资源管理、注入环境变量等。使用时通过 `new` 实化后加入 `plugins` 数组:

```javascript
const HtmlWebpackPlugin = require('html-webpack-plugin');

module.exports = {
  plugins: [
    new HtmlWebpackPlugin({ template: './src/index.html' }),
  ],
};
```

常用插件包括 `HtmlWebpackPlugin`(自动生成 HTML 并注入产物)、`MiniCssExtractPlugin`(把 CSS 抽成独立文件)、`DefinePlugin`(注入环境变量)、`CopyWebpackPlugin`(复制静态资源)等。

### Mode(模式)

将 `mode` 设为 `development`、`production` 或 `none`,可以开启 Webpack 内置的对应环境优化。默认值是 `production`:

```javascript
module.exports = {
  mode: 'production',
};
```

不同模式下 Webpack 会自动调整：开发模式启用 source map、关闭压缩;生产模式自动开启 Tree Shaking、代码压缩和 Scope Hoisting。

## 一个最小可运行的示例

新建项目目录并初始化:

```bash
mkdir webpack-demo && cd webpack-demo
npm init -y
npm install webpack webpack-cli webpack-dev-server \
  html-webpack-plugin babel-loader @babel/core @babel/preset-env \
  css-loader style-loader --save-dev
```

项目结构:

```
webpack-demo/
├── dist/
├── src/
│   ├── index.js
│   └── style.css
├── index.html
└── webpack.config.js
```

`webpack.config.js`:

```javascript
const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');

module.exports = {
  mode: 'development',
  entry: './src/index.js',
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'bundle.js',
    clean: true,
  },
  module: {
    rules: [
      { test: /\.css$/i, use: ['style-loader', 'css-loader'] },
      {
        test: /\.js$/i,
        exclude: /node_modules/,
        use: { loader: 'babel-loader', options: { presets: ['@babel/preset-env'] } },
      },
    ],
  },
  plugins: [new HtmlWebpackPlugin({ template: './index.html' })],
  devServer: { static: './dist', hot: true, port: 8080 },
};
```

在 `package.json` 中加入脚本:

```json
{
  "scripts": {
    "start": "webpack serve --open",
    "build": "webpack --mode=production"
  }
}
```

随后 `npm start` 即可在 `http://localhost:8080` 打开开发服务器，支持模块热替换（HMR,Hot Module Replacement）;`npm run build` 会输出压缩后的生产产物到 `dist/`。

## Webpack 5 值得关注的特性

截至撰稿时，Webpack 的最新稳定主版本仍是 Webpack 5(最新 patch 为 v5.108.4,2025-07-04 发布)。相比 4.x，这一代主要新增:

- **Module Federation(模块联邦)**:允许在不同构建之间运行时共享代码，是微前端架构的原生方案。
- **Asset Modules(资源模块)**:用 `asset/resource`、`asset/inline`、`asset/source`、`asset/bytes`、`asset` 五种内置类型替代了原先的 `file-loader`、`url-loader`、`raw-loader`,无需额外安装 loader。默认内联阈值为 8KB。
- **持久化缓存**:filesystem 缓存大幅提升二次构建速度。
- **更彻底的 Tree Shaking**:支持嵌套模块的死代码消除。
- **不再自动 polyfill Node.js 核心模块**:像 `crypto`、`path`、`os` 等模块在 5.x 里不会自动注入 polyfill，需要在配置中显式处理。

## 学习路径建议

给初次接触 Webpack 的同学一条可行路径:

1. 先跑通 [webpack-demos](https://github.com/ruanyf/webpack-demos),对"入口 / loader / plugin / 分割"有直观感受;
2. 通读 [官方 Concepts](https://webpack.js.org/concepts/),把 Entry、Output、Loaders、Plugins、Mode 五个概念牢牢建立起来;
3. 跟着 [官方 Guides](https://webpack.js.org/guides/) 做一遍 Asset Modules、Code Splitting、Lazy Loading、Caching 等实战;
4. 在此基础上再去看 Tree Shaking、Module Federation、持久化缓存等高级主题;
5. 最后把视线拉宽，横向对比 Vite / Rspack / Turbopack，理解新一代工具为什么要用原生 ESM 和 Rust 重写。

## 参考

- [Webpack 官方文档](https://webpack.js.org/)
- [Webpack 核心概念](https://webpack.js.org/concepts/)
- [Asset Modules 指南](https://webpack.js.org/guides/asset-modules/)
- [ruanyf/webpack-demos](https://github.com/ruanyf/webpack-demos)
- [userkang/webpack-demos-cn](https://github.com/userkang/webpack-demos-cn)
- [博客园：阮一峰 Webpack 教程](https://www.cnblogs.com/luckyting/articles/11278171.html)