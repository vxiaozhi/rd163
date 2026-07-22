+++
title = "行为树算法"
date = "2025-09-14"
lastmod = "2025-09-14"
subtitle = "用树状结构组织 AI 行为逻辑的通用方案"
description = "介绍行为树的基本概念、节点类型与工作方式,并梳理 C++/Go/Python(PyTrees) 三类主流开源实现。"
author = "小智晖"
authors = ["小智晖"]
categories = ["游戏开发"]
tags = ["gamedev", "行为树", "AI", "PyTrees", "游戏AI"]
keywords = ["行为树", "Behavior Tree", "PyTrees", "游戏AI", "决策树", "BehaviorTree.CPP"]
toc = true
draft = false
+++

行为树（Behavior Tree）是一种用于描述 AI 行为的树状数据结构，通过节点之间的层次关系来组织复杂的行为逻辑。它最初在游戏 AI 领域流行，后被广泛应用于机器人决策系统，逐渐成为替代传统有限状态机（FSM）的通用方案。

## 开源项目

### BehaviorTree.CPP

- [BehaviorTree.CPP](https://github.com/BehaviorTree/BehaviorTree.CPP):基于 C++17 的行为树框架，定位灵活、易用、可响应且高效。主要用于机器人，也可用于游戏 AI。支持异步非阻塞动作、并发执行的响应式行为、运行时加载 XML 定义的树、类型安全的节点间数据流，以及内置的日志与分析工具。

### Golang

- [behavior3go](https://github.com/magicsea/behavior3go):从 behavior3 移植的 Go 行为树库，可配合在线可视化编辑器使用。采用无状态树结构，状态保存在 blackboard 中，适合 MMOARPG 类游戏的 AI 逻辑。
- [go-behave](https://github.com/askft/go-behave):一个可扩展的 Go 行为树库，提供 Composite(Sequence、Selector、Random 变体)、Decorator(Inverter、Repeater、Delayer)与 Leaf 三类节点。
- [go-behaviortree](https://github.com/joeycumines/go-behaviortree):简洁的 Go 行为树实现，核心是无状态的 `Selector` 与 `Sequence`,并提供响应式行为树的辅助工具。

### PyTrees

PyTrees 是一个强大的 Python 行为树实现，专为机器人和其他复杂系统构建决策引擎而设计。它提供了一个优雅的模块化框架，让复杂的决策管理变得简单清晰。

PyTrees 常用于实现机器人在动态环境中的自主导航，或游戏 AI 角色对玩家操作的响应。

开源代码:

- [PyTrees](https://github.com/splintered-reality/py_trees)

详细文档:

- [py-trees.readthedocs.io(Composites)](https://py-trees.readthedocs.io/en/release-2.2.x/composites.html)

基于 py_trees 实现的 ROS 扩展:

- [py_trees_ros](https://github.com/splintered-reality/py_trees_ros)
- [py-trees-ros-tutorials](https://py-trees-ros-tutorials.readthedocs.io/en/devel/tutorials.html)

## PyTrees 基本结构

### 节点类型

1. **控制节点（Composites）** —— 决定执行流程
   - `Sequence`(顺序):所有子节点都成功才算成功。
   - `Selector`(选择):依次尝试，直到有一个子节点成功为止。
   - `Parallel`(并行):同时执行多个子节点，由策略（SuccessOnAll / SuccessOnOne / SuccessOnSelected）决定成功条件。

2. **执行节点（Behaviours）** —— 具体行为
   - `Action`:执行具体动作。
   - `Condition`:检查条件是否满足。

3. **装饰节点（Decorators）** —— 修饰子节点行为
   - 例如重复（Repeater）、取反（Inverter）、超时（Timeout）等。

### 惯用模式（Idioms）

PyTrees 提供了几种开箱即用的子树模式:

- `idioms.pick_up_where_you_left_off`:从中断处继续，避免任务被高优先级行为打断后从头开始。
- `idioms.either_or`:二选一，类似 Selector 但无优先级抢占，保证被选中的子树执行完毕。
- `idioms.oneshot`:单次执行，某个模式只完整执行一次。

## 工作方式

- **自顶向下**执行。
- **从左到右**遍历。
- 每个节点在一次 tick 中返回以下三种状态之一:
  - `SUCCESS`(成功)
  - `RUNNING`(执行中)
  - `FAILURE`(失败)

> 注:PyTrees 内部还存在一个 `INVALID` 状态，用于节点尚未启动或已被重置的内部记账，通常不需要在业务逻辑中处理。

## 简单示例

下面是一个典型的"遇到敌人则攻击，否则巡逻"的行为树结构:

```text
Selector (主行为)
├── Sequence (遇到敌人)
│   ├── Condition (发现敌人?)
│   └── Action (攻击)
└── Sequence (日常巡逻)
    ├── Action (移动)
    └── Action (观察)
```

执行流程:Selector 首先尝试左侧"遇到敌人"分支;若未发现敌人，Condition 返回失败，整个 Sequence 失败，Selector 继续尝试右侧"日常巡逻"分支。

## 参考

- [Behavior Trees in Robotics and AI (Colledanchise & Ögren)](https://link.springer.com/book/10.1007/978-3-030-42902-5) —— 行为树在机器人领域的经典学术著作。
- [py_trees 官方文档](https://py-trees.readthedocs.io/) —— PyTrees 的概念、组合节点、装饰器、Blackboard、Visitor 等完整说明。
- [BehaviorTree.CPP 文档](https://www.behaviortree.dev/) —— C++ 行为树框架的详细使用指南。