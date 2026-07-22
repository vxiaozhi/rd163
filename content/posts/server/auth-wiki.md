+++
title = "Auth-Wiki"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Logto 维护的开源身份认证与授权百科"
description = "Auth-Wiki 是由 Logto 团队维护、采用 CC0 协议的开源知识库,系统收录 OAuth 2.0、OpenID Connect、SAML 等身份认证与授权术语,支持 13 种语言。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "auth", "oauth", "oidc", "saml", "wiki"]
keywords = ["Auth-Wiki", "Logto", "OAuth 2.0", "OpenID Connect", "SAML", "身份认证"]
toc = true
draft = false
+++

在平时做后端服务、对接第三方登录或设计权限系统时，经常会遇到 OAuth、OIDC、SAML、PKCE、JWT 这类术语。官方规范（RFC）读起来晦涩，博客文章又常常各执一词。**Auth-Wiki** 正是为填补这块空白而存在的开源知识库——它由 [Logto](https://github.com/logto-io/logto) 团队发起维护，系统性地收录了与身份验证（Authentication）、授权（Authorization）以及身份与访问管理（IAM）相关的术语条目。

- 仓库地址:[logto-io/auth-wiki](https://github.com/logto-io/auth-wiki)
- 在线站点:[auth.wiki](https://auth.wiki/zh)(自动跳转至 `auth-wiki.logto.io`)

## 它是什么

Auth-Wiki 自我定位为「关于认证、授权与身份管理的文章、教程和资源的综合合集」(A comprehensive collection of articles, tutorials, and resources about authentication, authorization, and identity management)。与一般技术博客不同，它更像一本**术语词典（Glossary）**,每个条目都给出一个简明定义，再通过「了解更多」跳转到详细解释页。

项目托管在 GitHub 的 `logto-io` 组织下，与同名的开源身份平台 Logto 共用同一支维护团队。需要注意的是，Auth-Wiki 是**独立的知识项目**,内容并不绑定 Logto 的具体产品，讲的是通用协议与概念。

## 三大内容领域

站点把所有条目划分到三个核心域中:

### 身份验证（Authentication, AuthN）

回答「你是谁」的问题。收录的条目包括通行钥匙（Passkeys）、TOTP、多因素认证（MFA）、WebAuthn、无密码认证（Passwordless）、魔法链接（Magic Link）,以及认证与授权两者区别这类基础概念。

### 授权（Authorization, AuthZ）

回答「你能做什么」的问题。涵盖 RBAC、ABAC、访问令牌（Access Token）、作用域（Scope）、OAuth 2.0 各种授权模式、资源指示符（Resource Indicator）与授权服务器（Authorization Server）等。

### 身份与访问管理（IAM）

更宏观的基础设施概念，例如身份提供者（IdP）、多租户（Multi-tenancy）、即时配置（JIT Provisioning）、机器到机器（M2M）通信、管理 API 等。

## 重点协议与标准

Auth-Wiki 对三大开放标准给出了**显著位置**:

- **OpenID Connect (OIDC)**:包括 Discovery、认证请求、Hybrid Flow、UserInfo Endpoint、ID Token 等子条目。
- **OAuth 2.0 / OAuth 2.1**:覆盖授权码流程（Authorization Code Flow）、PKCE、设备流程（Device Flow）、客户端凭据流程（Client Credentials Flow）、隐式流程（Implicit Flow）、令牌内省（Token Introspection）、刷新令牌（Refresh Token）等。
- **SAML**:用于在身份提供者（IdP）与服务提供者（SP）之间交换认证与授权数据的标准。

此外还可以看到 JWT、JWE、JWS、JWK/JWKS、PKCE、CSRF、CSPRNG、XACML、企业 SSO、Webhook、API Key、备份码（Backup Codes）等高频出现的工程术语。条目数量据站点字母索引粗略统计在 55 条以上。

## 多语言与开源特性

多语言是 Auth-Wiki 的一大亮点。站点提供 **13 种语言**,包括简体中文、繁体中文、英语、日语、韩语、法语、德语、西班牙语、意大利语、葡萄牙语（巴西与欧洲两种变体）、荷兰语与阿拉伯语。仓库内还集成了基于 OpenAI 的翻译脚本(`translate.openai.mjs`),用以辅助本地化产出。

技术栈方面，项目使用:

| 组件 | 选型 |
|------|------|
| 站点框架 | Astro(静态站点生成) |
| 包管理 | PNPM(workspace 模式) |
| 内容格式 | MDX(Markdown + JSX) |
| 测试 | Vitest |
| 部署 | Cloudflare Workers |

内容源文件统一放在仓库的 `src/content` 目录下，98% 以上的代码量都是 MDX。许可证为 **CC0-1.0**(Creative Commons Zero),即自愿放弃版权、投入公共领域，任何人都可以自由复制、修改、再分发，甚至商用。

## 如何使用与贡献

**作为读者**,直接访问 [auth.wiki/zh](https://auth.wiki/zh) 浏览中文版本即可，条目按字母分类组织（A、B、D、F…）,每个词条页结构一致：粗体术语 + 中英文对照 + 一段白话定义 + 「了解更多」跳转。

**作为贡献者**,可以在 GitHub 上打开对应文件点编辑按钮直接提交 PR。本地预览也很简单:

```bash
git clone https://github.com/logto-io/auth-wiki.git
cd auth-wiki
pnpm install
pnpm dev
```

由于采用 CC0 协议，引用其中的释义到自己的文档或博客里也没有许可负担——这点对写技术文档的同学特别友好。

## 适用场景

个人觉得 Auth-Wiki 在以下几种场景下尤其有用:

1. **快速回忆术语**:忘了 Hybrid Flow 和 Authorization Code Flow 的区别时，比翻 RFC 快得多。
2. **团队知识对齐**:在 Code Review 或方案评审中，引用同一个条目链接能避免「我说的是这个 OAuth，你说的是那个 OAuth」的歧义。
3. **学习路径参考**:对刚接触身份认证领域的工程师，按 AuthN → AuthZ → IAM 的分类顺序阅读，能较快建立起全局视图。
4. **写文档查标准用法**:撰写 API 文档或安全设计文档时，统一使用 Auth-Wiki 的术语定义，有助于与业界惯例保持一致。

## 与 Logto 的关系

虽然 Auth-Wiki 由 Logto 团队维护，但它**不是 Logto 的产品文档**。Logto 本身是一个基于 OIDC 与 OAuth 2.1 的开源身份平台（协议兼容 SAML，支持企业 SSO、RBAC、MFA 等，采用 MPL-2.0 协议）,而 Auth-Wiki 是团队回馈社区的独立教育项目。两者在内容上互补：产品文档讲「怎么用 Logto」,Auth-Wiki 讲「这些概念到底是什么」。

## 参考

- [auth-wiki GitHub 仓库](https://github.com/logto-io/auth-wiki)
- [Auth-Wiki 中文站](https://auth.wiki/zh)
- [Logto 主仓库](https://github.com/logto-io/logto)
- [OAuth 2.0 RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749)
- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)
