+++
title = "Mac 重装系统"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "macOS Recovery 与启动快捷键的完整操作指南"
description = "介绍 Mac 重装系统的官方流程，涵盖 Intel 与 Apple Silicon 机型进入 macOS Recovery 的不同方式、三种恢复模式、抹盘重装步骤及启动 U 盘制作。"
author = "小智晖"
authors = ["小智晖"]
categories = ["mac"]
tags = ["mac", "macOS", "系统重装", "Recovery", "Apple Silicon"]
keywords = ["Mac 重装系统", "macOS Recovery", "Command R", "Apple Silicon 重装", "抹盘重装"]
toc = true
draft = false
+++

重装 macOS 是排查系统故障、出售或转让设备前的常见操作。与早期需要光盘或 U 盘引导不同，现代 Mac 内置了 **macOS Recovery(恢复系统)**,通过开机时的组合键或长按电源键即可进入,从联网下载安装镜像,无需额外介质。本文整理 Intel 与 Apple Silicon 两种机型进入 Recovery 的官方流程,并说明抹盘重装、启动 U 盘制作等关键步骤。

## 进入 macOS Recovery

进入 Recovery 的方式与 Mac 的芯片架构相关,需先确认机型。点击屏幕左上角的苹果图标,选择「关于本机」,在「芯片(Chip)」一项中可以看到 Apple Silicon(M1/M2/M3/M4 系列)或 Intel 标识。

### Intel 机型:开机组合键

对于搭载 Intel 处理器的 Mac,在按下电源键后立即长按对应组合键,直到出现苹果图标或旋转的地球图案再松手。不同组合对应不同的恢复行为:

| 组合键 | 作用 |
| --- | --- |
| `Command (⌘) + R` | 安装这台 Mac **最近安装过**的 macOS 版本(最常用的推荐选项) |
| `Option + Command + R` | 升级到与该 Mac 兼容的**最新** macOS |
| `Shift + Option + Command + R` | 安装这台 Mac **出厂时**自带的 macOS(或最接近的可用版本) |

> 原文提到的「长按 `Command + R` 直到出现苹果图标」正是 Intel 机型进入本地 Recovery 的标准做法,适用于大多数重装场景。

如果本地 Recovery 分区损坏,Mac 会自动尝试 **Internet Recovery(互联网恢复)**,此时屏幕上会出现旋转的地球图案,需要连接 Wi-Fi 或有线网络从苹果服务器下载恢复镜像。

### Apple Silicon 机型:长按电源键

搭载 Apple 芯片的 Mac 取消了复杂的组合键,改为统一的电源键交互。操作步骤如下:

1. 将 Mac 完全关机。
2. 按住电源键(或 Touch ID 键)不放,屏幕会出现「继续按住以显示启动选项」的提示。
3. 持续按住直到出现「正在加载启动选项(Loading startup options)」,然后松手。
4. 点击「选项(Options)」齿轮图标,再点击「继续」。
5. 选择管理员账户并输入密码后,进入 Recovery 界面。

Apple Silicon 的 Recovery 始终通过互联网下载系统,不再区分本地恢复与互联网恢复。

## Recovery 提供的工具

进入 Recovery 后,菜单栏的「实用工具(Utilities)」和主窗口提供以下常用功能:

- **Reinstall macOS / 重新安装 macOS**:启动安装程序,从联网下载并安装系统。
- **Disk Utility / 磁盘工具**:管理、修复或抹掉磁盘分区。出售或转让设备前应在此抹掉启动盘。
- **Terminal / 终端**:执行命令行修复,例如重置密码、修复权限等。
- **Safari**:查阅文档或下载工具。
- **Startup Security Utility / 启动安全实用工具**:配置安全启动、允许的外部介质等(适用于带有 T2 芯片或 Apple Silicon 的 Mac)。

## 抹盘重装

若只需在保留数据的前提下覆盖安装,直接选择「重新安装 macOS」即可。但遇到严重系统故障、准备出售或转让设备时,建议先抹掉启动盘:

1. 在 Recovery 中打开「磁盘工具」。
2. 在左侧选中启动盘(通常是 `Macintosh HD`)。
3. 点击工具栏的「抹掉」,格式选择 **APFS**(Apple Silicon 及较新的 Intel 机型均推荐),方案选择「GUID 分区图」。
4. 抹掉完成后退出磁盘工具,再选择「重新安装 macOS」。

对于 macOS Monterey 及更高版本,系统还提供了「**抹掉所有内容和设置(Erase All Content and Settings)**」的抹掉助手(Erase Assistant),可在「系统设置 > 通用 > 转移或重置」中直接抹掉所有数据、用户账户与系统设置,效果类似于 iOS 的「恢复出厂设置」,无需手动进入 Recovery。

> 抹盘会永久删除所有数据。操作前请务必通过 Time Machine 或外置硬盘做好完整备份。

## 制作启动 U 盘(可选)

当需要为多台 Mac 部署系统、网络环境不稳定或 Recovery 无法正常工作时,可以制作 macOS 启动 U 盘。Apple 官方文档(`HT201372`)记录了标准的 `createinstallmedia` 流程。

准备工作:

- 一块 14 GB 以上的 U 盘或移动硬盘(会被格式化,注意备份数据)。
- 从 App Store 下载完整的 macOS 安装程序(如 `Install macOS Sonoma.app`),它会出现在「应用程序」文件夹中。

将 U 盘命名为 `MyVolume`,并在「磁盘工具」中将其抹掉为 `Mac OS Extended (日志式)` 或 `APFS` 格式,然后在终端执行:

```bash
sudo /Applications/Install\ macOS\ Sonoma.app/Contents/Resources/createinstallmedia --volume /Volumes/MyVolume
```

命令中的安装程序路径需根据实际下载的 macOS 版本调整。执行后按提示输入管理员密码与确认,等待写入完成即可。启动时按住 `Option`(Intel)或长按电源键(Apple Silicon)进入启动选项,选择 U 盘启动安装。

## 操作前的注意事项

- **连接电源**:重装过程耗时较长,笔记本请连接电源适配器,避免中途断电导致系统损坏。
- **网络环境**:Internet Recovery 与 Apple Silicon 的 Recovery 均需要稳定的网络连接,建议使用有线网络或信号良好的 Wi-Fi。
- **Apple ID 与激活锁**:开启了「查找我的 Mac」的设备在重装后可能需要原 Apple ID 解锁激活锁。出售或转让前应先在系统设置中退出 Apple ID、关闭「查找」。
- **文件备份**:覆盖安装通常保留用户数据,但抹盘会清除一切,务必通过 Time Machine 完整备份后再操作。

## 参考

- [How to reinstall macOS from macOS Recovery (HT204904)](https://support.apple.com/en-us/HT204904) — Apple 官方重装 macOS 指南,涵盖 Intel 与 Apple Silicon。
- [Use Disk Utility to erase a Mac with Apple silicon (HT212030)](https://support.apple.com/en-us/HT212030) — 在 Apple Silicon Mac 上用磁盘工具抹盘的官方步骤。
- [Create a bootable installer for macOS (HT201372)](https://support.apple.com/en-us/HT201372) — 使用 `createinstallmedia` 制作启动 U 盘。
- [Mac User Guide — Reinstall macOS](https://support.apple.com/guide/mac-help/mchlp1599/mac) — macOS 用户手册中的重装章节。
