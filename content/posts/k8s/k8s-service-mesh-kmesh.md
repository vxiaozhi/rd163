+++
title = "Kmesh：基于 eBPF 的内核原生服务网格数据平面"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "用 eBPF 取代 Sidecar 的高性能数据平面"
description = "Kmesh 是基于 eBPF 与可编程内核实现的服务网格数据平面，通过将 L4 流量治理下沉到内核，显著降低 Sidecar 架构带来的延迟与资源开销。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "service-mesh", "kmesh", "ebpf", "istio"]
keywords = ["Kmesh", "eBPF", "服务网格", "Service Mesh", "Istio", "Sidecar"]
toc = true
draft = false
+++

## 背景

像 Istio 这样的服务网格（Service Mesh）已经成为管理复杂微服务架构的核心手段，提供流量管理、安全（mTLS）和可观测性等能力。Sidecar 模型——在每个业务 Pod 旁注入一个 Envoy 代理——是过去几年最主流的数据平面实现。它功能完备、对应用透明，但在性能与资源开销上代价不菲。

传统 Sidecar 架构的局限性主要体现在两点：

- **延迟开销**：每次服务调用都要经过本地 Sidecar 代理的两次上下文切换与协议栈穿越，Istio 官方与第三方测试都表明，即使没有实际流量分发，Sidecar 仍会引入约 2~3ms 的固有延迟，并随着连接数上升而进一步增大。对于延迟敏感型应用，这种常数级开销难以接受。
- **资源消耗**：每个 Pod 都要常驻一个 Sidecar 进程，在大规模集群（数千 Pod）中累积的 CPU 与内存开销相当可观。有估算显示，一个 500 Pod 的集群，仅 Sidecar 自身就可能消耗 25~50GB 内存，显著降低部署密度、抬升运营成本。

为了突破 Sidecar 模型的瓶颈，社区出现了两条无 Sidecar（sidecarless）演进路线：一条是 Istio Ambient Mesh，用节点级的 ztunnel（L4）与 waypoint（L7）替代 Sidecar；另一条则是 [Kmesh](https://github.com/kmesh-net/kmesh)，它选择把流量治理直接下沉到操作系统内核，利用 eBPF（Extended Berkeley Packet Filter，扩展伯克利数据包过滤器）与可编程内核技术，定义了一种全新的服务网格数据平面。

## Kmesh 是什么

Kmesh 是一个基于 eBPF 与可编程内核的高性能、低开销服务网格数据平面，由华为开源贡献，于 **2024 年 10 月 17 日**被 CNCF（Cloud Native Computing Foundation）接纳为 Sandbox（沙箱）级项目，2025 年 2 月正式发布 v1.0.0。

它的核心思想可以一句话概括：**把 L4 与简单 L7 的流量治理从用户态代理搬到内核态，让数据包在内核里就被治理完成，不再绕经任何用户态 Proxy。** 这样既能保留服务网格的治理能力，又能消除 Sidecar 的常数级开销。

Kmesh 兼容 xDS 协议，可以复用 Istio 的控制面（istiod）作为配置下发源，同时支持 Istio API 与 Kubernetes Gateway API，对上层保持平滑兼容。

## 架构与核心组件

Kmesh 以 DaemonSet 形式部署在每个节点上，主要由三个部分组成：

- **kmesh-daemon**：节点级管理组件，负责 eBPF 程序的生命周期管理、通过 xDS 订阅控制面（如 istiod）下发的服务发现与路由配置，并将配置写入 eBPF map；同时承担可观测性指标的上报。
- **eBPF 编排层**：在内核中完成流量拦截、L4 负载均衡、mTLS 加解密、监控以及简单的 L7 动态路由。这是 Kmesh 性能优势的关键。
- **Waypoint Proxy（可选）**：用于处理复杂的 L7 流量治理（如重试、Header 改写、细粒度路由），可按 namespace 或按 service 部署。仅在 Dual-Engine 模式下启用。

### eBPF 关键机制：sockmap 与 sockops

Kmesh 加速数据平面的关键技术之一是 Linux 内核的 sockmap 机制，包含两部分能力：

1. **sockops**：在 TCP 连接建立时，按四元组识别 socket 并存入 sockmap（一种 BPF map）。
2. **socket redirection（sk_msg）**：在数据发送阶段按 key 查找 sockmap，若命中则将数据**直接转发到目标 socket**，完全绕过内核协议栈的后续流程。

为了处理 NAT 场景下正向/反向连接的映射关系，Kmesh 还借助 `bpf_get_sockopt` 主动获取被 iptables 改写后的地址，维护一张辅助 map，保证双向流量都能被正确重定向。这就是 Kmesh "forged connection（伪造连接）"机制的底层实现——在内核里完成治理，无需任何用户态代理介入。

## 两种工作模式

Kmesh 提供两种渐进式工作模式，便于用户按需演进：

### Kernel-Native 模式（内核原生）

将 L4 与简单 L7（HTTP）治理全部下沉到内核，数据路径上**没有任何用户态代理**，是性能最高的模式。适合只需要基础流量管理、mTLS 和可观测性的场景。注意在该模式下，DNS 等能力与内核原生逻辑深度耦合，无法与 Dual-Engine 模式混用。

### Dual-Engine 模式（双引擎）

L4 治理由内核中的 eBPF 完成，复杂 L7 治理则由 Waypoint Proxy 在用户态完成。它提供了一条从"无网格 → 安全 L4 → 完整 L7"的渐进式落地路径：

- 第一阶段：只开启 eBPF L4，获得 mTLS、负载均衡、可观测性；
- 第二阶段：按需为某些 namespace 或 service 部署 waypoint，获得完整的 L7 治理能力。

## 与 Sidecar / Ambient 的对比

| 维度 | Istio Sidecar | Istio Ambient | Kmesh |
|------|---------------|---------------|-------|
| 数据平面位置 | Pod 内用户态代理 | 节点级用户态代理（ztunnel + waypoint） | 节点级内核态（eBPF） |
| L7 网络跳数 | 2 跳 | 最多 3 跳 | 仅 1 跳（需 waypoint 时） |
| 资源开销 | 高（每 Pod 一个代理） | 中（共享节点代理） | 低（数据面开销降低约 70%） |
| 转发延迟 | 基线 | 较 Sidecar 有改善 | 较 Sidecar 降低约 60% |
| 工作负载启动 | 受 Sidecar 启动拖累 | 改善 | 启动时间改善约 40% |

> 上述性能数字来自 Kmesh 官方博客与社区测试，实际收益取决于集群规模、流量模型与工作负载特征，建议在自己的环境中独立验证。

简言之：Ambient 解决了"每个 Pod 一个 Sidecar"的问题，但代理仍在用户态；Kmesh 则把代理彻底搬进内核，进一步消除了用户态拦截的开销与跳数。

## 快速上手

Kmesh 复用 Istio 的控制面，因此需要先准备一个开启 Ambient 的 istiod，再安装 Kmesh 数据平面。

### 环境要求

| 组件 | 版本要求 |
|------|----------|
| Kubernetes | 1.26+（官方测试覆盖 1.26~1.29） |
| Istio | 1.22+，需开启 Ambient 模式 |
| Helm | 3.0+ |
| Linux 内核 | 5.10+（eBPF 能力要求） |
| 节点内存 | 4GB+ |
| 节点 CPU | 2 核+ |

### 安装控制面（Istio Ambient）

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

kubectl create namespace istio-system
helm install istio-base istio/base -n istio-system

# 关键：必须开启 ambient，否则 Kmesh 无法与 istiod 建立 gRPC 连接
helm install istiod istio/istiod -n istio-system --version 1.24.0 \
  --set pilot.env.PILOT_ENABLE_AMBIENT=true
```

同时安装 Gateway API CRDs（Ambient/Kmesh 都依赖）：

```bash
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd/experimental?ref=444631bfe06f3bcca5d0eadf1857eac1d369421d" | kubectl apply -f -; }
```

### 安装 Kmesh 数据平面

推荐使用 OCI Chart：

```bash
helm install kmesh oci://ghcr.io/kmesh-net/kmesh-helm \
  -n kmesh-system --create-namespace
```

### 接入业务与验证

给 namespace 打上标签，让 Kmesh 接管该命名空间的数据平面：

```bash
kubectl label namespace default istio.io/dataplane-mode=Kmesh

kubectl apply -f ./samples/httpbin/httpbin.yaml
kubectl apply -f ./samples/sleep/sleep.yaml
```

通过 Pod 注解确认已被 Kmesh 接管：

```bash
kubectl describe po <pod-name> | grep Annotations
# 期望看到：kmesh.net/redirection: enabled
```

测试连通性：

```bash
kubectl exec <sleep-pod> -c sleep -- curl -IsS "http://httpbin:8000/status/200"
# 期望返回：HTTP/1.1 200 OK
```

### 切换工作模式

Kmesh 默认为 Dual-Engine 模式，可通过修改启动参数切换到 Kernel-Native 模式：

```bash
sed -i 's/--mode=dual-engine/--mode=kernel-native/' deploy/charts/kmesh-helm/values.yaml
```

## 适用场景与局限

**适合**：

- 对延迟敏感、Sidecar 开销占比偏高的在线服务；
- Pod 密度高、Sidecar 资源浪费严重的大规模集群；
- 已经在使用 Istio 控制面、希望换装数据平面的团队。

**需要注意的局限**：

- 强依赖较新的 Linux 内核（5.10+），部分老旧节点或受限内核（如某些托管 K8s）可能不支持；
- Kernel-Native 模式的 L7 能力较有限，复杂 L7 治理仍依赖 waypoint；
- 项目处于 CNCF Sandbox 阶段，生态与生产案例仍在积累，落地前建议充分评估稳定性。

## 参考

- [Kmesh 官方仓库（GitHub）](https://github.com/kmesh-net/kmesh)
- [Kmesh 官方文档与快速开始](https://kmesh.net/docs/setup/quick-start/)
- [Kmesh | CNCF 项目页](https://www.cncf.io/projects/kmesh/)
- [Kmesh v1.0 正式发布（CNCF Blog）](https://www.cncf.io/blog/2025/02/19/kmesh-v1-0-officially-released/)
- [Introducing Kmesh：用内核原生技术革新服务网格数据平面（Jimmy Song）](https://jimmysong.io/blog/introducing-kmesh-kernel-native-service-mesh/)
- [Accelerating ServiceMesh Data Plane Based on Sockmap（Kmesh Blog）](https://kmesh.net/blog/sockmap-itroduce/)
- [Kmesh Joins CNCF Cloud Native Landscape](https://kmesh.net/blog/kmesh%20has%20been%20included%20in%20cncf%20cloud%20native%20landscape%20in%20the%20service%20mesh%20category./)
