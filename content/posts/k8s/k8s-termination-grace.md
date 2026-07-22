+++
title = "Kubernetes 优雅停止"
date = "2025-05-09"
lastmod = "2025-05-09"
subtitle = "Pod 终止流程、PreStop 钩子与宽限期实践"
description = "梳理 Kubernetes Pod 优雅终止的完整流程,涵盖 PreStop 钩子、SIGTERM/SIGKILL 信号以及 terminationGracePeriodSeconds 宽限期的配置实践。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["kubernetes", "pod", "优雅停止", "生命周期", "最佳实践"]
keywords = ["Kubernetes 优雅停止", "Pod 终止流程", "PreStop Hook", "terminationGracePeriodSeconds", "SIGTERM", "kube-proxy"]
toc = true
draft = false
+++

在 Kubernetes（K8s）中，Pod 的优雅终止是一个有序的过程，旨在确保 Pod 中运行的应用程序能够平滑关闭、释放资源，并尽可能减少因突然关闭带来的数据丢失和服务中断。

## Pod 优雅终止的一般步骤

1.  **删除 Pod 请求**

    - 用户或控制器发出删除 Pod 的请求，例如通过 `kubectl delete pod <pod-name>` 触发，或由 Deployment 的滚动更新等策略引起。

2.  **Pod 状态更改为 Terminating**

    - Kubernetes 控制平面接收到请求后，将 Pod 的状态更新为 `Terminating`。

3.  **从 Endpoints 中移除 Pod**

    - Pod 被标记为 `Terminating` 的同时，API server 会将其从对应 Service 的 Endpoints（以及 EndpointSlices）中移除;随后各节点上的 kube-proxy 监听到这一变化，更新本地的 iptables/IPVS（或 eBPF）转发规则，使新的流量不再被路由到该 Pod。

4.  **执行 PreStop Hook**

    - 如果 Pod 的定义中包含 `.spec.containers[].lifecycle.preStop` 钩子，kubelet 会在发送 SIGTERM 信号**之前**先执行这些自定义操作，例如清理缓存、写入最终状态或通知外部服务。PreStop 钩子的执行时长会计入下面的优雅终止期。

5.  **发送 SIGTERM 信号**

    - PreStop 钩子执行完毕后（若未配置则立即）,kubelet 向 Pod 中每个容器的主进程（PID 1）发送 SIGTERM 信号，这标志着容器应当开始执行其自身的优雅停机流程。

6.  **等待容器关闭**

    - 容器在接收到 SIGTERM 信号后，应尽快结束正在处理的请求，完成必要的清理工作后自行退出。

7.  **Grace Period（优雅终止期）**

    - Kubernetes 会给 Pod 一个优雅终止期，默认为 **30 秒**,可在 Pod 的 `.spec.terminationGracePeriodSeconds` 中自定义。在此期间，kubelet 会等待容器自行关闭。注意:PreStop 钩子的执行时间与容器处理 SIGTERM 的时间合计不得超过该宽限期。

8.  **强制停止**

    - 如果宽限期结束后容器仍未退出，kubelet 会向其发送 SIGKILL 信号强制终止，以确保 Pod 能够及时释放资源。

9.  **清理 Pod 资源**

    - 所有容器终止后，kubelet 会清理与 Pod 关联的各种资源，例如临时存储卷、环境变量、网络端点等。

10. **Pod 完全删除**

    - 当 Pod 的所有资源都被成功清理后，kubelet 会将 Pod 从集群中删除，Pod 的生命周期至此结束。

综上，整个过程中应用程序应当监听 SIGTERM 信号，并在接收到该信号时开始优雅地关闭服务。这一系列动作确保了 Pod 不仅能够快速响应集群管理的需求，还能尽量避免由此造成的用户体验下降或数据完整性损失。

需要注意的是，如果在等待容器进程停止的过程中，kubelet 或容器运行时发生了重启，那么终止操作会重新获得一个满额的删除宽限期并重新执行删除流程。这是因为 kubelet 没有持久化 SIGTERM 发送时刻的时间戳，在重启后无法续算已用时间。

优雅终止过程确保了 Pod 中的容器在被删除前能够完成必要的清理工作，从而避免数据丢失和资源泄漏。这对长期运行的容器以及需要保持数据一致性的应用尤为重要。

## 原理及实践

由于「从 Endpoints 移除 Pod」与「向容器发送 SIGTERM」是两条并行的异步路径，二者之间存在竞态：当 kube-proxy 在部分节点上尚未完成规则更新时，容器可能已经开始关闭，从而导致少量请求被路由到正在退出的 Pod，出现连接拒绝或 502 等错误。常见的缓解手段包括:

- 在 `preStop` 钩子中加入 `sleep 5`（或更长，视集群规模而定）,为 kube-proxy 留出规则同步时间;
- 在应用层实现优雅关闭逻辑（如 drain 在途请求、停止接收新连接）;
- 必要时调大 `terminationGracePeriodSeconds`(默认 30 秒)。

一个典型的 Nginx 示例:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: graceful-pod
spec:
  terminationGracePeriodSeconds: 60
  containers:
    - name: app
      image: nginx
      lifecycle:
        preStop:
          exec:
            command: ["/bin/sh", "-c", "sleep 10 && nginx -s quit"]
```

上述配置中,`preStop` 先 sleep 10 秒以等待 kube-proxy 同步，再通过 `nginx -s quit` 触发 Nginx 自身的优雅退出;若 60 秒内容器仍未退出，kubelet 会发送 SIGKILL 强制终止。

## 参考

- [Pod 生命周期 - Kubernetes 官方文档](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-termination)
- [详解 Kubernetes Pod 优雅退出](https://www.cnblogs.com/zhangmingcheng/p/18254613)
