+++
title = "Kubernetes 渐进式发布"
date = "2025-04-23"
lastmod = "2025-04-23"
subtitle = "蓝绿发布与金丝雀发布的原理及 k8s 实现"
description = "介绍 Kubernetes 中蓝绿发布和金丝雀发布(灰度发布)的原理,以及基于 Deployment、rollout pause/resume 的原生实现方式,并对比 Argo Rollouts、OpenKruise Rollouts、Flagger 等第三方渐进式交付方案。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "kubernetes", "蓝绿发布", "金丝雀发布", "灰度发布", "rollout"]
keywords = ["k8s 渐进式发布", "蓝绿发布", "金丝雀发布", "灰度发布", "kubectl rollout", "Argo Rollouts"]
toc = true
draft = false
+++

通常渐进式发布主要包括两类：蓝绿发布和金丝雀发布。本文对此做详细介绍，前置背景可参考:

- [k8s 应用更新策略：灰度发布和蓝绿发布](https://www.hebye.com/docs/k8s-roll/k8s-roll-1dd4l55dga9d1)

## 常规方案

### 蓝绿发布

蓝绿部署中一共存在两套系统：一套是正在对外提供服务的系统，标记为「绿色」;另一套是准备发布的系统，标记为「蓝色」。两套系统都是功能完善、可独立运行的系统，只是版本和对外服务状态不同。

当需要用新版本替换线上旧版本时，会在现有系统之外部署一套使用新版本代码的全新系统。此时两套系统并存：继续对外提供服务的旧系统是绿色系统，新部署的系统是蓝色系统。切换时只需把流量入口指向蓝色系统即可完成发布;如需回退，再把流量切回绿色系统。

Kubernetes 原生并不直接支持蓝绿发布。要在 k8s 中实现蓝绿发布，通常的做法是：部署两个 Deployment 分别作为蓝方和绿方，再通过更新 Service 的 selector(或 Ingress 后端)将其指向新的 Deployment。

### 金丝雀发布

金丝雀发布的名称来源于一个历史典故：矿工曾利用金丝雀对瓦斯（一氧化碳、甲烷等）等有毒气体极为敏感的特性，将其带入矿井作为早期预警装置。当空气中出现微量有毒气体时，金丝雀会先于人体出现中毒反应，从而为矿工争取宝贵的撤离时间。(注：这一做法在 British Coal 等英国煤矿中大约始于 1900 年前后，直到 1986 年起逐步淘汰，并于 1996 年正式废止。)

金丝雀发布（国内常称灰度发布、灰度更新）借鉴了这一思路：先发布一台，或一个小比例（例如 2%）的服务实例，主要用于做流量验证，因此也称为金丝雀（Canary）测试。

简单的金丝雀测试一般通过手工验证完成;复杂的金丝雀测试则需要较完善的监控基础设施配合，通过监控指标反馈来观察金丝雀实例的健康状况，作为后续继续发布或回退的依据。如果金丝雀测试通过，则把剩余的 V1 版本全部升级为 V2 版本;如果金丝雀测试失败，则直接回退金丝雀，本次发布失败。

在 k8s 中，可以借助 Deployment 的滚动更新策略配合 `rollout pause/resume` 机制来实现简易的金丝雀发布，示例如下。

将应用 `myapp-v1` 的镜像升级到 v2，然后立即暂停滚动:

```bash
[root@k8s-master1 blue-green]# kubectl set image deployment myapp-v1 myapp=hebye/myapp:v2 -n blue-green && \
> kubectl rollout pause deployment myapp-v1 -n blue-green
deployment.apps/myapp-v1 image updated
deployment.apps/myapp-v1 paused
```

观察一段时间，如果一切正常，则继续 `resume` 推进剩余的滚动更新:

```bash
[root@k8s-master1 blue-green]# kubectl rollout resume deployment myapp-v1 -n blue-green
deployment.apps/myapp-v1 resumed
```

如果发现问题，则把镜像回退到先前版本，再 `resume`:

```bash
[root@k8s-master1 blue-green]# kubectl set image deployment myapp-v1 myapp=hebye/myapp:v1 -n blue-green
[root@k8s-master1 blue-green]# kubectl rollout resume deployment myapp-v1 -n blue-green
```

> 注意：在 Pause 状态下直接调用 `kubectl rollout undo` 是无法触发实际回滚动作的——`undo` 命令本身不会报错（它会修改 Pod template 并写入 revision history）,但 Deployment 控制器在暂停期间不会执行任何 ReplicaSet 的滚动，回滚要等 `rollout resume` 之后才会真正生效。因此上文采用「先 `set image` 回退、再 `resume`」的方式，等价于让暂停期间的累积变更在恢复时一次性应用:

```bash
[root@master1 ~]# kubectl rollout undo deployment myapp-v1 -n blue-green
# 在 paused 状态下,该命令修改了 template,但不会立即触发回滚
```

## 第三方基于 k8s 的实现方案

k8s 原生的 `Deployment + rollout pause/resume` 只能实现非常粗粒度的金丝雀（基于 Pod 副本数比例）,无法做到精确的按百分比、按请求头划分流量。生产环境中通常会使用专门的渐进式交付（Progressive Delivery）控制器:

- [Argo Rollouts](https://github.com/argoproj/argo-rollouts):Argo 生态的控制器，提供 BlueGreen、Canary 两种更新策略，支持流量整形、基于 Prometheus 等指标自动分析并决定晋升或回退。
- [OpenKruise Rollouts](https://github.com/openkruise/rollouts):OpenKruise 出品，支持 Canary、多批次（Multi-batch）和 A/B 测试等模式，兼容 Deployment、CloneSet、StatefulSet，并能与 Ingress、Gateway API 协同做细粒度流量编排。
- [Flux Flagger](https://github.com/fluxcd/flagger):CNCF 毕业项目，隶属于 Flux 家族，支持 Canary、A/B Testing、Blue/Green，可与多种 Ingress 控制器、服务网格（Istio、Linkerd 等）及监控系统集成，实现自动化的金丝雀分析与发布。

OpenKruise 官方文档中对这几种方案有更直观的对比:[OpenKruise Rollouts Introduction](https://openkruise.io/rollouts/introduction/)。

## 参考链接

- [Kubernetes 官方文档:Deployments - Pausing and Resuming a Rollout](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#pausing-and-resuming-a-rollout)
- [Kubernetes 官方文档:Deployments - Rolling Back a Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-back-a-deployment)
- [kubectl rollout 命令参考](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#rollout)
- [Argo Rollouts 官方文档](https://argo-rollouts.readthedocs.io/en/stable/)
- [Flagger 文档](https://docs.flagger.app/)
