+++
title = "Nginx 内存池机制"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "从 ngx_pool_t 结构到小块与大块内存的分配策略"
description = "剖析 Nginx 内存池的核心数据结构、小块与大块内存的分配方式、cleanup 机制，以及一页内存大小阈值背后的设计考量。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "nginx", "内存池", "源码分析", "C 语言"]
keywords = ["nginx", "内存池", "ngx_pool_t", "ngx_palloc", "内存管理"]
toc = true
draft = false
+++

Nginx 的内存池设计得非常精妙，它在满足小块内存申请的同时，也处理大块内存的申请请求，同时还允许挂载自己的数据区域及对应的数据清理操作。

Nginx 内存池的实现主要集中在 `src/core/ngx_palloc.{h,c}` 中，一些支持函数位于 `src/os/unix/ngx_alloc.{h,c}` 中。这些支持函数主要是对原有的 `malloc` / `free` / `memalign` 等函数的封装。

Nginx 内存池中有两个非常重要的结构。一个是 `ngx_pool_s`，主要作为整个内存池的头部，管理内存池结点链表、大块内存链表、cleanup 链表等，具体结构如下：

```c
// 该结构维护整个内存池的头部信息
struct ngx_pool_s {
    ngx_pool_data_t       d;         // 数据块
    size_t                max;       // 小块内存的最大值
    ngx_pool_t           *current;   // 指向当前用于分配的内存池结点
    ngx_chain_t          *chain;     // 可挂载一个 chain 结构
    ngx_pool_large_t     *large;     // 大块内存链表，分配超过 max 的请求
    ngx_pool_cleanup_t   *cleanup;   // 内存池销毁时同时释放的资源
    ngx_log_t            *log;
};
```

另一个重要的结构是 `ngx_pool_data_t`，用于把具体的内存池结点连接起来：

```c
// 内存池数据块信息
typedef struct {
    u_char               *last;      // 当前分配位置
    u_char               *end;       // 该结点的结束位置
    ngx_pool_t           *next;      // 连接下一个内存池结点
    ngx_uint_t            failed;    // 分配失败计数
} ngx_pool_data_t;
```

此外还有大块内存结构和清理结构，二者都通过单链表组织：

```c
// 大块内存结构
struct ngx_pool_large_s {
    ngx_pool_large_t     *next;      // 下一个大块内存
    void                 *alloc;     // Nginx 分配出的大块内存空间
};

// cleanup 结构
struct ngx_pool_cleanup_s {
    ngx_pool_cleanup_pt   handler;   // 数据清理的函数句柄
    void                 *data;      // 要清理的数据
    ngx_pool_cleanup_t   *next;      // 连接至下一个
};
```

## 特点

总结起来，Nginx 内存池具有如下特点：

- **原理**：内存池是在真正使用内存之前，预先申请分配一定数量的、大小相等（一般情况下）的内存块留作备用。当有新的内存需求时，就从内存池中分出一部分内存块；若内存块不够用时，再继续申请新的内存。
- **好处**：减少向系统申请和释放内存的时间开销，缓解内存频繁分配产生的碎片问题，提升程序性能。
- **按生命周期管理**：Nginx 会为不同的对象分别创建内存池进行内存管理，例如一个 TCP 连接、一个 HTTP 请求等。在对应的生命周期结束时，会摧毁整个内存池，把分配的内存一次性归还给操作系统。
- **小块与大块内存的区分**：在分配内存时，Nginx 区分小块内存与大块内存。对于小块内存，Nginx 会尝试在当前的内存池结点中分配；对于大块内存，则调用系统函数 `malloc` 向操作系统申请。
- **小块内存不单独释放**：在释放内存时，Nginx 没有专门提供针对小块内存的释放函数，小块内存会在 `ngx_destroy_pool` 和 `ngx_reset_pool` 时一并释放。
- **大块内存可单独释放**：针对大块内存，Nginx 提供了单独的释放函数 `ngx_pfree`（仅对挂在 `large` 链表上的大块内存生效，对小块内存返回 `NGX_DECLINED`）。
- **大块与小块的分界线是一页内存**：`p->max = (size < NGX_MAX_ALLOC_FROM_POOL) ? size : NGX_MAX_ALLOC_FROM_POOL`，其中 `NGX_MAX_ALLOC_FROM_POOL` 在 `src/core/ngx_palloc.h` 中定义为 `ngx_pagesize - 1`，而 `ngx_pagesize` 在 `src/os/unix/ngx_posix_init.c` 中通过 `getpagesize()` 获取（在 x86/Linux 上通常为 4096，故阈值为 4095 字节）。
- **为何阈值取一页**：大于一页的内存在物理上不一定是连续的，所以如果分配的内存大于一页，从内存池中使用和向操作系统重新申请，效率上差不多等价。

## 参考

- [Nginx 官方源码 ngx_palloc.h](https://github.com/nginx/nginx/blob/master/src/core/ngx_palloc.h)
- [Nginx 官方源码 ngx_palloc.c](https://github.com/nginx/nginx/blob/master/src/core/ngx_palloc.c)
- [初识 Nginx —— 内存池篇](https://www.cnblogs.com/magicsoar/p/6040238.html)
- [这是我见过最详细的 Nginx 内存池分析](https://xie.infoq.cn/article/7da75d942a40970e0538f734d)
