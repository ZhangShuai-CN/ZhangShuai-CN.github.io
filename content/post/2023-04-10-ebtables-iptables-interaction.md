---
layout:     post
title:      "[译] 在 Linux bridge 上 ebtables 与 iptables 如何进行交互"
subtitle:   "在 Linux bridge 上 ebtables 与 iptables 如何进行交互"
description: "ebtables/iptables interaction on a Linux-based bridge"
excerpt: ""
date:       2023-04-10 11:23:01
author:     "张帅"
image: "/img/2023-04-10-ebtables-iptables-interaction/backgroud.jpg"
showtoc: true
draft: true
tags:
    - Ebtables
categories: [ Tech ]
URL: "/2023/04/10/ebtables-iptables-interaction/"
---

本文翻译自[ebtables/iptables interaction on a Linux-based bridge](https://ebtables.netfilter.org/br_fw_ia/br_fw_ia.html)。由于译者水平有限，本文不免存在遗漏或错误之处。如有疑问，请查阅原文。

## 前言
- - -

## 1. Virtio 与 Vhost 协议介绍
- - -

### 1.1 Virtio 是如何被构建出来的？
- - -

#### 2.4.2 Vhost-net
- - -

[markdown](https://www.1nth.com/post/markdown_hugo_commond/)

`ctrl + a`
> 
>>

```xml {linenos=table, linenostart=1, hl_lines=[8 "9-10"]}


```


[comment]: # (Comment this out)
<!--more-->

<center>采用Token进行用户认证的流程图</center>

| Outbound特性 | Inbound特性 |
|--------|--------|
| Service authentication（服务认证）|Service authentication（服务认证）|
|Load Balancing（负载均衡）        |Authorization（鉴权）|

## 参考
- - -
* [Learn about virtio-networking](https://www.redhat.com/en/blog/learn-about-virtio-networking) 系列文章。如需了解更多，推荐阅读[原文](https://www.redhat.com/en/blog/learn-about-virtio-networking)。
* [Learn about virtio-networking](https://www.redhat.com/en/blog/learn-about-virtio-networking) 系列文章。如需了解更多，推荐阅读[原文](https://www.redhat.com/en/blog/learn-about-virtio-networking)。