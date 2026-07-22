+++
title = "Google 统计接入"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "为网站接入 Google Analytics 4 的完整流程与注意事项"
description = "介绍如何在 Hugo 网站中接入 Google Analytics 4,包括账号注册、Google 代码安装、Hugo/DoIt 主题配置以及验证与隐私设置。"
author = "小智晖"
authors = ["小智晖"]
categories = ["seo"]
tags = ["seo", "Google Analytics", "GA4", "gtag.js", "Hugo"]
keywords = ["Google Analytics", "GA4", "gtag.js", "Hugo 统计接入", "网站流量分析"]
toc = true
draft = false
+++

Google Analytics(谷歌分析，以下简称 GA)是 Google 提供的免费网站流量分析服务，可以统计访问量、来源、用户行为等指标。当前线上版本为 Google Analytics 4(GA4),它采用基于事件（event-based）的数据模型，取代了旧的基于会话（session-based）的 Universal Analytics(UA)。Google 已于 **2023 年 7 月 1 日**停止处理标准 Universal Analytics 属性的数据（360 属性的截止日期为 2024 年 7 月 1 日）,新接入的网站应直接使用 GA4。

本文记录为 Hugo 博客接入 GA4 的完整流程，以及在使用 DoIt 主题时的配置方式。

## 前置概念

在动手之前，需要先理清 GA4 中的几个关键概念:

- **账号（Account）**:GA 中的最顶层组织单位，通常对应一个公司或主体。一个账号可以包含多个媒体资源。
- **媒体资源（Property）**:一个网站或 App 的数据集合。GA4 的一个媒体资源可以同时接收来自网站和 App 的数据。
- **数据流（Data Stream）**:媒体资源下的数据来源，分为 Web、iOS、Android 三类。一个网站对应一个 Web 数据流。
- **衡量 ID(Measurement ID)**:Web 数据流的唯一标识，格式为 `G-XXXXXXXX`(例如 `G-L2FGRML2DB`),在 gtag.js 代码中以 `id=` 形式出现。
- **Google 代码（Google Tag）**:GA4 推送到网站上的 JavaScript 片段，核心是 `gtag.js`,负责把用户行为事件上报到 GA 服务器。

此外，一个 GA 账号可以接入多个网站（为每个网站创建独立的 Web 数据流，或在同一媒体资源下复用）,不一定每个站点都要单独注册账号。

## 接入步骤

### Step 1:注册账号并获取衡量 ID

1. 访问 [https://analytics.google.com/](https://analytics.google.com/),使用 Google 账户登录。
2. 按引导依次创建 **账号 → 媒体资源 → Web 数据流**,填入网站域名(如 `https://rd163.com`)和数据流名称。
3. 创建完成后，在「管理 → 数据流 → 选择 Web 数据流」中可以看到 **衡量 ID**(形如 `G-L2FGRML2DB`)以及「查看代码说明」入口。

> 提示：如果使用的是 CMS(如 WordPress、Shopify)或网站构建器，通常可以直接选用平台插件接入;手动接入网站则需要复制下文所示的 Google 代码。

### Step 2:复制并粘贴 Google 代码

在数据流详情页选择「查看代码说明 → 手动安装」,会得到一段以 `<!-- Google tag (gtag.js) -->` 开头的脚本。以下是示例(请把 `G-XXXXXXXX` 替换为你自己的衡量 ID):

```html
<!-- Google tag (gtag.js) -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', 'G-XXXXXXXX');
</script>
```

按照官方要求，这段代码应粘贴到每个网页 **`<head>` 元素之后**,且每个网页只放一个 Google 代码，避免重复上报。脚本通过 `async` 异步加载 `gtag.js` 主体，主体加载完成前先通过 `dataLayer` 队列暂存事件。

## 在 Hugo 中接入

Hugo 提供两种接入方式，根据所用主题选择其一即可。

### 方式一:Hugo 内置模板

Hugo 自带 Google Analytics 内部模板，只需在配置文件中填入衡量 ID。

`hugo.toml` 写法:

```toml
[services]
  [services.googleAnalytics]
    id = 'G-XXXXXXXX'

[privacy]
  [privacy.googleAnalytics]
    disable = false
    respectDoNotTrack = true
```

要点:

- `id` 必须是 GA4 的 `G-` 开头格式;如果配置成旧的 `UA-` 开头 ID,Hugo 会在构建时打印告警且不渲染代码。
- `respectDoNotTrack = true` 会让模板在浏览器开启「请勿跟踪」(DNT)时不下发脚本，符合隐私合规建议。

然后在模板的 `<head>` 中调用内置 partial:

```go-html-template
{{ template "_internal/google_analytics.html" . }}
```

或在新版本中使用:

```go-html-template
{{ partial "_internal/google_analytics.html" . }}
```

### 方式二:DoIt 主题配置

本站使用 DoIt 主题，它内置了一套统一的统计接入模块，支持 Google、百度、Umami、Plausible、Matomo 等多种统计服务。在 `config/_default/params.toml` 中开启即可:

```toml
[analytics]
  enable = true

  [analytics.google]
    id = "G-XXXXXXXX"
    anonymizeIP = true
```

DoIt 在 `layouts/_partials/plugin/analytics.html` 中渲染的 Google 代码等价于:

```html
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXX');
</script>
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXX"></script>
```

`anonymizeIP = true` 会在 `gtag('config', ...)` 中追加 `'anonymize_ip': true`,把上报的 IP 地址末段置零，以进一步满足 GDPR 等隐私法规的要求。

> 如果你在后端（如服务端模板渲染框架）而非静态站点接入，流程类似，差异主要在代码注入方式，可参考 [谷歌统计接入（后端方案）](https://www.cnblogs.com/lwhzj/p/18347217)。

## 增强衡量（Enhanced Measurement）

GA4 的 Web 数据流默认开启「增强衡量」功能，无需额外写代码即可自动采集以下事件:

| 事件 | 触发条件 |
|---|---|
| `page_view` | 页面加载或浏览器 history 状态变化（不可关闭） |
| `scroll` | 用户首次滚动到页面 90% 位置 |
| `click` | 点击指向当前域名之外的出站链接 |
| `view_search_results` | 站内搜索结果页(识别 `q`、`s`、`search` 等查询参数) |
| `video_start` / `video_progress` / `video_complete` | 嵌入式 YouTube 视频的播放、进度与完成 |
| `file_download` | 点击文档、压缩包、视频等文件类型的链接 |
| `form_start` / `form_submit` | 表单首次交互与提交 |

如果只需要基础的浏览量统计，可在「管理 → 数据流 → 配置网站设置」中关闭不需要的事件，避免噪声数据。

## 验证安装

接入完成后，通过下面任一方式确认代码生效:

1. **实时报告（Realtime）**:在 GA 后台「报告 → 实时」中，自己用浏览器（建议无痕模式）打开网站，大约 30 秒内应能看到当前在线访问者与触发的事件。
2. **Tag Assistant / DebugView**:安装 Chrome 扩展 [Tag Assistant](https://tagassistant.google.com/),把它连接到对应 GA4 媒体资源，逐页浏览即可在 GA 的「配置 → DebugView」中看到每个事件的详细参数。也可以在代码里加 `gtag('config', 'G-XXXXXXXX', { 'debug_mode': true })` 永久启用调试模式。
3. **浏览器开发者工具**:打开 Network 面板，过滤 `collect` 请求，正常访问页面应能看到向 `https://www.google-analytics.com/g/collect` 发出的 POST 请求。

排查无数据的常见原因：衡量 ID 写错、代码放在了被条件渲染的区域、同时加载了 gtag.js 与 Google Tag Manager 导致重复触发、使用了广告拦截插件拦截了上报域名。

## 隐私与合规

面向欧洲经济区（EEA）、瑞士、英国等地区用户时，Google 要求启用 **Consent Mode v2(同意模式 v2)**,在原有的 `ad_storage`、`analytics_storage` 两个信号之外，新增 `ad_user_data` 和 `ad_personalization` 两个信号，用于声明用户数据是否可用于广告用途和个性化广告。在「基本」模式下，用户拒绝同意时仍会发送无 Cookie 的转化 ping;在「高级」模式下，则可根据已同意用户的行为建模未同意用户的转化。

实操上，通常配合 Cookie 同意管理工具（如 Cookiebot、Consentmanager、Termly）在页面加载时先调用:

```javascript
gtag('consent', 'default', {
  'ad_storage': 'denied',
  'analytics_storage': 'denied',
  'ad_user_data': 'denied',
  'ad_personalization': 'denied',
  'wait_for_update': 500
});
```

用户做出选择后再用 `gtag('consent', 'update', {...})` 更新对应信号为 `granted`,即可与 GA4 / Google Ads 的合规要求保持一致。

## 小结

GA4 的接入并不复杂，关键是理解「账号 → 媒体资源 → 数据流 → 衡量 ID」的层级关系，并把 Google 代码放到全站公用的 `<head>` 中。对于 Hugo + DoIt 这类静态站点，优先用主题或 Hugo 内置的统计模块，避免直接改模板带来的维护成本。接入后，建议第一时间用实时报告或 Tag Assistant 验证事件上报，并根据站点定位决定是否开启增强衡量中的全部事件，以及是否为合规需要配置 Consent Mode。
