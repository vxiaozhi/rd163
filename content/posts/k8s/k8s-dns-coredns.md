+++
title = "域名解析(DNS) -- CoreDNS"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Kubernetes 默认集群 DNS 的工作原理与实战配置"
description = "介绍 Kubernetes 默认 DNS 服务 CoreDNS 的架构、Corefile 配置、插件机制、服务发现规则,以及 NodeLocal DNSCache 等性能优化方案。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "coredns", "dns", "networking"]
keywords = ["kubernetes", "coredns", "dns", "corefile", "nodelocaldns", "服务发现"]
toc = true
draft = false
+++

在 Kubernetes 中,服务发现(Service Discovery)的核心机制之一就是 DNS。每个 Service、每个有状态的 Pod 都会获得一个稳定的域名,业务容器只需要用域名访问即可,无需关心背后的 IP 变化。承担这一职责的默认组件,正是 **CoreDNS**。

本文整理 CoreDNS 在 Kubernetes 中的定位、Corefile 配置语法、常见调优手段,以及排查思路。

## 一、CoreDNS 是什么

CoreDNS 是一个用 Go 编写、基于插件链(Plugin Chain)架构的轻量级 DNS 服务器,由 CNCF(Cloud Native Computing Foundation)托管,与 Kubernetes 同属一个基金会。

它有两个关键特征:

- **插件化**:所有功能(转发、缓存、Kubernetes 解析、Prometheus 指标、重写等)都以插件形式挂载到请求处理链上,按 Corefile 中声明的顺序执行。
- **配置极简**:整个服务的行为由一个名为 `Corefile` 的文本文件描述,语法接近 Caddy。

在 Kubernetes 中,CoreDNS 取代了早期的 **kube-dns**,成为 1.13 之后默认的集群 DNS 实现。自 Kubernetes 1.21 起,`kubeadm` 已完全移除对 `kube-dns` 的支持,CoreDNS 成为唯一受支持的集群 DNS 应用。从 `kube-dns` 升级时,`kubeadm` 会基于原 ConfigMap 自动生成新的 Corefile,并保留 `stubDomains`、`upstreamNameservers` 等配置。

CoreDNS 以 Deployment 形式运行在 `kube-system` 命名空间,前端通过名为 `kube-dns` 的 Service 暴露(通常使用 `10.96.0.10` 这类集群 IP),以便兼容历史习惯。

## 二、Corefile 配置示例

CoreDNS 的行为完全由 ConfigMap `coredns` 中的 `Corefile` 决定。以下是一份 Kubernetes 集群中的典型默认配置:

```corefile
.:53 {
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    forward . /etc/resolv.conf {
       max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
}
```

- `.:53` 表示监听所有地址的 53 端口,`.` 代表根域。
- 每个 `{ ... }` 块称为一个 **Server Block**,内部声明的插件按顺序组成处理链。

## 三、关键插件说明

### kubernetes

`kubernetes` 插件让 CoreDNS 能够读取集群内的 Service、Endpoint、Pod 信息,实现符合 [Kubernetes DNS-Based Service Discovery Specification](https://github.com/kubernetes/dns/blob/master/docs/specification.md) 的解析。

常用选项:

| 选项 | 说明 |
| --- | --- |
| `pods disabled` | 默认值,不为 Pod 返回 A 记录(返回 NXDOMAIN)。 |
| `pods insecure` | 不校验直接返回,性能好但易被滥用。 |
| `pods verified` | 仅当同命名空间下存在对应 Pod 时才返回,更安全但内存占用更高(需 watch 全部 Pod)。 |
| `fallthrough [ZONES...]` | 在本插件权威区内未命中时,把请求传递给后续插件,而不是直接返回 NXDOMAIN。 |
| `ttl N` | 响应 TTL,默认 5 秒,最大 3600 秒。 |
| `namespaces NS...` | 仅暴露指定命名空间。 |

### forward

`forward . /etc/resolv.conf` 把无法在集群内解析的请求(例如外部域名)转发给节点 `/etc/resolv.conf` 中配置的上游 DNS。它等价于 `kube-dns` 时代的 `upstreamNameservers`。`max_concurrent` 用于限制并发查询数,防止在高负载下耗尽内存。

### cache

对响应做缓存,`cache 30` 表示缓存 30 秒,可显著降低上游 QPS。

### loop

检测并阻止无限递归转发(典型场景:CoreDNS 把请求转发给了自己),在配错 DNS 时能快速暴露问题。

### reload

监听 ConfigMap 变更,自动热加载 Corefile,无需重启 Pod。

### loadbalance

对返回的 A/AAAA 记录做轮询(round-robin)重排,实现简单的负载均衡。

### prometheus

在 `:9153` 暴露 Prometheus 指标,可对接 Grafana 监控 QPS、延迟、缓存命中率。

## 四、Kubernetes 中的 DNS 命名规则

CoreDNS 在集群内的默认域名后缀是 `cluster.local`(由 kubelet 的 `--cluster-domain`,即 `KubeletConfiguration` 的 `clusterDomain` 字段决定,默认 `cluster.local`)。常见命名规则:

**普通 Service**(有 ClusterIP):

```
<service-name>.<namespace>.svc.cluster.local
```

查询返回该 Service 的 ClusterIP;同时为每个具名端口生成 SRV 记录:

```
_<port-name>._<protocol>.<service-name>.<namespace>.svc.cluster.local
```

**Headless Service**(无 ClusterIP,`clusterIP: None`):查询返回的是后端每个就绪 Endpoint 的 Pod IP 集合。对于带 `hostname` 字段的 Endpoint,还会生成:

```
<hostname>.<service-name>.<namespace>.svc.cluster.local
```

**StatefulSet + Headless Service**:每个 Pod 获得稳定的、可预测的域名,常用于数据库、消息队列等需要稳定网络身份的场景:

```
<pod-name>.<service-name>.<namespace>.svc.cluster.local
# 示例
web-0.nginx.default.svc.cluster.local
web-1.nginx.default.svc.cluster.local
```

**Pod**(基于 IP):当 `pods` 选项非 `disabled` 时:

```
<pod-ip-dashed>.<namespace>.pod.cluster.local
# 示例(Pod IP 10.0.0.5)
10-0-0-5.default.pod.cluster.local
```

**ExternalName Service**:返回 CNAME 记录,把集群内域名别名到外部域名。

## 五、Pod 的 DNS 策略

每个 Pod 都可以通过 `dnsPolicy` 与 `dnsConfig` 精细控制解析行为:

```yaml
spec:
  dnsPolicy: ClusterFirst
  dnsConfig:
    nameservers:
      - 8.8.8.8
    searches:
      - ns1.svc.cluster.local
    options:
      - name: ndots
        value: "5"
```

`dnsPolicy` 的取值:

- `ClusterFirst`(默认):先走集群 DNS,未命中再转发上游。
- `Default`:继承所在节点的 `/etc/resolv.conf`。
- `ClusterFirstWithHostNet`:开启 `hostNetwork: true` 时使用,语义与 `ClusterFirst` 一致。
- `None`:完全忽略集群 DNS,只使用 `dnsConfig` 中显式指定的配置。

需要特别关注 `ndots: 5`。默认情况下,任何包含少于 5 个点的名称都会被先拼上 search 后缀尝试解析,这意味着访问 `google.com` 会先依次尝试 `google.com.default.svc.cluster.local` 等,最后才会以绝对域名查询。短名解析快、外部域名查询慢的根因往往就在这里。对于明确是绝对域名的查询,可手动加结尾的 `.`(如 `google.com.`)或调小 `ndots`。

## 六、常见定制场景

### 1. 自定义 Stub Domain

把某个内部域转发给自建 DNS,可新增一个 Server Block:

```corefile
example.com:53 {
    errors
    cache 30
    forward . 192.168.1.100:53
}
```

### 2. 静态 hosts 映射

使用 `hosts` 插件,在 Corefile 中直接维护少量自解析记录,适合应急或灰度:

```corefile
.:53 {
    hosts {
        10.0.0.100 foo.example.com
        fallthrough
    }
    # ... 其余插件
}
```

### 3. 修改默认上游

把外部解析交给指定公共 DNS:

```corefile
forward . 8.8.8.8 1.1.1.1 {
    max_concurrent 1000
}
```

## 七、性能优化:NodeLocal DNSCache

在大规模集群中,Pod 的 DNS 查询需要经过 kube-proxy 的 iptables DNAT 才能到达 CoreDNS,这会带来两个问题:

1. **conntrack 竞争与表项耗尽**:UDP DNS 查询会占用 conntrack 表项,默认 30 秒才过期,高 QPS 下容易饱和,出现 5 秒级偶发延迟(源自 conntrack 对 UDP 流的 INCOMPLETE 超时,见 kubernetes/kubernetes#56903)。
2. **跨节点查询延迟**:本节点没有 CoreDNS 实例时,Pod 需要走网络去别的节点查询。

**NodeLocal DNSCache**(Kubernetes 1.18 GA)通过在每个节点上以 DaemonSet 形式运行一份 CoreDNS 缓存代理,拦截本节点 Pod 的 DNS 查询并优先本地命中,从而:

- 绕过 iptables DNAT 与 conntrack;
- 把与上游 CoreDNS 之间的连接升级为 TCP,降低丢包导致的尾延迟;
- 提供每节点维度的指标可见性。

部署思路是:获取官方 manifest,替换 `__PILLAR__LOCAL__DNS__`、`__PILLAR__DNS__DOMAIN__`、`__PILLAR__DNS__SERVER__` 等占位符后 `kubectl create -f` 应用。注意,IPVS 模式与 iptables 模式的部署细节略有不同:IPVS 模式下还需要把 kubelet 的 `--cluster-dns` 改为本地缓存地址。

需要注意的是,NodeLocal DNSCache 默认会把非集群域的查询直接转发到上游,可能绕过 CoreDNS 的 `rewrite` 等逻辑。解决办法是把 NodeLocal DNSCache 的上游指向 CoreDNS 的 ClusterIP,而不是节点 `/etc/resolv.conf`。

## 八、排查思路

常用命令:

```bash
# 在 Pod 内部测试解析
kubectl exec -it <pod> -- nslookup kubernetes.default

# 用 dig 查看 TTL 与解析链路
kubectl exec -it <pod> -- dig +trace kubernetes.default.svc.cluster.local

# 查看 CoreDNS 日志
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=100

# 查看 Corefile 当前内容
kubectl get cm coredns -n kube-system -o yaml
```

常见问题:

- **解析 5 秒延迟**:多由 conntrack 竞争引起,考虑部署 NodeLocal DNSCache。
- **外部域名间歇失败**:检查 `forward` 上游、节点 `/etc/resolv.conf` 以及 `ndots` 设置。
- **ConfigMap 改了不生效**:确认开启了 `reload` 插件,或手动 `kubectl rollout restart deployment coredns -n kube-system`。
- **Pod 域名查不到**:确认 `kubernetes` 插件的 `pods` 选项不是 `disabled`。

## 参考

- [CoreDNS 官方文档](https://coredns.io/)
- [CoreDNS GitHub 仓库](https://github.com/coredns/coredns)
- [Kubernetes 官方文档:Using CoreDNS for DNS Service Discovery](https://kubernetes.io/docs/tasks/administer-cluster/coredns/)
- [Kubernetes 官方文档:DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [CoreDNS kubernetes 插件文档](https://coredns.io/plugins/kubernetes/)
- [NodeLocal DNSCache 官方文档](https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/)
- [DNS-Based Service Discovery Specification](https://github.com/kubernetes/dns/blob/master/docs/specification.md)
- [Scaling CoreDNS](https://github.com/coredns/deployment/blob/master/kubernetes/Scaling_CoreDNS.md)
- [Linux网络学习笔记(二):域名解析(DNS)——以 CoreDNS 为例](https://thiscute.world/posts/about-dns-protocol/)
- [CoreDNS 详解](https://github.com/chenzongshu/Kubernetes/blob/master/CoreDNS%E8%AF%A6%E8%A7%A3.md)
