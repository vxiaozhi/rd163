+++
title = "跨域资源共享 CORS 详解"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "浏览器跨域机制、预检请求与 CORS 响应头实战"
description = "CORS 是基于 HTTP 头的跨域机制,本文梳理同源策略、简单请求与预检请求、CORS 相关头部字段与 Cookie 凭证的处理要点。"
author = "小智晖"
authors = ["小智晖"]
categories = ["http"]
tags = ["http", "cors", "跨域", "web", "前端"]
keywords = ["cors", "跨域", "同源策略", "预检请求", "Access-Control-Allow-Origin"]
toc = true
draft = false
+++

## 简介

CORS(Cross-Origin Resource Sharing，跨域资源共享)是一个基于 HTTP 头的安全机制，允许服务器声明浏览器可以从**哪些源（origin）** 加载自己提供的资源。源由 **协议（scheme）、域名（host）和端口（port）** 三者共同决定，任一不同即视为跨域。

由于浏览器实现了 **同源策略（Same-Origin Policy）**,默认情况下 `fetch()`、`XMLHttpRequest` 等接口只能访问与当前页面同源的资源。CORS 通过一组 `Access-Control-*` 响应头打破这一限制，使前端能够安全地调用第三方 API。

> 注意:CORS 由浏览器（用户代理）执行，服务器只是按需返回 CORS 头。curl、Postman 等非浏览器客户端不受其约束。

CORS 最早由 W3C 提出，目前的标准定义在 [WHATWG Fetch Living Standard](https://fetch.spec.whatwg.org/) 中（原 W3C CORS 规范已废弃）。

## 同源策略与跨域场景

判断两个 URL 是否同源，只需比较三者:

| URL | 协议 | 域名 | 端口 | 是否同源 |
| --- | --- | --- | --- | --- |
| `https://example.com/a` | https | example.com | 443 | — |
| `https://example.com/b` | https | example.com | 443 | 同源 |
| `http://example.com/a` | http | example.com | 80 | 跨域（协议不同） |
| `https://api.example.com/a` | https | api.example.com | 443 | 跨域（域名不同） |
| `https://example.com:8080/a` | https | example.com | 8080 | 跨域（端口不同） |

跨域是日常开发中频繁遇到的场景，例如前端 `https://app.example.com` 调用 `https://api.example.com` 接口，或从 CDN 加载字体文件。涉及 CORS 的典型场景还包括 `fetch()` / `XMLHttpRequest`、CSS `@font-face` 跨域字体、WebGL 贴图、Canvas `drawImage()` 像素读取等。

## 两种请求类型

CORS 规范将跨域请求分为两类:**简单请求（Simple Request）** 和 **需预检的请求（Preflighted Request）**。区分的关键在于该请求是否"足以让服务器在事前就理解其意图"。

### 简单请求

满足以下全部条件的请求不会触发预检，直接由浏览器发送:

- 方法为 `GET`、`HEAD` 或 `POST`
- 仅使用 CORS 安全头部（cors-safelisted request-header）:`Accept`、`Accept-Language`、`Content-Language`、`Content-Type`(仅限三种值)、`Range`(单段)
- `Content-Type` 仅限:
    - `application/x-www-form-urlencoded`
    - `multipart/form-data`
    - `text/plain`
- 没有注册 `XMLHttpRequest.upload` 事件监听器
- 未使用 `ReadableStream`

浏览器在发出简单请求时会自动加上 `Origin` 头，服务端根据 `Origin` 决定是否放行，并在响应中返回 `Access-Control-Allow-Origin` 等头信息。

### 需预检的请求

不满足"简单请求"任一条件的请求，浏览器会先发送一个 `OPTIONS` 方法的 **预检请求（Preflight Request）**,询问服务器是否允许接下来的真实请求。常见触发预检的情况:

- 使用了 `PUT`、`DELETE`、`PATCH` 等非简单方法
- 自定义请求头，如 `X-Requested-With`、`Authorization`、`X-CSRF-Token`
- `Content-Type` 为 `application/json`(这是最常踩坑的点)

预检是浏览器的"安全握手":服务器拒绝预检，真实请求便不会发出。

## CORS 相关头部字段

### 请求头（浏览器自动添加）

以下头由浏览器生成，开发者无需手动设置:

- **`Origin`**:发起请求的源，格式为 `协议://域名:端口`。
- **`Access-Control-Request-Method`**:预检请求中声明真实请求将使用的 HTTP 方法。
- **`Access-Control-Request-Headers`**:预检请求中声明真实请求将携带的自定义头部，多个用逗号分隔。

### 响应头（服务器返回）

#### `Access-Control-Allow-Origin`

最核心的字段，指定允许访问的源。只有两种合法取值:

- 具体的源，如 `https://foo.example.com`
- `*`,表示允许任意源(注意：与凭证一起使用时不可为 `*`)

```
Access-Control-Allow-Origin: https://foo.example.com
```

如果按请求方的 `Origin` 动态返回，还应同时设置 `Vary: Origin`,避免 CDN 等缓存为某一源返回错乱的响应。

#### `Access-Control-Allow-Methods`

用于预检响应，声明服务器支持的方法:

```
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
```

#### `Access-Control-Allow-Headers`

用于预检响应，声明允许真实请求携带的头部:

```
Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With
```

#### `Access-Control-Expose-Headers`

默认情况下，JavaScript 通过 `response.headers` 只能读到少数几个安全响应头（CORS-safelisted response header）。该字段用于向 JavaScript 暴露额外的响应头:

```
Access-Control-Expose-Headers: X-Total-Count, X-Request-Id
```

#### `Access-Control-Max-Age`

预检结果的缓存时间（秒）,在有效期内同一请求不再发起预检:

```
Access-Control-Max-Age: 600
```

未设置时默认为 5 秒。各浏览器有上限:Firefox 上限为 86,400 秒（24 小时）,Chromium 自 v76 起为 7,200 秒（2 小时）,更早的 Chromium 为 600 秒。超出上限的值会被自动截断。

#### `Access-Control-Allow-Credentials`

布尔值，指示是否允许携带凭证（Cookie、HTTP 认证、客户端 SSL 证书）:

```
Access-Control-Allow-Credentials: true
```

## 完整流程示例

### 简单请求

```js
fetch("https://api.example.com/data")
  .then((res) => res.json())
  .then((data) => console.log(data));
```

浏览器发送:

```http
GET /data HTTP/1.1
Host: api.example.com
Origin: https://app.example.com
```

服务器响应:

```http
HTTP/1.1 200 OK
Access-Control-Allow-Origin: https://app.example.com
Content-Type: application/json

{"hello":"world"}
```

### 预检请求

```js
fetch("https://api.example.com/users", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Authorization": "Bearer xxx",
  },
  body: JSON.stringify({ name: "Alice" }),
});
```

浏览器先发预检:

```http
OPTIONS /users HTTP/1.1
Host: api.example.com
Origin: https://app.example.com
Access-Control-Request-Method: POST
Access-Control-Request-Headers: content-type, authorization
```

服务器预检响应:

```http
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: POST, GET, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Max-Age: 600
```

通过后，浏览器再发送真实请求。

## Cookie 与凭证

默认情况下 CORS 请求不携带 Cookie。要发送凭证,**前端和后端必须同时配置**:

```js
// fetch
fetch(url, { credentials: "include" });

// XMLHttpRequest
const xhr = new XMLHttpRequest();
xhr.withCredentials = true;
```

服务端:

```http
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Credentials: true
```

三个要点:

- 携带凭证时,`Access-Control-Allow-Origin` **不能是 `*`**,必须是具体的源
- 响应中 `Set-Cookie` 同样受浏览器第三方 Cookie 策略(如 `SameSite`)约束
- **预检请求本身永远不携带凭证**,服务器对预检响应设置 `Access-Control-Allow-Credentials: true` 用来声明真实请求可以带凭证

## 调试要点

- CORS 失败时，JavaScript 只能拿到一条通用的网络错误，真实原因需要在 **浏览器 DevTools 控制台和网络面板** 中查看
- HTTP 状态码为 200 并不代表 CORS 通过;若响应缺少必要的 CORS 头，浏览器依旧会把响应拦截
- 排查顺序通常是：是否同源 → 是否触发预检 → 预检响应头是否齐全 → `Origin` 是否在允许列表中 → 是否与凭证冲突
- 开发阶段常用的"关闭浏览器同源策略"或后端 `Access-Control-Allow-Origin: *` 并不适合生产环境

## 与 JSONP 的对比

在 CORS 普及之前，跨域 GET 常用 JSONP(JSON with Padding)方案。两者各有适用场景:

| 维度 | CORS | JSONP |
| --- | --- | --- |
| 支持的 HTTP 方法 | 所有方法 | 仅 `GET` |
| 错误处理 | 标准 HTTP 错误码与 `onerror` | 难以处理错误 |
| 安全性 | 浏览器与服务端协同校验 | 信任被注入的脚本，风险较高 |
| 浏览器兼容性 | 现代浏览器原生支持 | 兼容老式浏览器 |

新项目应优先使用 CORS,JSONP 仅在需要兼容非常老旧的环境时才考虑。

## 参考

- [MDN — Cross-Origin Resource Sharing (CORS)](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
- [WHATWG — Fetch Living Standard](https://fetch.spec.whatwg.org/)
- [阮一峰 — 跨域资源共享 CORS 详解](https://www.ruanyifeng.com/blog/2016/04/cors.html)
- [阮一峰 — CORS 通信](https://javascript.ruanyifeng.com/bom/cors.html)
- [MDN — Access-Control-Max-Age](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Max-Age)