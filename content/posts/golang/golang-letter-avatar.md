+++
title = "使用 LetterAvatar 在 Go 中生成字母头像"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "结合 go-pinyin 为中文昵称自动生成首字母彩色头像"
description = "介绍 Go 的 letteravatar 库工作原理,并配合 go-pinyin 解决中文字符的拼音转换,实现服务端自动生成昵称首字母彩色头像。"
author = "小智晖"
authors = ["小智晖"]
categories = ["golang"]
tags = ["编程语言", "golang", "avatar", "图片处理", "pinyin"]
keywords = ["golang", "letteravatar", "字母头像", "go-pinyin", "头像生成"]
toc = true
draft = false
+++

## 背景：为什么需要字母头像

在论坛、IM、评论区这类 UGC(User-Generated Content)场景中，相当一部分用户不会主动上传头像。如果默认显示统一的灰色占位图，界面会显得单调，也不利于快速识别用户。一个常见的做法是：用昵称的首个字符叠加在彩色背景上，生成所谓的「字母头像」(Letter Avatar)。Notion、Linear、Slack 等不少 SaaS 产品都采用了类似策略。

这类头像通常有两个关键诉求:

- **确定性**:同一昵称在不同时间生成应得到同样的颜色，避免每次刷新都变色。
- **可读性**:字符要在背景上清晰可见，配色要避免低对比度。

下面介绍的 [`letteravatar`](https://github.com/disintegration/letteravatar) 就是 Go 生态中专门处理这件事的小巧库，而中文名还需要 [`go-pinyin`](https://github.com/mozillazg/go-pinyin) 来配合。

> 注：作者最初的想法是「纯前端生成」,但 `letteravatar` 本身是服务端 Go 库，实际做法是在后端把 PNG 渲染好再返回给前端。原文标题里的「纯前端」更准确的理解是「无需用户主动上传」。

## letteravatar 工作原理

[`letteravatar`](https://github.com/disintegration/letteravatar) 由 `disintegration` 开发(他同时也是知名图像处理库 [`imaging`](https://github.com/disintegration/imaging) 的作者),代码非常精简，核心只暴露一个函数:

```go
func Draw(size int, letter rune, options *Options) (image.Image, error)
```

- `size`:头像边长（像素）,生成的图像是 `size × size` 的正方形。
- `letter`:要绘制的字符，类型是 `rune`,因此能正确处理非 ASCII 字符（如西里尔字母）。
- `options`:可选配置，传 `nil` 走默认值。

`Options` 结构定义如下:

```go
type Options struct {
    Font        *truetype.Font   // 自定义字体,默认使用内置 Roboto-Medium
    Palette     []color.Color    // 背景色候选,默认 208 个 Material Design 色卡
    LetterColor color.Color      // 字符颜色,默认浅灰
    PaletteKey  string           // 用于从调色板中确定性地挑选背景色
}
```

其中 `*truetype.Font` 来自 `github.com/golang/freetype/truetype`。

### 背景色如何选择

这是该库最值得说的设计点。在 `Draw` 内部，背景色的决策分两条路径:

```go
if options != nil && len(options.PaletteKey) > 0 {
    bgColor = palette[keyindex(len(palette), options.PaletteKey)]
} else {
    bgColor = palette[randint(len(palette))]
}
```

- **不传 `PaletteKey`**:从调色板里随机抽一个颜色，每次结果不同。
- **传 `PaletteKey`**:`keyindex` 会把字符串按 rune 累加取模，映射到调色板下标，从而**对同一 key 永远返回同一颜色**。

把用户 ID 或昵称作为 `PaletteKey` 传入，就能保证「同一用户每次拿到同一颜色」,这正是字母头像最关键的体验。

默认调色板包含 208 个取自 Material Design 的彩色，覆盖红、橙、紫、蓝、绿等多个色相，饱和度统一，放在一起不会突兀。默认字符色是浅灰，在大部分彩色背景上都能保证可读。

### 字符渲染

实际绘制由内部 `drawAvatar` 完成:

```go
func drawAvatar(bgColor, fgColor color.Color, font *truetype.Font, size int, letter rune) (image.Image, error) {
    dst := newRGBA(size, size, bgColor)
    fontSize := float64(size) * 0.6
    src, err := drawString(bgColor, fgColor, font, fontSize, string(letter))
    if err != nil {
        return nil, err
    }
    r := src.Bounds().Add(dst.Bounds().Size().Div(2)).Sub(src.Bounds().Size().Div(2))
    draw.Draw(dst, r, src, src.Bounds().Min, draw.Src)
    return dst, nil
}
```

字体大小固定为头像边长的 `0.6` 倍，然后再居中合成。由于 `Draw` 返回的是标准库 `image.Image`,后续用标准库 `image/png` 编码即可输出。

## 中文昵称的问题

`letteravatar` 的字符渲染本身并不限制语言，但内置字体 Roboto-Medium 只覆盖拉丁和部分西里尔字符集，中文字符直接传入会渲染成 **豆腐块**(tofu，缺失字形时的方框)。此外，中文字符视觉宽度比拉丁字母大得多，直接画上去观感也不好。

解决思路是:**先把中文字符转成拼音，再取首字母参与绘制**。这正是 `go-pinyin` 的用武之地。

## go-pinyin:中文转拼音

[`go-pinyin`](https://github.com/mozillazg/go-pinyin) 是 Python 版 `pypinyin` 的 Go 实现，内置离线词表，无需联网即可完成转换。安装:

```bash
go get github.com/mozillazg/go-pinyin
```

核心 API 很简洁:

```go
package main

import (
    "fmt"

    "github.com/mozillazg/go-pinyin"
)

func main() {
    hans := "中国人"

    a := pinyin.NewArgs()
    fmt.Println(pinyin.Pinyin(hans, a))
    // [[zhong] [guo] [ren]]

    a.Style = pinyin.Tone
    fmt.Println(pinyin.Pinyin(hans, a))
    // [[zhōng] [guó] [rén]]

    fmt.Println(pinyin.LazyPinyin(hans, pinyin.NewArgs()))
    // [zhong guo ren]
}
```

`pinyin.Pinyin` 返回 `[][]string`(支持多音字，每个字对应一组候选),`pinyin.LazyPinyin` 返回扁平的 `[]string`。

对于字母头像，我们只需要首字母，可以直接把 `Style` 设为 `pinyin.FirstLetter`:

```go
a := pinyin.NewArgs()
a.Style = pinyin.FirstLetter
fmt.Println(pinyin.LazyPinyin("小智晖", a))
// [x z h]
```

需要注意两点:

- 默认情况下,`go-pinyin` 会**忽略**没有拼音的字符（标点、数字、英文等）。如果想自定义这些字符的处理，可以设置 `Args.Fallback` 回调。
- 根据汉语拼音方案,`y`、`w`、`ü` 都不是声母，如果直接取 `FirstLetter` 与预期不符，需要参考官方说明再调整策略。

## 组合示例：生成完整可用的头像

下面把两个库串起来：接收任意昵称字符串，提取首个有效字符（英文/数字）或中文拼音首字母，再用 `PaletteKey` 保证颜色稳定。

```go
package main

import (
    "image/png"
    "log"
    "os"
    "unicode"

    "github.com/disintegration/letteravatar"
    "github.com/mozillazg/go-pinyin"
)

// initialOf 从昵称中提取用于头像的首字符 rune。
// - ASCII 字母 / 数字:直接返回
// - 中文字符:取拼音首字母
func initialOf(name string) rune {
    for _, r := range name {
        switch {
        case unicode.IsLetter(r) && r < 0x4E00:
            // 拉丁字母等,直接返回大写
            return unicode.ToUpper(r)
        case r >= 0x4E00 && r <= 0x9FFF:
            // CJK 统一表意文字基本块,转拼音取首字母
            a := pinyin.NewArgs()
            a.Style = pinyin.FirstLetter
            result := pinyin.LazyPinyin(string(r), a)
            if len(result) > 0 && len(result[0]) > 0 {
                return unicode.ToUpper(rune(result[0][0]))
            }
        case unicode.IsDigit(r):
            return r
        }
    }
    // 兜底:找不到合适字符时返回 #
    return '#'
}

func main() {
    names := []string{"Alice", "Bob", "小智晖", "张三", "李四", "王老虎"}

    for _, name := range names {
        letter := initialOf(name)
        img, err := letteravatar.Draw(120, letter, &letteravatar.Options{
            PaletteKey: name, // 同一昵称 -> 同一颜色
        })
        if err != nil {
            log.Fatal(err)
        }

        f, err := os.Create(name + ".png")
        if err != nil {
            log.Fatal(err)
        }
        if err := png.Encode(f, img); err != nil {
            log.Fatal(err)
        }
        f.Close()
    }
}
```

几个要点:

- `PaletteKey: name` 把昵称本身作为颜色键，这样「小智晖」每次生成的都是同一种背景色。
- `unicode.ToUpper` 让小写字母也渲染为大写，视觉上更整齐。
- 汉字范围 `0x4E00 ~ 0x9FFF` 是 CJK 统一表意文字（U+4E00–U+9FFF）的基本块;若要覆盖扩展区（部分生僻字）,可改用 `unicode.Is(unicode.Han, r)` 判断。
- 兜底返回 `#` 是为了在昵称里没有任何可绘制字符时（比如纯 emoji）也不至于崩。

## 在 HTTP 服务里返回头像

实际项目中，通常会把头像暴露成一个 HTTP 接口。最简单的形态:

```go
http.HandleFunc("/avatar/", func(w http.ResponseWriter, r *http.Request) {
    name := r.URL.Query().Get("name")
    if name == "" {
        name = "Anonymous"
    }
    letter := initialOf(name)
    img, err := letteravatar.Draw(120, letter, &letteravatar.Options{
        PaletteKey: name,
    })
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    w.Header().Set("Content-Type", "image/png")
    // 线上服务建议加上 Cache-Control 与 ETag
    _ = png.Encode(w, img)
})
```

几个生产环境的建议:

- **缓存**:`PaletteKey` 保证了输出确定性，可以放心在前面加 CDN 或反向代理缓存，加上 `Cache-Control: public, max-age=...` 即可。
- **回退到真实头像**:如果用户上传了自定义头像，优先 302 重定向到真实头像;没有时才回退到字母头像。
- **字体替换**:Roboto-Medium 不包含中文，但因为我们已经先转拼音，所以默认字体即可。如果想用统一品牌字体，可以解析自己的 `.ttf` 后传给 `Options.Font`。

## 前端 vs 后端

如果只是单纯想在前端浏览器里渲染字母头像，其实不必走 Go —— 用 CSS 把昵称首字母定位到彩色 `div` 上，或者用 Canvas 绘制，延迟更低、无需网络请求。

`letteravatar` 真正适合的场景是:

- 后端需要把头像以图片 URL 形式给到第三方（邮件、推送、IM 卡片）。
- 需要把头像嵌进 PDF、报表等无法跑 JS 的载体。
- 想要一份跟前端框架无关的统一渲染逻辑。

## 小结

`letteravatar` + `go-pinyin` 的组合不到 200 行就能给整站补齐「昵称首字母彩色头像」:前者负责绘图与确定性配色，后者负责把中文拉回 ASCII。关键三件事:**用 `PaletteKey` 保证颜色稳定**、**用 `FirstLetter` 风格拿拼音首字母**、**默认字体不含中文需要先转拼音**。

## 参考链接

- [disintegration/letteravatar](https://github.com/disintegration/letteravatar) — Go 字母头像生成库
- [mozillazg/go-pinyin](https://github.com/mozillazg/go-pinyin) — 汉语拼音转换工具 Go 版
- [letteravatar GoDoc](https://godoc.org/github.com/disintegration/letteravatar) — API 文档
- [《汉语拼音方案》](http://www.moe.gov.cn/s78/A19/yxs_left/moe_810/s230/195802/t19580201_186000.html) — 声母定义参考
