---
layout:     post
title:      "Linux 连接跟踪（conntrack）- Part 3：CT 系统底层实现 [译]"
subtitle:   "Linux Connection tracking - Part 3: CT System's Overview"
description: "Linux Connection tracking (conntrack)"
excerpt: ""
date:       2024-01-27 01:01:01
author:     "张帅"
image: "/img/2024-01-27-linux-conntrack-part1/background.jpg"
showtoc: true
draft: true
tags:
    - Conntrack
categories: [ Tech ]
URL: "/2024/01/27/linux-conntrack-part1/"
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

Linux 连接跟踪子系统（Linux Conntrack）是实现有状态包过滤与 NAT 功能的基础，一般工作中我们都将 Linux Conntrack 称之为 “CT”。此前也有很多关于 Linux Conntrack 内容的文章介绍，但这些文章都是基于较老的 kernel 版本，内容有点过时。本文基于 Linux kernel 5.10 LTS 版本对 Conntrack 的底层运作方式进行一个系统的介绍。

本文翻译自文章 [Connection tracking (conntrack)](https://thermalcircle.de/doku.php?id=blog:linux:connection_tracking_1_modules_and_hooks)，该文章主要分为三部分：
* 第一部分：CT 系统概述，并详细说明了 CT 与 Netfilter 和 Nftables 等其他内核组件的关系。
* 第二部分：源码级别介绍 CT 系统底层实现，并解释了连接跟踪表、连接查找和连接生命周期管理是如何工作的。
* 第三部分：如何通过 IPtables/Nftables 分析和跟踪连接状态，并展示了 ICMP、UDP 和 TCP 等一些常见协议的 CT 示例。

## 前言
- - -

由于译者水平有限，本文不免存在遗漏或错误之处。如有疑问，请查阅原文。

## 1. 概述
- - -




## 参考
- - -
* [Connection tracking (conntrack) - Part 1: Modules and Hooks](https://thermalcircle.de/doku.php?id=blog:linux:connection_tracking_1_modules_and_hooks)
* [Connection tracking (conntrack) - Part 2: Core Implementation](https://thermalcircle.de/doku.php?id=blog:linux:connection_tracking_2_core_implementation)
* [Connection tracking (conntrack) - Part 3: State and Examples](https://thermalcircle.de/doku.php?id=blog:linux:connection_tracking_3_state_and_examples)

## 公众号：Flowlet
- - -

<img src="/img/qrcode_flowlet.jpg" width = 30% height = 30% alt="Flowlet" align=center/>

- - -