# WebRTC 与 Asterisk

WebRTC (Web Real-Time Communication) 允许 Web 浏览器在无需插件和外部 softphone 的情况下拨打和接听电话——只需 JavaScript、麦克风以及与 Asterisk 之间的安全连接。自 Asterisk 11 起，Asterisk 就能够充当 WebRTC 服务器；自 Asterisk 12 引入 PJSIP 协议栈 (`res_pjsip`) 以来，这已成为实现该功能的推荐方式；在 Asterisk 22 中，其配置已简化为少数几个广为人知的选项。本章将展示如何将 PJSIP endpoint 转换为浏览器电话、安全媒体路径的工作原理，以及何时应该选择 Asterisk 内置的 WebRTC 支持而非专用的网关。

本章中的所有内容均已针对本书的 Asterisk 22 实验环境进行了验证；所展示的配置与 `lab/asterisk/etc` 中的配置相同。

## 目标

读完本章后，您应该能够：

- 解释 WebRTC 为 Asterisk 增加了什么功能以及何时使用它
- 描述 WebRTC 媒体安全（DTLS-SRTP）和 ICE 与普通 SIP 有何不同
- 启用 Asterisk HTTP 服务器和安全 WebSocket（`wss`）endpoint
- 使用`webrtc=yes`配置一个`wss` PJSIP transport 和一个 WebRTC endpoint
- 连接浏览器 softphone（SIP.js）并拨打电话
- 在 Asterisk 原生 WebRTC 和诸如 Janus 之类的媒体网关之间做出选择

## 为什么在 Asterisk 中使用 WebRTC

从 Asterisk 的角度来看，WebRTC endpoint 仅仅是另一个 PJSIP endpoint。
所不同的是浏览器如何连接到它，以及媒体如何进行加密。典型的应用场景包括：

- **网页点击通话 (Click-to-call)** — 访客直接从网页拨打队列或 extension。
- **基于 Web 的座席** — 联络中心座席完全在浏览器中工作，无需安装或更新桌面 softphone。
- **在您自己的 Web 应用程序中嵌入通话功能** — 例如，与 Asterisk 通信的 SipPulse web softphone。
- **零安装内部电话** — 员工使用浏览器标签页代替硬件电话或已安装的客户端。

其巨大的优势在于覆盖范围：每个现代浏览器都已经支持 WebRTC。代价是 WebRTC 非常严格——它*要求*加密媒体和安全传输，因此相比普通的 UDP SIP 电话，需要配置的内容更多。

## WebRTC 与普通 SIP 的区别

普通的 SIP 话机通过 UDP/TCP 进行信令传输，通常使用普通的 RTP 承载音频。WebRTC 浏览器客户端在三个重要方面有所不同，而 Asterisk 必须针对每一项进行匹配：

- **信令通过 WebSocket 传输。** 浏览器不是使用 UDP 端口 5060 上的 SIP，而是向 Asterisk 内置的 HTTP 服务器打开一个安全的 WebSocket (`wss://`)。SIP 消息在 WebSocket 内部传输。
- **媒体始终使用 DTLS-SRTP 加密。** 浏览器拒绝使用普通的 RTP。双方执行 DTLS 握手（通过 SDP 中交换的证书指纹进行认证），并从中派生出 SRTP 密钥。
- **连接通过 ICE 进行协商。** 双方不是假设存在可达的 IP 和端口，而是收集候选地址（主机地址、STUN 反射地址、TURN 中继地址）并进行探测，直到找到可用的地址。RTP 和 RTCP 通常在单个端口上进行多路复用 (`rtcp_mux`)。

好消息是：在 Asterisk 22 中，通过一个单一的 endpoint 选项 `webrtc=yes`，即可启用所有这些功能并使用合理的默认设置。我们将详细了解它具体设置了哪些内容。

## 第 1 步 — HTTP 服务器与 WebSocket

WebRTC 信令由 Asterisk 内置的 HTTP 服务器提供服务（`res_http_websocket`在其上公开了 `/ws` 路径）。浏览器需要*安全*的 WebSocket，因此我们需要启用 TLS。编辑 `http.conf`：

```
[general]
enabled=yes
bindaddr=0.0.0.0
bindport=8088

; TLS / WSS for WebRTC. Browsers require a secure WebSocket (wss://).
tlsenable=yes
tlsbindaddr=0.0.0.0:8089
tlscertfile=/etc/asterisk/keys/asterisk.crt
tlsprivatekey=/etc/asterisk/keys/asterisk.key
```

重新加载（`module reload res_http_websocket`或重启）并确认：

```
*CLI> http show status
HTTP Server Status:
Server: Asterisk/22.10.0
Server Enabled and Bound to 0.0.0.0:8088

HTTPS Server Enabled and Bound to 0.0.0.0:8089

Enabled URI's:
/ws => Asterisk HTTP WebSocket
```

浏览器将连接到 `wss://your-asterisk:8089/ws`。

### 关于证书

此处的 TLS 证书用于保护 *WebSocket*（信令通道）。在实验室环境中，自签名证书即可满足需求——您只需在浏览器中接受一次即可。在生产环境中，请使用名称与浏览器连接的主机名相匹配的真实证书（例如 Let's Encrypt），否则浏览器将拒绝连接该 WebSocket。

对于实验室环境，`lab/make-certs.sh` 会生成一个带有 `CN=localhost`（以及 `localhost`/`127.0.0.1` SAN）的自签名证书，并将其写入 `asterisk/etc/keys/`。对于公共部署，请改用真实证书——例如使用 Let's Encrypt：

```
certbot certonly --standalone -d voip.example.com
```

然后将 `http.conf` 指向已签发的文件并重新加载 `res_http_websocket`：

```
tlscertfile=/etc/letsencrypt/live/voip.example.com/fullchain.pem
tlsprivatekey=/etc/letsencrypt/live/voip.example.com/privkey.pem
```

请确保证书名称与浏览器连接的主机名相匹配，并在证书过期前进行续期（certbot 的计时器会自动执行此操作），否则 WebSocket 将会失败。

此证书与用于加密媒体的 DTLS 证书**不同**——正如我们将要看到的，Asterisk 会自动生成后者。

## 第 2 步 — WSS 传输

PJSIP 需要一个类型为 `wss` 的传输。将其添加到 `pjsip.conf` 中：

```
[transport-wss]
type=transport
protocol=wss
bind=0.0.0.0
```

验证它是否已加载：

```
*CLI> pjsip show transports
Transport:  transport-udp             udp      0      0  0.0.0.0:5060
Transport:  transport-wss             wss      0      0  0.0.0.0:5060
```

不要被 `wss` 传输显示的 `0.0.0.0:5060` 所误导 — WebSocket **并非**在 5060 端口上提供服务。WebRTC 信令由您在第 1 步中配置的 HTTP 服务器（`wss` 的 8089 端口）提供。PJSIP `wss` 传输只是 `res_http_websocket` 之上的一个轻量级垫片，因此为其打印的 `bind` 地址仅具装饰性，可以忽略；真正重要的是 `http.conf` 中的 `tlsbindaddr` 端口。

## Step 3 — the WebRTC endpoint

现在是 endpoint 本身。关键在于 `webrtc=yes`：

```
[webrtc-1000]
type=endpoint
context=internal
disallow=all
allow=opus,ulaw
webrtc=yes
transport=transport-wss
aors=webrtc-1000
auth=webrtc-1000

[webrtc-1000]
type=auth
auth_type=digest
username=webrtc-1000
password=Lab-webrtc-secret

[webrtc-1000]
type=aor
max_contacts=1
```

`webrtc=yes` 是一个便捷开关。它等同于手动设置所有 WebRTC 所需的选项。您可以确认它具体开启了哪些内容：

```
*CLI> pjsip show endpoint webrtc-1000
 dtls_auto_generate_cert            : Yes
 dtls_fingerprint                   : SHA-256
 dtls_setup                         : actpass
 ice_support                        : true
 media_encryption                   : dtls
 rtcp_mux                           : true
 use_avpf                           : true
 webrtc                             : yes
```

解读该输出：

- `media_encryption: dtls` 和 `dtls_auto_generate_cert: Yes` — 媒体采用 DTLS-SRTP，并且 Asterisk 会自动生成 DTLS 证书，因此您**无需**自行创建。指纹信息会在 SDP (`SHA-256`) 中进行通告。
- `ice_support: true` — Asterisk 会收集并协商 ICE candidates。
- `rtcp_mux: true` — RTP 和 RTCP 共享同一个端口，正如浏览器所预期的那样。
- `use_avpf: true` — AVPF RTP 配置文件（反馈），这是 WebRTC 所必需的。

建议使用 `allow=opus` — Opus 是浏览器首选的 codec。Asterisk 22 在核心中内置了 Opus *透传*（即 `res_format_attr_opus` 模块），这足以在两个支持 Opus 的链路之间中继 Opus 而无需重新编码。将 Opus *转码*为其他 codec 需要单独的 `codec_opus` 模块，官方 WebRTC 指南将其列为可选但强烈推荐，您可以在基础构建之上安装它；请参阅 *Designing a VoIP network* 中关于 codec 的讨论。保留 `ulaw` 作为桥接到无法使用 Opus 的非 WebRTC 链路时的后备方案。

## 第 4 步 — ICE、STUN 和 TURN

在扁平化的 LAN 环境中，使用 host 候选者的 ICE 就足够了，无需其他配置。在互联网环境下，通常需要添加一个 STUN 服务器，以便 Asterisk 和浏览器能够发现各自的公网地址；对于无法进行直接媒体传输的情况（例如对称 NAT 或限制性防火墙），则需要一个 TURN 服务器。在 `rtp.conf` 中将 Asterisk 指向它们：

```
[general]
icesupport=yes
stunaddr=stun.l.google.com:19302
; turnaddr=turn.example.com:3478
; turnusername=...
; turnpassword=...
```

浏览器在 JavaScript 中配置其自身的 ICE 服务器（即 `RTCPeerConnection` `iceServers` 列表）。对于纯内部部署，可以完全跳过 STUN/TURN。

`turnaddr` 接受一个可选端口（默认值为 `3478`）；`turnusername` 和 `turnpassword` 用于向中继进行身份验证。STUN 仅有助于对端 *发现* 其公网地址 — 当两端都位于对称 NAT 或限制性防火墙之后时，直接媒体传输是不可能的，此时只有 TURN 中继才能使音频正常流通。

**生产环境建议：** 公共 STUN 服务器（例如 Google 的服务器）足以用于地址发现，但请**不要**依赖公共 TURN 服务器来处理实际流量 — TURN 会中继您所有的媒体数据，因此您需要将其置于自己的控制之下。请运行您自己的 [coturn](https://github.com/coturn/coturn) 服务器。一个带有长期凭据的最小化 `/etc/turnserver.conf` 配置如下所示：

```
listening-port=3478
fingerprint
lt-cred-mech
user=asterisk:Strong-TURN-secret
realm=voip.example.com
external-ip=203.0.113.10
```

然后在 `rtp.conf` 中将 Asterisk 指向它：

```
[general]
icesupport=yes
stunaddr=stun.l.google.com:19302
turnaddr=turn.example.com:3478
turnusername=asterisk
turnpassword=Strong-TURN-secret
```

在浏览器的 `iceServers` 列表中提供相同的 TURN 服务器，以便两端都能进行中继。对于用户位于移动网络或企业防火墙之后的生产环境，自托管的 coturn 实际上是强制要求的。

## 第 5 步 — 浏览器客户端

任何 WebRTC SIP 库都可以使用；其中两个广泛使用的库是 **SIP.js** 和 **JsSIP**。本实验在 `lab/webrtc/index.html` 中包含了一个极简的 SIP.js softphone。其核心部分是传输 URL 和凭据：

```javascript
const ua = new SIP.UserAgent({
  uri: SIP.UserAgent.makeURI('sip:webrtc-1000@your-asterisk'),
  transportOptions: { server: 'wss://your-asterisk:8089/ws' },
  authorizationUsername: 'webrtc-1000',
  authorizationPassword: 'Lab-webrtc-secret',
});
await ua.start();
await new SIP.Registerer(ua).register();
// place a call to the echo test
const inviter = new SIP.Inviter(ua, SIP.UserAgent.makeURI('sip:600@your-asterisk'));
await inviter.invite();
```

需要记住两个关于浏览器的现实情况：

- **安全上下文。** `getUserMedia`（麦克风访问）仅在 `https://` 页面或 `http://localhost` 上有效。在生产环境中，请通过 HTTPS 提供页面服务。
- **接受一次证书。** 对于自签名的实验证书，请先在同一个浏览器中访问 `https://your-asterisk:8089/ws` 并接受警告，否则 WebSocket 将会静默失败。

SipPulse web softphone 是一个基于这些相同原语构建的生产级参考客户端。

## 验证 WebRTC 通话

在浏览器完成注册后，`pjsip show contacts`会显示动态联系人，并且通话会激活通道：

```
*CLI> pjsip show contacts
  Contact:  webrtc-1000/sip:webrtc-1000@... NonQual Avail
*CLI> core show channels
PJSIP/webrtc-1000-00000001  internal  600  Up  Echo
```

如果出现单向音频或无音频的情况，通常都是 ICE 或证书配置的问题——请参阅下方的故障排除部分。

## Asterisk WebRTC 与媒体网关的对比

Asterisk 可以直接终结 WebRTC，但这并不总是最合适的工具：

- **使用 Asterisk 原生 WebRTC**：当浏览器作为您 PBX 上的一个 *phone* 时——例如座席、内部 extension、或者落地到您 dialplan 中的点击拨号功能。此时浏览器只是另一个 endpoint，并且所有功能（队列、voicemail、IVR）都能正常工作。
- **使用专用网关（例如 Janus）**：当您需要独立于呼叫控制来扩展大量浏览器会话、为大型会议/流媒体进行选择性转发，或者需要将媒体平面与 PBX 分离时。网关将 WebRTC 桥接到普通 SIP，此时 Asterisk 看到的只是一个普通的 SIP 链路。

许多实际系统会将两者结合使用：Asterisk 用于呼叫控制，网关用于浏览器端的媒体扩展。（这就是 SipPulse 自身技术栈背后的架构。）

## 故障排除

- **WebSocket 无法连接：** 浏览器拒绝了 TLS 证书。直接打开 `https://host:8089/ws` 并接受它，或者安装受信任的证书。
- **已注册但无音频：** ICE 失败 —— 添加 STUN，如果跨越 NAT 则添加 TURN。检查 `pjsip set logger on` 并查看 SDP 候选者。
- **单向音频：** 通常是一侧的 NAT/ICE 问题，或者没有匹配的通用 codec —— 确保 `allow=opus,ulaw`。
- **应答时呼叫掉线：** DTLS 握手失败；确认 `dtls_auto_generate_cert` 为 `Yes` 且系统时钟正确（证书对时间敏感）。

## 实验

1. 运行 `./lab.sh up`，然后运行 `bash lab/make-certs.sh` 并重启 Asterisk。
2. 提供 `lab/webrtc/index.html`（来自 `lab/webrtc` 的 `python3 -m http.server`）并打开它；在 `https://localhost:8089/ws` 处接受证书。
3. 以 `webrtc-1000` 身份注册并呼叫 `600`（回声测试）——你应该能听到自己的声音。
4. 从注册为 `6001` 的 SipPulse softphone 拨打 `1000` 以呼叫浏览器。
5. 检查协商过程：运行 `pjsip set logger on`，拨打一个电话，并在 SDP 中查找 DTLS 指纹和 ICE 候选地址。

## 总结

WebRTC 将浏览器转变为一流的 Asterisk endpoint。其配置方案虽小但要求严格：启用带有 TLS 的 HTTP 服务器，以便浏览器能够打开安全的 WebSocket；添加一个 `wss` PJSIP transport；并在 endpoint 上设置 `webrtc=yes`——这将开启 DTLS-SRTP（使用自动生成的证书）、ICE、RTP/RTCP 多路复用以及 AVPF 配置文件。在穿越 NAT 时添加 STUN/TURN，通过 HTTPS 提供页面服务，并将 SIP.js（或 JsSIP）客户端指向 `wss://asterisk:8089/ws`。对于 PBX 上的浏览器电话，Asterisk 原生的 WebRTC 是最简单的路径；对于大规模媒体，请将其与网关配合使用。

## 测试题

1. WebRTC 浏览器客户端使用哪种传输方式将 SIP 信令发送到 Asterisk？
   - A. 端口 5060 上的普通 UDP
   - B. 到 Asterisk HTTP 服务器的安全 WebSocket (`wss://`)
   - C. 端口 5061 上的 TLS
   - D. 端口 8088 上的原始 TCP 套接字

2. 浏览器和 Asterisk 之间的 WebRTC 媒体使用哪种机制进行加密？
   - A. SDES-SRTP（密钥在 SDP 中交换）
   - B. DTLS-SRTP（密钥从 DTLS 握手中派生）
   - C. IPsec
   - D. 普通 RTP — WebRTC 不加密媒体

3. 判断对错：当您设置 `webrtc=yes` 时，必须手动生成并安装用于加密媒体的 DTLS 证书。

4. 实验中 Asterisk 的 HTTP 服务器在哪个端口上为 WebRTC 提供**安全** WebSocket？
   - A. 5060
   - B. 5061
   - C. 8088
   - D. 8089

5. 以下哪项由 `webrtc=yes` 默认开启？（选择所有适用项。）
   - A. `media_encryption: dtls`
   - B. `ice_support: true`
   - C. `rtcp_mux: true`
   - D. `use_avpf: true`
   - E. `transport: transport-udp`

6. 填空：WebRTC 通过让双方使用 ________ 框架来收集和探测候选地址（主机地址、STUN 反射地址、TURN 中继地址）来协商连接性。

7. 在 `rtp.conf` 中，哪两个设置指向外部服务器，以便 Asterisk 可以发现其公网地址并在直接路径失败时中继媒体？（选择所有适用项。）
   - A. `icesupport=yes`
   - B. `stunaddr=`
   - C. `turnaddr=`
   - D. `tlsbindaddr=`

8. Asterisk 的 `res_http_websocket` 为 WebRTC 信令提供的 URL 路径是 ________。

9. 根据本章内容，何时应该选择专用的媒体网关（例如 Janus）而不是 Asterisk 原生的 WebRTC？
   - A. 任何浏览器需要拨打电话时
   - B. 当您需要独立于呼叫控制扩展大量浏览器媒体会话、为大型会议进行选择性转发，或将媒体平面与 PBX 分离时
   - C. 仅在浏览器不支持 DTLS 时
   - D. 当您希望浏览器 endpoint 使用 voicemail 和 IVR 时

10. 判断对错：`getUserMedia`（麦克风访问）适用于任何 `http://` 页面，因此通过 HTTPS 提供 softphone 服务是可选的。

**答案：** 1 — B · 2 — B · 3 — 错误（Asterisk 会自动生成 DTLS 证书；`dtls_auto_generate_cert: Yes`） · 4 — D · 5 — A, B, C, D · 6 — ICE · 7 — B, C · 8 — `/ws` · 9 — B · 10 — 错误（需要安全上下文：`getUserMedia` 仅在 `https://` 或 `http://localhost` 上有效）
