+++
title = "Tmux"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "终端复用器的核心概念与常用命令速查"
description = "Tmux 是一款终端复用器，能解绑会话与终端窗口，让进程在 SSH 掉线或关闭窗口后继续运行。本文整理其层级模型、常用命令与配置要点。"
author = "小智晖"
authors = ["小智晖"]
categories = ["command-line"]
tags = ["cmd", "tmux", "terminal", "shell", "linux"]
keywords = ["tmux", "终端复用器", "tmux 配置", "tmux 命令", "terminal multiplexer"]
toc = true
draft = false
+++

Tmux 是一个终端复用器（terminal multiplexer），采用 ISC 许可证发布，作者 Nicholas Marriott，源码托管在 [tmux/tmux](https://github.com/tmux/tmux)。它最核心的能力是把"会话"与"终端窗口"彻底解绑：进程在服务器后台持续运行，关闭终端、SSH 掉线都不会让任务中断。本文整理 Tmux 的层级模型、常用命令与配置要点，便于日常查阅。

## 为什么需要 Tmux

常规终端会话存在两个痛点：一是关闭终端窗口时，窗口内运行的进程会被一并终止；二是通过 SSH 登录远程服务器执行长任务时，一旦网络中断，任务随之丢失。

Tmux 把会话从终端窗口中抽离出来，由后台 server 维护。窗口关闭只意味着客户端断开，会话本身仍在 server 中运行；下次接入（attach）即可回到原来的工作现场。这种"会话持久化"是 Tmux 最常被使用的特性。它的另一个价值是"多任务分屏"：在一个屏幕内同时观察日志、编辑代码、运行命令，靠窗口（window）与窗格（pane）的组合实现。

GNU Screen 提供了类似能力，但 Tmux 在配置、状态栏、窗格管理等方面更现代；社区中 byobu 以 Tmux 为后端做了开箱即用的封装，zellij 则是更年轻的设计。

## 层级模型：Session / Window / Pane

理解 Tmux 的关键是它清晰的三层结构：

```
tmux server（服务器）
  └── session（会话）—— 可命名，持久化运行
        └── window（窗口）—— 类似浏览器标签页
              └── pane（窗格）—— 同一窗口内的分割区域
```

- **Session（会话）**：Tmux 的顶层单位，一个 session 持有一组窗口。`tmux new -s <name>` 创建，`tmux ls` 列出。
- **Window（窗口）**：会话内的标签页，状态栏底部会显示编号和名称。可在多个窗口间快速切换。
- **Pane（窗格）**：窗口被分割后的矩形区域，每个窗格是一个独立的 shell。

前缀键（prefix key）默认为 **`Ctrl+b`**，即先按下并松开 `Ctrl+b`，再按功能键。所有快捷键都通过前缀键触发。若 `Ctrl+b` 与 shell 或编辑器冲突，可在配置中改为 `Alt+a`、`Ctrl+g` 等。

## 会话管理

| 操作 | 命令 | 快捷键 |
|------|------|--------|
| 新建会话 | `tmux new -s <name>` | — |
| 分离会话（后台保留） | `tmux detach` | `Ctrl+b d` |
| 列出会话 | `tmux ls` | `Ctrl+b s` |
| 接入会话 | `tmux attach -t <name>` | — |
| 切换会话 | `tmux switch -t <name>` | — |
| 重命名会话 | `tmux rename-session` | `Ctrl+b $` |
| 杀死会话 | `tmux kill-session -t <name>` | — |

最简工作流只有三步：`tmux new -s work` 创建 → `Ctrl+b d` 分离 → 下次 `tmux attach -t work` 重新接入。注意 `Ctrl+b d` 只是分离（detach），会话仍存活；要真正退出，应在 shell 内执行 `exit` 或按 `Ctrl+d`。

## 窗口管理

窗口相当于标签页。新建窗口 `Ctrl+b c`，状态栏会显示窗口列表。

| 操作 | 命令 | 快捷键 |
|------|------|--------|
| 新建窗口 | `tmux new-window -n <name>` | `Ctrl+b c` |
| 切换上一/下一窗口 | — | `Ctrl+b p` / `Ctrl+b n` |
| 按编号切换 | `tmux select-window -t <n>` | `Ctrl+b <number>` |
| 从列表选择 | — | `Ctrl+b w` |
| 重命名窗口 | `tmux rename-window` | `Ctrl+b ,` |
| 关闭窗口 | `tmux kill-window` | `Ctrl+b &` |

## 窗格管理

窗格是日常分屏的主力，支持垂直与水平拆分。

| 操作 | 命令 | 快捷键 |
|------|------|--------|
| 上下拆分 | `tmux split-window` | `Ctrl+b "` |
| 左右拆分 | `tmux split-window -h` | `Ctrl+b %` |
| 切换窗格 | `tmux select-pane -U/D/L/R` | `Ctrl+b <方向键>` |
| 下一个窗格 | — | `Ctrl+b o` |
| 上一个活跃窗格 | — | `Ctrl+b ;` |
| 交换相邻窗格 | `tmux swap-pane -U/D` | `Ctrl+b {` / `Ctrl+b }` |
| 关闭当前窗格 | — | `Ctrl+b x` |
| 窗格全屏/还原 | — | `Ctrl+b z` |
| 窗格拆成独立窗口 | — | `Ctrl+b !` |
| 显示窗格编号 | — | `Ctrl+b q` |
| 调整窗格大小 | — | `Ctrl+b Ctrl+<方向键>` |

`Ctrl+b z`（zoom）是个常被忽略的利器：临时把某个窗格全屏，再按一次还原，适合短暂查看日志又不想破坏布局。

## 复制模式与历史输出

由于 Tmux 接管了滚动缓冲，常规的 `Shift+PgUp` 在 Tmux 里看不到历史输出。需要进入**复制模式（copy mode）**：

- 进入复制模式：`Ctrl+b [`
- 翻页：`PgUp` / `PgDn`，或 vim 风格的 `k`/`j`
- 退出：按 `q` 或 `Esc`

复制模式下还可用空格选择文本、回车复制到 Tmux 缓冲区，再用 `Ctrl+b ]` 粘贴。

## 鼠标支持

从 Tmux 2.1 起，原先的 `mode-mouse`、`mouse-resize-pane`、`mouse-select-pane` 等多个选项被统一合并为一个 `mouse` 选项。开启后可点击切换窗格、拖拽分隔条、滚轮翻页。

在配置文件 `~/.tmux.conf` 中添加一行即可永久生效：

```
set -g mouse on
```

若只想临时测试，按 `Ctrl+b :` 进入命令模式，输入 `set -g mouse on` 回车。需要滚动时，Tmux 会自动进入复制模式并回滚历史。

## 常用配置片段

`~/.tmux.conf` 是 Tmux 的配置文件，改动后需重新加载：

```
tmux source-file ~/.tmux.conf
```

或在会话内按 `Ctrl+b :` 输入 `source-file ~/.tmux.conf`。

一份最小可用配置示例：

```bash
# 前缀键改为 Ctrl+a
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# 开启鼠标
set -g mouse on

# 窗口编号从 1 开始（0 在键盘太远）
set -g base-index 1
setw -g pane-base-index 1

# 关闭窗口后自动重排编号
set -g renumber-windows on

# 256 色 / true color 支持
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-256color:Tc"

# 更直观的分屏快捷键
bind | split-window -h
bind - split-window -v
```

## 常用排错命令

| 命令 | 用途 |
|------|------|
| `tmux list-keys` | 列出所有快捷键绑定 |
| `tmux list-commands` | 列出所有命令 |
| `tmux info` | 查看当前 server 的全部会话信息 |
| `tmux kill-server` | 杀掉所有会话并退出 server |

## 参考

- [tmux/tmux GitHub 仓库](https://github.com/tmux/tmux)
- [Tmux 使用教程 — 阮一峰](https://www.ruanyifeng.com/blog/2019/10/tmux.html)
- [tmux 里面用鼠标滚轮来卷动窗口内容](https://www.cnblogs.com/bamanzi/archive/2012/08/17/mouse-wheel-in-tmux-screen.html)
- [tmux man page](https://man.openbsd.org/tmux)
