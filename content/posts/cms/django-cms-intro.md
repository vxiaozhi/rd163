+++
title = "django-cms"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "基于 Django 的企业级开源内容管理系统入门"
description = "介绍 django-cms 的核心概念、架构特性与基于 Docker 的快速启动流程,适合需要二次开发企业官网的团队参考。"
author = "小智晖"
authors = ["小智晖"]
categories = ["cms"]
tags = ["cms", "django", "django-cms", "python", "docker"]
keywords = ["django-cms", "Django CMS", "Python CMS", "企业级 CMS", "Docker 部署"]
toc = true
draft = false
+++

由 Django 编写的企业级 CMS(Content Management System，内容管理系统),它功能实用、安全可靠，支持拖拽上传图片、轮播图、Docker 部署等功能，可轻松进行二次开发，多用于构建企业官网，比如：国家地理（National Geographic）、NASA、L'Oréal、Canonical、PBS 等机构的网站都基于它开发而成。本文整理其背景、核心概念与本地启动方式，方便快速评估是否适合自己的项目。

## 项目背景

django CMS 是一个开源的、面向企业与机构的 Web 内容管理系统，构建在 Django Web 框架之上，使用 Python 编写，采用 **BSD-3-Clause** 许可证发布。

项目演进的关键节点:

- **django CMS 1.0**:由 Thomas Steinacher 创建。
- **django CMS 2.0**:由 Patrick Lauber 完全重写，基于 `django-page-cms` 的一个 fork。
- **django CMS 3.0**(2013 年发布):确立了现代插件式架构与前端编辑（Editing）体验。
- **2020 年 7 月**:原维护方 Divio 将项目移交给新成立的非营利组织 **django CMS Association(dCA)**,由社区主导后续发展。
- **当前主版本**:5.x 系列已是稳定主线，引入了 headless(无头)能力、内容版本化与更现代的工作流。

它曾获 CMS Critic 2019 年度「最佳开源 CMS」奖项，在企业官网、高校门户、媒体机构场景中被广泛采用。

## 核心特性

从工程视角看，django CMS 的几个关键卖点如下:

- **前端编辑（Frontend Editing）**:管理员登录后可直接在页面所见即所得地编辑内容，无需在后台表单与前台页面之间来回切换。
- **占位符与插件（Placeholders & Plugins）**:这是 django CMS 最核心的抽象。页面模板预留占位符，内容由插件按需填充，插件可复用、可自定义。
- **多语言与多站点（Multilingual & Multisite）**:原生支持多语言内容与多站点管理，适合出海或跨国项目。
- **版本控制与工作流（Versioning & Workflow）**:5.x 版本内置了内容版本化与发布工作流，支持草稿、审核、发布等状态。
- **Headless 模式**:5.x 提供无头能力，可把内容通过 API 输出给前端框架（React、Vue、Next.js 等）。
- **权限与角色**:细粒度的用户角色和权限模型，适配多人协作的编辑团队。
- **生态丰富**:围绕 djangocms-* 形成了大量第三方插件，涵盖图集、轮播、表单、SEO 等常见需求。

## 核心概念

理解下面三个概念，基本就掌握了 django CMS 的内容组织方式。

### Placeholder(占位符)

Placeholder 是模板中预留给「动态内容」的区域。在 Django 模板里通过 `{% placeholder %}` 标签声明，例如:

```html
{% load cms_tags %}
{% placeholder "content" %}
```

编辑器会在这些区域里添加插件，前端根据插件渲染出最终 HTML。占位符的数量、位置完全由模板决定。

### Plugin(插件)

Plugin 是可复用的内容单元，例如「文本」「图片」「轮播图」「视频」等。每一个插件都对应一段 Python 类（Django Model + CMSPlugin 子类）、一段渲染模板。开发者可以编写自定义插件来封装业务组件（比如「产品介绍块」「团队成员卡片」）。

### Template(页面模板)

页面模板定义了页面的整体布局，并在其中放置占位符。同一套 CMS 可以挂载多套模板（首页模板、栏目页模板、详情页模板等）,编辑在后台为某个页面选择对应模板即可。

此外还有一个进阶概念 **Apphook(应用挂载)**:可以把一个普通的 Django App「挂载」到 CMS 的某个 URL 路径下，使业务页面与 CMS 页面共享导航、权限和布局。

## 版本兼容性

以当前稳定版 **django CMS 5.1.x** 为例，官方文档给出的兼容矩阵如下:

| Django 版本 | 是否支持 |
| --- | --- |
| 6.0 | 支持 |
| 5.2 | 支持 |
| 5.1 | 支持 |
| 6.1 | 暂不支持 |
| 5.0 及以下 | 不支持 |

Python 支持 3.9 至 3.14。新项目建议直接从 5.x 起步，3.11 仅作为旧系统的过渡版本。

## 基于 Docker 的快速启动

官方提供了 [django-cms-quickstart](https://github.com/django-cms/django-cms-quickstart) 模板，内置 Docker Compose 配置，几分钟即可跑起一个可用的 CMS 实例。该模板由 django CMS Association 背书，基于 Python 3.11、Django 4.2、django CMS 4.1.0 构建，适合作为本地试用和二次开发的起点。

前置条件：本地已安装 Docker(包含 Compose V2)。

```bash
git clone git@github.com:django-cms/django-cms-quickstart.git
cd django-cms-quickstart
docker compose build web
docker compose up -d database_default
docker compose run --rm web python manage.py migrate
docker compose run --rm web python manage.py createsuperuser
docker compose up -d
```

各步骤说明:

1. `build web`:构建 Web 服务镜像（包含 Django 与 django CMS 依赖）。
2. `up -d database_default`:后台启动数据库（PostgreSQL）容器。
3. `migrate`:在数据库中创建 CMS 所需的全部表结构。
4. `createsuperuser`:创建超级管理员账号，用于登录后台与前端编辑。
5. `up -d`:启动整套服务（Web + 数据库）。

启动完成后，浏览器访问:

- `http://django-cms-quickstart.127.0.0.1.nip.io:8000`(官方推荐，便于 cookie 与子域名隔离)
- 或 `http://127.0.0.1:8000`

首次访问会进入引导向导，按提示创建第一个页面即可。常用维护命令:

```bash
docker compose stop        # 停止服务,保留容器
docker compose start       # 再次启动
docker compose down        # 删除容器(数据库卷与 media 文件保留)
```

`down` 之后再次构建启动时,`docker compose build web && docker compose up -d` 即可恢复，数据不会丢失。

## 何时选择 django CMS

它适合:

- 需要一个**由社区(django CMS Association)主导、可深度二次开发**的企业官网或品牌站。
- 内容编辑需要**所见即所得**的前端编辑体验，且有多语言、多站点诉求。
- 希望复用 Django 的 ORM、Auth、Admin 等基础设施，把 CMS 作为业务模块的一部分。

需要权衡的点:

- 相比 Ghost、Strapi 等更「现代」的无头 CMS,django CMS 的前端编辑体验更适合传统服务端渲染场景;虽然 5.x 已支持 headless，但生态成熟度仍在追赶。
- 对 Python/Django 不熟悉的团队，学习成本会比 PHP 系（WordPress、Drupal）或 Node.js 系 CMS 高一些。

## 参考

- 官方网站:[django-cms.org](https://www.django-cms.org/)
- 官方文档:[docs.django-cms.org](https://docs.django-cms.org/)
- 快速启动模板:[django-cms/django-cms-quickstart](https://github.com/django-cms/django-cms-quickstart)
- 主仓库:[django-cms/django-cms](https://github.com/django-cms/django-cms)
- 项目治理:[django CMS Association(dCA)](https://www.django-cms.org/en/community/)
