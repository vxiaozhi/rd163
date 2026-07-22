+++
title = "Rust 实现的命令行工具"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "用 Rust 重写经典 Unix 命令的现代替代品清单"
description = "整理 bat、eza、ripgrep、fd、zoxide、NBPing、starship 等用 Rust 实现的命令行工具,介绍它们的特点、用法与安装方式,以及 Rust 适合编写 CLI 的原因。"
author = "小智晖"
authors = ["小智晖"]
categories = ["command-line"]
tags = ["cmd", "rust", "cli"]
keywords = ["Rust", "命令行工具", "ripgrep", "bat", "eza", "zoxide"]
toc = true
draft = false
+++

近年来,Rust 在命令行工具领域出现了一大批高质量的项目。许多经典的 Unix 命令(`cat`、`ls`、`grep`、`find`、`cd` 等)都有了 Rust 重写的现代版本,它们在保留原工具习惯的同时,提供了更好的性能、更友好的输出和更丰富的功能。

这篇文章整理笔者常用(或关注)的几个 Rust 命令行工具,并简要说明它们解决了什么问题。

## 为什么 Rust 适合写 CLI

在进入具体工具之前,先简单回答一个常见问题:为什么大家都用 Rust 重写命令行工具?

- **启动快**:Rust 编译为原生机器码,没有运行时(GC、JVM、解释器),CLI 启动几乎是毫秒级,这对被频繁调用的命令非常关键。
- **单二进制分发**:`cargo build --release` 产物是单个可执行文件,用户放到 `PATH` 即可使用,避免了 Python/Node CLI 的依赖地狱。
- **跨平台与交叉编译**:Windows、macOS、Linux 均为一等公民,配合 `cargo build --target` 可方便地交叉编译。
- **生态成熟**:`clap`(参数解析)、`serde`(序列化)、`anyhow`(错误处理)、`indicatif`(进度条)、`rayon`(并行)等库足够稳定,开发体验好。
- **安全与并发**:所有权系统在编译期消除数据竞争,适合需要并行遍历大量文件的搜索类工具。

## 文件查看与列目录

### bat —— 带语法高亮的 `cat`

[bat](https://github.com/sharkdp/bat) 是 `cat` 的克隆,由 sharkdp 用 Rust 编写。主要特性:

- 语法高亮(基于 `syntect`,支持大量语言和 Markdown)
- 集成 Git,在侧边栏显示文件改动
- 自动分页、显示行号
- 可作为 `fzf` 的预览器或 `MANPAGER`

常用安装:

```bash
# macOS
brew install bat
# Debian/Ubuntu(注意二进制名为 batcat)
sudo apt install bat
# Cargo
cargo install bat
```

简单用法:

```bash
bat README.md          # 带高亮显示
bat -p file.txt        # plain 模式,无装饰
bat -A file.txt        # 显示不可见字符
```

### eza —— 现代化的 `ls`

[eza](https://github.com/eza-community/eza) 是 `ls` 的现代替代,它是已停止维护的 `exa` 的社区接力分支。主要特性:

- 彩色输出,区分文件类型、权限、所有权、Git 状态
- 树形视图(递归列目录)
- 配合 Nerd Font 显示文件类型图标
- 人类可读的文件大小、Git 状态指示

```bash
# 长格式 + Git 状态 + 图标
eza -lg --icons
# 树形视图,限制两层
eza --tree --level=2
```

很多人会把它 alias 成 `ls`,作为日常默认的列目录命令。

## 搜索类工具

### ripgrep (rg) —— 更快的 `grep`

[ripgrep](https://github.com/BurntSushi/ripgrep) 是 Andrew Gallant(BurntSushi)开发的递归正则搜索工具,命令名为 `rg`。它的核心卖点是**快**:

- 默认遵循 `.gitignore`、`.ignore`、`.rgignore`,自动跳过隐藏文件和二进制文件
- 使用有限自动机 + SIMD + 字面量优化的正则引擎
- 支持 PCRE2(look-around、反向引用),通过 `-P` 开启
- 支持搜索压缩文件(brotli、gzip、xz、zstd 等,用 `-z`)
- 多文件类型过滤:`-t py` 只搜 Python,`-T js` 排除 JavaScript

```bash
rg 'TODO'                     # 递归搜索(忽略 .gitignore)
rg -tpy 'FastAPI'             # 只搜 Python 文件
rg -uuu pattern               # 关闭所有过滤,类似 grep -r
rg -z 'pattern' log.gz        # 搜压缩文件
rg -P '(?<=foo)bar'           # PCRE2 look-behind
```

### fd —— 更友好的 `find`

[fd](https://github.com/sharkdp/fd) 同样出自 sharkdp,目标是替代 `find`。特性:

- 默认忽略隐藏文件和 `.gitignore` 中的文件
- 默认智能大小写(全小写时忽略大小写)
- 使用正则匹配,语法比 `find` 直观得多
- 并行遍历,速度通常显著快于 `find`

```bash
fd config                    # 按名字模糊匹配
fd -e toml                   # 按扩展名
fd -H pattern                # 包含隐藏文件
fd -I pattern                # 不遵循 .gitignore
fd -e go -x gofmt -w         # 对所有 Go 文件并行执行命令
```

## 目录跳转

### zoxide —— 更聪明的 `cd`

[zoxide](https://github.com/ajeetdsouza/zoxide) 是受 `z` 和 `autojump` 启发的目录跳转工具。它记录你访问过的目录,并根据「频率 + 最近度」(frecency)排序,让你用极少的输入跳到目标。

```bash
z blog            # 跳到 frecency 最高的、名字含 blog 的目录
z github blog     # 多关键字匹配
z ..              # 上层目录
z -               # 上一次目录
zi blog           # 配合 fzf 交互式选择
```

支持 Bash、Zsh、Fish、PowerShell、Nushell 等主流 shell,还可以从 `autojump`、`z`、`fasd`、`zsh-z` 等工具导入历史记录。

## 网络诊断

### NBPing —— Rust 实现的并发 Ping 工具

[NBPing](https://github.com/hanshuaikang/Nping)(原名 Nping,后改名 NBPing,二进制名为 `nbping`)是一个用 Rust 编写的 Ping 工具,支持多个地址并发 Ping,并附带实时可视化图表。主要特性:

- 多地址并发 Ping
- 实时图表,支持 `graph`/`table`/`point`/`sparkline` 四种视图(运行时按 `1-4` 或 `Tab` 切换)
- TCP Ping、IP 段 Ping
- IPv6 支持(`-6`)
- **Exporter 模式**:把 ping 指标以 Prometheus 格式暴露出来,便于接入 Grafana
- 支持 YAML 配置文件

安装(目前官方只提到 Homebrew):

```bash
brew install nbping
```

基本用法:

```bash
# 同时 ping 多个目标,每 2 秒一次,共 20 次
nbping www.baidu.com www.google.com -c 20 -i 2

# 以 Prometheus exporter 模式启动,端口 9100
nbping exporter www.baidu.com www.google.com -i 1 -p 9100

# 使用配置文件
nbping --config nbping.yaml
```

关键参数:`-c`/`--count` 设置次数(默认 0 表示无限),`-i`/`--interval` 设置间隔秒数,`-v`/`--view-type` 设置初始视图,`-o`/`--output` 把结果保存到文件。

## Shell 提示符

### starship —— 跨 shell 的提示符

[starship](https://github.com/starship/starship) 是一个用 Rust 编写的跨 shell 提示符工具,官网 [starship.rs](https://starship.rs)。它的特点是极快、可高度定制,并且几乎支持所有主流 shell:Bash、Zsh、Fish、PowerShell、Nushell、Elvish、Cmd(通过 Clink)、Tcsh、Xonsh 等。

它能在提示符中按需显示当前 Git 分支与状态、语言运行时版本(Node、Python、Rust、Go 等)、Kubernetes 上下文、AWS profile 等信息,且配置统一,与具体 shell 解耦。

```bash
# Cargo 安装
cargo install starship --locked
```

各 shell 的初始化片段可在官网 Get Started 中找到。终端需要先安装一种 [Nerd Font](https://www.nerdfonts.com/) 才能正确显示图标。

## 小结

上面这些工具有一个共同特点:**保持与原命令接近的使用习惯,同时在性能、可读性和功能上有明显提升**。实际使用时不一定全部替换,可以从最高频的场景入手——比如用 `rg` 替代 `grep -r`、用 `fd` 替代 `find`、用 `bat` 替代 `cat`、用 `zoxide` 替代深层 `cd`——逐步迁移即可。如果不想手动 alias,也可以用 [modern-unix](https://github.com/ibraheemdev/modern-unix) 这个仓库作为索引,它汇总了一批类似的现代命令行工具。

## 参考

- [bat — GitHub](https://github.com/sharkdp/bat)
- [eza — GitHub](https://github.com/eza-community/eza)
- [ripgrep — GitHub](https://github.com/BurntSushi/ripgrep)
- [fd — GitHub](https://github.com/sharkdp/fd)
- [zoxide — GitHub](https://github.com/ajeetdsouza/zoxide)
- [NBPing(原 Nping)— GitHub](https://github.com/hanshuaikang/Nping)
- [starship — GitHub](https://github.com/starship/starship) / [starship.rs](https://starship.rs)
- [modern-unix — GitHub](https://github.com/ibraheemdev/modern-unix)
