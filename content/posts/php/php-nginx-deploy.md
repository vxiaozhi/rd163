+++
title = "Php + Nginx 部署"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "Php + Nginx 部署"
description = "Php + Nginx 部署"
author = "小智晖"
authors = ["小智晖"]
categories = ["php"]
tags = ["编程语言", "php"]
keywords = []
toc = true
draft = false
+++

# Php + Nginx 部署

这里介绍三种部署模式：

## 1. 常规部署

参考 [php-nginx](php-nginx.md)

## 2. Dockerfile 单镜像部署

- [Docker PHP-FPM 8.3 & Nginx 1.26 on Alpine Linux](https://github.com/TrafeX/docker-php-nginx) supervisord 【1.x版本支持PHP7.4 2.0开始升级到PHP8】

- [Docker PHP-FPM 8.2.7 & Nginx ](https://github.com/richarvey/nginx-php-fpm) supervisord + letsencrypt证书生成

## 3. Docker Compose 部署

参考 

- [Docker-compose php:7.4.3 & Nginx](https://github.com/mhilker/docker-nginx-php-example)  PHP-FPM中没有集成MySQL扩展。

