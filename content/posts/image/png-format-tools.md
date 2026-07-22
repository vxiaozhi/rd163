+++
title = "png 格式工具"
date = "2025-03-13"
lastmod = "2025-03-13"
subtitle = "ImageMagick、pngquant、ffmpeg 等 PNG 处理工具与常用命令"
description = "整理 PNG 格式处理中常用的工具链：用 ImageMagick 读写文本元数据、pngquant 压缩、以及多种方式将 PNG 转换为 JPG，并附带 ffmpeg 备忘命令。"
author = "小智晖"
authors = ["小智晖"]
categories = ["image"]
tags = ["image", "png", "imagemagick", "ffmpeg", "pngquant"]
keywords = ["PNG", "ImageMagick", "pngquant", "PNG 转 JPG", "ffmpeg", "图片压缩"]
toc = true
draft = false
+++

## 工具示例：ImageMagick

PNG 格式支持多种预定义的文本块类型（如 `tEXt`、`iTXt`、`zTXt`），用于存储作者、版权、描述等文本元数据。这些数据块会被大多数图片查看器和编辑器保留。

```bash
# 添加文本元数据
convert input.png -set "Description" "这是附加的注释" output.png

# 添加多个字段（如作者、版权）
convert input.png -set "Artist" "John Doe" -set "Copyright" "2024" output.png
```

## 查看元数据

```bash
identify -verbose output.png
```

## 压缩

安装：

```bash
# Linux (Debian/Ubuntu)
sudo apt-get install pngquant

# macOS (Homebrew)
brew install pngquant
```

用法：

```bash
pngquant --quality=80-90 input.png --output output.png
```

其中 `--quality min-max` 的两个值都位于 0-100 区间，`pngquant` 会尽量满足较大的质量值；若结果低于最小质量值，文件不会被保存。

## PNG 转 JPG

### 方法 1：使用 `convert` 命令（ImageMagick）

1. **安装 ImageMagick**（如果未安装）：

   ```bash
   # Linux (Debian/Ubuntu)
   sudo apt-get install imagemagick

   # macOS (Homebrew)
   brew install imagemagick
   ```

2. **单文件转换**：

   ```bash
   convert input.png -background white -flatten output.jpg
   ```

   - `-background white`：将透明背景替换为白色（JPEG 不支持透明通道）。
   - `-quality 85`：可选项，设置压缩质量（默认 92，范围 1-100）。
   - 在 ImageMagick 7 中，`-flatten` 已被标记为过时，更推荐用 `-alpha remove` 替代，例如 `convert input.png -background white -alpha remove output.jpg`。

3. **批量转换当前目录下所有 PNG 文件**：

   ```bash
   for file in *.png; do
     convert "$file" -background white -flatten "${file%.png}.jpg"
   done
   ```

### 方法 2：使用 `ffmpeg`

1. **安装 ffmpeg**（如果未安装）：

   ```bash
   # Linux (Debian/Ubuntu)
   sudo apt-get install ffmpeg

   # macOS (Homebrew)
   brew install ffmpeg
   ```

2. **转换单个文件**：

   ```bash
   ffmpeg -i input.png -q:v 2 output.jpg
   ```

   - `-q:v 2`：设置 JPEG 质量。数值越小质量越高，有效范围是 **2-31**（2 为最佳质量，31 为最低质量），通常取 2-5 即可获得较好的画质。

---

### 方法 3：使用 macOS 自带的 `sips` 命令

仅适用于 macOS 系统：

```bash
sips -s format jpeg input.png --out output.jpg
```

**批量转换**：

```bash
mkdir jpg_images  # 创建输出目录
for file in *.png; do
  sips -s format jpeg "$file" --out "jpg_images/${file%.png}.jpg"
done
```

---

### 常见问题

1. **保留原始尺寸和清晰度**：默认会保持原图分辨率，如需调整尺寸可添加 `-resize WIDTHxHEIGHT`（例如 `-resize 800x600`）。
2. **透明背景处理**：JPEG 不支持透明通道，务必使用 `-background 颜色 -flatten`（或 `-alpha remove`）填充背景色。
3. **保留 EXIF 信息**：默认会保留，如需清除可添加 `-strip` 参数。

---

## ffmpeg 命令备忘

播放原始 PCM 文件：

```bash
# 播放 16kHz 单声道 16bit 的 test.pcm
ffplay -ar 16000 -ac 1 -f s16le -i test.pcm
```

- `-ar 16000`：采样率 16kHz。
- `-ac 1`：单声道。
- `-f s16le`：有符号 16 位小端（signed 16-bit little-endian）格式。

## 参考

- [PNG 规范 - 文本块（tEXt/iTXt/zTXt）](https://www.w3.org/TR/png-3/#11textinfo)
- [pngquant 官方文档](https://pngquant.org)
- [ImageMagick 命令行选项](https://imagemagick.org/script/command-line-options.php)
- [ffmpeg 官方文档](https://ffmpeg.org/ffmpeg.html)