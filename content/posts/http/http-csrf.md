+++
title = "CSRF 跨站请求伪造详解"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "跨站请求伪造原理、攻击向量与防御方案梳理"
description = "CSRF(Cross-Site Request Forgery)利用浏览器自动携带 Cookie 的机制冒用已登录用户身份发起请求,本文梳理其原理与 Token、SameSite、Origin 校验等主流防御方案。"
author = "小智晖"
authors = ["小智晖"]
categories = ["http"]
tags = ["http", "csrf", "web", "安全", "cookie"]
keywords = ["csrf", "跨站请求伪造", "anti-csrf token", "samesite cookie", "web 安全"]
toc = true
draft = false
+++

## 简介

CSRF(Cross-Site Request Forgery，跨站请求伪造)是一种针对 Web 应用的攻击方式。攻击者诱导已登录（已通过身份认证）的用户，在他们不知情的情况下，以其身份向目标网站发送了一个恶意请求。由于浏览器在跨站请求中**会自动携带目标域的 Cookie**,服务器看到请求带着有效的会话凭证，就会把它当作合法用户本人的操作并予以执行。

一个典型的场景：某用户登录了银行账户后，在另一个标签页逛论坛时不小心点开恶意链接;恶意页面里嵌了一段 `<img>` 或隐藏表单，以这名用户的会话 Cookie 向银行发起转账请求。银行侧校验 Cookie 通过，转账被放行。

> 白话类比：就像别人偷拿了你的会员卡去消费，店家"认卡不认人",看到卡就相信持卡人是你本人。

CSRF 之所以成立，前提是**用户的身份已经被认证过**,且认证凭证（通常是 Session ID）会随跨站请求自动发送。它攻击的不是服务器漏洞，而是"浏览器自动携带凭证"这一HTTP 默认行为。

## 攻击原理

CSRF 的核心在于**借用身份**而非盗取凭证。攻击者无法读取目标域的 Cookie(受同源策略限制),但可以让浏览器**替自己带上**它。常见攻击向量包括:

- **隐藏表单（POST）**:在恶意页面构造一个 `action="https://bank.com/transfer"` 的 `<form>`,用 JavaScript 自动提交。
- **图片标签（GET）**:`<img src="https://bank.com/transfer?to=attacker&amount=1000">`,浏览器加载图片时即触发 GET 请求。
- **链接诱导**:诱导用户点击伪装的链接执行危险操作（前提是操作用 GET 完成）。

由此也衍生出一条**安全铁律**:

> 任何会改变服务器状态的操作（写、删、转账）,都不应通过 GET 请求完成。GET 必须是幂等且无副作用的。

## CSRF 与 XSS 的区别

两者常被混淆，但攻击模型截然不同:

| 维度 | CSRF | XSS(Cross-Site Scripting) |
|---|---|---|
| 攻击目标 | 已登录的**正常**用户 | 网站本身（注入恶意脚本） |
| 凭证是否泄露 | 否（只借用，不读取） | 是（脚本可读 Cookie、DOM） |
| 是否依赖 Cookie 自动携带 | 是 | 否 |

一个关键推论:**XSS 可以绕过几乎所有 CSRF 防御**。如果页面存在 XSS，攻击者能直接读取 Token 或在同源上下文中发起请求。因此 CSRF 防御必须与 XSS 防御配合使用。

## 主流防御方案

[OWASP CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)是公认权威的参考。下面按工程中实际使用频率梳理。

### 1. Anti-CSRF Token(同步令牌模式)

最经典、最推荐的方案。服务器为每个会话（或每个请求）生成一个**加密强度足够、不可预测**的随机 Token，在响应中以隐藏字段或自定义 Header 返回给客户端;客户端提交时附带 Token，服务器比对会话中存储的值。

```html
<form action="/transfer" method="POST">
  <input type="hidden" name="csrf_token" value="r4nd0mT0k3n..."/>
  <input type="text" name="to"/>
  <input type="number" name="amount"/>
  <button type="submit">提交</button>
</form>
```

关键点:

- Token 必须绑定到**当前会话**,且具有有效期。
- Token **不能**通过 Cookie 下发，否则又会被自动携带，失去防伪作用。
- 推荐为每个请求轮换 Token(Synchronizer Token Pattern 的标准形态)。

主流 Web 框架(如 Spring Security CSRF、Django `CsrfViewMiddleware`、Rails、Laravel `VerifyCsrfToken`、Express 的 `csurf` 中间件)均内置该机制。

### 2. 双重提交 Cookie(Double Submit Cookie)

**无状态**方案：服务器把 Token 放进 Cookie，客户端 JavaScript 读取后以 Header 或表单字段形式回传;服务器比对 Cookie 中的值与请求中携带的值是否一致。

更稳健的变体是**签名双重提交（Signed Double-Submit Cookie）**:用 HMAC 把 Token 绑定到用户会话 ID，防止子域注入 Cookie 造成伪造。OWASP 明确指出：朴素的（未签名、未绑定会话）实现存在被绕过的风险,**不推荐单独使用**。

### 3. SameSite Cookie 属性

这是现代浏览器原生提供的、最低成本的纵深防御手段。自 **Chrome 80(2020 年 2 月)** 起，未显式声明 `SameSite` 的 Cookie 默认被视为 `SameSite=Lax`。三种取值:

- **`Strict`**:跨站请求**完全不携带** Cookie。安全性最高，但会损害从外链跳转回站点的用户体验（点击邮件中的本站链接也不会带 Cookie，看起来像未登录）。
- **`Lax`**(默认):仅在同站请求、或顶层导航（top-level navigation）且使用安全方法（GET）时携带。能挡绝大多数 CSRF，但对 POST/PUT/DELETE 跨站请求无效——而这些恰恰是危险操作。
- **`None`**:允许跨站携带，但**必须同时设置 `Secure`**(仅 HTTPS)。

```
Set-Cookie: sessionid=abc123; Path=/; HttpOnly; Secure; SameSite=Lax
```

OWASP 提醒:SameSite 适合作为**纵深防御**手段，但不应替代基于 Token 的完整 CSRF 防御，因为它无法覆盖所有场景（子域、GET 类危险操作、老旧浏览器等）。

### 4. Origin / Referer 头校验

服务器检查请求的 `Origin` 或 `Referer` 头是否来自期望的源。这两个头属于浏览器的**禁止修改头（forbidden headers）**,JavaScript 无法篡改，因此可作为可信信号。

- 优先校验 `Origin`(更精确，不带路径);
- `Origin` 缺失时回退到 `Referer`;
- 两者都没有时，OWASP 建议**直接拒绝**。

```http
POST /transfer HTTP/1.1
Host: bank.com
Origin: https://bank.com
Cookie: sessionid=abc123
```

注意 `Referer` 可能因隐私策略被浏览器剥离，因此不能单独依赖。

### 5. Fetch Metadata 头

较新的浏览器会发送 `Sec-Fetch-Site`、`Sec-Fetch-Mode`、`Sec-Fetch-Dest` 等 Fetch Metadata 头，服务器据此判断请求的来源上下文。若 `Sec-Fetch-Site` 为 `cross-site` 且使用了非安全方法，即可直接拒绝。由于旧浏览器不发送这些头，需回退到 Origin 校验。

## 防御组合建议

工程实践中推荐**多层防御（Defense in Depth）**,而非单点依赖:

1. 框架内置的 **Anti-CSRF Token**(主防线);
2. 关键会话 Cookie 设置 `SameSite=Lax` 或 `Strict`(纵深防御);
3. 对状态变更操作做 **Origin/Referer 校验**;
4. 敏感操作（如大额转账、改密）**要求二次验证**(密码、OTP、CAPTCHA);
5. 同步推进 **XSS 防御**(输出转义、CSP),否则 CSRF 防御形同虚设。

## 常见误区

- **"用了 HTTPS 就不会有 CSRF"**:错误。HTTPS 加密传输，但不影响浏览器是否携带 Cookie。
- **"只接受 POST 就安全"**:错误。POST 同样能被跨站伪造（隐藏表单）。
- **"检查 Referer 就够了"**:不全对。Referer 可被隐私策略剥离，需配合 Token。
- **"SameSite=Lax 万事大吉"**:不全对。Lax 不保护 POST，危险操作仍需 Token。

## 参考

- [OWASP CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
- [OWASP - Cross Site Request Forgery (CSRF)](https://owasp.org/www-community/attacks/csrf)
- [MDN - Set-Cookie(SameSite 属性)](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie)
- [SameSite cookies explained - web.dev](https://web.dev/articles/samesite-cookies-explained)
- [什么是 CSRF 攻击？如何防范？ - explainthis](https://www.explainthis.io/zh-hans/swe/what-is-csrf)
