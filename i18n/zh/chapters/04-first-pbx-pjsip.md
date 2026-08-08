# 使用 PJSIP 构建您的第一个 PBX

在本章中，您将学习如何执行基本的 Asterisk PBX 配置。本章的主要目标是让您首次运行 PBX，实现分机间的拨号、拨打播放消息，以及拨打单个模拟或 SIP trunk。本章的宗旨是确保您的 Asterisk 能够尽快启动并运行。完成本章的工作后，您将具备足够的背景知识，为后续章节做好准备，届时我们将深入探讨配置细节。

## 目标

在本章结束时，你应该能够：

- 理解并编辑配置文件；
- 安装基于 SIP 的 softphone；
- 安装并配置 SIP trunk；
- 安装并配置模拟连接；
- 在 extension 之间拨打电话；
- 在电话和外部目的地之间拨打电话；以及
- 配置自动总机（auto attendant）。

## 理解配置文件

Asterisk 由位于 /etc/asterisk 中的文本配置文件进行控制。该文件格式类似于 Windows 的“.ini”文件。分号用作注释字符，“=”和“=>”符号是等效的，且空格会被忽略。

```
;
; The first line without a comment should be the session title.
;
[Session]
Key = value; Variable designation
[Session 2]
Key => value; Object declaration
```

Asterisk 以相同的方式解释“=”和“=>”。语法上的差异用于区分对象和变量。当您想要声明变量时使用“=”，而指定对象时使用“=>”。所有文件之间的语法都是相同的，但使用了三种类型的语法规则，如下所述。

## 语法

| 语法 | 对象创建方式 | 配置文件 | 示例 |
|---------|---------------------------|------------|---------|
| 简单组 | 全部在同一行 | `extensions.conf` | `exten => 4000,1,Dial(PJSIP/4000)` |
| 选项继承 | 先定义选项，对象继承这些选项 | `chan_dahdi.conf` | `[channels]; context=default; signalling=fxs_ks; group=1; channel => 1` |
| 复杂实体 | 每个实体拥有一个 context | `pjsip.conf`, `iax.conf` | `[cisco]; type=endpoint; auth=cisco-auth; aors=cisco; context=trusted` |

### 简单组

`extensions.conf`和`voicemail.conf`中使用的简单组格式是最基本的语法。每个对象及其选项都在同一行中声明。示例：

```
[Session]
Object 1 => op1,op2,op3
Object 2=> op1b,op2b,op3b
```

在此示例中，对象 1 使用选项 op1、op2 和 op3 创建，而对象 2 也使用选项 op1、op2 和 op3 创建。

### 对象选项继承语法

此格式由 chan_dahdi.conf 和 agents.conf 文件使用，其中有大量可用选项，且大多数接口和对象共享相同的选项。通常，一个或多个部分包含对象和通道声明。对象的选项在对象上方声明，并且可以针对另一个对象进行更改。虽然这个概念很难理解，但它非常易于使用。示例：

```
[Session]
op1 = bas
op2 = adv
object=>1
op1 = int
object => 2
```

前两行分别将选项 op1 和 op2 的值配置为 “bas” 和 “adv”。当实例化对象 1 时，它使用选项 1 为 “bas” 且选项 2 为 “adv” 进行创建。定义对象 1 后，我们将选项 1 更改为 “int”。接下来，我们创建对象 2，其选项 1 为 “int”，选项 2 为 “adv”。

### 复杂实体对象

此格式由 pjsip.conf、iax.conf 以及其他存在大量带有许多选项的实体的配置文件使用。通常，此格式不会共享大量的通用配置。每个实体都会接收一个 context。有时存在保留的 context，例如用于全局配置的 [general]。选项在 context 声明中进行声明。示例：

```
[entity1]
op1=value1
op2=value2
[entity2]
op1=value3
op2=value4
```

实体 [entity1] 的选项 op1 和 op2 的值分别为 “value1” 和 “value2”。实体 [entity2] 的选项 op1 和 op2 的值分别为 “value3” 和 “value4”。

## 构建 Asterisk 实验环境的方案

要配置一台 PBX，你需要一些基础硬件。这并不困难，也不昂贵，但有一些选项需要考虑。你只需要两部电话和一个连接到公共网络的接口。在创建实验环境时，有几种方案和组合可供选择，我们将在下面进行讨论。

### 方案 1：完整实验环境

使用完整实验环境，可以测试所有可用的场景，并比较 ATA、IP-phone 和 softphone 等解决方案。你还可以了解模拟 trunk 和 SIP trunk。你需要：

- 一个 SIP 模拟电话适配器 (ATA)
- 一部 IP-phone
- 一台专用的 Asterisk 服务器
- 一台安装了 softphone 的工作站
- 一块至少有两个接口（1 个 FXO 和 1 个 FXS）的模拟接口卡
- 一个 VoIP 提供商账号

### 方案 2：经济型实验环境

使用经济型实验环境，我们对其进行了一些简化。我们使用 ATA（通常比 IP-phone 便宜）和一块非常便宜的单口 FXO 卡。虽然我们无法直接将模拟电话连接到服务器，但这在实际应用中并不常见。你需要：

- 一个 SIP 模拟电话适配器 (ATA)
- 一台专用的 Asterisk 服务器
- 一台用于运行 softphone 的工作站
- 一块带有 1 个 FXO 的模拟接口卡
- 一个 VoIP 提供商账号

### 方案 3：超经济型实验环境

第三种实验环境是在学生的笔记本电脑上使用虚拟化服务器。这种模式的问题在于 UDP 端口冲突。有时 Asterisk 服务器和 softphone 会尝试访问同一个端口，导致 Asterisk 无法绑定地址端口。另一个问题是通话质量；虚拟环境并不适合像 Asterisk 这样的实时应用。在服务器和工作站上使用免费的 softphone，并通过 trunk 连接到 SIP 提供商。你需要：

- 一台运行 softphone 的笔记本电脑
- 一台用于安装 Asterisk 的虚拟机（VirtualBox、VMware 或类似软件）
- 一个 VoIP 提供商账号

## 安装顺序

为了帮助您理解安装顺序，我们列出了安装和配置 Asterisk 所需的步骤序列。

![参考实验室布局：作为 extension (1) 的 SIP/IAX softphone、IP phone 和模拟适配器，带有 ETH0/FXO/FXS 接口的 Asterisk 服务器 (3)，以及通过 VoIP 提供商或宽带链路连接到 PSTN 的 trunk (2)。]((../images/04-first-pbx-fig01.png))

1. extension 配置
   - a. SIP extension (ATA, softphone, IP phone)
   - b. IAX extension
   - c. FXS extension
2. trunk 配置
   - a. SIP trunk 的配置
   - b. FXO trunk 的配置
3. 构建基础 dialplan
   - a. 在 extension 之间拨号
   - b. 拨打外部目的地
   - c. 从操作员 extension 接听呼叫
   - d. 在 IVR 中接听呼叫

## 分机配置

分机是指 SIP、IAX 或连接到 FXS 端口的模拟电话。要配置分机，您应该编辑与通道相关的配置文件（pjsip.conf、iax.conf、chan_dahdi.conf）。

### SIP 分机

在 Asterisk 22 上，PJSIP（`res_pjsip` 堆栈，在 `/etc/asterisk/pjsip.conf` 中配置）是 SIP 通道驱动程序。它支持每个 endpoint 拥有多个传输方式，处于活跃维护状态，并且是该平台附带的唯一 SIP 驱动程序。（原始的 `chan_sip` 驱动程序已在 Asterisk 21 中移除——如果您需要迁移旧配置，请参阅 *Legacy channels* 一章。）

这里的思路是配置一个简单的 PBX。（后续章节将提供完整的 SIP/PJSIP 会话及所有细节。）PJSIP 在 `/etc/asterisk/pjsip.conf` 中配置，并包含与 SIP 电话和 VoIP 提供商相关的所有参数。在拨打和接听电话之前，必须先配置 SIP 客户端。

#### 传输层

在 PJSIP 中，监听器配置（绑定地址、端口、协议）存在于 `transport` 对象中。Asterisk 具有针对用户名猜测的内置保护机制——它始终为未知用户和已知用户返回相同的身份验证质询，并且来自同一 IP 的重复未识别请求会通过 `[global]` 选项 `unidentified_request_count`/`unidentified_request_period` 进行速率限制。传输层的主要选项包括：

- protocol：传输协议——`udp`、`tcp`、`tls`、`ws`或`wss`。
- bind：监听器绑定的地址和端口。如果您将地址设置为 `0.0.0.0`，它将绑定到所有接口；SIP 端口对于 UDP/TCP 默认为 5060。

一个最小化的 UDP 传输配置：

```
[global]
type=global

[transport-udp]
type=transport
protocol=udp
bind=10.1.30.45:5060
```

编解码器选择（`disallow`/`allow`）和默认的 `context` 是在每个 `endpoint`（如下所示）上配置的，而不是在传输层上配置的。匿名/访客呼叫由名为 `anonymous` 的 `endpoint` 处理。注册计时器通过 `maximum_expiration`/`default_expiration` 按 AOR 进行控制。

#### SIP 客户端

完成传输层部分后，现在是设置 SIP 客户端的时候了。我再次提醒读者，本书后面会有专门的 SIP/PJSIP 章节。目前，我们先专注于基础知识，将细节留到后面。

在 PJSIP 中，SIP 客户端由一组相关对象构建，并通过名称引用绑定在一起：

- `endpoint`：呼叫行为——编解码器（`allow`/`disallow`）、dialplan `context`，以及它使用的 `auth` 和 `aors`。
- `auth`：凭据。`username` 是 SIP 身份验证用户名，`password` 是用于验证设备的密码。
- `aor`：“记录地址”（Address of Record）——即可以联系到 endpoint 的位置。可以是静态的 `contact=`（用于固定 IP 的设备），也可以是 `max_contacts=`，允许设备动态注册。

警告：请使用强密码，至少包含 8 个字符，包含字母和数字，并至少包含一个符号。邮件列表中已经出现了服务器被黑的报告，而且针对 SIP 的暴力破解密码工具对于脚本小子来说很容易获得。通话欺诈会给消费者和提供商造成数千美元的损失。

Endpoint 6000 是一个固定 IP 的设备，因此其 AOR 携带静态 `contact`，而不是允许注册。Endpoint 6001 是一个可以注册的设备，因此其 AOR 允许它进行注册（`max_contacts=1`）：

```
[6000]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=6000-auth
aors=6000

[6000-auth]
type=auth
auth_type=digest
username=6000
password=#MySecret1#7

[6000]
type=aor
contact=sip:6000@10.1.30.50

[6001]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=6001-auth
aors=6001

[6001-auth]
type=auth
auth_type=digest
username=6001
password=Mys3cr3t#

[6001]
type=aor
max_contacts=1
```

PJSIP 允许 `endpoint`、`auth` 和 `aor` 部分共享相同的节名称（例如上面两个通过 `type=` 区分的 `[6001]` 块）；许多管理员为了可读性，会改为使用后缀（`[6001]`、`[6001-auth]`、`[6001]` aor）。对于注册设备，联系地址是在电话注册时动态获知的，因此 AOR 不需要静态 `contact`。

## IAX 分机

`chan_iax2` 在 Asterisk 22 中仍然提供，但现在已属于旧版（legacy）；SIP/PJSIP 是新部署的首选协议。

您也可以创建 IAX 分机。该协议是 Asterisk 的原生协议，本书稍后将用专门的章节进行介绍。现在，让我们使用该协议创建几个分机。作为第一个需要配置的部分，[general] 部分有一些参数需要设置。主要选项如下：

- allow/disallow：定义将要使用的 codec。
- bindaddr：IAX2 监听程序绑定的地址。如果将其设置为 0.0.0.0（默认值），它将绑定到所有接口。
- context：设置所有客户端的默认 context，除非在客户端部分进行了更改。出于安全考虑，我们使用了 dummy。当 allowguest 选项设置为 yes 时，未经身份验证的用户将进入此 context。
- bindport：IAX2 监听的 UDP 端口（默认 4569）。
- delayreject：当设置为 yes 时，会延迟发送 REGREQ 或 AUTHREQ 的身份验证拒绝响应，这可以提高针对暴力破解密码攻击的安全性。
- bandwidth：当设置为 high 时，允许选择高带宽 codec，例如 g711 的 ulaw 和 alaw 变体。

以下是 iax.conf 文件中 [general] 部分的示例。

```
[general]
bindport = 4569
bindaddr = 10.1.30.45 ;(use your IP)
context = dummy
delayreject=yes
bandwidth=high
disallow = all
allow = ulaw
```

### IAX 客户端

完成通用部分后，现在是时候设置 IAX 客户端了。

- `[name]`：该部分名称即为 IAX peer/user 名称；传入的 IAX 连接通过名称与此匹配。
- `type`：连接类型 — `peer`、`user`或 `friend`：
  - `peer`：Asterisk 向 peer 发送呼叫。
  - `user`：Asterisk 从 user 接收呼叫。
  - `friend`：同时支持两个方向。
- `host`：IP 地址或主机名。最常见的值是 `dynamic`，用于设备注册到 Asterisk 时。
- `secret`：用于验证 peer 和 user 的密码。

警告：请使用至少 8 个字符的强密码，包含字母和数字，并至少包含一个符号。邮件列表中已出现过服务器被黑的报告，且针对 IAX md5 哈希的暴力破解密码工具已可供脚本小子使用。电话欺诈会给消费者和提供商造成数千美元的损失。示例：

```
[guest]
type=user
context=dummy
callerid="Guest IAX User"
[6003]
type=friend
context=from-internal
secret=#sup3rs3cr3t#
host=dynamic
[6004]
type=friend
context=from-internal
secret=#s3cr3ts3cr3t#
host=dynamic
```

## 配置 SIP 设备

在 Asterisk 配置文件中定义话机后，现在是时候配置话机本身了。在本示例中，我们将展示如何配置一款免费的 softphone —— SipPulse Softphone（请从 https://www.sippulse.com/produtos/softphone 下载）。请查阅您设备的手册以了解您话机的参数。第 1 步：配置话机以使用 extension 6000。执行安装程序。执行完成后，打开账户/SIP 设置并添加一个新的 SIP 账户。填写所需信息。

![SipPulse Softphone 账户界面 —— 输入 Server（您的 Asterisk IP 或域名）、User Name、Password 和 Display Name，然后选择 Transport（UDP、TCP 或 TLS）。](../images/softphone/sipphone-account.png){width=35%}

Display Name: 6000  User Name: 6000  Password: #MySecret1#7  Authorization User Name: 6000  Domain: ip_of_your_server。使用控制台命令 `pjsip show endpoints`（或 `pjsip show endpoint 6000` 以获取详细信息；`pjsip show contacts` 显示已注册的 AOR 联系人）确认您的话机已注册。对 6001 话机重复上述配置。

![已注册的 SipPulse Softphone —— 绿点和账户行（`1001@softphone.sippulse.com.br`）确认了注册状态；通过小键盘或呼叫/视频按钮拨打电话。](../images/softphone/sipphone-registered.png){width=35%}

## 配置 IAX 设备

IAX2 是一种传统协议（请参阅 *Legacy channels* 一章），而 SipPulse Softphone 仅支持 SIP，因此它无法注册 IAX 账户。如果您需要测试 IAX2，请使用仍然支持该协议的 softphone。创建一个新的 IAX 账户，

3. 选择新的 IAX 账户。
4. 为 6003 电话插入相关选项，并可选择为 6004 插入选项。
5. 保存配置并使用 `iax2 show peers` 检查电话是否已注册。

重要提示：请为 SIP 使用一个账户，为 IAX 使用另一个账户。如果您想将系统配置为同时呼叫 IAX 和 SIP，我们将在 dialplan 部分向您展示如何操作。

### 配置 PSTN 接口

要连接到 PSTN，您需要一个外汇局 (FXO) 接口和一条电话线。您也可以使用现有的 PBX extension。您可以从多家制造商处获得带有 FXO 接口的电话接口卡。在本例中，我们将向您展示如何安装 DAHDI 接口卡。

![FXS 和 FXO 端口：FXS 端口驱动模拟电话（提供拨号音和振铃），而 FXO 端口将 Asterisk 连接到电信线路。](FXS_FXO_ports.png)(../images/04-first-pbx-fig02.png)

### 使用 DAHDI 的模拟线路

您可以从多家制造商处购买与 DAHDI 兼容的模拟卡。X100P 是 Digium 最早的卡之一，现已停产。一些制造商仍在生产类似的克隆产品。除了 X100P 的价格外，我们还发现这些卡与新主板之间存在一些问题，因此请谨慎使用。在我看来，X100P 不是生产环境的理想选择。任何与 DAHDI 兼容的卡都应该可以使用。感谢 DAHDI 开发团队，我们现在有了一个几乎可以自动检测和配置接口卡的工具。如果您刚刚安装了 DAHDI 驱动程序，请不要忘记运行 make config 并重启机器以自动加载它。您可以使用以下命令来检测和配置您的卡。第 1 步：要检测您的硬件，请使用：

```
dahdi_hardware
```

第 2 步：要进行配置，请使用：

```
dahdi_genconf
```

上述命令将生成两个文件 /etc/dahdi/system.conf 和 /etc/asterisk/dahdi-channels.conf。dahdi_genconf 的默认参数通常没问题，但您可以在 /etc/dahdi/genconf_parameters 文件中更改它们。默认情况下，它会将线路 (FXO) 插入到 context from-pstn 中，并将电话 (FXS) 插入到 context from-internal 中。第 3 步：运行 dahdi_genconf 后，在 /etc/asterisk/chan_dahdi.conf 文件的最后一行插入以下行：

```
#include dahdi-channels.conf
```

第 4 步：编辑 /etc/dahdi/modules 文件，并注释掉所有未使用的驱动程序。在继续之前重启，并使用以下命令检查通道是否被识别：

```
*CLI> dahdi show channels
```

### 使用 VoIP 提供商连接到 PSTN

如果您的预算非常有限，您可以配置一个 SIP trunk 来连接到 PSTN。这无疑是连接到 PSTN 最经济实惠的方式。全球有成千上万的 VoIP 提供商。要连接到其中之一，您需要一些参数。由 SIP 提供商提供的参数。

- username: login
- password: secret
- Provider’s domain: domain
- UDP port: 5060
- Allowed codecs: g729, ilbc, alaw

有两个参数需要由您确定。

- 接收呼叫的 extension——在本例中为：9999
- context: from-sip

在 PJSIP 中，注册 SIP trunk 是由用于 endpoint 的相同对象系列构建的，外加显式的 `registration` 和 `identify` 对象。`registration` 对象告诉 Asterisk 向提供商注册，`identify` 对象将来自提供商 IP 的入站流量匹配到 endpoint（PJSIP 通过源 IP 验证入站 INVITE），而 `outbound_auth` 提供出站呼叫和注册所需的凭据：

```
[siptrunk]
type=endpoint
context=from-sip
disallow=all
allow=ilbc
allow=alaw
allow=g729
dtmf_mode=rfc4733
outbound_auth=siptrunk-auth
aors=siptrunk
from_user=login
from_domain=domain

[siptrunk-auth]
type=auth
auth_type=digest
username=login
password=secret

[siptrunk]
type=aor
contact=sip:domain:5060

[siptrunk]
type=identify
endpoint=siptrunk
match=domain

[siptrunk-reg]
type=registration
transport=transport-udp
outbound_auth=siptrunk-auth
server_uri=sip:domain:5060
client_uri=sip:login@domain:5060
contact_user=9999
retry_interval=60
```

要访问此 trunk，我们将使用通道名称 `PJSIP/siptrunk`。设置 `dtmf_mode=rfc4733` 在带外传输 DTMF（RFC 4733 废弃了较旧的 RFC 2833；有效载荷是相同的）。`identify`/`match` 选项接受 IP 地址、CIDR 或主机名，但主机名仅在配置加载时解析一次，因此对于 IP 经常变化的提供商，请明确列出信令 IP。使用 `pjsip show registrations` 确认注册。

## Dial plan 简介

Dial plan 就像是 Asterisk 的心脏。它定义了 Asterisk 如何处理发送到 PBX 的每一通呼叫。它由一系列 extension 组成，这些 extension 为 Asterisk 制定了需要遵循的指令列表。指令由从 channel 或应用程序接收到的数字触发。为了成功配置 Asterisk，理解 dial plan 至关重要。大部分 dial plan 都包含在 /etc/asterisk 目录下的 extensions.conf 文件中。该文件使用简单的分组语法，并包含四个主要概念：

- Extension
- Priority
- Application
- Context

让我们创建一个基础的 dial plan。在本书的后续章节中，我将专门用一章来介绍 dial plan。如果您安装了示例文件（make samples），那么 extensions.conf 已经存在了。请将其另存为其他名称，并从一个空白文件开始。

## extensions.conf 文件的结构

extensions.conf 文件被分为多个部分。首先是 [general] 部分，随后是 [globals] 部分。每个部分的开头由其名称定义（例如 [default]）开始，并在创建另一个部分时结束。

### [general] 部分

general 部分位于文件的顶部。在开始配置 dialplan 之前，了解控制某些 dialplan 行为的通用选项会很有帮助。这些选项包括：

- static 和 write protect：如果设置为 `static=yes` 和 `writeprotect=no`，您可以使用以下 CLI 命令将正在运行的 dialplan 保存回磁盘：

```
*CLI> dialplan save
```

警告：如果您从 CLI 发出 `dialplan save` 命令，您将丢失文件中的所有备注和注释。

- autofallthrough：如果设置了 autofallthrough，那么当 extension 执行完毕后，它将根据 Asterisk 的最佳判断，以 BUSY、CONGESTION 或 HANGUP 终止呼叫。这是默认设置。如果未设置 autofallthrough，那么当 extension 执行完毕后，Asterisk 将等待拨打新的 extension。
- clearglobalvars：如果设置了 clearglobalvars，全局变量将在 dialplan reload 或 Asterisk reload 时被清除并重新解析。如果未设置 clearglobalvars，则全局变量将在重载期间保持不变，即使从 extensions.conf 或其包含的文件中删除了它们，它们仍将保持为之前的值。
- extenpatternmatchnew：使用更快的模式匹配算法，当您拥有大量 extension 时，这会有明显的帮助。默认为 no。
- userscontext：这是来自 users.conf 的条目所注册的 context。

### [globals] 部分

在 [globals] 部分，您将定义全局变量及其初始值。您可以在 dialplan 中使用 ${GLOBAL(variable)} 来访问该变量。您甚至可以使用 ${ENV(variable)} 访问在 linux/unix 环境中定义的变量。全局变量不区分大小写。以下是一些示例：

```
INCOMING=>DAHDI/8&DAHDI/9
RINGTIME=>3
```

在下面的示例中，您可以在 dialplan 中设置并测试一个全局变量。

```
exten=9000,1,set(GLOBAL(RINGTIME)=4)
exten=9000,n,Noop(${GLOBAL(RINGTIME)})
exten=9000,n,hangup()
```

## Contexts

Context 是 dialplan 的命名分区。在 [general] 和 [globals] 部分之后，dialplan 是一组 context，其中每个 context 包含多个 extension，每个 extension 包含多个 priority，每个 priority 调用一个带有多个参数的 application。

![Asterisk 呼叫流程：每个呼叫都以入局呼叫段的形式到达通道（IAX、SIP 等）；通道的 context（在通道配置文件中全局设置或按通道设置）决定了在呼叫离开出局呼叫段之前，extensions.conf 中的哪个 context 处理该呼叫。]((../images/04-first-pbx-fig03.png))

![呼叫处理：为通道定义的 `context=`（在 chan_dahdi.conf 或 pjsip.conf 中）指定了 extensions.conf 中匹配的 context，dialplan 在该 context 中处理呼叫。]((../images/04-first-pbx-fig04.png))

您可以构建一个简单的 dialplan 来连接其他电话和 PSTN。然而，Asterisk 的功能远不止于此。我们的目标是向您传授 dialplan 中可能实现的更多细节。

## Extensions

与传统的 PBX 不同（在传统 PBX 中，extension 与电话、接口、菜单等相关联），在 Asterisk 中，extension 是当特定的 extension 号码或名称被触发时所要处理的命令列表。这些命令按优先级顺序进行处理。

![Extension 语法：`exten => number(name),{priority|label}[(alias)],application`。Extension 可以是数字、字母数字、带 caller ID 的数字、模式，或者像 `s` 这样的标准 extension；优先级可以是数字、`n`（下一个）、`s`（相同）、偏移量或 `hint`。](../images/04-first-pbx-fig05.png)

Extension 可以是字面量、标准或特殊的。标准 extension 仅包含数字或名称以及字符 * 和 #；12#89* 是一个有效的字面量 extension。名称也可以用于 extension 匹配。Extension 是区分大小写的。但是，你不能创建两个名称相同但大小写不同的 extension。当拨打一个 extension 时，会执行优先级为 1 的命令，接着是优先级为 2 的命令，依此类推。此过程会一直持续，直到呼叫断开或某个命令返回数字 1（表示失败）。当执行到最后一个优先级时 Asterisk 的行为由参数 autofallthrough 调节。请参阅本章中的 [general] 部分。示例：

```
exten=>123,1,Answer
exten=>123,n,Playback(tt-weasels)
exten=>123,n,Hangup
```

在上面，你可以找到拨打 extension 123 时要处理的指令列表。第一个优先级是应答通道（当通道处于振铃状态时是必需的：例如 FXO 通道）。第二个优先级是回放名为 tt-weasels 的音频文件。第三个优先级是挂断通道。另一个选项是根据 caller ID 处理呼叫。你可以使用 / 字符来指定要处理的 caller ID。示例：

```
exten=>123/100,1,Answer()
exten=>123/100,n,Playback(tt-weasels)
exten=>123/100,n,Hangup()
```

此示例将触发 extension 123，并且仅在 caller ID 为 100 时执行以下选项。这也可以通过使用下面描述的模式来实现：

```
exten=>1234/_256NXXXXXX,1,Answer()
```

hint：将 extension 映射到通道。它用于监控通道状态。它与 presence 结合使用。电话必须支持此功能。

#### 模式 (Patterns)

你可以在 dialplan 中使用模式和字面量。模式对于减小 dialplan 的大小非常有用。所有模式都以 “_” 字符开头。可以使用以下字符来定义模式。该图标识了可与 Asterisk 一起使用的模式。

![模式匹配字符：`_` 启动一个模式，`.` 匹配一个或多个字符，`!` 匹配零个或多个，`[123-7]` 匹配任何列出的数字或范围，`X` 是 0-9，`Z` 是 1-9，`N` 是 2-9 — 并附有映射办公 extension 范围的示例。](../images/04-first-pbx-fig06.png)

### 特殊 Extensions

Asterisk 使用一些 extension 名称作为标准 extension。

![Asterisk 特殊 extensions：`i` (无效), `s` (开始), `h` (挂断), `t` (超时), `T` (绝对超时), `o` (接线员), `a` (在 voicemail 中按下 `*`), `fax` (传真检测), 以及 `Talk` (与 BackgroundDetect 一起使用)。](../images/04-first-pbx-fig07.png)

描述：

- **s**：Start（开始）。它用于在没有拨打号码时处理呼叫。它对于 FXO trunk 和菜单内处理非常有用。
- **t**：Timeout（超时）。它用于在播放提示音后呼叫保持不活动状态时。它也用于挂断不活动的线路。
- **T**：AbsoluteTimeout（绝对超时）。如果你使用 `TIMEOUT(absolute)` dialplan 函数建立了呼叫限制，一旦呼叫超过定义的限制，它将被发送到 T extension。
- **h**：Hangup（挂断）。它在用户断开呼叫后被调用。
- **i**：Invalid（无效）。当你在 context 中拨打不存在的 extension 时触发。使用这些 extension 可能会影响 CDR 记录的内容——特别是 dst 字段，它将不包含拨打的号码。
- **o**：Operator（接线员）。它用于在用户在 voicemail 期间按下 "0" 时转接至接线员。

使用这些 extension 可能会改变计费记录 (CDR) 的内容——特别是 dst 字段将不会包含拨打的号码。为了解决这个问题，你应该在 dial() 应用程序中使用选项 g，并考虑使用函数 resetcdr(w) 和/或 nocdr()。

## 变量

在 Asterisk PBX 中，变量可以是全局的、通道特定的以及环境特定的。你可以使用 NoOP() 应用程序在控制台中查看变量的内容。它可以将全局变量或通道特定变量用作应用程序参数。变量可以通过以下示例进行引用，其中 varname 是变量的名称。

```
${varname}
```

变量名称可以是字母数字字符串，且必须以字母开头。全局变量名称不区分大小写。然而，系统变量（Asterisk 定义的即通道定义的）是区分大小写的。因此，变量 ${EXTEN} 与 ${exten} 是不同的。

### 全局变量

全局变量可以在 extensions.conf 文件中的 [global] 部分进行配置，也可以使用以下应用程序进行配置：

```
set(Global(variable)=content)
```

### 通道特定变量

通道特定变量使用 set() 应用程序进行配置。每个通道都会接收其自己的变量空间。不同通道之间的变量不会发生冲突。通道特定变量会在通道挂断时销毁。一些最常用的变量包括：

- ${EXTEN} 已拨的 extension
- ${CONTEXT} 当前 context
- ${CALLERID(name)}
- ${CALLERID(num)}
- ${CALLERID(all)} 当前的 caller ID
- ${PRIORITY} 当前优先级

其他通道特定变量均为大写。你可以使用 dumpchan() 应用程序查看多个变量的内容。以下是 dump-channel 变量的一个简单摘录。

```
exten=9001,1,DumpChan()
exten=9001,n,Echo()
exten=9001,n,Hangup()
```

Dumpchan 输出：

```
Dumping Info For Channel: PJSIP/4400-00000001:
================================================================================
Info:
Name=               PJSIP/4400-00000001
Type=               PJSIP
UniqueID=           1161186526.1
LinkedID=           1161186526.0
CallerIDNum=        4400
CallerIDName=       laptop
ConnectedLineIDNum= (N/A)
ConnectedLineIDName=(N/A)
DNIDDigits=         9001
RDNIS=              (N/A)
Parkinglot=
Language=           en
State=              Ring (4)
Rings=              0
NativeFormat=       (ulaw)
WriteFormat=        ulaw
ReadFormat=         ulaw
RawWriteFormat=     ulaw
RawReadFormat=      ulaw
WriteTranscode=     No
ReadTranscode=      No
1stFileDescriptor=  16
Framesin=           0
Framesout=          0
TimetoHangup=       0
ElapsedTime=        0h0m0s
BridgeID=           (Not bridged)
Context=            default
Extension=          9001
Priority=           1
CallGroup=
PickupGroup=
Application=        DumpChan
Data=               (Empty)
Blocking_in=        (Not Blocking)
Variables:
```

上面的字段布局是 Asterisk 22 `DumpChan` 的输出（一个真实的 `PJSIP/...` 通道名称，`CallerIDNum`/`ConnectedLineID` 字段，以及 PJSIP 通道填充的 `Raw*`/`Transcode`/`BridgeID` 行）。与旧驱动程序不同，PJSIP 通道不会自动设置 `SIPCALLID`/`SIPUSERAGENT` 通道变量；等效的 SIP 详细信息是按需通过 `PJSIP_HEADER()` 和 `CHANNEL()` dialplan 函数读取的 —— 例如用于远程 RTP 地址的 `${CHANNEL(pjsip,call-id)}`、`${PJSIP_HEADER(read,User-Agent)}` 和 `${CHANNEL(rtp,dest)}`。

### 环境特定变量

环境特定变量可用于访问操作系统中定义的变量。你可以使用 ENV() 函数设置环境特定变量。例如：

```
${ENV(LANG)}
Set(ENV(LANG)=en_US)
```

### 应用程序特定变量

某些应用程序使用变量进行数据输入和输出。你可以在调用应用程序之前设置变量，或者在应用程序执行后检索变量。例如：Dial 应用程序会返回以下变量：

- ${DIALEDTIME} -> 这是从拨打通道到断开连接的时间。
- ${ANSWEREDTIME} -> 这是实际通话的时长。
- ${DIALSTATUS} 这是通话的状态：o CHANUNAVAIL o CONGESTION o NOANSWER o BUSY o ANSWER o CANCEL o DONTCALL o TORTURE
- ${CAUSECODE} -> 通话的错误代码。

## 表达式

表达式在 dialplan 中非常有用。它们用于操作字符串并执行数学和逻辑运算。

![Asterisk 表达式概览 — `$[expression1 operator expression2]` — 对 dialplan 中可用的数学、逻辑、比较、正则表达式和条件运算符进行分组。]((../images/04-first-pbx-fig08.png))

表达式语法定义如下：

```
$[expression1 operator expression2]
```

假设我们有一个名为 “I” 的变量，并且我们想给该变量加 100：

```
$[${I}+100]
```

当 Asterisk 在 dialplan 中发现一个表达式时，它会将整个表达式替换为计算结果。

### 运算符

以下运算符可用于构建表达式。注意运算符的优先级非常重要。

1. 圆括号 “()”
2. 一元运算符 “! -“
3. 正则表达式 “: =~
4. 乘法运算符 “* / %”
5. 加法运算符 “+ -“
6. 比较运算符
7. 逻辑运算符
8. 条件运算符

#### 数学运算符

- 加法 (+)
- 减法 (-)
- 乘法 (*)
- 除法 (/)
- 取模 (%)

#### 逻辑运算符

- 逻辑 “AND” (&)
- 逻辑 “OR” (|)
- 逻辑一元补码 (!)

#### 正则表达式运算符

- 正则表达式匹配 (:)
- 正则表达式精确匹配 (=~)

正则表达式是一种用于描述搜索模式的特殊文本字符串。你可以将正则表达式视为通配符。正则表达式用于将字符串与模式进行匹配以检查匹配情况。如果匹配成功且正则表达式包含至少一个匹配项，则返回第一个匹配项；否则，结果为匹配到的字符数。

#### 比较运算符

如果关系为真，则比较结果为 1，如果为假，则结果为 0。

- = 等于
- != 不等于
- < 小于
- > 大于
- <= 小于或等于
- >= 大于或等于

### 实验。评估以下表达式：

将这些表达式放入你的 dialplan 中，并使用 NoOP() 应用程序来评估这些表达式。拨打 9002 并在 Asterisk 控制台中检查结果。使用 verbose 15 来显示结果。

```
exten=9002,1,set(NAME="FLAVIO")                 ;Set NAME=FLAVIO
exten=9002,n,set(I=4)
exten=9002,n,set(URI="40001@voip.school")
exten=9002,n,NoOP(${NAME})
exten=9002,n,NoOP(${I})
exten=9002,n,NoOP($[${I}+${I}])
exten=9002,n,NoOP($[${I}=4])
exten=9002,n,NoOP($[${I}=4 & ${NAME}=FLAVIO])
exten=9002,n,NoOP($[${URI} =~ "4[0-9][0-9][0-9][0-9]@."])
exten=9002,n,NoOP($[${I}=4?"MATCH"::"DO NOT MATCH"])
exten=9002,n,hangup
```

## 函数

一些应用程序已经被函数所取代，这些函数允许以比单纯使用表达式更高级的方式处理变量。您可以通过执行以下控制台命令查看完整的函数列表：

```
*CLI> core show functions
```

字符串长度：${LEN(string)} 返回字符串的长度

```
Example:
exten=>100,1,Set(Fruit=pear)
exten=>100,2,NoOp(${LEN(Fruit)})
exten=>100,3,NoOp(${LEN(${Fruit})})
```

在第一个操作中，系统显示的结果为 5（单词“fruit”中的字母数量）。第二个操作返回数字 4（单词“pear”中的字母数量）。子字符串：返回从“offset”参数定义的位置开始，且长度由“length”参数定义的子字符串。如果 offset 为负数，则从右向左计数，从字符串末尾开始。如果省略 length 或其为负数，则获取从 offset 开始的整个字符串。

```
${string:offset:length }
```

示例 #1：多个子字符串

```
${123456789:1}-returns 23456789
${123456789:-4}-returns 6789
${123456789:0:3}-returns 123
${123456789:2:3}-returns 345
${123456789:-4:3}-returns 678
```

示例 #2：从前三位数字中提取区号。

```
exten=>_NXX.,1,Set(areacode=${EXTEN:0:3})
```

示例 #3：从变量 ${EXTEN} 中提取除区号外的所有数字。

```
exten=>_516XXXXXXX,1,Dial(${EXTEN:3})
```

### 字符串拼接

要拼接两个字符串，只需将它们写在一起即可。

```
${foo}${bar}
555${number}
${longdistanceprefix}555${number}
```

## Applications

要构建 dialplan，我们需要理解应用程序（applications）的概念。你将在 dialplan 中使用应用程序来处理通道。应用程序在多个模块中实现。可用的应用程序取决于所加载的模块。你可以使用以下控制台命令显示所有 Asterisk 应用程序：

```
*CLI> core show applications
```

或者，你可以使用以下示例显示特定应用程序的详细信息：

```
*CLI> core show application Dial
```

要构建一个简单的 dialplan，你需要了解几个应用程序。我们将在本书后面讨论更高级的示例。

![构建简单 dialplan 所需的几个应用程序：Answer（应答通道）、Dial（呼叫另一个通道）、Hangup（挂断通道）、Playback（播放音频文件）和 Goto（跳转到优先级、extension 或 context）。](../images/04-first-pbx-fig09.png)

我们将使用上述应用程序为两个基本 PBX 创建一个简单的 dialplan。

### Answer()

[概要] 应答正在振铃的通道 [描述] Answer([delay])：如果呼叫尚未应答，该应用程序将应答它。否则，它对呼叫没有影响。如果指定了 delay，Asterisk 将在应答呼叫前等待指定的毫秒数。

### Dial()

以下描述可以通过在 dialplan 中执行 show application dial 获取。为了方便搜索，在此处重现。Dial 应用程序的语法也显示如下：

```
;dial to a single channel
Dial(Technology/resource,timeout,options,URL)
;dialing to multiple channels
Dial(Technology/resource[&Tech2/resource2...],timeout,options,URL)
```

此应用程序将向一个或多个指定的通道发起呼叫。一旦请求的通道之一应答，发起呼叫的通道就会被应答（如果尚未应答的话）。这两个通道随后将在桥接呼叫中处于活动状态。所有其他被请求的通道随后将被挂断。除非指定了超时时间，否则 Dial 应用程序将无限期等待，直到其中一个被呼叫的通道应答、用户挂断，或者所有被呼叫的通道都忙或不可用。如果无法呼叫任何请求的通道或超时，dialplan 的执行将继续。此应用程序在完成时会设置以下通道变量：

- DIALEDTIME - 这是从拨打通道到断开连接的时间。
- ANSWEREDTIME - 这是实际通话的时长。
- DIALSTATUS - 这是呼叫的状态：o CHANUNAVAIL o CONGESTION o NOANSWER o BUSY o ANSWER o CANCEL o DONTCALL o TORTURE

对于隐私和筛选模式（Privacy and Screening Modes），如果被叫方选择将主叫方发送到 'Go Away' 脚本，DIALSTATUS 变量将被设置为 DONTCALL。如果被叫方希望将呼叫者发送到 'torture' 脚本，DIALSTATUS 变量将被设置为 TORTURE。如果发起呼叫的通道挂断，或者呼叫已桥接且桥接中的任何一方结束呼叫，此应用程序将报告正常终止。如果通道支持，可选的 URL 将发送给被叫方。如果设置了 OUTBOUND_GROUP 变量，此应用程序创建的所有对等通道都将包含在该组中（如

```
Set(GROUP()=...).
```

下表总结了 Dial 应用程序最常用的一些选项。有关完整列表，请使用控制台命令 `core show application Dial`。在 Asterisk 22 中，这些选项通过逗号与通道和超时时间分隔开——例如 `Dial(PJSIP/2000,20,tTm)`。

| 选项 | 描述 |
|--------|-------------|
| `A(x)` | 使用 `x` 作为文件向被叫方播放公告。 |
| `C` | 重置此呼叫的 CDR。 |
| `d` | 允许主叫用户在等待呼叫应答时拨打 1 位数的 extension。如果该 extension 在当前 context 中存在，则跳转到该 extension；如果存在，则跳转到 `EXITCONTEXT` 变量中定义的 context。 |
| `D([called][:calling])` | 在被叫方应答后、呼叫桥接前发送指定的 DTMF 字符串。向被叫方发送 `called` 字符串，向主叫方发送 `calling` 字符串。任一参数均可单独使用。 |
| `f` | 强制将主叫通道的 Caller ID 设置为通过 dialplan `hint` 与该通道关联的 extension。在 PSTN 不允许任意 Caller ID 的情况下非常有用。 |
| `g` | 如果目标通道挂断，则在当前 extension 继续执行 dialplan。 |
| `G(context^exten^pri)` | 如果呼叫被应答，将主叫方转移到指定的优先级，将被叫方转移到优先级+1。可以选择指定一个 extension（或 extension 和 context）；否则使用当前 extension。 |
| `h` | 允许被叫方通过发送 `*` DTMF 数字来挂断。 |
| `H` | 允许主叫方通过发送 `*` DTMF 数字来挂断。 |
| `L(x[:y][:z])` | 将呼叫限制为 `x` 毫秒，当剩余 `y` 毫秒时播放警告，并每隔 `z` 毫秒重复一次警告。请参阅下方的 `LIMIT_*` 变量。 |
| `m([class])` | 在请求的通道应答之前，为呼叫方提供保持音乐（Music on Hold）。可以指定特定的 MusicOnHold 类。 |
| `r` | 向主叫方指示振铃，并且在被叫通道应答之前不传递任何音频。 |
| `S(x)` | 在被叫方应答后 `x` 秒挂断呼叫。 |
| `t` | 允许被叫方通过发送 `features.conf` 中定义的 DTMF 序列来转移主叫方。 |
| `T` | 允许主叫方通过发送 `features.conf` 中定义的 DTMF 序列来转移被叫方。 |
| `w` | 允许被叫方通过发送 `features.conf` 中定义的 DTMF 序列来启用一键录音。 |
| `W` | 允许主叫方通过发送 `features.conf` 中定义的 DTMF 序列来启用一键录音。 |
| `k` | 允许被叫方通过发送 `features.conf` 中定义的呼叫驻留 DTMF 序列来驻留呼叫。 |
| `K` | 允许主叫方通过发送 `features.conf` 中定义的呼叫驻留 DTMF 序列来驻留呼叫。 |

`L(x[:y][:z])` 选项可以通过以下特殊变量进行调整：

- `LIMIT_PLAYAUDIO_CALLER` — `yes|no`（默认 `yes`）：为呼叫者播放声音。
- `LIMIT_PLAYAUDIO_CALLEE` — `yes|no`：为被叫方播放声音。
- `LIMIT_TIMEOUT_FILE` — 时间到时播放的文件。
- `LIMIT_CONNECT_FILE` — 呼叫开始时播放的文件。
- `LIMIT_WARNING_FILE` — 当定义了 `y` 时作为警告播放的文件。默认是播报剩余时间。

示例：

```
exten=_4XXX,1,Dial(PJSIP/${EXTEN},20,tTm)
```

在上面的示例中，该应用程序将拨打相应的 PJSIP 通道。主叫方和被叫方都可以转移呼叫（Tt）。将听到保持音乐而不是回铃音。如果 20 秒内无人应答，extension 将跳转到下一个优先级。

### Hangup()

挂断主叫通道 [描述] Hangup([causecode])：此应用程序将挂断主叫通道。如果给出了 cause code，通道的挂断原因将被设置为给定的值。

### Goto()

跳转到特定的优先级、extension 或 context [描述] Goto([[context|]extension|]priority)：此应用程序将导致主叫通道在指定的优先级继续执行 dialplan。如果没有指定特定的 extension（或 extension 和 context），此应用程序将跳转到当前 extension 的指定优先级。如果跳转到 dialplan 中其他位置的尝试不成功，通道将在当前 extension 的下一个优先级继续执行。

## 构建 dialplan

要构建一个简单的 dialplan，你需要通过创建 context 和 extension 来处理所有呼入和呼出的呼叫。在本节中，我们将向你展示如何构建最常见的 extension。

### 在 extension 之间拨号

为了实现 extension 之间的拨号，我们可以使用通道变量 ${EXTEN}，它指向被拨打的 extension。例如，如果 extension 范围在 4000 到 4999 之间，且所有 extension 都使用 SIP，我们可以采用以下命令：

```
[from-internal]
exten=_4XXX,1,Dial(PJSIP/${EXTEN})
```

### 拨打外部目的地

要拨打外部目的地，你可以在拨打的号码前加上路由。在北美，通常使用 9 后跟要拨打的外部号码。如果你使用的是连接到 PSTN 的模拟或数字通道，命令应如下所示：如果你想使用 SIP trunk 而不是 DAHDI，请使用 `PJSIP/...@siptrunk` 通道。

```
[from-internal]
exten=_9NXXXXXX,1,Dial(DAHDI/1/${EXTEN:1},20,tT)
or
exten=_9NXXXXXX,1,Dial(PJSIP/${EXTEN:1}@siptrunk,20,tT)
```

上述行将允许你拨打 9 和所需的号码。在给出的示例中，你将使用第一个 DAHDI 通道 (DAHDI/1)。如果你有多条线路且该线路正忙，呼叫将无法完成。但是，你可以使用以下行来自动选择第一个可用的 DAHDI 通道。或者，你可以使用 SIP trunk 代替 DAHDI。在 PJSIP 格式 `Dial(PJSIP/number@siptrunk,...)` 中，拨打的号码是用户部分，`siptrunk` 是上面配置的 endpoint。

```
[from-internal]
exten=_9NXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20,tT)
```

“g1” 参数将在组中搜索第一个可用的通道，从而允许使用所有通道。使用下面这一行，你可以拨打长途号码。

```
[from-internal]
exten=_91NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20,tT)
```

### 拨打 9 获取 PSTN 线路

如果你对外部拨号没有任何限制，你可以简化并使用以下内容：

```
[from-internal]
exten=9,1,Dial(DAHDI/g1,20,tT)
```

### 在操作员 extension 接收呼叫

在下面的示例中，操作员 extension 是 4000。PSTN 线路连接到 FXO 接口。在 chan_dahdi.conf 文件中，指定的 context 是 from-pstn。任何来自 PSTN 的呼叫都将被路由到 dialplan 中的 context from-pstn。此线路没有直接拨入 (DID) 功能；因此，我们将不得不通过 “s” extension 接收呼叫。如果从 SIP trunk 接收，请使用 context [from-sip]。

```
[globals]
OPERATOR=PJSIP/6000
[from-pstn]
exten = s,1,Dial(${OPERATOR},40,tT)
exten = s,n,Hangup()
[from-sip]
exten = s,1,Dial(${OPERATOR},40,tT)
exten = s,n,Hangup()
```

### 使用直接拨入 (DID) 接收呼叫

如果你有数字线路，你将收到拨打的 extension。在这种情况下，你不需要将呼叫转发给操作员；相反，你可以直接将呼叫转发到目的地。假设你的 DID 范围是从 3028550 到 3028599，并且最后四位数字在 DID 中传递。配置将如下例所示：

```
[from-pstn]
exten => _85[5-9]X,1,Answer()
exten => _85[5-9]X,n,Dial(PJSIP/${EXTEN},15,tT)
exten => _85[5-9]X,n,Hangup()
```

### 同时呼叫多个 extension

你可以设置 Asterisk 拨打一个 extension，如果无人接听，则同时拨打其他几个 extension，如下例所示：

```
exten => 0,1,Dial(DAHDI/1,15,tT)
exten => 0,n,Dial(DAHDI/1&DAHDI/2&DAHDI/3,15)
exten => 0,n,Hangup()
```

在此示例中，当有人拨打操作员时，首先尝试通道 DAHDI/1。如果 15 秒（超时）后无人接听，通道 DAHDI/1、DAHDI/2 和 DAHDI/3 将同时振铃另外 15 秒。

### 按 Caller ID 路由

在此示例中，你可以根据 Caller ID 进行不同的处理，这对于呼叫骚扰者可能很有用。例如：

```
exten => 8590/4832518888,1,Playback(I-have-moved-to-china)
exten => 8590,1,Dial(DAHDI/1,20)
```

在此示例中，我们添加了一条特殊规则：如果 Caller ID 是 4832518888，你将播放之前录制的文件 “I-have-moved-to-china”。其他呼叫则照常接受。

### 在 dialplan 中使用变量

Asterisk 可以在 dialplan 中使用全局变量和通道变量作为某些应用程序的参数。请看以下示例：

```
[globals]
Flavio => DAHDI/1
Daniel => DAHDI/2&PJSIP/pingtel
Anna => DAHDI/3
Christian => DAHDI/4
[mainmenu]
exten => 1,1,Dial(${Daniel}&${Flavio})
exten => 2,1,Dial(${Anna}&${Christian})
exten => 3,1,Dial(${Anna}&${Flavio})
```

使用变量使未来的更改更容易。如果你更改了变量，所有引用都会立即更改。

### 录制公告

在本节后面讨论的一些选项中，我们将使用录制的提示音。这里我们展示一种录制它们的简单方法。我们将使用应用程序 Record() 通过自己的电话保存公告。

```
[from-internal]
exten => _record.,1,Record(${EXTEN:6}:gsm)
exten => _record.,n,wait(1)
exten => _record.,n,Playback(${EXTEN:6})
exten => _record.,n,Hangup()
```

这些指令允许你从 softphone 录制任何消息。示例：从 softphone 拨打 recordmenu。这些指令将调用带有变量 ${EXTEN:6} 的录音，且不包含前六个字母。换句话说，该指令等同于 record(menu:gsm)。你所要做的就是拨打 record + 要录制的文件名，按 # 结束录音，然后等待听到录音。

### 在数字接待员中接收呼叫

现在我们有了一些简单的示例，让我们扩展一下关于应用程序 background() 和 goto() 的学习。Asterisk 中交互式系统的关键是应用程序 background()，它允许你执行一个音频文件，当呼叫者按下按键时，该文件会被中断，以便将呼叫发送到拨打的 extension。background() 应用程序的语法：

```
exten=>extension, priority, background(filename)
```

另一个非常有用的应用程序是 goto()。顾名思义，它跳转到指定的 context、extension 和 priority。应用程序 goto() 的语法：

```
exten=>extension, priority,goto(context, extension, priority)
```

goto() 命令的有效格式：

```
goto(context,extension,priority)
goto(extension,priority)
goto(priority)
```

在下面的示例中，我们将创建一个数字接待员。编辑 extensions.conf 文件并配置以下 extensions 非常简单：

```
[globals]
OPERATOR=PJSIP/6000
[from-pstn]
include=aapstn
[from-sip]
include=aasip
[aapstn]
exten=>s,1,answer()
exten=>s,n,set(TIMEOUT(response)=10)
exten=>s,n,background(menu1)
exten=>s,n,WaitExten(30)
exten=>s,n,Dial(${OPERATOR})
exten=>6000,1,Dial(PJSIP/6000)
exten=>6001,1,Dial(PJSIP/6001)
exten=>6003,1,Dial(IAX2/6003)
exten=>6004,1,Dial(IAX2/6004)
[aasip]
exten=>9999,1,answer()
exten=>9999,n,set(TIMEOUT(response)=10)
exten=>9999,n,background(menu1)
exten=>s,n,WaitExten(30)
exten=>9999,n,Dial(${OPERATOR})
exten=>6000,1,Dial(PJSIP/6000)
exten=>6001,1,Dial(PJSIP/6001)
exten=>6003,1,Dial(IAX2/6003)
exten=>6004,1,Dial(IAX2/6004)
```

SIP extensions 使用 `PJSIP/`，IAX extensions 使用 `IAX2/` —— 这两个驱动程序都随 Asterisk 22 一起提供，尽管 `chan_iax2` 现在被认为是旧版，且首选 SIP/PJSIP。

在文件 menu1.gsm 中，录制消息 “press the extension or wait for the operator”。当用户拨打号码 6000 时，他将被发送到 extension 6000。此时，你应该已经清楚地了解了多个应用程序的使用，包括 answer()、background()、goto()、hangup() 和 playback()。如果你还没有清楚地理解，请再次阅读本章，直到你对内容感到满意为止。你将非常频繁地使用 background 应用程序。一旦你理解了 extensions、priorities 和 applications 的基础知识，创建一个简单的 dialplan 就会变得很容易。这些概念将在本书后面进行更深入的探讨，你将看到 dialplan 会变得更加强大。

## 总结

在本章中，你已经了解到配置文件存储在 /etc/asterisk 目录中。要使用 Asterisk，首先必须配置通道（例如 pjsip、dahdi、iax）。配置文件存在三种不同的语法：简单组（simple group）、对象继承（object inheritance）和复杂实体（complex entity）。dialplan 是在 extensions.conf 文件中创建的，它是一组 context 和 extension。在 dialplan 中，每个 extension 都会触发一个应用程序。你已经学会了使用 playback、background、dial、goto、hangup 和 answer 应用程序。

## 测试题

1. 通道配置文件包括（选择所有适用项）：
   - A. `/etc/asterisk/chan_dahdi.conf`
   - B. `/etc/asterisk/pjsip.conf`
   - C. `/etc/asterisk/iax.conf`
   - D. `/etc/asterisk/extensions.conf`
2. 在 Asterisk 22 中，单个 `chan_sip` 对等体 `[6001]` (`type=friend`/`host=dynamic`) 在 `pjsip.conf` 中被哪一组相关对象所取代？
   - A. 一个 `type=peer` 和一个 `type=user`
   - B. 一个 `type=endpoint`、一个 `type=auth` 和一个 `type=aor`
   - C. 单个 `type=friend`
   - D. 一个 `type=transport` 和一个 `type=global`
3. 在通道配置文件中定义 context 很重要，因为它设置了来自该通道的呼入呼叫的 context —— 来自该通道的呼叫会在 `extensions.conf` 中匹配的 context 内进行处理。
   - A. 正确
   - B. 错误
4. `Playback()` 和 `Background()` 应用程序之间的主要区别是（选择两项）：
   - A. Playback 播放提示音但不等待按键。
   - B. Background 播放提示音但不等待按键。
   - C. Background 播放消息并等待按键。
   - D. Playback 播放消息并等待按键。
5. 当呼叫通过没有 DID 的电话接口卡 (FXO) 进入 Asterisk 时，它会在以下特殊 extension 中处理：
   - A. `0`
   - B. `9`
   - C. `s`
   - D. `i`
6. `Goto()` 应用程序的有效格式包括（选择三项）：
   - A. `Goto(context,extension,priority)`
   - B. `Goto(priority,context,extension)`
   - C. `Goto(extension,priority)`
   - D. `Goto(priority)`
7. 模式 `_7[1-5]XX` 匹配（选择所有适用项）：
   - A. 7100
   - B. 7600
   - C. 7630
   - D. 7230
8. 在 `Dial(PJSIP/${EXTEN},20,tTm)` 中，`m` 选项的作用是什么？
   - A. 将呼叫限制为最大时长。
   - B. 在通道应答前，向呼叫者提供保持音乐而不是回铃音。
   - C. 在被叫方应答后发送 DTMF 数字。
   - D. 使用 dialplan hint 强制设置主叫号码。
9. 在 `chan_dahdi.conf` 使用的选项继承语法中，你需要：
   - A. 在单行中定义对象。
   - B. 先定义选项，然后在定义的选项下方声明对象。
   - C. 为每个对象定义一个单独的 context。
10. extension 中的优先级必须按顺序编号 (1, 2, 3, …)，且不能使用 `n`。
    - A. 正确
    - B. 错误

**答案：** 1 — A, B, C · 2 — B · 3 — A · 4 — A, C · 5 — C · 6 — A, C, D · 7 — A, D · 8 — B · 9 — B · 10 — B
