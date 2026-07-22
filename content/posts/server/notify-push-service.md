+++
title = "通知推送服务方案"
date = "2025-05-31"
lastmod = "2025-05-31"
subtitle = "Bark 与 ntfy 两款可自建的通知推送服务对比"
description = "对比 Bark(bark-server)与 ntfy 两款开源、可自建的通知推送服务,涵盖架构、部署、API 调用及选型建议。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "push", "notification", "self-hosted", "bark", "ntfy"]
keywords = ["推送服务", "Bark", "ntfy", "自建推送", "bark-server", "通知推送"]
toc = true
draft = false
+++

在服务端开发与运维场景中,常常需要把监控告警、构建结果、定时任务状态等信息以推送通知的形式实时发送到手机或桌面。直接接入各厂商的推送通道(APNs、FCM)成本较高,而第三方 SaaS 又涉及数据出境和付费问题。此时,**自建通知推送服务**成为一种兼顾可控性与简洁性的选择。

本文介绍两款主流的开源推送服务——Bark 与 ntfy,并给出对比与选型建议。两者都支持自建,但定位差异明显:Bark 偏向 iOS 个人用户的轻量推送,ntfy 则是一个跨平台的 pub/sub 通知系统。

## Bark:iOS 用户的轻量推送

[Bark](https://github.com/Finb/Bark) 是一款 iOS 端的自定义推送工具,主打「免费、简单、安全」,借助苹果 APNs(Apple Push Notification service)下发,不在后台常驻进程,因此不会额外耗电。需要注意:**Bark 客户端仅有 iOS 版本**,没有官方 Android 实现。

### 工作原理

Bark 的链路非常简单:

1. 在 iOS 设备上安装 Bark App,App 启动后会向 APNs 注册并获得一个唯一的 `key`;
2. 服务调用方把这个 `key` 与自定义的标题、正文等内容发往 bark-server;
3. bark-server 转发给 APNs,再由 APNs 投递到 iPhone。

整个过程中,设备本身不暴露公网地址,推送也能在锁屏、息屏状态下到达。

### 自建 bark-server

[bark-server](https://github.com/Finb/bark-server) 使用 Go 编写,以 MIT 协议开源。默认使用内嵌的 Bbolt 文件数据库存储数据,数据目录默认为 `/data`;如果数据量较大或需要共享存储,可通过 `-dsn` 参数切换到 MySQL:

```bash
# 使用 Docker Hub 镜像启动
docker run -dt --name bark \
  -p 8080:8080 \
  -v "$(pwd)/bark-data:/data" \
  finab/bark-server
```

二进制部署时常用的启动参数:

```bash
bark-server \
  --addr 0.0.0.0:8080 \
  --data ./bark-data
# 切换到 MySQL:
# bark-server -dsn=user:pass@tcp(mysql_host)/bark
```

### API 调用

Bark 的接口非常直观,URL 路径本身就承载了内容,最低成本的调用方式是直接 GET 一个 URL:

```bash
# 最简形式:key/body
curl https://api.day.app/YOUR_KEY/这是正文

# 带标题:key/title/body
curl https://api.day.app/YOUR_KEY/告警/CPU使用率超过90%

# POST JSON 方式(更灵活,推荐)
curl -X POST https://api.day.app/YOUR_KEY \
  -H "Content-Type: application/json" \
  -d '{
    "title": "构建结果",
    "body": "main 分支构建成功",
    "group": "ci",
    "sound": "bell",
    "level": "timeSensitive",
    "url": "https://ci.example.com/job/1234"
  }'
```

URL 路径的完整形态为 `/:key/:title/:subtitle/:body`,POST JSON 时则可携带更多参数。

### 主要特性

- **分组(group)**:按业务线把通知聚合到一组,避免通知中心被刷屏。
- **自定义图标与声音**:图标支持在 iOS 15+ 上自定义;声音可指定音效,也支持 30 秒循环的「电话来电」提醒模式。
- **中断级别(level)**:`active`(默认,亮屏)、`timeSensitive`(可在专注模式下穿透)、`passive`(仅加入通知列表,不亮屏)。
- **严重告警(critical)**:忽略静音与勿扰模式,适合无人值守的告警。
- **端到端加密**:通过 `ciphertext` 参数推送加密内容,密钥仅客户端持有。
- **点击跳转(url)**:点击通知后打开指定 URL,常用于跳转到告警详情页。

## ntfy:跨平台的 pub/sub 通知

[ntfy](https://github.com/binwiederhier/ntfy)(读音同 "notify")是一个基于 HTTP 的发布订阅(pub/sub)通知服务。与 Bark 不同,ntfy **跨平台**:Android、iOS、Web、桌面 PWA、CLI 全部支持,且同时提供免费公共实例 [ntfy.sh](https://ntfy.sh) 与可自建的私有部署。采用 Apache 2.0 与 GPLv2 双协议开源,作者为 Philipp C. Heckel。

### 工作原理

ntfy 采用 topic(主题)模型:

- 发布方把消息以 PUT/POST 发到 `ntfy.sh/<topic>`;
- 订阅了该 topic 的客户端(Android/iOS App、Web、CLI、WebSocket、MQTT 等)即时收到推送;
- topic 无需显式创建,任意命名即可,文档建议选择不可猜测的长名字以避免被他人订阅。

公共实例底层用 Firebase Cloud Messaging(FCM)和 Web Push 进行实际下发,自建实例同样依赖这些通道。消息缓存默认写入 SQLite。

### 自建部署

官方提供 Docker 镜像与 `docker-compose.yml`:

```bash
docker run -d \
  --name ntfy \
  --restart=unless-stopped \
  -p 80:80 \
  -v /var/lib/ntfy:/var/lib/ntfy \
  -v /etc/ntfy:/etc/ntfy \
  binwiederhier/ntfy serve
```

自建实例可通过配置文件开启访问控制(ACL)、消息持久化、附件大小限制、速率限制等。对于需要严格权限控制的内部环境,通常配合反向代理(Traefik、Nginx)做 TLS 与鉴权。

### API 调用

最小调用只要一行 `curl`:

```bash
# 发送一条普通消息到 mytopic
curl -d "数据库备份完成" ntfy.sh/mytopic

# 带标题、优先级、标签(emoji)和点击动作
curl -H "Title: 生产环境告警" \
     -H "Priority: high" \
     -H "Tags: warning,skull" \
     -H "Click: https://grafana.example.com" \
     -d "订单服务 5xx 错误率超过 5%" \
     ntfy.sh/prod-alerts
```

也可以在脚本里用 Python、Go、JavaScript 等任意 HTTP 客户端发送,或使用官方 `ntfy` CLI。

### 主要特性

- **无需注册**:公共实例开箱即用,自建实例也只关心 topic 名。
- **多客户端**:Android(Google Play 与 F-Droid)、iOS、Web、PWA、CLI,覆盖桌面与移动端。
- **富通知**:支持优先级、tag(emoji 图标)、标题、点击跳转、动作按钮(Action Buttons)。
- **附件**:可在通知中携带文件,小文件直传,大文件可作为链接。
- **多种传输**:HTTP、WebSocket、MQTT、邮件(SMTP),方便集成遗留系统。
- **访问控制**:基于用户/角色的 ACL,可精细化限制谁能发布或订阅。
- **消息持久化与调度**:支持消息缓存与延迟/定时发送(At、Every)。

## 选型对比

| 维度 | Bark | ntfy |
| --- | --- | --- |
| 客户端平台 | 仅 iOS | Android、iOS、Web、桌面、CLI |
| 协议 | 自有 HTTP API(V2) | HTTP pub/sub |
| 后端语言 | Go | Go + React |
| 数据存储 | Bbolt(默认)/ MySQL | SQLite |
| 推送通道 | APNs | FCM + Web Push |
| 加密推送 | 支持(ciphertext) | 支持(自建可启用 TLS + ACL) |
| 公共实例 | 无官方公共服务 | 提供 ntfy.sh 公共实例 |
| 部署复杂度 | 低(单二进制/Docker) | 中(配置项较多) |
| 适用场景 | 个人 iOS 设备的轻量告警 | 团队/多端订阅、复杂通知需求 |

实操建议:

- **只有 iPhone、只需要给自己推告警**:用 Bark,部署最简单,API 也最直观,加密推送可以避免敏感内容经过服务器明文留存。
- **需要同时通知 Android/iOS/桌面,或要做团队订阅、带附件、带动作按钮**:用 ntfy。它的 pub/sub 模型天然适合「一个事件、多端订阅」的场景,公共实例还能让外部协作者直接订阅。

两者并不互斥:很多团队会以 ntfy 作为主通道,同时用 Bark 给值班的 iOS 设备做兜底告警,把延迟敏感的 critical 推送单独走 Bark,绕开 FCM 在国内网络的可达性问题。

## 参考

- [Bark(iOS App)GitHub 仓库](https://github.com/Finb/Bark)
- [bark-server GitHub 仓库](https://github.com/Finb/bark-server)
- [Bark 官方文档](https://bark.day.app/)
- [bark-server API V2 文档](https://github.com/Finb/bark-server/blob/master/docs/API_V2.md)
- [ntfy GitHub 仓库](https://github.com/binwiederhier/ntfy)
- [ntfy 官方文档](https://docs.ntfy.sh/)
- [ntfy 公共实例](https://ntfy.sh/)
