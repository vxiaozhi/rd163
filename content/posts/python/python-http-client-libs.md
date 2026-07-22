+++
title = "Python HTTP 客户端库"
date = "2025-01-15"
lastmod = "2025-01-15"
subtitle = "从 urllib 到 requests 再到 httpx"
description = "梳理 Python 主流 HTTP 客户端库(urllib、requests、httpx)的特性差异与异常处理套路,并给出一份通用的请求异常封装示例。"
author = "小智晖"
authors = ["小智晖"]
categories = ["python"]
tags = ["编程语言", "python", "http", "requests", "httpx", "urllib"]
keywords = ["python", "http 客户端", "requests", "httpx", "urllib", "异常处理"]
toc = true
draft = false
+++

## urllib、urllib2

Python 2 时代常用的标准库 HTTP 客户端是 `urllib` 和 `urllib2`,它们提供了 URL 编码、请求构造、认证、重定向等基础能力，让我们能在不依赖第三方库的情况下完成大多数 HTTP 调用。两者的分工略有差异:`urllib` 偏向基础 URL 处理,`urllib2` 则在请求定制（如自定义 header、handler、opener）上更强大。

到了 Python 3，这两个模块被合并重组成单一的 `urllib` 包(拆为 `urllib.request`、`urllib.parse`、`urllib.error` 等子模块),API 也更一致。如果只是写个小脚本、不想引入外部依赖，标准库的 `urllib.request.urlopen()` 仍然够用;但一旦涉及到会话、Cookie、连接池、超时精细控制等需求，几乎都会转向下面的 `requests`。

## requests

[requests](https://requests.readthedocs.io/) 是 Python 生态里使用率最高的 HTTP 库，API 设计优雅，被广泛誉为「为人类设计的 HTTP 库」。它封装了会话、Cookie 持久化、连接池、SSL 校验、自动解码、流式下载等常用能力，基本是写脚本和业务客户端时的默认选择。

### 异常情况处理

在发送 HTTP 请求获取数据的过程中，可能会遭遇以下几类异常:

1. 网络异常：网络不通、DNS 解析失败、连接超时等;
2. 请求异常：请求被拒绝、请求超时等;
3. 响应异常：状态码表示失败（4xx/5xx）、响应体无法解析等;
4. 值异常：响应内容能解析，但业务上数据不对(例如业务返回结构里的 `code` 字段非 0)。

前三类异常的处理代码通常是通用的，第四类对于「响应体里又包了一层 `code` 的 JSON」也往往可以抽象出统一的校验逻辑。

### 示例代码

下面是一份针对以上异常的通用样例代码，通常会被进一步封装成一个工具函数:

```python
import requests

# 注意异常捕获顺序:子类异常必须在父类异常之前,
# 否则父类(RequestException)会先匹配,后面的分支永远走不到。
try:
    response = requests.get('http://example.com/api/data', timeout=5)
    response.raise_for_status()  # 状态码 >= 400 时抛出 HTTPError
    data = response.json()
except requests.exceptions.ConnectionError as e:
    print('网络连接异常: ', e)
except requests.exceptions.Timeout as e:
    print('连接超时: ', e)
except requests.exceptions.HTTPError as e:
    # HTTPError 是 RequestException 的子类,必须放在 RequestException 之前
    print(f'HTTP 错误, 状态码: {e.response.status_code}, {e}')
except requests.exceptions.RequestException as e:
    # RequestException 是所有 requests 异常的基类,作为兜底
    print('请求异常: ', e)
except ValueError as e:
    # response.json() 解析失败时抛出
    print('响应解析异常: ', e)
```

需要特别注意的是:`response.raise_for_status()` 不可省略，否则当服务器返回 4xx/5xx 错误状态码时，requests 默认不会抛出异常，我们也就无法在 `except` 分支里捕获到失败请求。

另外提醒一个容易踩的坑:`raise_for_status()` 只在 **状态码 >= 400** 时抛出 `HTTPError`,并不会对 3xx 重定向或非 200 的成功码（如 201、204）报错;`response.status_code == 200` 也不应作为业务成功的唯一判据，具体还得结合业务返回结构来判断。

## httpx

随着 Python 在 `asyncio`(Python 3.4 引入、3.6 起趋于稳定)上的持续推进，异步 IO 逐渐成为高并发业务的首选模型。新一代 HTTP 库 [httpx](https://www.python-httpx.org/) 正是在这个背景下出现：它几乎完全兼容 `requests` 的同步 API，同时又提供了一等公民级别的异步客户端 `AsyncClient`,并且支持 HTTP/2。

按官方主页列出的核心特性:

- 广泛兼容 `requests` 的 API，迁移成本极低;
- 标准同步接口，需要时也能切到 async;
- 同时支持 HTTP/1.1 与 HTTP/2(后者通过 `httpx[http2]` 额外安装 `h2` 启用);
- 能够直接向 WSGI/ASGI 应用发起请求，方便本地测试;
- 严格的超时默认值（到处都有超时）;
- 完整的类型注解;
- 100% 测试覆盖率。

需要补充说明的是:httpx 启用 HTTP/2 后确实走的是 HTTP/2 协议，但 HTTP/2 协议层面的「多路复用」「服务端推送（Server Push）」更多是协议特性，httpx 作为客户端并未对外暴露服务端推送这类高级 API(实际上浏览器侧也正在废弃 Server Push),所以选型时不必把它当作 httpx 的卖点。此外，httpx 要求 **Python 3.8+**,在老项目里替换 `requests` 时要留意最低解释器版本。

## 参考

- [requests 官方文档](https://requests.readthedocs.io/)
- [httpx 官方文档](https://www.python-httpx.org/)
- [httpx HTTP/2 指南](https://www.python-httpx.org/http2/)
- [Python urllib.request 标准库文档](https://docs.python.org/3/library/urllib.request.html)
