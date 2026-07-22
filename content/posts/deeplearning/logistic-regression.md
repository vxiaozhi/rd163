+++
title = "逻辑回归"
date = "2025-04-26"
lastmod = "2025-04-26"
subtitle = "从 Sigmoid 到 Softmax 的分类建模原理"
description = "逻辑回归（Logistic Regression）是工业界最常用的线性分类模型，本文梳理它与线性回归的关系、Sigmoid 与 Softmax 函数的作用，以及极大似然估计下的参数求解。"
author = "小智晖"
authors = ["小智晖"]
categories = ["deeplearning"]
tags = ["deeplearning", "机器学习", "逻辑回归", "分类算法"]
keywords = ["逻辑回归", "Logistic Regression", "Sigmoid", "Softmax", "极大似然估计", "交叉熵"]
toc = true
draft = false
+++

Logistic Regression 虽然被称为「回归」，但其实际上是一个**分类模型**，并最常用于二分类（binary classification）。它因模型简单、可并行化、可解释性强，且训练和推理代价都较低，在广告点击率预估、风控、医疗诊断等工业场景中至今仍被广泛使用，常常作为强基线（strong baseline）出现。

Logistic 回归的本质是：**假设数据服从伯努利分布（Bernoulli distribution），然后使用极大似然估计（Maximum Likelihood Estimation, MLE）做参数的求解**。这一过程在数学上等价于最小化交叉熵损失（cross-entropy loss）。

## 与线性回归的区别

逻辑回归可以理解为在线性回归的基础上加了一个 Sigmoid 函数（非线性）映射，使得它从一个回归算法变成了一个优秀的分类算法。从统计学的视角看，二者都属于**广义线性模型**（Generalized Linear Model, GLM）——线性回归假设因变量服从正态分布，使用恒等链接函数（identity link）；逻辑回归假设因变量服从伯努利分布，使用 logit 链接函数（logit link）。它们要解决的问题并不一样：

- **线性回归**解决的是回归问题，输出连续值，取值范围为实数域 $\mathbb{R}$；
- **逻辑回归**解决的是分类问题，输出离散标签，通过概率的形式表达对类别的置信度。

我们需要明确 Sigmoid 函数到底起了什么作用：

- **收窄预测范围**：线性回归在实数域范围内进行预测，而二分类的概率取值范围是 $[0,1]$，Sigmoid 把实数压缩到了 $(0,1)$ 区间；
- **改变敏感度分布**：线性回归在整个实数域上敏感度一致，而逻辑回归在 $z=0$ 附近敏感（梯度最大），在远离 0 的位置趋于饱和、梯度接近 0。这种特性让模型更加关注分类边界附近，可以提升对极端样本的鲁棒性，但也带来了「饱和区梯度消失」的问题。

## 模型形式与 Sigmoid 函数（二分类）

给定输入特征向量 $\mathbf{x} \in \mathbb{R}^n$，逻辑回归先计算一个线性组合：

$$z = \mathbf{w}^\top \mathbf{x} + b = w_1 x_1 + w_2 x_2 + \dots + w_n x_n + b$$

其中 $\mathbf{w}$ 是权重向量，$b$ 是偏置项，$z$ 通常称为 logit。然后再通过 Sigmoid（也称 logistic 函数）将其映射为概率：

$$\sigma(z) = \frac{1}{1 + e^{-z}}$$

Sigmoid 函数有几个关键性质：

- 值域为 $(0, 1)$，单调递增；
- 当 $z = 0$ 时，$\sigma(z) = 0.5$；
- 关于点 $(0, 0.5)$ 中心对称；
- 导数有简洁形式：$\sigma'(z) = \sigma(z)\,(1 - \sigma(z))$，这一性质在后面推导梯度时会非常方便。

由于 $\sigma(z) = 0.5$ 当且仅当 $z = 0$，所以**决策边界**（decision boundary）就是超平面 $\mathbf{w}^\top \mathbf{x} + b = 0$。也就是说，逻辑回归本质上是一个**线性分类器**——若希望得到非线性边界，需要先做特征工程（如多项式特征）或换用核方法、神经网络等模型。判别规则通常为：

- 若 $\sigma(z) \geq 0.5$，预测为正类（label = 1）；
- 若 $\sigma(z) < 0.5$，预测为负类（label = 0）。

阈值 $0.5$ 并非必须，可以根据精度（precision）/召回（recall）的权衡进行调整，这在样本不均衡时尤其重要。

## 损失函数：从极大似然到交叉熵

假设有 $m$ 个训练样本 $\{(\mathbf{x}^{(i)}, y^{(i)})\}_{i=1}^{m}$，其中 $y^{(i)} \in \{0, 1\}$。记 $\hat{y}^{(i)} = \sigma(\mathbf{w}^\top \mathbf{x}^{(i)} + b)$ 为模型预测为正类的概率。由于每个样本服从伯努利分布，似然函数为：

$$L(\mathbf{w}, b) = \prod_{i=1}^{m} \left(\hat{y}^{(i)}\right)^{y^{(i)}} \left(1 - \hat{y}^{(i)}\right)^{1 - y^{(i)}}$$

对似然取对数并取负号，就得到**二元交叉熵损失**（Binary Cross-Entropy）：

$$J(\mathbf{w}, b) = -\frac{1}{m} \sum_{i=1}^{m} \left[ y^{(i)} \log \hat{y}^{(i)} + (1 - y^{(i)}) \log(1 - \hat{y}^{(i)}) \right]$$

这个损失函数是凸的（convex），因此可以用梯度下降（gradient descent）找到全局最优解。

## 梯度下降求解

利用 Sigmoid 导数 $\sigma'(z) = \sigma(z)(1-\sigma(z))$ 这一性质，对损失函数求偏导，会得到一个非常优雅的结果（推导从略）：

$$\frac{\partial J}{\partial w_j} = \frac{1}{m} \sum_{i=1}^{m} (\hat{y}^{(i)} - y^{(i)})\, x_j^{(i)}, \qquad
\frac{\partial J}{\partial b} = \frac{1}{m} \sum_{i=1}^{m} (\hat{y}^{(i)} - y^{(i)})$$

向量化形式为 $\nabla_{\mathbf{w}} J = \frac{1}{m} \mathbf{X}^\top (\hat{\mathbf{y}} - \mathbf{y})$。这与线性回归均方误差下的梯度形式**完全一致**，差别只在于 $\hat{y}$ 是由 Sigmoid 输出，而非线性映射。梯度下降更新规则为：

$$w_j := w_j - \alpha \cdot \frac{1}{m} \sum_{i=1}^{m} (\hat{y}^{(i)} - y^{(i)})\, x_j^{(i)}$$

其中 $\alpha$ 是学习率（learning rate）。实际工程中常用小批量随机梯度下降（mini-batch SGD）或 L-BFGS 等拟牛顿法来加速收敛。

## 正则化

为了防止过拟合，通常在损失函数中加入正则项：

- **L2 正则**（Ridge）：$+\frac{\lambda}{2}\|\mathbf{w}\|_2^2$，权重整体趋小，模型更平滑；
- **L1 正则**（Lasso）：$+\lambda\|\mathbf{w}\|_1$，产生稀疏权重，可视为特征选择；
- **ElasticNet**：L1 与 L2 的加权组合。

在 scikit-learn 中，正则化强度由参数 `C` 控制，它是 $\lambda$ 的倒数——`C` 越小，正则越强。

## Softmax 函数（多分类）

逻辑回归自然可以从二分类推广到多分类（multiclass classification）。当类别数为 $K$ 时，模型对每个类别学一组权重 $\mathbf{w}_k$，输出 $K$ 个 logit $z_1, \dots, z_K$，然后用 **Softmax 函数**将它们归一化为概率分布：

$$\text{Softmax}(z)_i = \frac{e^{z_i}}{\sum_{j=1}^{K} e^{z_j}}, \quad i = 1, 2, \dots, K$$

可以验证：

- 每个 $\text{Softmax}(z)_i \in (0, 1)$；
- $\sum_{i=1}^{K} \text{Softmax}(z)_i = 1$。

当 $K = 2$ 时，Softmax 在数学上与 Sigmoid + 二元交叉熵等价，可以说**Sigmoid 是 Softmax 在二分类下的特例**。这种「多分类版逻辑回归」有时也被称为 Softmax 回归（Softmax Regression）或多项逻辑回归（Multinomial Logistic Regression）。

工程实现上需要注意 Softmax 的数值稳定性：由于指数函数增长很快，直接计算会溢出。常用做法是先对所有 logit 减去最大值（max-subtraction trick）：

$$\text{Softmax}(z)_i = \frac{e^{z_i - \max(\mathbf{z})}}{\sum_{j=1}^{K} e^{z_j - \max(\mathbf{z})}}$$

减去常数不会改变结果，但把指数的最大值压到 $e^0 = 1$，从而避免上溢。

对应的损失函数是**多类交叉熵**：

$$J = -\frac{1}{m} \sum_{i=1}^{m} \sum_{k=1}^{K} \mathbb{1}[y^{(i)}=k]\, \log \hat{p}_k^{(i)}$$

## 实践示例

下面使用 scikit-learn 的 `LogisticRegression` 在一个二分类数据集上演示基本流程。`LogisticRegression` 位于 `sklearn.linear_model` 模块下，默认使用 L2 正则化、`lbfgs` 求解器；若需要 L1 正则或 ElasticNet，应切换到 `saga` 求解器。

```python
from sklearn.datasets import make_classification
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report

# 1. 生成合成二分类数据
X, y = make_classification(n_samples=1000, n_features=10,
                           n_informative=5, random_state=42)

# 2. 划分训练集与测试集
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42)

# 3. 训练模型（C 越小正则越强；max_iter 视收敛情况调大）
clf = LogisticRegression(C=1.0, solver='lbfgs', max_iter=200)
clf.fit(X_train, y_train)

# 4. 预测与评估
y_pred = clf.predict(X_test)
print("Accuracy:", accuracy_score(y_test, y_pred))
print(classification_report(y_test, y_pred))

# 5. 查看学习到的权重与偏置
print("Weights shape:", clf.coef_.shape)   # (1, n_features)
print("Intercept:", clf.intercept_)
```

如果是多分类任务，scikit-learn 在较新版本中默认会直接采用多项逻辑回归（multinomial）求解；早期版本中曾提供 `multi_class='ovr'`（One-vs-Rest）和 `multi_class='multinomial'` 两种策略，新版本中 `multi_class` 参数已被弃用。

## 适用场景与局限

逻辑回归并不是万能的，但它有一系列被低估的优点：

- **可解释性强**：每个特征对应一个权重，可以解读为「对正类的贡献方向与强度」；
- **训练/推理快**：参数量与特征数同阶，可承载大规模稀疏特征（如广告 CTR 场景的 one-hot 特征）；
- **概率输出**：天然输出校准较好的概率，便于和阈值策略、AUC 指标结合；
- **可作为基线**：在尝试复杂模型之前，先跑一版逻辑回归，往往能暴露数据与标签工程上的问题。

它的主要局限也很明显：

- 只能学到**线性决策边界**，对非线性可分数据需要依赖人工特征工程；
- 对特征间的多重共线性敏感，权重估计会变得不稳定；
- 对样本不平衡敏感，通常需要配合 `class_weight='balanced'` 或重采样策略。

理解这些边界条件，才能在合适的场景下用好这个看似简单的模型。

## 参考

- [scikit-learn 官方文档：Logistic Regression](https://scikit-learn.org/stable/modules/linear_model.html#logistic-regression)
- [李沐《动手学深度学习》—— softmax 回归](https://zh.d2l.ai/chapter_linear-networks/softmax-regression.html)
- Christopher M. Bishop, *Pattern Recognition and Machine Learning*, Section 4.3.2.
- Kevin P. Murphy, *Machine Learning: A Probabilistic Perspective*, Chapter 8.