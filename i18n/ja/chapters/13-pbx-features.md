# PBX機能の利用

SIPシステムでは、電話機能のほとんどがendpoint側で実装されています。多種多様なSIP電話機やメーカーが存在しており、相互運用性は保証されていません。Asteriskの開発チームは、これらの機能のほとんどをPBX自体に実装するという素晴らしい仕事をしており、Asteriskをほぼendpointに依存しないものにしています。しかし、電話機とAsteriskの両方で同じ機能が実行されている状況に遭遇することもあるでしょう。電話機とPBXの統合は、ユーザビリティにおける次のフロンティアであり、現在プロプライエタリなシステムが注力している分野です。本章では、これらの機能のほとんどを利用する方法を学びます。

## Objectives

この章を読み終えることで、以下の機能を理解し、使用できるようになります。

- Call Parking
- Call Pickup
- Call Transfer
- Call Conference (ConfBridge)
- Call Recording
- Music on hold

## 機能が実装されている場所

何よりもまず、PBXの機能が実行されているタイミングと、電話機側ですべての処理が行われているタイミングの違いを理解することが重要です。例えば、電話機の TRANSFER ボタンを使用して通話を転送する場合と、# をダイヤルして転送する場合（PBX自体によって実行される無条件転送）では、処理の主体が異なります。

## Asteriskによって実装される機能

これらの機能は、AsteriskのコードによってPBX内に実装されています。

- 保留音 (Music on hold)
- 通話パーク (Call parking)
- 通話ピックアップ (Call pickup)
- 通話録音 (Call recording)
- ConfBridge会議室 (ConfBridge conference room)
- 通話転送 (ブラインド転送および相談転送) (Call transfer (blind and consultative))

## dialplanで一般的に実装される機能

これらの機能は、Asteriskのdialplan（extensions.conf）でプログラムする必要があります。

- 話中時転送（Call forward on busy）
- 無条件転送（Call forward immediate）
- 不応答時転送（Call forward on unanswered）
- 着信フィルタリング（ブラックリスト）
- おやすみモード（Do not disturb）
- リダイヤル

## 電話機側で通常実装される機能

これらの機能は、電話機のファームウェアによって実装されます。

![PBXの機能が通常どこで実装されるか：Asterisk自体、dialplan、または電話機](../images/13-pbx-features-fig01.png)

- Call on hold
- Blind transfer
- Consultative transfer
- Three-way conference
- Message waiting indicator

## features設定ファイル

本章で紹介する機能の一部は、features.conf設定ファイルで構成されます。このファイルを変更することで、いくつかの機能の動作を変更することが可能です。関連する抜粋を以下に記載しました。本章の次節以降で、各機能について説明します。サンプルファイルからの抜粋（Asterisk 22）

![features.confの`[featuremap]`セクション、デフォルトのDTMF機能コード付き](../images/13-pbx-features-fig02.png)

Asterisk 12以降、コールパーキングは`features.conf`から独立したモジュールである`res_parking`へと移行され、設定は`res_parking.conf`で行われるようになりました。以下のパーキングロットブロック（`parkext`、`parkpos`、`context`、`parkingtime`など）は`res_parking.conf`に記述されます。`[featuremap]`セクション（`parkcall`を含むDTMF機能コード）は`features.conf`に残っています。

パーキングロットのオプションは`res_parking.conf`に記述されます。`default`という名前のパーキングロットは、設定ファイルに存在しない場合でも常に存在します。以下の抜粋はAsterisk 22の`res_parking.conf.sample`から引用したものです：

```
; res_parking.conf
[default]                       ; Default Parking Lot
parkext => 700                  ; What extension to dial to park. (optional; if
                                ; specified, extensions will be created for parkext and
                                ; the whole range of parkpos)
parkpos => 701-720              ; What range of parking spaces to use - must be numeric.
                                ; Creates these spaces as extensions if parkext is set.
context => parkedcalls          ; Which context parked calls and the default park
                                ; extension are created in
;parkingtime => 45             ; Number of seconds a call can be parked before returning
;comebacktoorigin = yes        ; When a parked call times out, attempt to send it back to
                               ; the peer that parked it (default is yes)
;courtesytone = beep           ; Sound file to play when someone picks up a parked call
;parkedplay = caller           ; Who to play courtesytone to: parked, caller, both (default caller)
;parkedcalltransfers = caller  ; Enable DTMF transfers when picking up a parked call (default no)
;parkedcallreparking = caller  ; Enable DTMF parking when picking up a parked call (default no)
;parkedcallhangup = caller     ; Enable DTMF hangups when picking up a parked call (default no)
;findslot => next              ; 'next' uses the next space after the most recently used one;
                               ; 'first' (default) uses the lowest-numbered space available
;parkedmusicclass = default    ; MOH class to use for the parked channel
```

（ワンステップ`parkcall`を含む）DTMF機能コードは、`features.conf`の`[featuremap]`セクションに残っています：

```
; features.conf
[featuremap]
;blindxfer => #1                ; Blind transfer  (default is #) -- Make sure to set the T and/or t option in the Dial() or Queue() app call!
;disconnect => *0               ; Disconnect  (default is *) -- Make sure to set the H and/or h option in the Dial() or Queue() app call!
;atxfer => *2                   ; Attended transfer  -- Make sure to set the T and/or t option in the Dial() or Queue()  app call!
;parkcall => #72                ; Park call (one step parking)  -- Make sure to set the K and/or k option in the Dial() app call!
;automixmon => *3               ; One Touch Record a.k.a. Touch MixMonitor -- Make sure to set the X and/or x option in the Dial() or Queue() app call!
```

## 通話転送

通話転送は、電話機、ATA、またはAsterisk自体によって実装できます。通話の転送方法については、お使いの電話機のマニュアルを参照してください。もしお使いの電話機が通話転送をサポートしていない場合は、Asteriskを使用してこのタスクを実行できます。通話転送には2つの異なる実装方法があります。

1つ目の方法は、ブラインド転送機能を使用することです。# をダイヤルし、続いて転送先の番号を入力します。IP電話機やIP softphoneの転送機能を使用する場合もあります。features.conf ファイル内の blindxfer パラメータを編集することで、転送用の文字を変更できます。

Asteriskでアテンデッド転送を有効にするには、features.conf ファイル内の atxfer パラメータの前にある ; を削除します。通話中に *2 を押すと、Asteriskが「transfer」とアナウンスし、ダイヤルトーンが聞こえます。発信者は保留音（music on hold）の状態になります。転送先の相手と話した後に電話を切ると、システムは発信者と転送先をブリッジします。

![通話転送：ブラインド転送（通話中に # を押す）とアテンデッド転送（*2 を押す）の手順](../images/13-pbx-features-fig03.png)

### 設定タスクリスト

1. PJSIP endpoint の場合、オプション `direct_media` が `no` に設定されていることを確認してください（これによりメディアがAsteriskを経由し、機能コードが検出されるようになります）。または、`Dial()` アプリケーションで `t`/`T` オプションを使用してください。

## Call parking

この機能は、通話をパーク（保留）するために使用されます。例えば、部屋の外で電話に応答し、その通話を自分のデスクに戻したい場合などに役立ちます。これを実現するには、通話を特定の extension にパークします。デスクに到着したら、パークした extension の番号をダイヤルするだけで、通話を再開できます。

![Call parking: 700をダイヤルして最初の空きスロット（701–720）に通話をパークします。Asteriskがスロット番号をアナウンスし、どの電話機からでもその番号をダイヤルすることで通話を復帰できます](../images/13-pbx-features-fig04.png)

デフォルトでは、700という extension が通話のパークに使用されます。通話中に # を押すと、通話が700という extension に転送されます。すると Asterisk が701や702といったパーク先の extension をアナウンスします。電話を切ると、発信者は保留状態になります。デスクの電話機まで移動し、アナウンスされたパーク先の extension をダイヤルすれば、通話を再開できます。発信者が長時間パークされたままの場合、タイムアウト機能が作動し、最初にダイヤルされた extension が再び呼び出されます。

### Configuration task list

Call parking を有効にするには、以下の手順に従ってください。ステップ1：dialplan から parking lot に到達できるようにします（必須）。デフォルトの parking lot の `context` は `parkedcalls` です（`res_parking.conf` で設定）。その context を、電話機がダイヤルを行う context に含めます（`extensions.conf`）：

```
include => parkedcalls
```

ステップ2：#700 をダイヤルして Call parking 機能をテストします。注意点：

- パーク用の extension は `dialplan show` CLI コマンドには表示されません。
- parking 設定ファイルを変更した後は、parking モジュールをリロードする必要があります：`module reload res_parking.so`。features.conf を変更した場合は、`module reload features.so` を実行してください。
- 通話をパークするには、#700 に転送する必要があります。`Dial()` アプリケーションにおける `t` および `T` オプションを確認してください。

## Call pickup

Call pickup を使用すると、同じ call group に属する同僚への着信を自分の端末で応答することができます。これは、例えば、同じ部屋にいる別の人の電話が鳴っているものの本人が不在である場合に、わざわざ席を立たなくても電話に出られるようにするのに役立ちます。*8 をダイヤルすることで、自分の call group 内の着信をピックアップできます。この番号は `features.conf` ファイルで変更可能です。

![Call pickup: メンバーは自分のグループ内の着信のみをピックアップできます。オペレーター (pickupgroup=1,2,3) はすべてのグループの着信をピックアップできます](../images/13-pbx-features-fig05.png)

### Configuration task list

Call pickup 機能を設定するには、以下の手順に従ってください。ステップ 1: extension 用の call group を設定します。これはチャネル設定ファイル (pjsip.conf, iax.conf, chan_dahdi.conf) で行います。PJSIP endpoint の場合は、 `pjsip.conf` の endpoint セクションで `call_group` と `pickup_group` を設定します (pjsip.conf では snake_case のオプション名を使用します)。このタスクは必須です。

PJSIP (pjsip.conf) の場合:
```
[4x00]
type=endpoint
call_group=1
pickup_group=1,2
```


ステップ 2: Call-pickup の機能番号を変更します (オプション)。これは `pjsip.conf` ではなく、 `features.conf` の `[general]` セクションで設定します:

```
; features.conf
[general]
pickupexten = *8   ; Configures the call pickup extension (default is *8)
```

## Conference (通話会議)

Asteriskで会議を実装する方法はいくつかあります。最初の選択肢は、電話機が持つ3者通話機能を使用することです。この機能を使用すれば、サーバー側でのサポートは一切不要です。しかし、3人以上の会議が必要な場合は、会議室（カンファレンスルーム）を運用する必要があります。Asteriskの現代的な会議アプリケーションが ConfBridge (`app_confbridge`) です。

ConfBridgeはHD音声会議とビデオ会議をサポートしています。ビデオ会議にはトランスコーディングが行われないという制限がいくつかあり、すべての参加者が同じ codec とプロファイルを使用する必要があります。ビデオ会議では「話者追従（follow-the-talker）」モードが使用され、最後に発言した人の映像が表示されます。ConfBridgeでは、新しい DTMF メニューを簡単に設定できます。

ConfBridgeは、Asterisk 19で非推奨となった古い MeetMe アプリケーションに代わるものです。MeetMeは Asterisk 22 のソースツリーにも含まれていますが、DAHDI に依存しておりデフォルトではビルドされないため、一般的な PJSIP インストール環境では単純に使用できません。現在サポートされている会議アプリケーションは ConfBridge です。MeetMeとは異なり、ConfBridgeは DAHDI やハードウェアのタイミングソースを**必要としません**。Asteriskの組み込みタイミングインターフェース（Linux上の`res_timing_timerfd`、または`res_timing_pthread`）に依存しているため、いかなる`dahdi_dummy`モジュールも不要です。もし`MeetMe()`や`meetme.conf`を使用していた古いシステムから移行する場合は、以下で説明するようにそれらを`ConfBridge()`や`confbridge.conf`に置き換えてください。

### ConfBridge

会議室を開始するための構文は以下の通りです。

```
ConfBridge(conference,bridge_profile,user_profile,menu)
```

コマンドの詳細な説明については、core show application confbridge を使用してください。

![`core show application confbridge`の出力。シノプシス、構文、および bridge_profile、user_profile、menu の各引数が表示されている](../images/13-pbx-features-fig06.png)

![複数の PJSIP endpoint が1つの名前付き ConfBridge 会議 (101) に参加している様子。参加者の1人が管理者。ミキシングとタイミングは`app_confbridge`が`bridge_softmix`および組み込みの`res_timing_*`タイマーと連携して処理しており、DAHDI は不要。](../images/13-pbx-features-fig09.png)

上記のように、3つの重要な引数があり、それぞれが`confbridge.conf`内のセクションタイプに対応しています。**bridge_profile**（`type=bridge`セクション）では、最大参加者数（`max_members`）、録音（`record_conference`）、`video_mode`、その他多くのブリッジ全体に関わるパラメータを選択します。

ここで例のファイル全体を再現しても意味がないため、confbridge.conf ファイル内で bridge_profile を設定する簡単な例を紹介します。

```
[default_bridge]
type=bridge
max_members=10
record_conference=yes
```

**user_profile**（`type=user`セクション）では、ユーザーが管理者かどうか（`admin=yes`）、ミュート状態で開始するかどうか（`startmuted=yes`）、保留音、その他多くのユーザーごとのオプションなど、ユーザー固有のオプションを定義します。例：

```
[admin_user]
type=user
admin=yes
```

**menu**（`type=menu`セクション）では、会議用のキーパッド（DTMF）マッピングを定義します。例えば、どのキーでミュートの切り替え、音量調整、会議からの退出を行うかなどを設定します。利用可能なすべてのアクションについては`confbridge.conf.sample`ファイルを確認してください。例：

```
[my_menu]
type=menu
*=playback_and_continue
1=toggle_mute
2=decrease_listening_volume
3=increase_listening_volume
4=decrease_talking_volume
5=increase_talking_volume
6=leave_conference
```

#### Confbridge 関数

会議ブリッジのオプションは、dialplan 内で CONFBRIDGE() 関数を使用して動的に渡すことができます。以下の例を参照してください。

```
exten => 1,1,Answer()
exten => 1,n,Set(CONFBRIDGE(user,template)=default_user)
exten => 1,n,Set(CONFBRIDGE(user,admin)=yes)
exten => 1,n,Set(CONFBRIDGE(user,marked)=yes)
exten => 1,n,ConfBridge(sales)
```

### ConfBridge 管理者コマンドと MeetMe からの移行

MeetMeから移行する場合、以前`MeetMeAdmin()`や`a`（管理者）オプションを通じて使用していた管理者機能は、現在では **admin user profile**（`admin=yes`）と **menu** アクションを通じて表現されます。管理者プロファイルと管理者アクションを含むメニューで参加した管理者は、キーパッドから直接、会議室のロック、ユーザーの強制退出、参加者のミュートをライブで行うことができます。`confbridge.conf`における関連メニューアクションは以下の通りです。

- `admin_kick_last` -- 最後に参加したユーザーを強制退出させる
- `admin_toggle_mute_participants` -- 管理者以外の全参加者をミュート/ミュート解除する
- `toggle_mute` -- 自分自身をミュート/ミュート解除する
- `participant_count` -- 参加者数をアナウンスする
- `leave_conference` -- ブリッジから退出して dialplan の続きを実行する

これらは、MeetMeの`MeetMe()`オプションフラグ（`a`、`A`、`m`、`M`、`l`、`x`、…）および`MeetMeAdmin()`コマンド（`k`、`K`、`L`、`M`、`N`、…）に代わるものです。現代的な PJSIP インストール環境では`app_meetme`を読み込む必要は一切ありません。すべての会議設定は`confbridge.conf`に存在し、変更は`module reload app_confbridge.so`で適用されます（ConfBridgeのロジックは`app_confbridge`に存在し、`res_confbridge`モジュールは存在しません）。

### ConfBridge の例

extension 500 で到達可能な会議室を作成するには、`extensions.conf`で以下のように設定します。

```
exten => 500,1,Answer()
 same => n,ConfBridge(101,default_bridge,default_user,sample_user_menu)
```

500 にダイヤルした最初の発信者が会議`101`を作成し、後続の発信者がそれに参加します。ここで参照されているプロファイルとメニュー（`default_bridge`、`default_user`、`sample_user_menu`）は`confbridge.conf`で定義されています。PIN を要求するには user profile で`pin=`を設定し、参加者を会議管理者に設定するには`admin=yes`を含む user profile を割り当ててください。

## 通話録音

Asteriskで通話録音を行う方法はいくつかあります。 `MixMonitor()` アプリケーションを使用すると、簡単に通話を録音できます。（2つの別々のファイルを録音していた古い `Monitor` アプリケーションは削除されました。代わりに `MixMonitor` を使用してください。）

### MixMonitorアプリケーションの使用

`MixMonitor` アプリケーションは、現在のチャネルの音声を指定されたファイルに録音します。ファイル名が絶対パスである場合、そのパスが使用されます。それ以外の場合は、asterisk.confで設定されたモニタリングディレクトリ内にファイルが作成されます。

![MixMonitor() アプリケーション: チャネルの音声をファイルに録音・ミキシングします。追記、ブリッジのみ、音量調整のオプションがあります](../images/13-pbx-features-fig09.png)

### MixMonitor()

通話を録音し、録音中に音声をミキシングします。構文: `MixMonitor(filename.extension[,options[,command]])`。現在のチャネルの音声を指定されたファイルに録音します。有効なオプションは以下の通りです。

- a - ファイルを上書きせず、追記します。
- b - チャネルがブリッジされている間のみ、音声をファイルに保存します。
- 注: 会議は含まれません。
- v(<x>) - 可聴音量を <x> 倍（-4から4の範囲）に調整します。
- V(<x>) - 通話音量を <x> 倍（-4から4の範囲）に調整します。
- W(<x>) - 可聴音量と通話音量の両方を <x> 倍（-4から4の範囲）に調整します。
- <command> は録音終了時に実行されます。^{X} に一致する文字列は ${X} にエスケープ解除され、その時点で全ての変数が評価されます。変数 MIXMONITOR_FILENAME には、録音に使用されたファイル名が格納されます。

興味深いリソースとして、ワンタッチ録音機能 `automixmon` があります。これは、通話中に当事者がDTMFコード（`features.conf` のサンプルでは `*3` が提案されていますが、組み込みのデフォルトはないため設定が必要です）をダイヤルすることで、即座に録音を開始（および停止）できる機能です。これはMixMonitorに基づいて構築されているため、単一のミキシングされたファイルが書き込まれます。例:

```
exten => _4XXX,1,Set(DYNAMIC_FEATURES=automixmon)
 same => n,Dial(PJSIP/${EXTEN},20,jtTXx) ; X and x enable one-touch MixMonitor recording
```

`X` および `x` オプションは、それぞれ発信者と着信者に対してワンタッチMixMonitor機能を有効にします。MixMonitorは単一のミキシングされたファイルを録音するため、後で個別のIN/OUTファイルを結合する必要はありません（`soxmix` 用に2つのファイルを作成していた古い `automon`/`Monitor` アプローチは、 `Monitor` アプリケーションと共に削除されました）。

Dial() アプリケーションの前に Set() を使用したくない場合は、globalsセクションで以下のように設定できます。

```
[globals]
DYNAMIC_FEATURES=automixmon
```

### 保留音 (Music on hold)

保留音 (MOH) は、バージョン 1.0、1.2、1.4 の間で何度か変更されました。最新バージョンでは、MOHはデフォルトで "FILE-BASED" になっています。つまり、Asteriskは g729、alaw、ulaw、gsm などの形式でMOHファイルを提供します。そのため、チャネルに送信する前に音楽をトランスコードする必要はありません。これによりプロセッサの時間を節約でき、本番システムを運用するユーザーにとって歓迎すべき変更となっています。

古いバージョンでは、MOHは通常MP3で提供されていました（現在もそのように設定可能です）。MP3を使用してMOHを提供すると、Asteriskはトランスコードを強制され、貴重なCPUパワーを消費してしまいます。

新しい設定ファイルを以下に示します。デフォルトのクラスがネイティブファイルフォーマットの mode=files を使用していることに注意してください。他の全てのモードはコメントアウトされています。現時点でコメントアウトされていないクラスは default のみです。異なるファイルに対して異なるクラスを持たせたい場合は、新しいセクション（クラス）を作成する必要があります。

![musiconhold.conf のサンプル設定。有効なMOHモード（quietmp3、mp3、custom、filesなど）がリストされています](../images/13-pbx-features-fig10.png)

```
; Music on Hold -- Sample Configuration
;[samplemp3]
;mode=quietmp3
;directory=/var/lib/asterisk/mohmp3
;
; valid mode options:
; quietmp3      -- default
; mp3           -- loud
; mp3nb         -- unbuffered
; quietmp3nb    -- quiet unbuffered
; custom        -- run a custom application (See examples below)
; files         -- read files from a directory in any Asterisk supported
;                  media format. (See examples below)
;[manual]
;mode=custom
; Note that with mode=custom, a directory is not required, such as when reading
; from a stream.
;directory=/var/lib/asterisk/mohmp3
;application=/usr/bin/mpg123 -q -r 8000 -f 8192 -b 2048 --mono -s
;[ulawstream]
;mode=custom
;application=/usr/bin/streamplayer 192.168.100.52 888
;format=ulaw
; mpg123 on Solaris does not always exit properly; madplay may be a better
; choice
;[solaris]
;mode=custom
;directory=/var/lib/asterisk/mohmp3
;application=/site/sw/bin/madplay -Q -o raw:- --mono -R 8000 -a -12
;
;
; File-based (native) music on hold
;
; This plays files directly from the specified directory, no external
; processes are required. Files are played in normal sorting order
; (same as a sorted directory listing), and no volume or other
; sound adjustments are available. If the file is available in
; the same format as the channel's codec, then it will be played
; without transcoding (same as Playback would do in the dialplan).
; Files can be present in as many formats as you wish, and the
; 'best' format will be chosen at playback time.
;
; NOTE:
; If you are not using "autoload" in modules.conf, then you
; must ensure that the format modules for any formats you wish
; to use are loaded _before_ res_musiconhold. If you do not do
; this, res_musiconhold will skip the files it is not able to
; understand when it loads.
;
[default]
mode=files
directory=/var/lib/asterisk/moh
;
;[native-random]
;mode=files
;directory=/var/lib/asterisk/moh
;random=yes     ; Play the files in a random order
```

### MOH設定タスク

保留音を使用するには、チャネル設定ファイル（chan_dahdi.conf、pjsip.conf、iax.conf など）でMOHクラスを設定します。PJSIP endpoint の場合は、 `pjsip.conf` の endpoint セクションで `moh_suggest` を設定します（レガシーな `musicclass` オプション名は chan_dahdi やその他のチャネルドライバに適用されるものであり、PJSIPには適用されません）。インストールされるフリープレイの楽曲は現在 wav 形式です。インストール時に（make menuselect を使用して）利用可能なMOHファイル形式を選択できます。新しいMOHファイルを追加したい場合は、必要な形式で提供する必要があります。例:

`/etc/asterisk/chan_dahdi.conf` に、 `musiconhold` 行を追加します。

```
[channels]
musiconhold=default
```

次に、 `/etc/asterisk/musiconhold.conf` を編集してそのクラスを定義します。

```
[default]
mode=files
directory=/var/lib/asterisk/moh
```

dialplan では、 `StartMusicOnHold` でチャネルの保留音を開始し（ `StopMusicOnHold` で停止し）ます。

```
exten => 100,1,StartMusicOnHold(default)
 same => n,Dial(PJSIP/2)
```

簡単なテストとして一定時間保留音を再生するには、期間（秒単位）を指定して `MusicOnHold` アプリケーションを使用します。

```
[local]
exten => 6601,1,MusicOnHold(default,30)
```

## Application Maps

Application mapsを使用すると、features.confファイルの`[applicationmap]`セクションを使用して新しい機能を追加できます。例えば、コールセンターで応答する顧客のタイプを識別する必要があるとします。顧客タイプごとにapplication mapを作成すれば、タイプごとの応答済み顧客数をカウントできるようになります。

## まとめ

本章では、AsteriskのPBX機能がどこに存在するか（コア、dialplan、あるいは電話機側）、そしてDTMF機能コードが`features.conf`の`[featuremap]`セクションでどのようにマッピングされているかを学びました。また、**call transfer**（ブラインド転送およびアテンデッド転送）や**call parking**（`res_parking.conf`、および`k`/`K`のDialオプションと`parkedcalls`ロットを使用）、グループによる**call pickup**、そして従来のMeetMeに代わる**ConfBridge**（`confbridge.conf`のbridge/user/menuプロファイル）を使用した**conferencing**の設定を行いました。さらに、MixMonitor（`automixmon`、および`X`/`x`のDialオプションと`DYNAMIC_FEATURES`）を使用した**one-touch recording**の設定、**music on hold**の構成、そして**application maps**を使用して独自のdialplanロジックをDTMFシーケンスにバインドする方法についても解説しました。これらの構成要素を組み合わせることで、ビジネス用PBXとしてユーザーが期待する日常的な機能を提供できるようになります。

## クイズ

1. コールパーキングについて正しい記述はどれですか？
   - A. デフォルトでは、extension 800がコールパーキングに使用されます。
   - B. 自分のデスクから離れているときに電話を受けた場合、それをパークすることができます。システムがパークスロットをアナウンスし、どの電話機からでもそのスロットにダイヤルすることで通話を再開できます。
   - C. デフォルトでは、extension 700で通話をパークし、通話は701–720のスロットにパークされます。
   - D. パークされた通話を再開するには700をダイヤルします。
2. コールピックアップ機能を使用するには、すべての extension が同じ ___ に属している必要があります。DAHDI チャネルの場合、これは ___ ファイルで設定されます。
3. 通話を転送する際、宛先に事前に確認を行わない ___ 転送と、完了前に宛先と会話を行う ___ 転送を選択できます。
4. アテンデッド（相談）転送を行うには ___ シーケンスを使用し、ブラインド転送には ___ を使用します。
   - A. #1, *2
   - B. *2, #1
   - C. #2, #1
   - D. #1, #2
5. Asterisk 22で電話会議をホストするには、___ アプリケーションを使用します。
6. ConfBridgeにおいて、参加者に管理者権限（キック、他者のミュート、ルームのロック）を付与するには、ユーザープロファイル（`confbridge.conf`）で以下を設定します：
   - A. admin=yes
   - B. marked=yes
   - C. moderator=yes
   - D. type=admin
7. 保留音（Music on Hold）に最適なフォーマットはMP3です。なぜなら、Asterisk サーバーの処理能力をほとんど消費しないからです。
   - A. 正
   - B. 誤
8. 特定のコールグループから通話をピックアップするには、一致する ___ グループに属している必要があります。
9. MixMonitor() アプリケーションまたはワンタッチ録音（`automixmon`）機能を使用して通話を録音できます。`features.conf`のサンプルでは、`automixmon`は ___ DTMFシーケンスにマッピングされています。
   - A. *1
   - B. *2
   - C. *3
   - D. #1
10. ConfBridgeにおいて、参加者をミュート状態で参加させる（会議を聞くことはできるが、ミュート解除されるまで発言できない）ための`confbridge.conf`ユーザープロファイルオプションはどれですか？
    - A. startmuted=yes
    - B. listen=only
    - C. muteall=yes
    - D. quiet=yes

**回答:** 1 — B, C · 2 — pickup group; `chan_dahdi.conf` · 3 — blind; attended · 4 — B · 5 — ConfBridge() · 6 — A · 7 — B · 8 — pickup · 9 — C · 10 — A
