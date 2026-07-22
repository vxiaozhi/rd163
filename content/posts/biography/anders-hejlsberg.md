+++
title = "安德斯·海尔斯伯格(Anders Hejlsberg)"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从 Turbo Pascal 到 C# 与 TypeScript,一位编程语言设计师的四十年"
description = "回顾丹麦程序员 Anders Hejlsberg 的职业生涯:他先后打造了 Turbo Pascal、Delphi、C# 与 TypeScript,深刻影响了现代软件开发。"
author = "小智晖"
authors = ["小智晖"]
categories = ["biography"]
tags = ["biography", "Anders Hejlsberg", "C#", "TypeScript", "Delphi", "编程语言"]
keywords = ["Anders Hejlsberg", "C# 之父", "TypeScript", "Turbo Pascal", "Delphi", "编程语言设计师"]
toc = true
draft = false
+++

安德斯·海尔斯伯格(Anders Hejlsberg)是当代最具影响力的编程语言设计师之一。从上世纪 80 年代的 Turbo Pascal,到 90 年代的 Delphi,再到 2000 年之后的 C# 与 TypeScript,他参与或主导设计的语言与开发工具横跨了近四十年的软件工业史。本文按时间线梳理他的主要工作与贡献。

## 早期经历与 PolyData 时期

Hejlsberg 于 1960 年 12 月 2 日出生于丹麦哥本哈根,曾就读于丹麦技术大学(Danmarks Tekniske Universitet,DTU)电气工程专业,但并未完成学位。

在读大学期间,他为 Nascom 微型计算机用汇编语言编写了一个 Pascal 编译器。这款编译器最初以 *Blue Label Software Pascal* 的名称发布,后更名为 *Compas Pascal*,最终定名为 *PolyPascal*,通过他所在的公司 PolyData 销售。这段早期的编译器实现经历,奠定了他后续在语言设计与底层优化上的功底。

## Borland 时期:Turbo Pascal 与 Delphi

1989 年,Hejlsberg 加入位于美国加利福尼亚的 Borland 公司,担任首席工程师。他将自己的 Pascal 编译器授权给 Borland,并在此基础上推动了 **Turbo Pascal** 的持续演进。Turbo Pascal 凭借极快的编译速度和集成的 IDE,成为 80 到 90 年代最受欢迎的 Pascal 开发工具之一。

随后,他作为首席架构师(chief architect)主导了 **Borland Delphi** 的设计与开发。Delphi 在 Object Pascal 的基础上提供了一套完整的快速应用开发(Rapid Application Development,RAD)环境,在 Windows 桌面开发领域影响深远。Hejlsberg 主持完成了 Delphi 1(1995)与 Delphi 2(1996)。

## 加入微软:从 Visual J++ 到 .NET

1996 年,Hejlsberg 从 Borland 跳槽至微软。据公开报道,比尔·盖茨(Bill Gates)亲自参与了这次招募,为了让 Hejlsberg 加盟,微软将签约奖金从最初的 50 万美元提高到 100 万美元,以回应 Borland 的反报价。

加入微软后,他先是参与了 **Visual J++** 与 Windows Foundation Classes(WFC)的开发,这是微软当时的 Java 实现与配套类库。由于 Sun Microsystems 的法律诉讼,Visual J++ 项目最终中止,Hejlsberg 随之转向一个全新的语言项目——C#。

## C# 的诞生与演进

2000 年,微软正式对外发布了 **C#**（读作 "See Sharp",源自乐谱升音记号）;自那时起,Hejlsberg 一直担任 C# 团队的首席架构师。C# 是一门面向对象、类型安全的通用编程语言,与 .NET Framework 和后来的 .NET(Core)运行时紧密绑定,旨在为托管环境提供一门兼具表达力与工程效率的现代语言。

在他的主导下,C# 在过去二十余年里持续引入现代语言特性,例如:

- **LINQ**(Language Integrated Query,2007,C# 3.0),将查询能力直接融入语言;
- **异步编程**(`async`/`await`,2012,C# 5.0),大幅降低了异步代码的编写复杂度;
- **模式匹配**、**可空引用类型**(Nullable Reference Types,C# 8.0)等,使其在表达力和类型安全上不断进化。

C# 不仅是 .NET 平台的首选语言,也通过 Unity、Godot 等引擎广泛用于游戏开发,并通过 Xamarin / .NET MAUI 进入移动开发领域。

## TypeScript:为 JavaScript 带来静态类型

2012 年,Hejlsberg 在微软对外宣布了 **TypeScript**。TypeScript 是 JavaScript 的超集,在保留运行时语义的前提下,为语言引入了可选的静态类型系统与现代化的语言结构(接口、泛型、联合类型等),最终编译为标准的 JavaScript 代码。

```typescript
// 一个简单的 TypeScript 示例:接口与类型注解
interface User {
  id: number;
  name: string;
  email?: string; // 可选属性
}

function greet(user: User): string {
  return `Hello, ${user.name}`;
}

const u: User = { id: 1, name: "Anders" };
console.log(greet(u));
```

TypeScript 很快被主流前端框架与工具链采纳,Angular、Vue 3、React 等生态均提供原生或一等公民级别的支持。如今,TypeScript 已成为大型前端工程与 Node.js 服务端项目的事实标准之一,TypeScript 编译器本身也是用 TypeScript 编写的。

## 职务与荣誉

Hejlsberg 目前担任微软 **Technical Fellow**(技术院士),这是微软内部最高的技术职级之一。在他的职业生涯中,先后获得过以下重要荣誉:

- **2001 年**,获颁 *Dr. Dobb's Excellence in Programming Award*,表彰他在 Turbo Pascal、Delphi、C# 与 .NET Framework 上的贡献;
- **2007 年**,与 C# 语言设计团队成员共同获得微软 *Technical Recognition Award for Outstanding Technical Achievement*。

此外,他还是 *The C# Programming Language* 一书(C# 语言规范的多版本合著作品,Addison-Wesley Professional 出版)的合著者之一。

## 设计哲学

纵观 Hejlsberg 的作品,可以观察到几个一致的设计取向:

1. **强类型与表达力并重**:从 Delphi 的 Object Pascal 到 C#,再到 TypeScript,他倾向于通过类型系统帮助开发者在编译期捕获错误,同时不牺牲语言的灵活性。
2. **注重开发者体验**:Turbo Pascal 与 Delphi 的集成开发环境,以及 C# 与 TypeScript 的工具链(如 IntelliSense、Language Server),都体现出他对开发体验的关注。
3. **务实演进**:C# 与 TypeScript 都是在已有流行语言(Pascal、Java/C++、JavaScript)基础上做"加法",而非另起炉灶,这有利于生态的承接与迁移。

从单人手写汇编编译器,到主导覆盖数百万开发者的现代编程语言,Anders Hejlsberg 的职业轨迹本身就是过去四十年软件工业演进的一个缩影。

## 参考

- [Anders Hejlsberg — Wikipedia](https://en.wikipedia.org/wiki/Anders_Hejlsberg)
- [编程领域的传奇!C#、TypeScript 之父!全世界最顶尖的程序员之一(腾讯云开发者社区)](https://cloud.tencent.com/developer/article/1751937)
- [C# 官方文档 — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/)
- [TypeScript 官方网站](https://www.typescriptlang.org/)
- [TypeScript GitHub 仓库](https://github.com/microsoft/TypeScript)
