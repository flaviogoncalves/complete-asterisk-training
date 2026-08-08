# SIP trunking, DID & the PSTN

自分自身としか通話できないPBXは、あまり役に立ちません。遅かれ早かれ、すべてのシステムは外部の世界、つまり公衆交換電話網（PSTN）、SIPプロバイダー、あるいは別のPBXと接続する必要があります。それらの通話を運ぶリンクを**trunk**と呼びます。TDM時代において、trunkとは物理的な回線、すなわちT1/E1 PRIやアナログFXO回線の束のことでした。今日では、それはほぼ例外なく**SIP trunk**、つまり他のあらゆる通信と同じIPネットワーク上で運ばれる、インターネット電話サービスプロバイダー（ITSP）への論理的な接続を指します。

本章では、PJSIPを使用してAsterisk 22をITSPに接続する方法、登録ベースのtrunkとIPベースのtrunkのどちらを選択すべきか、着信したDID番号を適切な宛先にルーティングする方法、正しいcaller-IDとE.164形式で発信する方法、そして複数のtrunkをまたいでフェイルオーバーや最小コストルーティングを構築する方法を解説します。最後に、trunkにおけるNATの取り扱いと、2台目のAsterisk（およびSIPp）を模擬ITSPとして立ち上げ、実際にtrunkを介して通話を行うラボを実施します。

ここに記載されている内容はすべて、本書のAsterisk 22.10.0ラボ環境で検証済みです。trunkオブジェクトのパターンは、『Building your first PBX with PJSIP』および『SIP & PJSIP in depth』で紹介したものと同じです。

## Objectives

この章を読み終えることで、以下のことができるようになります。

- PJSIPを使用して Asterisk 22 を ITSP に接続する
- レジストレーションベースのトランクと IP ベース（固定）のトランクを選択する
- 着信した DID を適切な extension、IVR、またはキューにルーティングする
- 発信者番号と E.164 フォーマットを適切に設定して外線通話をルーティングする
- `${DIALSTATUS}`を使用してトランクのフェイルオーバーと最小コストルーティングを構築する
- トランスポートおよび endpoint におけるトランクの NAT を処理する

## SIP trunkとは何か

SIP trunkとは、あなたのPBXと別のSIPシステムとの間の論理的な音声パスのことです。実際には、その「別のシステム」は以下の2つのいずれかです。

- **ITSP (Internet Telephony Service Provider)。** 通話の発着信サービスや、通常は電話番号のブロック（DID）を販売する商用キャリアです。Asteriskをプロバイダーのシグナリングホストに向けることで、プロバイダーがあなたの通話を広範なPSTNへと接続します。これが、現代のシステムのほとんどが電話網に接続する方法であり、電話用ハードウェアは不要です。
- **PSTN gateway。** 物理的なPSTNインターフェース（PRIカード、アナログFXOポート、またはGSM/4G gatewayなど）を持ち、それらをSIPとしてあなたのPBXに提示するデバイス（または別のAsterisk）です。gatewayがTDMからSIPへの変換を行い、Asteriskの観点からは、それは単なる別のSIP trunkとして扱われます。

いずれの場合も、PJSIPにおいてtrunkは**単なるendpoint**です。電話機に使用したものと同じオブジェクトファミリー（`endpoint`、`auth`、`aor`、オプションで`identify`および`registration`）がtrunkを構築します。違いは詳細部分にあります。trunkは*アウトバウンド*で認証を行います（あなたがクライアントであるため、資格情報は`outbound_auth`に入力し、`auth`ではありません）。また、通常はユーザーエージェントをあなたに対して登録させることはありません（あなたが*相手*に登録するか、相手が既知のIPからトラフィックを送信してきます）。そして、インバウンドの通話は`from-internal`ではなく`from-pstn`のような専用のcontextに着信します。

> **従来のTDM trunkとの比較。** PRIでは固定数のB-channel（T1で23、E1で30）が提供され、専用のD-channel上で通話設定のシグナリングが行われていました（*Legacy channels*の章を参照）。SIP trunkには固定のチャンネル数はなく、容量は帯域幅、プロバイダーのポリシー、および任意の`max_contacts`/同時通話制限によって決まります。かつてISDNの情報要素で伝送されていたCaller-ID、DID、および通話進行状況は、現在ではSIPヘッダーとSDPで伝送されます。

ITSPがあなたとトラフィックを交換する方法には2通りあり、それによってtrunkの構築方法が決まります。それは**登録ベース（registration-based）**と**IPベース（static）**です。それぞれについて順に説明します。

## Registration-based trunks

Registration-based trunk（登録ベースのトランク）は、プロバイダーが*あなた*からのログインを待機している場合に使用されるモデルです。Asteriskは定期的にSIP `REGISTER`をプロバイダーへ送信し、ユーザー名とパスワードで認証を行います。これは、電話機がPBXに登録するのと全く同じ仕組みです。このモデルは、パブリックIPが動的である場合、NATの背後にいる場合、あるいはプロバイダーがIPアドレスではなくSIP認証情報によって顧客を識別する場合に一般的です。

PJSIPでは、アウトバウンドのログイン情報は専用の `registration` オブジェクトに保持されます。これは、廃止された `chan_sip` ドライバーが `sip.conf` で使用していた単一の `register =>` 行を置き換えるものです。以下に、本書の以前の章で検証されたパターンに従った、架空のプロバイダーへの完全な登録トランクの設定例を示します。なお、endpointにおける `outbound_auth` （`auth` ではない）、`server_uri`/`client_uri` （`server`/`client` ではない）、`from_user`/`from_domain` 、および `dtmf_mode=rfc4733` に注意してください。

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

いくつか注意すべき点があります：

- **`auth_type=digest` （`userpass` ではない）。** どちらも同じダイジェスト認証を生成しますが、Asterisk 22では `userpass` （および古い `md5`）は **非推奨となり、警告なしで `digest` に変換されます**。新しい設定では `digest` を使用することを推奨します。古いファイルや本書の以前の章では、依然として `userpass` が見られるはずです。
- **endpointとregistrationの両方における `outbound_auth`。** registrationはこれを使用して `REGISTER` を認証し、endpointはこれを使用してプロバイダーがアウトバウンドの `INVITE` に対して送り返してくる `407 Proxy Authentication Required` に応答します。これらは一つの `auth` オブジェクトを共有できます。
- **`from_user` / `from_domain`。** 多くのプロバイダーは、その `From` ヘッダーにアカウント番号とプロバイダーのドメインが含まれていない通話を拒否します。これら2つのオプションは、まさにその値を設定するものです。
- **`contact_user=4830001000`。** これは登録する `Contact` のユーザー部分となるため、プロバイダーはどの番号に着信を配信すべきかを認識できます。これは、古い `register =>` 行における `/9999` サフィックスの現代的な代替手段です。
- **`retry_interval=60`。** 登録に失敗した場合、60秒ごとに再試行します。

リロード後、 `pjsip show registrations` で登録状況を確認します。ラボ環境（`itsp.example.com` が実際には応答しない環境）では、テーブルは以下のようになります：

```
*CLI> pjsip show registrations

 <Registration/ServerURI..............................>  <Auth....................>  <Status.......>
==========================================================================================

 itsp-reg/sip:itsp.example.com:5060                      itsp-auth                   Rejected          (exp. 56s)

Objects found: 1
```

`(exp. Ns)` サフィックスは、次の試行までの秒数をカウントダウンします。ゼロになると、再試行が実行される直前に一時的に `(exp. Ns ago)` と表示されます。実際のプロバイダーに対しては、 `Status` カラムに次のリフレッシュまでの残り秒数が `Registered` と表示されます。 `Rejected` （または `Unregistered`）は、プロバイダーがログインを受け入れなかったことを意味します。 `pjsip set logger on` を有効にして `401`/`403` の応答を確認してください。ほとんどの場合、ユーザー名、パスワード、または `client_uri` ドメインの誤りが原因です。

## IPベース（静的）トランク

2番目のモデルでは、登録は一切不要です。プロバイダーはあなたのパブリックIPアドレスを把握しており、そこに直接通話を送信します。あなたも同様に、プロバイダーの既知のシグナリングIPへ通話を送信します。認証はSIP認証情報ではなく、**送信元IPアドレス**によって行われます。これは、自身で管理する2つのサーバー間のトランクや、両端が静的アドレスを持つ企業向けトランクで一般的です。

重要なオブジェクトは `identify` です。これはAsteriskに対して「*この*IPから到着するSIPリクエストはすべて*あの*endpointに属する」と伝えます。これがない場合、PJSIPはインバウンドリクエストを `From` ユーザーによってendpointにマッチさせようとしますが、キャリアのトラフィックはこれを満たさないため、通話は拒否されるか、あるいは `anonymous` endpointにフォールバックしてしまいます。

静的トランクでは `registration` オブジェクトを削除し、 `identify` を追加します。

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

`match` はIPアドレス、CIDR範囲、またはホスト名を受け入れます。**ホスト名は設定読み込み時に一度だけ解決される**ため、プロバイダーのIPが変更された場合はリロードが必要です。複数のメディアゲートウェイを公開しているキャリアの場合、各シグナリングIPをリストアップします。 `match` を繰り返すか、CIDRを指定することができます。

```
[itsp-identify]
type=identify
endpoint=itsp
match=203.0.113.10
match=203.0.113.11
match=198.51.100.0/24
```

Asteriskが何を受け入れるかは `pjsip show identifies` で確認してください。ラボからキャプチャした結果です（ `sipp-identify` 行はラボの既存のSIPp endpointです）。

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

### セキュリティへの影響

認証のないIPベースのトランクはドアのようなものであり、 `identify` / `match` が唯一の鍵となります。もし `match` を広範囲に設定しすぎた場合、あるいは攻撃者が送信元IPを偽装できた場合、通話は認証なしであなたの `from-pstn` contextに着信してしまいます。以下の2つの防御策を併用してください。

- **可能な限り限定的にマッチさせる。** 広範なCIDRよりも特定のホストIPを優先してください。プロバイダーの実際のシグナリングIPのみを `match` に含めるべきです。
- **ACLと組み合わせる。** PJSIPは、 `type=acl` オブジェクト（または `acl.conf` ）を使用することで、トラフィックがendpointに到達する前にSIP層で破棄できます。

```
[itsp-acl]
type=acl
deny=0.0.0.0/0.0.0.0
permit=203.0.113.10
permit=203.0.113.11
```

`type=acl` セクションは参照を必要としません。 `res_pjsip_acl` は、すべてのインバウンドSIPトラフィックがendpointに到達する前に、そのようなすべてのオブジェクトを適用します。（オブジェクト上の `acl` および `contact_acl` オプションは、上記のように `permit` / `deny` をインラインでリストする代わりに、 `acl.conf` から名前付きルールリストを取得します。）原則はSIPの章と同じです。すべてを拒否し、信頼できるものだけを許可してください。また、トランクのcontextが何をするにしても、**意図的かつ認証されたルールなしでPSTNへ発信できるcontextに到達させないでください**。それが典型的な国際電話詐欺の入り口となります。

> **どちらのモデルを使うべきか？** プロバイダーがユーザー名とパスワードを提供している場合は、**登録（registration）**トランクを使用してください。プロバイダーがあなたのIPアドレスを要求し、彼らのIPアドレスを提示してきた場合は、**識別（identify）**トランクを使用してください。一部のプロバイダーは両方をサポートしています。多くの実際のトランクでは、登録（プロバイダーがあなたを見つけられるようにするため）と識別（プロバイダーのメディアゲートウェイからのインバウンドINVITEが、レジストラ以外のIPから到着した場合でもマッチするようにするため）を組み合わせています。

## インバウンドルーティングとDIDの処理

インバウンドコールが到着すると、その呼び出しはendpointの`context`に着信します。ここで`from-pstn`が行われます。**DID**（Direct Inward Dialing number：ダイヤルイン番号）とは、プロバイダーがリクエストURIで渡してくるダイヤルされた番号のことです。dialplanにおけるあなたの役割は、各DIDを特定の宛先（単一のextension、IVR、キュー、またはリンググループ）にマッピングすることです。

プロバイダーから送られてくる番号は、`from-pstn`内の`${EXTEN}`としてマッチングされます。どの程度まで番号が見えるかはプロバイダーによって異なります。完全なE.164番号（`+4830001000`）を送るプロバイダーもあれば、国内番号を送るプロバイダー、あるいは末尾の数桁のみを送るプロバイダーもあります。パターンを記述する前に、`pjsip set logger on`を使用して実際のインバウンドコールを調査し、リクエストURIを確認してください。

### 1つのDIDを1つのextensionへ

最も単純なケースとして、1つのDIDを直接電話機にルーティングする場合です：

```
[from-pstn]
exten => 4830001000,1,NoOp(Inbound DID: ${EXTEN} from ${CALLERID(num)})
 same =>             n,Dial(PJSIP/6001,30,tT)
 same =>             n,Hangup()
```

### 1つのDIDをIVR（自動応答）へ

電話機を鳴らすのではなく、メニューで応答すべき代表番号の場合：

```
[from-pstn]
exten => 4830001000,1,Answer()
 same =>             n,Wait(1)
 same =>             n,Goto(ivr-main,s,1)
```

`ivr-main`は、dialplanの章で構築した自動応答用contextです（`Background()` + `WaitExten()`）。DIDのルーティングは単なる`Goto`です。

### 1つのDIDをキューへ

コールキューに着信させるべきサポート回線の場合：

```
[from-pstn]
exten => 4830002000,1,Answer()
 same =>             n,Queue(support,t,,,300)
 same =>             n,Hangup()
```

### 複数のDIDを一度に処理する

番号ブロックを購入した場合、パターンを使用することでdialplanを簡潔に保てます。DIDの範囲が`4830003000`～`4830003099`で、プロバイダーが完全な番号を送ってくるものと仮定します。各DIDの末尾2桁をextension`60xx`にマッピングします：

```
[from-pstn]
exten => _48300030XX,1,NoOp(DID ${EXTEN} -> extension 60${EXTEN:-2})
 same =>             n,Dial(PJSIP/60${EXTEN:-2},30,tT)
 same =>             n,Hangup()
```

`${EXTEN:-2}`は末尾2桁を取得します（負のオフセットは右からカウントされます）。そのため、`4830003007`は`PJSIP/6007`を呼び出します。`GoSub`やAsteriskデータベース（`AstDB`/`func_odbc`）を使用して構築された`did => extension`ルックアップテーブルはさらに拡張性がありますが、少数の番号であれば明示的なパターンが最も明確です。

> **マッチしないDIDの捕捉。** `from-pstn`に`i`（無効）extensionを追加することで、ルーティングが外れたインバウンド番号に対して、無音で切断する代わりにアナウンスを流したり、オペレーターを呼び出したりすることができます：
>
> ```
> exten => i,1,Playback(ss-noservice)
>  same =>  n,Hangup()
> ```

## アウトバウンドルーティング、発信者番号、および E.164

アウトバウンド通話は逆方向に流れます。内線電話が番号をダイヤルすると、dialplanがそれを照合し、アクセスプレフィックスを取り除き、プロバイダーが期待する発信者番号を設定し、その通話を `Dial(PJSIP/<number>@itsp)` を使用してtrunkのendpointへ渡します。

### trunkへの通話の送信

trunkのチャネル構文は `PJSIP/<number>@<endpoint>` です。 `@` より前の部分はアウトバウンドリクエストURIのユーザー部分となり、 `@` より後の部分は、その `aor` `contact` が宛先ホストを提供するendpointを指名します。典型的な「外線発信のために9をダイヤルする」ルールは以下の通りです。

```
[from-internal]
exten => _9NXXXXXXXXX,1,NoOp(Outbound to ${EXTEN:1} via itsp)
 same =>             n,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp,60,tT)
 same =>             n,Hangup()
```

`${EXTEN:1}` は、番号が送信される前に先頭の `9` アクセスコードを取り除きます。パターン `_9NXXXXXXXXX` は、 `9` に続く10桁の番号（最初の桁は2〜9）に一致します。これを自身のdialplanに合わせて調整してください。

### アウトバウンド通話の発信者番号

ほとんどのITSPは、所有していない番号の発信者番号を無視するか、積極的に拒否します。アウトバウンドの発信者番号は、上記のように `Dial()` の前に `CALLERID(num)` 関数を使用して、所有するDIDのいずれかに設定してください。名前を設定することも可能です。

```
 same => n,Set(CALLERID(num)=4830001000)
 same => n,Set(CALLERID(name)=ACME Corp)
```

プロバイダーが依然として発信者番号の名前を取り除いたり上書きしたりする場合、それは彼らのポリシーです。多くの通信事業者は、表示名をあなたの `From` ヘッダーからではなく、番号をキーとした独自のCNAMデータベースから取得しています。

これに関連するendpointオプションが2つあります。

- **`from_user`** は、SIPレベルで `From` ヘッダーのユーザー部分を設定します。一部のプロバイダーは、 `CALLERID(num)` に関係なくこれを使用してアカウントを識別します。
- **`trust_id_outbound`** （デフォルトは `no`）は、Asteriskがプライバシーに配慮した識別ヘッダー（`P-Asserted-Identity`/`P-Preferred-Identity`）をアウトバウンドで送信するかどうかを制御します。プロバイダーがPAIを要求していると明記していない限りオフのままにしてください。要求されている場合は、 `trust_id_outbound=yes` および `send_pai=yes` を設定します。

### E.164への正規化

E.164は国際電話番号形式であり、先頭の `+`、国番号、その後に国内番号が続き、スペースや句読点は含まれません（例： `+5548999990000` や `+14155550100`）。通信事業者は、trunk上でE.164形式を期待する、あるいは要求することが増えています。フォーマットの処理をdialplan全体に散らばらせるのではなく、アウトバウンドのcontextで一度だけ正規化を行うようにします。

10桁の市内番号、11桁の `1` で始まる番号、またはすでにE.164形式になっている番号を受け入れ、常に `+1…` をtrunkに提示する北米の例を以下に示します。

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

`+` を要求するプロバイダーもあれば、数字のみを要求するプロバイダーもあります。もしプロバイダーが `+` を拒否する場合は、 `Dial` 内の `${EXTEN:1}` を使用して送信時にそれを取り除いてください。重要なのは、フォーマットに関するすべての知識を一箇所に集約しておくことであり、そうすればプロバイダーの切り替えや追加を行う際も、1行の変更で済むようになります。

## フェイルオーバーと最小コストルーティング

トランクが1つしかない場合、プロバイダーの障害は発信不能を意味します。2つ以上あれば、自動的にフェイルオーバーを行い、宛先ごとに最も安価なルートを選択する*最小コストルーティング*（LCR）さえ可能になります。

### `${DIALSTATUS}`によるフェイルオーバー

`Dial()`は、戻り値として`${DIALSTATUS}`チャネル変数を設定します。フェイルオーバーにおいて考慮すべき値は、`CHANUNAVAIL`（トランクに全く到達できなかった場合）と`CONGESTION`（呼び出しが拒否された場合、例：全回線使用中）です。まずプライマリトランクを試し、もし通話が確立できなかった場合はバックアップへフォールスルーさせます。

```
[from-internal]
exten => _9NXXXXXXXXX,1,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp_primary,60,tT)
 same =>             n,NoOp(Primary returned ${DIALSTATUS})
 same =>             n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?backup:done)
 same =>             n(backup),Dial(PJSIP/${EXTEN:1}@itsp_backup,60,tT)
 same =>             n(done),Hangup()
```

`BUSY`や`NOANSWER`ではフェイルオーバーを行わないという意図的な選択に注意してください。これらは*呼び出し先*に到達したが拒否されたことを意味するため、別のトランクで再試行すると、すでに拒否した電話を再び鳴らすことになり（2回目の通話料金が発生する可能性もあります）、不適切です。*トランク自体*が失敗した場合のみ、再ルーティングを行ってください。

### 再利用可能なルーティングサブルーチン

すべてのダイヤルパターンに対してそのロジックを繰り返すと、エラーが発生しやすくなります。これを`GoSub`ルーチンにまとめ、宛先番号を受け取って各トランクを順番に試すようにします。

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

これで、すべての発信パターンは1回の`GoSub`呼び出しで済み、トランクの順序は一箇所で定義されるようになります。

### 宛先による最小コストルーティング

真のLCRは、通話の行き先に基づいてトランクを選択します。一般的な構成は、宛先のプレフィックスを照合し、それぞれの通話クラスを最も安価なプロバイダーへ送信することです。例えば、国際電話は卸売キャリアへ、市内/国内通話はプライマリトランクへ送信するといった具合です。

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

プレフィックスが多数ある場合は、ルートテーブルをデータベース（`func_odbc`/`AstDB`）に保存し、パターンをハードコーディングする代わりにプレフィックスでトランクを検索するようにします。これにより、dialplanは簡潔に保たれ、料金設定はロジックをリロードすることなく編集可能なテーブル内に保持されます。

## NATとtrunk

NATは、trunkの問題を引き起こす最も一般的な原因です。典型的な症状としては、片方向音声や、登録はできるが着信が一切できないといった問題が挙げられます。原因は電話機の場合（*SIP & PJSIP in depth*および*Designing a VoIP network*で解説）と同じです。AsteriskはSIPやSDPの中で自身のIPアドレスを通知しますが、NAT配下にある場合、それはプロバイダーがルーティングできないプライベートな RFC 1918 アドレスになってしまうためです。

trunkの場合、修正には2つのパートがあります。**transport**の設定（自身のパブリックアドレス）と、**endpoint**の設定（プロバイダーのメディアをどのように扱うか）です。

### transportの設定 — 自身のパブリックアドレス

Asteriskサーバー自体がNAT配下にある場合（プライベートIPを持ち、1:1のパブリックIPが割り当てられたクラウドやオンプレミスのボックス）、transportに対してそのパブリックアドレスと、どのネットワークがローカルであるかを伝える必要があります。これらのオプションは`transport`で一度設定すれば、その上を通るすべてのトラフィックに適用されます。

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

- **`external_signaling_address`** — Asteriskが`local_net`の外側の宛先に対して、SIPヘッダー（`Via`、`Contact`）に書き込むパブリックIP。
- **`external_media_address`** — RTPが正しい場所に戻るように、AsteriskがSDPの`c=`行に書き込むパブリックIP。通常はシグナリング用のアドレスと同じです。
- **`local_net`** — Asteriskが内部ネットワークとして扱うネットワーク。LAN内のピアに対してアドレスの書き換えを行わないようにします。内部サブネットをすべてリストしてください。

### endpointの設定 — プロバイダーのメディア

もう半分は、プロバイダー自体がNAT配下にある場合や、単にSDPに記載されたアドレスとは異なるアドレスからメディアを送信してくる場合への対応です。これらはtrunkのendpointごとに設定します。

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

- **`direct_media=no`** — 2つのレグを直接通信させるのではなく、Asteriskを経由してメディアを流し続けます。NATを越える場合には不可欠であり、通話の録音、トランスコード、監視を行う場合にも必須となります。
- **`rtp_symmetric=yes`** — 古典的な*comedia*の動作です。SDPが主張するアドレスではなく、実際にメディアが送信されてきたアドレスに対してRTPを返信します。
- **`force_rport=yes`** — `Via`ヘッダーを信頼する代わりに、リクエストの送信元IP/ポート（RFC 3581）に対してSIPで応答します。
- **`rewrite_contact=yes`** — このendpointからの着信SIPメッセージに対して、`Contact`ヘッダー（または適切な`Record-Route`ヘッダー）を、パケットが実際に到達した送信元IPアドレスとポートに書き換えます。このオプションのドキュメントによれば、これは「NAT配下のendpointとの通信を助け」、「TCPやTLSのような信頼性の高いトランスポート接続の再利用を助ける」ものです。

> **推奨事項 — 電話機とtrunkの違い。** `rewrite_contact`は、電話機にとってはほぼ常に正しい選択です。なぜなら、電話機が通知する連絡先は通常、ルーティング不可能なプライベートな RFC 1918 アドレスだからです。固定IPベースのtrunkでは、プロバイダーの連絡先は通常すでに正しいパブリックアドレスであるため、書き換えは不要な場合が多いです。一部の通信事業者は、固定trunkではこの設定をオフにし、登録型のtrunkやNAT配下の電話機に対してのみ有効にすることを推奨しています。このオプションの文書化された効果は、上記の着信時の`Contact`/`Record-Route`の書き換えのみです。したがって、安全な運用としては、固定trunkで有効にする前に、特定の通信事業者でテストを行うことを推奨します。

任意のendpointにおける有効な設定は、以下のコマンドで確認できます。
`pjsip show endpoint <name>` — `direct_media`、`rtp_symmetric`、`force_rport`、
`rewrite_contact`、およびその他のパラメータがすべてダンプ出力されます。

## Lab — 2台目の Asterisk と SIPp を使用した模擬 ITSP

練習のために有料の trunk を用意する必要はありません。この本のラボ環境では、すでに Asterisk 22.10.0 コンテナと SIPp コンテナがプライベートな `172.30.0.0/24` ネットワーク上で動作しています。SIPp コンテナをインバウンド通話を発信する「キャリア」として扱い、その通話を `from-pstn` context に着信させる trunk endpoint を追加します。

![Asterisk PBX と ITSP 間の SIP trunk: PBX は 1 つのアカウントとして登録し、アウトバウンド通話は `PJSIP/<num>@trunk` にダイヤルし、インバウンド通話は `from-pstn` context に着信します。](images/trunk-lab.png){width=100%}(../images/09-sip-trunking-fig01.png)

### 1. trunk endpoint の追加

ラボの SIPp ホストと一致し、インバウンド通話を `from-pstn` に着信させる IP ベースの trunk を `lab/asterisk/etc/pjsip.conf` に追加します。

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

### 2. インバウンド DID のルーティング

`lab/asterisk/etc/extensions.conf` に、模擬キャリアがダイヤルする DID に応答して音声を再生する `from-pstn` context を追加し、アウトバウンドルールを追加します。

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

両方のファイルをリロードし（`core reload`）、trunk が読み込まれたことを確認します。

```
*CLI> pjsip show endpoint itsp
 Endpoint:  itsp                                                 Not in use    0 of inf
        Aor:  itsp-aor                                           0
      Contact:  itsp-aor/sip:172.30.0.50:5060              ...        NonQual         nan
   Identify:  itsp-identify/itsp
        Match: 172.30.0.50/32
```

### 3. trunk を経由したインバウンド通話の発信

DID をターゲットユーザーとして、SIPp シナリオを PBX に向けます。ラボ環境にはすでに `lab/sipp/uac_9000.xml` が同梱されており、extension `9000` に対して INVITE を送信します。これを `uac_did.xml` にコピーし、request-URI/`To` ユーザーを `9000` から `4830001000` に変更してから、SIPp コンテナから実行します。

```
docker compose -f lab/docker-compose.yml exec -T sipp \
  sipp -sf /sipp/uac_did.xml 172.30.0.10:5060 -m 1 -nostdin
```

Asterisk コンソールで通話が `from-pstn` に到達する様子を監視します（`pjsip set logger on` はインバウンドの INVITE を示し、`core show channels` は `PJSIP/itsp-…` チャネルが `demo-congrats` を再生していることを示します）。SIPp の送信元 IP が `identify` と一致するため、認証なしで通話が受け入れられます。これは、静的なキャリア trunk の動作そのものです。

### 4. trunk の調査

記録用に trunk の完全な設定をキャプチャします。

```
pjsip show endpoint itsp
pjsip show aors
pjsip show identifies
```

### 5. (発展課題) 登録型 trunk への変更

*2台目* の Asterisk コンテナを実際のレジストラとして立ち上げます。アカウント `4830001000` 用に `endpoint`+`auth`+`aor` を設定し、PBX 側で `identify` ブロックを本章の冒頭にある `registration` ブロックに入れ替えます（`server_uri` を 2 台目のコンテナの IP に向けます）。`pjsip show registrations` でステータスが `Registered` と表示されることを確認し、双方向に通話を発信してください。

## 概要

SIP trunkはPBXを外部世界と接続するものであり、PJSIPにおいては、すでに習得済みの `endpoint` + `auth` + `aor` ファミリーに `identify` または `registration` を加えた単なる endpoint に過ぎません。プロバイダーからユーザー名とパスワードが提供される場合は **registration trunk** (`type=registration` と `outbound_auth`) を使用し、ソースIPによって認証を行う場合は **IP-based trunk** (`type=identify` と `match`) を使用します。後者の場合は、認証のない trunk は国際電話詐欺の標的となるため、厳格な `match` と `acl` で保護してください。着信時、プロバイダーからの DID は `from-pstn` context 内の `${EXTEN}` として到着します。そこで extension、IVR、またはキューへとルーティングします。パターンや `${EXTEN:-N}` を使用することで、DID ブロックを簡潔に管理できます。発信時は、所有する番号を `CALLERID(num)` に設定し、一箇所で E.164 形式に正規化してから、呼び出しを `PJSIP/<number>@trunk` に渡します。複数の trunk を試行し、 `${DIALSTATUS}` に基づいて分岐させることで耐障害性を構築します（`CHANUNAVAIL`/`CONGESTION` は再ルーティングを意味し、`BUSY`/`NOANSWER` はそうではありません）。また、最小コストルーティングは `GoSub` テーブルに配置してください。最後に、trunk における NAT は双方向の対応が必要です。パブリックアドレスに対しては **transport** 上で `external_media_address`/`external_signaling_address`/`local_net` を設定し、プロバイダーのメディアに対しては **endpoint** 上で `direct_media=no`、 `rtp_symmetric`、 `force_rport`、 および `rewrite_contact` を設定します。

## クイズ

1. PJSIPにおいて、プロバイダーへの*アウトバウンド*コールや登録を認証するために使用される認証情報は、以下で参照されます：
   - A. `auth=`
   - B. `outbound_auth=`
   - C. `secret=`
   - D. `remotesecret=`
2. `type=registration`トランクを使用すべきなのは、どのような場合ですか：
   - A. プロバイダーが送信元IPアドレスであなたを識別する場合。
   - B. プロバイダーがユーザー名とパスワードを提供し、ログインを要求する場合。
   - C. Asteriskに`REGISTER`を送信させたくない場合。
   - D. トランクが、あなたが管理する2つの静的IPサーバー間にある場合。
3. `identify`オブジェクトの`match`オプションは、以下を受け入れます（該当するものをすべて選択してください）：
   - A. IPアドレス
   - B. CIDR範囲
   - C. ホスト名（設定読み込み時に解決されるもの）
   - D. SIPユーザー名のみ
4. Asterisk 22において、`auth_type=userpass`は：
   - A. 唯一の有効な値である
   - B. 非推奨となり、`digest`に変換される
   - C. 削除されており、読み込みエラーを引き起こす
   - D. アウトバウンド登録に必須である
5. インバウンドのDID番号は、dialplanにおいて以下として到着します：
   - A. `${CALLERID(num)}`
   - B. トランクendpointの`context`における`${EXTEN}`
   - C. `${DIALSTATUS}`
   - D. `${CONTEXT}`
6. ダイヤルされたDID`4830003007`の下2桁をextensionに送信するには、以下を使用します：
   - A. `${EXTEN:2}`
   - B. `${EXTEN:0:2}`
   - C. `${EXTEN:-2}`
   - D. `${EXTEN:8}`
7. トランクへの`Dial()`の後、どの`${DIALSTATUS}`値を持つバックアップトランクにフェイルオーバーすべきですか（2つ選択してください）：
   - A. `CHANUNAVAIL`
   - B. `BUSY`
   - C. `CONGESTION`
   - D. `NOANSWER`
8. 発信前にプロバイダーに提示する発信者ID番号を設定するには、以下を使用します：
   - A. `Set(CALLERID(num)=4830001000)`
   - B. `Set(from_user=4830001000)`
   - C. `Set(DIALSTATUS=4830001000)`
   - D. `Set(CONNECTEDLINE(num)=4830001000)`
9. サーバーがNATの背後にある場合に、Asteriskに対してその*パブリック*アドレスを通知するオプションは、どこで設定されますか：
   - A. `endpoint`
   - B. `aor`
   - C. `transport` (`external_media_address` / `external_signaling_address`)
   - D. `registration`
10. トランクendpoint上の`rtp_symmetric=yes`は、Asteriskに何を行わせますか：
    - A. SRTPでRTPを暗号化する
    - B. SDPを無視し、メディアが実際に到着したアドレスにRTPを返送する
    - C. RTPを完全に無効化する
    - D. endpoint間でダイレクトメディアを強制する

**回答:** 1 — B · 2 — B · 3 — A, B, C · 4 — B · 5 — B · 6 — C · 7 — A, C · 8 — A · 9 — C · 10 — B
