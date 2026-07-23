+++
title = "macOS 的 defaults 命令"
date = "2025-01-21"
lastmod = "2025-01-21"
subtitle = "用命令行读写 macOS 用户偏好与隐藏设置"
description = "介绍 macOS 内置的 defaults 命令,通过它读写 Finder、Dock、截屏等系统偏好的隐藏键值,并附常用示例。"
author = "小智晖"
authors = ["小智晖"]
categories = ["mac"]
tags = ["mac", "macOS", "defaults", "命令行", "Finder", "系统偏好"]
keywords = ["macOS defaults", "defaults 命令", "Finder 隐藏文件", "Dock 设置", "com.apple.finder", "mac 命令行"]
toc = true
draft = false
+++

`/usr/bin/defaults` 是 macOS(早期称 Mac OS X)系统自带的用户默认配置读写命令，几乎所有原生应用的偏好设置都通过它来管理。

[macos-defaults.com](https://macos-defaults.com/) 这个网站收录了大量 `defaults` 在修改 **Dock**、**Screenshots**、**Finder** 等模块时的具体用法，并且完全开源，开源地址:

- [yannbertrand/macos-defaults](https://github.com/yannbertrand/macos-defaults)

以下是 `man defaults` 中对它的官方描述（原文引用）:

> Defaults allows users to read, write, and delete Mac OS X user defaults from a command-line shell. Mac OS X applications and other programs use the
> defaults system to record user preferences and other information that must be maintained when the applications aren't running (such as default font
> for new documents, or the position of an Info panel). Much of this information is accessible through an application's Preferences panel, but some of
> it isn't, such as the position of the Info panel. You can access this information with defaults
>
> Note: Since applications do access the defaults system while they're running, you shouldn't modify the defaults of a running application. If you
> change a default in a domain that belongs to a running application, the application won't see the change and might even overwrite the default.
>
> User defaults belong to domains, which typically correspond to individual applications. Each domain has a dictionary of keys and values representing
> its defaults; for example, "Default Font" = "Helvetica". Keys are always strings, but values can be complex data structures comprising arrays,
> dictionaries, strings, and binary data. These data structures are stored as XML Property Lists.
>
> Though all applications, system services, and other programs have their own domains, they also share a domain named NSGlobalDomain.  If a default
> isn't specified in the application's domain, but is specified in NSGlobalDomain, then the application uses the value in that domain.

在 macOS 与 iOS 开发中，我们可以通过 `NSUserDefaults` API 来管理这类信息，实现数据的持久化暂存;由于它最终写入文件，因此可用于跨进程、跨控制器的数据传递。`NSUserDefaults` 属于 Foundation.framework，所以它是跨平台的——除 macOS、iOS 外，同样适用于 tvOS 和 watchOS，具体 API 可参考 [Apple 开发文档](https://developer.apple.com/documentation/foundation/userdefaults)。命令行下的 `/usr/bin/defaults` 则是面向终端用户的同名工具，用来增、删、改、查这些偏好值，这些值通常对应应用「偏好设置」面板中的 UI 项，但也有一些隐藏项只能通过命令行修改。

## defaults 命令使用

下面通过 `/usr/bin/defaults` 命令操作用户偏好，演示它对应用程序行为的影响。

### 在 Finder 标题栏显示完整路径

```bash
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
killall Finder
```

### 修改截屏图片的保存位置

```bash
defaults write com.apple.screencapture location <存放位置>
killall SystemUIServer
```

例如将截图保存到 `~/Pictures`:

```bash
defaults write com.apple.screencapture location ~/Pictures
killall SystemUIServer
```

### 显示 macOS 隐藏文件

```bash
defaults write com.apple.finder AppleShowAllFiles -bool true
killall Finder
```

恢复为默认（不显示隐藏文件）:

```bash
defaults write com.apple.finder AppleShowAllFiles -bool false
killall Finder
```

> 提示:macOS Sierra 及以后版本，也可在 Finder 中按 **⌘ Cmd + ⇧ Shift + .** 临时切换隐藏文件的显示。

### 让程序坞只显示正在运行的应用

默认情况下，程序坞（Dock）会把用户尚未「在程序坞中保留」却已经打开的应用程序显示出来。时间久了，那些不活跃的应用一直停留在程序坞中，会让它变得杂乱。下面的命令可以让程序坞**只显示正在运行的应用**,以减少不必要的干扰。

```bash
defaults write com.apple.dock static-only -boolean true
killall Dock
```

> 警告：启用 `static-only` 会**清空程序坞中所有固定的应用图标**,执行前请确认。

恢复为默认设置:

```bash
defaults delete com.apple.dock static-only
killall Dock
```

## 参考

- [macos-defaults.com](https://macos-defaults.com/) — 开源的 macOS defaults 命令示例集
- [yannbertrand/macos-defaults](https://github.com/yannbertrand/macos-defaults) — 上述网站的源码仓库
- [defaults 命令手册](https://www.manpagez.com/man/1/defaults/) — `man defaults` 在线版
- [NSUserDefaults — Apple Developer Documentation](https://developer.apple.com/documentation/foundation/userdefaults)
