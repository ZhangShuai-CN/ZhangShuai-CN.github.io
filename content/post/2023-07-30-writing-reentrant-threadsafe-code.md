---
layout:     post
title:      "如何编写可重入（Reentrant）且线程安全（Thread-safe）的代码 [译]"
subtitle:   "编写可重入（Reentrant）且线程安全（Thread-safe）的代码"
description: "Writing reentrant and threadsafe code"
excerpt: ""
date:       2023-07-30 01:01:01
author:     "张帅"
image: "/img/2023-07-30-writing-reentrant-threadsafe-code/background.jpg"
showtoc: true
draft: false
tags:
    - reentrant
    - thread-safe
categories: [ Tech ]
URL: "/2023/07/30/writing-reentrant-threadsafe-code/"
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

本文翻译自文章 [Writing reentrant and threadsafe code](https://www.ibm.com/docs/ar/aix/7.1?topic=programming-writing-reentrant-threadsafe-code)，由于译者水平有限，本文不免存在遗漏或错误之处。如有疑问，请查阅原文。

> **译者注：**
> 
> 文中 AIX 指：AIX（Advanced Interactive eXecutive）操作系统，是 IBM 公司开发的一款 UNIX 操作系统。

## 前言
- - -

单线程的进程中仅有一个控制流。这种进程执行的代码无需可重入或线程安全。在多线程的程序中，同一函数或资源可能被多个控制流并发访问。为保护资源完整性，多线程程序编码必须可重入且线程安全。

本节提供了一些编写可重入和线程安全程序的（指导）信息，但不包括编写线程高效程序的主题。线程高效程序是高效并行化的程序，仅可在程序设计中实现。现有的单线程程序可变得线程高效，但这需要完全地重新设计和重写。


## 1. 理解可重入和线程安全
- - -

可重入和线程安全与函数处理资源的方式有关。可重入和线程安全是两个相互独立的概念：一个函数可以仅是可重入的，可以仅是线程安全的，可以两者皆是或两者皆不是。

### 1.1 可重入
- - -

可重入函数不能为后续的调用保持静态（或全局）数据，也不能返回指向静态（或全局）数据的指针。函数中用到的所有数据，都应由函数调用者提供（不包括栈上的局部数据）。可重入函数不能调用不可重入的函数。

不可重入的函数经常（但不总是）可以通过其外部接口和用法识别。例如 strtok 是不可重入的，因为它保存着将被分隔为子串的字符串。ctime 也是不可重入的，它返回一个指向静态数据的指针，每次调用都会覆盖这些数据。


### 1.2 线程安全
- - -

线程安全的函数通过“锁”来保护共享资源不被并发地访问。“线程安全”仅关心函数的实现，而不影响其外部接口。

在 C 中，局部变量在栈上动态分配，因此，任何不使用静态数据和其它共享资源的函数就是最普通的线程安全（函数）。例如，以下函数就是线程安全的：

```c
/* threadsafe function */
int diff(int x, int y)
{
        int delta;

        delta = y - x;
        if (delta < 0)
                delta = -delta;

        return delta;
}
```
使用全局数据是线程不安全的。应为每个线程维护一份全局数据的拷贝或封装全局数据，以使对它的访问变成串行的。线程可能读取另一线程造成的错误对应的错误码。在 AIX 系统中，每个线程拥有属于自己的错误码（errno）值。

## 2. 如何编写可重入函数
- - -

在大部分情况下，不可重入的函数修改为可重入函数时，必须修改函数的对外接口。不可重入的函数不能用于多线程。此外，也许不可能让某个不可重入的函数是线程安全的。

### 2.1 返回数据
- - -

很多不可重入的函数返回一个指向静态数据的指针。这可通过两种方法避免：

* 返回从堆中动态分配的数据（即内存空间地址）。在这种情况下，调用者负责释放堆中的存储空间。其优点是不必修改函数的外部接口，但不能保证向后兼容。现有的单线程程序若不修改而直接使用修改后的函数，将不会释放存储空间，进而导致内存泄露。
* 由调用者提供存储空间。尽管函数的外部接口需要改变，仍然推荐使用这种方法。

例如，将字符串转换为大写的 strtoupper 函数实现可能如下代码片段所示：

```c
/* non-reentrant function */
char *strtoupper(char *string)
{
        static char buffer[MAX_STRING_SIZE];
        int index;

        for (index = 0; string[index]; index++)
                buffer[index] = toupper(string[index]);
        buffer[index] = 0

        return buffer;
}
```

该函数既不是可重入的，也不是线程安全的。使用第一种方法将其改写为可重入的，函数将类似于如下代码片段：

```c
/* reentrant function (a poor solution) */
char *strtoupper(char *string)
{
        char *buffer;
        int index;

        /* error-checking should be performed! */
        buffer = malloc(MAX_STRING_SIZE);

        for (index = 0; string[index]; index++)
                buffer[index] = toupper(string[index]);
        buffer[index] = 0

        return buffer;
}
```
更好的解决方案是修改接口。调用者须为输入和输出字符串提供存储空间，如下代码片段所示：

```c
/* reentrant function (a better solution) */
char *strtoupper_r(char *in_str, char *out_str)
{
        int index;

        for (index = 0; in_str[index]; index++)
        out_str[index] = toupper(in_str[index]);
        out_str[index] = 0

        return out_str;
}
```
通过使用第二种方法，不可重入的C标准库子例程被改写为可重入的。见下文讨论。

### 2.2 为连续调用保持数据
- - -
（可重入函数）不应为后续调用保持数据，因为不同线程可能相继调用同一函数。若函数需要在连续调用期间维持某些数据，如工作缓存区或指针，则该数据（资源）应由调用方函数提供调用者应该提供。

考虑如下示例。函数返回字符串中的连续的小写字符。字符串仅在第一次调用时提供，类似 strtok 。当遍历至字符串末尾时，函数返回 0。函数实现可能如下代码片段所示：

```c
/* non-reentrant function */
char lowercase_c(char *string)
{
        static char *buffer;
        static int index;
        char c = 0;

        /* stores the string on first call */
        if (string != NULL) {
                buffer = string;
                index = 0;
        }

        /* searches a lowercase character */
        for (; c = buffer[index]; index++) {
                if (islower(c)) {
                        index++;
                        break;
                }
        }
        return c;
}
```
该函数是不可重入的。为使它可重入，静态数据（即index变量）需由调用者来维护。该函数的可重入版本实现可能如下代码片段所示：

```c
/* reentrant function */
char reentrant_lowercase_c(char *string, int *p_index)
{
        char c = 0;

        /* no initialization - the caller should have done it */

        /* searches a lowercase character */
        for (; c = string[*p_index]; (*p_index)++) {
                if (islower(c)) {
                        (*p_index)++;
                        break;
                  }
        }
        return c;
}
```

函数的接口和用法均发生改变。调用者每次调用时必须提供该字符串，并在首次调用前将索引（index）初始化为0，如下代码片段所示：

```c
char *my_string;
char my_char;
int my_index;
...
my_index = 0;
while (my_char = reentrant_lowercase_c(my_string, &my_index)) {
        ...
}
```

## 3. 如何编写线程安全的函数
- - -
在多线程程序中，所有被多线程调用的函数都必须是线程安全的。然而，在多线程程序中可变通地使用线程不安全的子例程。注意，不可重入的函数通常都是线程不安全的，但将其改写为可重入时，一般也会使其线程安全。

### 3.1 对共享资源加锁
- - -

使用静态数据或其它任何共享资源(如文件或终端)的函数，必须对这些资源加“锁”来串行访问，以使该函数线程安全。例如，以下函数是线程不安全的：

```c
/* thread-unsafe function */
int increment_counter()
{
        static int counter = 0;

        counter++;
        return counter;
}
```

为使该函数线程安全，静态变量 counter 需要被静态锁保护，如下例（伪代码）所示：

```c
/* pseudo-code threadsafe function */
int increment_counter();
{
        static int counter = 0;
        static lock_type counter_lock = LOCK_INITIALIZER;

        pthread_mutex_lock(counter_lock);
        counter++;
        pthread_mutex_unlock(counter_lock);
        return counter;
}
```

在使用线程库的多线程应用程序中，应使用信号量互斥锁（mutex）来串行访问共享资源，独立库可能需要工作于线程上下文之外，因此使用其他类型的锁。

### 3.2 线程不安全函数的变通方案
- - -
多线程变通地调用线程不安全函数是可能的。这在多线程程序使用线程不安全库时尤其有用，如用于测试或待该库的线程安全版本可用时再予以替换。该变通方案会带来一些开销，因为需对整个函数甚至一组函数进行串行化。

* 对该库使用全局锁，每次使用库（调用库内子例程或使用库内全局变量）时均对其加锁，如下伪代码片段所示：

```c
/* this is pseudo code! */

lock(library_lock);
library_call();
unlock(library_lock);

lock(library_lock);
x = library_var;
unlock(library_lock);
```

该方案可能产生性能瓶颈，因为任一时刻仅有一个线程可访问库的任一部分。仅当不常访问库，或作为初步快速实现的权宜之计时可以采用该方案。

* 对每个库组件（例程或全局变量）或一组组件使用锁，如下例伪代码片段所示：

```c
/* this is pseudo-code! */

lock(library_moduleA_lock);
library_moduleA_call();
unlock(library_moduleA_lock);

lock(library_moduleB_lock);
x = library_moduleB_var;
unlock(library_moduleB_lock);
```
该方案实现相比前者稍微复杂，但可提高性能。

该方案应仅用于应用程序而非库，故可用互斥锁对库加锁。


## 4. 可重入和线程安全库
- - -
可重入和线程安全库广泛应用于并行（和异步）编程环境，而不仅仅用于线程内。因此，总是使用和编写可重入和线程安全的函数是良好的编程实践。


### 4.1 使用函数库
- - -

AIX 操作系统附带的几个代码库是线程安全的。在 AIX 当前版本中，以下库是线程安全的。

* C 标准函数库（libc.a）
* BSD兼容函数库（libbsd.a）

某些标准 C 函数是不可重入的，如 ctime 和 strtok 。它们的可重入版本函数名是原始子例程名添加“_r”后缀。

在编写多线程程序时，应使用子例程的可重入版本来替代原有版本。例如，以下代码片段：

```c
token[0] = strtok(string, separators);
i = 0;
do {
        i++;
        token[i] = strtok(NULL, separators);
} while (token[i] != NULL);
```

在多线程程序中应替换为以下代码片段：

```c
char *pointer;
...
token[0] = strtok_r(string, separators, &pointer);
i = 0;
do {
        i++;
        token[i] = strtok_r(NULL, separators, &pointer);
} while (token[i] != NULL);
```
线程不安全库可用于单线程程序中。程序员必须确保使用该库的线程唯一性；否则，程序行为不可预料，甚至可能崩溃。

### 4.2 改写函数库
- - -
以下几点展示了将现有库转换为可重入和线程安全库的主要步骤（仅适用于 C 语言代码库）。

* 识别对外的全局变量。这些变量通常在头文件中用 extern 关键字定义。
    
    应封装对外的全局变量。该变量应改为私有（在库源代码内用 static 关键字定义）。应创建（读写）该变量的子程序。

* 识别静态变量和其他共享资源。静态变量通常用 static 关键字定义。

    任一共享资源均应与锁关联。锁的粒度及数目会影响库的性能。可使用“一次性初始化”特性（如 pthread_once ）来方便地初始化锁。

* 识别不可重入函数并使之变为可重入函数。见“编写可重入函数”。
* 识别线程不安全函数并使之变为线程安全函数。见“编写线程安全函数”。


## 参考
- - -
* [Writing reentrant and threadsafe code](https://www.ibm.com/docs/ar/aix/7.1?topic=programming-writing-reentrant-threadsafe-code)


## 公众号：Flowlet
- - -

<img src="/img/qrcode_flowlet.jpg" width = 30% height = 30% alt="Flowlet" align=center/>

- - -