+++
title = "HTTP 相关的 C 库：libmicrohttpd 与 libcurl"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从服务端到客户端，C 语言里两组常用的 HTTP 基础库"
description = "梳理 C 语言中两类常用的 HTTP 库：嵌入式的服务端 libmicrohttpd 与通用的客户端 libcurl，覆盖特性、线程模型、接口与示例。"
author = "小智晖"
authors = ["小智晖"]
categories = ["http"]
tags = ["http", "libmicrohttpd", "libcurl", "C语言", "网络编程"]
keywords = ["libmicrohttpd", "libcurl", "HTTP 库", "C 语言 HTTP", "嵌入式 HTTP 服务器"]
toc = true
draft = false
+++

在 C/C++ 项目里，如果只想做最简单的 HTTP 收发，往往不必引入一整套 Web 框架。根据角色不同，常用的有两类基础库：

- **服务端库（HTTP server）**：把 HTTP 协议层封装好，让应用嵌入一个监听端口、处理请求的逻辑，典型代表是 GNU 的 **libmicrohttpd**。
- **客户端库（HTTP client）**：负责发起请求、处理重定向、TLS、Cookie 等，事实标准是 **libcurl**。

下面分别记录这两组库的要点，作为日后选型与查阅的索引。

## C 语言

### libmicrohttpd：嵌入式的 HTTP 1.1 服务端

libmicrohttpd 是 **GNU Project** 下的一个小型、开源的 HTTP 服务端库，目的是让应用程序可以方便地把一个 HTTP（乃至 HTTPS）服务嵌入到自身进程里。它只实现 HTTP 协议层，业务逻辑（生成响应内容、路由）由调用方提供，因此体積很小，适合在嵌入式设备、桌面应用、守护进程里跑一个调试页面或 metrics 端点。

#### 主要特性

- **协议**：主要实现 **HTTP/1.1**，同时兼容 HTTP/1.0。
- **TLS/SSL**：可选启用 HTTPS（编译期关闭），后端支持 GnuTLS 等主流实现。
- **认证**：内置 HTTP Basic 与 Digest 认证 API。
- **POST 处理**：提供 PostProcessor API，方便解析表单与文件上传。
- **IPv4 / IPv6** 双栈支持。
- **平台覆盖**：GNU/Linux、FreeBSD、OpenBSD、NetBSD、Darwin (macOS)、Windows (W32)、OpenIndiana/Solaris、z/OS（z/OS 上暂不支持 HTTPS），也有人在 vxWorks 等实时系统上使用。
- **许可证**：**LGPL v2.1+** 与 eCos License 双授权，可在闭源项目中以动态链接等方式合规使用。

#### 线程与事件模型

libmicrohttpd 通过启动时传入的 `MHD_USE_*` 标志位决定如何处理连接，常见组合如下：

| 标志 | 含义 |
| --- | --- |
| `MHD_USE_INTERNAL_POLLING_THREAD` | MHD 起一个内部线程跑事件循环（默认基于 `select`），调用方无需手动驱动 |
| `MHD_USE_THREAD_PER_CONNECTION` | 每条连接一个线程，模型简单但并发高时开销大；与 `MHD_USE_EPOLL` 不兼容 |
| `MHD_USE_POLL` | 用 `poll()` 替代 `select()`，突破 `FD_SETSIZE` 的描述符上限 |
| `MHD_USE_EPOLL` | Linux 上用 `epoll`，复杂度从 `select/poll` 的 O(n) 降到 O(1)，高并发下性能更好 |
| `MHD_USE_AUTO` | 自动选择当前平台最优的事件循环方式，推荐跨平台项目使用 |

线程池模式需要先开启 `MHD_USE_INTERNAL_POLLING_THREAD`，再用 `MHD_OPTION_THREAD_POOL_SIZE` 指定工作线程数；否则 `MHD_start_daemon` 会返回 `NULL`。对于大多数"跑一个内部接口"的场景，用 `MHD_USE_AUTO_INTERNAL_THREAD` 就够了。

#### 最小示例

下面是一个返回固定字符串的 HTTP 服务，监听 8080 端口：

```c
#include <string.h>
#include <microhttpd.h>

static enum MHD_Result answer(void *cls, struct MHD_Connection *conn,
                              const char *url, const char *method,
                              const char *version, const char *data,
                              size_t *size, void **ptr) {
    const char *page = "Hello from libmicrohttpd";
    struct MHD_Response *resp = MHD_create_response_from_buffer(
        strlen(page), (void *)page, MHD_RESPMEM_PERSISTENT);
    enum MHD_Result ret = MHD_queue_response(conn, MHD_HTTP_OK, resp);
    MHD_destroy_response(resp);
    return ret;
}

int main(void) {
    struct MHD_Daemon *d = MHD_start_daemon(
        MHD_USE_AUTO_INTERNAL_THREAD, 8080,
        NULL, NULL, &answer, NULL, MHD_OPTION_END);
    if (d == NULL) return 1;
    getchar();  /* 阻塞主线程，保持服务运行 */
    MHD_stop_daemon(d);
    return 0;
}
```

编译：`gcc -o demo demo.c -lmicrohttpd`。

#### 使用 libmicrohttpd 的项目

- **prometheus C 语言客户端**（[digitalocean/prometheus-client-c](https://github.com/digitalocean/prometheus-client-c)）：其 `libpromhttp` 子库依赖 libmicrohttpd，用于暴露 `/metrics` 端点供 Prometheus 拉取。注意该仓库目前处于 archived 状态（2026 年起只读）。

#### 参考

- [libmicrohttpd 官方站点（GNU）](https://www.gnu.org/software/libmicrohttpd/)
- [libmicrohttpd 参考手册](https://www.gnu.org/software/libmicrohttpd/manual/html_node/)
- [Karlson2k/libmicrohttpd（GitHub 镜像）](https://github.com/Karlson2k/libmicrohttpd)
- [libmicrohttpd：一个 C 编写的小型 HTTP 库（笔记）](https://github.com/ravenq/ravenq.github.io/blob/master/blog.md/microhttpd.md)

### libcurl：通用的客户端传输库

如果说 libmicrohttpd 解决的是"对外提供服务"，那么 **libcurl** 解决的就是"主动发起请求"。它是命令行工具 `curl` 背后的引擎，也是目前 C/C++ 生态里事实标准的客户端 URL 传输库，几乎所有主流语言（Python、PHP、Java、Rust、Go 等）都有对它的绑定。

#### 主要特性

- **协议广泛**：除 HTTP/HTTPS 外，还支持 FTP、FTPS、SFTP、SCP、SMTP、IMAP、POP3、LDAP、MQTT、RTSP、WebSocket（WS/WSS）、DICT、TELNET、TFTP、SMB 等 20 余种协议。
- **HTTP 版本**：HTTP/1.0、HTTP/1.1、HTTP/2（含多路复用）、HTTP/3（基于 QUIC）。
- **TLS 后端**：OpenSSL、GnuTLS、mbedTLS、Schannel（Windows）、Secure Transport（Apple 平台）等可切换。
- **认证**：Basic、Digest、NTLM、Negotiate (SPNEGO)、Kerberos、Bearer Token（OAuth2/JWT）、AWS Signature V4。
- **高级能力**：Cookie 存储、自动重定向（301/302/303/307/308）、连接复用（Keep-Alive）、代理（HTTP/HTTPS/SOCKS4/5）、SSL Pinning、断点续传。
- **可移植性**：在 Linux、Windows、macOS、各种 BSD、Solaris、甚至 Amiga、QNX、OpenVMS 上都能构建，API/ABI 稳定。
- **许可证**：类似 MIT 的宽松许可，可商用闭源。

#### 两套主要接口

libcurl 的 C API 分为两层，按并发需求选择：

- **easy interface**：同步、阻塞、一次处理一个传输。典型流程是 `curl_easy_init` → `curl_easy_setopt` 设置选项 → `curl_easy_perform` 执行 → `curl_easy_cleanup`。简单直观，适合一次性请求。
- **multi interface**：easy 接口的"异步兄弟"，可在单线程内同时驱动多个 easy handle，支持事件循环集成（配合 `epoll`/`kqueue`/`select`），适合爬虫、API 聚合等高并发场景。

#### 最小示例（easy 接口）

```c
#include <stdio.h>
#include <curl/curl.h>

int main(void) {
    CURL *curl = curl_easy_init();
    if (!curl) return 1;

    curl_easy_setopt(curl, CURLOPT_URL, "https://example.com");
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);

    CURLcode res = curl_easy_perform(curl);
    if (res != CURLE_OK) {
        fprintf(stderr, "curl failed: %s\n", curl_easy_strerror(res));
    }

    curl_easy_cleanup(curl);
    return 0;
}
```

编译：`gcc -o fetch fetch.c -lcurl`。

#### 参考

- [libcurl 官方站点](https://curl.se/libcurl/)
- [libcurl C API 文档](https://curl.se/libcurl/c/)
- [curl 命令行工具与库（GitHub）](https://github.com/curl/curl)

## 小结

| 维度 | libmicrohttpd | libcurl |
| --- | --- | --- |
| 角色 | HTTP 服务端 | HTTP / 通用协议客户端 |
| 典型场景 | 嵌入 Web UI、metrics 端点、REST 接口 | 调外部 API、爬取、上传下载 |
| 并发模型 | select / poll / epoll / 线程池 | easy（同步）/ multi（异步事件） |
| 协议重点 | HTTP/1.1（兼容 1.0） | HTTP/1.0、1.1、2、3，另含 FTP/SMTP 等 |
| 许可证 | LGPL v2.1+ / eCos | curl 许可（MIT 类） |

两者经常在同一项目里"结对"出现：进程内部用 libmicrohttpd 暴露管理接口，对外则用 libcurl 调依赖服务。理解它们各自的事件模型与接口边界，能省去不少重复造轮子的功夫。
