# 小智晖博客视觉优化方案(现代科技感)

## 设计方向(已确认)
- **气质**:现代科技感,高对比、利落、几何。参考 Vercel / Linear / GitHub 的审美
- **主色**:靛蓝 `#5b6cff` + 青 `#06b6d4`(渐变点缀)
- **背景**:纯白 `#ffffff` / 深空黑 `#0a0a0a`(深色模式)
- **字体**:英文 Inter + 等宽 JetBrains Mono;中文用 Web 字体
- **圆角/阴影**:8–12px 圆角 + 微妙阴影(克制)

## 实现机制(不碰主题源码,优雅可维护)
DoIt 提供两个用户覆盖钩子,Hugo 资源系统会让**项目级文件优先于主题文件**:
- `assets/css/_override.scss` — 覆盖 SCSS 变量(字体族、字号、间距)
- `assets/css/_custom.scss` — 注入自定义样式(配色变量、组件美化、动画)

主题编译 `style.scss` 时会自动 `@import` 这两个文件。配色走 CSS 变量系统,在 `_custom.scss` 用 `:root{}` 和 `html.dark{}` 重定义即可,无需改主题。

## 改动清单

### 1. `assets/css/_override.scss`(字体变量层)
- 覆盖 `$global-font-family`:加入 Inter 优先
- 覆盖 `$global-font-size`:16px(保持)
- 标题字重、等宽字体族优化

### 2. `assets/css/_custom.scss`(核心样式,约 300 行)
**A. 字体加载(@font-face via CDN)**
- 中文:思源黑体 Noto Sans SC(用 Google Fonts CSS,subset 化,font-display: swap)
- 英文:Inter
- 等宽:JetBrains Mono(代码块)
- 全局 `font-display: swap` 避免 FOIT
- `-webkit-font-smoothing: antialiased` 抗锯齿

**B. 配色系统重定义(CSS 变量)**
浅色 `:root`:
- 主色 `--global-link-color` / `--single-link-color`:靛蓝 `#5b6cff`
- hover:`#06b6d4`(青,渐变感)
- 背景:`#ffffff`,二级文字 `#525252`(更柔和的灰阶)
- 边框/分隔:`#e5e5e5`
- 引用块:靛蓝左边框 + 极浅靛蓝底
- 选中色:靛蓝半透明

深色 `html.dark`:
- 背景 `#0a0a0a`(深空黑,而非默认的 `#0d1117`)
- 二级背景 `#141414`,边框 `#262626`
- 主色提亮 `#7c8bff`(深色背景下更醒目)
- 文字 `#ededed`

**C. 头部导航(Header)**
- 半透明毛玻璃 backdrop-filter(blur)+ 滚动时加深
- Logo + 标题:微调字距
- 菜单项 hover:下划线滑入动画

**D. 首页个人资料区(Home Profile)— 视觉重点**
- 头像:圆形 + 靛蓝→青渐变描边光环(ring)+ 悬停放大
- 副标题(TypeIt 打字机):等宽字体,光标用主色
- 社交链接图标:圆形 hover 背景 + 缩放

**E. 文章卡片(Summary Card)— 信息层次**
- 卡片化:每个 `.single.summary` 加圆角 + 微阴影 + 左侧 3px 主色条(hover 时显色/加粗)
- hover:轻微上浮(translateY -2px)+ 阴影加深
- 标题:加粗 + hover 变主色
- 元信息(日期/分类/标签):更小、更灰、用主色点缀关键标签
- "阅读全文":改为带箭头的胶囊按钮样式

**F. 文章正文(Single Page)阅读体验**
- 正文宽度收窄到 ~720px(最佳中文阅读行宽 ~35 字)
- 行高加大到 1.8(中文需要更宽松)
- 段落间距优化
- 标题:层级清晰的字重/字号梯度,h1/h2 带底部渐变细线
- 代码块:深色背景 + 主色标题栏 + JetBrains Mono + 圆角
- 引用块:靛蓝左边框 + 浅底 + 主色文字
- 表格:圆角 + 斑马纹 + 表头主色

**G. 目录(TOC)**
- 当前激活项主色高亮 + 左边框
- 平滑过渡

**H. 分页(Pagination)**
- 胶囊按钮样式 + hover 主色
- 当前页主色填充

**I. 细节精致化**
- 自定义滚动条(细,主色滑块)
- 全局过渡曲线 `cubic-bezier(0.4, 0, 0.2, 1)`
- 选区颜色
- 图片圆角 + 微阴影
- 链接 hover 下划线动画

### 3. `config/_default/params.toml`(微调)
- `[header.title]` 图标换更几何感的(Microchip 已用,保留或换成几何符号)
- `[page.lightgallery]` 已开,保留(图片点击放大)

## 不做(克制原则)
- 不动主题源码(全部通过 _custom/_override 覆盖,主题可正常升级)
- 不加重型动画库(纯 CSS transition)
- 不加大图/背景图(保持科技感的"留白"清爽)
- 不改 Hugo 模板(纯样式层优化)

## 验证
1. `hugo --gc` 重新构建(SCSS 会重新编译)
2. 验证 `/css/style.min.css` 含新样式
3. 浏览器验证:首页 / 文章页 / 深浅切换 / 移动端
4. Caddy 静态伺服自动生效

## 风险
- 中文 Web 字体首次加载慢:用 font-display: swap + 子集化缓解,即使字体未加载也先用系统字体显示
- Google Fonts 在国内可能慢:首选用 jsDelivr/字节跳动的 CDN 镜像(更稳),而非直连 Google
- SCSS 编译错误:Hugo 会报错,可即时发现
