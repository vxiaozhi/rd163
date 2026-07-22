+++
title = "工作周报自动总结"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "用 Obsidian 搭建一套可自动汇总日记到周报的工作流"
description = "基于 Obsidian 的 Periodic Notes、Templater 与 AI Summary 插件,将每日日记自动汇聚并生成结构化工作周报的实践方案。"
author = "小智晖"
authors = ["小智晖"]
categories = ["work"]
tags = ["work", "obsidian", "automation", "ai"]
keywords = ["工作周报", "Obsidian", "AI 总结", "Periodic Notes", "自动化"]
toc = true
draft = false
+++

工作周报是研发团队常见的同步手段,但每周末手工翻阅五天日记、再归纳成文,既耗时又容易遗漏。本文记录一套基于 [Obsidian](https://obsidian.md/) 的自动化方案:每日按固定模板写日记,周末由插件汇总引用、再由 AI 模型生成可读的周报草稿。

## 整体思路

把周报拆成三件事:

1. **结构化的日记**——每天用同一份模板记录工作内容,保证后续可被机器读取。
2. **按周聚合**——用一个周记文件通过 `[[wikilink]]` 把当周七天的日记串起来。
3. **AI 摘要**——把周记所引用的全部日记内容一次性喂给大模型,生成总结。

这三步分别对应 Obsidian 生态里的三个插件,下文逐一说明。

## 日记模板:Periodic Notes + Templater

### Periodic Notes

[Periodic Notes](https://github.com/liamcain/obsidian-periodic-notes) 在 Obsidian 自带「日记(Daily Note)」基础上扩展出「周记(Weekly Note)」和「月记(Monthly Note)」。它的核心价值是为周记提供独立的文件夹、文件名格式和模板配置。

周记的文件名格式默认采用 `gggg-[W]ww`(ISO 周数),例如 `2025-W02`。模板中可使用如下占位符:

| 占位符 | 含义 |
| --- | --- |
| `{{title}}` | 文件标题 |
| `{{date}}` | 当天日期 |
| `{{time}}` | 当前时间 |
| `{{monday:YYYY-MM-DD}}` | 本周一的日期 |

与同一作者更早的 [Calendar 插件](https://github.com/liamcain/obsidian-calendar-plugin)配合使用时,侧边栏日历上的周数可直接点击跳转到对应周记,且 Calendar 中原有的周记配置会自动迁移到 Periodic Notes。

### Templater

[Templater](https://github.com/SilentVoid13/Templater) 比 Obsidian 内置模板更强,支持变量、函数,甚至内嵌 JavaScript。常见用法是在日记模板里自动填充日期、生成固定的小节标题。

> 注意:Templater 允许执行任意 JavaScript 和系统命令,从外部来源复制模板时务必确认内容可信。

一份典型的日记模板 `Daily.md` 可以是这样:

```markdown
<% tp.file.title %>

## 今日工作
- 

## 思考与阻塞
- 

## 明日计划
- 
```

周记模板 `Weekly.md` 则在文件顶部预先列出本周七天的链接,后续 AI 总结会用到这些链接:

```markdown
<% tp.file.title %> 周报

## 本周日记
- [[<% tp.date.weekday("YYYY-MM-DD", 1, tp.file.title, "gggg-[W]ww") %>]]
- [[<% tp.date.weekday("YYYY-MM-DD", 2, tp.file.title, "gggg-[W]ww") %>]]
- [[<% tp.date.weekday("YYYY-MM-DD", 3, tp.file.title, "gggg-[W]ww") %>]]
- [[<% tp.date.weekday("YYYY-MM-DD", 4, tp.file.title, "gggg-[W]ww") %>]]
- [[<% tp.date.weekday("YYYY-MM-DD", 5, tp.file.title, "gggg-[W]ww") %>]]
- [[<% tp.date.weekday("YYYY-MM-DD", 6, tp.file.title, "gggg-[W]ww") %>]]
- [[<% tp.date.weekday("YYYY-MM-DD", 0, tp.file.title, "gggg-[W]ww") %>]]

## 本周总结
（AI 生成内容粘贴到此处）
```

Templater 创建日记时会自动展开 `<% ... %>` 中的函数,`tp.date.weekday(...)` 根据周记文件名推算出对应工作日的日期。

## AI 摘要:Obsidian AI Summary

[Obsidian AI Summary](https://github.com/irbull/obsidian-ai-summary) 是这套流程的关键一环。它的工作机制是:

1. 扫描当前笔记中所有的 `[[wikilink]]`;
2. 将所引用笔记的正文拼接后发送给 OpenAI(兼容)API;
3. 用配置好的 prompt 生成摘要,结果显示在弹窗中,**不会改动任何已有笔记**;
4. 用户复制结果粘贴回周记即可。

插件作者在 README 中明确推荐把该插件用于「周报/月报」场景:周记里链接了七天的日记,一键即可生成一篇通顺的周总结。

### 配置要点

- **API Key**:在插件设置中填入 OpenAI API Key(也可指向兼容 OpenAI 接口的本地或第三方服务)。
- **默认 Prompt**:例如「请将以下日记整理为一份 200 字以内的工作周报,分"本周完成""问题与阻塞""下周计划"三部分」。
- **单笔记 Prompt 覆盖**:在笔记的 YAML front matter 中写 `Prompt: ...` 即可对该笔记单独指定 prompt,例如按月报、季报换不同口径。
- **Token 上限**:根据模型上下文窗口合理设置,避免截断。

## 与同类工具的取舍

除上述组合外,Obsidian 社区还有若干相关插件,各自侧重不同:

| 插件 | 作用 | 在本方案中的角色 |
| --- | --- | --- |
| [Periodic Notes](https://github.com/liamcain/obsidian-periodic-notes) | 日/周/月记管理 | 提供周记文件骨架 |
| [Calendar](https://github.com/liamcain/obsidian-calendar-plugin) | 侧边栏日历导航 | 可视化跳转到任意日记/周记 |
| [Templater](https://github.com/SilentVoid13/Templater) | 模板渲染 | 自动生成日期、链接结构 |
| [AI Summary](https://github.com/irbull/obsidian-ai-summary) | 大模型摘要 | 把多篇日记压成一篇周报 |
| Smart Connections / Copilot | 知识库问答、AI 助手 | 适合做更长周期的检索式总结 |

如果团队要求按固定字段(如"工时""需求 ID")上报,可在 Templater 模板里把这些字段做成结构化列表,方便后续脚本或正则提取。

## 几点实践建议

- **日记先结构化,再谈总结**。AI 只能整理已有信息,日记写得越规范,周报质量越高。
- **prompt 即"模板"**。把团队周报的固定段落顺序写进 prompt,生成结果几乎可直接交付。
- **隐私与成本**。日记内容会发送给外部模型,涉及敏感信息时建议使用本地部署的模型(如通过 [Ollama](https://ollama.com/) 提供 OpenAI 兼容接口)。
- **保留人工修订环节**。AI 输出作为草稿,落地前过一遍更稳妥。

## 参考

- [Obsidian AI Summary Plugin](https://github.com/irbull/obsidian-ai-summary) —— 本文方案的核心插件
- [Periodic Notes](https://github.com/liamcain/obsidian-periodic-notes) —— 周/月记管理
- [Calendar Plugin](https://github.com/liamcain/obsidian-calendar-plugin) —— 日历侧边栏
- [Templater](https://github.com/SilentVoid13/Templater) —— 模板与自动化
- [Obsidian 官方网站](https://obsidian.md/)
