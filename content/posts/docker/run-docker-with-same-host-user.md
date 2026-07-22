+++
title = "如何使用主机当前用户运行 docker"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "让容器内进程与宿主机当前用户保持一致的 UID/GID，避免挂载目录权限错乱"
description = "介绍两种在 Docker 容器中以宿主机当前用户身份运行进程的方法：使用 --user 参数和自定义 Dockerfile，解决挂载卷权限不一致的问题。"
author = "小智晖"
authors = ["小智晖"]
categories = ["docker"]
tags = ["docker", "权限", "uid", "gid", "dockerfile"]
keywords = ["docker", "docker 用户", "uid gid", "dockerfile", "挂载权限", "--user"]
toc = true
draft = false
+++

当我们在 Docker 容器中挂载宿主机目录时，如果容器内进程默认以 root 身份运行，新生成的文件会属于 root，宿主机当前用户往往无权读写。为了避免这种权限错乱，我们需要让容器内的进程以宿主机当前用户的 UID/GID 运行。下面提供两种方法。

## 方法一：使用 `--user` 参数

第一种方法无需自定义镜像，直接在 `docker run` 时通过 `--user`（简写 `-u`）参数指定 UID 和 GID 即可。

### 1. 获取当前用户的 UID 和 GID

使用 `id` 命令可以拿到当前用户的 UID（用户 ID）和 GID（组 ID）:

```bash
export MY_UID=$(id -u)
export MY_GID=$(id -g)
```

> 注意：在 bash 中，`UID` 是一个只读的内置变量（已经自动设置为当前用户的 UID），直接执行 `export UID=$(id -u)` 会报 `bash: UID: readonly variable` 错误。因此这里改用 `MY_UID` 作为变量名，避免冲突。

### 2. 启动容器

`--user` 参数的格式为 `<name|uid>[:<group|gid>]`，冒号前是用户，冒号后是组。下面是完整的示例:

```bash
docker run -it --rm --user $MY_UID:$MY_GID -v "$(pwd):/home/user" <IMAGE_NAME>
```

把 `<IMAGE_NAME>` 替换为你想运行的镜像名。这条命令会把当前目录挂载到容器的 `/home/user`，并以宿主机当前用户的身份启动容器。

这种方式的优点是简单直接，无需构建新镜像；缺点是每次运行都要手动传入 `--user`，且容器内 `/etc/passwd` 中并不存在这个 UID，部分依赖用户名查找的工具（如 `whoami`、`ls -l` 显示用户名）可能会异常。

## 方法二：自定义 Dockerfile

如果你经常需要以特定用户身份运行容器，更稳妥的做法是构建一个自定义镜像，在镜像里创建一个 UID/GID 与宿主机一致的普通用户。

### 1. 编写 Dockerfile

在 Dockerfile 中通过 `ARG` 接收 UID 和 GID，作为构建参数:

```dockerfile
FROM ubuntu

ARG UID
ARG GID

RUN groupadd --gid $GID nonroot && \
    useradd --uid $UID --gid $GID --create-home nonroot && \
    echo 'nonroot ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

USER nonroot
WORKDIR /home/nonroot
```

> 提示：`groupadd --gid $GID` 和 `useradd --uid $UID` 在 UID/GID 已经被镜像内其他用户占用时会失败（退出码 9）。如果构建时报错，可以加 `-o`（允许非唯一 UID/GID）或在前面用 `getent` 做存在性判断:
>
> ```dockerfile
> RUN (getent group $GID || groupadd --gid $GID nonroot) && \
>     (getent passwd $UID || useradd --uid $UID --gid $GID --create-home nonroot)
> ```

### 2. 构建镜像

构建时把宿主机的 UID/GID 作为 build-arg 传入:

```bash
docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t your-image-name .
```

### 3. 运行容器

用刚才构建好的镜像启动:

```bash
docker run -it --rm your-image-name
```

这种方法在容器内创建了一个与宿主机用户 UID/GID 完全一致的用户，由于 `/etc/passwd` 中也有对应条目，避免了第一种方法中用户名查找异常的问题，两个环境下的文件权限也能保持一致。

## 参考

- [Set current host user for docker container](https://faun.pub/set-current-host-user-for-docker-container-4e521cef9ffc)
- [Docker 官方文档:docker run --user 参数](https://docs.docker.com/reference/cli/docker/container/run/#user)
- [bash 手册:Shell Variables（UID 为只读变量）](https://www.gnu.org/software/bash/manual/html_node/Bash-Variables.html)
