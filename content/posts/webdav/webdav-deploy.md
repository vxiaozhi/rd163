+++
title = "WebDAV 自建方案选型与实践"
date = "2025-02-28"
lastmod = "2025-02-28"
subtitle = "从 Web 服务器扩展到专用服务器,横向对比五种主流自建方案"
description = "对比 Apache、Nginx、Caddy 与 hacdias/webdav、WsgiDAV 等主流 WebDAV 自建方案,分析各自优劣与适用场景。"
author = "小智晖"
authors = ["小智晖"]
categories = ["webdav"]
tags = ["webdav", "self-hosted", "nginx", "caddy", "go", "python"]
keywords = ["webdav", "webdav 自建", "hacdias webdav", "wsgidav", "caddy webdav", "obsidian 同步"]
toc = true
draft = false
+++

WebDAV(Web Distributed Authoring and Versioning,RFC 4918)是在 HTTP 之上扩展的一组方法(如 `PUT`、`PROPFIND`、`MKCOL`、`COPY`、`MOVE`),使得 Web 服务器可以当作可读写的网盘来用。相比 SFTP 或 NFS，它的优势在于走标准 HTTP(S) 端口、穿透代理和防火墙更友好，并且被几乎所有的笔记软件（如 Obsidian 的 Remotely Save 插件）、文件管理器（Windows 资源管理器、macOS Finder、Linux Nautilus/Dolphin）原生支持。

自建 WebDAV 的方案大致分两类：在通用 Web 服务器上加载 WebDAV 模块，或使用专用的 WebDAV 服务进程。下面分别梳理。

## Web 服务器方案

这类方案复用已有的 Apache / Nginx / Caddy，只需开启或追加 WebDAV 相关模块，适合已经部署了 Web 服务器、希望统一运维栈的场景。

### Apache HTTP Server

Apache 是最早原生支持 WebDAV 的 Web 服务器,`mod_dav` 和 `mod_dav_fs` 随主仓库分发，无需额外编译。开启方式是在 `httpd.conf` 或站点配置中:

```apache
DavLockDB /var/lib/dav/DavLock
Alias /dav /srv/webdav
<Location /dav>
    DAV On
    AuthType Basic
    AuthName "WebDAV"
    AuthUserFile /etc/apache2/webdav.passwd
    Require valid-user
</Location>
```

容器化部署社区里最知名的是 [bytemark/webdav](https://hub.docker.com/r/bytemark/webdav) 镜像，历史下载量超过千万，支持 Basic / Digest 认证、自签证书、通过 `USERNAME` / `PASSWORD` 环境变量或挂载 `/user.passwd` 配置多用户。**需要注意的是，该镜像已 7 年以上未更新**,基础系统包较老，不建议直接用于公网生产环境，若使用请置于反代之后并限制来源 IP。

### Nginx

Nginx 官方源码中自带的 `ngx_http_dav_module` 只实现了 `PUT`、`DELETE`、`MKCOL`、`COPY`、`MOVE` 子集,**缺少 `PROPFIND` 与 `OPTIONS`**,单独使用时大多数 WebDAV 客户端无法列目录。要支持完整的 WebDAV 语义，需要追加第三方扩展模块 [arut/nginx-dav-ext-module](https://github.com/arut/nginx-dav-ext-module),在编译时通过 `--add-module` 引入:

```bash
./configure --with-http_dav_module \
            --add-module=../nginx-dav-ext-module
make && sudo make install
```

对应的 Nginx 配置片段:

```nginx
location /dav/ {
    root /srv;
    dav_methods PUT DELETE MKCOL COPY MOVE;
    dav_ext_methods PROPFIND OPTIONS;
    dav_access user:rw group:rw all:r;
    create_full_put_path on;
    client_max_body_size 0;
    auth_basic "WebDAV";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

社区中有不少封装好的 Docker 镜像，例如 [ionelmc/webdav](https://hub.docker.com/r/ionelmc/webdav) 及其 Fork [erikluo/docker-webdav](https://github.com/erikluo/docker-webdav)。前者基于 Ubuntu Xenial(16.04，早已 EOL),同样多年未更新;后者仓库活跃度极低。对于生产环境，更稳妥的做法是自行基于官方 `nginx` 镜像编译扩展模块。

### Caddy

Caddy 官方主仓库默认 **不** 包含 WebDAV 处理器，需要通过社区模块 [mholt/caddy-webdav](https://github.com/mholt/caddy-webdav) 扩展。使用 `xcaddy` 构建带模块的自定义二进制:

```bash
xcaddy build --with github.com/mholt/caddy-webdav
```

`Caddyfile` 中的写法:

```caddy
example.com {
    root * /srv/webdav

    @webdav {
        method PUT DELETE MKCOL COPY MOVE PROPFIND OPTIONS PATCH
    }
    handle @webdav {
        webdav {
            root /srv/webdav
        }
    }
    handle {
        file_server
    }

    basicauth /* {
        admin $2a$14$...
    }
}
```

注意 `PUT` 需要写权限：运行 Caddy 的用户(通常是 `caddy`)必须对存储目录拥有写入权限，systemd 部署下还可能需要在 unit 文件中通过 `ReadWriteDirectories` 放开。Caddy 方案最大的红利是可以直接复用其自动 HTTPS，免去额外证书运维。

## 专用服务器方案

如果不需要复用现有 Web 服务器，独立的 WebDAV 守护进程部署更轻量，也更适合放进容器里跟其他服务隔离。这类实现通常把 WebDAV 作为核心功能，协议完整度和性能都优于"打补丁"式的模块方案。

### hacdias/webdav(Go)

[hacdias/webdav](https://github.com/hacdias/webdav) 是一款用 Go 编写的独立 WebDAV 服务器，单二进制、跨平台，MIT 协议。当前主分支为 v5 系列，稳定版本持续更新。

主要特性:

- 单一可执行文件，零依赖，适合 systemd 或容器部署
- 支持 Basic 认证，密码可用明文或 bcrypt 存储
- 按 用户 × 路径 × 方法 的细粒度权限（增、删、改、读）,可用正则规则限定
- 支持 SabreDAV 的 `PATCH` 扩展和 `Content-Range` 断点上传
- CORS、Fail2Ban 规则、反代示例齐备

安装:

```bash
# Go 工具链
go install github.com/hacdias/webdav/v5@latest

# 或 Homebrew
brew install webdav

# 或 Docker
docker pull ghcr.io/hacdias/webdav
```

配置文件支持 YAML / JSON / TOML。注意 v5 与 v4 的配置结构差异较大:v5 去掉了 `auth`/`scope`/`modify`/`delete` 字段——认证在检测到 `users` 时隐式启用,根目录改用 `directory` 指定,权限合并进 `permissions` 的字母组合(C/R/U/D),`users` 从 map 改为**列表(list)**。以下是一份最小化的 v5 `config.yml` 示例:

```yaml
address: 0.0.0.0
port: 6065
prefix: /
behindProxy: false        # 反代时改为 true,从 X-Forwarded-For 取真实 IP
directory: /srv/webdav    # v5:根目录(取代 v4 的 scope)
permissions: CRUD         # 全局默认权限,字母组合: C=Create/R=Read/U=Update/D=Delete
users:                    # v5:列表形式
  - username: admin
    password: "{bcrypt}$2a$14$..."   # 推荐 bcrypt
    permissions: CRUD
    rules:
      - regex: ^/private
        permissions: R               # /private 只读
```

启动后即得到一个开箱即用的 WebDAV 端点，非常适合个人自托管。

### WsgiDAV(Python)

[WsgiDAV](https://github.com/mar10/wsgidav) 是基于 WSGI 的通用 WebDAV 服务器，MIT 协议，当前主分支为 v4.3.x。相较于 Go 版本的"小而美",WsgiDAV 走的是"可嵌入、可扩展"路线:

- 独立运行，自带 SSL，跨 Linux / macOS / Windows
- `pip install wsgidav` 一行安装，也可用 Docker 镜像 `mar10/wsgidav`
- 实现了完整的 WebDAV(RFC 4918)协议栈，中间件栈可自定义
- 支持 Anonymous、PAM、文件等多种认证后端
- 提供 `FilesystemProvider` 直接读写本地目录

最小启动命令:

```bash
pip install wsgidav cheroot
wsgidav --host 0.0.0.0 --port 8080 \
        --root /path/to/vault \
        --auth anonymous
```

生产环境推荐用 `wsgidav.yaml` 显式声明用户与权限:

```yaml
host: 0.0.0.0
port: 8080
provider_mapping:
  "/":
    filesystem: /path/to/vault
simple_dc:
  user_mapping:
    "*":
      user1:
        password: "strong-pass"
      user2:
        password: "another-pass"
```

WsgiDAV 在笔记社区里常被用作 Obsidian + [Remotely Save](https://github.com/remotely-save/remotely-save) 插件的后端，支持完整 WebDAV 语义，跨桌面和移动端同步体验稳定。

## 方案选型建议

- **已有 Apache / Nginx / Caddy 站点**:优先复用现有 Web 服务器，但要接受模块化方案的协议完整度和维护度差异。
- **追求轻量、单二进制**:选 `hacdias/webdav`,部署成本最低、性能最好。
- **需要嵌入 Python 应用或对接 Obsidian**:选 WsgiDAV，生态最贴近。
- **公网暴露**:任何方案都应前置反向代理并启用 HTTPS，认证密码使用 bcrypt，配合 Fail2Ban 限制爆破。

## 参考

- RFC 4918 - HTTP Extensions for Web Distributed Authoring and Versioning (WebDAV): <https://datatracker.ietf.org/doc/html/rfc4918>
- [hacdias/webdav](https://github.com/hacdias/webdav) - Go 实现的独立 WebDAV 服务器
- [mar10/wsgidav](https://github.com/mar10/wsgidav) - Python WSGI 实现的通用 WebDAV 服务器
- [arut/nginx-dav-ext-module](https://github.com/arut/nginx-dav-ext-module) - Nginx WebDAV 扩展模块
- [mholt/caddy-webdav](https://github.com/mholt/caddy-webdav) - Caddy 的 WebDAV 处理器模块
- [Apache mod_dav 文档](https://httpd.apache.org/docs/2.4/mod/mod_dav.html)
