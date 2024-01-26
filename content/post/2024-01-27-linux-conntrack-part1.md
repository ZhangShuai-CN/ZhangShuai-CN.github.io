---
layout:     post
title:      "Linux 连接跟踪（conntrack）- Part 1：CT 系统概述 [译]"
subtitle:   "Linux Connection tracking - Part 1: CT System's Overview"
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

Linux 连接跟踪子系统（Linux Conntrack）是实现带状态的包过滤与 NAT 功能的基础，一般工作中我们都将 Linux Conntrack 称之为 “CT”。此前也有很多关于 Linux Conntrack 的文章介绍，但这些文章都是基于较老的 kernel 版本进行讲解，内容有点过时了。本文基于 Linux kernel 5.10 LTS 对 Conntrack 的底层运作方式进行详细介绍。

本文翻译自系列文章 [Connection tracking (conntrack)](https://thermalcircle.de/doku.php?id=blog:linux:connection_tracking_1_modules_and_hooks)，由于该系列文章篇幅过长，笔者打算分为以下三篇内容进行讲解：

* 第一部分：CT 系统（CT System's）概述，详细说明了 CT 系统与 Netfilter 和 Nftables 等其他内核组件的关系。
* 第二部分：CT 系统（CT System's）底层实现，详细说明了连接跟踪表（conntrack table）、连接查找和连接生命周期管理是如何工作的。
* 第三部分：如何通过 IPtables/Nftables 分析和跟踪连接状态，并通过 ICMP、UDP 和 TCP 等一些常见协议示例进行说明。

## 前言
- - -

由于译者水平有限，本文不免存在遗漏或错误之处。如有疑问，请查阅原文。

## 1. 概述
- - -

Conntrack 有什么作用？当 Linux 一旦激活连接跟踪，CT 系统就会检查 IPv4/IPv6 报文及其 payload，以确定哪些报文之间彼此关联。CT 系统并不参与端到端通信，而是透明的执行观测检查。一条连接的端点是本地还是远端都与 CT 系统无关。当端点位于远程主机上时，CT 系统仅在路由或桥接该报文的主机上进行观测。CT 系统维护其所有跟踪的连接实时列表。CT 系统为每个报文提供一个到其连接跟踪实例的引用（指针），在报文经过内核协议栈的时候对报文进行“分类”。其他内核组件可以根据此引用访问该报文所关联的连接跟踪实例并据此做出处理决策。

Conntrack 最主要的应用是 NAT 子系统以及 Iptables 和 Nftables 的带状态包过滤/带状态包检测 (SPI：stateful packet inspection) 模块。CT 系统本身并不修改/操纵报文，因此 CT 系统一般不会主动丢包。在进行报文检查时主要检查报文的 3 层和 4 层信息，因此它能够跟踪 TCP、UDP、ICMP、ICMPv6、SCTP、DCCP 和 GRE 等连接。

CT 系统对“连接”的定义并不局限于面向连接的协议，例如，它将 ICMP echo-request 与 echo-reply (ping) 视为一条“连接”。CT 系统同时提供了一些扩展组件，可以将其连接跟踪能力扩展到应用层，例如，跟踪 FTP、TFTP、IRC、PPTP、SIP 等应用层协议，该能力是实现应用层网关的基础。

## 2. 模块自动加载
- - -

内核的实现细节很大程度上取决于内核的编译构建配置，本文以 Debian 系统为例进行讲解。

围绕 Netfilter 框架并在其之上构建的整个基础设施由大量相互独立的内核模块组成，模块与模块之间具有复杂的依赖关系。其中许多模块通常不需要管理员使用 modprobe 或 insmod 命令显式加载，它们会按需自动加载。为了实现模块按需自动加载，Netfilter 通过调用 auto loader 内核模块提供的 request_module() 函数来实现这一点。当该函数被调用时，它通过执行一个运行 modprobe (kmod) 命令的用户态进程来加载所请求的模块以及该模块所依赖的所有模块。

## 3. nft_ct 模块
- - -

CT 系统会按模块自动加载的方式按需加载。一些内核组件需要使用连接跟踪特性，并能够触发 CT 系统模块的自动加载。以 nft_ct 内核模块为例，它是 Nftables 的带状态包过滤模块。该模块为 Nftables 数据包匹配规则提供连接跟踪表达式（CONNTRACK EXPRESSIONS）；这些表达式始终以关键字 ct 开头，并且可以例如：用于根据数据包与 ct 系统连接跟踪的关系（ct state ...）来匹配数据包。让我们看一些例子。

```shell
nft add rule ip filter forward iif eth0 ct state new drop
nft add rule ip filter forward iif eth0 ct state established accept
```
> 图 1：示例，将带有 CONNTRACK EXPRESSIONS 的 Nftables 规则添加到名为forward的链中

第一个 Nftables 规则匹配在接口 eth0 上收到的转发的 IPv4 数据包，这些数据包代表新跟踪连接的第一个数据包（ct state new），例如TCP SYN 数据包，将丢弃它们。第二条规则匹配在接口 eth0 上收到的转发的 IPv4 数据包，这些数据包是已建立的连接（ct state established）的一部分，并接受这些数据包。第一次将包含 CONNTRACK EXPRESSION 的 Nftables 规则添加到规则集中时，这会按照上述方式触发 Nftables 内核模块 nft_ct 的自动加载。由于该模块的依赖关系（如图 2 所示），现在会自动加载一大堆模块，包括代表实际 ct 系统的模块 nf_conntrack，以及其他模块（如 nf_defrag_ipv4 和 nf_defrag_ipv6）。

```shell
nft_ct                  # Nftables ct expressions and statements
   nf_tables
      nfnetlink
   nf_conntrack         # ct system
      nf_defrag_ipv4    # IPv4 defragmentation
      nf_defrag_ipv6    # IPv6 defragmentation
      libcrc32c
```

> 图2：nft_ct 内核模块的依赖树


请注意，我在这里描述的只是 ct 系统可能加载的多种方式之一。正如我所说，有几个内核组件使用 ct 系统。但是，涉及自动加载器和模块依赖项的整体模式在所有情况下都应该相同。

## 4. 网络 namespace
- - -

加载并不一定会导致所有这些模块立即变为活动状态。这是一个需要理解的重要细节。与内核网络协议栈的许多其他部分一样，ct 系统 nf_conntrack 以及 nf_defrag_ipv4 和 nf_defrag_ipv6 模块的任务需要在每个网络 namespace 内独立执行。

> 快速回顾网络 namespace
>
> 通过网络 namespace，在每个网络 namesapce 内运行完全独立的网络协议栈。它们中的每一个都有自己的一组网络设备、设置和状态，例如 IP 地址、路由、邻居表、Netfilter hooks、Iptables/Nftables rulesets……，从而拥有自己的单独网络流量。默认情况下，启动后，仅存在名为“init_net”的默认网络 namesapce，并且所有网络都发生在该 namesapce 内，但可以在运行时随时添加或删除其他网络 namesapce。例如 Docker 和 LXC 等容器解决方案使用网络 namesapce为每个容器提供隔离的网络资源。

ct 系统被设计为仅在当前 namespace 中生效。在我们的示例中，这意味着在网络 namespace 中，Nftables 规则集至少包含一条 CONNTRACK EXPRESSION 规则。因此，一旦添加该类型的第一条规则，它将自动在某个网络命名空间中启用，并且一旦删除该类型的最后一条规则，它将自动在该网络命名空间中禁用。由于每个网络命名空间都有自己的网络流量，因此有自己的要跟踪的连接，因此 ct 系统必须能够清楚地区分它们。对于它检查的每个网络数据包和它跟踪的每个连接，必须清楚该数据包属于哪个网络命名空间。

## 5. Netfilter hooks
- - -

与 Iptables 和 Nftables 一样，ct 系统构建在 Netfilter 框架之上。它实现了钩子函数，以便能够观察网络数据包并将其注册到 Netfilter 钩子中。从鸟瞰图来看，图 3 所示的 Netfilter 数据流图。

![](/img/2024-01-27-linux-conntrack/figure3.png)

> 图 3：Netfilter 数据流图

该图中名为 conntrack 的块代表 ct 系统的钩子函数。虽然这可能提供了一个足够的模型，但在编写用于状态数据包过滤的 Iptables/Nftables 规则时需要记住，但实际的实现更为复杂。完全相同的 Netfilter 挂钩，如预路由、输入、转发、输出和后路由，都独立存在于每个网络命名空间中。因此，它们代表实际的“on”/“off”开关，以在网络命名空间内单独启用/禁用 ct 系统：ct 系统的钩子函数仅使用该特定网络命名空间的钩子进行注册/取消注册，其中应启用/禁用 CT 系统。因此，ct 系统只能“看到”它应该看到的网络命名空间的网络数据包。

## 6. nf_conntrack 模块
- - -

我们回到上面的例子，看一下ct系统本身的内核模块。当包含 CONNTRACK EXPRESSION 的第一个 Nftables 规则添加到当前网络命名空间的规则集中时，Nftables 代码会触发 nf_conntrack 内核模块的加载（如果尚未加载）。之后，Nftables 代码调用 nf_ct_netns_get()。该函数由刚刚加载的 nf_conntrack 模块提供。调用该函数时，它将 ct 系统的钩子函数注册到当前网络命名空间的 Netfilter 钩子上。图 1 所示的 Nftables 规则指定 ip 地址族。因此，在这种情况下，ct 系统会向注册图 4 中所示的 IPv4 Netfilter 挂钩四个挂钩函数。对于 ip6 地址族 ，ct 系统会向 IPv6 的 Netfilter 挂钩注册相同的四个挂钩函数。对于 inet 地址族 ，它将向 IPv4 和 IPv6 Netfilter 挂钩注册其挂钩函数。

![](/img/2024-01-27-linux-conntrack/figure4.png)

> 图 4：使用 Netfilter IPv4 hook 注册的四个 conntrack hook函数。请参阅 net/netfilter/nf_conntrack_proto.c

函数 nf_ct_netns_get() 的目的是注册 ct 系统的钩子函数，而函数 nf_ct_netns_put() 的目的是取消注册。这两个函数在内部都使用引用计数。这意味着在当前的网络 namespace 中，可能有一个，也可能有几个内核组件在某个时刻需要连接跟踪，从而调用 nf_ct_netns_get()。然而，该函数仅在第一次调用时注册 ct 钩子函数，连续调用时仅增加引用计数器。如果组件在某个时刻不再需要连接跟踪，它将调用 nf_ct_netns_put()，这会减少引用计数器。如果它达到零，nf_ct_netns_put() 取消注册 ct 挂钩函数。在我们的例子中，例如如果您删除当前命名空间中规则集中包含 CONNTRACK EXPRESSIONS 的所有 Nftables 规则，就会发生这种情况。这种机制确保 ct 系统确实只在需要时启用。

### 6.1 主要的ct钩子函数
- - -

图 4 中的 Prerouting 钩子和 Output 钩子中以优先级 -200 注册的两个钩子函数与图 3 中的官方 Netfilter 数据流图中所示的 conntrack 钩子函数完全相同。在内部，它们都做同样的事。由一些做一些略有不同的事情的外部函数包装，它们调用的主要函数是 nf_conntrack_in()。因此，两者之间的主要区别仅在于它们的位置，Prerouting hook 处理网络上接收的数据包，而 Output hook 处理该主机上生成的输出数据包。这两个可以被认为是 ct 系统的“主要”钩子函数，因为 ct 系统遍历网络数据包的大部分操作都发生在这些钩子函数内部，分析数据包并将其与连接跟踪关联起来，然后为这些数据包提供引用（指针）到连接跟踪实例。

### 6.2 help+confirm 钩子函数
- - -

在图 4 中的另外两个钩子函数在 Input 钩子和 Postrouting 钩子中以 MAX 优先级注册。优先级 MAX 表示可能的最高无符号整数值。具有此优先级的钩子函数将作为 Netfilter 钩子中的最后一个函数进行遍历，并且在它之后不能注册任何其他钩子函数。这里的这两个钩子函数没有在图3中显示，可以认为是一些内部的东西，在鸟瞰图上不值得一提。它们都对遍历数据包执行相同的操作。两者之间的唯一区别是它们在 Netfilter 钩子中的位置，这确保所有网络数据包，无论传入/传出/转发的数据包，在遍历所有其他钩子函数后，最后遍历其中一个 conntrak hook。在本系列文章中，我将它们称为 conntrack“help+confirm”钩子函数，暗示它们有两个独立的用途。一个是执行“helper”代码，这是一项高级功能，仅在某些特定用例中使用，我不会在第一篇文章的范围内讨论该主题。二是“confirm”新跟踪的连接；请参阅 __nf_conntrack_confirm()。

> 此处为内核 v5.10.19 中，两个提到的功能“helper”和“confirm”才组合存在于同一钩子函数中。不久前，两者仍然以单独的 ct 钩子函数的形式存在于 Input 和 Postrouting Netfilter 钩子中：优先级为 300 的“helper”钩子函数和优先级为 MAX 的“confirm”钩子函数。参见例如LTS 内核 v4.19。在从内核 v5.0 迁移到 v5.1 期间，它们已合并在此 git commit 中。

## 7. nf_defrag_ipv4/6 模块
- - -

如图2所示，nf_conntrack 模块依赖于nf_defrag_ipv4和nf_defrag_ipv6模块。它们会分别负责 IPv4 和 IPv6 分片重组。通常，分片重组应该发生在接收端，而不是在中间端点。然而，在这种情况下这是必要的。只有当连接的所有数据包都可以被识别并且没有数据包可以从 ct 系统的手指中溜走时，连接跟踪才能完成其工作。分片报文的问题在于，它们并不都包含识别它们并将其与跟踪的连接相关联所需的必要协议标头信息。

![](/img/2024-01-27-linux-conntrack/figure5.png)

> 图 5：使用 Netfilter IPv4 挂钩注册的 分片重组 hook 函数。请参阅 net/ipv4/netfilter/nf_defrag_ipv4.c5)。

与 ct 系统本身一样，这些碎片整理模块不会在模块加载时全局激活。它们分别提供函数 nf_defrag_ipv4_enable() 和 nf_defrag_ipv6_enable()，这些函数向 Netfilter 钩子注册自己的钩子函数。图 5 显示了 nf_defrag_ipv4 模块和 IPv4 Netfilter hook 点：该模块在内部提供函数 ipv4_conntrack_defrag() 来处理遍历网络数据包的分片重组。该函数被注册为带有 Netfilter Prerouting 钩子和 Netfilter Output 钩子的钩子函数。在这两个地方，它都以优先级 -400 注册，这确保数据包在遍历以优先级 -200 注册的 conntrack 挂钩函数之前遍历它。在注册 ct 系统的钩子函数之前，上一节中提到的 ct 系统函数 nf_ct_netns_get() 确实会分别调用 nf_defrag_ipv4_enable() 和/或其 IPv6 对应函数。因此，defrag 挂钩函数与 conntrack 挂钩函数一起注册。然而，这里没有实现引用计数，这意味着，一旦注册了这个钩子函数，它就会保持注册状态（直到有人显式删除/卸载内核模块）。

## 8. hook 概述
- - -

图 6 通过显示提到的 conntrack 和 defrag hook 函数以及众所周知的 Iptables 数据包过滤链来总结内容。为了完整起见，我还在此处显示了优先级值。这应该可以与您在图 3 中的官方 Netfilter 数据包流图像中看到的内容进行舒适的比较。

![](/img/2024-01-27-linux-conntrack/figure6.png)

> 图 6：Conntrack+Defrag 钩子函数，使用 IPv4 Netfilter 钩子注册的 Iptables 链

当然，当我创建该映像时，我面临着与官方映像的制作者相同的困境：当使用 Nftables 时（我想现在大多数人都这样做），您可以根据自己的喜好自由创建和命名您的表和基础链。但在这样的图像中，默认情况下不会留下太多可显示的内容。因此，显示旧的但众所周知的 Iptables 链似乎仍然是最务实的事情。图 6 所示的重要一点是，关于 defrag 和 conntrack 钩子函数的遍历，所有类型的数据包都会发生相同的情况，无论这些数据包是否由本地套接字接收，是否由本地套接字生成。套接字并在网络上发送出去，或者如果这些只是转发（路由）数据包：它们都首先遍历分片重组钩子函数之一，无论是Prerouting钩子还是Output 钩子中的函数。这确保了这些函数可以在 ct 系统看到潜在碎片之前对它们进行分片重组。之后，数据包遍历 raw 表的潜在 Iptables 链（如果存在/正在使用），然后遍历主要的 conntrack 挂钩函数之一（优先级为 -200 的函数）。之后遍历其他 Iptables 链，例如常用于数据包过滤的优先级为 0 的链。然后，作为最后一件事，数据包遍历 conntrack“help+confirm”挂钩函数之一。

## 9. 如何工作
- - -

现在我们最后来谈谈 ct 系统实际上是如何运行的，以及它对遍历其钩子函数的网络数据包做了什么。请注意，我在本节中描述的是基础知识，并未涵盖 ct 系统实际执行的所有操作。 ct 系统在central table中维护其正在跟踪的连接。每个跟踪的连接都由 struct nf_conn 的一个实例表示。该结构包含 ct 系统在跟踪连接时随着时间的推移学到的连接的所有必要细节。从 ct 系统的角度来看，遍历其主要钩子函数之一（优先级为 -200 的函数）的每个网络数据包都是以下四种可能情况之一：

1. 它是其跟踪连接之一的一部分或与其相关。
2. 这是尚未跟踪的连接中第一个看到的数据包。
3. 这是一个无效的数据包，已损坏或无法装入。
4. 它被标记为 NOTRACK，告诉 ct 系统忽略它。

让我们看一下传入网络数据包的每一种可能性。我的意思是在网络接口上接收到的数据包，该数据包穿过 Netfilter Prerouting 和Input hook 点，然后由本地套接字接收。正如上一节所指出的，ct 系统在这里所做的也适用于outgoing或forwarded的网络数据包。因此，不需要针对这些类型的数据包提供额外的示例。

![](/img/2024-01-27-linux-conntrack/figure7.png)


> 图 7：网络数据包在 Prerouting hook 中遍历 ct 主钩子函数（优先级 -200），在central ct 表中查找发现数据包属于已跟踪的连接，数据包被赋予指向该连接的指针。

图 7 显示了第一种可能性的示例，传入数据包是已跟踪连接的一部分。当该数据包遍历主 conntrack 挂钩函数（优先级为 -200 的函数）时，ct 系统首先对其执行一些初始有效性检查。如果数据包通过了这些连接，ct 系统就会查找其 central 表以找到可能匹配的连接。在这种情况下，会找到匹配项，并向数据包提供指向匹配的跟踪连接实例的指针。为此，每个数据包的 skb6 拥有成员变量 _nfct。这意味着网络数据包被 ct 系统“标记”或“分类”。此外，现在正在分析数据包的 OSI 第 4 层协议，并将最新协议状态和详细信息保存到其跟踪的连接实例中。然后数据包继续通过其他钩子函数和网络协议栈。其他内核组件（例如具有 CONNTRACK EXPRESSION 规则的 Nftables）现在无需进一步查找 ct 表即可通过简单地**解引用** skb->_nfct 指针来获取有关数据包的连接信息。图 7 中以 Prerouting hook 中优先级为 0 的 Nftables 链示例的形式显示了这一点。如果您要在该链中建立一条带有表达式 ct state established 的规则，则该规则将匹配。数据包在被本地套接字接收之前遍历的最后一件事是 Input Hook 点中的 conntrack“help+confirm”挂钩函数。这里的数据包没有任何反应。该钩子函数是针对其他情况的。

![](/img/2024-01-27-linux-conntrack/figure8.png)

> 图 8：数据包遍历 ct 主钩子函数（优先级 -200），在中央 ct 表中查找未找到匹配项，数据包被视为新连接的第一个，创建新连接并向数据包提供指向它的指针，新连接稍后“confirmed”并添加到“help+confirm”挂钩函数中的 ct 表中（优先级 MAX）。

图 8 显示了第二种可能性的示例，传入数据包是第一个数据包，代表 ct 系统尚未跟踪的新连接。当该数据包遍历主 conntrack 挂钩函数（优先级为 -200 的函数）时，我们假设它通过了已经提到的有效性检查。然而，在这种情况下，在 ct 表 (1) 中查找没有找到匹配的连接。因此，ct 系统认为该数据包是新连接的第一个数据包。创建 struct nf_conn 的新实例 (2)，并且数据包的成员 skb->_nfct 被初始化以指向该实例。 ct 系统此时将新连接视为“unconfirmed”。因此，新的连接实例尚未添加到 central 表中。暂时停放在所谓的unconfirmed list 未确认名单上。此外，现在正在分析数据包的 OSI 第 4 层协议，并将协议状态和详细信息保存到其跟踪的连接实例中。然后数据包继续通过其他钩子函数和网络协议栈。图 8 还显示了 Prerouting hook 中优先级为 0 的 Nftables 链示例。如果您将带有表达式 ct state new 的规则放置在该链中，它将匹配。数据包在被本地套接字接收之前遍历的最后一件事是 Input 挂钩中的 conntrack“help+confirm”挂钩函数。该函数的工作是“confirm”新连接，这意味着相应地设置状态位并将连接实例从未确认列表移动到实际的 ct 表 (3)。这种行为背后的想法是，像这样的数据包可能会在主 conntrack 钩子函数和 conntrack“help+confirm”钩子函数之间的某个地方被丢弃，例如通过 Nftables 规则、路由系统或任何人……这个想法是为了防止“未经确认的”新连接弄乱中央 ct 表或消耗不必要的大量 CPU 资源。一个非常常见的情况是，例如存在像 iif eth0 ct state new drop 这样的 Nftables 规则，以防止新连接进入接口 eth0。当然，与此匹配的连接尝试应该被丢弃，同时消耗尽可能少的 CPU 功率，并且根本不应该出现在 ct 表中。在这种情况下，第一个这样的连接数据包将在 Nftables 链中被丢弃，并且永远不会到达 conntrack“help+confirm”钩子函数。因此，新的连接实例将永远不会被确认并在未确认列表中过早死亡。换句话说，它会与丢弃的网络数据包一起被删除。当您考虑有人进行端口扫描或 TCP SYN 泛洪攻击时，这一点尤其有意义。但即使是一个正在尝试建立例如的客户一个通过发送 TCP SYN 数据包的 TCP 连接表现正常，如果没有收到对端的任何回复，它仍然会发送几个 TCP SYN 数据包作为重传。因此，如果您设置了 ct 状态新丢弃规则，则此机制可确保 ct 系统故意不记住此（denied!）连接，从而将所有后续 TCP SYN 数据包（重传）再次视为新数据包，然后再将其视为新数据包。将被相同的ct状态新掉落规则掉落。

第三种可能是ct系统认为数据包无效。这例如当数据包未通过图 7 或 8 中 Prerouting hook 中主 conntrack hook 函数的初始有效性检查时，就会发生这种情况，例如由于无法解析的损坏或不完整的协议标头。当数据包无法对其 OSI 第 4 层协议进行详细分析时，还会发生这种情况。例如。在 TCP 的情况下，ct 系统会观察接收窗口和序列号，并且序列号不匹配的数据包将被视为无效。然而，丢弃无效数据包并不是 ct 系统的工作9)。 ct 系统将这个决定留给内核网络堆栈的其他部分。如果 ct 系统认为数据包无效，则简单地保留 skb->_nfct=NULL。如果您将表达式 ct state invalid 的 Nftables 规则放置在图 7 或 8 中的示例链中，则该规则将匹配。

第四种可能性是其他内核组件（如 Nftables）用“不跟踪”位（10）标记数据包的方法，告诉 ct 系统忽略它们。为了与 Nftables 一起使用，您需要创建一个优先级小于 -200（例如 -300）的链，这确保它在主 ct 钩子函数之前被遍历，并在该链中放置一个带有 notrack 语句的规则；请参阅 Nftables 维基。如果您随后将表达式 ct state untracked 的 Nftables 规则放置在图 7 或 8 中的示例链中，则该规则将匹配。这是一个极端案例主题，我不会在本文范围内讨论更多细节。

## 10. 连接生命周期
- - -
![](/img/2024-01-27-linux-conntrack/figure9.png)

> 图 9：被跟踪的连接实例的生命周期

图 9 总结了跟踪连接从创建到删除的通常生命周期。在按照上面各节所述进行分配和初始化之后，新连接首先被添加到未确认列表中。如果触发其创建的网络数据包在到达 ct 系统的 help+confirm 挂钩函数之前被丢弃，则该连接将从列表中删除并删除。然而，如果数据包通过了 help+confirm 挂钩函数，则连接将移至中央 ct 表并被标记为“已确认”。它会一直保留在那里，直到该连接被视为“过期”。这是通过超时处理的。简而言之……如果在一定时间内没有进一步的网络数据包到达所跟踪的连接，则该连接将被视为“过期”。定义该时间量的实际超时值很大程度上取决于该连接的网络协议、状态和流量行为。一旦“过期”，连接就会被移至死亡列表，并被标记为“死亡”。之后，它终于被删除了。

> 当使用 conntrack 用户空间工具列出所有当前跟踪的连接时，您可以观察超时情况11)。每行输出的第三列显示该连接到期之前的当前秒数。这就像倒计时（在下面的示例中为 431998 秒）：

conntrack -L
tcp      6 431998 ESTABLISHED src=192.168.2.100 ...
...

还值得一提的是，虽然整个系统只存在一个中央 ct 表，但每个网络命名空间和每个 CPU 核心都存在单独的未确认列表和死亡列表实例。




## 2. CT 示例
- - -

## 3. CT 示例
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