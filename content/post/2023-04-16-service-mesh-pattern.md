---
layout:     post
title:      "微服务时代的 TCP/IP：Service Mesh 的演进之路"
subtitle:   "下一代微服务：Service Mesh 的演进之路"
description: ""
excerpt: ""
date:       2023-04-16 01:01:01
author:     "张帅"
image: "/img/2023-04-16-service-mesh-pattern/backgroud.jpg"
showtoc: true
draft: true
tags:
    - service mesh
categories: [ Tech ]
URL: "/2023/04/16/service-mesh-pattern/"
---

- - -
###### 关于作者
> 
> **`张帅，网络从业人员，公众号：Flowlet`**
> 
> **`个人博客：https://flowlet.net/`**
- - -

## 前言
- - -

2018 年 9 月 1 日，Bilgin Ibryam 在 InfoQ 发表了一篇文章 [Microservices in a Post-Kubernetes Era](https://www.infoq.com/articles/microservices-post-kubernetes/)。

文中虽然没有明确指明“后 Kubernetes 时代的微服务”是什么，但是从文中可以看出作者的观点是：在后 Kubernetes 时代，服务网格（Service Mesh）技术已完全取代了通过使用软件库来实现网络运维的方式。

服务网格（Service Mesh）因此也被成为下一代微服务技术，笔者将会从技术演进的角度阐述一下，Service Mesh 这项技术诞生的历史必然性。


## 1. 计算机互联畅想时代
- - -

在 Intenet 实现计算机互联之前，最开始人们想象的计算机服务之间的交互方式是这样的：

![]()

一个应用程序通过与另一个应用程序发生对话来完成用户的请求。

## 2. ARPANET 时代
- - -

![]()

在 20 世纪 50 年代，那时候计算机很稀有，也很昂贵，计算机之间的互联的需求不大，数据量也很有限。

因此在 TCP/IP 协议出现之前，都是需要应用程序自己来处理网络通信所面临的丢包、乱序、重试等一系列流控问题，因此在应用程序的实现中，除了业务逻辑外，还包含对网络传输问题的处理逻辑。

## 3. TCP/IP 时代
- - -

![]()

随着计算机变得越来越普及，计算机之间的连接数量和数据量出现了爆炸式的增长。

为了避免每个应用程序都需要自己实现一套相似的网络传输处理逻辑，将应用程序中通用的路由传输与流量控制逻辑抽离出来，作为操作系统网络层的一部分，并逐渐形成 TCP/IP 这类的标准协议规范。

## 4. 微服务 1.0 时代
- - -

在 TCP/IP 协议出现之后，机器之间的网络通信不再是一个难题。当时服务都是以单体架构（monolithic）的形式运行，所有的业务进程都运行在一台服务器上。各个业务进程之间紧密耦合，如果一台服务器上的某个业务进程遇到需求峰值，纵使这台服务器上的其他业务进程资源利用率还比较低，也必须对整台服务器做集群扩展。而且由于各个业务进程紧密耦合，单个业务进程故障会对服务器上的其他业务进程造成故障影响。


![]()


为了解决单体架构（monolithic）的缺陷，在 2014 年 Martin Fowler 与 James Lewis 合写的文章《Microservices: A Definition of This New Architectural Term》中首次了解到微服务的概念。

在微服务架构 (Microservices)中，每个业务进程作为一项服务运行。这些服务之间使用轻量级 API 通过明确定义的接口进行通信。这些服务围绕业务功能进行构建，每项服务只执行一项特定功能。由于各个服务之间独立运行，因此可以针对各项服务独立进行更新、部署和扩展，以满足客户对不同业务服务的特定功能的需求。



![]()


微服务架构的发展也使得业务系统从集中式走向了分布式，无论是集中式系统还是分布式系统，最主要的是要有能提供服务发现的能力：即找到有能力处理请求的服务实例。比如，有个叫作 Teams 的服务需要找到一个叫作 Players 的服务实例。通过调用服务发现，可以获得一个满足条件的服务器清单。

对于单体系统来说，这个可以通过 DNS、负载均衡器和端口机制（比如通过 HTTP 服务器的 8080 端口来绑定服务）来实现。而在分布式系统里，事情就复杂了，服务发现需要处理更多的任务，比如客户端负载均衡、多环境（如 staging 环境和生产环境）、分布式服务器的物理位置等。


因此在分布式系统中的每个服务都需要根据业务需求来实现诸如：熔断策略、负载均衡、服务发现、认证和授权、quota 限制、trace 和监控等一系列与业务无关的通用功能逻辑。

## 5. 微服务 2.0 时代
- - -

![]()

为了避免分布式系统中每个服务都需要自己实现一套与业务无关的通用功能逻辑，随着技术的发展，一些面向微服务架构的开发框架出现了，如 Twitter 的 Finagle、Facebook 的 Proxygen 以及 Spring Cloud 等等，这些框架实现了分布式系统通信需要的各种与业务无关的功能逻辑：如负载均衡和服务发现等，因此一定程度上屏蔽了这些通信细节，使得开发人员可以专注于业务逻辑，而无需关注各种底层实现。


## 6. Service Mesh 1.0 时代
- - -

![]()

第二代微服务模式看似完美，但开发人员很快又发现，它也存在一些本质问题：

其一，虽然框架本身屏蔽了分布式系统通信的一些通用功能实现细节，但开发者却要花更多精力去掌握和管理复杂的框架本身，在实际应用中，去追踪和解决框架出现的问题也绝非易事；
其二，微服务软件库一般专注于某个平台，开发框架通常只支持一种或几种特定的语言；那些用没有框架支持的语言编写的服务，很难融入面向微服务的架构体系，想因地制宜的用多种语言实现架构体系中的不同模块也很难做到；
其三，框架以 lib 库的形式和服务联编，复杂项目依赖时的库版本兼容问题非常棘手，同时，框架库的升级也无法对服务透明，服务会因为和业务无关的 lib 库升级而被迫升级；


因此与 TCP/IP 协议栈一样，我们急切地希望能够将分布式服务所需要的一些特性放到底层的平台中。人们基于 HTTP 协议开发非常复杂的应用，无需关心底层 TCP 如何控制数据包。在开发微服务时也是类似的，工程师们聚焦在业务逻辑上，不需要浪费时间去编写服务基础设施代码或管理系统用到的软件库和框架。

![]()

但在当时，内核可编程技术（ebpf）还不成熟，直接在内核网络协议栈中加入这样的一个业务层不仅对内核有侵入性，而且由于内核更新速度太慢，无法满足快速变化的业务需求。


![]()

因此以 Linkerd，Envoy，Nginx Mesh 为代表的代理模式（sidecar，边车模式）应运而生，这就是第一代 Service Mesh，它将分布式服务的通信抽象为单独一层，在这一层中实现负载均衡、服务发现、认证授权、监控追踪、流量控制等分布式系统所需要的功能，作为一个和服务对等的代理服务，和服务部署在一起，接管服务的流量，通过代理之间的通信间接完成服务之间的通信请求，这样上边所说的三个问题也迎刃而解。

如果我们从一个全局视角来看，就会得到如下部署图：

![]()

如果我们暂时略去服务，只看 Service Mesh 的单机组件组成的网络：

![]()

由此大家可以看出所谓服务网格（Service Mesh），就像是一个由若干服务代理所组成的错综复杂的网格。

## 7. Service Mesh 2.0 时代
- - -

![]()

第一代 Service Mesh 由一系列独立运行的单机代理服务构成，随着容器技术的发展，微服务开始部署到更为复杂的运行时（如 Kubernetes 和 Mesos）上，并开始使用这些平台提供的网格网络工具。服务网格正从使用一系列独立运行的代理转向使用集中式的控制面板。

所有的单机代理组件通过和控制面板交互进行网络拓扑策略的更新和单机数据的汇报，这就是以 Istio 为代表的第二代 Service Mesh。


只看单机代理组件(数据面板)和控制面板的 Service Mesh 全局部署视图如下：
![]()


## 8. Service Mesh 的未来
- - -

对于 ServiceMesh 而言，目前最流行框架是 Istio，而它的数据面是 Envoy（使用 c++ 14 开发）。

基于 Istio 的 Service Mesh 架构在互联网公司进行大规模线上部署的时候逐渐遇到以下问题：

- Envoy（基于 c++ 开发） 上手难度大、维护成本高；
- SideCar 带来的额外资源开销以及 Proxy 模式带来的延迟增加；
- 全量配置下发带来内存消耗过大、配置文件过多难以查看运维；
- 微服务之间的通过 Http 或者其他不安全的协议进行通信，东西向流量难以防护；
- 线上为了保证系统的可用性，通常部署多集群多活，开源的 ServiceMesh 方案只注重单集群内的治理，对多集群多活场景没有直接给出完善的解决方案；

下面我们就从以上痛点出发，浅析一下 Service Mesh 的未来演进的几个方向。

### 8.1 数据面替换与插件模式
- - -

对于 ServiceMesh 而言，目前最流行框架是 Istio，而它的数据面是 Envoy（使用 c++ 14 开发）。Envoy 入门门槛比较高，直接改动或者进行二次开发难度很大。除此之外，很多公司更希望建立自己的生态系统，所以市面上就有很多数据面产品产生，主要分为下面两类：

* 网关类作代理的玩法，例如 apisix，他们推出了apiseven 来专门搞这件事情。
* 直接自研产品进行替代的玩法，以mson为代表，整个使用go进行开发的数据面，已经纳入cncf社区，不过还没有从里面毕业。


### 8.2 插件模式研究
- - -

目前社区的wasm方式不够成熟，支持内容偏少，加上大家对服务网格的需求很多，社区的研发进度满足不了很多人的需求，大家就希望一个成熟的插件模式能够出来。

当前阶段，插件模式的玩法主要有下面几种:

1）基于native c++自研，这一类对研发人员要求过高，不过结合是最好的。

2）脚本方式实现，以lua,nodejs为代表的。

3）cgo方式实现filter插件，以蚂蚁为代表。

4）基于envoyfilter进行协议对接，通过外围产品来辅助完成。

### 8.3 插件模式研究
- - -

3.性能问题的演进

对于服务网格来说，低延迟的快速转发一直是个强需求，而大家又想在这个基础上尽量少的使用cpu等资源。目前istio这一类网格产品表现则是差强人意，所以这方面的研究一直从未间断，当前市面上的玩法集中在下面两点:

1）iptables的替换策略，主要以ebpf

为代表，当然也有ipc通讯的方式，这种其实破坏了sdk和数据面之间的耦合性。

2）架构的调整，把数据面下沉到宿主机这个层面，有点类似把数据面往网卡这种设备去抽象的意思，这也是社区的最新研发方向。

对于这种玩法来说，笔者觉得是需要对当前数据面做切割的，要把通用的能力提取出来，来玩，其他功能往上浮才行。

4.xds按需下发


xDS 协议是 “X Discovery Service” 的简写，这里的 “X” 表示它不是指具体的某个协议，是一组基于不同数据源的服务发现协议的总称，包括 CDS、LDS、EDS、RDS 和 SDS 等。客户端可以通过多种方式获取数据资源，比如监听指定文件、订阅 gRPC stream 以及轮询相应的 REST API 等。

在 Istio 架构中，基于 xDS 协议提供了标准的控制面规范，并以此向数据面传递服务信息和治理规则。在 Envoy 中，xDS 被称为数据平面 API，并且担任控制平面 Pilot 和数据平面 Envoy 的通信协议，同时这些 API 在特定场景里也可以被其他代理所使用。目前 xDS 主要有两个版本 v2 和 v3，其中 v2 版本将于 2020 年底停止使用。

注：对于通用数据平面标准 API 的工作将由 CNCF 下设的 UDPA 工作组开展，后面一节会专门介绍。



当前社区xds的下发方式采用的都是全量下发的模式，这种模式通常会带来下面几个问题:

问题一:

每个运行态的sidecar上面的xds数据超大，而这些数据对当前pod来说绝大部分都是脏数据，这一来会影响envoy处理流量的耗时，二来也会消耗envoy很大的内存。

问题二:

这种超大的xds配置对于istiod更新xds有很大的冲击，特别是pod数量成千上万的时候，这种数据更新就会变得很不及时，而这种不及时会导致这段时间内的流量有可能会出错。

问题三:
很难排障，一个大几十万的配置文件，是很难发现问题的，只有研发一些工具才能解决，这又是一笔额外开销。

目前市面上的解决办法主要是两种，一种是社区增量xds的演进，据说2022年是重点，我们可以期待下。另外一种，是自己实现一些配套产品对xds进行裁剪，像蚂蚁才用了单独一个进程的方式与envoy进行通讯来解决这个问题。

5.安全和零信任网络

目前这是一个大趋势，社区和市面上已经有很多人在搞了，这个对于服务网格来说是一个天然优势，只要接入了服务网格，整个零信任网络就可以在业务无感知的情况下玩起来。

6.虚拟机调度和跨集群访问

对于企业来说，规模越大，虚拟机使用的越多，如果他们想推服务网格的话，虚拟机纳入管控中是必须要做的事情，像百度，阿里，腾讯这些大厂在玩服务网格的时候，都做了虚拟机这部分的单独开发。

除了虚拟机之外跨集群业务调度也是不得不解决的问题，因为规模的原因，很多业务线是物理隔离的，集群也是分离的，这样就需要有办法把他们统一管控起来。在网格中，这部分是通过serviceentry和ingress/egress配合来搞的。



## 参考
- - -
* [Pattern: Service Mesh](https://philcalcado.com/2017/08/03/pattern_service_mesh.html)
* [模式之服务网格](https://www.infoq.cn/article/pattern-service-mesh)
* [什么是 Service Mesh](https://zhuanlan.zhihu.com/p/61901608)
* [The Future of Service Mesh is Networking](https://www.infoq.com/articles/service-mesh-networking/)
* [Service Mesh 的未来在于网络](https://www.infoq.cn/article/tjhrjra2ljje5irdbrrg)
* [Microservices in a Post-Kubernetes Era](https://www.infoq.com/articles/microservices-post-kubernetes/)
* [microservices](https://aws.amazon.com/cn/microservices/)
* [微服务时代](http://icyfenix.cn/architecture/architect-history/microservices.html)
* [ServiceMesh PPT](https://hanamichi.wiki/posts/service-mesh2/)
* [eBPF and Wasm: Exploring the Future of the Service Mesh Data Plane](https://www.infoq.com/news/2022/01/ebpf-wasm-service-mesh/)
* [eBPF 和 Wasm：探索服务网格数据平面的未来](https://mp.weixin.qq.com/s/AeKaWy6ZHUiT3t_0AmKkHA)
* [How eBPF will solve Service Mesh – Goodbye Sidecars](https://isovalent.com/blog/post/2021-12-08-ebpf-servicemesh/)
* [告别 Sidecar——使用 eBPF 解锁内核级服务网格](https://cloudnative.to/blog/ebpf-solve-service-mesh-sidecar/)
* [Proxyless Service Mesh在百度的实践与思考 ](https://www.sohu.com/a/507156089_355140)
* [阿里巴巴 Service Mesh 落地的架构与挑战](https://zhuanlan.zhihu.com/p/465388624?utm_id=0)
* [目前社区关于ServiceMesh的主要方向](https://blog.csdn.net/zhghost/article/details/127099560)
* [百度在 Service Mesh 上的大规模落地实践](https://zhuanlan.zhihu.com/p/547654142)
* [xDS](https://www.wenjiangs.com/doc/xaweiqwblc)

## 公众号：Flowlet
- - -

<img src="/img/qrcode_flowlet.jpg" width = 30% height = 30% alt="Flowlet" align=center/>

- - -