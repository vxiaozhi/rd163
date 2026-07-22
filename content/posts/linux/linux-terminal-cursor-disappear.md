+++
title = "解决 Linux 终端中光标消失的问题"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从 ANSI 转义序列到 tput 与 reset 的完整修复方案"
description = "分析 Linux 终端光标消失的常见成因,介绍 DECTCEM 转义序列、tput、reset 等多种修复与防御手段。"
author = "小智晖"
authors = ["小智晖"]
categories = ["linux"]
tags = ["terminal", "ansi", "shell", "tmux", "vim"]
keywords = ["linux", "terminal", "光标消失", "ANSI 转义序列", "DECTCEM", "tput"]
toc = true
draft = false
+++

在使用 Linux 终端（Terminal）时，偶尔会遇到一个让人困惑的现象：输入命令时光标（那个用来标识插入位置的小方块或竖线）突然不见了，但键入的字符仍然能正常显示。这种情况几乎都不是系统故障，而是某个程序退出时没有正确恢复终端状态所导致。本文梳理其成因与多种修复手段。

## 成因：谁动了光标

终端中的光标显示与否，是由一组叫做 **DEC Private Mode**(DEC 私有模式)的转义序列控制的。全屏 TUI(Text User Interface，文本用户界面)程序——例如 `vim`、`less`、`htop`、`tmux`、`watch`、各种进度条与动画脚本——为了界面的整洁，通常会在启动时主动隐藏光标，退出时再恢复。

问题就出在「退出」这一步:

- 程序被 `kill -9` 强杀、段错误崩溃，跳过了恢复逻辑;
- 通过 `Ctrl+\`(SIGQUIT)或异常路径退出;
- 自写的 shell 脚本里执行了隐藏光标的转义序列，却忘了配对恢复;
- 在 `tmux` 中运行某些对 `terminal-overrides` 处理不当的程序，模式切换序列被「吃掉」。

一旦隐藏序列被发出而对应的显示序列没有发出，终端就停留在「光标不可见」的状态，直到下一次有程序主动把它打开。

## 原理:DECTCEM 转义序列

控制光标可见性的序列被称为 **DECTCEM**(DEC Text Cursor Enable Mode,DEC 文本光标启用模式),起源于 VT220 终端，目前在 xterm、GNOME Terminal、Konsole、iTerm2、Alacritty、Kitty、Windows Terminal 等主流终端中均被广泛支持。

- 显示光标:`ESC [?25h`(DECSET，设置模式)
- 隐藏光标:`ESC [?25l`(DECRST，重置模式)

其中 `ESC` 对应 ASCII 27(八进制 `\033` 或十六进制 `\x1b`),`[` 是 CSI(Control Sequence Introducer，控制序列引入符),`?25` 表示第 25 号私有模式，末尾的 `h`/`l` 分别代表 set(high)与 reset(low)。

## 立即修复：三种常用方法

### 方法一：直接发送转义序列

最直接的办法是手动向终端发送显示光标的序列:

```bash
# 显示光标
echo -e '\033[?25h'

# 隐藏光标
echo -e '\033[?25l'
```

更可移植的写法是用 `printf`,因为 `echo -e` 在不同 shell(如某些 `sh`)下行为不一致:

```bash
printf '\033[?25h'   # 显示光标
```

### 方法二：通过 terminfo 数据库

`echo` 直接硬编码了转义序列，在不同终端类型下未必通用。更优雅的方式是使用 `tput`,它会查询系统的 **terminfo** 数据库，根据当前 `$TERM` 自动选择正确的序列:

```bash
tput cnorm   # cursor normal,恢复光标可见
tput civis   # cursor invisible,隐藏光标
tput cvvis   # cursor very visible,使光标高亮(如加粗或闪烁)
```

`tput` 是 `ncurses` 配套工具，在几乎所有 Linux 发行版中默认可用，也是 shell 脚本里推荐的做法。

### 方法三：重置整个终端

如果光标消失的同时还伴随颜色错乱、回车失效等异常，最彻底的办法是用 `reset`:

```bash
reset
```

`reset` 是 `stty sane` 的超集：它先把行编辑模式（line discipline）恢复到合理默认值（开启回显、规范模式、换行转换等）,随后再通过 terminfo 向终端发送 reset 字符串，重新初始化终端缓冲区与视觉属性。当终端混乱到连回车都无法正常使用、命令无法输入时，可以用 `Ctrl+J` 代替回车，输入 `reset` 后再按一次 `Ctrl+J` 即可执行。

如果只是想恢复行设置而不重置终端外观，使用 `stty sane` 就够了:

```bash
stty sane
```

## 防御：让光标自动恢复

与其每次手动修复，不如在脚本和配置中做防御性处理。

### 在 shell 脚本中

任何隐藏光标的脚本都应该用 `trap` 注册退出钩子，确保即使被中断也能恢复:

```bash
#!/usr/bin/env bash
# 退出时(包括被 Ctrl+C、SIGTERM 终止)自动恢复光标
trap 'tput cnorm' EXIT

tput civis   # 隐藏光标,进入动画/进度展示
# ... 主要逻辑 ...
# 脚本结束时 trap 会自动调用 tput cnorm
```

`trap '...' EXIT` 在脚本以任何方式退出（正常结束、收到信号、出错）时都会触发，是最稳妥的方式。

### 在交互式 Shell 中

如果经常被崩溃的程序「弄瞎」光标，可以在每次显示提示符前主动恢复一次。Bash 中利用 `PROMPT_COMMAND`:

```bash
# 写入 ~/.bashrc
PROMPT_COMMAND='printf "\033[?25h"'
```

Zsh 中则是 `precmd` 钩子:

```zsh
# 写入 ~/.zshrc
precmd() { printf '\033[?25h' }
```

这样即使前一个程序没把光标恢复回来，下一次提示符出现时也会自动修好。

### 在 Vim / Neovim 中

`vim`/`nvim` 退出时光标形状异常（常见于插入模式用过竖线光标，退出后仍是竖线或干脆消失）,可以在退出时显式恢复:

```vim
" Vim (.vimrc)
autocmd VimLeave * :!echo -ne "\033[2 q"
```

```lua
-- Neovim (init.lua)
vim.api.nvim_create_autocmd("VimLeave", {
  pattern = "*",
  command = [[set guicursor=a:ver25-blinkon0]],
})
```

`\033[2 q` 是 DECSCUSR(Set Cursor Style)序列,`2` 表示块状（block）光标。

### 在 tmux 中

`tmux` 有时光标形状变化序列不会被正确转发给外层终端，在 `~/.tmux.conf` 中加上:

```tmux
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ',xterm-256color:Tc'
set -ga terminal-overrides ',*:Ss=\E[%p1%d q:Se=\E[2 q'
```

其中 `Ss`/`Se` 分别是设置和恢复光标形状的 terminfo 能力，这条 override 让 tmux 透传 DECSCUSR 序列。

## 小结

| 场景 | 推荐做法 |
|------|----------|
| 光标消失，临时恢复 | `echo -e '\033[?25h'` 或 `tput cnorm` |
| 终端整体混乱 | `reset`(或 `Ctrl+J reset Ctrl+J`) |
| 编写 shell 脚本 | `trap 'tput cnorm' EXIT` |
| 交互式 Shell 防御 | 在 `PROMPT_COMMAND`/`precmd` 中恢复 |
| Vim/Nvim 退出异常 | `VimLeave` 自动恢复光标形状 |

光标消失看起来像是「卡死」,实际上终端仍在正常工作，只是少发了一个显示光标的转义序列。理解了 DECTCEM 这个底层机制，无论是排查别人程序的问题，还是在自己的脚本里做防御，都能从容应对。

## 参考

- xterm Control Sequences — <https://invisible-island.net/xterm/ctlseqs/ctlseqs.html>
- `tput(1)` 与 `terminfo(5)` 手册
- `reset(1)` / `stty(1)` 手册(`man 1 reset`)
