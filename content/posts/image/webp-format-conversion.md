+++
title = "使用 webp-tools 实现 webp与png、jpg 之间的格式转换"
date = "2025-01-24"
lastmod = "2025-01-24"
subtitle = "使用 webp-tools 实现 webp与png、jpg 之间的格式转换"
description = "使用 webp-tools 实现 webp与png、jpg 之间的格式转换"
author = "小智晖"
authors = ["小智晖"]
categories = ["image"]
tags = ["image"]
keywords = []
toc = true
draft = false
+++

## 安装 webp-tools


```
#ubuntu
apt-get install webp
 
#centos
yum -y install libwebp-devel libwebp-tools

#macOS
brew install webp
```

会生成几个工具:

- cwebp → WebP encoder tool
- dwebp → WebP decoder tool
- vwebp → WebP file viewer
- webpmux → WebP muxing tool
- gif2webp → Tool for converting GIF images to WebP

### convert from webp to png

dwebp可以将webp图片转换成无损的png图片格式，有了png，则可以使用imagemagic之类的工具再转换成jpg.

```
dwebp mycat.webp -o mycat.png
```
 
### Convert from JPG to WebP

cwebp可以将jpg转换成webp，将png转换成webp

```
cwebp some.jpg -o target.webp
```

