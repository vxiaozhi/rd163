+++
title = "行为树算法"
date = "2025-09-14"
lastmod = "2025-09-14"
subtitle = "行为树算法"
description = "行为树算法"
author = "小智晖"
authors = ["小智晖"]
categories = ["gamedev"]
tags = ["gamedev", "行为树"]
keywords = []
toc = true
draft = false
+++

行为树(Behavior Tree)​​ 是一种用于描述AI行为的树状数据结构，通过节点之间的层次关系来组织复杂的行为逻辑。

## 开源项目

### BehaviorTree.CPP
- [BehaviorTree.CPP](https://github.com/BehaviorTree/BehaviorTree.CPP)

### Golang 
- [behavior3go](https://github.com/magicsea/behavior3go)
- [go-behave](https://github.com/askft/go-behave)
- [go-behaviortree](https://github.com/joeycumines/go-behaviortree) 实现了Sequence and Selector，与 PyTrees 类似

### PyTrees

PyTrees 是一个强大的 Python 行为树实现，专为机器人和其他复杂系统创建决策引擎而设计。PyTrees 提供了一个优雅的模块化框架，使复杂的决策管理变得简单。

PyTrees 可用来实现机器人在动态环境中导航或游戏 AI 角色响应玩家操作

开源代码：

- [PyTrees](https://github.com/splintered-reality/py_trees)

详细的文档：

- [py-trees.readthedocs.io](https://py-trees.readthedocs.io/en/release-2.2.x/composites.html)

基于py_trees实现的的机器人ROS扩展：

- [py_trees_ros](https://github.com/splintered-reality/py_trees_ros)
- [py-trees-ros-tutorials](https://py-trees-ros-tutorials.readthedocs.io/en/devel/tutorials.html)

## 🌳 PyTrees基本结构

### 节点类型：

1. **控制节点(Composites)** - 决定执行流程
   - `Sequence` (顺序)：所有子节点成功才算成功
   - `Selector` (选择)：直到一个子节点成功
   - `Parallel` (并行)：同时执行多个子节点

2. **执行节点(Behaviours)** - 具体行为
   - `Action`：执行具体动作
   - `Condition`：检查条件

3. **装饰节点(Decorators)** - 修饰行为
   - 重复、取反、超时等修饰
  
### 惯用模式

- idioms.pick_up_where_you_left_off 从中断处继续
- idioms.either_or 二选一
- idioms.oneshot 单次执行

## ⚡ 工作方式

- **自顶向下**执行
- **从左到右**遍历
- 每个节点返回三种状态：
  - ✅ `SUCCESS` (成功)
  - 🔄 `RUNNING` (执行中)
  - ❌ `FAILURE` (失败)


## 📊 简单示例

```
Selector (主行为)
├── Sequence (遇到敌人)
│   ├── Condition (发现敌人?)
│   └── Action (攻击)
└── Sequence (日常巡逻)
    ├── Action (移动)
    └── Action (观察)
```
