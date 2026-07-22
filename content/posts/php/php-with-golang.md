+++
title = "PHP 与 Golang 协同：用 RoadRunner 给 PHP 应用换一颗 Go 的心脏"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "RoadRunner 的架构、Goridge 通信协议与 PHP 常驻 Worker 模型解析"
description = "RoadRunner 是一个用 Go 编写的高性能 PHP 应用服务器,通过常驻 Worker 模型替代 PHP-FPM 的请求级引导开销,本文梳理其架构、通信协议与落地实践。"
author = "小智晖"
authors = ["小智晖"]
categories = ["php"]
tags = ["编程语言", "php", "golang", "RoadRunner", "性能优化", "应用服务器"]
keywords = ["PHP", "Golang", "RoadRunner", "Goridge", "PHP-FPM", "高性能"]
toc = true
draft = false
+++

PHP 与 Go 的结合并不少见，但在工程实践中，最常见的合作形态并不是「把 PHP 代码改写成 Go」,而是让 Go 接管网络层与进程管理，让 PHP 专注于业务逻辑。**RoadRunner** 正是这种思路的代表性项目：它用 Go 写了一个高性能的应用服务器（application server）,把 PHP 进程作为长驻 worker(常驻工作进程)调度起来，从而绕开了传统 PHP-FPM 在每个请求上重复引导框架的开销。

本文基于 RoadRunner 官方文档与 GitHub 仓库整理其核心概念、通信协议与使用方式。

## 为什么需要 Go 来托管 PHP

PHP 在 Web 领域的成功，很大程度上得益于「共享无关（shared-nothing）」的执行模型：每个请求启动一个干净的进程，跑完即销毁。这种模型简单稳定，但代价是**每一次请求都要重新加载 autoloader、初始化框架容器、重建路由表**。对于一个加载了数十个 Composer 包的现代框架（如 Laravel、Symfony）而言，这部分引导开销常常是毫秒级的，在 QPS 较高时成为瓶颈。

PHP 生态内部对此给出了几种答案:Swoole、ReactPHP、FrankenPHP、RoadRunner 等。其中 RoadRunner 的特别之处在于，它**把进程调度与网络 I/O 完全交给 Go 完成**,PHP 只负责执行业务代码。这种分工的好处是:

- Go 的 goroutine 模型在网络 I/O 多路复用上非常高效;
- Go 可以同时承担 HTTP/2、gRPC、队列、KV、指标等基础设施职责;
- PHP 进程被 Go 作为 worker pool 管理，生命周期、内存上限、超时都能精细控制。

## RoadRunner 的整体架构

RoadRunner 采用**主从（master/worker）架构**:

1. **Go 主进程** 作为应用服务器，对外暴露 HTTP(S)/2/3、FastCGI、gRPC、WebSocket、TCP 等入口;
2. **PHP worker 池** 是一组长驻的 PHP 进程，每个进程在内存里保留已经引导好的应用状态;
3. **Goridge** 作为 Go 与 PHP 之间的二进制 IPC(进程间通信)协议，负责把请求帧从 Go 端投递到 PHP 端，再把响应回传。

请求进来时，Go 主进程不是去 fork 一个新的 PHP 进程，而是把请求通过 Goridge 协议交给池子里一个空闲的 PHP worker;worker 处理完后回到等待状态，继续服务下一个请求。框架引导只在 worker 启动时发生一次，后续成千上万个请求都直接复用。

这种「常驻 worker + 进程隔离」的设计还有两个工程上的好处:**单个 worker 崩溃不会影响其他 worker**(supervisor 会自动重启),并且**水平扩展非常直接**——只要把 `num_workers` 调大即可。

## Goridge:Go 与 PHP 之间的二进制桥梁

RoadRunner 的性能优势离不开底层的通信协议 **Goridge**(GitHub: `roadrunner-server/goridge`)。Goridge 是一个高性能的 PHP↔Go 编解码库，基于原生 PHP socket 与 Go 的 `net/rpc` 包工作。

它有几个值得关注的设计点:

- **极低的消息头开销**:协议头仅 12 字节，适用于任意二进制 payload;
- **CRC32 校验**:对头部进行 CRC32 校验，保证数据完整性;
- **多传输方式**:支持 TCP socket、Unix socket、标准管道（pipe）三种传输;
- **高性能**:官方在 Ryzen 1700X、20 线程的测试环境下达到约 30 万次调用/秒。

语言侧的包分别是:Go 端 `github.com/roadrunner-server/goridge/v4`,PHP 端是独立的 `goridge-php` 仓库。需要 socket 传输时，PHP 侧需要安装 `ext-sockets` 扩展。

正是因为 Goridge 足够轻量，RoadRunner 才能让 Go 与 PHP 之间的每次通信成本远低于重新 fork 进程。

## 最小可用示例：一个 PSR-7 Worker

要跑通一个最小 HTTP worker，只需要两个 Composer 包:

```bash
composer require spiral/roadrunner-http nyholm/psr7
```

入口文件 `psr-worker.php` 的核心结构如下（摘自官方文档）:

```php
<?php

require __DIR__ . '/vendor/autoload.php';

use Nyholm\Psr7\Response;
use Nyholm\Psr7\Factory\Psr17Factory;
use Spiral\RoadRunner\Worker;
use Spiral\RoadRunner\Http\PSR7Worker;

$worker = Worker::create();
$factory = new Psr17Factory();
$psr7 = new PSR7Worker($worker, $factory, $factory, $factory);

while (true) {
    try {
        $request = $psr7->waitRequest();
        if ($request === null) {
            break; // 收到 null 表示需要优雅退出
        }
    } catch (\Throwable $e) {
        $psr7->respond(new Response(400));
        continue;
    }

    try {
        $psr7->respond(new Response(200, [], 'Hello RoadRunner!'));
    } catch (\Throwable $e) {
        $psr7->respond(new Response(500, [], 'Something Went Wrong!'));
    }
}
```

这个循环是 RoadRunner 的灵魂:`waitRequest()` 会阻塞，直到 Go 主进程通过 Goridge 投递一个新的请求帧;`respond()` 把 PSR-7 响应回传给 Go，再由 Go 写回给客户端。注意异常处理的两层：解析失败给 400，业务异常给 500,**无论哪种情况 worker 都不会退出**,而是继续 `continue` 服务下一个请求。

配套的最小配置 `.rr.yaml`:

```yaml
server:
  command: "php psr-worker.php"

http:
  address: 0.0.0.0:8080
```

启动后，RoadRunner 会按配置拉起若干 PHP worker，自己监听 8080 端口。

## 单入口多模式调度

实际项目中，同一个 PHP 进程入口往往需要同时支持 HTTP、Jobs(队列消费)、gRPC 等多种模式。RoadRunner 通过环境变量 `RR_MODE` 标识当前 worker 的类型，业务侧可以基于这个变量做分发:

```php
enum RoadRunnerMode: string
{
    case Http = 'http';
    case Jobs = 'jobs';
    case Temporal = 'temporal';
    case Grpc = 'grpc';
    case Tcp = 'tcp';
    case Centrifuge = 'centrifuge';
    case Unknown = 'unknown';
}
```

入口文件读取 `Spiral\RoadRunner\Environment::fromGlobals()`,根据 `getMode()` 选择对应的 dispatcher 执行。这种模式让一个代码仓库可以同时部署成 API 服务、队列消费者和 gRPC 服务，配置复用度高。

## 进程监督与可观测性

RoadRunner 的 Go 内核还内置了一套类 systemd 的进程监督器（supervisor）。典型配置如下:

```yaml
http:
  address: "0.0.0.0:8080"
  pool:
    num_workers: 6
    supervisor:
      watch_tick: 5s
      ttl: 0s
      idle_ttl: 10s
      exec_ttl: 10s
      max_worker_memory: 100  # 单位 MB,达到上限后重启 worker
```

其中 `max_worker_memory` 是个特别重要的参数:PHP worker 是常驻的，如果不设置内存上限，长期运行可能因为内存泄漏导致 OOM。RoadRunner 会在 worker 占用达到阈值时主动把它重启，从而获得「常驻」与「不泄漏」之间的平衡。

除此之外，RoadRunner 还内置了 Prometheus 指标、OpenTelemetry、静态文件服务、gzip、x-sendfile 等中间件，以及 KV(Redis、Memcached、BoltDB)、Jobs(RabbitMQ、Kafka、SQS、NATS 等)插件，这些都以 Go 插件形式存在，PHP 侧通过 Goridge RPC 调用。

## 与 PHP-FPM 的对比

| 维度 | PHP-FPM | RoadRunner |
|------|---------|------------|
| 进程模型 | 按请求复用/创建进程 | 长驻 worker 池，循环处理请求 |
| 引导开销 | 每个请求都要重新引导框架 | 只在 worker 启动时引导一次 |
| 并发模型 | 进程级，OS 调度 | Go goroutine 复用 worker 池 |
| 通信协议 | FastCGI | Goridge(二进制，12 字节头) |
| 功能边界 | 仅负责执行 PHP | HTTP/队列/KV/gRPC/指标/WebSocket 等一体化 |
| 内存控制 | 进程结束即释放 | 需配合 `max_worker_memory` 防泄漏 |

需要强调的是，RoadRunner **不是 PHP-FPM 的无条件替代品**。对于内存泄漏敏感、强依赖「每请求干净状态」的旧代码，常驻 worker 反而可能放大问题。它最适合的场景是 I/O 密集、引导开销大的现代框架应用。

## 注意事项与落地建议

把传统 PHP 应用搬到 RoadRunner 上，有几个工程上的注意点:

1. **小心单例与静态状态**:worker 常驻意味着跨请求的静态属性、单例容器会保留下来。任何依赖「请求结束自动清理」的代码都需要重新审视，典型的坑包括 Eloquent 的全局 query log、调试 bar、未释放的文件句柄。
2. **数据库连接复用**:常驻 worker 里复用 PDO 连接要特别注意 `wait_timeout` 与断线重连，否则空闲一段时间后第一次请求会拿到失效连接。
3. **内存上限必配**:`max_worker_memory` 既是兜底也是标配，生产环境务必开启。
4. **健康检查**:把 worker 启动命令 `php psr-worker.php` 单独跑一遍，有助于暴露引导阶段的语法错误与依赖问题。

## 参考

- [RoadRunner GitHub 仓库](https://github.com/roadrunner-server/roadrunner) — 高性能 PHP 应用服务器，用 Go 编写，MIT 协议
- [RoadRunner 官方文档](https://docs.roadrunner.dev/) — 架构、worker、插件配置等
- [Goridge 协议](https://github.com/roadrunner-server/goridge) — Go 与 PHP 之间的二进制 IPC 库
- [Spiral Framework](https://github.com/spiral/framework) — 与 RoadRunner 同一团队维护、原生支持的 PHP 框架
