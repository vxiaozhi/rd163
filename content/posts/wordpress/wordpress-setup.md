+++
title = "WordPress 安装配置实践"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "三种部署方式对比:Docker Compose、官方镜像与腾讯云 Lighthouse"
description = "对比 WordPress 在本地开发与生产环境下的三种常见部署方式,涵盖 Docker Compose、官方 Docker 镜像与腾讯云 Lighthouse 应用镜像的配置要点。"
author = "小智晖"
authors = ["小智晖"]
categories = ["wordpress"]
tags = ["web", "WordPress", "Docker", "腾讯云", "Lighthouse", "部署"]
keywords = ["WordPress 安装", "WordPress Docker", "docker-compose", "腾讯云 Lighthouse", "宝塔面板", "Nginx PHP-FPM"]
toc = true
draft = false
+++

WordPress 的部署方式相当灵活，既可以一条命令在本地起一个测试站，也可以借助云厂商的应用镜像快速搭建生产站点。本文整理三种实际使用过的安装方式，并对比其适用场景。前置的环境要求（PHP 7.4+/8.x、MySQL 5.5+/MariaDB、Apache 或 Nginx）在《为什么选择 WordPress》一文中已有说明，这里不再赘述。

## 三种方式概览

| 方式 | 适用场景 | 数据库 | Web 服务器 | 运维成本 |
| --- | --- | --- | --- | --- |
| docker-compose | 本地开发、插件/主题调试 | 容器内 MySQL | Apache(官方镜像内置) | 低 |
| 官方 Docker 镜像 | 已有外部 MySQL/MariaDB | 外部 | Apache | 中 |
| 腾讯云 Lighthouse 应用镜像 | 小型生产站点 | MariaDB | Nginx + PHP-FPM | 中（可视化面板） |

## 基于 docker-compose 的本地方式

如果只是想在本地快速跑起来看效果、调试主题或插件，推荐使用 [nezhar/wordpress-docker-compose](https://github.com/nezhar/wordpress-docker-compose)。这个仓库用一份 `docker-compose.yml` 把 WordPress 所需的服务编排在一起，核心包含三类容器:

- **WordPress**:基于官方 `wordpress` 镜像，内置 Apache + PHP，无需自行配置 Web 服务器。
- **MySQL**:作为数据库后端。
- **phpMyAdmin**:数据库可视化管理，默认监听 `http://127.0.0.1:8080`。

此外还带了一个 `wpcli` 服务用于执行 WP-CLI 命令，作者建议的别名是:

```bash
alias wp="docker-compose run --rm wpcli"
```

典型使用流程：把仓库根目录的 `env.example` 复制为 `.env`,按需修改 IP、MySQL root 密码与数据库名，然后:

```bash
docker-compose up -d
```

容器启动后会自动在当前目录生成 `wp-app`(WordPress 程序文件)和 `wp-data`(数据库文件)两个卷目录。要导出数据库，可以用仓库自带的 `export.sh` 脚本。

需要说明的是，这套编排里**没有 nginx**——它复用官方 WordPress 镜像自带的 Apache，对于本地调试已经足够，不建议把它直接搬到公网生产环境。

## 基于官方 Docker 镜像的方式

如果机器上已经有一套独立维护的 MySQL/MariaDB 服务（例如其他业务共用）,那么没必要再起一个数据库容器，直接用 [Docker 官方 WordPress 镜像](https://hub.docker.com/_/wordpress) 即可，仓库源码见 [docker-library/wordpress](https://github.com/docker-library/wordpress)。

官方镜像按 Web 服务器与基础系统提供了几个变种（variant）:

- `wordpress:<version>`:默认版本，内置 **Apache** + PHP，开箱即用。
- `wordpress:<version>-fpm`:基于 PHP-FPM(FastCGI Process Manager),需要在前面再加一层 Nginx 反向代理。Docker Hub 官方文档明确警告，FastCGI 协议本身不做鉴权,**绝不能直接暴露到公网**,只能在容器私网内通信。
- `wordpress:<version>-fpm-alpine`:同上，基础镜像换成了 Alpine，体积更小。
- `wordpress:cli`:只装 WP-CLI，不含 WordPress 本体，用于命令行维护。

复用外部数据库时，通过环境变量指定连接信息:

```bash
docker run --name some-wordpress \
  -p 8080:80 -d \
  -e WORDPRESS_DB_HOST=mysql.example.com:3306 \
  -e WORDPRESS_DB_USER=wp_user \
  -e WORDPRESS_DB_PASSWORD=******** \
  -e WORDPRESS_DB_NAME=wordpress \
  wordpress
```

需要注意,`WORDPRESS_DB_NAME` 指定的数据库**必须已经存在**,容器不会自动创建。如果不想把密码直接写在命令行里，可以用 `_FILE` 后缀的变量(如 `WORDPRESS_DB_PASSWORD_FILE=/run/secrets/wp_db_pwd`)让 Docker 从文件或 secret 读取。

## 基于腾讯云 Lighthouse WordPress 应用镜像

对于真正面向用户的生产站点，前两种容器方式在 HTTPS 签发、防火墙、面板管理上都要自己折腾。腾讯云轻量应用服务器（Lighthouse）提供了 **WordPress 应用镜像**,本质是把整套 LAMP/LEMP 栈预装进系统镜像，开机即用，相比前两种方式的优势在于:

- **一站式集成**:预装 Nginx + PHP-FPM + MariaDB + 宝塔面板（BT Panel）,省去手工编译与配置。
- **服务托管化**:Nginx、PHP-FPM、MariaDB 都已注册为 systemd 服务，支持 `systemctl` 启停与开机自启，异常退出后能被自动拉起。
- **可视化运维**:宝塔面板提供网站、数据库、SSL、计划任务等图形化管理，对非技术用户友好。

本站部署时使用的镜像版本对应目录大致如下:

| 组件 | 路径 |
| --- | --- |
| WordPress | `/usr/local/lighthouse/softwares/wordpress` |
| Nginx | `/www/server/nginx/` |
| PHP | `/www/server/php` |
| MariaDB | `/www/server/mysql/` |
| 宝塔 Linux 面板 | `/www` |

请求处理链路与标准 LEMP 一致:

```
用户 → Nginx(80/443) → fastcgi_pass → PHP-FPM(9000) → WordPress PHP
                                                    ↕
                                              MariaDB(3306)
```

服务管理的常用命令:

```bash
sudo systemctl restart nginx
sudo systemctl restart php-fpm        # 实际服务名视 PHP 版本而定,如 php81-php-fpm
sudo systemctl restart mariadb
```

### 在镜像内补装 Docker

腾讯云镜像默认不带 Docker，如果后续想在这台机器上跑其他容器服务，需要手动安装。以 CentOS 7(kernel `3.10.0-1160.108.1.el7.x86_64`)为例，先安装 `yum-utils`(提供 `yum-config-manager`),再添加 Docker 官方稳定仓库:

```bash
# 安装 yum-config-manager 工具
sudo yum install -y yum-utils

# 添加 Docker CE 稳定仓库
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

# 安装 Docker 引擎与 containerd
sudo yum install -y docker-ce docker-ce-cli containerd.io

# 启动并设置开机自启
sudo systemctl start docker
sudo systemctl enable docker

# 验证安装
sudo docker run hello-world
```

> 注:CentOS Stream / CentOS 9 默认使用 `dnf`,`yum-utils` 应替换为 `dnf-plugins-core`,`yum` 命令换成 `dnf`。具体以 [Docker 官方安装文档](https://docs.docker.com/engine/install/centos/) 为准。

## 选型建议

三种方式并非互相替代，而是对应不同阶段:

- **本地开发/插件主题调试**:docker-compose 起停最快，适合频繁重建环境。
- **个人小型站点**:已有数据库实例时，官方 Docker 镜像最轻量，但要自己处理反代和证书。
- **对外的生产博客/企业站**:Lighthouse 应用镜像提供了完整的运维链路，适合不想在系统层花太多精力的团队。

实际操作中，也可以把它们组合使用——本地用 docker-compose 调试，正式上线用 Lighthouse 镜像，中间通过 WP-CLI 或数据库导入导出完成内容迁移。

## 参考

- [nezhar/wordpress-docker-compose - GitHub](https://github.com/nezhar/wordpress-docker-compose)
- [Docker Official Image packaging for WordPress - GitHub](https://github.com/docker-library/wordpress)
- [WordPress - Docker Hub](https://hub.docker.com/_/wordpress)
- [Docker Engine 官方安装文档（CentOS）](https://docs.docker.com/engine/install/centos/)
- [腾讯云轻量应用服务器产品文档](https://cloud.tencent.com/document/product/1207)
