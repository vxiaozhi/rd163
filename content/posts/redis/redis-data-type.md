+++
title = "Redis 数据类型"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从 String 到 Stream:Redis 核心数据类型一览"
description = "系统梳理 Redis 支持的核心数据类型,重点介绍 Sorted Set、HyperLogLog 与 Stream 的原理、特性和典型应用场景。"
author = "小智晖"
authors = ["小智晖"]
categories = ["Redis"]
tags = ["Redis", "数据类型", "HyperLogLog", "Stream", "Sorted Set"]
keywords = ["Redis", "Redis 数据类型", "HyperLogLog", "Sorted Set", "Redis Stream", "Zset"]
toc = true
draft = false
+++

Redis 主要支持以下几种数据类型:

- **String(字符串)**:基本的数据存储单元，可以存储字符串、整数或者浮点数。
- **Hash(哈希)**:一个键值对集合，可以存储多个字段。
- **List(列表)**:一个简单的列表，可以存储一系列有序的字符串元素。
- **Set(集合)**:一个无序集合，可以存储不重复的字符串元素。
- **Zset(Sorted Set，有序集合)**:类似于集合，但是每个元素都有一个分数（score）与之关联。
- **位图（Bitmaps）**:基于字符串类型，可以对每个位进行操作。
- **HyperLogLog(超日志)**:用于基数统计，可以估算集合中的唯一元素数量。
- **Geospatial(地理空间)**:用于存储地理位置信息。
- **Pub/Sub(发布/订阅)**:一种消息通信模式，允许客户端订阅消息通道，并接收发布到该通道的消息。
- **Stream(流)**:用于消息队列和日志存储，支持消息的持久化和时间排序。
- **Modules(模块)**:Redis 支持动态加载模块，可以扩展 Redis 的功能。

## Zset(Sorted Set，有序集合)

Redis Zset 和 Set 一样，也是 string 类型元素的集合，且不允许重复的成员。

不同的是，每个元素都会关联一个 double 类型的分数。Redis 正是通过分数来为集合中的成员进行从小到大的排序。

Zset 的成员是唯一的，但分数（score）却可以重复。

关于为什么起名 Zset，社区里有两种解释:

- 前面的 Z 代表的是 XYZ 中的 Z,Zset 是在说这是比 Set 多了一个维度的 Set。
- Z 正好排在英文字母表中的最后一个，表示里面的元素都是类似于 ...X、Y、Z 这样按顺序排列的，所以叫 ZSET。

## HyperLogLog

HyperLogLog 是一种基数估算算法。所谓基数估算，就是估算在一批数据中，不重复元素的个数有多少。

从数学上来说，基数估计这个问题的详细描述是：对于一个数据流 {x1, x2, ..., xs} 而言，它可能存在重复的元素，用 n 来表示这个数据流的不同元素的个数，并且这个集合可以表示为 {e1, ..., en}。目标是：使用 m 这个量级的存储单位，可以得到 n 的估计值，其中 m 远小于 n，并且估计值和实际值 n 的误差是可以控制的。

对于上面这个问题，如果想得到精确的基数，可以使用字典（dictionary）这一数据结构。对于新来的元素，可以查看它是否属于这个字典;如果属于，则整体计数保持不变;如果不属于，则先把元素添加进字典，然后把整体计数加一。当遍历完整个数据流之后，得到的整体计数就是这个数据流的基数了。

这种算法虽然精准度很高，但是使用的空间复杂度也很高。那么是否存在一些近似的方法，可以估算出数据流的基数呢?HyperLogLog 就是这样一种算法，既能以较低的空间复杂度完成估算，最后得到的误差又是可以接受的。

### 应用场景举例

HyperLogLog 的主要应用场景就是进行基数统计，而这类问题的实际需求其实非常广泛。

例如，对于 Google 主页面而言，同一个账户可能会多次访问。于是在诸多的访问流水中，如何计算出 Google 主页面每天被多少个不同的账户访问过就是一个重要的问题。对于 Google 这种访问量巨大的网页而言，统计出十亿的访问量或十亿零十万的访问量其实并没有太大区别。因此，在这种业务场景下，为了节省成本，其实只需要计算出一个大概的值，而没有必要计算出精准的值。

对于上面的场景，可以使用 HashMap、BitMap 和 HyperLogLog 来解决。下面对这三种方案做一个简单对比:

- **HashMap**:算法简单，统计精度高，对于少量数据建议使用;但对于大量数据会占用很大的内存空间。
- **BitMap**:位图算法，统计精度高，虽然内存占用比 HashMap 少，但对于大量数据仍然会占用较大内存。
- **HyperLogLog**:存在一定误差，标准误差约为 0.81%;内存占用稳定，最多约 12 KB，最多可统计 2^64 个元素，适合上述应用场景。

## Stream

Redis Stream 是 Redis 5.0 版本新增的数据结构。

Redis Stream 主要用于消息队列（MQ,Message Queue）。Redis 本身提供了发布订阅（Pub/Sub）模式来实现消息队列的功能，但它有一个缺点：消息无法持久化，如果出现网络断开、Redis 宕机等情况，消息就会被丢弃。

简单来说，发布订阅（Pub/Sub）可以分发消息，但无法记录历史消息。

而 Redis Stream 提供了消息的持久化和主备复制功能，可以让任何客户端访问任何时刻的数据，并且能记住每一个客户端的访问位置，还能保证消息不丢失。

Stream 提供的功能可以类比其他消息队列中间件，如 Kafka。

## 参考链接

- [Redis Data Types 官方文档](https://redis.io/docs/latest/develop/data-types/)
- [Redis HyperLogLog 官方文档](https://redis.io/docs/latest/develop/data-types/probabilistic/hyperloglogs/)
- [Redis Streams 官方文档](https://redis.io/docs/latest/develop/data-types/streams/)
- [Redis Sorted Sets 官方文档](https://redis.io/docs/latest/develop/data-types/sorted-sets/)
- [Redis new data structure: the HyperLogLog — antirez](http://antirez.com/news/75)
