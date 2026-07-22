+++
title = "Boinc 任务分配"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Boinc 任务的广播、绑定与限流配置"
description = "介绍 Boinc 项目中 create_work 的任务分配方式(广播与绑定),以及通过 config.xml 与 config_aux.xml 对每主机任务并发数进行限制的配置方法。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "boinc", "分布式计算", "任务调度"]
keywords = ["boinc", "create_work", "任务分配", "广播", "targeted jobs", "config_aux"]
toc = true
draft = false
+++

参考 [AssignedWork](https://github.com/BOINC/boinc/wiki/AssignedWork)。

任务分配分两种情况：广播（Broadcast）和绑定（Targeted Jobs）。

先从任务提交命令说起。

```bash
bin/create_work --appname worker --wu_name worker_nodelete input
```

`create_work` 的一些重要参数说明:

- `--appname name`:应用名（必填）。
- `--app_version_num N`:指定应用版本号。
- `--wu_name name`:工作单元（Work Unit）名，不能重复。可以省略，省略时系统会基于应用名、PID 和时间戳自动生成一个不重复的名字。
- `--wu_template filename`:指定工作单元输入模板的文件名，不指定时默认为 `templates/appname_in`。
- `--target_user ID`:将工作单元分配给指定 ID 的用户。
- `--target_host ID`:将工作单元绑定到指定的主机。
- `--target_team ID`:将工作单元分配给指定团队（team）的所有主机。
- `--target_nresults n`:指定工作单元生成的 result 数量，默认为 `DEFAULT_TARGET_NRESULTS`(源码中定义为 1)。
- `--priority n`:指定优先级。
- `--broadcast`:将任务广播给所有主机。
- `--broadcast_user ID`:将任务广播给指定用户的所有主机。
- `--broadcast_team ID`:将任务广播给指定团队的所有主机。
- `--stdin`:从标准输入读取一个文件列表，一次提交多个工作单元。

广播和绑定的区别在于:

- 广播（broadcast）的任务在某台主机上失败后不会重试;而绑定的任务（targeted job）在集合内某台主机上失败时，会在集合内的另一台主机上重试，直到完成。
- 广播任务会跳过 validator 与 assimilator(项目方需要自行编写守护进程处理结果);绑定任务则会走正常的校验与归化流程。
- 开启任务广播，需要在 `config.xml` 中添加 `<enable_assignment_multi>1</enable_assignment_multi>`;开启绑定则添加 `<enable_assignment>1</enable_assignment>`。

任务绑定的应用场景:

- 当需要把某个任务指定给特定主机执行时，使用 `--target_host` 参数。
- 当需要把任务指定给一组主机执行时，可以使用 `--target_user` 参数（这一组主机用同一个账号登录即可）,也可以用 `--target_team` 限定到某个团队。

特别说明:

当任务被绑定时,`workunit.transitioner_flags` 字段会被设置为 `TRANSITION_NO_NEW_RESULTS`(源码中定义值为 `2`),用于告诉 transitioner 不要再为该工作单元创建 result 实例，改由调度器在匹配到合适的主机后再创建。

因此在提交一个绑定的工作单元时，不会直接在 `result` 表里创建记录，而是先把记录写入 `assignment` 表;等到有主机被分配到该任务后，再在 `result` 表里创建对应记录。

**提交工作单元的最佳实践**

可以参考 `sample_work_generator`(源码位于 `sched/sample_work_generator.cpp`,项目搭建后通常以 `bin/sample_work_generator` 形式被守护进程调用)。该示例程序以"维持一个未发送 result 的缓冲（cushion）"的思路持续生成工作单元。主要思路总结如下:

1. 将切片文件提前准备好并编号，统一存储在云端（例如腾讯云 COS、对象存储等）进行管理。
2. 在提交工作单元之前，先生成 input 文件，input 文件内容为对应的切片编号（或切片下载地址）,再提交。
3. 为避免一次性提交过多工作单元导致难以管理，可以对提交做限速：提交前先查询当前未发送（unsent）的 result 数量，只有当该数量低于设定的阈值（比如最多 10 个）时才继续提交。

> 说明:BOINC 自带的 `bin/wu_check`(源码 `sched/wu_check.cpp`)主要用于检查 result 的输入文件是否缺失并可选修复，它本身并不直接返回未发送 result 的数量。统计未发送 result 数量需要直接查询数据库(例如统计 `result` 表中 `server_state = 2` 的记录数),或参考 `sample_work_generator` 中"维持 cushion"的实现方式。

## 任务限制

任务限制（Job Limits）可以用来限定每个主机上运行的任务实例数量，通过配置可以分别在 CPU、GPU、project、app 等维度上做细粒度控制。

实现代码在以下文件中(位于 BOINC 源码的 `sched/` 目录):

```text
sched/sched_limit.cpp
sched/sched_limit.h
```

配置时，需要结合 `config.xml` 中的以下字段:

```xml
<max_wus_in_progress>N</max_wus_in_progress>
<max_wus_in_progress_gpu>M</max_wus_in_progress_gpu>
```

`max_wus_in_progress` 用于限制每台主机上该项目的 CPU 任务并发数（按处理器数量按比例生效）;`max_wus_in_progress_gpu` 用于限制 GPU 任务的并发数。这两个字段在调度器解析时，会被映射到 `config_aux.xml` 中 `max_jobs_in_progress.project_limits` 的 `cpu_limit`/`gpu_limit`(并自动按 per processor 生效)。

更细粒度的控制需要使用 **`config_aux.xml`** 中的 `max_jobs_in_progress` 字段。`config_aux.xml` 的格式如下:

```xml
<?xml version="1.0"?>
<config>
<max_jobs_in_progress>
    <project>
        <total_limit>
            <jobs>N</jobs>
        </total_limit>
        <cpu_limit>
            <jobs>N</jobs>
            <per_proc/>
        </cpu_limit>
        <gpu_limit>
            <jobs>N</jobs>
            <per_proc/>
        </gpu_limit>
    </project>
    <app>
        <app_name>name</app_name>
        <total_limit>
            <jobs>N</jobs>
        </total_limit>
        <cpu_limit>
            <jobs>N</jobs>
            <per_proc/>
        </cpu_limit>
        <gpu_limit>
            <jobs>N</jobs>
            <per_proc/>
        </gpu_limit>
    </app>
</max_jobs_in_progress>
</config>
```

其中:

- `<project>` 段作用于整个项目;`<app>` 段作用于指定应用，可重复多次。
- `<total_limit>`:该范围内的总任务数上限。
- `<cpu_limit>`:CPU 任务上限;`<gpu_limit>`:GPU 任务上限。
- `<jobs>N</jobs>`:任务数量上限（0 表示不限制）。
- `<per_proc/>`:若设置，则上述上限按"每处理器"生效(即实际限额为 `N × 处理器数`)。

## 参考

- [BOINC Wiki - AssignedWork](https://github.com/BOINC/boinc/wiki/AssignedWork)
- [BOINC Wiki - ProjectOptions](https://github.com/BOINC/boinc/wiki/ProjectOptions)
- [`create_work` 源码](https://github.com/BOINC/boinc/blob/master/tools/create_work.cpp)
- [`sched_limit.cpp` 源码](https://github.com/BOINC/boinc/blob/master/sched/sched_limit.cpp)
- [`sample_work_generator.cpp` 源码](https://github.com/BOINC/boinc/blob/master/sched/sample_work_generator.cpp)
