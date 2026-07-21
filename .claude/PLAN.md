# Hugo 个人博客搭建计划(DoIt 主题)

## 目标
为用户(vxiaozhi/小智晖)搭建一个 Hugo 中文个人博客,用于 R&D。主题选用 **DoIt**(LoveIt 官方维护分支,中文社区最流行,2026-07-20 仍在更新)。从源 Jekyll 博客 `../vxiaozhi.github.io/` 迁移全部 251 篇 2025 年文章 + 个人简介。本次仅本地搭建预览,不配置部署。

## 技术决策(已调研验证)
- **Hugo 版本**:v0.164.0 extended 版(DoIt v1.0.2 要求 extended 以编译 SCSS;Ubuntu apt 版本 0.68 太旧不可用)
- **安装方式**:从 GitHub Release 下载 `hugo_extended_0.164.0_linux-amd64.tar.gz`,解压到 `~/.local/bin/`
- **主题安装**:git submodule 方式引入 DoIt(便于后续更新)
- **迁移源**:`/home/lighthouse/github.com/vxiaozhi/vxiaozhi.github.io/docs/`(Jekyll + Huxpro 主题)
- **文章数**:251 篇(全部 2025 年),front matter 字段统一(layout/title/subtitle/date/author/catalog/tags),无 Liquid 标签,迁移干净

## 目录结构(最终)
```
rd163/
├── config.toml                  # 站点配置(DoIt 配置)
├── hugo.toml 或 config/         # 采用单文件 config.toml(简洁,便于 DoIt)
├── archetypes/
│   └── default.md               # 新文章模板(带 DoIt front matter)
├── content/
│   ├── posts/                   # 251 篇迁移文章(保留分类子目录)
│   │   ├── golang/
│   │   ├── k8s/
│   │   └── ...
│   └── about.md                 # 个人简介(中文)
├── static/
│   └── imgs/                    # 3377 张博客图片(绝对路径 /imgs/xxx)
├── themes/
│   └── DoIt/                    # git submodule
├── .gitignore                   # 忽略 public/、resources/、themes/(按需)
└── README.md                    # 更新使用说明
```

## 实施步骤

### 阶段 1:环境准备
1. 下载 Hugo extended v0.164.0 linux-amd64 二进制 → 解压到 `~/.local/bin/hugo`
2. 验证 `hugo version` 显示 `+extended`
3. 把 `~/.local/bin` 加入 PATH(若未在)

### 阶段 2:站点初始化
1. 在 `rd163/` 执行 `hugo new site . --force` 生成骨架
2. 用 git submodule 添加 DoIt 主题:`git submodule add https://github.com/HEIGE-PCloud/DoIt themes/DoIt`
3. 编写 `config.toml`(基于 DoIt 官方推荐配置),包含:
   - 站点信息:标题"小智晖的博客"/SEOTitle/作者/email/description/关键词/url
   - 语言:zh-cn 为默认,配置中文导航菜单
   - DoIt 主题参数:首页布局、搜索(本地 Lunr)、目录、代码高亮、暗色模式、KaTeX 数学公式、Mermaid、GitHub 社交链接
   -永久链接(permalink)用 Jekyll 兼容的 `/:year/:month/:slug/` 或保留分类 `/:categories/:slug/`

### 阶段 3:内容迁移(用 Python 脚本自动化)
编写迁移脚本 `/tmp/migrate.py`,遍历源 `_posts/zh/**/*.md`,对每篇:
1. **提取分类**:从路径 `_posts/zh/<category>/` 取得 category(源文章无显式 categories 字段)
2. **转换 front matter**(Jekyll → Hugo):
   - 删除 `layout: post`(Hugo 不需要)
   - 保留 `title`、`subtitle`→映射为 `description`、`date`、`author`
   - `tags` 保留
   - 新增 `categories: [<从路径提取>]`
   - `catalog: true` → DoIt 自动生成目录(无需字段)
3. **目标文件名**:去掉 Jekyll 日期前缀,保留 slug。日期从 front matter 取。例如 `2025-02-14-llm-retrieval-augmented-generation.md` → `posts/llm/llm-retrieval-augmented-generation.md`
4. **修正异常文件名**:`webp-format-conversion.md.md` → 单 `.md`
5. 正文 Markdown **原样保留**(图片用绝对路径 `/imgs/xxx`,无需改动;代码块 GFM 兼容)
6. **统计**:输出迁移成功/跳过/失败计数,记录跳过原因(如有)

输出到 `content/posts/<category>/<slug>.md`。

### 阶段 4:静态资源 + 个人简介
1. 复制源 `imgs/` 全目录 → `static/imgs/`(3377 张图,绝对路径 `/imgs/` 即可访问)
2. 创建 `content/about.md`:用 DoIt about 布局,内容来自源 `_includes/about/zh.md`(中文个人简介),front matter 设 `layout: "about"` 或 DoIt 标准 about 页配置
3. 配置首页头像(用源 `sidebar-avatar` 的 `https://github.com/vxiaozhi.png`)

### 阶段 5:本地验证
1. `hugo server -D --bind 0.0.0.0 --port 1313` 启动本地服务
2. 验证:
   - 首页正常加载、文章列表显示
   - 随机点开 3-5 篇文章,正文/图片/代码块/目录正常
   - 分类页、标签页、搜索功能可用
   - about 页正常
   - 暗色模式切换正常
3. `hugo` 构建,确认无错误,检查 `public/` 产物大小合理

### 阶段 6:收尾
1. 更新 `README.md`:说明本地预览命令、目录结构、主题来源、迁移来源
2. 配置 `.gitignore`(忽略 public/、resources/_assets/)
3. 验证 git status 干净,提交

## 风险与备选
- **Hugo extended 下载失败**:备选用 `go install github.com/gohugoio/hugo@latest`(已有 Go 1.23)
- **DoIt submodule 克隆失败/慢**:备选下载 release zip 解压到 themes/DoIt(非 submodule)
- **个别文章 front matter 异常**:脚本遇到解析失败的跳过并记录,不中断整体迁移
- **图片体积**:3377 张图可能较大,但属必要资源;如构建过慢可后续优化(本次不处理)

## 不做(范围外)
- 不配置部署(CI/CD、GitHub Pages、域名)— 用户明确仅本地预览
- 不迁移英文 about(源博客有中英双语,本次只做中文,符合用户"语言用中文"要求)
- 不做主题深度二次定制(用 DoIt 默认样式 + 标准配置)
- 不写新文章(仅迁移存量 + about)
