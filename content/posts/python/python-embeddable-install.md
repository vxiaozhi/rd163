+++
title = "Python embeddable 版本安装过程记录"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Windows 下用 get-pip.py 给 embeddable 包配置 pip 的踩坑笔记"
description = "记录 Windows 下 Python embeddable 包安装 pip 时遇到 No module named pip 的原因，以及通过修改 python310._pth 修复模块查找路径的方法。"
author = "小智晖"
authors = ["小智晖"]
categories = ["python"]
tags = ["Python", "Windows", "环境搭建", "pip", "embeddable"]
keywords = ["Python embeddable", "pip", "get-pip.py", "python310._pth", "Windows", "Python 3.10"]
toc = true
draft = false
+++

- 操作系统：Windows 11
- Python 版本：Python 3.10

## Step 1：安装 Python 3.10

从下载列表 [Python 3.10.0](https://www.python.org/downloads/release/python-3100/) 可以看出，Installer 版本的安装文件大小比 Embeddable 版本大很多：

```text
Windows installer (32-bit)            25.9 MB
Windows embeddable package (64-bit)    8.1 MB
```

下载好之后，解压到一个文件夹即可。这时候进入该文件夹，既看不到 `Scripts`，也看不到 `Lib\site-packages`，也就是说这个 Python 本身不带 pip。

```text
$ tree
.
├── LICENSE.txt
├── _asyncio.pyd
├── _bz2.pyd
├── _ctypes.pyd
├── _decimal.pyd
├── _elementtree.pyd
├── _hashlib.pyd
├── _lzma.pyd
├── _msi.pyd
├── _multiprocessing.pyd
├── _overlapped.pyd
├── _queue.pyd
├── _socket.pyd
├── _sqlite3.pyd
├── _ssl.pyd
├── _uuid.pyd
├── _zoneinfo.pyd
├── libcrypto-1_1.dll
├── libffi-7.dll
├── libssl-1_1.dll
├── pyexpat.pyd
├── python.cat
├── python.exe
├── python3.dll
├── python310._pth
├── python310.dll
├── python310.zip
├── pythonw.exe
├── select.pyd
├── sqlite3.dll
├── unicodedata.pyd
├── vcruntime140.dll
├── vcruntime140_1.dll
└── winsound.pyd

0 directories, 34 files
```

可以打开一个 `cmd` 窗口验证一下：运行 `python` 进入交互式控制台，然后通过以下方式退出（或按 `Ctrl+Z` 再回车）：

```python
import sys
sys.exit()
```

## Step 2：安装 pip

参考：[get-pip.py (GitHub)](https://github.com/pypa/get-pip)。

下载安装脚本 [get-pip.py](https://bootstrap.pypa.io/get-pip.py)，保存为文件 `get-pip.py`，放在任意目录均可。然后在 `cmd` 中进入该目录，执行：

```bash
python get-pip.py
```

脚本会把 pip、setuptools、wheel 三个包都装上（Python 3.10 仍会默认安装 setuptools 和 wheel），默认安装路径为 `Lib\site-packages\`，并在 `Scripts\` 目录下生成几个可执行文件。

本以为 pip 已经可以用了，但这时候无论是执行 `pip`，还是执行 `python -m pip`，都会失败，提示找不到模块 pip：

```text
ModuleNotFoundError: No module named 'pip'
```

我起初想通过设置 `PYTHONPATH` 环境变量来指向 site-packages 文件夹，但不起效。**原因后来才弄明白**：当 `python310._pth` 文件存在时，Python 会进入隔离模式（isolated mode），**所有注册表和环境变量（包括 `PYTHONPATH`）都会被忽略**，所以改环境变量这条路是走不通的。

最后找到文件 `python310._pth`，在原有内容下面添加一行（注意：路径用相对路径，即相对于 `python.exe` 所在目录的路径；反斜杠不用转义）：

```text
Lib\site-packages\
```

这一行指向新安装的 pip 等模块所在的 site-packages 文件夹。保存后新开一个 `cmd` 窗口，再执行 pip，就没问题了。

> 补充：官方文档给出的更规范做法是直接在 `python310._pth` 中取消注释 `import site` 一行。启用 site 模块后，site-packages 会被自动加入 `sys.path`，效果更完整。本文这种手动添加路径行的方式也能让 pip 本身可用，但如果安装的第三方包依赖 site 机制（例如需要读取 `.pth` 文件），建议改用 `import site` 的方式。

## Step 3：验证

要查看 Python 当前的模块查找路径，可以执行：

```bash
python -m site
```

它会输出当前 Python 的模块寻址路径，可用于检验你的路径配置是否生效。

## 参考

- [Python 官方文档：The Embeddable Package（Windows）](https://docs.python.org/3.10/using/windows.html#the-embeddable-package)
- [Python 官方文档：Finding Modules（`._pth` 文件说明）](https://docs.python.org/3.10/using/windows.html#finding-modules)
- [pip 官方文档：Installing pip with get-pip.py](https://pip.pypa.io/en/stable/installation/)
- [get-pip.py（GitHub 仓库）](https://github.com/pypa/get-pip)
