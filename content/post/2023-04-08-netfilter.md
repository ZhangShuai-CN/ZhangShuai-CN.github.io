---
layout:     post
title:      "Netfilter 101：netfilter 架构与 iptables/ebtables 入门"
subtitle:   "Netfilter 架构与 iptables/ebtables"
description: "A Deep Dive into Netfilter Architecture"
excerpt: ""
date:       2023-04-08 11:22:00
author:     "张帅"
image: "/img/2023-04-08-netfilter/background.jpg"
showtoc: true
draft: false
tags:
    - netfilter
    - iptables
    - ebtables
categories: [ Tech ]
URL: "/2023/04/08/netfilter/"
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
数据中心网络**中间节点**数据包处理基本都采用了内核 Offload/Upload 解决方案。但是对于**端节点**来说，Linux 庞大的生态系统致使有大量的开源软件和应用程序基于 Linux 内核实现，这些庞大应用程序很难基于内核 Offload/Upload 方案做改造。由于是端节点，对于性能的要求远没有中间节点那么迫切。

对于网络从业人员来说，无论是从事部分应用场景的网络开发，还是出于参考借鉴的目的，了解 Linux 内核网络协议栈的实现都是从事网络开发绕不开的点。

## 前言
- - -
Netfilter 是 Linux 内核的数据包处理框架，由 Rusty Russell 于 1998 年开发， 旨在改进以前的 ipchains（Linux2.2.x）和 ipfwadm（Linux2.0.x）数据包处理框架。

本文主要从 Netfilter 构成与转发框架、iptables/ebtables 示例等方面介绍 Netfilter 框架，由于笔者水平有限，文中不免有错误之处，欢迎指正交流。

## 1. Netfilter 构成
- - -
Netfilter 详细构成如下所示：
![](/img/2023-04-08-netfilter/2023-04-08-Netfilter-components.svg)

从上图我们可以看出，Netfilter 框架才用了高内聚、低耦合的模块化设计理念。主要由 Netfilter hook API、内核防火墙子模块、用户态配置工具/应用程序 3 部分组成。

* **Netfilter hook API**：Netfilter 在网络协议栈处理数据包的关键流程中定义了 5 个 Hook 点，其它内核防火墙子模块（比如 ip_tables.ko）可以向这些 hook 点注册处理函数，这样当数据包经过这些 hook 点时，其上注册的处理函数将被依次调用。

* **内核防火墙子模块**：Netfilter 提供了整个防火墙的框架，各个协议基于 Netfilter 框架来自己实现自己的防火墙功能。每个协议都有自己独立的表来存储自己的配置信息，他们之间完全独立的进行配置和运行。
  
  - **链路层（2 层）防火墙子模块**：
  
        ebtables，对运行在 Bridge 中协议报文进行处理。

  - **ARP（2.5 层）防火墙子模块**：
      
        arptables，对 ARP 协议报文进行处理。

  - **网络层（3 层）防火墙子模块**：
        
        iptables（IPv4）、ip6tables（IPv6）分别对 IPv4协议栈与IPv6协议栈中的报文进行处理。

  - **nf_tables**：
      
        旨在替换现有的 {ip，ip6，arp，eb}tables 框架，它使用现有的 Netfilter hook API，为 {ip，ip6}tables 提供一个新的包过滤框架、一个新的用户空间实用程序（nft）和一个兼容层。
 
        Centos 8 已经使用 nftables 框架替代 iptables 框架作为默认的网络包过滤工具。

  - **NAT 子系统**：
        
        网络地址转换（SNAT、DNAT）。

  - **Conntrack**：
        
        连接跟踪模块，内核实现 statefull firewall、L4LB功能的主要模块。

  - **Logging**：
        
        nf_log，主要提供 Netfilter 的日志记录服务。使用 nft 添加规则，Netfilter 抛出日志，然后用户态的 ulogd2 程序监听读取这些日志后。
        
        ulogd2 会将这些数据包日志转换成json、sqlite3/mysql、pcap等多种格式文件，方便进行分析或用于进行其他的数据处理（审计、分析等）。

  - **Queueing**：
        
        nf_queue，内核在 Netfilter 框架基础上提供的 ip_queue/nfnetlink_queue 机制，通常用于将数据包上送给用户空间的应用程序进行处理，从而使得基于用户态的防火墙开发成为可能。

  - **Xtables**：
        
        主要包含{eb，arp，ip，ip6}tables模块所使用的共享代码部分。后来，Xtables或多或少被用来指整个防火墙(v4、v6、arp和eb)体系结构。


* **用户态配置工具/应用程序**：每个内核防火墙子模块（除了 Xtables）都有一个对应的用户态配置工具/应用程序。在讲述**内核防火墙子模块**的时候已经进行了相应介绍，这里不再进行赘述。

## 2. Netfilter 转发框架
- - -
数据包在 Netfilter 框架中的转发路径如下图所示：
![](/img/2023-04-08-netfilter/2023-04-08-Netfilter-packet-flow.svg)

上图协议栈主要分为 4 层，蓝色框为链路层、绿色框为网络层、黄色框为协议层、红色框为应用层。

图中绿色小方框表示 iptables 的表和链，蓝色小方框表示 ebtables 的表和链。在 br-nf 的作用下（从2.6 kernel开始）可以支持在链路层调用 iptables 的表和链。

br-nf 的引入是为了解决在链路层 Bridge 中处理 IP 数据包的问题（比如：在链路层内进行IP DNAT，外部机器与主机上虚拟机之间的通信流量），br-nf 也是 openstack 中实现安全组功能的基础。

## 3. Netfilter 与 iptables
- - -
Netfilter 在 网络层（L3）提供了以下 5 个 hook 点，包经过协议栈时会触发内核模块注册在这里的处理函数。触发哪个 hook 取决于包的方向（ingress/egress）、包的目的地址、包在上一个 hook 点是被丢弃还是拒绝等等。

```c
include/uapi/linux/netfilter.h

enum nf_inet_hooks {
	NF_INET_PRE_ROUTING,
	NF_INET_LOCAL_IN,
	NF_INET_FORWARD,
	NF_INET_LOCAL_OUT,
	NF_INET_POST_ROUTING,
	NF_INET_NUMHOOKS
};
```

* **NF_INET_PRE_ROUTING**:
    
      接收到的包进入协议栈后立即触发此 hook，在进行任何路由判断 （将包发往哪里）之前。
* **NF_INET_LOCAL_IN**: 
      
      接收到的包经过路由判断，如果目的是本机，将触发此 hook。
* **NF_INET_FORWARD**: 
      
      接收到的包经过路由判断，如果目的是其他机器，将触发此 hook。
* **NF_INET_LOCAL_OUT**: 
      
      本机产生的准备发送的包，在进入协议栈后立即触发此 hook。
* **NF_INET_POST_ROUTING**: 
      
      本机产生的准备发送的包或者转发的包，在经过路由判断之后， 将触发此 hook。

注册处理函数时必须提供优先级，以便 hook 触发时能按照优先级高低调用处理函数。这使得多个子模块（或者同一内核子模块的多个实例）可以在同一 hook 点注册，并且有确定的处理顺序。内核模块会依次被调用，每次返回一个结果给 netfilter 框架，提示该对这个包做什么操作。

### 3.1 iptables 构成
- - -
iptables 由 tables、chains、rules 3 部分组成：

![](/img/2023-04-08-netfilter/2023-04-08-table-chain-rule.png)

iptables 使用 table 来组织 rule，根据 rule 是被用来做什么业务类型处理，将 rule 分为不同 table。

例如，如果 rule 是处理网络地址转换的，那会放到 nat table；如果是判断是否允许数据包继续转发，那可能会放到 filter table。

在每个 table 内部，规则被进一步组织成 chain，内置的 chain 是 netfilter hook 触发的，chain 基本上能决定 rule 何时被匹配。

rule 放置在特定 table 的特定 chain 里面。当 chain 被调用的时候，包会依次匹配 chain 里面的 rule。每条 rule 都有一个匹配部分和一个 target（动作）部分。

### 3.2 iptables 规则
- - -
* 规则（rules）：是应用于数据包的操作。

规则其实就是通过 iptables 配置的预定义的条件，规则一般定义为 “如果数据包满足这些条件（rules），就会执行相应的的动作（actions）”。

规则可以匹配协议类型、目的或源地址、目的或源端口、目的或源网段、接收或发送的接口（网卡）、协议头、连接状态等信息，当数据包与规则匹配时，iptables就根据规则所定义的 actions 来处理这些数据包，如放行（accept）、拒绝（reject）和丢弃（drop）等。

配置防火墙的主要工作就是添加、修改和删除这些规则。

* 目标（target）：
数据包符合某种规则条件而触发的动作（action）叫做目标（target）。

目标分为两种类型：
  - 终止目标（terminating targets）：
      
        这种 target 会终止 chain 的匹配，将控制权转移回 netfilter hook。根据返回值的不同，hook 或者将数据包丢弃，或者允许数据包进行下一阶段的处理。
  - 非终止目标（non-terminating targets）：
  
        执行非终止目标动作，然后继续 chain 的执行。虽然每个 chain 最终都会回到一个终止目标，但是在这之前，可以执行任意多个非终止目标。

### 3.3 iptables 链
- - -
* 链（chains）：是规则的集合。

内置的 chain 和 netfilter hook 是一一对应的，内置的 chain 是由 netfilter hook 触发的。chain 基本上能决定（basically determin）规则何时被匹配。
* PREROUTING chain: 
    
      由 NF_INET_PRE_ROUTING hook 触发
* INPUT chain: 
      
      由 NF_INET_LOCAL_IN hook 触发
* FORWARD chain: 
      
      由 NF_INET_FORWARD hook 触发
* OUTPUT chain: 
      
      由 NF_INET_LOCAL_OUT hook 触发
* POSTROUTING chain: 
      
      由 NF_INET_POST_ROUTING hook 触发

chain 使管理员可以控制在包的传输路径上哪个 hook 点应用策略。

因为每个 table 有多个 chain，因此一个 table 可以在处理过程中的多个地方施加影响。特定类型的规则只在协议栈的特定点有意义，因此并不是每个 table 都 会在内核的每个 hook 注册 chain。

### 3.4 iptables 表
- - -
* 表（tables）：是链的集合。

#### 3.4.1 filter 表：过滤（放行/拒绝）
- - -
filter table 是最常用的 table 之一，用于判断是否允许一个数据包通过。

#### 3.4.2 nat 表：网络地址转换
- - -
nat table 用于实现网络地址转换。

当数据包进入协议栈的时候，这些规则决定是否以及如何修改包的源/目的地址，以改变数据包被路由时的行为。nat table 通常用于将数据包路由到无法直接访问的网络。

#### 3.4.3 mangle 表：修改 IP 头
- - -
mangle（修正）table 用于修改数据包的 IP 头。

例如，可以修改数据包的 TTL，增加或减少数据包可以经过的跳数。

这个 table 还可以对数据包打上只在内核内有效的“标记”（internal kernel “mark”），后续的 table 或工具可以根据这些标记进行处理。标记不会修改包本身，只是在包的内核表示上做标记。

#### 3.4.4 raw 表：conntrack 相关
- - -
iptables 防火墙是有状态的：对每个数据包进行判断的时候是依赖已经判断过的数据包。

建立在 netfilter 之上的连接跟踪（connection tracking）特性使得 iptables 将数据包看作是已有连接或会话的一部分，而不是一个由独立、不相关的数据包而组成的流。 数据包到达网络接口之后很快就会有连接跟踪逻辑判断。

raw table 定义的功能非常有限，其唯一目的就是提供一个让数据包绕过连接跟踪的框架。

#### 3.4.5 security 表：打 SELinux 标记
- - -
security table 的作用是给报文打上 SELinux 标记，以此影响 SELinux 或其他可以解读 SELinux 安全上下文的系统处理报文的行为。这些标记可以基于单个报文，也可以基于连接。

### 3.5 每种 table 实现的 chain
- - -
下面的表格展示了 table 和 chain 的关系。横向是 table， 纵向是 chain，Y 表示这个 table 里面有这个 chain。

例如，第二行表示 raw table 有 PRETOUTING 和 OUTPUT 两 个 chain。具体到每列，从上倒下的顺序就是 netfilter hook 触发的时候，（对应 table 的）chain 被调用的顺序。

在下面的图中，nat table 被细分成了 DNAT （修改目的 IP） 和 SNAT（修改源 IP），以更方便地展示他们的优先级。另外，我们添加了路由决策点和连接跟踪点，以使得整个过程更完整全面：

| Tables/Chain | PREROUTING | INPUT | FORWARD | OUTPUT | POSTROUTING |
|--------------|------------|-------|---------|--------|-------------|
|（路由判断）   |            |       |         | Y      |             |
| raw          | Y          |       |         | Y      |             |
| （连接跟踪）  | Y          |       |         | Y      |             |
| mangle       | Y          | Y     | Y       | Y      | Y           |
| nat（DNAT）  | Y          |       |         | Y      |             |
|（路由判断）   | Y          |       |         | Y      |             |
| filter       |            | Y      | Y      | Y      |             |
| security     |            | Y      | Y      | Y      |             |
| nat（SNAT）  |            | Y      |        | Y      | Y           |

当一个报文触发 netfilter hook 时，处理过程将沿着列从上向下执行。 触发哪个 hook（列）和报文的方向（ingress/egress）、路由判断、过滤条件等相关。

特定事件会导致 table 的 chain 被跳过。例如，只有每个连接的第一个报文会去匹配 NAT 规则，对这个报文的动作会应用于此连接后面的所有报文。到这个连接的应答报文会被自动应用反方向的 NAT 规则。

### 3.6 Chain 遍历优先级
- - -
假设服务器知道如何路由数据包，而且防火墙允许数据包传输，下面就是不同场景下报文的游走流程：
* **收到的、目的是本机的包**：
  
      PRETOUTING -> INPUT
* **收到的、目的是其他主机的包**：

      PRETOUTING -> FORWARD -> POSTROUTING
* **本地产生的包**：
      
      OUTPUT -> POSTROUTING

综合前面讨论的 table 顺序问题，我们可以看到对于一个收到的、目的是本机的包： 首先依次经过 PRETOUTING chain 上面的 raw、mangle、nat table；然后依次经过 INPUT chain 的 mangle、filter、security、nat table，然后才会到达本机的某个 socket。

### 3.7 用户自定义 chain
- - -

这里要介绍一种特殊的非终止目标：跳转目标（jump target）。jump target 是跳转到其他 chain 继续处理的动作。我们已经讨论了很多内置的 chain，它们和调用它们的 netfilter hook 紧密联系在一起。然而，iptables 也支持管理员创建他们自己用于管理目的的 chain。

向用户自定义 chain 添加规则和向内置的 chain 添加规则的方式是相同的。不同的地方在于， 用户定义的 chain 只能通过从另一个规则跳转（jump）到它，因为它们没有注册到 netfilter hook。

用户定义的 chain 可以看作是对调用它的 chain 的扩展。例如，用户定义的 chain 在结束的时候，可以返回 netfilter hook，也可以继续跳转到其他自定义 chain。

这种设计使框架具有强大的分支功能，使得管理员可以组织更大更复杂的网络规则。

### 3.8 iptables 简明教程
- - -

#### 3.8.1 iptables 语法格式
- - -
![](/img/2023-04-08-netfilter/2023-04-15-iptables-cmd.png)
```bash
iptables [-t 表名] 命令选项 ［链名］［条件匹配］ [-j 目标动作或跳转]
```
#### 3.8.2 表名
- - -

```bash
iptables [-t 表名] ：对指定的表 table 进行操作， table 必须是以下表中的一个。如果不指定此选项，默认的是 filter 表。
```
* **raw**     ：高级功能，如：网址过滤。
* **mangle**  ：数据包修改（QOS），用于实现服务质量。
* **nat**     ：地址转换，用于网关路由器。
* **filter**  ：包过滤，用于防火墙规则。
* **security**：SELinux 相关

#### 3.8.3 命令选项
- - -

```bash
-A 在指定链的末尾添加（append）一条新的规则
-D 删除（delete）指定链中的某一条规则，可以按规则序号和内容删除
-I 在指定链中插入（insert）一条新的规则，默认在第一行添加
-R 修改、替换（replace）指定链中的某一条规则，可以按规则序号和内容替换
-L 列出（list）指定链中所有的规则进行查看
-E 重命名用户定义的链，不改变链本身
-F 清空（flush）
-N 新建（new-chain）一条用户自己定义的规则链
-X 删除指定表中用户自定义的规则链（delete-chain）
-P 设置指定链的默认策略（policy）
-Z 将所有表的所有链的字节和数据包计数器清零
-n 使用数字形式（numeric）显示输出结果
-v 查看规则表详细信息（verbose）的信息
-V 查看版本(version)
-h 获取帮助（help）
--line-numbers 规则显示带序号
```

#### 3.8.4 链名（区分大小写，必须为大写）
- - -

```bash
INPUT 链 ：处理输入数据包。
OUTPUT 链 ：处理输出数据包。
FORWARD 链 ：处理转发数据包。
PREROUTING 链 ：用于目标地址转换（DNAT）。
POSTOUTING 链 ：用于源地址转换（SNAT）。
```
#### 3.8.5 条件匹配
- - -

```bash
! 表示：取反/非

[!]-p  匹配协议
[!]-s  匹配源地址
[!]-d  匹配目标地址
[!]-i  匹配入站网卡接口
[!]-o  匹配出站网卡接口
[!]--sport  匹配源端口
[!]--dport  匹配目标端口
[!]--src-range  匹配源地址范围
[!]--dst-range  匹配目标地址范围
[!]--limit  四配数据表速率
[!]--mac-source  匹配源MAC地址
[!]--sports  匹配源端口范围
[!]--dports  匹配目标端口范围
[!]--state  匹配状态（INVALID、ESTABLISHED、NEW、RELATED）
[!]--string  匹配应用层字串
```

#### 3.8.6 匹配动作（区分大小写，必须为大写）
- - -

```bash
ACCEPT      ：接收数据包。
DROP        ：丢弃数据包。
REDIRECT    ：重定向、映射、透明代理。
SNAT        ：源地址转换。
DNAT        ：目标地址转换。
MASQUERADE  ：IP伪装（NAT），用于ADSL。
LOG         ：日志记录。
SEMARK      : 添加SEMARK标记以供网域内强制访问控制（MAC）
```
#### 3.8.7 实验
- - -

##### 3.8.7.1 实验环境
- - -

```bash
系统配置：
  ubuntu20.04 + iptables v1.8.4
```
**拓扑**：
![](/img/2023-04-08-netfilter/2023-04-15-iptables-experiment.png)

VM 1 的 ens33 网卡 与 VM 2 的 ens33 网卡连在一起，通过 192.168.129/24 网段进行通信。

PC（10.0.0.1/24） 通过 VMware 网桥连接到 VM 2 的 ens37 网卡（10.0.0.11/24）。 

##### 3.8.7.2 查看链默认策略
- - -

```bash
iptables [-t 表名] -nvL
```
**参数含义**：

-L ：表示查看当前表的所有规则，默认查看的是 filter 表，如果要查看 nat 表，可以加上 -t nat 参数。

-n ：表示不对 IP 地址进行反查，加上这个参数显示速度将会加快。

-v ：表示输出详细信息，包含通过该规则的数据包数量、总字节数以及相应的网络接口。

```bash
在 VM2 机器上查看 filter 表的链默认策略：

root@ubuntu:/home/ubuntu# iptables -nvL
Chain INPUT (policy ACCEPT 505 packets, 46082 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 384 packets, 31012 bytes)
 pkts bytes target     prot opt in     out     source               destination 
```

所有的链旁边都有policy ACCEPT标注，这表明当前链的默认策略为ACCEPT，也就是对应的防火墙为黑名单，默认放通所有类型的流量，只有指定规则的 flow 才会 DROP。

此时 VM1 ping VM2 可以 ping 通：
```bash
root@ubuntu:/home/ubuntu# ping 192.168.79.130 -I 192.168.79.129
PING 192.168.79.130 (192.168.79.130) from 192.168.79.129 : 56(84) bytes of data.
64 bytes from 192.168.79.130: icmp_seq=1 ttl=64 time=0.558 ms
^C
--- 192.168.79.130 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.558/0.558/0.558/0.000 ms
```
##### 3.8.7.3 设置链默认策略
- - -

查看 VM2 可以看到 PC （10.0.0.1:6025）通过 ssh 连接到 VM2 的 （10.0.0.11:22） 端口。
```bash {linenos=table, linenostart=1, hl_lines=[7]}
root@ubuntu:~# netstat -nat
Active Internet connections (servers and established)
Proto Recv-Q Send-Q Local Address           Foreign Address         State      
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:6010          0.0.0.0:*               LISTEN     
tcp        0     36 10.0.0.11:22            10.0.0.1:6025           ESTABLISHED
tcp6       0      0 :::22                   :::*                    LISTEN     
tcp6       0      0 ::1:6010                :::*                    LISTEN     
```
为了保证 PC 能够通过 SSH 正常连接到 VM2 不中断，我们先将 ens37 接口对应的流量放行：
```bash {linenos=table, linenostart=1, hl_lines=[6,13]}
root@ubuntu:~# iptables -A INPUT -i ens37 -j ACCEPT
root@ubuntu:~# iptables -A OUTPUT -o ens37 -j ACCEPT
root@ubuntu:~# iptables -nvL
Chain INPUT (policy ACCEPT 1 packets, 328 bytes)
 pkts bytes target     prot opt in     out     source               destination         
   53  3168 ACCEPT     all  --  ens37  *       0.0.0.0/0            0.0.0.0/0           

Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 1 packets, 318 bytes)
 pkts bytes target     prot opt in     out     source               destination         
   31  2308 ACCEPT     all  --  *      ens37   0.0.0.0/0            0.0.0.0/0 
```
将 VM2 防火墙设置为白名单，默认拒绝所有类型流量，只有指定规则的 flow 才会 ACCEPT：
```bash
root@ubuntu:~# iptables -P INPUT DROP
root@ubuntu:~# iptables -P FORWARD DROP
root@ubuntu:~# iptables -P OUTPUT DROP
root@ubuntu:~# iptables -nvL
Chain INPUT (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
  220 14373 ACCEPT     all  --  ens37  *       0.0.0.0/0            0.0.0.0/0           

Chain FORWARD (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
  149 13204 ACCEPT     all  --  *      ens37   0.0.0.0/0            0.0.0.0/0
```
将 VM 2 所有表的所有链的字节和数据包计数器清零
```bash
root@ubuntu:~# iptables -Z
```
VM1 ping VM2 指定 10 个报文：
```bash
root@ubuntu:~# ping 192.168.79.130 -I 192.168.79.129 -c 10 -i 0.1
PING 192.168.79.130 (192.168.79.130) from 192.168.79.129 : 56(84) bytes of data.

--- 192.168.79.130 ping statistics ---
10 packets transmitted, 0 received, 100% packet loss, time 934ms
```

VM 2 查看会发现 filter 表的 INPUT 链 ：DROP 10 packets
```bash {linenos=table, linenostart=1, hl_lines=[2]}
root@ubuntu:~# iptables -nvL
Chain INPUT (policy DROP 10 packets, 840 bytes)
 pkts bytes target     prot opt in     out     source               destination         
   56  3733 ACCEPT     all  --  ens37  *       0.0.0.0/0            0.0.0.0/0           

Chain FORWARD (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
   47  5192 ACCEPT     all  --  *      ens37   0.0.0.0/0            0.0.0.0/0 
```
将 VM 2 filter 表 INPUT 链设置为放通 icmp 流量，同时清空计数器：
```bash
root@ubuntu:~# iptables -A INPUT -p icmp -j ACCEPT
root@ubuntu:~# iptables -Z
```
VM1 ping VM2 指定 10 个报文：
```bash
root@ubuntu:~# ping 192.168.79.130 -I 192.168.79.129 -c 10 -i 0.1
PING 192.168.79.130 (192.168.79.130) from 192.168.79.129 : 56(84) bytes of data.

--- 192.168.79.130 ping statistics ---
10 packets transmitted, 0 received, 100% packet loss, time 934ms
```
VM 2 查看会发现 filter 表的 INPUT 链 ：ACCEPT 10 packets，OUTPUT 链 ：DROP 10 packets
```bash {linenos=table, linenostart=1, hl_lines=[5, 10]}
root@ubuntu:~# iptables -nvL
Chain INPUT (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
   12   720 ACCEPT     all  --  ens37  *       0.0.0.0/0            0.0.0.0/0           
   10   840 ACCEPT     icmp --  *      *       0.0.0.0/0            0.0.0.0/0           

Chain FORWARD (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy DROP 10 packets, 840 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    7   716 ACCEPT     all  --  *      ens37   0.0.0.0/0            0.0.0.0/0
```
将 VM 2 filter 表 OUTPUT 链设置为放通 icmp 流量，同时清空计数器：
```bash
root@ubuntu:~# iptables -A OUTPUT -p icmp -j ACCEPT
root@ubuntu:~# iptables -Z
```

VM1 ping VM2 指定 10 个报文：
```bash
root@ubuntu:~# ping 192.168.79.130 -I 192.168.79.129 -c 10 -i 0.1
PING 192.168.79.130 (192.168.79.130) from 192.168.79.129 : 56(84) bytes of data.
64 bytes from 192.168.79.130: icmp_seq=1 ttl=64 time=0.785 ms
64 bytes from 192.168.79.130: icmp_seq=2 ttl=64 time=0.401 ms
64 bytes from 192.168.79.130: icmp_seq=3 ttl=64 time=0.522 ms
64 bytes from 192.168.79.130: icmp_seq=4 ttl=64 time=0.510 ms
64 bytes from 192.168.79.130: icmp_seq=5 ttl=64 time=0.335 ms
64 bytes from 192.168.79.130: icmp_seq=6 ttl=64 time=1.42 ms
64 bytes from 192.168.79.130: icmp_seq=7 ttl=64 time=0.500 ms
64 bytes from 192.168.79.130: icmp_seq=8 ttl=64 time=0.346 ms
64 bytes from 192.168.79.130: icmp_seq=9 ttl=64 time=0.514 ms
64 bytes from 192.168.79.130: icmp_seq=10 ttl=64 time=0.500 ms
```
VM 2 查看会发现 filter 表的 INPUT 链 ：ACCEPT 10 packets，OUTPUT 链 ：ACCEPT 10 packets
```bash {linenos=table, linenostart=1, hl_lines=[5, 13]}
root@ubuntu:~# iptables -nvL
Chain INPUT (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
   16   992 ACCEPT     all  --  ens37  *       0.0.0.0/0            0.0.0.0/0           
   10   840 ACCEPT     icmp --  *      *       0.0.0.0/0            0.0.0.0/0           

Chain FORWARD (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
   11  1064 ACCEPT     all  --  *      ens37   0.0.0.0/0            0.0.0.0/0           
   10   840 ACCEPT     icmp --  *      *       0.0.0.0/0            0.0.0.0/0 
```

VM 2 查看 filter 表，通过 --line-numbers 显示序号：
```bash
root@ubuntu:~# iptables -nvL --line-numbers
Chain INPUT (policy DROP 8 packets, 1025 bytes)
num   pkts bytes target     prot opt in     out     source               destination         
1       66  4317 ACCEPT     all  --  ens37  *       0.0.0.0/0            0.0.0.0/0           
2       10   840 ACCEPT     icmp --  *      *       0.0.0.0/0            0.0.0.0/0           

Chain FORWARD (policy DROP 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy DROP 30 packets, 3000 bytes)
num   pkts bytes target     prot opt in     out     source               destination         
1       41  3772 ACCEPT     all  --  *      ens37   0.0.0.0/0            0.0.0.0/0           
2       10   840 ACCEPT     icmp --  *      *       0.0.0.0/0            0.0.0.0/0 
```
VM 2 删除 filter 表，INPUT 链与 OUTPUT 链序号为 2 的规则：
```bash
root@ubuntu:~# iptables -D OUTPUT 2
root@ubuntu:~# iptables -D INPUT 2
```
VM 2 查看 filter 表，发现INPUT 链与 OUTPUT 链序号为 2 的规则已被删除：
```bash
root@ubuntu:~# iptables -nvL --line-numbers
Chain INPUT (policy DROP 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination         
1      160 10101 ACCEPT     all  --  ens37  *       0.0.0.0/0            0.0.0.0/0           

Chain FORWARD (policy DROP 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy DROP 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination         
1      100  9624 ACCEPT     all  --  *      ens37   0.0.0.0/0            0.0.0.0/0 
```
VM 2 清空所有防火墙规则：
```bash
root@ubuntu:~# iptables -F
```
VM 2 清空所有链统计计数：
```bash
root@ubuntu:~# iptables -Z
```
VM 2 删除指定表中（默认为 filter 表），用户自定义的链：
```bash
root@ubuntu:~# iptables -X
```
VM 2 保存防火墙规则：

`iptables-save` 命令用来 dump iptables 规则，通过重定向将 iptables 配置保存到文件中：
```bash
root@ubuntu:~# install -Dv /dev/null /etc/iptables/iptables-save.conf
root@ubuntu:~# iptables-save > /etc/iptables/iptables-save.conf
```
VM 2 恢复防火墙规则：
```bash
root@ubuntu:~# iptables-restore < /etc/iptables/iptables-save.conf
```

## 4. Netfilter 与 ebtables
- - -
netfilter 实现主要分两层：

![](/img/2023-04-08-netfilter/2023-04-17-nf-hooks.png)

第一层在 IP 层，由 IP 协议栈预留的 HOOK 点提供支持，对应的应用层的管理工具是 iptables；

第二层在链路层，由软桥协议栈预留的 HOOK 点提供支持，对应应用层的管理工具是 ebtables。

Netfilter 在 链路层（L2）提供了以下 6 个 hook 点：其中 NF_BR_BROUTING 不是通过调用 netfilter 框架的 register 函数来进行 HOOK 的回调注册的。

```c
include/uapi/linux/netfilter_bridge.h

#define NF_BR_PRE_ROUTING	  0
#define NF_BR_LOCAL_IN		  1
#define NF_BR_FORWARD		    2
#define NF_BR_LOCAL_OUT		  3
#define NF_BR_POST_ROUTING	4
/* Not really a hook, but used for the ebtables broute table */
#define NF_BR_BROUTING		  5
#define NF_BR_NUMHOOKS		  6
```
* **NF_BR_PRE_ROUTING**:
    
      在网卡混杂模式 drop 之后，进行 checksum 校验。
* **NF_BR_LOCAL_IN**: 
      
      数据包的目的 MAC 是本地 box。
* **NF_BR_FORWARD**: 
      
      数据包的目的 MAC 是桥的另一个接口。
* **NF_BR_LOCAL_OUT**: 
      
      本机产生的数据包。
* **NF_BR_POST_ROUTING**: 
      
      数据包即将发送出去。
* **NF_BR_BROUTING**: 
      
      并不是真正的 hook，被 ebtables 的 broute 表所使用的。

### 4.1 ebtables
- - -
ebtables 即以太网桥防火墙，以太网桥工作在数据链路层，ebtables用来过滤数据链路层数据包。 在内核中，ebtables 的数据截获点比 iptables 更“靠前”，它获得的数据更“原始”，ebtables 多用于桥模式，比如控制 VLAN ID 等。 

ebtables 的配置分为表、链和规则三级。

#### 4.1.1 表
- - -

表共分为三种: filter, nat, broute，用 -t 选项指定。默认为 filter 表。

* filter：过滤本机流入流出的数据包时默认使用的表。

      它包含有 3 条链，分别为 INPUT 链、OUTPUT 链、FORWARD 链。
* nat   ：用于 mac 地址转换（mac-NAT）。

      它包含有 3 条链，分别为 PREROUTING 链、OUTPUT链、POSTROUTING 链。
* broute：网桥的一种特殊工作模式，它可以根据配置对满足某些规则的包送入三层进行路由；也可以根据配置对满足某些规则的二层包进行 bridge。；类似于 VPP（Vector packet processing）中的 bridge-domain。

      它只有 1 个 BROUTING 链。

#### 4.1.2 链
- - -

链分为内置和自定义两种。不同的表内置链不同。自定义链挂接在对应的内置链内，使用 -j 让其跳转到新的链中。

ebtables 共分为以下 6 条内置链：
* INPUT：
    
      数据帧的目的地址是网桥本身。
* FORWARD：
    
      被网桥转发的数据帧。
* OUTPUT：
      
      针对本地生成和桥接路由的数据帧。
* PREROUTING：
      
      在被网桥转发之前。
* POSTROUTING：
      
      在被网桥转发之后。
* BROUTING：
      
      以太帧进入网桥设备后首先通过的就是 BROUTING 链，经过 BROUTING 后才决定数据包是进入网桥转发处理流程还是本地路由处理流程。

#### 4.1.3 规则
- - -
每个链中有一系列规则，每个规则定义了一些过滤选项。每个数据包都会匹配这些项，一旦匹配成功就会执行对应的动作（TARGET）。

目标（TARGETS）可以是以下：
* ACCEPT：让以太帧通过此链。（BROUTING 链：ACCEPT 表示以太帧进入网桥转发处理流程）
* DROP：丢弃该以太帧。（BROUTING 链：DROP 表示以太帧进入本地路由处理流程）
* CONTINUE：检查同一条链的下一条规则，一般用于统计通过该条链的流量。
* RETURN：停止检查该条链的余下规则。
* TARGET EXTENSION：扩展的执行目标，如 –mark-set 等。
* 跳转到自定义的链进行规则匹配。

### 4.2 ebtables 简明教程
- - -

ebtables 使用规则如下：
```bash
ebtables [-t 表名] 命令选项 ［链名］［条件匹配］ [-j 目标动作或跳转]
```
#### 4.2.1 表名
- - -
filter, nat, broute 3 张表中的其中一个，默认为 filter 表。

#### 4.2.2 命令选项
- - -
```bash
-A 添加到现有链的末尾
-D 从选定的链中删除一条或多条规则
-I 从选定的链中插入规则，默认插入到头部。
-P 指定策略，可以为ACCEPT、DROP或 RETURN
-F 删掉所有的链
-Z 设置选定的链的计数为 0
-L 列出所有的规则
-n 显示规则的编码
-c 显示匹配统计
```

#### 4.2.3 链名（区分大小写，必须为大写）
- - -
```bash
INPUT：数据帧的目的地址是网桥本身。
FORWARD：被网桥转发的数据帧。
OUTPUT：针对本地生成和桥接路由的数据帧。
PREROUTING：在被网桥转发之前。
POSTROUTING：在被网桥转发之后。
BROUTING：以太帧进入网桥设备后首先通过的就是 BROUTING 链，经过 BROUTING 后才决定数据包是进入网桥转发处理流程还是本地路由处理流程。
```
#### 4.2.4 条件匹配
- - -
```bash
! 表示：取反/非

[!]-p  匹配协议
[!]-s  匹配源地址
[!]-d  匹配目标地址
[!]-i  匹配入站网卡接口
[!]-o  匹配出站网卡接口
[!]--logical-in 网桥入接口
[!]--logical-out 网桥出接口
```

#### 4.2.4 匹配动作（区分大小写，必须为大写）
- - -
```bash
ACCEPT：让以太帧通过此链。（BROUTING 链：ACCEPT 表示以太帧进入网桥转发处理流程）
DROP：丢弃该以太帧。（BROUTING 链：DROP 表示以太帧进入本地路由处理流程）
CONTINUE：检查同一条链的下一条规则，一般用于统计通过该条链的流量。
RETURN：停止检查该条链的余下规则。
TARGET EXTENSION：扩展的执行目标，如 –mark-set 等。
```
#### 4.2.5 实验
- - -

##### 4.2.5.1 实验环境
- - -
```bash
系统配置：
  ubuntu20.04 + ebtables 1.8.4
```
##### 4.2.5.2 查看链默认策略
- - -

查看 filter 表链的默认策略：
```bash
root@ubuntu:~# ebtables -Lnc
Bridge table: filter

Bridge chain: INPUT, entries: 0, policy: ACCEPT

Bridge chain: FORWARD, entries: 0, policy: ACCEPT

Bridge chain: OUTPUT, entries: 0, policy: ACCEPT
```

##### 4.2.5.3 保存 ebtables 配置：
- - -
`ebtables-save` 命令用来 dump ebtables 规则，通过重定向将 ebtables 配置保存到文件中：

```bash
root@ubuntu:~# install -Dv /dev/null /etc/ebtables/ebtables-save.conf
root@ubuntu:~# ebtables-save > /etc/ebtables/ebtables-save.conf
# Generated by ebtables-save v1.8.4 on Mon Apr 17 07:23:57 2023
*filter
:INPUT ACCEPT
:FORWARD ACCEPT
:OUTPUT ACCEPT
# Completed on Mon Apr 17 07:23:57 2023
# Generated by ebtables-save v1.8.4 on Mon Apr 17 07:23:57 2023
*nat
:PREROUTING ACCEPT
:OUTPUT ACCEPT
:POSTROUTING ACCEPT
# Completed on Mon Apr 17 07:23:57 2023
```
##### 4.2.5.4 恢复 ebtables 配置：
- - -
```bash
root@ubuntu:~# ebtables-restore < /etc/ebtables/ebtables-save.conf
```

### 4.3 bridge-netfilter
- - -
ebtables 只可以简单过滤二层以太网帧，无法过滤 ipv4 数据包。解决这个问题，Linux内核引入了 bridge-netfilter（以下简称：br-nf）以解决在链路层 Bridge 中处理 IP 数据包的问题（比如：在链路层内进行IP DNAT，外部机器与主机上虚拟机之间的通信流量），br-nf 也是 openstack 中实现安全组功能的基础。

![](/img/2023-04-08-netfilter/2023-04-10-PacketFlow.png)

br-nf 在链路层 Bridge 代码中插入了几个能够被 iptables 调用的钩子函数，Bridge 中数据包在经过这些钩子函数时，iptables 规则被执行(上图中 Link Layer 中的绿色小方框即是 iptables 插入到链路层的 chain，蓝色小方框为 ebtables chain)。

这就使得 {ip,ip6,arp}tables 能够 “看见” Bridge 中的 IPv4,ARP 等数据包。这样不管此数据包是发给主机本身，还是通过 Bridge 转发给虚拟机，iptables 都能完成过滤。

#### 4.3.1 br-nf 启用：
- - -

**加载**：br_netfilter.ko
```bash
root@ubuntu:/home/ubuntu# modprobe br_netfilter
root@ubuntu:/home/ubuntu# lsmod | grep br_netfilter
br_netfilter           28672  0
bridge                176128  1 br_netfilter
```
**使能**：/proc/sys/net/bridge/bridge-nf-call-iptables

```bash
root@ubuntu:/home/ubuntu# echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
```

## 参考
- - -
* [A Deep Dive into Iptables and Netfilter Architecture]([https://](https://www.digitalocean.com/community/tutorials/a-deep-dive-into-iptables-and-netfilter-architecture))
* [Netfilter](https://en.wikipedia.org/wiki/Netfilter)
* [ebtables/iptables interaction on a Linux-based bridge](http://ebtables.netfilter.org/br_fw_ia/br_fw_ia.html)
* [IPTables， Chains & Rules](https://www.easy-network.de/iptables.html)
* [云计算底层技术-netfilter框架研究]([https://](https://opengers.github.io/openstack/openstack-base-netfilter-framework-overview/))
* [[译] 深入理解 iptables 和 netfilter 架构](http://arthurchiao.art/blog/deep-dive-into-iptables-and-netfilter-arch-zh/)
* [走进Linux内核之Netfilter框架](https://juejin.cn/post/7008945265021288484)
* [iptables&Netfilter简介](https://www.freebuf.com/articles/network/324614.html)

## 公众号：Flowlet
- - -

<img src="/img/qrcode_flowlet.jpg" width = 30% height = 30% alt="Flowlet" align=center/>

- - -