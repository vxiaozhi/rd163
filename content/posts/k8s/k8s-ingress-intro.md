+++
title = "K8s Ingress 介绍"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Kubernetes 七层流量入口的资源模型与工作原理"
description = "介绍 Kubernetes Ingress 资源的作用、核心字段(rules、pathType、TLS、defaultBackend)、IngressClass 的工作机制,以及它与 Service、Ingress Controller 三者之间的关系。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "ingress", "ingress-controller", "networking", "gateway-api"]
keywords = ["k8s", "Ingress", "Ingress Controller", "IngressClass", "pathType", "Gateway API"]
toc = true
draft = false
+++

在 Kubernetes 中，把集群内服务暴露给外部访问有多种方式:`ClusterIP` 仅集群内可达,`NodePort` 在每个节点上开一个端口,`LoadBalancer` 借助云厂商的负载均衡器把流量引入。这些方式都属于四层（L4）入口，但当流量是 HTTP/HTTPS 时，我们往往希望按域名（Host）和 URL 路径（Path）做更精细的路由、统一做 TLS 终止、复用一个公网 IP 对外。`Ingress` 就是为此而生的七层（L7）资源对象。

本文梳理 Ingress 的定位、核心字段与工作原理，让后续阅读 [Ingress 控制器](../k8s-ingress-controller) 和 [Gateway API](../k8s-gateway-intro) 时有一个清晰的认知基础。

> 说明:Kubernetes 官方文档已明确写明「**Ingress API 已经被冻结**」——它不会被移除、依然遵循正式发布 API 的稳定性保证，但也不再获得新功能。新建大规模流量入口时，官方推荐评估 [Gateway API](https://gateway-api.sigs.k8s.io/) 作为继任者。本文仍然适用存量集群与小型场景。

## Ingress 是什么

Ingress 是 Kubernetes 中的一类 API 对象(API 组 `networking.k8s.io/v1`),它声明「从集群外部到集群内 Service 的 HTTP/HTTPS 路由规则」。这些规则由 Ingress 资源声明，但实际转发动作由 **Ingress 控制器（Ingress Controller）** 完成——它本身就是一个运行在集群中的反向代理程序（通常以 Pod 形式部署）。

Ingress 提供三类核心能力:

- **基于名称的虚拟主机（name-based virtual hosting）**:按请求的 `Host` 头把流量分发到不同 Service。
- **TLS 终止（SSL/TLS termination）**:在入口处卸载 HTTPS，后端 Service 接收的就是明文 HTTP。
- **负载均衡（load balancing）**:把匹配某条规则的后端流量在 Pod 间均衡。

需要注意:Ingress **只处理 HTTP/HTTPS**,不暴露任意端口或协议——需要 TCP/UDP 时仍应使用 `NodePort` 或 `LoadBalancer` 类型的 Service。

## 三者关系:Service、Ingress、Ingress Controller

理解 Ingress 的关键，是区分三个角色:

- **Service**:后端真实服务的抽象，用标签选择器聚合一组 Pod，提供稳定的 L4 访问入口。
- **Ingress**:声明式的反向代理规则（L7）,描述「Host/Path → Service:Port」的映射。
- **Ingress Controller**:真正运行反向代理（NGINX、Envoy、HAProxy、Kong 等）的程序，持续监听 API Server 上的 Ingress、Service、Endpoints、Secret 等资源变化，把规则翻译成数据面配置并执行转发。

这里有个常被忽略的细节:**仅仅 `kubectl apply` 一个 Ingress YAML 不会有任何转发效果**——必须集群里先部署了 Ingress 控制器，Ingress 才会被消费。官方文档的原文是:「为了让 Ingress 在集群中工作，你必须运行一个 Ingress 控制器。」

整体的数据路径大致是:

```
外部客户端 (HTTP/HTTPS)
      │
      ▼
Ingress Controller (NGINX / Envoy / HAProxy / ...)
      │  读取 Ingress 规则
      ▼
Ingress 资源 (Host / Path → Service)
      │
      ▼
Service (按标签选择 Pod)
      │
      ▼
Pod (业务容器)
```

## Ingress 资源结构

`Ingress` 资源自 **Kubernetes v1.19** 起在 `networking.k8s.io/v1` 进入 stable(GA),旧的 `extensions/v1beta1` 与 `networking.k8s.io/v1beta1` 在 **Kubernetes 1.22** 中已被移除。一个最小示例如下:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minimal-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
```

几个关键点:

- **`ingressClassName`**:把该 Ingress 绑定到某个具体的 IngressClass，由对应的控制器处理。
- **`rules[].host`**:可选。不写则规则匹配所有入站 HTTP 流量;写了则要求请求的 `Host` 头一致。
- **`path` 与 `pathType`**:`pathType` 在 v1 中是必填项，三种取值为 `Prefix`(按 `/` 分割的前缀匹配)、`Exact`(完全相等，大小写敏感)、`ImplementationSpecific`(交由具体控制器解释)。
- **`backend.service`**:路由的后端，由 Service 名与端口号（或名称）指定。
- **`annotations`**:Ingress 规范只覆盖最基础的字段，所有「高级」能力（重写路径、限流、金丝雀权重、超时等）都依赖各控制器自定义的注解。这也是 Ingress 长期被诟病「可移植性差」的根源——同一份注解换一个控制器就不工作了。

### TLS 配置

要做 TLS 终止，先把证书与私钥放进一个 `kubernetes.io/tls` 类型的 Secret，然后在 Ingress 里引用:

```yaml
spec:
  tls:
  - hosts:
    - example.com
    secretName: example-tls
  rules:
  - host: example.com
    http: { ... }
```

控制器会读取该 Secret 中的证书，在监听端口上呈现给客户端，完成 HTTPS 握手后再用明文 HTTP 转发到后端 Service。

### defaultBackend

当 Ingress 不写任何 `rules` 时，所有流量走 `.spec.defaultBackend`;如果有 `rules` 但没有规则命中，默认行为也由 `defaultBackend` 决定。如果不设置，则交由具体控制器自行处理（通常返回 404）。

## IngressClass:多个控制器并存时的选择

一个集群里可以同时部署多个 Ingress 控制器（例如一个 NGINX、一个 Cilium、一个云厂商 CLB 控制器）。此时需要用 **`IngressClass`** 把 Ingress 与控制器绑定。Ingress 通过 `spec.ingressClassName` 显式声明归属;某个 IngressClass 还可以打上注解:

```yaml
ingressclass.kubernetes.io/is-default-class: "true"
```

使得没有显式指定类的 Ingress 自动归属到该控制器。历史上还有 `kubernetes.io/ingress.class` 这类注解来选择控制器，但它**已废弃**,新集群应统一使用 `ingressClassName` 字段。

## Ingress 的局限与 Gateway API

Ingress 解决了「一个公网入口按域名/路径路由」的基本问题，但在长期实践中暴露出几类结构性短板:

- **只覆盖 HTTP/HTTPS**,gRPC、TCP、UDP 等协议不在规范内，只能靠控制器扩展。
- **高级路由靠注解**:流量权重、Header 匹配、跨命名空间后端、请求改写等几乎只能写到 annotation 里，无法跨实现移植。
- **角色边界模糊**:同一条 Ingress 既包含基础设施属性（域名、TLS）又包含应用规则（路径、后端）,难以对应「基础设施 / 集群运维 / 应用开发」三种角色的职责。

为此，Kubernetes SIG-Network 牵头设计了 [Gateway API](https://gateway-api.sigs.k8s.io/),以 CRD 形式提供 `GatewayClass` / `Gateway` / `HTTPRoute` 等分层资源，并在 2023 年 10 月 GA。它是面向角色、可移植、表达力更强的新一代入口规范;Ingress 不会被移除，但新场景应优先评估 Gateway API。

## 主流控制器一览

控制器选型涉及数据面、配置方式、生态等多个维度，详细对比见本博客的 [K8s Ingress 控制器](../k8s-ingress-controller) 一文。这里只做简表:

| 控制器 | 数据面 | 备注 |
|---|---|---|
| ingress-nginx | NGINX | 社区最广，但仓库已归档，新集群应避免 |
| Contour | Envoy | CNCF 孵化，支持 HTTPProxy CRD 与 Gateway API |
| Traefik | 自有（Go） | 自动服务发现，内置中间件 |
| HAProxy Ingress | HAProxy | 老牌负载均衡器，热更新 |
| Kong KIC | Kong Gateway | 插件丰富，Gateway API 一致性高 |
| APISIX Ingress | Apache APISIX | API 网关能力强 |
| Istio Ingress Gateway | Envoy | 与服务网格深度集成 |
| Cilium Ingress | eBPF | 内核态处理，高性能 |

Kubernetes 项目官方直接维护的只有 **AWS Load Balancer Controller** 与 **GCE Ingress Controller**,二者把 Ingress 翻译成云厂商的托管负载均衡器。

## 在腾讯蓝鲸（bk-bcs）中的实践

对于自建基础设施或不想绑定单一云厂商的团队，自研一个把 Ingress 翻译为云厂商 CLB/SLB API 的控制器是常见路径。腾讯蓝鲸的 `bcs-ingress-controller` 就是这类实现，它从早期的 `bcs-clb-controller` 重构而来，具有以下特点:

- 支持 **HTTP / HTTPS / TCP / UDP**,可对 CLB 监听器参数做精细化配置。
- 单条 Ingress 可同时驱动**多个跨可用区的 CLB 实例**,实现容灾。
- 同时支持 **NodePort 转发**与**直连 Pod**模式，后者通过 Service 的标签选择直接把流量打到 Pod，可按权重做蓝绿/灰度。
- 控制器拆为两层:`ingress-controller` 计算 listener 期望状态并下发增量更新,`listener-controller` 把期望状态同步到云负载均衡实例;每个 CLB 实例对应一个独立的 synchronizer goroutine。
- 引入「接收缓存 + 处理中缓存」双层缓冲，合并短时间内的突发事件，防止 Pod 扩缩容引发的 flapping 把云 API 打爆。

这种「Ingress 声明 + 控制器翻译为基础设施 API」的模式，正是 Ingress API 在云厂商场景下的典型落地。

## 小结

Ingress 是 Kubernetes 七层流量入口的标准声明：它用 YAML 描述 Host/Path 到 Service 的映射，由 Ingress Controller 真正完成转发。理解 Ingress 时要把握三点——它**只覆盖 HTTP/HTTPS**、**必须配套控制器**、**高级能力靠注解**,这三条决定了它的边界，也是 Gateway API 取而代之的根本原因。在已有 Ingress 资产需要维护、或集群规模较小的场景下，Ingress 仍然稳定可用;但新设计的入口架构，建议把目光放到 Gateway API。

## 参考

- [Ingress - Kubernetes 官方文档](https://kubernetes.io/zh-cn/docs/concepts/services-networking/ingress/)
- [Ingress Controllers - Kubernetes 官方文档](https://kubernetes.io/zh-cn/docs/concepts/services-networking/ingress-controllers/)
- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [bcs-ingress-controller design](https://github.com/TencentBlueKing/bk-bcs/blob/master/docs/features/bcs-ingress-controller/design.md)
- [bcs-ingress-controller 使用](https://github.com/TencentBlueKing/bk-bcs/blob/master/docs/features/bcs-ingress-controller/usage.md)
- [bcs CLB controller(已被 bcs-ingress-controller 代替)](https://github.com/TencentBlueKing/bk-bcs/blob/master/docs/features/bcs-clb-controller/README.md)
- [浅谈 Kubernetes Ingress 控制器的技术选型](https://cloud.tencent.com/developer/article/1592281)
- [使用 ingress + service 机制实现高可用负载均衡](https://www.cnblogs.com/kebibuluan/p/15143837.html)
- [Ingress 总览（awesome-ingress）](https://github.com/Miss-you/awesome-ingress)
