+++
title = "trpc微服务寻址方案设计"
date = "2025-06-01"
lastmod = "2025-06-01"
subtitle = "从服务命名到北极星寻址的完整方案"
description = "介绍 tRPC 微服务的服务命名、路由命名、RPC 接口命名规范，以及基于北极星(PolarisMesh)插件的服务寻址方案，对比 WithServiceName 与 WithTarget 两种寻址方式。"
author = "小智晖"
authors = ["小智晖"]
categories = ["cpp"]
tags = ["cpp", "trpc", "微服务", "服务寻址", "北极星", "PolarisMesh"]
keywords = ["tRPC", "微服务寻址", "北极星", "PolarisMesh", "服务命名", "WithServiceName"]
toc = true
draft = false
+++

## 服务命名

tRPC 在服务命名上定义了以下 3 个维度信息：

- **app 名（应用名）**：表示某个业务系统的名称，用于标识某个业务下不同服务模块的一个集合。
- **server 名（模块名）**：表示具体服务模块的名称，一般也称为模块的进程名称。
- **service 名**：表示具体服务提供者的名称，一般使用 proto 文件定义的 Service 名称。

其中 `app.server` 的组合在全局上要具备唯一性。

服务命名这样定义的好处是：

- 对于服务开发，可以方便脚手架工具自动生成 tRPC 服务代码；
- 对于服务寻址，可以生成全局唯一的服务路由名称，方便服务注册和服务发现；
- 对于服务运营，可以方便服务的部署、各种维度的监控数据采集、告警等。

## 服务路由命名

为了方便对服务的路由寻址，服务的路由命名规范如下：

由 `.` 号分隔的四段字符串 `trpc.{app}.{server}.{service}` 组成。

其中，第 1 段固定为 `trpc`，表示这个服务是一个 tRPC 服务；第 2 段到第 4 段参考服务命名的含义。

另外，主调（caller）与被调（callee）的命名一般也与服务的路由命名保持一致。

## RPC 接口命名

接下来看看 tRPC 中被调如何根据主调的消息信息调用相应 RPC 方法来处理请求。这就涉及到主调方与被调方在消息通信协议上对 RPC 方法的命名需要有统一的规范。

下面是一个比较简单的服务提供的接口 proto 文件：

```proto
syntax = "proto3";

package trpc.test.helloworld;

service Greeter {
  rpc SayHello (HelloRequest) returns (HelloReply) {}
}

message HelloRequest {
   string msg = 1;
}

message HelloReply {
   string msg = 1;
}
```

基于 proto 文件的用法，tRPC 在 tRPC 协议上对 RPC 接口的名字制定了统一的规范，RPC 调用方法名由 proto 文件中的 `/{package_name}.{service_name}/{method_name}` 组成。

其中 `{package_name}` 建议使用 `trpc.{app}.{server}`，`{service_name}` 为上面 proto 文件中定义的 service 名字，`{method_name}` 为 service 下具体的方法名，即我们要调用的 RPC 接口。

## 北极星服务寻址

### tRPC-Go 框架内（tRPC-Go 服务）寻址

```go
import (
    _ "trpc.group/trpc-go/trpc-naming-polarismesh"
)

func main() {
    opts := []client.Option{
        // 命名空间，不填写默认使用本服务所在环境 namespace
        client.WithNamespace("Development"),
        // 服务名
        client.WithServiceName("trpc.app.server.service"),
    }

    clientProxy := pb.NewGreeterClientProxy(opts...)
    req := &pb.HelloRequest{
        Msg: "hello",
    }

    rsp, err := clientProxy.SayHello(ctx, req)
    if err != nil {
        log.Error(err.Error())
        return
    }

    log.Info("req:%v, rsp:%v, err:%v", req, rsp, err)
}
```

### 获取被调 IP

```go
import (
    "trpc.group/trpc-go/trpc-go/naming/registry"

    _ "trpc.group/trpc-go/trpc-naming-polarismesh"
)

func main() {
    node := &registry.Node{}
    opts := []client.Option{
        client.WithNamespace("Development"),
        client.WithServiceName("trpc.app.server.service"),
        // 传入被调 node
        client.WithSelectorNode(node),
    }

    clientProxy := pb.NewGreeterClientProxy(opts...)
    req := &pb.HelloRequest{
        Msg: "hello",
    }

    rsp, err := clientProxy.SayHello(ctx, req)
    if err != nil {
        log.Error(err.Error())
        return
    }
    // 打印被调节点
    log.Infof("remote server ip: %s", node)

    log.Info("req:%v, rsp:%v, err:%v", req, rsp, err)
}
```

### client.WithServiceName 寻址与 client.WithTarget 寻址的区别

#### 两种寻址方式的严格定义

满足 `client.WithServiceName` 寻址的充要条件（两条必须同时满足）：

- 未使用 `client.WithTarget` option；
- `trpc_go.yaml` 中 `client.service` 没有配置 `target` 字段。

满足 `client.WithTarget` 寻址的充分条件（两个条件二选一，同时存在时代码 option 的优先级高于配置）：

- 使用了 `client.WithTarget` option；
- `trpc_go.yaml` 中 `client.service` 配置了 `target` 字段。

上面没有提到 `client.WithServiceName` option 或者配置中的 `name` 字段，是因为这两个始终存在，不是区分这两种寻址方式的必要因素。

#### WithServiceName

期望通过 `WithServiceName` 的方式来完成北极星寻址，需要同时满足以下几个条件：

- 正确配置本插件：1. 包含匿名 import；2. 插件配置中有 polaris mesh selector。
- 代码 option 不要带 `client.WithTarget`，`trpc_go.yaml` 的客户端配置中也不要带 `target` 字段。

这样就实现了 `WithServiceName` 的寻址方式。此时你会发现除了插件配置中的 polaris mesh selector 有北极星相关信息，客户端配置中任何地方不再需要有 `polaris` 字样，但实际却是使用的北极星插件能力进行的寻址。这种现象的原因是北极星插件替换了 trpc-go 框架中的一些默认组件（服务发现、服务路由、负载均衡）为北极星插件的实现，导致客户端以几乎无感知的形式完成北极星寻址。

#### WithTarget

期望通过 `WithTarget` 的方式来完成北极星寻址，需要同时满足以下条件：

- 正确配置本插件：1. 包含匿名 import；2. 插件配置中有 polaris mesh selector。
- 二选一（同时存在时，代码 option 的优先级高于配置）：
  - 代码 option 带 `client.WithTarget("polarismesh://trpc.app.server.service")`；
  - `trpc_go.yaml` 的客户端配置中带 `target` 字段：`target: polarismesh://trpc.app.server.service`。

这样就实现了 `WithTarget` 的寻址方式。这里你会在 target 处看到明确的 `polaris` 字样，明确地感知到这个客户端在使用北极星寻址。

### 服务路由的打开与关闭区别

在关闭服务路由的前提下，可以通过设置环境名来指定请求路由到具体某个环境。

如下代码：根据路由信息寻址时，北极星只要查找到服务的 `NameSpace`、`ServiceName`、`EnvName` 满足条件，就会返回该服务的地址信息。

```go
opts := []client.Option{
    // 命名空间，不填写默认使用本服务所在环境 namespace
    client.WithNamespace("Development"),
    // 服务名
    // client.WithTarget("polarismesh://trpc.app.server.service"),
    client.WithServiceName("trpc.app.server.service"),
    // 设置被调服务环境
    client.WithCalleeEnvName("62a30eec"),
    // 关闭服务路由
    client.WithDisableServiceRouter()
}
```

当服务路由打开时，北极星寻址除了要检查被调服务（目标服务）的 `NameSpace`、`ServiceName`、`EnvName` 是否满足外，还需检查主调服务是否满足条件：

- 如果主调服务与被调服务属于同一个 Server，即 `trpc.{app}.{server}.service` 前三个字段相同，则匹配成功。
- 如果主调服务与被调服务属于不同 Server，需要在被调服务的北极星入站路由规则中放通主调服务。
- 如果被调服务的北极星入站路由规则中没有放通主调服务，则也可以在主调服务的北极星出站路由规则中放通被调服务。
- 被调服务的北极星入站路由规则和主调服务的出站路由规则同时存在的情况下，生效入站规则，出站规则失效。

**总结**

名字服务的寻址规则可以用 IP 地址的路由规则来类比：默认情况下，只有局域网内的地址能互通；如果跨网段，则需要配置跨网段路由；如果跨网段但又不想配路由，那么只能强制让路由规则失效。

## 参考

- [tRPC - 多语言、插件化、高性能的 RPC 开发框架](https://github.com/trpc-group/trpc/blob/main/README.zh_CN.md)
- [北极星插件 trpc-naming-polarismesh](https://github.com/trpc-ecosystem/go-naming-polarismesh/blob/main/README.zh_CN.md)
- [tRPC 术语文档（服务命名与路由规范）](https://github.com/trpc-group/trpc/blob/main/docs/zh/terminology.md)
