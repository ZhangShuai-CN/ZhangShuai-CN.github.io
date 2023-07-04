---
layout:     post
title:      "Netfilter 102：在 Linux bridge 上 ebtables 与 iptables 如何进行交互 [译]"
subtitle:   "在 Linux bridge 上 ebtables 与 iptables 如何进行交互"
description: "ebtables/iptables interaction on a Linux-based bridge"
excerpt: ""
date:       2023-04-10 11:23:01
author:     "张帅"
image: "/img/2023-04-10-ebtables-iptables-interaction/background.jpg"
showtoc: true
draft: false
tags:
    - netfilter
    - iptables
    - ebtables
    - br-nf
categories: [ Tech ]
URL: "/2023/04/10/ebtables-iptables-interaction/"
---

- - -
###### 关于作者
> 
> **`张帅，网络从业人员，公众号：Flowlet`**
> 
> **`个人博客：https://flowlet.net/`**
- - -

本文翻译自文章 [ebtables/iptables interaction on a Linux-based bridge](https://ebtables.netfilter.org/br_fw_ia/br_fw_ia.html)。

本文为译者根据原文意译，非逐词逐句翻译。由于译者水平有限，本文不免存在遗漏或错误之处。如有疑问，请查阅原文。

## 1. 介绍
- - -

本文档描述了在 Linux bridge 上 iptables 和 ebtables filter 表如何进行交互操作的。

Linux 从 2.6 的内核开始包含 ebtables 和 br-nf 的代码。br-nf 代码可以使链路层（L2） Bridge 中处理的数据包通过网络层（L3）iptables 的链。

ebtables 在链路层（L2）进行数据包过滤，而 iptables 只对 IP 数据包进行过滤。br-nf 代码有时会违反 TCP/IP 网络模型：例如在链路层内执行 IP DNAT 操作。

**术语**：
* 帧（frame）：是用于描述链路层的报文
* 分组（packet）：是用于描述网络层的报文。

但是，当我们谈论处在链路层内的 IP 数据包时，frame 与 packet 表达的含义相同。

## 2. 帧是如何遍历 ebtables 链的
- - -
> 本节只考虑 ebtables 不考虑 iptables
### 2.1 帧通用转发流程
- - -
![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge2a.png)

本小节我们只讨论链路层，数据包的目的 MAC 为 bridge，但 ip 地址不一定是 bridge 所在的计算机。

路由器的工作原理就是：路由器收到的数据报文中，目的 MAC 地址为路由器的 MAC 地址，目的 ip 地址为你真正想通信的目的设备的 ip 地址。

### 2.2 bridge hook 点
- - -
![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge2b.png)

Linux bridge 代码中定义了 6 个 hook 点，其中 BROUTING hook 点是专门为 ebtables 新增的。hook 点位于网络代码中的特定位置，其它软件可以将自己的代码绑定到该位置，从而处理通过该位置的数据包。

例如，内核模块负责将 ebtables 的 FORWARD 链绑定到 bridge 的 FORWARD hook 点。

请注意，ebtables 的 BROUTING 和 PREOUTING 链在网桥决策（bridge decision）之前已经被遍历，因此这些链会看到被 bridge 会忽略的数据包。此外，这些链不会看到进入非 bridge 桥接端口的数据包。

Bridge 维护一个转发数据库（Forwarding Data Base），包含端口号，以及在此端口上学习到的 MAC 地址等信息，用于数据转发（Forwarding）。

数据包根据报文的目的 MAC 查找 FDB 后，将会有以下转发行为之一：
* 报文的目的 MAC 在网桥的另一端口侧，则转发到该端口。
* 找不到对应的转发信息，则泛洪到网桥的所有端口。
* 报文的目的 MAC 为网桥本身的 MAC，则转发到更高的协议层（IP 层）进行处理。
* 报文的目的 MAC 与该数据包进入网桥的端口同侧，则忽略此报文。

### 2.3 ebtables 遍历过程
- - -
![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge2c.png)

如上图所示，ebtables 有 filter，nat 和 broute 3 张表，每张表都有各自的链：
* broute 表：拥有 BROUTING 链。
* filter 表：拥有 FORWARD、INPUT、OUTPUT 3 条链。
* nat 表：拥有 PREROUTING、OUTPUT、POSTROUTING 3 条链。

> filter 表和 nat 表的 OUTPUT 链是分离的，并拥有不同的用法。

上图清晰地给出了 ebtables 的链是如何关联到网桥的 hook 点的。

当被绑定到网桥上的网卡接收到数据帧时，数据帧会首先通过 BROUTING 链。在这个特殊的链，你可以选择通过路由转发此数据帧或通过网桥转发此数据帧，这时候网桥将成为一个 brouter。

> brouter：是（基于链路层信息）通过网桥转发一部分数据帧并能够（基于网络层信息）通过路由转发其他数据帧的设备。数据帧是被网桥转发还是被路由转发，取决于决策的配置信息。

例如，可以使用 brouter 充当 2 个网络之间 IP 流量互通的普通路由器，同时通过网桥转发这些网络之间的特定流量（NetBEUI，ARP 等）。IP 路由表不使用网桥逻辑设备，而是将 IP 地址分配给物理网络设备，这些物理网络设备也恰好是网桥端口（网桥绑定该网卡）。

BROUTING 链中的默认策略是网桥转发。

接下来，数据帧通过 PREROUTING 链。在此链中，你可以更改数据帧的目标 MAC 地址（MAC-DNAT）。如果数据帧通过了 PREROUTING 链，则网桥通过查看数据帧的目的 MAC 地址（它不关心网络层信息）来决定将数据帧的发送到哪。

### 2.4 本机接收数据帧的链遍历过程
- - -

![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge2d.png)

如果网桥通过决策后发现这个数据帧的目的地是本机，则该数据帧就会经过 INPUT 链。在 INPUT 链中，你可以过滤目的是 bridge 所在机器的数据帧。在遍历过 INPUT 链后，这个数据帧将会被上送到网络层（IP 相关的代码中）。

因此，一个被路由转发的 IP 数据包在逻辑上将会经过 ebtables 的 INPUT 链，而不会经过 ebtables 的 FORWARD 链。

### 2.5 本机转发数据帧的链遍历过程
- - -

![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge2e.png)

如果数据帧要被转发到网桥的另一侧，则数据帧将会通过 FORWARD 链和 POSTROUTING 链。 你可以在 FORWARD 链中过滤数据帧，在 POSTROUTING 链中，可以更改数据帧的源 MAC 地址(MAC-SNAT)。

### 2.6 本机发送数据帧的链遍历过程
- - -

![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge2f.png)

本地发送的数据帧在经过网桥决策之后，将遍历 nat 表的 OUTPUT 链、filter 表的 OUTPUT 链和 nat 表的 POSTROUTING 链。在 nat 表的 OUTPUT 链中可以更改数据帧的目的 MAC 地址，而在 filter 表的 OUTPUT 链可以过滤来自本机的数据帧。

值得注意的事 nat 表的 OUTPUT 链是在网桥做完决策之后遍历的，这对于数据帧转发来说实际上已经太晚了（因为 nat 表的 OUTPUT 链允许进行数据帧的 MAC-DNAT，此时网桥决策的数据帧的网卡出口早已经确定了）。 对 nat 表的 POSTROUTING 链来说也是同样的。

> 当目的设备是逻辑网桥设备时，需要被路由的数据帧也可能通过这三条链。

## 3. 机器被用作网桥设备和路由器设备（不是 brouter 设备）
- - -

### 3.1 IP hook 点
- - -
![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge3a.png)

以上是绿色方框为 IP 层的 hook 点。

### 3.2 iptables 遍历过程
- - -
![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge3b.png)

请注意，iptables nat 表的 OUTPUT 链位于路由决策之后，这对于 IP-DNAT 来说已经太晚了。可以通过重新路由被 DNAT 的 IP 数据包来解决这个问题。

上图清晰的给出了 iptables 的链是如何关联到到 IP hook 点的。

当在内核中启用 bridge-netfilter（br-nf） 代码时，iptables 的链也会关联到网桥的 hook上。这并不意味着 iptables 的链不再关联 IP 代码的 hook 上。对于通过网桥代码的 IP 数据包来说，br-nf 代码将决定 iptables 链将在网络代码的哪个位置被遍历。很明显，这将确保同一个数据包不会遍历两次相同的链。如上图所示，所有不与网桥代码接触的数据包都会以标准方式遍历 iptables 的链。

以下各节还将尝试解释 br-nf 代码的功能以及它为什么这样做。

### 3.3 bridge/route 路由数据包到网桥接口
- - -
![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge3c.png)

当设备在被用作网桥也被用作路由器时，如果路由决策发送数据帧到网桥接口，将会看到一个 IP 数据包依次遍历 ebtables 的 nat 表的 PREROUTING 链，filter 表的 INPUT 链，nat 表的 OUTPUT 链，filter 表的 OUTPUT 链和 nat 表的 POSTROUTING 链。

该数据包是具有 IP 层信息的以太网帧，其目的 MAC 地址为网桥的 MAC 地址，而目的 IP 地址不是网桥的 IP 地址。这就是 IP 数据包 如何通过 bridge/router 的。

### 3.4 bridge/route 路由数据包到非网桥接口
- - -
![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge3d.png)

上图假设 IP 数据包的入口是网桥端口。 这里将看到 iptables 的 PREROUTING 链在 ebtables 的 INPUT 链之前被遍历。具体原因将在下章说明。

## 4. 对被 bridge 的数据包进行 DNAT
- - -
假设我们想对网桥收到的 IP 数据包进行 IP DNAT。必须在 bridge 代码决定如何处理数据包之前进行数据包的目的地址转换（IP-DNAT 和 MAC-DNAT）。

因此，必须在 bridge 代码比较靠前的位置执行 IP DNAT 操作（换句话说必须在 bridge 代码执行任何实际操作之前执行 IP DNAT 操作）。这与 ebtables 的 nat 表 PREROUTING 链被遍历的位置相同（出于相同的原因）。 这就可以解释为什么 3.4 节中 iptables 的 PREROUTING 链在 ebtables 的 INPUT 链之前被遍历。 

我们应该可以注意到，在 ebtables 和 iptables 的 PREROUTING 链中将看到 2.2 节中第 4 项所描述的被网桥忽略的数据帧。

## 5. 被 bridge 的 IP 数据包的链遍历过程
- - -
![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge5.png)

被 bridge 的数据包永远不会进入链路层以上的任何网络代码。 所以，一个被 bridge 的 IP 数据包永远不会进入 IP 代码中。如上图所示，当 IP 数据包在 bridge 代码中时，将遍历所有的 iptables 链。

## 6. 在 iptables 规则中使用 bridge 端口
- - -

如果能够在 iptables 中基于网桥的物理端口配置 iptables 规则这对防止欺骗攻击将会很有帮助。

假设 br0 有 2 个物理端口 eth0 和 eth1。如果 iptables 只能基于 br0 配置规则，那么除了查看报文的源 MAC 地址之外，无法知道 eth0 端所连的设备何时将其源 IP 地址更改为 eth1 端所连设备的源 IP 地址。 

通过使用 iptables physdev 模块，您可以在 iptables 中基于 eth0 和 eth1 配置规则。

### 6.1 在 iptables 规则中使用 bridge 决策后的出端口
- - -

为了在 iptables 规则中使用 bridge 决策后的出端口，必须在 bridge 代码决策数据帧从网桥的哪个接口发送（eth0, eth1 or both）之后，才能遍历 iptables 的链。

当一个数据包从网桥接口进入，并被路由转发时数据报文将如下图所示，遍历 ebtables 与 iptables 链（bridge-netfilter 代码已经被编译进内核）：

![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge6a.png)

> 在 br-nf 代码的作用下，所有的链都将在 bridge 代码中被遍历的。
> 
> 显然这并不意味着被路由的 IP 数据包不会进入 IP 层的代码。而是他们在 IP 代码中时不会再重复经过 iptables 的链而已。

### 6.2 本地发出的数据包进行 IP DNAT
- - -

本地发出的数据包一般将如下图所示这样遍历链：

![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge6c.png)

从 6.1 节我们知道，由于 br-nf 代码的原因，实际情况应该如下图所示：

![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge6d.png)

请注意，当数据包在 IP 代码中遍历 iptables 的 nat 表 OUTPUT 链，并且当数据包做完网桥转发决策之后，遍历 iptables 的 filter 表 OUTPUT 链。

这使得可以对转发到另外设备的数据帧在 iptables 的 nat 表 OUTPUT 链执行 DNAT 转换，并可以让我们在 iptables 的 filter 表 OUTPUT 链中使用网桥端口配置 iptables 规则。

## 7. 数据包通过 iptables PREROUTING，FORWARD 和 POSTROUTING 链的两种可能方式
- - -

由于 br-nf 代码的存在，数据包有 2 种方式可以通过 iptables PREROUTING，FORWARD 和 POSTROUTING 链。

第一种方式是数据帧被网桥转发，所以 iptables 链将被 bridge 代码调用。

第二种方式是当数据包被路由时。

因此必须特别注意区分这两者，尤其是在 iptables FORWARD 链中。以下是需要注意的奇怪事情的示例：

![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge7a.png)

> 172.16.1.2 和 172.16.1.4 的默认网关是172.16.1.1。
> 
> 172.16.1.1 网桥 br0 的 ip 地址，br0 将 eth0 与 eth1 绑定到网桥 br0。
>

> 更多细节：
>
> 思想是：172.16.1.4 和 172.16.1.2 之间的流量通过 bridge 转发，而其他流量使用 masquerade 进行路由转发。

![](/img/2023-04-10-ebtables-iptables-interaction/2023-04-10-bridge7b.png)

配置如下所示：
```bash {linenos=table, linenostart=1}
iptables -t nat -A POSTROUTING -s 172.16.1.0/24 -d 172.16.1.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s 172.16.1.0/24 -j MASQUERADE

brctl addbr br0
brctl stp br0 off
brctl addif br0 eth1
brctl addif br0 eth2

ifconfig eth1 0 0.0.0.0
ifconfig eth2 0 0.0.0.0
ifconfig br0 172.16.1.1 netmask 255.255.255.0 up

echo '1' > /proc/sys/net/ipv4/ip_forward
```
注意第一行，因为网桥数据包和路由数据包都会执行 iptables 代码，我们需要区别对待。

我们并不希望网桥转发的数据包执行 masquerade 操作。如果我们省略第一行，情况将会有所不同：

比如 172.16.1.2 ping 172.16.1.4，网桥收到 ping 请求后，将报文的源 IP 地址设置（masquerade）为 172.16.1.1 后通过 eth1 端口发送出去，而 172.16.1.4 会将 icmp replay 返回给网桥（br0）。

masquerade 会将此响应的 IP 目的地址从 172.16.1.1 更改为 172.16.1.2。一切都会正常转发，但最好不要这么做。因此，我们使用第一行来避免这种情况的发生。

请注意，如果我们想要过滤访问 Internet 的连接，我们肯定需要第一行，这样我们就不会过滤本地进行网桥转发的报文。

## 8. 进入网桥端口的数据包在 iptables PREROUTING 链上执行 IP DNAT 转换
- - -

通过一些常规操作，可以保证经过 DNAT 处理的数据包在 DNAT 处理后具有与输入设备相同的输出设备（逻辑网桥设备我们喜欢称之为 br0）。该数据包将通过 ebtables 的 FORWARD 链，而不会通过 ebtables 的 INPUT/OUTPUT 链。

所有其他 DNAT 的数据包将只会被路由，因此不会通过 ebtables 的 FORWARD 链，他们将会通过 ebtables 的 INPUT 链，也有可能会通过 ebtables 的 OUTPUT 链。

## 9. iptables 使用 MAC 模块扩展
- - -

当在内核中启用 netfilter 代码时将会产生以下副作用，IP 数据包被路由并且该数据包的出口设备是 br0 设备。在 iptables FORWARD 链中过滤数据包的源 MAC 地址时将会遇到副作用。

从前面的几个小结的介绍可以清楚的知道，当数据包通过 bridge 代码时 iptables FORWARD 链的才会被遍历，这样做的目的是为了我们可以基于网桥的输出端口进行数据包过滤。这对数据包的源 MAC 地址会有副作用，因为 IP 代码会将数据包的源 MAC 地址更改为 br0 的 MAC 地址。

因此不可能在 iptables 的 FORWARD 链上，通过数据包的源 MAC 地址过滤发送到网桥/路由器的有问题的数据包。如果需要通过数据包的源 MAC 地址进行过滤，应该在 nat 表的 PREROUTING 链中进行过滤。

如果要在 FORWARD 链中实现过滤数据包真实源 MAC 地址的功能可能会引起非常肮脏的黑客攻击，这就得不偿失了。

## 10. 使用 iptables physdev 匹配模块
- - -

Linux 2.6 标准内核包含一个名为 physdev 的 iptables匹配模块，它用于基于网桥的物理转发端口配置 iptables 规则。它的基本用法很简单（更多详细信息，请参见 iptables 手册）：

```bash
iptables -m physdev --physdev-in <bridge-port>
iptables -m physdev --physdev-out <bridge-port>
```

## 11. IP 数据流的详细转发流程
- - -

Joshua Snyder（<josh_at_imagestream.com>）制作了 IP 数据包 在 Linux 网桥防火墙上转发的[详细流程图](https://ebtables.netfilter.org/br_fw_ia/PacketFlow.png)。

Jan Engelhardt 基于 Joshua 的流程图制作了一张更新的[转发流程图](https://upload.wikimedia.org/wikipedia/commons/3/37/Netfilter-packet-flow.svg)。

## 参考
- - -
* [ebtables/iptables interaction on a Linux-based bridge](https://ebtables.netfilter.org/br_fw_ia/br_fw_ia.html)

## 公众号：Flowlet
- - -

<img src="/img/qrcode_flowlet.jpg" width = 30% height = 30% alt="Flowlet" align=center/>

- - -