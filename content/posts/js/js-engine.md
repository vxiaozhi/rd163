+++
title = "JS引擎"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "JavaScriptCore、V8、Hermes、QuickJS 横向对比与选型"
description = "横向对比 JavaScriptCore、V8、Hermes、QuickJS 四款主流 JS 引擎的历史渊源、性能特点与适用场景，并讨论 Hybrid 跨端开发中的引擎选型思路。"
author = "小智晖"
authors = ["小智晖"]
categories = ["JavaScript"]
tags = ["JavaScript", "JS 引擎", "Hybrid", "React Native", "跨端开发"]
keywords = ["JS引擎", "JavaScriptCore", "V8", "Hermes", "QuickJS", "Hybrid"]
toc = true
draft = false
+++

## 1. JavaScriptCore

JavaScriptCore（简称 JSC）是 WebKit 默认的内嵌 JS 引擎。在维基百科上它都没有独立词条，只在 WebKit 词条的三级目录里被介绍了一下。个人感觉这多少有些不像话，毕竟它也是老牌 JS 引擎了。

由于 WebKit 最早由 Apple 主导开源，所以它被广泛用在 Apple 自家的 Safari 浏览器和 WebView 上。尤其在 iOS 系统上，由于 Apple 的限制，所有第三方浏览器和网页加载都必须使用 WebKit 内核，WebKit 在 iOS 上因此形成了事实垄断。作为 WebKit 核心模块之一的 JSC，借着这股政策春风，也「基本」垄断了 iOS 平台的 JS 引擎份额。

垄断归垄断，JSC 的性能其实还是可以的。

很多人可能不清楚，JSC 的「高性能化」比 V8 还要早一些。2008 年 6 月，WebKit 团队发布了基于字节码解释器的 SquirrelFish；随后在同年 9 月推出了带 JIT 的 SquirrelFish Extreme（SFX），而 Google 的 V8 是 2008 年 9 月 2 日才随 Chrome 发布的。两者几乎前后脚进入 JIT 时代，JSC 在当时算得上是最快的 JS 引擎之一，只是后来逐渐被 V8 追上并反超。此外 JSC 还有一个重大利好：自 iOS 7（2013 年）起，JSC 作为系统级 Framework（`JavaScriptCore.framework`）开放给第三方开发者使用。也就是说，如果你的 App 用 JSC，只需在项目里 `import` 一下即可，包体积是零开销的。在今天讨论的几款 JS 引擎里，JSC 在这一点上最能打。

需要补充一句的是：虽然 Safari 和 WKWebView 内部运行的 JSC 可以启用 JIT，但第三方 App 直接调用 `JavaScriptCore.framework` 时，由于受 iOS 进程沙盒限制，并不会启用 JIT——这也是后续 Hermes 选择「不依赖 JIT」这条路线在 iOS 上并非完全劣势的原因之一。

## 2. V8

V8 我想不用过多解释了。JavaScript 能有如今的地位，V8 功不可没。它的性能没得说，开启 JIT 后就是业内最强（不只是 JS 领域）。介绍 V8 的文章已经很多，这里不再赘述，下面重点说说 V8 在移动端的表现。

V8 同样是 Google 家的产品，每一台 Android 手机出厂都自带基于 Chromium 的 WebView，V8 也一并被捆绑进去。但 V8 与 Chromium 绑定得太紧，不像 iOS 上的 JavaScriptCore 那样被封装为系统库供所有 App 调用。这导致想在 Android 上用 V8，还得自己封装一层。社区里比较出名的项目是 J2V8，它提供了 V8 的 Java bindings。

V8 的性能没得说，Android 上也能开启 JIT，但这些优势是有代价的：开启 JIT 后内存占用偏高，V8 自身的包体积也不小（大约 7 MB 左右）。对一个只是用来画 UI 的 Hybrid 系统来说，这就有些奢侈了。

## 3. Hermes

Hermes 是 Facebook 在 2019 年年中开源的一款 JS 引擎。从它的 release 记录可以看出，这是一款专为 React Native 打造的引擎，可以说从设计之初就是冲着 Hybrid UI 系统去的。

Hermes 一开始的目标就是要替代 RN Android 端原先使用的 JavaScriptCore（因为 JSC 在 Android 端表现比较拉胯）。我们可以理一下时间线：Facebook 自 2019 年 7 月 12 日宣布 Hermes 开源之后，jsc-android 的维护信息就永远停在了 2019 年 6 月 25 日。这个信号暗示得非常明显——JavaScriptCore 的 Android 版本不再维护，大家都去用我们做的 Hermes 吧。

此后 Hermes 也登上了 iOS 平台：React Native 0.64（2021 年 3 月发布）正式支持在 iOS 上开启 Hermes（需手动 opt-in），到 React Native 0.70（2022 年 9 月发布）时，Hermes 已经成为 Android 和 iOS 双端的默认引擎。至于它与 Apple 开发者协议（Apple Agreement 3.3.2）相关的合规讨论，大家可以参考我之前的解读文章，这里就不展开了。

Hermes 的特点主要有两个：一是不支持 JIT，二是支持直接生成/加载字节码。下面分开讲。

Hermes 不支持 JIT 的主要原因有两个。其一是加入 JIT 后，JS 引擎启动时的预热时间会变长，一定程度上会拉长首屏 TTI（Time To Interactive，页面首次可交互时间）。现在的移动页面都讲究一个「秒开」，TTI 是个相当重要的测量指标。其二是 JIT 会增加包体积和内存占用——Chrome 内存占用高，V8 要承担相当一部分责任。

也正因为不支持 JIT，Hermes 在 CPU 密集计算的场景下并不占优势。所以在 Hybrid 系统里，比较合理的做法是充分发挥 JavaScript「胶水语言」的作用：把 CPU 密集的计算（如矩阵变换、参数加密等）放到 Native 层去做，算好后再回传给 JS 表现到 UI 上，这样可以兼顾性能与开发效率。

Hermes 最引人瞩目的特性就是支持生成字节码。我在之前的博文《跨端框架的核心技术到底是什么？》里也提到过：Hermes 引入 AOT 后，Babel、Minify、Parse、Compile 这些流程全部都在开发者电脑上完成，运行时直接下发字节码让 Hermes 执行即可。

## 4. QuickJS

- [QuickJS：一个小巧且可嵌入的 JavaScript 引擎](https://github.com/quickjs-zh/QuickJS)

正式介绍 QuickJS 之前，我们先说说它的作者：Fabrice Bellard。

软件业界一直有个说法——一个高级程序员创造的价值可以超过 20 个平庸的程序员。但 Fabrice Bellard 不是高级程序员，他是天才。在我看来，他的创造力可以超过 20 个高级程序员。我们可以顺着时间轴理一下他创造过些什么：

- 1997 年，他提出了计算圆周率的 Bellard 公式（Bailey–Borwein–Plouffe 公式的变体），将计算效率提升了约 43%，这是他在数学领域的成就。
- 2000 年，发布了 FFmpeg，这是他在音视频领域的成就。
- 2000、2001 年，两度获得国际混淆 C 代码大赛（IOCCC）。
- 2002 年，发布了 TinyGL，这是他在图形学领域的成就。
- 2005 年，发布了 QEMU，这是他在虚拟化领域的成就。
- 2011 年，他用 JavaScript 写了一个 PC 虚拟机 Jslinux，一个跑在浏览器里的 Linux 操作系统。
- 2019 年，发布了 QuickJS，一个支持 ES2020 规范的 JS 虚拟机。

当人与人之间的差距拉大到几个数量级后，羡慕嫉妒之类的情绪就会转变为崇拜，Bellard 就是这样一个人。

收一收心情，我们来看看 QuickJS 这个项目。QuickJS 继承了 Fabrice Bellard 作品的一贯特色——小巧而强大。

QuickJS 体积非常小，只有几个 C 文件，没有乱七八糟的第三方依赖。但它的功能又相当完善，JS 语法支持到 ES2020；在 Test262（ECMAScript 官方一致性测试套件）上的测试结果显示，QuickJS 的语法支持度甚至比 V8 还要高。

## 参考

- [V8、JSCore、Hermes、QuickJS，hybrid 开发 JS 引擎怎么选](https://cloud.tencent.com/developer/article/1801742)
- [Hermes Engine 官方网站](https://hermesengine.dev/)
- [React Native 0.70 发布说明（Hermes 成为默认引擎）](https://reactnative.dev/blog/2022/09/05/version-070)
- [React Native 0.64 发布说明（Hermes 登陆 iOS）](https://reactnative.dev/blog/2021/03/12/version-0.64)
- [QuickJS 官方网站](https://bellard.org/quickjs/)
