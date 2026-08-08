# Asterisk PBX 简介

诸如 FreePBX 和 Issabel 等即开即用型发行版的普及度近期有所提升。在本书中，我们将介绍经典的 Asterisk，它是理解这些发行版的基石。Asterisk PBX 是一款开源软件，能够将普通的 PC 转变为功能强大的多协议 PBX。在本章中，我们将了解这项新技术所带来的可能性及其基本架构。

## 目标

在本章结束时，你应该能够：

- 解释 Asterisk 是什么以及它的功能；
- 描述 Digium™ 及其继任者 Sangoma 的角色；
- 识别 Asterisk 的基本架构及其组件；
- 指出几种使用场景；以及
- 确定获取信息和帮助的来源。

## 什么是 Asterisk

Asterisk 是一款开源的 PBX 软件，它能将一台普通计算机转变为功能齐全的 PBX，适用于家庭用户、企业、VoIP 服务提供商和电话公司。Asterisk 既是一个开源社区，也是一个由 Sangoma Technologies（于 2018 年收购了 Digium）赞助的项目。您可以自由使用和修改 Asterisk 以满足您的需求。Asterisk 实现了 PSTN 和 VoIP 网络之间的实时连接。由于 Asterisk 的功能远不止于 PBX，您不仅可以对现有的 PBX 进行卓越的升级，还可以实现电话通信领域的新功能，例如：

- 通过宽带互联网将居家办公的员工连接到办公室 PBX；
- 通过 IP 网络、专用网络甚至互联网本身连接位于不同地点的多个办公室；
- 为您的员工提供与 Web 和电子邮件集成的 voicemail；
- 构建诸如 IVR 之类的应用程序，以连接到您的订购系统或其他应用程序；
- 让出差用户通过简单的宽带或 VPN 连接，从任何地方访问公司 PBX；以及
- 更多功能……

Asterisk 包含了几种以前仅在高端系统中才能找到的高级资源，例如：

- 为在呼叫队列中等待的客户提供保持音乐，支持媒体流和 MP3 文件；
- 呼叫队列，代理团队可以通过该功能接听电话并监控队列；
- 与文本转语音和语音识别的集成；
- 传输到文本文件和 SQL 数据库的详细记录；以及
- 通过数字和模拟线路实现的 PSTN 连接。

## 什么是 AsteriskNOW（历史版本）和 FreePBX

Asterisk 的最纯粹形式，也被称为“经典 Asterisk”（Debian 软件包命名），本身被认为更像是一种开发工具，而非成品。AsteriskNOW 是一项旨在将 Asterisk 转换为软件一体机的计划。该发行版包含了作为操作系统的 CentOS 和作为图形界面的 FreePBX。AsteriskNOW 现已停止维护。

如今，标准的 Asterisk 开箱即用发行版是 **FreePBX**（由 Sangoma 维护），它将 Asterisk 与基于 Web 的管理 GUI 和模块生态系统捆绑在一起。FreePBX 根据 GPL 许可协议授权，可以从 www.freepbx.org 免费下载。对于商业部署，Sangoma 还提供 **FreePBX Distro**（一个完整的 Linux 镜像）及其商业产品 **PBXact**。

## Digium™ 和 Sangoma 的角色

Digium 是一家位于阿拉巴马州亨茨维尔的公司，自 1999 年成立以来，一直是 Asterisk 的创建者和主要开发者。除了作为 Asterisk 开发的主要赞助商外，Digium 还为 Asterisk PBX 生产电话接口卡和其他硬件，并创建了诸如 Switchvox（针对中小企业市场）等商业产品。2018 年，Digium 被加拿大统一通信公司 **Sangoma Technologies** 收购。自收购以来，Sangoma 继续赞助 Asterisk 的开发并担任其主要管理方，在 www.asterisk.org 维护该开源项目。

从历史上看，Digium 曾以三种类型的许可协议提供 Asterisk：

- 通用公共许可证 (GPL) Asterisk。这是使用最广泛的版本。它包含所有功能，并可根据 GPL 许可条款免费使用和修改。
- Asterisk Business Edition 是 Asterisk 的商业版本。一些公司使用商业版是因为他们不想或不能使用 GPL 许可——通常是因为他们不想将其源代码与 Asterisk 一起发布。**注意：** Asterisk Business Edition 已停产；如今 Asterisk 仅在 GPL 下分发。
- Asterisk OEM 许可。在 Digium 停止零售 Asterisk Business Edition 后，它继续向 OEM 客户（即那些希望在 Asterisk 之上构建专有产品而不根据 GPL 发布其自身源代码的设备供应商）许可该商业版本。

### Zapata 项目及其与 Asterisk 的关系

Zapata 项目由 Jim Dixon 开发，他同时也负责了与 Asterisk 一起使用的革命性硬件设计。该硬件也是开源的；因此，任何公司都可以使用它，如今有几家制造商生产与此架构兼容的卡。

Zapata 项目产生了一种名为 Zaptel 的架构，后来更名为 DAHDI (Digium/Asterisk Hardware Device Interface)。该架构的主要优点之一是能够利用 PC CPU 来处理媒体流、回声消除和转码。相比之下，大多数现有的卡使用数字信号处理器 (DSP) 来执行这些任务。使用 PC CPU 代替专用 DSP 极大地降低了板卡的成本。因此，这些卡比其他制造商之前提供的接口要便宜得多。另一方面，这些卡需要大量的 CPU 资源；对 PC CPU 的不当使用会显著影响语音质量。最近，Digium 推出了一款协处理器卡，它使用 DSP 来编码和解码 G.729 和 G.723，从而为大量通道提供了更好的可扩展性。

## 为什么选择 Asterisk？

我记得我第一次接触 Asterisk 的情景。通常，人们对新事物的最初反应——尤其是当它与你已知的知识产生竞争时——往往是排斥！这正是 2003 年发生在我身上的事情。当时 Asterisk 正在与我向客户销售的一款解决方案（4 E1 VoIP Gateway）竞争，而它的价格竟然比我当时销售的方案便宜了十倍。这种巨大的价格差异促使我开始研究 Asterisk，试图找出它潜在的缺陷和短板。例如，我发现当时的 PC CPU 无法支持 120 路 g.729 同时通话，最终，我凭借我的 Gateway 解决方案赢得了那个项目。

然而，这次经历让我发现，Asterisk 可以为我的客户群解决各种非常昂贵的问题。我们当时正为 IVR、统一消息、通话录音和拨号器的高昂报价而苦恼；通过适当的规模规划，CPU 的问题是可以规避的。事实上，仅仅三年时间，Asterisk 就成为了我公司的旗舰产品（我甚至决定专门为 Asterisk 业务成立了另一家公司）。在我看来，Asterisk 是电信领域的一场革命，它之于 IP 电话，正如 Apache 之于 Web 服务。

### 极高的成本削减

如果你将传统的 PBX 与 Asterisk 在数字接口和电话方面进行比较，Asterisk 仅比那些 PBX 稍微便宜一点。然而，当你添加 voicemail、ACD、IVR 和 CTI 等高级功能时，Asterisk 的性价比优势就真正体现出来了。有了这些高级功能，Asterisk 比传统 PBX 便宜得多。事实上，将 Asterisk PBX 与低端模拟 PBX 进行比较是不公平的，因为 Asterisk 提供了许多低端模拟系统所不具备的功能。

### 电话系统控制权与独立性

客户经常提到的 Asterisk 的优势之一是它所提供的独立性。如今的一些制造商甚至不向客户提供系统密码或配置文档。通过 Asterisk 的“自己动手”模式，用户可以获得完全的自由；作为额外奖励，用户还可以访问标准接口。

### 简单且快速的开发环境

Asterisk 可以使用 PHP 和 Perl 等脚本语言，通过 AMI 和 AGI 接口进行扩展。Asterisk 是开源的，用户可以修改其源代码。其源代码主要使用 ANSI C 编程语言编写。

### 功能丰富

Asterisk 拥有许多在传统 PBX 中要么找不到、要么作为可选功能的特性（例如 voicemail、CTI、ACD、IVR、内置的音乐保持以及录音）。在某些平台上，这些功能的成本甚至超过了平台本身的价格。

### 电话上的动态内容

Asterisk 使用 C 语言以及当今开发环境中常见的其他语言进行编程。提供动态内容的可能性几乎是无限的。

### 灵活且强大的 dialplan

Asterisk 的另一个突破是其强大的 dialplan。在传统 PBX 中，即使是像最小成本路由 (LCR) 这样简单的功能，要么不可行，要么是可选的。而在 Asterisk 中，选择最佳路由既简单又清晰。

### 运行在 Linux 之上的开源软件

Asterisk 最伟大的特性之一是它的社区。目前有多种资源可供使用，包括官方的 Asterisk 文档 (docs.asterisk.org)、社区维护的 VoIP-Info wiki (www.voip-info.org <http://www.voip-info.org>)、电子邮件分发列表和论坛。随着 Asterisk 的普及，漏洞会被迅速发现并修复。凭借庞大的用户群和活跃的开发团队，Asterisk 成为世界上测试最广泛的 PBX 平台之一，这有助于保持代码库的稳定和成熟。

### Asterisk 架构的局限性

Asterisk 的一些局限性源于对 Zapata 电话设计的使用。在这种设计中，Asterisk 使用 PC CPU 来处理语音通道，而不是其他平台中常见的专用数字信号处理器 (DSP)。虽然这极大地降低了硬件接口的成本，但系统变得依赖于 PC CPU。我的建议是在专用机器上运行 Asterisk，并在硬件规模规划上保持保守。你也可以在独立的 VLAN 中使用 Asterisk，以避免消耗 CPU 的过度广播（由环路或病毒引起的广播风暴）。来自多家供应商的一些较新的接口卡现在开始包含用于处理回声消除、codec 和其他功能的 DSP，这将使 Asterisk 变得更加出色。

## 关于 Asterisk PBX 的主要异议

人们在采用 Asterisk 时常会提出一些异议，我们将在本节中予以解答。

### Asterisk 的市场份额太小

市场份额通常是通过售出的 PBX 数量来衡量的。这些统计数据通常来自最大的分销商。Asterisk 是一款免费软件，用户无需通过任何销售记录即可下载并部署，因此在这些统计数据中，它的数量被系统性地低估了。即便如此，Asterisk 在全球范围内仍拥有庞大的装机量——从单服务器办公 PBX 到大型运营商和呼叫中心部署——并且依然是开源 PBX 生态系统（包括 FreePBX 等开箱即用的发行版）背后的主导引擎。

### 如果它是免费的，制造商如何生存？

事实上，传统意义上的开源软件制造商并不存在。Digium 自 1999 年以来开发了 Asterisk，通过销售电话接口卡、Switchvox 等商业 PBX 产品以及相关软件来维持自身运营。2018 年，Sangoma Technologies 收购了 Digium。Sangoma 继续资助 Asterisk 的开发，并通过商业产品（FreePBX 商业模块、PBXact、Switchvox）、硬件销售和专业服务来创造收入。

### 很难找到技术支持！

Sangoma 通过其合作伙伴生态系统以及直接通过其产品供应，为 Asterisk 提供商业技术支持。一个由认证专业人员组成的全球网络提供一线支持和专业服务。社区支持依然活跃，用户可以通过 www.asterisk.org 上的 Asterisk 论坛和邮件列表获取帮助。

### Asterisk 支持超过 200 个 extension 吗？

是的，绝对支持。一台配置合理的 Asterisk 服务器可以处理大量的 extension，并且 Asterisk 可以通过在多台服务器之间分配用户来实现负载均衡和故障转移，从而进一步扩展，支持大型多站点部署。

### 只有“极客”才能安装 Asterisk

有了 FreePBX（可作为 Sangoma 提供的独立发行版），即使是对 Linux 了解有限的专业人员也能够安装和配置中等复杂程度的 PBX。在 GUI 的帮助下，只需几个小时即可配置好整个 PBX。

### 如果服务器故障了怎么办？

Asterisk 的主要优势之一是其在容错系统中运行的能力。让两台服务器并行运行既简单又经济。我敢说，您可以尝试用传统的 PBX 来实现这一点！

### 我们公司不使用开源软件

您的公司可能在不知不觉中就已经在使用开源软件了。许多设备都使用 Linux 作为其操作系统。此外，Sangoma 及其认证合作伙伴网络还提供商业支持和托管部署服务。

### 不建议使用 PC 的 CPU 来处理信令和媒体

Asterisk 使用服务器的 CPU 来处理语音通道的信令和媒体，而不是使用专用的 DSP。虽然这可以将成本降低多达五倍，但它使系统依赖于主 CPU 的性能。通过正确的配置，Asterisk 完全有能力处理大容量业务。如果您仍然希望将主 CPU 从这些任务中解放出来，您也可以使用硬件回声消除，甚至可以使用基于 DSP 的转码卡，例如 Sangoma（前身为 Digium）的 TC400B。

## Asterisk 架构

本节将解释 Asterisk 的架构是如何工作的。下图展示了基本的 Asterisk 架构。接下来，我们将解释与架构相关的概念，包括 channel、codec 和 application。

![Asterisk 架构](../images/01-introduction-fig01.png)

### Channels

channel 等同于电话线，但以数字格式呈现。它通常由模拟或数字 (TDM) 信令系统，或者 codec 与信令协议的组合（例如 SIP-GSM、IAX-uLaw）组成。最初，所有的电话连接都是模拟的，容易受到回声和噪声的影响。后来，大多数系统转换为数字系统，在大多数情况下，模拟声音通过脉冲编码调制 (PCM) 转换为数字格式。这种格式允许以 64 kbps 的速率进行语音传输，且无需压缩。

与 PSTN 进行交互的 channel：

- `chan_dahdi`：来自 Sangoma（前身为 Digium）、Xorcom 等厂商的模拟 (FXO/FXS) 和数字 (E1/T1/PRI) TDM 卡。与 DAHDI 分开构建 —— 请参阅 *Legacy channels* 一章。

与 VoIP 进行交互的 channel：

- `chan_pjsip`：SIP —— Asterisk 22 LTS 中主要且唯一的 SIP channel 驱动程序。拨号字符串：`PJSIP/endpoint_name`。（**注意：** 旧的 `chan_sip` 已在 Asterisk 21 中移除，在 Asterisk 22 中不存在。有关配置，请参阅 *Building your first PBX with PJSIP*。）
- `chan_iax2`：IAX2 协议 —— 仍然随 Asterisk 22 发布，但属于 legacy；对于新部署，首选 SIP/PJSIP。拨号字符串：`IAX2/peer`。
- `chan_unistim`：Nortel/Avaya UNISTIM 电话。仍然可用（扩展支持），但很少使用。

较旧的 VoIP channel 不再是标准 Asterisk 22 构建的一部分：`chan_h323` (H.323) 仅作为社区 `ooh323` 插件存在，而 `chan_mgcp` (MGCP) 和 `chan_skinny` (Cisco SCCP) 已被弃用并从现代 channel 集中删除。如果您必须与这些协议进行互通，通常的做法是在 Asterisk 前面放置一个网关。

其他 channel：

- **Local**：一种伪 channel（内置于核心中），它会回环到不同 context 的 dialplan 中 —— 对于递归路由和将呼叫分发到多个目的地非常有用。拨号字符串：`Local/extension@context`。

### Codec 和 codec 转换

我们通常尝试在数据网络中尽可能多地放置语音连接。Codec 在数字语音中实现了新功能，包括压缩，这是最重要的功能之一，因为它允许超过 8 比 1 的压缩率。许多 codec 还定义了诸如语音活动检测（静音抑制）、丢包隐藏和舒适噪声生成等功能，尽管 Asterisk 本身并不生成舒适噪声或执行静音抑制。Asterisk 支持多种 codec，并且可以在它们之间进行透明转换。在内部，当 Asterisk 需要从一种 codec 转换为另一种 codec 时，它使用 slinear 作为流格式。Asterisk 中的某些 codec 仅支持透传模式；这些 codec 无法进行转换。要验证系统中安装了哪些 codec，可以使用控制台命令：

```
CLI>core show translation
```

支持以下 codec：

- G.711 ulaw (USA) - (64 Kbps)。
- G.711 alaw (Europe) - (64 Kbps)。
- G.722 (High Definition) – (64 Kbps)
- G.723.1 - 仅透传模式
- G.726 - (16/24/32/40kbps)
- G.729 - 由 Sangoma 分发的二进制 codec 模块；下载免费，但合法使用需要购买每 channel 许可 (8Kbps)
- GSM - (12-13 Kbps)
- iLBC - (15 Kbps)
- LPC10 - (2.4 Kbps)
- Speex - (2.15-44.2 Kbps)
- Opus - (6-510 Kbps)

### Protocols

只要数据能自行找到通往另一部电话的路径，将数据从一部电话发送到另一部电话应该是很容易的。不幸的是，情况并非如此，因此需要一种信令协议来在电话之间建立连接、发现终端设备并实现电话信令。SIP 是现代部署中的主流信令协议，也是 Asterisk 22 LTS 中唯一可用的 SIP channel（通过 chan_pjsip）。IAX2 仍然可用，但被视为 legacy。Asterisk 支持以下协议。

- SIP — 通过 `chan_pjsip`
- IAX2 — legacy，仍随 Asterisk 22 发布
- UNISTIM — Nortel/Avaya 电话（扩展支持）
- H.323、MGCP 和 SCCP (Cisco Skinny) — 不再包含在标准 Asterisk 22 构建中的 legacy 协议（H.323 仅通过社区 `ooh323` 插件提供）

### Applications

要将呼叫从一部电话桥接到另一部电话，需要使用 application dial()。大多数 Asterisk 功能（例如 voicemail 和会议）都是作为 application 实现的。您可以使用 core show applications 控制台命令查看可用的 Asterisk application。

```
CLI>core show applications
```

您可以从 Asterisk add-ons、第三方提供商添加 application，甚至可以添加您自己开发的 application。

## Asterisk 系统概述

Asterisk 是一个开源 PBX，它充当混合型 PBX，集成了 TDM 和 IP 电话等技术。Asterisk 已经准备好实现诸如 IVR 和 ACD 等功能；此外，如前所述，它还支持开发新的应用程序。此图展示了 Asterisk 如何使用模拟和数字接口连接到 PSTN 和现有的 PBX，并支持模拟电话和 IP 电话。它可以充当 SoftSwitch、媒体网关、voicemail 以及音频会议系统，并且内置了音乐保持（music on hold）功能。

![Asterisk 系统概述](../images/01-introduction-fig02.png)

## 比较旧世界与新世界

在旧的 SoftSwitch 模型中，所有组件都是分开销售的，这意味着你必须分别购买每个组件，然后将其集成到 PBX 或 SoftSwitch 环境中。其成本和风险都很高，且大多数设备都是专有的。

![旧世界：组件分开购买并集成](../images/01-introduction-fig03.png)

### 使用 Asterisk 进行电话通信

所有功能都集成在 Asterisk 平台中，根据规模需求，它们可以位于同一台或不同的设备上，并且全部采用 GPL 许可。有时，安装 Asterisk 比许可某些主流 IP-PBX 更容易。

![使用 Asterisk 进行电话通信：功能已集成](../images/01-introduction-fig04.png)

## 构建测试系统

在实施 Asterisk 解决方案时，我们的第一步通常是构建一个测试系统。其目标是建立一个最小化的 **1×1 PBX**（即一部电话可以呼叫另一部电话），这样您就可以在接触生产环境之前先试用 endpoint、dialplan 和各项功能。如今，这完全是软件层面的工作：您不需要任何电话硬件。

![一个简单的 Asterisk 测试系统](../images/01-introduction-fig05.png)

### 现代方式：软件实验室（推荐）

最快的测试系统是在容器或虚拟机中运行 Asterisk 22，并使用 **softphone** 作为 endpoint，还可以选择配置一个 **SIP trunk** 来连接公共网络：

- 运行在小型 Linux 主机、VM 或 Docker 容器上的 **Asterisk 22**。本书提供了一个现成的 Docker 实验室（请参阅实验室指南），只需一条命令即可启动配置完整的 Asterisk 22——无需编译，无需硬件。
- 两个注册为 PJSIP endpoint 的 **softphone**，这样您就可以在它们之间进行真实的通话。在本书中，我们使用 **SipPulse Softphone**（免费下载：<https://www.sippulse.com/produtos/softphone>），它适用于桌面端和移动端。
- 来自 VoIP 提供商的 **SIP trunk**（可选），用于连接 PSTN。无需板卡，也无需模拟线路——只需凭据即可。

本书中的每一个示例都是通过这种方式构建和验证的，您可以在任何笔记本电脑上复现它。

### 传统方式：模拟/数字板卡

在 VoIP 出现之前，测试 PBX 需要物理接口：一个用于连接现有电话线的 **FXO** 端口，以及一个用于连接模拟电话的 **FXS** 端口，两者结合便构成了一个 1×1 PBX。一张同时带有 FXO 和 FXS 接口的单卡是经典的入门套件。这些基于 DAHDI 的板卡（来自 Sangoma，前身为 Digium）对于必须终结模拟线路或 T1/E1 线路的站点仍然存在，但它们在今天属于小众需求——大多数部署都是纯 VoIP。如果您只需要连接模拟电话或线路，请参阅 *Legacy Channels* 章节；否则，您可以完全跳过电话硬件部分。

## Asterisk 应用场景

Asterisk 可用于多种不同的场景。我们将列举其中一些，并解释每种场景的优势和可能的局限性。

### IP PBX

最常见的场景是安装新的 PBX 或替换现有的 PBX。如果您将 Asterisk 与其他替代方案进行比较，会发现它比目前市场上大多数 PBX 更便宜且功能更丰富。目前，许多公司正在将其规格要求更改为 Asterisk，而不是其他品牌的 PBX。

![作为 IP PBX 的 Asterisk](../images/01-introduction-fig06.png)

### 为传统 PBX 提供 IP 支持

下图展示了最常用的设置之一。大型公司通常不希望在投资新技术时承担重大风险，同时又希望保留其在传统设备上的投资。为传统 PBX 提供 IP 支持可能非常昂贵；因此，对于注重成本的客户来说，使用 T1/E1 线路连接 Asterisk PBX 可能是一个不错的选择。另一个好处是可以连接到具有更优惠通话费率的 VoIP 服务提供商。

![为传统 PBX 提供 IP 支持](../images/01-introduction-fig07.png)

### 长途旁路 (Toll Bypass)

VoIP 的一个非常有用的应用是通过互联网或 WAN 连接分支机构。利用现有的数据连接，您可以绕过总部与分支机构之间电信连接产生的长途费用。

![通过 WAN 在办公室之间进行长途旁路](../images/01-introduction-fig08.png)

### 应用服务器 (IVR, Conference, Voicemail)

Asterisk 可用作现有 PBX 的应用服务器，或直接连接到 PSTN。Asterisk 提供诸如 voicemail、传真接收、通话录音、连接到数据库的 IVR 以及音频会议服务器等服务。如果您将 voicemail 和传真集成到现有的电子邮件服务器中，您将拥有一个统一的消息系统，这通常是一个昂贵的解决方案。与其它解决方案相比，使用 Asterisk 作为应用服务器可大幅降低成本。

![作为应用服务器的 Asterisk](../images/01-introduction-fig09.png)

### 媒体网关

大多数 VoIP 服务提供商使用 SIP 代理来托管所有 SIP 用户的注册、定位和身份验证。他们仍然必须直接将呼叫发送到 PSTN，或使用 SIP 或 H.323 VoIP 连接通过批发呼叫终止提供商进行路由。Asterisk 可以充当背靠背用户代理 (B2BUA) 或媒体网关，取代非常昂贵的 SoftSwitch 或媒体网关。将主流市场制造商的四端口 E1/T1 网关价格与 Asterisk 进行比较。Asterisk 解决方案的成本可能比其他解决方案低数倍，并且能够转换信令协议 (H.323, SIP, IAX…) 和 codec (G.711, G.729…)。

![作为媒体网关的 Asterisk](../images/01-introduction-fig10.png)

### 呼叫中心平台

呼叫中心是一个非常复杂的解决方案，结合了多种技术，例如自动呼叫分配 (ACD)、交互式语音应答 (IVR) 和呼叫监管。基本上，有三种类型的呼叫中心：呼入式、呼出式和混合式。

呼入式呼叫中心非常复杂，通常需要 ACD、IVR、CTI、录音、监管和报告。Asterisk 具有内置的 ACD 来对呼叫进行排队。IVR 可以使用 Asterisk Gateway Interface (AGI) 或内部机制（例如 application background()）来完成。计算机电话集成 (CTI) 是通过 Asterisk Manager Interface (AMI) 实现的；录音和报告功能已内置于 Asterisk 中。

对于呼出式呼叫中心，预测式或自动拨号器是主要组件之一。尽管开源 Asterisk 有多种拨号器可用，但如果您愿意，为该平台构建自己的拨号器并不困难。混合式呼叫中心允许同时进行呼入和呼出操作，通过确保更有效地利用座席时间来节省资金。可以使用 Asterisk 及其 ACD 机制来实现混合解决方案。

![一个 Asterisk 呼叫中心平台](../images/01-introduction-fig11.png)

## 查找信息与获取帮助

本节将提供一些与 Asterisk 相关的主要信息来源。

- Asterisk 官方网站：<https://www.asterisk.org> 在这里您可以找到以下相关信息：
- 文档与 Wiki -> <https://docs.asterisk.org>
- 社区论坛 -> <https://community.asterisk.org>
- 问题追踪 -> <https://github.com/asterisk/asterisk/issues>
- Wiki（旧版，大部分内容已被 docs.asterisk.org 取代） -> <https://wiki.asterisk.org>

### 社区论坛

Asterisk 社区论坛已在很大程度上取代了旧的邮件列表，是您提问的首选之地。在发帖之前，请尽量收集尽可能多的信息。如果您没有做好功课，没人会帮助您——请至少尝试自己解决一次问题。

- <https://community.asterisk.org>

## 总结

Asterisk 是一款基于 GPL 许可的软件，它能让普通的 PC 摇身一变，成为功能强大的 IP PBX 平台。Digium 的 Mark Spencer 在 20 世纪 90 年代末创建了 Asterisk，并通过销售 Asterisk 相关硬件和商业产品来维持 Digium 的运营。Digium 于 2018 年被 Sangoma Technologies 收购；Sangoma 目前负责赞助 Asterisk 的开发。硬件接口设计源于 Jim Dixon 开发的 Zapata 项目，该项目最终衍生出了 DAHDI。

Asterisk 架构包含以下主要组件：

- CHANNELS（通道）：模拟、数字或 IP 语音。在 Asterisk 22 LTS 中，SIP 仅由 `chan_pjsip` 处理。
- PROTOCOLS（协议）：通信协议，负责呼叫信令，包括 SIP（通过 PJSIP）、H.323、MGCP 和 IAX2。
- CODECS（编解码器）：转换语音的数字格式，以实现压缩和丢包隐藏。请注意，Asterisk 本身不执行静音抑制（语音活动检测）或舒适噪声生成；当 endpoint 使用 VAD 时，应在客户端禁用舒适噪声。
- APPLICATIONS（应用程序）：负责 Asterisk PBX 的功能。会议、voicemail 和传真都是 Asterisk 应用程序的示例。

Asterisk 可用于各种场景，从小型 IP PBX 到复杂的呼叫中心均可胜任。您可以轻松地在 www.asterisk.org 和 docs.asterisk.org 找到帮助。

## 测试题

1. 哪家公司在 2018 年收购了 Digium，并现作为 Asterisk 开源项目的主要管理方？
   - A. Cisco Systems
   - B. Sangoma Technologies
   - C. Nortel Networks
   - D. Red Hat

2. 在 Asterisk 22 LTS 中，哪个通道驱动程序提供 SIP 连接？
   - A. `chan_sip`
   - B. `chan_skinny`
   - C. `chan_pjsip`
   - D. `chan_h323`

3. 判断对错：`chan_sip`通道驱动程序已在 Asterisk 21 中被移除，且不存在于标准的 Asterisk 22 构建版本中。

4. 以下哪些通道/协议**不再**属于标准的 Asterisk 22 构建版本？（请选择所有适用项。）
   - A. MGCP (`chan_mgcp`)
   - B. SCCP / Cisco Skinny (`chan_skinny`)
   - C. IAX2 (`chan_iax2`)
   - D. H.323 (`chan_h323`，仅作为社区 `ooh323` 插件存在)

5. Zapata 项目的硬件架构（最初称为 Zaptel）后来被重命名为 ____。
   - A. DAHDI
   - B. PJSIP
   - C. PRI
   - D. mISDN

6. 当 Asterisk 需要将音频从一种 codec 转换为另一种时，它通过哪种内部流格式进行转换？
   - A. G.711 ulaw
   - B. GSM
   - C. slinear (signed linear)
   - D. Opus

7. 根据本章内容，Sangoma 分发的 G.729 codec 模块的许可情况如何？
   - A. 它是 GPL 协议，且可免费用于任何用途。
   - B. 下载是免费的，但合法使用需要购买每个通道的许可证。
   - C. 不购买 Asterisk Business Edition 就无法获得它。
   - D. 它仅能以透传模式工作，无法安装。

8. 哪个 Asterisk 应用程序用于将呼叫从一部电话桥接到另一部电话？
   - A. `Background()`
   - B. `Dial()`
   - C. `Queue()`
   - D. `Goto()`

9. Asterisk 中的 `Local` 通道是什么？
   - A. 用于模拟电话的硬件 FXS 接口。
   - B. 连接到本地服务提供商的 SIP trunk。
   - C. 一种伪通道，将呼叫回环到 dialplan 中不同的 context。
   - D. 一种用于网内呼叫的 codec。

10. 在哪种使用场景下，Asterisk 充当背靠背用户代理 (B2BUA)，在信令协议和 codec 之间进行转换，以替代昂贵的 SoftSwitch？
    - A. 为传统 PBX 启用 IP 功能
    - B. 长途旁路 (Toll bypass)
    - C. Media Gateway
    - D. 联络中心平台

**答案：** 1 — B · 2 — C · 3 — 对 · 4 — A, B, D · 5 — A · 6 — C · 7 — B · 8 — B · 9 — C · 10 — C
