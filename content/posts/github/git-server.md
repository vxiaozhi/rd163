+++
title = "Git 服务搭建"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从零搭建一台只依赖 SSH 的最小化 Git 服务器"
description = "讲解 Git 四种传输协议的取舍，并以 SSH 为核心示范裸仓库初始化、git-shell 限制与 authorized_keys 加固，搭出一台可用的自托管 Git 服务器。"
author = "小智晖"
authors = ["小智晖"]
categories = ["github"]
tags = ["git", "ssh", "self-hosted", "git-server", "git-shell", "devops"]
keywords = ["Git 服务搭建", "Git SSH 服务器", "git-shell", "裸仓库", "自托管 Git", "Git 传输协议"]
toc = true
draft = false
+++

在团队私有代码托管、内网交付或学习 Git 内部原理的场景中，不依赖 GitHub、Gitea 这类平台，只用一台带 SSH 服务的 Linux 机器就能跑起一台可用的 Git 服务器。本文基于 Pro Git 官方文档的 "Git on the Server" 一章，整理协议选型、最小化搭建步骤，以及若干安全加固要点。

## 为什么只需要 SSH

Git 的远程通信依赖传输协议（transport protocol）。Pro Git 把它归纳为四种：本地协议（Local）、HTTP 协议、SSH 协议和 Git 协议。

| 协议 | 默认端口 | 认证 | 加密 | 匿名读 | 可推送 |
| --- | --- | --- | --- | --- | --- |
| Local | 无 | 文件权限 | 否 | 看权限 | 是 |
| Smart HTTP | 80 / 443 | 用户名密码等 | HTTPS 时是 | 是 | 是 |
| Dumb HTTP | 80 / 443 | 无 | 否 | 是 | 否 |
| SSH | 22 | 公钥 | 是 | 否 | 是 |
| Git | 9418 | 无 | 否 | 是 | 理论可行但极少使用 |

四种里，**SSH 协议是自托管最省事的选择**：几乎所有 Linux 服务器默认就带 sshd，传输加密、压缩、支持公钥认证，既能读也能写。代价是不支持匿名访问，每个协作者都必须在服务器上有账号（或共用一个受限账号）。对于三五人的内部团队这完全够用。

Git 协议（`git://`，端口 9418）虽然最快，但没有认证也没有加密，官方明确警告：在不可信网络下克隆可能被中间人注入恶意代码，因此不推荐自建使用。Smart HTTP 适合需要对外匿名克隆或穿越公司防火墙的场景，配置上要依赖 Apache/Nginx 加 `git-http-backend` CGI，门槛比 SSH 高。本文后续以 SSH 为主线。

## 最小化搭建流程

下面这套流程与 Pro Git 官方手册基本一致，只是把分散的命令串成一个完整工作流。

### 1. 在服务器上创建专用用户

不要用 root 或个人账号承接 Git 流量，建一个名为 `git` 的专用用户：

```bash
sudo adduser git          # 部分发行版用 sudo useradd -m git
su - git
mkdir ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
```

`.ssh` 目录必须是 `700`，`authorized_keys` 必须是 `600`，否则 sshd 会因权限过宽而拒认密钥。

### 2. 分发开发者公钥

每位协作者在本地用 `ssh-keygen` 生成密钥对（推荐 ed25519）：

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

把各自的公钥（`~/.ssh/id_ed25519.pub`）追加到服务器 `git` 用户的 `~/.ssh/authorized_keys`。最省事的方式是在客户端直接执行：

```bash
ssh-copy-id git@<server-ip>
```

### 3. 创建裸仓库（bare repository）

服务端的仓库应该是**裸仓库**——只有 `.git` 目录的内容，没有工作区（working tree）。这避免了推送时因分支切换产生的冲突：

```bash
sudo mkdir -p /srv/git
sudo chown git:git /srv/git
su - git
cd /srv/git
mkdir project.git
cd project.git
git init --bare
```

阮一峰在《最简单的 Git 服务器》一文中给出一个更极简的写法：直接在本地用 SSH 远程执行 `git init --bare`：

```bash
ssh git@192.168.1.25 'git init --bare example.git'
```

两条命令等价，差别只在于你想不想先登录服务器。

### 4. 客户端推送

```bash
cd myproject
git init
git add .
git commit -m "Initial commit"
git remote add origin git@gitserver:/srv/git/project.git
git push -u origin main
```

其他协作者克隆：

```bash
git clone git@gitserver:/srv/git/project.git
```

这里需要注意默认分支名。从 Git 2.28（2020 年发布）开始，`git init` 的默认分支可以由 `init.defaultBranch` 配置，许多发行版和托管平台已默认改为 `main`。如果你的 Git 较旧，`git init` 仍会创建 `master`，推送时按实际分支名写即可。

## 用 git-shell 收紧登录权限

到目前为止有个隐患：任何把公钥加进 `authorized_keys` 的人，都能 `ssh git@gitserver` 拿到一个完整 shell，进而遍历服务器上其他仓库甚至越权。解决办法是给 `git` 用户换上一个**受限登录 shell**——`git-shell`。

`git-shell` 是 Git 自带的工具，只允许执行 `git-receive-pack`、`git-upload-pack`、`git-upload-archive` 这几个与服务端 Git 操作相关的命令，其他命令一律拒绝。配置步骤：

```bash
# 1. 找到 git-shell 路径并加入 /etc/shells
which git-shell                       # 例如 /usr/bin/git-shell
echo /usr/bin/git-shell | sudo tee -a /etc/shells

# 2. 把 git 用户的登录 shell 改为 git-shell
sudo chsh git -s $(which git-shell)
```

之后再次尝试交互登录就会被拒：

```bash
$ ssh git@gitserver
fatal: Interactive git shell is not enabled.
hint: ~/git-shell-commands should exist and have read and execute access.
```

而正常的 `git clone`、`git push` 不受影响。

## 在 authorized_keys 里再做一道防御

`git-shell` 限制了能执行的命令，但 SSH 本身仍允许端口转发、X11 转发、PTY 分配。Pro Git 给出的建议是在 `authorized_keys` 每一行公钥前面加上限制选项：

```
no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ssh-ed25519 AAAA... user@host
```

这样除了 Git 命令本身，其他 SSH 能力都被关闭，实现"纵深防御"（defense in depth）。

如果还需要更细粒度的权限控制——谁能读哪个仓库、谁能写哪个分支——光靠 `git-shell` 不够，这时可以上 Gitolite，或直接选一个完整的自托管平台（Gitea、Gogs、GitLab CE 等）。它们的底层仍然是这套 SSH + 裸仓库的模型，只是在上面加了一层访问控制和 Web UI。

## 常见坑与备忘

- **权限**：`~/.ssh` 必须是 `700`，`authorized_keys` 必须是 `600`，属主必须是 `git` 用户本人，否则 sshd 静默拒绝密钥登录。
- **裸仓库目录约定**：以 `.git` 结尾（如 `project.git`）是社区约定，并非强制，但加上后 URL 更直观、与工具链兼容性更好。
- **SCP 风格 URL**：`git@gitserver:/srv/git/project.git` 是 SCP 简写；等价的 ssh URL 是 `ssh://git@gitserver/srv/git/project.git`，后者更利于在 CI 配置里拼接。
- **首次连接指纹**：客户端第一次连接会提示是否信任主机指纹（host key fingerprint），生产环境最好通过配置管理工具预置 `known_hosts`，避免中间人风险。
- **多仓库共用账号**：上面这套是"一个 git 账号 + 多人公钥"的简单模型，仓库级 ACL 需要靠文件系统权限或 Gitolite 之类工具补充。

## 小结

对学习 Git 内部机制、或在小范围内部团队共享代码而言，"SSH + 裸仓库 + git-shell" 是最低成本的自托管方案：不需要数据库、不需要 Web 服务、不需要额外端口，一台开了 sshd 的 Linux 机器足矣。再往上一步，需要 issue 管理、Pull Request、CI/CD、Web UI 时，再迁移到 Gitea、Gogs 或 GitLab CE，它们都建立在这同一套底层模型之上。

## 参考

- [Pro Git — Git on the Server: The Protocols](https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols)
- [Pro Git — Git on the Server: Setting Up the Server](https://git-scm.com/book/en/v2/Git-on-the-Server-Setting-Up-the-Server)
- [Pro Git — Git on the Server: Smart HTTP](https://git-scm.com/book/en/v2/Git-on-the-Server-Smart-HTTP)
- [阮一峰 — 最简单的 Git 服务器](https://www.ruanyifeng.com/blog/2022/10/git-server.html)
- [Git 底层原理：传输协议分析（一）](https://xiaowenxia.github.io/git-inside/2021/02/23/git-internal-protocol.1/index.html)
- [Git 底层原理：传输协议分析（二）](https://xiaowenxia.github.io/git-inside/2021/02/23/git-internal-protocol.2/)
- `man git-shell`