# SIP trunking, DID 与 PSTN

一个只能拨打自身分机的 PBX 用处不大。迟早每个系统都需要连接到外部世界——公共交换电话网络 (PSTN)、SIP 提供商或另一个 PBX。承载这些呼叫的链路称为 **trunk**。在 TDM 时代，trunk 是物理电路：T1/E1 PRI 或一组模拟 FXO 线路。如今，它几乎总是 **SIP trunk**——一种通过与其它业务相同的 IP 网络承载的、连接到互联网电话服务提供商 (ITSP) 的逻辑连接。

本章将展示如何使用 PJSIP 将 Asterisk 22 连接到 ITSP，如何在基于注册的 trunk 和基于 IP 的 trunk 之间进行选择，如何将入站 DID 号码路由到正确的目的地，如何发送带有正确主叫 ID 和 E.164 格式的出站呼叫，以及如何跨多个 trunk 构建故障转移和最低成本路由。最后，我们将介绍 trunk 的 NAT 处理，并进行一个实验：搭建第二个 Asterisk（以及 SIPp）作为模拟 ITSP，以便您可以跨 trunk 拨打真实呼叫。

此处的所有内容均已针对本书的 Asterisk 22.10.0 实验环境进行了验证；其 trunk 对象模式与《Building your first PBX with PJSIP》和《SIP & PJSIP in depth》中介绍的模式相同。

## 目标

读完本章后，您应该能够：

- 使用 PJSIP 将 Asterisk 22 连接到 ITSP
- 在基于注册的 trunk 和基于 IP（静态）的 trunk 之间进行选择
- 将入站 DID 路由到正确的 extension、IVR 或队列
- 使用正确的 caller-ID 和 E.164 格式路由出站呼叫
- 使用 `${DIALSTATUS}` 构建 trunk 故障转移和最低成本路由
- 处理传输层和 endpoint 上的 trunk NAT 问题

## 什么是 SIP trunk

SIP trunk 是您的 PBX 与另一个 SIP 系统之间的逻辑语音路径。在实践中，那个“另一个系统”通常是以下两者之一：

- **ITSP（互联网电话服务提供商）。** 一家商业运营商，向您出售呼叫发起和终止服务，通常还包括一组电话号码（DID）。您将 Asterisk 指向提供商的信令主机，提供商便会将您的呼叫连接到更广泛的 PSTN。这是大多数现代系统接入电话网络的方式——无需任何电话硬件。
- **PSTN 网关。** 一种拥有物理 PSTN 接口（如 PRI 卡、模拟 FXO 端口或 GSM/4G 网关）的设备（或另一台 Asterisk），它将这些接口以 SIP 的形式呈现给您的 PBX。网关负责执行 TDM 到 SIP 的转换；从 Asterisk 的角度来看，它仅仅是另一个 SIP trunk。

无论哪种方式，在 PJSIP 中，trunk **仅仅是一个 endpoint**。您用于电话的同一对象系列——`endpoint`、`auth`、`aor`，以及可选的`identify`和`registration`——同样可以构建一个 trunk。区别在于细节：trunk 进行*出站*认证（您是客户端，因此凭据放在`outbound_auth`中，而不是`auth`中），它通常不会向您注册用户代理（是您注册到*它*，或者它从已知的 IP 向您发送流量），并且它会将入站呼叫落地到专用的 context 中，例如`from-pstn`，而不是`from-internal`。

> **与旧式 TDM trunk 的比较。** PRI 为您提供了固定数量的 B 通道（T1 上为 23 个，E1 上为 30 个），并通过专用的 D 通道进行呼叫建立信令（请参阅 *Legacy channels* 一章）。SIP trunk 没有固定的通道数量——容量取决于您的带宽、提供商的策略以及任何`max_contacts`/并发呼叫限制。曾经承载在 ISDN 信息元素上的 Caller-ID、DID 和呼叫进度，现在则承载在 SIP 头部和 SDP 中。

ITSP 与您交换流量的方式有两种，它们决定了您如何构建 trunk：**基于注册（registration-based）**和**基于 IP（静态）（IP-based (static)）**。我们将依次介绍这两种方式。

## 基于注册的 trunk

基于注册的 trunk 是当服务提供商要求*你*登录到*他们*系统时所使用的模型。你的 Asterisk 会定期向服务提供商发送 SIP `REGISTER`，使用用户名和密码进行身份验证，这与电话注册到你的 PBX 的方式完全相同。当你的公网 IP 是动态的、你位于 NAT 之后，或者服务提供商仅仅通过 SIP 凭据而非 IP 地址来识别客户时，这种方式非常常见。

在 PJSIP 中，出站登录存在于一个专门的 `registration` 对象中。它取代了已移除的 `chan_sip` 驱动程序在 `sip.conf` 中使用的单个 `register =>` 行。以下是一个连接到虚构服务提供商的完整注册 trunk 示例，遵循了本书前面章节中验证过的模式 —— 请注意 `outbound_auth`（而非 `auth`）、`server_uri`/`client_uri`（而非 `server`/`client`）、endpoint 上的 `from_user`/`from_domain`，以及 `dtmf_mode=rfc4733`：

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
outbound_auth=itsp-auth
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com

[itsp-auth]
type=auth
auth_type=digest
username=4830001000
password=Lab-itsp-secret

[itsp-aor]
type=aor
contact=sip:itsp.example.com:5060

[itsp-reg]
type=registration
transport=transport-udp
outbound_auth=itsp-auth
server_uri=sip:itsp.example.com:5060
client_uri=sip:4830001000@itsp.example.com:5060
contact_user=4830001000
retry_interval=60
```

需要注意的几点：

- **`auth_type=digest`，而非 `userpass`。** 两者都会产生相同的摘要身份验证，但在 Asterisk 22 中，`userpass`（以及旧的 `md5`）已被**弃用并静默转换为 `digest`**。在新的配置中请优先使用 `digest`；你仍然会在旧文件和本书前面的章节中看到 `userpass`。
- **endpoint 和 registration 上均使用 `outbound_auth`。** registration 使用它来验证 `REGISTER`；endpoint 使用它来应答服务提供商发回给外呼 `INVITE` 的 `407 Proxy Authentication Required`。它们可以共享同一个 `auth` 对象。
- **`from_user` / `from_domain`。** 许多服务提供商会拒绝那些 `From` 报头中未携带你的账号及其域名的呼叫。这两个选项正是用于设置这些内容。
- **`contact_user=4830001000`。** 这将成为你注册的 `Contact` 的用户部分，以便服务提供商知道将入站呼叫传送到哪个号码。它是旧 `register =>` 行上 `/9999` 后缀的现代等效项。
- **`retry_interval=60`。** 如果注册失败，则每 60 秒重试一次。

重新加载后，使用 `pjsip show registrations` 确认注册状态。在实验环境中 —— 其中 `itsp.example.com` 实际上不会应答 —— 表格看起来如下所示：

```
*CLI> pjsip show registrations

 <Registration/ServerURI..............................>  <Auth....................>  <Status.......>
==========================================================================================

 itsp-reg/sip:itsp.example.com:5060                      itsp-auth                   Rejected          (exp. 56s)

Objects found: 1
```

`(exp. Ns)` 后缀会倒计时直到下一次尝试；一旦归零，它会在重试触发前短暂显示 `(exp. Ns ago)`。在连接真实服务提供商时，`Status` 列会显示 `Registered`，即距离下一次刷新剩余的秒数。`Rejected`（或 `Unregistered`）意味着服务提供商未接受该登录 —— 请开启 `pjsip set logger on` 并阅读 `401`/`403` 回复，这通常是由于错误的用户名、密码或 `client_uri` 域名导致的。

## 基于 IP 的（静态）trunk

第二种模式完全不需要注册。提供商知道您的公网 IP 地址，并直接将呼叫发送到该地址；反过来，您将呼叫发送到提供商已知的信令 IP。身份验证是通过 **源 IP 地址** 进行的，而不是通过 SIP 凭据。这对于您控制的两台服务器之间的 trunk，或者双方都拥有静态地址的企业 trunk 来说是典型的配置。

关键对象是 `identify`。它告诉 Asterisk：“任何来自 *此* IP 的 SIP 请求都属于 *那个* endpoint。” 如果没有它，PJSIP 会尝试通过 `From` 用户将入站请求匹配到 endpoint，而运营商的流量无法满足此条件——因此呼叫将被拒绝或落入 `anonymous` endpoint。

静态 trunk 会舍弃 `registration` 对象并添加 `identify`：

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com

[itsp-aor]
type=aor
contact=sip:203.0.113.10:5060

[itsp-identify]
type=identify
endpoint=itsp
match=203.0.113.10
```

`match` 接受 IP 地址、CIDR 范围或主机名。**主机名仅在配置加载时解析一次**，因此如果您的提供商 IP 发生变化，您必须重新加载。对于发布了多个媒体网关的运营商，请列出每个信令 IP——您可以重复 `match` 或提供一个 CIDR：

```
[itsp-identify]
type=identify
endpoint=itsp
match=203.0.113.10
match=203.0.113.11
match=198.51.100.0/24
```

使用 `pjsip show identifies` 验证 Asterisk 将接受的内容。从实验室捕获（`sipp-identify` 行是实验室预先存在的 SIPp endpoint）：

```
*CLI> pjsip show identifies

 Identify:  <Identify/Endpoint...........................................................>
      Match:  <criteria...........................>
==========================================================================================

 Identify:  itsp-identify/itsp
      Match: 172.30.0.50/32

 Identify:  sipp-identify/sipp
      Match: 172.30.0.0/24

Objects found: 2
```

### 安全影响

没有身份验证的基于 IP 的 trunk 就像一扇门，而 `identify`/`match` 是它唯一的锁。如果您 `match` 的范围太广——或者攻击者可以伪造源 IP——呼叫就会在未经身份验证的情况下进入您的 `from-pstn` context。两种防御措施应结合使用：

- **匹配范围尽可能窄。** 优先使用特定的主机 IP，而不是宽泛的 CIDR。只有提供商真实的信令 IP 才应包含在 `match` 中。
- **将其与 ACL 配对。** PJSIP 可以使用 `type=acl` 对象（或 `acl.conf`）在 SIP 层到达 endpoint 之前丢弃流量：

```
[itsp-acl]
type=acl
deny=0.0.0.0/0.0.0.0
permit=203.0.113.10
permit=203.0.113.11
```

`type=acl` 部分不需要引用：`res_pjsip_acl` 会将每个此类对象应用于 *所有* 入站 SIP 流量，然后再到达任何 endpoint。（对象上的 `acl` 和 `contact_acl` 选项会从 `acl.conf` 中提取命名规则列表，而不是像上面那样内联列出 `permit`/`deny`。）其原则与 SIP 章节中的相同：拒绝所有内容，然后仅允许您信任的内容。无论您的 trunk context 执行什么操作，**切勿让它在没有经过深思熟虑的、经过身份验证的规则的情况下连接到可以拨出到 PSTN 的 context**——这就是经典的电话欺诈漏洞。

> **我应该使用哪种模式？** 如果提供商为您提供了用户名和密码，请使用 **注册 (registration)** trunk。如果他们要求提供您的 IP 地址并给您他们的 IP，请使用 **标识 (identify)** trunk。一些提供商同时支持这两种模式；许多真实的 trunk 会结合注册（以便提供商可以找到您）和标识（以便来自提供商媒体网关的入站 INVITE 即使在从注册服务器以外的 IP 到达时也能被匹配）。

## 入站路由与 DID 处理

一旦入站呼叫到达，它们会进入 endpoint 的 `context` —— 即 `from-pstn`。**DID**（直接拨入号码）仅仅是提供商在请求 URI 中传递给您的被叫号码。您在 dialplan 中的工作是将每个 DID 映射到一个目的地：单个 extension、IVR、队列或振铃组。

提供商发送的号码在 `from-pstn` 中作为 `${EXTEN}` 进行匹配。您能看到多少内容取决于提供商 —— 有些发送完整的 E.164 号码（`+4830001000`），有些发送国内号码，还有些只发送最后几位数字。在编写模式之前，请使用 `pjsip set logger on` 检查真实的入站呼叫并查看请求 URI。

### 一个 DID 到一个 extension

最简单的情况 —— 单个 DID 直接路由到一部电话：

```
[from-pstn]
exten => 4830001000,1,NoOp(Inbound DID: ${EXTEN} from ${CALLERID(num)})
 same =>             n,Dial(PJSIP/6001,30,tT)
 same =>             n,Hangup()
```

### 一个 DID 到一个 IVR（自动总机）

一个应该以菜单响应而不是振铃电话的主号码：

```
[from-pstn]
exten => 4830001000,1,Answer()
 same =>             n,Wait(1)
 same =>             n,Goto(ivr-main,s,1)
```

`ivr-main` 是您在 dialplan 章节中构建的自动总机 context（`Background()` + `WaitExten()`）。路由 DID 仅仅是一个 `Goto`。

### 一个 DID 到一个队列

一个应该进入呼叫队列的支持热线：

```
[from-pstn]
exten => 4830002000,1,Answer()
 same =>             n,Queue(support,t,,,300)
 same =>             n,Hangup()
```

### 同时处理多个 DID

当您购买了一组号码时，使用模式可以保持 dialplan 的简洁。假设您的 DID 范围是 `4830003000`–`4830003099`，且提供商发送的是完整号码；将每个 DID 的最后两位数字映射到 extension `60xx`：

```
[from-pstn]
exten => _48300030XX,1,NoOp(DID ${EXTEN} -> extension 60${EXTEN:-2})
 same =>             n,Dial(PJSIP/60${EXTEN:-2},30,tT)
 same =>             n,Hangup()
```

`${EXTEN:-2}` 获取最后两位数字（负偏移量从右侧开始计数），因此 `4830003007` 会振铃 `PJSIP/6007`。使用 `GoSub` 或 Asterisk 数据库（`AstDB`/`func_odbc`）构建的 `did => extension` 查找表可以进一步扩展，但对于少量号码而言，显式模式是最清晰的。

> **捕获未匹配的 DID。** 在 `from-pstn` 中添加一个 `i`（无效）extension，以便错误路由的入站号码可以播放提示音或振铃至接线员，而不是静默挂断：
>
> ```
> exten => i,1,Playback(ss-noservice)
>  same =>  n,Hangup()
> ```

## 出站路由、主叫号码和 E.164

出站呼叫的流程则相反：内部电话拨打一个号码，您的 dialplan 匹配该号码，去除任何接入前缀，设置提供商期望的主叫号码，然后通过 `Dial(PJSIP/<number>@itsp)` 将呼叫交给 trunk endpoint。

### 将呼叫发送到 trunk

trunk 的通道语法是 `PJSIP/<number>@<endpoint>`：`@` 之前的部分成为出站请求 URI 的用户部分，而 `@` 之后的部分指定了其 `aor` `contact` 提供目标主机的 endpoint。一个经典的“拨 9 拨打外线”规则如下：

```
[from-internal]
exten => _9NXXXXXXXXX,1,NoOp(Outbound to ${EXTEN:1} via itsp)
 same =>             n,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp,60,tT)
 same =>             n,Hangup()
```

`${EXTEN:1}` 在发送号码之前去除了前导的 `9` 接入码。模式 `_9NXXXXXXXXX` 匹配 `9` 加上一个首位数字为 2–9 的 10 位数字；请根据您的 dial plan 进行调整。

### 出站呼叫上的主叫号码

大多数 ITSP 会忽略——或主动拒绝——非您拥有的主叫号码。在 `Dial()` 之前，使用 `CALLERID(num)` 函数将出站主叫号码设置为您的 DID 之一，如上所示。您也可以设置名称：

```
 same => n,Set(CALLERID(num)=4830001000)
 same => n,Set(CALLERID(name)=ACME Corp)
```

如果提供商仍然去除或覆盖您的主叫号码名称，那是他们的策略——许多运营商根据号码从他们自己的 CNAM 数据库中获取显示的名称，而不是从您的 `From` 头部获取。

有两个 endpoint 选项与此相关：

- **`from_user`** 在 SIP 层面设置 `From` 头部的用户部分，一些提供商无论 `CALLERID(num)` 如何，都会使用该部分来识别您的账户。
- **`trust_id_outbound`**（默认 `no`）控制 Asterisk 是否向外发送隐私敏感的身份头部（`P-Asserted-Identity`/`P-Preferred-Identity`）。除非您的提供商明确要求使用 PAI，否则请将其关闭；如果需要，请设置 `trust_id_outbound=yes` 和 `send_pai=yes`。

### 归一化为 E.164

E.164 是国际号码格式：以 `+` 开头，后跟国家代码，然后是国内号码，不包含空格或标点符号（例如 `+5548999990000` 或 `+14155550100`）。运营商越来越期望——或要求——在 trunk 上使用 E.164 格式。与其在 dialplan 中分散处理格式，不如在出站 context 中统一进行归一化。

以下是一个北美示例，它接受 10 位本地号码、11 位以 `1` 为前缀的号码，或已经是 E.164 格式的号码，并始终向 trunk 提供 `+1…`：

```
[from-internal]
; 10-digit local: 4155550100  -> +14155550100
exten => _NXXNXXXXXX,1,Set(E164=+1${EXTEN})
 same =>            n,Goto(send-pstn,${E164},1)

; 11-digit with national prefix: 14155550100 -> +14155550100
exten => _1NXXNXXXXXX,1,Set(E164=+${EXTEN})
 same =>             n,Goto(send-pstn,${E164},1)

; already E.164: the user dialled + first
exten => _+X.,1,Goto(send-pstn,${EXTEN},1)

[send-pstn]
exten => _+X.,1,Set(CALLERID(num)=+14155550000)
 same =>     n,Dial(PJSIP/${EXTEN}@itsp,60,tT)
 same =>     n,Hangup()
```

一些提供商需要 `+`；而另一些则需要纯数字。如果您的提供商拒绝 `+`，请在 `Dial` 中使用 `${EXTEN:1}` 将其去除。关键在于所有格式化逻辑都集中在一处，因此更换提供商——或添加第二个提供商——只需修改一行代码。

## 故障转移与最低成本路由

如果只有一个 trunk，一旦服务商发生故障，外呼电话就会中断。如果拥有两个或更多 trunk，您可以实现自动故障转移，甚至可以根据目的地选择最便宜的路由——即*最低成本路由* (LCR)。

### 使用 `${DIALSTATUS}` 进行故障转移

`Dial()` 在返回时会设置 `${DIALSTATUS}` 通道变量。您需要关注的用于故障转移的值是 `CHANUNAVAIL`（完全无法连接到 trunk）和 `CONGESTION`（呼叫被拒绝，例如所有线路忙）。尝试使用主 trunk；如果它无法承载该呼叫，则回退到备用 trunk：

```
[from-internal]
exten => _9NXXXXXXXXX,1,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp_primary,60,tT)
 same =>             n,NoOp(Primary returned ${DIALSTATUS})
 same =>             n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?backup:done)
 same =>             n(backup),Dial(PJSIP/${EXTEN:1}@itsp_backup,60,tT)
 same =>             n(done),Hangup()
```

请注意，我们特意选择**不**在 `BUSY` 或 `NOANSWER` 的情况下进行故障转移——因为这些状态意味着已经联系到了*被叫方*但对方拒绝了呼叫，因此在另一个 trunk 上重试只会再次拨打一个已经拒绝的电话（而且可能会产生第二次通话费用）。只有在 *trunk 本身* 发生故障时才进行重新路由。

### 可重用的路由子程序

为每个拨号模式重复编写该逻辑很容易出错。将其提取到一个 `GoSub` 子程序中，该子程序接收目标号码并按顺序尝试每个 trunk：

```
[from-internal]
exten => _9NXXXXXXXXX,1,GoSub(dialout,s,1(${EXTEN:1}))
 same =>             n,Hangup()

[dialout]
exten => s,1,Set(NUM=${ARG1})
 same =>   n,Set(CALLERID(num)=4830001000)
 same =>   n,Dial(PJSIP/${NUM}@itsp_primary,60,tT)
 same =>   n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?try2:end)
 same =>   n(try2),Dial(PJSIP/${NUM}@itsp_backup,60,tT)
 same =>   n(try2-chk),GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?try3:end)
 same =>   n(try3),Dial(PJSIP/${NUM}@itsp_thirdparty,60,tT)
 same =>   n(end),Return()
```

现在，每个外呼模式只需调用一次 `GoSub`，且 trunk 的顺序仅在一个地方定义。

### 按目的地进行最低成本路由

真正的 LCR 会根据呼叫的目的地选择 trunk。一种常见的做法是匹配目标前缀，并将每一类呼叫发送给对其而言最便宜的服务商——例如，将国际长途发送给批发运营商，将本地/国内呼叫发送给您的主 trunk：

```
[from-internal]
; international (011 + ...) -> wholesale trunk, then fall back to primary
exten => _9011.,1,GoSub(dialout-intl,s,1(${EXTEN:1}))
 same =>      n,Hangup()
; everything else -> domestic routing
exten => _9NXXXXXXXXX,1,GoSub(dialout,s,1(${EXTEN:1}))
 same =>             n,Hangup()

[dialout-intl]
exten => s,1,Set(NUM=${ARG1})
 same =>   n,Dial(PJSIP/${NUM}@itsp_wholesale,60,tT)
 same =>   n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?fb:end)
 same =>   n(fb),Dial(PJSIP/${NUM}@itsp_primary,60,tT)
 same =>   n(end),Return()
```

对于超过几个前缀的情况，请将路由表存储在数据库（`func_odbc`/`AstDB`）中，并按前缀查找 trunk，而不是硬编码模式。这样 dialplan 可以保持精简，且费率存储在表中，您无需重新加载逻辑即可进行编辑。

## NAT 与 trunk

NAT 是导致 trunk 问题最常见的原因——通常表现为单向音频，或者 trunk 虽然注册成功但无法接收呼入电话。其原因与话机（在 *SIP & PJSIP in depth* 和 *Designing a VoIP network* 中已涵盖）相同：Asterisk 在 SIP 和 SDP 中通告的是它自己认为的地址，而在 NAT 之后，这是一个服务提供商无法路由回来的私有 RFC 1918 地址。

对于 trunk，修复方案包含两部分——**transport** 上的设置（您的公网地址）以及 **endpoint** 上的设置（如何处理服务提供商的媒体流）。

### 关于 transport — 您的公网地址

当 Asterisk 服务器本身位于 NAT 之后（例如具有私有 IP 和 1:1 公网 IP 的云主机或本地设备）时，需要告知 transport 其公网地址以及哪些网络属于本地。这些选项在 `transport` 上设置一次，并应用于通过该 transport 的所有流量：

```
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
local_net=172.30.0.0/24
local_net=10.0.0.0/8
external_media_address=203.0.113.50
external_signaling_address=203.0.113.50
```

- **`external_signaling_address`** — Asterisk 写入 SIP 头部（`Via`、`Contact`）中用于 `local_net` 之外目的地的公网 IP。
- **`external_media_address`** — Asterisk 写入 SDP `c=` 行中的公网 IP，以便 RTP 能返回到正确的位置。通常与信令地址相同。
- **`local_net`** — Asterisk 视为内部的网络，因此它不会为 LAN 对端重写地址。请列出所有内部子网。

### 关于 endpoint — 服务提供商的媒体流

另一半设置用于处理本身位于 NAT 之后，或者从非 SDP 中声明的地址发送媒体流的服务提供商。请为每个 trunk endpoint 设置以下内容：

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
outbound_auth=itsp-auth
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com
```

- **`direct_media=no`** — 保持媒体流通过 Asterisk 传输，而不是让两端直接通信。这在跨越 NAT 时至关重要，并且如果您需要录音、转码或监听通话，这也是必需的。
- **`rtp_symmetric=yes`** — 经典的 *comedia* 行为：将 RTP 发送回媒体流实际来源的地址，而不是 SDP 声称的地址。
- **`force_rport=yes`** — 从请求的源 IP/端口（RFC 3581）回复 SIP，而不是信任 `Via` 头部。
- **`rewrite_contact=yes`** — 在来自此 endpoint 的入站 SIP 消息上，将 `Contact` 头部（或适当的 `Record-Route` 头部）重写为数据包实际来源的源 IP 地址和端口。根据该选项自身的文档，这“有助于服务器与位于 NAT 之后的 endpoint 通信”，并“有助于重用诸如 TCP 和 TLS 之类的可靠传输连接”。

> **建议 — 话机与 trunk 的对比。** `rewrite_contact` 对于话机来说几乎总是正确的选择，因为它们通告的联系地址通常是无法路由回来的私有 RFC 1918 地址。在基于静态 IP 的 trunk 上，服务提供商的联系地址通常已经是正确的公网地址，因此重写它往往是不必要的；一些运营商倾向于在静态 trunk 上关闭它，仅对注册型 trunk 和 NAT 后的话机启用。该选项记录的效果仅限于上述入站 `Contact`/`Record-Route` 重写——因此，最稳妥的做法是在静态 trunk 上启用它之前，先针对您的特定运营商进行测试。

您可以使用 `pjsip show endpoint <name>` 来确认任何 endpoint 上的有效设置——`direct_media`、`rtp_symmetric`、`force_rport`、`rewrite_contact` 以及其余参数都会在参数转储中打印出来。

## 实验 — 使用第二个 Asterisk 和 SIPp 模拟 ITSP

你不需要付费的 trunk 即可进行练习。本书的实验环境已经在私有的 `172.30.0.0/24` 网络中运行了一个 Asterisk 22.10.0 容器和一个 SIPp 容器；我们将把 SIPp 容器视为发起入站呼叫的“运营商”，并添加一个将这些呼叫接入 `from-pstn` context 的 trunk endpoint。

![Asterisk PBX 与 ITSP 之间的 SIP trunk：PBX 注册为一个账户，出站呼叫拨打 `PJSIP/<num>@trunk`，入站呼叫接入 `from-pstn` context。](images/trunk-diagram.png){width=100%}(../images/09-sip-trunking-fig01.png)

### 1. 添加 trunk endpoint

在 `lab/asterisk/etc/pjsip.conf` 中添加一个基于 IP 的 trunk，使其匹配实验环境的 SIPp 主机并将入站呼叫接入 `from-pstn`：

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
aors=itsp-aor

[itsp-aor]
type=aor
contact=sip:172.30.0.50:5060

[itsp-identify]
type=identify
endpoint=itsp
match=172.30.0.50
```

### 2. 路由入站 DID

在 `lab/asterisk/etc/extensions.conf` 中，添加一个 `from-pstn` context，用于应答模拟运营商拨打的 DID 并播放语音，然后添加一条出站规则：

```
[from-pstn]
exten => 4830001000,1,NoOp(Inbound DID ${EXTEN} from ${CALLERID(num)})
 same =>             n,Answer()
 same =>             n,Playback(demo-congrats)
 same =>             n,Hangup()
exten => i,1,Playback(ss-noservice)
 same =>  n,Hangup()

[from-internal]
; outbound across the trunk
exten => _9X.,1,Set(CALLERID(num)=4830001000)
 same =>     n,Dial(PJSIP/${EXTEN:1}@itsp,30,tT)
 same =>     n,Hangup()
```

重新加载这两个文件（`core reload`）并验证 trunk 是否已加载：

```
*CLI> pjsip show endpoint itsp
 Endpoint:  itsp                                                 Not in use    0 of inf
        Aor:  itsp-aor                                           0
      Contact:  itsp-aor/sip:172.30.0.50:5060              ...        NonQual         nan
   Identify:  itsp-identify/itsp
        Match: 172.30.0.50/32
```

### 3. 通过 trunk 发起入站呼叫

将 SIPp 场景指向 PBX，并将 DID 作为目标用户。实验环境已经内置了 `lab/sipp/uac_9000.xml`，它会 INVITE extension `9000`；将其复制到 `uac_did.xml` 并将 request-URI/`To` 用户从 `9000` 修改为 `4830001000`，然后在 SIPp 容器中运行它：

```
docker compose -f lab/docker-compose.yml exec -T sipp \
  sipp -sf /sipp/uac_did.xml 172.30.0.10:5060 -m 1 -nostdin
```

观察呼叫在 Asterisk 控制台上触发 `from-pstn`（`pjsip set logger on` 显示入站 INVITE；`core show channels` 显示 `PJSIP/itsp-…` 通道正在播放 `demo-congrats`）。由于 SIPp 的源 IP 与 `identify` 匹配，呼叫无需认证即可被接受 — 这正是静态运营商 trunk 的工作方式。

### 4. 检查 trunk

捕获 trunk 的完整配置以备记录：

```
pjsip show endpoint itsp
pjsip show aors
pjsip show identifies
```

### 5.（进阶）将其配置为注册型 trunk

启动第二个 Asterisk 容器作为真正的注册服务器：为账户 `4830001000` 提供一个 `endpoint`+`auth`+`aor`，然后在 PBX 上将 `identify` 块替换为本章开头的 `registration` 块（将 `server_uri` 指向第二个容器的 IP）。使用 `pjsip show registrations` 确认状态显示为 `Registered`，然后尝试在两个方向上拨打电话。

## 总结

SIP trunk 将您的 PBX 连接到外部世界，在 PJSIP 中，它只是一个由您已经熟悉的 `endpoint` + `auth` + `aor` 系列构建而成的 endpoint，外加一个 `identify` 或 `registration`。当服务提供商为您提供用户名和密码时，请使用**注册中继**（`type=registration` 配合 `outbound_auth`）；当通过源 IP 进行身份验证时，请使用 **IP 中继**（`type=identify` 配合 `match`）——并使用严格的 `match` 和 `acl` 对后者进行锁定，因为未经身份验证的 trunk 是电话欺诈的目标。在入站方向，服务提供商的 DID 会作为 `${EXTEN}` 到达您的 `from-pstn` context，您可以在此处将其路由至 extension、IVR 或队列——模式匹配和 `${EXTEN:-N}` 可以保持 DID 块的简洁。在出站方向，将 `CALLERID(num)` 设置为您拥有的号码，在一个地方将其标准化为 E.164，然后将呼叫移交给 `PJSIP/<number>@trunk`。通过尝试多个 trunk 并根据 `${DIALSTATUS}` 进行分支来构建弹性（`CHANUNAVAIL`/`CONGESTION` 表示重新路由；`BUSY`/`NOANSWER` 则不执行），并将最低成本路由放入 `GoSub` 表中。最后，trunk 的 NAT 是双向的：在 **transport** 上使用 `external_media_address`/`external_signaling_address`/`local_net` 来处理您的公网地址，并在 **endpoint** 上使用 `direct_media=no`、`rtp_symmetric`、`force_rport` 和 `rewrite_contact` 来处理服务提供商的媒体流。

## 测试题

1. 在 PJSIP 中，用于验证*出站*呼叫或向服务提供商注册的凭据通过以下哪项引用：
   - A. `auth=`
   - B. `outbound_auth=`
   - C. `secret=`
   - D. `remotesecret=`
2. 在以下哪种情况下，你应该使用 `type=registration` trunk：
   - A. 服务提供商通过你的源 IP 地址来识别你。
   - B. 服务提供商为你提供了用户名和密码，并要求你进行登录。
   - C. 你不希望 Asterisk 发送任何 `REGISTER`。
   - D. 该 trunk 位于你所控制的两台静态 IP 服务器之间。
3. `identify` 对象的 `match` 选项接受（选择所有适用项）：
   - A. IP 地址
   - B. CIDR 范围
   - C. 主机名（在配置加载时解析）
   - D. 仅 SIP 用户名
4. 在 Asterisk 22 上，`auth_type=userpass` 是：
   - A. 唯一有效的值
   - B. 已弃用并转换为 `digest`
   - C. 已移除并会导致加载错误
   - D. 出站注册所必需的
5. 入站 DID 号码进入 dialplan 的方式为：
   - A. `${CALLERID(num)}`
   - B. trunk endpoint 的 `context` 中的 `${EXTEN}`
   - C. `${DIALSTATUS}`
   - D. `${CONTEXT}`
6. 若要将所拨打 DID `4830003007` 的最后两位数字发送到某个 extension，你应该使用：
   - A. `${EXTEN:2}`
   - B. `${EXTEN:0:2}`
   - C. `${EXTEN:-2}`
   - D. `${EXTEN:8}`
7. 在向 trunk `Dial()` 之后，你应该故障转移到备用 trunk，在该 trunk 上应设置哪些 `${DIALSTATUS}` 值（选择两项）：
   - A. `CHANUNAVAIL`
   - B. `BUSY`
   - C. `CONGESTION`
   - D. `NOANSWER`
8. 若要在拨出电话前设置呈现给服务提供商的主叫号码（caller-ID），请使用：
   - A. `Set(CALLERID(num)=4830001000)`
   - B. `Set(from_user=4830001000)`
   - C. `Set(DIALSTATUS=4830001000)`
   - D. `Set(CONNECTEDLINE(num)=4830001000)`
9. 当服务器位于 NAT 之后时，告知 Asterisk 其*公网*地址的选项设置在：
   - A. `endpoint`
   - B. `aor`
   - C. `transport` (`external_media_address` / `external_signaling_address`)
   - D. `registration`
10. 在 trunk endpoint 上设置 `rtp_symmetric=yes` 会导致 Asterisk：
    - A. 使用 SRTP 加密 RTP
    - B. 将 RTP 发送回媒体实际到达的地址，忽略 SDP
    - C. 完全禁用 RTP
    - D. 强制 endpoint 之间进行直接媒体传输

**答案：** 1 — B · 2 — B · 3 — A, B, C · 4 — B · 5 — B · 6 — C · 7 — A, C · 8 — A · 9 — C · 10 — B
