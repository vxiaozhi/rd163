+++
title = "解决Linux操作系统下Terminal中光标消失的问题"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "解决Linux操作系统下Terminal中光标消失的问题"
description = "解决Linux操作系统下Terminal中光标消失的问题"
author = "小智晖"
authors = ["小智晖"]
categories = ["linux"]
tags = ["terminal"]
keywords = []
toc = true
draft = false
+++

# 解决Linux操作系统下Terminal中光标消失的问题

使用Terminal时会偶尔遇到光标消失的问题。


显示光标

```
echo -e "\033[?25h"
```

隐藏光标

```
echo -e "\033[?25l"
```
