+++
title = "内存优化综述"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "按对象特性分类:内核与应用层的通用内存管理策略"
description = "从 Linux SLAB/SLUB 到 Nginx 内存池,梳理对象池、延迟销毁、动态生成三类内存特性背后的优化思路。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "memory", "allocator", "slab", "slub", "内存池"]
keywords = ["内存优化", "对象池", "SLAB 分配器", "SLUB", "Nginx 内存池", "延迟销毁"]
toc = true
draft = false
+++

任何一个复杂系统的内存分配与释放策略，其最优解几乎都不是依赖某一种「通用」的分配器，而是**按照对象的特性进行分类管理**:把不同生命期、不同大小、不同访问模式的对象，交给与之匹配的专用机制来处理。这种「分而治之」的思路贯穿了从内核到应用层的所有高性能内存子系统。

按特性粗略划分，可以把内存对象归为三类:

- **对象池（Object Pool）** —— 大小固定、频繁创建销毁的对象。
- **延迟销毁（Lazy Deletion）** —— 引用关系复杂、不能立即释放的对象。
- **动态生成（Dynamic Generation）** —— 内容与生命周期不可预测、按需构造的对象。

下面分别讨论它们为什么比通用分配算法更快，以及业界如何落地。

## 一、对象池：把「分配」变成「移动指针」

如果有大量**相同大小**的对象需要反复分配与回收，最高效的做法是预先创建一批对象放进池子，用**空闲链（free list）** 串起来：分配时从链头摘一个，回收时挂回链头。两次操作都是 O(1),且完全不涉及通用分配器内部的位图搜索、桶分裂、合并伙伴块等开销。

这一思路最经典的工程实现就是 Jeff Bonwick 在 1994 年为 SunOS 5.4 设计的 **Slab 分配器**("The Slab Allocator: An Object-Caching Kernel Memory Allocator",USENIX Summer 1994)。它的核心洞察有三点:

1. **缓存的是已初始化的对象，不是裸字节**。释放时不真正析构，分配时不重新构造，省掉了大量重复的初始化代价(比如 `inode`、`task_struct`、`sk_buff` 这类大结构体)。
2. **同一类型的对象紧凑排布在同一块物理连续页中**,既节省空间（伙伴系统最小粒度是整页，小对象直接占一页是浪费）,又能减少 CPU cache miss。
3. **Slab Coloring(slab 着色)** 给不同 slab 加偏移，使同类对象落到不同的 cache line，降低 L1/L2 冲突。

Linux 内核在此基础上演化出三种实现:

- **SLAB**:Bonwick 思想的原始移植，管理结构复杂、对 NUMA 友好，但元数据开销大。
- **SLUB**:由 Christoph Lameter 于 2007 年重写，2.6.23 起成为默认。元数据直接挂在 `struct page`(新内核里叫 `struct folio`)里，代码更精简、诊断更丰富、扩展性更好，也是目前服务器 Linux 几乎都在用的版本。
- **SLOB**:面向嵌入式的小巧实现，代码极简但缺少调试与防碎片能力，在 **Linux 6.4(2023 年)被移除**,其场景由新增的 `CONFIG_SLUB_TINY`(SLUB tiny)接替。

内核之外，应用层的对象池同样常见：数据库连接池、线程池、glibc `malloc` 里的小块 fastbin、Go runtime 的 `mcache`、Java JVM 的 TLAB(Thread Local Allocation Buffer)等，本质都是同一种思路在不同抽象层上的复现。

## 二、层级内存池：让生命周期与分配边界对齐

如果对象的特性是**层级化生命周期** —— 同一层级的对象几乎同时诞生、也几乎同时销毁 —— 那么最佳策略是:**在生命周期开始时一次性向系统申请一整块内存池，在生命周期结束时一次性整块归还**。中间所有小对象都从这个池里「bump-pointer」分配，不需要维护任何逐对象的空闲链，也没有碎片问题。

典型的层级场景:

- 一次 TCP 连接的所有收发缓冲、上下文结构。
- 一次 HTTP 请求的所有 header、URL、body 解析结果。
- 一次事务或一次 RPC 调用的所有临时对象。

**Nginx** 是这套模式最广为人知的实践者。根据官方《Development Guide》的描述，Nginx 的核心数据结构 `ngx_pool_t` 在 `src/core/ngx_palloc.h` 中定义，内部维护一条连续的内存块链表:

- 小额分配(小于 `pool->max`,即 `min(pool 大小 - sizeof(ngx_pool_t), NGX_MAX_ALLOC_FROM_POOL)`,而 `NGX_MAX_ALLOC_FROM_POOL = ngx_pagesize - 1`,x86 上约为 **4KB**)走 **bump pointer**,即把 `d.last` 指针向前移动,几乎零开销。
- 超过 `max` 的大块走系统 `malloc`,挂在 `pool->large` 链表上，允许单独 `ngx_pfree()`。
- `ngx_pool_cleanup_t` 注册析构回调，用于关闭临时文件、释放外部资源。

每个 `ngx_connection_t` 在 `accept` 时通过 `ngx_create_pool(NGX_DEFAULT_POOL_SIZE, log)` 创建一个独立池;HTTP 请求 `ngx_http_request_t` 则子分配在该连接池内;请求结束时 `ngx_http_free_request()` 触发 cleanup handler，连接关闭时 `ngx_destroy_pool(c->pool)` 把整块内存一次性还给操作系统。Keep-alive 复用连接时则用 `ngx_reset_pool()` 重置 `last` 指针，而不是逐对象释放。

这种「**整进整出**」的好处是:

- 分配是 O(1) 的指针推进;
- 回收是 O(1) 的整块归还;
- 不存在长期堆碎片 —— 池的生命周期短，外部碎片还没来得及累积就被收回;
- 与 Nginx 单线程事件循环模型天然契合，无需复杂的锁。

类似的层级池在很多高性能服务里都能看到:Apache APR pool、Redis 的 SDS 临时区、PostgreSQL 的 memory context、Envoy 的 Arena，乃至 Linux 内核中断上下文的 `__get_free_pages` 临时块，思想都是同源的。

## 三、延迟销毁与动态生成：放弃精确回收换取吞吐

对象池和层级池都隐含一个前提:**回收时机是确定的**。但现实中还有两类对象无法满足这个前提。

### 延迟销毁（Lazy Deletion）

当一个对象被多个 owner 引用、或者释放发生在不可阻塞的上下文（如 RCU 软中断、信号处理、GC 安全点）时，精确同步释放往往代价过大。常见做法是:

- **引用计数（reference counting）** —— Linux VFS 的 `inode`、`dentry`,`struct file` 都靠 `atomic_inc/dec` 维持;计数归零才真正销毁。
- **RCU(Read-Copy-Update)** —— Linux 内核里读侧几乎零开销，写侧延迟到所有读者退出宽限期后再回收，本质是把「销毁」推迟到一个确定的安全点。
- **分代式 GC / Epoch based reclamation** —— 把对象按存活代际分组，新对象死得快、老对象扫得稀，牺牲一点峰值延迟换整体吞吐。
- **代际回收（generational collection）** —— Java HotSpot、V8、.NET 都遵循同一规律:99% 的对象朝生夕死，扫完年轻代就能回收绝大多数垃圾。

### 动态生成（Dynamic Generation）

还有一类对象在编译期连结构都不确定:JIT 编译产出的机器码、动态加载的 `.so`、protobuf 解码出的临时对象、模板渲染出的 HTML 片段。对这类对象，常见做法是把它们放进专门的 **Arena / CodeHeap**,生命周期与某个执行阶段绑定，阶段结束统一清理。JVM 的 CodeCache、V8 的 code space、Linux 的 `module_alloc` 区都是这个套路。

## 四、工程实践要点

把上面三条思路落到自己系统里时，有几点经验值得记下:

1. **先测再优**。`perf`、`valgrind --tool=massif`、`jemalloc` 的 `stats_print`、`/proc/meminfo` 里 `Slab`/`SReclaimable` 都是定位内存热点的入口;不测就盲改内存池，常常是负优化。
2. **池的大小要和负载匹配**。Nginx 连接池默认 16KB，大 body 请求会自动走 `large` 链;自研池若把 `max` 设错，要么频繁走慢路径，要么池膨胀成堆。
3. **生命周期边界要清晰**。池一旦泄漏（忘了 destroy）,就是整块级别的泄漏，比逐对象泄漏更猛;务必让「谁 create、谁 destroy」成对出现在同一个抽象层。
4. **不要把短生命周期对象塞进长生命周期池**。这是最常见的设计错误，会让池无限增长。反过来，也不要为只出现一次的对象建池 —— 直接用通用分配器即可。
5. **诊断能力不可省**。SLUB 的 `red zone`(`0xbb` 填充)、`poison`(`0x6b`/`0xa5`)能在第一时间暴露越界和 use-after-free;自研池最好也带上 canary 字段和泄漏报告。

## 小结

通用内存分配器(glibc `malloc`、`mimalloc`、`jemalloc`)解决的是「**任意大小、任意生命期**」的平均情况，它们做得很好;但在性能关键路径上，凡是能识别出对象特性的地方，几乎都能用「分类管理」再压榨出一两个数量级：固定大小走对象池，层级生命期走整块池，引用复杂走延迟销毁，内容不可预测走 arena。Linux SLAB/SLUB、Nginx `ngx_pool_t`、JVM 分代 GC，都只是这条规律在不同领域的投影。

## 参考

- [The Slab Allocator: An Object-Caching Kernel Memory Allocator (Jeff Bonwick, USENIX 1994)](https://www.usenix.org/legacy/publications/library/proceedings/bos94/full_papers/bonwick.a)
- [Linux 内核文档:Slab 分配器](https://www.kernel.org/doc/html/latest/mm/slab.html)
- [Nginx Development Guide — Memory Management](https://nginx.org/en/docs/dev/development_guide.html)
- [Linux内存之Slab —— 小武](https://fivezh.github.io/2017/06/25/Linux-slab-info/)
- [Linux 内核 | 内存管理——Slab 分配器 —— 钓莫](https://www.dingmos.com/index.php/archives/23/)
- [细节拉满，80 张图带你一步一步推演 slab 内存池的设计与实现 —— bin的技术小屋](https://www.cnblogs.com/binlovetech/p/17288990.html)
- [Linux 内存管理 slub 分配器 —— LoyenWang](https://www.cnblogs.com/LoyenWang/p/11922887.html)
- [高性能内存分配库 Libhaisqlmalloc 的设计思路](https://zhuanlan.zhihu.com/p/352938740)
