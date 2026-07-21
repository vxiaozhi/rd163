+++
title = "使用 LetterAvatar 实现纯前端生成字母头像"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "使用 LetterAvatar 实现纯前端生成字母头像"
description = "使用 LetterAvatar 实现纯前端生成字母头像"
author = "小智晖"
authors = ["小智晖"]
categories = ["golang"]
tags = ["编程语言", "golang", "avatar"]
keywords = []
toc = true
draft = false
+++

# 使用 LetterAvatar 实现纯前端生成字母头像

如何自动给没头像的用户生成一个昵称首字符的彩色头像。参考这个 golang 库：

- [letteravatar](https://github.com/disintegration/letteravatar)

遗憾的是，这个库不支持中文，因此可以将中文字符先转化为拼音再调用这个库。

- [go-pinyin](https://github.com/mozillazg/go-pinyin)
