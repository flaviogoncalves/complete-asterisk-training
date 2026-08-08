# chan_sip から PJSIP への移行：クックブック

もしあなたが Asterisk 13、16、または 18 を現在本番環境で運用しているなら、期限が迫っています。`chan_sip` — `sip.conf` を通じて設定されるオリジナルの SIP チャネルドライバ — は、**Asterisk 17 で非推奨となり、Asterisk 19 ではデフォルトビルドから除外され、Asterisk 21 では完全に削除されました**。Asterisk 22 LTS には存在しません。これを有効に戻すフラグも、回避するための `noload` も、インストール可能なパッケージもありません。Asterisk 22 における唯一の SIP チャネルドライバは **PJSIP** (`res_pjsip` および `chan_pjsip`) であり、これは `pjsip.conf` を通じて設定されます。

したがって、ほとんどのサイトにとって Asterisk 22 へのアップグレードは、単なるバージョンアップであると同時に、*SIP 移行プロジェクト*でもあります。幸いなことに、ネットワーク上のプロトコル自体は変更されません。昨日登録して通話できた電話機は、明日も登録して通話できます。また、Asterisk には翻訳作業の最初の 80% を自動化する変換ツールが同梱されています。本章は実践的なクックブックです。概念のマッピング、変換スクリプト、実際に遭遇するケースに対応した `sip.conf` → `pjsip.conf` の並列翻訳、移行に伴う dialplan や CLI の変更、realtime (データベース) の移行、そしてチェックリストと陥りやすい落とし穴について解説します。

ここに記載されている内容はすべて、本書の Asterisk 22.10.0 ラボ環境で検証済みです。`chan_sip` 自体に関する詳細なレガシー資料や、マルチデバイス `sip.conf` のエンドツーエンドの変換作業については *Legacy channels* の章に記載されています。本章は、その内容を補完する、レシピ形式の集中ガイドです。

## Objectives

この章を読み終えることで、以下のことができるようになります。

- Asterisk 22でなぜ `chan_sip` が廃止されたのか、そして何に置き換わるのかを説明する
- `sip.conf` のpeer/user/friendモデルをPJSIPのオブジェクトモデル（endpoint + aor + auth + identify + transport + registration）にマッピングする
- `sip_to_pjsip.py` 変換スクリプトを実行し、その出力を批判的にレビューする
- 一般的なデバイスタイプ（登録型電話機、インバウンドtrunk、アウトバウンド登録）を `sip.conf` から `pjsip.conf` へ手動で変換する
- NAT、メディア、DTMF、codec、認証設定をオプションごとに移行する
- dialplan（`SIP/` → `PJSIP/`）およびCLI（`sip show` → `pjsip show`）を更新する
- realtime/ARAのデプロイメントを `sippeers`/`sipregs` からSorcery `ps_*` テーブルへ移行する
- 移行チェックリストに従って作業を進め、典型的な落とし穴を回避する

## なぜ移行する必要があるのか

`chan_sip`は20年近くにわたりAsteriskを支えてきましたが、アーキテクチャ上の負債を抱えていました。それは、モノリシックなモジュール、デバイスごとに1つの設定ブロック、弱いマルチトランスポートサポート、そしてRFCに追いつけなくなったSIPスタックです。**PJSIP**は、Teluuの成熟したpjprojectスタックを基盤として構築され、Asterisk 12で導入された、ゼロから作り直された代替品です。Asterisk 21までに、Asteriskプロジェクトはその作業を完了し、ツリーから`chan_sip`を削除しました。

Asterisk 22のシステムであれば、以下のコマンドで状況を確認できます。

```
*CLI> module show like chan_sip
Module                         Description              Use Count  Status      Support Level
0 modules loaded

*CLI> module show like chan_pjsip
Module                         Description              Use Count  Status      Support Level
chan_pjsip.so                  PJSIP Channel Driver     0          Running     core
1 modules loaded
```

`chan_sip`を実行すると *0 modules loaded* と返されます。つまり、そこにはもう存在しないのです。PJSIP以外への移行先は存在しないため、唯一の現実的な問いは「移行するかどうか」ではなく「どのように移行するか」です。

## 概念的なマッピング：単一の「ピア」は存在しない

`sip.conf`から移行する際に誰もがつまずく思考の転換点はこれです。**PJSIPには`[peer]`が存在しません。** `sip.conf`では、角括弧で囲まれた1つのブロック（`peer`、`user`、または`friend`）が、デバイスに関するすべて（認証情報、接続先、codec、NATの挙動、dialplanのcontextなど）を記述していました。PJSIPでは、その単一のブロックを意図的に分割し、それぞれが`type=`でタグ付けされた、単一目的の小さなオブジェクト群にしています。これらは*名前によって相互に参照*し合います。

| PJSIPオブジェクト（`type=`） | 役割 |
| --- | --- |
| `endpoint` | デバイスの通話処理におけるアイデンティティ：codec、context、DTMF、メディア、NAT、および`auth`/`aors`/`transport`への参照 |
| `aor` (Address of Record) | デバイスへの*到達先*：登録済みまたは静的な連絡先、`max_contacts`、qualify設定 |
| `auth` | インバウンドおよび/またはアウトバウンド認証のための認証情報（ユーザー名/パスワード） |
| `identify` | インバウンドリクエストを`From`ユーザーではなく**送信元IP**によってendpointにマッチングさせる |
| `transport` | リッスンするソケット：プロトコル、バインドするアドレス/ポート、NAT/外部アドレス |
| `registration` | Asteriskからプロバイダーへの**アウトバウンド**REGISTER |

`friend`/`peer`/`user`という区別は完全に消滅しました。PJSIPではすべてが`endpoint`です。したがって、単一の`sip.conf` friendは、通常、名前を共有し互いを指し示す3つのオブジェクト（`endpoint` + `auth` + `aor`）になります。

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

endpointは接着剤のような役割を果たします。これは`transport`（またはデフォルトを継承）と`auth`オブジェクト、そして1つ以上の`aors`を指定します。このオブジェクトモデルについては『*SIP & PJSIP in depth*』で詳しく解説されていますが、ここではすべての変換のターゲットとして理解しておけば十分です。

## `sip_to_pjsip.py`変換ツール

Asteriskには、既存の`sip.conf`を読み込み、`pjsip.conf`を書き出すPythonスクリプトが同梱されています。これはCLIコマンドとして実行するものではなく、インストールされたバイナリではなく**Asteriskソースツリー**内に存在します：

```
${ASTERISK_SRC}/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py
```

ラボのAsterisk 22.10.0では、フルパスは例えば`/usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py`となります。同じディレクトリには`sip_to_pjsql.py`（後述するrealtime/SQLバリアント）や、ヘルパーモジュールの`astconfigparser.py`、`astdicts.py`、`sqlconfigparser.py`も格納されています。

### 実行方法

このスクリプトはオプションの位置引数`[input-file [output-file]]`をとります。デフォルトではカレントディレクトリの`sip.conf`と`pjsip.conf`が使用されます：

```
cd /etc/asterisk
python /usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py \
       sip.conf pjsip_generated.conf
```

主なオプションは以下の通りです：

```
-h, --help              show usage
-p, --prefix PREFIX     output prefix for include files (default: pjsip_)
-q, --quiet             don't print messages to stdout
```

入力ファイルを読み込み、`Converting to PJSIP...`を出力し、出力ファイルを書き出します。内部的にはすべての`sip.conf`セクションを走査し、デバイスごとに対応する`endpoint`、`auth`、`aor`、`registration`、および（推論可能な場合は）`transport`オブジェクトを生成し、次節で説明するオプションのマッピングを自動的に適用します。

### 実行内容と制限事項

出力されたファイルは**完成品ではなく、初稿**として扱ってください。このスクリプトは自身の限界を明確にしており、きれいにマッピングできなかったものはすべて、出力ファイルの先頭にある明確に区切られたブロックに書き出されます：

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

この実際の断片を見ると、`sip.conf`ピアの`qualify = yes`が*非マッピング*ブロックに配置されていることがわかります。これは、PJSIPでは`qualify_frequency`（秒）を**aor**で修飾するためであり、デバイス上のブール値ではないため、スクリプトはユーザーが意図的に設定するように残しています。計画時に考慮すべき実用上の制限は以下の通りです：

- **トランスポートは設計ではなく推測される。** スクリプトは`bindport`/`bindaddr`から基本的な`transport-udp`を出力しますが、TLS証明書、TCPの要件、マルチバインドのレイアウトまでは把握できません。トランスポートを確認し、書き直してください。
- **NATと外部アドレスには人間の判断が必要。** `externaddr`/`localnet`はきれいに移行できない可能性があるため、トランスポート上の`external_media_address`、`external_signaling_address`、`local_net`を手動で確認してください。
- **`qualify`、カスタムタイマー、およびいくつかのオプションは「非マッピング」ブロックに配置される。** そのブロックを上から下まで読み、それぞれについて判断を下してください。
- **コーデックリスト、context、セキュリティにはレビューが必要。** `disallow`/`allow`、dialplanの`context`を確認し、意図せずデバイスが開放されたままになっていないことを検証してください。

したがって、ワークフローは次のようになります：スクリプトを実行して*スクラッチ*ファイルを作成し、diffをとってレビューし、適切な部分を実際の`pjsip.conf`に統合してから、本番環境の前に徹底的にテストしてください。

## Side-by-side translations

これらはレシピです。左側に`sip.conf`、右側に検証済みの`pjsip.conf`相当の記述を配置しています（ページ幅の都合上、ここでは上下に並べています）。右側のすべてのオプション名と値は、Asterisk 22のラボ環境にて`config show help res_pjsip ...`を使用して確認済みです。

### レジストレーションを行う電話機（`host=dynamic`）

最も一般的なデバイスです。シークレットを使用してログインし、自身の場所を登録するデスクフォンやsoftphoneのことです。

**レガシーな`sip.conf`:**

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

**Asterisk 22の`pjsip.conf`:**

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

重要な変更点：`host=dynamic`は`max_contacts`を持つ`aor`になります（デバイスがREGISTERして連絡先を埋めます）。`secret=`は`type=auth`内の`password=`になります。`qualify=yes`はendpointではなく**aor**上の`qualify_frequency=60`（秒単位）になります。`max_contacts`を1より大きく設定するのは、同じアカウントを複数のデバイスで同時に使用したい場合のみにしてください。

### インバウンドトランク（`host=<ip>` / `type=peer`）

既知のIPアドレスから通話を発信してくるプロバイダーです。ここでは登録は行われません。代わりに`identify`を使用して、*キャリアのトラフィックを送信元IPで*認証します。

**レガシーな`sip.conf`:**

```
[itsp-in]
type=peer
host=203.0.113.10
context=from-pstn
disallow=all
allow=ulaw
insecure=invite
```

**Asterisk 22の`pjsip.conf`:**

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

重要な変換は **`insecure=invite` → `identify`** です。`chan_sip`では、`insecure=invite`がAsteriskに対して「このピアからのインバウンドINVITEに対して認証を要求するな」と指示していました。PJSIPでは、`type=identify`/`match=`を使用して*送信元IPをendpointに照合する*ことで同じ効果を実現します。これはより明確であり、かつ安全です。静的な`host=`は`aor`上の永続的な`contact=`となるため、キャリアに対して*発信*することも可能になります。`match=`はIPアドレス、CIDR範囲、またはホスト名（設定読み込み時に解決されます。プロバイダーのIPが変更された場合はリロードしてください）を受け付けます。

### アウトバウンドレジストレーション（`register =>`）

プロバイダーが*あなた*にログインを要求する場合、`chan_sip`では`[general]`内の単一の`register =>`行を使用していました。PJSIPでは、これを専用の`type=registration`オブジェクトと`outbound_auth`に置き換えます。

**レガシーな`sip.conf`:**

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

**Asterisk 22の`pjsip.conf`:**

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

`register =>`フィールドを1対1でマッピングします。`1020:supersecret`の認証情報は`auth`オブジェクト（`outbound_auth`として参照）になり、`@sip.example.com:5600`は`server_uri`になります。`/9999`のサフィックス（プロバイダーがインバウンド通話を配信する際のユーザー部分）は`contact_user=9999`になります。`defaultuser`/`fromuser`および`fromdomain`は、endpoint上の`from_user`および`from_domain`になります。`outbound_auth`は*2回*登場することに注意してください。レジストレーションはREGISTERのためにこれを使用し、endpointはアウトバウンドINVITEに対する`407`チャレンジに応答するためにこれを使用します。

## オプションごとの移行リファレンス

手動で移行を行う場合（またはスクリプトの出力を監査する場合）、この表を参照してください。すべての PJSIP オプション名と配置場所（endpoint / aor / auth / transport）は、Asterisk 22 のラボ環境で検証済みです。

| Legacy `sip.conf` | Asterisk 22 `pjsip.conf` | 配置場所 |
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

### `secret` → `auth` および `auth_type` に関する注記

`chan_sip`の `secret=` は、ある `type=auth` オブジェクトの `password=` フィールドになります。**認証メソッド**は `auth_type` で設定します。必ず `auth_type=digest` を使用してください。古い値である `userpass` や `md5` も引き続き動作しますが、**非推奨であり、自動的に `digest` へと変換されます**。これはラボ環境で直接検証済みです。

```
*CLI> config show help res_pjsip auth auth_type
...
 The older 'md5' and 'userpass' values are deprecated and converted to 'digest'.
    userpass - Deprecated.  Use 'digest'.
    md5 - Deprecated.  Use 'digest'.
    digest - If selected, the 'password' ... parameters must be provided.
```

古い設定ファイルや変換スクリプトの出力（および本書の以前の章）には `auth_type=userpass` が見られるはずです。これ自体に害はありませんが、新規の設定には `digest` を記述するようにしてください。

### NAT、メディア、DTMFの詳細

これら3つの項目は、移行後に「登録はできるが音声が聞こえない」という問い合わせが発生する最も一般的な原因です。`chan_sip` の省略形である `nat=force_rport,comedia` は、3つの動作を1つのオプションに詰め込んでいました。PJSIP ではこれらが分割されているため、それぞれについて個別に検討できます。

```
; sip.conf:  nat=force_rport,comedia
; pjsip.conf (on the endpoint):
force_rport=yes        ; reply to the source IP/port of the request (RFC 3581)
rewrite_contact=yes    ; rewrite the stored Contact to the real source address
rtp_symmetric=yes      ; send RTP back where it actually came from (comedia)
```

**メディア**に関しては、 `directmedia` が `direct_media` になります（アンダースコアが変更点のすべてです）。通話を Asterisk でアンカーする必要がある場合（NAT を越える場合や、録音・トランスコード・転送を行う場合）は、常に `direct_media=no` を維持してください。**DTMF** に関しては、RFC の番号が付け直されました。すなわち、 `chan_sip` の `dtmfmode=rfc2833` は PJSIP では `dtmf_mode=rfc4733` となります（帯域外 telephone-event メカニズムは同じで、現在の RFC 番号に基づいています）。ラボでの検証により、有効な `dtmf_mode` の値は `rfc4733`、 `inband`、 `info`、 `auto`、 および `auto_info` であり、デフォルトは `rfc4733` であることが確認されています。

**codec** に関しては、変更はありません。 `disallow=all` に続く `allow=ulaw` （など）は、PJSIP endpoint においても同一の構文を使用します。

## Dialplan and CLI changes

移行は`pjsip.conf`だけで終わるわけではありません。日常的に使用する2つの要素が変更されます。

### Channel strings: `SIP/` → `PJSIP/`

古いテクノロジーを指定していた`extensions.conf`内のすべての`Dial()`およびチャネル参照は、更新する必要があります。

```
; Before (chan_sip)
exten => 2000,1,Dial(SIP/2000,30,tT)

; After (chan_pjsip)
exten => 2000,1,Dial(PJSIP/2000,30,tT)
```

Trunkのdial stringも同様のパターンに従い、`Dial(SIP/${EXTEN}@itsp)`は`Dial(PJSIP/${EXTEN}@itsp)`になります。また、PJSIPでは、AORにバインドされたすべてのコンタクトを同時に呼び出すための`PJSIP_DIAL_CONTACTS()`関数や、`PJSIP_HEADER()` / `PJSIP_MEDIA_OFFER()` dialplan関数が追加されています。dialplanに対して`SIP/`、`SIPPEER`、`SIPCHANINFO`、および`CHANNEL(...)`のSIP参照をgrepで検索し、それぞれを変換してください。

### CLI: `sip show ...` → `pjsip show ...`

ドライバの廃止に伴い、すべての`sip ...`コマンドツリーが削除されました。代替コマンドは以下の通りです。

| `chan_sip` command | Asterisk 22 (`chan_pjsip`) |
| --- | --- |
| `sip show peers` | `pjsip show endpoints` |
| `sip show peer <name>` | `pjsip show endpoint <name>` |
| `sip show registry` | `pjsip show registrations` |
| `sip show channels` | `core show channels` (or `pjsip show channels`) |
| `sip set debug on` | `pjsip set logger on` |
| `sip reload` | `module reload res_pjsip.so` (or `core reload`) |

古いコマンドは動作が異なるだけでなく、存在しなくなりました。ラボ環境において、`sip show peers`を実行すると *No such command* が返されますが、`pjsip show endpoints`、`pjsip show aors`、`pjsip show auths`、`pjsip show contacts`、`pjsip show registrations`、および`pjsip show identifies`はすべて利用可能です。最も有用なトラブルシューティングコマンドである、すべてのメッセージを`sip set debug`で出力していたSIPパケットロガーは、現在では **`pjsip set logger on`** となっています（特定のピアに絞る場合は `pjsip set logger host <ip>` を使用します）。

## Realtime (ARA) 移行

もしデータベース（Asterisk Realtime Architecture）から `chan_sip` を実行していた場合、デバイスは `sippeers` テーブルに、レジストレーションは `sipregs` に格納されていました。PJSIP は、**Sorcery** という全く異なるストレージ層を使用しており、*オブジェクトタイプごとに1つのテーブル*が割り当てられます。マッピングは以下の通りです。

| `chan_sip` realtime table | PJSIP / Sorcery table(s) |
| --- | --- |
| `sippeers` | `ps_endpoints`, `ps_aors`, `ps_auths` (それぞれ1行ずつに分割) |
| `sipregs` | `ps_contacts` (動的レジストレーション) |
| — (outbound `register=>`) | `ps_registrations` |
| — (IP matching) | `ps_endpoint_id_ips` (`identify` オブジェクト) |
| — (domain aliases) | `ps_domain_aliases` |

概念的な分割はフラットファイルの場合と同じです。1つの `sippeers` 行が、エンドポイント名で相互参照される3つのテーブル（`ps_endpoints` + `ps_aors` + `ps_auths`）の *3行* になります。

この作業を容易にする要素が2つあります。

- **スキーマは自動生成されます。** Asterisk には `contrib/ast-db-manage/` 配下に Alembic マイグレーションが同梱されており、これによって必要な `ps_*` テーブルがすべて作成されます。DDL を手書きする代わりに、`config` データベースに対して `alembic upgrade head` を実行し、現在の PJSIP スキーマを構築してください。
- **SQL 変換スクリプトが用意されています。** `sip_to_pjsip.py` と同じ `contrib/scripts/sip_to_pjsip/` ディレクトリには **`sip_to_pjsql.py`** が存在します。これは同じ `convert()` ロジックを再利用しますが、フラットな設定ファイルの代わりに `ps_*` テーブル用の `INSERT` ステートメントを含む `pjsip.sql` ファイルを出力します。フラットファイル用ツールと同様に、読み込む前に出力を確認してください。

最後に、PJSIP が `ps_*` テーブルから（`res_config_odbc` / `res_pjsip_realtime` を経由して）endpoint、aor、auth、contact を読み込めるように `sorcery.conf` をデータベースに向けます。これはかつて `extconfig.conf` が `chan_sip` のために `sippeers` をデータベースに向けていたのと全く同じです。Realtime の仕組みについては *Realtime* の章で解説されています。移行における重要なポイントは、単に「どのテーブルがどれに対応するか」という点です。

## 移行チェックリスト

本番環境への切り替えにおける実用的な作業手順は以下の通りです。

1. **インベントリの作成。** すべてのデバイス、trunk、および `register =>` を `sip.conf` （またはすべての `sippeers`/`sipregs` 行）にリストアップします。カスタムの NAT、codec、DTMF 設定を記録してください。
2. **コンバーターを実行し、スクラッチファイルに出力する。**
   `sip_to_pjsip.py sip.conf pjsip_generated.conf`。本番環境の `pjsip.conf` に対して直接実行しては**いけません**。
3. **「Non mapped elements」ブロックを読む。** 出力ファイルの先頭にあるこのブロックを確認し、すべての行を解決してください。特に `qualify`、タイマー、および NAT 関連の項目は重要です。
4. **トランスポートを手動で設計する。** IP/ポートごとに1つのトランスポートを割り当てます。必要に応じて TLS/TCP を追加し、クラウドや NAT 環境のボックス向けに `external_*_address` および `local_net` を設定します。
5. **認証の検証。** すべての `auth` オブジェクトにおいて、 `auth_type=digest`、ユーザー名、パスワードを確認します。
6. **NAT/メディア/DTMF の検証。** 必要に応じて、endpoint ごとに `force_rport`/`rewrite_contact`/`rtp_symmetric`、 `direct_media`、 `dtmf_mode=rfc4733` を設定します。
7. **dialplan の更新。** すべての箇所で `SIP/` を `PJSIP/` に変更します。また、 `SIP*` 関数とチャネル変数をチェックしてください。
8. **スクリプトと監視の更新。** `sip show ...` の出力を解析していたツールや AMI コンシューマーは、すべて `pjsip show ...` または PJSIP AMI アクションへ移行する必要があります。
9. **リロードと検証。** `module reload res_pjsip.so` を実行した後、 `pjsip show endpoints`、 `pjsip show registrations`、 `pjsip show identifies` を確認します。
10. **パケットロガーによるテスト。** `pjsip set logger on` を使用します。レジストレーション、インバウンド通話、アウトバウンド通話をそれぞれ実行し、SIP のやり取りをエンドツーエンドで読み取ります。

## よくある落とし穴

- **`alwaysauthreject` は現在組み込み済みです — 探す必要はありません。** `chan_sip` は、不正なユーザー名に対して異なる応答を返すことでどの extension が存在するかを漏洩させないために `alwaysauthreject=yes` を必要としていました。PJSIP は設計上セキュアであり、endpoint が存在するかどうかを一切明かしません。設定すべき `alwaysauthreject` オプションは存在しません。関連する保護機能である「未確認の送信者のスロットリング」は、グローバルな `unidentified_request_count` / `unidentified_request_period` であり、デフォルトで有効になっています。

- **`insecure=invite` は PJSIP のオプションではありません — `identify` を使用してください。** `pjsip.conf` には `insecure=` は存在しません。既知のキャリアからの認証されていない INVITE を受け入れる方法は、ソース IP によって endpoint を識別することです。これには `type=identify` / `match=` を使用します。可能な限り限定的にマッチさせ（広範な CIDR ではなく特定のホスト IP）、`type=acl` で保護してください。認証なしの IP マッチングされた trunk は、国際電話詐欺の標的となります。

- **IP/ポートごとに 1 つのトランスポート。** 同じ IP:ポートに 2 つのトランスポートをバインドすることはできません。また、同じ IP バージョンの複数の TCP または TLS トランスポートをバインドすることもできません。変換スクリプトが既存のトランスポートと競合するトランスポートを出力する可能性があるため、意図的に設計された単一のトランスポート層に統合してください。

- **`qualify=yes` はブール値に変換されません。** これは **aor** の `qualify_frequency=<seconds>` に属します。コンバーターが `qualify=yes` を非マッピングブロックに配置するのは、まさに endpoint 上に同等のブール値が存在しないためです。

- **`secret=` は endpoint のオプションではありません。** 資格情報は、endpoint が参照する `type=auth` オブジェクト内にのみ存在します（インバウンドには `auth=`、アウトバウンドには `outbound_auth=`）。endpoint にパスワードを設定しても何も起こりません。

- **CLI およびスクレイピングスクリプトは警告なしに失敗します。** `sip show ...` は「No such command」を返しますが、これは監視システムが必ずしもエラーとして検知できるとは限りません。切り替え前に、すべての cron ジョブ、Nagios チェック、および AMI クライアントで `sip ` コマンドを監査してください。

## 概要

Asterisk 22 への移行は、すなわち `chan_sip` からの脱却を意味します。これは、Asterisk 21 で当該ドライバが削除され、SIPチャネルとして PJSIP のみが残されたためです。作業の核心は、すべてを1つのブロックに詰め込んでいた各 `sip.conf` の `peer`/`user`/`friend` を、連携する一連の PJSIP オブジェクトとして再定義することにあります。具体的には、1つの `endpoint` に加え、1つの `auth`、1つの `aor`、そしてデバイスに応じて `identify`（インバウンド trunk）、`registration`（アウトバウンドログイン）、および共有の `transport` を構成します。

`contrib/scripts/sip_to_pjsip/` に含まれる `sip_to_pjsip.py` スクリプトが変換作業の大半を担い、マッピングできない要素については正直に「Non mapped elements」ブロックとしてフラグを立ててくれますが、その出力はあくまで初稿に過ぎません。トランスポート、NAT、セキュリティの設定は手動で設計し、本番環境へ投入する前に必ずテストを行ってください。設定の周辺では、dialplan（`SIP/` → `PJSIP/`）を更新し、手作業やスクリプト（`sip show` → `pjsip show`、`sip set debug` → `pjsip set logger`）も修正する必要があります。Realtime デプロイメントでは、従来の `sippeers`/`sipregs` から Sorcery の `ps_endpoints`/`ps_aors`/`ps_auths`/`ps_contacts` テーブルへと移行し、その際 `sip_to_pjsql.py` と `contrib/ast-db-manage` スキーマを活用します。落とし穴にも注意してください。すなわち、NAT の `alwaysauthreject` は組み込みであること、`insecure=invite` は `identify` になること、`qualify=yes` は `qualify_frequency` になること、そして1つの IP/ポートにつき1つのトランスポートであるという点です。これらを押さえれば、切り替え作業は不可解なものではなく、機械的な手順となります。

## クイズ

1. Asterisk 22のデプロイメントでSIPにPJSIPを使用しなければならない理由は何ですか？
   - A. `chan_sip`は低速ですが、まだ利用可能です
   - B. `chan_sip`はAsterisk 21で削除されており、Asterisk 22には存在しません
   - C. PJSIPがデフォルトですが、`chan_sip`は`modules.conf`で読み込むことができます
   - D. `chan_sip`はAsterisk 22ではTLSでのみ動作します

2. 単一の`sip.conf``type=friend`ブロックは、一般的にどのPJSIPオブジェクトのセットになりますか？
   - A. 単一の`type=peer`
   - B. `type=endpoint`のみ
   - C. `type=endpoint` + `type=auth` + `type=aor`
   - D. `type=transport` + `type=registration`

3. `sip.conf`において、`host=dynamic`（デバイスが自身の場所を登録する）は以下にマッピングされます：
   - A. `type=identify`と`match=dynamic`
   - B. `type=aor`と`max_contacts`（デバイスがREGISTERを行う）
   - C. エンドポイント上の`direct_media=yes`
   - D. `type=registration`

4. `sip_to_pjsip.py`変換スクリプトとは何ですか：
   - A. CLIコマンド：`asterisk -rx 'sip_to_pjsip'`
   - B. Asteriskソースツリーの`contrib/scripts/sip_to_pjsip/`にあるPythonスクリプト
   - C. 起動時に読み込まれるコンパイル済みモジュール
   - D. `res_pjsip.so`の一部

5. 正か誤か：`sip_to_pjsip.py`の出力は本番環境ですぐに使用可能であり、レビューなしで読み込むべきである。

6. `chan_sip`の省略形`nat=force_rport,comedia`は、PJSIPエンドポイント上でどの3つのオプションに変換されますか？
   - A. `nat=yes`、`qualify=yes`、`directmedia=no`
   - B. `force_rport=yes`、`rewrite_contact=yes`、`rtp_symmetric=yes`
   - C. `external_media_address`、`external_signaling_address`、`local_net`
   - D. `insecure=invite`、`identify`、`match`

7. `sip.conf`の`dtmfmode=rfc2833`は、どのPJSIP設定になりますか？
   - A. `dtmf_mode=rfc2833`
   - B. `dtmf_mode=inband`
   - C. `dtmf_mode=rfc4733`
   - D. `dtmf_mode=info`

8. Asterisk 22において、`auth`オブジェクトはどの`auth_type`を使用すべきであり、また`userpass`のステータスはどうなっていますか？
   - A. `auth_type=userpass`；これが唯一の有効な値です
   - B. `auth_type=digest`；`userpass`は非推奨であり、`digest`に変換されます
   - C. `auth_type=md5`；`digest`は非推奨です
   - D. `auth_type=plaintext`；`digest`は削除されました

9. `insecure=invite`（既知のIPからの認証なしINVITEを受け入れる）を持つ`chan_sip`プロバイダーピアは、以下を使用してPJSIPに移行されます：
   - A. エンドポイント上の`insecure=invite`
   - B. `[global]`内の`allowguest=yes`
   - C. `match=<provider IP>`を持つ`type=identify`オブジェクト
   - D. `auth_type=anonymous`

10. realtime移行において、`chan_sip``sippeers`テーブルはどのPJSIP/Sorceryテーブルに置き換えられますか？
    - A. 単一の`pjsip_peers`テーブル
    - B. `ps_endpoints`、`ps_aors`、および`ps_auths`
    - C. `sipregs`および`voicemail`
    - D. `ps_contacts`のみ

**回答:** 1 — B · 2 — C · 3 — B · 4 — B · 5 — 誤 · 6 — B · 7 — C · 8 — B · 9 — C · 10 — B
