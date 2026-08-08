# Asterisk REST Interface (ARI)

前の章では、Asteriskに外部ロジックを組み込むための2つの古典的な手法であるAMIとAGIについて解説しました。どちらも現代のWebが登場する前の技術です。AMIはTCPソケットを介した生の行指向イベントストリームを提供し、AGIは通話期間中、単一のchannelをスクリプトに渡します。どちらも、Webサービスと連携するIVR、クリック・トゥ・コール・ダッシュボード、会議コントローラー、音声エンジンに音声をストリーミングするボイスボットなど、今日人々が構築しているようなステートフルで非同期なマルチchannelアプリケーション向けには設計されていません。

ARI（Asterisk REST Interface）は、そのギャップを埋めるためにAsterisk 12で導入されました。Asterisk 22においては、新しい電話アプリケーションを構築するための推奨インターフェースとなっています。ARIの背後にある考え方は、関心の明確な分離です。すなわち、**Asteriskはメディアエンジンとなり**（channelの応答、bridgeのミキシング、音声の再生と録音、DTMFの送信を行います）、**アプリケーション側がREST（HTTP）APIとWebSocketイベントストリームを組み合わせて、すべての通話制御ロジックを提供します**。

## Objectives

この章を読み終えることで、読者は以下のことができるようになります。

- ARIとは何か、そしてAMIやAGIとどのように異なるかを説明できる
- プロジェクトにおいていつARIが適切なインターフェースとなるかを判断できる
- `ari.conf`および`http.conf`を設定してARIを有効にし、ユーザーを作成できる
- ARIのWebSocketイベントストリームに接続できる
- Stasis dialplanアプリケーションと`StasisStart`/`StasisEnd`イベントについて説明できる
- ARIのリソースモデル（channels、bridges、playbacks、recordings、endpoints、device states）について説明できる
- チャネルに応答し、音声を再生し、切断する最小限のStasisアプリケーションをPythonで記述できる
- `externalMedia`チャネルとは何か、そしてそれがAIやvoicebotの統合においてなぜ重要なのかを説明できる

## ARIとは何か、いつ使用すべきか

ARIは、連携して動作する2つのトランスポート上に構築されています。

- **REST (HTTP) API**: アプリケーションがチャネルの発信、応答、音声の再生、ブリッジの作成、録音の開始、切断といった「操作」を行うために呼び出すAPIです。これらは`http://asterisk-host:8088/ari/...`に対する通常のHTTPリクエスト（`GET`、`POST`、`DELETE`）です。
- **WebSocketイベントストリーム**: Asteriskがアプリケーションに対して、チャネルが作成された、DTMFが入力された、再生が終了した、チャネルがアプリケーションから離脱したといった「状況」を通知するためのストリームです。イベントはJSONオブジェクトとして配信されます。

このパターンは非同期です。リクエストを行うと、そのリクエストの「結果」は通常、後からイベントとして返されます。例えば、音声を再生するリクエストを`POST`すると、Asteriskは即座に`Playback`オブジェクトで応答し、数秒後に音声が終了した時点で`PlaybackFinished`イベントを受け取ります。

以下のような場合には、AMIやAGIではなくARIを選択してください。

- **チャネルとブリッジのきめ細かな制御**が必要な場合。dialplanのアプリケーションに頼るのではなく、プリミティブから会議、パーク、キュー、あるいは独自の通話フローを構築する場合です。
- アプリケーションが**ステートフルかつ長時間実行**される場合。複数のチャネルを同時に保持し、それらすべてのイベントに対して反応する必要があります。
- **Webサービス、メッセージバス、またはAI/音声エンジン**と統合したい場合。行指向プロトコルやstdin/stdoutスクリプトよりも、HTTP経由のJSONを好む場合です。
- **新規プロジェクト**を開始するにあたり、Asteriskプロジェクトが積極的に推奨するインターフェースを使用したい場合。

システムを「監視」するだけ、あるいは時折コマンドを発行するだけ（ダイヤラー、ウォールボード、監視など）であれば、依然としてAMIが適切なツールです。また、簡潔で自己完結型のIVRスクリプトには、AGIが依然として便利です。しかし、通話をオーケストレーションするようなあらゆる用途において、ARIが現代的な回答となります。

> ARIはdialplanを置き換えるものではなく、補完するものです。チャネルは通常通りdialplan内で実行され、`Stasis()`アプリケーションに到達した時点で、制御がARIアプリケーションに引き渡されます。アプリケーションの処理が完了すると、チャネルはdialplanに戻されるか、切断されます。

## ARIの有効化: http.conf と ari.conf

ARIはAsteriskの組み込みHTTPサーバー上で動作するため、2つの設定ファイルが関係します。すなわち、Webサーバーを有効にする`http.conf`と、ARIを有効にしてユーザーを定義する`ari.conf`です。

### http.conf

HTTPサーバーを有効にし、アドレスとポートにバインドする必要があります。ARIの標準的なポートは **8088** です。

```ini
[general]
enabled=yes
bindaddr=0.0.0.0
bindport=8088
```

本番環境では、ARIをTLSの背後に配置すべきです。AsteriskはHTTPSを直接提供することもできますし（`tlsenable=yes`、`tlsbindaddr`、`tlscertfile`、`tlsprivatekey`）、ポート 8088 の手前にあるリバースプロキシでTLSを終端させることも可能です。TLS経由の場合、URLは`http://`や`ws://`ではなく、`https://`や`wss://`になります。

HTTPサーバーが起動しているかどうかは、CLIから確認できます。

```
asterisk*CLI> http show status
HTTP Server Status:
Server Enabled and Bound to 0.0.0.0:8088
```

### ari.conf

`ari.conf`には`[general]`セクションと、ユーザーごとに1つのセクションが含まれます。

```ini
[general]
enabled=yes
pretty=yes              ; pretty-print JSON responses (handy while learning)

[asterisk]
type=user
read_only=no            ; set to yes for a user that may only issue GET requests
password=secret
password_format=plain   ; "plain" (default) or "crypt"
```

これらのオプションに関するいくつかの注意点です。

- `enabled`はARIをグローバルに有効または無効にします。
- `pretty`はJSONレスポンスを人間が読みやすい形式に整形します。本番環境では無効にしてください。
- 各ユーザーは`type=user`を持つ名前付きセクションです。
- `read_only=yes`はそのユーザーを読み取り専用（GET）リクエストに制限します。
- `password_format`には`plain`（パスワードはプレーンテキスト）または`crypt`（`mkpasswd -m sha-512`で生成されたハッシュ化パスワード）を指定できます。
- `permit`、`deny`、および`acl`は、`acl.conf`と同じルールに従い、ユーザーごとのIP制限を可能にします。

ファイルを編集した後、関連するモジュールをリロードする（`module reload res_ari.so`および`module reload http.so`）か、Asteriskを再起動してください。ARIが実行中であることは以下で確認できます。

```
asterisk*CLI> module show like res_ari
res_ari.so          Asterisk RESTful Interface          Running
res_ari_channels.so RESTful API module - Channel res... Running
res_ari_bridges.so  RESTful API module - Bridge reso... Running
...

asterisk*CLI> ari show apps
Application Name
=========================
```

`ari show apps`は、接続中のクライアントによって現在登録されているStasisアプリケーションを一覧表示します。クライアントが接続するまでは空ですが、それこそが次に私たちが実行することです。

### WebSocketイベントURL

クライアントは、実装するStasisアプリケーション名を指定し、認証情報を渡して`/ari/events`エンドポイントへのWebSocketを開くことで、イベントストリームを購読します。

```
ws://asterisk-host:8088/ari/events?app=hello&api_key=asterisk:secret
```

クエリパラメータは以下の通りです。

- `app` — Stasisアプリケーションの名前です。これはdialplanの`Stasis()`呼び出しで使用する名前と同じです。カンマ区切りで複数の名前を渡すこともできます。
- `api_key` — `ari.conf`内のユーザーと一致する、`username:password`形式の認証情報です。
- `subscribeAll` — オプションのブール値（デフォルトは`false`）です。`true`の場合、アプリケーションは自身が所有するリソースのイベントだけでなく、すべてのイベントを受信します。

同じ`user:pass`認証情報は、REST呼び出しにおけるHTTP Basic認証として使用されます（または、そこでも`api_key`クエリパラメータとして付加されます）。

## Stasis: アプリケーションへのチャネルの受け渡し

dialplanとARIの間のブリッジとなるのが **`Stasis()`** dialplanアプリケーションです（基盤となるフレームワークもStasisと呼ばれます）。チャネルが `Stasis(appname[,args])` に到達すると、Asteriskはそのチャネルを `appname` として登録されたARIアプリケーションに引き渡し、そのチャネルに対するdialplanの実行を停止します。これで制御権はあなたのコードに移ります。

```
[from-internal]
exten => _X.,1,Stasis(hello)
 same => n,Hangup()
```

チャネルがアプリケーションに入ると、 `hello` を購読しているすべての接続済みクライアントは、WebSocket経由で **`StasisStart`** イベントを受け取ります。これにはチャネルの完全なオブジェクト（ID、名前、caller ID、状態、および `Stasis()` に渡された引数）が含まれています。これがチャネルの制御を開始する合図となります。

あなたのコードが `continueInDialplan` を使用してチャネルをdialplanに戻したか、あるいはハングアップされたことによってチャネルがアプリケーションから離れると、 **`StasisEnd`** イベントを受け取ります。 `Stasis()` がdialplanに復帰した後、 `STASISSTATUS` チャネル変数（ `SUCCESS` または `FAILED` ）が設定されるため、dialplanはその結果に基づいて分岐することができます。

## ARIリソースモデル

ARIは、Asteriskの内部構造を少数のRESTリソースとして公開します。各リソースは`/ari/<resource>`の下に存在し、標準的なHTTPメソッドで操作されます。最も重要なリソースは以下の通りです。

| リソース | 何を表すか | 操作例 |
|----------|--------------------|--------------------|
| **channels** | 単一の通話レグ | originate, answer, play, record, hangup |
| **bridges** | チャネルを結合するミキシングポイント | create, add/remove channels, play to the bridge |
| **playbacks** | 進行中のメディア再生 | get status, stop, pause/unpause |
| **recordings** | ライブおよび保存済みの録音 | start, stop, list stored, delete |
| **endpoints** | 設定済みのピア (PJSIPなど) | list, get state, send a message |
| **deviceStates** | カスタムデバイス状態 | list, get, set, delete |

具体的なREST呼び出しの例をいくつか示します（パスは通信経路上に現れる`/ari`プレフィックス付きで表示しています）。

```
# Channels
POST   /ari/channels                          # originate a new channel
POST   /ari/channels/{channelId}/answer       # answer an incoming channel
POST   /ari/channels/{channelId}/play         # play media (body: media=sound:hello-world)
POST   /ari/channels/{channelId}/record       # record the channel
DELETE /ari/channels/{channelId}              # hang up the channel

# Bridges
POST   /ari/bridges                           # create a bridge (e.g. type=mixing)
POST   /ari/bridges/{bridgeId}/addChannel     # add a channel (param: channel=<id>)
POST   /ari/bridges/{bridgeId}/play           # play media to everyone in the bridge
DELETE /ari/bridges/{bridgeId}                # destroy the bridge

# Read-only resources
GET    /ari/endpoints
GET    /ari/deviceStates
GET    /ari/recordings/stored
GET    /ari/playbacks/{playbackId}
```

`play`リクエストの`media`パラメータは、メディアURIを受け取ります。最も一般的な形式は、組み込みサウンドを指定する`sound:`URIであり、例えば`sound:hello-world`や`sound:tt-monkeys`などが挙げられます。オーディオの再生が終了すると、Asteriskはその再生IDに対して`PlaybackFinished`イベントを発行します。アプリケーションはこのイベントによって、次の処理へ進むタイミングを知ることができます。

channelsとbridgesは、通話フローを作成するために組み合わせる2つの構成要素です。例えば、2人の発信者を接続するには、2つのチャネルを発信または着信させ、`POST /ari/bridges`を使用して`mixing`ブリッジを作成し、`POST /ari/bridges/{bridgeId}/addChannel`を使って両方のチャネルをそのブリッジに追加します。会議通話を構築するには、同じブリッジにチャネルを追加し続けるだけで実現できます。

## 実践例：最小限の Stasis アプリケーション

最も小さく、かつ実用的な ARI アプリケーションを作成してみましょう。いずれかの extension がダイヤルされると、通話は私たちの Stasis アプリに送られ、そこで応答し、定番の `hello-world` プロンプトを再生して、通話を終了します。

### dialplan

`extensions.conf` で、channel を Stasis に送ります。

```
[from-internal]
exten => _X.,1,Stasis(hello)
 same => n,Hangup()
```

アプリケーション名 `hello` は、接続時に使用する `app=hello` と一致させる必要があります。

### Python クライアント

このクライアントは、REST 呼び出し用の `requests` と、イベントストリーム用の `websocket-client` という2つの有名なライブラリを使用します。これらは `pip install requests websocket-client` でインストールしてください。

```python
#!/usr/bin/env python3
"""Minimal ARI Stasis app: answer, play hello-world, hang up."""
import json
import requests
from websocket import create_connection

ARI_HOST = "127.0.0.1"
ARI_PORT = 8088
ARI_USER = "asterisk"
ARI_PASS = "secret"
APP = "hello"

BASE = f"http://{ARI_HOST}:{ARI_PORT}/ari"
AUTH = (ARI_USER, ARI_PASS)

def answer(channel_id):
    requests.post(f"{BASE}/channels/{channel_id}/answer", auth=AUTH)

def play(channel_id, media):
    # Returns the Playback object; we could track its id to await PlaybackFinished.
    r = requests.post(
        f"{BASE}/channels/{channel_id}/play",
        params={"media": media},
        auth=AUTH,
    )
    return r.json()

def hangup(channel_id):
    requests.delete(f"{BASE}/channels/{channel_id}", auth=AUTH)

def main():
    ws_url = (
        f"ws://{ARI_HOST}:{ARI_PORT}/ari/events"
        f"?app={APP}&api_key={ARI_USER}:{ARI_PASS}"
    )
    ws = create_connection(ws_url)
    print(f"Connected to ARI, waiting for calls into Stasis app '{APP}'...")

    # Track which channel each playback belongs to, so we hang up when it ends.
    playback_owner = {}

    while True:
        event = json.loads(ws.recv())
        kind = event["type"]

        if kind == "StasisStart":
            channel_id = event["channel"]["id"]
            print(f"StasisStart on channel {channel_id}")
            answer(channel_id)
            pb = play(channel_id, "sound:hello-world")
            playback_owner[pb["id"]] = channel_id

        elif kind == "PlaybackFinished":
            pb_id = event["playback"]["id"]
            channel_id = playback_owner.pop(pb_id, None)
            if channel_id:
                print(f"Playback done, hanging up {channel_id}")
                hangup(channel_id)

        elif kind == "StasisEnd":
            print(f"StasisEnd on channel {event['channel']['id']}")

if __name__ == "__main__":
    main()
```

スクリプトを実行し、登録済みの endpoint から任意の番号をダイヤルしてください。「Hello, world」という音声が聞こえた後、通話が切断されるはずです。Asterisk コンソールでは、クライアントが接続されている間、 `ari show apps` が `hello` をリスト表示します。

この流れを一度追ってみましょう。

1. dialplan が `Stasis(hello)` を実行します。Asterisk は channel を私たちのアプリに渡し、 `StasisStart` イベントを送信します。
2. 私たちは channel に応答し、Asterisk に `sound:hello-world` を再生するよう要求します。Asterisk は `Playback` オブジェクトを返し、私たちはその `id` を保持します。
3. 音声の再生が終了すると、Asterisk はその playback `id` を含む `PlaybackFinished` を送信します。私たちは channel を特定し、通話を終了させます。
4. 通話を終了すると channel は Stasis から離脱し、 `StasisEnd` イベントが発生します。

> **クライアントライブラリに関する注意。** `ari-py` （ `ari` パッケージ）と呼ばれる高レベルのラッパーが存在しますが、これはメンテナンスされておらず、古い時代の Python および Swagger ツール向けに書かれたものです。Asterisk 22 での新規開発では、上記で示した明示的な `requests` + WebSocket のアプローチ、あるいは並行処理が必要な場合は `asyncari` のような asyncio ライブラリを使用することを推奨します。生の（raw）アプローチを採用することで、実際の REST 呼び出しやイベントに近い状態で作業できるため、ARI を学習する際には最適です。

## externalMedia: AIとボイスボットへの扉

上記の各リソースを使用することで、*ファイル*の再生や録音が可能になります。しかし、音声認識（speech-to-text）、AIボイスボット、リアルタイム分析といった現代の音声アプリケーションでは、通話の*ライブオーディオストリーム*を外部プロセスに配信し、さらに音声を注入し返す必要があります。

ARIは、**`externalMedia`チャネル**を通じてこれを実現します。 `POST /ari/channels/externalMedia`リクエストは、電話機と通信するのではなく、通話のRTPメディアを外部ホストへ（および外部ホストから）ストリーミングする特別なチャネルを作成します。このチャネルを発信者のチャネルとブリッジすることで、外部プログラムがオーディオパスに介在し、発信者の音声をRTPとして受信し、合成音声を送り返すことが可能になります。

このリクエストに必要なのは以下の項目のみです。

- `app` — 新しいチャネルを所有するStasisアプリケーション。
- `format` — オーディオフォーマット（例: `ulaw`や`slin16`）。

`external_host`（メディアアプリケーションの`host:port`）はスキーマ上ではオプションであり、WebSocketサーバー形式の接続であれば空でも構いませんが、一般的なRTPボイスボットの場合は指定する必要があります。 `encapsulation`パラメータはデフォルトで`rtp`となり、`transport`は`udp`となりますが、これはストリーミングメディアのendpointとしてまさに望ましい設定です。

```
POST /ari/channels/externalMedia
    app=hello
    external_host=127.0.0.1:9000
    format=slin16
```

この単一の機能こそが、AsteriskをAIのフロントエンドへと変貌させる鍵です。電話網はAsteriskで終端され、ARIが通話を制御し、`externalMedia`が音声を音声認識/AIエンジンへと送受信します。これこそが、AIサービスやボイスボットが構築されるメカニズムです。

## 概要

ARIは、Asterisk 22上でテレフォニーアプリケーションを構築するための、現代的で推奨されるインターフェースです。ARIは役割を明確に分離します。Asteriskはメディアエンジンとして機能し、HTTP経由でJSONを扱いWebSocketで通信するアプリケーションが、通話制御ロジックを提供します。ARIは`http.conf`（ポート8088で動作する組み込みWebサーバー）と`ari.conf`（ARIを有効化しユーザーを定義する設定）を通じて利用可能になります。

`Stasis()` dialplanアプリケーションは、チャネルをアプリケーションに引き渡し、チャネルがアプリケーションに入ると`StasisStart`を、離れると`StasisEnd`を発生させます。そこから、チャネル、ブリッジ、再生、録音、endpoint、デバイス状態といった一連のRESTリソースを操作することで、応答、再生、録音、ブリッジ、切断を行います。

私たちは、着信に応答してプロンプトを再生し、切断する最小限のPython Stasisアプリケーションを構築しました。また、`externalMedia`チャネルがどのようにライブRTPを外部プログラムにストリーミングするかを確認しました。これは、AIやボイスボットを統合するための基盤となります。

## クイズ

1. ARIはAsteriskのどのバージョンで導入されましたか？
   - A. Asterisk 1.4
   - B. Asterisk 11
   - C. Asterisk 12
   - D. Asterisk 18
2. ARIモデルにおいて、Asteriskはメディアエンジンとして機能し、外部アプリケーションが通話制御ロジックを提供します。
   - A. 真
   - B. 偽
3. ARIは2つのトランスポートを組み合わせて使用します。正しい組み合わせはどれですか？
   - A. コマンド発行用の REST/HTTP API と、イベント受信用の WebSocket ストリーム
   - B. TCPラインプロトコルと stdin/stdout スクリプト
   - C. SNMP と SMTP
   - D. 2つの独立した UDP ソケット
4. ARIを有効にするために設定が必要な2つの設定ファイルはどれですか？
   - A. `manager.conf` および `agi.conf`
   - B. `http.conf` および `ari.conf`
   - C. `sip.conf` および `rtp.conf`
   - D. `modules.conf` および `cdr.conf`
5. Asterisk HTTPサーバー（したがってARI）の一般的な TCP ポートは ____ です。
6. どの dialplan アプリケーションがチャネルを ARI アプリケーションに引き渡しますか？
   - A. `AGI()`
   - B. `Dial()`
   - C. `Stasis()`
   - D. `System()`
7. チャネルが Stasis アプリケーションに入ると、接続されたクライアントにどのイベントが送信されますか？
   - A. `ChannelDestroyed`
   - B. `StasisStart`
   - C. `Newchannel`
   - D. `Hangup`
8. 2つ以上のチャネルを結合できるミキシングポイントを作成する ARI リクエストはどれですか？
   - A. `POST /ari/channels`
   - B. `POST /ari/bridges`
   - C. `GET /ari/endpoints`
   - D. `DELETE /ari/recordings/stored`
9. チャネル上で組み込みのプロンプトを再生する際、音声が終了したことをアプリケーションに通知し、次の処理へ進めるようにするイベントはどれですか？
   - A. `PlaybackStarted`
   - B. `DTMFReceived`
   - C. `PlaybackFinished`
   - D. `ChannelTalkingFinished`
10. `externalMedia` チャネルは主に何のために使用されますか？
    - A. 通話をローカルの WAV ファイルに録音する
    - B. 通話のライブオーディオ（RTP）を外部アプリケーション（AI/音声エンジンなど）との間でストリーミングする
    - C. PJSIP endpoint を登録する
    - D. dialplan をリロードする

**回答:** 1 — C · 2 — A · 3 — A · 4 — B · 5 — `8088` · 6 — C · 7 — B · 8 — B · 9 — C · 10 — B
