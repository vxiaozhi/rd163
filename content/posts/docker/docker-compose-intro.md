+++
title = "docker-compose 简介"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "用 volumes 管理数据卷的两种姿势"
description = "介绍 docker-compose 中 volumes 的两种挂载方式(本地路径与命名卷),以及如何用 docker volume 命令查看卷标真实路径。"
author = "小智晖"
authors = ["小智晖"]
categories = ["docker"]
tags = ["docker", "docker-compose", "volume"]
keywords = ["docker-compose", "volumes", "docker volume", "数据卷", "持久化"]
toc = true
draft = false
+++

## docker-compose 中 volumes 参数说明

docker-compose 通过 `volumes` 配置数据卷来实现数据持久化。常见有两种写法。

**第一种：本地路径直接挂载（bind mount）**

```yaml
ghost:
  image: ghost
  volumes:
    - ./ghost/config.js:/var/lib/ghost/config.js
```

**第二种：使用命名卷（named volume）**

```yaml
services:
  mysql:
    image: mysql
    container_name: mysql
    volumes:
      - mysql:/var/lib/mysql
# ...
volumes:
  mysql:
```

> 第一种方式将宿主机路径直接挂载到容器，比较直观，但需要自己管理本地路径。
> 第二种使用命名卷，写法更简洁，但数据存在宿主机的某个默认位置，不易一眼看到。下面说明如何查看命名卷的真实位置。

查看所有卷标:

```bash
docker volume ls
```

查看某个 volume 对应的真实地址:

```bash
$ docker volume inspect vagrant_mysql
[
  {
    "Name": "vagrant_mysql",
    "Driver": "local",
    "Mountpoint": "/var/lib/docker/volumes/vagrant_mysql/_data"
  }
]
```

可以看到，命名卷默认存放在宿主机的 `/var/lib/docker/volumes/<卷名>/_data` 目录下。

## 参考

- [Difference between "docker compose" and "docker-compose"](https://stackoverflow.com/questions/66514436/difference-between-docker-compose-and-docker-compose)
- [docker-compose 和 docker compose 的区别](https://www.cnblogs.com/zhaodalei/p/17553269.html)
- [Docker Compose overview](https://docs.docker.com/compose/)
- [Docker Compose v2 github](https://github.com/docker/compose)
- [docker: 'compose' is not a docker command when installing using convenience scripts](https://github.com/docker/compose/issues/8630)
- [Docker Volumes 官方文档](https://docs.docker.com/engine/storage/volumes/)
