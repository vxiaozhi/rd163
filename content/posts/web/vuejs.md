+++
title = "Vue.js 框架入门"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "渐进式 JavaScript 框架的核心概念与开发实践"
description = "Vue.js 是构建用户界面的渐进式框架。本文梳理其声明式渲染、响应式系统、单文件组件与组合式 API 等核心概念。"
author = "小智晖"
authors = ["小智晖"]
categories = ["web"]
tags = ["web", "Vue", "Vue.js", "前端框架", "组合式 API"]
keywords = ["Vue.js", "Vue 3", "组合式 API", "响应式", "单文件组件"]
toc = true
draft = false
+++

Vue(发音 /vjuː/,同 view)是一个用于构建用户界面（user interface）的 JavaScript 框架，基于标准 HTML、CSS 与 JavaScript 构建。它由尤雨溪（Evan You）于 2014 年发布，目前主版本为 Vue 3，截至撰稿时最新稳定版为 3.5 系列。Vue 在官方文档中将自己定位为「渐进式框架」(progressive framework)——可以根据项目复杂度逐步引入，从给静态页面加点交互，到构建复杂的单页应用（Single-Page Application, SPA）、服务端渲染（SSR）、静态站点生成（SSG）,甚至配合 Electron / Capacitor 打包为桌面端或移动端应用。

本文梳理 Vue 的核心概念与上手要点，便于快速建立整体认知。

## 核心特性

Vue 的设计围绕两个核心能力展开:

- **声明式渲染（Declarative Rendering）**:通过扩展的模板语法，声明式地描述 DOM 与 JavaScript 状态之间的绑定关系，而不是手动操作 DOM。
- **响应性（Reactivity）**:Vue 会自动追踪 JavaScript 状态的变化，并在状态改变时高效地更新 DOM。

这两点是 Vue 区别于原生 DOM 操作、同时也区别于 jQuery 命令式范式的关键。

### 渐进式框架

「渐进式」意味着 Vue 不会强制你一次性接受整套方案:

- 仅引入 `vue.js` 一份脚本，就能在静态 HTML 上增强交互（类似 jQuery 的使用方式）;
- 引入 Vite 等构建工具与单文件组件后，可组织中型应用;
- 配合 Vue Router、Pinia 等官方生态，可构建完整 SPA;
- 配合 Nuxt 等元框架（meta-framework）,可做 SSR/SSG 与全栈开发。

### 单文件组件（SFC）

单文件组件（Single-File Component, SFC）是 `.vue` 后缀的文件，把组件的模板（HTML）、逻辑（JavaScript/TypeScript）、样式（CSS）封装在同一个文件中，是 Vue 最具标志性的组织方式。一个典型 SFC 如下:

```vue
<script setup>
import { ref } from 'vue'

const count = ref(0)
function increment() {
  count.value++
}
</script>

<template>
  <button @click="increment">Count is {{ count }}</button>
</template>

<style scoped>
button {
  font-weight: bold;
}
</style>
```

`<style scoped>` 让样式仅作用于当前组件，避免全局污染。

## 两种 API 风格

Vue 3 提供两种书写组件逻辑的 API:

| 风格 | 特点 | 适用场景 |
| --- | --- | --- |
| 选项式 API(Options API) | 以 `data`、`methods`、`mounted` 等选项对象组织逻辑，基于 `this` 组件实例 | 初学者、低复杂度或无构建工具场景 |
| 组合式 API(Composition API) | 通过 `ref`、`onMounted` 等导入的函数组织逻辑，常搭配 `<script setup>` | 完整 SPA、需要逻辑复用与类型推导 |

官方明确说明：选项式 API 是在组合式 API 的基础上实现的，两者共享同一套底层响应式系统，核心概念互通，可以根据团队与项目自由选择。生产项目中，构建完整 SPA 时更推荐组合式 API + 单文件组件。

## 模板语法要点

Vue 模板基于标准 HTML，通过指令（directive）与插值实现绑定。指令是以 `v-` 为前缀的特殊 attribute。

- **文本插值**:`{{ msg }}`,双大括号（Mustache 语法）,值会被作为纯文本渲染。
- **原始 HTML**:`v-html="rawHtml"`,注意官方警告：在网站上动态渲染任意 HTML 非常危险，切勿用于用户输入，以防 XSS 攻击。
- **属性绑定**:`v-bind:id="dynamicId"` 或缩写 `:id="dynamicId"`。Vue 3.4+ 支持同名简写，当属性名与变量名一致时可直接写 `:id`。
- **事件绑定**:`v-on:click="handler"` 或缩写 `@click="handler"`;修饰符如 `@click.prevent` 等价于调用 `event.preventDefault()`。
- **双向绑定**:`v-model`,常用于表单控件。
- **条件与列表**:`v-if` / `v-else` 控制渲染,`v-for` 遍历数组或对象渲染列表。
- **动态参数**:`:[attributeName]="..."` 或 `@[eventName]="..."`,用方括号包裹表达式作为参数名;在 DOM 内嵌模板时需避免名称中包含大写字母。

模板中的表达式会被沙盒化，只能访问白名单全局对象(如 `Math`、`Date`),且每个绑定仅支持单一表达式，不能写 `var a = 1` 这类语句。

## 响应式 API

组合式 API 的响应式系统基于以下几个核心 API:

### `ref()` —— 推荐的主声明方式

`ref()` 接收任意值并返回一个带 `.value` 属性的 ref 对象。在 JavaScript 中读写需要通过 `.value`,在模板中则自动解包（unwrap）:

```js
import { ref } from 'vue'

const count = ref(0)
console.log(count.value) // 0
count.value++
```

`ref` 对非原始值也会做深层响应式处理。官方推荐使用 `ref()` 作为主要的状态声明方式。

### `reactive()` —— 仅用于对象/数组

`reactive()` 让对象本身具有响应性，返回原始对象的 Proxy。它有几个局限：只能用于对象类型（不能用于 string/number/boolean）;不能整体替换对象，否则会丢失响应式连接;对解构不友好，解构出的原始类型属性会断开响应性。

```js
import { reactive } from 'vue'

const state = reactive({ count: 0 })
state.count++
```

### `computed()` —— 计算属性

用于派生状态，会自动追踪依赖并缓存结果，只有依赖变化时才会重新计算:

```js
import { ref, computed } from 'vue'

const count = ref(0)
const double = computed(() => count.value * 2)
```

### `watch()` / `watchEffect()` —— 侦听器

`watch` 显式侦听一个或多个响应式数据源，允许访问新值与旧值;`watchEffect` 则自动收集回调中用到的响应式依赖，适合触发副作用（如发起网络请求、操作 DOM）。

### 生命周期钩子

组合式 API 中以 `on` 前缀的函数形式提供，如 `onMounted`、`onUpdated`、`onUnmounted`,需要在 `setup` 同步注册:

```js
import { onMounted } from 'vue'

onMounted(() => {
  console.log('组件已挂载')
})
```

### `nextTick()`

Vue 对状态变更引起的 DOM 更新是异步缓冲的。若需要在状态更新后立即操作更新后的 DOM，可 `await nextTick()`。

## `<script setup>` 语法糖

`<script setup>` 是组合式 API 在单文件组件中的编译时语法糖（compile-time syntactic sugar）,也是 Vue 3 推荐的写法。它的优势:

- 顶层声明的变量、函数、`import` 自动暴露给模板，无需写 `return`;
- 导入的组件可直接使用，无需注册;
- 更好的运行时性能与 TypeScript 类型推导;

它还提供一组编译时宏（macros）,无需 import，编译时会被移除:

- `defineProps()` —— 声明 props;
- `defineEmits()` —— 声明 emits;
- `defineExpose()` —— 显式暴露属性供父组件通过 `ref` 访问;
- `defineModel()` —— 简化父子组件双向绑定（Vue 3.4 起稳定）;
- `defineOptions()` / `defineSlots()` —— 设置组件选项与类型化插槽。

简单带类型的示例:

```vue
<script setup lang="ts">
interface Props {
  msg?: string
}
const props = withDefaults(defineProps<Props>(), { msg: 'hello' })
const emit = defineEmits<{ (e: 'change', id: number): void }>()
</script>
```

## 上手建议

官方推荐三种学习路径：互动教程、阅读指南、查看示例。最快的实践方式是打开 [Vue Playground](https://play.vuejs.org/) 直接在浏览器里写 SFC，无需安装任何环境;本地新建项目则推荐使用 Vite:

```bash
npm create vue@latest
```

该脚手架由官方维护，可交互式选择是否引入 TypeScript、Router、Pinia、Vitest、ESLint 等。

## 参考链接

- [Vue.js 官方中文文档](https://cn.vuejs.org/)
- [Vue 简介](https://cn.vuejs.org/guide/introduction.html)
- [模板语法](https://cn.vuejs.org/guide/essentials/template-syntax.html)
- [响应式基础](https://cn.vuejs.org/guide/essentials/reactivity-fundamentals.html)
- [`<script setup>` 语法糖](https://cn.vuejs.org/api/sfc-script-setup.html)
- [Vue Playground 在线演练场](https://play.vuejs.org/)
- [Vue.js GitHub 仓库（core）](https://github.com/vuejs/core)
