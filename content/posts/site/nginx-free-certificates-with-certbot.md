+++
title = "使用 Certbot 为 Nginx 网站服务器设置永久免费的 HTTPS 证书"
date = "2025-01-13"
lastmod = "2025-01-13"
subtitle = "基于 Webroot 模式申请 Let's Encrypt 证书并配置自动续签"
description = "介绍在 Nginx 上使用 Certbot 的 Webroot 模式申请 Let's Encrypt 免费 HTTPS 证书,并配置 cron 定时任务实现自动续签的完整流程。"
author = "小智晖"
authors = ["小智晖"]
categories = ["site"]
tags = ["建站", "Nginx", "Certbot", "HTTPS", "Let's Encrypt"]
keywords = ["Certbot", "Nginx", "HTTPS", "Let's Encrypt", "免费证书", "Webroot"]
toc = true
draft = false
+++

目前流行的免费 HTTPS 证书申请方案主要有两种:

- [acme.sh](https://github.com/acmesh-official/acme.sh):采用纯 Shell 实现，拥有完善的中文文档，依赖少，适合脚本化场景。
- [Certbot](https://certbot.eff.org/):由 EFF(Electronic Frontier Foundation)维护，官方文档完善，与 Let's Encrypt 配套使用最为广泛。

本文介绍第二种方式，即在 Nginx 上使用 Certbot 的 Webroot 模式申请并自动续签证书。

参考:[使用 Nginx 结合 CertBot 配置 HTTPS 协议](https://developer.aliyun.com/article/689901)

## Certbot 安装

官网:<https://certbot.eff.org>

官方提供了交互式的安装指引，可在 <https://certbot.eff.org/instructions> 选择对应的操作系统与 Web 服务器获取最新命令。

Certbot 打包在 EPEL(Extra Packages for Enterprise Linux，企业版 Linux 扩展包)仓库中，使用前必须先启用 EPEL 仓库;在 RHEL 或 Oracle Linux 中还需启用可选频道（optional channel）。可执行如下命令安装 Certbot:

```bash
sudo yum install epel-release
sudo yum install certbot
```

> 说明:CentOS 7 已于 2024 年 6 月停止维护（EOL）。若你使用的是较新的系统（如 RHEL 8/9、CentOS Stream、Rocky Linux、AlmaLinux 等）,建议优先参考官方指引，使用 `dnf` 或推荐的 `snap`/`pip` 方式安装。

## 生成证书

我们需要先配置 Nginx 来完成服务器域名验证。Certbot 的 standalone 模式虽然能直接签发证书，但每次 90 天到期续签时都需要短暂停止 Web 服务再启动，会中断访问。因此本文改用 **Webroot 模式**:Certbot 会在指定的 Web 根目录下生成一个随机验证文件，Let's Encrypt 服务器通过 HTTP 访问该文件来确认域名所有权。这样续签时无需停机。

修改 Nginx 配置，在 80 端口的 server 模块中新增一个 location:

```nginx
server {
    listen       80;
    server_name  your.domain.com; # 这里填你要验证的域名

    location ^~ /.well-known/acme-challenge/ {
        default_type "text/plain";
        root         /usr/share/nginx/html/; # 需与下文 --webroot -w 的路径一致
    }
}
```

配置完成后，重载 Nginx:

```bash
sudo service nginx reload
```

然后执行证书申请命令:

```bash
sudo certbot certonly --webroot -w /usr/share/nginx/html/ -d your.domain.com
```

记得将 `your.domain.com` 替换为你自己的域名。

如果看到类似下面的提示，说明证书生成成功:

```text
IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at
   /etc/letsencrypt/live/your.domain.com/fullchain.pem. Your cert
   will expire on 20XX-09-23. To obtain a new or tweaked version of
   this certificate in the future, simply run certbot again. To
   non-interactively renew *all* of your certificates, run "certbot
   renew"
 - If you like Certbot, please consider supporting our work by:

   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le
```

接着启用 443 端口。修改 Nginx 配置文件，新建一个 443 端口的 server 配置:

```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl ipv6only=on;

    ssl_certificate     /etc/letsencrypt/live/your.domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your.domain.com/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/your.domain.com/chain.pem;

    # ... 其他配置项 ...
}
```

记得将 `your.domain.com` 替换为你自己的域名。

再次重载 Nginx:

```bash
sudo service nginx reload
```

至此，网站已成功启用免费的 HTTPS 证书。

> 提示:nginx 1.25.1 起弃用了 `listen ... ssl http2` 的组合写法，如需启用 HTTP/2，应改用独立的 `http2 on;` 指令。

## 删除证书

如果因为种种原因生成了多余的证书，它们会一直留在服务器上造成冗余。Let's Encrypt 官方并未提供"取消授权"的接口，但可以在本地删除证书文件并停止续签，从而释放该证书。进入对应目录，查看已生成的证书域名文件夹，然后依次删除即可(记得将 `your.domain.com` 替换为你要删除的域名):

```bash
cd /etc/letsencrypt/live/
ls
sudo rm -rf /etc/letsencrypt/live/your.domain.com/
sudo rm -rf /etc/letsencrypt/archive/your.domain.com/
sudo rm -f /etc/letsencrypt/renewal/your.domain.com.conf
```

## 设置自动续签

由于 Let's Encrypt 的免费证书有效期只有 90 天，需要设置自动续签任务来定期刷新证书。

在 CentOS 等系统上可以使用 `crontab` 配置定时任务。先在命令行模拟一次续签:

```bash
sudo certbot renew --dry-run
```

如果出现类似下面的提示，说明模拟续签成功:

```text
-------------------------------------------------------------------------------
Processing /etc/letsencrypt/renewal/your.domain.com.conf
-------------------------------------------------------------------------------
** DRY RUN: simulating 'certbot renew' close to cert expiry
**          (The test certificates below have not been saved.)

Congratulations, all renewals succeeded. The following certs have been renewed:
  /etc/letsencrypt/live/your.domain.com/fullchain.pem (success)
** DRY RUN: simulating 'certbot renew' close to cert expiry
**          (The test certificates above have not been saved.)
```

接下来使用 `crontab -e` 添加定时任务:

```bash
sudo crontab -e
```

进入编辑模式后，加入以下内容(每天凌晨 2 点 30 分执行一次续签，日志写入 `/var/log/le-renew.log`):

```cron
30 2 * * * /usr/bin/certbot renew >> /var/log/le-renew.log
```

保存退出后，可在命令行手动执行一次 `/usr/bin/certbot renew >> /var/log/le-renew.log` 验证是否正常。若一切 OK，则自动续签配置完成。

> 补充：通过官方推荐的 `snap` 或包管理器安装的 Certbot，通常会自动注册 `systemd` 定时器(`certbot.timer`),无需再手动添加 cron 任务。可通过 `systemctl list-timers | grep certbot` 查看是否已存在。

## 参考

- [Certbot 官方文档](https://certbot.eff.org/)
- [Let's Encrypt 官方文档](https://letsencrypt.org/docs/)
- [acme.sh 项目仓库](https://github.com/acmesh-official/acme.sh)
- [使用 Nginx 结合 CertBot 配置 HTTPS 协议](https://developer.aliyun.com/article/689901)
