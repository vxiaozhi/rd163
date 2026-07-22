+++
title = "函数调用关系绘制"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "用 GNU cflow 静态分析 C 源码生成调用图"
description = "介绍 GNU cflow 这款 C 语言静态分析工具的安装、基本用法、直接图/反向图/交叉引用三种输出模式及常见进阶技巧。"
author = "小智晖"
authors = ["小智晖"]
categories = ["code"]
tags = ["code", "cflow", "C语言", "静态分析", "call graph"]
keywords = ["cflow", "函数调用图", "C语言", "静态分析", "call graph", "GNU"]
toc = true
draft = false
+++

## 简介

[cflow](https://www.gnu.org/software/cflow/) 是 GNU 项目维护的一款 C 语言静态分析（static analysis）工具，能够扫描源码并生成函数之间的调用关系图（call graph）。它不需要运行程序，仅依赖源代码本身，因此非常适合用于梳理陌生代码库、排查遗留项目或为代码写文档。

cflow 主要能产出三类信息：

- **直接图（direct graph）**：默认输出，以 `main` 为根，递归展开它调用的所有函数，是一棵自顶向下的调用树。
- **反向图（reverse graph）**：与直接图方向相反，以某个函数为焦点，反向追溯它的所有调用者，由若干子图组成。
- **交叉引用列表（cross-reference）**：列出文件中出现的每个符号的定义位置和所有引用位置。

由于直接图/反向图都呈树状，文档中也常称之为「树」。工具还提供了对输出符号的精细控制，可以省略不感兴趣的符号、控制缩进与编号，便于聚焦关键路径。

- 官网：https://www.gnu.org/software/cflow/
- 下载（FTP 镜像）：https://ftp.gnu.org/gnu/cflow/
- 在线手册：https://www.gnu.org/software/cflow/manual/

截至本文撰写时，cflow 最新版本为 **1.8**（2025 年 7 月发布）。

## 安装

主流 Linux 发行版均可直接通过包管理器安装：

```bash
# Debian / Ubuntu(官方源包名为 cflow)
sudo apt install cflow

# Fedora / RHEL / CentOS
sudo dnf install cflow

# Arch Linux（AUR）
yay -S cflow

# macOS（Homebrew）
brew install cflow
```

如需使用最新版本或自定义路径，可以从 FTP 站点下载源码编译：

```bash
wget https://ftp.gnu.org/gnu/cflow/cflow-1.8.tar.gz
tar xf cflow-1.8.tar.gz
cd cflow-1.8
./configure && make && sudo make install
```

安装完成后执行 `cflow --version` 验证。

## 快速上手

cflow 最基本的用法是把一个或多个 C 源文件作为参数传入。以手册中的经典示例 `whoami.c` 为例：

```bash
cflow whoami.c
```

默认会得到一张直接图：

```
main() <int main (int argc,char **argv) at whoami.c:26>:
    fprintf()
    who_am_i() <int who_am_i (void) at whoami.c:8>:
        getpwuid()
        geteuid()
        getenv()
        fprintf()
        printf()
```

输出约定：

- 每一行以函数名加 `()` 开头；自定义函数在尖括号 `<...>` 内附上**签名与文件位置**。
- 末尾带冒号 `:` 表示该函数还会继续调用其他函数，下一级通过缩进（默认 4 个空格）表示嵌套层级。
- 库函数（如 `fprintf`、`getenv`）只显示名字，因为它们没有在输入源码中定义。

如果一次分析多个文件，建议加 `--` 分隔，避免文件名被误识别为选项：

```bash
cflow -- main.c utils.c parser.c
```

## 输出模式

### 直接图（默认）

直接图回答「谁调用了谁」的问题，是 cflow 的默认输出。当源码中存在多个顶层函数且没有 `main` 时，可以用 `--main`（简写 `-m`）指定从某个函数开始绘制：

```bash
cflow --main who_am_i whoami.c
```

```text
who_am_i() <int who_am_i (void) at whoami.c:8>:
    getpwuid()
    geteuid()
    getenv()
    fprintf()
    printf()
```

与之相对的 `--target` 选项用于设置**终止符号**——遇到该函数就不再继续下钻，适合在庞大的调用链里截取片段。`--all`（`-A`）则一次性输出所有顶层函数的子图；连续两次使用 `--all` 时，会扩展到所有全局函数。如果不希望对 `main` 做特殊处理，可以加上 `--no-main`。

### 反向图

反向图回答「谁调用了它」的问题，通过 `--reverse`（`-r`）开启：

```bash
cflow --reverse whoami.c
```

反向图由若干子图组成，每个子图以某个函数为根，反向列出它的所有调用者。原始输出存在大量重复——同一个被调用函数的子图会在每个调用点完整重画一次。配合 `--brief`（`-b`）可以折叠重复子图，仅用 `[see N]` 引用首次出现的位置：

```bash
cflow --brief --reverse whoami.c
```

`[see N]` 中的 `N` 是行号，需要再加 `--number`（`-n`）来打开行号输出，方便在大图中快速跳转定位：

```bash
cflow --number --brief --reverse whoami.c
```

注意 `--brief` 与 `--number` 在直接图和反向图中都生效，并非反向图专属。

### 交叉引用

加上 `--xref`（`-x`）后，cflow 不再画树，而是输出每个符号的「定义 + 所有引用位置」列表。例如：

```text
printdir * d.c:42 void printdir (int level,char *name)
printdir   d.c:74
printdir   d.c:102
```

约定：

- 带星号 `*` 的行是符号**定义**点，紧随其后是该符号的完整声明。
- 不带星号的行是符号的**引用**点。

哪些类别的符号会进入列表由 `--include` 选项控制，除了函数之外，还可以选择性地纳入静态符号、typedef 类型名等。

## 常用选项速查

| 选项 | 作用 |
|------|------|
| `-m NAME`, `--main=NAME` | 以函数 `NAME` 为根开始绘制 |
| `-r`, `--reverse` | 输出反向图 |
| `-b`, `--brief` | 折叠重复子图，用 `[see N]` 引用 |
| `-n`, `--number` | 每行前置行号，便于引用跳转 |
| `-x`, `--xref` | 输出交叉引用列表 |
| `-A`, `--all` | 为所有顶层函数生成图；重复两次扩展到所有全局函数 |
| `--target=NAME` | 不下钻到 `NAME` 之下 |
| `--no-main` | 取消对 `main` 的特殊处理 |
| `-i SPECS`, `--include=SPECS` | 控制纳入的符号类别(`_` 表示名字以下划线开头的符号、`s` 表示静态符号、`t` 表示 typedef、`x` 表示数据符号等) |
| `--omit-symbol-names` | 隐藏签名中的函数名 |
| `--omit-arguments` | 隐藏签名中的参数列表 |
| `-o FILE` | 把输出写入文件 `FILE` |
| `-I DIR` | 把 `DIR` 加入头文件搜索路径 |

`--omit-symbol-names` 与 `--omit-arguments` 适合在仅关心拓扑结构、不需要关注具体签名的场景下精简输出。

## 进阶技巧

### 与构建系统协作

cflow 只做语法层面的静态分析，因此必须让它看到与正式编译一致的预处理环境，否则 `#ifdef` 分支、宏展开可能与分析结果不一致。常见做法是把 Makefile 中的 `CFLAGS`、`CPPFLAGS` 直接透传：

```bash
cflow -I include -I src -DHAVE_CONFIG_H $(wildcard src/*.c)
```

对于使用 CMake 或 Bear 的项目，可以先抓取 `compile_commands.json` 再喂给 cflow，保证头文件路径与宏定义齐全。

### 输出到文件并渲染

cflow 默认输出纯文本树,但自 1.1 起就**原生支持 DOT 输出格式**,无需外挂脚本转换:

```bash
# 把调用关系保存为文本树
cflow --number main.c > callgraph.txt

# 直接输出 Graphviz DOT 格式,再用 dot 渲染成图片
cflow --format=dot main.c | dot -Tsvg -o callgraph.svg
# 简写: cflow -f dot main.c | dot -Txlib
```

`--format`(`-f`)既支持默认的 `tree`(纯文本树),也支持 `dot`(Graphviz)。配合 [Graphviz](https://graphviz.org/) 的 `dot` 即可渲染为 SVG/PNG,方便嵌入技术文档。如果对默认 DOT 样式不满意,也可以用 Python/awk 二次处理 cflow 的文本树输出,自定义节点与边的样式。

### 排查「为何某函数没出现」

如果分析结果中缺了某个函数，通常有三种原因：

1. 该函数是静态函数,但 `--include` 没有打开 `s` 类别(注意:`s` 才表示静态符号,`_` 表示名字以下划线开头的符号);
2. 该函数受 `#ifdef` 包裹，预处理时被剔除了；
3. 它确实没有任何调用路径连到根函数，是死代码（dead code）候选。

反向图（`cflow -r`）和交叉引用（`cflow -x`）是定位第三种情况的好帮手。

## 局限性

cflow 专注于 C 语言，且只做静态分析，使用时需要注意：

- **不支持 C++**。C++ 项目可改用 Doxygen（开启 `CALL_GRAPH = YES`）、Clang AST 或 Codeviz。
- **函数指针、`dlopen`、虚表分发无法精确解析**，输出中通常只能显示为未解析的间接调用。
- **预处理敏感**。需要正确的 `-I`、`-D` 参数，否则结果可能与实际编译不一致。
- **递归与互递归**会在树中循环出现，需要靠 `--brief` 等选项控制规模。

## 参考

- [GNU cflow 官方主页](https://www.gnu.org/software/cflow/)
- [GNU cflow 在线手册](https://www.gnu.org/software/cflow/manual/)（含 Quick Start、Direct and Reverse、Cross-References、ASCII Tree 等章节）
- [cflow 下载目录（FTP）](https://ftp.gnu.org/gnu/cflow/)
- [Graphviz 官网](https://graphviz.org/)
- [使用 cflow 绘制函数的调用图](https://blog.csdn.net/qq_23599965/article/details/88839012)