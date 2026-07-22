+++
title = "Nginx + PHP-FPM 部署与调优"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从 FastCGI 协议到进程池调优的完整配置指南"
description = "梳理 Nginx 反向代理 PHP-FPM 的 FastCGI 通信原理、Nginx 与 php-fpm 配置要点,以及 static/dynamic/ondemand 三种进程管理模式的调优思路。"
author = "小智晖"
authors = ["小智晖"]
categories = ["php"]
tags = ["编程语言", "php", "nginx", "php-fpm", "fastcgi", "部署", "性能调优"]
keywords = ["php-fpm", "nginx", "fastcgi", "php 部署", "进程池调优", "pm dynamic"]
toc = true
draft = false
+++

PHP-FPM(FastCGI Process Manager)是 PHP 官方维护的 FastCGI 协议实现，自 **PHP 5.3.3(2010 年 7 月发布)** 起合并进 PHP 核心代码库，在此之前它只是 Andréi Nigmatulin 维护的一个独立补丁。合并后，编译 PHP 时加上 `--enable-fpm` 即可获得 `php-fpm` 二进制，SAPI(Server API)名称为 `fpm-fcgi`。源码位于 PHP 主仓库的 `sapi/fpm/` 目录，入口文件为 [`sapi/fpm/fpm/fpm_main.c`](https://github.com/php/php-src/blob/master/sapi/fpm/fpm/fpm_main.c)。

在与 Nginx 搭配时，PHP-FPM 负责管理 worker 进程池执行 PHP 脚本，Nginx 只承担静态资源服务与反向代理，二者通过 FastCGI 协议通信。本文梳理这套组合的配置与调优要点。

## 工作原理

PHP-FPM 服务启动时会先拉起一个 **master 进程**,负责解析配置、初始化执行环境，并根据 `pm` 指令创建若干 **worker 进程**。Nginx 收到 `.php` 请求后，通过 FastCGI 协议把请求转给 PHP-FPM 监听的地址（TCP 或 Unix domain socket）,master 把连接分派给某个空闲 worker,worker 执行完 PHP 脚本后将响应回传给 Nginx，再由 Nginx 返回给客户端。

整个链路的关键在于:`SCRIPT_FILENAME` 这个 FastCGI 参数必须正确指向磁盘上真实存在的 PHP 文件，否则 PHP-FPM 会直接返回 `File not found.` 或 `Primary script unknown`。

## Nginx 配置

下面是一份经过安全加固的最小可用配置:

```nginx
server {
    listen      80;                       # http 用 80,https 用 443 ssl
    server_name example.com;
    root        /var/www/html;
    index       index.php index.html index.htm;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        try_files        $uri =404;                            # 文件不存在直接 404,防止 PATH_INFO 解析攻击
        fastcgi_pass     127.0.0.1:9000;                      # 也可用 unix:/run/php/php8.1-fpm.sock
        fastcgi_index    index.php;
        include          fastcgi.conf;                        # 已包含 SCRIPT_FILENAME,无需重复设置
    }
}
```

几个容易踩的坑:

- **正则要转义点号**:`location ~ \.php$` 中的 `.` 必须写成 `\.`,否则 `xxphp` 这类请求也会被匹配。
- **`fastcgi.conf` 与 `fastcgi_params` 的区别**:Nginx 在 0.8.30(2009 年)引入了 `fastcgi.conf`,它在 `fastcgi_params` 的基础上多了 `fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;` 一行，就是为了避免历史版本里大家总是忘记手动加这一行而导致的「白屏」问题。两者**不要同时 include**,也不要在 include `fastcgi.conf` 后再写一遍 `SCRIPT_FILENAME`,否则会向 PHP-FPM 发送重复参数。
- **务必加 `try_files $uri =404`**:历史上配合 `cgi.fix_pathinfo=1`(老版本默认值)出现过经典的 `avatar.png/.php` 上传漏洞——攻击者把 PHP 代码塞进图片，通过 PATH_INFO 让 PHP-FPM 当成脚本执行。`try_files` 在转发前确认文件真实存在，是最简单有效的防护。
- **如果框架需要 PATH_INFO**(如 CodeIgniter、部分 REST 路由),再加一组拆分指令:

    ```nginx
    fastcgi_split_path_info ^(.+\.php)(/.*)$;
    fastcgi_param PATH_INFO $fastcgi_path_info;
    ```

    同时在 `php.ini` 中设置 `cgi.fix_pathinfo = 0`、`security.limit_extensions = .php`。

## PHP-FPM 配置

### 安装

Debian/Ubuntu 用 apt 安装,版本号会跟发行版绑死:Debian 12 默认是 `php8.2-fpm`,Ubuntu 22.04 是 `php8.1-fpm`,Ubuntu 24.04 是 `php8.3-fpm`。

```bash
apt update && apt install -y php-fpm nginx
```

### 修改监听地址

编辑对应版本的 pool 配置(以 8.1 为例):

```bash
vim /etc/php/8.1/fpm/pool.d/www.conf
```

TCP 监听是最常见的写法:

```ini
listen = 127.0.0.1:9000
listen.allowed_clients = 127.0.0.1
```

如果 Nginx 与 PHP-FPM 同机部署,改用 Unix socket 性能更好——少了 TCP 协议栈的开销,基准测试下吞吐通常有 15%–30% 的提升:

```ini
listen = /run/php/php8.1-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
```

此时 Nginx 端对应改成 `fastcgi_pass unix:/run/php/php8.1-fpm.sock;`。

### 重启服务

```bash
systemctl restart php8.1-fpm
systemctl status  php8.1-fpm    # 确认 active (running)
```

修改配置后用 `reload` 即可平滑重载,不会中断在途请求:`systemctl reload php8.1-fpm`。

## 进程管理模式

`pool.d/www.conf` 里的 `pm` 指令决定 PHP-FPM 如何创建 worker,直接决定内存占用与突发并发能力。三种模式各有适用场景:

| 模式 | 行为 | 适用场景 |
|------|------|----------|
| `static` | 启动时按 `pm.max_children` 创建固定数量的 worker,常驻内存 | 流量稳定、内存充裕的生产服务 |
| `dynamic` | 在 `pm.min_spare_servers` / `pm.max_spare_servers` 之间动态伸缩,启动时按 `pm.start_servers` 创建 | 通用默认值,大部分 Web 应用 |
| `ondemand` | 启动时不创建 worker,请求到达才 fork,空闲超时(`pm.process_idle_timeout`)后回收 | 内存敏感、低流量或开发环境 |

`dynamic` 的推荐起步配置:

```ini
pm = dynamic
pm.max_children = 50          ; 同时并发的最大 worker 数
pm.start_servers = 5          ; 启动时创建的 worker 数
pm.min_spare_servers = 5      ; 空闲时最少保留的 worker 数
pm.max_spare_servers = 35     ; 空闲时最多保留的 worker 数
pm.max_requests = 500         ; 每个 worker 处理 500 个请求后重启，防止第三方扩展内存泄漏
```

`pm.max_children` 是最关键的参数,设置过大极易触发 OOM。常见估算公式:

```
max_children ≈ (可用内存) / (单个 worker 平均内存)
```

例如 8GB 内存、其他服务占用 2GB、单个 worker 约 80MB,则 `max_children ≈ 6144 / 80 ≈ 76`,生产环境通常再保守取 50–60。

## 排错与运维

- **查看状态页**:在 `www.conf` 中开启 `pm.status_path = /status`,再在 Nginx 里把 `/status` 转发给 PHP-FPM,即可看到当前 worker 数、空闲数、最近请求等指标,Prometheus 抓取还可选用 `openmetrics` 输出格式。
- **慢日志**:设置 `slowlog = /var/log/php8.1-fpm.slow.log` 与 `request_slowlog_timeout = 5s`,可以记录执行超过 5 秒的脚本及其 PHP backtrace,是定位卡死接口的利器。
- **Windows 不支持 PHP-FPM**:FPM 依赖 `fork()` 系统调用,Windows 上只能用 `php-cgi.exe`,但后者没有进程池管理能力。
- **`fastcgi_finish_request()`**:PHP-FPM 独有的一个函数,调用后会先把响应刷回客户端,PHP 进程继续在后台执行耗时任务(发邮件、写日志、推埋点),是简单实现「异步收尾」的常用手段。

## 参考

- [PHP 官方手册:FastCGI Process Manager (FPM)](https://www.php.net/manual/en/install.fpm.php)
- [PHP 官方手册:configuration 关于 pm 参数](https://www.php.net/manual/en/install.fpm.configuration.php)
- [Nginx 官方文档:NGINX PHP FastCGI 示例](https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/)
- [PHP 5.3.3 Release Announcement](https://www.php.net/releases/5_3_3.php)
- [php/php-src 仓库(sapi/fpm 源码)](https://github.com/php/php-src/tree/master/sapi/fpm)
- 站内相关:[PHP + Nginx 部署模式总览](php-nginx-deploy.md)
