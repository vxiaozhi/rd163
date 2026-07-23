+++
title = "线性回归"
date = "2025-04-26"
lastmod = "2025-04-26"
subtitle = "从解析解到梯度下降的原理与手写实现"
description = "介绍线性回归的建模假设、解析解与梯度下降两种求解方式，并给出一份不依赖任何机器学习框架的手写实现。"
author = "小智晖"
authors = ["小智晖"]
categories = ["deeplearning"]
tags = ["线性回归", "梯度下降", "解析解", "机器学习"]
keywords = ["线性回归", "梯度下降", "解析解", "损失函数", "深度学习"]
toc = true
draft = false
+++

回归（regression）是一类能为一个或多个自变量与因变量之间关系建模的方法。在自然科学和社会科学领域，回归经常用来表示输入与输出之间的关系。

线性回归（linear regression）的历史可以追溯到 19 世纪初（最小二乘法由勒让德于 1805 年首次发表），它在回归的各种标准工具中最简单也最流行。线性回归基于几个简单的假设：首先，假设自变量 `x` 与因变量 `y` 之间的关系是线性的，即 `y` 可以表示为 `x` 中元素的加权和，这里通常允许包含观测值的一些噪声；其次，我们假设任何噪声都比较正常，例如噪声服从正态分布。

模型参数（model parameters）的求解需要两样东西：

- （1）一种模型质量的度量方式，通常为损失函数（loss function）；
- （2）一种能够更新模型以提高预测质量的方法，通常包括求解解析解和随机梯度下降（stochastic gradient descent，SGD）两种方式。

## 解析解

线性回归刚好是一个很简单的优化问题。与其他大部分模型不同，线性回归的解可以用一个公式简洁地表达出来，这类解叫作解析解（analytical solution）。

首先，我们将偏置 `b` 合并到权重 `w` 中，方法是在包含所有参数的矩阵中附加一列。此时预测问题是最小化 ‖y − Xw‖²，这在损失平面上只有一个临界点，且对应于整个区域的损失极小值点。将损失关于 `w` 的导数设为 0，便可得到解析解：

```
w* = (XᵀX)⁻¹ Xᵀy
```

这就是所谓的正规方程（normal equation）。

像线性回归这样的简单问题存在解析解，但并不是所有问题都存在解析解。解析解可以进行很好的数学分析，但它对问题的限制非常严格，因此在深度学习中难以广泛应用。

## 随机梯度下降

即使我们无法得到解析解，仍然可以有效地训练模型。在许多任务上，那些难以优化的模型反而效果更好，因此，弄清楚如何训练这些难以优化的模型就显得非常重要。

梯度下降（gradient descent）几乎可以用来优化所有的深度学习模型。它通过不断地在损失函数递减的方向上更新参数来降低误差。

梯度下降最简单的用法是计算损失函数（数据集中所有样本的损失均值）关于模型参数的导数（这里也称为梯度）。但直接这样做在实际中可能会非常慢：因为每一次更新参数之前，都需要遍历整个数据集。因此，我们通常会在每次需要计算更新时随机抽取一小批样本，这种变体叫做小批量随机梯度下降（minibatch stochastic gradient descent）。

## 二元线性回归模型训练实例

下面给出一个完全手写的二元线性回归模型训练实例，涵盖从数据生成到模型训练的全过程：

- 完全自主实现；
- 不使用任何机器学习框架；
- 手动实现梯度计算与参数更新。

训练过程：

- 手工计算均方误差（MSE）损失；
- 手动推导梯度计算公式：
  - ∂Loss/∂w₁ = (2/n)Σ(y_pred − y_true)·x₁
  - ∂Loss/∂w₂ = (2/n)Σ(y_pred − y_true)·x₂
  - ∂Loss/∂b = (2/n)Σ(y_pred − y_true)
- 参数更新公式：θ ← θ − α·∇θ。

> 说明：下文代码中实现的是**批量梯度下降**（batch gradient descent），即每次更新遍历全部样本；其损失采用平方误差（未除以 2），梯度公式中的常数因子 `2` 会被吸收进学习率，因此代码里的累积梯度写作 `error * x`，更新时再除以 `n`。

关于线性回归梯度下降的详细推导，可参考这篇文章：[线性回归的求解：矩阵方程和梯度下降、数学推导及 NumPy 实现](https://zhuanlan.zhihu.com/p/143150436)。

```python
import random

# 数据生成函数（手动创建训练集）
def generate_data(num_samples=100):
    # 真实参数：w1=2, w2=-3, b=5
    w_true = [2, -3]
    b_true = 5
    data = []

    for _ in range(num_samples):
        # 生成两个特征（范围 0-10）
        x1 = random.uniform(0, 10)
        x2 = random.uniform(0, 10)
        # 计算目标值并添加噪声
        noise = random.gauss(0, 1)  # 高斯噪声
        y = w_true[0] * x1 + w_true[1] * x2 + b_true + noise
        data.append(([x1, x2], y))

    return data


# 模型定义
class LinearRegression:
    def __init__(self):
        # 手动初始化参数
        self.w = [random.uniform(-1, 1) for _ in range(2)]  # 权重
        self.b = random.uniform(-1, 1)                       # 偏置项

    def predict(self, x):
        # 前向计算：y = w1*x1 + w2*x2 + b
        return self.w[0] * x[0] + self.w[1] * x[1] + self.b

    def train(self, data, learning_rate=0.01, epochs=100):
        n = len(data)

        for epoch in range(epochs):
            total_loss = 0
            grad_w = [0.0, 0.0]  # 梯度累积
            grad_b = 0.0

            # 遍历所有样本（批量梯度下降）
            for x, y_true in data:
                # 计算预测值
                y_pred = self.predict(x)

                # 计算损失（平方误差）
                loss = (y_pred - y_true) ** 2
                total_loss += loss

                # 计算梯度（手工求导，常数因子 2 被吸收进学习率）
                error = y_pred - y_true
                grad_w[0] += error * x[0]
                grad_w[1] += error * x[1]
                grad_b += error

            # 参数更新（批量梯度下降）
            self.w[0] -= learning_rate * (grad_w[0] / n)
            self.w[1] -= learning_rate * (grad_w[1] / n)
            self.b -= learning_rate * (grad_b / n)

            # 打印训练进度
            if (epoch + 1) % 10 == 0:
                avg_loss = total_loss / n
                print(f"Epoch {epoch + 1}/{epochs} | Loss: {avg_loss:.4f}")


# 训练流程
if __name__ == "__main__":
    # 生成训练数据（10000 个样本）
    train_data = generate_data(10000)

    # 初始化模型
    model = LinearRegression()
    print("初始参数：")
    print(f"w1={model.w[0]:.3f}, w2={model.w[1]:.3f}, b={model.b:.3f}")

    # 开始训练
    model.train(data=train_data, learning_rate=0.001, epochs=200000)

    # 显示最终参数
    print("\n训练后参数：")
    print(f"w1={model.w[0]:.3f} (真实值：2.000)")
    print(f"w2={model.w[1]:.3f} (真实值：-3.000)")
    print(f"b={model.b:.3f} (真实值：5.000)")

    # 测试预测
    test_sample = [3.0, 4.0]
    pred = model.predict(test_sample)
    true_value = 2 * 3.0 + (-3) * 4.0 + 5
    print(f"\n测试样本预测：{pred:.3f} (真实值：{true_value:.3f})")
```

## 参考

- [李沐《动手学深度学习》—— 线性回归](https://zh.d2l.ai/chapter_linear-networks/linear-regression.html)
- [线性回归的求解：矩阵方程和梯度下降、数学推导及 NumPy 实现](https://zhuanlan.zhihu.com/p/143150436)
