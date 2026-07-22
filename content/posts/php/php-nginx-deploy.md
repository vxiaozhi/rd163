+++
title = "PHP + Nginx 部署模式总览"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从裸机到容器化:三种部署模式的取舍"
description = "对比 PHP + Nginx 在裸机安装、Dockerfile 单镜像、Docker Compose 三种部署方式下的实现与选型要点。"
author = "小智晖"
authors = ["小智晖"]
categories = ["php"]
tags = ["编程语言", "php", "nginx", "docker", "部署", "php-fpm"]
keywords = ["php", "nginx", "php-fpm", "docker", "docker-compose", "部署"]
toc = true
draft = false
+++

在生产环境部署 PHP 应用时，Nginx 与 PHP-FPM(FastCGI Process Manager)的组合是最主流的方案。PHP-FPM 自 PHP 5.3.3 起就已经合并进 PHP 核心代码库(源码位于 `sapi/fpm/`),通过 FastCGI 协议与 Web 服务器通信，负责管理 worker 进程池来执行 PHP 脚本。

围绕这套组合，工程实践中常见三种部署模式：裸机直装、Dockerfile 单镜像、Docker Compose 多容器。它们在易用性、隔离性、可维护性上各有取舍，下文逐一展开。

## 选型对比一览

| 模式 | 复杂度 | 隔离性 | 适用场景 |
|------|--------|--------|----------|
| 裸机安装 | 低（单机） | 弱 | 单机小站、学习测试 |
| Dockerfile 单镜像 | 中 | 中 | 微服务、CI/CD 流水线 |
| Docker Compose 多容器 | 中高 | 强 | 多组件系统（MySQL/Redis 等） |

## 1. 常规部署（裸机安装）

最经典的方式：在 Linux 主机上用系统包管理器分别安装 Nginx 和 PHP-FPM，二者通过本地回环接口或 Unix socket 走 FastCGI 协议通信。配置要点见 [Nginx+PHP-FPM 部署](php-nginx.md)。

核心流程可以概括为三步:

1. 安装服务:`apt install nginx php-fpm`(Debian/Ubuntu)或 `dnf install nginx php-fpm`(RHEL 系)。
2. 让 Nginx 把 `.php` 请求转发给 PHP-FPM 监听的地址(通常是 `127.0.0.1:9000` 或 `/run/php/php-fpm.sock`)。
3. 调优 PHP-FPM 的进程管理器(`pm`)参数，使其匹配机器内存与流量形态。

PHP-FPM 支持三种进程管理模式:

- **`static`**:启动时创建固定数量的 worker，常驻内存，响应最快但占用最大。
- **`dynamic`**:按需在 `pm.min_spare_servers` 与 `pm.max_children` 之间伸缩，是默认值。
- **`ondemand`**:启动时不创建 worker，请求到达时才 fork，空闲超时后回收——内存占用最低，适合低流量场景。

裸机部署的优势是简单直接、性能损耗最小;缺点是环境不可复现，迁移和多版本并存麻烦。

## 2. Dockerfile 单镜像部署

将 Nginx 和 PHP-FPM 打包进同一个镜像，容器内通常用 `supervisord` 或 `s6` 这类进程管理器同时拉起两个守护进程。这种模式违反 Docker「一个容器一个进程」的最佳实践，但部署单元只有一个，适合小型应用或 CI 流水线。

社区有两个广为引用的开源镜像:

- **[TrafeX/docker-php-nginx](https://github.com/TrafeX/docker-php-nginx)**:基于 Alpine Linux，用 supervisord 在非特权用户(`nobody`)下同时运行 Nginx 与 PHP-FPM，两者通过 FastCGI 协议通信，默认走 `ondemand` 进程管理。版本演进值得留意——按官方 releases 记录,**1.x 版本线最后一版是 1.10.0(PHP 7.4)**,从 **2.0.0(2021-04-13)起升级到 PHP 8.0**,目前 3.x 主线最新版本已跟进到 PHP 8.x。如果项目还在 PHP 7.4，只能锁 `1.10.0` 这个 tag。
- **[richarvey/nginx-php-fpm](https://github.com/richarvey/nginx-php-fpm)**:同样基于 Alpine，内置 **PHP 8.2.7 + Nginx 1.24**,亮点是集成了 Let's Encrypt 证书自动签发与续期脚本，适合需要一键 HTTPS 的场景。注意该仓库已有一段时间没有活跃更新，选用前建议核对最近一次发布。

使用 `docker run` 即可拉起:

```bash
docker run -p 80:8080 -v $(pwd)/src:/var/www/html trafex/php-nginx:latest
```

## 3. Docker Compose 部署

这是目前最推荐的方式：把 Nginx 和 PHP-FPM 拆成两个独立容器，通过 Docker 网络互通，需要数据库、缓存等中间件时再追加 service。它的好处是职责清晰、扩缩容方便，缺点是要多维护一份 `docker-compose.yml` 和容器间的共享卷。

一个最小可运行的示例如下:

```yaml
# docker-compose.yml
services:
  php:
    image: php:8.3-fpm-alpine
    volumes:
      - ./src:/var/www/html
    restart: unless-stopped

  nginx:
    image: nginx:1.27-alpine
    ports:
      - "8080:80"
    volumes:
      - ./src:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - php
    restart: unless-stopped
```

对应的 Nginx 配置(把 PHP 请求转给 `php` 这个 service 名解析出的容器):

```nginx
server {
    listen 80;
    server_name localhost;
    root /var/www/html;
    index index.php index.html;

    location ~ \.php$ {
        fastcgi_pass php:9000;       # Compose 网络中,service 名即主机名
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
```

几点容易踩的坑:

- **官方 `php:fpm` 镜像默认不带 PDO MySQL 等扩展**,需要自己在 Dockerfile 里 `docker-php-ext-install pdo_mysql` 或选用带扩展的社区镜像。如果发现连接不上 MySQL，大概率是这一步遗漏。
- **Nginx 与 PHP-FPM 容器必须挂载同一份代码卷**(`./src:/var/www/html`),否则 Nginx 能找到静态文件，但 PHP-FPM 容器里 `SCRIPT_FILENAME` 指向的文件并不存在，会返回 `File not found.`
- **需要数据库时再加一个 `mysql` service** 即可，不要把 MySQL 客户端扩展塞进 PHP-FPM 镜像就以为能直接连。

## 小结

三种模式并非互斥，而是一条渐进路径：本地开发先用裸机或单镜像快速验证，生产环境落到 Compose 多容器以便横向扩展。无论选哪种，理解 Nginx 把 `.php` 请求通过 FastCGI 协议交给 PHP-FPM 的 worker 进程执行，是排查一切问题的起点。

## 参考

- [PHP 官方手册:FastCGI Process Manager (FPM)](https://www.php.net/manual/en/install.fpm.php)
- [TrafeX/docker-php-nginx(GitHub)](https://github.com/TrafeX/docker-php-nginx)
- [richarvey/nginx-php-fpm(GitHub)](https://github.com/richarvey/nginx-php-fpm)
- [Nginx 官方文档:NGINX PHP FastCGI 示例](https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/)
- 站内相关:[Nginx+PHP-FPM 部署](php-nginx.md)
