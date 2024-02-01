---
layout:     post
title:      "GCC -O2 踩坑指南：严格别名（Strict Aliasing）与整数环绕（Integer Wrap-around）"
subtitle:   "严格别名（Strict Aliasing）与整数环绕（Integer Wrap-around）"
description: "GCC -O2 Compiler optimization: Strict Aliasing and Integer Wrap-around"
excerpt: ""
date:       2024-02-07 01:01:01
author:     "张帅"
image: "/img/2024-02-07-gcc-strict-aliasing/background.jpg"
showtoc: true
draft: true
tags:
    - GCC -O2
    - Strict Aliasing
    - Integer Wrap-around
categories: [ Tech ]
URL: "/2024/02/07/gcc-strict-aliasing/"
---

- - -
###### 关于作者
> 
> **`张帅，网络从业人员，公众号：Flowlet`**
> 
> **`个人博客：https://flowlet.net/`**
- - -

## 序言
- - -

GCC 在开启 -O2 编译优化后，会遇到编译器领域的两个著名问题：**严格别名（Strict Aliasing）**与**整数环绕（Integer Wrap-around）**。

本次笔者就为大家详细讲解下这两个经典的编译优化问题。

## 前言
- - -

由于作者水平有限，本文不免存在遗漏或错误之处，欢迎指正交流。

## 1. 什么是别名（alias）
- - -

在 C 和 C++ 中，当多个左值 lvalue 指向同一个内存区域时，就会出现别名（alias）。

例 1：
```c {linenos=table, linenostart=1, hl_lines=[2 "2-2"]}
int a = 42;
int *ptr = &a;
```

*ptr 改变 a 的值也会改变。这里 *ptr 就被称为 a 的别名。

### 1.1 类型双关（type punning）
- - -

别名（alias）最常见的用途就是类型双关（type punning）。有时我们想绕过类型系统，将一个对象解释为不同的类型，这就是所谓的类型双关。类型双关经常应用在编译器、序列化、网络传输等领域。

类型双关一般做法是通过别名（alias）来实现，通过获取对象的地址，将其转换为我们想要重新解释的类型的指针，然后访问该值。

以下就是类型双关的例子，在标准定义中，这种类型双关属于未定义的行为。
```c {linenos=table, linenostart=1}
int a;
float *ptr = (float *)&a;

printf("%f\n", *ptr);
```

## 2. 什么是严格别名
- - -

严格别名就是编译器当看到多个别名（alias）时，会在一定规则下默认它们指向不同的内存区域（即使它们实际上指向相同的内存区域），并以此进行优化，这可能会生成与我们期望不同的代码。

符合 strict aliasing，编译器认为 argv1，argv2 指向同一内存区域：
```c {linenos=table, linenostart=1}
int a;
void foo(char *argv1, int *argv2)

foo((char *)(&a), &a);
```

违背 strict aliasing，编译器认为 argv1，argv2 指向不同的内存区域 ，为未定义的行为（UB，Undefined Behavior）。
```c {linenos=table, linenostart=1}
int a;
void foo(float *argv1, int *argv2)

foo((float *)(&a), &a);
```

### 2.1 C11 （N1570）标准严格别名下规则
- - -

由于笔者主要从事网络领域编程，DPDK 采用 C11 标准的内存模型，因此这里只介绍 C11 标准。
在 N1570 第 6.5 节的第 7 段：

对象的存储值只能由具有以下类型之一的左值表达式访问：
#### 2.1.1 与对象的有效类型兼容的类型
- - -
```c {linenos=table, linenostart=1}
int x = 1;
int *ptr = &x;
printf("%d\n", *ptr); // *ptr 是 int 类型的左值表达式，与 int 类型兼容（相同）
```

#### 2.1.2 与对象的有效类型兼容类型的限定版本
- - -
```c {linenos=table, linenostart=1}
int x = 1;
const int *ptr = &x;
printf("%d\n", *ptr); // *ptr 是 const int 类型的左值表达式，与 int 类型兼容
```

#### 2.1.2 与对象的有效类型相对应的有符号或无符号类型的类型
- - -
例如，使用 signed int * ，或者 unsigned int * 作为 int 类型的别名。

```c {linenos=table, linenostart=1}
int x = 1;
unsigned int *ptr = (unsigned int*)&x;
printf("%u\n", *ptr); // *ptr 是 unsigned int 类型的左值表达式，是 int 类型对应的无符号类型
```

注意, 使用 int * 作为 unsigned int 的别名，不符合标准，但 gcc 和 clang 都做了拓展，因此没有问题。
参见：[Why does gcc and clang allow assigning an unsigned int * to int * since they are not compatible types, although they may alias.](https://twitter.com/shafikyaghmour/status/957702383810658304)

```c {linenos=table, linenostart=1}
unsigned int x = 1;
int *ptr = (int *)&x;
printf("%d\n", *ptr); // No Warnning, No Error
```

#### 2.1.3 类型是与对象的有效类型相对应的限定版本有符号或无符号类型
- - -
```c {linenos=table, linenostart=1}
int x = 1;
const unsigned int *ptr = (const unsigned int*)&x;
printf("%u\n", *ptr );
```
#### 2.1.4 struct 或 union 类型，其成员中包括上述类型之一（递归地包含 struct 或包含 union 的成员）
- - -

```c {linenos=table, linenostart=1}
struct foo {
    int x;
};

void foobar(struct foo *foo_ptr, int *int_ptr);  // f 是一个 struct 类型，并包含 int 类型，因此 *int_ptr 可以是 f.x 的别名。

struct foo f;
foobar(&f, &f.x);

```

#### 2.1.5 字符类型
- - -
```c {linenos=table, linenostart=1}
int x = 65; // ASCII 值 65 对应的字符为 A
char *ptr = (char *)&x;
printf("%c\n", *ptr);  // *ptr 是 char 类型的左值表达式， char 类型可以作为任何类型的别名。

```

char 类型是严格别名规则下的**银弹**，可以作为任何类型的别名。不只是 char 类型，unsigned char，uint8_t, int8_t 也满足这条规则。

## 3. GCC 编译优化选项
- - -

GCC -O0, -O1 编译优化选项下开启严格别名（strict aliasing）规则的编译选项为：-fstrict-aliasing。

GCC -O2, -O3, -Os 编译优化选项下，严格别名（strict aliasing）规则默认开启。

具体的各个编译优化等级的优化参数，参考如下 GCC 手册：[Options That Control Optimization](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html)

默认情况下无论是在 GCC -O0, -O1 优化下开启 -fstrict-aliasing，还是开启 GCC -O2, -O3, -Os 优化，如果想让违反严格别名规则代码在编译的时候产生告警需要增加 -Wstrict-aliasing 编译选项。

## 4. 违反严格别名规则
- - -

下面我们举几个例子，在 GCC 开启 -O2 优化时，违反严格别名规则导致的未定义行为。

### 4.1 违反严格别名规则示例 1
- - -

#### 4.1.1 开启 GCC -O2 导致示例 1 未定义的行为
- - -

```c
#include "stdio.h"

int foo( float *f, int *i ) {
    *i = 1;               
    *f = 0.0f;            
   
   return *i;
}

int main() {

    int x = 0;
    
    printf("%d\n", x);

    x = foo((float*)(&x), &x);

    printf("%d\n", x);
}
```

在 GCC 开启 -O1编译优化时，输出结果为：
```bash
0
0
```

我们可以通过 [godbolt](https://godbolt.org/) 这个网站实时查看 C/C++ 代码的汇编代码:

![](/img/2024-02-07-gcc-strict-aliasing/figure1.jpg)


在 GCC 开启 -O2编译优化时，输出结果为：
```bash
0
1
```

![](/img/2024-02-07-gcc-strict-aliasing/figure2.jpg)

#### 4.1.2 开启 -Wstrict-aliasing 编译参数
- - -

![](/img/2024-02-07-gcc-strict-aliasing/figure3.jpg)

在本例中即使开启 `-Wstrict-aliasing` 严格别名告警编译参数，本例虽然违反了严格别名规则，在 x86-64 gcc 13.2 下也未收到任何编译告警提示。

#### 4.1.3 开启 -fno-strict-aliasing 编译参数
- - -

![](/img/2024-02-07-gcc-strict-aliasing/figure4.jpg)

开启 `-fno-strict-aliasing` 取消严格别名优化，修改 GCC -O2 导致的严格别名 Bug。

#### 4.1.4 GCC 开启 -O2编译优化，避免严格别名 Bug 的方法
- - -

推荐处理顺序为从左到右：
    改代码 > -fno-strict-aliasing > 不开 GCC -O2 优化 > -Wno-strict-aliasing （掩耳盗铃，强烈不建议）

Linux 内核的做法是：
    在开启 GCC -O2 编译优化的同时开启 `-fno-strict-aliasing` 编译参数。

其实如果按照 GCC 那帮人的严格别名（Strict Aliasing）标准，Linux 代码有一半都跑不起来。2018 年 Linus Torvalds 就针对 Strict Aliasing 对 GCC 进行了开喷：[device property: Get rid of union aliasing](https://lkml.org/lkml/2018/6/5/769)

## 5. 整数环绕
- - -




## 参考
- - -
* [What is the Strict Aliasing Rule and Why do we care?](https://gist.github.com/shafik/848ae25ee209f698763cffee272a58f8)
* [Understanding Strict Aliasing](https://cellperformance.beyond3d.com/articles/2006/06/understanding-strict-aliasing.html)
* [（翻訳）C/C++のStrict Aliasingを理解する または - どうして#$@##@^%コンパイラは僕がしたい事をさせてくれないの！](https://yohhoy.hatenadiary.jp/entry/20120220/p1)
* [Options That Control Optimization](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html)
* [严格别名（Strict Aliasing）规则是什么，编译器为什么不做我想做的事？](https://zhuanlan.zhihu.com/p/595286568)
* [Programming languages — C](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf)
* [DPDK adopts the C11 memory model](https://www.dpdk.org/blog/2021/03/26/dpdk-adopts-the-c11-memory-model/)


## 公众号：Flowlet
- - -

<img src="/img/qrcode_flowlet.jpg" width = 30% height = 30% alt="Flowlet" align=center/>

- - -