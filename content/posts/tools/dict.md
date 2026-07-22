+++
title = "英汉词典"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "命令行与离线英汉词典工具盘点"
description = "整理命令行英汉词典、离线词典数据库与词典软件，涵盖 sdcv、ECDICT、GoldenDict-ng 等开源项目及其使用方式。"
author = "小智晖"
authors = ["小智晖"]
categories = ["tools"]
tags = ["工具", "词典", "命令行", "sdcv", "ECDICT"]
keywords = ["英汉词典", "命令行词典", "sdcv", "ECDICT", "GoldenDict", "离线词典"]
toc = true
draft = false
+++

在终端环境下阅读英文文档、写代码或翻译时，频繁切换到浏览器查词会打断思路。一个顺手、响应快、可离线的词典工具能显著提升效率。本文整理几类常见的开源英汉词典方案，包括命令行查词工具、离线词典数据库与桌面词典软件。

## 命令行查词工具

命令行词典（command-line dictionary）通常体积小、启动快，适合在 tmux 分屏或 SSH 会话里随手查询。

### sdcv:StarDict 的控制台版本

[sdcv](https://github.com/Dushistov/sdcv)（StarDict Console Version）是一个跨平台、基于文本的词典查询工具，使用 C++ 编写，遵循 GPL-2.0 协议。它只读取 [StarDict](https://github.com/huzheng001/stardict-3) 格式的词典文件，支持多本词典同时安装与查询。

常用调用方式：

```bash
# 基本查词
sdcv hello

# 以 JSON 输出，便于配合 jq 处理
sdcv hello --json

# 只使用指定词典
sdcv -n --use-dict=Oxford hello
```

sdcv 提供标准输入（stdin）读取，因此可以与 `fzf`、`grep`、`jq` 等工具组合，构建交互式查词流水线。源码编译采用 CMake：

```bash
mkdir build-sdcv && cd build-sdcv
cmake /path/to/sdcv
make && make install
```

在 Debian/Ubuntu 上也可直接 `apt install sdcv` 安装。安装后，把 StarDict 格式的词典目录放入 `~/.stardict/dic/` 或 `/usr/share/stardict/dic/` 即可使用。

### Wudao-dict:有道词典的命令行版本

[Wudao-dict（无道词典）](https://github.com/ChestnutHeng/Wudao-dict) 由 `ChestnutHeng` 维护，使用 Python 编写，提供约 20 万英汉词条与约 10 万汉英词条，并支持在线查询补充词库。主要特性：

- 英汉互查与短语查询，例如 `wd in order to`
- 约 1 万最常用词的 Tab 自动补全
- 交互模式 `wd -i`，可连续查词
- 短模式 / 完整模式切换（`wd -s` 控制是否显示例句）
- 查过的词自动保存到生词本，便于复习
- 跨平台支持 Debian/Ubuntu、OpenSUSE、CentOS 与 macOS

在线查询依赖 `bs4`（Beautiful Soup）与 `lxml`，首次查询结果会被本地缓存以加速重复查询。

### ydict:Go 版命令行有道词典

[ydict](https://github.com/TimothyYe/ydict) 使用 Go 编写，定位是 "Yet another command-line youdao dictionary for geeks!"。除英汉互查外，还支持：

- 通过 `mpg123` 朗读单词
- `-m` 显示更多例句，`-s` 翻译整句
- 本地生词本管理（`-c` 缓存、`-l` 列出、`-d` 删除、`-p` 循环播放）
- SOCKS5 代理（经 `.env` 配置）
- Vim 集成插件 [vim-ydict](https://github.com/TimothyYe/vim-ydict)

需要说明的是，ydict 最新版本为 2023 年 11 月发布的 v2.2.2，目前处于低活跃维护状态，依赖在线服务的工具长期使用需留意接口可用性。

### MyDict:纯 C 实现的离线词典

[MyDict](https://github.com/haricheung/MyDict) 由 `haricheung` 维护，使用 C 语言编写，采用 Trie（前缀树）数据结构，内存占用约 73 MB。原文章中链接 `chienlungcheung/MyDict` 为该仓库的历史地址，GitHub 会自动 301 重定向到当前地址。

核心特性：

- 完全离线，词库 45,093 词
- 支持大小写混用输入
- 词库文件 `raw-dict` 可替换以生成自定义词典
- 在 Linux 下 `make` 后执行 `./MyDict` 即可

作者规划中的改进包括使用三元搜索树（ternary search tree）降低内存占用、Tab 补全、未命中时给出最长前缀建议等。

## 离线词典数据库

命令行查词工具本身不携带词库，词库质量决定查词体验。下面这个项目是中文社区使用最广的免费英汉词库。

### ECDICT:开源英汉词典数据库

[ECDICT](https://github.com/skywind3000/ECDICT) 由 `skywind3000` 发起，采用 MIT 协议，是开源的英汉双语词典数据库。它从一份两万词的词表起步，经过多年爬取、社区贡献与开源词典数据合并（如 cdict）逐步扩展。

词库规模与字段：

- 基础版 `ecdict.csv` 约 77 万词条，release v1.0.28 扩展到 222 万词条
- 每条记录包含：`word`（单词）、`phonetic`（音标）、`definition`（英文释义）、`translation`（中文翻译）、`pos`（词性）、`collins`（柯林斯星级）、`oxford`（牛津 3000 词标记）、`tag`（考试分类如 CET-4/CET-6/GRE/IELTS）、`bnc`（BNC 语料库排名）、`frq`（当代语料库词频）、`exchange`（时态 / 复数 / 词形还原）

可用格式与使用方式：

- **CSV**：UTF-8 编码，方便版本管理与提交 PR
- **SQLite**：经仓库内的 `stardict.py` 由 CSV 转换得到，本地查询速度更快
- **StarDict**：可生成 GoldenDict、sdcv 直接读取的离线词典文件
- **MDX/MDD**：可在 MDict、GoldenDict 等移动端 / 桌面端软件使用

仓库自带的 `stardict.py` 暴露 `DictCsv`、`StarDict`、`DictMySQL` 三个统一接口的类，支持查询、匹配、增删改等操作。配合 `lemma.en.txt`（基于 BNC 1 亿词语料分析得到的词形还原表），可实现 `gave → give` 这类形态归并查询。

## 桌面词典软件

如果更习惯图形界面，下面这个项目是 Linux/Windows/macOS 上常用的桌面词典。

### GoldenDict-ng:新一代 GoldenDict

[GoldenDict-ng](https://github.com/xiaoyifang/goldendict-ng)（The Next Generation GoldenDict）是经典项目 GoldenDict 的活跃分支，使用 C++ 编写，遵循 GPLv3+ 协议。它本身是 GUI 程序而非命令行工具，适合需要大量查阅、多词典对比的场景。

主要特性：

- 基于 Qt WebEngine 的现代 HTML/CSS 渲染
- 支持超过 4 GB 的大型词典
- 内置 Xapian 全文搜索引擎，针对千万级词条做了性能优化
- 高 DPI 显示、暗色主题
- Anki 集成
- 跨平台：Linux / Windows / macOS

GoldenDict-ng 支持 StarDict、MDict、Babylon、Dictd 等多种主流词典格式，可以将 ECDICT 转换得到的 StarDict 文件直接挂载使用。

## 选型建议

不同场景下的工具选择参考：

| 场景 | 推荐方案 |
|---|---|
| 终端里随手查词 | sdcv + ECDICT 生成的 StarDict 词库 |
| 需要在线补充释义与例句 | Wudao-dict 或 ydict |
| 完全离线、依赖少 | MyDict（纯 C、单文件） |
| 大量词典对比、桌面阅读 | GoldenDict-ng + 多本 StarDict 词典 |
| 编程获取词库数据 | ECDICT 的 CSV / SQLite 接口 |

## 命令行查词示例

以 sdcv + ECDICT 为例，一个最小可用的离线查词流程：

```bash
# 1. 安装 sdcv
sudo apt install sdcv

# 2. 下载 ECDICT 并转为 StarDict 格式（用仓库内 stardict.py）
python3 stardict.py -c ecdict.csv --sd wysd

# 3. 把生成的词典目录放到 sdcv 读取路径
cp -r stardict-* ~/.stardict/dic/

# 4. 查词
sdcv dictionary
```

配置 `~/.inputrc` 后还可以把查词绑定到快捷键，配合 fzf 实现交互式词典选择。

## 参考

### 命令行查词工具

- [sdcv - StarDict Console Version](https://github.com/Dushistov/sdcv)
- [Wudao-dict 无道词典](https://github.com/ChestnutHeng/Wudao-dict)
- [ydict - Go 版命令行有道词典](https://github.com/TimothyYe/ydict)
- [MyDict 用 C 语言实现的命令行英汉对照词典](https://github.com/haricheung/MyDict)
- [Dict《牛津英汉词典》查词（C++ + HTTP 服务）](https://github.com/yyt6801/Dict)

### 词典数据与桌面软件

- [ECDICT 开源英汉词典数据库](https://github.com/skywind3000/ECDICT)
- [GoldenDict-ng 新一代 GoldenDict](https://github.com/xiaoyifang/goldendict-ng)
- [StarDict 词典格式（经典项目）](https://github.com/huzheng001/stardict-3)
