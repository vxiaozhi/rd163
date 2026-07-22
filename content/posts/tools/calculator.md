+++
title = "计算器"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从命令行 bc 到全平台开源计算器盘点"
description = "盘点命令行、桌面与 Web 端的开源计算器，涵盖 bc、Qalculate!、Windows Calculator 等项目及其背后的表达式求值原理。"
author = "小智晖"
authors = ["小智晖"]
categories = ["tools"]
tags = ["工具", "计算器", "命令行", "bc", "表达式求值"]
keywords = ["计算器", "bc 命令行计算器", "Qalculate", "Windows Calculator", "表达式求值", "逆波兰表达式"]
toc = true
draft = false
+++

计算器（calculator）几乎是每台操作系统都会预装的工具。看似简单，背后却涉及一套成熟的表达式求值算法，而具体形态又从命令行、桌面到 Web 各有取舍。日常开发中，能熟练用一行命令算清一个表达式、做一次单位换算或进制转换，往往比反复切到鼠标点击 GUI 更高效。本文先聊一聊命令行里最常驻的 `bc`，再扩展到全平台的开源桌面/Web 计算器，以及支撑它们的表达式求值原理。

## 命令行计算器：bc

`bc`（basic calculator）是一种任意精度（arbitrary precision）的计算器语言，几乎在所有 Unix-like 系统中默认可用，并由 POSIX 标准定义。在 Linux/macOS 上无需额外安装，直接 `bc` 即可进入交互式 REPL。

### 基本用法

```bash
# 一次性计算
echo '2 ^ 10' | bc
# 输出：1024

# 设置小数位数（scale），任意精度除法
echo 'scale=30; 1 / 7' | bc
# 输出：.142857142857142857142857142857

# 加载标准数学库（-l），计算平方根
echo 'sqrt(2)' | bc -l
# 输出：1.41421356237309504880

# 进制转换：十进制转十六进制
echo 'obase=16; 255' | bc
# 输出：FF

# 二进制输入转十进制
echo 'ibase=2; 1010' | bc
# 输出：10
```

常用选项：

| 选项 | 含义 |
| --- | --- |
| `-l` | 加载标准数学库（同时把 `scale` 设为 20） |
| `-q` | 安静模式，不打印 GNU 欢迎信息 |
| `-i` | 强制进入交互模式 |
| `-s` | 严格遵循 POSIX 标准 |
| `-w` | 对非 POSIX 扩展给出警告 |

`bc` 提供三个核心内置变量：`scale`（小数位数）、`ibase`（输入进制）、`obase`（输出进制），再加上 `if`/`while`/`for` 与 `define` 自定义函数，足以承担一段小型数值脚本的编写。需要提醒的是，POSIX 标准库不包含 `sqrt`、`sin`、`cos` 等函数，必须通过 `-l` 加载 GNU 扩展数学库后才能使用。

### 进阶：手写阶乘

```bash
cat <<'EOF' | bc -q
define f(n) {
  if (n <= 1) return 1
  return n * f(n - 1)
}
f(20)
EOF
# 输出：2432902008176640000
```

由于 `bc` 采用任意精度整数，结果不会像 C/Python 那样溢出（除非超过内存限制），适合做组合数、大整数运算。

## 表达式求值：背后的算法

GUI 计算器与命令行计算器都绕不开同一个问题：**如何把人类书写的算式（infix expression，中缀表达式）求值**。OI Wiki 的[表达式求值](https://oi-wiki.org/misc/expression/)一页对此有系统的归纳，要点如下。

### 三种表示法

同一棵表达式树，按不同的遍历顺序会得到三种写法：

- **前缀表达式**（Prefix / Polish notation）：运算符在操作数前，例如 `+ 1 2`。
- **中缀表达式**（Infix）：运算符在操作数中间，例如 `1 + 2`，是人类日常使用的形式。
- **后缀表达式**（Postfix / Reverse Polish Notation，RPN）：运算符在操作数后，例如 `1 2 +`。

后缀表达式的关键优势是**不需要括号**也能唯一确定运算顺序，便于计算机直接处理。早期惠普（HP）系列科学计算器（如 HP-35、HP-12C）即采用 RPN 输入，正是因为它能跳过中缀转后缀的解析步骤。

### 调度场算法

经典做法是 Dijkstra 提出的**调度场算法（Shunting Yard Algorithm）**，使用两个栈（操作数栈与运算符栈）将中缀表达式转换为后缀表达式，再通过单栈完成求值。其大致流程：

1. 遇到数字直接压入操作数栈。
2. 遇到左括号压入运算符栈。
3. 遇到右括号，不断弹出运算符并参与计算，直到匹配到左括号。
4. 遇到运算符，先弹出栈中优先级 **大于等于**（对右结合运算符如 `^` 则为 **大于**）当前运算符的运算符参与计算，再压入当前运算符。
5. 扫描结束后，把栈中剩余运算符依次弹出。

整段流程对长度为 n 的表达式时间复杂度是 O(n)，这也是大多数通用计算器底层使用的算法骨架。

### 浮点精度

对于浮点运算，计算器还要决定采用 IEEE 754 浮点还是任意精度有理数。像 Windows Calculator 在基础运算上选择"无限精度"以避免 `0.1 + 0.2` 这类经典误差，而 `bc` 则通过 `scale` 由用户显式控制小数位数。

## 桌面计算器：Windows Calculator

[Windows Calculator](https://github.com/microsoft/calculator) 是微软官方计算器应用的开源仓库，遵循 MIT 协议，主要使用 C++/C# 编写，基于 UWP（Universal Windows Platform）与 XAML 构建。它随 Windows 10/11 默认安装，GitHub 上的源码与系统内置版本基本一致。

提供的主要模式：

- **Standard**：基本四则运算，立即求值（immediate execution）。
- **Scientific**：科学计算，遵循运算符优先级。
- **Programmer**：开发者模式，支持 HEX/DEC/OCT/BIN 进制互转与位运算。
- **Date Calculation**：日期差与日期加减。
- **Converter**：长度、重量、温度、货币等单位换算；货币汇率在零售版本中由 Bing 数据提供。

基础四则运算部分采用任意精度算术，避免浮点累加误差，这一点在仓库 README 中有明确说明。Graphing（图形计算器）模式在路线图中，但因图形引擎为闭源组件，社区构建版本仅提供占位 API，无法实际绘图。

## Web 与中文场景的开源项目

### CalculatorSoup：综合在线计算器

[CalculatorSoup](https://www.calculatorsoup.com/) 是一个免费的在线计算器合集，所有计算逻辑使用 JavaScript/HTML/CSS 编写并在浏览器本地执行，无需后端交互。按类别覆盖数学、金融、统计、几何、物理、化学、单位换算等多个领域，部分页面还会附带分步求解过程，便于核对公式。其形态接近一本"在线公式手册"，适合偶尔需要一次性计算（如贷款月供、几何面积、显著数字处理）的场景。

### 中国亲戚关系计算器

[mumuy/relationship](https://github.com/mumuy/relationship)（约 3.7k stars，MIT 协议）是一个非常经典的中文场景计算器：输入"妈妈的妈妈的哥哥"这类关系链，输出"舅外公"等正确称谓。除默认的称谓查找外，还支持：

- **Chain 模式**：解释某个称谓指的是什么关系。
- **Pair 模式**：计算两个 relatives 之间的相互称谓。
- **反向查找**：对方该如何称呼我。
- **整句解析**：如"舅妈如何称呼外婆？"。

它体现了"计算器"概念外延到语义/规则引擎的一个有趣方向，代码以 JavaScript 实现，可以直接嵌入网页。

### 2019 个税计算器

[YutHelloWorld/personal-income-tax-calculator](https://github.com/YutHelloWorld/personal-income-tax-calculator) 基于 React + Material-UI + Redux 构建，支持 PWA 与响应式布局，针对 2019 版新个税规则计算应纳税额。仓库未附带 LICENSE 文件（默认未授予开源授权，引用或二次开发时需联系作者），项目活跃度较低，仅适合作为学习 React 税务计算的参考实现。税法规则每年都可能调整，作为生产工具使用前需要核对最新税率表与起征点。

### JavaScript 版 Windows 10 计算器

[seaswalker/js_calculator](https://github.com/seaswalker/js_calculator)（Apache-2.0）用 JavaScript 模仿 Windows 10 计算器的界面与交互，实现了 Standard、Science、Programmer 三种模式。项目体量很小（约 63 stars，18 commits），适合作为前端练手项目阅读：它把"按钮事件 → 中缀表达式 → 求值 → 显示"的整条链路在 Web 端复刻了一遍，可以与前文提到的调度场算法对照阅读。

## 选型建议

| 场景 | 推荐 |
| --- | --- |
| 终端脚本里做一次进制/精度计算 | `bc`，几乎零依赖 |
| 带单位换算、物理常数、符号运算 | [Qalculate!](https://qalculate.github.io/)（`qalc` 为 CLI 版本） |
| Windows 桌面日常计算 | Windows Calculator（系统自带） |
| 中文家庭称谓查询 | [relationship](https://github.com/mumuy/relationship) |
| 一次性在线公式计算 | [CalculatorSoup](https://www.calculatorsoup.com/) |

命令行计算器的优势在于可组合、可脚本化；桌面计算器胜在直观、带历史记录与单位换算；Web/语义计算器则把"计算"延伸到规则匹配领域。三者并非互斥，了解它们的边界与底层算法，能在合适的场景里顺手取用。

## 参考

### 命令行与算法

- [GNU bc - Arbitrary Precision Calculator Language](https://www.gnu.org/software/bc/)
- [POSIX.1-2017 bc 定义（Open Group）](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/bc.html)
- [OI Wiki：表达式求值](https://oi-wiki.org/misc/expression/)

### 桌面与 Web 计算器

- [Windows Calculator（微软官方开源）](https://github.com/microsoft/calculator)
- [CalculatorSoup 在线计算器合集](https://www.calculatorsoup.com/)
- [JavaScript 模仿 Windows 10 计算器（seaswalker/js_calculator）](https://github.com/seaswalker/js_calculator)

### 中文场景计算器

- [中国亲戚关系计算器（mumuy/relationship）](https://github.com/mumuy/relationship)
- [2019 个税计算器（YutHelloWorld）](https://github.com/YutHelloWorld/personal-income-tax-calculator)