# WebRTC with Asterisk

WebRTC (Web Real-Time Communication) を使用すると、Webブラウザでプラグインや外部の softphone を使用することなく、通話の発着信が可能になります。必要なのは JavaScript、マイク、そして Asterisk へのセキュアな接続だけです。Asterisk は Asterisk 11 以降、WebRTC サーバーとして機能することが可能であり、Asterisk 12 で PJSIP スタック (`res_pjsip`) が導入されて以来、それが推奨される方法となっています。Asterisk 22 では、設定は十分に理解されたいくつかのオプションに集約されました。本章では、PJSIP endpoint をブラウザフォンに変える方法、セキュアなメディアパスの仕組み、そして Asterisk の組み込み WebRTC サポートを使用すべき場合と専用のゲートウェイを使用すべき場合について解説します。

本章の内容はすべて、本書の Asterisk 22 ラボ環境で検証済みです。示されている設定は `lab/asterisk/etc` と同一のものです。

## Objectives

この章を読み終えることで、以下のことができるようになります。

- WebRTCがAsteriskに何をもたらすのか、またいつそれを使用すべきかを説明できる
- WebRTCのメディアセキュリティ（DTLS-SRTP）とICEが、通常のSIPとどのように異なるかを説明できる
- AsteriskのHTTPサーバーとセキュアなWebSocket（`wss`）エンドポイントを有効にできる
- `wss` PJSIPトランスポートとWebRTCエンドポイントを`webrtc=yes`で設定できる
- ブラウザベースのsoftphone（SIP.js）を接続し、通話を発信できる
- AsteriskネイティブのWebRTCと、Janusのようなメディアゲートウェイのどちらを選択すべきかを判断できる

## AsteriskにおけるWebRTCの理由

Asteriskの観点から見ると、WebRTCのendpointは、単なるPJSIPのendpointに過ぎません。
変わるのは、ブラウザがどのようにそこに到達するか、そしてメディアがどのように保護されるかという点です。典型的な用途には以下のようなものがあります。

- **Webサイトでのクリック・トゥ・コール** — 訪問者がWebページからキューやextensionに発信します。
- **Webベースのエージェント** — コンタクトセンターのエージェントが完全にブラウザ上で業務を行い、デスクトップのsoftphoneをインストールしたり更新したりする必要がありません。
- **独自のWebアプリケーションへの通話機能の組み込み** — 例えば、Asteriskと通信するSipPulse Web softphoneなどが挙げられます。
- **インストール不要の社内電話** — スタッフがハードウェア電話やインストール型のクライアントの代わりに、ブラウザのタブを使用します。

最大の利点は到達範囲の広さです。現代のすべてのブラウザはすでにWebRTCに対応しています。その代償として、WebRTCは厳格であり、暗号化されたメディアとセキュアなトランスポートが*必須*となるため、通常のUDP SIP電話よりも多くの設定が必要になります。

## WebRTCと通常のSIPの違い

通常のSIP電話はUDP/TCP上でシグナリングを行い、通常はプレーンなRTPとして音声を伝送します。WebRTCブラウザクライアントは、以下の3つの重要な点で異なっており、Asteriskはそれぞれに対応する必要があります。

- **シグナリングはWebSocket上で実行される。** ブラウザはUDPポート 5060 を使用するSIPの代わりに、Asteriskの内蔵HTTPサーバーに対してセキュアなWebSocket（`wss://`）を開きます。SIPメッセージはそのWebSocket内を通過します。
- **メディアは常にDTLS-SRTPで暗号化される。** ブラウザはプレーンなRTPを拒否します。双方はDTLSハンドシェイク（SDP内で交換された証明書のフィンガープリントによって認証される）を実行し、そこからSRTPキーを生成します。
- **接続性はICEでネゴシエーションされる。** 到達可能なIPとポートを前提とするのではなく、双方が候補となるアドレス（ホスト、STUNリフレクティブ、TURNリレー）を収集し、機能するものが見つかるまでプローブを行います。RTPとRTCPは通常、単一のポート（`rtcp_mux`）上で多重化されます。

朗報として、Asterisk 22では、単一のendpointオプションである`webrtc=yes`によって、これらすべてを適切なデフォルト設定で有効にできます。次に、これが具体的に何を設定するのかを見ていきます。

## Step 1 — HTTPサーバーとWebSocket

WebRTCのシグナリングは、Asteriskに組み込まれたHTTPサーバーによって提供されます（`res_http_websocket`は、その上で`/ws`パスを公開します）。ブラウザは*セキュア*なWebSocketを必要とするため、TLSを有効にします。`http.conf`を編集してください：

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

リロード（`module reload res_http_websocket`または再起動）して確認します：

```
*CLI> http show status
HTTP Server Status:
Server: Asterisk/22.10.0
Server Enabled and Bound to 0.0.0.0:8088

HTTPS Server Enabled and Bound to 0.0.0.0:8089

Enabled URI's:
/ws => Asterisk HTTP WebSocket
```

ブラウザは`wss://your-asterisk:8089/ws`に接続します。

### 証明書について

ここでのTLS証明書は、*WebSocket*（シグナリングチャネル）を保護するためのものです。ラボ環境では自己署名証明書で問題ありません。ブラウザで一度許可すればよいためです。本番環境では、ブラウザが接続するホスト名と一致する正規の証明書（Let's Encryptなど）を使用してください。そうしないと、ブラウザがWebSocket接続を拒否します。

ラボ環境の場合、`lab/make-certs.sh`は`CN=localhost`（および`localhost`/`127.0.0.1`のSAN）を使用して自己署名証明書を生成し、`asterisk/etc/keys/`に書き込みます。公開環境へのデプロイでは、代わりに正規の証明書を取得してください。例えばLet's Encryptを使用する場合：

```
certbot certonly --standalone -d voip.example.com
```

次に、`http.conf`を発行されたファイルに向け、`res_http_websocket`をリロードします：

```
tlscertfile=/etc/letsencrypt/live/voip.example.com/fullchain.pem
tlsprivatekey=/etc/letsencrypt/live/voip.example.com/privkey.pem
```

証明書の名前がブラウザの接続先ホストと一致していることを確認し、有効期限が切れる前に更新してください（certbotのタイマーが自動的に行います）。そうしないと、WebSocket接続が失敗します。

この証明書は、メディアを暗号化するために使用されるDTLS証明書とは**別物**です。DTLS証明書は、後述するようにAsteriskが自動的に生成します。

## Step 2 — the WSS transport

PJSIPには `wss` 型のトランスポートが必要です。これを `pjsip.conf` に追加してください：

```
[transport-wss]
type=transport
protocol=wss
bind=0.0.0.0
```

読み込まれたことを確認します：

```
*CLI> pjsip show transports
Transport:  transport-udp             udp      0      0  0.0.0.0:5060
Transport:  transport-wss             wss      0      0  0.0.0.0:5060
```

`wss` トランスポートに対して表示される `0.0.0.0:5060` に惑わされないでください。WebSocketはポート 5060 では提供され**ません**。WebRTCのシグナリングは、Step 1で設定したHTTPサーバー（`wss` の場合はポート 8089）によって提供されます。PJSIPの `wss` トランスポートは `res_http_websocket` 上の薄いシム（shim）であるため、そのために表示される `bind` アドレスは装飾的なものであり無視して構いません。重要なポートは `http.conf` 内の `tlsbindaddr` です。

## Step 3 — the WebRTC endpoint

次に endpoint そのものです。鍵となるのは `webrtc=yes` です：

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

`webrtc=yes` は便利なスイッチです。これは WebRTC に必要なすべてのオプションを手動で設定するのと同等です。何が有効になったのかは、以下で正確に確認できます：

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

その出力を読み解くと：

- `media_encryption: dtls` および `dtls_auto_generate_cert: Yes` — メディアは DTLS-SRTP であり、Asterisk が自動的に DTLS 証明書を生成するため、自分で作成する必要は**ありません**。フィンガープリントは SDP (`SHA-256`) 内でアドバタイズされます。
- `ice_support: true` — Asterisk が ICE candidates を収集し、ネゴシエーションを行います。
- `rtcp_mux: true` — ブラウザの期待通り、RTP と RTCP が 1 つのポートを共有します。
- `use_avpf: true` — WebRTC で必須となる AVPF RTP プロファイル (フィードバック) です。

`allow=opus` が推奨されます。Opus はブラウザが優先する codec です。Asterisk 22 には Opus の *passthrough* 機能がコア (`res_format_attr_opus` モジュール) に含まれており、再エンコードなしで Opus 対応の 2 つのレグ間で Opus を中継するのに十分です。Opus を別の codec に *トランスコーディング* するには、別途 `codec_opus` モジュールが必要です。これは公式の WebRTC ガイドではオプションとされていますが、強く推奨されており、ベースビルドに追加でインストールします。*Designing a VoIP network* の codecs に関する議論を参照してください。Opus を話せない非 WebRTC レグへのブリッジ用フォールバックとして、`ulaw` を保持しておいてください。

## Step 4 — ICE, STUN and TURN

フラットなLAN環境であれば、ホスト候補を用いたICEだけで十分であり、他に何も必要ありません。インターネットを介する場合、通常はSTUNサーバーを追加してAsteriskとブラウザが自身のパブリックアドレスを検出できるようにし、さらに直接的なメディア通信が不可能な場合（対称型NATや制限の厳しいファイアウォール環境）に備えてTURNサーバーを追加します。これらを`rtp.conf`でAsteriskに指定します。

```
[general]
icesupport=yes
stunaddr=stun.l.google.com:19302
; turnaddr=turn.example.com:3478
; turnusername=...
; turnpassword=...
```

ブラウザ側は、JavaScript（`RTCPeerConnection`の`iceServers`リスト）で独自のICEサーバーを設定します。完全に内部向けのデプロイメントであれば、STUN/TURNを完全にスキップすることも可能です。

`turnaddr`はオプションのポート（デフォルトは`3478`）を受け取ります。`turnusername`と`turnpassword`はリレーへの認証に使用されます。STUNはピアが自身のパブリックアドレスを*検出*するのを助けるだけです。両端が対称型NATや制限の厳しいファイアウォールの背後に存在する場合、直接的なメディア通信は不可能であり、音声を通すためにはTURNリレーが唯一の手段となります。

**本番環境への推奨事項:** アドレス検出には公開されているSTUNサーバー（Googleのものなど）で問題ありませんが、実際のトラフィックに公開TURNサーバーを**使用しないでください**。TURNはすべてのメディアを中継するため、自身の管理下にあるサーバーを使用する必要があります。独自の[coturn](https://github.com/coturn/coturn)サーバーを運用してください。長期認証情報を使用した最小限の`/etc/turnserver.conf`は以下のようになります。

```
listening-port=3478
fingerprint
lt-cred-mech
user=asterisk:Strong-TURN-secret
realm=voip.example.com
external-ip=203.0.113.10
```

次に、`rtp.conf`でAsteriskにそのサーバーを指定します。

```
[general]
icesupport=yes
stunaddr=stun.l.google.com:19302
turnaddr=turn.example.com:3478
turnusername=asterisk
turnpassword=Strong-TURN-secret
```

両方のレグでリレーができるように、ブラウザの`iceServers`リストにも同じTURNサーバーを指定してください。モバイルネットワークや企業のファイアウォールの背後にいるユーザーを抱える本番環境では、セルフホスト型のcoturnの導入が事実上必須となります。

## Step 5 — ブラウザクライアント

WebRTC SIPライブラリであればどれでも動作しますが、広く使われているものとして **SIP.js** と **JsSIP** があります。このラボには、最小限のSIP.js softphoneが`lab/webrtc/index.html`に含まれています。重要な部分は、トランスポートURLと認証情報です。

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

ブラウザに関して覚えておくべき2つの現実があります。

- **セキュアコンテキスト。** `getUserMedia`（マイクへのアクセス）は、`https://`ページまたは`http://localhost`でのみ動作します。本番環境では、HTTPS経由でページを配信してください。
- **証明書を一度承認する。** 自己署名のラボ用証明書を使用する場合、まず同じブラウザで`https://your-asterisk:8089/ws`にアクセスして警告を承認してください。そうしないと、WebSocketが警告なしに失敗します。

SipPulseウェブsoftphoneは、これらと同じプリミティブに基づいて構築された、本番環境グレードのリファレンスクライアントです。

## WebRTCコールの検証

ブラウザが登録されると、`pjsip show contacts`に動的なコンタクトが表示され、コールによってチャネルがアクティブになります。

```
*CLI> pjsip show contacts
  Contact:  webrtc-1000/sip:webrtc-1000@... NonQual Avail
*CLI> core show channels
PJSIP/webrtc-1000-00000001  internal  600  Up  Echo
```

音声が片方向である、または聞こえない場合は、ほぼ間違いなくICEまたは証明書の問題です。以下のトラブルシューティングを参照してください。

## Asterisk WebRTCとメディアゲートウェイの比較

AsteriskはWebRTCを直接終端できますが、常にそれが最適なツールであるとは限りません。

- **AsteriskネイティブのWebRTCを使用する場合**: ブラウザがPBX上の*電話機*として機能するケースです。エージェント、内線extension、dialplanに接続するクリック・トゥ・コールなどがこれに該当します。ブラウザは単なる別のendpointとして扱われ、すべての機能（キュー、voicemail、IVR）がそのまま利用可能です。
- **専用ゲートウェイ（例: Janus）を使用する場合**: 通話制御とは独立して多数のブラウザセッションをスケーリングする必要がある場合や、大規模な会議やストリーミングのために選択的な転送を行う場合、あるいはメディアプレーンをPBXから分離しておきたい場合に適しています。ゲートウェイはWebRTCを通常のSIPにブリッジし、Asterisk側からは通常のSIPレグとして認識されます。

多くの実運用システムでは、Asteriskによる通話制御と、ブラウザ側のメディアスケーリングのためのゲートウェイを組み合わせています。（これはSipPulse独自のスタックの背後にあるアーキテクチャです。）

## トラブルシューティング

- **WebSocketが接続できない:** ブラウザがTLS証明書を拒否しました。直接 `https://host:8089/ws` を開き、証明書を承認するか、信頼された証明書をインストールしてください。
- **登録はできるが音声が聞こえない:** ICEが失敗しました。STUNを追加し、NAT越えの場合はTURNを追加してください。 `pjsip set logger on` を確認し、SDP候補を調べてください。
- **片方向音声:** 通常は片側のNAT/ICEの問題、または共通の codec が一致しないことが原因です。 `allow=opus,ulaw` を確認してください。
- **応答時に通話が切断される:** DTLSハンドシェイクが失敗しました。 `dtls_auto_generate_cert` が `Yes` であること、およびシステム時刻が正しいこと（証明書は時間に依存します）を確認してください。

## 実習

1. `./lab.sh up`を実行し、続いて`bash lab/make-certs.sh`を実行してから Asterisk を再起動します。
2. `lab/webrtc/index.html`（`lab/webrtc`から`python3 -m http.server`）を配信して開き、`https://localhost:8089/ws`で証明書を承認します。
3. `webrtc-1000`として登録し、`600`（エコーテスト）に発信します。自分の声が聞こえるはずです。
4. `6001`として登録された SipPulse Softphone から`1000`にダイヤルし、ブラウザを呼び出します。
5. ネゴシエーションを調査します。`pjsip set logger on`を実行して通話を発信し、SDP 内の DTLS フィンガープリントと ICE 候補を確認してください。

## 概要

WebRTCは、ブラウザをAsteriskのファーストクラスのendpointへと変貌させます。その手順は小規模ですが厳格です。ブラウザがセキュアなWebSocketを開けるようにTLSを有効にしたHTTPサーバーを構築し、PJSIPのtransportを`wss`に追加し、endpointに`webrtc=yes`を設定します。これにより、DTLS-SRTP（自動生成された証明書を使用）、ICE、RTP/RTCP多重化、およびAVPFプロファイルが有効になります。NATを越える場合はSTUN/TURNを追加し、ページをHTTPS経由で提供し、SIP.js（またはJsSIP）クライアントを`wss://asterisk:8089/ws`に向けます。PBX上のブラウザフォンについては、AsteriskネイティブのWebRTCが最もシンプルな経路となります。大規模なメディアを扱う場合は、ゲートウェイと組み合わせてください。

## クイズ

1. WebRTCブラウザクライアントは、AsteriskへのSIPシグナリングを運ぶためにどのトランスポートを使用しますか？
   - A. ポート 5060 でのプレーンな UDP
   - B. AsteriskのHTTPサーバーへのセキュアな WebSocket (`wss://`)
   - C. ポート 5061 での TLS
   - D. ポート 8088 での生の TCP ソケット

2. ブラウザとAsterisk間のWebRTCメディアは、どのメカニズムを使用して暗号化されますか？
   - A. SDES-SRTP (SDP内で交換される鍵)
   - B. DTLS-SRTP (DTLSハンドシェイクから導出される鍵)
   - C. IPsec
   - D. プレーンな RTP — WebRTCはメディアを暗号化しない

3. 正か誤か：`webrtc=yes`を設定する場合、メディアの暗号化に使用されるDTLS証明書を手動で生成およびインストールする必要があります。

4. ラボのAsterisk HTTPサーバーは、WebRTC用の**セキュアな** WebSocketをどのポートで公開していますか？
   - A. 5060
   - B. 5061
   - C. 8088
   - D. 8089

5. `webrtc=yes`はデフォルトで以下のどれを有効にしますか？（該当するものをすべて選択してください。）
   - A. `media_encryption: dtls`
   - B. `ice_support: true`
   - C. `rtcp_mux: true`
   - D. `use_avpf: true`
   - E. `transport: transport-udp`

6. 空欄を埋めてください：WebRTCは、両側で候補アドレス（ホスト、STUNリフレクティブ、TURNリレー）を収集およびプローブすることで接続性をネゴシエーションします。これには ________ フレームワークを使用します。

7. `rtp.conf`において、Asteriskがパブリックアドレスを検出し、直接パスが失敗したときにメディアをリレーできるように外部サーバーを指定する設定はどれですか？（該当するものをすべて選択してください。）
   - A. `icesupport=yes`
   - B. `stunaddr=`
   - C. `turnaddr=`
   - D. `tlsbindaddr=`

8. Asteriskの`res_http_websocket`がWebRTCシグナリングのために公開するURLパスは ________ です。

9. 本章によると、AsteriskネイティブのWebRTCではなく、専用のメディアゲートウェイ（Janusなど）を使用すべきなのはどのような場合ですか？
   - A. ブラウザが通話を行う必要があるときはいつでも
   - B. 通話制御とは独立して多数のブラウザメディアセッションをスケーリングする必要がある場合、大規模会議のために選択的転送を行う場合、またはメディアプレーンをPBXから分離しておく必要がある場合
   - C. ブラウザがDTLSをサポートしていない場合のみ
   - D. ブラウザのendpointでvoicemailやIVRを動作させたい場合

10. 正か誤か：`getUserMedia`（マイクへのアクセス）はどの`http://`ページでも動作するため、ブラウザのsoftphoneをHTTPS経由で提供することは任意です。

**回答:** 1 — B · 2 — B · 3 — 誤 (Asteriskは自動的にDTLS証明書を生成します; `dtls_auto_generate_cert: Yes`) · 4 — D · 5 — A, B, C, D · 6 — ICE · 7 — B, C · 8 — `/ws` · 9 — B · 10 — 誤 (セキュアなコンテキストが必要です: `getUserMedia`は`https://`または`http://localhost`でのみ動作します)
