# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概览

**研发日志 · R&D Log**(`rd163`)—— 基于 Hugo + DoIt 主题的中文个人博客。
非交互式纯静态站点:无构建链(webpack/vite)、无前端框架、无测试套件、无 CI。
核心工作流就是「改 Markdown / TOML / SCSS → `hugo` 构建 → `public/` 由 Caddy 反代托管」。

## 常用命令(详见 Makefile,直接 `make` 看帮助)

```bash
make serve                                 # 本地预览(含草稿,127.0.0.1:1313)
make serve BIND=0.0.0.0 PORT=8080          # 外网临时预览(变量均可覆盖)
make build                                 # 生产构建 --minify → public/(即部署)
make new name=content/posts/<分类>/<slug>.md  # 新建文章(套用 archetypes/default.md)
make clean                                 # 清理 public/ resources/_gen/ .hugo_build.lock
make update-theme                          # 更新 DoIt submodule 到最新
```

**本机 Hugo**:`~/.local/bin/hugo`(v0.164.0 **extended**——必须 extended 才能编译 SCSS,Ubuntu apt 的 0.68 太旧不可用)。
**部署模型**:Caddy 反代本机 `public/`,所以 `make build` 就等于"上线",不存在单独的 deploy 命令——不要臆造部署脚本。

## 架构要点(需跨多文件理解的部分)

### 1. 配置分层:Hugo 多语言多文件结构
配置在 `config/_default/` 下拆成十几个 TOML,不是单一 `config.toml`。关键约定:
- `hugo.toml` —— 全站基底(baseURL/语言/主题/时区)
- `*.zh-cn.toml` —— 中文语言覆盖层(`defaultContentLanguage = "zh-cn"`)
- `params.toml` / `params.zh-cn.toml` —— 主题参数(站点标题在**两处都要改**:`hugo.toml` 的 `title` + `params.toml` 的 `[header.title].name` + `params.zh-cn.toml` 的 `[app].title`)
- 改站点级显示文字时,务必 grep 确认是否同时在 `params.toml` 与 `params.zh-cn.toml` 出现,以免改一处漏一处。

### 2. 主题作为 git submodule(不要直接改主题源码)
`themes/DoIt/` 是 `https://github.com/HEIGE-PCloud/DoIt` 的 submodule。
**所有定制走"项目级覆盖",而非改主题文件**——Hugo 资源系统让项目级文件优先于主题同名文件:

- **样式定制**:`assets/css/_override.scss`(覆盖 SCSS 变量)+ `assets/css/_custom.scss`(注入自定义样式/配色/动画)。主题编译 `style.scss` 时会自动 `@import` 这两个文件。
  - ⚠️ 已知坑:`_override.scss` 的 SCSS 变量在 Hugo 的 Dart Sass 编译链里**不生效**(覆盖机制不作用于 SCSS `@import` 的 partial)。字体族等需要在 `_custom.scss` 用纯 CSS(`font-family: ... !important`)覆盖,而非靠 SCSS 变量。
- **模板定制**:`layouts/_partials/head/link.html` 覆盖主题同名 partial(目前用于注入 Google Fonts 预连接 + 字体加载)。
- 配色走 CSS 变量系统:在 `_custom.scss` 用 `:root{}` 和 `html.dark{}` 重定义即可切深浅色,无需改主题。

视觉设计规范见 `.claude/DESIGN-PLAN.md`(主色靛蓝 `#5b6cff` + 青 `#06b6d4`,现代科技感)。

### 3. 内容组织
- 文章在 `content/posts/<分类>/<slug>.md`(56 个分类目录,225 篇)。
- front matter 用 **TOML(`+++`)** 格式(非 YAML),archetype 模板见 `archetypes/default.md`。字段:`title/date/lastmod/subtitle/description/author/authors/categories/tags/keywords/toc/draft`。
- 图片放 `static/imgs/`(约 3377 张),文章中以 `/imgs/xxx` 绝对路径引用。
- **永久链接**:`permalinks.toml` 设 `posts = "/posts/:slugorcontentbasename"`,改文件名会变 URL。
- `enableGitInfo = true` —— `lastmod` 自动取 git 提交时间,手改 front matter 的 `lastmod` 可能被覆盖。

### 4. 性能与远程资源
- `[image] cacheRemote = false` —— 故意关闭远程图缓存(文章含大量外部图床链接,缓存会导致构建超时)。
- `timeout = "5m"` —— 放宽单页渲染超时,同理防慢请求。
- `ignoreErrors = ["error-remote-getjson"]` —— 忽略远程 JSON 获取错误。

## 工作约定

- **提交前必跑** `make build` 验证构建通过(改了配置/样式尤其重要)。
- Markdown 解析用 Goldmark,`[goldmark.renderer] unsafe = true` —— 文章里可直接写 HTML 标签;支持 `\[ \]` `$$ $$` `\(\)` 数学公式 passthrough。
- `themes/DoIt` 的指针变更(submodule 更新)需连同 `.gitmodules` 一起提交。
- `public/` `resources/_gen/` `.hugo_build.lock` 已在 `.gitignore`,不要提交构建产物。
