+++
title = "虚幻引擎 UE 学习路线"
date = "2025-09-07"
lastmod = "2025-09-07"
subtitle = "从开源项目上手到 UnLua 脚本化改造"
description = "整理虚幻引擎（Unreal Engine）的实战学习路线，推荐几个适合上手的开源项目（Roguelike、EpicSurvivalGame、CARLA、AirSim、DeepDrive），并给出 UnLua、Python 脚本化改造的延伸方向。"
author = "小智晖"
authors = ["小智晖"]
categories = ["ue"]
tags = ["ue", "unreal-engine", "游戏开发", "自动驾驶", "模拟器", "unlua"]
keywords = ["虚幻引擎", "Unreal Engine", "学习路线", "CARLA", "AirSim", "UnLua"]
toc = true
draft = false
+++

## 一、启动项目

### 1. Roguelike

- [Action Roguelike C++ Unreal Engine Game](https://github.com/vxiaozhi/ActionRoguelike)

推荐理由：

- 足够简单而且代码开源；
- 提供 UE4.x - UE5.x 的支持；
- 有中英文教程：
  - [斯坦福课程 UE4 C++ ActionRoguelike 游戏实例教程 0. 绪论](https://www.cnblogs.com/Qiu-Bai/p/17180550.html)

### Step

```bash
git clone git@github.com:vxiaozhi/ActionRoguelike.git
cd ActionRoguelike
git checkout UE5.3
```

> 注:该 fork 保留了多个历史分支(`UE4.25`/`4.26`/`4.27`/`5.1`/`5.2`/`5.3`/`5.4`/`5.5` 等),可按课程对应的引擎版本 `git checkout` 切换。如需更新的 UE5.6 示例,可参考上游 [tomlooman/ActionRoguelike](https://github.com/tomlooman/ActionRoguelike) 的 `UE5.6-CourseProject` 分支。

---

### 2. EpicSurvivalGame - Epic 求生游戏

- [EpicSurvivalGame](https://github.com/vxiaozhi/EpicSurvivalGame)

---

### 3. CARLA - 自动驾驶模拟器

- **GitHub 地址**：<https://github.com/carla-simulator/carla>
- **描述**：CARLA 是一个开源的自动驾驶模拟器，基于 Unreal Engine 构建。它提供了高度可定制的城市环境、交通模拟、传感器模拟（如摄像头、激光雷达）以及用于训练和测试自动驾驶算法的 API。
- **特点**：
  - 支持多种天气和光照条件；
  - 提供真实的物理模拟和交通行为；
  - 通过官方的 [carla-ros-bridge](https://github.com/carla-simulator/ros-bridge) 兼容 ROS（机器人操作系统）和 Autoware。

---

### 4. AirSim - 无人机与车辆模拟器

- **GitHub 地址**：<https://github.com/microsoft/AirSim>
- **描述**：AirSim 是微软开发的开源模拟器，最初专注于无人机，后来扩展支持车辆模拟。它基于 Unreal Engine（也提供 Unity 的实验性支持），提供高保真的物理引擎和传感器模拟，适用于自动驾驶研究和机器学习。
- **特点**：
  - 支持多种车辆类型（汽车、无人机）；
  - 提供逼真的环境渲染和物理模拟；
  - 兼容 Python 和 C++ API，便于集成机器学习框架。
- **维护状态**：微软已停止对该开源版本的更新，最后一个版本为 v1.8.1（2022 年 7 月）。商业后续版本以 **Project AirSim** 的形式由 IAMAI 接手，参见 [iamaisim/ProjectAirSim](https://github.com/iamaisim/ProjectAirSim)。若需活跃维护，可考虑社区分支 [Cosys-AirSim](https://github.com/Cosys-Lab/Cosys-AirSim) 等。

---

### 5. DeepDrive - 自动驾驶模拟平台

- **GitHub 地址**：<https://github.com/deepdrive/deepdrive>
- **描述**：DeepDrive 是一个基于 Unreal Engine 的自动驾驶模拟平台，专注于提供大规模数据集和训练环境。它支持端到端的深度学习模型训练，并提供丰富的传感器数据。
- **特点**：
  - 支持多摄像头和 LiDAR 数据生成；
  - 提供预构建的城市环境和交通场景；
  - 易于与 TensorFlow 或 PyTorch 集成。
- **维护状态**：该项目长期未更新（最后版本为 2.0，2018 年 5 月），更适合作为学习与历史参考。

---

## 二、把项目改为：UnLua

> 计划使用 [UnLua](https://github.com/Tencent/UnLua)（腾讯开源的 UE Lua 脚本化插件，支持 UE 4.17.x - UE 5.x）将上述项目中的部分逻辑改写为 Lua，借助热重载特性加速迭代。（待补充实践记录）

## 三、把项目改为：UnLua + Python

> 在 UnLua 的基础上进一步引入 Python（借助 UE 自带的 Python 插件或 puerts 等方案），用于工具链与数据驱动的逻辑。（待补充实践记录）

---

## 参考资料

- [Tom Looman - Action Roguelike（上游仓库）](https://github.com/tomlooman/ActionRoguelike)
- [CARLA 官方文档](https://carla.readthedocs.io/)
- [CARLA ROS Bridge](https://github.com/carla-simulator/ros-bridge)
- [Microsoft AirSim Releases](https://github.com/microsoft/AirSim/releases)
- [Tencent UnLua](https://github.com/Tencent/UnLua)
