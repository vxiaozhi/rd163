+++
title = "K8s 源码阅读"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "kubernetes/kubernetes 仓库结构、核心目录与控制器模式的源码导读"
description = "整理 Kubernetes 主仓库的目录组织、staging 机制、核心组件入口以及 Informer/Controller 模式,为系统阅读源码提供一条清晰的路径。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "源码阅读", "kubernetes", "client-go", "go"]
keywords = ["k8s 源码", "kubernetes 源码阅读", "client-go", "informer", "staging 目录", "kubernetes 仓库结构"]
toc = true
draft = false
+++

## 概述

Kubernetes 的主仓库 [`kubernetes/kubernetes`](https://github.com/kubernetes/kubernetes) 是一个以 Go 为主(占比约 97%)的庞大项目,截至本文写作时提交数已超过 14 万。直接从根目录切入很容易迷失方向,阅读源码前先理解它的整体结构、构建机制和典型调用链,可以显著降低入门成本。

本文整理仓库目录组织、staging 机制、核心组件入口以及 Informer/Controller 模式,作为系统阅读 K8s 源码的索引。

## 仓库整体结构

根目录下的主要文件夹分工如下:

| 目录 | 作用 |
|------|------|
| `cmd/` | 各组件二进制的入口(`main.go`),如 `kube-apiserver`、`kube-controller-manager`、`kube-scheduler`、`kubelet`、`kube-proxy`、`kubeadm`、`kubectl` |
| `pkg/` | 核心实现代码,绝大部分业务逻辑集中于此 |
| `staging/` | 暂存目录,托管发布为独立 Go module 的子项目(如 `client-go`、`api`、`apimachinery`) |
| `plugin/` | 准入控制器(Admission Plugins)、调度器插件、云厂商插件 |
| `api/` | OpenAPI / Swagger 形式的 API 定义 |
| `build/`、`hack/` | 构建脚本、代码生成、CI 辅助工具 |
| `cluster/` | 在不同环境拉起集群的脚本 |
| `test/` | 端到端(e2e)、集成测试与基准测试 |
| `vendor/` | Go vendor 目录,第三方依赖 |

阅读时通常遵循「从 `cmd/` 进入,追踪到 `pkg/` 具体实现」的路径。

## staging 机制

Kubernetes 把对外发布的库放在 `staging/src/k8s.io/` 下,每个子目录是一个独立的 Go module,有自己的 `go.mod`。这些库通过 publishing-bot 自动同步到独立的 GitHub 仓库(如 `kubernetes/client-go`、`kubernetes/api`),开发者可以直接 `go get k8s.io/client-go` 使用,而不必引入整个 `kubernetes/kubernetes`。

仓库根目录的 README 明确说明:**直接将 `k8s.io/kubernetes` 作为库引入是不被支持的**,对外提供的稳定 API 都位于 staging 子项目里。

常用 staging 子项目:

- **`k8s.io/api`** — 内置资源(Pod、Deployment、Service 等)的 Go 类型定义,几乎不含业务逻辑。
- **`k8s.io/apimachinery`** — API 基础设施:Scheme、runtime、codec、`ObjectMeta`/`TypeMeta`/`ListMeta` 等元类型。
- **`k8s.io/client-go`** — 官方 Go 客户端库。
- **`k8s.io/apiserver`** — 自建 API Server 的通用库。
- **`k8s.io/code-generator`** — 代码生成工具集。
- **`k8s.io/component-base`** — 各组件共享的工具(命令行、metric、日志等)。

## 核心目录速览

### `cmd/` — 组件入口

每个子目录对应一个可执行文件,职责与 K8s 组件模型一致:

- `kube-apiserver`:控制面组件,暴露 Kubernetes HTTP API,是所有管理操作的入口。
- `kube-controller-manager`:控制面组件,内嵌多种控制器(Node、ReplicaSet、Endpoint、ServiceAccount 等)以 goroutine 形式运行。
- `kube-scheduler`:控制面组件,负责把未绑定节点的 Pod 调度到合适节点。
- `kubelet`:节点组件,每个节点上运行,确保 Pod 中容器按 PodSpec 运行。
- `kube-proxy`:节点组件,维护节点上的网络规则,实现 Service 的路由与负载均衡。
- `kubeadm`:集群引导工具。
- `kubectl`:命令行客户端。

### `pkg/` — 业务实现

- `pkg/apis/` — 内置 API 组的类型定义。
- `pkg/controller/` — 各类内建控制器的实现。
- `pkg/kubelet/` — Kubelet 主体逻辑(Pod 生命周期、CRI、容器运行时交互)。
- `pkg/proxy/` — kube-proxy 的 iptables/IPVS 实现。
- `pkg/scheduler/` — 调度框架与各调度插件。
- `pkg/apiserver/` — API Server 通用机制(认证、鉴权、准入、注册表)。
- `pkg/kubectl/` — kubectl 命令实现。

### `k8s.io/client-go` 子目录

| 子目录 | 作用 |
|--------|------|
| `kubernetes/` | typed clientset,如 `clientset.CoreV1().Pods(ns)` |
| `dynamic/` | 基于 `unstructured.Unstructured` 的非类型化客户端 |
| `discovery/` | 查询 API Server 支持的 API groups/resources |
| `informers/` | 带本地缓存的 Watch 封装,控制器核心组件 |
| `listers/` | 配合 informer 的类型化缓存访问器 |
| `tools/cache/` | `Reflector`、`Controller`、`SharedInformer` 等原语 |
| `tools/clientcmd/` | 加载 kubeconfig |
| `util/workqueue/` | 控制器使用的限速工作队列 |
| `applyconfigurations/` | Server-Side Apply 的生成类型 |

## Informer 与 Controller 模式

理解 K8s 控制器的关键是 Informer 模式。典型流程:

1. **Reflector** 通过 List + Watch 把 apiserver 上的对象同步到本地。
2. 对象被存入 **Store**(本地缓存),同时把事件丢入 **Delta FIFO Queue**。
3. **SharedInformer** 从队列取出事件,分发给已注册的 **EventHandler**。
4. EventHandler 通常只把对象的 key(namespace/name)放入 **workqueue**。
5. 控制器 worker goroutine 从 workqueue 取出 key,通过 **Lister** 查本地缓存执行业务逻辑。

相关源码主要集中在 `staging/src/k8s.io/client-go/tools/cache/` 与 `staging/src/k8s.io/client-go/util/workqueue/`,是阅读控制器实现的必经路径。

## 代码生成工具

K8s 大量使用代码生成保持类型定义、客户端、informer、lister 与编解码代码一致。`k8s.io/code-generator` 提供的生成器包括:

- `deepcopy-gen` — 生成 `DeepCopyObject` / `DeepCopy` 方法。
- `client-gen` — 生成 typed clientset。
- `informer-gen` — 生成 informer 工厂。
- `lister-gen` — 生成 lister。
- `conversion-gen` — 内部类型与版本化类型之间的转换函数。
- `openapi-gen` — OpenAPI schema 定义。

当前推荐入口脚本是仓库根目录下的 `kube_codegen.sh`。开发 CRD 控制器时,通常用这些工具生成样板代码,再补上自己的 reconcile 逻辑。

## 建议阅读顺序

1. `staging/src/k8s.io/api/core/v1/types.go` — 数据模型起点(`Pod`、`PodSpec`、`Container`)。
2. `staging/src/k8s.io/apimachinery/pkg/apis/meta/v1/types.go` — `ObjectMeta`、`TypeMeta`、`ListMeta`。
3. `staging/src/k8s.io/client-go/rest/config.go` — 客户端配置如何构造。
4. `staging/src/k8s.io/client-go/kubernetes/clientset.go` — typed clientset 入口。
5. `staging/src/k8s.io/client-go/tools/cache/` — `reflector.go`、`shared_informer.go`、`controller.go`。
6. `staging/src/k8s.io/client-go/util/workqueue/` — 限速队列实现。
7. `cmd/kube-controller-manager/` 与 `pkg/controller/` — 一个具体控制器(如 deployment)的完整链路。

## 上手项目

想自己写控制器时,以下官方示例值得参照:

- [`kubernetes/sample-controller`](https://github.com/kubernetes/sample-controller) — 用 CRD 定义一个 `Foo` 资源并实现对应控制器,覆盖类型注册、clientset/informer 生成、reconcile 逻辑全流程。
- [`kubernetes/sample-apiserver`](https://github.com/kubernetes/sample-apiserver) — 演示如何基于 `k8s.io/apiserver` 自建一个聚合 API Server。

## 参考

- [kubernetes/kubernetes 主仓库](https://github.com/kubernetes/kubernetes)
- [Kubernetes Components 官方文档](https://kubernetes.io/docs/concepts/overview/components/)
- [kubernetes/client-go](https://github.com/kubernetes/client-go)
- [kubernetes/code-generator](https://github.com/kubernetes/code-generator)
- [kubernetes/sample-controller](https://github.com/kubernetes/sample-controller)
- [Kubeedge 源码分析之总体介绍](https://github.com/chenzongshu/Kubernetes/blob/master/k8s%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90/Kubeedge%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90%E4%B9%8B%E6%80%BB%E4%BD%93%E4%BB%8B%E7%BB%8D.md)
