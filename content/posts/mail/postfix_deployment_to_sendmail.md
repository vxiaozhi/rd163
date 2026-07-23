+++
title = "部署postfix服务进行发送邮件"
date = "2025-07-09"
lastmod = "2025-07-09"
subtitle = "Postfix 邮件服务器部署标准化流程与安全加固实践"
description = "面向仅需发送邮件(监控报警、事务通知)的场景,介绍 Postfix 的安装、核心配置、TLS 加密、SPF/DKIM 反垃圾邮件、访问限制及日常维护的完整生产环境流程。"
author = "小智晖"
authors = ["小智晖"]
categories = ["运维", "mail"]
tags = ["mail", "postfix", "DKIM", "SPF", "TLS", "邮件服务器"]
keywords = ["postfix", "邮件服务器", "sendmail", "DKIM", "SPF", "TLS"]
toc = true
draft = false
+++

## 概述

若只需发送邮件（如监控报警、事务通知）,无需接收邮件，可采用 Postfix 或 SSMTP 的极简配置。本文介绍如何部署 Postfix 服务进行发送邮件。

如果需要收发同时支持，可采用 iRedMail 部署。

以下是 **Postfix 邮件服务器部署的标准化流程**,涵盖从安装到安全加固的完整步骤，适用于生产环境。

---

## 一、基础部署流程

### 1. 环境准备

**系统要求**:

- 操作系统:Ubuntu 22.04 / CentOS 8(推荐)
- 硬件:1 核 2GB 内存（支持约 1000 用户/日）
- 域名：已注册域名(如 `example.com`)

**DNS 预配置**:

```text
MX 记录  → mail.example.com [优先级 10]
A 记录   → mail.example.com → 服务器 IP
PTR 记录 → 服务器 IP 反向解析为 mail.example.com(需云厂商支持,阿里云解析 DNS 不支持)
```

用如下命令检测 DNS 配置是否生效:

```bash
dig +short MX example.com
dig +short A mail.example.com
```

### 2. 安装 Postfix

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install postfix mailutils

# CentOS/RHEL
sudo yum install postfix mailx
```

说明:Ubuntu 上 `mail` 命令由 `mailutils` 提供，CentOS/RHEL 上则由 `mailx` 提供，两者作用相同。安装时选择 **Internet Site**,并输入主域名(如 `example.com`)。

### 3. 核心配置（/etc/postfix/main.cf）

```ini
# 基础参数
myhostname = mail.example.com
mydomain = example.com
myorigin = $mydomain
inet_interfaces = all
mydestination = $myhostname, localhost.$mydomain, localhost

# 网络访问控制
mynetworks = 127.0.0.0/8, [::1]/128, 192.168.1.0/24

# 邮件存储格式
home_mailbox = Maildir/
```

### 4. 启用加密端口

编辑 `/etc/postfix/master.cf`,取消注释 `submission` 段:

```ini
submission inet n - y - - smtpd
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
```

`submission` 启用后，会在 587 端口监听。`smtpd_tls_security_level=encrypt` 表示强制客户端使用 STARTTLS 加密，未加密连接将被拒绝。

---

## 二、安全加固流程

### 1. TLS 证书配置

```bash
# 使用 Let's Encrypt
sudo certbot certonly --standalone -d mail.example.com
```

在 `/etc/postfix/main.cf` 添加:

```ini
smtpd_tls_cert_file=/etc/letsencrypt/live/mail.example.com/fullchain.pem
smtpd_tls_key_file=/etc/letsencrypt/live/mail.example.com/privkey.pem
smtpd_tls_security_level=may
```

### 2. 反垃圾邮件配置

**SPF 记录（DNS TXT）**:

```text
example.com. IN TXT "v=spf1 mx ip4:your_server_ip ~all"
```

其中 `your_server_ip` 需替换为你的服务器 IPv4 地址，例如 `ip4:203.0.113.10`。`~all` 表示软失败（对方接受但标记可疑）,生产环境若确定发送源可改为 `-all` 强制拒绝。

**DKIM 签名**:

```bash
sudo opendkim-genkey -D /etc/opendkim/keys/ -d example.com -s default
sudo chown opendkim:opendkim /etc/opendkim/keys/default.private
```

执行后生成 `default.private`(私钥)与 `default.txt`(待发布的 DNS TXT 记录，记录名形如 `default._domainkey.example.com`)。

SPF 或 DKIM 如果未配置，则邮件可能会被垃圾邮件过滤器拒绝。下面是一段 Gmail 实际返回的退信日志示例:

```text
to=<whutluohui@gmail.com>, relay=gmail-smtp-in.l.google.com[172.253.118.26]:25,
  delay=2.8, delays=0.02/0.01/0.47/2.3, dsn=5.7.26, status=bounced
  (host gmail-smtp-in.l.google.com[172.253.118.26] said:
   550-5.7.26 Your email has been blocked because the sender is unauthenticated.
   550-5.7.26 Gmail requires all senders to authenticate with either SPF or DKIM.
   550-5.7.26 Authentication results:
   550-5.7.26   DKIM = did not pass
   550-5.7.26   SPF [agrfactory.com] with ip: [43.134.183.194] = did not pass
   550-5.7.26 For instructions on setting up authentication, go to
   550 5.7.26 https://support.google.com/mail/answer/81126#authentication
   (in reply to end of DATA command))
```

Postfix 集成 OpenDKIM 配置(写入 `/etc/postfix/main.cf`):

```ini
milter_protocol = 6
smtpd_milters = inet:localhost:8891
non_smtpd_milters = inet:localhost:8891
```

> 注:`milter_protocol` 建议使用 `6`(对应 Sendmail 8.14 及以上版本的 Milter 协议),OpenDKIM 在该版本下能正确处理头部插入与宏传递。使用旧版 `2` 可能导致签名头位置异常或被后续 milter 还原。

### 3. 访问限制

```ini
smtpd_client_restrictions = permit_mynetworks, reject_unknown_client
smtpd_helo_restrictions = reject_invalid_helo_hostname
smtpd_sender_restrictions = reject_unknown_sender_domain
```

---

## 三、服务验证与测试

### 1. 启动服务

```bash
sudo systemctl restart postfix
sudo postfix check  # 检查语法
```

### 2. 发送测试邮件

```bash
echo "Test Body" | mail -s "Test Subject" user@example.com
echo "Test Body" | mail -s "Test Subject" -r lighthouse@example.com test@gmail.com
```

### 3. 日志监控

```bash
tail -f /var/log/mail.log          # 实时日志
grep 'status=sent' /var/log/mail.log  # 成功发送记录
```

> 注:CentOS/RHEL 上日志路径通常是 `/var/log/maillog`,而非 `/var/log/mail.log`。

### 4. 端口验证

```bash
telnet mail.example.com 25                              # SMTP 基础测试
openssl s_client -connect mail.example.com:587 -starttls smtp  # TLS 加密测试
```

---

## 四、维护与优化

### 1. 日常维护命令

```bash
postqueue -p        # 查看邮件队列
postsuper -d ALL    # 清空队列(谨慎使用,ALL 必须大写)
mailq | head        # 查看队列前若干条
```

> 注:`postsuper -d ALL` 中的 `ALL` 必须为大写;若误写为小写 `all`,Postfix 会将其当作普通 queue id 处理，既不删除任何邮件，也不会报错。

### 2. 性能优化参数（/etc/postfix/main.cf）

```ini
default_process_limit = 100
smtpd_client_connection_count_limit = 20
message_size_limit = 52428800  # 允许 50MB 附件(单位为字节)
```

> 注:`message_size_limit` 接收的是字节数,`50M` 这种带单位的写法 Postfix 并不识别，需写成 `52428800`;同样 `smtpd_client_connection_count_limit`(注意 `_count`)才是限制单客户端并发连接数的正确参数名,`smtpd_client_connection_limit` 不存在、会被静默忽略。

### 3. 备份策略

- **邮件数据**:定时打包 `/home/*/Maildir`
- **配置备份**:

```bash
tar czf postfix_backup_$(date +%F).tar.gz /etc/postfix /etc/opendkim
```

---

## 参考

- [Postfix 官方文档](http://www.postfix.org/documentation.html)
- [Postfix `postconf` 参数手册](http://www.postfix.org/postconf.5.html)
- [OpenDKIM 项目](http://www.opendkim.org/)
- [OpenSPF 文档](http://www.open-spf.org/)
- [Gmail 批量发件人要求](https://support.google.com/mail/answer/81126)
