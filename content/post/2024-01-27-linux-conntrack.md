---
layout:     post
title:      "Linux 连接跟踪（conntrack）[译]"
subtitle:   "Linux Connection tracking"
description: "Linux Connection tracking (conntrack)"
excerpt: ""
date:       2024-01-27 01:01:01
author:     "张帅"
image: "/img/2024-01-27-linux-conntrack/background.jpg"
showtoc: true
draft: true
tags:
    - Conntrack
categories: [ Tech ]
URL: "/2024/01/27/linux-conntrack/"
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

本文翻译自系列文章 [Connection tracking (conntrack)](https://thermalcircle.de/doku.php?id=blog:linux:connection_tracking_1_modules_and_hooks)，原文共分为三篇，笔者将三篇合为一篇进行讲解，本文主要分为以下三个章节：

* 第一部分：CT 系统（CT System's）概述，详细说明了 CT 系统与 Netfilter 和 Nftables 等其他内核组件的关系。
* 第二部分：CT 系统（CT System's）底层实现，详细说明了连接跟踪表（conntrack table）、连接查找和连接生命周期管理是如何工作的。
* 第三部分：如何通过 IPtables/Nftables 分析和跟踪连接状态，并通过 ICMP、UDP 和 TCP 等一些常见协议示例进行说明。

## 前言
- - -

由于译者水平有限，本文不免存在遗漏或错误之处。如有疑问，请查阅原文。

## 0. 概览
- - -

Conntrack 有什么作用？当 Linux 一旦激活连接跟踪，CT 系统就会检查 IPv4/IPv6 报文及其 payload，以确定哪些报文之间彼此关联。CT 系统并不参与端到端通信，而是透明的执行观测检查。一条连接的端点是本地还是远端都与 CT 系统无关。当端点位于远程主机上时，CT 系统仅在路由或桥接该报文的主机上进行观测。CT 系统维护其所有跟踪的连接实时列表。CT 系统为每个报文提供一个到其连接跟踪实例的引用（指针），在报文经过内核协议栈的时候对报文进行“分类”。其他内核组件可以根据此引用访问该报文所关联的连接跟踪实例并据此做出处理决策。

Conntrack 最主要的应用是 NAT 子系统以及 Iptables 和 Nftables 的带状态包过滤/带状态包检测 (SPI：stateful packet inspection) 模块。CT 系统本身并不修改/操纵报文，因此 CT 系统一般不会主动丢包。在进行报文检查时主要检查报文的 3 层和 4 层信息，因此它能够跟踪 TCP、UDP、ICMP、ICMPv6、SCTP、DCCP 和 GRE 等连接。

CT 系统对“连接”的定义并不局限于面向连接的协议，例如，它将 ICMP echo-request 与 echo-reply (ping) 视为一条“连接”。CT 系统同时提供了一些扩展组件，可以将其连接跟踪能力扩展到应用层，例如，跟踪 FTP、TFTP、IRC、PPTP、SIP 等应用层协议，该能力是实现应用层网关的基础。

## 1. CT 系统（CT System's）概述
- - -

### 1.1 模块自动加载
- - -

内核的实现细节很大程度上取决于内核的编译构建配置，本文以 Debian 系统为例进行讲解。

围绕 Netfilter 框架并在其之上构建的整个基础设施由大量相互独立的内核模块组成，模块与模块之间具有复杂的依赖关系。其中许多模块通常不需要管理员使用 modprobe 或 insmod 命令显式加载，它们会按需自动加载。为了实现模块按需自动加载，Netfilter 通过调用 auto loader 内核模块提供的 request_module() 函数来实现这一点。当该函数被调用时，它通过执行一个运行 modprobe (kmod) 命令的用户态进程来加载所请求的模块以及该模块所依赖的所有模块。

### 1.2 nft_ct 模块
- - -

CT 系统会按模块自动加载的方式按需加载。一些内核组件需要使用连接跟踪特性，并能够触发 CT 系统模块的自动加载。以 nft_ct 内核模块为例，它是 Nftables 的带状态包过滤模块。该模块为 Nftables 提供基于连接跟踪表达式（CONNTRACK EXPRESSIONS）的报文匹配规则；这些表达式以 ct 关键字作为开头，并且可以根据 ct 的状态（ct state ...）来匹配报文。

```shell
nft add rule ip filter forward iif eth0 ct state new drop
nft add rule ip filter forward iif eth0 ct state established accept
```
> 图 1.1：示例，将基于连接跟踪表达式（CONNTRACK EXPRESSIONS）的 Nftables 规则添加到 forward 链中

第一条 Nftables 规则：匹配在 eth0 接口上收到进行 IPv4 转发的一条新的连接跟踪（ct state new）的第一个报文，比如，TCP SYN 包，该规则将对其进行丢弃。
第二条 Nftables 规则：匹配在 eth0 接口上收到进行 IPv4 转发的已建立连接跟踪（ct state established）的报文，该规则将接收该报文。

在第一次将包含连接跟踪表达式（CONNTRACK EXPRESSIONS）的 Nftables 规则添加到规则集时，会触发 nft_ct 内核模块自动加载。该模块的依赖关系如图 1.2 所示，因此会自动加载一大堆其所依赖的模块，包括代表实际 ct 系统的 nf_conntrack 模块，以及 nf_defrag_ipv4/nf_defrag_ipv6 等其他模块。

```shell
nft_ct                  # Nftables ct expressions and statements
   nf_tables
      nfnetlink
   nf_conntrack         # ct system
      nf_defrag_ipv4    # IPv4 defragmentation
      nf_defrag_ipv6    # IPv6 defragmentation
      libcrc32c
```

> 图 1.2：nft_ct 内核模块的依赖树

### 1.3 网络命名空间（Network Namespace）
- - -

这些模块加载后并不会导致所有模块立刻被激活。与内核网络协议栈的许多其他部分一样，ct 系统 nf_conntrack 以及 nf_defrag_ipv4/nf_defrag_ipv6 模块在每个网络命名空间内独立执行。

> 网络命名空间
>
> 每个网络命名空间运行完全独立的网络协议栈，每个网络命名空间都有一组自己的网络设备、独立的网络配置和设备状态，例如 IP 地址、路由、邻居表、Netfilter hook 点、Iptables/Nftables rulesets 等，因此，每个网络命名空间都拥有自己独立的网络流量。默认情况下，系统启动后，仅存在名为 “init_net” 的默认网络命名空间，并且所有网络都发生在该网络命名空间内。可以在运行时添加或删除其他网络命名空间，例如 Docker 和 LXC 等容器解决方案使用网络命名空间为每个容器提供隔离的网络资源。

ct 系统被设计为仅在当前网络命名空间中生效。

### 1.4 Netfilter hook 点
- - -

与 Iptables 和 Nftables 一样，ct 系统基于 Netfilter 框架进行构建。ct 系统将能够观测网络报文的钩子函数，注册到 Netfilter hook 点上。Netfilter 数据流图如图 1.3 所示：

![](/img/2024-01-27-linux-conntrack/figure1.3.png)

> 图 1.3：Netfilter 数据流图

图中名为 conntrack 的方块代表 ct 系统的钩子函数。每个独立的网络命名空间都有完全相同的 Netfilter hook 点，如：Prerouting, Input, Forward, Output 和 Postrouting。该 hook 点代表网络命名空间内 ct 系统的启用/禁用开关。因此，ct 系统只能“看到”自己所在网络命名空间上的报文。

### 1.5 nf_conntrack 模块
- - -

当第一条带有连接跟踪表达式（CONNTRACK EXPRESSION）的 Nftables 规则添加到当前网络命名空间的规则集（ruleset）中时，Nftables 代码会触发 nf_conntrack 内核模块被自动加载（如果该模块尚未加载）。随后，Nftables 代码调用 nf_ct_netns_get() 函数，该函数由刚刚加载的 nf_conntrack 内核模块提供（export）。当该函数被调用时，它将 ct 系统的钩子函数注册到当前网络命名空间的 Netfilter hook 点上。

图 1.1 所示的 Nftables 规则指定了 ip 地址族。因此，ct 系统会向图 1.4 所示的 IPv4 Netfilter hook 点注册四个钩子函数。对于 ip6 地址族，ct 系统会向 IPv6 的 Netfilter hook 点注册相同的四个挂钩函数。对于 inet 地址族，ct 系统会同时向 IPv4 和 IPv6 Netfilter hook 点注册其挂钩函数。

![](/img/2024-01-27-linux-conntrack/figure1.4.png)

> 图 1.4：四个 conntrack 钩子函数注册到 Netfilter IPv4 hook 点。具体代码请参阅 net/netfilter/nf_conntrack_proto.c

ct 系统使用 nf_ct_netns_get() 函数是注册钩子函数，通过使用 nf_ct_netns_put() 函数可以取消注册。如果在当前网络命名空间中，同时有几个内核组件都需要使用连接跟踪而调用 nf_ct_netns_get() 函数，nf_ct_netns_get()/nf_ct_netns_put() 通过在内部使用引用计数解决这个问题。

nf_ct_netns_get() 函数仅在第一次被调用时注册 ct 系统的钩子函数，当被连续调用时仅增加引用计数。如果某个内核组件在某个时刻不再需要使用连接跟踪，它通过调用 nf_ct_netns_put() 来减少引用计数。如果引用计数为零，nf_ct_netns_put() 则取消 ct 钩子函数注册。例如，如果当前网络命名空间规则集中包含跟踪表达式（CONNTRACK EXPRESSION）的所有 Nftables 规则被删除，就会发生这种情况。该机制确保 ct 系统只在需要时才被启用。

#### 1.5.1 主要的 ct 钩子函数
- - -

以 -200 优先级注册到图 1.4 Prerouting hook 点和 Output hook 点的两个钩子函数基本完全相同。在内部，它们都做差不多同样的事情。它们调用的主要函数是 nf_conntrack_in()，两者之间的主要区别仅在于 hook 点的位置，Prerouting hook 用于处理网络上接收的报文，而 Output hook 用于处理本地主机上产生的输出报文。这两个 hook 可以被认为是 ct 系统的“主要”钩子函数，ct 系统遍历网络数据包的大部分操作都发生在两个钩子函数内部，分析报文并将报文与其连接跟踪关联起来，然后为这些报文提供到连接跟踪实例的引用（指针）。

#### 1.5.2 help + confirm 钩子函数
- - -

另外两个钩子函数以 MAX 优先级注册到图 1.4 中的 Input 和 Postrouting hook 点。MAX 表示最高无符号整数，具有此优先级的钩子函数将作为 Netfilter hook 点中的最后一个函数进行遍历，并且在它之后不能注册任何其他钩子函数。

这两个钩子函数并没有在图 1.3 中体现，它们都对遍历的报文执行相同的操作。两者的唯一区别在于它们在 Netfilter hook 点中的位置不同，这确保了所有报文，无论是进入/输出/转发的报文，在遍历完所有其他钩子函数之后，最后都能遍历这两个钩子函数中的其中一个。

在本文中，我将其称为连接跟踪 “help+confirm” 钩子函数。一个是执行 “helper” 代码，这是一项高级功能，仅在某些特定用例中使用。二是 “confirm” 新跟踪的连接，具体代码请参阅 __nf_conntrack_confirm() 函数，后面我们会对其进行详细说明。

> 在 v5.10.19 内核中 “helper” 和 “confirm” 组合存在于同一钩子函数中。在 v4.19 LTS 内核中，优先级为 300 的 “helper” 钩子函数和优先级为 MAX 的 “confirm” 钩子函数以单独的 ct 钩子函数的形式存在于 Netfilter Input 和 Postrouting hook 点

### 1.6 nf_defrag_ipv4/6 模块
- - -

如图 1.2 所示，nf_conntrack 模块依赖于 nf_defrag_ipv4 和 nf_defrag_ipv6 模块。这两个模块分别负责 IPv4 和 IPv6 报文的分片重组。通常情况下，应该在接收端而不是在中间节点进行分片重组。正常情况下，只有当一条连接的所有报文都能够被识别时，连接跟踪才能正常工作。然而对于分片报文，分片报文并不都包含识别它们所需的必要协议头信息。

![](/img/2024-01-27-linux-conntrack/figure1.5.png)

> 图 1.5：分片重组钩子函数注册到 Netfilter IPv4 hook 点。具体代码请参阅 net/ipv4/netfilter/nf_defrag_ipv4.c

与 ct 系统本身类似，分片重组模块不会在模块加载时直接全局启用。它们对外提供 nf_defrag_ipv4_enable() 和 nf_defrag_ipv6_enable() 函数，通过调用这些函数向 Netfilter hook 点注册分片重组钩子。

图 1.5 展示了 nf_defrag_ipv4 分片重组模块及对应的 Netfilter IPv4 hook 点：
该模块内部通过 ipv4_conntrack_defrag() 函数来进行网络报文的分片重组。该函数以 -400 的优先级注册为 Netfilter Prerouting 和 Netfilter Output hook 点的钩子函数。以确保报文在遍历 -200 优先级注册的 conntrack 钩子函数之前遍历它。

在注册 ct 系统自身的钩子函数之前，ct 系统会调用 nf_ct_netns_get() 函数，该函数会分别调用 nf_defrag_ipv4_enable() 函数或其对应的 IPv6 函数。因此，defrag 钩子函数与 conntrack 钩子函数一起被注册。defrag 钩子函数没有引用计数，一旦注册了该钩子函数，它就会一直保持注册状态（直到有人显式的删除/卸载该内核模块）。

### 1.7 hook 点概述
- - -

图 1.6 通过前面提到的 conntrack 和 defrag 钩子函数以及 Iptables 链来进行总结。

![](/img/2024-01-27-linux-conntrack/figure1.6.png)

> 图 1.6：Conntrack + Defrag 钩子函数，以及注册到 IPv4 Netfilter hook 点的 Iptables 链

如图 1.6 所示，所有类型的报文（由本地套接字接收/本地套接字生成/转发）：它们都会首先遍历 Prerouting 或 Output 这个两个 hook 点的分片重组钩子函数中的其中一个。这就保证了在 ct 系统看到分片报文之前对其进行分片重组。随后，报文遍历 raw 表的 Iptables 链（如果存在/正在使用），然后遍历 conntrack 主要的钩子函数（优先级为 -200 的钩子函数），之后遍历其他 Iptables 链，例如：常用于报文过滤的优先级为 0 的链。最后，报文遍历 conntrack “help + confirm” 钩子函数中的其中一个。

### 1.8 CT 系统是如何工作的
- - -

ct 系统在 central table 中维护其正在跟踪的连接，每个跟踪的连接都由一个 struct nf_conn 的实例表示。该结构包含 ct 系统在跟踪观测连接时学到的所有必要细节。从 ct 系统的角度来看，每个遍历其主要钩子函数（优先级为 -200 的钩子函数）的报文都会出现以下可能的四种情况：

 - 1. 该报文是其跟踪连接的一部分或与其相关。
 - 2. 该报文是尚未跟踪连接的第一个包。
 - 3. 该报文是一个无效报文（已损坏或其他原因）。
 - 4. 该报文被标记为 NOTRACK，ct 系统将会忽略该报文。

我们以从接口上收到一个报文，该数据包穿过 Netfilter Prerouting 和 Input hook 点，然后由本地套接字接收为例。

![](/img/2024-01-27-linux-conntrack/figure1.7.png)


> 图 1.7：报文在 Prerouting hook 点中遍历 ct 主要钩子函数（优先级 -200），在 central ct 表中查找发现报文属于已跟踪的连接，报文被赋予指向该连接实例的指针。

**第一种可能：**

如图 1.7 所示，传入的报文是已跟踪连接的一部分。当该报文遍历 conntrack 主要钩子函数（优先级为 -200 的钩子函数）时，ct 系统首先对其执行初始有效性检查。如果报文通过了该检查，ct 系统就会查找 central 表以找到可能匹配的连接。在本示例的场景下，会找到匹配项，并向数据包提供指向匹配的连接跟踪实例的指针。每个报文的 skb 拥有一个 _nfct 成员变量，这意味着报文被 ct 系统进行“标记”或“分类”。此外，ct 系统将会分析报文的 4 层协议信息，并将最新的协议状态及详细信息保存到其连接跟踪实例中。

然后报文将继续通过其他钩子函数和网络协议栈。其他内核组件（例如，具有连接跟踪表达式（CONNTRACK EXPRESSION）规则的 Nftables）现在无需进一步查找 ct 表即可通过简单地**解引用** skb->_nfct 指针就可获取有关报文的连接信息。

图 1.7 中，优先级为 0 的 Nftables 链挂载在 Prerouting hook 点，如果在该链中创建一条带有 `ct state established` 表达式的规则，该规则将会被匹配。报文在被本地套接字接收之前，最后一件事就是遍历 Input Hook 点中的 conntrack “help + confirm” 钩子函数。在本例中，该函数不会有任何操作，该钩子函数主要是针对其他特殊情况的。

![](/img/2024-01-27-linux-conntrack/figure1.8.png)

> 图 1.8：报文遍历 ct 主要钩子函数（优先级 -200），在 central ct 表中未找到匹配项，报文被视为新连接的第一个数据包，创建新连接并向报文提供指向它的指针，新连接将在稍后被 “confirmed” 并将 “help + confirm” 钩子函数（优先级 MAX）添加到 ct 表中。

**第二种可能：**

如图 1.8 所示，传入报文是 ct 系统尚未跟踪的新连接的第一个数据包。当该报文遍历 conntrack 主要钩子函数（优先级 -200）时，我们假设它已经通过了有效性检查，在 ct 表 (1) 中查找没有找到匹配的连接。因此，ct 系统认为该报文是新连接的第一个数据包。创建新的 struct nf_conn 实例 (2)，并将报文的 skb->_nfct 成员初始化为指向该实例的指针。

ct 系统此时将新连接视为 “unconfirmed”。因此，新的连接实例尚未添加到 central 表中，暂时存放在未确认列表（unconfirmed list）上。此外，ct 系统将会分析报文的 4 层协议信息，并将协议状态和详细信息保存到其连接跟踪实例中。然后报文将继续通过其他钩子函数和网络协议栈。

图 1.8 中，优先级为 0 的 Nftables 链挂载在 Prerouting hook 点，如果在该链中创建一条带有 `ct state new` 表达式的规则，该规则将会被匹配。报文在被本地套接字接收之前，最后一件事就是遍历 Input Hook 点中的 conntrack “help + confirm” 钩子函数。该函数的工作是 “confirm” 新连接，该函数设置相应地状态位并将连接跟踪实例从未确认列表移动到实际的 ct 表 (3) 中。这么设计的原因是，报文可能会在 conntrack 主钩子函数和 conntrack “help + confirm” 钩子函数之间的某个地方被丢弃，例如，被 Nftables 规则、路由系统丢弃。同时也是为了防止 “unconfirmed” 新连接弄乱central ct 表及消耗大量不必要的 CPU 资源。

例如，存在 `iif eth0 ct state new drop` 这样的 Nftables 规则，用来防止新连接进入 eth0 接口。因此，与之匹配的连接应该被丢弃，该连接跟踪根本不会出现在 ct 表中。在此情况下，第一个连接报文将在 Nftables 链中被丢弃，并且永远不会到达 conntrack “help + confirm” 钩子函数。因此，新的连接实例将永远不会被确认并在未确认列表（unconfirmed list）中死亡。换句话说，新的连接实例将会与丢弃的报文一起被删除。这在有人进行端口扫描或发起 TCP SYN 泛洪攻击时，很有意义。

正常情况下 client 正在尝试通过发送 TCP SYN 报文建立 TCP 连接，如果没有收到对端的任何回复，它仍然会发送几个 TCP SYN 重传报文。如果您设置了 `ct state new drop` 规则，则此机制可确保 ct 系统（denied!）新的连接。

**第三种可能：**
如果 ct 系统认为报文无效。例如，当报文未通过图 7 或 8 中 Prerouting hook 点的 conntrack 主钩子函数的初始有效性检查。例如，由于无法解析损坏或不完整的协议头。当无法对报文的 4 层协议进行详细分析时，也会发生这种情况。例如，对于 TCP 报文，ct 系统会观察接收窗口和序列号，如果序列号不匹配则报文将被视为无效（丢弃无效报文并不是 ct 系统的工作，ct 系统将这个决定留给内核协议栈的其他模块）。如果 ct 系统认为报文无效，只是简单地将 skb->_nfct=NULL。如果您将 `ct state invalid` 的 Nftables 规则放置在图 1.7 或 1.8 中的示例链中，则该规则将会被匹配。

**第四种可能：**
其他内核组件（如 Nftables）通过 “do not track” bit 位标记报文，告诉 ct 系统忽略它们。为了与 Nftables 一起使用，您需要创建一个优先级小于 -200（例如 -300）的链，这确保它能在 ct 主钩子函数被遍历之前遍历，并在该链中添加一条带有 `notrack` 语句的规则。如果您将带有 `ct state untracked` 表达式的 Nftables 规则放置在图 1.7 或 1.8 中的示例链中，则该规则将会被匹配。

### 1.9 连接跟踪实例的生命周期
- - -
![](/img/2024-01-27-linux-conntrack/figure1.9.png)

> 图 1.9：连接跟踪实例的生命周期

图 1.9 展示了连接跟踪实例从创建到删除的生命周期。一个新的连接首先被添加到未确认列表（unconfirmed list）中。如果触发其创建的网络报文在到达 ct 系统的 help + confirm 钩子函数之前被丢弃，则该连接将从未确认列表（unconfirmed list）中被删除。如果报文通过了 help + confirm 钩子函数，则该连接将被移至 central ct 表中并被标记为 “confirmed”。这条连接将会一直存在，直到该连接超时被视为 “expired”。如果在一段时间内没有收到该连接跟踪新的网络报文，则该连接将被视为 “expired”。一旦“expired”，连接就会被移至死亡列表（dying list），并被标记为“dying”，在此之后将被删除。

> 可以通过 conntrack 命令列出所有连接跟踪实例，每行输出的第三列为该连接的到期时间。（以下示例中为 431998 秒）：

```shell
conntrack -L
tcp      6 431998 ESTABLISHED src=192.168.2.100 ...
...
```

整个系统只存在一个 central ct 表，但每个网络命名空间和每个 CPU 都有单独的未确认列表（unconfirmed list）和死亡列表（dying list）。

## 2. CT 系统（CT System's）底层实现
- - -

### 2.1 
- - -



## 3. CT 实战
- - -

### 3.1 
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