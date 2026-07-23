+++
title = "GOAP(Goal-Oriented Action Planning)算法"
date = "2025-09-13"
lastmod = "2025-09-13"
subtitle = "让 AI 自己规划动作序列的目标驱动决策算法"
description = "介绍 GOAP(目标导向行动规划)的核心思想、工作流程与伪代码实现,对比 FSM 与行为树,并梳理 Unity/Python 主流开源实现。"
author = "小智晖"
authors = ["小智晖"]
categories = ["游戏开发"]
tags = ["gamedev", "GOAP", "AI", "游戏AI", "动作规划", "A*"]
keywords = ["GOAP", "Goal-Oriented Action Planning", "目标导向行动规划", "游戏AI", "动作规划", "A*搜索"]
toc = true
draft = false
+++

## GOAP 概述

GOAP(Goal-Oriented Action Planning，目标导向行动规划)是一种基于目标的智能决策算法，常用于游戏 AI、机器人控制等领域。它由 Jeff Orkin 在 Monolith Productions 开发游戏《F.E.A.R.》(2005)时系统化提出，并在 GDC 2006 的演讲《Three States and a Plan: The A.I. of F.E.A.R.》中介绍给业界，此后成为游戏 AI 的经典规划范式之一。

它的核心思想是:AI 通过分析当前状态与目标状态的差异，动态规划一系列动作序列（Action Sequence）,以最有效的方式达成目标。

与传统的有限状态机（FSM）或行为树（Behavior Tree）不同，GOAP 不依赖预定义的状态流转或固定行为分支，而是通过搜索最优动作组合来解决问题，具有更强的灵活性和适应性。

**GOAP 的核心特点**

- **目标驱动**:AI 明确知道"要做什么"(如"生存""攻击敌人""收集资源"),而非被动响应环境。
- **动态规划**:根据当前世界状态实时计算动作序列，适应动态变化的环境。
- **动作依赖与约束**:每个动作有明确的前提条件（Preconditions）和执行后效果（Effects）,只有满足前提才能触发，执行后会改变世界状态。
- **启发式搜索**:通常使用 A* 等算法搜索最优动作路径，平衡效率与效果。

## GOAP 的工作流程

GOAP 的决策过程可分为以下步骤。

### 步骤 1:定义目标

AI 根据当前情境（如血量低、敌人靠近）确定一个或多个目标（例如"消灭敌人""治疗自己"）。

### 步骤 2:检查目标是否已达成

若当前世界状态已满足目标的所有条件(如 `enemyDefeated: true`),则无需规划，直接结束。

### 步骤 3:规划动作序列

规划器通过搜索算法（如 A*）寻找从当前世界状态到目标状态的动作路径:

- **初始节点**:当前世界状态。
- **目标节点**:满足目标条件的世界状态。
- **扩展节点**:对于每个当前状态，尝试所有可行动作（即前提条件被满足的动作）,生成新状态（原状态 + 动作效果）。
- **路径选择**:优先选择"总成本最低"且"最接近目标"的动作序列（通过启发式函数评估）。

### 步骤 4:执行动作序列

按规划出的顺序依次执行动作，每执行一个动作后更新世界状态。若执行过程中环境变化（如敌人突然消失）,可能需要重新规划。

## GOAP 的简单代码示例（伪代码）

以下是一个简化的 GOAP 实现框架（伪代码）:

```python
# 定义世界状态(字典形式)
world_state = {"hasTool": True, "hasAmmo": False, "isEnemyNearby": True, "health": 80}

# 定义目标(需要满足的状态)
goal = {"hasAmmo": True}  # 目标:补充弹药

# 定义动作列表(按成本从低到高排序,便于演示优先选择低成本动作)
actions = [
    {
        "name": "装弹",
        "preconditions": {"hasTool": True, "hasAmmo": False},
        "effects": {"hasAmmo": True},
        "cost": 1,
    },
    {
        "name": "寻找弹药",
        "preconditions": {},
        "effects": {"hasAmmo": True},
        "cost": 3,
    },
]

# 规划器:搜索动作序列(简化版逻辑)
def plan_actions(current_state, goal, actions):
    # 实际实现需用优先队列、启发式函数等,此处简化为按顺序遍历所有可行动作
    for action in actions:
        if all(current_state.get(k, False) == v for k, v in action["preconditions"].items()):
            new_state = current_state.copy()
            new_state.update(action["effects"])  # 应用动作效果
            if all(new_state.get(k, False) == v for k, v in goal.items()):
                return [action["name"]]  # 找到直接达成目标的动作
            # 实际实现需递归规划后续动作,直到目标达成或搜索完所有可能组合
    return []  # 无可行方案

# 执行规划
action_sequence = plan_actions(world_state, goal, actions)
print("规划的动作序列:", action_sequence)  # 输出: ['装弹']
```

> 注：上述伪代码仅演示"单步即可达成目标"的最简情形，且按列表顺序返回首个匹配动作。真实 GOAP 规划器会把动作成本作为边权，用 A* 在状态空间图中搜索完整的最优动作链。

## 开源代码

- [Unity 的 GOAP 插件](https://github.com/crashkonijn/GOAP):基于 Unity 的多线程 GOAP 系统，利用 Unity Job System 进行并行规划，支持通过 Unity Package Manager、OpenUPM 或 Asset Store 安装。
- [Python pygoap](https://github.com/bitcraft/pygoap):轻量级 Python GOAP 库，通过图搜索实时生成智能体行为，附带 pygame 演示。
- [Python GOApy](https://github.com/leopepe/GOApy):面向自治代理（Autonomous Agent）的 GOAP 实现，内部使用 A* 在以世界状态为节点、动作为边的图中搜索最短路径。

## 参考

- [Three States and a Plan: The A.I. of F.E.A.R. (Jeff Orkin, GDC Vault 2006)](https://www.gdcvault.com/play/1022381/Three-States-and-a-Plan-The) —— GOAP 在商业游戏中应用的开创性演讲。
- [Applying Goal-Oriented Action Planning to Games (Jeff Orkin, AI Game Programming Wisdom 2, 2003)](https://www.sciencedirect.com/science/article/pii/B9781558605929500779) —— 系统阐述 GOAP 设计思路的经典章节。
- [crashkonijn/GOAP 官方文档](https://goap.crashkonijn.com/) —— Unity GOAP 插件的概念、配置与使用指南。
