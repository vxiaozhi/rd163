+++
title = "使用 KubeRay 在 Kubernetes 中托管 Ray 工作负载"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "用 Operator 模式在 K8s 上编排 Ray 集群、作业与服务"
description = "介绍如何使用 KubeRay Operator 在 Kubernetes 上部署和管理 Ray 集群、RayJob 与 RayService,并结合 Kueue 做排队调度。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "Ray", "KubeRay", "Kubernetes", "分布式计算", "Kueue"]
keywords = ["KubeRay", "Ray", "Kubernetes", "RayCluster", "RayJob", "Kueue"]
toc = true
draft = false
+++

Ray 是源自 UC Berkeley RISELab 的通用分布式计算框架，被广泛用于机器学习训练、超参搜索、强化学习和在线推理。当团队规模扩大、需要在多租户的共享集群上跑 Ray 时，把 Ray 装到裸机或虚拟机往往会陷入调度、容错和版本管理的泥潭。Kubernetes 已经成为事实标准的工作负载编排平台，而 KubeRay 正是把 Ray 与 Kubernetes 桥接起来的官方推荐方案。

本文整理 Ray 在 Kubernetes 上落地的核心概念、安装方式、典型 CRD(Custom Resource Definition，自定义资源定义)用法，以及与 Kueue 结合做排队调度的实践要点。

## Ray 与 KubeRay 简介

### Ray 是什么

Ray 在 Python 中以 `@ray.remote` 装饰器提供两个核心原语：无状态的 **Task**(任务)和有状态的 **Actor**(执行体)。在此之上构建了 Ray Data、Ray Train、Ray Tune、Ray Serve、RLlib 等高层库，覆盖数据预处理、训练、调参、推理和强化学习全链路。

一个 Ray 集群由两类节点组成:

- **Head 节点（头节点）**:运行全局控制服务 GCS(Global Control Service)、Raylet 进程和 Dashboard，是整个集群的协调中枢。
- **Worker 节点（工作节点）**:只运行 Raylet 与任务执行器，处理实际的计算负载。

默认情况下 Head 节点也参与计算，但生产环境通常会把它作为控制面独立保护。

### KubeRay 是什么

[KubeRay](https://github.com/ray-project/kuberay) 是 Ray 项目下的开源 Kubernetes Operator(Apache-2.0 协议),由字节跳动、Anyscale 等共同维护，Apple、Google、Spotify、DoorDash、Roblox、Airbnb、eBay、Reddit 等公司都在生产中使用。

它通过 Operator 模式把 Ray 集群抽象成几类 CRD，用户可以像管理 Deployment、StatefulSet 一样，用 `kubectl` 管理 Ray 资源，并复用 Helm、Prometheus、Grafana、Volcano、Kueue 等云原生生态。

## KubeRay 的三个核心 CRD

KubeRay 核心提供三类 CRD，分别对应三种使用场景。

### RayCluster

`RayCluster` 是最基础的资源，描述一个完整的 Ray 集群，包括 Head 和 Worker 的规格、副本数、镜像、自动扩缩容参数等。KubeRay 负责整个生命周期：创建、删除、扩缩容与故障恢复。

```yaml
apiVersion: ray.io/v1
kind: RayCluster
metadata:
  name: raycluster-sample
spec:
  rayVersion: "2.52.0"
  headGroupSpec:
    serviceType: ClusterIP
    rayStartParams:
      dashboard-host: "0.0.0.0"
    template:
      spec:
        containers:
          - name: ray-head
            image: rayproject/ray:2.52.0
            ports:
              - containerPort: 6379
                name: gcs
              - containerPort: 8265
                name: dashboard
              - containerPort: 10001
                name: client
            resources:
              limits:
                cpu: "1"
                memory: "5Gi"
              requests:
                cpu: "500m"
                memory: "2Gi"
  workerGroupSpecs:
    - replicas: 1
      minReplicas: 1
      maxReplicas: 10
      groupName: small-group
      rayStartParams: {}
      template:
        spec:
          containers:
            - name: ray-worker
              image: rayproject/ray:2.52.0
              resources:
                limits:
                  cpu: "1"
                  memory: "1Gi"
                requests:
                  cpu: "500m"
                  memory: "1Gi"
```

Head Pod 暴露的关键端口:`6379`(GCS)、`8265`(Dashboard)、`10001`(Ray Client)。生产环境务必把 CPU/memory 的 `requests` 与 `limits` 设成相等，且使用整数 CPU，避免节点超卖导致任务被驱逐。

### RayJob

`RayJob` 适合一次性批处理任务：它会自动创建一个临时 RayCluster，提交用户脚本，完成后根据 `shutdownAfterJobFinishes` 决定是否删除集群，从而避免闲置浪费。

```yaml
apiVersion: ray.io/v1
kind: RayJob
metadata:
  name: rayjob-sample
spec:
  submissionMode: K8sJobMode
  entrypoint: "python /home/ray/samples/sample_code.py"
  shutdownAfterJobFinishes: true
  ttlSecondsAfterFinished: 10
  runtimeEnvYAML: |
    pip:
      - requests==2.26.0
      - pendulum==2.1.2
    env_vars:
      counter_name: "test_counter"
  rayClusterSpec:
    rayVersion: "2.52.0"
    # headGroupSpec / workerGroupSpecs 与 RayCluster 一致
```

`submissionMode` 有两种:`K8sJobMode`(默认，通过 K8s Job 跑 submitter)与 `HTTPMode`(直接调 Ray Dashboard API)。源码与示例可以通过 ConfigMap 挂载到 Pod 里。

### RayService

`RayService` 面向在线推理，由一个 RayCluster 和一份 Ray Serve 部署图组成，提供零停机升级（Zero-downtime upgrade）和高可用。更新时 KubeRay 会先拉起新版本集群，流量切换成功后再回收旧集群，避免模型迭代期间服务中断。

## 安装 KubeRay Operator

KubeRay 推荐使用 Helm 安装。前置条件是 Helm >= 3 和一个可用的 Kubernetes 集群（KinD、minikube 或云上集群均可）。

```bash
# 添加 KubeRay 官方 Helm 仓库
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update

# 安装 operator(默认部署到 default 命名空间)
helm install kuberay-operator kuberay/kuberay-operator

# 检查 operator 是否就绪
kubectl get pods -l app.kubernetes.io/name=kuberay-operator
```

安装完成后，即可用 `kubectl apply -f` 提交 RayCluster/RayJob/RayService 资源。截至本文撰写时，KubeRay 最新版本为 v1.6.2(2025 年 6 月发布),示例中的 Ray 版本为 2.52.0;实际使用时请以 [Releases 页面](https://github.com/ray-project/kuberay/releases)和 [Ray 官方文档](https://docs.ray.io/)的最新版本为准。

如果只是想快速体验，也可以直接用 Helm 拉起一个最小集群:

```bash
helm install raycluster kuberay/ray-cluster
kubectl get raycluster raycluster-kuberay
kubectl port-forward svc/raycluster-kuberay-head-svc 8265:8265
# 浏览器打开 http://127.0.0.1:8265 即可访问 Ray Dashboard
```

## 与 Kueue 集成做排队调度

在多团队共享的 GPU 集群上，仅靠 KubeRay 的自动扩缩容不足以解决"谁先拿到资源"的问题。[Kueue](https://kueue.sigs.k8s.io/) 是 kubernetes-sigs 下的批处理排队调度器，核心概念包括:

- **ResourceFlavor**:定义一种资源规格（例如按需实例、Spot 实例、带 GPU 的节点池）。
- **ClusterQueue**:集群级配额池，聚合多个 LocalQueue 的请求。
- **LocalQueue**:命名空间内的队列，业务方把 RayJob 指向某个 LocalQueue 提交。
- **Cohort**:让多个 ClusterQueue 之间互相借用闲置配额。

把 RayJob 接入 Kueue 只需在 metadata 上加一个标签，资源请求写在 `spec.rayClusterSpec` 的 `headGroupSpec` 与 `workerGroupSpecs` 中:

```yaml
metadata:
  labels:
    kueue.x-k8s.io/queue-name: user-queue
```

Kueue 接管后会自动控制 `spec.suspend` 字段：资源不够时挂起 RayJob，资源可用时再 unsuspend。需要注意几个限制:

1. 被 Kueue 接管的 RayJob 不能复用已存在的 RayCluster;
2. 必须设置 `spec.shutdownAfterJobFinishes: true`;
3. 由于 PodSet 上限为 18,worker group 数量最多 17 个。

从 Kueue v0.14.7 / v0.15.2 起，通过开启 `ElasticJobsViaWorkloadSlices` 特性门控、加上 `kueue.x-k8s.io/elastic-job: "true"` 注解，并在 RayCluster 中设置 `enableInTreeAutoscaling: true`,还能让 Ray 在 Kueue 调度框架内做弹性扩缩容。

## 生产实践要点

- **GCS 容错**:Ray 默认把 GCS 状态存在内存，Head 重启会丢元数据。生产环境建议开启外部存储（如 Redis）,让 Actor、Placement Group 等状态可恢复。
- **资源请求=限制**:K8s 调度器基于 `requests` 分配，KubeRay 自动扩缩容也以此为准。把 `requests` 设为与 `limits` 相等，可避免 noisy neighbor 与 OOM。
- **镜像管理**:Ray 镜像较大（带 GPU 的镜像可达数 GB）,建议预拉到节点或用镜像加速;不同业务隔离时，通过 `runtimeEnvYAML` 管理 pip 依赖，而非不断打新镜像。
- **可观测性**:KubeRay 仓库 `install/prometheus` 下提供 Prometheus 抓取配置，Ray Dashboard 同时暴露 Grafana 可视化指标，建议把 Ray 的核心指标（任务数、对象存储占用、节点状态）接入现有监控。
- **多版本并存**:一个 K8s 集群里可以同时跑多个不同 Ray 版本的 RayCluster，便于灰度迁移，但要留意 Operator 与 Ray 的版本兼容矩阵。

## 参考

- [KubeRay GitHub 仓库](https://github.com/ray-project/kuberay)
- [Ray 官方文档:Ray on Kubernetes](https://docs.ray.io/en/latest/cluster/kubernetes/index.html)
- [KubeRay RayCluster 快速开始](https://docs.ray.io/en/latest/cluster/kubernetes/getting-started/raycluster-quick-start.html)
- [Kueue 文档：运行 RayJob](https://kueue.sigs.k8s.io/docs/tasks/run_rayjobs/)
- [使用 KubeRay 和 Kueue 在 Kubernetes 中托管 Ray 工作负载（火山引擎开发者社区）](https://developer.volcengine.com/articles/7309395740965486619)
