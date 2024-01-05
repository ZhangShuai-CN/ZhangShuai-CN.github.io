---
layout:     post
title:      "使用 RDMA 提升微软 Azure 云的存储性能 [NSDI'23]"
subtitle:   "使用 RDMA 提升微软 Azure 云的存储性能"
description: "Empowering Azure Storage with RDMA"
excerpt: ""
date:       2024-01-03 01:01:01
author:     "张帅"
image: "/img/2024-01-03-empowering-azure-storage-with-rdma/background.jpg"
showtoc: true
draft: true
tags:
    - RDMA
    - Storage
categories: [ Tech ]
URL: "/2024/01/03/empowering-azure-storage-with-rdma/"
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

NSDI 的全称是 Networked Systems Design and Implementation，是 USENIX 旗下的旗舰会议之一，也是计算机网络系统领域久负盛名的顶级会议。与网络领域的另一顶会 SIGCOMM 相比，NSDI 更加侧重于网络系统的设计与实现。

RDMA 在数据中心的主要应用场景是存储与 HPC/AI，微软目前在所有服务器上都部署了 RDMA 网卡，在微软 Azure 云中 RDMA 流量已经占到了数据中心总流量的 70%，超过了传统的以太网流量。

本文翻译自 NSDI'23 论文《[Empowering Azure Storage with RDMA](https://www.usenix.org/conference/nsdi23/presentation/bai)》，该文章阐述了微软在 Azure 云中通过部署 RDMA 来提升存储性能。

## 前言
- - -

由于译者水平有限，本文不免存在遗漏或错误之处。如有疑问，请查阅[原文](https://www.usenix.org/conference/nsdi23/presentation/bai)。

## 摘要
- - -

鉴于公共云中广泛采用存算分离架构（Disaggregated Storage），网络是云存储服务实现高性能和高可靠性的关键。在 Azure 云中，我们在存储前端流量（计算 VM 和存储集群之间）和后端流量（存储集群内）之间启用 RDMA（Remote Direct Memory Access）作为我们的传输层。由于计算集群和存储集群可能位于 Azure 云 region 内的不同 dc 中，因此我们需要在 region 范围内支持 RDMA。

这项工作展示了我们通过在 region 内部署 RDMA 以承载 Azure 中的存储工作负载方面的经验。Azure 中的基础设施的高度复杂性和异构性同时带来了一系列新的挑战，例如不同类型的 RDMA 网卡之间的互操作性问题。我们对网络基础设施进行了多项更改以应对这些挑战。如今，在 Azure 中大约 70% 的流量是 RDMA 流量，并且在 Azure 的所有公有云 region 都支持 region 内 RDMA。RDMA 帮助我们显着的提升磁盘 I/O 性能并节​​省 CPU 资源。

## 1. 介绍
- - -

高性能、高可靠的存储服务是公有云最基础的服务之一。近年来，我们见证了存储介质和技术的显着改进，客户也希望能在云中能获得类似的性能提升。鉴于云中广泛采用存算分离架构，互连计算集群和存储集群的网络成为云存储的关键性能瓶颈。尽管基于 Clos 的网络架构提供了足够的网络带宽，但传统的 TCP/IP 协议栈仍面临高延迟、单核吞吐量低，CPU 消耗高等问题，使其并不适合这种存算分离的场景。

鉴于这些限制，RDMA（Remote Direct Memory Access） 提供了一种很有前景的解决方案。通过将网络协议栈卸载到网卡（NIC）硬件上，RDMA 在 CPU 接近零开销的情况下，实现了超低处理延迟和超高吞吐。除了性能改进之外，RDMA 还减少了每台服务器上专为网络协议栈处理报文所预留的 CPU 核数。这些节省下来的 CPU 核可以作为 VM 进行出售或被用于应用程序。

为了充分利用 RDMA 的优势，我们的目标是在存储前端流量（VM 计算集群和存储集群之间）和后端流量（存储集群内）中启用 RDMA。这与之前的工作不同，之前的工作仅仅是针对存储后端流量启用 RDMA。在 Azure 云中，由于受容量问题的影响，计算集群和存储集群可能位于同一 region 内的不同数据中心。这就要求我们必须具有 region 规模支持 RDMA 的能力。

在本文中，我们总结了在 region 规模部署 RDMA 以支持 Azure 存储工作负载的经验。与之前的 RDMA 部署相比，由于 Azure region 内的高度复杂性和异构性，region 规模 RDMA 部署引入了许多新的挑战。随着 Azure 基础设施的不断发展，不同的集群可能会部署不同的 RDMA NIC。虽然所有 NIC 都支持 DCQCN，但不同厂商 NIC 的实现方式不同。当不同厂商的 NIC 互通时，这会导致许多不可预期的行为。同样的，来自多个供应商的异构交换机软硬件显着增加了我们的运营工作量。此外，互连数据中心的长距离电缆会导致 region 内较大的传播时延和较大的往返时间（RTT）的变化，这给拥塞控制带来了新的挑战。

为了安全地在 region 内为 Azure 存储流量启用 RDMA，我们从应用层协议到链路层流量控制等方面对网络基础设施进行了多项改造。我们基于 RDMA 开发了具有许多优化和 failover 支持的全新存储协议，并能在传统存储协议栈中进行无缝集成。我们构建了 RDMA Estats 工具用来监控主机网络协议栈的状态。我们通过 SONiC 在不同交换机平台上实施统一的软件栈部署。我们更新了 NIC 的固件以统一其 DCQCN 行为，并结合使用 PFC 和 DCQCN 来实现网络的高吞吐、低延迟和近乎零丢包。

![](/img/2024-01-03-empowering-azure-storage-with-rdma/figure1.png)
图 1：2023 年 1 月 18 日至 2 月 16 日期间 Azure 公有云所有 region 的流量统计数据。流量是通过收集所有 ToR 交换机上面向服务器一次的交换机端口计数器测量得到的，大约 70% 的流量是 RDMA 流量。

2018 年，我们开始为后端存储流量启用 RDMA。 2019 年，我们开始为客户前端存储流量启用 RDMA 。图 1 给出了 2023 年 1 月 18 日至 2 月 16 日期间 Azure 公有云所有 region 的流量统计数据。截至 2023 年 2 月，Azure 云中大约 70% 的流量是 RDMA 流量，并且 Azure 公有云所有 region 都支持 region 内 RDMA。 RDMA 帮助我们显着提高磁盘 I/O 性能并节​​省 CPU 资源。

## 2. 背景
- - -

在本节中，我们首先介绍 Azure 网络和存储架构的背景知识。然后，我们介绍一下 region 内实现 RDMA 网络的动机和挑战。

### 2.1 Azure region 的网络架构
- - -

![](/img/2024-01-03-empowering-azure-storage-with-rdma/figure2.png)

在云计算中，region 是部署在延迟定义的边界内的一组数据中心。图 2 显示了一个 Azure region 的简化拓扑。region 内的服务器通过基于以太网的 Clos 网络进行连接，该 Clos 网络具有四级（four tiers）交换架构：第 0 层（T0）、第 1 层（T1）、第 2 层（T2）和 region 枢纽层 (RH/region hub)。我们使用 eBGP 进行路由学习，使用 ECMP 进行负载平衡。
我们部署以下四种类型的组件：
* Rack（机架）：T0 交换机和连接到它的服务器。
* Cluster（集群）：连接到同一组 T1 交换机的一组机架。
* Datacenter（数据中心）：连接到同一组 T2 交换机的一组集群。
* Region（地域）：连接到同一组 RH 交换机的数据中心。与数据中心中的短链路（几米到数百米）相比，T2 和 RH 交换机通过长度可达数十公里的长距离链路进行连接。

该架构有两点需要注意：首先，由于 T2 和 RH 之间通过长距离链路进行连接，基本 RTT 从数据中心内的几微秒到 region 内的 2 毫秒进行变化。其次，我们使用两种类型的交换机：用于 T0 和 T1 的盒式交换机（pizza box switch），以及用于 T2 和 RH 的框式交换机（chassis switch）。盒式交换机已被学术界广泛研究并使用，该交换机通常带有一颗浅 buffer 的 ASIC 交换芯片。相比之下，框式交换机具有多颗基于虚拟输出队列 (VoQ) 架构的深 buffer ASIC 交换芯片。

### 2.2 Azure 存储的高级架构
- - -

![](/img/2024-01-03-empowering-azure-storage-with-rdma/figure3.png)

在 Azure 云中，我们计算集群与存储资源进行分离以节省成本并支持自动扩展。在 Azure 云中主要有两种类型的集群：计算集群和存储集群。在计算集群中创建 VM ，但是其虚拟硬盘 (VHD) 实际存储在存储集群中。

图 3 显示了 Azure 存储的高级架构。 Azure 存储分为三层：前端层、分区层和流层。流层是一个仅附加的分布式文件系统。它将位存储在磁盘上并复制它们以实现持久性，但它不理解更高级别的存储抽象，例如 Blob、表和 VHD。分区层理解不同的存储抽象，管理存储集群中所有数据对象的分区，并将对象数据存储在流层之上。分区层和流层的守护进程分别称为分区服务器（PS）和扩展节点（EN）。 PS 和 EN 位于每个存储服务器上。前端 (FE) 层由一组服务器组成，用于验证传入请求并将其转发到相应的 PS。在某些情况下，FE服务器也可以直接访问流层以提高效率。




## 参考
- - -
* [Empowering Azure Storage with RDMA](https://www.usenix.org/conference/nsdi23/presentation/bai)

## 公众号：Flowlet
- - -

<img src="/img/qrcode_flowlet.jpg" width = 30% height = 30% alt="Flowlet" align=center/>

- - -