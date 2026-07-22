+++
title = "如何在 K8s 上运行 Spark"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "原生调度器与 Spark Operator 两种方式的原理与实践"
description = "介绍 Apache Spark 在 Kubernetes 上运行的两种主流方式:spark-submit 原生调度器与 Kubeflow Spark Operator,涵盖部署模型、关键配置、调度增强与选型建议。"
author = "小智晖"
authors = ["小智晖"]
categories = ["k8s"]
tags = ["k8s", "spark", "大数据", "spark-operator"]
keywords = ["spark on kubernetes", "spark operator", "k8s spark", "spark-submit", "大数据云原生"]
toc = true
draft = false
+++

Apache Spark 自 2.3 版本开始提供对 Kubernetes 的原生支持,在 3.0 版本中正式 GA。把 Spark 跑在 K8s 上,可以利用容器的弹性伸缩和资源隔离能力,摆脱对 YARN 或独立集群管理器(Standalone)的依赖,让数据工程与现有云原生体系统一在一起。本文整理在 K8s 上运行 Spark 的两种主流方式、关键概念和落地要点。

## 两种运行方式对比

在 K8s 上跑 Spark 主要有两条路径:

| 方式 | 入口 | 适用场景 |
| --- | --- | --- |
| **原生调度器(Native K8s Scheduler)** | `spark-submit --master k8s://...` | 一次性作业、批处理、CI 触发的 ETL |
| **Spark Operator** | 声明式 CRD `SparkApplication` | 长期运行、需要 GitOps/调度/监控的稳定生产环境 |

两者的底层调度最终都落到 K8s Pod 上,区别在于「谁来调用 `spark-submit`」以及「如何管理作业生命周期」。

## 原生调度器:spark-submit 直接提交

### 工作原理

使用原生调度器时,`spark-submit` 本身作为客户端向 K8s API Server 提交作业。它的工作流程是:

1. `spark-submit` 在 K8s 集群中创建一个 **Driver Pod**,负责运行 Spark Driver 进程;
2. Driver 根据配置的 `spark.executor.instances` 数量,动态创建 **Executor Pod** 来执行任务;
3. 作业完成后,Executor Pod 被回收;Driver Pod 保留在 `Completed` 状态,方便事后查看日志(不再占用 CPU/内存)。

Master URL 使用 `k8s://` 协议头,例如 `k8s://https://<apiserver>:<port>`。若不写协议,默认走 HTTPS。

### 基本示例

```bash
./bin/spark-submit \
  --master k8s://https://<k8s-apiserver-host>:<k8s-apiserver-port> \
  --deploy-mode cluster \
  --name spark-pi \
  --class org.apache.spark.examples.SparkPi \
  --conf spark.executor.instances=5 \
  --conf spark.kubernetes.container.image=apache/spark:3.5.0 \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  local:///path/to/examples.jar
```

API Server 地址可以通过 `kubectl cluster-info` 查看。

### 镜像准备

Spark 仓库自带 `bin/docker-image-tool.sh` 脚本和 `kubernetes/dockerfiles/` 下的 Dockerfile,可以自行构建并推送到私有仓库:

```bash
./bin/docker-image-tool.sh -r <repo> -t my-tag build
./bin/docker-image-tool.sh -r <repo> -t my-tag push
```

也可以直接使用 Docker Hub 上的官方镜像 `apache/spark:<version>`。PySpark 与 SparkR 需要分别用 `-p` / `-R` 参数指定对应绑定 Dockerfile 构建。

### 命名空间与 RBAC

Driver Pod 需要一个 ServiceAccount 来创建和监听 Executor Pod,因此必须授予 **创建 Pod 和 Service** 的权限:

```bash
kubectl create serviceaccount spark
kubectl create clusterrolebinding spark-role \
  --clusterrole=edit \
  --serviceaccount=default:spark \
  --namespace=default
```

通过 `--conf spark.kubernetes.namespace=<ns>` 指定作业所在命名空间(默认 `default`)。

### 资源与调度配置

常用的 K8s 专属配置项:

- `spark.kubernetes.container.image`:指定 Driver/Executor 镜像(**必填**);
- `spark.kubernetes.driver.request.cores` / `spark.kubernetes.executor.request.cores`:Pod 的 CPU 请求;
- `spark.kubernetes.driver.limit.cores` / `spark.kubernetes.executor.limit.cores`:CPU 上限;
- `spark.kubernetes.memoryOverheadFactor`:非堆内存系数,JVM 默认 `0.1`,非 JVM(如 Python)默认 `0.4`;
- `spark.kubernetes.node.selector.xxx`:节点选择器,可分别为 driver/executor 单独设置;
- `spark.kubernetes.executor.deleteOnTermination`:Executor 结束后是否删除 Pod(默认 `true`)。

### 调试命令

```bash
# 查看 Driver 日志
kubectl -n=<namespace> logs -f <driver-pod-name>

# 查看 Pod 调度情况
kubectl describe pod <driver-pod-name>

# 端口转发访问 Spark Web UI
kubectl port-forward <driver-pod-name> 4040:4040
```

## Spark Operator:声明式管理

### Operator 是什么

[Spark Operator](https://github.com/kubeflow/spark-operator) 是 Kubeflow 社区维护的 Kubernetes Operator,目标是让 Spark 应用像其他 K8s 工作负载一样用声明式方式定义和管理。它最早源自 GoogleCloudPlatform 下的 `spark-on-k8s-operator`,后捐献给 Kubeflow 社区统一维护。

其核心是 **自定义资源定义(CRD)** `SparkApplication`(API 组 `sparkoperator.k8s.io`,版本 `v1beta2`),以及用于定时调度的 `ScheduledSparkApplication`。Operator 控制器监听这些资源,自动调用 `spark-submit` 完成 Pod 创建和生命周期管理。

### 主要特性

- 声明式 YAML 定义 Spark 应用,变更后自动重新提交;
- 原生支持 cron 定时调度(`ScheduledSparkApplication`);
- 通过 Mutating Webhook 自定义 Pod(挂载 ConfigMap/Volume、设置亲和性等),弥补原生 `spark-submit` 的不足;
- 支持配置重启策略与失败自动重试(线性退避);
- 内置 Prometheus 指标暴露,方便接入监控告警。

### 安装

通过 Helm 安装(推荐):

```bash
helm repo add spark-operator https://kubeflow.github.io/spark-operator
helm install spark-operator spark-operator/spark-operator \
    --namespace spark-operator --create-namespace --wait
```

也可以使用 Kustomize:

```bash
git clone https://github.com/kubeflow/spark-operator.git
kubectl apply -k config/default --server-side --force-conflicts
```

### SparkApplication 示例

下面是一个计算 π 的经典示例,提交后 Operator 会自动运行 `spark-submit`:

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-pi
  namespace: default
spec:
  type: Scala
  mode: cluster
  image: apache/spark:3.5.0
  mainClass: org.apache.spark.examples.SparkPi
  mainApplicationFile: local:///path/to/examples.jar
  driver:
    cores: 1
    memory: 512m
    serviceAccount: spark
  executor:
    instances: 2
    cores: 1
    memory: 512m
```

通过 `kubectl apply -f spark-pi.yaml` 提交后,可用 `kubectl get sparkapplication` 查看运行状态。

## 调度增强

原生 K8s 调度器对批处理作业的「抢占」与「队列」支持较弱,在 Spark 3.3 之后可以集成外部批调度器:

- **Volcano**(Spark 3.3.0 + Volcano 1.7.0 起):通过 `spark.kubernetes.scheduler.name=volcano` 启用,支持 PodGroup 实现gang scheduling,适合大规模 All-or-Nothing 的分布式训练/计算任务;
- **Apache YuniKorn**:另一个可选的 K8s 调度器,通过 label/annotation 把作业分配到指定队列。

## 选型建议

- **临时作业、CI/CD 流水线、个人调试**:直接用 `spark-submit --master k8s://`,无需额外组件,启动成本低;
- **生产环境、需要 GitOps、定时调度、监控告警**:优先考虑 Spark Operator,把 Spark 作业纳入 K8s 声明式管理体系;
- **对调度公平性、抢占、队列有强需求**:结合 Volcano 或 YuniKorn 使用原生调度器或 Operator。

## 已知限制

根据官方文档,目前 K8s 上运行 Spark 仍有若干限制需要注意:

1. **暂无 External Shuffle Service**:动态分配需依赖 `spark.dynamicAllocation.shuffleTracking.enabled=true` 进行 shuffle 追踪;
2. **Driver Pod 需手动清理**:作业结束后 Driver Pod 残留在 API 中(不占资源),长期运行需配置 TTL 或定时清理;
3. **Pod Template 字段会被覆盖**:Spark 会强制覆盖 Pod 模板中的 name、namespace、image、resources 等字段;
4. **Minikube 默认配置不足**:单 Executor 作业建议至少分配 3 CPU + 4GB 内存。

## 参考

- [Running Spark on Kubernetes(官方文档)](https://spark.apache.org/docs/latest/running-on-kubernetes.html)
- [kubeflow/spark-operator(GitHub)](https://github.com/kubeflow/spark-operator)
- [Spark Operator 文档站点](https://spark.kubeflow.org/)
- [Apache Spark 下载与版本说明](https://spark.apache.org/downloads.html)
