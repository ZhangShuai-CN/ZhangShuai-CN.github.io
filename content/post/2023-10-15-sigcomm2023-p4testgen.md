---
layout:     post
title:      "P4Testgen：一种 P4 可扩展测试预言 (Test Oracle) [SIGCOMM 2023]"
subtitle:   "一种 P4 可扩展测试预言 (Test Oracle)"
description: "P4Testgen: An Extensible Test Oracle For P4"
excerpt: ""
date:       2023-10-15 01:01:01
author:     "张帅"
image: "/img/2023-10-15-sigcomm2023-p4testgen/background.jpg"
showtoc: true
draft: true
tags:
    - SIGCOMM 2023
categories: [ Tech ]
URL: "/2023/10/15/sigcomm2023-p4testgen/"
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

笔者最近在做基于 Tofino 通过 P4testgen 完成 P4<sub>16</sub> 代码的测试预言 (test oracle)，从而在上线之前通过自动生成测试用例完成整个 P4<sub>16</sub> 代码的逻辑自洽。正好趁这个机会为爱发电，翻译下 SIGCOMM'23 论文《P4Testgen: An Extensible Test Oracle For P4》为大家做点贡献。

文中的 **Test Oracle** ：并不是测试甲骨文的意思，该术语的中文表述为**测试预言**。在 T.Xie《Augmenting automatically generated unit-test suites with regression oracle checking》的论文中对**测试预言**给出了一个很明确的定义：
> A test case consists of two parts: a test input to exercise the program under test and a test oracle to check the correctness of the test execution. A test oracle is often in the form of executable assertions such as in the JUnit testing framework. Manually generated test cases are valuable in exposing program faults in the current program version or regression faults in future program versions.

> 1 个 测试用例 (test case) = 1 个测试输入 (test input) + 1 个测试预言 (test oracle)。
> 测试输入 (test input) 是用来执行程序的，测试预言 (test oracle) 是用来检查测试执行的正确性的。且测试预言 (test oracle) 通常是以可执行的 assertions 语句（比如在 JUnit test 框架中）的形式出现。
> 即：测试预言 (test oracle) 是测试用例的一部分，是用来检查测试输入 (test input) 执行过后产生结果的正确性的。

以下为译文：

## 前言
- - -

本文为译者根据原文意译，非逐词逐句翻译。由于译者水平有限，本文不免存在遗漏或错误之处。如有疑问，请查阅[原文](https://dl.acm.org/doi/10.1145/3603269.3604834)。

## 摘要
- - -

P4Testgen，是一种针对 P4<sub>16</sub> 语言的测试预言 (test oracle)。P4Testgen 支持为任何 P4 target 生成自动测试，它对 target 数据包处理 pipeline（包括 P4 语言、架构和 externs 以及特定于 target 的扩展）的完整语义进行建模。P4Testgen 使用污点跟踪（taint tracking）和混合符号执行（concolic execution 也叫动态符号执行（dynamic symbolic execution））处理非确定性行为和复杂的 externs（例如，checksums 和 hash 函数）。它还提供通过路径选择策略，减少实现代码全覆盖所需的测试量。

我们已经为 V1model、eBPF、PNA 和 Tofino P4 架构实现了 P4Testgen 实例化。我们通过在 P4C 测试套件以及 Tofino P4 Studio 附带的示例程序中运行 P4Testgen 生成的自动化测试，并对齐进行验证。通过使用该工具，我们还确认了 BMv2 和 Tofino 的成熟生产工具链中的 25 个错误。

## 1. 介绍 
- - -

我们提出 P4Testgen，这是一种针对 P4<sub>16</sub> 语言的可扩展测试预言 (test oracle)。给定一个 P4 程序和充足的时间，它就会生成一组详尽的测试用例，涵盖 P4 程序中的每个可达语句。每个测试用例都包含用于测试的输入报文、控制平面配置以及预期的输出报文格式。

P4Testgen 通过生成测试用例来验证 P4 程序的实现逻辑。此类测试确保执行 P4 代码的设备（通常称为 “target”）及其工具链（例如，编译器、控制平面和各种 API 层）实现 P4 程序的指定行为。

P4 芯片制造商可以通过 P4Testgen 生成的测试用例用于例验证与其芯片设备相关的工具链，P4 编译器编写者可以通过 P4Testgen 生成的测试用例用于优化调优和代码转换，网络开发者可以通过 P4Testgen 生成的测试用例检查固定功能和可编程 target 是否实现 P4 程序中的指定行为。

为指定的 P4 程序生成一组详尽的测试用例的想法并不新鲜。但之前的工作主要集中在特定的 P4 架构上，例如，p4pktgen 主要针对 BMv2 target，Meissa 和 p4v 主要针对 Tofino target，而 SwitchV 主要针对具有固定功能交换芯片。这些工具只针对于特定 target 主要原因是开发工作较难。构建 P4 验证工具需要同时理解：
* (i) P4 语言；
* (ii) 形式化验证方法；
* (iii) target 的特定行为；

即使是针对单一的 target，同时寻找满足这三个要求的开发人员也已经很难，寻找能够为所有 target 设计通用工具的开发人员将会更加困难。这样导致的结果是，P4 生态变得支离破碎。如今大多数 P4 target 都缺乏足够的测试工具，并且针对一种 target 开发的工具很难移植到其他 target。

这种 P4 生态的分裂完全是可以避免的，虽然在某些情况下可能需要开发针对于特定 target 的工具，但在通常情况下（为给定程序生成 input-output 对），可以从 P4 语言的语义中推导出测试用例。为验证工具开发一个通用的开源平台有几个好处：
* 首先，通用软件基础设施（词法分析器（lexer）、解析器（parser）、类型校验器（type checker）等）和实现 P4 核心语言语义的解释器只需实现一次即可在多种工具之间共享。
* 其次，因为它是开源的，开发者可以改进并回馈给 P4Testgen ，从而使整个社区受益。

P4Testgen 在开源工具中结合了多种技术以适配其在生产环境中使用。
* 首先，P4Testgen 提供了一个可扩展框架来定义整个程序的语义，将 P4 代码的标准规范语义与其执行 target 的语义相结合。 P4 程序通常由多个 P4 代码块组成，这些 P4 代码块由特定于架构的元素分隔。 P4Testgen 基于开源的 P4 编译器（P4C）精心设计了一个解释器，并通过该解释器成为第一个为整个 P4 程序语义提供可扩展框架的工具。

* 其次，虽然 P4Testgen 最终使用 SMT 求解器（solver）来生成测试用例，但它还可以处理难以使用 SMT 求解器建模的复杂函数（例如 checksums 和未定义值、随机数等）。为了实现这一点，P4Testgen 使用污点跟踪、混合符号执行和数据包大小动态调整（packet-sizing）的精确模型来准确地在 bit 级粒度上对程序的语义进行建模。

* 第三，P4Testgen 提供了先进的路径选择策略，可以有效地生成针对所有 P4 语句的覆盖测试，即使面对遭受路径爆炸的大型 P4 程序也可以生成有效的覆盖测试。与之前的论文相比，这些策略可以完全自动化的生成，并且不需要代码注解（annotations）就可以有效使用。

P4Testgen 的关键技术创新如下：
* （1）**针对整个程序的语义**：大多数 P4 target 执行的处理程序并不仅仅是标准的 P4 规范程序，而是特定于 target 的 P4 程序。 P4Testgen 使用 pipeline 模板将整个 pipeline 的行为简洁地描述为 P4 可编程块和 target 特定元素的组合。
* （2）**特定于 target 的扩展**：许多设备厂商的 P4 target 都或多或少的的偏离了 P4<sub>16</sub> 语言规范。为了适配这些偏差，P4Testgen 的可扩展解释器支持通过特定于 target 的 P4 扩展来覆盖默认的 P4 行为，包括初始化语义和支持数据包大小动态调整（packet-sizing）的复杂模型，该模型针对不同的 target ，在处理过程中动态的修改数据包的目标。
* （3）**污点分析**：target 在测试过程中可能表现出不确定性的行为，从而无法正确预测测试结果。为了确保生成测试的可靠性，P4Testgen 使用污点分析来跟踪测试输出中的非确定性部分。
* （4）**混合符号执行**：某些 target 的特有 feature，无法使用 SMT 求解器对齐很容易得进行建模。P4Testgen 使用混合符号（concolic execution）来对 hash 函数和 checksums 等特性进行建模。
* （5）**路径选择策略**：真实的 P4 程序通常具有大量的分支路径，从而无法进行完整的代码路径覆盖。 P4Testgen 提供启发式路径选择策略，可以实现完整的语句覆盖，并且通常会比其他方法少几个数量级的测试用例。

为了验证我们的 P4Testgen 的设计，我们针对 5 个不同的真实 target 及其相应的 P4 架构进行了实例化：针对于 BMv2 target 的 v1model 架构、针对于 Linux 内核 的 ebpf_model 架构、针对于 DPDK SoftNIC 的 pna 架构、针对于 Tofino 1 芯片 target 的 tna 架构以及 针对于 Tofino 2 芯片的 t2na 架构。所有的 5 个实例都实现了整个程序语义，无需修改 P4Testgen 的核心部分代码。我们通过对基于上面所有列出架构的 P4 程序生成 input-output 测试来测试 P4Testgen 测试预言本身的正确性。使用对应的 target 工具链执行 P4Testgen 的测试，我们在 Tofino 编译器工具链中发现了 17 个错误，在 BMv2 的工具链中发现了 8 个错误。 

P4Testgen 项目路径如下：
[https://p4.org/projects/p4testgen](https://github.com/p4lang/p4c/tree/main/backends/p4tools/modules/testgen)

## 2. 动机与挑战
- - -
P4 提供了指定网络行为的新功能，但这种灵活性是有代价的：网络所有者现在必须使用比固定功能设备更大、更复杂的工具链。因此，随着 P4 生态系统的成熟，人们更加关注被放置在用于验证 P4 实现的工具上 [1,6,19,45,52,61,74,77]，通常通过进行输入输出测试。

乍一看，为给定的 P4 程序生成测试的任务似乎相对简单。先前的工作，例如 p4pktgen [52]、p4v [46]、P4wn [39]、Meissa [77] 和 SwitchV [1] 已经表明，可以使用编程语言和软件工程的技术自动生成测试。文献[31,42,63]。具体细节因工具而异，但基本思想是首先使用符号执行遍历程序中的路径，收集符号环境和路径约束，然后使用一阶定理证明器（即 SAT /SMT 求解器）来计算可执行测试。定理证明者填充来自符号环境的输入输出数据包以满足路径约束，并计算执行所选路径所需的控制平面配置，例如，转发匹配动作表中的条目。



## 参考
- - -
* [P4Testgen: An Extensible Test Oracle For P4](https://dl.acm.org/doi/10.1145/3603269.3604834)
* [Augmenting automatically generated unit-test suites with regression oracle checking](https://dl.acm.org/doi/10.1007/11785477_23)

## 公众号：Flowlet
- - -

<img src="/img/qrcode_flowlet.jpg" width = 30% height = 30% alt="Flowlet" align=center/>

- - -