+++
title = "Python Web 框架"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Django、FastAPI 与 Sanic 的特性、定位与选型"
description = "梳理 Django、FastAPI、Sanic 三款主流 Python Web 框架的核心特性、异步模型与适用场景,便于在项目中做技术选型。"
author = "小智晖"
authors = ["小智晖"]
categories = ["python"]
tags = ["编程语言", "python", "web", "django", "fastapi", "sanic"]
keywords = ["python", "web 框架", "django", "fastapi", "sanic", "asgi"]
toc = true
draft = false
+++

Python 生态里有不少成熟的 Web 框架，各自针对不同的场景做了取舍。本文按"大而全 / 微框架 / 高性能异步"三类，记录我在调研与使用过程中沉淀的几款主流框架要点，以及若干实操链接。

## 总览:WSGI 与 ASGI

在具体谈框架之前，先理清两个底层接口规范:

- **WSGI(Web Server Gateway Interface)** 是 Python 同步 Web 应用的标准接口，定义了服务器与应用之间的调用约定。它结构简单、生态成熟，但天然不支持 WebSocket、长连接等异步场景。
- **ASGI(Asynchronous Server Gateway Interface)** 是 WSGI 的"精神继承者",由 Django 团队在 [`asgiref`](https://github.com/django/asgiref) 项目下孵化。它既能跑同步应用，也能跑异步应用，并提供了 WSGI 兼容层，是当前异步 Python Web 的基础设施。

是否原生基于 ASGI、是否充分使用 `async/await`,往往是区分新一代 Python Web 框架与传统框架的关键。

## Django:大而全的"全家桶"

[Django](https://www.djangoproject.com/) 是一个高阶 Python Web 框架，口号是"鼓励快速开发、干净务实的设计",免费且开源。它的核心思路是把 Web 开发中常见的轮子都内置好，让开发者专注于业务本身。

### Python 版本支持

根据官方安装文档，Django 5.x 的 Python 兼容矩阵如下:

| Django 版本 | 支持的 Python |
|---|---|
| 5.0 | 3.10、3.11、3.12 |
| 5.1 | 3.10、3.11、3.12、3.13(3.13 自 5.1.3 起加入) |
| 5.2 | 3.10、3.11、3.12、3.13、3.14(3.14 自 5.2.8 起加入) |

此外，官方明确 **Django 4.2 是 LTS 版本**,其安全支持在 2026 年 4 月结束，同时也是最后一个支持 Python 3.9 的版本。需要长期稳定支持的项目可优先考虑 LTS。

### MTV 架构与内置能力

Django 采用 **MTV(Model-Template-View)** 模式，本质上是 MVC 的一种变体——框架自身充当 Controller。三层大致分工:

- **Model(数据层)**:用 Python 类描述数据库 schema，通过 ORM 操作数据，无需手写 SQL。
- **Template(表现层)**:基于继承、变量、过滤器与标签的模板系统。
- **View(逻辑层)**:接收请求、调用 Model、渲染 Template 并返回响应。

Django 的"全家桶"特性包括:

- **ORM**:支持跨关系查询的 JOIN，例如 `Article.objects.filter(reporter__full_name__startswith="John")`,无需代码生成。
- **Admin 后台**:被官方形容为"不是脚手架，而是整栋房子",注册模型即可得到生产可用的 CRUD 界面。
- **迁移系统**:通过 `python manage.py makemigrations` 与 `python manage.py migrate` 管理 schema 演进。
- **认证、缓存、RSS/Atom、模板继承、静态文件**等开箱即用。

值得一提的是，这些组件是松耦合的：可以不用 Django 自带模板引擎，也可以不用它的数据库 API，自由替换。

### 何时选 Django

适合内容管理、电商后台、企业内部系统这类"功能面广、表结构复杂、需要后台管理"的项目。代价是相对"重",对追求极致性能或纯粹 API 服务的场景并非最优。

## FastAPI:面向 API 的现代异步框架

[FastAPI](https://fastapi.tiangolo.com/) 是一个面向 API 的现代、高性能 Web 框架，完全基于 Python 标准类型注解（type hints）。它在两个核心库之上构建:

- **[Starlette](https://www.starlette.io/)**:负责 Web 部分（路由、中间件、WebSocket、基于 HTTPX 的测试客户端等）。FastAPI 实际上是 Starlette 的子类，继承了 Starlette 的全部能力。
- **[Pydantic](https://docs.pydantic.dev/)**:负责数据部分，所有的数据校验、序列化都由 Pydantic 完成。

### 核心特性

FastAPI 围绕开放标准设计，主要特性包括:

- **自动文档**:默认在 `/docs` 提供 Swagger UI，在 `/redoc` 提供 ReDoc，可在浏览器中直接调用、测试 API。
- **标准协议**:遵循 [OpenAPI](https://github.com/OAI/OpenAPI-Specification) 与 [JSON Schema](https://json-schema.org/),文档不是"事后补丁",而是从类型注解原生生成。
- **依赖注入**:强大的 DI 系统，依赖可以再依赖，框架自动解析整个依赖图。
- **校验与编辑器支持**:对 `str`/`int`/`float`/`dict`/`list` 等基础类型以及 URL、Email、UUID 等都自动校验，并在 VS Code、PyCharm 等编辑器中获得完整补全。
- **安全**:集成 HTTP Basic、OAuth2(含 JWT)、API Key 等 OpenAPI 安全方案。
- **测试**:官方宣称 100% 测试覆盖、100% 类型注解。

### 路由

- [路径参数：定义一般路由](https://fastapi.tiangolo.com/zh/tutorial/path-params/) —— 强调一点：静态路径要声明在动态路径之前，例如 `/users/me` 必须先于 `/users/{user_id}`,否则会被后者捕获。
- [APIRouter:对路由分组](https://fastapi.tiangolo.com/zh/reference/apirouter/) —— 用 `APIRouter` 把模块拆成多组路由再挂载，适合中大型项目。

### OpenAPI 文档相关

- [请求体 - 字段](https://fastapi.tiangolo.com/zh/tutorial/body-fields/)
- [元数据和文档 URL](https://fastapi.tiangolo.com/zh/tutorial/metadata/)
- [Pydantic BaseModel 字段约束的 Field 定义](https://docs.pydantic.dev/latest/api/fields/)

### 中间件

- [如何使用中间件修改请求及应答包体](https://dev.to/avirgvd/python-fastapi-middleware-to-modify-request-and-response-body-3f7f)

### 日志

参考:[为 FastAPI 配置日志的三种方法](https://cloud.tencent.com/developer/article/2009553)。

文章总结了三种思路，我在实践中也踩过对应的坑:

1. **像写脚本那样记录日志**。在应用初始化时建立一个全局 `logger`,其它模块通过 `logging.getLogger(__name__)` 获取即可。理想状态下，我希望像 Go 的 Macaron 框架那样，在中间件中创建 `logger` 对象并通过请求上下文传递到下游路由——但 FastAPI 并不原生支持这种"中间件注入请求级对象"的模式。
2. **记录 uvicorn 的日志**。把 uvicorn 自身的 access log 接入业务日志体系。
3. **配置 uvicorn 的日志**。通过 `--log-config` 传入 dictConfig / fileConfig，统一格式与输出目标。

对于结构化生产日志，推荐结合 `structlog` 或 Python 3.2+ 内置的 `logging.config.dictConfig`,并在 ASGI 中间件层统一打入口/出口日志。

### 单元测试

依赖:

```bash
pip install httpx pytest
```

FastAPI 提供 `fastapi.testclient.TestClient`,内部基于 HTTPX，可以用同步写法测试异步应用:

```python
from fastapi import FastAPI
from fastapi.testclient import TestClient

app = FastAPI()

@app.get("/")
async def read_main():
    return {"msg": "Hello World"}

client = TestClient(app)

def test_read_main():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"msg": "Hello World"}
```

注意 `TestClient` 接收的是 JSON 可序列化数据，而不是 Pydantic 模型本身;若要发送模型数据，可借助 `fastapi.encoders.jsonable_encoder` 转换。官方文档见 [Testing](https://fastapi.tiangolo.com/tutorial/testing/)。

### 何时选 FastAPI

适合纯 API 服务、机器学习推理接口、微服务后端，以及强依赖类型/文档协作的团队。它的代价是默认不带 ORM、后台、模板，需要自行组合 SQLAlchemy / Tortoise 等组件。

## Sanic:为速度而生的 ASGI 框架

[Sanic](https://github.com/sanic-org/sanic) 自我定位是"Python 3.8+ 的 Web 服务器与 Web 框架，为速度而生"。它从设计之初就支持 `async/await`(Python 3.5 引入的语法),并符合 ASGI 规范，可部署到其它 ASGI 服务器。

### 特性要点

- **异步非阻塞**:全链路基于 `async/await`,适合高并发、I/O 密集型场景。
- **ASGI 兼容**:既可用内置服务器，也可对接其它 ASGI 服务器。
- **性能优先**:可选启用 `uvloop`(asyncio 事件循环的高速替代)和 `ujson`(更快的 JSON 实现)以进一步提升吞吐。
- **社区维护**:由社区维护、为社区服务。

需要 Python 3.7 兼容时，官方建议使用 `v22.12LTS`。Sanic 在路由 API、参数解析、中间件等机制上与 Flask 类似，熟悉 Flask 的开发者上手较快，但写法上是异步的。

### 何时选 Sanic

适合对单机吞吐和延迟敏感、又希望保留 Flask 风格 API 的场景。和 FastAPI 相比，Sanic 不强依赖 Pydantic，也不自动生成 OpenAPI 文档，更适合"自己造轮子"偏好较强的团队。

## 选型小结

| 维度 | Django | FastAPI | Sanic |
|---|---|---|---|
| 定位 | 全栈全家桶 | API 优先 | 高性能异步 |
| 异步支持 | 3.1 起部分支持 | 原生 ASGI | 原生 ASGI |
| ORM/后台 | 内置 | 需自配 | 需自配 |
| 自动 API 文档 | 需第三方（DRF 等） | 内置 Swagger/ReDoc | 无 |
| 适用场景 | 内容/管理系统、复杂业务 | 微服务、ML 推理、API 服务 | 高并发、低延迟服务 |

实际项目中，这三者并非互斥：一个系统里完全可以用 Django 承担后台与运营管理，用 FastAPI 暴露对外的开放 API，用 Sanic 处理某些对延迟极敏感的网关逻辑。框架只是工具，理解它们各自的取舍，才能在不同模块做出恰当选择。

## 参考

- [Django 官方文档](https://docs.djangoproject.com/)
- [FastAPI 官方文档（中文）](https://fastapi.tiangolo.com/zh/)
- [Starlette 官方文档](https://www.starlette.io/)
- [Pydantic 官方文档](https://docs.pydantic.dev/)
- [Sanic GitHub 仓库](https://github.com/sanic-org/sanic)
- [ASGI 规范](https://asgi.readthedocs.io/)
