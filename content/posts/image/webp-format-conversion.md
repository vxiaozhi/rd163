+++
title = "使用 webp-tools 实现 WebP 与 PNG、JPG 的格式转换"
date = "2025-01-24"
lastmod = "2025-01-24"
subtitle = "libwebp 官方命令行工具 cwebp 与 dwebp 的安装与用法"
description = "WebP 是 Google 推出的现代图像格式，体积相比 PNG/JPEG 显著更小。本文介绍如何在 Linux 与 macOS 上安装 libwebp 工具集，并使用 cwebp、dwebp 等命令完成 WebP 与 PNG、JPEG 的相互转换。"
author = "小智晖"
authors = ["小智晖"]
categories = ["image"]
tags = ["image", "webp", "libwebp", "cwebp", "dwebp"]
keywords = ["webp", "cwebp", "dwebp", "libwebp", "webp 转 png", "图像格式转换"]
toc = true
draft = false
+++

WebP 是 Google 开发的一种现代图像格式（image format），针对 Web 场景做了专门优化。它同时支持**有损压缩（lossy compression）**和**无损压缩（lossless compression）**，并允许携带透明通道（alpha channel）。根据官方资料，无损 WebP 在同等质量下通常比 PNG 小约 **26%**，有损 WebP 在等价 SSIM（结构相似度）质量下比 JPEG 小 **25%–34%**；对于带透明通道的 RGB 图像，WebP 文件相比 PNG 可小到约三分之一。

WebP 的参考实现由开源项目 `libwebp` 提供，上游仓库托管在 `chromium.googlesource.com/webm/libwebp`。该项目除 C 语言库外，还附带一组命令行工具，是我们在终端下做格式转换最直接、最稳定的方案。本文记录这套工具的安装与常用转换方法。

## 安装 webp-tools

在主流系统上，官方仓库均已收录 `libwebp`，无需自行编译。各发行版的包名略有不同：

```bash
# Ubuntu / Debian（包名为 webp，位于 universe 仓库）
sudo apt-get install webp

# CentOS / RHEL / Rocky / Fedora（核心工具在 libwebp-tools）
sudo yum  install libwebp-tools
sudo dnf  install libwebp-tools   # Fedora / RHEL 8+ 推荐 dnf

# 仅当你需要在本地编译依赖 libwebp 的程序时，才需要 devel 头文件包
sudo yum  install libwebp-devel

# macOS（Homebrew formula 名为 webp）
brew install webp
```

安装完成后，可通过 `cwebp -version` 或 `dwebp -version` 查看版本号，确认安装成功。

## 工具集一览

`libwebp` 提供了若干个相互独立的命令行工具，各自承担一类任务。最常用的两个是 `cwebp`（编码器）和 `dwebp`（解码器）。

| 工具 | 作用 |
| --- | --- |
| `cwebp` | WebP 编码器（encoder），将 PNG / JPEG / TIFF 等转为 WebP |
| `dwebp` | WebP 解码器（decoder），将 WebP 还原为 PNG / PPM / BMP / TIFF / PGM |
| `vwebp` | WebP 查看器（viewer），基于 OpenGL/GLUT 直接在窗口中显示 |
| `webpmux` | WebP 多路复用工具，用于读写 ICC、EXIF、XMP 元数据与动画帧 |
| `gif2webp` | 将动态 GIF 转换为动态 WebP |
| `img2webp` | 将一组静态图片序列合成动画 WebP |

下面分别介绍日常最常用的两类转换：**WebP → PNG/JPG** 与 **JPG/PNG → WebP**。

## 将 WebP 转换为 PNG

`dwebp` 用于把 `.webp` 文件解码为其它格式。它的默认输出格式是 PNG，这也是最常用的场景：

```bash
dwebp mycat.webp -o mycat.png
```

`-o` 指定输出文件名；若省略，则只输出统计信息而不落盘。

除了 PNG，`dwebp` 还支持多种无损位图格式，方便对接不同的后端处理流程：

```bash
dwebp mycat.webp -ppm  -o mycat.ppm    # PPM（不带 alpha）
dwebp mycat.webp -pam  -o mycat.pam    # PAM（保留 alpha）
dwebp mycat.webp -bmp  -o mycat.bmp    # BMP
dwebp mycat.webp -tiff -o mycat.tiff   # TIFF
```

### 再从 PNG 转 JPG

`dwebp` 本身不支持直接输出 JPEG。常规做法是先转成 PNG，再用 ImageMagick 之类的工具二次转换：

```bash
dwebp mycat.webp -o mycat.png
convert mycat.png -quality 90 mycat.jpg    # ImageMagick
```

如果系统没有 ImageMagick，也可以用 `cwebp` 的逆向伙伴——`djpeg`/`pnmtopng` 等老牌 netpbm / libjpeg 工具链，思路一致：先得到无损中间格式，再压成 JPEG。

### WebP 转 JPG 的注意事项

- `dwebp` **不支持动画 WebP**（animated WebP）。如果输入是动画文件，`dwebp` 会报错，此时应改用 `webpmux` 配合 `gif2webp` 的反向流程或专门工具处理。
- 若图像带 alpha 通道，转 JPEG 前需要先做合成（flatten），否则透明区域会被丢弃或填成黑色。可用 ImageMagick 的 `-background white -flatten` 显式处理。

## 将 JPG / PNG 转换为 WebP

`cwebp` 是 WebP 的编码器，可读入 PNG、JPEG、TIFF 等常见格式并输出 `.webp`。基本用法：

```bash
# 从 JPEG 转 WebP（默认有损，质量 75）
cwebp some.jpg -o target.webp

# 从 PNG 转 WebP
cwebp logo.png -o logo.webp
```

### 控制压缩质量

`cwebp` 的关键参数是 `-q`（quality，0–100，默认 **75**）。值越小文件越小、画质越低：

```bash
cwebp -q 80 photo.jpg -o photo.webp
```

如果追求像素级一致（例如截图、线条图、图标），可以启用**无损模式**：

```bash
cwebp -lossless -q 100 diagram.png -o diagram.webp
```

无损模式下，`-q` 控制的是压缩努力程度而非画质。对于色块清晰的 UI 截图、漫画等，无损 WebP 通常能给出比 PNG 小得多的文件。

### 其它常用选项

根据 `cwebp` 官方手册，常用的可选参数还有：

```bash
# 在编码前先缩放到指定尺寸（0 表示按比例自适应）
cwebp -resize 1280 0 big.jpg -o big.webp

# 保留 EXIF / ICC / XMP 元数据
cwebp -metadata all photo.jpg -o photo.webp

# 多线程编码，加速大图处理
cwebp -mt huge.png -o huge.webp

# 使用 photo 预设参数，对照片通常更友好
cwebp -preset photo scenery.jpg -o scenery.webp
```

其中 `-preset` 提供了若干预设组合：`default`、`photo`、`picture`、`drawing`、`icon`、`text`，分别针对不同类型的图像内容调优。

### 透明通道

PNG 转 WebP 时，alpha 通道会被自动保留。可用 `-alpha_q`（默认 100，即无损 alpha）单独控制透明层的压缩质量：

```bash
cwebp -q 80 -alpha_q 90 icon.png -o icon.webp
```

## 批量转换示例

实际项目中，往往需要对整个目录的图片做批量转换。下面是一段简洁的 shell 片段：

```bash
# 将当前目录下所有 jpg/png 转为 webp（质量 80）
for f in *.{jpg,jpeg,png}; do
  [ -e "$f" ] || continue
  cwebp -q 80 "$f" -o "${f%.*}.webp"
done

# 反向：将所有 webp 还原为 png
for f in *.webp; do
  [ -e "$f" ] || continue
  dwebp "$f" -o "${f%.*}.png"
done
```

如果转换量很大，可以加上 `-mt` 启用多线程，或者结合 `xargs -P` 做并行。

## 小结与取舍

- 仅做格式转换，安装 `webp` / `libwebp-tools` 即可，无需 `devel` 头文件包。
- 日常两个命令记牢即可：**`cwebp` 编码进去，`dwebp` 解码出来**。
- WebP 转 JPG 没有直接路径，需要先转 PNG 再用其它工具二次编码。
- 动画 WebP 超出 `dwebp` 的能力范围，应使用 `webpmux` 与相关动画工具。
- 选 `-q` 还是 `-lossless`，取决于源图类型：照片一般有损 `-q 80` 起步；线条图、图标、截图更适合无损。

WebP 已被所有主流现代浏览器支持，配合 `libwebp` 提供的这套小而精的命令行工具，足以覆盖绝大多数服务端或本地批处理的图像格式互转需求。

## 参考

- WebP 官方介绍：<https://developers.google.com/speed/webp>
- cwebp 命令手册：<https://developers.google.com/speed/webp/docs/cwebp>
- dwebp 命令手册：<https://developers.google.com/speed/webp/docs/dwebp>
- libwebp 上游仓库：<https://chromium.googlesource.com/webm/libwebp>
- libwebp 工具说明文档：<https://chromium.googlesource.com/webm/libwebp/+/HEAD/doc/tools.md>
