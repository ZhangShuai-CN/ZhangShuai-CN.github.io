---
layout:     post
title:      "Achelous：超大规模云网络中如何实现网络的可编程性、弹性和可靠性 [SIGCOMM 2023]"
subtitle:   "超大规模云网络中如何实现网络的可编程性、弹性和可靠性"
description: "Achelous：Enabling Programmability, Elasticity, and Reliability in Hyperscale Cloud Networks"
excerpt: ""
date:       2023-09-30 01:01:01
author:     "张帅"
image: "/img/2023-09-30-sigcomm2023-achelous/background.jpg"
showtoc: true
draft: true
tags:
    - SIGCOMM 2023
categories: [ Tech ]
URL: "/2023/09/30/sigcomm2023-achelous/"
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

SIGCOMM 是 ACM 组织在网络通信领域的顶会，阿里云洛神云网络团队发表的《Achelous: Enabling Programmability, Elasticity, and Reliability in Hyperscale Cloud Networks》被 SIGCOMM'23 主会录用，本文为该论文的译著。

## 前言
- - -

本文为译者根据原文意译，非逐词逐句翻译。由于译者水平有限，本文不免存在遗漏或错误之处。如有疑问，请查阅[原文](https://dl.acm.org/doi/10.1145/3603269.3604859)。

## 摘要
- - -

云计算取得了巨大的增长，促使企业迁移到云端以获得可靠且按需购买的计算力。

在单个 VPC 内，计算实例（如虚拟机、裸金属、容器）的数量已达到数百万级别，百万实例对云网络的高弹性、高性能和高可靠性都带来了前所未有的挑战。

然而，学术研究主要集中在高速数据平面和虚拟化路由基础设施等具体问题上，而工业届现有的网络技术无法充分应对这些挑战。

在本文中，我们报告了 Achelous 的设计和经验，阿里云网络虚拟化平台。

Achelous 包含三个增强超大规模 VPC 的关键设计：

(𝑖)一种基于数据平面和控制平面协同设计的新颖的分层编程架构；

(𝑖𝑖) 分别用于无缝纵向扩展（scale-up）和横向扩展（scale-out）的弹性性能策略和分布式 ECMP 方案；

(𝑖𝑖𝑖)健康检查方案和透明的虚拟机实时迁移机制，确保故障转移期间的状态流（stateful flow）的连续性。

评估结果表明，Achelous 可在单个 VPC 中扩展到超过 1,500,000 个具有弹性网络容量的虚拟机，并减少 25 倍的编程时间, 99%更新都可以在1 秒内完成。对于故障转移，它在虚拟机实时迁移期间的停机时间压缩了 22.5 倍。并确保 99.99% 的应用程序不会出现停顿。

更重要的是，三年的运行经验证明了Achelous的耐用性，以及独立于任何特定硬件平台的多功能性。

## 1. 介绍
- - -

多年来，云计算持续增长，有前景的新云服务（例如无服务计算、AI 训练和数字办公）已经成为人们关注的焦点，强化了这一趋势。


大型企业将业务迁移至云端，寻求灵活的扩展能力以应对不断变化的业务需求，往往会造成网络峰谷现象。

同时，租户期望云中的网络服务与物理硬件一样可靠。这些综合需求对云网络的设计提出了重大挑战。

然而，学术研究主要集中在高速数据平面[48,49]和虚拟化路由基础设施[31,41]等具体问题上，而现有的工业网络技术难以充分支持超大规模云网络。
例如，Andromeda [14] 提出了 Hoverboard，以在 Google 云网络虚拟化中提供大规模的高性能、隔离性和速度。

然而，这些技术不足以解决现代云应用带来的网络可扩展性和突发性能等更重大的挑战。

我们的经验告诉我们集成内聚系统和跨网络基础设施分配功能的重要性，例如控制器、网关和 vSwitch。

下面，我们重点介绍现代云环境中遇到的三个主要挑战。

### Change 1 为数百万个并发实例提供服务时，重新配置时间为亚秒级（sub-second）。
- - -

第一个重大挑战源于电子商务业务（例如淘宝[5]）向云的迁移，导致在单个虚拟私有云 (VPC) 中部署大量实例（例如虚拟机、裸机和容器）。

图 1 展示了阿里巴巴单个 VPC 内的电子商务实例呈指数级增长的典型示例，到 2022 年将达到 1,500,000 个实例。

![](/img/2023-09-30-sigcomm2023-achelous/figure1.png)

超大规模网络呈现出两个关键特征：高部署密度和频繁的实例创建/销毁。

例如，在流量高峰期间，我们可能需要额外启动 20,000 个容器实例，每个容器实例的生命周期只有几分钟。

现有的网络编程方法无法同时处理如此大量实例的创建和准备。例如，Andromeda [14] 在论文中提出了一种可扩展 100,000 个实例的设计，根据最新报告，AWS 支持每个 VPC 最多 256,000 个实例 [3]。

然而，在阿里云内部，需要支持的实例数量比任何现有技术所能容纳的要高出一个数量级。

这些超大规模VPC的激增导致路由条目大幅增加和网络变化频率较高，从而对网络收敛速度提出了挑战。

具体来说，云供应商必须在有限的时间内提供服务，例如能够在 1 秒内启动大量具有就绪网络连接的无服务器容器。

### Change 2 高弹性网络，适合大流量 网络中间设备（middle-box） 、云网关 部署
- - -
第二个重大挑战来自于迁移传统的重负载网络应用程序，例如中间盒。到云中的虚拟机 (VM)。最初，这些中间件（例如负载均衡器、NAT 网关和防火墙）部署在物理网络内的专用硬件上。

将它们迁移到云端可提供弹性和企业成本优化优势。然而，这种转换破坏了最初专用设备提供的隔离，可能导致与同一主机上的其他实例发生资源争用（网络和 CPU 资源）。

此外，中间盒虚拟机必须表现出弹性可扩展性（纵向扩展和横向扩展），以有效处理可变的流量压力，因为客户的容量需求可能会发生变化。

不幸的是，现有的研究[8,11,22,27,45]未能考虑资源竞争，因此不适合在多租户云主机上提供隔离但弹性的资源分配。

在横向扩展场景方面，负载均衡方法 [15, 55] 和传统的等价多路径 (ECMP) 路由机制 [9, 37] 引入了新的瓶颈。

集中式负载均衡器和 ECMP 转发节点成为网络可扩展性的主要限制因素，因为它们处理来自数百万个源虚拟机的流量。

### Change 3 高云服务可用性和可靠性
- - -


对于云厂商来说，资源利用率和可靠性是云平台的重要指标。然而，在云网络中，检测故障并实现快速故障转移提出了重大挑战。虚拟网络和物理设备之间的动态映射使得建立精确的拓扑变得困难，这反过来又阻碍了故障遥测。

现有的故障遥测技术[8,11,22,27,32,34,45]要么关注物理网络，要么缺乏实时能力，无法保证虚拟网络的可靠性。使问题更加复杂的是，大多数实时迁移技术 [28,30,53] 忽视了有状态流的流量连续性，导致租户服务中断。

考虑到上述挑战，我们在三年前就开始重新构建我们的网络架构。我们发现当前的网络组件（即控制器、网关和 vSwitch）无法独立满足这些要求。

利用来自控制平面和数据平面的见解，我们提出了 Achelous，阿里云的网络虚拟化平台，可在超大规模云网络中提供可编程性、弹性和可靠性。

我们重点介绍基于我们丰富的运营经验的三种主要设计选择。

首先，为了解决较大的转发表和较慢的收敛速度的挑战，我们提出了一种新颖的编程机制，该机制根据需要从网关而不是控制器主动学习转发信息。

控制器只需将网络规则卸载到网关，而不是每台主机上的 vSwitch（第 4.1 节）。我们还设计了一个轻量级的转发缓存，对IP粒度进行有效管理，以进一步缩小表结构（§4.3）。

其次，为了在保证性能隔离的同时实现主机内的可扩展性，我们提出了一种新颖的弹性策略，可以平衡隔离和突发流量，并实现带宽和CPU资源的高利用率（§5.1）。

此外，我们演示了一种分布式 ECMP 机制，将流量重定向到多个 vSwitch，以实现主机之间服务的无缝横向扩展（第 5.2 节）

第三，我们提出了一个链路健康检查方案来验证 vSwitch 和 VM 之间的网络链路状态，以及一个用于检测 vSwitch 本身状态的监视器（第 6.1 节）。

此外，我们还介绍了一系列透明的虚拟机实时迁移技术，包括流量重定向、会话重置和会话同步。

这些技术缩短了虚拟机迁移停机时间，在应用程序不知情的情况下支持无状态和有状态流的连续性（第 6.2 节）。

我们的部署和评估结果验证了这些设计选择的有效性。多年来，Achelous 一直是阿里巴巴 VPC 网络堆栈的基石。它显着改善了用户可感知的体验。

值得注意的是，99% 的服务启动延迟小于 1 秒，而 99.99% 的应用程序没有出现停顿。

经过多年的运营，我们相信Achelous的设计选择不仅可行而且非常有效，并且经验教训（§8）可以广泛应用于其他云供应商。

因此本文做出以下贡献：

我们提出了一种新颖的按需主动学习编程机制，具有优化的表结构，以加速超大规模 VPC 的网络覆盖。
超过150万个VM实例的VPC可以在1.33𝑠内完成配置覆盖。与传统部署模式相比，我们的机制将配置收敛时间提高了 25 倍以上。


我们提出了弹性网络容量策略和分布式ECMP机制，支持主机间隔离和无缝横向扩展的前提下进行纵向扩展。
重载服务，我们支持0.3𝑠以内无缝扩缩容


我们为虚拟机设计了一整套故障检测和避免机制，其中包括丰富的健康检查方法和无缝实时迁移方案。通过这些机制，VM 的故障转移延迟约为 100𝑚𝑠，而不会影响来宾 VM 内的应用程序





## 2. 背景与动机
- - -

Achelous是阿里云的网络虚拟化平台，在过去十年中不断发展以支持阿里云的虚拟网络。

通过 Achelous 1.0 和 Achelous 2.0 阶段，它的性能得到了显着改进。
随着云网络不断扩展，新的挑战出现，促使我们增强和迭代 Achelous 2.0。在本节中，我们将讨论 Achelous 的演变、Achelous 2.0 中的 VM 网络数据路径以及新的挑战.

### 2.1 Achelous在阿里云中的作用
- - -

在阿里云中，Achelous 通过三个基本组件提供 VM 网络虚拟化（如图 2 所示）：控制平面的SDN控制器，数据平面的vSwitch和网关。

![](/img/2023-09-30-sigcomm2023-achelous/figure2.png)

在控制平面上，控制器管理实例（例如虚拟机、裸机）生命周期中的所有网络配置，并将网络规则发布到 vSwitch 和网关。

例如，一旦创建了 VM 实例（例如 VM1），控制器会将所有现有 VM1 的网络转发信息发布到 vSwitch 和网关。

然后，如果VM1的网络发生变化（例如迁移到另一台主机、安装新网卡），控制器将更新并更正数据平面中的相应规则。

在数据平面上，vSwitch 作为专用于虚拟机流量转发的每主机交换节点。

网关作为高层转发组件，促进不同域之间的互连。在图 2 中，我们提供了一个示例：当 vSwitch 处理 VM1 的数据包时，它会确定适当的目的地。

如果目的VM与VM1（例如VM2）在同一主机上，则vSwitch直接转发数据包。否则，如果目标虚拟机位于不同的主机（例如裸机）上，则数据包将通过网关中继。有关网关的更多详细信息，请参考 Sailfish [42]，支持在各种硬件平台上部署。

### 2.2 Achelous 的进化
- - -

Achelous的开发始于十多年前，最初的版本Achelous 1.0为阿里云提供了基础的虚拟网络环境。。

由于其开发时间早于VXLAN标准的制定[39]，Achelous 1.0经历了从经典二层网络到标准VPC覆盖网络的架构转变。

这一演进通过 VXLAN 网络标识符 (VNI) 启用来宾虚拟机的第 2 层隔离，从而增强了安全性。

然而，Achelous 1.0由于其数据平面依赖Linux内核中的netfilter[4]而面临性能挑战，这始终是网络处理的瓶颈。


在Achelous 2.0中，通过数据平面开发套件（DPDK）[2]加速和硬件卸载，数据平面性能得到了显着提高。

这些加速方法有效地减少了数据路径上的数据包复制开销，这对于转发性能至关重要。

此外，Achelous 2.0 中的优化涉及卸载东西向流量（VM-VM 流量）以缓解潜在的瓶颈。由于东西向流量占总流量的3/4以上，依靠网关进行中继会带来明显的瓶颈。在 Achelous 2.0 中，控制器向 vSwitch 发出所有东西向规则，以便 vSwitch 可以通过直接路径转发东西向流量（见图 2）。然而，这会引起挑战1（第2.4节中），因为当网络发生变化时，每个vSwitch都应该被告知正确的规则。


### 2.3 Achelous 2.0 中的 VM 网络数据路径
- - -

为了深入了解该平台，我们简要介绍 Achelous 2.0 的 VM 网络数据路径上的关键流程和数据结构。

Achelous 2.0 的 VM 网络数据路径（图 3）由两部分组成：慢速路径和快速路径。慢速路径包含一个由各种表组成的数据包处理管道，每个表都有特定的功能。

![](/img/2023-09-30-sigcomm2023-achelous/figure3.png)

这些表包括访问控制列表（ACL）、服务质量表（QoS）、VXLAN路由表（VRT）、VM-HOST映射表（VHT）（即vm_ip-host_ip映射关系）等。所有表格均由控制器配置，其中 VHT 尤其重要。随着VPC内虚拟机数量的增加，VHT出现大幅扩容，导致条目激增。

对于快速路径，我们首先引入一种称为会话的新数据结构，它由两个方向的一对流条目（即原始方向的oflow和反向的rflow）以及数据包所需的所有状态组成。加工。

流表项包含报文的五元组，采用精确匹配算法。报文处理流程如下： 1）第一个报文通过慢速路径的管道进行处理；
2) 然后生成五元组流表项及其会话，并将其重新注入到快速路径中；

3）后续报文可以直接在快速路径上进行匹配和处理。

Achelous 2.0 中快速路径和慢速路径之间的性能差距很大，快速路径比慢速路径表现出 7-8 倍的性能优势。

这会导致来自不同流的数据包的网络专用 CPU 消耗和性能有所不同。例如，具有短期连接的虚拟机可能会独占高达 90% 的 vSwitch CPU 资源，从而影响其他虚拟机。这加剧了挑战2（第 2.4 节）。


此外，对超大规模VPC网络的需求放大了Achelous 2.0数据平面和控制平面中感知的设计“缺陷”所带来的挑战，特别是在适应电子商务和中间盒迁移到云等新服务场景方面。


### 2.4 Achelous 2.0 面临的挑战
- - -
与云厂商管理的有限VPC网络规模相比，超大规模部署下的新场景带来了三大严峻挑战：

(1)路由表较大，收敛速度较慢。最关键的考虑因素之一是控制平面的可扩展性。一方面，大型网络的扩展性需要更大的路由表，例如 VHT 和 VRT，从而导致资源受限的主机或云基础设施处理单元 (CIPU) 上的内存消耗增加[1]。例如，在阿里云中，VPC可以容纳超过150万个虚拟机，从而导致表项数量庞大，并消耗数GB内存来实现高效的数据包转发。

另一方面，还存在管理大量并发条目更改请求的问题。我们的实证分析表明，控制平面每天收到超过 1 亿个网络变更请求。请求的大量涌入对网络融合提出了挑战，而网络融合是自动扩展和故障转移的关键因素。

（2）在公平和隔离的基础上平衡闲置资源和突发流量。

随着虚拟机部署密度的不断增加，对弹性网络能力的需求日益迫切。在阿里云上进行的分析揭示了以下发现：

1）超过98%的虚拟机平均吞吐量低于10Gbps，表明网络资源严重闲置（见图4a）； 2）然而，网络爆发每天都会发生，导致数据平面中带宽和CPU资源的竞争（见图4b1）。

![](/img/2023-09-30-sigcomm2023-achelous/figure4.png)

例如，在线会议服务在工作时间会出现流量爆发的情况同时在休息期间需要最少的带宽。为了平衡闲置资源和突发流量，资源分配必须实现高弹性，同时保持公平性和隔离性。此外，流量大的租户在面临流量泛滥时需要跨多个主机的无缝扩展能力。

(3)检测网络风险并在租户无意识的情况下逃逸。

随着VPC网络配置的日益复杂，保证网络的高可靠性至关重要。传统上，网络运维严重依赖人工干预，导致缺乏预测故障的能力。


租户报告的网络故障通常需要花费大量时间和精力来查找和解决。尽管我们已经开发了各种网络故障定位技术[16]，但先进的先发制人的故障检测仍然是一个挑战。在超大规模 VPC 的背景下，采用网络风险意识方法对于早期故障检测和避免变得越来越重要，从而能够不间断地向租户提供服务。

此外，透明的实时迁移技术对于帮助租户虚拟机从故障主机或网络进行迁移时确保流量连续性至关重要。上述挑战促使我们重新思考Achelous中数据面和控制面的设计，并做出新的创新。


## 3. 设计概览
- - -

为了应对规模爆炸带来的挑战，我们在 Achelous 2.1 中提出了创新设计和改进。脱离单个组件过度优化的原则，我们探索数据平面和控制平面之间的协同协作。三个关键改进如下：

超大规模网络可编程性。为了减少网络收敛时间并提高记忆效率，我们在 Achelous 2.1 中提出了主动学习机制（§4.1）。在该机制中，vSwitch仅管理转发缓存，并通过路由同步协议（RSP）主动从网关学习路由信息.


因此控制器只需要对网关进行网络编程，而不需要对每个vSwitch节点进行网络编程。这种方法可以通过高性能数据平面实现快速网络更新，并确保以最短的收敛时间同步到受影响的 vSwitch。因此，我们避免在每台主机上存储完整的转发信息，从而将每台服务器的内存利用率和可扩展性提高一个数量级以上。

弹性网络容量。 Achelous通过无缝的纵向扩展和横向扩展方法来实现基于隔离的高弹性网络性能。


在数据平面中，网络容量是通过专用CPU内核提供的，因此需要考虑所有可用资源。 Achelous 2.1采用弹性策略（§5.1）为主机内的所有虚拟机分配带宽和CPU资源，不仅可以充分利用空闲资源应对突发流量，而且可以保证性能隔离。此外，为了在主机之间提供无缝服务扩展，我们在每个vSwitch（Achelous的边缘节点）中实现了分布式ECMP机制（第5.2节），消除了与底层网络集中部署相关的转发瓶颈。


网络风险意识和实时迁移。 Achelous 执行网络链路健康检查，以主动感知和预警故障，例如网络拥塞或 VM 停止（第 6.1 节）.

这涉及 vSwitch 根据预先配置的检查列表向虚拟机发送定期运行状况检查数据包。同时，vSwitch 本身向控制器报告性能统计数据，从而实现主动干预以减轻网络风险。一旦检测到风险，vSwitch 就会在控制器的指导下提供透明的虚拟机实时迁移以进行故障转移。在迁移过程中，Achelous 实施流量重定向、会话重置和会话复制技术（第 6.2 节），以满足不间断服务的网络属性（例如低停机时间、无状态流、有状态流和应用程序无感知） 。



## 4. 超大规模网络编程
- - -

在本节中，我们将介绍 Achelous 2.1 的设计，其目标是第 2.4 节中的第一个挑战。我们详细介绍了为超大规模云网络开发的编程机制，称为主动学习机制（ALM）。


### 4.1 主动学习机制设计
- - -

问题与目标。高内存消耗仍然是大规模转发表的关键挑战。在软件转发架构中[17, 43]，vSwitch与VM共享内存，导致内存中的超大规模转发条目大量使用内存，可能会导致主机内存资源紧张。

在硬件加速架构中[18, 44]，专用硬件上可用高速片上存储器的限制进一步加剧了存储器资源的限制。

更糟糕的是，当大规模转发表遇到高并发的网络变更请求时，控制器无法及时通知每个受影响的vSwitch，从而成为瓶颈。因此，我们的目标是在 Achelous 中开发一种有效的编程机制来服务于超大规模网络。

洞察力。我们的主要观察结果是，数据中心网络会经历不断的变化来处理故障、部署/升级服务以及适应流量波动。

因此，虚拟机或容器的位置可能会因虚拟机迁移、故障和创建/释放事件而频繁变化。具体来说，虚拟路由表（VRT）和虚拟机主机映射表（VHT）经历高频更新。另一方面，vSwitch 上的配置表（例如 ACL 和 QoS）更改频率较低。

例如，租户安全组配置保持相对稳定，而VHT在业务扩展过程中进行更新和收缩。这样，我们就可以将经常变化的表转移到强大的网关上，从而合理减少vSwitch的资源消耗，提高整体效率。

设计概述。我们根据长期的生产经验和作为云供应商的观察，继续迭代我们的 Achelous 设计。
ALM 是我们迈向超大规模 VPC 以支持数百万虚拟机的最新举措。如图 5 所示，ALM 需要对 Achelous 中的所有三个核心组件进行修改。 ALM的核心思想是将控制器从下发网络变更的繁重负担中解放出来，让vSwitch主动按需通过网关同步转发规则。

![](/img/2023-09-30-sigcomm2023-achelous/figure5.png)

据此，我们设计： 1）轻量级转发表，命名为转发缓存（FC）表，以提高存储效率； 2）按需转发规则同步机制，以实现更快的收敛。


### 4.2 具有层次结构数据包处理路径的轻量级转发表
- - -

轻量级转发表。我们引入了轻量级转发缓存（FC）表以实现高效的软件切换。 vSwitch 不依赖显式的 VRT/VHT 条目，而是利用从网关获知的紧凑的“目标 IP -> 下一跳”映射。
首先，基于IP的条目更加紧凑并且可以覆盖更大的流量，因为每个VM-VM对的多个流可以仅重用一个条目。


我们可以将不同端口号的流表条目减少到单个IP条目，在极端情况下这可能会减少65535倍的存储空间。其次，通过从基于流的表转向基于 IP 的表，我们解决了元组空间爆炸 (TSE) 攻击的漏洞，这是针对软件包分类器的拒绝服务攻击。

层次结构数据包处理路径。如图5所示，在解析VXLAN内部报头的数据包的目标IP后，后续的数据包处理遵循层次结构路径：


1）快速路径：快速路径与§2.3相同，作为与业务逻辑无关的高性能加速路径。快路径中不匹配的报文将被上调到慢路径；

2）慢速路径：慢速路径上原来的VHT和VRT（见§2.3）被FC替换，但ACL和QoS表仍然保留。

对于管理而言，慢速路径根据网关的需要更新FC表项，得到本地小表，只需要很小的存储空间。具体来说，慢速路径根据每个数据包的“Dst IP”查找FC。如果缓存未命中，数据包将被向上调用到网关 1○，并最终转发到目的地 2○。而命中 FC 的数据包将被重新注入到快速路径并直接路由 3○


Achelous 中的分层数据包处理设计简化了 vSwitch 内的转发表结构和数据包处理逻辑。通过利用网关存储和管理整套转发规则，vSwitch可以按需同步条目，从而显着减少每个vSwitch节点的存储开销。

这种设计方法还将 vSwitch 与复杂的路由逻辑解耦，从而提高转发性能、增强多功能性并简化维护。第773章。


### 4.3 按需转发规则同步机制
- - -

来自网关的主动流量驱动学习。除了在数据平面中的作用之外，我们架构中的网关还充当控制平面中的转发规则调度程序。 vSwitch 节点通过路由同步协议 (RSP)（我们内部设计的协议）从网关按需学习转发规则。

如图6所示，RSP有两种报文类型：请求报文和应答报文。请求报文包含流的五元组，应答报文包含相应请求的下一跳。

![](/img/2023-09-30-sigcomm2023-achelous/figure6.png)

vSwitch根据流量时长、吞吐量等因素决定是学习规则还是直接将流量发送到网关。当vSwitch需要学习规则时，它会构造RSP请求报文并发送给网关。然后网关解析请求，收集特定规则，并写入回复数据包。收到回复后，vSwitch 将相应的条目插入到转发缓存 (FC) 中。


同步频率。为了保证从网关学习到的vSwitch FC中已有表项的及时性，ALM采用了周期性更新的策略。


我们在 vSwitch 中创建了一个管理线程，每隔 50𝑚𝑠 遍历一次 FC 条目，用于检查每个条目的生命周期（上次更新与当前之间的间隔）是否超过某个阈值（例如 100𝑚𝑠）。如果生命周期超过阈值，vSwitch 会主动发送 RSP 请求 4○ 与网关进行数据协调。然后，vSwitch 根据来自网关 5○ 的 RSP 回复，在本地 FC 上执行适当的操作。


减少开销。为了减少网络中RSP数据包的数量，提高ALM的效率，我们在ALM中采用批处理设计。在vSwitch中，我们允许将多个查询请求封装到单个RSP数据包中。相应地，网关也可以实现批量处理，将多个响应封装在一个回复包中。我们在部署中验证了我们的设计，得到的结果是平均请求数据包长度约为 200 字节，RSP 的最大带宽份额 < 4%（参见第 7.1 节）。因此，与它为虚拟网络带来的更强大的功能相比，这种开销是可以接受的（例如，我们可以在必要时通过 RSP 协议协商租户连接的 MTU、加密功能和其他功能）。


## 5 弹性网络容量
- - -
在本节中，为了解决Achelous 2.0中的第二个挑战（参见§2.4），我们首先引入单主机内的纵向扩展方案，该方案在性能隔离的前提下提供弹性。接下来，我们在主机集群中展示我们的横向扩展方案。


### 5.1 主机内扩展
- - -


问题与目标。弹性带宽被广泛研究[22,27,32,34]，然而，仅监控带宽并不能满足弹性要求。例如，当虚拟机出现短连接突发时，虽然该虚拟机的带宽没有达到上级限制，但可能会消耗过多vSwitch的CPU资源。同一主机上的其他虚拟机无法获得足够的CPU资源，从而导致带宽下降和主机内隔离的破坏。因此，我们需要在主机内的虚拟机隔离的基础上提供弹性。


弹性和隔离。为了解决这个问题，我们提出了监控两个维度指标的信贷策略。第一个指标是虚拟机的BPS/PPS2，用𝑅𝐵表示，它直接限制了虚拟机的流量速率。第二个指标是 vSwitch 为 VM 传输流量所使用的 CPU 周期，用 𝑅𝐶 表示。这两个指标都为每个虚拟机提供了弹性和隔离性的系统保证。


主机上所有虚拟机的总带宽资源（CPU 资源）用 𝑅𝐵 𝑇 (𝑅𝐶 𝑇 ) 表示。 VM 的实际带宽资源（CPU 资源）使用情况用 𝑅𝐵 𝑣𝑚 (𝑅𝐶 𝑣𝑚 ) 表示。我们为每个虚拟机设置默认资源限制 𝑅𝐵 𝑏𝑎𝑠𝑒 和 𝑅𝐶 𝑏𝑎𝑠𝑒。此外，每个虚拟机都有自己的信用值 𝐶𝑟𝑒𝑑𝑖𝑡𝐵 和 𝐶𝑟𝑒𝑑𝑖𝑡𝐶 。 VM可以消耗或累积其信用值。例如，如果 𝑅𝐵 𝑣𝑚 < 𝑅𝐵 𝑏𝑎𝑠𝑒 ，在空闲状态下，vSwitch 将累积 𝐶𝑟𝑒𝑑𝑖𝑡𝐵 = 𝐶𝑟𝑒𝑑𝑖𝑡𝐵 + ( 𝑅𝐵 𝑏𝑎𝑠𝑒 − 𝑅𝐵 𝑣𝑚 ）用于虚拟机。如果 𝑅𝐵 𝑣𝑚 > 𝑅𝐵 𝑏𝑎𝑠𝑒 ，在突发状态下，vSwitch 将消耗 𝐶𝑟𝑒𝑑𝑖𝑡𝐵 = 𝐶𝑟𝑒𝑑𝑖𝑡𝐵 -( 𝑅𝐵 𝑣𝑚 −𝑅𝐵 𝑏𝑎𝑠𝑒 )×𝐶，其中 0 < 𝐶 ≤ 1 是 VM 的信用消耗率。我们将算法 1 的细节推迟到附录 A。

![](/img/2023-09-30-sigcomm2023-achelous/algorithm1.png)

与令牌桶法的比较。我们的信用算法优于带有被盗功能的令牌桶方法。首先，信用消耗有特定的上限，这是信用算法与令牌桶的重要区别之一。其次，信用算法的通信开销低于令牌桶方法，因为它不需要在信用桶之间交换信息。此外，我们的方法可以防御由于长时间大量资源占用而导致的隔离破坏，例如DDoS攻击。

### 5.2 主机间横向扩展
- - -

问题。单主机内的纵向扩展无法满足租户不断增长的服务扩展需求。因此，利用ECMP来横向扩展主机间的服务能力势在必行。然而，ECMP部署中的集中式网关将引入阻碍网络扩展的新瓶颈。为此，我们在每个 vSwitch 节点上设计了分布式 ECMP 机制，以提供无缝横向扩展


分布式 ECMP。在此机制中，虚拟机可以创建一系列绑定vNIC以实现VPC间的安全通信。如图7所示，Host1上的租户虚拟机创建了三个绑定vNIC，并将它们挂载到服务VPC的虚拟机中（参见“Middlebox”VPC的Host2、3和4上的虚拟机）。

![](/img/2023-09-30-sigcomm2023-achelous/figure7.png)

所有绑定 vNIC 共享一个主 IP 地址（图中的“192.168.1.2”）和相同的安全组。然后控制器将相应的 ECMP 路由条目发布到 Host1 上的 vSwitch 中。这确保租户虚拟机的数据包可以发送到“Middlebox”VPC 中相应的虚拟机进行处理。为了平滑扩展，如果“Middlebox”VPC 中的虚拟机资源耗尽，则会自动创建额外的虚拟机并使用绑定 vNIC 进行挂载。随后，使用其他 ECMP 条目更新源 vSwitch，从而将流量重定向到新添加的虚拟机。值得注意的是，每个虚拟机都能够安装来自不同 VPC 的多个绑定 vNIC。这使得“中间盒”VPC 中的虚拟机能够为来自不同 VPC 的大量虚拟机提供服务。

分布式 ECMP 机制通过确保每个源虚拟机都与一个 vSwitch 关联来消除潜在的瓶颈，从而有效地重新分配流量。这种方法显着增强了大流量需求服务的弹性能力。例如，阿里云的云防火墙可以通过在其单个 VPC 上公开绑定 vNIC 接口，为数百万租户提供安全检测服务。借助分布式 ECMP 机制提供的水平可扩展性，这些租户可以无缝地从增加的资源中受益，无需主动管理或调整中间盒可用性的变化.


比负载平衡有好处。尽管LB架构可以提供与分布式ECMP机制类似的功能，但它们通常需要更多的租户配置。例如，随着流量的增加，中心化的LB节点可能会成为瓶颈，需要进行横向扩展，这伴随着租户侧代理配置的变化。此外，LB架构不支持不同租户的单独安全组。假设多个租户使用同一个 LB 节点，但每个租户都需要特定的安全组，则在 LB 节点后面的 vSwitch 上手动配置这些网络要求是唯一的选择。相比之下，分布式ECMP机制通过统一配置bonding vNIC，可以实现网络配置的无缝同步，从而更容易实现企业服务的横向扩展。



分布式 ECMP 中的故障转移。为了防止租户 VPC 的大量遥测流量导致服务 VPC 中的虚拟机崩溃，我们利用集中管理节点在分布式 ECMP 中进行健康检查。如图7所示，管理节点定期遥测“Middlebox”虚拟机所在的vSwitch。然后管理节点维护全局状态并与源侧vSwitch同步。一旦vSwitch出现故障（例如Host4上的vSwitch），管理节点会通知源侧vSwitch更新相应的ECMP表（即删除ECMP表中的Host4表项），以避免丢包.


## 6 网络风险意识和实时迁移
- - -

在本节中，我们解决 Achelous 数据平面的最后一个挑战（参见第 2.4 节）。我们首先介绍网络风险意识方案。具体来说，我们探测主机内部和主机之间的网络链路连接，并向控制平面发出即将到来的网络风险的警报。然后，我们提出了用于故障恢复的无缝热迁移方案.

## 6.1 网络风险意识
- - -


问题与目标。由于物理网络探测不涉及虚拟网络堆栈，因此许多虚拟网络堆栈错误无法通过以前的物理遥测方法发现。然而，超大规模云中的异常网络事件是频繁且不可避免的。如果不能及时、适当地解决这些问题，可能会导致小故障升级为严重的网络拥塞或应用程序故障。为此，我们在Achelous上设计了链路健康检查模块，用于监控超大规模网络的状态，以主动感知故障并进行早期预警。本模块重点关注两种类型的网络风险：1）网络链路运行状况，包括 VM-vSwitch、vSwitch-vSwitch 和 vSwitch-gateway 链路； 2）虚拟网络设备状态信息，指示网络设备本身的运行状态。我们将两者的设计细节介绍如下

链接健康检查。如图8所示，VM-vSwitch健康检查和vSwitch-vSwtich健康检查分别是红色路径和蓝色路径。 VM-vSwitch 表示从 vSwitch 到主机中 VM 的链路。 

![](/img/2023-09-30-sigcomm2023-achelous/figure8.png)

vSwitch向虚拟机发送ARP请求，并获取虚拟机的ARP响应，以检查虚拟机的网络状态。 vSwitch-vSwitch 是从一个vSwitch 到其他主机上的vSwitch 的链路。监控控制器系统配置检查表（即IP地址）后，链路健康检查模块向检查表中的虚拟机发送健康检查报文。然后，链路运行状况监视器分析响应的延迟并向控制平面报告风险（例如，虚拟机故障和链路拥塞）。为了最大限度地减少健康检查数据包对数据平面的侵入，我们将健康检查频率设置为30𝑠以减少额外的开销。同时，Achelous以特定格式封装健康检查报文，仅转发给链路健康监控器.


设备状态健康检查。 Achelous除了检查链路的健康状态外，还检查虚拟网络设备的健康状态。首先，Achelous 监视设备的 CPU 负载和内存使用情况。同时，Achelous 监控网络性能，例如虚拟和物理网卡的丢包率。如果网络设备存在风险（例如CPU负载高、NIC掉线率高、内存耗尽），我们会将这些异常情况报告给控制器。然后，控制器将介入并启动故障恢复机制。健康检查机制让网络具有风险意识，改变潜在风险，主动干预风险


## 6.2 透明虚拟机热迁移
- - -

问题与目标。我们通过实时迁移来执行故障恢复。然而，传统的实时迁移机制[12]没有考虑状态流量连续性和租户无感知。为了解决这个挑战，我们首先引入四个属性来保证虚拟机热迁移过程中的流量连续性。然后，我们展示了 Achelous 中实时迁移方案的演变，以逐步满足这些特性。


VM 实时迁移的属性。如表1所示，故障恢复的实时缓解应满足以下属性： 1）低停机时间意味着实时迁移应实现持续的高吞吐量和毫秒级停机时间。秒级宕机无法满足超大规模场景需求； 2）无状态流是指我们应该快速重定向无状态流（例如UDP和ICMP）； 3）有状态流意味着迁移方案支持有状态流（例如TCP和NAT）以及流状态、会话信息甚至ACL安全组状态的自适应处理； 4）应用无感知是指迁移方案要适应各种应用，原生应用不需要感知迁移过程


VM 实时迁移方案。我们首先设计了一种流量重定向（TR）方案来转发无状态流量并满足低停机时间要求。为了扩展TR方案以确保无状态流的连续性，我们提出了会话重置（SR）方案。然而，SR方案需要修改VM中的客户端应用程序以响应热迁移期间的TCP重连接请求，这降低了厂商的服务兼容性和质量。最后，我们在 Achelous 中开发会话同步 (SS)，它可以按需同步必要的会话，并在迁移过程中保持连接状态。 SS 方案确保了本机应用程序无意识的状态流连续性。我们在图 9 中展示了所有这些方案。由于篇幅限制，我们将这些方案的实时迁移步骤详细推迟到附录 B。


我们的实时迁移方案只有几毫秒的停机时间。因此，Achelous 数据平面可以快速恢复无状态和有状态流，而无需了解本机客户端服务。基于健康监控和故障预警，我们可以将虚拟机平滑迁移到其他主机，避免可能发生的故障或快速从故障中恢复，极大提高了云网络的可靠性

## 7 评估
- - -

在本节中，我们首先介绍实际部署中的 ALM 性能。然后，我们评估弹性信用算法的有效性和鲁棒性。最后，我们测量实时迁移方案的停机时间和流程连续性。在我们的评估中，我们收集了阿里云部署 Achelous 的五个典型区域的数据。这些区域的规模从数百到数千万个实例不等

### 7.1 ALM 的有效性
- - -

编程时间。图 10 显示了 Achelous 在不同尺度区域的编程时间。我们可以看到：1）ALM 在我们的生产场景中具有较短的收敛时间。例如，在具有 106 个虚拟机的 VPC 下，平均编程时间为 1.334 秒，而基线编程网关模型为 28.5 秒，比 ALM 大 21.36 倍； 2）ALM具有更好的可扩展性。随着虚拟机数量从10个增加到106个，预编程网关模型的平均编程时间从2.61s变为28.50s，增加了10.9倍。然而，ALM 的平均编程时间从 1.03 秒增加到 1.33 秒，仅引入 0.3 秒。这表明Achelous有能力支持更高数量级的网络规模


ALM 流量和 FC 条目。图11展示了不同区域网络规模从数百Gbps到数十Tbps的ALM流量占比。我们可以看到： 1）ALM流量的比例非常低，不超过4%，对于低编程时间来说是可以接受的； 2）较小的节点Region 相关的路由规则较少，因此 Region 越小，ALM 流量比例越低。图 12 显示了典型区域 FC 表条目的 CDF。至于存储开销，使用 ALM 时，每个 vSwitch 的平均内存消耗为 1,900 个缓存条目。拥有 150 万虚拟机的 VPC 的 FC 存储峰值为 3,700，远小于 𝑂（𝑁 2）。我们可以发现ALM节省了95%以上的内存使用，并且几乎不需要额外的开销就解决了超大规模云网络的路由表存储问题。


### 7.2 弹性网络能力
- - -

弹性信用算法的效果。为了验证弹性信用算法的效果，我们在同一主机中设置了VM1和VM2的弹性网络实验，如图13和图14所示。我们将这两个VM中任意一个的基础带宽限制为1000 Mbps。分为三个阶段：1）在前 30 秒内，我们使用另一台主机上的两个 VM 分别向 VM1 和 VM2 发送稳定的 300 Mbps 流量。

两个VM的CPU消耗均为20%； 2) 之后，向VM1发送突发流（30s到60s）。我们观察到VM1可以短暂达到1500Mbps左右。然后，VM1 消耗所有信用并被抑制到 1000Mbps。 VM1的CPU消耗短时间内达到55%，随后回落至40%； 3）60秒后，我们向VM2发送小数据包，这将消耗更多的CPU资源，因此VM2的CPU利用率将达到60%。 VM2带宽可以达到1200Mbps，而基于CPU的弹性信用算法则可以抑制到1000Mbps。

VM1的CPU消耗短时间内达到55%，随后回落至40%； 3）60秒后，我们向VM2发送小数据包，这将消耗更多的CPU资源，因此VM2的CPU利用率将达到60%。 VM2带宽可以达到1200Mbps，而基于CPU的弹性信用算法则可以抑制到1000Mbps。因此，我们观察到vSwitch总是严格保证VM1分配的CPU资源至少为40%（在资源争用的情况下），因此可以保证VM1的带宽基本不变。

在实践中，我们的基于BPS+CPU的方法也可以通过消除资源竞争来保证延迟，99%的流量延迟在300𝜇s以内。自从我们部署此机制以来，如图 15 所示，遭受资源（CPU/带宽）争用的主机的平均数量减少了 86%。综上所述，我们的弹性信用算法采用基于BPS+CPU的方法，无论在简单还是复杂的VPC场景下都可以保证隔离性并具有较高的弹性性能。第777章

分布式ECMP机制的有效性。至于分布式ECMP机制，我们将其部署在所有生产云区域中。通过无缝横向扩展，我们实现了0.3秒内网络服务的扩展和收缩。基于这些技术，我们已经实现阿里云80%的网络中间件（如LB、NAT、VPN网关等）以网络功能虚拟化（NFV）的形式迁移到云上的虚拟机上。虚拟机内的这些中间盒为数百万租户提供了高级网络服务。

### 7.3 健康检查和热迁移的有效性
- - -
健康检查发现的异常情况。如第 6.1 节中所述，Achelous 可以检测链路故障和设备故障。通过健康检查的预警，Achelous可以提前让租户意识到可能发生的故障。表 2 说明 Achelous 有助于检测多类硬件故障（表 2 的第一部分）。其中，CPU异常是最常见的类型，因为很多虚拟设备都是基于CPU转发的（例如vSwitch、网关）。此外，Achelous 可以检测表 2 第二部分中的资源争用，这可能会导致 VM 网络抖动或性能下降。最后但并非最不重要的一点是，Achelous 的健康检查机制是可扩展的。未来我们可以添加更多的指标进行监控，以快速发现故障

实时迁移期间的停机时间。我们测量两种情况（ICMP 和 TCP）下的停机时间、迁移和重新连接之间的时间间隔。具体来说，我们首先顺序发送ICMP探测。我们统计迁移过程中丢失的数据包数量，从而计算停机时间。其次，我们在虚拟机之间创建 TCP 连接。我们通过检查 TCP 序列号来得出停机时间。图16展示了TR方案和传统无重定向方案的停机时间。我们观察到TR可以大大减少热迁移过程中的停机时间，TR 的停机时间为 400ms，在 ICMP 和 TCP 下分别比传统方法快 22.5 倍和 32.5 倍。

会话重置和会话同步的有效性。在图17中，如果应用程序具有自动重新连接功能（见绿线），它将在32秒（Linux系统中的默认值）内重新启动应用程序连接。否则（见红线），虚拟机热迁移过程中连接将会丢失。相比之下，我们的 TR+SR 仅引入 1 秒的停机时间。因此，我们的TR+SR可以成功减少应用程序重新连接之前的等待时间。在诸如目标虚拟机配置了 ACL 规则等场景中，该规则仅允许源虚拟机进入并拒绝任何其他虚拟机的流量。如图 18 所示，我们观察到由于新 vSwitch 中缺少 ACL 规则，TR+SR 下的连接被阻塞，导致流程无法继续。相比之下，我们的TR+SS方案使vSwitch能够同步会话；因此，连接不会被阻止。值得注意的是，该方案仅引入了约100𝑚𝑠的故障恢复延迟。我们的结论是，Achelous 实时迁移方案实用且低延迟，仅消耗几百毫秒，同时保证有状态流的连续性。



## 8 经验
- - -
Achelous 已在我们的超大规模 VPC 中部署多年，提高了阿里云网络的可服务性。即使面临网络规模不断扩大、突发流量和恶意攻击等不稳定的生产挑战，它仍然为租户提供了良好的体验，因此我们相信我们在正确的地方做正确的事情。除了论文中的设计之外，我们还积累了大量的云网络研发经验。现在我们想在本节中分享它们

### 8.1 部署问题
- - -

Achelous 中的设计可以用于硬件卸载架构吗？随着硬件卸载方法成为趋势，各大云厂商都部署了SmartNIC或基于CIPU的vSwitch（如[18]）来提高VM网络容量。但事实是，FPGA等非CPU硬件由于缺乏灵活性和迭代效率，无法独立实现云vSwitch的所有功能。所以对于Achelous来说，硬件扮演着加速缓存的角色（就像§2.3中提到的快速路径）。它的实现不会影响本文的协同设计。而且阿里巴巴近年来在硬件卸载加速方面的经验也证明了这些协同设计可以很好地服务于基于SoC的vSwitch。

Achelous 准备好在阿里云之外提供服务了吗？ Achelous 2.0 的主要创新致力于解决超大规模 VPC 的新挑战。需要注意的是，这些设计都不是基于阿里云专用的硬件平台或软件框架来实现的。这意味着所有这些设计基于简单的原理，可以在任何硬件和软件平台上轻松实现。我们相信，随着云计算市场的增长，其他中小型云供应商很快就会面临像我们一样规模的问题，他们将从我们的经验中受益。

### 8.2 得到教训
- - -

协同设计是云网络的趋势。由于摩尔定律失效，单个模块的过度设计很难获得良好的效益。硬件卸载并不意味着在复杂场景下始终提供稳定的高性能。因此，不同网络组件之间的协同设计对于更高质量的虚拟网络是必要的。以ALM机制（第4.1节）为例，在如此庞大且多变的网络中，如果没有网关、控制器和vSwitch的配合，就无法实现快速收敛。我们相信，在未来，协同设计（包括组件间和软硬件的协作）将发挥更加关键的作用，并且超越简单地堆叠资源所能实现的目标

除了性能之外，快速迭代和灵活性对于网络转发组件也至关重要。转发组件的迭代速度将直接决定我们能够以多快的速度支持租户的新需求并修复现有的错误。这些功能对于云基础设施的发展至关重要。但在实现过程中，我们需要兼顾架构设计的灵活性和高性能。在Achelous中，经过几年的迭代，我们采用了服务逻辑与加速路径解耦的设计。这使得我们能够在同一套业务逻辑下实现软件、硬件等不同架构的加速形式。这就是为什么本文的创新在 Achelous 2.0 中很容易实现。

## 9 相关工作
- - -

网络虚拟化一直是过去十年的研究热点。在数据平面方面，最流行的开源项目Open vSwitch[43]首先提出了快慢路径分离的设计。之后，提出了一系列性能优化方法，例如用户空间组件加速和硬件卸载方案[18,19,25,51]。对于控制平面，Google 提出了 B4 [26, 29]，Azure 提出了 VFP [17]，丰富了 SDN 理论。然而，随着云计算的发展逐渐进入新的阶段，单方面的优化已经无法支撑日益增长的租户需求。因此，Achelous提出了数据平面和控制平面的协同设计来支持hyperscsale VPC网络。我们将简要讨论与 Achelous 最相关的作品。


超大规模网络编程。预编程模型[31]是第一个用于软件定义网络编程的模型。然而，它的编程开销随着VPC的大小呈二次方增加，这对于我们的超大型集群来说是不可接受的。 Andromeda [14]和Zeta [54]结合了网关模型和按需模型的优点。但他们选择的流量粒度将使网关成为潜在的重击者，而且它也比 Achelous 更繁重，因为使用中心化节点来决定卸载策略。

弹性。关于网络带宽分配有许多经过深入研究的著作，例如[8,11,22,27,32,34,45]。然而，传统的带宽策略忽略了虚拟网络中多种资源的消耗。 Picnic[33]和[7]中的作者提到有必要为租户共享和分配网络专用CPU资源，但缺乏统一的系统管理。 Achelous对不同资源采用统一的资源分配算法，既保证了隔离性又适应了网络突发情况。另一方面，我们注意到目前还没有关于如何在虚拟网络中部署 ECMP 路由的工作。因此我们提出分布式ECMP机制来克服集中式部署的瓶颈，并为租户提供轻松横向扩展的能力

可靠性。对于故障遥测，有很多工作[10,20,21,23,24,47,50,56]致力于物理网络中的故障遥测，但由于它们中的大多数不能直接在虚拟网络中使用可变虚拟拓扑。因此，我们在 Achelous 中开发了一种虚拟网络遥测方法，以在租户感知之前感知故障并进行故障转移。对于实时迁移，大多数现有工作都集中在主机资源迁移，例如裸机云上的内存脏页[28]或SR-IOV网络设备[53]。凯等人[30]提出了一种多步迁移过程来减少停机时间并确保迁移过程中的流量连续性，但无法解决有状态流的连续性。在Achelous中，采用“TR+SS”机制的热迁移保证了租户有状态服务的不中断。

## 9 相关工作
- - -

随着云计算需求的不断增长，云供应商需要在单个VPC中托管数百万个实例。因此网络配置的快速收敛、高弹性、高可靠性变得极具挑战性。为此，我们提出了 Achelous，它为阿里云中的超大规模 VPC 提供多年的高可服务性。在Achelous中，我们详细展示了它通过ALM机制、弹性网络容量策略、分布式ECMP机制和网络故障避免方案来实现这一目标。与数据平面上现有的经过充分研究的设计相比，Achelous 开辟了一些关于确保云网络可服务性的令人兴奋的研究方向，我们认为这是云供应商成功的关键指标。 Achelous 不依赖任何定制硬件，因此其他中小型云供应商可以从我们的设计和本文介绍的部署经验中受益。这项工作不会引起任何道德问题

## 致谢
- - -

我们衷心感谢所有匿名审稿人提出的宝贵意见和建设性建议。该工作得到中央高校基本科研业务费专项资金226-2022-00151、阿里云创新研究计划、浙江省科技计划（2022C01044）、浙江省博士后科研项目资助省（ZJ2022072），该研究还得到了杭州城市大学超级计算中心提供的先进计算资源的支持。第779章



## 参考
- - -
* [Achelous：Enabling Programmability, Elasticity, and Reliability in Hyperscale Cloud Networks](https://conferences.sigcomm.org/sigcomm/2023/program.html)

## 公众号：Flowlet
- - -

<img src="/img/qrcode_flowlet.jpg" width = 30% height = 30% alt="Flowlet" align=center/>

- - -