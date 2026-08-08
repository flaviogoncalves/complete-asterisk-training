# SIP & PJSIPの詳細

SIPはプロトコルであり、PJSIPはAsterisk 22におけるその実装方法です。**PJSIP**（`chan_pjsip`、設定は`pjsip.conf`を使用）は、Asterisk 22 LTSにおける唯一のSIPチャネルドライバです。本章では、SIPプロトコルの基礎（プロトコルレベルの仕様であり、100%有効なままです）と、日常的に使用するPJSIPのオブジェクトモデルおよび設定について解説します。廃止されたレガシードライバと移行ガイドについては、「*Legacy channels*」の章で取り上げています。

## Objectives

この章を読み終えることで、以下のことができるようになります。

- SIPユーザーエージェント、プロキシ、レジストラ、ゲートウェイの役割を説明する。
- 基本的なSIPコールフロー（REGISTER、INVITE、暫定応答および最終応答、ACK、BYE）を追い、SIPメッセージを読み解く。
- SDPがどのようにメディアセッションをネゴシエーションするか、またNATがSIPシグナリングとRTPにどのような影響を与えるかを説明する。
- PJSIPオブジェクトモデル（`endpoint`、`auth`、`aor`、`transport`、`identify`、および`registration`）をマッピングし、それらのオブジェクトがどのように相互参照されるかを理解する。
- NATトラバーサルオプションを含め、`pjsip.conf`でSIP電話とtrunkを設定する。
- `pjsip show …` CLIコマンドを使用して、endpointの検証とトラブルシューティングを行う。

## SIPプロトコルの基礎

Session Initiation Protocol (SIP) は、HTTPやSMTPに似たテキストベースのプロトコルであり、ユーザー間の対話型通信セッションを開始、維持、終了するために設計されました。これらのセッションには、音声、ビデオ、チャット、対話型ゲームなどが含まれます。SIPはIETFによって定義され、音声通信の事実上の標準となっています。SIPがどのように機能するかを理解することは非常に重要です。Asterisk 22では、SIPの設定は`pjsip.conf`に記述されます。これは、SIPベースのシステムにおいて（`extensions.conf`の次に）最も頻繁に編集されるファイルの一つです。

### 動作の理論

SIPは、User Agent Client、User Agent Servers、SIP Proxies、SIP Gatewaysというコンポーネントで構成されるシグナリングプロトコルです。以下の図は、これらのコンポーネント間の関係を示しています。

- UAC (user agent client) – SIPシグナリングを開始するクライアントまたは端末。
- UAS (user agent server) – UACからのSIPシグナリングに応答するサーバー。
- UA (user agent) – SIP端末（UACとUASの両方を含む電話機やゲートウェイ）。
- Proxy Server – UAからリクエストを受け取り、特定のステーションが自身の管理下にない場合に他のSIP Proxiesへ転送する。
- Redirect Server – リクエストを受け取り、宛先に直接転送する代わりに、宛先データを含む情報をUAに送り返す。
- Location Server – UAからリクエストを受け取り、この情報でロケーションデータベースを更新する。

通常、プロキシ、リダイレクト、およびロケーションサーバーは同じハードウェア上でホストされ、同じソフトウェアを使用します。これをSIPプロキシと呼びます。SIPプロキシは、ロケーションデータベースの維持、接続の確立、およびセッションの終了を担当します。

![主要なSIPコンポーネント：ユーザーエージェント (UAC/UAS/UA)、レジストラ/プロキシ/リダイレクトサーバー、およびPSTNへのゲートウェイ。RTPメディアはエンドポイント間で直接流れる](../images/07-sip-and-pjsip-fig01.png)

#### SIP登録プロセス

電話機が通話を受信できるようになるには、ロケーションデータベースに登録される必要があります。ロケーションデータベースでは、IPアドレスが名前と紐付けられます。以下の例では、extension 8500がIPアドレス 200.180.1.1 に紐付けられます。必ずしも電話番号を使用する必要はありません。SIPアーキテクチャでは、登録されるextensionは flavio@voip.school のような形式でも構いません。

![SIP登録：電話機がextension 8500を自身のIPアドレスに紐付けるREGISTERを送信し、レジストラがその連絡先をロケーションデータベースに保存して200 OKで応答する](../images/07-sip-and-pjsip-fig02.png)

#### プロキシの動作

SIPプロキシとして動作する場合、SIPサーバーはシグナリングの途中に留まり、高度なルーティングや課金を行うことができます。Real Time Protocol (RTP) に基づくメディアフローは、依然としてエンドポイント間で直接行われます。

![プロキシの動作：SIPプロキシはシグナリングパス (INVITE/200 OK) に留まり、ロケーションサーバーで着信側を検索する。一方、RTPメディアは2つのエンドポイント間で直接流れる](../images/07-sip-and-pjsip-fig03.png)

#### リダイレクトの動作

リダイレクトを行う際、SIPサーバーは単にメッセージ（例：302 moved temporarily）をユーザーエージェントに送信し、新しいメッセージのパスから外れます。リソース使用量の観点からは非常に軽量ですが、制御は一切行えません。リダイレクトは、負荷分散の設計で使用されることがあります。

![リダイレクトの動作：リダイレクトサーバーが連絡先情報を含む302 Moved TemporarilyでINVITEに応答し、その後は退く。発信側は新しい宛先にINVITE/ACKを直接再送する](../images/07-sip-and-pjsip-fig04.png)

#### AsteriskにおけるSIPの扱い

AsteriskはSIPプロキシでもSIPリダイレクタでもないことを理解しておくことが重要です。Asteriskはレジストラおよびロケーションサーバーの役割を果たすことができますが、自身に対して2つのUACを接続するだけです。そのため、AsteriskはBack-to-Back User Agent (B2BUA) と見なされます。言い換えれば、2つのSIPチャンネルを接続し、ブリッジする役割を果たします。Asteriskには、SIPチャンネルをAsterisk経由ではなく直接通信させるためのre-inviteメカニズムがあります。PJSIP endpointでは、これはパラメータ`direct_media`によって制御されます。`direct_media=yes`を使用すると、RTPフローは一方のエンドポイントから他方へ直接流れ、サーバーリソースを解放します。

#### direct_media=yes を使用したSIP動作

![directmedia=yes を使用したSIP動作：SIPシグナリングはAsteriskを経由するが、RTP音声は2台の電話機間で直接流れ、サーバーリソースを解放する](../images/07-sip-and-pjsip-fig05.png)

ただし、Asteriskを使用して通話を転送または録音する必要がある場合は、パラメータ`direct_media=no`を使用してRTPフローをAsteriskサーバー経由に強制することができます。

#### direct_media=no を使用したSIP動作

![directmedia=no を使用したSIP動作：SIPシグナリングとRTP音声の両方がAsteriskを経由するため、通話の録音、トランスコード、転送が可能になる](../images/07-sip-and-pjsip-fig06.png)

#### SIPメッセージ

基本的なSIPメッセージは以下の通りです：

- INVITE – 接続の確立
- ACK – 確認応答
- BYE – 接続の終了
- CANCEL – 確立されていない通話の終了
- REGISTER – SIPプロキシへのUACの登録
- OPTIONS – 可用性の確認に使用
- REFER – SIP通話を他へ転送
- SUBSCRIBE – 通知イベントの購読
- NOTIFY – チャンネル情報の送信
- INFO – 各種メッセージの送信（例：DTMF）
- MESSAGE – インスタントメッセージの送信

SIPレスポンスはテキスト形式であり、（HTTPメッセージと同様に）容易に読み取ることができます。最も重要なレスポンスは以下の通りです：

- 1XX – 情報メッセージ (100–trying, 180–ringing, 183–progress)
- 2XX – リクエスト成功 (200 – OK)
- 3XX – 通話リダイレクト、リクエストを別の場所に転送する必要がある (302 – moved temporarily, 305 – use proxy)
- 4XX – エラー (403 – Forbidden)
- 5XX – サーバーエラー (500 – Internal Server Error; 501 – Not implemented)
- 6XX – グローバル失敗 (606 – Not acceptable)

例：

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

#### Session Description Protocol (SDP)

SDPは元々IETF RFC 2327で定義され、現在はRFC 4566に置き換えられています。これは、セッションのアナウンス、セッションへの招待、およびその他のマルチメディアセッション開始の目的で、マルチメディアセッションを記述することを意図しています。SDPには以下が含まれます：

- トランスポートプロトコル (RTP/UDP/IP)
- メディアの種類 (テキスト、音声、ビデオ)
- メディアフォーマットまたはcodec (H.261ビデオ、g.711音声など)
- これらのメディアを受信するために必要な情報 (アドレス、ポートなど)

以下の例は、2台の電話機間の通話を記述するSDPの転写です。

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

### SIP NAT Traversal

Network Address Translation (NAT) は、インターネットIPアドレスを節約するためにほとんどのネットワークで使用される機能です。通常、企業は小さなIPアドレスブロックを受け取り、エンドユーザーはインターネットに接続する際に動的に1つのIPアドレスを受け取ります。NATは、内部アドレスを外部アドレスにマッピングすることでアドレス問題を解決します。NATは内部アドレスと外部アドレスのマッピングをメモリに保持します。このマッピングは一定時間有効であり、その後破棄されます。マッピングには、内部および外部アドレスのIP:portペアが使用されます。NATには4つの種類があります：

- Full Cone
- Restricted Cone
- Port Restricted Cone
- Symmetric

以下のNAT理論（4つのNATタイプ、Contactヘッダーの問題、キープアライブ、サーバー経由のメディア強制）はプロトコルレベルのものであり、あらゆるSIP実装に適用されます。Asterisk 22 (PJSIP) で各動作を設定する方法については、この章の後半の *Nat traversal on res_pjsip* で説明します。

#### Full Cone

最初のNATであるFull Coneは、外部のIP:portペアから内部のIP:portペアへの静的なマッピングを表します。外部のコンピュータは、その外部IP:portペアを使用して接続できます。これは、フィルタを使用して実装されたステートレスファイアウォールで見られるケースです。

![Full Cone NAT：内部ホスト (10.0.0.1:8000) が外部ペア 200.180.4.168:1234 に静的にマッピングされているため、外部のコンピュータはパケットをそのペアに送信して内部ホストに到達できる](../images/07-sip-and-pjsip-fig11.png)

#### Restricted Cone

Restricted Coneのシナリオでは、外部のIP:portペアは、内部のコンピュータが外部アドレスにデータを送信したときにのみ開かれます。しかし、Restricted Cone NATは、異なるアドレスからの着信パケットをブロックします。言い換えれば、内部のコンピュータは、外部のコンピュータからデータを受け取る前に、まずそのコンピュータへデータを送信する必要があります。

#### Port Restricted Cone

Port Restricted Coneファイアウォールは、Restricted Coneとほぼ同じです。唯一の違いは、着信パケットが送信パケットと全く同じIPおよびポートから来る必要があるという点です。

#### Symmetric

最後のNATタイプはSymmetricと呼ばれます。最初の3つと異なり、各外部アドレスに対して特定のマッピングが行われる点が異なります。NATマッピングによって戻ってくることが許可されるのは、特定の外部アドレスのみです。NATデバイスによって使用される外部IP:portペアを予測することは不可能です。他の3つのNATタイプでは、外部サーバーを使用して通信用の外部IPアドレスを検出できます。Symmetric NATでは、外部サーバーに接続できたとしても、検出されたアドレスはそのサーバー以外のデバイスには使用できません。

![Symmetric NAT：宛先ごとに異なる外部送信元ポートが割り当てられるため、あるサーバーに対して検出されたマッピングを別のホストが再利用できず、STUNベースのトラバーサルが機能しなくなる](../images/07-sip-and-pjsip-fig12.png)

#### NATファイアウォール表

以下の表は、4種類のNATをまとめたものです。

| NATタイプ | 最初にデータを送信する必要があるか | 戻りパケット用の外部IP:portを特定できるか | 宛先IP:portへの着信パケットを制限するか |
| --- | --- | --- | --- |
| Full Cone | いいえ | はい | いいえ |
| Restricted Cone | はい | はい | IPのみ |
| Port Restricted Cone | はい | はい | はい |
| Symmetric | はい | いいえ | はい |

#### NAT越しのSIPシグナリングとRTP

NATトラバーサルにおける最大の問題の一つは、SIPシグナリングと音声 (RTP) という2つの問題を解決しなければならないことです。片方向音声の問題のほとんどはNATに関連しています。SIPの興味深い点は、UACがパケットを送信する際、IPアドレスをSIPの「Contact」ヘッダーフィールドに埋め込むことです。通常、これは内部 (RFC1918) アドレスであるため、このパケットへの応答はインターネットを経由してUACに戻るようにルーティングできません。概念的な修正方法は常に同じです：

- **Contact/Viaアドレスを無視し、パケットが実際に来た場所に返信する。** これはRFC 3581 (`rport`) で定義されている動作です。PJSIPでは`force_rport=yes`であり、`rewrite_contact=yes`は保存された連絡先を送信元アドレスに書き換えます。
- **RTPが実際に到着したアドレスにメディアを返信する** (symmetric RTP、歴史的には *comedia* と呼ばれます)。PJSIPでは`rtp_symmetric=yes`です。
- **NATマッピングを維持する。** マッピングがタイムアウトすると、AsteriskはUACにINVITEを送信できなくなります（電話機は発信できますが、着信できません）。定期的にOPTIONS ( *qualify* ) を送信することで、ピンホールを開いたままにします。PJSIPでは、AOR上の`qualify_frequency=`で設定します。

ユーザーのNATがSymmetricタイプの場合、あるUACから別のUACへ直接パケットを送信することは不可能です。その場合は、`direct_media=no`を使用してRTPをAsterisk経由に強制する必要があります。これらの設定はほとんどのケースで適切です。Simple Traversal of UDP over NAT (STUN) やApplication Layer Gateway (ALG) といった高度な技術を使用してトラフィックを最適化することも可能です。STUNはFull Cone、Restricted Cone、Port Restricted Coneで有効です。残念ながら、今日のほとんどのファイアウォール（家庭用DSL/ケーブルルーターでさえ）はSymmetricであり、STUNを使用できません。ALGは問題を解決できる可能性がありますが、ほとんどの場合サポートされていないか、実装されていないか、バグがあります。

#### NAT配下のAsterisk

Asteriskサーバー自体がNAT配下のファイアウォールに配置されることもあります。これはクラウドにデプロイする際によくある状況です。この場合、Asteriskがプライベートアドレスではなく**パブリック**アドレスをSIPおよびSDPヘッダーで通知するように、追加の設定が必要です。

概念的には3つのステップがあります：

- ファイアウォールからAsteriskサーバーへ、SIPシグナリングポート（デフォルトでUDP 5060）を転送する。
- ファイアウォールからAsteriskサーバーへ、RTPメディアポート範囲（デフォルトでUDP 10000–20000、`rtp.conf`で設定）を転送する。
- Asteriskに外部アドレスとローカルネットワークを教え、パブリックアドレスに置き換えるべきタイミングを認識させる。

PJSIPでは、これら後半の2項目は**transport**上の`external_media_address`/`external_signaling_address`および`local_net=`にマッピングされ、RTPポート範囲は引き続き`rtp.conf`で設定されます：

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

NAT配下のAsteriskサーバーに対する完全なPJSIP設定例は、この章の後半の *Asterisk Server behind NAT* で説明します。

### SIPの制限

Asteriskは、着信RTPフローを使用して発信フローを同期します。着信フローが中断されると（無音抑制など）、保留音 (music-on-hold) が途切れます。つまり、Asteriskを使用する場合、電話機やプロバイダー側で無音抑制を使用してはいけません。

## PJSIP: SIPチャネル

PJSIPはAsteriskにおけるSIPチャネルです。Asterisk 12で初めて導入され、長年の開発を経て、現在では標準かつ推奨されるSIPチャネルとなりました。Asterisk 22（現在のLTS）では、唯一のSIPチャネルドライバとなっています。PJSIPはTeluuのプロジェクトであるpjprojectをベースにしています。pjprojectスタックは、多くのsoftphoneや商用SIP実装で採用されており、汎用性が高く成熟したSIPスタックです。

### PJSIPを使用する理由

PJSIPは、AsteriskがSIPを扱う方法をゼロから再設計したものであり、なぜこれが標準となったのか、その機能を理解する価値があります。

#### 機能

このチャネルは多くの機能をサポートしており、その一部をここで紹介します。

- 複数登録: 同じAddress of Recordに対して複数の電話機を接続できます。言い換えれば、1つのendpointに対して2台の電話機を接続することが可能です。
- 使いやすいApplication Program Interface (API): APIはモジュール式で拡張が容易であり、巨大なコードブロックではなく、連携する小さなモジュール群で構成されています。
- 複数トランスポート: PJSIPを使用すると、複数のアドレス、ポート、トランスポートをリッスンできます。すべてのデバイスに対して単一のバインド用アドレスに制限されることはありません。PJSIPは非常に柔軟です。

#### 設定に関する注意点

PJSIPの設定はより冗長です。各デバイスが1つのピアブロックではなく、関連する複数のオブジェクトによって記述されるため、設定には少し手間と行数が必要です。その余分な構造こそがPJSIPの柔軟性を生み出しており、設定ウィザード（後述）を使用することで、日常的なプロビジョニングを短縮できます。

### PJSIPモジュール

PJSIPチャネルは、以下に説明する多くのモジュールによって実装されています。

#### res_pjsip

これはPJSIPのベースレイヤーであり、メインモジュールです。主要なサービスの一部を担っています。

#### res_pjsip_session

このモジュールは、メディアセッション、Session Description Protocolの処理、およびいくつかのアドオンを担当します。

#### res_pjsip_messaging

SIPメッセージを処理し、SIPヘッダーを解析します。

#### res_pjsip_registrar

SIP登録の処理を担当します。

#### res_pjsip_pubsub

subscribe、notify、publishの処理を担当します。これらのメッセージは、SIPプレゼンスおよびBLF (Busy Lamp Field) の処理を担います。

### PJSIP設定

PJSIPには多くの異なるセクションがあります。セクションの形式は以下の通りです。

```
[Section Name]
Option = Value
Option = Value
```

#### Endpointセクション

最も重要な設定オブジェクトはendpointです。endpoint設定にはコア機能が含まれており、AORおよびTransportセクションと関連付ける必要があります。例:

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

上記の例を見るとわかるように、endpointはすべてのセクションを繋ぎ合わせる接着剤のような役割を果たします。トランスポート、Address of Record、および電話機の認証を指定します。また、dialplanにおけるコンテキストの入り口という最も重要な部分も定義します。

#### Address of Record (AOR)

このオブジェクトは、Asteriskに対してendpointへの連絡先を伝えます。連絡先アドレスを保存し、ボイスメールボックスの設定も可能です。例:

```
[softphone]
type=aor
max_contacts=2
```

#### Authentication

このセクションは、インバウンドおよびアウトバウンドの認証を担当します。ドキュメントはサンプルファイルpjsip.confにあります。例:

```
[softphone]
type=auth
auth_type=digest
username=softphone
password=#supersecret#
```

#### Transport

transportセクションでは、IPv4およびIPv6アドレス、およびTCP、UDP、TLS、Websocketsなどのトランスポートプロトコルを定義できます。このセクションでNAT配下のアドレスを設定することも可能です。複数のトランスポートを作成できますが、同じIPとポートを共有することはできず、同じIPバージョンの複数のTCPまたはTLSトランスポートをバインドすることはできません。例:

```
[transport-udp-main]
type=transport
protocol=udp
bind=0.0.0.0:5060
```

#### Registration

このオブジェクトは、アウトバウンド登録を設定するために使用されます。例:

```
[siptrunk]
type=registration
outbound_auth=siptrunk
server_uri=sip:1020@sip.flagonc.com:5600
client_uri=sip:1020@sip.flagonc.com
contact_user=9999
```

#### Identify

このオブジェクトは、どのSIPリクエストがどのendpointに属するかを制御します。identifyセクションがない場合、システムは「From」ヘッダーの内容とendpoint名を照合します。このセクションを使用すると、ユーザー名またはIPによって識別される特定のendpointに、特定のIPアドレスを割り当てることができます。例:

```
[siptrunk]
type=identify
endpoint=siptrunk
match=52.37.87.85
```

#### ACL

ACLオブジェクトを使用すると、endpointへのアクセスを特定のネットワークに設定できます。現在、ACLは特定のセクションまたはacl.confで定義されます。例:

```
[acl]
type=acl
deny=0.0.0.0/0.0.0.0
permit=209.16.236.0
permit=209.16.236.1
```

### エンティティ間の関係

設定オブジェクト間の関係は、設定に大きな柔軟性をもたらします。しかし、初心者には少し複雑に見えるかもしれません。

![PJSIP設定オブジェクト間の関係：endpointはtransport、auth、AOR（連絡先を保持）にリンクし、registrationはtransportとauthに結びつき、identifyはendpointを指し、ACLとdomain aliasは独立している](../images/07-sip-and-pjsip-fig14.png)

上記の図は以下を意味します。

#### 関係性:

| オブジェクト | カーディナリティ |
| --- | --- |
| ENDPOINT / AOR | 多対多 |
| ENDPOINT / AUTH | ゼロ対多、またはゼロ対一 |
| ENDPOINT / IDENTIFY | ゼロ対一 |
| ENDPOINT / TRANSPORT | ゼロ対多、または少なくとも一 |
| REGISTRATION / AUTH | ゼロ対多、またはゼロ対一 |
| REGISTRATION / TRANSPORT | ゼロ対多、または少なくとも一 |
| AOR / CONTACT | 多対多 |

ACLおよびDOMAIN_ALIASは、他のオブジェクトと直接的な設定上の関係を持ちません。

### Softphoneの設定

Softphoneを設定するには、多くの異なるセクションを定義する必要があります。以下にSoftphoneの設定例を示します。クライアント側にはSipPulse Softphone (https://www.sippulse.com/produtos/softphone) を使用でき、これをダウンロードして以下のendpointに対して登録できます。

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

上記の設定では、ポート5060でUDPのトランスポートを設定し、endpointを定義し、ユーザー名とパスワードによる認証を設定し、最大2つの連絡先を持つAddress of Recordを定義しています。

### SIP trunkの設定

SIP trunkを設定するには、SIP trunkのIPアドレスまたはホスト名、名前、パスワードが必要です。この目的のために新しいregistrationセクションを作成する必要があります。

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

### res_pjsipにおけるNATトラバーサル

Network Address Translationは、IPv4アドレスの不足に対処する方法として大昔に作成されました。多くの人は、ネットワークの内部アドレスをパブリックインターネットから隠すセキュリティ機能としてもNATを使用しています。時にはNATトラバーサルを処理しなければならないこともあります。サーバーがクラウドにデプロイされている場合など、サーバー自体がNAT配下にあるケースもあります。クラウドにデプロイする場合、ユーザーもNATルーターの背後にいることがよくあります。整理するために、これを2つのパートに分けます。1つ目はクラウドデプロイのようなNAT配下のAsteriskサーバー、2つ目はres_pjsipを使用してNAT配下のクライアントをサポートする方法です。

#### NAT配下のAsteriskサーバー

AsteriskサーバーがNAT配下にある場合、transportセクションで外部および内部のローカルアドレスを通知する必要があります。以下のディレクティブを使用します。

##### direct_media

メディアはピア間で直接流れるか、サーバーを経由するか？NATの場合、サーバーを経由させる必要があります。NATにはnoを選択してください。例:

```
direct_media=no
```

##### external_media_address

外部RTPを処理するためのメディアアドレス。通常はexternal_signaling_addressと同じです。メディアおよびシグナリングにはサーバーのパブリックIPアドレスを使用してください。例:

```
external_media_address=54.232.1.20
```

##### external_signaling_address

メッセージを受信するための外部SIPアドレス。例:

```
external_signaling_address=54.232.1.20
```

##### local_net

ローカルネットワークとみなすネットワーク。例:

```
local_net=172.16.30.0/24
local_net=127.0.0.1/32
```

#### NAT配下のAsteriskサーバーのトランスポート設定の完全な例

NAT配下のAsteriskサーバーを使用するには、2つのステップが必要です。まず、NAT配下のトランスポートを定義します。次に、このトランスポートをendpointに関連付けます。

##### NAT配下のトランスポートの作成

pjsip.confファイルにNAT配下のトランスポートを作成するには、以下のようなセクションを作成します。

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

トランスポートをendpointに関連付ける

```
[6000]
type=endpoint
transport=tnat
context=from-internal
direct_media=no
auth=6000
aors=6000
```

SIP trunkの場合は、以下のようにトランスポートをregistrationセクションにも関連付ける必要があります。

```
[siptrunk_reg]
type=registration
transport=tnat
server_uri=sip:sip.flagonc.com:5600
outbound_auth=siptrunk_auth
client_uri=sip:23456789@flagonc.com
contact_user=9999
```

#### NAT配下のクライアントでのAsteriskの使用

NAT配下の電話機を使用するには、endpointごとにいくつかの追加パラメータを設定する必要があります。

##### direct_media

メディアはピア間で直接流れるか、サーバーを経由するか？NATの場合、サーバーを経由させる必要があります。例:

```
direct_media=no
```

##### rtp_symmetric

これは「comedia」と呼ばれるものです。SIPで通常行われるようにSDPヘッダーで定義されたアドレスに依存するのではなく、最初のRTPパケットを受信したアドレスを使用し、同じアドレスに返信します。例:

```
rtp_symmetric=yes
```

##### force_rport

これはRFC3581で定義された動作です。VIAヘッダーのアドレスを使用するのではなく、リクエストが来た場所に対してレスポンスを返します。例:

```
force_rport=yes
```

##### qualify_frequency

この設定は（endpointではなく）AORに適用する必要があります。最後のステップとして、qualifyオプションを設定します。NATマッピングを維持するために、常に宛先にpingパケットを送信する必要があります。これはAORセクションで設定します。例:

- qualify_frequency=15

サーバーとクライアントの両方がNAT配下にあるendpointの完全な例

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

### チャネルの命名

いつものように、チャネルの重要な側面の1つはその命名であり、PJSIPには興味深い詳細がいくつかあります。PJSIP endpointには`PJSIP/`テクノロジーを使用してダイヤルします。

```
exten=>6000,1,Dial(PJSIP/6000,20,tT)
```

便利な機能として、AORに登録されているすべての連絡先に一度にダイヤルできる可能性があります。関数PJSIP_DIAL_CONTACTSは、ダイヤルする連絡先のリストに変換されます。

```
exten=>6000,1,Dial(${PJSIP_DIAL_CONTACTS(6000)},20,tT)
```

trunkへのダイヤルは少し異なります。trunkがプラットフォームに登録されない、またはAORに関連付けられたIPアドレスを持たないと仮定します。その場合、行内で直接trunkのアドレスを指定できます。国際電話の例を使用します。

```
exten=>9011.,1,Dial(PJSIP/siptrunk/sip:${EXTEN:1}@sip.flagonc.com)
```

AORセクションでtrunkのアドレスを指定したい場合は、以下も使用できます。

```
exten=>9011.,1,Dial(PJSIP/${EXTEN:1}@siptrunk)
```

### PJSIP設定ウィザード

PJSIPは強力ですが、設定が冗長です。多くの異なるセクションやテンプレートがあり、最初は混乱するかもしれません。良いニュースは、PJSIP設定ウィザードがあることです。各チャネルを数行で定義することで、テンプレートを作成し、新しいデバイスの設定を簡素化できます。設定にはpjsip_wizard.confファイルを使用します。ただし、pjsip.confファイル内でtransportおよびglobalセクションを定義する必要があります。個人的には、ウィザードは電話機のためだけに使用し、SIP trunkは数が多くないため、通常はpjsipで直接設定することをお勧めします。ウィザードの最大の利点は、テンプレートを使用して電話機を素早く作成できることです。

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

### PJSIPのロードとアンロード

PJSIPはAsterisk 22における唯一のSIPチャネルであり、そのモジュールはデフォルトでロードされます。まれに、IAX2やDAHDIのみを使用するサーバーでPJSIPを無効にするなど、modules.confファイルからモジュールのロードを制御したい場合があります。

#### PJSIPを無効にするには

modules.confファイルを編集し、以下の行を追加します。

```
noload => res_pjsip.so
noload => res_pjsip_pubsub.so
noload => res_pjsip_session.so
noload => chan_pjsip.so
noload => res_pjsip_exten_state.so
```

### コンソールコマンド

PJSIP endpointの設定が完了したら、設定を確認する方法を見てみましょう。この作業を助けるコンソールコマンドが多数あります。pjsip.confを編集した後、以下で設定をリロードします。

```
module reload res_pjsip.so
```

単純な`reload`（または`core reload`）は、PJSIPを含むすべてのモジュールをリロードします。（注意：単独の`pjsip reload`コマンドはありません。—`pjsip reload`は`pjsip reload qualify aor|endpoint`という形式でのみ存在します。）利用可能なすべてのPJSIPコンソールコマンドは`help pjsip`で一覧表示できます。

#### pjsip show endpoints

このコマンドは利用可能なendpointを表示します。下の画像はスクリーンショットです。softphone endpointのアドレスを確認でき、利用可能であることがわかります。

![`pjsip show endpoints`の出力。blink、siptrunk、softphoneの各endpointがAOR、auth、transport、可用性とともに表示されている — softphoneの連絡先は登録済み(Avail)](../images/07-sip-and-pjsip-fig15.png)

#### pjsip show endpoint <endpoint>

上記のコマンドで、endpointの各パラメータを確認できます。以下のリストは、現在のパラメータの半分以下に切り詰められています。

![`pjsip show endpoint softphone`の出力。100relやallow=(ulaw)からcallerid、connected_line_methodまで、単一endpointの全パラメータリストが表示されている](../images/07-sip-and-pjsip-fig16.png)

#### pjsip show aors

このコマンドは、設定されたAddress of Recordオブジェクトとその連絡先を一覧表示するため、Asteriskが各endpointに対してどこに呼び出しを送信するかを確認できます。

#### pjsip show registrations

以下のコマンドは、自サーバーによって行われた登録を表示します。

![`pjsip show registrations`の出力：アウトバウンド登録 siptrunk/sip:1020@sip.flagonc.com:5600 が Registered ステータスで表示されている](../images/07-sip-and-pjsip-fig17.png)

#### pjsip list

listコマンドはもう少し親しみやすく、データは少ないですが、より構造化されています。endpointのリスト表示:

![`pjsip list endpoints`の出力：endpointごとのコンパクトな1行リスト（blink, siptrunk, softphone）と、その状態およびチャネル数](../images/07-sip-and-pjsip-fig18.png)

連絡先のリスト表示:

![`pjsip list contacts`の出力。siptrunkおよびsoftphoneの連絡先URIがハッシュとqualifyステータスとともに表示されている](../images/07-sip-and-pjsip-fig19.png)

#### pjsip set logger on

最も便利なトラブルシューティングコマンドはSIPパケットロガーです。すべてのSIPリクエストと応答が送受信されるたびにコンソールに出力されるため、登録や通話設定の問題を診断する際に非常に役立ちます。

```
pjsip set logger on
pjsip set logger off
```

`pjsip set logger host <ip>`を使用して、ログを単一のホストに制限することもできます。

#### pjsip set history on

PJSIPへの素晴らしい追加機能は、履歴の概念です。SIPリクエストと応答をリアルタイムで簡単にキャプチャおよび分析できます。履歴を開始するには、以下のコマンドを使用します。

![`pjsip set history on`を実行すると "PJSIP History enabled" が返される](../images/07-sip-and-pjsip-fig20.png)

これで履歴を表示できます:

![`pjsip show history`の出力：キャプチャされたSIPメッセージ（REGISTER, 401 Unauthorized, REGISTER, 200 OK）の番号付きテーブル。タイムスタンプ、方向、アドレスが表示されている](../images/07-sip-and-pjsip-fig21.png)

次に、特定のリクエストや応答を確認するには、履歴アイテムを表示します:

![`pjsip show history entry`の出力：キャプチャされた単一SIPメッセージの全文 — ここではOPTIONSプローブに対するAsterisk 22の`404 Not Found`応答 — Via（`rport`/`received`付き）、Call-ID、From、To、CSeqヘッダー、`Allow`/`Supported`機能、および`Server: Asterisk PBX 22.10.0`ヘッダーが表示されている](../images/07-sip-and-pjsip-fig22.png)

とても簡単ですよね？`pjsip set history clear`を使用して、いつでも履歴をクリアできます。

> **既存の chan_sip/sip.conf システムからの移行ですか？** レガシーな`chan_sip`ドライバと、完全な **sip.conf → pjsip.conf 移行ガイド**（概念マッピングテーブルと`sip_to_pjsip.py`変換スクリプトを含む）については、「レガシーチャネル」の章で解説しています。

## 概要

SIPは、メディアセッションの確立、変更、および終了を行うためのIETFシグナリングプロトコルです。そのユーザーエージェント、プロキシ、レジストラ、およびゲートウェイは、テキストベースのメッセージ（REGISTER、INVITE、暫定応答および最終応答、ACK、BYE）を交換し、一方でSDPがcodecをネゴシエーションし、RTPがメディアを伝送します。このプロトコルの理論は時代を超越したものであり、あらゆるSIP実装に適用されます。

Asterisk 22では、SIPは`chan_pjsip`（PJSIP）を通じて扱われ、設定は`pjsip.conf`で行われます。単一の巨大なピアではなく、デバイスは相互参照される小さなオブジェクトの集合としてモデル化されます。それらは、`endpoint`（通話動作とcodec）、`auth`（認証情報）、`aor`（到達先）、および`transport`（リスナー）であり、さらにサービスプロバイダー向けには`identify`（IPによるtrunkの照合）と`registration`（アウトバウンドの登録）があります。これらのオブジェクトがどのように組み合わされるか、電話機とtrunkの両方を設定する方法、NATトラバーサルのオプション（`force_rport`、`rewrite_contact`、`rtp_symmetric`、`direct_media`、およびトランスポートの`external_*`/`local_net`）が実際のデプロイメントにおける問題をどのように解決するか、そして`pjsip show endpoints`、`aors`、`contacts`、および`registrations`を使用してそれらすべてをどのように調査するかを学びました。

## クイズ

1. SIPアーキテクチャにおいて、リクエストを受信して新しい場所を伝えるリダイレクト応答（`302 Moved Temporarily`など）を返し、その後のメッセージ経路から外れるコンポーネントはどれですか？
   - A. Proxy server
   - B. Redirect server
   - C. Location server
   - D. Registrar

2. 2台の電話機間のSIP通話を処理する際、Asteriskはどのような役割を果たしますか？
   - A. シグナリング経路のみに留まるSIPプロキシ
   - B. SIPリダイレクトサーバー
   - C. 2つのSIPチャネルをブリッジするバックツーバックユーザーエージェント（B2BUA）
   - D. ステートレスなSIPロードバランサー

3. 電話機が自身の現在のIPアドレスをRegistrarに通知し、後で着信を受け取れるようにするために使用するSIPメソッドはどれですか？
   - A. INVITE
   - B. OPTIONS
   - C. SUBSCRIBE
   - D. REGISTER

4. 正誤問題：Asterisk 22では、PJSIPと並んで`chan_sip`および`sip.conf`がレガシーなフォールバックとして依然として利用可能です。

5. Asteriskが使用するリスニングソケットを認識し、そのデバイスへの通話の送信先を特定するために、endpointをどの設定オブジェクトに関連付ける必要がありますか？（該当するものをすべて選択してください。）
   - A. `type=transport`
   - B. `type=aor`
   - C. `type=identify`
   - D. `type=registration`

6. PJSIPの`aor`オブジェクトにおいて、コンタクトを定期的に確認（qualify）することでNATマッピングを維持する設定はどれですか。また、その単位は何ですか？
   - A. `qualify=yes` (boolean)
   - B. `qualify_frequency` (seconds)
   - C. `rtp_timeout` (milliseconds)
   - D. `nat=force_rport`

7. 空欄を埋めてください：AsteriskがインバウンドのSIPリクエストを（`From`ヘッダーではなく）送信元IPアドレスによって特定のendpointにマッチさせるには、`type=________`を使用してセクションを作成します。

8. AsteriskからSIP trunkプロバイダーへの**アウトバウンド**登録を設定するために使用されるPJSIPオブジェクトはどれですか？
   - A. `type=aor`
   - B. `type=identify`
   - C. `type=registration`
   - D. `type=auth`

9. Asterisk 22のCLIにおいて、すべてのSIPリクエストと応答をコンソールに出力するSIPパケットロガーを有効にするコマンドはどれですか？
   - A. `sip set debug on`
   - B. `pjsip set logger on`
   - C. `pjsip debug on`
   - D. `sip show registry`

10. 対称型NATの背後にある電話機を使用するPJSIP endpointにおいて、Asteriskがリクエストの送信元アドレスに応答し（RFC 3581）、RTPが実際に到着した場所にメディアを送信するようにする設定の組み合わせはどれですか？
    - A. `direct_media=yes` および `srvlookup=yes`
    - B. `force_rport=yes` および `rtp_symmetric=yes`
    - C. `allowguest=yes` および `insecure=invite`
    - D. `qualify=yes` および `nat=no`

**回答:** 1 — B · 2 — C · 3 — D · 4 — False · 5 — A, B · 6 — B · 7 — identify · 8 — C · 9 — B · 10 — B
