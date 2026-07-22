+++
title = "K8s 中的开放接口"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "CRI、CNI、CSI 三大可插拔接口与扩展机制"
description = "梳理 Kubernetes 通过 CRI、CNI、CSI 三类开放接口将计算、网络、存储解耦的实现方式，并补充 Device Plugin 等扩展机制。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "CRI", "CNI", "CSI", "云原生", "架构"]
keywords = ["Kubernetes 开放接口", "CRI", "CNI", "CSI", "容器运行时接口", "Device Plugin"]
toc = true
draft = false
+++

Kubernetes 作为云原生应用的基础调度平台，常被类比为"云原生的操作系统"。和传统操作系统通过驱动屏蔽硬件差异类似，Kubernetes 通过一组**开放接口（Open Interfaces）** 把计算、网络、存储这三类最基础的资源抽象出来，让上游可以对接不同的后端实现，而无需修改 Kubernetes 核心代码。这种可插拔（pluggable）的设计，是 Kubernetes 能够支撑极其多样化的基础设施的关键。

## 接口全景

Kubernetes 的三大核心开放接口分别对应一种基础资源类型：

| 接口 | 全称 | 提供的资源 | 协议 | 规范仓库 |
| --- | --- | --- | --- | --- |
| CRI | Container Runtime Interface | 计算资源（容器） | gRPC | `kubernetes/cri-api` |
| CNI | Container Network Interface | 网络资源 | JSON 配置 + 可执行插件 | `containernetworking/cni` |
| CSI | Container Storage Interface | 存储资源 | gRPC | `container-storage-interface/spec` |

此外还有面向异构硬件的 **Device Plugin** 机制，可以让 GPU、FPGA、NIC 等设备以扩展资源的方式接入集群，常被并称为"第四类接口"。

下面分别展开。

## CRI:容器运行时接口

CRI（Container Runtime Interface）是 kubelet 与容器运行时之间的**主要 gRPC 协议**。Kubernetes 官方文档对其的定义是：

> The CRI is a plugin interface which enables the kubelet to use a wide variety of container runtimes, without having a need to recompile the cluster components.

### 服务拆分

CRI 把运行时能力拆成两个 gRPC 服务：

- **RuntimeService**:负责 Pod 沙箱（PodSandbox）和容器的生命周期管理，例如 `RunPodSandbox`、`CreateContainer`、`StartContainer`、`ContainerStatus` 等。
- **ImageService**:负责镜像的拉取、列表、查询和删除，例如 `PullImage`、`ListImages`。

PodSandbox 是 CRI 里的关键抽象，通常对应一组 Linux 命名空间（network、IPC 等）,同一 Pod 内的所有容器共享这同一个沙箱。

### kubelet 创建 Pod 的流程

当 kubelet 从 API Server 收到一个 Pod 后，典型交互如下:

```text
kubelet
  ├── gRPC ──► ImageService.PullImage()          # 1. 拉镜像
  ├── gRPC ──► RuntimeService.RunPodSandbox()    # 2. 创建沙箱,拿到 PodSandboxID
  ├── gRPC ──► RuntimeService.CreateContainer()  # 3. 在沙箱里创建容器
  ├── gRPC ──► RuntimeService.StartContainer()   # 4. 启动容器
  └── 轮询  ──► ContainerStatus() / ListContainers()  # 5. 持续对账
```

kubelet 通过 `--container-runtime-endpoint` 参数指定运行时监听的 Unix socket，例如:

```bash
kubelet --container-runtime-endpoint=unix:///run/containerd/containerd.sock
```

### 版本与运行时选型

- CRI API 的 `v1` 版本自 Kubernetes v1.23 起达到 Stable;**从 v1.26 起，kubelet 强制要求运行时支持 `v1` CRI API**,否则节点不会注册。
- 自 Kubernetes v1.24 起，内置的 `dockershim` 被移除，Docker Engine 不再直接对接 kubelet，需要通过 `cri-dockerd` 适配。
- 目前主流的 CRI 实现:
  - **containerd**:CNCF 毕业项目，业界事实标准。
  - **CRI-O**:由 Kubernetes 社区发起、CNCF 毕业，专为 Kubernetes 设计的轻量运行时，底层调用 OCI 兼容的 `runc` 或 `kata-containers`。
  - **cri-dockerd**:Mirantis 维护的 Docker Engine 适配层。

> 小贴士:Kubernetes v1.36 引入了 `CRIListStreaming`(Alpha),用流式 RPC 替代 `ListContainers` 等，解决单节点万级容器时 gRPC 默认 16 MiB 消息上限问题。

## CNI:容器网络接口

CNI（Container Network Interface）本身是一个**独立于 Kubernetes 的 CNCF 项目**,包含规范、库与一组参考插件，目标是"为 Linux 容器配置网络接口"。Kubernetes 借用它来实现 Pod 网络。

### 规范与仓库

- 规范仓库:`containernetworking/cni`,协议为 Apache-2.0，主要用 Go 实现，参考插件在 `containernetworking/plugins`。
- Kubernetes 要求 CNI 规范**最低 v0.4.0**,推荐 **v1.0.0** 及以上。
- 配置目录默认为 `/etc/cni/net.d/`,二进制目录默认为 `/opt/cni/bin/`。

### 由谁负责

一个常见的误解是 "kubelet 加载 CNI 插件"。实际上,**自 Kubernetes v1.24 起，kubelet 不再通过 `cni-bin-dir`、`network-plugin` 参数管理 CNI，改由容器运行时（containerd、CRI-O 等）负责加载和管理**。kubelet 仅仅通过 CRI 询问沙箱的网络命名空间，实际的网络配置走 CNI 协议。

### 工作模式

CNI 的设计非常 Unix 风格：它把网络能力切分成一个个独立的二进制(如 `bridge`、`ptp`、`host-local`、`portmap`、`bandwidth`),通过 JSON 配置串联起来，典型结构如下:

```json
{
  "name": "k8s-pod-network",
  "cniVersion": "0.4.0",
  "plugins": [
    { "type": "calico", "ipam": { "type": "host-local", "subnet": "usePodCidr" } },
    { "type": "portmap", "capabilities": { "portMappings": true } }
  ]
}
```

社区常见的 CNI 实现包括 Calico、Cilium、Flannel、Antrea、Weave Net、Kube-OVN、AWS VPC CNI 等，具体对比与选型可参考本博客的 [K8s CNI 网络插件](../k8s-network-cni/) 一文。

## CSI:容器存储接口

CSI（Container Storage Interface）是一个跨容器编排系统的标准，用于把任意的块存储、文件存储系统暴露给容器化工作负载。它由 Kubernetes、Mesos、Cloud Foundry 等社区共同推动，规范定义在 `container-storage-interface/spec`(对应 `csi.proto`)。

### 出树（out-of-tree）理念

在 CSI 之前，Kubernetes 把各类云盘驱动(`gcePersistentDisk`、`awsElasticBlockStore` 等)直接**编译进二进制**,称为 in-tree 插件。这种模式的缺点显而易见:

- 存储厂商每改一行代码，都要等下一个 Kubernetes 版本。
- 核心仓库被各家驱动塞得越来越臃肿。
- 安全/合规问题难以独立修复。

CSI 把这些能力搬到集群外部，以 **DaemonSet + Deployment** 的方式独立部署，既加快了迭代，也降低了核心复杂度。社区正在逐步把老的 in-tree 插件迁移到 CSI 并弃用之。

### 三种 gRPC 服务

CSI 驱动需要实现三类服务:

- **Identity Service**:声明驱动身份与能力。
- **Controller Service**:集群级操作，如 CreateVolume、DeleteVolume、Attach/Detach、Snapshot。
- **Node Service**:节点级操作，如 NodeStageVolume、NodePublishVolume(挂载到 Pod)。

### Sidecar 模式

为了避免每个驱动都重复实现一遍 Kubernetes API 交互逻辑，社区提供了一组 **external sidecar 容器**,负责监听 PVC、PV、VolumeAttachment 等对象并触发 CSI 调用，常见的有:

| Sidecar | 作用 |
| --- | --- |
| `external-provisioner` | 监听 PVC，触发 `CreateVolume`/`DeleteVolume` |
| `external-attacher` | 处理 VolumeAttachment，触发 `ControllerPublishVolume` |
| `external-resizer` | 处理 PVC 扩容 |
| `external-snapshotter` | 管理 VolumeSnapshot |
| `node-driver-registrar` | 把驱动注册到 kubelet |
| `livenessprobe` | 健康检查 |

CSI 自 Kubernetes v1.13 起 GA，生产环境基本以 v1.0.0 规范为基线。

## Device Plugin:面向异构硬件的"第四接口"

虽然不像前三个有醒目的三字母缩写,**Device Plugin** 同样是 Kubernetes 暴露的一类重要扩展接口，专门用于让厂商把 GPU、FPGA、SR-IOV NIC、InfiniBand 等硬件以**扩展资源（Extended Resource）** 的方式接入集群。

工作流程大致是：厂商以 DaemonSet 形式在每个节点运行一个 gRPC 服务，通过 `/var/lib/kubelet/device-plugins/kubelet.sock` 向 kubelet 注册自己，例如声明资源名 `nvidia.com/gpu`,随后通过 `ListAndWatch` 上报设备列表与健康状态。Pod 通过 `resources.limits` 申请:

```yaml
spec:
  containers:
    - name: cuda-container
      image: nvidia/cuda:12.0.0-base-ubuntu22.04
      resources:
        limits:
          nvidia.com/gpu: 2
```

容器创建时，kubelet 会调用驱动的 `Allocate`,把对应的设备节点(`/dev/nvidia0` 等)、环境变量、挂载、CDI 设备名注入到容器里。NVIDIA、Intel、AMD、华为等都基于这套机制提供了自己的 Device Plugin 实现。

## 为什么这种设计至关重要

把 CRI、CNI、CSI、Device Plugin 放在一起看，会发现 Kubernetes 的扩展模型有几个共同特点:

- **协议化、解耦**:核心只定义 gRPC/JSON 协议，后端实现可以独立演进。
- **out-of-tree**:厂商无需侵入 Kubernetes 主仓库，版本节奏各自掌控。
- **最小内核 + 丰富生态**:核心保持精简，生态通过接口外延。

正因如此，计算可以用 containerd 或 Kata Containers，网络可以选 Calico 或 Cilium，存储可以挂本地盘、Ceph 或云厂商的块存储，GPU 可以来自任意厂商——而 Kubernetes 本身一行代码都不用改。可以说，这套"开放接口"才是 Kubernetes 真正的护城河。

## 参考

- [Kubernetes 官方文档 — Container Runtime Interface (CRI)](https://kubernetes.io/docs/concepts/architecture/cri/)
- [Kubernetes 官方文档 — Network Plugins](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)
- [Kubernetes CSI 文档](https://kubernetes-csi.github.io/docs/)
- [Kubernetes 官方文档 — Device Plugins](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/device-plugins/)
- [CRI API 协议定义 (cri-api)](https://github.com/kubernetes/cri-api)
- [CNI 规范仓库 (containernetworking/cni)](https://github.com/containernetworking/cni)
- [CSI 规范仓库 (container-storage-interface/spec)](https://github.com/container-storage-interface/spec)
- [CRI-O 项目（cri-o/cri-o）](https://github.com/cri-o/cri-o)
- [开放接口 — Kubernetes Handbook](https://hezhiqiang.gitbook.io/kubernetes-handbook/gai-nian-yu-yuan-li/index/open-interfaces)
