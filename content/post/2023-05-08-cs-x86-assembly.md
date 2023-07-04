---
layout:     post
title:      "计算机系统 Lecture 2：x86-64 汇编"
subtitle:   "x86-64 汇编"
description: "Computation System Lecture 2: x86-64 Assembly"
excerpt: ""
date:       2023-05-08 01:01:01
author:     "张帅"
image: "/img/2023-07-01-cs-x86-assembly/background.jpg"
showtoc: true
draft: true
tags:
    - x86-64 assembly
categories: [ Tech ]
URL: "/2023/07/01/cs-x86-assembly/"
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

本文主要讲解计算机系统：x86-64 汇编。

## 前言
- - -

由于作者水平有限，本文不免存在遗漏或错误之处，欢迎指正交流。

## 1. 基本概念
- - -

对于机器级编程来说，有几个十分重要的抽象概念：

### 1.1 指令集架构（ISA）
- - -
**计算机指令（Instruction）**是计算机硬件直接能识别的命令。指令是由一串二进制数码组成。一条指令通常由两个部分组成：操作码和地址码。操作码指明该指令要完成的操作的类型或性质，如取数、做加法或输出数据等；地址码指明操作对象的内容或所在的存储单元地址。


**指令集架构 (Instructure Set Architecture，ISA)**是指一种类型 CPU （x86/arm/risc-v）中用来计算和控制计算机系统的一套指令的集合。它定义了处理器的状态、指令格式以及每条指令对状态的影响，是软硬件之间的“合同”，就是在那里，软件遇见了硬件。指令集作为一种标准规范，用于规范芯片设计工程师及编译器开发工程师。

![](/img/2023-07-01-cs-x86-assembly/2023-07-01-pic1.png)


### 1.2 指令集架构（ISA）
- - -


**微架构（Mircoarchitecture）**：指令集架构的具体实现方式 (比如流水线级数，缓存大小等)，它是可变的


**虚拟内存**：机器级程序使用的内存地址是虚拟内存地址，使得内存模型看上去是一个很大的连续字节数组。然后由操作系统将其转换为真实的物理内存地址。


## 参考
- - -
* [15-213: Intro to Computer Systems: Schedule for Fall 2015](http://www.cs.cmu.edu/afs/cs/academic/class/15213-f15/www/schedule.html)
* [CS 61C：Great Ideas in Computer Architecture (Machine Structures)](https://cs61c.org/su23/)

## 公众号：Flowlet
- - -

<img src="/img/qrcode_flowlet.jpg" width = 30% height = 30% alt="Flowlet" align=center/>

- - -