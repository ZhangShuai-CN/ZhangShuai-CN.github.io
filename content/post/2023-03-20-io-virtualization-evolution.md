---
layout:     post
title:      "I/O虚拟化 104：I/O 虚拟化技术演进之路"
subtitle:   "Emulate、virtio、vhost-net、VFIO、vhost-user、SR-IOV、VFIO-mdev、virtio-user、vDPA 与 VDUSE 技术概述"
description: "The Evolution of I/O Virtualization: Emulate, virtio, vhost-net, VFIO, vhost-user, SR-IOV, VFIO-mdev, virtio-user, vDPA and VDUSE."
excerpt: ""
date:       2023-03-20 01:01:01
author:     "张帅"
image: "/img/2023-03-20-io-virtualization-evolution/background.jpg"
showtoc: true
draft: true
tags:
    - virtio
categories: [ Tech ]
URL: "/2023/03/20/io-virtualization-evolution/"
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
虚拟化技术是实现云计算的基石，虚拟化技术主要由三项关键技术构成：CPU虚拟化、内存虚拟化和 I/O 虚拟化。I/O 虚拟化作为计算、网络与存储的技术交织点，其重要性与复杂性不言而喻。

I/O 虚拟化技术的变革必将带来网络架构与存储架构的变革，为了满足更高性能、更少线缆、更低成本的要求，I/O 虚拟化技术从诞生至今一直都在不断演进。

本文将从 I/O 虚拟化技术演进的角度来谈一谈，Linux 从过去发展到现在的主流 I/O 虚拟化技术。

## 前言
- - -

由于作者水平有限，本文不免存在遗漏或错误之处，欢迎指正交流。

## 1. Trap-and-emulate
- - -


### 1.1 二号标题
- - -


#### 1.1.1 三号标题
- - -

## 2. Trap-and-emulate
- - -


## 参考
- - -
* [浅谈Linux设备虚拟化技术的演进之路](https://www.modb.pro/db/110904)
* [Virtio_user for Container Networking](https://doc.dpdk.org/guides/howto/virtio_user_for_container_networking.html)