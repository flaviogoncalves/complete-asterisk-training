# PJSIPを使用した最初のPBXの構築

本章では、基本的な Asterisk PBX の設定方法を学びます。ここでの主な目的は、PBX を初めて稼働させ、extension 間での通話、再生されるメッセージへのダイヤル、そして単一のアナログまたは SIP trunk へのダイヤルができるようにすることです。本章の狙いは、Asterisk を可能な限り迅速に立ち上げ、動作させることにあります。本章の作業を完了すれば、設定の詳細をより深く掘り下げる後続の章に向けて、十分な基礎知識を身につけることができます。

## Objectives

この章を読み終えることで、以下のことができるようになります。

- 設定ファイルの理解と編集
- SIPベースのsoftphoneのインストール
- SIP trunkのインストールと設定
- アナログ接続のインストールと設定
- extension間でのダイヤル
- 電話機と外部宛先間でのダイヤル
- auto attendant（自動応答）の設定

## 設定ファイルの理解

Asteriskは、/etc/asterisk に配置されたテキスト形式の設定ファイルによって制御されます。ファイル形式はWindowsの「.ini」ファイルに似ています。セミコロンはコメント文字として使用され、「=」と「=>」という記号は同等であり、スペースは無視されます。

```
;
; The first line without a comment should be the session title.
;
[Session]
Key = value; Variable designation
[Session 2]
Key => value; Object declaration
```

Asteriskは「=」と「=>」を同じように解釈します。構文の違いは、オブジェクトと変数を区別するために使用されます。変数を宣言する場合は「=」を使用し、オブジェクトを指定する場合は「=>」を使用してください。すべてのファイル間で構文は共通ですが、以下で説明するように3種類の文法が使用されます。

## Grammars

| Grammar | How the object is created | Conf. file | Example |
|---------|---------------------------|------------|---------|
| Simple Group | 全てを同一行に記述 | `extensions.conf` | `exten => 4000,1,Dial(PJSIP/4000)` |
| Option Inheritance | 最初にオプションを定義し、オブジェクトがそれを継承する | `chan_dahdi.conf` | `[channels]; context=default; signalling=fxs_ks; group=1; channel => 1` |
| Complex Entity | 各エンティティがコンテキストを持つ | `pjsip.conf`, `iax.conf` | `[cisco]; type=endpoint; auth=cisco-auth; aors=cisco; context=trusted` |

### Simple Group

`extensions.conf`および`voicemail.conf`で使用される Simple Group 形式は、最も基本的な文法です。各オブジェクトは、そのオプションと共に同一行で宣言されます。例：

```
[Session]
Object 1 => op1,op2,op3
Object 2=> op1b,op2b,op3b
```

この例では、オブジェクト 1 はオプション op1、op2、op3 を伴って作成され、オブジェクト 2 も同様にオプション op1、op2、op3 を伴って作成されます。

### Object options inheritance grammar

この形式は chan_dahdi.conf や agents.conf などのファイルで使用されます。これらのファイルでは多数のオプションが利用可能であり、ほとんどのインターフェースやオブジェクトが共通のオプションを共有しています。一般的に、1 つ以上のセクションでオブジェクトやチャネルの宣言が行われます。オブジェクトに対するオプションはオブジェクトの定義より前に宣言され、別のオブジェクトに対して変更することが可能です。この概念は理解しにくいかもしれませんが、使用するのは非常に簡単です。例：

```
[Session]
op1 = bas
op2 = adv
object=>1
op1 = int
object => 2
```

最初の 2 行で、オプション op1 と op2 の値をそれぞれ “bas” と “adv” に設定しています。オブジェクト 1 がインスタンス化される際、オプション 1 は “bas”、オプション 2 は “adv” として作成されます。オブジェクト 1 を定義した後、オプション 1 を “int” に変更します。次に、オプション 1 を “int”、オプション 2 を “adv” としてオブジェクト 2 を作成します。

### Complex entity object

この形式は pjsip.conf、iax.conf、および多数のオプションを持つエンティティが存在するその他の設定ファイルで使用されます。通常、この形式では大量の共通設定を共有することはありません。各エンティティはコンテキストを受け取ります。グローバル設定のための [general] のように、予約されたコンテキストが存在する場合もあります。オプションはコンテキスト宣言内で宣言されます。例：

```
[entity1]
op1=value1
op2=value2
[entity2]
op1=value3
op2=value4
```

エンティティ [entity1] は、オプション op1 と op2 に対してそれぞれ “value1” と “value2” という値を持っています。エンティティ [entity2] は、オプション op1 と op2 に対して “value3” と “value4” という値を持っています。

## Asteriskのラボを構築するための選択肢

PBXを構築するには、基本的なハードウェアがいくつか必要になります。決して難しくも高価でもありませんが、考慮すべき選択肢がいくつか存在します。必要なものは、電話機2台と公衆網への接続だけです。ラボを作成する際にはいくつかの選択肢や組み合わせが可能であり、以下でそれらを検討します。

### 選択肢1：完全なラボ

完全なラボでは、利用可能なすべてのシナリオをテストし、ATA、IP-phone、softphoneといったソリューションを比較することが可能です。また、アナログtrunkやSIP trunkについても学習できます。必要なものは以下の通りです。

- SIP対応のアナログ電話アダプタ (ATA)
- IP-phone
- Asterisk専用サーバー
- softphoneをインストールしたワークステーション
- 少なくとも2つのインターフェース（1 FXOおよび1 FXS）を備えたアナログインターフェースカード
- VoIPプロバイダーのアカウント

### 選択肢2：経済的なラボ

経済的なラボでは、構成を少し簡略化します。IP-phoneよりも一般的に安価なATAと、非常に安価なFXOカードを1枚使用します。サーバーに直接接続されたアナログ電話機を使用することはできませんが、実際の運用においてそのような構成は一般的ではありません。必要なものは以下の通りです。

- SIP対応のアナログ電話アダプタ (ATA)
- Asterisk専用サーバー
- softphone用のワークステーション
- 1 FXOを備えたアナログインターフェースカード
- VoIPプロバイダーのアカウント

### 選択肢3：超経済的なラボ

3つ目のラボでは、学習者自身のノートPC上で仮想化されたサーバーを使用します。このモデルの問題点は、UDPポートによって発生する競合です。Asteriskサーバーとsoftphoneの両方が同じポートにアクセスしようとすることがあり、その場合Asteriskがアドレスポートをバインドできなくなります。もう1つの問題は通話品質です。仮想環境は、Asteriskのようなリアルタイムアプリケーションには適していません。サーバーとワークステーションには無料のsoftphoneを使用し、SIPプロバイダーへのtrunk接続を利用します。必要なものは以下の通りです。

- softphoneを実行するノートPC
- Asteriskをインストールするための仮想マシン (VirtualBox、VMwareなど)
- VoIPプロバイダーのアカウント

## インストール手順

インストール手順を理解しやすくするために、Asteriskをインストールおよび設定するために必要なステップの順序を以下にまとめました。

![リファレンスラボのレイアウト：SIP/IAXソフトフォン、IP電話、および内線としての各アナログアダプタ (1)、ETH0/FXO/FXSインターフェースを備えたAsteriskサーバー (3)、およびVoIPプロバイダーまたはブロードバンド回線を介したPSTNへのトランク (2)。]((../images/04-first-pbx-fig01.png))

1. extensionの設定
   - a. SIP extension (ATA、softphone、IP電話)
   - b. IAX extension
   - c. FXS extension
2. trunkの設定
   - a. SIP trunkの設定
   - b. FXO trunkの設定
3. 基本的なdialplanの構築
   - a. extension間での通話
   - b. 外部の宛先への発信
   - c. オペレーターのextensionでの着信
   - d. 自動応答（IVR）での着信

## extensionの構成

extensionは、SIP、IAX、またはFXSポートに接続されたアナログ電話機です。extensionを構成するには、チャネルに関連する設定ファイル（pjsip.conf、iax.conf、chan_dahdi.conf）を編集する必要があります。

### SIP extension

Asterisk 22では、PJSIP（`res_pjsip`スタック、設定は`/etc/asterisk/pjsip.conf`）がSIPチャネルドライバとなります。これはエンドポイントごとに複数のトランスポートをサポートし、活発にメンテナンスされており、プラットフォームに同梱される唯一のSIPドライバです。（オリジナルの`chan_sip`ドライバはAsterisk 21で削除されました。古い設定を移行する必要がある場合は、*Legacy channels*の章を参照してください。）

ここでの目的は、シンプルなPBXを構成することです。（以降の章で、SIP/PJSIPセッションの全詳細を解説します。）PJSIPは`/etc/asterisk/pjsip.conf`で構成され、SIP電話機およびVoIPプロバイダーに関連するすべてのパラメータを保持します。通話の発着信を行うには、あらかじめSIPクライアントを設定しておく必要があります。

#### トランスポート

PJSIPでは、リスナー設定（バインドアドレス、ポート、プロトコル）は`transport`オブジェクト内に存在します。Asteriskにはユーザー名の推測に対する組み込みの保護機能があり、不明なユーザーと既知のユーザーに対して常に同一の認証チャレンジを返します。また、同一IPからの繰り返される未識別リクエストは、`[global]`オプションの`unidentified_request_count`/`unidentified_request_period`によってレート制限されます。トランスポートの主なオプションは以下の通りです。

- protocol: トランスポートプロトコル — `udp`、`tcp`、`tls`、`ws`、または`wss`。
- bind: リスナーがバインドするアドレスとポート。アドレスを`0.0.0.0`に設定すると、すべてのインターフェースにバインドされます。SIPポートはUDP/TCPともにデフォルトで5060です。

最小限のUDPトランスポート設定例：

```
[global]
type=global

[transport-udp]
type=transport
protocol=udp
bind=10.1.30.45:5060
```

コーデックの選択（`disallow`/`allow`）およびデフォルトの`context`は、トランスポートではなく、各`endpoint`（下記参照）で設定されます。匿名/ゲスト通話は`anonymous`という名前の`endpoint`によって処理されます。登録タイマーは、AORごとに`maximum_expiration`/`default_expiration`を介して制御されます。

#### SIPクライアント

トランスポートセクションの完了後、SIPクライアントを設定します。本書の後の章でSIP/PJSIPについて詳しく解説しますが、ここでは基本に集中し、詳細は後回しにします。

PJSIPにおいて、SIPクライアントは名前参照によって結び付けられた一連の関連オブジェクトから構築されます。

- `endpoint`: 通話動作 — コーデック（`allow`/`disallow`）、dialplanの`context`、および使用する`auth`と`aors`。
- `auth`: 資格情報。`username`はSIP認証ユーザー名であり、`password`はデバイスの認証に使用されるシークレットです。
- `aor`: 「Address of Record（AOR）」 — エンドポイントへの到達先。固定IP上のデバイス用の静的な`contact=`、またはデバイスが動的に登録できるようにする`max_contacts=`のいずれかです。

警告: 8文字以上で、英数字と記号を少なくとも1つ含んだ強力なパスワードを使用してください。メーリングリストではサーバーがハッキングされたという報告が上がっており、SIP用のブルートフォースパスワードクラッカーはスクリプトキディでも容易に入手可能です。通話詐欺は、消費者やプロバイダーに数千ドルの損害を与える可能性があります。

エンドポイント6000は固定IP上のデバイスであるため、そのAORは登録を許可する代わりに静的な`contact`を保持します。エンドポイント6001は登録を行うデバイスであるため、そのAORは登録を許可します（`max_contacts=1`）：

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

PJSIPでは、`endpoint`、`auth`、および`aor`セクションで同じセクション名を使用できます（例：上記の2つの`[6001]`ブロックは、その`type=`によって区別されます）。多くの管理者は、読みやすさのためにサフィックス（`[6001]`、`[6001-auth]`、`[6001]` aorなど）を付けます。登録を行うデバイスの場合、コンタクト情報は電話機が登録する際に動的に学習されるため、AORに静的な`contact`は不要です。

## IAX Extensions

`chan_iax2` は Asterisk 22 にも同梱されていますが、現在はレガシーな扱いとなっており、新規導入には SIP/PJSIP が推奨されるプロトコルです。

IAX extension を作成することも可能です。このプロトコルは Asterisk ネイティブなものであり、本書の後半で丸ごと1セクションを割いて解説します。ここでは、このプロトコルを使用していくつか extension を作成してみましょう。最初に設定するセクションとして、[general] セクションには設定すべき特定のパラメータがあります。主なオプションは以下の通りです。

- allow/disallow: 使用する codec を定義します。
- bindaddr: IAX2 リスナーがバインドするアドレスです。0.0.0.0 (デフォルト) に設定すると、すべてのインターフェースにバインドされます。
- context: クライアントセクションで変更されない限り、すべてのクライアントに対するデフォルトの context を設定します。セキュリティ上の理由から dummy を使用しました。allowguest オプションが yes に設定されている場合、認証されていないユーザーはこの context に入ります。
- bindport: リッスンする IAX2 UDP ポートです (デフォルトは 4569)。
- delayreject: yes に設定すると、REGREQ または AUTHREQ に対する認証拒否の送信を遅延させ、ブルートフォースパスワード攻撃に対するセキュリティを向上させます。
- bandwidth: high に設定すると、ulaw や alaw といった g711 のバリエーションなど、高帯域幅の codec を選択できるようになります。

以下は iax.conf ファイルの [general] セクションのサンプルです。

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

### IAX Clients

general セクションの設定が完了したら、次は IAX client を設定します。

- `[name]`: セクション名は IAX peer/user 名です。着信した IAX 接続は、名前によってこれと照合されます。
- `type`: 接続クラス — `peer`、`user`、または `friend` です。
  - `peer`: Asterisk が peer に通話を発信します。
  - `user`: Asterisk が user からの通話を受信します。
  - `friend`: 両方向を同時に行います。
- `host`: IP アドレスまたはホスト名です。最も一般的な値は `dynamic` で、デバイスが Asterisk に登録する際に使用されます。
- `secret`: peer および user を認証するためのパスワードです。

警告: 8文字以上で、英数字と記号を少なくとも1つ含んだ強力なパスワードを使用してください。メーリングリストではサーバーがハッキングされたという報告が上がっており、IAX md5 ハッシュに対するブルートフォースパスワードクラッカーがスクリプトキディ向けに出回っています。国際電話詐欺（Toll fraud）は、消費者やプロバイダーに数千ドルの損害をもたらします。例:

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

## SIPデバイスの設定

Asteriskの設定ファイルで電話機を定義した後、電話機本体の設定を行う必要があります。この例では、無料のsoftphoneであるSipPulse Softphoneの設定方法を紹介します（https://www.sippulse.com/produtos/softphone からダウンロードしてください）。お使いのデバイスのマニュアルを確認し、電話機のパラメータを理解してください。ステップ1：extension 6000を使用するように電話機を設定します。インストールプログラムを実行してください。実行後、アカウント/SIP設定を開き、新しいSIPアカウントを追加します。必要な情報を入力してください。

![SipPulse Softphoneのアカウント画面 — Server（AsteriskのIPまたはドメイン）、User Name、Password、Display Nameを入力し、Transport（UDP、TCP、またはTLS）を選択します。](../images/softphone/sipphone-account.png){width=35%}

Display Name: 6000  User Name: 6000  Password: #MySecret1#7  Authorization User Name: 6000  Domain: ip_of_your_server。コンソールコマンド `pjsip show endpoints`（または詳細を表示する `pjsip show endpoint 6000`。登録されているAORの連絡先を表示する `pjsip show contacts`）を使用して、電話機が登録されていることを確認してください。電話機6001についても同様の設定を繰り返します。

![登録済みのSipPulse Softphone — 緑色の点とアカウント行（`1001@softphone.sippulse.com.br`）が登録完了を示しています。キーパッドまたは通話/ビデオボタンから発信してください。](../images/softphone/sipphone-registered.png){width=35%}

## IAXデバイスの設定

IAX2はレガシープロトコルであり（*Legacy channels*の章を参照）、SipPulse SoftphoneはSIP専用であるため、IAXアカウントを登録することはできません。IAX2をテストする必要がある場合は、現在もIAX2をサポートしているソフトフォンを使用してください。新しいIAXアカウントを作成します。

3. 新しいIAXアカウントを選択します。
4. 6003番の電話機に関連するオプションを挿入し、必要に応じて6004番についても同様に行います。
5. 設定を保存し、電話機が登録されているかどうかを`iax2 show peers`を使用して確認します。

重要：SIP用とIAX用にそれぞれ別のアカウントを使用してください。IAXとSIPの両方を同時に鳴らすようにシステムを設定したい場合は、dialplanのセクションでその方法を説明します。

### PSTNインターフェースの設定

PSTNに接続するには、foreign exchange office (FXO)インターフェースと電話回線が必要です。既存のPBXのextensionを使用することも可能です。FXOインターフェースを備えたテレフォニーインターフェースカードは、複数のメーカーから入手できます。この例では、DAHDIインターフェースカードのインストール方法を説明します。

![FXSポートとFXOポート：FXSポートはアナログ電話機を駆動し（ダイヤルトーンと呼び出し音を供給）、FXOポートはAsteriskを電話会社の回線に接続します。]((../images/04-first-pbx-fig02.png))

### DAHDIを使用したアナログ回線

DAHDIと互換性のあるアナログカードは、複数のメーカーから購入できます。X100PはDigiumの最初のカードの1つでしたが、すでに製造中止になっています。一部のメーカーは現在も同様のクローンを製造しています。X100Pの価格に加え、これらのカードと新しいマザーボードの間にはいくつかの問題が見つかっているため、使用には注意が必要です。私の意見では、X100Pは本番環境には適していません。DAHDIと互換性のあるカードであれば動作するはずです。DAHDI開発者チームのおかげで、現在ではインターフェースカードをほぼ自動的に検出および設定するツールが用意されています。DAHDIドライバーをインストールしたばかりの場合は、make configを実行し、マシンを再起動して自動的に読み込ませることを忘れないでください。以下のコマンドを使用して、カードの検出と設定を行うことができます。ステップ1：ハードウェアを検出するには、以下を使用します。

```
dahdi_hardware
```

ステップ2：設定を行うには、以下を使用します。

```
dahdi_genconf
```

上記のコマンドは、/etc/dahdi/system.confと/etc/asterisk/dahdi-channels.confの2つのファイルを生成します。dahdi_genconfのデフォルトパラメータで通常は問題ありませんが、/etc/dahdi/genconf_parametersファイルで変更することも可能です。デフォルトでは、回線（FXO）がcontextのfrom-pstnに、電話機（FXS）がcontextのfrom-internalに挿入されます。ステップ3：dahdi_genconfを実行した後、/etc/asterisk/chan_dahdi.confファイルの最後の行に、以下の行を挿入します。

```
#include dahdi-channels.conf
```

ステップ4：/etc/dahdi/modulesファイルを編集し、使用していないすべてのドライバーをコメントアウトします。続行する前に再起動し、以下のコマンドを使用してチャンネルが認識されているか確認してください。

```
*CLI> dahdi show channels
```

### VoIPプロバイダーを使用したPSTNへの接続

予算が非常に限られている場合は、SIP trunkを設定してPSTNに接続することができます。これは、PSTNに接続するための最も手頃な方法であることは間違いありません。世界中には何千ものVoIPプロバイダーが存在します。それらのいずれかに接続するには、いくつかのパラメータが必要です。SIPプロバイダーから提供されるパラメータは以下の通りです。

- username: login
- password: secret
- Provider’s domain: domain
- UDP port: 5060
- Allowed codecs: g729, ilbc, alaw

以下の2つのパラメータは、自身で決定する必要があります。

- 通話を受信するためのextension—この場合は: 9999
- context: from-sip

PJSIPでは、登録型のSIP trunkはendpointに使用されるのと同じオブジェクトファミリーに加え、明示的な`registration`および`identify`オブジェクトから構築されます。`registration`オブジェクトはAsteriskに対してプロバイダーへの登録を指示し、`identify`オブジェクトはプロバイダーのIPからendpointへの着信トラフィックを照合し（PJSIPは送信元IPによって着信INVITEを認証します）、`outbound_auth`は発信通話と登録のための認証情報を提供します。

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

このtrunkにアクセスするには、チャンネル名`PJSIP/siptrunk`を使用します。`dtmf_mode=rfc4733`設定はDTMFを帯域外で伝送します（RFC 4733は古いRFC 2833を廃止しましたが、ペイロードは同一です）。`identify`/`match`オプションはIPアドレス、CIDR、またはホスト名を受け入れますが、ホスト名は設定読み込み時に一度だけ解決されるため、IPが変更されるプロバイダーの場合は、シグナリングIPを明示的にリストしてください。`pjsip show registrations`を使用して登録を確認します。

## Dial planの概要

Dial planはAsteriskの心臓部のようなものです。これは、PBXへのすべての通話をAsteriskがどのように処理するかを定義するものです。Dial planは、Asteriskが従うべき命令リストを作成するextensionで構成されています。命令は、チャネルまたはアプリケーションから受信した数字によって実行されます。Asteriskを正しく設定するためには、Dial planを理解することが不可欠です。Dial planの大部分は、/etc/asteriskディレクトリにあるextensions.confファイルに含まれています。このファイルは単純なグループ文法を使用しており、以下の4つの主要な概念があります。

- Extensions
- Priorities
- Applications
- Contexts

基本的なDial planを作成してみましょう。本書の後のセクションで、Dial plan専用の章を設けます。サンプルファイル（make samples）をインストール済みの場合、extensions.confはすでに存在します。別の名前で保存し、空のファイルから始めてください。

## extensions.conf ファイルの構造

extensions.conf ファイルはセクションに分かれています。最初は [general] セクションで、その後に [globals] セクションが続きます。各セクションの開始は名前の定義（例: [default]）によって示され、別のセクションが作成されるまでがその範囲となります。

### [general] セクション

general セクションはファイルの一番上に配置されます。dialplan の設定を開始する前に、dialplan の特定の動作を制御する一般的なオプションを知っておくと便利です。これらのオプションは以下の通りです。

- static および write protect: `static=yes`かつ`writeprotect=no`の場合、実行中の dialplan を CLI コマンドでディスクに保存できます。

```
*CLI> dialplan save
```

警告: CLI から`dialplan save`コマンドを実行すると、ファイル内の備考やコメントがすべて失われます。

- autofallthrough: autofallthrough が設定されている場合、extension で実行する処理がなくなると、Asterisk の判断に基づいて BUSY、CONGESTION、または HANGUP で通話を終了します。これがデフォルトの動作です。autofallthrough が設定されていない場合、extension で実行する処理がなくなると、Asterisk は新しい extension がダイヤルされるのを待機します。
- clearglobalvars: clearglobalvars が設定されている場合、dialplan reload または Asterisk reload が実行されると、グローバル変数はクリアされ、再解析されます。clearglobalvars が設定されていない場合、グローバル変数はリロード後も保持され、extensions.conf やそのインクルードファイルから削除されたとしても、以前の値が設定されたままになります。
- extenpatternmatchnew: より高速なパターンマッチングアルゴリズムを使用します。これは、多数の extension がある場合に顕著な効果を発揮します。デフォルトは no です。
- userscontext: これは users.conf からのエントリが登録される context です。

### [globals] セクション

[globals] セクションでは、グローバル変数とその初期値を定義します。dialplan 内では ${GLOBAL(variable)} を使用して変数にアクセスできます。また、${ENV(variable)} を使用して linux/unix 環境で定義された変数にアクセスすることも可能です。グローバル変数は大文字と小文字を区別しません。いくつかの例を以下に示します。

```
INCOMING=>DAHDI/8&DAHDI/9
RINGTIME=>3
```

次の例では、dialplan 内でグローバル変数を設定およびテストする方法を示します。

```
exten=9000,1,set(GLOBAL(RINGTIME)=4)
exten=9000,n,Noop(${GLOBAL(RINGTIME)})
exten=9000,n,hangup()
```

## Contexts

Context は dialplan の名前付きパーティションです。 [general] セクションと [globals] セクションの後、 dialplan は一連の context で構成されます。各 context は複数の extension を持ち、各 extension は複数の priority を持ち、各 priority は複数の引数を伴うアプリケーションを呼び出します。

![Asterisk の通話フロー: すべての通話は着信レグとしてチャネル (IAX、 SIP など) に到着します。チャネルの context (グローバルまたはチャネル設定ファイルでチャネルごとに設定) によって、通話が発信レグへ向かう前に extensions.conf 内のどの context がその通話を処理するかが決定されます。](images/call_flow.png){width=100%}(../images/04-first-pbx-fig03.png)

![通話処理: チャネルに対して定義された `context=` (chan_dahdi.conf または pjsip.conf 内) は、 dialplan が通話を処理する extensions.conf 内の対応する context を指定します。](images/call_processing.png){width=100%}(../images/04-first-pbx-fig04.png)

他の電話機や PSTN に接続するためのシンプルな dialplan を構築することは可能です。しかし、 Asterisk はそれよりもはるかに強力です。本書の目的は、 dialplan で何が可能かについて、より詳細な知識を提供することです。

## Extensions

従来のPBXでは、extensionは電話機、インターフェース、メニューなどに関連付けられていますが、Asteriskにおけるextensionとは、特定のextension番号や名前がトリガーされた際に処理されるコマンドのリストを指します。コマンドは優先順位（priority）に従って処理されます。

![Extensionの構文: `exten => number(name),{priority|label}[(alias)],application`。extensionは数値、英数字、発信者番号付きの数値、パターン、あるいは`s`のような標準的なextensionにすることができます。priorityは数値、`n`（次）、`s`（同じ）、オフセット、または`hint`を指定できます。](../images/04-first-pbx-fig05.png)

extensionは、リテラル、標準、または特殊なものに分類されます。標準的なextensionには、数字や名前、および * や # 文字のみが含まれます。12#89* は有効なリテラルextensionです。名前もextensionのマッチングに使用できます。extensionは大文字と小文字を区別します。ただし、同じ名前で大文字と小文字が異なる2つのextensionを作成することはできません。extensionがダイヤルされると、priority 1のコマンドが実行され、続いてpriority 2のコマンドが実行される、という順序で進みます。これは、通話が切断されるか、いずれかのコマンドが1を返して失敗を示すまで続きます。最後のpriorityが実行された後にAsteriskが何を行うかは、autofallthroughパラメータによって制御されます。本章の [general] セクションを参照してください。例：

```
exten=>123,1,Answer
exten=>123,n,Playback(tt-weasels)
exten=>123,n,Hangup
```

上記は、extension 123 がダイヤルされた際に処理される命令リストです。最初のpriorityはチャネルに応答することです（チャネルが呼び出し状態にある場合、つまりFXOチャネルなどで必要となります）。2番目のpriorityは tt-weasels という音声ファイルを再生することです。3番目のpriorityはチャネルを切断します。もう一つの選択肢として、発信者番号（caller ID）に基づいて通話を処理する方法があります。/ 文字を使用して、処理対象の発信者番号を指定できます。例：

```
exten=>123/100,1,Answer()
exten=>123/100,n,Playback(tt-weasels)
exten=>123/100,n,Hangup()
```

この例では、extension 123 がトリガーされ、発信者番号が 100 の場合にのみ、以下のオプションが実行されます。これは、以下に説明するパターンを使用することでも実現可能です：

```
exten=>1234/_256NXXXXXX,1,Answer()
```

hint: extensionをチャネルにマッピングします。これはチャネルの状態を監視するために使用されます。プレゼンス（presence）と組み合わせて使用されます。電話機側がこれをサポートしている必要があります。

#### Patterns

dialplanではパターンとリテラルを使用できます。パターンはdialplanのサイズを削減するのに非常に役立ちます。すべてのパターンは "_" 文字で始まります。パターンを定義するには、以下の文字を使用できます。図はAsteriskで使用可能なパターンを示しています。

![パターンマッチング文字: `_`はパターンの開始、`.`は1文字以上にマッチ、`!`は0文字以上にマッチ、`[123-7]`はリストされた数字や範囲にマッチ、`X`は0-9、`Z`は1-9、`N`は2-9を表します。オフィス内のextension範囲をマッピングする例も示されています。](../images/04-first-pbx-fig06.png)

### Special extensions

Asteriskでは、いくつかのextension名を標準的なextensionとして使用します。

![Asteriskの特殊なextension: `i` (invalid)、`s` (start)、`h` (hangup)、`t` (timeout)、`T` (absolute timeout)、`o` (operator)、`a` (voicemail中の`*`押下)、`fax` (fax検出)、および`Talk` (BackgroundDetectで使用)。](../images/04-first-pbx-fig07.png)

説明：

- **s**: Start。ダイヤルされた番号がない場合に通話を処理するために使用されます。FXO trunkやメニュー内での処理に便利です。
- **t**: Timeout。プロンプトが再生された後、通話が非アクティブな状態が続いた場合に使用されます。また、非アクティブな回線を切断するためにも使用されます。
- **T**: AbsoluteTimeout。dialplan関数の`TIMEOUT(absolute)`を使用して通話制限を設定した場合、通話が定義された制限時間を超えると、T extensionに送られます。
- **h**: Hangup。ユーザーが通話を切断した後に呼び出されます。
- **i**: Invalid。コンテキスト内に存在しないextensionが呼び出されたときにトリガーされます。これらのextensionを使用すると、CDRレコードの内容、具体的にはダイヤルされた番号が含まれない dst フィールドに影響を与える可能性があります。
- **o**: Operator。ユーザーがvoicemail中に "0" を押した際にオペレーターへ転送するために使用されます。

これらのextensionを使用すると、課金記録（CDR）の内容が変化する可能性があります。特に、dst フィールドにはダイヤルされた番号が記録されません。この問題を回避するには、dial() アプリケーションのオプション g を使用し、resetcdr(w) 関数や nocdr() 関数を検討してください。

## Variables

Asterisk PBXでは、変数はグローバル、チャネル固有、および環境固有のものに分類されます。NoOP() アプリケーションを使用すると、コンソールで変数の内容を確認できます。これは、アプリケーションの引数としてグローバル変数またはチャネル固有変数のいずれかを使用できます。変数は以下の例のように参照でき、varname は変数名となります。

```
${varname}
```

変数名は、英字で始まる英数字の文字列にすることができます。グローバル変数名は、大文字と小文字を区別しません。しかし、システム変数（Asterisk定義のものやチャネル定義のもの）は、大文字と小文字を区別します。したがって、変数 ${EXTEN} は ${exten} とは異なります。

### Global variables

グローバル変数は、extensions.conf ファイルの [global] セクションで設定するか、以下のアプリケーションを使用して設定できます。

```
set(Global(variable)=content)
```

### Channel-specific variables

チャネル固有変数は、set() アプリケーションを使用して設定されます。各チャネルは独自の変数領域を持ちます。異なるチャネル間での変数衝突の可能性はありません。チャネル固有変数は、チャネルがハングアップしたときに破棄されます。最も一般的に使用される変数には、以下のようなものがあります。

- ${EXTEN} ダイヤルされた extension
- ${CONTEXT} 現在の context
- ${CALLERID(name)}
- ${CALLERID(num)}
- ${CALLERID(all)} 現在の caller ID
- ${PRIORITY} 現在の priority

その他のチャネル固有変数はすべて大文字です。dumpchan() アプリケーションを使用すると、いくつかの変数の内容を確認できます。以下は、dump-channel 変数の単純な抜粋です。

```
exten=9001,1,DumpChan()
exten=9001,n,Echo()
exten=9001,n,Hangup()
```

Dumpchan の出力:

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

上記のフィールドレイアウトは Asterisk 22 の `DumpChan` 出力です（実際の `PJSIP/...` チャネル名、`CallerIDNum`/`ConnectedLineID` フィールド、および PJSIP チャネルが入力する `Raw*`/`Transcode`/`BridgeID` 行）。古いドライバとは異なり、PJSIP チャネルは `SIPCALLID`/`SIPUSERAGENT` チャネル変数を自動設定しません。同等の SIP 詳細情報は、必要に応じて `PJSIP_HEADER()` および `CHANNEL()` dialplan 関数で読み取ります。例えば、リモート RTP アドレスについては `${CHANNEL(pjsip,call-id)}`、 `${PJSIP_HEADER(read,User-Agent)}`、および `${CHANNEL(rtp,dest)}` を使用します。

### Environment-specific variables

環境固有変数は、オペレーティングシステムで定義された変数にアクセスするために使用できます。ENV() 関数を使用して環境固有変数を設定できます。例:

```
${ENV(LANG)}
Set(ENV(LANG)=en_US)
```

### Application-specific variables

一部のアプリケーションは、データの入力および出力に変数を活用します。アプリケーションを呼び出す前に変数を設定したり、アプリケーション実行後に変数を取得したりできます。例: Dial アプリケーションは、以下の変数を返します。

- ${DIALEDTIME} -> チャネルをダイヤルしてから切断されるまでの時間です。
- ${ANSWEREDTIME} -> 実際の通話時間です。
- ${DIALSTATUS} 通話のステータスです: o CHANUNAVAIL o CONGESTION o NOANSWER o BUSY o ANSWER o CANCEL o DONTCALL o TORTURE
- ${CAUSECODE} -> 通話のエラーメッセージです。

## Expressions

Expressions は dialplan において非常に有用です。これらは文字列の操作や、数学的および論理的な演算を実行するために使用されます。

![Asterisk expressions overview — `$[expression1 operator expression2]` — dialplan で利用可能な数学、論理、比較、正規表現、および条件演算子をグループ化したもの。]((../images/04-first-pbx-fig08.png))

expression の構文は次のように定義されます。

```
$[expression1 operator expression2]
```

「I」という名前の変数があり、その変数に 100 を加算したいと仮定します。

```
$[${I}+100]
```

Asterisk が dialplan 内で expression を見つけると、その expression 全体を計算結果の値に置き換えます。

### Operators

expression を構築するには、以下の演算子を使用できます。演算子の優先順位に注意することが重要です。

1. 括弧 “()”
2. 単項演算子 “! -“
3. 正規表現 “: =~
4. 乗法演算子 “* / %”
5. 加法演算子 “+ -“
6. 比較演算子
7. 論理演算子
8. 条件演算子

#### Math Operators

- 加算 (+)
- 減算 (-)
- 乗算 (*)
- 除算 (/)
- 剰余 (%)

#### Logical Operators

- 論理 “AND” (&)
- 論理 “OR” (|)
- 論理単項補数 (!)

#### Regular expression operators

- 正規表現マッチング (:)
- 正規表現完全一致 (=~)

正規表現とは、検索パターンを記述するために使用される特殊なテキスト文字列です。正規表現はワイルドカードのようなものだと考えることができます。正規表現は、文字列をパターンと照合して一致を確認するために使用されます。一致が成功し、正規表現に少なくとも1つのマッチが含まれている場合、最初の一致が返されます。それ以外の場合は、一致した文字数が返されます。

#### Comparison operators

比較の結果は、関係が真であれば 1、偽であれば 0 となります。

- = 等しい
- != 等しくない
- < より小さい
- > より大きい
- <= 以下
- >= 以上

### LAB. Evaluate the following expressions:

これらの expression を dialplan に記述し、NoOP() アプリケーションを使用して expression を評価してください。9002 にダイヤルし、Asterisk コンソールで結果を確認してください。結果を表示するには verbose 15 を使用します。

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

## Functions

一部のアプリケーションは関数に置き換えられました。関数を使用することで、式だけを用いるよりも高度な方法で変数を処理できます。以下のコンソールコマンドを実行すると、関数の全リストを確認できます。

```
*CLI> core show functions
```

文字列の長さ: ${LEN(string)} は文字列の長さを返します。

```
Example:
exten=>100,1,Set(Fruit=pear)
exten=>100,2,NoOp(${LEN(Fruit)})
exten=>100,3,NoOp(${LEN(${Fruit})})
```

最初の操作では、システムは結果として 5 を表示します（「fruit」という単語の文字数）。2番目の操作では 4 を返します（「pear」という単語の文字数）。部分文字列: 「offset」パラメータで定義された位置から開始し、「length」パラメータで定義された長さを持つ部分文字列を返します。オフセットが負の場合、文字列の末尾から左に向かって開始します。長さが省略されたか負の場合、オフセットから始まる文字列全体を取得します。

```
${string:offset:length }
```

例 #1: いくつかの部分文字列

```
${123456789:1}-returns 23456789
${123456789:-4}-returns 6789
${123456789:0:3}-returns 123
${123456789:2:3}-returns 345
${123456789:-4:3}-returns 678
```

例 #2: 最初の3桁から市外局番を取得します。

```
exten=>_NXX.,1,Set(areacode=${EXTEN:0:3})
```

例 #3: 変数 ${EXTEN} から、市外局番を除くすべての数字を取得します。

```
exten=>_516XXXXXXX,1,Dial(${EXTEN:3})
```

### 文字列の連結

2つの文字列を連結するには、単にそれらを並べて記述します。

```
${foo}${bar}
555${number}
${longdistanceprefix}555${number}
```

## Applications

dialplanを構築するには、アプリケーションの概念を理解する必要があります。dialplan内でチャネルを操作するためにアプリケーションを使用します。アプリケーションは複数のモジュールに実装されており、利用可能なアプリケーションはモジュールによって異なります。コンソールコマンドを使用して、すべてのAsteriskアプリケーションを表示できます。

```
*CLI> core show applications
```

あるいは、以下の例のように、特定のアプリケーションの詳細を表示することも可能です。

```
*CLI> core show application Dial
```

単純なdialplanを構築するには、いくつかのアプリケーションを知っておく必要があります。より高度な例については、本書の後半で解説します。

![単純なdialplanを構築するために必要な少数のアプリケーション：Answer（チャネルに応答する）、Dial（別のチャネルを呼び出す）、Hangup（チャネルを切断する）、Playback（音声ファイルを再生する）、Goto（優先度、extension、またはcontextへジャンプする）。](../images/04-first-pbx-fig09.png)

上記のアプリケーションを使用して、2つの基本的なPBX用の単純なdialplanを作成します。

### Answer()

[概要] 呼び出し中のチャネルに応答する [説明] Answer([delay]): 通話が応答されていない場合、このアプリケーションはそれに応答します。それ以外の場合、通話には影響しません。遅延（delay）が指定されている場合、Asteriskは指定されたミリ秒数だけ待機してから通話に応答します。

### Dial()

以下の説明は、dialplan内で show application dial を実行することで取得できます。検索しやすいように、以下に転載します。Dialアプリケーションの構文も以下に示します。

```
;dial to a single channel
Dial(Technology/resource,timeout,options,URL)
;dialing to multiple channels
Dial(Technology/resource[&Tech2/resource2...],timeout,options,URL)
```

このアプリケーションは、指定された1つまたは複数のチャネルに対して発信を行います。要求されたチャネルのいずれかが応答するとすぐに、発信元のチャネルが（まだ応答していない場合）応答状態になります。その後、これら2つのチャネルがブリッジされた通話としてアクティブになります。要求された他のすべてのチャネルは切断されます。タイムアウトが指定されていない限り、Dialアプリケーションは、呼び出されたチャネルのいずれかが応答するか、ユーザーが切断するか、または呼び出されたすべてのチャネルが話中または利用不可になるまで無期限に待機します。要求されたチャネルを呼び出せない場合やタイムアウトが発生した場合は、dialplanの実行が継続されます。このアプリケーションは、完了時に以下のチャネル変数を設定します。

- DIALEDTIME - チャネルへのダイヤル開始から切断されるまでの時間です。
- ANSWEREDTIME - 実際の通話時間です。
- DIALSTATUS - 通話のステータスです： o CHANUNAVAIL o CONGESTION o NOANSWER o BUSY o ANSWER o CANCEL o DONTCALL o TORTURE

プライバシーおよびスクリーニングモードの場合、呼び出された側が発信者を「Go Away」スクリプトに送ることを選択すると、DIALSTATUS変数はDONTCALLに設定されます。呼び出された側が発信者を「torture」スクリプトに送ることを希望する場合、DIALSTATUS変数はTORTUREに設定されます。このアプリケーションは、発信元のチャネルが切断された場合、または通話がブリッジされ、ブリッジ内のいずれかの当事者が通話を終了した場合に、正常終了を報告します。オプションのURLは、チャネルがサポートしている場合に呼び出された側に送信されます。OUTBOUND_GROUP変数が設定されている場合、このアプリケーションによって作成されたすべてのピアチャネルがそのグループに含まれます（以下のように）。

```
Set(GROUP()=...).
```

以下の表は、Dialアプリケーションで最も頻繁に使用されるオプションの一部をまとめたものです。完全なリストについては、コンソールコマンド`core show application Dial`を使用してください。Asterisk 22では、これらのオプションはチャネルやタイムアウトとカンマで区切られます（例：`Dial(PJSIP/2000,20,tTm)`）。

| オプション | 説明 |
|--------|-------------|
| `A(x)` | `x`をファイルとして使用し、呼び出された側にアナウンスを再生します。 |
| `C` | この通話のCDRをリセットします。 |
| `d` | 通話の応答を待っている間に、呼び出し側のユーザーが1桁のextensionをダイヤルできるようにします。そのextensionが現在のcontextに存在する場合はそのextensionへ、存在しない場合は`EXITCONTEXT`変数で定義されたcontextへ移動します。 |
|  | (表内注記: 上記参照) |
| `D([called][:calling])` | 呼び出された側が応答した後、通話がブリッジされる前に指定されたDTMF文字列を送信します。`called`文字列は呼び出された側に、`calling`文字列は呼び出し側に送信されます。いずれかのパラメータのみを使用することも可能です。 |
| `f` | 発信元チャネルのCaller IDを、dialplanの`hint`を介してチャネルに関連付けられたextensionに強制的に設定します。PSTNが任意のCaller IDを許可していない場合に便利です。 |
| `g` | 宛先チャネルが切断された場合、現在のextensionでdialplanの実行を継続します。 |
| `G(context^exten^pri)` | 通話が応答された場合、呼び出し側を指定された優先度へ、呼び出された側を優先度+1へ転送します。オプションでextension（またはextensionとcontext）を指定できます。指定しない場合は現在のextensionが使用されます。 |
| `h` | 呼び出された側が`*`のDTMF桁を送信することで切断できるようにします。 |
| `H` | 呼び出し側が`*`のDTMF桁を送信することで切断できるようにします。 |
| `L(x[:y][:z])` | 通話を`x`ミリ秒に制限し、`y`ミリ秒残った時点で警告を再生し、`z`ミリ秒ごとに警告を繰り返します。以下の`LIMIT_*`変数を参照してください。 |
| `m([class])` | 要求されたチャネルが応答するまで、呼び出し側に保留音（Music on Hold）を提供します。特定のMusicOnHoldクラスを指定できます。 |
| `r` | 呼び出し側に呼び出し音を鳴らし、呼び出されたチャネルが応答するまで音声を流しません。 |
| `S(x)` | 呼び出された側が応答してから`x`秒後に通話を切断します。 |
| `t` | 呼び出された側が`features.conf`で定義されたDTMFシーケンスを送信することで、呼び出し側を転送できるようにします。 |
| `T` | 呼び出し側が`features.conf`で定義されたDTMFシーケンスを送信することで、呼び出された側を転送できるようにします。 |
| `w` | 呼び出された側が`features.conf`で定義されたDTMFシーケンスを送信することで、ワンタッチ録音を有効にできるようにします。 |
| `W` | 呼び出し側が`features.conf`で定義されたDTMFシーケンスを送信することで、ワンタッチ録音を有効にできるようにします。 |
| `k` | 呼び出された側が`features.conf`で定義された通話パーク用DTMFシーケンスを送信することで、通話をパークできるようにします。 |
| `K` | 呼び出し側が`features.conf`で定義された通話パーク用DTMFシーケンスを送信することで、通話をパークできるようにします。 |

`L(x[:y][:z])`オプションは、以下の特別な変数で調整できます。

- `LIMIT_PLAYAUDIO_CALLER` — `yes|no`（デフォルト`yes`）：呼び出し側に音声を再生します。
- `LIMIT_PLAYAUDIO_CALLEE` — `yes|no`：呼び出された側に音声を再生します。
- `LIMIT_TIMEOUT_FILE` — 時間切れの際に再生されるファイルです。
- `LIMIT_CONNECT_FILE` — 通話開始時に再生されるファイルです。
- `LIMIT_WARNING_FILE` — `y`が定義されている場合に警告として再生されるファイルです。デフォルトでは残り時間を読み上げます。

例：

```
exten=_4XXX,1,Dial(PJSIP/${EXTEN},20,tTm)
```

上記の例では、アプリケーションは対応するPJSIPチャネルへダイヤルします。呼び出し側と呼び出された側の両方が通話を転送できます（Tt）。呼び出し音の代わりに保留音が聞こえます。20秒以内に誰も応答しない場合、extensionは次の優先度へ進みます。

### Hangup()

呼び出し側のチャネルを切断する [説明] Hangup([causecode]): このアプリケーションは呼び出し側のチャネルを切断します。原因コード（cause code）が指定された場合、チャネルの切断原因はその値に設定されます。

### Goto()

特定の優先度、extension、またはcontextへジャンプする [説明] Goto([[context|]extension|]priority): このアプリケーションは、呼び出し側のチャネルに、指定された優先度でdialplanの実行を継続させます。特定のextension（またはextensionとcontext）が指定されていない場合、このアプリケーションは現在のextensionの指定された優先度へジャンプします。dialplan内の別の場所へのジャンプが成功しなかった場合、チャネルは現在のextensionの次の優先度で継続します。

## dial plan の構築

シンプルな dial plan を構築するには、context と extension を作成して、すべての着信および発信通話を処理する必要があります。このセクションでは、最も一般的な extension の構築方法を紹介します。

### extension 間の通話

extension 間の通話を有効にするには、ダイヤルされた extension を参照するチャネル変数 ${EXTEN} を使用できます。例えば、extension の範囲が 4000 から 4999 で、すべての extension が SIP を使用している場合、以下のコマンドを採用できます。

```
[from-internal]
exten=_4XXX,1,Dial(PJSIP/${EXTEN})
```

### 外部宛先への通話

外部宛先にダイヤルするには、ダイヤルする番号の前にルートを付けることができます。北米では、9 をダイヤルした後に外部へダイヤルする番号を続けるのが一般的です。PSTN へのアナログまたはデジタルチャネルを使用している場合、コマンドは以下のようになります。DAHDI の代わりに SIP trunk を使用したい場合は、`PJSIP/...@siptrunk` チャネルを使用してください。

```
[from-internal]
exten=_9NXXXXXX,1,Dial(DAHDI/1/${EXTEN:1},20,tT)
or
exten=_9NXXXXXX,1,Dial(PJSIP/${EXTEN:1}@siptrunk,20,tT)
```

上記の行により、9 と目的の番号をダイヤルできるようになります。この例では、最初の DAHDI チャネル (DAHDI/1) を使用します。複数の回線があり、その回線が使用中の場合、通話は完了しません。しかし、以下の行を使用すれば、利用可能な最初の DAHDI チャネルを自動的に選択できます。オプションとして、DAHDI の代わりに SIP trunk を使用することも可能です。PJSIP 形式の `Dial(PJSIP/number@siptrunk,...)` では、ダイヤルされた番号がユーザー部分であり、`siptrunk` は上記で設定された endpoint です。

```
[from-internal]
exten=_9NXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20,tT)
```

“g1” パラメータはグループ内で利用可能な最初のチャネルを検索するため、すべてのチャネルを使用できるようになります。以下の行を使用すると、長距離番号にダイヤルできます。

```
[from-internal]
exten=_91NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20,tT)
```

### 9 をダイヤルして PSTN 回線を取得する

外部へのダイヤルに制限がない場合は、以下のように簡略化できます。

```
[from-internal]
exten=9,1,Dial(DAHDI/g1,20,tT)
```

### オペレーター extension での着信

以下の例では、オペレーターの extension は 4000 です。PSTN 回線は FXO インターフェースに接続されています。chan_dahdi.conf ファイルで指定されている context は from-pstn です。PSTN からのすべての通話は、dial plan 内の context from-pstn にルーティングされます。この回線には direct inward dialing (DID) がないため、通話は “s” extension を介して受信する必要があります。SIP trunk から受信する場合は、context [from-sip] を使用してください。

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

### direct inward dialing (DID) を使用した着信

デジタル回線がある場合、ダイヤルされた extension を受信します。この場合、通話をオペレーターに転送する必要はなく、宛先に直接転送できます。DID の範囲が 3028550 から 3028599 で、下 4 桁が DID で渡されると仮定します。設定は以下の例のようになります。

```
[from-pstn]
exten => _85[5-9]X,1,Answer()
exten => _85[5-9]X,n,Dial(PJSIP/${EXTEN},15,tT)
exten => _85[5-9]X,n,Hangup()
```

### 複数の extension を同時に呼び出す

Asterisk を設定して、ある extension を呼び出し、応答がない場合に他の複数の extension を同時に呼び出すようにすることができます。以下の例を参照してください。

```
exten => 0,1,Dial(DAHDI/1,15,tT)
exten => 0,n,Dial(DAHDI/1&DAHDI/2&DAHDI/3,15)
exten => 0,n,Hangup()
```

この例では、誰かがオペレーターを呼び出すと、最初にチャネル DAHDI/1 が試行されます。15 秒（タイムアウト）経過しても誰も応答しない場合、チャネル DAHDI/1、DAHDI/2、DAHDI/3 が同時にさらに 15 秒間鳴ります。

### Caller ID によるルーティング

この例では、Caller ID に基づいて異なる処理を行うことができます。これは、迷惑電話の発信者に対して有用です。例えば以下の通りです。

```
exten => 8590/4832518888,1,Playback(I-have-moved-to-china)
exten => 8590,1,Dial(DAHDI/1,20)
```

この例では、Caller ID が 4832518888 の場合に、あらかじめ録音されたファイル “I-have-moved-to-china” からメッセージを再生するという特別なルールを追加しました。その他の通話は通常通り受け入れられます。

### dial plan での変数の使用

Asterisk は、特定のアプリケーションの引数として、dial plan 内でグローバル変数およびチャネル変数を使用できます。以下の例を見てください。

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

変数を使用すると、将来の変更が容易になります。変数を変更すれば、すべての参照先が即座に変更されます。

### アナウンスの録音

このセクションの後半で説明するいくつかのオプションでは、録音されたプロンプトを使用します。ここでは、それらを録音する簡単な方法を紹介します。Record() アプリケーションを使用して、自分の電話からアナウンスを保存します。

```
[from-internal]
exten => _record.,1,Record(${EXTEN:6}:gsm)
exten => _record.,n,wait(1)
exten => _record.,n,Playback(${EXTEN:6})
exten => _record.,n,Hangup()
```

これらの指示により、softphone から任意のメッセージを録音できます。例：softphone から recordmenu をダイヤルする。この指示は、最初の 6 文字を除いた変数 ${EXTEN:6} で録音を呼び出します。言い換えれば、この指示は record(menu:gsm) と同等です。record + 録音するファイル名 をダイヤルし、# を押して録音を終了し、録音内容が再生されるのを待つだけです。

### デジタル受付での着信

いくつかの簡単な例を見たところで、background() および goto() アプリケーションについての学習を広げましょう。Asterisk における対話型システムの鍵は background() アプリケーションです。これにより、音声ファイルを再生し、発信者がキーを押したときにそれを中断して、ダイヤルされた extension に通話を送信できます。background() アプリケーションの構文は以下の通りです。

```
exten=>extension, priority, background(filename)
```

もう一つ非常に便利なアプリケーションが goto() です。名前が示す通り、指定された context、extension、priority にジャンプします。goto() アプリケーションの構文は以下の通りです。

```
exten=>extension, priority,goto(context, extension, priority)
```

goto() コマンドの有効な形式は以下の通りです。

```
goto(context,extension,priority)
goto(extension,priority)
goto(priority)
```

以下の例では、デジタル受付を作成します。extensions.conf ファイルを編集して、以下の extension を設定するのは非常に簡単です。

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

SIP extension は `PJSIP/` を使用し、IAX extension は `IAX2/` を使用します。どちらのドライバーも Asterisk 22 に同梱されていますが、`chan_iax2` は現在レガシーとみなされており、SIP/PJSIP が推奨されています。

menu1.gsm ファイルに、“extension を押すか、オペレーターをお待ちください” というメッセージを録音してください。ユーザーが 6000 をダイヤルすると、extension 6000 に送信されます。この時点で、answer()、background()、goto()、hangup()、playback() を含むいくつかのアプリケーションの使用方法を明確に理解できているはずです。もし明確に理解できていない場合は、内容に慣れるまでこの章を読み直してください。background アプリケーションは非常に頻繁に使用することになります。extension、priority、アプリケーションの基本を理解すれば、シンプルな dial plan を作成するのは簡単です。これらの概念については本書の後半でより深く掘り下げていき、dial plan がより強力になることを実感できるでしょう。

## まとめ

本章では、設定ファイルが /etc/asterisk ディレクトリに格納されていることを学びました。Asterisk を使用するには、まずチャネル（例: PJSIP、DAHDI、IAX）を設定する必要があります。設定ファイルには、単純グループ、オブジェクト継承、複雑なエンティティという3つの異なる文法が存在します。dialplan は extensions.conf ファイル内に作成され、context と extension の集合体です。dialplan 内では、各 extension がアプリケーションをトリガーします。また、playback、background、dial、goto、hangup、answer といったアプリケーションの使用方法についても学びました。

## クイズ

1. チャネル設定ファイルは以下の通りです（該当するものをすべて選択してください）：
   - A. `/etc/asterisk/chan_dahdi.conf`
   - B. `/etc/asterisk/pjsip.conf`
   - C. `/etc/asterisk/iax.conf`
   - D. `/etc/asterisk/extensions.conf`
2. Asterisk 22において、単一の `chan_sip` ピア（`[6001]`）（`type=friend`/`host=dynamic`）は、 `pjsip.conf` ではどの関連オブジェクトのセットに置き換えられますか？
   - A. `type=peer` と `type=user`
   - B. `type=endpoint`、 `type=auth`、 および `type=aor`
   - C. 単一の `type=friend`
   - D. `type=transport` と `type=global`
3. チャネル設定ファイルで context を定義することは、そのチャネルからの着信に対する着信先 context を設定するため重要です。つまり、そのチャネルからの通話は `extensions.conf` 内の該当する context で処理されます。
   - A. 真
   - B. 偽
4. `Playback()` アプリケーションと `Background()` アプリケーションの主な違いは以下の通りです（2つ選択してください）：
   - A. Playback はプロンプトを再生しますが、ダイヤル入力を待ちません。
   - B. Background はプロンプトを再生しますが、ダイヤル入力を待ちません。
   - C. Background はメッセージを再生し、ダイヤル入力が押されるのを待ちます。
   - D. Playback はメッセージを再生し、ダイヤル入力が押されるのを待ちます。
5. DID を持たないテレフォニーインターフェースカード（FXO）を介して Asterisk に通話が入ってきた場合、それは特別な extension で処理されます：
   - A. `0`
   - B. `9`
   - C. `s`
   - D. `i`
6. `Goto()` アプリケーションの有効なフォーマットは以下の通りです（3つ選択してください）：
   - A. `Goto(context,extension,priority)`
   - B. `Goto(priority,context,extension)`
   - C. `Goto(extension,priority)`
   - D. `Goto(priority)`
7. パターン `_7[1-5]XX` は以下にマッチします（該当するものをすべて選択してください）：
   - A. 7100
   - B. 7600
   - C. 7630
   - D. 7230
8. `Dial(PJSIP/${EXTEN},20,tTm)` において、 `m` オプションは何を行いますか？
   - A. 通話時間を最大時間に制限する。
   - B. チャネルが応答するまで、呼び出し音の代わりに保留音（Music on Hold）をかける。
   - C. 呼び出し先が応答した後に DTMF を送信する。
   - D. dialplan の hint を使用して発信者番号を強制する。
9. `chan_dahdi.conf` で使用されるオプション継承文法では、以下のことを行います：
   - A. オブジェクトを1行で定義する。
   - B. 最初にオプションを定義し、その定義されたオプションの下にオブジェクトを宣言する。
   - C. オブジェクトごとに個別の context を定義する。
10. extension 内の優先度（priority）は連続した番号（1, 2, 3, …）である必要があり、 `n` を使用することはできません。
    - A. 真
    - B. 偽

**回答:** 1 — A, B, C · 2 — B · 3 — A · 4 — A, C · 5 — C · 6 — A, C, D · 7 — A, D · 8 — B · 9 — B · 10 — B
