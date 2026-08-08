# 从 chan_sip 迁移到 PJSIP：实战指南

如果您正在阅读本章，且您的 Asterisk 13、16 或 18 系统仍在生产环境中使用，那么您已经面临最后期限了。`chan_sip`——通过 `sip.conf` 配置的原始 SIP 通道驱动程序——已在 **Asterisk 17 中被弃用，在 Asterisk 19 的默认构建中被移除，并在 Asterisk 21 中被彻底删除**。它在 Asterisk 22 LTS 中已不存在。没有任何标志可以将其重新开启，没有 `noload` 可以规避，也没有软件包可以安装。Asterisk 22 中唯一的 SIP 通道驱动程序是 **PJSIP**（`res_pjsip` 加上 `chan_pjsip`），通过 `pjsip.conf` 进行配置。

因此，对于大多数站点而言，升级到 Asterisk 22 不仅仅是版本提升，更是一个 *SIP 迁移项目*。好消息是，线路上的协议并没有改变——昨天能够注册并通话的电话，明天依然可以注册并通话——而且 Asterisk 提供了一个转换工具，可以为您完成 80% 的初步转换工作。本章是一本实用的操作指南：涵盖了概念映射、转换脚本、针对您实际情况的 `sip.conf` → `pjsip.conf` 并行翻译、迁移后随之而来的 dialplan 和 CLI 变更、realtime（数据库）迁移，以及一份检查清单和容易踩坑的陷阱。

此处的所有内容均已在本书的 Asterisk 22.10.0 实验环境中进行了验证。关于 `chan_sip` 本身的深度遗留资料，以及一个多设备 `sip.conf` 的端到端转换实例，请参阅 *Legacy channels* 一章；本章是该章节的重点式、食谱风格的配套指南。

## 目标

在本章结束时，你应该能够：

- 解释为什么 `chan_sip` 在 Asterisk 22 中被移除以及它的替代方案是什么
- 将 `sip.conf` 的 peer/user/friend 模型映射到 PJSIP 对象模型（endpoint + aor + auth + identify + transport + registration）
- 运行 `sip_to_pjsip.py` 转换脚本并批判性地审查其输出
- 手动将常见的设备类型（注册电话、入站 trunk、出站注册）从 `sip.conf` 转换为 `pjsip.conf`
- 逐个选项地迁移 NAT、媒体、DTMF、codec 和身份验证设置
- 更新 dialplan（`SIP/` → `PJSIP/`）和 CLI（`sip show` → `pjsip show`）
- 将 realtime/ARA 部署从 `sippeers`/`sipregs` 迁移到 Sorcery `ps_*` 表
- 完成迁移检查清单并避免常见的陷阱

## 为什么要进行迁移

`chan_sip` 为 Asterisk 服务了近二十年，但它背负着架构债务：一个单体模块、每个设备仅限一个配置块、对多传输协议的支持较弱，以及一个已经落后于 RFC 标准的 SIP 栈。**PJSIP** —— 基于 Teluu 成熟的 pjproject 栈构建，并于 Asterisk 12 中引入 —— 是从底层进行的彻底替换。到 Asterisk 21 版本，Asterisk 项目完成了这项工作，并从代码树中移除了 `chan_sip`。

你可以在任何 Asterisk 22 系统上确认这一情况：

```
*CLI> module show like chan_sip
Module                         Description              Use Count  Status      Support Level
0 modules loaded

*CLI> module show like chan_pjsip
Module                         Description              Use Count  Status      Support Level
chan_pjsip.so                  PJSIP Channel Driver     0          Running     core
1 modules loaded
```

`chan_sip` 返回 *0 modules loaded* —— 它确实已经不存在了。除了 PJSIP 之外，没有其他可迁移的目标，因此唯一真正的问题是 *如何* 迁移，而不是 *是否* 迁移。

## 概念映射：不存在单一的“peer”

对于从 `sip.conf` 转过来的用户来说，最容易让人困惑的思维转变是：**PJSIP 没有 `[peer]`。** 在 `sip.conf` 中，一个方括号括起来的块 —— 无论是 `peer`、`user` 还是 `friend` —— 描述了关于设备的*所有*信息：其凭据、如何联系它、其 codec、其 NAT 行为以及其 dialplan context。PJSIP 有意将那个单一的块拆分为几个更小的、单一用途的对象，每个对象都用一个 `type=` 标记，并*通过名称相互引用*：

| PJSIP 对象 (`type=`) | 职责 |
| --- | --- |
| `endpoint` | 设备的呼叫处理标识：codec、context、DTMF、媒体、NAT，以及对其 `auth`/`aors`/`transport` 的引用 |
| `aor` (Address of Record) | *在哪里*联系该设备 —— 已注册或静态的联系人、`max_contacts`、qualify |
| `auth` | 用于入站和/或出站认证的凭据（用户名/密码） |
| `identify` | 通过 **源 IP** 而不是通过 `From` 用户将入站请求匹配到 endpoint |
| `transport` | 监听 socket：协议、绑定地址/端口、NAT/外部地址 |
| `registration` | 从 Asterisk 到服务提供商的 **出站** REGISTER |

`friend`/`peer`/`user` 的区别完全消失了 —— 在 PJSIP 中，一切都是 `endpoint`。因此，一个单一的 `sip.conf` friend 通常会变成三个对象（`endpoint` + `auth` + `aor`），它们共享一个名称并相互指向：

```
                sip.conf                              pjsip.conf
            ┌──────────────┐              ┌──────────┐   ┌──────┐   ┌─────┐
            │   [2000]     │   becomes    │ endpoint │──▶│ auth │   │ aor │
            │ type=friend  │  ─────────▶  │  [2000]  │   │[2000]│   │[2000]│
            │ host=dynamic │              │  auth=───┼──▶└──────┘   └──────┘
            │ secret=...   │              │  aors=───┼───────────────▶ ▲
            └──────────────┘              └────┬─────┘
                                               │ transport=
                                               ▼
                                          ┌───────────┐
                                          │ transport │  (shared by all endpoints)
                                          └───────────┘
```

endpoint 是粘合剂。它命名了一个 `transport`（或继承默认值）、一个 `auth` 对象以及一个或多个 `aors`。对象模型在 *SIP & PJSIP in depth* 中有深入介绍；在这里，我们只需要将其作为每次转换的目标即可。

## `sip_to_pjsip.py` 转换工具

Asterisk 提供了一个 Python 脚本，用于读取现有的 `sip.conf` 并写入 `pjsip.conf`。它不是作为 CLI 命令运行的——它位于 **Asterisk 源代码树**中，而不是已安装的二进制文件中：

```
${ASTERISK_SRC}/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py
```

在实验环境的 Asterisk 22.10.0 中，其完整路径例如为 `/usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py`。同一目录下还包含 `sip_to_pjsql.py`（稍后介绍的 realtime/SQL 变体）以及辅助模块 `astconfigparser.py`、`astdicts.py` 和 `sqlconfigparser.py`。

### 运行该工具

该脚本接受可选的位置参数 —— `[input-file [output-file]]` —— 默认为当前目录下的 `sip.conf` 和 `pjsip.conf`：

```
cd /etc/asterisk
python /usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py \
       sip.conf pjsip_generated.conf
```

它仅有的实际选项如下：

```
-h, --help              show usage
-p, --prefix PREFIX     output prefix for include files (default: pjsip_)
-q, --quiet             don't print messages to stdout
```

它读取输入文件，打印 `Converting to PJSIP...`，并写入输出文件。在内部，它会遍历每一个 `sip.conf` 部分，并针对每个设备生成匹配的 `endpoint`、`auth`、`aor`、`registration` 以及（在可以推断出的情况下）`transport` 对象，并自动应用下一节中的选项映射。

### 功能及其局限性

请将输出结果视为**初稿，而非最终文件。** 该脚本对其自身的不足之处非常坦诚：任何无法清晰映射的内容都会被写入输出文件顶部的一个清晰的封闭块中：

```
;--
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[general]
bindport = 5060
[softphone]
qualify = yes
...
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
--;
```

请注意，在那个真实的片段中，来自 `sip.conf` 对端的 `qualify = yes` 进入了*未映射*块 —— 因为 PJSIP 是通过 `qualify_frequency`（秒）在 **aor** 上进行限定的，而不是在设备上使用布尔值，所以脚本将其留给您自行设置。需要规划的实际局限性包括：

- **传输方式是猜测的，而非设计的。** 脚本会从 `bindport`/`bindaddr` 生成一个基本的 `transport-udp`，但它无法获知您的 TLS 证书、TCP 需求或多绑定布局。请检查并重写传输配置。
- **NAT 和外部地址需要人工干预。** `externaddr`/`localnet` 可能无法完整保留；请手动确认传输配置上的 `external_media_address`、`external_signaling_address` 和 `local_net`。
- **`qualify`、自定义计时器以及少数选项会进入“未映射”块。** 请从头到尾阅读该块并逐一决定。
- **Codec 列表、context 和安全性需要审查。** 请验证 `disallow`/`allow`、dialplan `context`，并确保没有设备被无意中保持开放状态。

因此，工作流程为：将脚本运行到*草稿*文件中，进行 diff 和审查，将好的部分合并到您真实的 `pjsip.conf` 中，然后在投入生产前进行详尽的测试。

## 并行翻译

这些是配置方案。左侧是 `sip.conf`，右侧是经过验证的 `pjsip.conf` 等效配置（此处为适应页面宽度而垂直排列）。右侧的每个选项名称和值都已通过 Asterisk 22 实验室环境使用 `config show help res_pjsip ...` 进行了核对。

### 注册型话机（`host=dynamic`）

最常见的设备：通过密码登录并注册自身位置的桌面话机或 softphone。

**传统 `sip.conf`：**

```
[2000]
type=friend
host=dynamic
context=from-internal
disallow=all
allow=ulaw
allow=alaw
dtmfmode=rfc2833
secret=Sup3rSecret
qualify=yes
```

**Asterisk 22 `pjsip.conf`：**

```
[2000]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
auth=2000
aors=2000

[2000]
type=auth
auth_type=digest
username=2000
password=Sup3rSecret

[2000]
type=aor
max_contacts=1
qualify_frequency=60
```

关键变动：`host=dynamic` 变成了带有 `max_contacts` 的 `aor`（设备通过 REGISTER 填入其联系地址）；`secret=` 变成了 `type=auth` 内部的 `password=`；`qualify=yes` 变成了 **aor** 上的 `qualify_frequency=60`（以秒为单位），而不是 endpoint 上的。仅当您确实希望同一账户同时在多个设备上使用时，才将 `max_contacts` 设置为大于 1 的值。

### 入站 trunk（`host=<ip>` / `type=peer`）

从已知 IP 地址向您发送呼叫的运营商。此处无需注册——您使用 `identify` 通过 *源 IP 验证运营商的流量*。

**传统 `sip.conf`：**

```
[itsp-in]
type=peer
host=203.0.113.10
context=from-pstn
disallow=all
allow=ulaw
insecure=invite
```

**Asterisk 22 `pjsip.conf`：**

```
[itsp-in]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw

[itsp-in]
type=aor
contact=sip:203.0.113.10:5060

[itsp-in]
type=identify
endpoint=itsp-in
match=203.0.113.10
```

至关重要的转换是 **`insecure=invite` → `identify`**。在 `chan_sip` 中，`insecure=invite` 告诉 Asterisk “不要对来自该 peer 的入站 INVITE 进行身份验证质询”。PJSIP 通过使用 `type=identify`/`match=` 将 *源 IP 与 endpoint 匹配* 来实现相同的效果，这既更明确也更安全。静态的 `host=` 变成了 `aor` 上的永久 `contact=`，因此您也可以向该运营商拨出呼叫。`match=` 接受 IP 地址、CIDR 范围或主机名（在配置加载时解析——如果运营商的 IP 发生变化，请重新加载）。

### 出站注册（`register =>`）

当运营商要求 *您* 登录到 *他们* 时，`chan_sip` 在 `[general]` 中使用单行 `register =>`。PJSIP 将其替换为一个专用的 `type=registration` 对象加上一个 `outbound_auth`。

**传统 `sip.conf`：**

```
[general]
register => 1020:supersecret@sip.example.com:5600/9999

[itsp]
type=peer
host=sip.example.com
port=5600
defaultuser=1020
secret=supersecret
fromuser=1020
fromdomain=sip.example.com
context=from-pstn
```

**Asterisk 22 `pjsip.conf`：**

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
outbound_auth=itsp-auth
aors=itsp-aor
from_user=1020
from_domain=sip.example.com

[itsp-auth]
type=auth
auth_type=digest
username=1020
password=supersecret

[itsp-aor]
type=aor
contact=sip:sip.example.com:5600

[itsp-reg]
type=registration
transport=transport-udp
outbound_auth=itsp-auth
server_uri=sip:sip.example.com:5600
client_uri=sip:1020@sip.example.com:5600
contact_user=9999
retry_interval=60
```

将 `register =>` 字段一一映射：`1020:supersecret` 凭据成为 `auth` 对象（引用为 `outbound_auth`）；`@sip.example.com:5600` 成为 `server_uri`；`/9999` 后缀（即运营商发送入站呼叫时使用的用户部分）成为 `contact_user=9999`。`defaultuser`/`fromuser` 和 `fromdomain` 成为 endpoint 上的 `from_user` 和 `from_domain`。请注意，`outbound_auth` 出现了 *两次*：注册过程使用它进行 REGISTER，而 endpoint 使用它来响应出站 INVITE 上的 `407` 质询。

## 选项迁移参考

当您手动进行翻译（或审核脚本输出）时，此表可作为查询参考。每个 PJSIP 选项名称及其位置（endpoint / aor / auth / transport）均已在 Asterisk 22 实验环境中进行了验证。

| Legacy `sip.conf` | Asterisk 22 `pjsip.conf` | 位置 |
| --- | --- | --- |
| `[peer]` / `[user]` / `[friend]` | `type=endpoint` (+ `auth` + `aor`) | — |
| `host=dynamic` | `max_contacts=1` (device REGISTERs) | aor |
| `host=<ip/host>` | `contact=sip:<host>:<port>` | aor |
| `register => u:p@host/ext` | `type=registration` + `outbound_auth` | registration |
| `secret=` | `password=` | auth |
| `username=` / `defaultuser=` | `username=` | auth |
| `secret=` (auth method) | `auth_type=digest` | auth |
| `nat=force_rport,comedia` | `force_rport=yes` + `rewrite_contact=yes` + `rtp_symmetric=yes` | endpoint |
| `directmedia=yes/no` | `direct_media=yes/no` | endpoint |
| `dtmfmode=rfc2833` | `dtmf_mode=rfc4733` | endpoint |
| `disallow=` / `allow=` | `disallow=` / `allow=` (same syntax) | endpoint |
| `context=` | `context=` | endpoint |
| `qualify=yes` | `qualify_frequency=<seconds>` | aor |
| `insecure=invite` | omit auth; use `type=identify` + `match=` | identify |
| `fromuser=` / `fromdomain=` | `from_user=` / `from_domain=` | endpoint |
| `externaddr=` / `externip=` | `external_media_address=` + `external_signaling_address=` | transport |
| `localnet=` | `local_net=` | transport |

### 关于 `secret` → `auth` 和 `auth_type` 的说明

`chan_sip` 的 `secret=` 变成了 `type=auth` 对象的 `password=` 字段。**认证方法**通过 `auth_type` 进行设置。请使用 `auth_type=digest`。较旧的值 `userpass` 和 `md5` 仍然有效，但已被**弃用并静默转换为 `digest`** —— 这已直接在实验环境中得到验证：

```
*CLI> config show help res_pjsip auth auth_type
...
 The older 'md5' and 'userpass' values are deprecated and converted to 'digest'.
    userpass - Deprecated.  Use 'digest'.
    md5 - Deprecated.  Use 'digest'.
    digest - If selected, the 'password' ... parameters must be provided.
```

您会在较旧的配置和转换脚本的输出中（以及本书的前几章中）看到 `auth_type=userpass`。它没有危害，但在编写任何新内容时，请使用 `digest`。

### NAT、媒体和 DTMF 详解

这三项是迁移后出现“已注册但无音频”工单的主要原因。旧版 `chan_sip` 的简写 `nat=force_rport,comedia` 将三种行为打包在一个选项中；而 PJSIP 将它们拆分，以便您可以分别进行配置：

```
; sip.conf:  nat=force_rport,comedia
; pjsip.conf (on the endpoint):
force_rport=yes        ; reply to the source IP/port of the request (RFC 3581)
rewrite_contact=yes    ; rewrite the stored Contact to the real source address
rtp_symmetric=yes      ; send RTP back where it actually came from (comedia)
```

对于 **媒体 (media)**，`directmedia` 变成了 `direct_media`（下划线是唯一的改动）；当通话必须锚定在 Asterisk 上时（例如跨越 NAT，或进行录音、转码、转接），请保留 `direct_media=no`。对于 **DTMF**，RFC 编号已更新：`chan_sip` 的 `dtmfmode=rfc2833` 对应 PJSIP 的 `dtmf_mode=rfc4733`（相同的带外 telephone-event 机制，当前的 RFC 编号）。实验证实，有效的 `dtmf_mode` 值包括 `rfc4733`、`inband`、`info`、`auto` 和 `auto_info`，默认值为 `rfc4733`。

对于 **codec**，没有任何变化：`disallow=all` 后跟 `allow=ulaw`（等）在 PJSIP endpoint 上使用完全相同的语法。

## Dialplan 和 CLI 变更

迁移工作并不仅限于 `pjsip.conf`。日常使用中的两项内容发生了变化。

### 通道字符串：`SIP/` → `PJSIP/`

在 `extensions.conf` 中引用旧技术的每一个 `Dial()` 和通道引用都必须进行更新：

```
; Before (chan_sip)
exten => 2000,1,Dial(SIP/2000,30,tT)

; After (chan_pjsip)
exten => 2000,1,Dial(PJSIP/2000,30,tT)
```

Trunk 拨号字符串遵循相同的模式 —— `Dial(SIP/${EXTEN}@itsp)` 变为 `Dial(PJSIP/${EXTEN}@itsp)`。PJSIP 还增加了 `PJSIP_DIAL_CONTACTS()` 函数，用于同时呼叫绑定到 AOR 的所有联系人，以及 `PJSIP_HEADER()` / `PJSIP_MEDIA_OFFER()` dialplan 函数；请在您的 dialplan 中搜索 `SIP/`、`SIPPEER`、`SIPCHANINFO` 和 `CHANNEL(...)` SIP 引用，并逐一进行转换。

### CLI：`sip show ...` → `pjsip show ...`

整个 `sip ...` 命令树已随驱动程序一同移除。以下是替代方案：

| `chan_sip` 命令 | Asterisk 22 (`chan_pjsip`) |
| --- | --- |
| `sip show peers` | `pjsip show endpoints` |
| `sip show peer <name>` | `pjsip show endpoint <name>` |
| `sip show registry` | `pjsip show registrations` |
| `sip show channels` | `core show channels` (或 `pjsip show channels`) |
| `sip set debug on` | `pjsip set logger on` |
| `sip reload` | `module reload res_pjsip.so` (或 `core reload`) |

旧命令不仅行为不同，它们已不复存在。在实验室环境中，`sip show peers` 会返回 *No such command*，而 `pjsip show endpoints`、`pjsip show aors`、`pjsip show auths`、`pjsip show contacts`、`pjsip show registrations` 和 `pjsip show identifies` 均可用。最实用的故障排除命令 —— 即那个通过 `sip set debug` 打印每条消息的 SIP 数据包记录器 —— 现在是 **`pjsip set logger on`**（使用 `pjsip set logger host <ip>` 可聚焦于单个 peer）。

## Realtime (ARA) 迁移

如果您之前通过数据库（Asterisk Realtime Architecture）运行 `chan_sip`，那么您的设备存储在 `sippeers` 表中，注册信息存储在 `sipregs` 中。PJSIP 使用了一个完全不同的存储层——**Sorcery**——即*每个对象类型*对应一张表。映射关系如下：

| `chan_sip` realtime 表 | PJSIP / Sorcery 表 |
| --- | --- |
| `sippeers` | `ps_endpoints`, `ps_aors`, `ps_auths` (每种一行，拆分存储) |
| `sipregs` | `ps_contacts` (动态注册) |
| — (出站 `register=>`) | `ps_registrations` |
| — (IP 匹配) | `ps_endpoint_id_ips` (即 `identify` 对象) |
| — (域名别名) | `ps_domain_aliases` |

其概念上的拆分与平面文件（flat-file）的情况相同：一行 `sippeers` 数据会变成三个表中的*三行*数据（`ps_endpoints` + `ps_aors` + `ps_auths`），它们通过 endpoint 名称相互引用。

以下两点使迁移变得可行：

- **架构由系统为您生成。** Asterisk 在 `contrib/ast-db-manage/` 下提供了 Alembic 迁移脚本，可以创建所有的 `ps_*` 表。针对 `config` 数据库运行 `alembic upgrade head`，即可构建当前的 PJSIP 架构，而无需手动编写 DDL。
- **存在一个 SQL 转换脚本。** 在 `contrib/scripts/sip_to_pjsip/` 目录中，与 `sip_to_pjsip.py` 并列存放着 **`sip_to_pjsql.py`**；它复用了相同的 `convert()` 逻辑，但输出的是一个包含 `INSERT` 语句的 `pjsip.sql` 文件，用于填充 `ps_*` 表，而不是生成平面配置文件。与平面文件工具一样，请在加载前检查输出内容。

最后，将 `sorcery.conf` 指向您的数据库，以便 PJSIP 通过 `res_config_odbc` / `res_pjsip_realtime` 从 `ps_*` 表中读取 endpoint、aor、auth 和 contact，这与 `extconfig.conf` 曾经将 `sippeers` 指向数据库以获取 `chan_sip` 的方式完全一致。Realtime 的具体机制在《Realtime》一章中已有介绍；此处迁移的重点仅仅是*哪些表映射到哪些表*。

## 迁移检查清单

生产环境切换的实用操作顺序：

1. **盘点。** 列出所有设备、trunk 和 `register =>`，记录在 `sip.conf` 中（或每个 `sippeers`/`sipregs` 行）。记录自定义的 NAT、codec 和 DTMF 设置。
2. **运行转换器并输出到临时文件。**
   `sip_to_pjsip.py sip.conf pjsip_generated.conf`。请**不要**将其指向您正在运行的 `pjsip.conf`。
3. **阅读输出顶部的 "Non mapped elements"（未映射元素）区块** 并解决每一行问题 —— 特别是 `qualify`、计时器以及任何与 NAT 相关的内容。
4. **手动设计 transport。** 每个 IP/端口对应一个 transport；根据需要添加 TLS/TCP；为云端/NAT 设备设置 `external_*_address` 和 `local_net`。
5. **验证认证。** 在每个 `auth` 对象上确认 `auth_type=digest`、用户名和密码。
6. **验证 NAT/媒体/DTMF。** 根据需要为每个 endpoint 配置 `force_rport`/`rewrite_contact`/`rtp_symmetric`、 `direct_media` 和 `dtmf_mode=rfc4733`。
7. **更新 dialplan。** 将所有地方的 `SIP/` 替换为 `PJSIP/`；检查 `SIP*` 函数和通道变量。
8. **更新脚本和监控。** 任何解析 `sip show ...` 输出的工具或 AMI 消费者都必须迁移到 `pjsip show ...` / PJSIP AMI 操作。
9. **重载并验证。** 执行 `module reload res_pjsip.so`，然后检查 `pjsip show endpoints`、`pjsip show registrations` 和 `pjsip show identifies`。
10. **使用数据包记录器进行测试。** 执行 `pjsip set logger on`；发起一次注册、一次呼入呼叫和一次呼出呼叫，并端到端地读取 SIP 交互过程。

## 常见陷阱

- **`alwaysauthreject` 现在是内置功能 — 无需寻找。** `chan_sip` 过去需要 `alwaysauthreject=yes` 以免通过对错误用户名做出不同响应来泄露存在的 extension。PJSIP 在设计上就采用了安全做法：它从不透露 endpoint 是否存在。没有 `alwaysauthreject` 选项需要设置。相关的保护措施——对未识别的发送者进行限流——是全局的 `unidentified_request_count` / `unidentified_request_period`，默认处于开启状态。

- **`insecure=invite` 不是 PJSIP 选项 — 请使用 `identify`。** 在 `pjsip.conf` 中没有 `insecure=`。接收来自已知运营商未经身份验证的 INVITE 的方法是：通过 `type=identify` / `match=` *根据源 IP 识别 endpoint*。匹配范围应尽可能窄（使用具体的主机 IP，而不是宽泛的 CIDR），并配合 `type=acl` 使用——一个没有身份验证且仅通过 IP 匹配的 trunk 是话费欺诈的目标。

- **每个 IP/端口仅限一个传输层。** 你不能将两个传输层绑定到同一个 IP:端口，也不能绑定多个相同 IP 版本的 TCP 或 TLS 传输层。转换脚本可能会生成一个与你现有传输层冲突的配置——请将其整合为一个经过精心设计的单一传输层。

- **`qualify=yes` 不能转换为布尔值。** 它属于 **aor**，即 `qualify_frequency=<seconds>`。转换器将 `qualify=yes` 放入未映射的块中，正是因为 endpoint 上没有对应的布尔值。

- **`secret=` 不是 endpoint 选项。** 凭据仅存在于 endpoint *引用* 的 `type=auth` 对象中（`auth=` 用于入站，`outbound_auth=` 用于出站）。在 endpoint 上设置密码不会起任何作用。

- **CLI 和任何抓取脚本会静默失败。** `sip show ...` 会返回 "No such command"，而不是你的监控系统必然能捕获的错误。在切换之前，请审计每一个 cron 任务、Nagios 检查和 AMI 客户端中的 `sip ` 命令。

## 总结

迁移到 Asterisk 22 意味着必须弃用 `chan_sip`，因为该驱动程序已在 Asterisk 21 中被移除，而 PJSIP 是唯一保留的 SIP 通道。这项工作的核心是将每个 `sip.conf` `peer`/`user`/`friend`（它们将所有内容打包在一个块中）重新表达为一组相互协作的 PJSIP 对象：一个 `endpoint` 加上一个 `auth`、一个 `aor`，并根据设备的不同，还需要一个 `identify`（入站 trunk）、一个 `registration`（出站登录）以及一个共享的 `transport`。位于 `contrib/scripts/sip_to_pjsip/` 中的 `sip_to_pjsip.py` 脚本完成了大部分转换工作，并会如实地在“Non mapped elements”块中标记出无法映射的内容，但其输出仅为初稿：请务必手动设计 transport、NAT 和安全性，并在投入生产前进行测试。在配置方面，请更新 dialplan（`SIP/` → `PJSIP/`）以及您的操作习惯和脚本（`sip show` → `pjsip show`，`sip set debug` → `pjsip set logger`）。Realtime 部署需从 `sippeers`/`sipregs` 迁移至 Sorcery 的 `ps_endpoints`/`ps_aors`/`ps_auths`/`ps_contacts` 表，并可借助 `sip_to_pjsql.py` 和 `contrib/ast-db-manage` 模式来完成。请注意其中的陷阱——`alwaysauthreject` 是内置的，`insecure=invite` 变为 `identify`，`qualify=yes` 变为 `qualify_frequency`，且每个 IP/端口只能有一个 transport——这样切换过程将是机械化的，而非神秘莫测的。

## 测试题

1. 为什么 Asterisk 22 部署必须使用 PJSIP 来处理 SIP？
   - A. `chan_sip` 速度较慢但仍然可用
   - B. `chan_sip` 已在 Asterisk 21 中移除，且在 Asterisk 22 中不存在
   - C. PJSIP 是默认选项，但可以通过 `modules.conf` 加载 `chan_sip`
   - D. `chan_sip` 在 Asterisk 22 中仅支持 TLS

2. 单个 `sip.conf` `type=friend` 块最常转换为哪一组 PJSIP 对象？
   - A. 单个 `type=peer`
   - B. 仅 `type=endpoint`
   - C. `type=endpoint` + `type=auth` + `type=aor`
   - D. `type=transport` + `type=registration`

3. 在 `sip.conf` 中，`host=dynamic`（设备注册其自身位置）映射到：
   - A. 带有 `match=dynamic` 的 `type=identify`
   - B. 带有 `max_contacts` 的 `type=aor`（设备执行 REGISTER）
   - C. endpoint 上的 `direct_media=yes`
   - D. `type=registration`

4. `sip_to_pjsip.py` 转换脚本是：
   - A. 一个 CLI 命令：`asterisk -rx 'sip_to_pjsip'`
   - B. Asterisk 源码树中位于 `contrib/scripts/sip_to_pjsip/` 下的一个 Python 脚本
   - C. 一个在引导时加载的已编译模块
   - D. `res_pjsip.so` 的一部分

5. 判断对错：`sip_to_pjsip.py` 的输出已达到生产就绪状态，无需审查即可直接加载。

6. `chan_sip` 的简写 `nat=force_rport,comedia` 在 PJSIP endpoint 上会转换为哪三个选项？
   - A. `nat=yes`, `qualify=yes`, `directmedia=no`
   - B. `force_rport=yes`, `rewrite_contact=yes`, `rtp_symmetric=yes`
   - C. `external_media_address`, `external_signaling_address`, `local_net`
   - D. `insecure=invite`, `identify`, `match`

7. `sip.conf` 的 `dtmfmode=rfc2833` 变成了哪个 PJSIP 设置？
   - A. `dtmf_mode=rfc2833`
   - B. `dtmf_mode=inband`
   - C. `dtmf_mode=rfc4733`
   - D. `dtmf_mode=info`

8. 在 Asterisk 22 上，`auth` 对象应该使用哪个 `auth_type`，且 `userpass` 的状态是什么？
   - A. `auth_type=userpass`；这是唯一有效的值
   - B. `auth_type=digest`；`userpass` 已被弃用并转换为 `digest`
   - C. `auth_type=md5`；`digest` 已被弃用
   - D. `auth_type=plaintext`；`digest` 已被移除

9. 带有 `insecure=invite`（接受来自已知 IP 的未经身份验证的 INVITE）的 `chan_sip` 提供商对等体，通过以下哪种方式迁移到 PJSIP：
   - A. endpoint 上的 `insecure=invite`
   - B. `[global]` 中的 `allowguest=yes`
   - C. 带有 `match=<provider IP>` 的 `type=identify` 对象
   - D. `auth_type=anonymous`

10. 在 realtime 迁移中，`chan_sip` `sippeers` 表被哪些 PJSIP/Sorcery 表替换？
    - A. 单个 `pjsip_peers` 表
    - B. `ps_endpoints`, `ps_aors` 和 `ps_auths`
    - C. `sipregs` 和 `voicemail`
    - D. 仅 `ps_contacts`

**答案：** 1 — B · 2 — C · 3 — B · 4 — B · 5 — 错误 · 6 — B · 7 — C · 8 — B · 9 — C · 10 — B
