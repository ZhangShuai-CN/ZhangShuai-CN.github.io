---
layout:     post
title:      "微服务时代的 TCP/IP 协议：Service Mesh"
subtitle:   "下一代微服务：Service Mesh"
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

![]()



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

## 公众号：Flowlet
- - -

<img src="/img/qrcode_flowlet.jpg" width = 30% height = 30% alt="Flowlet" align=center/>

- - -