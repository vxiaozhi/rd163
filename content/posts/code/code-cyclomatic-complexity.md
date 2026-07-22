+++
title = "详解圈复杂度"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "衡量代码判定结构复杂度的经典指标与计算方法"
description = "介绍圈复杂度的定义、计算公式 V(G) = e - n + 2、与代码覆盖率的关系,以及常用的圈复杂度测量工具。"
author = "小智晖"
authors = ["小智晖"]
categories = ["code"]
tags = ["code", "圈复杂度", "代码质量", "静态分析", "代码度量"]
keywords = ["圈复杂度", "Cyclomatic Complexity", "McCabe", "代码复杂度", "静态代码分析", "V(G)"]
toc = true
draft = false
+++

## 什么是圈复杂度?

圈复杂度（Cyclomatic Complexity）是一种代码复杂度的衡量标准，由 Thomas J. McCabe, Sr. 于 1976 年在论文 *A Complexity Measure*(IEEE Transactions on Software Engineering, SE-2(4): 308-320)中提出，目的是指导程序员写出更具可测性和可维护性的代码。

它可以用来衡量一个模块判定结构的复杂程度，数量上表现为独立路径条数，也可以理解为覆盖所有可能情况最少需要的测试用例数量。

圈复杂度大说明程序代码质量低且难于测试和维护。根据经验，高的圈复杂度与程序出错的可能性之间存在很大关系。

代码覆盖率和圈复杂度有什么关系呢?下面的例子说明:100% 代码覆盖率的单元测试并不代表测试了代码的全部执行路径。

示例程序:

```c
int foo(bool isOK)
{
    const int ZERO = 0;
    int* pInt = NULL;
    if (isOK)
    {
        pInt = &ZERO;
    }
    return *pInt;
}
```

上面代码的圈复杂度为 2。如果只测试一种情况 `foo(true)`,结果是测试通过，并且达到 100% 的代码覆盖率;但测试 `foo(false)` 就会失败(因为 `pInt` 未被赋值，解引用空指针)。可见圈复杂度非常重要，良好的测试应该覆盖程序的所有执行路径，即用例的个数至少应该等于方法的圈复杂度。

## 意义

- 提前发现代码缺陷。
- 具备更好的可测性和可维护性。

## 圈复杂度的计算方法

通常采用的计算方法为点边计算法（此外还有节点判定法）,计算公式为:

```text
V(G) = e - n + 2
```

其中:

- `e` 表示控制流图中的边数（edges）;
- `n` 表示控制流图中的节点数（nodes）。

完整公式为 `V(G) = e - n + 2p`,其中 `p` 为连通分量数;对于单个函数 `p = 1`,故化简为上式。圈复杂度也等于判定节点数加 1，即 `V(G) = P + 1`。

按 McCabe 的经验建议，模块的圈复杂度应控制在 10 以内，超过该值往往意味着代码难以测试和维护。

## 降低圈复杂度的方法

- 提取函数：将复杂的判定逻辑拆分到独立的子函数中。
- 简化条件表达式：合并重复判定，用早返回（guard clause）替代深层嵌套。
- 表驱动法：用查找表替代冗长的 `if/else` 或 `switch` 分支。
- 多态替代分支：利用继承或多态替代基于类型的条件分支。
- 算法替换：选用更合适的数据结构与算法，从根本上减少判定路径。

## 圈复杂度计算工具

### 1. [lizard](https://github.com/terryyin/lizard)

Lizard 是一个可扩展的静态代码分析工具，专注于圈复杂度分析，无需关心 C/C++ 头文件或 Java 导入，支持 25 种以上主流语言（C/C++、Java、JavaScript、Python、Go、Swift、Objective-C、Rust、TypeScript 等）。它按函数统计以下指标:

- **NLOC**:不含注释的代码行数;
- **CCN**:圈复杂度;
- **token count**:函数的 token 数;
- **parameter count**:函数的参数个数。

安装:`pip install lizard`,可对 CCN、函数长度、参数个数等设置告警阈值，常用于 CI 流水线。

### 2. [OCLint](https://github.com/oclint/oclint)

OCLint 是一个针对 C、C++ 和 Objective-C 的静态代码分析工具，用于提高代码质量、减少缺陷。它通过检查源代码来寻找编译器无法发现的潜在问题，例如:

- 可能的 bug:空的 `if`/`else`/`try`/`catch`/`finally` 语句;
- 未使用的代码：未使用的局部变量和参数;
- 复杂的代码：高圈复杂度、高 NPath 复杂度和高 NCSS;
- 冗余代码：冗余的 `if` 语句和无用的括号;
- 代码坏味道：过长的方法和过长的参数列表;
- 不良实践：反向逻辑和参数重新赋值。

### 3. [CppNcss](https://cppncss.sourceforge.net/)

CppNcss 通过静态分析 C++ 源代码提供多种度量指标，主要用于评估可维护性，聚焦于评审重点并指示重构机会。它主要报告两项指标:

- **NCSS**(Non Commenting Source Statements):非注释源语句数，排除注释和空行;
- **CCN**(Cyclomatic Complexity Number):圈复杂度。

可输出文本或 XML，并附带 XSL 样式表转换为 HTML。该项目最后发布于 2007 年，目前已不再维护，使用前需评估其对新版 C++ 标准的兼容性。

### 4. [CCCC (C and C++ Code Counter)](https://github.com/sarnold/cccc)

CCCC 是一个针对 C、C++ 和 Java 的源码计数与度量工具，生成 HTML 或 XML 报告，包含软件复杂度相关度量。最初由 Tim Littlefair 作为学术研究项目的概念验证开发，目前由 Stephen L. Arnold 维护。

## 参考

- [详解圈复杂度 — Kaelzhang](https://kaelzhang81.github.io/2017/06/18/%E8%AF%A6%E8%A7%A3%E5%9C%88%E5%A4%8D%E6%9D%82%E5%BA%A6/)
- [圈复杂度详解以及解决圈复杂度常用的方法](https://blog.csdn.net/u010684134/article/details/94410027)
- [Cyclomatic complexity — Wikipedia](https://en.wikipedia.org/wiki/Cyclomatic_complexity)
- McCabe, T. J. (1976). *A Complexity Measure.* IEEE Transactions on Software Engineering, SE-2(4), 308-320.
