+++
title = "Zig 语言简介"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "一门面向系统编程、对标的 C 的现代编译型语言"
description = "Zig 是一门通用的系统编程语言，由 Andrew Kelley 设计，目标是替代 C，提供显式内存管理、编译期元编程和开箱即用的交叉编译。本文介绍其设计哲学、核心特性与典型场景。"
author = "小智晖"
authors = ["小智晖"]
categories = ["zig"]
tags = ["编程语言", "zig", "系统编程", "C 语言", "编译期", "交叉编译"]
keywords = ["Zig 语言", "系统编程语言", "comptime", "C 语言替代", "交叉编译", "Andrew Kelley"]
toc = true
draft = false
+++

[Zig](https://ziglang.org/) 是一门通用的编程语言和配套工具链，官方用三个词概括其设计目标：**robust（健壮）、optimal（最优）、reusable（可重用）**。它由 Andrew Kelley 主导设计，第一份公开提交可以追溯到 2015 年，目前由 2020 年成立的非营利组织 Zig Software Foundation（ZSF）维护。截至本文更新时，最新稳定版本为 0.16.0（仍处于 1.0 之前的快速迭代期，API 尚未冻结）。

从定位看，Zig 是一门**底层的高级语言**——它和 C 处于同一个生态位，承担系统编程、嵌入式、编译器底层、高性能服务等场景，但用现代语言的语法和工程实践重新打磨了 C 留下的旧问题。维基百科将其归纳为「命令式、通用、静态类型、编译型的系统编程语言」，并明确「旨在替代 C」。

## 为什么需要又一门系统语言

C 语言屹立数十年，靠的是「贴近硬件、零运行时开销、可移植」三点；但它的代价同样显著：预处理器宏、隐式类型转换、未定义行为、手工内存管理带来的悬垂指针与内存泄漏、缺少模块化与错误处理机制。大多数现代语言（Rust、Go、Swift 等）选择在 C 之上抽象出更厚的运行时或更复杂的类型系统来缓解这些问题。

Zig 走了另一条路：**不引入隐藏机制，把所有显式的成本暴露给程序员，同时用语言内置能力替代 C 中需要靠约定或外部工具才能做到的事情**。它没有垃圾回收（GC）、没有宏、没有预处理器、没有运算符重载、没有隐式函数调用；但提供了编译期求值、显式分配器、错误作为值、可选类型等现代特性。结果是代码「所见即所执行」，调试时不用先去理解语言本身。

## 核心设计哲学

官方文档把 Zig 的特性归纳为几条相互呼应的原则。

### 没有隐藏的控制流

如果一段代码看起来在调用 `foo()` 再调用 `bar()`，那它真的就是按顺序执行这两次调用——没有运算符重载会在你访问字段时偷偷执行函数，没有异常会跳过 `bar()`，没有析构函数会在作用域结束时隐式触发。所有控制转移都通过显式关键字（`if`、`while`、`for`、`switch`、`return`、`try`、`catch`、`orelse`、`defer`）完成。

### 没有隐藏的内存分配

Zig 标准库中**任何需要分配内存的函数都必须显式接收一个分配器（allocator）参数**。这意味着同一个标准库既能用于完整的用户态程序，也能用于裸机（freestanding）环境——因为没有哪个底层函数会偷偷去调用 `malloc`。配合 `defer` 与 `errdefer` 关键字，资源释放变得明确且可静态检查：

```zig
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const buf = try allocator.alloc(u8, 1024);
    defer allocator.free(buf);
    // ...
}
```

### 错误即值

Zig 没有异常。函数返回类型前的 `!` 表示它可能返回错误，例如 `!void`。调用方要么用 `try` 把错误向上传播，要么用 `catch` 显式处理：

```zig
const value = try parseNumber(str);          // 出错则向上 return
const value = parseNumber(str) catch 0;      // 出错则用默认值
```

对 `error` 集合做 `switch` 时，编译器会强制你覆盖所有分支，漏掉任何一个都编译不过。错误返回追踪（Error Return Traces）则在不付出栈展开代价的前提下，展示错误是从哪条调用链传播过来的。

### 可选类型取代空指针

Zig 中**普通指针不能为 null**——`@ptrFromInt(0x0)` 直接是编译错误。任何可能"缺失"的值必须用 `?T` 表示为可选类型，并通过 `orelse`、`if`/`while` 捕获语法解包：

```zig
const maybe_name: ?[]const u8 = lookup();
if (maybe_name) |name| {
    std.debug.print("got {s}\n", .{name});
} else {
    std.debug.print("no name\n", .{});
}
```

这一设计从类型系统层面消灭了 C 中最常见的"对空指针解引用"类错误。

## 编译期元编程（comptime）

`comptime` 是 Zig 最具代表性的特性。任何函数、变量、代码块都可以在 `comptime` 上下文中执行，由编译器在构建时求值。由于类型本身也是编译期已知的值，**泛型不过是一个"返回 type 的函数"**：

```zig
fn List(comptime T: type) type {
    return struct {
        items: []T,
        len: usize,
    };
}

const IntList = List(i32);
const StrList = List([]const u8);
```

更进一步，`@typeInfo` 提供了对任意类型的反射能力，格式化打印（`std.fmt`）就是完全用 Zig 自身实现的，而不是像 C 的 `printf` 或 Rust 的 `format!` 那样硬编码进编译器。这种"语言能力即普通库"的思路，使得 Zig 在不引入宏系统的前提下，达到了通常只有宏才能实现的表达力。

## 工具链：C 编译器与开箱即用的交叉编译

Zig 不只是语言，还是一套完整的工具链。其中两项能力尤其值得关注。

**作为 C/C++ 编译器**：Zig 内置了基于 LLVM/Clang 的 C/C++ 编译能力，可以零依赖地充当系统的 `cc`：

```bash
zig build-exe hello.c -lc      # 直接编译 C 源码
zig cc hello.c -o hello        # 也可以当作 cc 使用
```

通过 `@cImport`，Zig 还能直接导入 C 头文件并使用其中的类型、函数甚至内联函数，无需手写绑定。官方的口号是「Zig 比 C 自己更擅长使用 C 库」。

**交叉编译是一等公民**：无需安装 MinGW、musl-cross 或任何额外工具链，一条 `-target` 参数就能为支持的目标生成原生可执行文件：

```bash
zig build-exe hello.zig -target aarch64-linux-gnu
zig build-exe hello.zig -target x86_64-windows-gnu
zig build-exe hello.zig -target wasm32-freestanding
```

Zig 发行包捆绑了 97+ 个目标的 libc、compiler-rt、libunwind、libcxx、libtsan，整体压缩后仅约 50 MiB。这对嵌入式分发、CI 构建矩阵、静态发布都极有吸引力。

## 构建系统与四种构建模式

`zig init` 会在项目根目录生成 `build.zig`（构建脚本）与 `build.zig.zon`（包元数据），构建逻辑本身是用 Zig 写的，跨平台行为一致。`zig build`、`zig build test`、`zig build run` 是日常命令。

性能与安全的权衡通过四种构建模式控制，可以一路细化到作用域级别：

| 模式 | 特点 |
| --- | --- |
| `Debug` | 默认，运行时安全检查全开，速度最慢，便于调试 |
| `ReleaseSafe` | 优化开启，同时保留运行时安全检查 |
| `ReleaseFast` | 全速优化，关闭运行时安全检查 |
| `ReleaseSmall` | 优化二进制体积，适合资源受限场景 |

整数溢出在所有模式下都是编译期错误；在带安全检查的模式下，运行时非法行为会触发 panic 并打印栈轨迹。

## 什么时候该考虑 Zig

从本质上看，Zig 适合以下几类场景：

- **嵌入式与裸机开发**：可选链接 libc、显式分配器、对 freestanding 友好的标准库。
- **对延迟和确定性有极高要求的服务**：无 GC、无运行时隐藏分配，行为可预测。
- **已有 C/C++ 代码库的渐进式现代化**：可以用 Zig 作为更顺手的 C 编译器，再逐步把模块替换为 Zig。
- **跨平台工具与发布物**：单二进制交叉编译，简化 CI。
- **想避开复杂类型系统、又想要现代工程实践的开发者**：相比 Rust，Zig 学习曲线更平缓，心智负担更低。

如果你正在做嵌入式开发，或是对运行速度与可预测性有高要求，又不愿意承担高级语言的运行时成本与复杂类型系统的认知负担，Zig 是一个值得放进工具箱的选项。需要注意的是，1.0 之前的 Zig 仍在快速演进，标准库 API（尤其是 I/O 与文件系统相关）在不同版本之间会有破坏性变更，生产使用前请锁定具体版本并关注 release notes。

## 参考

- [Zig 官方网站](https://ziglang.org/)
- [Zig 语言概述（官方）](https://ziglang.org/learn/overview/)
- [Zig 代码示例（官方）](https://ziglang.org/learn/samples/)
- [Zig GitHub 仓库](https://github.com/ziglang/zig)
- [Zig 语言圣经（中文社区）](https://course.ziglang.cc/)
- [Zig Software Foundation](https://ziglang.org/zsf/)
