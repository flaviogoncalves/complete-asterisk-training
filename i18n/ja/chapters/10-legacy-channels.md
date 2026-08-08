# レガシーチャネル: アナログ、TDM、IAX2

2026年のVoIPが主流の世界において、本章で扱うチャネルタイプはますます希少なものとなっています。新規導入のほとんどはEthernet経由のSIP trunkおよびPJSIP endpointであり、電話用ハードウェアを一切使用しない構成が一般的です。それにもかかわらず、Asterisk 22はこれらのほとんどを完全にサポートしています。アナログ（FXO/FXS）およびデジタルTDM（E1/T1/ISDN PRI/BRI）の接続は、DAHDIを通じて提供されます。これは元々Digiumによって開発されたドライバスタックであり、商標紛争を経てZaptelドライバが改称された後、2018年にSangomaによって買収されました。IAX2によるサーバー間接続は`chan_iax2`によって提供されます。これは現在も同梱・サポートされていますが、今日では完全にレガシーなプロトコルとなっています。

本章では、**レガシーSIP**に関する資料もまとめています。Asterisk 21で削除され、Asterisk 22では存在しない古い`chan_sip`ドライバとその`sip.conf`設定に加え、既存の`sip.conf`システムをPJSIPへ移行するための完全ガイドを掲載しています。もし、電話用カードやIAX2 trunkを使用せず、変換すべきレガシーな`sip.conf`も存在しない、純粋なPJSIPベースのSIP環境で運用している場合は、本章を読み飛ばしても問題ありません。

## Objectives

この章を読み終えることで、以下のことができるようになります。

- DAHDI を介して FXO/FXS インターフェースで Asterisk をアナログ回線および電話機に接続する。
- デジタル TDM 接続（E1/T1、ISDN PRI/BRI）を認識し、その設定方法を理解する。
- サーバー間 trunk 用に IAX2（`chan_iax2`）を設定し、なぜ現在それがレガシーとなっているのかを理解する。
- 引退した`chan_sip`ドライバと、現在でも遭遇する可能性のある`sip.conf`構文を識別する。
- 既存の`chan_sip`/`sip.conf`システムを PJSIP に移行する。

## アナログチャネル (FXO/FXS)

Asterisk 22の時点でも、DAHDIおよびアナログテレフォニーカードは完全にサポートされており、DAHDIは現在のカーネルに対してもビルド可能です。とはいえ、新規導入の大部分は純粋なVoIP（SIP trunk、PJSIP）であるため、アナログ/TDMハードウェアは現在ではニッチな選択肢となっており、主にレガシー環境、地方のPSTN接続、あるいは規制の厳しい市場で見られる程度です。以下の内容は、そうしたシナリオにおいても依然として適用されます。

公衆交換電話網（PSTN）に接続する方法はいくつかあります。最適な方法は、お住まいの地域で電話会社がどのような接続を提供しているかによって異なります。最も単純な方法は、家庭で使用しているようなアナログ回線を利用することです。このセクションでは、Sangoma™（旧Digium™）およびXorcom™のアナログカードの設定方法を説明します。

### 学習目標

この章を読み終えることで、以下のことができるようになります。

- 主要なテレフォニー用語や頭字語を認識する。
- デジタル回線とアナログ回線を使用すべきタイミングを理解する。
- FXSとFXOの違いを認識する。
- AsteriskでFXSおよびFXOを設定する。

### テレフォニーの基礎

ほとんどのアナログ実装では、tipおよびringと呼ばれる銅線ペアを使用します。ループが閉じると、電話機は通信事業者（または構内PBX）から発信音（ダイヤルトーン）を受け取ります。最も頻繁に使用されるシグナリングはループスタートですが、他にもいくつかの国で使用されているグランドスタートなど、あまり一般的ではないシグナリングも存在します。シグナリングには以下の3つのカテゴリがあります。

- 監視シグナリング
- アドレスシグナリング
- 情報シグナリング

#### 監視シグナリング

主な監視シグナリングには、オンフック、オフフック、呼び出し（リンギング）があります。

- **オンフック** – ユーザーが受話器を置くと、PBXは接続を遮断し、電流が流れないようにします。この状態をオンフックと呼びます。この状態では、呼び出し音（リンガー）のみが有効です。
- **オフフック** – 通話を開始する前に、電話機はオフフック状態に移行する必要があります。受話器を上げるとループが閉じ、ユーザーが発信しようとしていることがPBXに伝わります。この合図を受けると、PBXは発信音を生成し、宛先アドレス（電話番号）を受け入れる準備ができたことをユーザーに知らせます。
- **呼び出し（リンギング）** – ユーザーが別の電話機に発信すると、相手側の呼び出し音を鳴らすための電圧が生成され、着信を知らせます。シグナリングは国によって異なり、国ごとに異なるトーンが使用されます。

Asteriskのトーンは、indications.confファイルを変更することで、お住まいの国に合わせてカスタマイズできます。例：

```
[br]
description=Brazil
ringcadance=1000,4000
dial=425
busy=425/250,0/250
ring=425/1000,0/4000
congestion=425/250,0/250,425/750,0/250
callwaiting=425/50,0/1000
```

#### アドレスシグナリング

ダイヤルには2種類のシグナリングを使用できます。最初で最も一般的なものはデュアルトーン多重周波数（dtmf）であり、もう一方はパルスダイヤル（古い回転式電話機で使用）です。電話機にはダイヤル用のキーパッドがあり、各ボタンには高低2つの周波数が割り当てられています。dtmfシグナリングの場合、これらのトーンの組み合わせによって押された数字が示されます。MFC/R2は、dtmfとは異なる多重周波数トーンを使用します。

#### 情報シグナリング

情報シグナリングは、通話の進行状況やさまざまなイベントを示します。

- 発信音
- 話中音（ビジートーン）
- 呼び出し音（リングバックトーン）
- 輻輳音（コンジェスチョン）
- 無効な番号
- 確認音

### PSTNインターフェース

古いPBXの場合と同様に、Asterisk PBXをPSTNに接続する必要があることがよくあります。ここでは、その方法を説明します。通常、電話回線には3つの選択肢があります。

- アナログ: 家庭や小規模ビジネスで最も一般的な形式で、通常は金属製の銅線ペアで提供されます。
- デジタル: 多くの回線が必要な場合に使用されます。デジタル回線は通常、CSU/DSUまたは光マルチプレクサによって提供されます。エンドユーザー側のコネクタは通常RJ45です。国によっては、E1回線が2つの同軸BNCコネクタを使用して提供される場合があり、その場合はテレフォニーボードのRJ45ジャックに接続するためにバランが必要です。
- SIP: このオプションは最近開発されたものです。電話回線は、SIPシグナリング（VoIP）を使用したデータ接続を通じて提供されます。テレフォニーカードを購入する必要がないため、Asteriskで使用するには良い選択肢です。通話は直接イーサネットポートに配信されます。もう一つの利点は、コーデックのトランスコーディングを回避することで、CPUリソースを解放できる可能性があることです。

### アナログFXS、FXO、およびE&Mインターフェース

いくつかのアナログインターフェースタイプが利用可能です。電話網や他のPBXへの接続方法を学ぶには、これらのインターフェースの違いを理解することが不可欠です。ここでは、E&Mインターフェースについて説明します。現在Asteriskでは利用できず、多くのベンダーで製造中止となっていますが、この種のインターフェースを備えたルーターやPBXを見かけることがあるため、何を取り扱っているのかを知っておくことは有益です。

#### Foreign eXchange (FX) インターフェース

FXインターフェースはアナログです。「Foreign eXchange」という用語は、PSTNの中央局（CO）へのアクセス用トランクに適用されます。Foreign eXchange Office (FXO)

![アナログ電話機（FXS）と電話回線（FXO）の間に位置するAsterisk：FXS側は電話機に発信音と呼び出し音を提供し、FXO側は中央局から発信音を引き出す。](../images/10-legacy-fig01.png)

FXOインターフェースは、中央局（CO）または他のPBXの内線に接続するために使用されます。これはPSTNから来る電話回線と直接通信します。もう一つの選択肢は、FXOインターフェースを既存のPBXに接続し、AsteriskとレガシーPBX間の通信を可能にすることです。AsteriskをPBXポートに接続し、VoIPを使用してリモート内線を提供することは、オフプレミス内線（OPX）と呼ばれることがよくあります。FXOインターフェースは発信音を受信します。Foreign eXchange Station (FXS) FXSインターフェースは、アナログ電話機、モデム、またはファックスに供給を行います。FXSは電話機に発信音と電力を提供します。

#### トランクシグナリング

- ループスタート
- グランドスタート
- Kewlstart

AsteriskにおけるKewlstartシグナリングの使用は、ほぼデフォルトとなっています。Kewlstartはそれ自体がシグナリングというわけではなく、相手側で何が起きているかを監視することで回路にインテリジェンスを追加するものです。Kewlstartはループスタートに基づいています。ほとんどのスイッチはこの機能をサポートしておらず、これは切断通知を取得するために使用されます。

- ループスタート: ほとんどのアナログ回線で使用され、電話機が「オンフック」と「オフフック」を示し、スイッチが「呼び出し」と「呼び出しなし」を示すことを可能にします。これはおそらく、ほとんどの家庭にあるものです。この名前は、回線が常に開いているという事実に由来します。ループを閉じると、スイッチが発信音を提供します。着信は、開いたペア上の100Vの呼び出し電圧によって通知されます。

![VoIPゲートウェイとして動作するAsterisk：FXOポートがレガシーPBXの内線に接続され、リモートのAsteriskがIP経由のFXSポートを通じてその回線をアナログ電話機に提供している（オフプレミス内線、またはOPX）。](../images/10-legacy-fig02.png)

- グランドスタート: ループスタートに似ています。発信したい場合、回線の一方が短絡されます。スイッチがこの状態を識別すると、開いたペアを通じて電圧を反転させ、その後ループが閉じられます。その結果、回線は発信者に提供される前にまず占有状態になります。
- Kewlstart: 回路にインテリジェンスを追加し、相手側の監視を可能にします。Kewlstartはループスタートの多くの利点を取り入れています。

### Asteriskテレフォニーチャネルの設定

テレフォニーインターフェースカードを設定するには、いくつかの手順が必要です。この章では、最も一般的な3つのシナリオを紹介します。

- FXSを使用したアナログ接続
- FXOを使用したアナログ接続
- FXSおよびFXOインターフェースを備えたAstribank™の接続

### 設定手順（両方のケースで有効）

Asterisk用のハードウェアを選択する前に、インストールおよび有効化する同時通話数、サービス、コーデックを考慮する必要があります。AsteriskはCPU負荷の高いアプリケーションであるため、Asterisk専用のコンピューターを推奨します。コンピューター内にインストールできるインターフェースカードの数は、利用可能なスロットと割り込みの数によって制限されます。4ポートのカードを2枚挿すよりも、8ポートのインターフェースを備えたカードを1枚挿す方が望ましいです。もう一つの選択肢は、Xorcom AstribankのようなUSBチャネルバンクを使用することです。最近では、一部のメーカー（CIANETなど）がTDMoEチャネルバンクの製造を開始しており、数十ものアナログインターフェースをさらに簡単に接続できるようになっています。

![Xorcom Astribank：19インチラックマウント型のUSBチャネルバンク。ホストのPCIスロットを消費することなく、数十のFXS/FXOポート（ここでは32ポートユニット）を提供する。](../images/10-legacy-fig03.png)

#### 例1：FXO 1つ、FXS 1つのインストール

この例では、1つのFXSモジュールと1つのFXOモジュールを備えたSangoma TDM400テレフォニーインターフェースカード（旧Digium TDM400として販売）を使用します。必要な手順は以下の通りです。

1. アナログカードのFXS、FXO、またはその両方をインストールします。
2. `/etc/dahdi/system.conf`（旧`/etc/zaptel.conf`）ファイルを構成します。
3. `dahdi_genconf`を使用して設定ファイルを生成します。
4. DAHDIインターフェース用のドライバーをロードします。
5. `dahdi_test`を実行して、割り込みの欠落を確認します。
6. `dahdi_cfg`を実行してドライバーを設定します。
7. `chan_dahdi.conf`ファイルでDAHDIチャネルを設定し、Asteriskをロードします。

##### 手順1：TDM400ボードのインストール

TDM404PカードにはFXSおよびFXOモジュールが含まれています。FXS（S110M、緑）およびFXO（X100M、赤）モジュールを接続します。FXSモジュールを使用している場合は、molexコネクタを使用してカードを電源に直接接続してください。ハードウェアの損傷を防ぐため、インターフェースカードを取り扱う前に静電気防止対策を行ってください。Sangoma（旧Digium）のアナログカードは、ハードウェアエコーキャンセレーションモジュールVPMADT032もサポートしています。

##### 手順2：dahdi_genconfによる設定の生成

設定に関する朗報は、DAHDIインターフェースの設定を自動的に検出し生成する新しいユーティリティ`dahdi_genconf`です。このユーティリティは2つのファイルを生成します。

- `/etc/dahdi/system.conf`
- `/etc/asterisk/dahdi-channels.conf`
- `/etc/asterisk/users.conf`（`users`オプション付き）
- これらのファイルはすべて`chan_dahdi full`オプションを使用します

`dahdi_genconf`を実行する前に、`genconf_parameters`（しばしば`gen_parameters.conf`と呼ばれます）ファイルを構成することが重要です。

![Sangoma/Digium TDM404Pアナログカード：最大4つのFXSまたはFXOモジュールが番号付きポートに差し込まれ、オプションのハードウェアエコーキャンセレーションドーターカードと、FXSモジュール専用の12V電源コネクタを備えている。](../images/10-legacy-fig04.png)

```
#
# /etc/dahdi/genconf_parameters
#
# This file contains parameters that affect the
# dahdi_genconf configurator generator.
#
#base_exten          4000
#fxs_immediate       no
#fxs_default_start   ks
#lc_country          il
#context_lines       from-pstn
#context_phones      from-internal
#context_input       astbank-input
#context_output      astbank-output
#group_phones        0
#group_lines         5
#brint_overlap
#bri_sig_style       bri_ptmp
#
# The echo canceller to use. If you have a hardware echo canceller, just
# leave it be, as this one won't be used anyway.
#
# The default is mg2, but it may change in the future. E.g: a packager
# that bundles a better echo canceller may set it as the default, or
# dahdi_genconf will scan for the "best" echo canceller.
#
#echo_can            hpec
#echo_can            oslec
#echo_can            none   # to avoid echo cancellers altogether
# bri_hardhdlc: If this parameter is set to 'yes', in the entries for
# BRI cards 'hardhdlc' will be used instead of 'dchan' (an alias for
# 'fcshdlc').
#
#bri_hardhdlc        yes
# For MFC/R2 Support
#pri_connection_type R2
#r2_idle_bits        1101
# pri_types contains a list of settings:
# Currently the only setting is for TE or NT (the default is TE)
#
#pri_termtype
# SPAN/2              NT
# SPAN/4              NT
```

`genconf_parameters`ファイルを使用すると、設定をカスタマイズできます。アナログ回線にとって最も重要なパラメータは以下の通りです。

```
base_exten          4000
fxs_immediate       no
fxs_default_start   ks
lc_country          br
context_lines       from-pstn
context_phones      from-internal
context_input       astbank-input
context_output      astbank-output
group_phones        0
group_lines         5
#echo_can           hpec
#echo_can           oslec
echo_can            MG2
```

警告：少なくともチャネルのエコーキャンセレーションアルゴリズムを設定する必要があります。base_extenパラメータは、FXS内線の基本的なdialplanを定義します。この場合、最初のFXSチャネルには内線番号4000が割り当てられ、2番目には4001が割り当てられます。回線（context_phones）とトランク（context_lines）が作成されるcontextは非常に重要です。ファイルを生成した後、`/etc/asterisk/chan_dahdi.conf`ファイルに`/etc/asterisk/dahdi-channels.conf`ファイルを含める必要があります。

```
#include dahdi-channels.conf
```

注：アナログシグナリングは少し混乱しやすく、常にカードの逆になります。FXSカードはFXOでシグナリングされ、FXOカードはFXSでシグナリングされます。Asteriskは、反対側にいるかのようにこれらのデバイスと通信します。

##### 手順3：カーネルドライバーのロード

次に、chan_dahdiモジュールと関連するカードのカーネルドライバーをロードする必要があります。dahdi_hardwareを使用して、カードとドライバー名を検出します。例：

| カード | ドライバー | 説明 |
| --- | --- | --- |
| TE410P | wct4xxp | 4xE1/T1 - 3.3V PCI |
| TE405P | wct4xxp | 4xE1/T1 - 5V PCI |
| TDM400P | wctdm | 4 FXS/FXO |
| T100P | wct1xxp | 1 T1 |
| E100P | wct1xxp | 1 E1 |
| X100P | wcfxo | 1 FXO |

ドライバーをロードするコマンド：

```
modprobe dahdi
modprobe wctdm
```

##### 手順4：dahdi_testユーティリティの使用

重要なユーティリティであるdahdi_testは、DAHDIカードの割り込み欠落を確認するために使用されます。オーディオ品質の問題は、多くの場合、割り込みの競合に関連しています。DAHDIカードが他のカードと割り込みを共有していないことを確認するには、次のコマンドを使用します。

```
#cat /proc/interrupts
```

DAHDIカードでコンパイルされたdahdi_testユーティリティを使用して、割り込み欠落の数を確認できます。99.987%を下回る数値は、問題が発生している可能性を示しています。

##### 手順5：dahdi_cfgユーティリティによるドライバーの設定

DAHDIには、ドライバーをロードするための特殊なシステムがあります。まず/etc/dahdi/system.confを設定し、次にdahdi_cfgを使用してそれらの設定をDAHDIドライバーに適用します。この場合、dahdi_cfgはFXインターフェースのシグナリングを設定するために使用されます。結果を確認するには、コマンドに「-vvvvv」を追加して詳細表示を行います。

```
#
/sbin/dahdi_cfg -vv
Dahdi Configuration
======================
Channel map:
Channel 01: FXS Kewlstart (Default) (Slaves: 01)
Channel 02: FXO Kewlstart (Default) (Slaves: 02)
2 channels configured.
```

チャネルが正常にロードされた場合、上記のような出力が表示されます。ユーザーはchan_dahdi.confのチャネル間のシグナリングを逆に設定してしまうことがよくあります。これが発生すると、以下のようなメッセージが表示されます。

```
DAHDI_CHANCONFIG failed on channel 1: Invalid argument (22)
Did you forget that FXS interfaces are configured with FXO signalling
and that FXO interfaces use FXS signalling?
```

ハードウェアの設定が完了したら、Asteriskの設定に進むことができます。

##### 手順6：/etc/asterisk/chan_dahdi.confファイルの設定

奇妙に聞こえるかもしれませんが、/etc/dahdi/system.confを設定した時点で、カード自体の設定は完了しています。DAHDIはルーティングやSS7など、他の目的にも使用できます。Asteriskで使用するには、AsteriskのDAHDIチャネルを設定する必要があります。Asteriskのすべてのチャネルを定義する必要があります。SIP/PJSIPチャネルはpjsip.confで定義されます（注：chan_sipとsip.confはAsterisk 21で削除されました）。一方、TDMチャネルはchan_dahdi.confで定義されます。これにより、dialplanで使用される論理的なTDMチャネルが作成されます。

```
signalling=fxs_ks;                  ; FXS signaling for the FXO interface
group=1;                            ; channel group
context=incoming;                   ; context
channel => 1;                       ; channel number
signalling=fxo_ks;                  ; FXO signaling for the FXS interface
group=2;                            ; channel group
context=extensions;                 ; context
channel => 2                        ; channel number
```

### 設定オプション

chan_dahdi.confファイルにはいくつかのオプションが用意されています。すべてのオプションを説明するのは退屈で非効率的であるため、理解を深めるために主要なオプショングループに焦点を当てます。

#### 一般オプション（チャネル非依存）

これらのオプションはどのチャネルでも機能します。context：着信コンテキストを定義します。

```
context=default
```

channel：チャネルまたはチャネル範囲を定義します。各チャネル定義は、宣言の前に定義されたオプションを継承します。チャネルは個別に、またはカンマ区切りで同じ行に指定できます。範囲は「-」を使用して定義できます。

```
Channel=>1-15
Channel=>16
Channel=>17,18
```

group：チャネルをグループとして扱うことを可能にします。チャネル番号の代わりにグループ番号にダイヤルすると、利用可能な最初のチャネルが使用されます。チャネルが電話機である場合、グループに発信するとすべての電話機が同時に鳴ります。カンマを使用すると、同じチャネルに対して複数のグループを指定できます。

```
group=1
group=3,5
```

language：国際化を有効にし、言語を設定します。この機能は、特定の言語のシステムメッセージを設定します。標準インストールでプロンプトが完全に利用できるのは英語のみです。musiconhold：保留音クラスを選択します。

#### 発信者番号（Caller ID）オプション

多くのcalleridオプションがあります。デフォルトでほとんどが有効になっていますが、一部は無効にできます。usecallerid：後続のチャネルのcallerid送信を有効または無効にします（Yes/No）。注：システムが応答する前に2回呼び出し音が鳴る場合は、この機能を無効にしてみてください。即座に応答するはずです。hidecallerid：発信者番号を非表示にするかどうかを定義します（Yes/No）。callerid：特定のチャネルのcallerid文字列を設定します。発信者はasreceivedで設定できます。これは主に、着信calleridを示すためにトランクインターフェースで使用されます。

```
callerid = "Flavio Eduardo Gonçalves" <48 30258500>
```

callwaitingcallerid：キャッチホン中のcalleridをサポートします。useincomingcalleridondahditransfer：転送時に着信calleridを使用します。

#### キャッチホン（Call Waiting）

AsteriskはFXSチャネルでのキャッチホンをサポートしています。誰かが内線に発信しようとすると、ユーザーは待機トーンを受け取ります。キャッチホンを有効にするには：

```
callwaiting=yes
```

キャッチホンでcalleridをサポートするには：

```
callwaitingcallerid=yes
```

#### オーディオ品質オプション

エコーキャンセレーションの調整は、技術的な側面と芸術的な側面の両方を持っています。これらのオプションは、DAHDIチャネルのオーディオ品質に影響を与える特定のAsteriskパラメータを調整します。アナログインターフェースのオーディオ品質を向上させるのに役立ちます。

#### fxotuneユーティリティ

fxotuneは、FXOモジュールの特定のパラメータを微調整するために使用されるユーティリティです。この微調整は、ハイブリッドによって引き起こされるインピーダンスの不整合を調整するために必要です。このユーティリティには3つの動作モードがあります。

- 検出（-i）：既存のFXOチャネルを検出して修正し、設定を保存します。

```
fxotune.conf
```

- ダンプモード（-d）：波形ファイルをfxotune_dump.valsに生成します。
- スタートアップモード（-s）：fxotune.confファイルを読み込み、FXOモジュールに適用します。

Asteriskを起動する前に、システムロード時にfxotune –s命令を挿入する必要があることを理解しておくことが重要です。

```
#modprobe dahdi
#modprobe wctdm
#fxotune -s
```

### エコーキャンセレーション

ほとんどのエコーキャンセレーションアルゴリズムは、受信信号の複数のコピーを生成し、それぞれを特定の時間だけ遅延させることで動作します。フィルターのタップ数は、キャンセルする必要があるエコー遅延のサイズを決定します。これらの遅延されたコピーは調整され、受信信号から差し引かれます。コツは、CPUサイクルを使いすぎずにエコーを除去するために、遅延信号のみを調整することです。ユーザーの観点からは、適切なエコーキャンセレーションアルゴリズムを選択することが重要です。デフォルトはMG2ですが、Sangoma（旧Digium）のHigh Performance Echo Cancellation（HPEC）や、David Roweによって開発されたオープンソースのエコーキャンセレーション（OSLEC）という2つのオプションも利用可能です。

OSLEC（https://www.rowetel.com/?page_id=454）はLinuxカーネルにマージされており、カーネルの`drivers/staging/echo`領域に存在します。DAHDIは個別のダウンロードを出荷するのではなく、それに対してビルドされます。エコーキャンセレーションアルゴリズムを変更するには、`/etc/dahdi/system.conf`で`echo_can`パラメータを設定します。例：

```
echo_can=oslec
```

Asteriskのエコーキャンセレーションは、/etc/asterisk/chan-ファイル内の3つのパラメータによって制御されます。

```
dahdi.conf.
```

- **echocancel**: エコーキャンセレーションを無効または有効にします。この機能は有効にしておく必要があります。"yes"またはタップ数を指定します。（解説：エコーキャンセリングはどのように機能するのでしょうか？ほとんどのエコーキャンセリングアルゴリズムは、受信信号の複数のコピーを生成し、それぞれをわずかな間隔で遅延させることで動作します。この小さな流れを「タップ」と呼びます。タップ数は、キャンセル可能なエコー遅延を決定します。これらのコピーは遅延、調整され、元の信号から差し引かれます。コツは、エコーを除去するために必要な分だけ、遅延信号を正確に調整することです。）
- **echocancelwhenbridged**: 純粋なTDM通話中にエコーキャンセラーを有効または無効にします。これは通常必要ありません。
- **rxgain**: 受信ゲインを調整して、受信音量を上げたり下げたりします（-100%から100%）。
- **txgain**: 送信ゲインを調整して、送信音量を上げたり下げたりします（-100%から100%）。

例：

```
echocancel=yes
echocancelwhenbridged=yes
txgain=-10%
rxgain=10%
```

#### 課金オプション

これらのオプションは、通話詳細記録（CDR）データベースに通話情報が記録される方法を変更します。amaflags：CDRの分類に影響するAMAフラグを設定します。以下の値を指定できます。

- billing
- documentation
- omit
- default

accountcode：特定のチャネルのアカウントコードを設定します。英数字の値を含めることができ、通常は部署名やユーザー名が使用されます。

```
accountcode=finance
amaflags=billing
```

### 通話進行状況オプション

これらの項目は、通話の進行状況に関する情報を取得するために使用されます。公衆インターフェースでは、通話の進行状況を検出し、応答があったか話中であるかを判断すると便利です。話中検出は非常に実験的なものであり、特定のパラメータによって規制されています。

```
busydetect=yes
busycount=4
busypattern=500,500
callprogress=yes
progzone=br
```

これらのパラメータ（上記）は、インターフェースが話中音を検出しようとするかどうか、検出成功のためにいくつのトーンを使用するか、話中パターンは何かを指定します。話中検出は大部分が実験的なものであり、Makefileで追加のパラメータを変更できます。正確な課金に不可欠な通話の応答を検出するには、極性反転を使用して正確な応答時間を通知することが可能です。これは、通話料金を請求する予定がある場合や、比較のために正確な課金記録が必要な場合に重要です。通常、このサービスをリクエストするには電話会社に連絡する必要があります。

```
answeronpolarityswitch=yes
```

国によっては、極性反転を使用して通話の切断を検出することも可能です。

```
hanguponpolarityswitch=yes
```

#### 電話機用オプション

これらのオプションは、FXSインターフェースに接続された電話機に使用されます。DAHDIインターフェースに直接接続されたアナログ電話機に提供されるすべての機能は、Asteriskによって制御されます。

- **adsi** (Analog Display Services Interface): チケット購入などのサービスを提供するために一部の通信事業者が使用する通信規格のセットです。
- **cancallforward**: 通話転送を有効または無効にします（*72で有効、*73で無効）。
- **calleridcallwaiting**: キャッチホン中に受信したcalleridを有効にします（Yes/No）。
- **immediate**: イミディエイトモードでは、発信音を提供する代わりに、チャネルは定義されたコンテキストの「s」内線に即座にジャンプします。これはホットラインを作成するために使用されます。
- **threewaycalling**: 三者通話を有効または無効にします。
- **mailbox**: 利用可能なボイスメールメッセージをユーザーに警告します。可聴信号または視覚的インジケーター（電話機がこの機能をサポートしている場合）になります。引数はメールボックス番号です。
- **callgroup**: ダイヤルまたはピックアップ用の電話機グループ。
- **pickupgroup**: 通話ピックアップ用の電話機グループ。

### 便利なDAHDI CLIコマンド

DAHDIチャネルをロードしてAsteriskが実行されたら、Asterisk CLIからチャネルの状態を確認できます。これらのコマンドはAsterisk 22でも現役です。

```
*CLI> dahdi show channels
*CLI> dahdi show channel 1
*CLI> module reload chan_dahdi.so
```

### DAHDIチャネル形式

DAHDIチャネルは、dialplanで以下の形式を使用します。

```
DAHDI/[g]<identifier>[c][r<cadence>]
<identifier> - Physical channel numeric identifier
[g] - Group identifier
[c] - Answer confirmation. A number is not considered until the callee presses "#"
[r] - customized ringing
[cadence] - Integer from 1 to 4
```

例：

```
DAHDI/2     - channel 2
DAHDI/g1    - First available channel in group 1
```

## デジタルチャネル (E1/T1/PRI / TDM)

Asterisk 22の時点では、DAHDIとlibpriは引き続き完全にサポートされていますが、新規導入においてはTDMデジタル・トランク（E1/T1/ISDN PRI）はSIPトランクに置き換わりつつあります。このセクションは、TDM接続が必要な環境では引き続き完全に適用可能です。新規環境（グリーンフィールド）では、通常、電話用ハードウェアなしで同等のチャネル密度を実現できるSIPトランク（第3章）が採用されます。

デジタルチャネルは非常に一般的であるため、大規模な顧客をターゲットにする場合は、これらのチャネルの実装方法を学ぶ必要があります。チャネル数が多い場合（通常8以上）、T1/E1/J1といったデジタルインターフェースを使用するのが一般的です。T1は米国で非常に一般的であり、E1はヨーロッパ、J1は日本で一般的です。これらのチャネルタイプは、T1チャネルあたり24、E1チャネルあたり30という優れた回路密度を実現します。

ラテンアメリカ、中国、アフリカでは、MFC/R2として知られるチャネル関連信号（CAS）を使用するのが一般的です。本章では、OpenR2ライブラリを使用してMFC/R2を実装する方法を検証します。米国およびヨーロッパでは、ISDN PRIが最も一般的な信号方式です。また、本章では、ヨーロッパの中規模アプリケーションで非常に一般的なISDN BRI（Basic Rate Interface）についても解説します。

本書のすべての例はDAHDIチャネルに焦点を当てています。一部のカードは独自のチャネルを使用して実装されているため、特定のカードの設定方法についてはメーカーに詳細を確認してください。

### 学習目標

本章を終えると、以下のことができるようになります。

- デジタル電話で使用される主要な用語を理解する
- CAS信号とCCS信号の違いを区別する
- R2信号とISDN信号の違いを区別する
- ISDN信号を使用するインターフェースを設定する
- R2信号を使用するインターフェースを設定する

### E1/T1デジタル回線

デジタル回線E1/T1は、多数のチャネルを実装する必要がある場合の選択肢となります。1つのE1回線は30の同時通話が可能であり、DID（直通ダイヤルイン）、Caller ID（発信者番号通知）、高度な信号方式といった機能を利用できます。E1/T1回線は、国によってツイストペア、光ファイバー、マイクロ波など、さまざまな方法で企業に引き込まれます。デジタル回線は、UTP、光ファイバー、またはマイクロ波を使用して企業に提供されます。物理的な回線を提供するためにモデムやマルチプレクサ（MUX）が使用されます。T1回線への接続は常にRJ45コネクタに基づいています。ただし、E1回線はBNCを使用して提供されることもあります。特にE1回線の場合、どのようなコネクタで提供されるかを事前に知っておくことが非常に重要です。通常、RJ45までのすべての機器は通信事業者（TELCO）によって提供されます。

![E1/T1回路の提供方法：通信事業者は、UTP銅線（E1用のHDSLモデム、またはT1用の直接カード接続）、光マルチプレクサを介した光ファイバー、またはマイクロ波無線リンクを介してトランクを提供できます。](../images/10-legacy-fig05.png)

![UTPかBNCか：ほとんどのデジタルカードはRJ45（UTP）コネクタを使用しますが、一部のE1回線はデュアルBNC同軸ケーブルで提供されます。その場合、同軸ペアをカードのRJ45ジャックに適応させるためにバランが必要です。](../images/10-legacy-fig06.png)

#### 音声はどのようにビットに変換されるか？

アナログ信号は1秒間に8,000回サンプリングされ、アナログ音声のデジタル版を作成します。このエンコーディングはパルス符号変調（PCM）として知られています。米国と日本では、信号はmu-law（Asteriskではulawと表記）を使用してエンコードされます。世界のその他の地域では、エンコーディングはalawです。

![パルス符号変調（PCM）：4 kHzのアナログ音声信号は1秒間に8,000回サンプリングされ（ナイキスト周波数）、64 Kbpsのデジタルビットストリームに符号化されます。](../images/10-legacy-fig07.png)

#### 時分割多重（TDM）

アナログ回線は、少数のチャネルが必要な場合に適しています。時分割多重（TDM）を使用すると、単一のデータ接続に複数のチャネルを詰め込むことが可能です。多数の回路が必要な場合、電話会社は通常、PCMを使用してデジタル形式で音声が伝送されるデータ回路であるデジタル・トランクを提供します。各タイムスロットは、単一の音声チャネルを伝送するために64 Kbpsの帯域幅を使用します。

![E1およびT1における時分割多重：E1フレームは2048 Kbpsで32のタイムスロットを伝送し（DS0 #0はフレーム同期用、DS0 #16は信号用）、T1フレームは1544 Kbpsで24のタイムスロットを伝送し、同期に1ビット、信号にRobbed-bit方式を使用します。](../images/10-legacy-fig08.png)

米国では、最も一般的なデジタル・トランクはT1で、24の利用可能な回線があります。ヨーロッパやラテンアメリカでは、E1トランクに30の回線があります。一部の企業は、より少ないチャネルを持つフラクショナルT1/E1を提供しています。Robbed bit信号方式：T1トランクは、信号のために1ビットを借用するRobbed bit方式を使用することがあります。T1トランクでは、データ/音声チャネルは各タイムスロットで56 Kbpsで送信されます。お気づきの通り、Robbed bitを使用する場合、T1回路は同期と信号のために2つのスロットを失うことはありません。

#### T1/E1回線符号（Line code）

T1およびE1は実際にはデータ回路であり、ビットが解釈される方法を決定するデータ符号化方式を持っています。E1の場合、最も一般的な回線符号はレイヤー1でHDB3、レイヤー2でCCSです。デジタル・トランクの設定方法を知る最も簡単な方法は、通信事業者にこの情報を問い合わせることです。この情報は、/etc/dahdi/system.confファイルを構成するために必要になります。

#### T1/E1信号方式

T1/E1回線は、以下のようなさまざまな種類の信号方式で提供される可能性があることを理解しておくことが重要です。

- Robbed bit信号方式のT1
- ISDN信号方式のT1
- MFC/R2信号方式のE1（CAS - チャネル関連信号）
- ISDN信号方式のE1

ISDNはヨーロッパや米国でよく使用されます。これは1984年に国際電気通信連合（ITU）によって標準化されたデジタル音声ネットワークです。ISDNは2種類のチャネルを提供します。

- ベアラチャネル（Bチャネル）
  - 音声
  - データ
- データチャネル（Dチャネル）
  - アウトオブバンド信号
  - LAPD信号
  - Q.931

通常、ISDN回線は2つの物理的な手段で提供されます。

- 基本インターフェース（BRI）
  - 2B+Dとして知られる
  - 2つのベアラ（64K）チャネルと1つのデータ（16K）チャネル
  - 148Kbpsの銅線ペアを使用
- 一次群インターフェース（PRI）
  - T1/E1トランクを使用して提供
  - T1の場合は23B+D
  - E1の場合は30B+D

時折、E1回路はITUによってQ.421/Q441として知られる標準として定義されたMFC/R2と呼ばれるCAS信号方式を使用します。これはラテンアメリカやアジアで頻繁に見られます。これらの国のいくつかの電話会社は、MFC/R2のカスタマイズされたバリエーションを使用しています。そのため、動作させるには正しい国別バリエーションを知る必要があります。

### ISDN BRI

ISDN BRI信号方式を使用するチャネルはヨーロッパで非常に人気があります。Asterisk用のほとんどのISDN BRIカードは、NTおよびTE機能を備えたS/Tインターフェースをサポートしています。TE（端末）接続は、通信事業者やネットワーク終端（NT）として構成された他のPBXに接続するために使用されます。NTは、TEとして構成された電話機やPBXを接続するために使用されます。ISDN BRIは2つのデータ/音声チャネルと1つの信号チャネルを提供します。ISDN BRIカードは、Asterisk用のインターフェースカードを扱う複数のベンダーから入手可能です。

### Asteriskサーバー用の電話カードの選択

Asteriskと互換性のあるデジタルカードのメーカーはいくつかあります。カードの選択は、以下の要因のいくつかに依存します。

#### データバス

PCにはいくつかの種類のバスがあります。サーバーに適したカードを用意することが非常に重要です。以下の概要は、最も頻繁に使用されるカードを示しています。

- 32ビット PCI 5V：デスクトップを含むほとんどのコンピュータで見られる
  - Sangoma (旧Digium) TE405, TE407, TE205, TE207, TE120, TE122, B410, TDM2400, TDM800, TDM410, TC400
  - Sangoma A101, A102, A104
- 32/64ビット PCI 3.3V：基本的にサーバーで見られる
  - Sangoma (旧Digium) TE410, TE412, TE210, TE212, TE120, TE122, B410, TDM2400, TDM800, TDM410, TC400
- PCI Express：デスクトップおよびサーバーで見られる
  - Sangoma (旧Digium) TE420, TE220, TE121, AEX2400, AEX800
  - Sangoma A101, A102, A104

これらのカードファミリーはDigiumが起源ですが、2018年にSangomaが買収しました。現在はSangomaブランドで販売・サポートされています。ここに記載されている古いSKUの多くは製造中止になっているため、購入前にwww.sangoma.comで現在のモデルの在庫状況を確認してください。

- MiniPCI：組み込みシステムで見られる
  - OpenVOX A100M(FXO), B100M(ISDN BRI), B200M(ISDN BRI), B400M(ISDN BRI)
- USB 2.0：ほとんどの現代のPCで見られる。USBベースのソリューションは、アナログおよびデジタルチャネルの高密度化を可能にします。このバスは480 Mbpsをサポートし、各音声チャネルは64 Kbpsを占有します。USBハブを使用すると、単一のポートで最大1,000のアナログポートの密度を実現できます。
  - Xorcom Astribank (FXS, FXO, E1-ISDN, E1-R2)
- Ethernet：Ethernetの最大の利点は、カードを複数のサーバーで接続できることです。高可用性ソリューションは、通常これらのデバイスの主要なアプリケーションです。このソリューションの強みは、空のPCIスロットがないサーバーやブレードサーバーを使用できることです。
  - Redfone FoneBridge (最大4つのE1回路)

### ハードウェア・エコーキャンセレーションの使用

ハードウェア・エコーキャンセレーションは、ホストCPUの負荷を軽減します。E1インターフェースを複数持つカードの場合、ハードウェア・エコーキャンセレーションはプロセッサの負荷を軽減するのに役立ちます。OSLECのような新しい強化されたソフトウェア・エコーキャンセラーは、ハードウェア・エコーキャンセラーの必要性を減らしています。ハードウェアとソフトウェアのどちらのエコーキャンセラーを選択するかは、サーバーで利用可能な処理能力とE1回路の数に基づいて検討する必要があります。エコーキャンセレーション処理は、OSLECを使用した場合、128タップの振幅で音声チャネルあたり最大9 MIPS（1秒あたりの百万命令数）を使用する可能性があります（参照：Xorcom Ltd.）。各命令に1 CPUサイクルを考慮すると（プロセッサやソフトウェアの実装自体に基づいて常に正しいとは限りませんが）、4つのE1に対して1.080 GHzが必要という計算になります。

#### 信号方式のタイプ

信号方式のタイプ（例：T1 CAS、T1 PRI、E1 CAS R2、E1 CAS ISDN）を選択するのは簡単な作業ではありません。それは、お住まいの地域で何が利用可能か、そしてどのような価格かによって決まります。共通線信号方式（CCS）は、チャネル関連信号（CAS）よりも優れていることが多いですが、利用できない場合もよくあります。米国では、ほとんどの通信事業者が一般ユーザー向けにT1 CASを、高度なユーザー（コールセンターなど）向けにT1 PRIを提供しているため、通常は選択可能です。ラテンアメリカではE1 CAS R2が普及していますが、一部の都市ではISDN PRIも利用可能です。

![DAHDIソフトウェアアーキテクチャ：Asteriskは`chan_dahdi`チャネルドライバと通信し、それがプロトコルライブラリlibpri（ISDN）、libopenr2（MFC/R2）、libss7（SS7）をロードします。これらは`/dev/dahdi`インターフェース、DAHDIカーネルドライバ、およびカード固有のインターフェースカーネルドライバの上に配置されています。](../images/10-legacy-fig09.png)

R2を実装するには、Moises Silvaによって開発されたOpenR2というライブラリをインストールし、インストール前にAsteriskにパッチを適用する必要があります。これは本章の後半で示す簡単な手順です。このライブラリはいくつかのテストに合格しており、私たちの顧客の数社で本番稼働しています。ISDNは、利用可能であれば常に最良の選択であると私は考えます。一部のプロバイダーは、電話会社間で利用可能なCCS信号である信号方式7（SS7）にアクセスできる場合があります。SS7には、独自のソリューションとオープンソースのソリューションの両方が存在します。AsteriskでSS7をサポートするには、ライブラリlibss7が使用されます。

### Asterisk電話チャネルの設定

電話インターフェースカードの設定には、いくつかの必要な手順が含まれます。本章では、最も一般的な3つのシナリオを紹介します。

- ISDN PRIを使用したデジタル接続
- ISDN BRIを使用したデジタル接続
- MFC/R2を使用したデジタル接続

DAHDIチャネルを設定するには2つの方法があります。1つ目は、すべてのパラメータを完全に制御して手動で設定する方法です。2つ目は、ユーティリティdahdi_genconfを使用してカードを検出し、設定する方法です。

#### 自動検出と設定

DAHDI開発チームのおかげで、カードの自動検出と設定が可能になりました。ステップ1：設定を自動的に生成するには、ユーティリティdahdi_genconfを使用します。これによりカードが検出され、/etc/dahdi/system.confおよびdahdi-channels.confファイルが生成されます。

```
dahdi_genconf
```

ステップ2：chan_dahdi.confファイルの最後の行に、dahdi-channels.confファイルを含めます。

```
#include dahdi_channels.conf
```

ステップ3：modulesファイル内の未使用のモジュールをすべてコメントアウトするか、単に以下を使用します。

```
dahdi_genconf modules
```

#### 手動設定

もう1つの選択肢は、インターフェースを手動で設定することです。以下に、DAHDIチャネルの設定例をいくつか示します。

##### 例 #1 – ISDNを使用した2つのT1/E1チャネル

必要な手順：

1. TE205PまたはTE210Pのインストール
2. `/etc/dahdi/system.conf`ファイルの設定
3. DAHDIドライバのロード
4. `dahdi_test`ユーティリティ
5. `dahdi_cfg`ユーティリティ
6. `chan_dahdi.conf`ファイルの設定
7. Asteriskのロードとテスト

ステップ1：TE205Pのインストール。TE205Pをインストールする前に、TE205PカードとTE210Pカードの違いを理解することが重要です。TE210Pカードは、サーバーのマザーボードにのみ見られる3.3ボルトで駆動する64ビットバスを使用します。このインターフェースカードを指定する場合は注意してください。ハードウェアが64ビット、3.3Vバスをサポートしていることを確認してください。TE205Pカードは、デスクトップコンピュータによく見られる5V PCIを使用します。この例では、1スパンのカードへの縮小や4スパンのカードへの拡張が容易であるため、2スパンのTE205Pインターフェースカードを選択しました。これらのカードは現在、Sangomaブランド（旧Digium）で販売されています。

![Sangoma/Digium TE205PデュアルスパンE1/T1カード：2つのRJ45ポートがデジタル・トランクを受け入れ、オンボードのジャンパ（E1/T1/J1セレクタ）が回線規格を設定します。](../images/10-legacy-fig10.png)

```
Step 2: /etc/dahdi/system.conf configuration file
```

TDMデジタルカードの設定は、アナログカードの設定とは少し異なります。まず、ボードのスパンを設定し、次にチャネルを設定する必要があります。スパンは、カードの認識順序に応じて順番に番号が付けられます。つまり、インターフェースカードが複数ある場合、どのスパンがどれに属しているかを知ることは困難です。dahdi_hardwareを使用して、各スパンにどのハードウェアがインストールされているかを確認してください。例 #1 (2xT1 PRI)

```
span=1,1,0,esf,b8zs
span=2,0,0,esf,b8zs
bchan=1-23
dchan=24
bchan=25-47
dchan=48
defaultzone=us
loadzone=us
```

例 #2 (2xE1 PRI)

```
span=1,1,0,ccs,hdb3,crc4 # not always necessary, consult Telco.
span=2,0,0,ccs,hdb3,crc4
bchan=1-15, 17-31
dchan=16
bchan=33-47, 49-63
dchan=48
defaultzone=br
loadzone=br
```

例 #3 (4xBRI)

```
loadzone=de
defaultzone=de
span=1,1,0,ccs,ami
bchan=1,2
hardhdlc=3
span=2,0,0,ccs,ami
bchan=4,5
hardhdlc=6
span=3,0,0.ccs.ami
bchan=7,8
hardhdlc=9
span=4,0,0,ccs,ami
bchan=10,11
hardhdlc=12
```

ステップ3：カーネルドライバのロード。dahdi_hardwareを使用して、インストールする必要があるドライバを確認します。

```
dahdi_hardware
pci:0000:04:02.0     wcte2xxp    e159:0001 Sangoma Wildcard TE205P T1/E1 Board
```

ロードするには以下を使用します：

```
modprobe dahdi
modprobe wct2xxp
```

ステップ4：dahdi_testを使用して、欠落している割り込みを確認します。DAHDIカードでコンパイルされたdahdi_testユーティリティを使用して、割り込みミスの数を確認できます。99.987%を下回る数値は、問題が発生している可能性を示しています。dahdi_testは以下にあります。

```
/usr/sbin.
#./dahdi_test
Opened pseudo zap interface, measuring accuracy...
99.987793% 100.000000% 100.000000% 100.000000% 100.000000% 100.000000%
100.000000%
100.000000% 100.000000% 100.000000% 100.000000% 100.000000% 100.000000%
100.000000% 100.000000%
100.000000% 100.000000% 100.000000% 100.000000% 99.987793% 100.000000%
100.000000% 100.000000%
100.000000% 100.000000% 100.000000%
--- Results after 26 passes ---
Best: 100.000000 -- Worst: 99.987793 -- Average: 99.999061
```

ステップ5：dahdi_cfgユーティリティの使用。これは、1つのフラクショナルE1（15ポート）スパンと2つのFXOポートに対するdahdi_cfgの正しい出力です。

```
#./dahdi_cfg -vvvv
Dahdi configuration
======================
SPAN 1: CCS/HDB3 Build-out: 0 db (CSU)/0-133 feet (DSX-1)
Channel map:
Channel 01: Clear channel (Default) (Slaves: 01)
Channel 02: Clear channel (Default) (Slaves: 02)
Channel 03: Clear channel (Default) (Slaves: 03)
Channel 04: Clear channel (Default) (Slaves: 04)
Channel 05: Clear channel (Default) (Slaves: 05)
Channel 06: Clear channel (Default) (Slaves: 06)
Channel 07: Clear channel (Default) (Slaves: 07)
Channel 08: Clear channel (Default) (Slaves: 08)
Channel 09: Clear channel (Default) (Slaves: 09)
Channel 10: Clear channel (Default) (Slaves: 10)
Channel 11: Clear channel (Default) (Slaves: 11)
Channel 12: Clear channel (Default) (Slaves: 12)
Channel 13: Clear channel (Default) (Slaves: 13)
Channel 14: Clear channel (Default) (Slaves: 14)
Channel 15: Clear channel (Default) (Slaves: 15)
Channel 16: D-channel (Default) (Slaves: 16)
16 channels configured.
```

ステップ6：/etc/asterisk/chan_dahdi.confファイルへのDAHDIの設定。例 #1 (2xT1)

```
callerid="John Doe"<(555)555-1111>
switchtype=national
signalling =pri_cpe
context=from-pstn
group = 1
channel => 1-23
group =2
channel => 25-47
```

例 #2 (2xE1)

```
callerid="Flavio Eduardo" <4830258580>
switchtype=euroisdn
signalling = pri_cpe
group = 1
channel => 1-15;17-31
group =2
channel => 32-46;48-62
```

例 #3 (4xBRI)

```
signaling=bri_cpe
switchtype=euroisdn
group=1
context=from-pstn
channel=>1,2,4,5,7,8,10,11
```

ポイント・ツー・マルチポイントBRIには、signaling=bri_cpe_ptmpを使用してください。現在、BRIポイント・ツー・マルチポイントはNTモードではサポートされていません。

#### カーネルドライバのロード

ドライバを設定した後、サーバーを再起動するだけです。make configでDAHDIをインストールした場合は、追加の作業は必要ありません。カーネルドライバは自動的にロードされ、設定されます。ただし、手動でドライバをロードおよびアンロードすると便利な場合があります。例：

```
modprobe wct11xp
dahdi_cfg -vvvvv
```

最初のコマンドでドライバをロードし、2番目のdahdi_cfgで設定をカーネルドライバに適用します。

### トラブルシューティング

最初からうまくいくとは限りません。DAHDIのトラブルシューティングのためのリソースをいくつか確認しましょう。ステップ1：カードがオペレーティングシステムによって認識されているか確認します。Sangoma/Digiumカードは通常、ISDNモデムとして認識されます。

```
lspci -v
00:00.0 Host bridge: Intel Corporation E7230/3000/3010 Memory Controller Hub
00:01.0 PCI bridge: Intel Corporation E7230/3000/3010 PCI Express Root Port
00:1c.0 PCI bridge: Intel Corporation 82801G (ICH7 Family) PCI Express Port 1 (rev 01)
00:1c.4 PCI bridge: Intel Corporation 82801GR/GH/GHM (ICH7 Family) PCI Express Port 5 (rev
01)
00:1c.5 PCI bridge: Intel Corporation 82801GR/GH/GHM (ICH7 Family) PCI Express Port 6 (rev
01)
00:1d.0 USB Controller: Intel Corporation 82801G (ICH7 Family) USB UHCI Controller #1 (rev
01)
00:1d.1 USB Controller: Intel Corporation 82801G (ICH7 Family) USB UHCI Controller #2 (rev
01)
00:1d.2 USB Controller: Intel Corporation 82801G (ICH7 Family) USB UHCI Controller #3 (rev
01)
00:1d.7 USB Controller: Intel Corporation 82801G (ICH7 Family) USB2 EHCI Controller (rev 01)
00:1e.0 PCI bridge: Intel Corporation 82801 PCI Bridge (rev e1)
00:1f.0 ISA bridge: Intel Corporation 82801GB/GR (ICH7 Family) LPC Interface Bridge (rev 01)
00:1f.1 IDE interface: Intel Corporation 82801G (ICH7 Family) IDE Controller (rev 01)
00:1f.2 IDE interface: Intel Corporation 82801GB/GR/GH (ICH7 Family) SATA IDE Controller (rev
01)
00:1f.3 SMBus: Intel Corporation 82801G (ICH7 Family) SMBus Controller (rev 01)
01:00.0 PCI bridge: Intel Corporation 6702PXH PCI Express-to-PCI Bridge A (rev 09)
01:00.1 PIC: Intel Corporation 6700/6702PXH I/OxAPIC Interrupt Controller A (rev 09)
02:08.0 SCSI storage controller: LSI Logic / Symbios Logic SAS1068 PCI-X Fusion-MPT SAS (rev
01)
03:00.0 PCI bridge: Intel Corporation 6702PXH PCI Express-to-PCI Bridge A (rev 09)
04:02.0 Network controller: Tiger Jet Network Inc. Tiger3XX Modem/ISDN interface
05:00.0 Ethernet controller: Broadcom Corporation NetXtreme BCM5721 Gig. Eth.PCI Express (rev
11)
07:00.0 Ethernet controller: Realtek Semiconductor Co., Ltd. RTL-8139/8139C/8139C+ (rev 10)
07:05.0 VGA compatible controller: ATI Technologies Inc ES1000 (rev 02)
```

ステップ2：以下を使用して、カーネルドライバが正しくロードされているか確認します。

```
modprobe wct11xp
dmesg
TE110P: Setting up global serial parameters for E1 FALC V1.2
TE110P: Successfully initialized serial bus for card
TE110P: Span configured for CAS/HDB3
Calling startup (flags is 4099)
Found a Wildcard: Sangoma Wildcard TE110P T1/E1
TE110P: Span configured for CCS/HDB3/CRC4
Calling startup (flags is 4099)
dahdi: Registered tone zone 0 (United States / North America)
wcte1xxp: Setting yellow alarm
```

ステップ3：接続の物理レイヤーに関連するアラームの状態を確認します。E1接続の物理レイヤーを確認するには、以下のAsterisk CLIコマンドを使用できます。

```
dahdi show status
```

アラームはポートの問題を示します：Red Alarm：リモートスイッチとの同期を維持できません。これは通常、回線符号やフレーミングの不一致などの物理的な問題です。Yellow alarm：リモートスイッチがRed Alarm状態であることを通知します。これは、リモートスイッチがあなたの送信を受信していないことを示します。Blue Alarm：すべてのタイムスロットでフレーム化されていない1を受信しています。dahdi_toolは現在Blue Alarmを検出できません。Loopback：ポートがローカルまたはリモートのループバック状態です。

```
vtsvoffice*CLI> dahdi show status
Description                              Alarms     IRQ        bpviol     CRC4
Sangoma Wildcard E100P E1/PRA Card 0      OK         0          0          0
Wildcard X100P Board 1                   OK         0          0          0
Wildcard X100P Board 2                   RED        0          0          0
```

ステップ4：Asteriskサーバー上のDAHDIの問題を検出するには、まず以下を使用してチャネルが認識されているか確認します。

```
dahdi show channels
pabxip01*CLI> dahdi show channels
   Chan Extension  Context         Language   MOH Interpret
 pseudo            default                    default
      1            from-pstn                  default
      2            from-pstn                  default
      3            from-pstn                  default
      4            from-pstn                  default
      5            from-pstn                  default
      6            from-pstn                  default
      7            from-pstn                  default
      8            from-pstn                  default
      9            from-pstn                  default
     10            from-pstn                  default
     11            from-pstn                  default
     12            from-pstn                  default
     13            from-pstn                  default
     14            from-pstn                  default
     15            from-pstn                  default
     17            from-pstn                  default
     18            from-pstn                  default
     19            from-pstn                  default
     20            from-pstn                  default
     21            from-pstn                  default
     22            from-pstn                  default
     23            from-pstn                  default
     24            from-pstn                  default
     25            from-pstn                  default
     26            from-pstn                  default
     27            from-pstn                  default
     28            from-pstn                  default
     29            from-pstn                  default
     30 2171       from-pstn                  default
     31 2171       from-pstn                  default
```

ステップ5：ISDNレイヤー3（q.931とも呼ばれる）の状態を確認します。以下を使用してISDNレイヤー3がアップしているか確認できます：`pri show spans`（すべてのスパンをリスト表示）または特定のスパンに対して`pri show span <n>`：

```
vtsvoffice*CLI> pri show span 1
Primary D-channel: 16
Status: Provisioned, Up, Active
Switchtype: EuroISDN
Type: CPE
Window Length: 0/7
Sentrej: 0
SolicitFbit: 0
Retrans: 0
Busy: 0
Overlap Dial: 0
T200 Timer: 1000
T203 Timer: 10000
T305 Timer: 30000
T308 Timer: 4000
T313 Timer: 4000
N200 Counter: 3
```

`pri show spans`（複数形）を使用して、設定されているすべてのPRIスパンの状態を一度にリスト表示します。

特定のチャネルを確認します。dahdi show channel x：

```
vtsvoffice*CLI> dahdi show channel 1
Channel: 1
File Descriptor: 21
Span: 1
Extension:
Dialing: no
Context: entrada
Caller ID: 4832341689
Calling TON: 33
Caller ID name:
Destroy: 0
InAlarm: 0
Signalling Type: PRI Signalling
Radio: 0
Owner: <None>
Real: <None>
Callwait: <None>
Threeway: <None>
Confno: -1
Propagated Conference: -1
Real in conference: 0
DSP: no
Relax DTMF: no
Dialing/CallwaitCAS: 0/0
Default law: alaw
```

debug pri span x：すべて試しても問題が解決しない場合は、priスパンのデバッグを開始します。このコマンドはISDN通話の詳細なデバッグを有効にします。何かが正しくないと思われる場合に重要なコマンドです。誤ってダイヤルされた数字やその他の問題を検出できます。以下に、成功した通話のデバッグ出力の例を示します。失敗した通話と問題のない通話を比較する必要がある場合は、この例を参照してください。ヒントとして、core set verbose=0を使用してISDN q.931メッセージのみを受信する方法があります。

```
-- Making new call for cr 32833
> Protocol Discriminator: Q.931 (8)  len=57
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: SETUP (5)
> [04 03 80 90 a3]
> Bearer Capability (len= 5) [ Ext: 1  Q.931 Std: 0  Info transfer capability: Speech (0)
>                              Ext: 1  Trans mode/rate: 64kbps, circuit-mode (16)
>                              Ext: 1  User information layer 1: A-Law (35)
> [18 03 a9 83 81]
> Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
>                        ChanSel: Reserved
>                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
>                       Ext: 1  Channel: 1 ]
> [28 0e 46 6c 61 76 69 6f 20 45 64 75 61 72 64 6f]
> Display (len=14) @h@>[ Flavio Eduardo ]
> [6c 0c 21 80 34 38 33 30 32 35 38 35 39 30]
> Calling Number (len=14) [ Ext: 0  TON: National Number (2)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1)
>                           Presentation: Presentation permitted, user number not screened
(0) '4830258590' ]
> [70 09 a1 33 32 32 34 38 35 38 30]
> Called Number (len=11) [ Ext: 1  TON: National Number (2)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1) '32248580' ]
> [a1]
> Sending Complete (len= 1)
< Protocol Discriminator: Q.931 (8)  len=10
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: CALL PROCEEDING (2)
< [18 03 a9 83 81]
< Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
<                        ChanSel: Reserved
<                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
<                       Ext: 1  Channel: 1 ]
-- Processing IE 24 (cs0, Channel Identification)
< Protocol Discriminator: Q.931 (8)  len=9
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: ALERTING (1)
< [1e 02 84 88]
< Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Public network serving the remote user (4)
<                               Ext: 1  Progress Description: Inband information or
appropriate pattern now available. (8) ]
-- Processing IE 30 (cs0, Progress Indicator)
< Protocol Discriminator: Q.931 (8)  len=64
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: SETUP (5)
< [04 03 80 90 a3]
< Bearer Capability (len= 5) [ Ext: 1  Q.931 Std: 0  Info transfer capability: Speech (0)
<                              Ext: 1  Trans mode/rate: 64kbps, circuit-mode (16)
<                              Ext: 1  User information layer 1: A-Law (35)
< [18 03 a1 83 82]
< Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Preferred Dchan: 0
<                        ChanSel: Reserved
<                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
<                       Ext: 1  Channel: 2 ]
< [1c 15 91 a1 12 02 01 bc 02 01 0f 30 0a 02 01 01 0a 01 00 a1 02 82 00]
< Facility (len=23, codeset=0) [ 0x91, 0xa1, 0x12, 0x02, 0x01, 0xbc, 0x02, 0x01, 0x0f, '0',
0x0a, 0x02, 0x01, 0x01, 0x0a, 0x01, 0x00, 0xa1, 0x02, 0x82, 0x00 ]
< [1e 02 82 83]
< Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Public network serving the local user (2)
<                               Ext: 1  Progress Description: Calling equipment is non-ISDN.
(3) ]
< [6c 0c 21 83 34 38 33 32 32 34 38 35 38 30]
< Calling Number (len=14) [ Ext: 0  TON: National Number (2)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1)
<                           Presentation: Presentation allowed of network provided number (3)
'4832248580' ]
< [70 05 c1 38 35 38 30]
< Called Number (len= 7) [ Ext: 1  TON: Subscriber Number (4)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1) '8580' ]
< [a1]
< Sending Complete (len= 1)
-- Making new call for cr 5720
-- Processing Q.931 Call Setup
-- Processing IE 4 (cs0, Bearer Capability)
-- Processing IE 24 (cs0, Channel Identification)
-- Processing IE 28 (cs0, Facility)
Handle Q.932 ROSE Invoke component
-- Processing IE 30 (cs0, Progress Indicator)
-- Processing IE 108 (cs0, Calling Party Number)
-- Processing IE 112 (cs0, Called Party Number)
-- Processing IE 161 (cs0, Sending Complete)
> Protocol Discriminator: Q.931 (8)  len=10
> Call Ref: len= 2 (reference 5720/0x1658) (Terminator)
> Message type: CALL PROCEEDING (2)
> [18 03 a9 83 82]
> Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
>                        ChanSel: Reserved
>                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
>                       Ext: 1  Channel: 2 ]
> Protocol Discriminator: Q.931 (8)  len=14
> Call Ref: len= 2 (reference 5720/0x1658) (Terminator)
> Message type: CONNECT (7)
> [18 03 a9 83 82]
> Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
>                        ChanSel: Reserved
>                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
>                       Ext: 1  Channel: 2 ]
> [1e 02 81 82]
> Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Private network serving the local user (1)
>                               Ext: 1  Progress Description: Called equipment is non-ISDN.
(2) ]
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: CONNECT ACKNOWLEDGE (15)
< Protocol Discriminator: Q.931 (8)  len=9
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: PROGRESS (3)
< [1e 02 84 82]
< Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Public network serving the remote user (4)
<                               Ext: 1  Progress Description: Called equipment is non-ISDN.
(2) ]
-- Processing IE 30 (cs0, Progress Indicator)
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: CONNECT (7)
> Protocol Discriminator: Q.931 (8)  len=5
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: CONNECT ACKNOWLEDGE (15)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Active, peerstate Connect Request
> Protocol Discriminator: Q.931 (8)  len=9
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: DISCONNECT (69)
> [08 02 81 90]
> Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Private network
serving the local user (1)
>                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: RELEASE (77)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Null, peerstate Release Request
> Protocol Discriminator: Q.931 (8)  len=9
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: RELEASE COMPLETE (90)
> [08 02 81 90]
> Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Private network
serving the local user (1)
>                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Null, peerstate Null
NEW_HANGUP DEBUG: Destroying the call, ourstate Null, peerstate Null
< Protocol Discriminator: Q.931 (8)  len=9
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: DISCONNECT (69)
< [08 02 82 90]
< Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Public network
serving the local user (2)
<                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
-- Processing IE 8 (cs0, Cause)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Disconnect Indication, peerstate Disconnect
Request
> Protocol Discriminator: Q.931 (8)  len=9
> Call Ref: len= 2 (reference 5720/0x1658) (Terminator)
> Message type: RELEASE (77)
> [08 02 81 90]
> Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Private network
serving the local user (1)
>                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: RELEASE COMPLETE (90)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Null, peerstate Null
NEW_HANGUP DEBUG: Destroying the call, ourstate Null, peerstate Null
```

### chan_dahdi.confの設定オプション

chan_dahdi.confファイルには多くのオプションが用意されています。すべてのオプションを説明するのは退屈で非効率的です。ここでは、より深く理解するために、利用可能な主要なオプショングループを詳しく説明します。

#### 一般オプション（チャネル非依存）

context：着信コンテキストを定義します。

```
context=default
```

channel：チャネルまたはチャネル範囲を定義します。各チャネル定義は、宣言の前に定義されたオプションを継承します。チャネルは個別に、またはカンマ区切りで同じ行に指定できます。範囲は“-”を使用して定義できます。

```
Channel=>1-15
Channel=>16
Channel=>17,18
```

group：チャネルをグループとして扱うことを可能にします。チャネル番号の代わりにグループ番号をダイヤルすると、利用可能な最初のチャネルが使用されます。チャネルが電話機である場合、グループを呼び出すとすべての電話機が同時に鳴ります。カンマを使用すると、同じチャネルに対して複数のグループを指定できます。

```
group=1
group=3,5
```

language：国際化を有効にし、言語を設定します。この機能は、特定の言語のシステムメッセージを設定します。標準インストールで完全なプロンプトが利用可能な言語は英語のみです。musiconhold：保留音クラスを選択します。

#### ISDNオプション

switchtype：使用されるPBXまたはスイッチに依存します。ヨーロッパやラテンアメリカではEuroISDNが一般的です。

- 5ess：Lucent 5ESS
- euroisdn：EuroISDN
- national：National ISDN
- dms100：Nortel DMS100
- 4ess：AT&T 4ESS
- Qsig：Q.SIG

```
switchtype = EuroISDN
```

pridialplan：ダイヤルプランの指定が必要な一部のスイッチで必要です。このオプションは多くのスイッチで無視されます。有効なオプションはprivate、national、international、unknownです。

```
pridialplan = unknown
```

prilocaldialplan：一部のスイッチで必要です。通常はunknownです。

```
prilocaldialplan = unknown
```

overlapdial：オーバーラップダイヤルは、接続が確立された後に数字を送信する場合に使用されます。ブロックモード番号付け（overlapdial=no）または桁モード（overlapdial=yes）を使用できます。ブロックモードはオペレーターによってよく使用されます。signaling：後続のチャネルの信号方式タイプを設定します。これらのパラメータは、chan_dahdi.confファイル内のパラメータと一致する必要があります。正しい選択は、利用可能なチャネルに基づきます。ISDNの場合、5つのオプションを選択できます。

- pri_cpe：デバイスがCPE（クライアント、ユーザー、またはスレーブと呼ばれることもある）である場合に使用されます。これは最も単純で最も使用される信号方式です。プライベートPBXに接続しようとすると、PBXもCPEとして設定されていることがよくあります。その場合は、Asteriskでpri_net信号方式を使用してください。
- pri_net：AsteriskがCPEとして設定されたプライベートPBXに接続されている場合に使用されます。信号方式は、ホスト、マスター、またはネットワークと呼ばれることがよくあります。
- bri_cpe：AsteriskがISDN BRIトランクにCPEとして接続されている場合に使用されます。
- bri_net：Asteriskが端末（TE）として設定されたISDN電話機またはPBXに接続されている場合に使用されます。
- bri_cpe_ptmp：bri_cpeと同じですが、ポイント・ツー・マルチポイントアーキテクチャで使用されます。

#### CallerIDオプション

多くのCaller IDオプションが利用可能です。一部は無効にできますが、ほとんどはデフォルトで有効になっています。usecallerid：後続のチャネルのCaller ID送信を有効または無効にします（Yes/No）。注意：システムが応答する前に2回の呼び出し音を必要とする場合は、すぐに応答するようにこの機能を無効にしてみてください。hidecallerid：Caller IDを非表示にします（Yes/No）。calleridcallwaiting：キャッチホン通知中にCaller IDの受信を有効にします（Yes/No）。callerid：特定のチャネルのCaller ID文字列を設定します。トランクインターフェースでは、Caller IDを転送するために“asreceived”を設定できます。

```
callerid = "Flavio Eduardo Gonçalves" <48 30258500>
```

注意：ほとんどの通信事業者は、正しいCaller IDを設定することを義務付けています。正しいCaller IDを渡さないと、通信事業者経由でダイヤルアウトできない場合があります。一方で、Caller IDを設定しなくても通話を受信することは可能です。

#### 音質オプション

これらのオプションは、DAHDIチャネルの音質に影響を与える特定のAsteriskパラメータを調整します。

- **echocancel**：エコーキャンセレーションを無効または有効にします。この機能は有効にしておくべきです。"yes"またはタップ数を受け入れます。（解説：エコーキャンセレーションはどのように機能するか？ほとんどのエコーキャンセレーションアルゴリズムは、受信信号の複数のコピーを生成し、それぞれを短い間隔で遅延させることで動作します。この小さな流れは「タップ」と呼ばれます。タップ数は、キャンセル可能なエコー遅延を決定します。これらのコピーは遅延、調整され、元の信号から差し引かれます。コツは、エコーを除去するために必要な分だけ遅延信号を正確に調整することです。）
- **echocancelwhenbridged**：純粋なTDM通話中にエコーキャンセラーを有効または無効にします。これは通常必要ありません。
- **rxgain**：受信音量を増減させるために受信ゲインを調整します（-100%から100%）。
- **txgain**：送信音量を増減させるために送信ゲインを調整します（-100%から100%）。

例：

```
echocancel=yes
echocancelwhenbridged=yes
txgain=-10%
rxgain=10%
```

#### 課金オプション

これらのオプションは、通話詳細記録（CDR）データベースに通話情報が記録される方法を変更します。amaflags：CDRの分類に影響します。以下の値を受け入れます。

- billing
- documentation
- omit
- default

accountcode：特定のチャネルのアカウントコードを設定します。英数字の値を含めることができ、通常は部門名やユーザー名です。

```
accountcode=finance
amaflags=billing
```

### MFC/R2設定

MFC/R2は、ラテンアメリカ、中国、アフリカのいくつかの国、および一部のヨーロッパ諸国で使用されています。ISDNの方が優れており、利用可能であればそちらが推奨されます。

#### 問題の理解

MFC/R2の信号に使用されるカードは、ISDNの信号に使用されるものと同じです。libopenR2（www.libopenr2.com）というライブラリを使用して、DAHDIチャネルでMFC/R2を使用することが可能です。このライブラリは、1.6.2より前のAsteriskバージョンには含まれていませんでした。

##### MFC/R2プロトコルの理解

MFC/R2プロトコルは、インバンド信号とアウトオブバンド信号を組み合わせたものです。アドレス信号は一連のトーンを使用してインバンドで転送され、チャネル情報はアウトオブバンド信号としてタイムスロット16を介して送信されます。

**回線信号（ITU-T Q.421）。** タイムスロット16では、各音声チャネルが4つのABCDビットを使用して状態と通話制御を通知します。CビットとDビットはめったに使用されません。一部の国では、課金用（課金パルス）に使用されることがあります。通常の会話では、発信側と着信側の両方が動作します。発信側からの信号は前方信号と呼ばれ、着信側は後方信号を使用します。前方信号をAfとBf、後方信号をAbとBbと呼びます。

| 状態 | ABCD 前方 | ABCD 後方 |
| --- | --- | --- |
| アイドル/解放 | 1001 | 1001 |
| 捕捉（Seized） | 0001 | 1001 |
| 捕捉確認 | 0001 | 1101 |
| 応答 | 0001 | 0101 |
| クリアバック | 0001 | 1101 |
| クリアフォワード（クリアバック前） | 1001 | 0101 |
| クリアフォワード（切断確認） | 1001 | 1001 |
| ブロック | 1001 | 1101 |

MFC/R2はITUによって定義されました。残念ながら、いくつかの国は標準を自国のニーズに合わせてカスタマイズしました。その結果、国間で標準のバリエーションが生じました。

**レジスタ間信号（ITU-T Q.441）。** MFC/R2信号は2つのトーンの組み合わせを使用します。以下の表はITU標準を示しています。

信号グループ I (前方):

| 説明 | 前方信号 |
| --- | --- |
| 数字 1 | I-1 |
| 数字 2 | I-2 |
| 数字 3 | I-3 |
| 数字 4 | I-4 |
| 数字 5 | I-5 |
| 数字 6 | I-6 |
| 数字 7 | I-7 |
| 数字 8 | I-8 |
| 数字 9 | I-9 |
| 数字 0 | I-10 |
| 国コードインジケータ、発信側ハーフエコーサプレッサが必要 | I-11 |
| 国コードインジケータ、エコーサプレッサ不要 | I-12 |
| テスト通話インジケータ | I-13 |
| 国コードインジケータ、発信側ハーフエコーサプレッサ挿入済み | I-14 |
| 未使用 | I-15 |

信号グループ II (前方):

| 説明 | 前方信号 |
| --- | --- |
| 優先順位なし加入者 | II-1 |
| 優先順位あり加入者 | II-2 |
| 保守機器 | II-3 |
| 予備 | II-4 |
| オペレーター | II-5 |
| データ伝送 | II-6 |
| 前方転送機能なしの加入者またはオペレーター | II-7 |
| データ伝送 | II-8 |
| 優先順位あり加入者 | II-9 |
| 前方転送機能ありのオペレーター | II-10 |
| 予備 | II-11 |
| 予備 | II-12 |
| 予備 | II-13 |
| 予備 | II-14 |
| 予備 | II-15 |

信号グループ A (後方):

| 説明 | 後方信号 |
| --- | --- |
| 次の数字を送信 (n+1) | A-1 |
| 最後から2番目の数字を送信 (n-1) | A-2 |
| アドレス完了、グループB信号の受信へ切り替え | A-3 |
| 国内ネットワークの輻輳 | A-4 |
| 発信者のカテゴリを送信 | A-5 |
| アドレス完了、課金、通話条件の設定 | A-6 |
| 最後から3番目の数字を送信 (n-2) | A-7 |
| 最後から4番目の数字を送信 (n-3) | A-8 |
| 予備 | A-9 |
| 予備 | A-10 |
| 国コードインジケータを送信 | A-11 |
| 言語または識別数字を送信 | A-12 |
| 回線の性質を送信 | A-13 |
| エコーサプレッサの使用に関する情報を要求 | A-14 |
| 国際交換機またはその出力での輻輳 | A-15 |

信号グループ B (後方):

| 説明 | 後方信号 |
| --- | --- |
| 予備 | B-1 |
| 特別情報トーンを送信 | B-2 |
| 加入者回線使用中 | B-3 |
| 輻輳（グループAからBへの切り替え後） | B-4 |
| 未割り当て番号 | B-5 |
| 加入者回線空き、課金 | B-6 |
| 加入者回線空き、課金なし | B-7 |
| 加入者回線故障中 | B-8 |
| 予備 | B-9 |
| 予備 | B-10 |
| 予備 | B-11 |
| 予備 | B-12 |
| 予備 | B-13 |
| 予備 | B-14 |
| 予備 | B-15 |

#### MFC/R2シーケンス

以下のシーケンスは、Asteriskの内線からPSTNの端末への通話発信を示しています。PSTNが通話を切断し、通信を終了します。

![Asteriskと通信事業者間の完全なMFC/R2通話フロー：回線信号（アイドル、捕捉、捕捉確認、応答、クリアバック、クリアフォワード）はタイムスロット16で交換され、ダイヤルされた数字と後方「次の数字を送信」信号（グループI/A/B）はインバンドで伝送され、可聴トーンが加入者に届きます。](../images/10-legacy-fig11.png)

### libopenr2ドライバの使用方法

Moises Silvaによって開始されたプロジェクトは、Steve Underwoodによって書かれたUnicallチャネルドライバに触発されました。OpenR2ライブラリは、現在Asteriskにとって最も安定したソフトウェアソリューションです。このソリューションにより、DAHDIと互換性のあるあらゆるデジタルカードを使用できます。以前はMFC/R2には独自のソリューションしかありませんでしたが、私が使用した中で最高のものの一つはKhomp（www.khomp.com.br）が提供するものです。Asterisk 22では、コンパイル時にライブラリが存在すれば、libopenR2によるMFC/R2サポートが組み込まれます。外部パッチは不要です。以下の手順は参考のための歴史的な手動インストールを示しています。最新のシステムでは、パッケージマネージャーから`libopenr2-dev`をインストールしてから`./configure`を実行し、次に`make menuselect`で`chan_dahdi`を有効にします。

以下の手順は、現在のGitリポジトリからopenr2とAsteriskをビルドします。これらはソースからビルドするサイトのための参考として保持されています。最新のディストリビューションでは、通常`libopenr2-dev`パッケージとパッケージ化されたAsterisk 22ビルドをインストールすることで完全にスキップできます。これは`chan_dahdi`が外部パッチなしでlibopenr2に対して直接R2サポートをコンパイルするためです。

ステップ1：必要なビルドツールをインストールします。

```
apt-get install git
```

ステップ2：openr2ライブラリとAsteriskソースをクローンします。Asterisk 22では特別なパッチ適用済みツリーは必要ありません。libopenr2が存在する限り、標準のチェックアウトでR2サポートがビルドされます。

```
cd /usr/src
git clone https://github.com/moises-silva/openr2.git
git clone https://github.com/asterisk/asterisk.git
```

ステップ3：コンパイルとインストール。進める前にサーバーをバックアップしてください。

```
cd /usr/src/openr2
./configure && make && make install && ldconfig
cd /usr/src/asterisk
./configure && make menuselect && make && make install
```

注意：設定ファイルが上書きされないように、“make samples”は実行しないでください。

```
Step 4: Changing the file /etc/dahdi/system.conf:
vim /etc/dahdi/system.conf
```

1つのE1インターフェースを持つカードがあると仮定します。

```
span=1,1,0,cas,hdb3
cas=1-15:1101
cas=17-31:1101
dchan=16
loadzone=br
defaultzone=br
```

ステップ5：dahdi_cfgコマンドを実行して、ドライバに変更を適用します。

```
dahdi_cfg -vvvvvvvv
Dahdi Version:SVN-branch-1.4-r4348
Echo Canceller: MG2
Configuration
======================
SPAN 1: CAS/HDB3 Build-out: 0 db (CSU)/0-133 feet (DSX-1)
Channel map:
Channel 01: CAS / User (Default) (Slaves: 01)
Channel 02: CAS / User (Default) (Slaves: 02)
Channel 03: CAS / User (Default) (Slaves: 03)
Channel 04: CAS / User (Default) (Slaves: 04)
Channel 05: CAS / User (Default) (Slaves: 05)
Channel 06: CAS / User (Default) (Slaves: 06)
Channel 07: CAS / User (Default) (Slaves: 07)
Channel 08: CAS / User (Default) (Slaves: 08)
Channel 09: CAS / User (Default) (Slaves: 09)
Channel 10: CAS / User (Default) (Slaves: 10)
Channel 11: CAS / User (Default) (Slaves: 11)
Channel 12: CAS / User (Default) (Slaves: 12)
Channel 13: CAS / User (Default) (Slaves: 13)
Channel 14: CAS / User (Default) (Slaves: 14)
Channel 15: CAS / User (Default) (Slaves: 15)
Channel 16: D-channel (Default) (Slaves: 16)
Channel 17: CAS / User (Default) (Slaves: 17)
Channel 18: CAS / User (Default) (Slaves: 18)
Channel 19: CAS / User (Default) (Slaves: 19)
Channel 20: CAS / User (Default) (Slaves: 20)
Channel 21: CAS / User (Default) (Slaves: 21)
Channel 22: CAS / User (Default) (Slaves: 22)
Channel 23: CAS / User (Default) (Slaves: 23)
Channel 24: CAS / User (Default) (Slaves: 24)
Channel 25: CAS / User (Default) (Slaves: 25)
Channel 26: CAS / User (Default) (Slaves: 26)
Channel 27: CAS / User (Default) (Slaves: 27)
Channel 28: CAS / User (Default) (Slaves: 28)
Channel 29: CAS / User (Default) (Slaves: 29)
Channel 30: CAS / User (Default) (Slaves: 30)
Channel 31: CAS / User (Default) (Slaves: 31)
31 channels to configure.
-----------------------------------------------------------------------
```

ステップ5：chan_dahdi.confファイルを変更します。

```
vim /etc/asterisk/chan_dahdi.conf
[channels]
usecallerid=yes
callwaiting=yes
usecallingpres=yes
callwaitingcallerid=yes
threewaycalling=yes
transfer=yes
canpark=yes
cancallforward=yes
callreturn=yes
echocancel=yes
echotrainning=yes
echocancelwhenbridged=yes
signalling=mfcr2
mfcr2_variant=br
mfcr2_get_ani_first=no
mfcr2_max_ani=20
mfcr2_max_dnis=4
mfcr2_category=national_subscriber
mfcr2_logdir=span1
mfcr2_logging=all
group=1
callgroup=1
pickupgroup=1
callerid=asreceived
context=from-mfcr2
channel => 1-15,17-31
```

ステップ6：extensions.confファイルのダイヤルプランを変更します。

```
vim /etc/asterisk/extensions.conf
[default]
exten => _XXXXXXXX,1,Set(CALLERID(num)=1145678990)
exten => _XXXXXXXX,n,Dial(DAHDI/g1/${EXTEN},60,tT)
```

注意：一部の通信事業者は、Caller IDなしの通話を受け付けません。通信事業者から割り当てられたDID番号のいずれかをCaller IDに設定してください。一部の国では、この手順は不要です。ステップ7：ソリューションのテスト：from-internalコンテキストの内線から任意の番号に電話をかけ、コンソールを観察します。エラーが発生していないか確認してください。 -- Executing Set("SIP/8564-081ca5d8", "CALLERID(num)=1145678990") in new stack -- Executing Dial("SIP/8564-081ca5d8", "DAHDI/g1/35678899|60|tT") in new stack

#### OpenR2のデバッグ

通話のエラーを検出するには、デバッグを有効にできます。これを行うには、以下の手順に従ってください。

1. `chan_dahdi.conf`ファイルを編集し、設定に以下の3行を追加します。

```
mfcr2_logdir=span1
mfcr2_logging=all
mfcr2_call_files=yes
```

2. Asteriskサーバーを再起動します。
3. 通話をテストし、`/var/log/asterisk/mfcr2/span1`で通話ファイルを確認します。

以下は通常の通話のトレースです。受信した通話と比較してください。

```
[15:05:47:710] [Thread: 3078019984] [Chan 1] - Call started at Mon Jul  6 15:05:47 2009 on
chan 1
[15:05:47:710] [Thread: 3078019984] [Chan 1] - CAS Tx >> [SEIZE] 0x00
[15:05:47:710] [Thread: 3078019984] [Chan 1] - CAS Raw Tx >> 0x01
[15:05:47:951] [Thread: 3078019984] [Chan 1] - Bits changed from 0x08 to 0x0C
[15:05:47:951] [Thread: 3078019984] [Chan 1] - CAS Rx << [SEIZE ACK] 0x0C
[15:05:47:951] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 2
[15:05:47:951] [Thread: 3078019984] [Chan 1] - timer id 2 found, cancelling it now
[15:05:47:951] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 3
[15:05:47:951] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [ON]
[15:05:48:070] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:070] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:070] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:070] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [OFF]
[15:05:48:150] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:150] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 0
[15:05:48:150] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [ON]
[15:05:48:150] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:250] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:250] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:250] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:250] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [OFF]
[15:05:48:350] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:350] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 2
[15:05:48:350] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [ON]
[15:05:48:350] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:450] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:450] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:450] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:450] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [OFF]
[15:05:48:550] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:550] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 5
[15:05:48:550] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [ON]
[15:05:48:550] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:650] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:650] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:650] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:650] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [OFF]
[15:05:48:750] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:750] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 8
[15:05:48:750] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [ON]
[15:05:48:750] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:850] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:850] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:850] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:850] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [OFF]
[15:05:48:950] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:950] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 5
[15:05:48:950] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [ON]
[15:05:48:950] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:49:050] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:49:050] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:050] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:050] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [OFF]
[15:05:49:150] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:49:150] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 8
[15:05:49:150] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [ON]
[15:05:49:150] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:49:250] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:49:250] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:250] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:250] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [OFF]
[15:05:49:330] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:49:330] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 4
[15:05:49:330] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [ON]
[15:05:49:330] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:49:590] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:49:590] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:590] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:590] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [OFF]
[15:05:49:670] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:49:670] [Thread: 3078019984] [Chan 1] - Sending category National Subscriber
[15:05:49:670] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:49:770] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:49:770] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:770] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:770] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:49:850] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:49:850] [Thread: 3078019984] [Chan 1] - Sending ANI digit 4
[15:05:49:850] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [ON]
[15:05:49:930] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:49:930] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:930] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:930] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [OFF]
[15:05:50:030] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:030] [Thread: 3078019984] [Chan 1] - Sending ANI digit 8
[15:05:50:030] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [ON]
[15:05:50:130] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:130] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:130] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:130] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [OFF]
[15:05:50:230] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:230] [Thread: 3078019984] [Chan 1] - Sending ANI digit 3
[15:05:50:230] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [ON]
[15:05:50:330] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:330] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:330] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:330] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [OFF]
[15:05:50:430] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:430] [Thread: 3078019984] [Chan 1] - Sending ANI digit 0
[15:05:50:430] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [ON]
[15:05:50:530] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:530] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:530] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:530] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [OFF]
[15:05:50:610] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:610] [Thread: 3078019984] [Chan 1] - Sending ANI digit 2
[15:05:50:610] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [ON]
[15:05:50:710] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:710] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:710] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:710] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [OFF]
[15:05:50:810] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:810] [Thread: 3078019984] [Chan 1] - Sending ANI digit 7
[15:05:50:810] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [ON]
[15:05:50:910] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:910] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:910] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:910] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [OFF]
[15:05:51:010] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:010] [Thread: 3078019984] [Chan 1] - Sending ANI digit 2
[15:05:51:010] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [ON]
[15:05:51:110] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:110] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:110] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:110] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [OFF]
[15:05:51:210] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:210] [Thread: 3078019984] [Chan 1] - Sending ANI digit 1
[15:05:51:210] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:51:310] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:310] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:310] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:310] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:51:410] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:410] [Thread: 3078019984] [Chan 1] - Sending ANI digit 7
[15:05:51:410] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [ON]
[15:05:51:510] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:510] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:510] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:510] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [OFF]
[15:05:51:610] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:610] [Thread: 3078019984] [Chan 1] - Sending ANI digit 1
[15:05:51:610] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:51:710] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:710] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:710] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:710] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:51:810] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:810] [Thread: 3078019984] [Chan 1] - Sending more ANI unavailable
[15:05:51:810] [Thread: 3078019984] [Chan 1] - MF Tx >> F [ON]
[15:05:51:990] [Thread: 3078019984] [Chan 1] - MF Rx << 3 [ON]
[15:05:51:990] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:990] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:990] [Thread: 3078019984] [Chan 1] - MF Tx >> F [OFF]
[15:05:52:090] [Thread: 3078019984] [Chan 1] - MF Rx << 3 [OFF]
[15:05:52:090] [Thread: 3078019984] [Chan 1] - Sending category National Subscriber
[15:05:52:090] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:53:350] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:53:350] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:53:350] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:53:350] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:53:430] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:06:03:322] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:06:03:322] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:06:03:322] [Thread: 3078019984] [Chan 1] - CAS Tx >> [CLEAR FORWARD] 0x08
[15:06:03:322] [Thread: 3078019984] [Chan 1] - CAS Raw Tx >> 0x09
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Bits changed from 0x0C to 0x08
[15:06:03:569] [Thread: 3085228944] [Chan 1] - CAS Rx << [IDLE] 0x08
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Call ended
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Attempting to cancel timer timer 0
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Cannot cancel timer 0
```

#### MFC/R2設定

オプションはchan_dahdi.confファイル内に文書化されています。最も重要なオプションのいくつかをここで詳しく説明します。必須パラメータ：mfcr2_variant, mfcr2_max_ani, mfcr2_max_dnis。mfcr2_variant：国別バリエーション。

```
r2test -l
Variant Code        Country
AR                  Argentina
BR                  Brazil
CN                  China
CZ                  Czech Republic
CO                  Colombia
EC                  Ecuador
ITU                 International Telecommunication Union
MX                  Mexico
PH                  Philippines
VE                  Venezuela
```

mfcr2_max_ani：要求するANI桁数の最大値。mfcr2_max_dnis：要求するDNIS桁数の最大値。mfcr2_get_ani_first：DNISの前にANIを取得するかどうか（一部の通信事業者で必要）。mfcr2_category：発信者カテゴリ。通話を開始する前に変数MFCR2_CATEGORYを設定できます。mfcr2_logdir：通話ファイルを記録するディレクトリ（/var/log/asterisk/mfcr2/directory）。mfcr2_call_files：通話を記録するかどうか。

- mfcr2_logging：ログ値
- cas – 送受信用のABCDビット
- mf – 多周波トーン
- stack – チャネルおよびコンテキストスタックの詳細出力
- all – すべてのアクティビティ
- nothing – 何も記録しない

mfcr2_mfback_timeout：この値は言及する価値があります。携帯電話への通話や完了までに時間がかかる通話の場合、このパラメータがタイムアウトする可能性があるため、微調整のために変更されることがよくあります。通話が完了しない場合は、まずこのパラメータを変更する必要があります。mfcr2_metering_pulse_timeout：パルスは、一部のR2バリエーションでコストを示すために使用されます。mfcr2_allow_collect_calls：ブラジルでは、トーンII-8がコレクトコールを示すために使用されます。このパラメータを使用すると、コレクトコールをブロックできます。mfcr2_double_answer：二重応答が必要な場合にコレクトコールを回避するためにも使用されます。double_answer=yesにすると、実質的にコレクトコールをブロックします。mfcr2_immediate_accept：グループB/II信号の使用をスキップし、直接受け入れ状態に進むことができます。mfcr2_forced_release：通話の解放を高速化できます。ブラジルのバリエーションで機能します。

#### ANIとDNIS

自動番号識別（ANI）は発信者の番号です。ダイヤル番号識別サービス（DNIS）は呼び出された番号、つまりダイヤルされた番号です。通話を受信すると、通常、直通ダイヤルイン（DID）と呼ばれるプロセスで、最後の4桁がPBXに渡されます。ANI番号は実際にはCaller IDです。ダイヤル時にANIには発信者の内線番号が含まれ、DNISには通話先が含まれます。これらのパラメータが正しく設定されていることが重要です。一部のスイッチは最後の4桁のみを送信し、他のスイッチは完全な番号を送信します。

### DAHDIチャネル形式

DAHDIチャネルは、ダイヤルプランで以下の形式を使用します。

```
DAHDI/[g]<identifier>[c][r<cadence>]
<identifier> - Physical channel numeric identifier
[g] - Group identifier
[c] - Answer confirmation. A number is not considered until the callee presses "#"
[r] - customized ringing
[cadence] - Integer from 1 to 4
```

例：

```
DAHDI/2     - channel 2
DAHDI/g1    - First available channel in group 1
```

## The IAX2 protocol

本章では、Inter-Asterisk eXchange (IAX) プロトコルの長所と短所を含め、その詳細について学習します。トランクモードや2台の Asterisk サーバー間の相互接続といった詳細についても解説します。本書におけるすべての言及は、IAX バージョン 2 に対応しています。

IAX プロトコルは、音声およびビデオのためのメディア転送とシグナリングを提供します。IAX は非常に革新的であり、トランクモードでは帯域幅を節約でき、NAT を通過する必要がある場合には SIP よりもはるかにシンプルです。現在、IAX の主な用途は Asterisk サーバー同士の相互接続です。IAX は主に音声用に作成されましたが、ビデオやその他のマルチメディアストリームにも対応可能です。

IAX は、SIP や MGCP といった他の VoIP プロトコルから着想を得ています。IAX は、シグナリングとメディアに別々のプロトコルを使用するのではなく、それらを統合して独自のプロトコルにしました。IAX はメディア転送に RTP を使用せず、代わりに同じ UDP 接続内にメディアを埋め込みます。

**Asterisk 22 におけるステータス。** `chan_iax2` は Asterisk 22 LTS にも引き続き含まれており、完全にサポートされているため、このセクションの内容はすべて有効です。ただし、IAX2 はレガシープロトコルであり、新規導入は比較的少なくなっています。業界は、プロバイダーのトランク接続とサーバー間の相互接続の両方において、SIP（Asterisk 22 では `chan_pjsip` を使用）に大きく収束しています。IAX2 の現在残されている主な利点は、シングルポート設計です。すべてのシグナリングとメディアが単一の UDP ポート（デフォルトで 4569）を流れるため、SIP とその個別の RTP ストリームと比較して、ファイアウォールや NAT の設定が簡素化されます。NAT が懸念されない新規の Asterisk 間トランク接続には、PJSIP トランクが推奨される現代的なアプローチです。IAX2 は、特にファイアウォールを通過できる UDP ポートが1つしかない場合など、依然として有効な選択肢であるため、ここで取り上げています。

### 学習目標

本章を読み終えると、以下のことができるようになります。

- IAX プロトコルの長所と短所を特定する
- IAX プロトコルの利用シナリオを説明する
- IAX トランクモードの利点を説明する
- 電話機用に iax.conf を設定する
- VoIP プロバイダーへの接続用に iax.conf を設定する
- Asterisk 相互接続用に iax.conf を設定する
- IAX 認証を理解する

### IAX の設計

IAX 設計の主な目的は以下の通りです。

- メディア転送とシグナリングに必要な帯域幅を削減すること
- NAT トランスペアレンシー（透過性）を提供すること
- dialplan 情報を送信できるようにすること
- ページングとインターコムを効率的にサポートすること

IAX は、RTP を使用しない SIP に似たピアツーピアのシグナリングおよびメディアプロトコルです。基本的なアプローチは、2つのホスト間の単一の UDP 接続上でマルチメディアストリームを多重化することです。このアプローチの最大の利点は、xDSL モデムなどで一般的に見られる NAT を介した接続を通過する際のシンプルさです。IAX は単一のポート（デフォルトで UDP 4569）を使用し、15ビットのコール番号を使用してすべてのストリームを多重化します。IAX プロトコルは、SIP プロトコルと同様の登録および認証プロセスを使用します。プロトコルの詳細については、http://www.ietf.org/internet-drafts/draft-guy-iax-05.txt を参照してください。

![IAX プロトコルは、単一の UDP ポート（デフォルトで 4569）上で2つのエンドポイント間の多くの通話を多重化し、15ビットのコール番号を使用してストリームを分離します。これにより、NAT トラバーサルが単純化されます。]((../images/10-legacy-fig12.png))

### 帯域幅の使用量

VoIP ネットワークで使用される帯域幅は、いくつかの要因に影響されます。その中で最も重要なのは codec とプロトコルヘッダーです。IAX プロトコルには、トランクモードと呼ばれる驚くべき機能があり、単一のヘッダーを使用して複数の通話を多重化します。Asterisk 帯域幅計算ツールを使用すると、IAX トランクが複数の通話でトラフィックを最大 80% 節約できることがわかります。

![IAX と SIP のオーバーヘッドの比較：2つの SIP/RTP 通話には2つのパケットが必要（156バイトのオーバーヘッドの下で 40バイトのペイロードを運ぶ）ですが、IAX2 トランクモードでは、多くのミニフレーム間で1つの IP/UDP ヘッダーを共有することにより、両方の通話を単一のパケット（わずか 66バイトのオーバーヘッドの下で 40バイトのペイロード）で運びます。]((../images/10-legacy-fig13.png))

### チャネルの命名

dialplan でチャネルを指定する際にこれらの名前を使用するため、チャネル命名規則を理解しておくことが重要です。アウトバウンドチャネルに使用される IAX チャネル名の形式は以下の通りです。

```
IAX/[<user>[:<secret>]@]<peer>[:<portno>][/<exten>[@<context>][/<options>]
```

- `<user>` — リモートピア上の UserID、または iax.conf で設定されたクライアント名
- `<secret>` — パスワード。あるいは、末尾の拡張子（.key または .pub）を除き、角括弧で囲まれた RSA キーのファイル名でも可
- `<peer>` — 接続先サーバー名
- `<portno>` — 接続用ポート番号
- `<exten>` — リモート Asterisk サーバー内の extension
- `<context>` — リモート Asterisk サーバー内の context
- `<options>` — 利用可能な唯一のオプションは 'a' であり、'request autoanswer' を意味します

#### アウトバウンドチャネルの例：

アウトバウンドチャネルは Asterisk コンソールで確認できます。

- `IAX2/8590:secret@myserver/8590@default` — myserver の 8590 extension を呼び出します。名前/パスワードのペアとして 8590:secret を使用します
- `IAX2/iaxphone` — "iaxphone" を呼び出します
- `IAX2/judy:[judyrsa]@somewhere.com` — ユーザー名に judy を使用し、認証に RSA キーを使用して somewhere.com を呼び出します

#### インバウンド IAX チャネルの形式は以下の通りです：

インバウンドチャネルは Asterisk コンソールで確認できます。

```
IAX2/[<username>@]<host>]-<callno>
```

- `<username>` — 既知の場合のユーザー名
- `<host>` — 接続元ホスト
- `<callno>` — ローカルコール番号

インバウンドチャネルの例：

- `IAX2[flavio@8.8.30.34]/10` — IP アドレス 8.8.30.34 から、ユーザー flavio を使用してコール番号 10 を呼び出します。
- `IAX2[8.8.30.50]/11` — IP アドレス 8.8.30.50 からコール番号 11 を呼び出します。

### IAX の使用

IAX はいくつかの方法で使用できます。このセクションでは、以下を含むいくつかのシナリオで IAX を設定する方法を示します。

- IAX を使用した softphone の接続
- IAX を使用した VoIP プロバイダーへの IAX 接続
- IAX を使用した2台のサーバーの接続
- トランクモードで IAX を使用した2台のサーバーの接続
- IAX 接続のデバッグ
- 認証に RSA キーペアを使用する

#### IAX を使用した softphone の接続

Asterisk は、ATCOM や Digium の古い ATA（IAXy と呼ばれる）などの IAX ベースの IP 電話、および IAX2 プロトコルを実装している softphone をサポートしています。softphone、ATA、ハードウェア電話の手順は似ています。IAX デバイスを設定するには、/etc/asterisk 内の iax.conf ファイルを編集する必要があります。

```
directory.
```

例として IAX2 対応の softphone を使用します。

1. 元の `iax.conf` ファイルを以下のようにバックアップします：

```
#cd /etc/asterisk
#mv iax.conf iax.conf.backup
```

2. 新しい `iax.conf` ファイルの編集を開始します：

```
[general]
bindport=4569
bindaddr=8.8.1.4
bandwidth=high
```

- ; 非常に重要なパラメーターで、利用可能な codec を変更します

```
disallow=all
allow=ulaw
jitterbuffer=no
forcejitterbuffer=no
tos=lowdelay
autokill=yes
[guest]
type=user
context=guest
callerid="Guest IAX User"
; Trust Caller*ID Coming from iaxtel.com
;
[iaxtel]
type=user
context=default
auth=rsa
inkeys=iaxtel
;
; Trust Caller*ID Coming from iax.fwdnet.net
;
[iaxfwd]
type=user
context=default
auth=rsa
inkeys=freeworlddialup
;
; Trust callerid delivered over DUNDi/e164
;
;
;[dundi]
;type=user
;dbsecret=dundi/secret
;context=dundi-e164-local
[2003]
type=friend
context=default
secret=senha
host=dynamic
```

サンプルファイルのデフォルト（コメントアウトされていない）行を維持するようにしました。以下のパラメーターが変更されています：

```
bandwidth=high
```

この行は codec の選択に影響します。high 設定を使用すると、ulaw キーワードで定義される g.711 のような高帯域幅かつ高品質な codec を選択できます。デフォルトのパラメーターのままにすると、ulaw を選択できません。その場合、以下の設定に対して Asterisk は「no codec available」というメッセージを表示します。

```
disallow=all
allow=ulaw
```

上記のコマンドでは、すべての codec を無効にし、ulaw のみを有効にしました。LAN 環境では、プロセッサ負荷が低く CPU サイクルを節約できるため、ulaw を好む人が多いです。帯域幅を多く消費する場合でも、LAN には通常 100メガビットイーサネットやギガビットイーサネットがあるため、この codec が推奨されます。ulaw を使用した音声通話は、ネットワーク帯域幅を毎秒約 100キロビット使用しますが、今日の高速 LAN では非常に軽い負荷です。WAN やインターネットネットワークでは、通常 ulaw を無効にし、帯域幅を有効活用するために音声圧縮で CPU サイクルを消費する設定にします。codec である gsm、g729、ilbc も優れた圧縮率を提供します。

```
[2003]
type=friend
context=default
secret=senha
host=dynamic
```

上記のコマンドでは、[2003] という名前の friend を定義しました。context はデフォルトです（最初のラボでは混乱を避けるため常にデフォルトの context を使用します。この context は dialplan を扱う際に詳しく説明します）。「host=dynamic」という行は、電話機の IP アドレスの動的登録を提供します。

3. IAX2 対応の softphone をダウンロードしてインストールします。ラボ用には、IAX2 プロトコルをサポートしている任意の softphone を選択できます。
4. クライアントで IAX アカウントを設定します（通常は *Add account* → IAX）。SipPulse Softphone は SIP 専用であり IAX2 経由で登録できないことに注意してください。IAX のテストには、プロトコルをサポートしているクライアントが必要です。

5. IAX デバイスをテストするために `extensions.conf` ファイルを設定します。

```
[default]
exten=>2000,1,Dial(SIP/2000)
exten=>2001,1,Dial(SIP/2001)
exten=>2003,1,Dial(IAX2/2003)
```

これで、第3章で作成した SIP 電話と、ラボで作成した IAX 電話の間で通話ができるようになります。

#### IAX を使用した VoIP プロバイダーへの接続

IAX をサポートしている VoIP プロバイダーは少数です。「IAX providers」で検索すると、IAX プロバイダーを簡単に見つけることができます。IAX は帯域幅を大幅に節約でき、NAT を容易に通過し、RSA キーペアを使用して認証できるため、IAX プロバイダーを使用することには大きな意味があります。

![インターネットを介した IAX トランク経由で VoIP プロバイダーに接続された顧客の Asterisk：単一のトランクがプロバイダーとの間のすべての通話を運びます。]((../images/10-legacy-fig14.png))

IAX 対応の商用 VoIP プロバイダーの数は、過去数回の Asterisk リリースで急激に減少しました。現在、ほとんどのプロバイダーは SIP/PJSIP トランクのみを提供しています。IAX プロバイダーと契約する前に、彼らが IAX インフラストラクチャを積極的に維持しているか確認してください。新規のプロバイダー統合には、PJSIP トランク（第3章）が推奨される代替手段です。

#### IAX を使用したプロバイダーへの接続

ステップ 1：お気に入りのプロバイダーでアカウントを開設します。プロバイダーから以下の3つの情報が提供されます。

- 名前
- Secret
- IP アドレスまたはホスト名
- RSA 公開鍵

ステップ 2：Asterisk をプロバイダーに登録するために iax.conf ファイルを設定します。ファイルの [general] セクションに以下の行を追加します。

```
[general]
register=>name:secret@hostname/2003
```

上記の手順では、アカウントとパスワードを使用してプロバイダーに登録しました。通話を受信すると、2003 extension に転送されます。

```
[name]
```

- ; アカウント名または番号

```
type=peer
secret=secret
; Your password
host=hostname
```

上記の手順では、ダイヤル目的でプロバイダーに対応するピアを作成しました。

```
[nameiax]
type=user
context=default
auth=rsa
inkeys=hostname
```

これは RSA 認証に必要です。プロバイダーの公開鍵を使用することで、受信した通話が本当にそのプロバイダーからのものであることを確認できます。他の誰かが同じパスを使用しようとしても、対応する秘密鍵を持っていないため認証できません。ステップ 4：接続を試します。接続をテストするには、任意の番号に電話をかけます。一部のベンダーはエコーテストを提供しています。これを実現するには、extensions.conf ファイルを編集してください。

```
[default]
exten=>*98,1,Dial(IAX2/name:secret@hostname/*98,20,r)
```

Asterisk CLI に移動し、reload を実行します。Asterisk がプロバイダーに登録されているか確認するには、次のコマンドを使用します。

```
*CLI>reload
*CLI>iax2 show register
```

あとは、Asterisk サーバーに接続された softphone で *98 をダイヤルするだけです。

#### IAX トランクを介した2台の Asterisk サーバーの接続

サーバー同士を接続するのは非常に簡単です。IP アドレスが既にわかっているため、登録する必要はありません。iax.conf ファイルでピアとユーザーを作成する必要があります。本社（HQ）サイトのすべての extension は 20 で始まり、その後に2桁が続きます（例：2000）。支店（Branch）では、すべての extension は 22 で始まり、その後に2桁が続きます（例：2200）。トランクを使用します。この機能を有効にするには、DAHDI タイミングソースが必要です。ステップ 1：支店サーバーの iax.conf ファイルを編集します。

![IAX トランクで2台の Asterisk サーバーを接続：HQ サーバー（192.168.1.1、extension 20xx）と支店サーバー（192.168.1.2、extension 22xx）は、単一の IAX トランクを介して互いに到達します。両方の IP アドレスが固定で既知であるため、登録は不要です。]((../images/10-legacy-fig15.png))

```
[general]
bindport=4569                   ; bindport and bindaddr may be specified
bindaddr=0.0.0.0                ; more than once to bind to multiple
disallow=all
allow=ulaw
;allow=gsm
[Branch]
type=user
context=default
secret=password
host=192.168.2.10
trunk=yes
notransfer=yes
[HQ]
type=peer
context=default
username=HQ
secret=password
host=192.168.2.10
callerID='HQ'
trunk=yes
notransfer=yes
[2200]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2000'
[2201]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2001'
```

ステップ 2：支店サーバーの extensions.conf ファイルを設定します

```
[general]
static=yes
writeprotect=no
autofallthrough=yes
clearglobalvars=no
priorityjumping=no
[default]
exten=>_20XX,1,dial(IAX2/HQ/${EXTEN},20)
exten=>_20XX,2,hangup
exten=>_22XX,1,dial(IAX2/${EXTEN},20)
exten=>_22XX,2,hangup
```

ステップ 3：HQ サーバーの iax.conf ファイルを設定します

```
[general]
bindaddr=0.0.0.0
bindport=4569
disallow=all
allow=ulaw
allow=gsm
[Branch]
type=peer
context=default
username=Branch
secret=password
host=192.168.2.9
callerid="Branch"
trunk=yes
notransfer=yes
[HQ]
type=user
secret=password
context=default
host=192.168.2.9
callerid="HQ"
trunk=yes
notransfer=yes
[2000]
type=friend
auth=md5
context=default
secret=password
callerid="2200"
host=dynamic
[2001]
type=friend
auth=md5
context=default
secret=password
callerid="2201"
host=dynamic
```

ステップ 4：HQ サーバーの extensions.conf ファイルを設定します。

```
[general]
static=yes
writeprotect=no
autofallthrough=yes
clearglobalvars=no
priorityjumping=no
[default]
exten=>_22XX,1,Dial(IAX2/Branch/${EXTEN})
exten=>_22XX,2,hangup
exten=>_20XX,1,Dial(IAX2/${EXTEN})
exten=>_20XX,2,hangup
```

ステップ 5：HQ サーバーの電話 2000 から支店サーバーの電話 2200 への通話をテストします。

### IAX 認証

次に、各要件に最適な方法を選択できるように、IAX 認証プロセスを実用的な観点から分析します。

#### インバウンド接続

![インバウンド通話の IAX 認証決定フロー：Asterisk は、ユーザー名が提供されているか、セクションと一致するか、ソース IP が許可されているか、Secret（プレーンテキスト、MD5、または RSA）が一致するかによって分岐し、そのセクションの context とピアオプションで通話を受け入れるか、拒否します。]((../images/10-legacy-fig16.png))

Asterisk がインバウンド接続を受信したとき、初期情報にはユーザー名（"username=" フィールドから）が含まれている場合と含まれていない場合があります。インバウンド接続には IP アドレスもあり、Asterisk はこれも認証に使用します。

ユーザーが提供された場合、Asterisk は以下の処理を行います：

1. iax.conf で type=user（またはユーザー名と一致するセクション名を持つ type=friend）のエントリを検索します。見つからない場合、Asterisk は接続を拒否します。
2. 見つかったエントリに deny/allow 設定がある場合、発信者の IP アドレスを比較し、deny/allow 句に基づいて通話を受け入れるかどうかを決定します。
3. プレーンテキスト、md5、または RSA を使用してパスワード（secret）を確認します。
4. 接続を受け入れ、iax.conf ファイルの "context=" 行で指定された context に通話を送信します。

ユーザー名が提供されない場合、Asterisk は以下の処理を行います：

1. iax.conf ファイル内で、secret が指定されていない type=user（または type=friend）を含むエントリを検索します。deny/allow 句も確認します。エントリが見つかった場合、接続は受け入れられ、セクション名がユーザー名として使用されます。
2. iax.conf ファイル内で、secret または RSA キーが指定されている type=user（または type=friend）を含むエントリを検索します。deny/allow 句を確認します。エントリが見つかった場合、指定された secret を使用して発信者の認証を試みます。一致すれば接続を受け入れます。セクション名がユーザー名となります。

iax.conf ファイルに以下のエントリがあると仮定します：

```
[guest]
type=user
context=guest
[iaxtel]
type=user
context=incoming
auth=rsa
inkeys=iaxtel
[iax-gateway]
type=friend
allow=192.168.0.1
context=incoming
host=192.168.0.1
[iax-friend]
type=user
secret=this_is_secret
auth=md5
context=incoming
```

以下のようにユーザー名が指定された通話の場合：

- guest
- iaxtel
- iax-gateway
- iax-friend

Asterisk は iax.conf ファイル内の対応するエントリのみを使用して通話の認証を試みます。他の名前が指定された場合、通話は拒否されます。ユーザーが指定されていない場合、Asterisk は guest として接続の認証を試みます。ただし、guest が存在しない場合、secret が一致する他の接続を試みます。言い換えれば、iax.conf ファイルに guest セクションがない場合、悪意のあるユーザーがユーザー名を指定しないことで一致する secret を推測しようとする可能性があります。IP アドレスの deny/allow 制限も適用されます。secret の推測を避ける良い方法は、RSA 認証を使用することです。もう一つの方法は、通話を許可する IP アドレスを制限することです。

#### IP アドレスの制限

アクセスは `permit` および `deny` 行で制御されます：

```
permit = <ipaddr>/<netmask>
deny = <ipaddr>/<netmask>
```

ルールは順番に解釈され、すべてが評価されます（この概念は、ルーターやファイアウォールで通常見られる ACL とは異なります）。最後に一致した命令が以前の命令を上書きします。

例 #1：

```
permit=0.0.0.0/0.0.0.0
deny=192.168.0.0/255.255.255.0
```

これは 192.168.0.0/24 ネットワークからのすべてのパケットを拒否します。

例 #2：

```
deny=192.168.0.0/255.255.255.0
permit=0.0.0.0/0.0.0.0
```

これはすべてのパケットを許可します。最後の命令が最初の命令を上書きするためです。

#### アウトバウンド接続

アウトバウンド接続は、以下の方法を使用して認証情報を取得します：

- dial() アプリケーションによって渡される IAX2 チャネル記述
- iax.conf ファイル内の type=peer または type=friend を持つエントリ
- 両方の方法の組み合わせ

#### RSA キーを使用した2台の Asterisk サーバーの接続

非対称 RSA キーを使用して強力な認証で IAX を使用することが可能です。ソースコード（res_krypto.c）によると、Asterisk はより弱い MD5 の代わりに、メッセージダイジェストに SHA-1 アルゴリズムを使用した RSA キーを使用します。以下は、RSA キーを使用して2台のサーバーをセットアップするためのステップバイステップガイドです。

##### 支店サーバーの設定

ステップ 1：支店サーバーで RSA キーを生成します

```
astgenkey -n
```

尋ねられたら、キー名 branch を使用します。Asterisk が再初期化されるたびにパスフレーズを入力しなくて済むように、パラメーター –n を使用しました。セキュリティを向上させたい場合は、–n を使用せず、asterisk -i で Asterisk を起動してください。ステップ 2：キーを /var/lib/asterisk/keys ディレクトリにコピーします

```
cp branch.* /var/lib/asterisk/keys
```

ステップ 3：公開鍵を HQ サーバーにコピーします

```
scp branch.pub root@hq_ip_address:/var/lib/asterisk/keys
```

ステップ 4：支店サーバーの iax.conf ファイルを編集します。

```
[general]
bindport=4569                   ; bindport and bindaddr may be specified
bindaddr=0.0.0.0                ; more than once to bind to multiple
disallow=all
allow=ulaw
;Create an entry for the HQ server
[hq]
type=user
context=default
host=192.168.2.10
trunk=yes
notransfer=yes
auth=rsa
inkeys=hq
[2200]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2200'
[2201]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2201'
```

ステップ 8：支店サーバーの extensions.conf ファイルを設定します

```
 [default]
exten=>_20XX,1,dial(IAX2/branch:[branch]@192.168.2.10/${EXTEN},20)
exten=>_20XX,2,hangup
exten=>_22XX,1,dial(IAX2/${EXTEN},20)
exten=>_22XX,2,hangup
```

##### 本社サーバーの設定

ステップ 1：HQ サーバーで RSA キーを生成します

```
astgenkey -n
```

尋ねられたら、キー名 hq を使用します。ステップ 2：キーを /var/lib/asterisk/keys ディレクトリにコピーします

```
cp hq.* /var/lib/asterisk/keys
```

ステップ 3：公開鍵を BRANCH サーバーにコピーします

```
scp hq.pub root@branch_ip_address:/var/lib/asterisk/keys
```

ステップ 4：HQ サーバーの iax.conf ファイルを設定します

```
[general]
bindaddr=0.0.0.0
bindport=4569
disallow=all
allow=ulaw
allow=gsm
;Configure an entry for the branch server
[branch]
type=user
context=default
host=192.168.2.9
trunk=yes
notransfer=yes
auth=rsa
inkeys=branch
[2000]
type=friend
auth=md5
context=default
secret=password
callerid="2000"
host=dynamic
[2001]
type=friend
auth=md5
context=default
secret=password
callerid="2001"
host=dynamic
```

ステップ 10：HQ サーバーの extensions.conf ファイルを設定します。

```
[default]
exten=>_22XX,1,Dial(IAX2/hq:[hq]@192.168.2.9/${EXTEN})
exten=>_22XX,2,hangup
exten=>_20XX,1,Dial(IAX2/${EXTEN})
exten=>_20XX,2,hangup
```

ステップ 11：HQ サーバーの電話 2000 から支店サーバーの電話 2200 への通話をテストします。

### iax.conf ファイルの設定

iax.conf ファイルにはいくつかのパラメーターがあります。各パラメーターを一つずつ議論するのは退屈で非効率的です。すべてのパラメーターと説明はサンプルファイルに記載されています。wiki の www.voip-info.org には、各パラメーターの詳細情報があります。ここでは、general セクション、ピア、ユーザーの設定において最も重要なパラメーターをいくつか紹介します。

#### [General] セクション

サーバーアドレス：

- `bindport = <portnum>` — IAX UDP ポートを設定します。デフォルトは 4569 です。
- `bindaddr = <ipaddr>` — 0.0.0.0 を使用して Asterisk をすべてのインターフェースにバインドするか、特定のインターフェースの IP アドレスを指定します。

Codec の選択：

- `bandwidth = [low|medium|high]` — High = すべての codec、Medium = ulaw と alaw を除くすべての codec、Low = 低帯域幅 codec。
- `allow/disallow = [alaw|ulaw|gsm|g.729| etc.]` — Codec 選択の微調整。

### ジッターバッファ

ジッターとは、パケット間の遅延の変動のことです。これは音声品質に影響を与える最も重要な要因です。ジッターバッファは、遅延の変動を補正するために使用されます。これは、ジッターを低くするためにレイテンシを犠牲にします。ジッターバッファと貯水タンクを例えることができます。どちらも不規則な間隔でパケットや水を受け取りますが、最終的には規則的な流れを提供します。

![貯水タンクとしてのジッターバッファ：パケットはネットワークから不規則に到着してバッファを満たし、バッファはそれらを一定の速度で解放してスムーズな音声フローを作り出します。バッファサイズ（ms単位）は、ジッターを低くするためにわずかなレイテンシを犠牲にします。過剰バッファ帯域により、Asterisk はネットワーク状況の変化に応じてバッファを拡大または縮小できます。]((../images/10-legacy-fig17.png))

小さなジッター（20 ms 未満など）は通常感知できません。しかし、これを超えるジッターは不快です。レイテンシまたは遅延は 150ms 未満に保つ必要があります。ジッターバッファを作成すると、ジッターを低くするために遅延が犠牲になります。これは「遅延バジェット」として知られる概念です。以下のパラメーターを使用してジッターバッファに影響を与えることができます：

- Jitterbuffer=<yes/no> – 有効または無効にします
- Dropcount=<number> - 過去2秒間に遅延させるべきフレームの最大数。推奨設定は 3（ドロップされたフレームの 1.5%）です
- Maxjitterbuffer=<ms> - 通常 100 ms 未満
- Maxexcessbuffer=<ms> - ネットワーク遅延が改善された場合、ジッターバッファが大きすぎる可能性があります。その結果、Asterisk はそれを削減しようとします。
- Minexcessbuffer=<ms> - 過剰バッファがこの値まで低下すると、Asterisk はバッファサイズの増加を開始します。

### フレームタグ付け

以下のパラメーターは、サービスタイプフィールドの IP パケットにマークを付けます。ルーターはこのタグを読み取り、トラフィックに優先順位を付けることができます。Asterisk はこのフィールドに DSCP コード（RFC 2474）を使用します。許可される値は、CS0、CS1、CS2、CS3、CS4、CS5、CS6、CS7、AF11、AF12、AF13、AF21、AF22、AF23、AF31、AF32、AF33、AF41、AF42、AF43、および ef（すなわち、expedited forwarding）です。

```
tos=ef
```

### IAX2 暗号化

IAX は、AES（Advanced Encryption Standard）と呼ばれる対称鍵 128ビットブロック暗号を使用した通話暗号化をサポートしています。IAX トランク間の暗号化を有効にするのは非常に簡単です。iax.conf ファイルで以下を使用します：

```
encryption=yes
```

暗号化を強制するには：

```
forceencryption=yes
```

古いバージョンとの互換性を保証するために、キーローテーションを無効にする必要がある場合があります：

```
keyrotate=no
```

### IAX2 デバッグコマンド

以下は、Asterisk の最も重要なトラブルシューティングコンソールコマンドです。

```
iax2 show netstats
vtsvoffice*CLI> iax2 show netstats
                        -------- LOCAL ---------------------  -------- REMOTE ---------------
-----
Channel           RTT  Jit  Del  Lost   %  Drop  OOO  Kpkts  Jit  Del  Lost   %  Drop  OOO
Kpkts
IAX2/8590-1        16   -1    0    -1  -1     0   -1      1   60  110     3   0     0    0
0
iax2 show channels
vtsvoffice*CLI> iax2 show channels
Channel       Peer             Username    ID (Lo/Rem)  Seq (Tx/Rx)  Lag      Jitter  JitBuf
Format
IAX2/8590-2   8.8.30.43        8590        00002/26968  00004/00003  00000ms  -0001ms  0000ms
unknow
iax2 show peers
vtsvoffice*CLI> iax2 show peers
Name/Username    Host                 Mask             Port          Status
8584             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8564             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8576             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8572             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8571             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8585             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8589             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8590             8.8.30.43       (D)  255.255.255.255  4569          OK (16 ms)
3232             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
9 iax2 peers [1 online, 8 offline, 0 unmonitored]
iax2 debug
```

この出力を見て、通話の開始と終了を特定します。poke パケットと pong パケットを使用して取得された遅延とジッター情報を観察します。これらのパケットは、「iax2 show netstats」コマンドの出力を作成するのに役立ちます。

```
vtsvoffice*CLI> iax2 debug
IAX2 Debugging Enabled
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: REGREQ
   Timestamp: 00003ms  SCall: 26975  DCall: 00000 [8.8.30.43:4569]
   USERNAME        : 8590
   REFRESH         : 60
Tx-Frame Retry[000] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: REGAUTH
   Timestamp: 00009ms  SCall: 00003  DCall: 26975 [8.8.30.43:4569]
   AUTHMETHODS     : 2
   CHALLENGE       : 137472844
   USERNAME        : 8590
Rx-Frame Retry[ No] -- OSeqno: 001 ISeqno: 001 Type: IAX     Subclass: REGREQ
   Timestamp: 00016ms  SCall: 26975  DCall: 00003 [8.8.30.43:4569]
   USERNAME        : 8590
   REFRESH         : 60
   MD5 RESULT      : f772b6512e77fa4a44c2f74ef709e873
Tx-Frame Retry[000] -- OSeqno: 001 ISeqno: 002 Type: IAX     Subclass: REGACK
   Timestamp: 00025ms  SCall: 00003  DCall: 26975 [8.8.30.43:4569]
   USERNAME        : 8590
   DATE TIME       : 2006-04-17  16:03:00
   REFRESH         : 60
   APPARENT ADDRES : IPV4 8.8.30.43:4569
   CALLING NUMBER  : 4830258590
   CALLING NAME    : Flavio
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 002 Type: IAX     Subclass: ACK
   Timestamp: 00025ms  SCall: 26975  DCall: 00003 [8.8.30.43:4569]
Tx-Frame Retry[000] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: POKE
   Timestamp: 00003ms  SCall: 00006  DCall: 00000 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: ACK
   Timestamp: 00003ms  SCall: 26976  DCall: 00006 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: PONG
   Timestamp: 00003ms  SCall: 26976  DCall: 00006 [8.8.30.43:4569]
   RR_JITTER       : 0
   RR_LOSS         : 0
   RR_PKTS         : 1
   RR_DELAY        : 40
   RR_DROPPED      : 0
   RR_OUTOFORDER   : 0
Tx-Frame Retry[-01] -- OSeqno: 001 ISeqno: 001 Type: IAX     Subclass: ACK
   Timestamp: 00003ms  SCall: 00006  DCall: 26976 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: NEW
   Timestamp: 00003ms  SCall: 26977  DCall: 00000 [8.8.30.43:4569]
   VERSION         : 2
   CALLING NUMBER  : 8590
   CALLING NAME    : 4830258590
   FORMAT          : 2
   CAPABILITY      : 1550
   USERNAME        : 8590
   CALLED NUMBER   : 8580
   DNID            : 8580
Tx-Frame Retry[000] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: AUTHREQ
   Timestamp: 00007ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
   AUTHMETHODS     : 2
   CHALLENGE       : 190271661
   USERNAME        : 8590
Rx-Frame Retry[Yes] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: NEW
   Timestamp: 00003ms  SCall: 26977  DCall: 00000 [8.8.30.43:4569]
   VERSION         : 2
   CALLING NUMBER  : 8590
   CALLING NAME    : 4830258590
   FORMAT          : 2
   CAPABILITY      : 1550
   USERNAME        : 8590
   CALLED NUMBER   : 8580
   DNID            : 8580
Tx-Frame Retry[-01] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: ACK
   Timestamp: 00003ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 001 ISeqno: 001 Type: IAX     Subclass: AUTHREP
   Timestamp: 00063ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
   MD5 RESULT      : 57cc5c48affba14106c29439944413a1
Tx-Frame Retry[000] -- OSeqno: 001 ISeqno: 002 Type: IAX     Subclass: ACCEPT
   Timestamp: 00054ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
   FORMAT          : 1024
Tx-Frame Retry[000] -- OSeqno: 002 ISeqno: 002 Type: CONTROL Subclass: ANSWER
   Timestamp: 00057ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Tx-Frame Retry[000] -- OSeqno: 003 ISeqno: 002 Type: VOICE   Subclass: 138
   Timestamp: 00090ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 002 Type: IAX     Subclass: ACK
   Timestamp: 00054ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 003 Type: IAX     Subclass: ACK
   Timestamp: 00057ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 004 Type: IAX     Subclass: ACK
   Timestamp: 00090ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 004 Type: VOICE   Subclass: 138
   Timestamp: 00210ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Tx-Frame Retry[-01] -- OSeqno: 004 ISeqno: 003 Type: IAX     Subclass: ACK
   Timestamp: 00210ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 003 ISeqno: 004 Type: IAX     Subclass: PING
   Timestamp: 02083ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Tx-Frame Retry[000] -- OSeqno: 004 ISeqno: 004 Type: IAX     Subclass: PONG
   Timestamp: 02083ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
   RR_JITTER       : 0
   RR_LOSS         : 0
   RR_PKTS         : 1
   RR_DELAY        : 40
   RR_DROPPED      : 0
   RR_OUTOFORDER   : 0
Rx-Frame Retry[ No] -- OSeqno: 004 ISeqno: 005 Type: IAX     Subclass: ACK
   Timestamp: 02083ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 004 ISeqno: 005 Type: IAX     Subclass: HANGUP
   Timestamp: 08693ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
   CAUSE           : Dumped Call
```

デバッグをオフにするには、以下を使用します：

```
vtsvoffice*CLI>iax2 no debug
```

### まとめ

本章では、IAX プロトコルの長所と短所をレビューしました。softphone や2台の Asterisk サーバー間のトランクなど、いくつかのシナリオで IAX がどのように機能するかを実証しました。トランクモードでは、単一のパケットで複数の通話を運ぶことで帯域幅を節約できます。最後に、プロトコルのステータスを確認し、デバッグするために使用できるコンソールコマンドを学習しました。

## Legacy SIP: chan_sip and sip.conf (Asterisk 21以降で削除)

> **レガシー / 歴史的背景:** このセクションの内容はすべて、古い `chan_sip`
> ドライバとその `sip.conf` 設定ファイルを使用しています。 `chan_sip` は
> いくつかのリリースで非推奨とされ、**Asterisk 21で削除**されたため、
> **Asterisk 22には存在しません**。以下の `sip.conf` の例は、現在のシステムでは
> どれも動作しません。これらは、レガシーなデプロイメントがどのように機能していたかを
> 文書化し、移行を支援するためだけにここに残されています。これらを実行するための
> モダンでサポートされている方法については、*SIP & PJSIP in depth* 章の
> *PJSIP: the SIP channel* セクションを参照してください。SIP *プロトコル*の
> 理論（メソッド、登録、プロキシ/リダイレクト、SDP、NATタイプなど）は
> プロトコルレベルの話であり、その章で扱います。以下に続くのは、純粋に削除された
> `chan_sip` の**設定**に関する内容です。

Asterisk 20までのレガシーシステムでは、SIPは `/etc/asterisk/sip.conf` で設定されていました。これは（`extensions.conf` に次いで）2番目に変更頻度が高いファイルでした。以下のセクションでは、かつて `chan_sip` がどのようにAsteriskをSIPプロバイダーに接続していたか、SIPを使用して2つのAsteriskを接続する方法、ドメインサポート、プレゼンス、codec/DTMF/QoSオプション、認証、そしてNATについて説明し、その後にすべてをPJSIPへ移行するためのガイドを記載します。

### AsteriskをSIPプロバイダーに接続する (sip.conf)

Asteriskは、SIP VoIPプロバイダーへの接続によく使用されます。VoIPプロバイダーは、従来のプロバイダーよりも通話料金が安い傾向にあります。VoIPプロバイダーのもう一つの興味深く魅力的な点は、他の都市や外国のDID番号を購入できることです。これらは、電気通信にVoIPを使用する十分な理由となります。このセクションでは、レガシーな `chan_sip` がどのようにAsteriskをVoIPプロバイダーに接続していたかを学びます。AsteriskをSIPプロバイダーに接続するには3つのステップが必要です。テストは、お好みのプロバイダーでアカウントを作成することで実施できます。ステップ1: sip.confでSIPプロバイダーに登録する。SIPプロバイダーに接続するには、プロバイダーから以下の情報を提供してもらう必要があります。

![インターネットまたはプライベートWAN経由でVoIPサービスプロバイダーに接続されたAsterisk。ローカルのSIP電話がAsteriskサーバーに登録されている様子](../images/07-sip-and-pjsip-fig07.png)

- username
- secret および remotesecret (インバウンドリクエストの認証には secret を、アウトバウンドリクエストには remotesecret を使用します)
- hostname
- domain
- codecs allowed

この設定により、プロバイダーはAsteriskのIPアドレスを特定できるようになります。以下のステートメントでは、hostnameで定義されたSIPプロバイダーにAsteriskを登録し、AsteriskのIPアドレスをプロバイダーに通知するようAsteriskに指示しています。このステートメントは、extension 4100で着信を受けたいことを示しています。sip.conf ファイルの [general] セクションに、以下の行を入力してください。

```
register=>name:secret@hostname/4100
```

ステップ 2: sip.conf で [peer] を設定する。Asterisk のダイヤルを簡素化するために、目的のプロバイダーに対する peer タイプの項目を作成します。

```
[provider]
context=incoming
type=friend
dtmfmode=rfc2833
directmedia=no
username=username
remotesecret=secret
host=hostname
fromuser=username
fromdomain=domain
insecure=invite
disallow=all
allow=ulaw ; or any other codec available from your provider
```

ステップ 3: dialplan 内でプロバイダーへのルートを作成する

プロバイダーへの宛先ルートとして、数字の 010 を選択します。プロバイダー内の 610000 にダイヤルするには、単に 010610000 とダイヤルします。

```
exten=>_010.,1,Set(CALLERID(num)=username)
exten=>_010.,n,Set(CALLERID(Name)="Flavio Gonçalves")
exten=>_010.,n,Dial(SIP/${EXTEN:3}@provider)
exten=>_010.,n,Hangup
```

#### プロバイダーシナリオに固有の SIP オプション

以下の議論では、VoIP プロバイダーへの接続のために `sip.conf` ファイルで設定されるオプションの詳細について検討します。

```
register=>username:password@hostname/4100
```

sip.conf ファイル内の register 命令は、プロバイダーへの登録に使用されます。register トランザクションは、name と secret を使用して認証されます。スラッシュ（“/”）を使用することで、着信用の extension を指定できます。技術的に言えば、この extension は SIP リクエストの “Contact” ヘッダーフィールドに配置されます。登録の動作は、特定のパラメータによって制御可能です：

```
registertimeout=20
registerattempts=10
```

登録が成功したかどうかを確認するための従来のコンソールコマンドは `sip show registry` でした。Asterisk 22 における同等のコマンドは、アウトバウンド登録については `pjsip show registrations`、endpoint のステータスについては `pjsip show endpoints` となります。

パラメータ “username” は認証ダイジェストで使用されます。ダイジェストは username、secret、および realm を使用して計算されます。

```
username=username
```

Hostは、VoIPプロバイダーのアドレスまたは名前を定義します。

```
host=hostname
```

Fromuser および Fromdomain パラメータは、認証のために必要となる場合があります。これらのパラメータは、SIP の From ヘッダーフィールドで使用されます：

```
fromuser=username
fromdomain=hostname
```

VoIPプロバイダーに接続する際は、認証情報が必要となります。最初のINVITEの後、プロバイダーは「407 Proxy Authentication Required」というメッセージを送信してきます。これに対し、後続のINVITEメッセージで認証情報を提供します。着信の場合、Asteriskサーバーはプロバイダーに対して認証情報を要求します。当然ながら、プロバイダーはAsteriskサーバーに対する有効な認証情報を持っていません。insecure=inviteを使用すると、Asteriskに対してプロバイダーへ「407 Proxy Authentication Required」を送信しないよう指示し、着信を許可することになります。また、insecure=port, inviteを使用することで、ポート番号を照合せずにIPアドレスに基づいてピアを照合することも可能です。

```
insecure=invite, port
```

### SIP を使用した2台の Asterisk サーバー間の接続 (sip.conf)

SIP を使用して2台の Asterisk サーバーを相互接続することができます。この設定を進める前に、dialplan に注意を払うことが重要です。ユーザーは一般的に、最小限の労力で他の PBX と接続したいと考えます。ここでの考え方は、他の PBX に接続するためだけに extension 番号を使用するというものです。ステップ 1: サーバー A の sip.conf ファイルを編集します。

```
[B]
type=user
secret=B
host=A
disallow=all
allow=ulaw
directmedia=no
[B-out]
type=peer
fromuser=A
username=A
remotesecret=A
host=B
disallow=all
allow=ulaw
directmedia=no
```

ステップ 2: サーバー B の sip.conf ファイルを編集します:

```
[A]
type=user
host=B
secret=A
disallow=all
allow=ulaw
directmedia=no
[A-out]
```

![SIPを使用して2台のAsteriskサーバーを接続する：サーバーA（内線4400/4401）とサーバーB（内線4500/4501）がSIPシグナリングを交換し、各PBXのユーザーが相互にダイヤルできるようにする](../images/07-sip-and-pjsip-fig08.png)

```
type=peer
host=A
fromuser=B
username=B
remotesecret=B
disallow=all
allow=ulaw
directmedia=no
```

ステップ 3: サーバー A の extensions.conf ファイルを編集します:

```
[default]
exten=_44XX,1,dial(SIP/${EXTEN},20)
exten=_44XX,2,hangup()
exten=_45XX,1,dial(SIP/B-out/${EXTEN})
exten=_45XX,2,hangup()
```

ステップ 4: サーバー B の extensions.conf ファイルを編集します:

```
[default]
exten=_44XX,1,dial(SIP/A-out/${EXTEN})
exten=_44XX,2,hangup()
exten=_45XX,1,dial(SIP/${EXTEN})
exten=_45XX,2,hangup()
```

### Asteriskのドメインサポート (sip.conf)

SIPプロトコルはインターネットアーキテクチャに従います。SIPを設定する前に最初に行うべきことは、DNSサーバーを正しく設定することです。SIP環境では、任意のSIPプロキシに配置されたユーザーを呼び出すことができ、他のユーザーもSIP Uniform Resource Identifier (URI) を使用してあなたを呼び出すことができます。SIP用にDNSサーバーを設定するには、DNSサーバーにSRVレコードを追加する必要があります。

```
; SIP server/proxy and its backup server/proxy
sip1.yourdomain.com
21600 IN A
200.180.4.169
sip2.yourdomain.com
21600 IN A
200.175.61.150
;
; DNS SRV records for SIP
_sip._udp.yourdomain.com  21600 IN SRV 10 0 5060 sip1.voip.school.
_sip._udp.yourdomain.com  21600 IN SRV 20 0 5060 sip2.voip.school.
```

DNSの設定後、SIPユーザー、SIP電話、または電話のextensionを指し示すURIを使用できるようになります。SIP URIはメールアドレスに似た形式（例: sip:chuck@yourpartnerdomain.com）をしています。SIP URIを使用すれば、あるSIP電話から別のSIP電話へ通話を発信する際に電話番号は不要です。外部のユーザーにダイヤルするには、以下に示すようなステートメントを単純に使用してください。

```
exten=4000,1,dial(SIP/chuck@yourpartnerdomain.com)
```

ドメインの動作を制御できるパラメータがいくつか存在します。

```
srvlookup=yes
```

このパラメータは、発信通話における DNS SRV ルックアップを有効にします。このパラメータを使用することで、ドメインに基づいた SIP 名を使用して通話を発信することが可能になります。

```
allowguest=yes
```

このパラメータを使用すると、外部からのINVITEを認証なしで処理できるようになります。この呼び出しは、generalセクションまたはdomainステートメントで定義されたcontext内で処理されます。警告：PSTNへのアクセス権を持つcontextをgeneralセクションで定義した場合、外部ユーザーがあなたのPBXを経由してPSTNへ発信できてしまいます。この場合、発生した料金はすべてあなたの負担となります。generalセクションで定義するcontextには、自身のextensionのみを許可するようにしてください。

![ドメインによる他のSIPサーバーへの接続：yourdomain.comとyourpartnerdomain.comがSIPシグナリングを交換することで、leeやbruceといったユーザーがSIP URIを使用してchuckやnorrisを呼び出すことができる](../images/07-sip-and-pjsip-fig09.png)

```
domain=acme.com,default
```

domain コマンドを使用すると、Asterisk 内で複数のドメインを扱うことができます。特定のドメインから着信があった場合、その呼び出しを特定の context へと振り向けることが可能です。

```
;autodomain=yes
```

このパラメータには、許可されたドメインにローカルIPとホスト名が含まれます。

```
;allowexternaldomains=no
```

デフォルトは yes です。外部ドメインへの通話を禁止するには、この行のコメントを解除してください。

### SIPの高度な設定 (sip.conf)

このセクションでは、プレゼンス、codec選択、DTMFオプション、QoSパケットマーキングなど、レガシーなSIPチャネルの高度なパラメータについて説明します。ここで示す`sip.conf`のパラメータ名はAsterisk 22には存在しませんが、その**概念**（BLF/プレゼンス、codecネゴシエーション、DTMFモード、DSCPマーキング）はPJSIPにも引き継がれています。PJSIPでは、DTMFモードはendpointの`dtmf_mode=`で設定し、codecは`allow=`/`disallow=`で設定します。

#### SIPプレゼンス

SIPプレゼンスはAsteriskにおいて部分的に実装されています。Asteriskは、チャネルの状態に応じてSUBSCRIBEやNOTIFYといったユーザーからのリクエストをサポートしています。AsteriskはSIPメソッドのPUBLISHをサポートしていません。言い換えれば、チャネルの状態（通話中、アイドル、呼び出し中）を購読することはできますが、「離席中」や「応答不可」といった情報を公開することはできません。プレゼンスの最も一般的なシナリオは、各extensionやtrunkのランプでKSシステムの動作をシミュレートするbusy lamp field (BLF) です。プレゼンスに関するSIPパラメータは以下の通りです。

- allowsubscribe=yes: SIPサブスクリプションメソッドを許可する
- subscribecontext=sip_subscribers: ヒントを探すためのcontext
- notifyring=yes: 呼び出し時にSIP NOTIFYを送信する
- notifyhold=yes: 保留時にSIP NOTIFYを送信する
- counteronpeer (Asterisk 1.4.xでlimitonpeerから名称変更): peer側のみにカウンターを適用する
- callcounter=yes: デバイス内の通話カウンターを有効にする
- busylevel=1: デバイスを通話中とみなすための通話数のしきい値

例として、ステップ1：AsteriskでSIPプレゼンスをテストするのはそれほど難しくありません。まず、sip.confとextensions.confファイルを構成してみましょう。

sip.confファイル内

```
[general]
bindaddr=0.0.0.0
bindport=5060
disallow=all
allow=ulaw
allowsubscribe=yes
notifyringing=yes
notifyhold=yes
limitonpeer=yes
counteronpeer=yes
subscribecontext=default
[2000]
type=friend
host=dynamic
context=default
dtmfmode=rfc2833
secret=senha
callcounter=yes
busylevel=1
[2001]
type=friend
host=dynamic
context=default
dtmfmode=rfc2833
secret=senha
callcounter=yes
busylevel=1
In the file extensions.conf
[default]
exten=2000,hint,SIP/2000
exten=2001,hint,SIP/2001
exten=_20XX,1,dial(SIP/${EXTEN})
exten=_20XX,n,Hangup()
```

ステップ 2: 次に、プレゼンスを使用するように softphone を設定します。ここでは SipPulse Softphone の設定方法を説明します。

- 手順: 右クリック -> SIP Account Settings -> Properties -> Presence
- プレゼンスモデルを peer-to-peer から presence agent に変更します。これにより、softphone は Asterisk に対して SIP イベントの購読を行うようになります。

ステップ 3: 他の softphone に連絡先を追加します。この例では、SipPulse Softphone はアカウント 2000 なので、アカウント 2001 の連絡先を追加します。手順: 右パネル（softphone 内のプレゼンスパネル）を開く -> Contacts をクリック -> Add a contact。名前に 2001 と入力します。表示名を 2001 とし、Show this contact’s availability のチェックボックスを忘れずにオンにしてください。

ステップ 4: 次に extension 2001 に発信し、softphone の右パネルで電話機のステータスを確認します。コンソールコマンド `core show hints` を使用して、サーバー側でプレゼンスステータスが変化する様子を確認してください（レガシーな chan_sip では、各回線で何件の通話があるかを `sip show inuse` で確認できました）。Asterisk 22 では、endpoint と channel の状態を調査するために `pjsip show endpoints` を使用します。プレゼンス/BLF ステータスは softphone の連絡先または BLF パネルに表示されます。表示方法はクライアントによって異なります。

#### Codec configuration

Codec configuration はシンプルで分かりやすいものです。[general] セクションまたは peer/user セクションで allow および disallow を設定できます。ベストプラクティスは、プロセッサ負荷の高いトランスコーディングを避けるために codec を標準化することです。メッセージやプロンプトには同じ codec を使用してください。

```
[general]
disallow=all
allow=g729
```

#### DTMFオプション

特定の状況下では、voicemailやIVRといったアプリケーションに対して数字を渡す必要があります。DTMFを正しく渡すことは重要です。DTMFを渡すための最も単純な方法はinbandと呼ばれるものです。これはsip.confファイルの[general]セクション、またはpeer/userセクションで設定します。dtmfmode=inbandを設定すると、DTMFトーンは音声チャネル内の音として生成されます。この方法の主な問題点は、g729のようなcodecを使用して音声チャネルを圧縮すると、音が歪んでしまい、DTMFトーンが正しく認識されなくなることです。dtmfmode=inbandを使用する予定であれば、g.711 codec（ulawおよびalaw）を使用してください。

```
dtmfmode=inband
```

もう一つのアプローチは RFC2833 を使用する方法です。これを使うと、DTMFトーンを RTP パケット内の名前付きイベントとして送信できるようになります。

```
dtmfmode=rfc2833
```

最後に、RTPパケットの代わりにSIPパケット内でDTMFデジットを送信することも可能です。この方式は、RFC3265（シグナリングイベント）およびRFC2976で定義されています。

```
dtmfmode=info
```

version 1.2のリリースに伴い、以下の機能が利用可能になりました。

```
dtmfmode=auto
```

これは RFC2833 の使用を試みます。それが不可能な場合は、帯域内トーンを使用します。

#### Quality of service (QoS) マーキングの設定

QoS は、音声品質を担う一連の技術です。QoS は、帯域幅、遅延、およびジッターを削減するように実装されます。主な QoS 機能には、パケットスケジューリング、フラグメンテーション、ヘッダー圧縮があります。QoS は Asterisk 自体ではなく、スイッチやルーターに実装されます。しかし、Asterisk はパケットに優先配送のマーキングを行うことで、ルーターやスイッチを支援することができます。マーキングは、RFC 2474 および RFC2475 で定義されている differentiated services code points (DSCP) を使用して行われます。

```
tos_sip=cs3
tos_audio=ef
tos_video=af41
```

バージョン 1.4 以降、シグナリング (SIP)、音声 (RTP)、およびビデオ (RTP) に対して異なる codec を指定できるようになりました。

### SIP 認証 (sip.conf)

レガシーな `chan_sip` が SIP コールを受信した際、以下の図で説明されるルールに従っていました。SIP 認証において、3 つのパラメータが重要な役割を果たしていました。Asterisk 22 では、認証は代わりに endpoint によって参照される PJSIP `auth` オブジェクト (`type=auth`、`auth_type=userpass`、`username=`、`password=`) を使用して設定され、IP アクセス制御は endpoint 上の `permit=`/`deny=`、または `acl` を介して行われます。

![レガシーな chan_sip 認証の決定フロー: Asterisk は From ヘッダーを sip.conf と照合し、一致する type=user/peer セクションと MD5 資格情報を試行し、最終的に insecure=invite または allowguest にフォールバックしてコールの許可または拒否を行います](../images/07-sip-and-pjsip-fig10.png)

```
allowguest=yes/no
```

このパラメータは、対応するpeerを持たないユーザーが、名前とsecretなしで認証できるかどうかを制御します。このパラメータについては、ドメインサポートのセクションで説明しました。

```
insecure=invite,port
```

insecure=invite を使用する場合、Asterisk は「407 Proxy Authentication Required」というメッセージを生成しません。このメッセージがないと、ユーザーは認証なしで通話を発信できてしまいます。これは、VoIPサービスプロバイダーに接続する際によく利用されます。VoIPサービスプロバイダーから着信する通話は、通常、認証が行われないためです。

```
autocreatepeer=yes/no
```

このコマンドは、AsteriskがSIPプロキシに接続されている場合に使用されます。これは、各通話に対して動的にピアを作成します。このオプションを有効にすると、あらゆるUACがAsteriskサーバーに接続できるようになります。IP接続をSIPプロキシに限定することが重要です。SIPプロキシは、その役割としてアクセス制御を担います。ピアの設定は、generalオプションおよびSIPパケットの「Contact」ヘッダーフィールドに基づいています。警告：Asteriskを完全に開放してしまうため、この機能の使用には細心の注意を払ってください。

```
secret=secret, remotesecret=secret
```

このパラメータは、認証に使用するシークレットを設定します。インバウンドリクエストには `secret` を、アウトバウンドリクエストには `remotesecret` を使用してください。テキストファイル内にシークレットをそのまま記述したくない場合は、`md5secret` を使用してシークレットの代わりにハッシュを含めることができます。MD5シークレットを生成するには、以下を使用します。

```
echo -n "username:realm:secret" |md5sum
```

次に、以下のステートメントを使用します。

```
md5secret=0b0e5d467890....
```

警告: –n パラメータを使用することを忘れないでください。キャリッジリターンが md5 の計算に使用されてしまいます。

```
deny=0.0.0.0/0.0.0.0
permit=192.168.1.0/255.255.255.0
```

上記のステートメントは、すべてのIPアドレスを拒否し、ローカルネットワーク（192.168.1.0/24）からのUACのみを許可します。

#### RTPオプション

いくつかのRTPパラメータを制御することが可能です。

```
rtptimeout=60
```

これは、保留中でない状態で60秒以上RTPアクティビティがない通話を終了させます。

```
rtpholdtimeout=120
```

これは、保留中であってもRTPアクティビティのない通話を終了させます（rtptimeoutよりも大きな値にする必要があります）。

### SIP NATトラバーサル (sip.conf)

NATの*理論*（4つのNATタイプ、Contactヘッダーの問題、キープアライブ、およびサーバー経由でのメディア強制）はプロトコルレベルの話であり、*SIP & PJSIP in depth*の章で解説されています。ここに示されている`sip.conf`パラメータ（`nat=`、`qualify=`、`directmedia=`、`externaddr=`、`localnet=`）は**レガシーなchan_sip**のものであり、Asterisk 21以降では削除されました。PJSIPでは、これらはトランスポート上の`rewrite_contact=yes`、`force_rport=yes`、`rtp_symmetric=yes`、`direct_media=no`、`external_media_address`、`external_signaling_address`、`local_net=`、およびAOR上の`qualify_frequency=`といったトランスポート/endpoint設定にマッピングされます。

レガシーなchan_sipにおいて、パラメータ`nat`には5つのオプションがありました。

- nat = no — RFC3581以外の特別なNAT処理を行わない
- nat = force_rport — rportパラメータが存在しなかった場合でも、存在したかのように振る舞う
- nat = comedia — SDPで指定された送信先に関わらず、Asteriskがメディアを受信したポートへメディアを送信する
- nat = auto_force_rport — AsteriskがNATを検出した場合にforce_rportオプションを設定する（デフォルト）
- nat = auto_comedia — AsteriskがNATを検出した場合にcomediaオプションを設定する

sip.confファイルに「nat=force_rport」という記述を入れると、Asteriskに対して、SIPヘッダーの「Contact」ヘッダーフィールドに含まれるアドレスを無視し、パケットのIPヘッダーにある送信元IPアドレスとポートを使用するよう指示することになります。また、SDPヘッダーの内容を無視して、メディアを受信したアドレスへ送り返すよう指示することにもなります。

```
nat=force_rport,comedia
```

NATマッピングを維持しておく必要があります。NATがタイムアウトすると、AsteriskはUACに対してINVITEを送信できなくなります。UACは発信はできますが、着信が一切できなくなります。NATを維持するために、以下のステートメントを使用できます。

```
qualify=yes
```

Qualifyは、SIPのOPTIONSメソッドを使用したパケットを定期的に送信し、NATを維持するのに役立ちます。Qualifyは60秒ごとにOPTIONSを送信し、ホストに到達できない場合は10秒ごとに送信します。`sip show peers`を使用すると、ピアのレイテンシを確認できます。ユーザーのNATが対称型（symmetric）である場合、あるUACから別のUACへ直接パケットを送信することはできません。その場合は、以下を使用してRTPをAsterisk経由で強制的に中継する必要があります。

```
directmedia=no
```

#### NAT配下のAsterisk (sip.conf)

これまでのすべてのシナリオでは、Asteriskサーバーが外部（有効な）インターネットアドレスを持っていることを前提としていました。場合によっては、AsteriskサーバーがNATを使用するファイアウォールの背後に実装されることもあります。この場合、いくつかの追加設定を行う必要があります。

![NAT配下のAsterisk: ファイアウォールがパブリックアドレス 200.180.4.168 を内部のAsteriskサーバー (192.168.1.100) にマッピングし、UDP 5060 の SIP と rtp.conf で定義された UDP 10000–20000 の RTP 範囲を転送している様子](../images/07-sip-and-pjsip-fig13.png)

1. UDPポート 5060 をAsteriskサーバーへ静的にリダイレクトするようにファイアウォールを設定します。
2. UDPポート 10000 から 20000 を静的にリダイレクトするようにファイアウォールを設定します。

開放するポート数を制限したい場合は、`rtp.conf`ファイルを編集してRTPポートの範囲を変更できます。別の方法として、SIPプロトコルをサポートするインテリジェントなファイアウォールを使用して、RTPポートを動的に開放する方法もあります。

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

ステップ 3: SIPパケットのヘッダーフィールド（Session Description Protocol (SDP) を含む）に外部アドレスを含めるよう Asterisk を設定します。これは、sip.conf ファイルに以下の2つのステートメントを追加することで実現できます。

```
externaddr=200.180.4.168
;External IP address
localnet=192.168.1.0/255.255.255.0
;Internal Network Address
nat=force_rport,comedia
```

最初のパラメータである externaddr は、外部宛先の SIP ヘッダー内に外部 IP アドレスを含めるよう Asterisk に指示します。2 番目のパラメータである localnet は、Asterisk が外部アドレスと内部アドレスを区別できるようにします。オプションとして、サーバー上で DHCP アドレスと Dynamic DNS を使用している場合は externhost を使用することも可能です。

### SIP ダイヤル文字列 (chan_sip)

以下に示す `SIP/...` ダイヤル文字列テクノロジーは、削除された chan_sip ドライバーのものです。Asterisk 22 では代わりに `PJSIP/...` テクノロジーを使用してください。例えば `Dial(PJSIP/2000)` や `Dial(PJSIP/${EXTEN}@provider)` などです。形式や意味はそれ以外の場合と同様です。

レガシーな SIP 宛先を呼び出すには、異なるダイヤル文字列を使用できます。

```
SIP/peer
```

- ; sip.conf 内に定義済みの peer が必要です

```
SIP/flavio@voffice.com.br ; By the URI
SIP/[exten@]peer[:portno]
SIP/[user:password@domain/extension
```

例としては以下が挙げられます：

```
exten=>s,1,Dial(SIP/ipphone)
exten=>s,1,Dial(SIP/info@voffice.com.br)
exten=>s,1,Dial(SIP/192.168.1.8:5060,20)
exten=>s,1,Dial(SIP/8500@sip.com:9876)
```

## レガシーな chan_sip システムから PJSIP への移行

Asterisk 21 で `chan_sip` が削除され、Asterisk 22 では完全に廃止されたため、既存の `sip.conf` デプロイメントはすべて PJSIP に移行する必要があります。概念上の最大の変更点は、単一の `sip.conf` `[peer]` または `[friend]` が、それぞれ `type=` を持つ複数の PJSIP オブジェクトに分割されることです。具体的には、**endpoint**（通話/codec/メディア設定）、1つ以上の **aor** オブジェクト（デバイスの到達先/登録先）、**auth** オブジェクト（認証情報）、および共有の **transport**（リッスンソケット、NAT アドレス）に分かれます。以下の表は、一般的な概念の対応関係を示しています。

| レガシー sip.conf の概念 | PJSIP の同等機能 (pjsip.conf) |
| --- | --- |
| `[peer]` / `[friend]` ブロック | `type=endpoint` + `type=aor` + `type=auth` (`auth=` および `aors=` を介して参照) |
| `type=friend` / `type=peer` / `type=user` | 単一の `type=endpoint` (PJSIP には friend/peer/user の区別はありません) |
| `host=dynamic` (デバイス登録) | `max_contacts=1` を持つ `type=aor`; デバイスは REGISTER を送信してコンタクトを更新します |
| `host=<ip/hostname>` (静的) | 静的な `contact=sip:host:port` を持つ `type=aor` |
| `register=>user:secret@host/ext` (アウトバウンド) | `type=registration` (`server_uri=`, `client_uri=`, `outbound_auth=`) |
| `secret=` / `username=` | `type=auth`, `auth_type=userpass`, `username=`, `password=` |
| `context=` | endpoint 上の `context=` |
| `disallow=all` / `allow=ulaw` | endpoint 上の `disallow=all` / `allow=ulaw` (構文は同じ) |
| `dtmfmode=rfc2833` | `dtmf_mode=rfc4733` (PJSIP) — および `inband`, `info`, `auto` |
| `directmedia=yes/no` | endpoint 上の `direct_media=yes/no` |
| `nat=force_rport,comedia` | `force_rport=yes`, `rewrite_contact=yes`, `rtp_symmetric=yes` (endpoint) |
| `qualify=yes` | **aor** 上の `qualify_frequency=` (秒単位) |
| `externaddr=` | **transport** 上の `external_media_address=` および `external_signaling_address=` |
| `localnet=` | **transport** 上の `local_net=` |
| `insecure=invite` (プロバイダー、認証なし) | `auth=`/`outbound_auth=` を省略し `identify` (`type=identify`, `match=`) を使用 |
| `allowguest=yes` | `anonymous` endpoint + `allow_unauthenticated_options` (使用には注意が必要) |
| `tos_sip` / `tos_audio` | endpoint 上の `tos_audio` / `tos_video` (および `cos_audio` / `cos_video`) |

レガシーな `sip.conf` で以下のように記述されていた登録型 extension は：

```
[2000]
type=friend
host=dynamic
context=default
dtmfmode=rfc2833
disallow=all
allow=ulaw
secret=senha
```

Asterisk 22 上の `pjsip.conf` では以下のようになります：

```
[2000]
type=endpoint
context=default
disallow=all
allow=ulaw
dtmf_mode=rfc4733
direct_media=no
auth=2000
aors=2000

[2000]
type=auth
auth_type=userpass
username=2000
password=senha

[2000]
type=aor
max_contacts=1
qualify_frequency=60
```

### sip_to_pjsip.py 変換スクリプト

Asterisk には、既存の `sip.conf` を読み込んで `pjsip.conf` を生成するヘルパースクリプト **`sip_to_pjsip.py`** が同梱されています。これは /etc/asterisk ディレクトリ内で直接実行できます。このユーティリティは、Asterisk ソースツリー内の `contrib/scripts/sip_to_pjsip/` にあります（ここで `${PATH_TO_ASTERISK_SOURCE}` は Asterisk ソースファイルがあるパス、通常は /usr/src/asterisk-22.x.y/ です）：

```
${PATH_TO_ASTERISK_SOURCE}/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py
```

`--help` オプションを付けて実行すると、オプションの一覧が表示されます：

```
-h, --help                help
-p, --prefix PREFIX       prefix to use for the included config files
-q, --quiet               suppress warnings and informational messages
```

また、オプションの位置引数として `[input-file [output-file]]` を受け取り、デフォルトではカレントディレクトリの `sip.conf` および `pjsip.conf` が使用されます。

この出力はあくまで **出発点** として扱ってください。生成されたすべてのオブジェクト、特に transport、NAT 設定、codec リストを確認し、本番環境に投入する前に徹底的にテストしてください。

VoIP School Blackbelt (voip.school) のコンパニオンラボにある sip.conf を移行してみましょう。

#### sip.conf

```
[general]
bindport=5060
bindaddr=0.0.0.0
context=dummy
disallow=all
allow=ulaw
alwaysauthreject=yes
allowguest=no
register=>1020:supersecret@sip.flagonc.com:5600/9999
[alice]
type=friend
secret=#supersecret#
host=dynamic
qualify=yes
directmedia=no
context=from-internal
[bob]
type=friend
secret=#supersecret#
host=dynamic
qualify=yes
directmedia=no
context=from-internal
[siptrunk]
type=peer
defaultuser=1020
secret=supersecret
port=5600 ; nor 5060, 5600
insecure=invite
host=sip.flagonc.com
fromuser=1020
fromdomain=sip.flagonc.com
context=from-siptrunk
```

#### pjsip.conf

```
;--
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[general]
bindport = 5060
[alice]
qualify = yes
[bob]
qualify = yes
[siptrunk]
defaultuser = 1020
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
--;
[transport-udp]
type = transport
protocol = udp
bind = 0.0.0.0:5060
[reg_sip.flagonc.com]
type = registration
retry_interval = 20
max_retries = 10
contact_user = 9999
expiration = 120
transport = transport-udp
outbound_auth = auth_reg_sip.flagonc.com
client_uri = sip:1020@sip.flagonc.com:5600
server_uri = sip:sip.flagonc.com:5600
[auth_reg_sip.flagonc.com]
type = auth
password = supersecret
username = 1020
[alice]
type = aor
max_contacts = 1
[alice]
type = auth
username = alice
password = #supersecret#
[alice]
type = endpoint
context = from-internal
disallow = all
allow = ulaw
direct_media = no
auth = alice
outbound_auth = alice
aors = alice
[bob]
type = aor
max_contacts = 1
[bob]
type = auth
username = bob
password = #supersecret#
[bob]
type = endpoint
context = from-internal
disallow = all
allow = ulaw
direct_media = no
auth = bob
outbound_auth = bob
aors = bob
[siptrunk]
type = aor
contact = sip:1020@sip.flagonc.com:5600
[siptrunk]
type = identify
endpoint = siptrunk
match = sip.flagonc.com
[siptrunk]
type = auth
username = siptrunk
password = supersecret
[siptrunk]
type = endpoint
context = from-siptrunk
disallow = all
allow = ulaw
from_user = 1020
from_domain = sip.flagonc.com
auth = siptrunk
outbound_auth = siptrunk
aors = siptrunk
```

変換は概ねうまくいっているようですが、qualify=yes のような一部の要素は直接マッピングできないことがわかります。これを修正するには、aor セクションに qualify_frequency=time（秒単位）というコマンドを追加する必要があります。以下の例を参照してください。

```
[bob]
type = aor
max_contacts = 1
qualify_frequency=15
```

PJSIP の詳細な設定については *SIP & PJSIP in depth* の章で解説しており、docs.asterisk.org の公式ドキュメントでもこのチャネルについて網羅的に説明されています。voip.school のコンパニオンラボでは、ラボ 5 で今学んだことを実際に練習できます。

## まとめ

本章では、今日の純粋なVoIP展開以前から存在するものの、Asterisk 22でも引き続きサポートされているチャネル技術についてまとめました。DAHDI上の **FXO/FXS** インターフェースを介した **アナログ** 回線や電話機の接続方法、**デジタルTDM** リンク（E1/T1およびISDN PRI/BRI）のプロビジョニング方法、そして現在では完全にレガシーな技術でありながら、依然として効率的でNATフレンドリーなサーバー間trunkとして機能する **IAX2**（`chan_iax2`）について解説しました。また、すでに廃止された **`chan_sip`** ドライバとその `sip.conf` 構文についても振り返りました。これらは古いシステムでは見かけますが、Asterisk 22には存在しません。さらに、概念マッピングテーブルと `sip_to_pjsip.py` スクリプトを使用して、そのようなシステムをPJSIPへ移行する方法についても学習しました。経験則として、本章で取り上げた技術は、物理ハードウェアや既存のレガシーシステムによって強制される場合にのみ使用してください。新規構築（グリーンフィールド）の場合は、すべてIPベースのPJSIPを選択するのが原則です。

## クイズ

1. 2つのアナログForeign eXchangeインターフェースに関して、正しい記述をすべて選択してください：
   - A. FXOインターフェースはPSTN（公衆交換電話網）の局側に接続し、そこからダイヤルトーンを取得する。
   - B. FXSインターフェースは、標準的なアナログ電話機、FAX、またはモデムに対してダイヤルトーンと呼び出し電力を供給する。
   - C. FXSインターフェースは、Asteriskを電話会社の回線に接続するための正しい方法である。
   - D. FXOインターフェースは、レガシーPBXの内線ポートに接続することもできる。
2. アナログ回線における監視信号には、以下のどれが含まれますか（すべて選択してください）？
   - A. オンフック
   - B. オフフック
   - C. 呼び出し（リンギング）
   - D. DTMF
3. DAHDIアナログカードで発生するエコー、ポップ音、ノイズの原因として最も多いものはどれですか：
   - A. Asteriskのコンパイル方法
   - B. PCI割り込みの競合
   - C. 不適切なSIP codec
   - D. dialplanの欠如
4. アナログチャネルで正確な課金を行うには、相手側がいつ応答したかを正確に検出する必要があります。これを実現するためにAsteriskで有効にし（かつ電話会社に要求する）機能はどれですか？
   - A. Answer reversal
   - B. Billing reversal
   - C. Polarity reversal
   - D. ダイヤルトーン生成
5. DAHDIハードウェアはAsteriskから独立しています。物理カードは`/etc/dahdi/system.conf`で設定され、一方`chan_dahdi.conf`はハードウェアそのものではなくAsteriskのチャネルを定義します。
   - A. 正
   - B. 誤
6. デジタルtrunkの容量と信号方式に関して、正しい記述をすべて選択してください：
   - A. E1 trunkは30の音声チャネルを運び、T1 trunkは24の音声チャネルを運ぶ。
   - B. ISDN PRIは、E1では30B+D、T1では23B+Dを使用する。
   - C. ISDNはCCS信号方式の例であり、MFC/R2はCAS信号方式の例である。
   - D. T1は、ヨーロッパやラテンアメリカで最も一般的に使用されるデジタルtrunkである。
7. DAHDIカードを自動的に検出し、`/etc/dahdi/system.conf`および`dahdi-channels.conf`を生成するユーティリティはどれですか？
   - A. dahdi_generator
   - B. dahdi_genconf
   - C. dahdi_cfg
   - D. generate_dahdi
8. レガシーな`sip.conf`の`[friend]`をPJSIPに移行する場合、単一のブロックを複数のオブジェクトに分割する必要があります。通常、1つの登録を行う`[friend]`を置き換えるPJSIPの`type=`オブジェクトのセットはどれですか？
   - A. `type=endpoint`、`type=aor`、および`type=auth`
   - B. `type=peer`および`type=user`
   - C. `type=sip`のみ
   - D. `type=channel`および`type=device`
9. 2つのAsteriskサーバー間でIAX2 trunkモードを使用する主な実用上の利点は何ですか？
   - A. デフォルトでTLSを使用してすべての通話を暗号化する
   - B. 単一のヘッダーで複数の通話を運ぶため、帯域幅を節約できる
   - C. codecが一切不要になる
   - D. 品質向上のために通話ごとに個別のUDPポートを割り当てる
10. RSA鍵はIAX2認証に使用できます。秘密にしておくべき鍵と、相手のサーバーに渡すべき鍵はどれですか？
    - A. 公開鍵を秘密にし、秘密鍵を共有する
    - B. 秘密鍵を秘密にし、公開鍵を共有する
    - C. 共有鍵を秘密にし、秘密鍵を共有する
    - D. 両方の鍵を共有しなければならない

**回答:** 1 — A, B, D · 2 — A, B, C · 3 — B · 4 — C · 5 — A · 6 — A, B, C · 7 — B · 8 — A · 9 — B · 10 — B
