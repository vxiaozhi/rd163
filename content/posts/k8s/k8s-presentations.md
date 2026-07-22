+++
title = "K8s 演示文稿及学习资源汇总"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "汇总 K8s 演示文稿、社区分享、官方文档与认证路径"
description = "整理 Kubernetes 学习过程中有价值的演示文稿、视频分享、官方文档与社区资源,方便不同阶段的学习者系统入门和深入。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "kubernetes", "cncf", "学习资源", "社区"]
keywords = ["kubernetes", "k8s", "cncf", "学习资源", "演示文稿", "kubecon"]
toc = true
draft = false
+++

本文整理 Kubernetes(简称 K8s)学习路径上值得收藏的演示文稿、视频分享、官方文档与社区资源。内容面向不同阶段的学习者：从概念入门、网络模型深挖，到生产实践与认证考试，均可在此找到对应素材。文中链接以官方渠道与社区一手资料为主，尽量规避失效或转载失真的内容。

## CNCF 社区资源

Kubernetes 是 CNCF(Cloud Native Computing Foundation，云原生计算基金会)托管的最具代表性的毕业项目（Graduated Project）,围绕它形成了大量社区资源。

### CNCF Community Presentations

[cncf/presentations](https://github.com/cncf/presentations) 是 CNCF 维护的社区演示文稿集合，收纳了来自 KubeCon、CloudNativeCon 等 CNCF 活动的公开幻灯片。仓库按项目维度划分目录，涵盖 Kubernetes、Prometheus、Envoy、gRPC、Jaeger、CoreDNS、Linkerd、OPA、OpenTracing 等，并提供中、日、韩等多语言版本。

该仓库目前正逐步迁移到 [presentations.cncf.io](https://presentations.cncf.io),但旧仓库数据不会删除，仍可作为检索入口。提交方式有两种：非技术背景用户可通过 Issue 申请，技术人员可直接向 `presentations.yaml` 提交 PR(Pull Request)。

### KubeCon + CloudNativeCon

[KubeCon + CloudNativeCon](https://www.cncf.io/kubecon-cloudnativecon-events/) 是 CNCF 的旗舰会议，每年在北美、欧洲、中国、日本、印度等多地举办。会议议题覆盖 Kubernetes 本身及生态项目（网络、存储、安全、可观测性、服务网格等）,所有正式议程均有录像，会后免费发布在 [CNCF YouTube 频道](https://www.youtube.com/c/cloudnativefdn),是跟踪前沿实践最直接的渠道。

## Kubernetes 官方社区

### Kubernetes Community 仓库

[kubernetes/community](https://github.com/kubernetes/community) 是 Kubernetes 社区协作的中心枢纽，存放治理文档、贡献指南、各 SIG(Special Interest Group，特别兴趣小组)与 WG(Working Group，工作组)的章程和会议记录。

仓库内列出了约 26 个 SIG，与日常使用关联最紧密的几个:

| SIG | 关注领域 |
| --- | --- |
| sig-network | CNI、Service、Ingress、Gateway API、kube-proxy、NetworkPolicy |
| sig-storage | CSI、PV/PVC、Volume Snapshot、存储驱动 |
| sig-node | kubelet、容器运行时（CRI）、Pod 生命周期、资源管理 |
| sig-auth | RBAC、ServiceAccount、Pod Security、Secret |
| sig-scheduling | kube-scheduler、调度框架、批处理与 Volcano 协同 |
| sig-cluster-lifecycle | kubeadm、集群创建、升级、高可用 |

每个 SIG 都有定期的社区会议和 YouTube 录像归档，深入某一方向时，直接追 SIG 的会议记录比看二手博客更可靠。

### 沟通渠道

- **Slack**:[slack.k8s.io](https://slack.k8s.io/) 是 Kubernetes 官方 Slack 入口（现经 inviter.co 跳转）,按 SIG、地区、语言划分了上千个 channel。
- **邮件列表与论坛**:[discuss.kubernetes.io](https://discuss.kubernetes.io/) 是官方 Discourse 论坛，适合长问题、深度讨论。

## 推荐演示文稿（PPT）

以下幻灯片是笔者在学习网络模型时反复参考的素材，主题集中于 Kubernetes 整体介绍与网络:

- [K8s Introduction](https://drive.google.com/file/d/1p65kmMRyDL4_r2MWSJLTMAZyMnHEZUXt/view?pli=1):对 Kubernetes 核心对象（Pod、Deployment、Service）的整体介绍，适合入门通读。
- [Deep dive into Kubernetes Networking](https://www.slideshare.net/slideshow/deep-dive-into-kubernetes-networking-108505405/108505405#1):从 CNI、Pod 间通信到 Service 转发的较系统讲解。
- [Kubernetes Networking 101](https://www.slideshare.net/slideshow/kubernetes-networking-78049891/78049891#1):网络入门向材料，与笔者另一篇《kubernetes 网络模型》可对照阅读。
- [Kubernetes 101 / 201](https://itdks.su.bcebos.com/03ede220525049a7aea7ad4966c21387.pdf):中文社区分享的进阶幻灯片，101 与 201 合集。

> 注:SlideShare 自 2023 年起逐步收紧访问策略，部分链接可能出现跳转或登录提示，如打不开可结合下文视频资源或官方文档替代查阅。

## 推荐分享视频

视频比幻灯片更适合理解数据包流转、控制循环等动态过程:

- [k8s 主流网络方案（OVS、Flannel、Calico）及原理](https://www.youtube.com/watch?v=cyKUaT0SEtU):横向对比三种主流 CNI 实现，便于建立选型直觉。
- [技术分享:Kubernetes Networking Model(赵锟)](https://www.youtube.com/watch?v=HxS4s11rmyA):围绕 K8s 网络模型的中文技术分享。
- [深入理解 Kubernetes 网络](https://www.bilibili.com/video/BV1Ft4y117Ch/):B 站中文讲解，适合搭配上文幻灯片对照学习。

## 官方文档与免费课程

### 官方文档结构

[Kubernetes 官方文档](https://kubernetes.io/zh-cn/docs/home/)按读者层次组织成五大块，检索时直接定位对应章节效率最高:

- **入门（Getting Started）**:Minikube、kind 等学习环境搭建，以及 kubeadm 生产环境部署。
- **教程（Tutorials）**:包含 [Kubernetes Basics](https://kubernetes.io/zh-cn/docs/tutorials/kubernetes-basics/) 和 [Hello Minikube](https://kubernetes.io/zh-cn/docs/tutorials/hello-minikube/) 等交互式入门练习。
- **概念（Concepts）**:架构、工作负载、服务与网络、存储、安全、配置等原理性章节。
- **任务（Tasks）**:面向具体操作的 how-to，例如配置探针、Node Affinity、NetworkPolicy 等。
- **参考（Reference）**:API、kubectl、各组件命令行参数与配置文件的权威说明。

### Linux Foundation 免费课程

Linux Foundation 与 CNCF 联合提供一批免费在线课程（注册账号即可旁听）,与 Kubernetes 直接相关的有:

| 课程代码 | 名称 | 重点 |
| --- | --- | --- |
| LFS158 | [Introduction to Kubernetes](https://training.linuxfoundation.org/resources/?_sft_technology=kubernetes) | K8s 整体概念 primer |
| LFS157 | Introduction to Serverless on Kubernetes | Knative、FaaS |
| LFS144 | Introduction to Istio | 服务网格入门 |
| LFS146 | Introduction to Cilium | 基于 eBPF 的 CNI |
| LFS147 | Introduction to AI/ML Toolkits with Kubeflow | Kubeflow 与 ML 工作流 |

付费方向另有 LFD259(Kubernetes for Developers)等可用于系统备考。

## 认证路径

CNCF 与 Linux Foundation 提供四项主流 Kubernetes 认证，均两年有效:

- **KCNA**(Kubernetes and Cloud Native Associate):入门级，在线多选题，适合零基础检验学习成果。
- **CKA**(Certified Kubernetes Administrator):Performance-based 上机考试，聚焦集群运维、故障排查、网络与存储。
- **CKAD**(Certified Kubernetes Application Developer):偏应用侧，考察 Deployment、ConfigMap、Service、Job 等对象的编写与排错。
- **CKS**(Certified Kubernetes Security Specialist):需先持 CKA，聚焦集群与容器安全（Cluster Hardening、Supply Chain Security 等）。

详细信息见 [CNCF 培训与认证页](https://www.cncf.io/training/certification/)。

## 推荐书籍

- **Kubernetes Patterns**(Bilgin Ibryam、Roland Huss,O'Reilly):将 GoF(Gang of Four)设计模式思想引入 K8s，归纳出 Foundational、Structural、Behavioral、Configuration、Security、Advanced 六类模式（Init Container、Sidecar、Operator 等）。配套示例仓库 [rhuss/k8spatterns](https://github.com/rhuss/k8spatterns)。
- **The Kubernetes Book**(Nigel Poulton):入门向的精炼读本，几乎每年更新一版。
- **Site Reliability Engineering**(Google):免费在线阅读 [sre.google/sre-book](https://sre.google/sre-book/table-of-contents/),理解 K8s 设计中的 SLO、错误预算、控制循环思想时可作为对照。

## 参考

- [CNCF Presentations 仓库](https://github.com/cncf/presentations)
- [Kubernetes Community 仓库](https://github.com/kubernetes/community)
- [Kubernetes 官方文档](https://kubernetes.io/zh-cn/docs/home/)
- [KubeCon + CloudNativeCon](https://www.cncf.io/kubecon-cloudnativecon-events/)
- [CNCF 培训与认证](https://www.cncf.io/training/certification/)
- [Linux Foundation 免费资源](https://training.linuxfoundation.org/resources/?_sft_technology=kubernetes)
- [Google SRE Book](https://sre.google/sre-book/table-of-contents/)
- [rhuss/k8spatterns 示例仓库](https://github.com/rhuss/k8spatterns)
- [kubernetes 网络模型（本博客）](../k8s-networking-model)
