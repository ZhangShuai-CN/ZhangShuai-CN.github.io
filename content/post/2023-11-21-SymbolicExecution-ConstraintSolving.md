---
layout:     post
title:      "符号执行 (Symbolic Execution) 与约束求解 (Constraint Solving)"
subtitle:   "符号执行与约束求解"
description: "Symbolic Execution and Constraint Solving"
excerpt: ""
date:       2023-11-21 01:01:01
author:     "张帅"
image: "/img/2023-11-21-SymbolicExecution-ConstraintSloving/background.jpg"
showtoc: true
draft: true
tags:
    - Symbolic Execution
    - Constraint Sloving
categories: [ Tech ]
URL: "/2023/11/21/SymbolicExecution-ConstraintSloving/"
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

笔者最近在做通过符号执行（Symbolic Execution）与约束求解器（Constraint Solver）来自动生成 P4 程序的测试用例，符号执行属于形式化验证（Formal Verification）类型的方法技术。

根据软件测试 7 项基本原则中的第一条：Testing can show that defects are present, but cannot prove that there are no defects（测试只能证明软件有 Bug，但不能证明软件没 Bug），因此有必要针对软件程序通过形式验证（Formal Verification）的方式（即通过数学方法）来严格的证明系统没 Bug。

![](/img/2023-11-21-SymbolicExecution-ConstraintSolving/figure1-7-Testing-Principles.png)

本文为**软件分析学科**中符号执行（Symbolic Execution）与约束求解（Constraint Solving）子系统的概念论述。

## 前言
- - -


## 1. 一号标题
- - -
一号标题 ...

### 1.1 二号标题
- - -
二号标题 ...

#### 1.1.1 三号标题
- - -
三号标题 ...

1. 字体反显高亮

    `字体反显高亮`

2. 超链接

    [超链接](https://)

3. 注释

    [comment]: #1-一号标题 (注释 ...)
    [comment]: #11-二号标题 (注释 ...)
    [comment]: #111-三号标题 (注释 ...)
    [comment]: # (注释 ...)
    <!-- 这是注释 -->

4. 代码块高亮

```c {linenos=table, linenostart=1, hl_lines=[2 "2-2"]}
int main(int argc, char **argv) {
    printf("Hello World!");
    return 0;
}
```
5. 区块

> 最外层
>> 中间层
>>> 最内层

6. 表格


|| column 1 | column 2 | column 3 |
|---|:---|:---:|---:|
| **row 1** | 11 | 12 | 13 |
| **row 2** | &#124; | - | 2 <br /> 3 |
| **row 3** | | |

123[^1]

[^1]: 123

123456.<p> 456

:joy:

== 123 ==
http://www.example.com
`http://www.example.com`

7. 上下标
上标：a<sup>2</sup>
下标：a<sub>2</sub>

8. 圆圈数字
① ② ③ ④ ⑤ ⑥ ⑦ ⑧ ⑨ ⑩

## 参考
- - -
* [Reference 1](https://)
* [Reference 2](https://)

## 公众号：Flowlet
- - -

<img src="/img/qrcode_flowlet.jpg" width = 30% height = 30% alt="Flowlet" align=center/>

- - -