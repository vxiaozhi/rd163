+++
title = "kube-dns"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Kubernetes 早期内置 DNS 方案 kube-dns 的架构与配置"
description = "介绍 Kubernetes 早期集群 DNS 方案 kube-dns 的三容器架构、Service 与 Pod 的 DNS 记录格式、存根域与上游 nameserver 配置,以及 Pod 的 DNS 策略与继承机制。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "kube-dns", "dns", "networking"]
keywords = ["kubernetes", "kube-dns", "dns", "dnsmasq", "stubDomains", "服务发现"]
toc = true
draft = false
+++

## 简介

从 Kubernetes v1.3 版本开始，集群会通过 cluster add-on 插件管理器自动启动内置的 DNS 服务。

> 说明：自 Kubernetes v1.12 起，CoreDNS 已取代 kube-dns 成为默认的集群 DNS 插件。本文介绍的是早期 kube-dns 方案，新集群建议使用 [CoreDNS](../k8s-dns-coredns)。

kube-dns 的 Pod 中包含 3 个容器:

- **kubedns**:kubedns 进程监视 Kubernetes master 上 Service 和 Endpoint 的变化，并在内存中维护查找结构以响应 DNS 请求。
- **dnsmasq**:dnsmasq 容器提供 DNS 缓存，用于提升解析性能。
- **sidecar**:sidecar 容器对 dnsmasq 和 kubedns 同时执行健康检查，对外暴露统一的健康检查端点（监听 10054 端口）。

DNS Pod 拥有静态 IP，并以 Kubernetes Service 的形式暴露出来。该静态 IP 分配后，kubelet 会通过 `--cluster-dns=<dns-service-ip>` 标志将其传递给每个容器。

DNS 名称还需要一个集群域名，可在 kubelet 中通过 `--cluster-domain=<default-local-domain>` 标志配置。

kube-dns 基于 SkyDNS 库实现，支持正向查找（A 记录）、服务查找（SRV 记录）和反向 IP 地址查找（PTR 记录）。

## kube-dns 支持的 DNS 格式

kube-dns 会为 Service 和 Pod 分别生成不同格式的 DNS 记录。

### Service

- **A 记录**:生成形如 `my-svc.my-namespace.svc.cluster.local` 的域名，解析为 IP 地址，分两种情况:
  - 普通 Service:解析为 ClusterIP。
  - Headless Service:解析为后端 Pod 的 IP 列表。
- **SRV 记录**:为带名称的端口（普通 Service 或 Headless Service）生成形如 `_my-port-name._my-port-protocol.my-svc.my-namespace.svc.cluster.local` 的域名。

### Pod

- **A 记录**:生成形如 `pod-ip.my-namespace.pod.cluster.local` 的域名，其中 Pod IP 中的点(`.`)需替换为短横线(`-`),例如 `172-17-0-3.default.pod.cluster.local`。

## Pod 的 hostname 与 subdomain

可以在 Pod 中指定 `hostname` 和 `subdomain`,从而得到形如 `hostname.custom-subdomain.default.svc.cluster.local` 的 FQDN。

例如:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  labels:
    name: busybox
spec:
  hostname: busybox-1
  subdomain: busybox-subdomain
  containers:
  - name: busybox
    image: busybox
    command:
    - sleep
    - "3600"
```

该 Pod 的 FQDN 是 `busybox-1.busybox-subdomain.default.svc.cluster.local`。

> 注意：要让上述 Pod 的 A 记录可被解析，还需存在一个同名的 Headless Service(`busybox-subdomain`),其 selector 选中对应 Pod。否则只会得到 Service 的 A 记录，而非 Pod 级别的 A 记录。

补充：这样做的意义在于，可以将相同类型或相同业务的 Pod 按子域名进行划分，便于服务发现和分组管理。

## 继承节点的 DNS

运行 Pod 时，kubelet 会将预先配置的集群 DNS 服务器写入 Pod 的 DNS 配置，并搜索节点自身的 DNS 设置路径。如果节点能够解析更大环境中特定的 DNS 名称，那么 Pod 通常也能够解析。

若要为 Pod 设置不同的 DNS 配置，可以给 kubelet 指定 `--resolv-conf` 标志:

- 将该值设置为 `""`,意味着 Pod 不继承节点 DNS。
- 将其设置为有效的文件路径，意味着 kubelet 将使用该文件而不是 `/etc/resolv.conf` 用于 DNS 继承。

## 配置存根域和上游 DNS 服务器

通过为 kube-dns(`kube-system:kube-dns`)提供一个 ConfigMap，集群管理员可以指定自定义的存根域（stub domain）和上游 nameserver。

例如，下面的 ConfigMap 建立了一个 DNS 配置，其中包含一个单独的存根域和两个上游 nameserver:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-dns
  namespace: kube-system
data:
  stubDomains: |
    {"acme.local": ["1.2.3.4"]}
  upstreamNameservers: |
    ["8.8.8.8", "8.8.4.4"]
```

上面配置中，带有 `.acme.local` 后缀的 DNS 请求会被转发到地址为 `1.2.3.4` 的 DNS 服务器;其它域名查询则转发给 `8.8.8.8` 和 `8.8.4.4` 这两个上游 DNS 服务器。

> 注意:ConfigMap 中的 JSON 字符串必须使用 ASCII 双引号 `"`(标准 JSON),不能使用中文全角引号 `“”`。

### Pod 中 DNS 策略配置

Pod 的 `dnsPolicy` 取值如下:

- `Default`:Pod 继承所在节点的名称解析配置。
- `None`:忽略 Kubernetes 环境的 DNS 设置，所有 DNS 配置必须由 `dnsConfig` 字段显式提供。
- `ClusterFirst`:与集群后缀不匹配的 DNS 查询会被转发到上游 nameserver;这是未显式指定时的默认策略。
- `ClusterFirstWithHostNet`:对于以 `hostNetwork: true` 方式运行的 Pod，应显式设置该策略，否则会回退为 `Default` 行为。

如果配置了存根域和上游 DNS 服务器（如前面示例）,DNS 查询将按下面的流程进行路由:

1. 查询首先被发送到 kube-dns 中的 DNS 缓存层（dnsmasq）。
2. 缓存层根据请求后缀判断转发目标:
   - 具有集群后缀的名字(例如 `.cluster.local`):请求被发送到 kube-dns。
   - 具有存根域后缀的名字(例如 `.acme.local`):请求被发送到配置的自定义 DNS 解析器(例如监听在 `1.2.3.4` 的服务器)。
   - 不匹配任何已配置后缀的名字(例如 `widget.com`):请求被转发到上游 DNS(例如 Google 公共 DNS 服务器 `8.8.8.8` 和 `8.8.4.4`)。

![kube-dns 查询策略](/imgs/k8s-dns-poilicy.png)

## ConfigMap 选项

kube-dns(`kube-system:kube-dns`)的 ConfigMap 支持以下选项:

- `stubDomains`
- `upstreamNameservers`

### 示例：存根域

在这个例子中，用户已有一套 Consul DNS 服务发现系统，希望与 kube-dns 集成。Consul 域名服务器地址为 `10.150.0.1`,所有 Consul 名称都带有 `.consul.local` 后缀。要配置 Kubernetes，集群管理员只需创建如下的 ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-dns
  namespace: kube-system
data:
  stubDomains: |
    {"consul.local": ["10.150.0.1"]}
```

注意，集群管理员不希望覆盖节点的上游 nameserver，因此没有指定可选的 `upstreamNameservers` 字段。

### 示例：上游 nameserver

在这个示例中，集群管理员希望将所有非集群 DNS 查询显式地转发到自己的 nameserver `172.16.0.1`。实现方式很简单：只需创建一个 ConfigMap，在 `upstreamNameservers` 字段中指定该 nameserver 即可:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-dns
  namespace: kube-system
data:
  upstreamNameservers: |
    ["172.16.0.1"]
```

## 参考

- [安装配置 kube-dns](https://hezhiqiang.gitbook.io/kubernetes-handbook/zui-jia-shi-jian/service-discovery-and-loadbalancing/dns-installation/configuring-dns)
- [Kubernetes DNS GitHub 仓库](https://github.com/kubernetes/dns)
- [DNS 学习笔记 - SRV 记录](https://skyao.io/learning-dns/dns/record/srv.html)
- [Kubernetes 官方文档:DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Kubernetes 官方文档:Customizing DNS Service(CoreDNS)](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/)