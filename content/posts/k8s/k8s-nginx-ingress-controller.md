+++
title = "K8s Nginx Ingress Controller 简介"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Kubernetes 官方 ingress-nginx 控制器的实现与热加载机制"
description = "介绍 Kubernetes 官方维护的 ingress-nginx 控制器:它如何围绕 Ingress 资源组装 nginx.conf、通过 OpenResty/Lua 避免上游端点变更时的全量 reload,以及 cmd 目录下各入口命令的用途。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "ingress", "ingress-controller", "nginx", "lua"]
keywords = ["k8s", "Nginx Ingress Controller", "ingress-nginx", "Ingress", "nginx.conf", "Lua"]
toc = true
draft = false
+++

在 Kubernetes 集群中，Ingress 作为集群内服务对外暴露的访问接入点，几乎承载着集群内服务访问的所有流量。

Ingress 是 Kubernetes 中的一个资源对象，用来管理集群外部访问集群内部服务的方式。通过 Ingress 资源可以配置不同的转发规则，根据 Host、URL 路径等条件，将请求路由到不同 Service 所对应的后端 Pod。

## Ingress Controller 工作原理

Ingress Controller 用于解析 Ingress 的转发规则。它接收外部请求，匹配 Ingress 规则后将其转发到后端 Service 所对应的 Pod，由 Pod 处理请求。Kubernetes 中 Service、Ingress 与 Ingress Controller 三者的关系如下：

- **Service**：后端真实服务的抽象，一个 Service 可以代表一组提供相同功能的后端 Pod。
- **Ingress**：反向代理规则，用来规定 HTTP、HTTPS 请求应该被转发到哪个 Service 所对应的 Pod。例如根据请求中的 Host 和 URL 路径，让请求落到不同 Service 所对应的 Pod 上。
- **Ingress Controller**：反向代理程序，负责解析 Ingress 的反向代理规则。如果 Ingress 发生增删改，Ingress Controller 会及时更新自己相应的转发规则；当请求到达时，它依据这些规则将请求转发到对应 Service 的 Pod 上。

Ingress Controller 通过 API Server 监听 Ingress 资源的变化，动态生成反向代理程序所需的配置文件，进而生成新的路由转发规则。

![ingress-controller 架构](/imgs/ingress-controller-arch.png)

## Nginx Ingress Controller

Nginx Ingress Controller 是 NGINX 在 Kubernetes 上的 Ingress Controller 实现，围绕 Kubernetes [Ingress 资源](https://kubernetes.io/docs/concepts/services-networking/ingress/) 构建，并使用 [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/) 存放控制器的全局配置。

Kubernetes 官方维护的仓库为：<https://github.com/kubernetes/ingress-nginx>

> 重要提示：该仓库已于 **2026 年 3 月 26 日归档**，进入只读状态。归档前为 best-effort 维护，归档后不再发布新版本、不再修复 bug 与安全问题，但已有部署以及镜像、Helm Chart 等产物仍可继续使用。新建集群不应再采用它，官方建议改用 [Gateway API](https://gateway-api.sigs.k8s.io/) 实现。

> 注意区分：`ingress-nginx`（Kubernetes 社区维护）与 `nginxinc/kubernetes-ingress`（NGINX 公司维护）是两个不同的项目，配置注解与 CRD 不互通，迁移时需注意区分。

ingress-nginx 仓库 `cmd/` 目录下的入口命令包括：

- `annotations`：注解处理逻辑。
- `dataplane`：数据面相关入口。
- `dbg`：调试工具。
- `nginx`：主程序，负责启动 ingress-nginx。
- `plugin`：kubectl 插件，用于检查 ingress-nginx 部署。
- `waitshutdown`：优雅关停辅助。

## 配置组装与热加载

ingress-nginx 控制器的核心目标是组装一份配置文件（`nginx.conf`）。这带来的主要影响是：配置文件发生任何更改后，通常都需要重新加载 NGINX。

控制器内部维护两份配置模型——当前运行中的配置和根据变更新生成的配置，通过 sync 逻辑做 diff；一旦发现变化，就把 Ingress、Secret、Endpoints 等渲染进 [nginx.tmpl](https://github.com/kubernetes/ingress-nginx/tree/main/rootfs/etc/nginx/template) 模板生成新的 `nginx.conf`，并触发 NGINX reload。

但需要注意：**当只有上游配置（即应用部署时 Endpoints 端点变化）或证书发生更改时，并不会重新加载 NGINX**。控制器通过 OpenResty 的 `lua-nginx-module`，把这些变更以 payload 形式 POST 到 NGINX 内部由 Lua 处理的端点，实现动态更新。Lua 脚本位于 `rootfs/etc/nginx/lua`，承担热更新、限流、监控、金丝雀流量切分等能力。

## 参考

- [ingress-nginx 官方文档](https://kubernetes.github.io/ingress-nginx/)
- [kubernetes/ingress-nginx 仓库（已归档）](https://github.com/kubernetes/ingress-nginx)
- [ingress-nginx Code Overview](https://kubernetes.github.io/ingress-nginx/developer-guide/code-overview/)
- [Ingress - Kubernetes 官方文档](https://kubernetes.io/zh-cn/docs/concepts/services-networking/ingress/)
- [Gateway API](https://gateway-api.sigs.k8s.io/)
