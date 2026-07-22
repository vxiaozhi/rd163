+++
title = "K8s 本地安装"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "minikube、Kind、K3s、kubeadm 四种本地集群安装速查"
description = "面向本地开发与学习场景,介绍 Kubernetes 的四种主流本地安装方案及其核心命令,涵盖 minikube 多节点、Kind 配置文件、K3s 单二进制与 kubeadm 引导流程。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "kubernetes", "minikube", "kind", "k3s", "kubeadm", "本地部署"]
keywords = ["k8s 本地安装", "minikube", "kind", "k3s", "kubeadm", "本地 Kubernetes"]
toc = true
draft = false
+++

在学习和开发 Kubernetes(K8s)应用时，先在本地计算机上搭建一个集群用于验证，通常是最高效的方式。Kubernetes 官方文档专门将这类场景归为「学习环境（Learning Environment）」,与「生产环境（Production Environment）」相对。本文聚焦「安装」这一动作，给出四种主流本地安装方案的速查命令与关键点。

## 前置准备：安装 kubectl

不论采用哪种方案，操作集群都需要 `kubectl`——Kubernetes 官方命令行工具。先把它装好:

```bash
# Linux (x86-64) 下载最新稳定版
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# macOS
brew install kubectl
```

安装完成后，执行 `kubectl version --client` 验证。各操作系统详细步骤可参考官方文档[安装和设置 kubectl](https://kubernetes.io/zh-cn/docs/tasks/tools/install-kubectl/)。

## 方案对比

四种方案各有侧重，先用一张表概览，下文再逐一展开:

| 方案 | 运行方式 | 主要场景 | 启动速度 | 资源开销 |
| --- | --- | --- | --- | --- |
| **minikube** | 在 VM 或容器中运行单/多节点集群 | 学习、应用开发 | 中 | 中 |
| **Kind** | 在 Docker/Podman 容器中运行 K8s 节点 | CI、本地开发、测试 K8s 本身 | 快 | 低 |
| **K3s** | 单一二进制文件，轻量化发行版 | 边缘、IoT、CI、资源受限环境 | 快 | 极低 |
| **kubeadm** | 在裸机或虚拟机上引导集群 | 生产级集群引导，也用于本地「准生产」 | 慢 | 高 |

## 1. minikube

[minikube](https://github.com/kubernetes/minikube) 由 Kubernetes SIG 维护，定位是「在本地快速搭建 Kubernetes 集群」,主要面向应用开发者和 K8s 新手。它支持 Linux、macOS、Windows，可把集群部署为虚拟机、容器或裸金属进程。

最低硬件要求:2 CPU、2 GB 可用内存、20 GB 可用磁盘，以及一个容器或虚拟机管理器（Docker、QEMU、Hyper-V、KVM、VirtualBox 等）。安装:

```bash
# Linux (x86-64)
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# macOS
brew install minikube
```

启动一个默认的单节点集群:

```bash
minikube start              # 启动本地集群
kubectl get nodes
minikube dashboard          # 打开 Web 控制台
minikube delete             # 删除集群
```

### 多节点集群

minikube 从 1.10.1 版本开始原生支持多节点集群（Multi-node cluster）,通过 `--nodes` 参数指定节点数。例如启动一个 2 节点集群（1 个控制面 + 1 个工作节点）:

```bash
minikube start --nodes 2 -p multinode-demo
kubectl get nodes
minikube status -p multinode-demo
```

需要注意：默认的 host-path 存储卷 provisioner **不支持**多节点集群。若在多节点集群中使用 PersistentVolume，应改用 CSI Hostpath Driver 等插件。更多内容参见官方教程 [Multi-node Clusters](https://minikube.sigs.k8s.io/docs/tutorials/multi_node/)。

## 2. Kind

[Kind](https://github.com/kubernetes-sigs/kind) 全称 **Kubernetes IN Docker**,同样由 Kubernetes SIG 维护。它的核心思路是把每个 Kubernetes「节点」放进一个 Docker(或 Podman、nerdctl)容器中运行，而非虚拟机;每个节点内部再通过 `kubeadm` 完成引导。Kind 最初是为了测试 Kubernetes 自身而设计，现已广泛用于本地开发和 CI 流水线，是一个 **CNCF 认证的、符合一致性标准的 Kubernetes 安装器**。

前置依赖:Docker 或 Podman。安装:

```bash
# 通过 Homebrew(macOS/Linux)
brew install kind

# 或直接下载二进制
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

快速创建并销毁集群:

```bash
kind create cluster                          # 创建默认集群(名为 kind)
kubectl cluster-info --context kind-kind
kind delete cluster                          # 销毁集群
```

### 用配置文件定义多节点拓扑

Kind 通过 YAML 配置文件描述节点拓扑。以下示例创建一个 1 控制面 + 2 工作节点的集群:

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
```

应用配置:

```bash
kind create cluster --config kind-config.yaml
```

若要在集群中运行本地构建的镜像，而无需推送至远程仓库，可使用 `kind load docker-image <image>` 直接把本地镜像载入节点。更多用法见 [Kind Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/)。

## 3. K3s

[K3s](https://github.com/k3s-io/k3s) 是由 SUSE/Rancher 发起、现隶属于 CNCF 沙箱项目的轻量级 Kubernetes 发行版。设计目标是「在无需 Kubernetes 博士学位的地方」运行 K8s，典型场景包括边缘计算（Edge）、物联网（IoT）、CI 和 ARM 设备（如树莓派）。关键特征:

- 打包为单个小于 70 MB 的二进制文件，大幅减少依赖与安装步骤
- 默认使用 SQLite3 作为存储后端，同时支持 etcd3、MySQL、PostgreSQL
- 内置 containerd、Flannel、CoreDNS、Traefik、Service LB 等组件，开箱即用
- 支持 x86_64、ARMv7、ARM64 架构，对 ARM 高度优化
- 分为 server(控制面)和 agent(工作节点)两种角色，通过 token 加入

在 Linux 上一键安装并启动 server:

```bash
curl -sfL https://get.k3s.io | sh -

# 查看 node 状态(K3s 自带 kubectl 子命令)
sudo k3s kubectl get nodes
```

加入工作节点(server 节点的 node-token 存放在 `/var/lib/rancher/k3s/server/node-token`):

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://<server-ip>:6443 K3S_TOKEN=<node-token> sh -
```

由于资源占用极低，K3s 非常适合在笔记本或单板机上模拟多节点集群;若希望以容器方式管理 K3s，可进一步使用 [k3d](https://github.com/k3d-io/k3d)(K3s in Docker)。

## 4. Kubeadm

[kubeadm](https://github.com/kubernetes/kubeadm) 是 Kubernetes 官方提供的集群引导（bootstrapping）工具，严格来说它面向**生产环境**,而非单纯的本地开发。但由于它的行为贴近真实集群，很多开发者也会用它在本地虚拟机中搭建「准生产」环境。

kubeadm 只负责引导集群本身，不会安装网络插件、存储、Ingress 等附加组件，这些需要用户自行选型与配置。核心命令包括:

| 命令 | 作用 |
| --- | --- |
| `kubeadm init` | 在控制面节点上初始化集群 |
| `kubeadm join` | 将工作节点或控制面节点加入已有集群 |
| `kubeadm upgrade` | 升级集群版本 |
| `kubeadm reset` | 回滚 `init` / `join` 的改动 |
| `kubeadm token` | 管理引导 token |
| `kubeadm certs` | 证书相关操作（续期、检查过期等） |

典型初始化流程（在控制面节点执行）:

```bash
# 安装 kubelet / kubeadm / kubectl(以 Debian/Ubuntu 为例,参考 pkgs.k8s.io 仓库)
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# 初始化控制面
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# 按提示配置 kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 安装 CNI(以 Flannel 为例)
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

初始化成功后，终端会打印一条 `kubeadm join ...` 命令，复制到工作节点执行即可加入集群。详细步骤可参考官方文档 [Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)。

## 如何选择

针对不同需求，可以参考以下建议:

- **想最快跑起来一个集群做开发** → 用 minikube 或 Kind
- **在 CI 中跑 Kubernetes 测试** → 优先 Kind，启动快、销毁干净
- **资源非常受限，或在树莓派/ARM 上运行** → 用 K3s
- **希望贴近真实生产环境的安装流程** → 用 kubeadm，自行配置虚拟机
- **想模拟多节点/高可用拓扑** → 四者均支持;minikube `--nodes`、Kind 配置文件、K3s server/agent、kubeadm `join` 各有侧重

实际工作中，几种工具也常组合使用：例如本地用 minikube 做日常开发，CI 用 Kind 跑自动化测试，边缘环境部署 K3s，生产环境基于 kubeadm 引导。

## 参考

- [安装工具（Kubernetes 官方中文文档）](https://kubernetes.io/zh-cn/docs/tasks/tools/)
- [minikube GitHub 仓库](https://github.com/kubernetes/minikube)
- [minikube 多节点集群教程](https://minikube.sigs.k8s.io/docs/tutorials/multi_node/)
- [Kind GitHub 仓库](https://github.com/kubernetes-sigs/kind)
- [Kind Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [K3s GitHub 仓库](https://github.com/k3s-io/k3s)
- [K3s 官方网站](https://k3s.io/)
- [kubeadm GitHub 仓库](https://github.com/kubernetes/kubeadm)
- [Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
