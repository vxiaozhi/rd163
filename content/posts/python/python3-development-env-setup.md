+++
title = "python3 开发环境搭建"
date = "2025-09-20"
lastmod = "2025-09-20"
subtitle = "在 Ubuntu 20.04 上用 Deadsnakes PPA 安装 Python 3.10 并配置虚拟环境与类型检查"
description = "介绍 Python 3.10 开发环境的搭建过程,包括版本选择、在 Ubuntu 20.04 上通过 Deadsnakes PPA 安装 Python 3.10、创建虚拟环境以及配置 mypy 静态类型检查,并附 Dockerfile 示例。"
author = "小智晖"
authors = ["小智晖"]
categories = ["python"]
tags = ["Python", "环境搭建", "Ubuntu", "Deadsnakes", "venv", "mypy"]
keywords = ["Python 3.10", "Ubuntu 20.04", "Deadsnakes PPA", "venv", "mypy", "开发环境"]
toc = true
draft = false
+++

## 版本选择

建议使用 Python 3.10 及以上版本，因为更低版本已陆续停止维护。以 Python 3.8 为例，它已于 **2024-10-07** 正式结束生命周期（End of Life, EOL）,Python 官方不再提供 bug 修复和安全更新。

在 macOS 上用 Homebrew 安装 `python@3.8` 时，会直接被禁用并报错:

```text
==> Fetching downloads for: python@3.8
Error: python@3.8 has been disabled because it is deprecated upstream! It was disabled on 2024-10-14.
```

## 在 Ubuntu 20.04 上安装 Python 3.10

Ubuntu 20.04(focal)自带的 Python 版本是 3.8。要在其上使用 Python 3.10,**推荐使用 Deadsnakes PPA**,这是社区中最便捷、维护最积极的方式。

> 说明:`Deadsnakes` 是一个第三方软件源，专门为 Ubuntu 提供官方仓库中未收录的新旧 Python 版本，由社区维护，在 Python 社区中广泛使用。需要注意的是，Ubuntu 20.04 的标准支持已于 2025 年 5 月结束，Deadsnakes 当前主要维护 22.04/24.04 等较新的 LTS 版本;20.04 上的旧包通常仍可用，但不再有官方保证。若在新部署上遇到问题，建议直接升级到 22.04 或使用 `pyenv` 从源码编译。

1.  **更新系统包列表**

    首先确保系统包列表是最新的。

    ```bash
    sudo apt update
    ```

2.  **安装预备依赖**

    安装添加 PPA 所需的软件包。

    ```bash
    sudo apt install software-properties-common -y
    ```

3.  **添加 Deadsnakes PPA**

    将包含 Python 3.10 的软件源添加到系统中。

    ```bash
    sudo add-apt-repository ppa:deadsnakes/ppa
    ```

    出现提示时,按 `Enter` 键继续。

4.  **再次更新包列表**

    添加 PPA 后,需要再次更新,以便 APT 能识别新源中的软件包。

    ```bash
    sudo apt update
    ```

5.  **安装 Python 3.10**

    现在可以安装 Python 3.10 解释器及相关组件。

    ```bash
    sudo apt install python3.10 python3.10-venv python3.10-dev -y
    ```

    - `python3.10`:Python 3.10 解释器。
    - `python3.10-venv`:提供 `venv` 模块,用于创建 Python 3.10 虚拟环境;创建虚拟环境时会通过 `ensurepip` 自动安装 `pip`。
    - `python3.10-dev`:包含开发头文件和静态库,编译依赖 C 扩展的包(如 `NumPy`、`lxml`)时必需。

### Dockerfile 示例

下面是一个在 Ubuntu 20.04 镜像中安装 Python 3.10 的 Dockerfile 示例,供参考。

```dockerfile
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN echo "deb http://mirrors.tencent.com/ubuntu/ focal main restricted universe multiverse \n" \
    "deb http://mirrors.tencent.com/ubuntu/ focal-security main restricted universe multiverse \n" \
    "deb http://mirrors.tencent.com/ubuntu/ focal-updates main restricted universe multiverse \n" \
    "deb-src http://mirrors.tencent.com/ubuntu/ focal main restricted universe multiverse \n" \
    "deb-src http://mirrors.tencent.com/ubuntu/ focal-security main restricted universe multiverse \n" \
    "deb-src http://mirrors.tencent.com/ubuntu/ focal-updates main restricted universe multiverse \n" \
    > /etc/apt/sources.list

RUN apt-get update \
    && apt-get install -y bash \
                   build-essential \
                   zip unzip dnsutils \
                   curl \
                   vim \
                   wget \
                   ca-certificates \
                   libsndfile1-dev \
                   fontconfig \
                   xfonts-utils \
                   ttf-mscorefonts-installer \
                   protobuf-compiler \
                   software-properties-common \
                   && rm -rf /var/lib/apt/lists

RUN apt remove -y python3-yaml
RUN add-apt-repository ppa:deadsnakes/ppa && apt update && apt install python3.10 python3.10-venv python3.10-dev -y && rm -rf /var/lib/apt/lists
RUN python3.10 -m ensurepip --upgrade && python3.10 -m pip install --no-cache-dir --upgrade pip setuptools wheel
RUN mkdir -p /usr/share/fonts/myfonts

RUN mkdir /data
WORKDIR /data

COPY requirements.txt /data/requirements.txt
RUN python3.10 -m pip uninstall -y PyYAML || true
RUN python3.10 -m pip install -r requirements.txt
```

## 用 Python 3.10 创建虚拟环境

为每个项目隔离依赖是 Python 开发的最佳实践,使用标准库自带的 `venv` 即可完成。

```bash
# 创建名为 'my_venv' 的虚拟环境
python3.10 -m venv my_venv

# 激活虚拟环境
source my_venv/bin/activate

# 激活后，提示符前会出现 (my_venv)
# 此时使用的 python 和 pip 命令都指向该虚拟环境内部
(my_venv) $ python --version
Python 3.10.12
(my_venv) $ pip install requests

# 退出虚拟环境
deactivate
```

## 配置 mypy 静态类型检查

`mypy` 是 Python 最主流的静态类型检查工具。可以在项目根目录放置 `mypy.ini` 进行配置:

```ini
[mypy]
python_version = 3.10
warn_return_any = True
disallow_untyped_defs = False

# 包含的目录
files = server/, tests/

# 排除的目录（值为正则表达式）
exclude = .venv/|.*/migrations/|.*/__pycache__/

# 忽略 protobuf 相关模块的导入错误
[mypy-google.*]
follow_imports = skip

[mypy-server.proto.*]
follow_imports = skip
```

说明:

- `files`:逗号分隔的路径列表,指定 mypy 检查的范围。
- `exclude`:一个正则表达式,匹配到的文件、目录会被跳过。
- `follow_imports = skip`:跳过对相应模块的类型检查,常用于自动生成代码或缺少类型存根(stub)的第三方库。

## 参考

- [Python 各版本状态与生命周期(Python 官方)](https://devguide.python.org/versions/)
- [Deadsnakes PPA(Launchpad)](https://launchpad.net/~deadsnakes/+archive/ubuntu/ppa)
- [mypy 配置文件文档](https://mypy.readthedocs.io/en/stable/config_file.html)
- [Python venv 模块文档](https://docs.python.org/3/library/venv.html)