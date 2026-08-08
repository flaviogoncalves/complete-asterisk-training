# SIP 与 PJSIP 深度解析

SIP 是协议；PJSIP 是 Asterisk 22 使用该协议的方式。**PJSIP**（`chan_pjsip`，通过 `pjsip.conf` 进行配置）是 Asterisk 22 LTS 中唯一的 SIP 通道驱动程序。本章涵盖了 SIP 协议的基础知识（这些知识属于协议层面，且依然 100% 有效），以及您日常使用的 PJSIP 对象模型和配置。关于已淘汰的旧版驱动程序及迁移指南，请参阅 *Legacy channels* 一章。

## 目标

在本章结束时，你应该能够：

- 解释 SIP 用户代理、代理服务器、注册服务器和网关的作用；
- 遵循基本的 SIP 呼叫流程（REGISTER、INVITE、临时响应和最终响应、ACK、BYE）并阅读 SIP 消息；
- 描述 SDP 如何协商媒体会话，以及 NAT 如何影响 SIP 信令和 RTP；
- 映射 PJSIP 对象模型 —— `endpoint`、`auth`、`aor`、`transport`、`identify`和`registration` —— 以及这些对象如何相互引用；
- 在`pjsip.conf`中配置 SIP 话机和 trunk，包括 NAT 穿越选项；以及
- 使用`pjsip show …` CLI 命令验证和排查 endpoint 故障。

## SIP 协议基础

会话发起协议（SIP）是一种类似于 HTTP 和 SMTP 的基于文本的协议，旨在初始化、保持和终止用户之间的交互式通信会话。这些会话可能包括语音、视频、聊天、交互式游戏等。SIP 由 IETF 定义，并已成为语音通信的事实标准。理解 SIP 的工作原理非常重要。在 Asterisk 22 上，SIP 配置位于 `pjsip.conf`，这是基于 SIP 的系统中最常编辑的文件之一（仅次于 `extensions.conf`）。

### 操作理论

SIP 是一种信令协议，包含以下组件：用户代理客户端（UAC）、用户代理服务器（UAS）、SIP 代理和 SIP 网关。下图描绘了这些组件之间的关系。

- UAC（用户代理客户端）—— 初始化 SIP 信令的客户端或终端。
- UAS（用户代理服务器）—— 响应来自 UAC 的 SIP 信令的服务器。
- UA（用户代理）—— SIP 终端（包含 UAC 和 UAS 的电话或网关）。
- 代理服务器 —— 接收来自 UA 的请求，如果特定站点不在其管理范围内，则将其转发给其他 SIP 代理。
- 重定向服务器 —— 接收请求并将其发回给 UA（包含目标数据），而不是直接将其转发给目的地。
- 位置服务器 —— 接收来自 UA 的请求，并使用此信息更新位置数据库。

通常，代理、重定向和位置服务器托管在同一硬件中并使用相同的软件，我们称之为 SIP 代理。SIP 代理负责位置数据库维护、连接建立和会话终止。

![主要的 SIP 组件：用户代理（UAC/UAS/UA）、注册/代理/重定向服务器以及通往 PSTN 的网关，RTP 媒体流直接在端点之间传输](../images/07-sip-and-pjsip-fig01.png)

#### SIP 注册过程

在电话能够接收呼叫之前，它需要注册到位置数据库。在位置数据库中，IP 地址将与名称绑定。在以下示例中，分机 8500 将绑定到 IP 地址 200.180.1.1。您不一定非要使用电话号码。在 SIP 架构中，注册的分机也可以是 flavio@voip.school。

![SIP 注册：电话发送一个将分机 8500 绑定到其 IP 地址的 REGISTER 请求，注册服务器将联系信息存储在位置数据库中并回复 200 OK](../images/07-sip-and-pjsip-fig02.png)

#### 代理操作

当作为 SIP 代理运行时，SIP 服务器位于信令中间，能够进行高级路由和计费。基于实时传输协议（RTP）的媒体流仍然直接在端点之间传输。

![代理操作：SIP 代理位于信令路径（INVITE/200 OK）中并在位置服务器中查找被叫方，而 RTP 媒体流直接在两个端点之间传输](../images/07-sip-and-pjsip-fig03.png)

#### 重定向操作

当进行重定向时，SIP 服务器只需向用户代理发送一条消息（例如 302 moved temporarily），然后退出新消息的路径。从资源使用角度来看，这非常轻量，但您完全无法进行控制。重定向有时用于负载均衡设计。

![重定向操作：重定向服务器用携带联系信息的 302 Moved Temporarily 响应 INVITE，然后退出，由主叫方直接向新位置重新发送 INVITE/ACK](../images/07-sip-and-pjsip-fig04.png)

#### Asterisk 如何处理 SIP

必须理解，Asterisk 既不是 SIP 代理也不是 SIP 重定向器。Asterisk 可以执行注册服务器和位置服务器的角色；但是，它只将两个 UAC 连接到自身。因此，Asterisk 被视为背靠背用户代理（B2BUA）。换句话说，它连接两个 SIP 通道，并将它们桥接在一起。Asterisk 具有一种 re-invite 机制，可以使 SIP 通道直接相互通信，而不是通过 Asterisk。在 PJSIP 端点上，这由参数 `direct_media` 控制。当使用 `direct_media=yes` 时，RTP 流直接从一个端点传输到另一个端点，从而释放服务器资源。

#### direct_media=yes 时的 SIP 操作

![directmedia=yes 时的 SIP 操作：SIP 信令流经 Asterisk，而 RTP 音频直接在两部电话之间传输，从而释放服务器资源](../images/07-sip-and-pjsip-fig05.png)

但是，如果您需要使用 Asterisk 转移或录制呼叫，则可以使用参数 `direct_media=no` 强制 RTP 流经 Asterisk 服务器。

#### direct_media=no 时的 SIP 操作

![directmedia=no 时的 SIP 操作：SIP 信令和 RTP 音频都锚定在 Asterisk 上，允许其录制、转码或转移呼叫](../images/07-sip-and-pjsip-fig06.png)

#### SIP 消息

基本的 SIP 消息包括：

- INVITE —— 建立连接
- ACK —— 确认
- BYE —— 终止连接
- CANCEL —— 终止未建立的呼叫
- REGISTER —— 将 UAC 注册到 SIP 代理
- OPTIONS —— 可用于检查可用性
- REFER —— 将 SIP 呼叫转移给其他人
- SUBSCRIBE —— 订阅通知事件
- NOTIFY —— 发送通道信息
- INFO —— 发送各种消息（例如 DTMF）
- MESSAGE —— 发送即时消息

SIP 响应采用文本格式，易于阅读（类似于 HTTP 消息）。最重要的响应包括：

- 1XX —— 信息消息（100–trying, 180–ringing, 183–progress）
- 2XX —— 请求成功完成（200 – OK）
- 3XX —— 呼叫重定向，请求必须定向到其他地方（302 – moved temporarily, 305 – use proxy）
- 4XX —— 错误（403 – Forbidden）
- 5XX —— 服务器错误（500 – Internal Server Error; 501 – Not implemented）
- 6XX —— 全局失败（606 – Not acceptable）

例如：

```
INVITE sip:2000@192.168.1.133 SIP/2.0
Via: SIP/2.0/UDP
192.168.1.116;rport;branch=z9hG4bKc0a8017400000063452fafbb00006967000000d2
From: "unknown"<sip:2001@192.168.1.133>;tag=1556140623845
To: <sip:2000@192.168.1.133>
Contact: <sip:2001@192.168.1.116>
Call-ID: 64B4C8EC-FCFC-49E9-98B1-90982EEEBED3@192.168.1.116
CSeq: 2 INVITE
Max-Forwards: 70
User-Agent: SJphone/1.61.312b (SJ Labs)
Content-Length: 335
Content-Type: application/sdp
Proxy-Authorization: Digest
username="2001",realm="asterisk",nonce="6c55905e",uri="sip:2000@192.168.1.133",
response="983c0099eea125d8cdfe93b0ec99f3ec",algorithm=MD5
```

#### 会话描述协议（SDP）

SDP 最初定义在 IETF RFC 2327 中，现已被 RFC 4566 取代。它旨在描述多媒体会话，用于会话公告、会话邀请和其他形式的多媒体会话初始化。SDP 包括：

- 传输协议（RTP/UDP/IP）
- 媒体类型（文本、音频、视频）
- 媒体格式或 codec（H.261 视频、g.711 音频等）
- 接收这些媒体所需的信息（地址、端口等）

以下示例是描述两部电话之间呼叫的 SDP 转录。

```
v=0
o=- 3369741883 3369741883 IN IP4 192.168.1.116
s=SJphone
c=IN IP4 192.168.1.116
t=0 0
a=setup:active
m=audio 49160 RTP/AVP 3 97 98 8 0 101
a=rtpmap:3 GSM/8000
a=rtpmap:97 iLBC/8000
a=rtpmap:98 iLBC/8000
a=fmtp:98 mode=20
a=rtpmap:8 PCMA/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-11,16
```

### SIP NAT 穿透

网络地址转换（NAT）是大多数网络用于节省互联网 IP 地址的功能。通常，公司会收到一小块 IP 地址，而最终用户在连接到互联网时会动态获得一个 IP 地址。NAT 通过将内部地址映射到外部地址来解决寻址问题。它在内存中存储内部地址到外部地址的映射。此映射在特定时间内有效，之后映射将被丢弃。该映射使用 IP:port 对作为内部和外部地址。存在四种 NAT 类型：

- Full Cone
- Restricted Cone
- Port Restricted Cone
- Symmetric

下方的 NAT 理论（四种 NAT 类型、Contact 头部问题、keep-alives 以及强制媒体流经服务器）属于协议层面，适用于任何 SIP 实现。在 Asterisk 22 (PJSIP) 上配置每种行为的方式将在本章后面的 *Nat traversal on res_pjsip* 中介绍。

#### Full Cone

第一种 NAT，full cone，表示从外部 IP:port 对到内部 IP:port 对的静态映射。任何外部计算机都可以使用该外部 IP:port 对连接到它。这是在通过过滤器实现的非状态防火墙中的情况。

![Full Cone NAT：内部主机 (10.0.0.1:8000) 被静态映射到外部对 200.180.4.168:1234，因此任何外部计算机都可以向该对发送数据包并到达内部主机](../images/07-sip-and-pjsip-fig11.png)

#### Restricted Cone

在 restricted cone 场景中，外部 IP:port 对仅在内部计算机向外部地址发送数据时才打开。但是，restricted cone NAT 会阻止来自不同地址的任何传入数据包。换句话说，内部计算机必须先向外部计算机发送数据，然后才能接收发回的数据。

#### Port Restricted Cone

port restricted cone 防火墙与 restricted cone 几乎相同。唯一的区别是，现在传入的数据包必须来自与发送数据包完全相同的 IP 和端口。

#### Symmetric

最后一种 NAT 类型称为 symmetric。它与前三种不同，因为它对每个外部地址执行特定的映射。NAT 映射仅允许特定的外部地址返回。无法预测 NAT 设备将使用的外部 IP:port 对。其他三种 NAT 类型允许使用外部服务器来发现用于通信的外部 IP 地址。使用 symmetric NAT 时，即使您可以连接到外部服务器，发现的地址也无法用于除此服务器之外的任何其他设备。

![Symmetric NAT：为每个目的地分配不同的外部源端口，因此向一个服务器发现的映射不能被另一个主机重用，这会破坏基于 STUN 的穿透](../images/07-sip-and-pjsip-fig12.png)

#### NAT 防火墙表

下表总结了四种 NAT 类型。

| NAT 类型 | 必须先发送数据 | 能否确定返回数据包的外部 IP:port | 是否限制传入数据包到目标 IP:port |
| --- | --- | --- | --- |
| Full Cone | 否 | 是 | 否 |
| Restricted Cone | 是 | 是 | 仅 IP |
| Port Restricted Cone | 是 | 是 | 是 |
| Symmetric | 是 | 否 | 是 |

#### NAT 上的 SIP 信令和 RTP

NAT 穿透中最大的问题之一是必须解决两个问题：SIP 信令和音频（RTP）。大多数单向音频问题都与 NAT 有关。关于 SIP 的一个有趣之处在于，当 UAC 发送数据包时，它会将 IP 地址嵌入到 SIP “Contact” 头部字段中。通常这是一个内部（RFC1918）地址；对该数据包的响应无法通过互联网路由回 UAC。概念上的修复方法总是相同的：

- **忽略 Contact/Via 地址并回复到数据包实际来源的地址。** 这是 RFC 3581 (`rport`) 中定义的行为。在 PJSIP 上是 `force_rport=yes`，并且 `rewrite_contact=yes` 会将存储的联系地址重写为源地址。
- **将媒体发送回 RTP 实际到达的地址**（对称 RTP，历史上称为 *comedia*）。在 PJSIP 上，这是 `rtp_symmetric=yes`。
- **保持 NAT 映射打开。** 如果映射超时，Asterisk 将无法再向 UAC 发送 INVITE —— 电话可以拨打电话但无法接听。发送周期性的 OPTIONS（*qualify*）可以保持针孔打开。在 PJSIP 上，这是 AOR 上的 `qualify_frequency=`。

如果用户的 NAT 是 symmetric 类型，则无法直接从一个 UAC 向另一个 UAC 发送数据包；在这种情况下，您必须使用 `direct_media=no` 强制 RTP 流经 Asterisk。这些配置适用于大多数情况。可以使用高级技术优化流量，例如 Simple Traversal of UDP over NAT (STUN)（适用于 full cone、restricted cone 和 port restricted cone）以及 Application Layer Gateway (ALG)。不幸的是，当今大多数防火墙（甚至是家庭 DSL/电缆路由器）都是 symmetric 的，这使得 STUN 无法使用。ALG 本可以解决这个问题，但在大多数情况下它不受支持、未实现或存在错误。

#### NAT 后面的 Asterisk

有时 Asterisk 服务器本身部署在带有 NAT 的防火墙后面 —— 这是在云端部署时非常常见的情况。在这种情况下，有必要进行一些额外的配置，以便 Asterisk 在 SIP 和 SDP 头部中通告其 **公共** 地址而不是私有地址。

概念上有三个步骤：

- 将防火墙的 SIP 信令端口（默认 UDP 5060）转发到 Asterisk 服务器。
- 将防火墙的 RTP 媒体端口范围（默认 UDP 10000–20000，在 `rtp.conf` 中设置）转发到 Asterisk 服务器。
- 告诉 Asterisk 其外部地址以及哪个网络是本地网络，以便它知道何时将公共地址替换到头部中。

在 PJSIP 上，最后两项映射到 **传输** 上的 `external_media_address` / `external_signaling_address` 和 `local_net=`，而 RTP 端口范围仍在 `rtp.conf` 中配置：

```
; RTP Configuration
;
[general]
;
; RTP start and RTP end configure start and end addresses
;
rtpstart=10000
rtpend=20000
```

NAT 后面的 Asterisk 服务器的完整、有效的 PJSIP 配置将在本章后面的 *Asterisk Server behind NAT* 中给出。

### SIP 限制

Asterisk 使用传入的 RTP 流来同步传出的流。如果传入流中断（静音抑制），保持音乐（music-on-hold）将会被切断。换句话说，您不应在带有 Asterisk 的电话或提供商中使用静音抑制。

## PJSIP：SIP 通道

PJSIP 是 Asterisk 中的 SIP 通道。它最初在 Asterisk 12 中引入，经过多年的开发，现已成为默认且推荐的 SIP 通道。在 Asterisk 22（当前的 LTS 版本）中，它是唯一的 SIP 通道驱动程序。PJSIP 基于 Teluu 的一个名为 pjproject 的项目。pjproject 协议栈被许多 softphone 和商业 SIP 实现所采用。它是一个功能多样且成熟的 SIP 协议栈。

### 为什么要使用 PJSIP

PJSIP 对 Asterisk 处理 SIP 的方式进行了彻底的重新设计，了解使其成为标准的特性是非常有价值的。

#### 特性

该通道支持许多特性，其中一些值得在此提及：

- 多重注册：您可以将多部电话连接到同一个 Address of Record。换句话说，您可以将两部电话连接到同一个 endpoint。
- 友好的应用程序接口 (API)。该 API 是模块化的且易于扩展，由许多相互协作的小型模块构建而成，而不是一个庞大的代码块。
- 多重传输：使用 PJSIP 时，您可以监听多个地址、端口和传输协议。您不必局限于为所有设备使用单一的绑定地址。PJSIP 非常灵活。

#### 关于配置的说明

PJSIP 的配置更为冗长：它需要付出更多的努力并编写更多的配置行，因为每个设备是由几个相关的对象而不是一个 peer 块来描述的。这种额外的结构赋予了 PJSIP 灵活性，而配置向导（稍后介绍）可以简化日常的配置工作。

### PJSIP 模块

PJSIP 通道由下面描述的许多模块实现：

#### res_pjsip

这是 PJSIP 的基础层和主要模块。它负责一些核心服务。

#### res_pjsip_session

该模块负责媒体会话、会话描述协议处理以及一些附加功能。

#### res_pjsip_messaging

处理 SIP 消息并解析 SIP 头部。

#### res_pjsip_registrar

负责处理 SIP 注册。

#### res_pjsip_pubsub

负责处理 subscribe、notify 和 publish。这些消息负责处理 SIP 状态呈现和 BLF (Busy Lamp Field)。

### PJSIP 配置

PJSIP 有许多不同的部分。部分的格式如下：

```
[Section Name]
Option = Value
Option = Value
```

#### End point 部分

最重要的配置对象是 endpoint。endpoint 配置具有核心功能，并且必须与 AOR 和 Transport 部分相关联。示例：

```
[softphone]
type=endpoint
transport=transport-udp-main
context=from-internal
disallow=all
allow=ulaw
aors=softphone
auth=softphone
```

如果您查看上面的示例，endpoint 就像是一种将所有部分粘合在一起的胶水。它指定了传输方式、Address of Record 以及电话的认证信息。它还定义了最重要的部分，即 dialplan 中的 context 入口点。

#### Address of Record (AOR)

该对象告诉 Asterisk 在哪里联系 endpoint。它存储联系地址。它还允许配置语音信箱。示例：

```
[softphone]
type=aor
max_contacts=2
```

#### 认证 (Authentication)

该部分负责入站和出站认证。相关文档可以在示例文件 pjsip.conf 中找到。示例：

```
[softphone]
type=auth
auth_type=digest
username=softphone
password=#supersecret#
```

#### 传输 (Transport)

传输部分允许您定义 IPV4 和 IPV6 地址以及传输协议，如 TCP、UDP、TLS、Websockets 等。您也可以在此部分配置 NAT 地址。您可以创建多个传输，但它们不能共享相同的 IP 和端口，并且您不能绑定同一 IP 版本的多个 TCP 或 TLS 传输。示例：

```
[transport-udp-main]
type=transport
protocol=udp
bind=0.0.0.0:5060
```

#### 注册 (Registration)

该对象用于配置出站注册。示例：

```
[siptrunk]
type=registration
outbound_auth=siptrunk
server_uri=sip:1020@sip.flagonc.com:5600
client_uri=sip:1020@sip.flagonc.com
contact_user=9999
```

#### 识别 (Identify)

该对象控制哪个 SIP 请求属于哪个 endpoint。如果您没有 identify 部分，系统会将“From”头部的内容与 endpoint 名称进行匹配。使用此部分，您可以将特定的 IP 地址分配给特定的 endpoint，通过用户名或 IP 进行识别。示例：

```
[siptrunk]
type=identify
endpoint=siptrunk
match=52.37.87.85
```

#### ACL

ACL 对象允许您配置具有访问 endpoint 权限的特定网络。现在 ACL 定义在特定的部分或 acl.conf 中。示例：

```
[acl]
type=acl
deny=0.0.0.0/0.0.0.0
permit=209.16.236.0
permit=209.16.236.1
```

### 实体之间的关系

配置对象之间的关系为配置提供了极大的灵活性。然而，对于初学者来说，这看起来有点复杂。

![PJSIP 配置对象之间的关系：endpoint 链接到 transport、auth 和 AOR（其中包含联系人）；registration 绑定到 transport 和 auth；identify 指向 endpoint，而 ACL 和 domain alias 是独立的](../images/07-sip-and-pjsip-fig14.png)

上图的含义如下：

#### 关系：

| 对象 | 基数 |
| --- | --- |
| ENDPOINT / AOR | 多对多 |
| ENDPOINT / AUTH | 零到多，对零到一 |
| ENDPOINT / IDENTIFY | 零到一 |
| ENDPOINT / TRANSPORT | 零到多，对至少一 |
| REGISTRATION / AUTH | 零到多，对零到一 |
| REGISTRATION / TRANSPORT | 零到多，对至少一 |
| AOR / CONTACT | 多对多 |

ACL 和 DOMAIN_ALIAS 与其他对象没有直接的配置关系。

### 配置 Softphone

要配置 softphone，您必须定义许多不同的部分。下面是一个如何配置 softphone 的示例。对于客户端，您可以使用 SipPulse Softphone (https://www.sippulse.com/produtos/softphone)，您可以下载并将其注册到下面的 endpoint。

```
[transport-udp-main]
type=transport
protocol=udp
bind=0.0.0.0:5060
[softphone]
type=endpoint
transport=transport-udp-main
context=from-internal
disallow=all
allow=ulaw
aors=softphone
auth=softphone
[softphone]
type=auth
auth_type=digest
username=softphone
password=#supersecret#
[softphone]
type=aor
max_contacts=2
```

上面的配置设置了端口 5060 上的 UDP 传输，然后定义了一个 endpoint、其用户名和密码的认证，以及最大包含两个联系人的 Address of Record。

### 配置 SIP trunk

要配置 SIP trunk，您需要拥有 SIP trunk 的 IP 地址或主机名、名称和密码。您必须为此创建一个新的注册部分。

```
[siptrunk]
type=endpoint
transport=transport-udp-main
context=from-siptrunk
direct_media=no
disallow=all
allow=ulaw
outbound_auth=siptrunk
aors=siptrunk
[siptrunk]
type=aor
contact=sip:sip.flagonc.com:5600
[siptrunk]
type=auth
auth_type=digest
username=1020
password=supersecret
[siptrunk]
type=registration
outbound_auth=siptrunk
server_uri=sip:1020@sip.flagonc.com:5600
client_uri=sip:1020@sip.flagonc.com
contact_user=9999
[siptrunk]
type=identify
endpoint=siptrunk
match=sip.flagonc.com
```

### res_pjsip 上的 NAT 穿越

网络地址转换 (NAT) 是很久以前为了解决 IP 版本 4 地址短缺问题而创建的。许多人还将 NAT 作为一种安全功能，将网络的内部地址从公共互联网中隐藏起来。有时您必须处理 NAT 穿越。在某些情况下，服务器可能位于 NAT 之后，例如当您在云端部署服务器时。很多时候，如果您在云端部署，您的用户也会位于 NAT 路由器之后。为了理清思路，我们将这部分分为两部分。第一部分是位于 NAT 之后的 Asterisk 服务器，例如云部署。在第二部分中，我们将介绍如何使用 res_pjsip 支持位于 NAT 之后的客户端。

#### 位于 NAT 之后的 Asterisk 服务器

当 Asterisk 服务器位于 NAT 之后时，您应该在传输部分告知外部和内部本地地址。我们将使用以下指令。

##### direct_media

媒体是直接在对等点之间流动，还是通过服务器流动？对于 NAT，它应该通过服务器流动。对于 NAT，选择 no。示例：

```
direct_media=no
```

##### external_media_address

用于处理外部 RTP 的媒体地址。通常与 external_signaling_address 相同。请使用服务器的公共 IP 地址进行媒体和信令传输。示例：

```
external_media_address=54.232.1.20
```

##### external_signaling_address

接收消息的外部 SIP 地址。示例：

```
external_signaling_address=54.232.1.20
```

##### local_net

您认为属于本地网络的网络。示例：

```
local_net=172.16.30.0/24
local_net=127.0.0.1/32
```

#### 位于 NAT 之后的 Asterisk 服务器的完整传输示例

要使用位于 NAT 之后的 Asterisk 服务器，您必须执行两个步骤。第一，定义一个位于 NAT 之后的传输。第二，将此传输关联到 endpoint。

##### 创建位于 NAT 之后的传输

要在 pjsip.conf 文件中创建位于 NAT 之后的传输，请创建如下部分。

```
[tnat]
type=transport
protocol=udp
bind=0.0.0.0
local_net=172.16.30.0/24
local_net=127.0.0.1/32
external_media_address=54.232.1.20
external_signaling_address=54.232.1.20
```

将传输关联到 endpoint

```
[6000]
type=endpoint
transport=tnat
context=from-internal
direct_media=no
auth=6000
aors=6000
```

对于 SIP trunk，您还应该将传输关联到注册部分，如下所示。

```
[siptrunk_reg]
type=registration
transport=tnat
server_uri=sip:sip.flagonc.com:5600
outbound_auth=siptrunk_auth
client_uri=sip:23456789@flagonc.com
contact_user=9999
```

#### 在位于 NAT 之后的客户端上使用 Asterisk

要使用位于 NAT 之后的电话，您必须为每个 endpoint 配置一些额外的参数。

##### direct_media

媒体是直接在对等点之间流动，还是通过服务器流动？对于 NAT，它应该通过服务器流动。示例：

```
direct_media=no
```

##### rtp_symmetric

这就是我们所说的 comedia。它不依赖于 SDP 头部中定义的地址（SIP 中的常规做法），而是使用您接收到第一个 RTP 数据包的地址，并从同一地址发回。示例：

```
rtp_symmetric=yes
```

##### force_rport

这是 RFC3581 中定义的行为。它不使用 VIA 头部中的地址，而是从请求来源的地址发回响应。示例：

```
force_rport=yes
```

##### qualify_frequency

此设置必须应用于 AOR（而不是 endpoint）。最后一步是配置 qualify 选项。您应该始终有一些数据包 ping 目标地址以保持 NAT 映射打开。这在 AOR 部分设置。示例：

- qualify_frequency=15

服务器和客户端都位于 NAT 之后的 endpoint 完整示例

```
[6000]
type=endpoint
transport=tnat
context=from-internal
direct_media=no
force_rport=yes
rtp_symmetric=yes
auth=6000
aors=6000
[6000]
type=aor
qualify_frequency=15
```

### 通道命名

像往常一样，通道的重要方面之一是其命名，PJSIP 有一些有趣的细节。您可以使用 `PJSIP/` 技术拨打 PJSIP endpoint：

```
exten=>6000,1,Dial(PJSIP/6000,20,tT)
```

一个有用的特性是可以一次拨打注册到 AOR 的所有联系人。函数 PJSIP_DIAL_CONTACTS 将被转换为要拨打的联系人列表。

```
exten=>6000,1,Dial(${PJSIP_DIAL_CONTACTS(6000)},20,tT)
```

拨打 trunk 的方式略有不同。假设 trunk 不会注册到您的平台，或者没有与您的 AOR 地址关联的 IP 地址。您可以直接在行中指定 trunk 的地址。以国际拨号为例。

```
exten=>9011.,1,Dial(PJSIP/siptrunk/sip:${EXTEN:1}@sip.flagonc.com)
```

如果您更喜欢在 AOR 部分指定 trunk 的地址，您也可以使用。

```
exten=>9011.,1,Dial(PJSIP/${EXTEN:1}@siptrunk)
```

### PJSIP 配置向导

PJSIP 功能强大但配置冗长：有许多不同的部分和模板，起初可能会让人感到困惑。好消息是 PJSIP 配置向导。通过在几行内定义每个通道，它允许您创建模板并简化新设备的配置。使用 pjsip_wizard.conf 文件进行配置。您仍然需要在 pjsip.conf 文件中定义传输和全局部分。个人而言，我更喜欢仅将向导用于电话，对于 SIP trunk，通常数量不多，您可以直接在 pjsip 中配置。向导最大的优势是可以使用模板并快速创建电话。

```
[phone_default](!)
type = wizard
accepts_auth = yes
accepts_registrations = yes
transport = tnat
endpoint/allow = ulaw
endpoint/context = from-internal
endpoint/direct_media=no
endpoint/force_rport=yes
endpoint/rtp_symmetric=yes
aor/qualify_frequency=15
[alice](phone_default)
inbound_auth/username = alice
inbound_auth/password = supersecret
[bob](phone_default)
inbound_auth/username = bob
inbound_auth/password = supersecret
```

### 加载和卸载 PJSIP

PJSIP 是 Asterisk 22 中唯一的 SIP 通道，其模块默认加载。在极少数情况下，您可能仍希望从 modules.conf 文件中控制模块加载——例如，在仅使用 IAX2 或 DAHDI 的服务器上禁用 PJSIP。

#### 禁用 PJSIP

编辑 modules.conf 文件并添加以下行。

```
noload => res_pjsip.so
noload => res_pjsip_pubsub.so
noload => res_pjsip_session.so
noload => chan_pjsip.so
noload => res_pjsip_exten_state.so
```

### 控制台命令

现在您已经配置了 PJSIP endpoint，是时候看看如何检查您的配置了。有许多控制台命令可以帮助您完成此任务。编辑 pjsip.conf 后，使用以下命令重新加载配置：

```
module reload res_pjsip.so
```

普通的 `reload`（或 `core reload`）会重新加载所有模块，包括 PJSIP。（注意没有纯粹的 `pjsip reload` 命令——`pjsip reload` 仅以 `pjsip reload qualify aor|endpoint` 的形式存在。）您可以使用 `help pjsip` 列出所有可用的 PJSIP 控制台命令。

#### pjsip show endpoints

此命令显示可用的 endpoint。在下图中，我们有一个截图。您可以看到 softphone endpoint 的地址，并看到它是可用的。

![`pjsip show endpoints` 的输出，列出了 blink、siptrunk 和 softphone endpoint 及其 AOR、auth、transport 和可用性——softphone 联系人已注册 (Avail)](../images/07-sip-and-pjsip-fig15.png)

#### pjsip show endpoint <endpoint>

使用上述命令，您可以查看 endpoint 的每个参数。下面的列表被截断为当前参数的一半不到。

![`pjsip show endpoint softphone` 的输出，显示了单个 endpoint 的完整参数列表，从 100rel 和 allow=(ulaw) 一直到 callerid 和 connected_line_method](../images/07-sip-and-pjsip-fig16.png)

#### pjsip show aors

此命令列出已配置的 Address of Record 对象及其联系人，以便您可以确认 Asterisk 将为每个 endpoint 发送呼叫的位置。

#### pjsip show registrations

下面的命令显示了我们自己的服务器所做的注册。

![`pjsip show registrations` 的输出：显示了出站注册 siptrunk/sip:1020@sip.flagonc.com:5600，状态为 Registered](../images/07-sip-and-pjsip-fig17.png)

#### pjsip list

list 命令更友好，显示的数据较少，但结构更好。列出 endpoint：

![`pjsip list endpoints` 的输出：每个 endpoint 一行的紧凑列表（blink、siptrunk、softphone），包含它们的状态和通道计数](../images/07-sip-and-pjsip-fig18.png)

列出联系人：

![`pjsip list contacts` 的输出，显示了 siptrunk 和 softphone 联系人 URI 及其哈希值和 qualify 状态](../images/07-sip-and-pjsip-fig19.png)

#### pjsip set logger on

最有用的故障排除命令是 SIP 数据包记录器。它将每个 SIP 请求和回复在发送或接收时打印到控制台，这在诊断注册和呼叫建立问题时非常宝贵。

```
pjsip set logger on
pjsip set logger off
```

您还可以使用 `pjsip set logger host <ip>` 将日志记录限制为单个主机。

#### pjsip set history on

PJSIP 的一个重要补充是历史记录的概念。您可以轻松地实时捕获和分析 SIP 请求和回复。要开始记录历史，请使用以下命令。

![运行 `pjsip set history on` 返回 "PJSIP History enabled"](../images/07-sip-and-pjsip-fig20.png)

现在您可以显示历史记录：

![`pjsip show history` 的输出：捕获的 SIP 消息的编号表格——REGISTER、401 Unauthorized、REGISTER、200 OK——包含时间戳、方向和地址](../images/07-sip-and-pjsip-fig21.png)

然后要查看特定的请求或回复，请显示历史记录项：

![`pjsip show history entry` 的输出：单个捕获的 SIP 消息的全文——此处为 Asterisk 22 对 OPTIONS 探测的 `404 Not Found` 回复——显示了 Via（带有 `rport`/`received`）、Call-ID、From、To 和 CSeq 头部，`Allow`/`Supported` 能力，以及 `Server: Asterisk PBX 22.10.0` 头部](../images/07-sip-and-pjsip-fig22.png)

非常简单，不是吗？您还可以随时使用 `pjsip set history clear` 清除历史记录。

> **正在迁移现有的 chan_sip/sip.conf 系统？** 旧版的 `chan_sip`
> 驱动程序以及完整的 **sip.conf → pjsip.conf 迁移指南**（包括
> 概念映射表和 `sip_to_pjsip.py` 转换脚本）在 *Legacy channels* 一章中介绍。

## 总结

SIP 是 IETF 定义的信令协议，用于建立、修改和拆除媒体会话。其用户代理、代理服务器、注册服务器和网关交换基于文本的消息——如 REGISTER、INVITE、临时和最终响应、ACK 以及 BYE——同时 SDP 负责协商 codec，而 RTP 则承载媒体流。这些协议理论是永恒的，适用于任何 SIP 实现。

在 Asterisk 22 中，你通过 **PJSIP** (`chan_pjsip`) 使用 SIP，并在 `pjsip.conf` 中进行配置。设备不再被视为单一的整体对等体，而是被建模为一组相互引用的微小对象：`endpoint`（呼叫行为和 codec）、`auth`（凭据）、`aor`（可达位置）和 `transport`（监听器），此外还有针对服务提供商的 `identify`（通过 IP 匹配 trunk）和 `registration`（出站注册）。你已经了解了这些对象是如何组合在一起的，如何配置话机和 trunk，NAT 穿越选项（`force_rport`、`rewrite_contact`、`rtp_symmetric`、`direct_media`以及传输层的 `external_*`/`local_net`）如何解决实际部署中的问题，以及如何使用 `pjsip show endpoints`、`aors`、`contacts`和 `registrations` 来检查所有这些配置。

## 测验

1. 在 SIP 架构中，哪个组件接收请求并以重定向响应（例如 `302 Moved Temporarily`）进行应答，其中携带了新位置，随后便不再参与后续消息的路径？
   - A. Proxy server
   - B. Redirect server
   - C. Location server
   - D. Registrar

2. 当 Asterisk 处理两部电话之间的 SIP 通话时，它扮演什么角色？
   - A. 仅保留在信令路径中的 SIP proxy
   - B. SIP redirect server
   - C. 桥接两个 SIP 通道的 back-to-back user agent (B2BUA)
   - D. 无状态的 SIP 负载均衡器

3. 电话使用哪种 SIP 方法来告知 registrar 其当前的 IP 地址，以便后续能够接收呼叫？
   - A. INVITE
   - B. OPTIONS
   - C. SUBSCRIBE
   - D. REGISTER

4. 判断对错：在 Asterisk 22 中，`chan_sip` 和 `sip.conf` 是否仍然作为 PJSIP 之外的遗留后备方案提供？

5. endpoint 必须与哪些配置对象关联，以便 Asterisk 知道要使用哪个监听 socket 以及将呼叫发送到该设备的何处？（选择所有适用项。）
   - A. `type=transport`
   - B. `type=aor`
   - C. `type=identify`
   - D. `type=registration`

6. 在 PJSIP `aor` 对象中，哪个设置通过定期对联系人进行限定（qualifying）来保持 NAT 映射开启，其单位是什么？
   - A. `qualify=yes` (布尔值)
   - B. `qualify_frequency` (秒)
   - C. `rtp_timeout` (毫秒)
   - D. `nat=force_rport`

7. 填空：要使 Asterisk 通过源 IP 地址（而不是通过 `From` 头部）将入站 SIP 请求匹配到特定的 endpoint，你需要创建一个带有 `type=________` 的部分。

8. 哪个 PJSIP 对象用于配置从 Asterisk 到 SIP trunk 提供商的 **出站** 注册？
   - A. `type=aor`
   - B. `type=identify`
   - C. `type=registration`
   - D. `type=auth`

9. 在 Asterisk 22 CLI 上，哪个命令可以启用 SIP 数据包记录器，将每个 SIP 请求和回复打印到控制台？
   - A. `sip set debug on`
   - B. `pjsip set logger on`
   - C. `pjsip debug on`
   - D. `sip show registry`

10. 在服务于对称 NAT 后方电话的 PJSIP endpoint 上，哪一对设置能使 Asterisk 回复请求的源地址（RFC 3581）并将媒体发送回 RTP 实际到达的来源处？
    - A. `direct_media=yes` 和 `srvlookup=yes`
    - B. `force_rport=yes` 和 `rtp_symmetric=yes`
    - C. `allowguest=yes` 和 `insecure=invite`
    - D. `qualify=yes` 和 `nat=no`

**答案：** 1 — B · 2 — C · 3 — D · 4 — False · 5 — A, B · 6 — B · 7 — identify · 8 — C · 9 — B · 10 — B
