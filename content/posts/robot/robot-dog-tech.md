+++
title = "机器狗技术"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从 MIT Mini Cheetah 到国内厂商的四足机器人开源生态"
description = "梳理机器狗(四足机器人)背后的技术栈:MIT Mini Cheetah 开源项目、ROS 机器人操作系统,以及国内主要厂商的开源资源。"
author = "小智晖"
authors = ["小智晖"]
categories = ["robot"]
tags = ["robot", "quadruped-robot", "ros", "mit-cheetah", "open-source", "unitree"]
keywords = ["机器狗", "四足机器人", "Mini Cheetah", "ROS", "宇树科技", "开源"]
toc = true
draft = false
+++

机器狗（Quadruped Robot，四足机器人）是过去十年进展最显著的机器人形态之一。从实验室里能完成后空翻的 MIT Mini Cheetah，到能在工地、变电站、巡检现场落地的商用产品，这条技术路线的核心驱动力之一是**开源**。本文梳理机器狗技术栈的两个根基——MIT Mini Cheetah 软件项目和机器人操作系统（ROS）,以及国内主要厂商的开源资源，方便快速建立一张「技术地图」。

## 行业背景：为什么「都基于 MIT」

国内外绝大多数机器狗公司，其运动控制框架都直接或间接地建立在 **MIT Biomimetics Lab** 的开源工作之上。两条关键技术遗产是:

- **MIT Cheetah 软件栈**:包含机器人本体控制代码、动力学库和仿真环境，定义了四足机器人控制软件的基本结构。
- **ROS(Robot Operating System)**:提供了节点化通信、传感器驱动、构建工具链等通用基础设施。

加上近年来强化学习（Reinforcement Learning,RL）在 sim-to-real(仿真到现实迁移)上的突破，四足机器人从「能用」走向了「好用」。理解这条主线，就能看懂市面上绝大多数机器狗的技术来源。

## MIT Mini Cheetah 与 Cheetah-Software

### Mini Cheetah 是什么

Mini Cheetah 是 MIT 仿生机器人实验室（Biomimetics Lab）开发的紧凑型四足机器人，是更大的 Cheetah 3 的「迷你兄弟」。它以高功率密度的准直驱（Quasi-Direct Drive）执行器著称，2019 年成为**第一台完成后空翻的四足机器人**,因此被业界视为四足机器人 agility(敏捷性)的标志性平台。

### Cheetah-Software 仓库

MIT 将 Mini Cheetah / Cheetah 3 的控制与仿真软件开源在 GitHub:

- 项目地址:<https://github.com/mit-biomimetics/Cheetah-Software>
- 许可证:**MIT License**
- 主要语言:C++(约 90%),辅以 CMake、Python、MATLAB

仓库的典型目录结构如下:

```
common/      # 共享库:动力学、工具函数
robot/       # 机器人本体的控制程序
sim/         # 仿真程序(依赖 Qt)
config/      # 配置文件
lcm-types/   # LCM 消息定义(进程间通信)
scripts/     # 辅助脚本
third-party/ # 第三方依赖
user/        # 用户自定义代码
```

编译时通过 CMake 区分目标平台：为 Mini Cheetah 本体编译时需添加:

```bash
cmake -DMINI_CHEETAH_BUILD=TRUE ..
```

仓库没有正式的 release tag，文档相对精简，需要配合实验室公开的论文与硬件资料阅读。它最大的价值是给出了一个**可参考、可改写的四足控制骨架**,后续大量学术工作与商业产品都在此基础上演化。

## ROS:机器人操作系统

### 是什么，不是什么

ROS(Robot Operating System)名字里带「Operating System」,但它**并不是操作系统**,而是一套用于编写机器人软件的中间件（middleware）与工具链，由 Open Source Robotics Foundation(OSRF)维护。其核心抽象包括:

- **Node(节点)**:一个执行单一功能的进程。
- **Topic(话题)**:节点间的异步发布/订阅消息总线。
- **Service(服务)**:同步的请求/响应调用。
- **Action(动作)**:支持反馈与取消的长时间任务接口。

这套通信模型让传感器、执行器、规划算法可以解耦开发、独立运行，再通过消息总线组合成完整系统。

### 运行时四要素

实际部署一台基于 ROS 的机器狗，通常要处理以下四个部分:

1. **环境（Environment）**:操作系统（一般是 Ubuntu）、ROS 发行版、依赖库与构建工具（colcon / catkin）。
2. **执行器（Actuator）**:电机驱动、关节控制器，以及下发力矩/位置的接口。
3. **传感器（Sensor）**:IMU、深度相机、LiDAR、关节编码器等的驱动与标定。
4. **软件结构（Software Architecture）**:节点划分、话题拓扑、launch 文件、参数管理。

### ROS 2 与发行版

ROS 2 是对 ROS 1 的重写，引入了基于 DDS(Data Distribution Service)的实时通信、生命周期节点与更好的多机支持。当前推荐在 ROS 2 上做新项目。截至 2026 年的主要发行版:

| 发行版 | 发布日期 | 支持周期 |
| --- | --- | --- |
| Humble Hawksbill | 2022-05 | LTS 至 2027-05 |
| Iron Irwini | 2023-05 | 已停止支持 |
| Jazzy Jalisco | 2024-05 | LTS 至 2029-05 |
| Kilted Kaiju | 2025-05 | 至 2026-11 |
| Lyrical Luth | 2026-05 | LTS 至 2031-05 |

偶数年发行版为 5 年支持的长期支持版（LTS）,奇数年版本只支持约 1.5 年。新项目建议直接选择当前 LTS(如 Jazzy 或 Lyrical)。

### 参考资源

官方:

- [ROS 官网](https://www.ros.org)
- [ROS 2 设计文档](https://design.ros2.org)
- [ROS Wiki / 文档](https://docs.ros.org)

中文学习资料:

- [ROS(C++)机器人操作系统学习笔记](https://github.com/HuangCongQing/ROS)
- [Learn Ros(中文整理)](https://github.com/Ewenwan/Ros)

## 国内机器人厂商的开源资源

国内机器狗公司近年也开始积极开源。下面列出的都是可在 GitHub 上直接拉取的项目，主要覆盖 SDK、ROS 包、强化学习训练与仿真。

### 宇树科技（Unitree Robotics）

宇树是出货量最大的国产四足机器人厂商之一，其 GitHub 组织 [`unitreerobotics`](https://github.com/unitreerobotics) 维护了较完整的开源生态，代表性的仓库包括:

- **`unitree_ros`** — ROS 1 仿真包，提供全系列机器人的 URDF 模型（含 11 款四足、若干人形与机械臂）。
- **`unitree_ros2`** — Go2 / B2 等新机型在 ROS 2 环境下的开发包。
- **`unitree_sdk2` / `unitree_sdk2_python`** — 用于 Go2、B2、H1、G1、H2、R1、A2 等机型的 C++ / Python SDK。
- **`unitree_legged_sdk`** — 针对 Aliengo、A1、Go1、B1 等早期机型的底层控制 SDK。
- **`unitree_rl_gym` / `unitree_rl_lab` / `unitree_rl_mjlab`** — 基于 Isaac Sim / Isaac Lab / MuJoCo 的强化学习训练示例。
- **`unitree_mujoco`** — 内置 sim-to-real 流程的 MuJoCo 仿真器。
- **`unitree_guide`** — 配套宇树官方四足控制教材的实现算法，适合入门控制理论。

这套生态对研究者非常友好：从仿真训练到实机部署基本可以全部跑通。

### 云深处科技（DEEP Robotics）

杭州云深处科技以「绝影（Jueying）」系列四足机器人（如 X10、X20、X30 等）著称，产品在电力巡检、应急救援等场景落地较多。相比宇树，云深处在核心运动控制与 RL 算法上的开源较为有限，公开仓库多以文档、SDK 封装或 ROS 驱动为主，具体可在 GitHub 搜索 `deeprobotics` / `jueying` 关键词核实最新资源。官方网址为 <https://www.deeprobotics.cn>。

### 智元（Agibot）X1

需要澄清的一点是：智元开源的 **X1 是一台模块化人形机器人（modular humanoid robot）**,并不是四足机器狗。把它放在这里是因为它代表了国内具身智能（Embodied AI）方向上「全栈开源」的最新范式，与机器狗技术栈高度同源——同样涉及 RL 步态控制、仿真训练与 sim-to-real。

智元在 GitHub 组织 [`AgibotTech`](https://github.com/AgibotTech) 下开源了 X1 的三大件:

- **[`agibot_x1_infer`](https://github.com/AgibotTech/agibot_x1_infer)** — 推理模块（C++）。
- **[`agibot_x1_train`](https://github.com/AgibotTech/agibot_x1_train)** — 强化学习训练代码（Python）。
- **[`agibot_x1_hardware`](https://github.com/AgibotTech/agibot_x1_hardware)** — 硬件设计文件。

整套系统建立在智元自研的开源框架 [AimRT](https://aimrt.org) 之上，AimRT 起到类似 ROS 的中间件作用，负责模型推理、平台驱动与仿真模块之间的通信。对于想从机器狗跨到人形的开发者，X1 是一个可以直接借鉴 RL 训练流水线的样本。

## 小结

机器狗技术的快速发展离不开三个开源支点:MIT Mini Cheetah 提供了控制软件的范本，ROS 提供了通信与工具链基础设施，各厂商的 SDK / RL 仓库则补齐了从仿真到实机的最后一公里。入门路径上，一个可行的顺序是:

1. 用 ROS 2 跑通一个 turtlesim 或简化模型，熟悉节点/话题模型;
2. 拉 `Cheetah-Software` 读 `common/` 里的动力学与控制器代码;
3. 用宇树 `unitree_rl_gym` 在 Isaac Sim 中训练一个简单步态;
4. 通过 `unitree_sdk2` 把策略下发到真实机器上完成 sim-to-real。

把这条链路走通，机器狗技术栈的全貌也就基本掌握了。

## 参考

- [MIT Cheetah-Software](https://github.com/mit-biomimetics/Cheetah-Software)
- [ROS 官网](https://www.ros.org) / [ROS 2 文档](https://docs.ros.org)
- [Unitree Robotics GitHub](https://github.com/unitreerobotics)
- [Agibot Tech GitHub](https://github.com/AgibotTech)
- [AimRT 官网](https://aimrt.org)
- [DEEP Robotics 官网](https://www.deeprobotics.cn)
