# Asterisk 安全性

自诞生以来，Asterisk 的安全性问题就至关重要。根据 CERT.BR 的统计，SIP（会话发起协议）是互联网上遭受攻击最多的协议。任何运行蜜罐（honeypot）的人都可以证实这一点。互联网收入分成欺诈（Internet Revenue Share Fraud）问题非常严重，可能导致超过数十万美元的损失。在没有适当安全措施的情况下，切勿将 Asterisk 服务器连接到互联网。在本章中，您将学习如何识别可能遭受的主要攻击类型，以及如何通过实施适当的安全策略来预防这些攻击。最后但同样重要的是，您将学习如何实施建议的安全策略。

本章针对 **Asterisk 22 LTS**，其中 PJSIP（`res_pjsip` / `chan_pjsip`）是唯一的 SIP 通道。（旧的 `chan_sip` 驱动程序已在 Asterisk 21 中移除——如果您正在迁移旧系统，请参阅*遗留通道*章节。）一个与安全相关的后果是：身份验证失败现在通过 Asterisk **安全事件框架**和专用的 `security` 日志通道发出，这改变了 Fail2Ban 的配置方式（本章稍后将详细介绍）。

## 目标

读完本章后，您应该能够：

- 识别针对 Asterisk 服务器的常见主要攻击类型
- 定义有效的安全策略
- 实施安全策略
- 为 Asterisk 安装并配置 IPTABLES
- 为 Asterisk 安装并配置 Fail2Ban
- 安装并配置 TLS 和 SRTP 以实现加密

## IP 电话的主要攻击方式

IP 电话的主要攻击方式可分为 DOS/DDOS、服务盗用/话费欺诈以及窃听。其中一些名称可能会引起混淆，不同的来源有时会对同一种攻击使用不同的称呼。服务盗用、话费欺诈、互联网收入分成欺诈、电话欺诈，这些都是指黑客利用您的 PBX 向高费率号码拨打流量，并从服务提供商处获取回扣的不同名称。

### DDoS/DOS

拒绝服务攻击（Denial of Service）和分布式拒绝服务攻击（Distributed Denial of Service）是针对任何 IT 基础设施的常见攻击。SIP 和其他 Voice over IP 协议也不例外。分布式拒绝服务攻击通常由僵尸网络实施，而 DOS 仅由单台计算机实施。2011 年 2 月，Sality 僵尸网络对整个 IPv4 地址空间进行了隐蔽且协调的扫描，寻找易受攻击的 SIP 服务器——观察 UCSD 网络望远镜的研究人员将其归因于大约 300 万个不同的源 IP 地址探测 UDP 端口 5060，这极有可能是为了暴力破解 SIP 账户以进行话费欺诈。[^sality]

[^sality]: A. Dainotti 等人，“Analysis of a '/0' Stealth Scan from a Botnet,” *IEEE/ACM Transactions on Networking*, 2015 (DOI 10.1109/TNET.2013.2297678)。

![一个点对点僵尸网络向服务器发起数千次 SIP 注册尝试](../images/19-security-fig01.png)

DOS 通常通过模糊测试（fuzzing）和洪水攻击（flooding）等技术实现。洪水攻击可以使用 SIP、IAX、RTP 和其他协议。它们可以完全停止服务或降低语音质量。如果端口对互联网开放，这些攻击将非常难以缓解。以下是攻击者使用的一些工具：

**模糊测试：**

- **PROTOS Test Suite (c07-sip)** — 来自奥卢大学 OUSPG。发送数千个格式错误的数据包，以引发缓冲区溢出等导致软件停止运行的故障。
- **Voiper** — 生成超过 200,000 个测试用例，涵盖所有 SIP 属性，并验证您的服务器是否能有效处理这些消息。 <http://voiper.sourceforge.net/>

**洪水攻击：**

- **INVITE Flooder** — 用 SIP INVITE 请求淹没服务器。 <http://www.hackingvoip.com/tools/inviteflood.tar.gz>
- **IAX Flooder** — 用 IAX2 流量淹没服务器。 <http://www.hackingvoip.com/tools/iaxflood.tar.gz>
- **RTP Flooder** — 用 RTP 数据包淹没活动的媒体会话，以降低语音质量。 <http://www.hackingvoip.com/tools/rtpflood.tar.gz>

### DoS/DDoS 的缓解技术

我的建议是：

1. 不要将您的 Asterisk 服务器暴露在互联网上，除非有必要并采取了适当的保护措施（SBC）。
2. 在内部网络中使用虚拟局域网（VLAN）进行语音传输，特别是在用户数量较多的大学或学院环境中。
3. 使用 VPN 或 TLS 进行外部访问。

### 互联网收入分成欺诈

这种欺诈手段理解起来有点棘手。关键在于理解国际高费率号码（IPRN）的概念。

![互联网收入分成欺诈的三个步骤：购买高费率号码，寻找易受攻击的 VoIP 设备并拨打该号码，然后收取报酬](../images/19-security-fig02.png)

IPRN 是您可以在某些特定的互联网电话公司免费分配的号码。搜索“互联网高费率号码提供商”，您会找到很多此类公司。在这类运营商处，您可以分配一个例如卫星网络（如 Iridium）的号码，该目的地每分钟的通话成本高达数十美元。IPRN 提供商会为您收到的每一分钟通话返还一定比例的收入（收入的 10% 到 20%）。

![显示各国支付费率和测试号码的 IPRN 提供商价格表](../images/19-security-fig03.png)

在分配阶段之后，黑客会尝试寻找任何能够拨打已分配 IPRN 的开放 Asterisk 服务器。受害者被黑客控制的 PBX 将向 IPRN 号码拨打数百次电话，为黑客产生巨额回报，并为受害者带来巨额电话账单。很多时候，一个周末的账单就可能超过数十万美元。

黑客攻击 PBX 的主要工具：

1. **SIPVicious**: http://code.google.com/p/sipvicious/。Sipvicious 是一套易于使用的安全工具。其主要目标是识别易受攻击的 PBX，并使用暴力破解攻击来破解 SIP 密码。最常用的工具是 svcrack。该工具每秒能够测试数千个密码。
2. **电话漏洞**。黑客经常使用的另一个攻击向量是电话本身。许多安装 Asterisk 的人不会更改电话 Web 界面中的默认密码。一旦这些电话在互联网上开放，黑客就可以尝试使用默认的界面密码下载配置，通常可以在其中找到 SIP 密码。

#### TFTPTheft：

如果您正在使用 TFTP 进行电话自动配置，那么您很可能容易受到此类攻击。TFTP 是一种简单且不安全的文件传输协议。

![攻击者从 TFTP 服务器下载可猜测的 .cfg 文件，并从配置文件中获取明文凭据](../images/19-security-fig04.png)

配置文件名称很容易通过 MAC 地址后跟 .cfg 来猜测（例如 001A2B3C4D5E.cfg）。聪明的黑客可以轻松创建一个工具来按顺序尝试所有 MAC 地址，或者直接下载一个现成的工具来执行此操作。配置文件通常未加密，内部包含 SIP 密码。

#### 针对暴力破解和 TFTPTheft 的缓解措施

要缓解这些攻击，您可以应用以下解决方案。暴力破解：缓解暴力破解攻击的最佳方案是防止未经授权的连续尝试。几乎所有的 Asterisk 安装程序都会为此使用 fail2ban 工具。当 fail2ban 检测到多次错误的密码或用户名尝试时，它会封禁攻击者的 IP 一段时间。针对暴力破解的第二项措施是使用强密码，长度超过 12 个字符，且至少包含一个特殊字符。TFTPTheft：为防止 TFTPTheft，请配置配置服务使用 https 并设置用户名和密码。文件将以加密方式传输，且用户名和密码可防止攻击者尝试下载任何文件。

### 窃听

我们很少看到这类攻击，因为在大多数情况下，它们根本没有被检测到。在 IP 环境中，窃听非常难以察觉。诸如 UCsniff 之类的免费工具能够在大多数网络中窃听 VoIP 通话。其主要技术是使用 ARP 欺骗，强制流量通过运行 UCsniff 的计算机并记录通话。

#### 窃听的缓解措施

您可以通过加密 VoIP 流量来防止窃听。另一种方法是防止网络上的中间人（MITM）攻击。ARP 检测在第 2 层网络中防止 MITM 非常有效。请咨询您的网络技术支持以了解如何实施。在本书的后续章节中，我们将学习如何安装基于 TLS 和 SRTP 的加密。您还可以使用 ARPWatch 来发现是否有人正在滥用 ARP 协议来攻击您的网络。

## Asterisk 安全策略

实现安全性的最佳方式是制定一套安全策略。对于本培训，我将为大多数 Asterisk 安装建议一套安全策略。请将其作为基础起点，并根据您的需求进行调整。建议的安全策略如下：

1. 不开放不必要的 UDP/TCP 端口
2. 不在互联网上开放任何管理接口（SSH/HTTPS）的访问权限。
3. 若要访问 SSH 和/或 HTTP/HTTPS，应在 IPTABLES 防火墙中设置明确的例外规则
4. 使用 12 位字符且至少包含一个特殊字符的强密码
5. 使用 Fail2ban 禁止在身份验证中失败超过 10 次的 IP 地址
6. 国际长途电话需进行密码确认
7. 将 SIP 端口的访问权限限制在您已知的 IP 地址范围内

如果您需要对 PBX 进行外部访问，有两种可能性。使用 SBC (Session Border Controller) 来保护您的服务器免受 DOS/DDOS 攻击，或者在需要外部访问时使用 VPN。如果您在没有 SBC 或 VPN 的情况下将 5060 端口暴露在互联网上，您将面临 DOS/DDOS 攻击的风险。风险由您自行承担。

### PJSIP 时代的安全加固 (Asterisk 22)

除了防火墙和 Fail2Ban，Asterisk 22 的 PJSIP 栈还提供了几种配置级别的控制，这些应成为您安全策略的一部分。它们是对上述网络控制的补充（而非替代）：

- **每个 endpoint 的身份验证。** 每个 endpoint 都应引用一个专用的 `type=auth` 部分，并配有一个强且唯一的 `password` (`auth_type=digest`)。切勿在多个 endpoint 之间重复使用凭据。
- **内置匿名处理。** PJSIP 在身份验证失败时不会泄露用户名是否存在。若要接受匿名呼叫，您必须显式创建一个名为 `anonymous` 的 endpoint，并使用 `type=identify` 部分（基于源 IP 匹配）将已知的对端映射到 endpoint。如果您不需要匿名呼叫，只需不创建 `anonymous` endpoint，未匹配的请求将会被质询/拒绝。
- **ACL。** 使用 `/etc/asterisk/acl.conf` 命名 ACL 限制谁可以访问 endpoint，并通过 endpoint 中的 `acl=`（信令/源 ACL）和 `contact_acl=`（限制联系人/注册地址）进行引用。您也可以直接在 endpoint 上设置 permit/deny。
- **`qualify`。** 在 AOR 上设置 `qualify_frequency`（以及 `qualify_timeout`），以便 Asterisk 主动监控已注册联系人的可达性并剔除失效的联系人。
- **PJSIP 传输加固 / DoS 保护。** `type=transport` 不提供针对每个传输的客户端上限，因此连接洪泛保护来自防火墙（本章中的 iptables/Fail2Ban 规则），而不是 PJSIP 选项。传输层确实为您提供的是 TCP keep-alive 调整（`tcp_keepalive_enable`, `tcp_keepalive_idle_time`, `tcp_keepalive_interval_time`, `tcp_keepalive_probe_count`）以清除失效/半开连接，以及用于正确 NAT 处理的 `local_net`/`external_*` 设置。将这些与防火墙规则结合使用，以抵御连接洪泛攻击。
- **TLS + SRTP 用于媒体。** 在 endpoint 上使用 TLS 传输加密信令，并使用 `media_encryption=sdes`（或用于 WebRTC 的 `dtls`）加密媒体 — 本章稍后会介绍。
- **AMI/ARI 访问控制。** 将 Asterisk Manager Interface (`manager.conf`) 和 ARI (`ari.conf` / `http.conf`) 限制在 localhost 或受信任的管理网络，使用强且唯一的密钥，将 HTTP 服务器绑定到私有接口，且绝不要将其暴露在互联网上。

上述所有选项名称均已在 Asterisk 22.10 中确认：`type=transport` 部分公开了 `tcp_keepalive_enable`, `tcp_keepalive_idle_time`, `tcp_keepalive_interval_time`, `tcp_keepalive_probe_count`, `tos`, `cos`, `local_net` 和 `external_*` 系列，但它**没有** `max_clients` 选项 — 连接洪泛保护来自防火墙，而非传输层。endpoint 选项 `acl` 和 `contact_acl` 从 `acl.conf` 获取部分名称，而针对未经身份验证的对端的源 IP 匹配则通过 `type=identify` 部分（`match=`）完成。

### 移除不必要的端口

与其去发现与所有 Asterisk 协议相关的所有漏洞，不如通过移除不必要的端口来简化问题。要列出 Asterisk 服务器打开的所有端口，请使用：

```
netstat -pantu |grep asterisk
```

该命令的输出如下所示。

![netstat 输出显示了 Asterisk 绑定的许多端口，包括 4569 (IAX) 和 2727 (MGCP)](../images/19-security-fig05.png)

如果您查看输出，会发现许多端口处于打开状态。我们需要它们吗？不一定，2727 是 MGCP 协议 (chan_mgcp)，4569 是 IAX (chan_iax2)。如果您不使用这些协议，只需在配置文件 modules.conf 中移除相应的模块即可。

您可能会注意到 Asterisk 绑定了一个高位 UDP 端口。这来自于 `res_pjsip` 的解析器发出的出站 DNS 查询（源端口是临时的，就像任何客户端 DNS 查询一样），而不是来自入站监听器 — 您的防火墙只需要为它允许 **established/related** 的返回流量（下文显示的 iptables `conntrack ESTABLISHED,RELATED` 规则已经涵盖了这一点）。您**不需要**仅仅为了 PJSIP DNS 而打开大范围的入站高位 UDP 端口。

要移除不必要的端口，请禁用您不使用的模块。编辑 modules.conf 文件并为您不使用的通道和协议添加 `noload` 行。**不要** noload `res_pjsip`, `res_pjproject` 或 `chan_pjsip` — 这些是 Asterisk 22 中 SIP 所必需的：

```
; res_pjsip / res_pjproject / chan_pjsip are REQUIRED in Asterisk 22 - keep them loaded
noload => chan_iax2.so
noload => chan_unistim.so
```

（在 Asterisk 22 中，您不再需要 noload `chan_mgcp` 或 `chan_skinny` — 这些驱动程序已在 Asterisk 21 中*移除*，不属于标准 22 构建的一部分。）通过上述说明，我已经移除了所有不必要的通道，仅保留了 PJSIP。您可以选择任何您想要的协议模块，只需移除未使用的即可。结果如下面的截图所示 — 现在只有您的 PJSIP 传输绑定的 SIP 端口 (5060) 被暴露在入站方向。

![禁用未使用模块后的 netstat 输出：Asterisk 仅绑定了 UDP 端口 5060](../images/19-security-fig06.png)

### 使用 IPTABLES 实现安全策略

IPTABLES 或 netfilter 是大多数 Linux 发行版中标准的防火墙。在本实验中，我们将配置 iptables 和 fail2ban。目标是为 Asterisk 实现推荐的安全策略并阻止所有不必要的流量。请按照以下步骤操作：

1. 阻止所有外部流量
2. 允许来自内部网络或单个主机的 SSH 流量
3. 允许 UDP 和 TCP 端口 5060 的 SIP 流量
4. 允许 UDP 媒体端口范围内的 RTP 流量。没有单一的内置默认值 — 当未设置任何内容时，Asterisk 自身的 `rtp.conf` 会回退到 5000–31000 端口，但随附的 `rtp.conf.sample` 配置了 `rtpstart=10000` / `rtpend=20000`，因此我们在此使用该示例范围。请将您的防火墙规则与您在 `rtp.conf` 中实际设置的 `rtpstart`/`rtpend` 相匹配。

确保您拥有服务器的控制台访问权限，您肯定不想把自己锁在系统之外。请务必小心。

1. 安装 net-persistent 软件包。

   ```
   sudo apt-get install iptables-persistent
   ```

2. 允许来自回环接口的所有流量

   ```
   sudo iptables -I INPUT -i lo -j ACCEPT
   sudo iptables -I OUTPUT -o lo -j ACCEPT
   ```

3. 允许已建立的连接

   ```
   sudo iptables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
   ```

4. 允许来自 192.168.0.0 网络的 SSH/HTTPS 流量

   ```
   sudo iptables -I INPUT -p tcp -s 192.168.0.0/16 --dport 22 -m conntrack --ctstate
   NEW,ESTABLISHED -j ACCEPT
   sudo iptables -I INPUT -p tcp -s 192.168.0.0/16 --dport 443 -m conntrack --ctstate
   NEW,ESTABLISHED -j ACCEPT
   ```

5. 插入 Asterisk 规则

   ```
   sudo iptables -I INPUT -p udp -m udp --dport 5060 -j ACCEPT
   sudo iptables -I INPUT -p tcp -m tcp --dport 5060 -j ACCEPT
   sudo iptables -I INPUT -p tcp -m tcp --dport 5061 -j ACCEPT
   sudo iptables -I INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT
   ```

   请注意，端口 5061 (SIP over TLS) 是 **TCP**，而不是 UDP。上述规则同时在 UDP 和 TCP 上打开 5060，并在 TCP 上打开 5061。如果您只运行 TLS，则可以完全删除普通的 5060 规则。仅打开您的 PJSIP 传输实际绑定的端口。

   `-I` 表示 PREPEND（前置）

6. 最后一条规则必须是 drop（丢弃）

   ```
   sudo iptables -A INPUT -j DROP
   ```

   `-A` 表示 APPEND（追加）。注意：维护新规则时要小心，您必须在 DROP 之前添加规则。对新规则使用 PREPEND `-I`

7. 保存规则并重启 iptables

   ```
   sudo iptables-save >/etc/iptables/rules.v4
   sudo /etc/init.d/netfilter-persistent restart
   ```

### 使用 Fail2Ban 阻止多次身份验证失败尝试

Fail2Ban 几乎是 Asterisk 的标配。大多数用户通过它来增强安全性。该实用程序会扫描 Asterisk 日志以查找失败的尝试，并封禁攻击者的 IP 地址。下面我提供安装 Fail2Ban 的说明。

在 Asterisk 22 中，PJSIP 通过 Asterisk **安全事件框架**报告身份验证失败和其他安全事件，这些事件被写入专用的 **`security` 日志通道**。要使 Fail2Ban 工作，您必须：

1. 在 `/etc/asterisk/logger.conf` 中启用安全通道。语法是 `<filename> => <levels>`，因此要将安全级别发送到名为 `security` 的文件，请写入：

```
[logfiles]
security => security
```

然后在 CLI 中运行 `logger reload`。这将产生 `/var/log/asterisk/security`，每个安全事件一行，格式如下：

```
[2026-01-15 10:23:45] SECURITY[1234] res_security_log.c: SecurityEvent="InvalidPassword",...,RemoteAddress="IPV4/UDP/203.0.113.7/5060",...
```

Fail2Ban 关注的事件是 `InvalidPassword`, `ChallengeResponseFailed`, `InvalidAccountID` 和 `FailedACL`，每个事件都携带一个标识违规者的 `RemoteAddress="IPV4/UDP/<ip>/<port>"` 字段。（注意地址被包裹为 `IPV4/UDP/.../...`，而不是裸 IP — 您的过滤器必须从该字符串中提取主机。）

2. 将 `asterisk` 监狱指向该文件 (`logpath = /var/log/asterisk/security`) 并使用解析此安全事件格式的过滤器。

现代 Fail2Ban 附带一个 `asterisk` 过滤器，其 `failregex` 已经匹配了上述事件并从 `RemoteAddress` 字段中提取了 `<HOST>`，例如：

```
failregex = ^SecurityEvent="(?:FailedACL|InvalidAccountID|ChallengeResponseFailed|InvalidPassword)".*,RemoteAddress="IPV[46]/[^/"]+/<HOST>/\d+"
```

PBX 发行版（FreePBX/Sangoma）附带了等效的过滤器。优先使用打包好的过滤器，而不是手写一个，因为确切的事件字符串取决于版本。需要注意的一个警告：一个现已修补的公告 (GHSA-5743-x3p5-3rg7) 表明，精心构造的 PJSIP 流量可以注入虚假的日志行 — 请保持 Asterisk 和 Fail2Ban 过滤器均为最新。

下面我提供安装 Fail2Ban 的说明

1. 在 Linux 上安装 fail2ban

   ```
   sudo apt-get install fail2ban
   ```

2. 为 Asterisk 和 SSH 激活 fail2ban

   ```
   sudo vi /etc/fail2ban/jails.d/defaults-debian.conf
   ```

   添加以下行以激活 ssh 和 asterisk 的 fail2ban

   ```
   [sshd]
   enabled = true
   [asterisk]
   enabled=true
   ```

3. 重启 fail2ban

   ```
   /etc/init.d/fail2ban restart
   ```

4. 验证。更改 softphone 的密码并尝试重新注册 10 次。使用 `iptables -L`，检查 softphone 地址是否被包含为已封禁地址。
5. 从封禁列表中移除该地址（假设地址为 192.168.0.5）

   ```
   sudo fail2ban-client set asterisk unbanip 192.168.0.5
   ```

注意：在命令中将 192.168.0.5 替换为您手机的 IP 地址

### 实现 TLS 和 SRTP

我将本节分为两部分。第一部分我们将介绍用于加密信令的 TLS，第二部分介绍用于加密媒体的 SRTP。此处的目的是为这些资源配置 Asterisk。

#### TLS

TLS (Transport Layer Security) 是为保护 SIP 信令而定义的加密机制。下表总结了 TLS 可以防御的攻击类型：

| 攻击类型 | 是否受保护？ | 注释 |
|----------------|-----------|-------|
| 信令攻击 | 是 | TLS 确保消息的完整性 |
| 中间人攻击 | 是 | TLS 检查服务器证书 |
| 窃听 | 否 | TLS 加密信令，不加密媒体 |

对于媒体（语音/视频）加密，请使用 SRTP。

#### 自签名数字证书

您可以使用两种类型的证书：自签名证书和商业证书。自签名证书由您自己的服务器签名，而商业证书由外部机构签名。对于 VoIP，您可以成为自己的证书颁发机构。无需 GoDaddy 和 Verisign 等外部证书，这是不必要的开支。我们将使用 ast_tls_cert 生成我们自己的证书。

#### 配置带有自签名证书的 TLS

以下是实现 TLS 的分步指南。我们首先生成证书，然后配置 PJSIP TLS 传输（参见“配置 TLS 与 chan_pjsip”），最后将 softphone 指向它。我们将使用原生支持 TLS 和 SRTP 的 SipPulse Softphone。（任何支持 TLS/SRTP 的 SIP softphone 工作方式相同。）

**第 1 步。** 为我们的证书颁发机构创建一个使用 3DES 加密、长度为 4096 位的私有 RSA 密钥。/usr/src/asterisk-22.x.y/contrib/scripts 中提供的以下命令将创建证书颁发机构和 Asterisk 证书。像往常一样，如果需要请调整说明，版本会变，目录也会变。请注意您正在执行的操作。在 –C 选项中使用您的域名或 IP 地址。命令 ast_tls_cert 有三个选项。

- -C 主机或 IP 地址（我使用了 192.168.0.74，即我的虚拟机 IP 地址）
- -O 组织名称
- -d 存储密钥的目录

```
mkdir /etc/asterisk/keys
cd /usr/src/asterisk-22.0.0/contrib/scripts
root@asterisk:/usr/src/asterisk-22.0.0/contrib/scripts# ./ast_tls_cert -C 192.168.0.74 -O "AsteriskGuide" -d /etc/asterisk/keys
No config file specified, creating '/etc/asterisk/keys/tmp.cfg'
You can use this config file to create additional certs without
re-entering the information for the fields in the certificate
Creating CA key /etc/asterisk/keys/ca.key
Generating RSA private key, 4096 bit long modulus
........................................................++
........................................................++
e is 65537 (0x010001)
Enter pass phrase for /etc/asterisk/keys/ca.key:
Verifying - Enter pass phrase for /etc/asterisk/keys/ca.key:
Creating CA certificate /etc/asterisk/keys/ca.crt
Enter pass phrase for /etc/asterisk/keys/ca.key:
Creating certificate /etc/asterisk/keys/asterisk.key
Generating RSA private key, 2048 bit long modulus
........................++++++
......................++++++
e is 65537 (0x010001)
Creating signing request /etc/asterisk/keys/asterisk.csr
Creating certificate /etc/asterisk/keys/asterisk.crt
Signature ok
subject=CN = 192.168.0.74, O = AsteriskGuide
Getting CA Private Key
Enter pass phrase for /etc/asterisk/keys/ca.key:
Combining key and crt into /etc/asterisk/keys/asterisk.pem
root@asterisk:/usr/src/asterisk-22.0.0/contrib/scripts#
```

我不会生成客户端证书，因为我们不会使用证书来验证客户端。客户端不需要出示其自己的证书。

**第 2 步。** 配置 Asterisk 以支持我们的 TLS 客户端。这是在 `pjsip.conf` 中完成的（一个 TLS 传输加上 endpoint 设置）— 完整配置将在下一节“配置 TLS 与 chan_pjsip”中显示。我们不使用证书进行身份验证，只是加密流量。

**第 3 步。** 安装支持 TLS 的 SIP softphone（作者使用的是 SipPulse Softphone）。

**第 4 步。** 将证书颁发机构复制到运行 softphone 的计算机上。安装后，如果您使用的是自签名证书，请将文件 `/etc/asterisk/keys/ca.crt` 复制到运行 softphone 的计算机上（使用 scp，或 Windows 上的 WinSCP）。

**第 5 步。** 在 softphone 中创建账户。在账户屏幕中，像添加任何其他 sip 账户一样正常添加账户。使用正确的密码，身份验证仍然基于密码。

**第 6 步。** 在账户设置中将 TLS 设置为传输方式。在 SipPulse Softphone 账户屏幕（下方）中，选择 **TLS** 作为传输方式并使用端口 5061。调整您的防火墙以打开 TCP 端口 5061。

![SipPulse Softphone 账户屏幕 — 输入服务器（您的 Asterisk IP 或域名）、用户名、密码和显示名称，然后选择传输方式（UDP、TCP 或 TLS）。](../images/softphone/sipphone-account.png){width=35%}

**第 7 步。** 信任证书颁发机构。如果您的 Asterisk TLS 证书由公共 CA 签名（例如 Let's Encrypt — 参见*部署*章节），现代 softphone（如 SipPulse Softphone）会通过系统证书存储自动信任它，无需手动导入。如果您使用自签名证书，请将其 CA (`/etc/asterisk/keys/ca.crt`) 导入到客户端或操作系统的信任存储中，或者在提示时接受它。

**第 8 步。** 您**不需要**客户端证书。一个常见的误解是每部手机都需要自己的证书来进行身份验证 — 其实不需要。此时 Asterisk 仅*加密*会话；身份验证仍然是用户名和密码。Asterisk 默认不验证客户端证书，因此无需分发每个客户端的证书。

**第 9 步。** 更改证书或传输方式后，请完全重启 softphone（退出并重新启动，而不仅仅是关闭窗口），以便它通过新的传输方式重新连接。

### 配置 TLS 与 chan_pjsip

现在让我们学习如何为 TLS 配置 PJSIP。PJSIP 是 Asterisk 22 中唯一的 SIP 通道，所以无需切换 — 只需确保加载了 `res_pjsip`, `res_pjproject` 和 `chan_pjsip`。第 1 步：确认 PJSIP 在 /etc/asterisk/modules.conf 中已启用。

```
; res_pjsip / res_pjproject / chan_pjsip must be loaded (do NOT noload them)
noload => chan_iax2.so
noload => chan_unistim.so
```

第 2 步：配置 PJSIP 以支持 TLS。在 /etc/asterisk/pjsip.conf 文件中为 TLS 传输添加一个部分

```
[transport-tls]
type=transport
protocol=tls
bind=0.0.0.0:5061
cert_file=/etc/asterisk/keys/asterisk.crt
priv_key_file=/etc/asterisk/keys/asterisk.key
method=tlsv1_2
```

使用 `method=tlsv1_2`（如果您的 OpenSSL/PJSIP 构建支持，则使用 `tlsv1_3`）— TLS 1.0/1.1 已过时且不安全，不应使用。

第 3 步：为 blink 配置 endpoint。编辑 `pjsip.conf` 并编辑 blink 的部分。让 PJSIP 自动选择传输方式。

```
[blink]
type=endpoint
aors=blink
auth=blink
context=from-internal
disallow=all
allow=ulaw
dtmf_mode=rfc4733
media_encryption=sdes
[blink]
type=aor
max_contacts=2
remove_existing=yes
[blink]
type=auth
auth_type=digest
username=blink
password=supersecret
```

第 4 步：验证。要验证注册是否通过 TLS 进行，请在 Asterisk 控制台中使用以下命令。

```text
asterisk*CLI> pjsip show aor blink

      Aor:  <Aor.............................................>  <MaxContact>
    Contact:  <Aor/ContactUri........................> <Hash....> <Status> <RTT(ms)..>
==========================================================================================

      Aor:  blink                                                2
    Contact:  blink/sip:03694827@192.168.0.67:56295;transp 620d91556d NonQual    nan
 ParameterName        : ParameterValue
 ====================================================================
 authenticate_qualify : false
 contact              : sip:03694827@192.168.0.67:56295;transport=tls
 default_expiration   : 3600
 max_contacts         : 2
 maximum_expiration   : 7200
 minimum_expiration   : 60
 qualify_frequency    : 0
 qualify_timeout      : 3.000000
 remove_existing      : true
 support_path         : false
```

### 使用 SRTP 进行安全通话

负责媒体加密的协议是 RFC3711 中定义的 Secure Real Time Protocol (SRTP)。该协议的缺点之一是缺乏标准化的密钥交换方式。Asterisk 使用 SDES 在由 TLS 提供的信令加密保护的 SDP 协议上交换密钥。还有其他方法，例如 MIKEY 和 ZRTP。由 Philipp Zimmermann 开发的 ZRTP 是密钥交换和媒体加密中最复杂的方法之一。一些 softphone 和硬电话允许使用 ZRTP。然而，标准方式仍然是 SDES，您会在市场上几乎任何可用的电话中找到这种方法。下面是一个在 SDP 中定义了加密密钥的请求示例，位于 a=crypto:1 和 a=crypto:2 行中。

```
INVITE sip:8000@192.168.1.237 SIP/2.0
Via:
SIP/2.0/tls
192.168.1.192:65525;rport;branch=z9hG4bKPj9fa224a14b17488ea15625ead833ea3a
Max-Forwards: 70
From:
"Flavio"
<sip:flavio@192.168.1.237>;tag=35afe6cc11274934867b24e43c805638
To: <sip:8000@192.168.1.237>
Contact: <sip:pyhkxnjz@192.168.1.192:65524;transport=tls>
Call-ID: 530a339c72af47f0a76e7ecb2a58ac43
CSeq: 5669 INVITE
Allow: SUBSCRIBE, NOTIFY, PRACK, INVITE, ACK, BYE, CANCEL, UPDATE, MESSAGE
Supported: 100rel
User-Agent: Blink 0.2.5 (Windows)
Authorization: Digest username="flavio", realm="asterisk", nonce="72ff51ad",
uri="sip:8000@192.168.1.237",
response="ba8c10672751baa7007d82eb34e2340e",
algorithm=MD5
Content-Type: application/sdp
Content-Length: 544
v=0
o=- 3509174186 3509174186 IN IP4 192.168.1.192
s=Blink 0.2.5 (Windows)
c=IN IP4 192.168.1.192
t=0 0
m=audio 50004 RTP/SAVP 9 104 103 102 0 8 101
a=rtcp:50005
a=rtpmap:9 G722/8000
a=rtpmap:104 speex/32000
a=rtpmap:103 speex/16000
a=rtpmap:102 speex/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-15
a=crypto:1
AES_CM_128_HMAC_SHA1_80
inline:WrtZH82ztz93albRNT8o+oMcK9GvlAHRoaR1STvJ
a=crypto:2
AES_CM_128_HMAC_SHA1_32
inline:4Ma9jJOCEEGMPzzkmgyf6ttp1qhN16yumdXB7eRv
a=sendrecv
```

#### 在 Asterisk 上配置 SRTP

在 Asterisk 上配置 SRTP 非常简单。在 endpoint 上设置 `media_encryption=sdes`；您还可以使用 `media_encryption_optimistic=no` 要求它，以便拒绝未加密的媒体，而不是静默允许。请注意，SDES 要求信令通过 TLS 运行，因此密钥不会以明文形式发送。

**第 1 步。** Asterisk 配置

在 `pjsip.conf` 的 `type=endpoint` 部分设置以下内容：

```
[blink]
type=endpoint
aors=blink
auth=blink
context=from-internal
disallow=all
allow=ulaw
transport=transport-tls
media_encryption=sdes
media_encryption_optimistic=no
```

**第 2 步。** Softphone 配置

在 softphone 中，为账户媒体启用 SRTP（将 **SRTP (Media Encryption)** 选项设置为 *Mandatory*），以便语音被加密。

![SipPulse Softphone 账户设置（下部）— 将 **Transport** 设置为 TLS，并将 **SRTP (Media Encryption)** 设置为 *Mandatory*，以便信令和媒体都被加密。](../images/softphone/sipphone-config.png){width=35%}

## 启用国际长途的双向认证

有时最好的方法是根本不设置国际路由。然而，如果您确实需要拨打国际长途，请使用额外的密码。我们将使用 Asterisk 的应用程序 vmauthenticate，在拨打国际长途之前要求输入 voicemail 密码。这需要在 dialplan 的 extensions.conf 中进行配置。请参阅下方的示例。这样，即使黑客发现了 peer 密码或入侵了电话，仍然需要 voicemail 密码才能拨打此目的地。

```
exten=_9011.,1,Playback(pleasedialyourvmpassword)
exten=_9011.,2,VMAuthenticate(${CALLERID(num)}@default,s)
exten=_9011.,3,Dial(PJSIP/${EXTEN:1}@my_trunk,20,tT)
exten=_9011.,4,Hangup()
```

`VMAuthenticate` 在 Asterisk 22 中仍然是一个标准应用程序。上述 `Dial()` 通过 SIP/PJSIP trunk (`PJSIP/<number>@<trunk>`) 路由呼叫，这是大多数现代安装连接到 PSTN 的方式 —— 请根据您自己的 trunk 名称调整 `my_trunk`，并且仅在您确实拥有 DAHDI span 时才使用 `DAHDI/g1/...`。在 dialplan 中进行防范通话欺诈 —— 像这样的双重验证，结合限制哪些 context 可以访问您的出站和国际路由 —— 仍然是您可以部署的最重要的保护措施之一。

## 总结

在本章中，您已经了解了将 IP PBX 连接到互联网所带来的风险。随后，我们学习了如何通过实施安全策略来保护我们的 PBX。在该安全策略中，我们部署了 iptables、fail2ban、TLS、SRTP 以及针对国际长途呼叫的双向认证。希望您喜欢本章内容。

## 测试题

1. 针对互联网收入分成欺诈（Internet Revenue Share Fraud）最重要的防御措施是什么？
   - A. 实施 SRTP
   - B. 保持 Asterisk 更新
   - C. 实施 TLS
   - D. 使用强密码
2. SIP 模糊测试（fuzzing）的定义是：
   - A. 使用畸形请求和回复进行的 DoS 攻击
   - B. 通过暴力破解密码进行的盗用服务
   - C. 窃听当前通话
   - D. 通过大量 SIP 请求发起的 DDoS 攻击
3. TFTP 盗窃发生在服务器通过 TFTP 提供配置文件时。你可以通过以下方式避免它：
   - A. FTP
   - B. HTTP
   - C. 带用户名和密码的 HTTPS
   - D. SCP
4. 中间人攻击（Man-in-the-middle attacks）使用了一种称为以下的技术：
   - A. TFTP 盗窃
   - B. ARP 欺骗（ARP spoofing）
   - C. MAC 泛洪（MAC poisoning）
   - D. dsniff
5. 对于 SRTP，Asterisk 使用以下系统来交换密钥：
   - A. MIKEY
   - B. SDES
   - C. ZRTP
   - D. Pluto
6. 用于生成证书颁发机构和证书的实用程序，位于 `/usr/src/asterisk-22.x.y/contrib/scripts`，是：
   - A. ast_tls_cert
   - B. gen_tls
   - C. gen_ast_tls
   - D. tls_generator
7. 防止窃听的有效策略（勾选所有适用项）：
   - A. 实施模拟窃听检测器
   - B. 使用 ARPwatch 实用程序检测 ARP 欺骗
   - C. 在交换机中启用 ARP 欺骗检测
   - D. 使用 SRTP
8. Asterisk 通过验证客户端证书来支持强身份验证。（PJSIP TLS 传输可以要求并验证客户端的证书。）
   - A. 正确
   - B. 错误
9. 在 Asterisk 22 上，哪项 PJSIP endpoint 设置开启了使用 in-SDP (SDES) 密钥的 SRTP 媒体加密？
   - A. `encryption=yes`
   - B. `media_encryption=sdes`
   - C. `srtp=mandatory`
   - D. `transport=tls`
10. 在 Asterisk 22 中，Fail2Ban 必须从专用的 ________ 日志记录通道（在 `logger.conf` 中启用）读取 PJSIP 身份验证失败事件。
    - A. `console`
    - B. `messages`
    - C. `security`
    - D. `verbose`

**答案：** 1 — D · 2 — A · 3 — C · 4 — B · 5 — B · 6 — A · 7 — B, C, D · 8 — A · 9 — B · 10 — C
