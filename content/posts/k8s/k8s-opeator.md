+++
title = "Kubernetes CRD 和 Operator"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "自定义资源与控制器模式：如何扩展 Kubernetes API"
description = "理解 Kubernetes 中 CRD（CustomResourceDefinition）与 Operator 的关系，介绍 Controller 的调和机制、三种开发方式（Informer、controller-runtime、Kubebuilder）以及 OpenKruise 等常用扩展。"
author = "小智晖"
authors = ["小智晖"]
categories = ["云原生", "k8s"]
tags = ["k8s", "Kubernetes", "CRD", "Operator", "controller-runtime", "Kubebuilder"]
keywords = ["CRD", "CustomResourceDefinition", "Operator", "Controller", "Reconcile", "Kubebuilder"]
toc = true
draft = false
+++

CRD 的全称是 CustomResourceDefinition，是 Kubernetes 为提高可扩展性、让开发者自定义资源（如 Deployment、StatefulSet 等）的一种方法。

```text
Operator = CRD（CustomResourceDefinition）+ Controller
```

CRD 仅仅是资源的定义，而 Controller 可以监听 CRD 的 CRUD 事件来添加自定义业务逻辑。

如果只是对 CRD 实例进行 CRUD，没有 Controller 也能实现，只是这时仅有数据（只会在 etcd 内生成这个对象），而没有针对数据的操作。

CR 约定了这个资源（或者说应用）将要达到的状态。那如何到达这个状态呢？这时就需要一个 Controller 负责调和（Reconcile）。

Controller 将 CR 规划的应用蓝图落地，并最终实现 CR 约定的应用状态。Controller 与 API Server 建立通信，监听特定 CR 的创建、销毁和更新事件，并在自己的控制循环内，使用 Kubernetes API 完成调和工作。

## 开发方式

开发 Controller 通常有以下三种方式：

- **直接使用 Informer**：直接使用 Informer 编写 Controller 需要编写更多代码，因为我们需要在代码里处理更多底层细节，例如如何在集群中监视资源，以及如何处理资源变化的通知。但这种方式也可以更自定义和灵活，因为我们可以更细粒度地控制 Controller 的行为。

- **controller-runtime**：controller-runtime 基于 Informer 实现，在 Informer 之上为编写 Controller 提供了高级别的抽象和帮助类，包括 Leader Election、Event Handling 和 Reconcile Loop 等。使用 controller-runtime，可以更容易地编写和测试 Controller，因为它已经处理了许多底层细节。

- [**Kubebuilder**](https://github.com/kubernetes-sigs/kubebuilder)：与 Informer 及 controller-runtime 不同，Kubebuilder 并不是一个代码库，而是一个开发框架，底层使用了 controller-runtime。Kubebuilder 提供了 CRD 生成器和代码生成器等工具，可以帮助开发者自动生成一些重复性的代码和资源定义，提高开发效率；同时还能生成 Webhooks，用于校验自定义资源。需要注意的是，Kubebuilder 的版本要与目标 Kubernetes 版本对应（例如 Kubebuilder 3.2 对应 Kubernetes 1.22，其 controller-runtime 版本为 v0.10.x）。

## 常用 Operator

### OpenKruise

[OpenKruise](https://github.com/openkruise/kruise) 是一个基于 Kubernetes 的扩展套件，是 CNCF 孵化项目，主要聚焦于云原生应用的自动化，涵盖部署、发布、运维以及可用性防护等场景。

OpenKruise 提供的绝大部分能力都基于 CRD 扩展来定义，不依赖任何外部组件，可以运行在任意纯净的 Kubernetes 集群中。典型能力包括 CloneSet、Advanced StatefulSet、Advanced DaemonSet、BroadcastJob、AdvancedCronJob 等高级工作负载，支持原地更新（in-place update）、增强发布策略等特性。

## 参考

- [Kubernetes CRD 和 Operator](https://github.com/chenzongshu/Kubernetes/blob/master/Kubernetes%20CRD%E5%92%8COperator.md)
- [Kubernetes Controller 机制详解（一）](https://www.zhaohuabing.com/post/2023-03-09-how-to-create-a-k8s-controller/)
- [Kubebuilder Book（官方文档）](https://book.kubebuilder.io/)
- [controller-runtime（GitHub）](https://github.com/kubernetes-sigs/controller-runtime)
- [OpenKruise 官方文档](https://openkruise.io/)
