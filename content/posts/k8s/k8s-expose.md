+++
title = "k8s 暴露服务的方式"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从 NodePort、LoadBalancer、Ingress 到 port-forward"
description = "梳理 Kubernetes 在集群内外暴露 Service 的常见方式，包括 NodePort、LoadBalancer、Ingress，以及本地调试常用的 kubectl proxy 与 kubectl port-forward。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "kubernetes", "service", "ingress", "nodeport", "kubectl"]
keywords = ["k8s 暴露服务", "NodePort", "LoadBalancer", "Ingress", "kubectl proxy", "kubectl port-forward"]
toc = true
draft = false
+++

## 暴露 Service 的三种方式

Kubernetes 中将 Service 暴露给集群外部访问，最常用的有三种类型：NodePort、LoadBalancer 和 Ingress。（ClusterIP 仅在集群内部可达，ExternalName 则通过 DNS CNAME 映射，二者不在本文讨论的对外暴露范围内。）

### 1. NodePort

将 Service 的 `type` 设置为 `NodePort`。此时每个集群节点都会在节点本机上打开一个端口（默认端口范围是 `30000-32767`），并将在该端口上接收到的流量重定向到后端 Service。

也就是说，该服务不仅在集群内部 IP 和端口上可以访问，还可以通过任意节点的 `<NodeIP>:<NodePort>` 从外部访问。

### 2. LoadBalancer

将 Service 的 `type` 设置为 `LoadBalancer`。它是 NodePort 类型的扩展：Kubernetes 会先自动创建 ClusterIP 和 NodePort，然后调用底层云基础设施（由云控制器管理器提供）分配一个专用的外部负载均衡器。负载均衡器把流量转发到各节点上的 NodePort，客户端通过负载均衡器的公网 IP 访问服务。

因此 LoadBalancer 通常只能在公有云（如 AWS、GCP、Azure、阿里云等）或安装了兼容负载均衡器实现的裸金属集群上使用。

### 3. Ingress

创建一个 Ingress 资源，这与前两种方式机制完全不同。Ingress 通过一个 IP 地址（由 Ingress Controller 提供）公开多个服务，通常面向 HTTP/HTTPS 流量，可以根据域名（host）或路径（path）将请求路由到集群内的不同 Service。

可以把 Ingress 理解为集群的网关入口，作用类似于 Spring Cloud 中的 Zuul、Spring Cloud Gateway 或 Nginx 反向代理。需要注意，单独创建 Ingress 资源并不会生效，必须先安装一个 Ingress Controller（如 NGINX Ingress Controller、Traefik 等）来实际处理和转发流量。

> 提示：Kubernetes 官方目前已推荐使用 [Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/) 作为 Ingress 的演进方案，Ingress API 已进入维护状态（frozen），不再新增特性，但仍可稳定使用。

## 本地 K8s 集群暴露方法

在本地开发、调试场景下，通常无需把服务暴露到集群外部，而是通过下面的方式从本地访问集群内的资源。

### 1. kubectl proxy

`kubectl proxy` 是 Kubernetes 命令行工具提供的子命令，用于在本地启动一个代理服务器，将本地端口与集群的 API Server 连接起来。它复用了 kubeconfig 中的认证信息，因此可以通过 HTTP 直接访问 API Server 提供的 REST 接口和资源，而无需把 API Server 直接暴露给外部网络。

执行 `kubectl proxy` 后，会在本地启动一个 HTTP 代理，默认监听 `127.0.0.1:8001`。之后即可用 `curl`、`wget` 或浏览器等工具访问和操作集群中的 API 资源。

例如，获取 default 命名空间下的所有 Pod：

```bash
curl http://localhost:8001/api/v1/namespaces/default/pods
```

需要注意的是，在生产环境中不建议把 API Server 直接暴露到公共网络，而应通过严格的安全策略进行访问控制和认证。`kubectl proxy` 主要用于开发、测试和调试场景。

### 2. kubectl port-forward

`port-forward` 通过端口转发，把本地端口映射到集群内指定资源（Pod、Deployment、Service 等）的端口上，常用于验证部署的 Pod、Service 等是否正常提供访问。

命令格式：

```bash
kubectl port-forward <pod_name> <local_port>:<remote_port> \
  --namespace <namespace> --address <IP>  # IP 默认为 127.0.0.1
```

例如，将本地的 8080 端口转发到某个 Pod 的 80 端口：

```bash
kubectl port-forward pod/my-pod 8080:80
```

`--address` 默认只绑定 `127.0.0.1`（以及 IPv6 的 `[::1]`）。如果要让局域网内其他主机也能访问，可显式指定 `--address 0.0.0.0`，但要注意这会带来安全风险。此外，`port-forward` 仅支持 TCP，命令运行期间会一直占用前台进程，需要另开终端进行其他操作。

## 参考

- [详解 Kubernetes 五种暴露服务的方式](https://www.cnblogs.com/gaoyuechen/p/17318934.html)
- [k8s-（七）暴露服务的三种方式](https://blog.csdn.net/qq_21187515/article/details/112363072)
- [kubectl proxy 作用](https://golang.0voice.com/?id=7330)
- [Kubernetes 官方文档：Service](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Kubernetes 官方文档：Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Kubernetes 官方文档：使用端口转发访问集群应用](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)
