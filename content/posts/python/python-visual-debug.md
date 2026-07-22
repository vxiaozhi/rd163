+++
title = "Python 可视化调试"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从断点到执行轨迹:三种用图形界面理解 Python 运行时的方式"
description = "介绍 Python 中三种可视化调试思路:VS Code 图形化调试器、PyCharm 内置调试器,以及基于时间线的执行轨迹工具 VizTracer,涵盖安装、用法与适用场景。"
author = "小智晖"
authors = ["小智晖"]
categories = ["python"]
tags = ["编程语言", "python", "调试", "性能分析", "VizTracer"]
keywords = ["python", "可视化调试", "VizTracer", "VS Code", "PyCharm", "debugpy"]
toc = true
draft = false
+++

「可视化调试」在 Python 语境下有两层含义:一是用图形界面(GUI)的调试器,在断点处查看变量、调用栈与求值表达式;二是把程序的执行过程可视化,用时间线、火焰图等呈现函数调用顺序与耗时。前者解决「程序为什么是这个状态」,后者解决「程序究竟是怎么跑的」。本文介绍三种常用方案。

## 方法 1:VS Code

VS Code 通过官方的 **Python 扩展**自动附带 **Python Debugger** 扩展(基于 [`debugpy`](https://github.com/microsoft/debugpy)),无需额外安装即可对脚本、Web 应用、远程进程做断点调试。

### 启动调试

最简单的入口是编辑器右上角运行按钮旁的下拉箭头,选择 **Python Debugger: Debug Python File**。对于 Flask、Django、FastAPI 等 Web 项目,Run and Debug 视图中的「Show all automatic debug configurations」会根据项目结构自动生成配置。

如果需要传参或自定义启动逻辑,可以在 `.vscode/launch.json` 中显式配置:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "debugpy",
      "request": "launch",
      "name": "当前文件",
      "program": "${file}",
      "console": "integratedTerminal",
      "justMyCode": true
    }
  ]
}
```

注意 `type` 字段应使用 `"debugpy"`,旧的 `"python"` 值已废弃。`request` 可选 `"launch"`(启动新进程)或 `"attach"`(附加到已运行进程)。

### 关键能力

- **断点 / 条件断点 / 日志断点(Logpoint)**:条件断点支持按表达式或命中次数(`>`、`>=`、`%`)触发;Logpoint 可在不暂停执行的情况下输出日志。
- **调用栈、变量、Watch、Debug Console**:暂停时可查看局部/全局变量、表达式求值,Debug Console 中的表达式在远程调试时运行于远端机器。
- **代码热重载**:`"autoReload": {"enable": true}` 在命中断点后修改源码会自动重启调试器。
- **子进程调试**:通过 `subProcess` 设置开启多目标调试。
- **远程调试**:基于 SSH 隧道或直接网络附加,`pathMappings` 用于映射本地工作区与远端路径。

## 方法 2:PyCharm

PyCharm 内置完整调试器,在编辑器任意行右键选择 **Debug <filename>** 即可启动调试会话;复杂场景(需传参或预执行步骤)可通过 Run/Debug Configuration 自定义。

### 主要功能

- **断点**:可设置触发条件,精确控制程序在何处冻结。
- **单步执行(Stepping)**:Step Over / Step Into / Step Out,逐步追踪代码路径。
- **状态检视**:变量视图、线程状态、堆对象分布;甚至可以主动抛出异常以测试异常处理逻辑。
- **Evaluate Expression**:在暂停期间执行任意 Python 代码。
- **Watches**:跟踪特定表达式随程序执行的变化。

### 后端实现

从 Python 3.9 起,PyCharm 默认使用 **debugpy**(基于 Debug Adapter Protocol,DAP)作为调试后端,与标准 Python 调试工作流和外部调试适配器兼容;旧的 **pydevd** 仍可作为备选,在 Settings | Python Debugger 中切换。需要注意的是,debugpy 目前尚不支持 SSH/Docker/Vagrant 等远程解释器、Attach to Process 以及 Scrapy、远程 Jupyter 等场景,此时需回退到 pydevd 或 Attach to DAP。

## 方法 3:VizTracer

[**VizTracer**](https://github.com/gaogaotiantian/viztracer) 由 Tian Gao 开发,采用 Apache 2.0 协议,定位为「低开销的日志/调试/性能分析工具」,能够 trace 并可视化 Python 代码的执行过程。它记录每次函数进入与退出,并在前端用 [Perfetto](https://perfetto.dev/) 渲染时间线,适合排查复杂的并发执行顺序、死锁或性能热点。

### 核心特性

- **时间线可视化**:按函数调用顺序在时间轴上展开,键盘 `A`/`W`/`S`/`D` 缩放与导航。
- **低开销**:作者声称是「市场上最快的 tracer 之一」。Python 3.12+ 使用 `sys.monitoring`(替代 `sys.setprofile`),在常见场景下开销可低于 1x,「明显快于 cProfile」。纯递归函数在 Python 3.11+ 上可能产生 3x-4x 开销。
- **并发支持**:threading、multiprocessing、subprocess、asyncio,以及 PyTorch 原生/GPU 事件(`--log_torch`)。
- **无需改源码**:绝大多数功能零侵入,命令行直接替换 `python3` 即可。
- **大数据量渲染**:可平滑渲染 GB 级 trace。
- **远程 attach**:可附加到任意 Python 进程进行 trace。

### 安装与基本用法

```bash
pip install viztracer
```

可选安装 `orjson` 以加速 JSON 序列化;若未安装,VizTracer 会自动回退到标准库 `json`。

**命令行用法**(直接替换 `python3`):

```bash
# 最简形式,生成默认的 result.json
viztracer my_script.py arg1 arg2

# 生成 HTML 报告并在 trace 完成后自动打开
viztracer -o result.html --open my_script.py arg1 arg2

# trace 一个模块(等价于 python -m)
viztracer -m your_module

# trace 控制台脚本(如 Flask)
viztracer flask run

# 启用 PyTorch 原生/GPU 事件
viztracer --log_torch your_model.py
```

**Python 内联用法**:

```python
from viztracer import VizTracer

tracer = VizTracer()
tracer.start()
# 你的代码
tracer.stop()
tracer.save()
```

也支持 `with` 上下文管理器:

```python
with VizTracer(output_file="optional.json") as tracer:
    # 你的代码
    ...
```

**Jupyter Notebook** 提供了 cell magic:

```python
%load_ext viztracer
%%viztracer
# 单元格内的代码会被自动 trace
```

### 查看结果

默认输出 `result.json`(Chrome Trace Event 格式,兼容 Perfetto)。通过 `vizviewer` 启动本地 HTTP 服务器查看:

```bash
vizviewer result.json                    # 打开单个 trace 文件
vizviewer ./                             # 显示目录下所有 trace 文件
vizviewer --use_external_processor result.json  # 用于超大 trace
vizviewer --server_only result.json      # 不自动打开浏览器
vizviewer --once result.json             # 一次性查看,不留常驻服务
```

默认监听 `http://localhost:9001`,在 UI 中选中若干 slice 后可选择 **Slice Flamegraph** 生成火焰图。VizTracer 还提供官方 **VS Code 扩展**,可在编辑器内直接查看 trace。

### 过滤与增强日志

为避免 trace 噪音,VizTracer 支持多种过滤选项:最小持续时间(min duration)、最大栈深度(max stack depth)、按文件 include/exclude、忽略 C 函数、稀疏日志(sparse log)。它还能在不改源码的前提下,通过正则记录变量值、函数入参、返回值、异常抛出、GC 事件与 audit 事件;也支持自定义 instant / variable / duration 事件,效果「类似 print 调试,但能看到这条 print 在整个 trace 中发生的时间点」。

## 如何选择

| 场景 | 推荐工具 |
|---|---|
| 单步调试、查看局部变量、条件断点 | VS Code / PyCharm(按团队习惯选) |
| Web 框架(Django/Flask/FastAPI)调试 | VS Code 自动配置 或 PyCharm |
| 远程/容器内调试 | VS Code (`attach` + `pathMappings`) 或 PyCharm(pydevd) |
| 理解并发执行顺序、排查死锁、asyncio 流程 | VizTracer |
| 性能热点定位、火焰图分析 | VizTracer(时间线 + Flamegraph) |
| PyTorch 训练过程 trace | VizTracer(`--log_torch`) |

断点式调试器(VS Code、PyCharm)回答「为什么程序此刻处于这种状态」,而 VizTracer 回答「程序究竟是怎么跑到这里的」。两者互补——日常排错用断点足够,涉及并发、异步或性能分析时,VizTracer 的时间线视角往往能一眼看出问题。

## 参考

- [VizTracer — GitHub](https://github.com/gaogaotiantian/viztracer)
- [Perfetto — Trace UI 后端](https://perfetto.dev/)
- [VS Code — Python debugging 官方文档](https://code.visualstudio.com/docs/python/debugging)
- [debugpy — GitHub](https://github.com/microsoft/debugpy)
- [PyCharm — Debugging code 官方文档](https://www.jetbrains.com/help/pycharm/debugging-code.html)
