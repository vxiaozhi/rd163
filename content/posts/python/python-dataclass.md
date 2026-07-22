+++
title = "Python 的 dataclass"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "用装饰器自动生成数据类的样板代码"
description = "介绍 Python 3.7 标准库中的 dataclasses 模块,涵盖 @dataclass 装饰器、field 配置、frozen 不可变实例与 __post_init__ 钩子等核心用法。"
author = "小智晖"
authors = ["小智晖"]
categories = ["python"]
tags = ["编程语言", "python", "dataclass", "dataclasses", "PEP 557"]
keywords = ["python", "dataclass", "dataclasses", "PEP 557", "python 3.7"]
toc = true
draft = false
+++

`dataclasses` 是 Python 3.7 起进入标准库的一个模块，由 [PEP 557](https://peps.python.org/pep-0557/) 引入，作者是 Eric V. Smith。它的核心目标是：为「主要用来存储数据的类」自动生成 `__init__`、`__repr__`、`__eq__` 等样板方法（boilerplate）,让开发者把精力放在字段定义上而不是重复的 `def __init__(self, ...)`。

Python 3.6 可以通过 `pip install dataclasses` 安装官方 backport 来使用;3.7 及以上版本无需任何额外安装，直接 `from dataclasses import dataclass` 即可。

## 设计动机

在 `dataclasses` 出现之前，Python 中「定义一个数据容器类」常见做法有几种:

- 手写 `__init__`、`__repr__`、`__eq__`,代码冗长且容易写错;
- 使用 `collections.namedtuple`,但实例不可变、字段不能有默认值、不能加自定义方法，而且会与普通 tuple 比较相等，容易引发隐藏 bug;
- 使用第三方库 [attrs](https://www.attrs.org/),功能强大但不在标准库中。

PEP 526 引入的变量类型注解语法(`name: str`)给了 `dataclasses` 一个干净的基础：装饰器只需要扫描类体里带注解的变量，就能知道哪些是字段。需要注意的是,`dataclasses` 不引入任何基类或元类，被装饰的类仍然是「普通的 Python 类」,可以正常继承、可以加普通方法、可以与元类共存。它也不试图替代 `attrs`,只覆盖最常见的简单场景。

## 最小示例

```python
from dataclasses import dataclass

@dataclass
class InventoryItem:
    """Class for keeping track of an item in inventory."""
    name: str
    unit_price: float
    quantity_on_hand: int = 0

    def total_cost(self) -> float:
        return self.unit_price * self.quantity_on_hand
```

上面这段代码等价于手写一个带类型注解的 `__init__`、一个形如 `InventoryItem(name='...', unit_price=..., quantity_on_hand=...)` 的 `__repr__`,以及按字段逐个比较的 `__eq__`。在交互式环境里就能感受到差异:

```python
>>> item = InventoryItem("widget", unit_price=3.5, quantity_on_hand=10)
>>> item
InventoryItem(name='widget', unit_price=3.5, quantity_on_hand=10)
>>> item == InventoryItem("widget", 3.5, 10)
True
>>> item.total_cost()
35.0
```

## `@dataclass` 装饰器参数

`@dataclass` 是一个关键字参数 only 的装饰器，完整签名如下:

```python
@dataclass(*, init=True, repr=True, eq=True, order=False,
           unsafe_hash=False, frozen=False, match_args=True,
           kw_only=False, slots=False, weakref_slot=False)
```

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `init` | `True` | 是否生成 `__init__` |
| `repr` | `True` | 是否生成 `__repr__` |
| `eq` | `True` | 是否生成 `__eq__`(按字段比较) |
| `order` | `False` | 是否生成 `__lt__`/`__le__`/`__gt__`/`__ge__`,为 `True` 时 `eq` 必须也为 `True` |
| `unsafe_hash` | `False` | 强制生成 `__hash__`,通常不建议 |
| `frozen` | `False` | 生成会抛出 `FrozenInstanceError` 的 `__setattr__`/`__delattr__`,模拟不可变 |
| `match_args` | `True` | 生成 `__match_args__`(Python 3.10+,服务于 `match` 语句) |
| `kw_only` | `False` | 所有字段变为关键字参数（Python 3.10+） |
| `slots` | `False` | 生成 `__slots__` 并返回一个新类（Python 3.10+） |
| `weakref_slot` | `False` | 额外添加 `__weakref__` 槽，要求 `slots=True`(Python 3.11+) |

关于 `__hash__` 的隐式规则值得单独记住:

- `eq=True` 且 `frozen=True` → 自动生成 `__hash__`,实例可哈希;
- `eq=True` 且 `frozen=False` → 把 `__hash__` 设为 `None`,实例不可哈希(放进集合或当字典键会抛 `TypeError`);
- `eq=False` → 不动 `__hash__`,沿用父类的行为。

### 不可变与可排序的例子

```python
from dataclasses import dataclass, field

@dataclass(frozen=True, order=True)
class Point:
    x: float
    y: float
    tags: list = field(default_factory=list, compare=False)
```

`frozen=True` 让 `Point` 实例不能被修改，因此可以放进 `set` 或当 `dict` 的键;`order=True` 顺便生成了排序方法。`compare=False` 把 `tags` 排除在比较和排序之外，否则两个含不同 `tags` 的点在排序时会被干扰。

## `field()`:精细控制每个字段

简单的「类型 + 默认值」不够用时，用 `dataclasses.field()` 单独配置某个字段:

```python
from dataclasses import dataclass, field

@dataclass
class Card:
    rank: str
    suit: str
    metadata: dict = field(default_factory=dict, repr=False)
```

`field()` 的常用关键字参数包括 `default`、`default_factory`、`init`、`repr`、`hash`、`compare`、`metadata`、`kw_only`(3.10+)以及 `doc`(3.14+)。其中 `default` 和 `default_factory` 互斥，前者是固定默认值，后者接收一个零参可调用对象（callable）,每次实例化时调用一次来生成新默认值。

### 可变默认值的陷阱

这是 `dataclasses` 中最容易踩坑的地方：直接把 `list`、`dict`、`set` 当作默认值会被所有实例共享（因为默认值实际作为类属性存在）。所以装饰器会主动检测并报错:

```python
@dataclass
class Bad:
    items: list = []   # ValueError: mutable default for field items is not allowed
```

正确写法是使用 `default_factory`:

```python
@dataclass
class Good:
    items: list = field(default_factory=list)

assert Good().items is not Good().items   # 每个实例都有独立的列表
```

自 Python 3.11 起，检测策略从「按类型名单(`list`/`dict`/`set`)」改为「检查默认值是否 unhashable」,覆盖面更广。

## `__post_init__` 与 `InitVar`

生成的 `__init__` 会在末尾调用 `__post_init__`(如果定义了),常用于依赖其他字段的派生字段:

```python
from dataclasses import dataclass, field

@dataclass
class C:
    a: float
    b: float
    c: float = field(init=False)

    def __post_init__(self):
        self.c = self.a + self.b
```

如果有些值只想在构造时传入、不作为字段保存，可以用 `dataclasses.InitVar` 声明，它会被传给 `__post_init__` 但不会出现在 `fields()` 返回值里。

## 常用模块级函数

| 函数 | 作用 |
|------|------|
| `fields(class_or_instance)` | 返回这个数据类全部 `Field` 对象组成的元组(不含 `ClassVar` 与 `InitVar`) |
| `asdict(instance)` | 递归地把实例转成 `dict`,对非数据类对象会做深拷贝 |
| `astuple(instance)` | 递归地把实例转成 `tuple` |
| `replace(obj, /, **changes)` | 基于 `__init__` 生成一个改了若干字段的新实例，会重新触发 `__post_init__` |
| `is_dataclass(obj)` | 判断对象是否是数据类或其实例 |
| `MISSING` | 表示「没有默认值」的哨兵值（sentinel） |

`asdict`/`astuple` 默认会做递归深拷贝，如果只想要浅拷贝，可以手动构造:

```python
{f.name: getattr(obj, f.name) for f in fields(obj)}
```

## 继承行为

数据类之间可以互相继承。字段按反向 MRO(从 `object` 开始)收集，基类字段在前、子类字段在后;同名字段以子类为准。需要注意，生成的 `__init__` 不会调用基类的 `__init__`,如果需要这种行为，应显式在 `__post_init__` 里调用 `super().__post_init__()`。

## 一些使用 dataclasses 的应用

- [lcovparser.py](https://github.com/ChrisTimperley/lcovparser.py/blob/main/lcovparser.py):一个纯 Python 编写的 LCOV trace 文件解析器，仓库根目录的 `lcovparser.py` 即用 `dataclass` 定义 AST 节点，Apache-2.0 协议。
- CPython 标准库自身也大量使用 `dataclasses`,例如 `graphlib` 的 `CycleError` 上下文、`statistics` 模块的内部结构等。

## 何时不适合用 dataclass

`dataclasses` 是一把称手的「轻量级」工具，但并非万能。以下场景建议考虑其它方案:

- 需要参数校验、类型转换、槽位约束等高级特性 → [attrs](https://www.attrs.org/) 或 [Pydantic](https://docs.pydantic.dev/);
- 需要严格不可变、哈希友好、可作字典键的轻量值对象 → `typing.NamedTuple` 或 `frozen=True` 的 dataclass;
- 需要 ORM 映射、关系建模 → Django Model、SQLAlchemy ORM;
- 单纯的常量枚举 → `enum.Enum`。

## 参考

- [dataclasses — Python 官方文档](https://docs.python.org/3/library/dataclasses.html)
- [PEP 557 – Data Classes](https://peps.python.org/pep-0557/)
- [掌握 Python 的 dataclass，让你的代码更简洁优雅](https://www.cnblogs.com/wang_yb/p/18077397)
- [attrs 项目](https://www.attrs.org/)
