+++
title = "Boinc 网络通信协议"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "BOINC 客户端与服务器四步交互流程及关键 URL"
description = "梳理 BOINC 客户端从 Master URL 到文件上传的四个通信步骤，包含关键 URL 格式、调试选项与源码入口。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "boinc", "分布式计算", "网络协议", "源码分析"]
keywords = ["BOINC", "分布式计算", "网络通信协议", "调度服务器", "file_upload_handler"]
toc = true
draft = false
+++

官网文档对此有简要介绍：

- [网络交互概览（CommIntro）](https://github.com/BOINC/boinc/wiki/CommIntro)

![boinc-net-proto](https://raw.githubusercontent.com/wiki/BOINC/boinc/comm.png)

为了更好地观察 BOINC 客户端与服务器的通信流程，可以在客户端开启 `http_debug`、`http_xfer_debug` 调试选项。当加入新项目时，便可在日志中观察到客户端与服务器之间的通信协议内容。

总结起来，整个流程分为以下四个步骤：

## Step 1. 下载 Master URL

客户端首先下载 Master URL 页面，从中获取调度服务器的域名列表。Master URL 的地址通常为：

- `https://{URL_BASE}/{PROJECT}/`

同时，客户端会将该请求的应答内容存入本地文件 `master_{project_url}.xml`，方便调试。

该页面 head 信息中包含了调度器列表，客户端解析后即可得到调度器地址。具体实现位于客户端的以下函数：

```cpp
int SCHEDULER_OP::parse_master_file(PROJECT* p, vector<string> &urls) {
}
```

**加入项目 / 登录**

在客户端下载 Master URL 之前，其实还有一个登录流程。当加入 BOINC 项目时，会触发客户端依次发起以下请求：

- `https://{URL_BASE}/{PROJECT}/get_project_config.php`
- `https://{URL_BASE}/{PROJECT}/lookup_account.php?email_addr=xxx%40xxx%2Ecom&passwd_hash=f803245bdd0ea825d16d736e72448309`

`get_project_config.php` 的请求应答会存入本地文件 `get_project_config.xml`。

`lookup_account.php` 的请求应答会存入本地文件 `lookup_account.xml`；如果账号验证成功，客户端还会创建文件 `account_{project_url}.xml`，其中保存了该账号的 key 信息。

## Step 2. 发送调度请求

客户端向调度服务器发送请求，调度服务器返回应答消息。应答消息中包含工作单元的输入、输出文件描述，以及对应的输入输出 URL 列表。

调度请求的 URL 通常如下：

- `https://{URL_BASE}/{PROJECT}_cgi/cgi`

当收到调度服务器的应答消息后，客户端会对其进行解析，并调用以下函数处理（定义在 `cs_scheduler.cpp`）：

```cpp
int CLIENT_STATE::handle_scheduler_reply()
```

## Step 3. 下载文件

客户端使用标准的 HTTP GET 请求，从一个或多个下载数据服务器下载文件。

文件下载逻辑是一般 Web 服务器都支持的能力。BOINC 这里直接复用了 Apache 的文件下载机制，只需在 Apache 配置文件中配置好下载目录即可，不需要额外的 PHP 或 CGI 代码。

## Step 4. 上传结果文件

当计算完成后，客户端上传结果文件。上传使用的是 BOINC 特定的协议，它可以保护数据服务器免受 DOS 攻击。

同时，客户端会再次与调度服务器通信，上报已完成的工作单元，并请求更多工作单元。

上传逻辑相对于文件下载要复杂一些，因为需要对文件进行校验，所以 BOINC 采用 CGI 实现文件上传逻辑。URL 路径通常为：

- `https://{URL_BASE}/{PROJECT}_cgi/file_upload_handler`

上传结果文件对 BOINC 任务来说是可选的，具体取决于任务的输出模板文件配置。

## 参考

- [BOINC Wiki - Network communication overview (CommIntro)](https://github.com/BOINC/boinc/wiki/CommIntro)
- [BOINC Wiki - RPC Protocol (RpcProtocol)](https://github.com/BOINC/boinc/wiki/RpcProtocol)
- [BOINC Wiki - ClientConfiguration (日志调试选项)](https://github.com/BOINC/boinc/wiki/ClientConfiguration)
