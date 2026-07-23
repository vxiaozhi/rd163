+++
title = "Linux 中的虚拟网络接口"
date = "2025-01-12"
lastmod = "2025-01-12"
subtitle = "tun/tap、bridge、veth、macvlan、ipvlan、vlan、vxlan/geneve 一次看懂"
description = "系统梳理 Linux 内核中常见的虚拟网络接口:tun/tap、ipip 隧道、veth、bridge、macvlan、ipvlan、vlan 以及 vxlan/geneve 等 overlay 协议的原理、用途与适用场景。"
author = "小智晖"
authors = ["小智晖"]
categories = ["server"]
tags = ["server", "linux", "network", "虚拟网络", "容器网络", "隧道"]
keywords = ["虚拟网络接口", "tun/tap", "veth", "bridge", "macvlan", "ipvlan", "vxlan", "geneve"]
toc = true
draft = false
+++

## tun/tap

- 对应字符设备 `/dev/net/tun`。
- 是操作系统内核中的虚拟网络设备，由用户层程序提供数据的接收与传输。
- 普通的物理网络接口如 `eth0`，它的两端分别是内核协议栈和外面的物理网络。而对于 TUN/TAP 虚拟接口如 `tun0`，它的一端一定连接着用户层程序，另一端则视配置方式的不同而变化，可以直连内核协议栈，也可以是某个 bridge。
- TUN 和 TAP 的区别在于工作的网络层次不同：用户程序通过 TUN 设备只能读写网络层的 IP 数据包，而 TAP 设备则支持读写链路层的数据包（通常是以太网数据包，带有 Ethernet header）。
- TUN 与 TAP 的关系，就类似于 socket 与 raw socket。
- TUN/TAP 应用最多的场景是 VPN 代理，比如 clash、tun2socks。

## ipip

即 IPv4 in IPv4，在 IPv4 报文的基础上再封装一个 IPv4 报文。

Linux 原生支持多种三层隧道，其底层实现原理都是基于 tun 设备。我们可以通过命令 `ip tunnel help` 查看 IP 隧道的相关操作。Linux 原生共支持 5 种 IP 隧道：

- **ipip**：即 IPv4 in IPv4，在 IPv4 报文的基础上再封装一个 IPv4 报文。
- **gre**：即通用路由封装（Generic Routing Encapsulation），定义了在任意一种网络层协议上封装其他任意一种网络层协议的机制，IPv4 和 IPv6 都适用。
- **sit**：和 ipip 类似，不同的是 sit 是用 IPv4 报文封装 IPv6 报文，即 IPv6 over IPv4。
- **isatap**：即站内自动隧道寻址协议（Intra-Site Automatic Tunnel Addressing Protocol），和 sit 类似，也是用于 IPv6 的隧道封装。
- **vti**：即虚拟隧道接口（Virtual Tunnel Interface），是 Cisco 提出的一种 IPsec 隧道技术。

## veth

- 虚拟网络接口，它和 TUN/TAP 或者其他物理网络接口一样，也都能配置 MAC/IP 地址（但并不是一定得配 MAC/IP 地址）。
- veth 接口总是成对出现，一对 veth 接口就类似一根网线，从一端进来的数据会从另一端出去。
- 其主要作用就是连接不同的网络，比如在容器网络中，用于将容器的 namespace 与 root namespace 的网桥 `br0` 相连。
- 容器网络中，容器侧的 veth 自身设置了 IP/MAC 地址并被重命名为 `eth0`，作为容器的网络接口使用，而主机侧的 veth 则直接连接在 `docker0`/`br0` 上面。
- 使用 veth 实现容器网络，一般需要结合 bridge。

## bridge

- Linux Bridge 是工作在链路层的网络交换机，由 Linux 内核模块 `bridge` 提供，它负责在所有连接到它的接口之间转发链路层数据包。
- 添加到 Bridge 上的设备被设置为只接受二层数据帧，并且转发所有收到的数据包到 Bridge 中。
- 在 Bridge 中会进行类似物理交换机的查 MAC 端口映射表、转发、更新 MAC 端口映射表这样的处理逻辑，从而数据包可以被转发到另一个接口/丢弃/广播/发往上层协议栈，由此 Bridge 实现了数据转发的功能。
- 如果使用 `tcpdump` 在 Bridge 接口上抓包，可以抓到网桥上所有接口进出的包，因为这些数据包都要通过网桥进行转发。
- 与物理交换机不同的是，Bridge 本身可以设置 IP 地址，可以认为当使用 `brctl addbr br0` 新建一个 `br0` 网桥时，系统自动创建了一个同名的隐藏 `br0` 网络接口。
- `br0` 一旦设置 IP 地址，就意味着这个隐藏的 `br0` 接口可以作为路由接口设备，参与 IP 层的路由选择（可以使用 `route -n` 查看最后一列 Iface）。
- 只有当 `br0` 设置 IP 地址时，Bridge 才有可能将数据包发往上层协议栈。
- 被添加到 Bridge 上的网卡是不能配置 IP 地址的，它们工作在数据链路层，对路由系统不可见。
- Bridge 常被用于在虚拟机、主机上不同的 namespace 之间转发数据。

## macvlan

- 目前 docker/podman 都支持创建基于 macvlan 的 Linux 容器网络。
- macvlan 是比较新的 Linux 特性，需要内核版本 >= 3.9，它被用于在主机的网络接口（父接口）上配置多个虚拟子接口，这些子接口都拥有各自独立的 MAC 地址，也可以配上 IP 地址进行通讯。
- macvlan 下的虚拟机或者容器网络和主机在同一个网段中，共享同一个广播域。
- macvlan 和 bridge 比较相似，但因为它省去了 bridge 的存在，所以配置和调试起来比较简单，而且效率也相对更高。
- macvlan 自身也完美支持 VLAN。
- 如果希望容器或者虚拟机放在主机相同的网络中，享受已经存在网络栈的各种优势，可以考虑 macvlan。
- macvlan 和 WiFi 存在兼容问题，如果使用笔记本测试，可能会遇到麻烦（原因是 802.11 帧的地址格式与多 MAC 地址不兼容，AP 会丢弃来源非物理 MAC 的帧）。

## ipvlan

- Linux 网络虚拟化：ipvlan。
- Cilium 1.9 已经提供了基于 ipvlan 的网络（beta 特性），用于替换传统的 veth+bridge 容器网络。详见 [IPVLAN based Networking (beta) - Cilium 1.9 Docs](https://docs.cilium.io/en/v1.9/concepts/networking/ipvlan/)。
- ipvlan 和 macvlan 的功能很类似，也是用于在主机的网络接口（父接口）上配置出多个虚拟的子接口。但不同的是，ipvlan 的各子接口没有独立的 MAC 地址，它们和主机的父接口共享 MAC 地址。
- 因为 MAC 地址共享，所以如果使用 DHCP，就要注意不能使用 MAC 地址做 DHCP 标识，需要额外配置唯一的 clientID。

如果遇到以下情况，请考虑使用 ipvlan：

- 父接口对 MAC 地址数目有限制，或者在 MAC 地址过多的情况下会造成严重的性能损失。
- 工作在 802.11（wireless）无线网络中（macvlan 无法和无线网络共同工作）。
- 希望搭建比较复杂的网络拓扑（不是简单的二层网络和 VLAN），比如要和 BGP 网络一起工作。
- 基于 ipvlan/macvlan 的容器网络，比 veth+bridge+iptables 的性能要更高。

## vlan

- vlan 即虚拟局域网，是一个链路层的广播域隔离技术。
- 用于切分局域网，解决广播泛滥和安全性问题。被隔离的广播域之间需要上升到第三层才能完成通讯。
- 常用的企业路由器如 ER-X 基本都可以设置 vlan，Linux 也直接支持了 vlan。
- 以太网数据包有一个专门的字段提供给 vlan 使用（802.1Q tag），vlan 数据包会在该位置记录它的 VLAN ID，交换机通过该 ID 来区分不同的 VLAN，只将该以太网报文广播到该 ID 对应的 VLAN 中。

## vxlan/geneve

- **underlay 网络**：即物理网络。
- **overlay 网络**：指在现有的物理网络之上构建的虚拟网络。其实就是一种隧道技术，将原生态的二层数据帧报文进行封装后通过隧道进行传输。
- vxlan 与 geneve 都是 overlay 网络协议，它俩都是使用 UDP 包来封装链路层的以太网帧。
- vxlan 于 2014 年标准化（RFC 7348）；geneve 则在 2020 年 11 月正式标准化为 RFC 8926（Proposed Standard）。目前 Linux/Cilium 都已经支持 geneve。
- geneve 相对 vxlan 最大的变化，是它更灵活——它的 header 长度是可变的，通过 TLV（Type-Length-Value）选项携带可扩展的元数据。
- 目前所有 overlay 的跨主机容器网络方案，几乎都是基于 vxlan 实现的（例外：Cilium 也支持 geneve）。
- 单机的容器网络，通常不需要用到 vxlan，而跨主机容器网络方案如 flannel/calico/cilium 基本都会采用 vxlan（overlay）及 BGP（underlay）实现。

## vxlan

- VxLAN 协议比原始报文多出 50 字节的内容，这会降低网络链路传输有效数据的比例。
- 新增加的 VXLAN 报文封装也引入了一个问题，即 MTU 值的设置。一般来说，虚拟机的默认 MTU 为 1500 Bytes，也就是说原始以太网报文最大为 1500 字节。这个报文在经过 VTEP 时，会封装上 50 字节的新报文头（VXLAN 头 8 字节 + UDP 头 8 字节 + 外部 IP 头 20 字节 + 外部 MAC 头 14 字节），这样一来，整个报文长度达到了 1550 字节。而现有的 VTEP 设备，一般在解封装 VXLAN 报文时，要求 VXLAN 报文不能被分片，否则无法正确解封装。这就要求 VTEP 之间的所有网络设备的 MTU 最小为 1550 字节。如果中间设备的 MTU 值不方便进行更改，那么设置虚拟机的 MTU 值为 1450，也可以暂时解决这个问题。
- 默认端口的历史：Linux 内核 3.7 版本首次实现 VXLAN 时，IANA 尚未规定标准端口，早期实现沿用了厂商事实上的 8472 端口；IANA 后来正式分配的标准端口是 **4789**，Linux 内核 3.15 起将默认值改为 4789。`ip link add type vxlan` 可通过 `dstport` 参数显式指定端口，以便与硬件 VTEP 互通。

## 参考

- [Linux 中的虚拟网络接口](https://thiscute.world/posts/linux-virtual-network-interfaces/)
- [linux 上实现 vxlan 网络](https://cizixs.com/2017/09/28/linux-vxlan/)
- [什么是 IP 隧道，Linux 怎么实现隧道通信？](https://www.cnblogs.com/bakari/p/10564347.html)
- [理解 Linux IPIP 隧道](https://cloud.tencent.com/developer/article/2350062)
- [Linux ipip 隧道技术测试二，模拟 calico 网络（三主机、单网卡、多 namespace）](http://www.asznl.com/post/83)
- [RFC 7348: Virtual eXtensible Local Area Network (VXLAN)](https://www.rfc-editor.org/rfc/rfc7348)
- [RFC 8926: Geneve: Generic Network Virtualization Encapsulation](https://www.rfc-editor.org/rfc/rfc8926)