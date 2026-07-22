+++
title = "x86 汇编语言"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "机器码、指令编码与反汇编速查"
description = "整理 x86/x64 汇编的常用机器码、指令编码规则,以及 objdump、ndisasm 等反汇编工具的常用参数与在线资源。"
author = "小智晖"
authors = ["小智晖"]
categories = ["asm"]
tags = ["汇编", "asm", "x86", "逆向工程", "工具"]
keywords = ["x86 汇编", "机器码", "指令编码", "objdump", "反汇编"]
toc = true
draft = false
+++

x86 汇编是贴近硬件底层的编程接口，在性能调优、漏洞分析、逆向工程（reverse engineering）、shellcode 编写和操作系统内核开发中经常用到。本文整理日常工作中最常用的速查内容：机器码与助记符的对应、指令编码规则，以及反汇编工具的常见用法。

## Intel 语法与 AT&T 语法

x86 汇编主要有两种书写风格，在阅读反汇编结果或编写代码时需要先分清:

| 特性 | Intel 语法 | AT&T 语法 |
| --- | --- | --- |
| 操作数顺序 | `mov dst, src` | `mov src, %dst` |
| 寄存器前缀 | 无 | `%`(如 `%rax`) |
| 立即数前缀 | 无 | `$`(如 `$0x10`) |
| 注释 | `;` | `;` 或 `#` |
| 典型工具 | NASM、MASM、Intel 手册 | GCC、GAS、objdump 默认输出 |

GNU 工具链（objdump、GDB、GAS）默认使用 AT&T 语法。如果你更熟悉 Intel 风格，大多数工具都支持切换:

```bash
# objdump 切换到 Intel 语法
objdump -d -M intel /bin/ls

# GDB 切换到 Intel 语法
(gdb) set disassembly-flavor intel
```

## 指令编码：从机器码到助记符

x86 是变长指令集，指令长度从 1 字节到 15 字节不等。一条典型指令由若干前缀、操作码（opcode）、ModR/M 字节、SIB 字节、位移和立即数组合而成。其中 **ModR/M 字节**用于指定寻址方式与寄存器操作数，它由三部分构成:

```
  7   6   5   4   3   2   1   0
+-------+-----------+-----------+
|  Mod  |  Reg/Op   |   R/M     |
+-------+-----------+-----------+
   2 位      3 位        3 位
```

- **Mod**:决定 R/M 字段是寄存器直接寻址(`11`)还是内存寻址(`00`/`01`/`10`,后两者带位移)。
- **Reg/Op**:通常是寄存器编号，或者作为 opcode 的扩展( group 指令，如 `FF /4` 中的 `/4`)。
- **R/M**:寄存器或内存操作数编号。

### 示例:`jmp rax` 的编码 `FF E0`

以原文提到的 `FF E0`(`jmp rax`)为例，逐位拆解:

- **`FF`** 是 Group 5 的 opcode。`FF` 本身并不能确定具体操作，需要 ModR/M 中的 Reg/Op 字段来细分:`/4` 表示 JMP,`/5` 表示 JMP far,`/6` 表示 PUSH 等。
- **`E0`** 的二进制是 `11 100 000`:
  - `Mod = 11` → 操作数为寄存器
  - `Reg/Op = 100` (= 4) → 选中 `JMP r/m64`(near jump，绝对间接)
  - `R/M = 000` → 在 64 位模式下对应 **RAX**

因此 `FF E0` 在 64 位（long mode）下解码为 `jmp rax`;在 32 位模式下同样这两个字节解码为 `jmp eax`(默认操作数大小不同)。无需 REX 前缀，因为 RAX 已经是默认的寄存器 0。

类似地,`FF E1` 是 `jmp rcx`,`FF E2` 是 `jmp rdx`,只需修改 R/M 字段。

### JMP 指令的常见 opcode

根据 Intel SDM Vol.2,JMP 指令有多种编码形式:

| Opcode | 助记符 | 说明 |
| --- | --- | --- |
| `EB cb` | `jmp rel8` | 短跳转，8 位有符号相对位移（±127 字节） |
| `E9 cw` | `jmp rel16` | 近跳转，16 位相对位移 |
| `E9 cd` | `jmp rel32` | 近跳转，32 位相对位移（64 位模式也使用） |
| `FF /4` | `jmp r/m16/32/64` | 近跳转，绝对间接（通过寄存器或内存） |
| `EA cd` | `jmp ptr16:16` | 远跳转，绝对直接（64 位模式不可用） |
| `FF /5` | `jmp m16:16` | 远跳转，绝对间接 |

原文给出的链接锚点 `#xCB` 指向 `CB` 这一字节码，即 **`RET FAR`**(far return),也属于这类控制转移指令族。

## 在线汇编 / 反汇编工具

手头没有 binutils 时，可以用在线工具快速验证机器码与助记符的对应关系:

- **[Online x86 / x64 Assembler and Disassembler](https://defuse.ca/online-x86-assembler.htm)**(defuse.ca):支持 Intel 语法输入，可在 x86 与 x64 两种模式间切换;底层调用 GCC 与 objdump，适合学习指令编码或调试 shellcode。反汇编时会自动忽略 `0x` 前缀和非十六进制字符，可以直接粘贴 C 风格的字节数组。

完整的机器码列表请参考权威索引:

- **[X86 Opcode and Instruction Reference](http://ref.x86asm.net/coder64.html#xCB)**(ref.x86asm.net):列出 x86-64 几乎全部 opcode，按字节组织，便于按机器码反查助记符。
- **Intel SDM Vol.2 / [Felix Cloutier 的 HTML 镜像](https://www.felixcloutier.com/x86/)**:官方手册的网页版，包含每条指令的伪代码、异常与受影响的标志位。注意该站点自我标注为非官方（unofficial）整理版本。

## 反汇编:objdump 常用参数

`objdump` 来自 GNU Binutils，是最常用的命令行反汇编工具。常用参数如下:

- **`objdump -d <file>`**:反汇编可执行段(通常是 `.text`)。注意与 `-D` 区分，后者会反汇编**所有**段，包括数据段，可能产生大量噪声。
- **`objdump -D <file>`**:反汇编所有段。
- **`objdump -S <file>`**:在反汇编结果中交替显示源代码;编译时需带 `-g` 调试信息，隐含 `-d`。
- **`objdump -C <file>`**:对 C++ 修饰名（name mangling）进行 demangle，例如把 `_ZNSt6vectorIiSaIiEE9push_backEOi` 还原为 `std::vector<int>::push_back(int&&)`。
- **`objdump -l <file>`**:在反汇编中插入文件名与行号，同样需要调试信息。
- **`objdump -j <section> -d <file>`**:仅反汇编指定 section，例如 `-j .text` 或 `-j .init_array`。
- **`objdump -M intel <file>`**:使用 Intel 语法（默认为 AT&T）。
- **`objdump -t <file>`**:显示符号表;`-T` 显示动态符号表。

几个组合示例:

```bash
# 查看带源码、demangled 符号、行号的完整反汇编
objdump -dSCl ./a.out

# 只反汇编 .text 段,使用 Intel 语法
objdump -d -M intel -j .text ./a.out

# 直接反汇编一段裸机器码(以二进制方式读 stdin)
echo -ne '\xff\xe0' | objdump -D -b binary -m i386:x86-64 -
```

最后一行会输出 `ff e0  jmp rax`,正是上文的 `FF E0` 编码。

## 其他反汇编工具

除了 objdump，还有几款工具在不同的场景下更顺手:

- **`ndisasm`**:随 NASM 一并安装，专门反汇编**裸二进制**(raw binary),输出 NASM 语法。常用 `-b 16|32|64` 指定位数,`-e <bytes>` 跳过头部字节。例如 `ndisasm -b 64 -e 512 disk.img` 可以跳过 MBR 引导扇区再反汇编。
- **`radare2`**:交互式逆向分析框架，适合较大的二进制与漏洞利用分析。
- **Ghidra / IDA Pro**:带反编译器（decompiler）的图形化逆向平台，可以将汇编进一步还原为 C 伪代码。

## 小结

理解 x86 指令编码的关键是抓住 **opcode + ModR/M** 这条主线:opcode 决定指令大类，ModR/M 决定具体的操作数与寻址方式，寄存器编号、内存位移、立即数都在此基础上扩展。日常查机器码时优先用 ref.x86asm.net 的字节索引;查指令语义与异常时优先用 Intel SDM 或其 HTML 镜像;快速验证编码则用 objdump 或在线工具。把这些资源与 objdump 几个核心参数(`-d`、`-S`、`-C`、`-l`、`-j`、`-M intel`)记熟，x86 汇编相关的工作就能顺畅很多。

## 参考

- [X86 Opcode and Instruction Reference](http://ref.x86asm.net/coder64.html#xCB) — ref.x86asm.net 按字节组织的机器码索引
- [Online x86 / x64 Assembler and Disassembler](https://defuse.ca/online-x86-assembler.htm) — defuse.ca 提供的在线汇编 / 反汇编工具
- [Intel® 64 and IA-32 Architectures Software Developer's Manual, Vol.2](https://www.intel.com/sdm) — 指令集参考权威手册
- [x86 and x64 Instruction Reference](https://www.felixcloutier.com/x86/) — Intel SDM Vol.2 的非官方 HTML 镜像
- [GNU Binutils — objdump](https://sourceware.org/binutils/docs/binutils/objdump.html) — objdump 官方文档
- [NASM Documentation](https://www.nasm.us/doc/) — 包含 ndisasm 章节
