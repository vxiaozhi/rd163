+++
title = "fzf 使用笔记"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "命令行模糊查找器 fzf 的安装、快捷键与常见集成"
description = "fzf 是一款用 Go 编写的通用命令行模糊查找器,本文整理其安装方式、搜索语法、shell 快捷键、环境变量及与 ripgrep、tmux 等工具的集成用法。"
author = "小智晖"
authors = ["小智晖"]
categories = ["command-line"]
tags = ["cmd", "fzf", "fuzzy-finder", "tmux", "shell"]
keywords = ["fzf", "模糊查找", "命令行工具", "fzf-tmux", "ripgrep", "shell 集成"]
toc = true
draft = false
+++

[fzf](https://github.com/junegunn/fzf) 是一款用 Go 语言编写的通用命令行模糊查找器（fuzzy finder）,以单一二进制分发、速度极快，官方称可在毫秒级处理上百万条目。它的本质是一个交互式过滤器——任何以换行分隔的列表(文件、进程、命令历史、Git 分支、`/etc/hosts` 中的主机名等)都能丢给它，再用模糊匹配快速缩小范围，最后把选中项输出到 STDOUT。

配合 shell 快捷键、`ripgrep`、`tmux` 等工具，fzf 能显著提升日常终端操作的效率。

## 安装

fzf 已被各大发行版和包管理器收录，常用方式如下:

```bash
# macOS / Linuxbrew
brew install fzf

# Debian / Ubuntu(19.10 之后已进入官方源)
sudo apt install fzf

# Arch
sudo pacman -S fzf

# Fedora
sudo dnf install fzf
```

Windows 下可经 Chocolatey、Scoop、Winget 或 MSYS2 安装;若想要最新特性，也可直接 clone 仓库执行 `install` 脚本，或从 GitHub Releases 下载预编译二进制。需要注意的是：发行版源里的版本往往滞后，部分新特性(如 `--popup`、`--bash`/`--zsh`/`--fish` 集成参数)依赖较新版本，推荐有条件时通过 Homebrew 或二进制升级。

## 搜索语法

fzf 默认运行在扩展搜索模式（extended-search mode）下，多个以空格分隔的词会按"与"组合。常用 token 如下:

| 写法 | 含义 |
|------|------|
| `sbtrkt` | 模糊匹配，依次包含这些字母 |
| `'wild` | 精确包含 `wild` |
| `'wild'` | 在词边界上精确匹配 |
| `^music` | 前缀精确匹配 |
| `.mp3$` | 后缀精确匹配 |
| `!fire` | 反向匹配(不含 `fire`) |
| `!^music` | 反向前缀 |
| `!.mp3$` | 反向后缀 |

竖线 `|` 作为 OR 运算符，例如 `^core go$ | rb$ | py$` 表示"以 `core` 开头，且以 `go`、`rb` 或 `py` 结尾"。若希望默认走精确匹配，可加 `-e` / `--exact`,此时单引号前缀反而用来"解除"精确，使该词变回模糊。

## Shell 集成与快捷键

fzf 自带 Bash、Zsh、Fish、Nushell 的集成脚本，推荐使用 fzf 0.48+ 提供的子命令一键加载:

```bash
# bash:写入 ~/.bashrc
eval "$(fzf --bash)"

# zsh:写入 ~/.zshrc
source <(fzf --zsh)

# fish:写入 ~/.config/fish/config.fish
fzf --fish | source
```

加载后即可获得三个核心快捷键:

- `CTRL-T`:把选中的文件/目录粘贴到当前命令行
- `CTRL-R`:模糊搜索命令历史(再按一次 `CTRL-R` 在"相关性排序"与"时间序"之间切换)
- `ALT-C`: fuzzy 切换到选中的目录(等价于 `cd`)

另一个常被忽视的特性是模糊补全（fuzzy completion）:在命令中输入 `**` 再按 `TAB`,就会触发 fzf:

```bash
vim **<TAB>        # 在当前目录下选文件
cd **<TAB>         # 选目录
kill -9 **<TAB>    # 选进程 PID
ssh **<TAB>        # 从 /etc/hosts 与 ~/.ssh/config 中选主机
```

## 环境变量

fzf 的行为高度可由环境变量定制，常用的几个:

```bash
# 直接运行 fzf(无管道输入)时使用的命令
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix'

# 所有 fzf 调用的默认参数
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"

# 单独覆盖 CTRL-T / CTRL-R / ALT-C 的行为
export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always {}'"
export FZF_CTRL_R_OPTS="--header 'Press CTRL-Y to copy'"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

# 把默认参数写到文件,避免 .zshrc 过长
export FZF_DEFAULT_OPTS_FILE=~/.fzfrc
```

> 注意：官方明确不建议把 `--preview` 放进 `FZF_DEFAULT_OPTS`。预览命令(如 `bat`)只对文件输入有意义，而对进程列表、历史命令等会产生噪音。同理 `--ansi` 会拖慢首屏扫描，也应避免放入默认参数。

## fzf-tmux

fzf 安装包自带一个脚本 `bin/fzf-tmux`,作用是把 fzf 启动在一个 tmux 分屏或弹出窗口（popup）中;当不在 tmux 会话中时，它会自动退化为直接调用 fzf。

常用布局参数:

| 参数 | 含义 |
|------|------|
| `-p [W%,H%]` | 以 popup 形式弹出（默认 50%）,需 tmux ≥ 3.2 |
| `-u [H%]` | 在上方分屏 |
| `-d [H%]` | 在下方分屏(默认行为,`50%`) |
| `-l [W%]` | 在左侧分屏 |
| `-r [W%]` | 在右侧分屏 |
| `-w` / `-h` / `-x` / `-y` | 配合 `-p` 设置 popup 宽、高、列、行 |

示例:

```bash
# 在 tmux 中以 popup 形式打开 fzf,宽度 80%、高度 40%
fzf-tmux -p 80%,40%

# 在下方 30% 高度分出一个新 pane
fzf-tmux -d 30%
```

新版 fzf(0.53+)本身也内置了 `--tmux` 选项，可在不依赖 `fzf-tmux` 脚本的情况下直接以 popup 启动;`fzf-tmux` 主要用于旧版 tmux 或偏好分屏布局的场景。脚本会在内部强制加上 `--no-height`、`--no-tmux` 等参数以避免与新特性冲突。

## 与 ripgrep 联动：交互式内容搜索

fzf 的 `reload` 绑定可以做到"每次按键都重新执行命令",配合 ripgrep 能搭出一个交互式全文搜索工具:

```bash
: | rg_prefix='rg --column --line-number --no-heading --color=always --smart-case' \
    fzf --bind 'start:reload:$rg_prefix ""' \
        --bind 'change:reload:$rg_prefix {q} || true' \
        --bind 'enter:become(vim {1} +{2})' \
        --ansi --disabled --height=50% --layout=reverse
```

这段命令的关键点:`--disabled` 让 fzf 自身不做过滤，完全交给 ripgrep;`change:reload` 在每次输入变化时重新跑 `rg`;`become(vim {1} +{2})` 则把 fzf 进程直接替换成 vim，打开选中文件并跳到对应行号。

类似地,`become()` 也可用于文件选择，比 `vim "$(fzf)"` 更稳健（取消时不会打开空文件，多选时也能正确处理空格）:

```bash
fzf --bind 'enter:become(vim {})'
```

## 小结

fzf 的价值在于"通用"二字：任何列表都能模糊过滤，任何选中结果都能交给其他程序消费。日常用得最多的三件事是——`CTRL-R` 翻历史、`**<TAB>` 补全参数、`FZF_DEFAULT_COMMAND` 配合 `fd` / `rg` 替换默认数据源。把这几个组合用熟，再按需引入 `fzf-tmux` 和 `--popup`,基本上就能覆盖绝大多数命令行查找场景。

## 参考

- [junegunn/fzf — GitHub 官方仓库](https://github.com/junegunn/fzf)
- [fzf Wiki](https://github.com/junegunn/fzf/wiki)
- [使用模糊搜索神器 FZF 来提升办公效率](https://oskernellab.com/2021/02/15/2021/0215-0001-Using_FZF_to_Improve_Productivity/)
- [每天学习一个命令:fzf 使用笔记](https://www.cnblogs.com/guolongnv/articles/16211433.html)
