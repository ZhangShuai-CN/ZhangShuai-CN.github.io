---
layout:     post
title:      "I/O虚拟化 101：虚拟化技术概述 与 I/O 虚拟化（IOV）详解"
subtitle:   "A Deep Dive into virtualization technology and I/O virtualization（IOV）"
description: "A Deep Dive into virtualization technology and I/O virtualization（IOV）"
excerpt: ""
date:       2023-03-17 01:01:01
author:     "张帅"
image: "/img/2023-03-17-virtualization-tech-and-iov/background.jpg"
showtoc: true
draft: false
tags:
    - virtualization
    - I/O virtualization
categories: [ Tech ]
URL: "/2023/03/17/virtualization-tech-and-iov/"
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
虚拟化技术是实现云计算的基石，虚拟化技术主要由三项关键技术构成：CPU 虚拟化、内存虚拟化和 I/O 虚拟化。I/O 虚拟化作为计算、网络与存储的技术交织点，其重要性与复杂性不言而喻。

I/O 外设资源是有限的，通过 I/O 虚拟化（IOV：I/O Virtualization）技术可以在多个虚拟机之间共享单个 I/O 资源。

本文将详解虚拟化技术分类与实现 I/O 虚拟化的 2 种方式：**I/O 模拟（Device emulation）** 与 **I/O 直通（Device passthrough）**。

其中 ：

**I/O 模拟（Device emulation）可分为**：I/O 全虚拟化（I/O Full-virtualization）与 I/O 半虚拟化（I/O Para-virtualization）；

**I/O 直通（Device passthrough）可分为**：设备直通（Direct I/O assignment）与 SR-IOV 直通；

## 前言
- - -

由于作者水平有限，本文不免存在遗漏或错误之处，欢迎指正交流。


## 1. 虚拟化介绍
- - -

在计算机系统中，从底层至高层依次可分为：硬件层、操作系统层、函数库层、应用程序层。

可以对上述 4 层中的任意一层进行虚拟化，在对某层实施虚拟化时，该层和上一层之间的接口不发生变化，而只变化该层的实现方式。对以上 4 层进行虚拟化，可以分别形成以下 4 种虚拟化方式：

### 1.1 硬件抽象层虚拟化
- - -

硬件抽象层上的虚拟化是指通过虚拟硬件抽象层来实现虚拟机，为虚拟机操作系统呈现和物理硬件相同或相近的硬件抽象层，又称为指令集级虚拟化。

实现在此层的虚拟化技术可以对整个计算机系统进行虚拟，即可将一台物理计算机系统虚拟为一台或多台虚拟机。每台虚拟机都拥有自己的虚拟硬件（如 CPU、内存和设备等），来提供一个独立的虚拟机执行环境。

每个虚拟机中的操作系统可以完全不同，并且它们的执行环境是完全独立的。由于虚拟机操作系统所能看到的是硬件抽象层，因此，虚拟机操作系统的行为和在物理平台上没有什么区别。

例如：KVM、WMware Workstation、VMware vSphere、Microsoft Hyper-v 都属于硬件抽象层的虚拟化。

### 1.2 操作系统层虚拟化
- - -

操作系统层上的虚拟化是指操作系统的内核可以提供多个互相隔离的用户态实例。这些用户态实例（也就是现在广为人知的：容器）对于它的用户来说就像是一台真实的计算机，有自己独立的文件系统、网络协议栈以及系统设置和库函数等。

由于这是操作系统内核提供的虚拟化，因此操作系统层上的虚拟化通常非常高效，它的虚拟化资源和性能开销非常小，也不需要特殊的硬件支持。但它的灵活性相对较小，每个容器的操作系统和宿主机的操作系统通常必须是同一种操作系统。

另外，操作系统层上的虚拟化虽然为用户态实例间提供了比较强的隔离性，但其粒度是比较粗的。

例如：Docker、Containered 都属于操作系统层的虚拟化。

### 1.3 库函数层虚拟化
- - -
操作系统通常会通过库函数的形式给其他应用程序提供一组通用服务，例如文件操作服务、时间操作服务等。这些库函数可以隐藏操作系统内部的一些细节，使得应用程序编程更为简单。

不同的操作系统库函数有着不同的服务接口，例如 Linux 的服务接口是不同于 Windows 的。库函数层上的虚拟化就是通过将操作系统的应用级库函数的服务接口进行虚拟化，使得应用程序不需要修改，就可以在不同的操作系统中无缝运行，从而提高系统间的互操作性。

例如，Wine 就是在 Linux 上模拟了 Windows 的库函数接口，使得一个 Windows 应用程序能够在 Linux 上正常运行。


### 1.4 编程语言层虚拟化
- - -

编程语言层上的虚拟机称为语言级虚拟机，例如 JVM（Java Virtual Machine）。这一类虚拟机运行的是进程级的作业，所不同的是这些程序所针对的不是一个硬件上存在的体系结构，而是一个虚拟体系结构。

这些程序的代码首先被编译为针对其虚拟体系结构的中间代码，再由虚拟机的运行时支持将中间代码翻译为硬件的机器语言进行执行。

## 2. VMM 介绍
- - -

我们本篇讨论的虚拟化是硬件抽象层虚拟化。即：指令集级虚拟化，是最早被提出和研究的一种虚拟化技术，当前存在多种此种技术的具体实现方案，在介绍它们之前，有必要先了解实现系统级虚拟化可采取的途径。

在每台虚拟机中都有属于它的虚拟硬件，通过虚拟化层的模拟，虚拟机中的操作系统认为自己仍然是独占机器在运行，这个虚拟化层被称为虚拟机监控器（Virtual Machine Monitor，VMM）。

VMM 对物理资源的虚拟可以归结为三个主要任务：处理器虚拟化、内存虚拟化和I/O虚拟化。

![](/img/2023-03-17-virtualization-tech-and-iov/2023-03-19-hyperviosrs.png)

当前企业级主流的 VMM (Virtual Machine Monitor) 主要分为 3 种类型：**Type-1（Hypervisor 模型）、Type-2（宿主机模型）、Type-3/Type-1.5（混合模型）**。

### 2.1 Type-1（Hypervisor 模型/ Bare-metal）
- - -

Hypervisor 这个术语是在 20 世纪 70 年代出现的，在早期计算机界，操作系统被称为 Supervisor，因而能够运行的其他操作系统的操作系统被称为 Hypervisor。

在 Hypervisor 模型中，VMM 首先可以被看做是一个完备的操作系统，不过和传统操作系统不同的是，VMM是为虚拟化而设计的，因此还具备虚拟化功能。从架构上来看，首先，所有的物理资源如处理器、内存和 I/O 设备等都归 VMM 所有，因此，VMM 承担着管理物理资源的责任；其次，VMM 需要向上提供虚拟机用于运行客户机操作系统，因此，VMM 还负责虚拟环境的创建和管理。

由于 VMM 同时具备物理资源的管理功能和虚拟化功能，因此，物理资源虚拟化的效率会更高一些。Hypervisor 模型在拥有虚拟化高效率的同时也有其缺点。由于 VMM 完全拥有物理资源，因此，VMM 需要进行物理资源的管理，包括设备的驱动。

我们知道，设备驱动开发的工作量是很大的。因此，对于 Hypervisor 模型来说这是个很大的挑战。事实上，在实际的产品中，基于 Hypervisor 模型的 VMM 通常会根据产品定位，有选择地挑选一些 I/O 设备来支持，而不是支持所有的 I/O 设备。

> 采用这种模型的典型是面向企业级应用的 VMware vSphere。

### 2.2 Type-2 (宿主机模型 / Hosted)
- - -

在宿主模型中，物理资源由宿主机操作系统管理。宿主机操作系统是传统操作系统，如 Windows 、Linux 等，这些传统操作系统并不是为虚拟化而设计的，因此本身并不具备虚拟化功能，实际的虚拟化功能由 VMM 来提供。

VMM 通常是宿主机操作系统独立的内核模块，有些实现中还包括用户态进程，如负责 I/O 虚拟化的用户态设备模型。 VMM 通过调用宿主机操作系统的服务来获得资源，实现处理器、内存和 I/O 设备的虚拟化。VMM创建出虚拟机之后，通常将虚拟机作为宿主机操作系统的一个进程参与调度。

宿主模型的优缺点和 Hypervisor 模型恰好相反。宿主模型最大的优点是可以充分利用现有操作系统的设备驱动程序，VMM 无须为各类 I/O 设备重新实现驱动程序，可以专注于物理资源的虚拟化。考虑到 I/O 设备种类繁多，千变万化， 设备驱动程序开发的工作量非常大，因此，这个优点意义重大。此外，宿主模型也可以利用宿主机操作系统的其他功能，例如调度和电源管理等，这些都不需要 VMM 重新实现就可以直接使用。

宿主模型当然也有缺点，由于物理资源由宿主机操作系统控制，VMM 得要调用宿主机操作系统的服务来获取资源进行虚拟化，而那些系统服务在设计开发之初并没有考虑虚拟化的支持，因此，VMM 虚拟化的效率和功能会受到一定影响。

> 采用这种模型的典型是 KVM、QEMU、VirtualBox 和 VMware Workstation。

### 2.3 Type-3/Type-1.5（混合模型 / Hybrid）
- - -

混合模型是上述两种模式的混合体。VMM 依然位于最低层，拥有所有的物理资源。与 Hypervisor 模式不同的是，VMM 会主动让出大部分 I/O 设备的控制权，将它们交由一个运行在特权虚拟机中的特权操作系统控制。相应地，VMM 虚拟化的职责也被分担，处理器和内存的虚拟化依然由 VMM 来完成，而 I/O 的虚拟化则由 VMM 和特权操作系统共同合作来完成。因此，设备模型模块位于特权操作系统中，并且通过相应的通信机制与 VMM 合作。

混合模型集中了上述两种模型的优点。VMM 可以利用现有操作系统的 I/O 设备驱动程序，不需要另外进行开发。VMM 直接控制处理器、内存等物理资源，虚拟化的效率也比较高。

当然，混合模型也存在缺点。由于特权操作系统运行在虚拟机上，当需要特权操作系统提供服务时，VMM 需要切换到特权操作系统，这里面就产生上下文切换的开销。当切换比较频繁时，上下文切换的开销会造成性能的明显下降。出于性能方面的考虑，很多功能还是必须在VMM 中实现，如调度程序和电源管理等。

> 采用这种模型的典型是 Xen。

![](/img/2023-03-17-virtualization-tech-and-iov/2023-03-19-Comparison-of-Xen-KVM-and-QEMU.png)


## 3. I/O 模拟
- - -

**I/O 模拟（Device emulation）主要分为**：I/O 全虚拟化（I/O Full-virtualization）与 I/O 半虚拟化（I/O Para-virtualization）2 种架构。

在讲解这 2 种 I/O 模拟架构之前，我们先看一下目前主流的 2 种 VMM 模型中，设备模拟是如何工作的：

* 第一种架构中将设备模拟集成到 VMM 中。
* 第二种架构则在 VMM 的外部的应用程序中进行设备模拟。

![](/img/2023-03-17-virtualization-tech-and-iov/2023-03-19-figure1.gif)

在 VMM 中集成设备模拟是在 VMware workstations 中实现的设备模拟的常用方法。如上图所示，在这个模型中，VMM 包括各种虚拟机操作系统可以共享的公共设备（例如：虚拟磁盘、虚拟网络适配器等）的模拟。

![](/img/2023-03-17-virtualization-tech-and-iov/2023-03-19-figure2.gif)

如上图所示，第二种架构成为用户空间设备模拟。顾名思义，不是将设备模拟嵌入到 VMM 中，而是在用户进程中实现。QEMU 提供设备模拟，并被大量独立的 VMM（基于内核的虚拟机[KVM]）所使用。

此模型的优点是，因为设备模拟独立于 VMM，因此可以在 VMM 之间共享模拟设备。它还可以在不改动 VMM 的同时，进行任意类型的设备模拟。

### 1.1 I/O 全虚拟化
- - -

![](/img/2023-03-17-virtualization-tech-and-iov/2023-03-19-io-full-virtualization.png)

该方式采用软件模拟真实硬件设备。一个设备的所有功能或者总线结构（如设备枚举、识别、中断和DMA）等都可以在 VMM 中模拟。而对虚拟机而言看到的是一个功能齐全的“真实”的硬件设备。其实现上通常需要宿主机上的软件配合截取客户机对 I/O 设备的各种请求，然后通过软件模拟真实的硬件。比如：QEMU/KVM 虚拟化中 QEMU 就可以模拟各种类型的网卡。

这种方式对客户机而言非常透明，无需考虑底层硬件的情况，不需要专有驱动，因此不需要修改操作系统。但是，全虚模型有一个很大的不足之处，即性能不够高，主要原因有两方面：
* 模拟方式是用软件行为进行模拟，这种方式本身就无法得到很高的性能；
* 这种模型下 I/O 请求的完成需要虚拟机与 VMM 多次的交互，产生大量的上下文切换，造成巨大开销。 

![](/img/2023-03-17-virtualization-tech-and-iov/2023-03-19-kvm-qemu.png)
在 KVM-qemu 模型的虚拟化中，模拟 IO 虚拟化方式的最大开销在于处理器模式的切换：包括从 Guest OS 到 VMM 的切换，以及从内核态的 VMM 到用户态的 IO 模拟进程之间的切换。

### 1.2 I/O 半虚拟化
- - -
![](/img/2023-03-17-virtualization-tech-and-iov/2023-03-19-io-para-virtualization.png)

在这种虚拟化中，客户机操作系统能够感知到自己是虚拟机，I/O 的虚拟化由前端驱动和后端驱动共同模拟实现。

前端/后端架构也称为 “Split I/O”，即将传统的I/O驱动模型分为两个部分，一部分是位于客户机OS内部的设备驱动程序(前端)，该驱动程序不会直接访问设备，前端驱动负责接收来自其他模块的I/O操作请求，并通过虚拟机之间的事件通道机制将I/O请求转发给后端驱动，后端驱动可以直接调用物理I/O设备驱动访问硬件。后端在处理完请求后会异步地通知前端。

相比于全虚模型中 VMM 需要截获每个 I/O 请求并多次上下文切换的方式，这种基于请求/事务的方式能够在很大程度上减少上下文切换的频率，并降低开销。但是这种 I/O 模型有一个很大的缺点，要修改操作系统内核以及驱动程序，因此会存在移植性和适用性方面的问题，导致其使用受限。

而在不同的虚拟化机制中，这一过程的实现手段也有所区别，例如：VMware 的 VMXNET2、VMXNET3，KVM 中的 virtio。

![](/img/2023-03-17-virtualization-tech-and-iov/2023-03-19-virtio-architecture.png)

半虚拟化中的 virtio 是 IBM 于2005年提出的一套方案，经过了十多年的发展，其驱动现在基本已经被主流的操作系统接纳编入内核，因此 **virtio 也已经成为 I/O 半虚拟化的事实标准**。


## 2. I/O 直通
- - -
**I/O 直通（Device passthrough）可分为**：设备直通（Direct I/O assignment）与 SR-IOV 直通；

### 2.1 设备直通
- - -
![](/img/2023-03-17-virtualization-tech-and-iov/2023-03-19-figure3.gif)

软件实现 I/O 虚拟化的技术中，所有的虚拟机都共享物理平台上的硬件设备。如果物理条件好，有足够的硬件，就可以考虑让每个虚拟机独占一个物理设备，这样无疑会提高系统的性能。

把某一个设备直接分配给一个虚拟机，让虚拟机可以直接访问该物理设备而不需要通过VMM或被VMM截获，这就是设备直通技术。

在设备直通模型中，虚拟机操作系统可直接拥有某一物理设备的访问控制权限，VMM 不再干涉其访问操作。因此，该模型可以较大地改善虚拟化设备的性能，降低 VMM 程序的复杂性，易于实现，并且不需要修改操作系统，保证了高可用性。

设备直通模型虽然在性能上相比软件方式的两种 I/O 设备虚拟化模型有着很大的提升，但是该模型的使用也是有一定限制的。

因为该模型将一件物理设备直接分配给了一个虚拟机，其它虚拟机是无法使用该设备的，所产生的一个问题就是如果其它虚拟机需要访问该设备则无法满足需求，解决办法就是物理资源充分满足需求或者通过硬件虚拟化技术虚拟出多个 IO 设备(与物理设备性能极为接近)供多个虚拟机使用(硬件必须支持)。

### 2.2 SR-IOV 直通
- - -
![](/img/2023-03-17-virtualization-tech-and-iov/2023-03-19-figure4.gif)

在I/O 直通技术中，将一件物理设备直接分配给了一个虚拟机，虽然获得近似于直接访问设备的 I/O 性能。但是由于其它虚拟机无法使用该设备的，牺牲了系统的扩展性。

因此，2007年9月，PCI-SIG 官方发布了《[Single Root I/O Virtualization and Sharing Specification Revision 1.0](https://pcisig.com/single-root-io-virtualization-and-sharing-specification-revision-10)》规范，定义了多个 System Images 如何共享 PCI 接口的 I/O 硬件设备。（这里的设备可以是 PCIe 网卡，一块 PCIe SSD 等等）。

SR-IOV 全称 Single Root I/O Virtualization。在SR-IOV中，定义了两个功能类型：
* **PF（物理功能类型）**，负责管理 SR-IOV 设备的特殊驱动，其主要功能是提供设备访问功能和全局共享资源配置的功能，虚拟机所有影响设备状态的操作均需通过通信机制向 PF 发出请求完成。

        每个PF都可以被物理主机发现和管理。进一步讲，借助物理主机上的 PF 驱动可以直接访问 PF 所有资源，并对所有 VF 并进行配置，比如：设置 VF 数量，并对其进行全局启动或停止。


* **VF（虚拟功能类型）**，是轻量级的 PCIe 功能，包含三个方面：向虚拟机操作系统提供的虚拟网卡；数据的发送、接收功能；与 PF 进行通信，完成全局相关操作。由于 VF 的资源仅是设备资源的子集，因此 VF 驱动能够访问的资源有限，对其它资源的访问必须通过 PF 完成。

        一个或者多个 VF 共享一个 PF，其驱动装在虚拟机上，当 VF 分配给虚拟机以后，虚拟机就能像使用普通 PCIe 设备一样初始化和配置 VF。如果 PF 代表的是一张物理网卡，那么 VF 则是一个虚拟机可以看见和使用的虚拟网卡。



## 参考
- - -
* [Virtio: An I/O virtualization framework for Linux](https://developer.ibm.com/articles/l-virtio/)
* [Linux virtualization and PCI passthrough](https://developer.ibm.com/tutorials/l-pci-passthrough/)
* [Virtualization Deep Dive](https://virtualizationdeepdive.wordpress.com/about/6-2/)
* [What is a Virtual Machine?](https://www.marksei.com/what-is-virtual-machine/)
* [虚拟化技术基础](https://www.cnblogs.com/VicLiu/p/12111792.html)
* [虚拟化技术介绍](https://zhuanlan.zhihu.com/p/565358215)
* [Virtualization 1 of 4 – Hypervisor](https://www.digihunch.com/2020/07/overview-of-virtualization/)
* [VMware，Redhat，Citrix和Microsoft 4种主要的网络IO虚拟化模型](https://www.dell.com/community/%E7%BB%BC%E5%90%88%E8%AE%A8%E8%AE%BA%E5%8C%BA/%E5%88%86%E4%BA%AB-VMware-Redhat-Citrix%E5%92%8CMicrosoft-4%E7%A7%8D%E4%B8%BB%E8%A6%81%E7%9A%84%E7%BD%91%E7%BB%9CIO%E8%99%9A%E6%8B%9F%E5%8C%96%E6%A8%A1%E5%9E%8B/td-p/6930736)
* [CNTT Relevant Technologies](https://cntt-test.readthedocs.io/en/anuket-docs-all-sphinx-interlink/common/technologies.html)
* [NFV关键技术：计算虚拟化之IO虚拟化](https://www.51cto.com/article/696128.html)

## 公众号：Flowlet
- - -

<img src="/img/qrcode_flowlet.jpg" width = 30% height = 30% alt="Flowlet" align=center/>

- - -