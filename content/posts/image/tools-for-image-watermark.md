+++
title = "图片加水印的命令行工具"
date = "2025-03-13"
lastmod = "2025-03-13"
subtitle = "用 ImageMagick 与 FFmpeg 批量给图片打水印"
description = "介绍在 Linux/macOS 下使用 ImageMagick、FFmpeg 等命令行工具为图片添加文字水印与图片水印的常用方法，并给出批量处理示例。"
author = "小智晖"
authors = ["小智晖"]
categories = ["image", "工具"]
tags = ["image", "ImageMagick", "ffmpeg", "水印", "命令行", "sips"]
keywords = ["图片水印", "ImageMagick", "FFmpeg", "命令行水印", "convert", "sips"]
toc = true
draft = false
+++

在 Linux 或 macOS 系统中，可以通过命令行工具（如 **ImageMagick** 或 **FFmpeg**）快速为图片添加水印。相比图形化软件，命令行方式更便于批量处理与脚本化。以下是几种常用方法。

> 备注：ImageMagick 7 已将主命令统一为 `magick`，`convert` 作为兼容别名仍可使用。下文示例沿用 `convert`，使用 ImageMagick 7 的同学将其替换为 `magick` 即可。

---

## 方法 1：使用 ImageMagick（推荐）

### 1. 安装 ImageMagick

```bash
# Linux (Debian/Ubuntu)
sudo apt-get install imagemagick

# macOS
brew install imagemagick
```

### 2. 添加文字水印

```bash
convert input.jpg -font Arial -pointsize 40 -fill "rgba(255,255,255,0.5)" \
  -gravity southeast -annotate +20+10 "Your Watermark" output.jpg
```

- `-font Arial`：指定字体（可用 `convert -list font` 查看可用字体）。
- `-pointsize 40`：文字大小。
- `-fill "rgba(255,255,255,0.5)"`：文字颜色与透明度（最后一位 `0.5` 为透明度，`0`=全透明，`1`=不透明）。
- `-gravity southeast`：水印位置（`southeast`=右下角，其他常用值：`north`、`center`、`northwest` 等）。
- `-annotate +20+10`：相对锚点的偏移量（水平 `+20`，垂直 `+10`）。

如果在 Ubuntu 中找不到 Arial 字体，可以通过如下命令安装：

```bash
# 安装微软核心字体包（含 Arial）
sudo apt install ttf-mscorefonts-installer

# 刷新字体缓存
sudo fc-cache -f -v

# 验证安装
fc-list | grep -i "Arial"
```

### 3. 添加图片水印

```bash
convert input.jpg watermark.png -gravity center -geometry +0+0 -composite output.jpg
```

- `watermark.png`：水印图片（推荐使用带透明背景的 PNG）。
- `-geometry +0+0`：水印位置偏移量（`+0+0`=居中；`+20-10`=右移 20 像素、上移 10 像素）。
- `-composite`：将水印图层合并到原图。

也可以用如下命令生成一张带文字的白色背景图片，作为水印素材：

```bash
convert -size 200x20 xc:white -font Arial -fill "rgba(255,0,255,0.5)" \
  -gravity center -pointsize 20 -annotate 0 "小智晖的AI单词本：word.vxiaozhi.com" output.png
```

### 4. 批量添加水印

```bash
for file in *.jpg; do
  convert "$file" -font Arial -pointsize 30 -fill "rgba(0,0,0,0.3)" \
    -gravity southeast -annotate +20+10 "Private" "watermarked_${file}"
done
```

---

## 方法 2：使用 FFmpeg

FFmpeg 同样支持对单张图片加水印（输出可视为「一帧的视频」）。

### 1. 安装 FFmpeg

```bash
# Linux (Debian/Ubuntu)
sudo apt-get install ffmpeg

# macOS
brew install ffmpeg
```

### 2. 添加文字水印

```bash
ffmpeg -i input.jpg -vf "drawtext=text='Your Watermark':x=10:y=H-th-10:\
fontsize=24:fontcolor=white@0.5:fontfile=/path/to/font.ttf" -q:v 2 output.jpg
```

- `x=10:y=H-th-10`：水印位置（左下角，距左 10 像素，距下 10 像素；`H` 为图像高度，`th` 为文字高度）。
- `fontcolor=white@0.5`：颜色与透明度（`@0.5`=半透明）。
- `fontfile`：字体文件路径（在很多 FFmpeg 构建中为必需，否则会报「Could not load font」）。
- `-q:v 2`：JPEG 输出质量（有效范围约 2–31，数值越小质量越高，推荐 `2`）。

### 3. 添加图片水印

```bash
ffmpeg -i input.jpg -i watermark.png \
  -filter_complex "overlay=10:main_h-overlay_h-10" output.jpg
```

- `overlay=10:main_h-overlay_h-10`：水印位置（左下角；`main_h` 为底图高度，`overlay_h` 为水印高度）。

---

## 方法 3：使用 macOS 自带的 `sips`（仅图片水印）

macOS 自带的 `sips`（Scriptable Image Processing System）可以完成一些基本图像处理，但不擅长直接绘制文字水印，通常需配合预先做好的水印图片（PNG）使用：

```bash
# 将 watermark.png 叠加到 input.jpg（需较新版本的 sips 支持）
sips input.jpg --overlay watermark.png --out output.jpg
```

> 说明：`--overlay` 在不同 macOS 版本上的支持情况并不一致，部分版本可能不识别该参数。如果遇到问题，请改用方法 1 或方法 2。
>
> 另外，原文中提到的 `textutil -convert png ...` 写法有误：`textutil` 是文本格式转换工具（支持 txt/html/rtf/doc/docx 等），**不能** 生成 PNG 图片，也不支持 `-strokeColor`、`-text` 这类参数。生成文字水印图片请直接用 ImageMagick 的 `convert` 或 FFmpeg 的 `drawtext`。

---

## 常见问题与小技巧

1. **水印位置计算**：使用 `-gravity` 定位（如 `southeast`=右下角），再通过 `-geometry` 微调偏移量。例如 `-geometry +20-10` 表示右移 20 像素、上移 10 像素。

2. **透明度控制**：
   - ImageMagick 使用 `rgba(255,255,255,0.5)`（最后一位 0–1 表示透明度）。
   - FFmpeg 使用 `white@0.5`（`@` 后是 0–1 的透明度）。

3. **批量处理**：用 `find` 处理含子目录的文件，例如：

   ```bash
   find . -name "*.jpg" -exec convert {} -font Arial -pointsize 30 \
     -fill "rgba(0,0,0,0.3)" -gravity southeast -annotate +20+10 "Private" \
     {}.watermarked.jpg \;
   ```

   注意 `{}` 在 `-exec` 中代表当前文件，`{}.watermarked.jpg` 会生成 `原文件名.jpg.watermarked.jpg`，如需更精细的命名，建议改写为 `while read` 循环。

4. **优化水印清晰度**：若水印模糊，可提高水印图片分辨率或使用矢量格式（如 SVG）；文字水印可适当增大 `-pointsize` 或 `fontsize`。

---

## 参考链接

- ImageMagick 命令行选项：<https://imagemagick.org/script/command-line-options.php>
- ImageMagick 7 迁移说明：<https://imagemagick.org/script/porting.php>
- FFmpeg drawtext 滤镜文档：<https://ffmpeg.org/ffmpeg-filters.html#drawtext>
- FFmpeg overlay 滤镜文档：<https://ffmpeg.org/ffmpeg-filters.html#overlay>
- Apple `sips` man page：<https://developer.apple.com/library/archive/documentation/Darwin/Reference/ManPages/man1/sips.1.html>
- Apple `textutil` man page：<https://developer.apple.com/library/archive/documentation/Darwin/Reference/ManPages/man1/textutil.1.html>
