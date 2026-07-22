+++
title = "K8s Ingress 控制器"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "在 Ingress 资源与真实数据面之间承上启下的控制器"
description = "介绍 Kubernetes Ingress 控制器的作用、工作原理,以及主流开源实现(ingress-nginx、Contour、Traefik、HAProxy、Kong、Istio、Cilium 等)的多维度对比与选型要点。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "ingress", "ingress-controller", "gateway-api"]
keywords = ["k8s", "ingress", "ingress controller", "gateway api", "nginx ingress", "服务网格"]
toc = true
draft = false
+++

Kubernetes 的 `Ingress` 资源只声明了「外部 HTTP/HTTPS 流量如何路由到集群内的 Service」,它本身不会产生任何转发行为。真正监听 Ingress 变化、把规则翻译成数据面配置、并对外接收流量的程序,就是 **Ingress 控制器(Ingress Controller)**。本文梳理它的工作原理与主流开源实现,并提供一个多维度对比与选型参考。

> 注意:Kubernetes 官方已宣布 **Ingress API 进入冻结状态(frozen)**,新功能不再向 Ingress 添加,推荐使用 [Gateway API](https://gateway-api.sigs.k8s.io/) 作为继任者。Ingress 资源本身稳定可用、不会被移除,新建大规模流量入口建议优先评估 Gateway API 实现。

## 工作原理

Ingress 控制器本身以 Pod 形式部署在集群中(通常配合 `type: LoadBalancer` 的 Service 或 NodePort 把流量引入),其工作流可概括为四步:

1. **监听 API Server**:通过 informer 监听 `networking.k8s.io/v1` 的 Ingress、IngressClass、Service、Endpoints、Secret 等资源变化。
2. **规则翻译**:把 Ingress 规则、注解(annotations)、ConfigMap 配置翻译成数据面(NGINX、Envoy、HAProxy、Kong 等)能理解的配置,例如 `nginx.conf` 或 xDS。
3. **热加载**:对数据面执行 reload 或动态下发配置。对上游端点(Endpoints)的变化,多数实现通过 Lua、xDS stream 等机制做到不中断地更新,避免每次 Pod 扩缩容都触发完整 reload。
4. **流量转发**:外部请求到达控制器后,按 Host、Path、Header 等规则匹配并转发到对应 Service 的 Pod。

三者关系如下:

- **Service**:后端真实服务的抽象,一组 Pod 的稳定访问入口(L4)。
- **Ingress**:声明式反向代理规则(L7),描述「Host/Path → Service」的映射。
- **Ingress Controller**:运行反向代理程序,持续消费 Ingress 并生成实际的转发规则。

一个最小的 Ingress 示例(稳定版 `networking.k8s.io/v1`,自 Kubernetes 1.19 起 GA):

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

注意 `pathType` 在 v1 中是必填项,可取值 `Prefix`、`Exact`、`ImplementationSpecific`;旧的 `extensions/v1beta1` 与 `networking.k8.io/v1beta1` 已在 Kubernetes 1.22 中移除。

## Ingress 与 IngressClass

当一个集群里部署了多个控制器时,需要用 **IngressClass** 把 Ingress 与控制器绑定起来。Ingress 通过 `spec.ingressClassName` 字段声明自己归谁管;某个 IngressClass 可以打上注解 `ingressclass.kubernetes.io/is-default-class: "true"`,使没有显式指定类的 Ingress 自动归属到该控制器。

## 主流开源实现

Kubernetes 官方只直接维护两个面向云厂商的控制器:**AWS Load Balancer Controller** 与 **GCE Ingress Controller**,它们把 Ingress 翻译成云厂商的托管负载均衡器。社区里更常用的是部署在集群内的「反向代理 + 控制器」组合,下面列出几个代表性项目。

### ingress-nginx(NGINX Ingress Controller)

- **仓库**:[kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx)
- **数据面**:NGINX
- **特点**:社区最广泛使用的实现,围绕 Ingress 资源构建,用 ConfigMap 存全局配置、用注解覆盖单条规则;支持 TLS 终止、金丝雀发布、ModSecurity WAF、Prometheus 监控等。
- **重要提示**:该仓库已于 **2026 年 3 月归档**。在此之前进入「best-effort」维护,归档后不再发布新版本、不再修复 bug 与安全问题。新建集群不应再采用,官方建议改用 Gateway API 实现。

> `ingress-nginx`(Kubernetes 社区维护)与 `nginxinc/kubernetes-ingress`(NGINX 公司维护)是两个不同的项目,配置注解与 CRD 不互通,迁移时需注意区分。

### Contour

- **数据面**:Envoy
- **特点**:作为 Envoy 的控制面,部署为 Deployment 或 DaemonSet,可对 Envoy 做动态配置更新而无需重启;提供 `HTTPProxy` CRD 扩展路由能力,并支持 TLS 证书委派。属于 **CNCF 孵化项目**。

### Traefik

- **数据面**:自有(Go 编写)
- **特点**:**The Cloud Native Application Proxy**,通过服务发现自动生成路由配置;内置中间件(负载均衡、限流、熔断、认证、ACME 自动证书等);同时支持 Ingress、Ingress-NGINX 注解与 Gateway API,Traefik 3.x 将 Gateway API 作为主推能力之一。

### HAProxy Ingress

- **仓库**:[jcmoraisjr/haproxy-ingress](https://github.com/jcmoraisjr/haproxy-ingress)
- **数据面**:HAProxy
- **特点**:用 Go 编写控制器,把 Ingress/注解/ConfigMap 翻译为 HAProxy 配置,变更即时生效(无需重启);对性能敏感、习惯 HAProxy 配置语法的团队较友好。

### Kong Ingress Controller(KIC)

- **数据面**:Kong Gateway
- **特点**:把 Ingress、HTTPRoute 等 Kubernetes 资源翻译成 Kong 配置,从而获得 Kong 生态的插件能力(认证、限流、可观测性等)。KIC 是 Gateway API 的重要推动者之一,核心一致性测试 100% 通过。

### Apache APISIX Ingress Controller

- **数据面**:Apache APISIX
- **特点**:既支持原生 Ingress,也支持 Gateway API 与 APISIX 自带的声明式 CRD;可走 etcd 模式或 standalone(无 etcd)模式,适合需要 API 网关能力(路由、认证、限流、负载均衡)的场景。

### Istio Ingress Gateway

- **数据面**:Envoy(sidecar / ingress gateway)
- **特点**:服务网格方案下的入口,既支持 Istio 自有的 `Gateway` CRD,也兼容 Kubernetes Ingress 与 Gateway API。强项在于与网格内部 mTLS、可观测性、流量治理策略统一,适合已经或计划采用 Istio 的团队。

### Cilium Ingress Controller

- **数据面**:eBPF(Cilium)
- **特点**:基于 eBPF 在内核态处理流量,绕过部分 kube-proxy/iptables 路径,性能与可观测性较优,适合以 Cilium 为 CNI 的集群。

此外,Envoy Gateway(envoyproxy/gateway)是较新的实现,以 Envoy 为数据面、原生对齐 Gateway API,常作为从 Ingress 迁移到 Gateway API 的目标之一。

## 多维度对比

| 控制器 | 数据面 | 配置方式 | API 形态 | 生态/亮点 |
|---|---|---|---|---|
| ingress-nginx | NGINX | ConfigMap + 注解 | Ingress | 社区最广,但已归档 |
| nginxinc/kubernetes-ingress | NGINX | ConfigMap + 注解 + CRD | Ingress / VirtualServer | NGINX 公司维护 |
| Contour | Envoy | HTTPProxy CRD / Ingress | Ingress / Gateway API | CNCF 孵化,动态配置 |
| Traefik | 自有 | CRD / Ingress / 注解 | Ingress / Gateway API | 自动服务发现,内置中间件 |
| HAProxy Ingress | HAProxy | ConfigMap + 注解 | Ingress | 老牌负载均衡器,热更新 |
| Kong KIC | Kong Gateway | CRD + 注解 | Ingress / Gateway API | 插件丰富,Gateway API 一致性高 |
| APISIX Ingress | APISIX | CRD / Ingress | Ingress / Gateway API | API 网关能力强 |
| Istio Ingress Gateway | Envoy | Istio CRD / Gateway API | Ingress / Gateway / Gateway API | 与服务网格深度集成 |
| Cilium Ingress | eBPF | Cilium CRD | Ingress | eBPF 高性能 |

选型时可从以下角度权衡:

- **功能定位**:仅做七层入口(Ingress),还是需要 API 网关能力(认证、限流、灰度、可观测性)?
- **数据面**:对 NGINX/HAProxy 老牌配置的熟悉度,还是倾向 Envoy/eBPF 的现代化能力?
- **API 演进**:是否同步规划 Gateway API?优先选择已经良好支持 Gateway API 的实现(Contour、Kong、Traefik、Istio、Envoy Gateway 等)。
- **运维成本**:配置热更新、监控、证书自动化、多租户安全隔离的成熟度。
- **社区活跃度**:ingress-nginx 已归档,新项目应避免将其作为首选。

## 参考

- [Ingress Controllers - Kubernetes 官方文档](https://kubernetes.io/zh-cn/docs/concepts/services-networking/ingress-controllers/)
- [Ingress - Kubernetes 官方文档](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx)(已归档)
- [ingress-nginx 官方文档](https://kubernetes.github.io/ingress-nginx/)
- [Project Contour](https://projectcontour.io/)
- [Traefik Proxy](https://traefik.io/traefik/)
- [HAProxy Ingress Controller](https://github.com/jcmoraisjr/haproxy-ingress)
- [Kong Ingress Controller](https://developer.konghq.com/kubernetes-ingress-controller/)
- [Apache APISIX Ingress Controller](https://apisix.apache.org/docs/ingress-controller/)
- [Istio Ingress](https://istio.io/latest/docs/tasks/traffic-management/ingress/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)
- [K8s 工程师必懂的 10 种 Ingress 控制器(中文,原 kubernetes.org.cn 旧文)](https://www.kubernetes.org.cn/5948.html)
