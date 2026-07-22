+++
title = "k8s 本地化安装部署"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "在本地计算机上运行 Kubernetes 的几种常见工具对比"
description = "介绍 Kind、Minikube、K3s、kubeadm 四种主流的 Kubernetes 本地化部署方案,对比其适用场景与核心特性,帮助开发者快速搭建本地集群。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "kubernetes", "kind", "minikube", "k3s", "kubeadm"]
keywords = ["k8s 本地部署", "Kubernetes 本地集群", "kind", "minikube", "k3s", "kubeadm"]
toc = true
draft = false
+++

在学习和开发 Kubernetes(K8s)应用时,先在本地计算机上搭建一个集群用于测试和验证,是最高效的方式之一。官方文档将这些场景归为「学习环境(Learning Environment)」,与「生产环境(Production Environment)」相对。本文梳理四种主流的本地化部署工具,并对比其适用场景。

## 工具概览

按照使用方式与目标场景,常见的本地化部署方案可分为以下几类:

| 工具 | 运行方式 | 主要场景 |
| --- | --- | --- |
| **Kind** | 在 Docker/Podman 容器中运行 K8s 节点 | CI、本地开发、测试 K8s 本身 |
| **Minikube** | 在 VM 或容器中运行单/多节点集群 | 学习、应用开发 |
| **K3s** | 单一二进制文件,轻量化发行版 | 边缘、IoT、CI、资源受限环境 |
| **kubeadm** | 在裸机或虚拟机上引导集群 | 生产级集群引导,也可用于本地 |

下面逐一介绍。

## Kind(Kubernetes IN Docker)

[Kind](https://kind.sigs.k8s.io/) 是 Kubernetes SIG 维护的工具,全称是 **Kubernetes IN Docker**。它的核心思路是把每个 Kubernetes「节点」放进一个 Docker(或 Podman、nerdctl)容器中运行,而不是虚拟机。每个节点内部通过 `kubeadm` 完成引导。

Kind 最初是为了测试 Kubernetes 自身而设计的,但也广泛用于本地开发和 CI 流水线。它是一个 **CNCF 认证的、符合一致性标准的 Kubernetes 安装器**。

主要特性:

- 支持多节点集群(包括高可用拓扑)
- 支持从源码构建 Kubernetes 发行版
- 跨平台:Linux、macOS、Windows
- 启动速度快,资源开销低

安装(需要 Go 1.17+ 与 Docker):

```bash
go install sigs.k8s.io/kind@v0.32.0
```

快速创建并销毁集群:

```bash
kind create cluster        # 创建默认集群(名为 kind)
kubectl cluster-info --context kind-kind
kind delete cluster        # 销毁集群
```

GitHub 仓库:[kubernetes-sigs/kind](https://github.com/kubernetes-sigs/kind)。

## Minikube

[Minikube](https://minikube.sigs.k8s.io/) 同样由 Kubernetes SIG 维护,定位是「在本地快速搭建 Kubernetes 集群」,主要面向应用开发者和 K8s 新手。它支持 Linux、macOS、Windows,可以选择将集群部署为虚拟机、容器或裸金属进程。

最低硬件要求:2 CPU、2 GB 可用内存、20 GB 可用磁盘,以及一个容器或虚拟机管理器(Docker、QEMU、Hyper-V、KVM、VirtualBox 等)。

主要特性:

- 通过驱动(Drivers)机制支持多种后端:Docker、KVM、Hyper-V、VirtualBox 等
- 内置丰富的 addons(如 ingress、metrics-server、dashboard 等)
- 支持多容器运行时:CRI-O、containerd、docker
- 支持 LoadBalancer、网络策略、GPU 等高级特性
- 支持当前及过去 6 个 Kubernetes 小版本

安装后启动一个集群:

```bash
minikube start              # 启动本地集群
kubectl get nodes
minikube dashboard          # 打开 Web 控制台
minikube delete             # 删除集群
```

对于刚接触 Kubernetes 的开发者,Minikube 是最友好的入门工具之一。

## K3s

[K3s](https://k3s.io/) 是一个由 SUSE/Rancher 发起、现隶属于 CNCF 沙箱项目的轻量级 Kubernetes 发行版。它的设计目标是「在无需 Kubernetes 博士学位的地方」运行 K8s,典型场景包括边缘计算(Edge)、物联网(IoT)、CI 和 ARM 设备(如树莓派)。

K3s 的关键特征:

- 打包为单个小于 70 MB 的二进制文件,大幅减少依赖与安装步骤
- 默认使用 SQLite3 作为存储后端,同时支持 etcd3、MySQL、PostgreSQL、MariaDB
- 内置 containerd、Flannel、CoreDNS、Traefik、Service LB 等组件,开箱即用
- 支持 x86_64、ARMv7、ARM64 架构
- 分为 server(控制面)和 agent(工作节点)两种角色,通过 token 加入

在 Linux 上一键安装并启动 server:

```bash
curl -sfL https://get.k3s.io | sh -

# 查看 node 状态
sudo k3s kubectl get nodes
```

加入工作节点:

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://<server-ip>:6443 K3S_TOKEN=<node-token> sh -
```

GitHub 仓库:[k3s-io/k3s](https://github.com/k3s-io/k3s)。由于 K3s 资源占用极低,它也是本地开发者非常喜欢的一种方案,尤其适合在笔记本或单板机上模拟多节点集群。

## kubeadm

[kubeadm](https://kubernetes.io/zh-cn/docs/setup/production-environment/tools/kubeadm/) 是 Kubernetes 官方提供的集群引导工具,严格来说它面向的是**生产环境**,而非单纯的本地开发。但由于它的行为更贴近真实集群,很多开发者也会用它在本地虚拟机中搭建「准生产」环境。

kubeadm 只负责引导集群本身,不会安装网络插件、存储、Ingress 等附加组件,这些需要用户自行选型与配置。核心命令包括:

- `kubeadm init`——在控制面节点上初始化集群
- `kubeadm join`——将工作节点或控制面节点加入已有集群
- `kubeadm upgrade`——升级集群版本
- `kubeadm reset`——回滚 `init` / `join` 的改动
- `kubeadm token`——管理引导 token
- `kubeadm certs`——证书相关操作

典型初始化流程:

```bash
# 在控制面节点执行
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# 按提示配置 kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 安装 CNI(以 Flannel 为例)
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

在工作节点上执行 `kubeadm join` 即可加入集群。详细步骤可参考官方文档 [Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)。

## 如何选择

针对不同的需求,可以参考以下建议:

- **想最快跑起来一个集群做开发** → 用 Minikube 或 Kind
- **在 CI 中跑 Kubernetes 测试** → 优先 Kind,启动快、销毁干净
- **资源非常受限,或在树莓派/ARM 上运行** → 用 K3s
- **希望贴近真实生产环境的安装流程** → 用 kubeadm,自行配置虚拟机
- **想模拟多节点/高可用拓扑** → Kind、Minikube、K3s 均可,K3s 最贴近真实多节点体验

实际工作中,几种工具也常组合使用:例如本地用 Minikube 做日常开发,CI 用 Kind 跑自动化测试,边缘环境部署 K3s。

## 参考

- [Kubernetes Tools 官方文档(中文)](https://kubernetes.io/zh-cn/docs/tasks/tools/)
- [Kind 官方网站](https://kind.sigs.k8s.io/)
- [Kind GitHub 仓库](https://github.com/kubernetes-sigs/kind)
- [Minikube 官方文档](https://minikube.sigs.k8s.io/docs/)
- [Minikube Start 指南](https://minikube.sigs.k8s.io/docs/start/)
- [K3s 官方网站](https://k3s.io/)
- [K3s GitHub 仓库](https://github.com/k3s-io/k3s)
- [kubeadm 官方文档(中文)](https://kubernetes.io/zh-cn/docs/setup/production-environment/tools/kubeadm/)
- [Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
