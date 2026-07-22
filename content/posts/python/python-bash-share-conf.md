+++
title = "Python 与 bash 脚本共享配置文件的最佳实践"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "让两种语言零第三方依赖读取同一份配置"
description = "介绍 Python 与 bash 脚本共享同一份 env 配置文件的实践：bash 通过 source 或 set -a 加载，Python 通过 env 注入环境变量或使用 pydantic-settings 读取，并附 pydantic v2 BaseSettings 的正确用法。"
author = "小智晖"
authors = ["小智晖"]
categories = ["python"]
tags = ["编程语言", "python", "bash", "配置管理", "pydantic", "环境变量"]
keywords = ["python", "bash", "env 配置", "pydantic-settings", "BaseSettings", "环境变量"]
toc = true
draft = false
+++

同一个工程的代码中常常会同时包含 Python 代码和 bash 脚本，不可避免地会用到配置文件。某些场景下，这两种语言需要共享同一份配置。怎么实现呢？一般有两种方案：

1. 使用不同格式的配置文件，例如 bash 用 `.env`，Python 用 JSON。
2. 使用相同格式的配置文件，例如两者都用 `.env` 或 JSON。

显然，第二种方式更好：第一种方式需要维护两份不同格式的配置，在相互转换时容易出现不一致。

那么，用什么格式的配置文件能让 bash 和 Python 在**不引入第三方库**的前提下都方便地读取呢？

经过实践，我发现用 env 文件即可。假设配置文件名为 `conf/cov.env`，格式如下：

```bash
# 项目源码根目录
SOURCE_PROJECT_DIR=/data/home/xx/code-coverage

# 每个文件最低代码覆盖率
MIN_COVERAGE_RATE=0.6

# lcov max remove count
LCOV_MAX_REMOVE_COUNT=10
```

## bash

在 bash 中可以通过 `source` 加载配置：

```bash
#!/bin/bash

source conf/cov.env

# ...
```

需要注意的是，`source` 只会把变量注入到当前 shell，并不会自动导出给子进程。如果后续命令（例如子脚本、子进程）也需要读取这些变量，可以改用 `set -a` 自动导出：

```bash
#!/bin/bash

set -a
source conf/cov.env
set +a

# ...
```

## Python

Python 侧可以在启动时把配置文件中的键值对以环境变量的方式注入到进程：

```bash
#!/bin/bash

env $(grep -v '^#' conf/cov.env | xargs) python3 src/main.py
```

随后在 `main.py` 里按常规方式读取环境变量即可：

```python
import os

source_project_dir = os.environ.get("SOURCE_PROJECT_DIR", "/xxx")
```

> 这种 `env $(grep ... | xargs)` 的写法对包含空格或特殊字符的值不够健壮,仅适合简单配置。如果值中有空格,建议改用多行写法:
>
> ```bash
> set -a
> source conf/cov.env
> set +a
> python3 src/main.py
> ```
>
> 注意 `set +a` 只是取消自动导出,必须单独成行;不要写成 `set +a python3 ...`,那样并不会运行 python。或使用专门的 dotenv 解析库(python-dotenv、pydantic-settings)。

## 用 pydantic-settings 更优雅地管理

除了直接读取环境变量，Python 生态也提供了专门的库来管理配置。Pydantic v2 起将 `BaseSettings` 拆分到了独立的 `pydantic-settings` 包，功能更强大，使用前需要先安装：

```bash
pip install pydantic-settings
```

基本用法如下：

```python
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    api_key: str = Field(..., description="API 访问密钥")
    timeout: float = 5.0
    debug: bool = False

    model_config = SettingsConfigDict(
        env_file=".env",        # 从 .env 文件加载
        env_file_encoding="utf-8",
    )

# 加载优先级：
# 1. 显式传入的参数（Settings(api_key="abc")）
# 2. 环境变量
# 3. .env 文件中的变量
# 4. 字段默认值
```

`BaseSettings` 还支持自定义环境变量前缀：

```python
from pydantic_settings import BaseSettings, SettingsConfigDict


class DatabaseSettings(BaseSettings):
    db_host: str = "localhost"
    db_port: int = 5432
    db_user: str
    db_pass: str

    model_config = SettingsConfigDict(env_prefix="DB_")

# 会查找以下环境变量：
# DB_DB_HOST, DB_DB_PORT, DB_DB_USER, DB_DB_PASS
```

也可以完全自定义单个字段对应的环境变量名：

```python
from pydantic import Field
from pydantic_settings import BaseSettings


class AuthSettings(BaseSettings):
    secret_key: str = Field(..., validation_alias="AUTH_SECRET_KEY")
    token_expire: int = 3600
```

## 参考

- [GNU Bash Manual: The Set Builtin（`set -a` / `set +a`）](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
- [Pydantic Settings 官方文档](https://docs.pydantic.dev/latest/concepts/pydantic_settings/)
- [Pydantic v1 → v2 迁移指南](https://docs.pydantic.dev/latest/migration/)
- [12-Factor App: Config（环境变量管理规范）](https://12factor.net/config)
