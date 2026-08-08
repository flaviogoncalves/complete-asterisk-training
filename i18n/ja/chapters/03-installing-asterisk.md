# Asterisk 22のインストール

第1章では、電話環境においてAsteriskがどのように役立つかについて少し学びました。本章では、Asteriskのダウンロードとインストール方法について解説します。作業を始める前に、コンパイルとインストールの方法を学ぶことが不可欠です。コンパイルのプロセスは、従来のMicrosoft™ Windows™ユーザーには奇妙に思えるかもしれませんが、Linux™環境ではごく一般的なことです。Asteriskをコンパイルすることで、使用しているハードウェアに最適化されたコードを得ることができます。本章ではその手順を行います。Asteriskはいくつかのオペレーティングシステムで動作しますが、ここではシンプルにするためにLinuxのみを使用します。依存関係のインストールが容易で、フットプリントが小さく、安定しており、サポートが充実しているサーバー向けディストリビューションである**Ubuntu 24.04 LTS**を使用します。別のディストリビューションを好む場合は、それに応じてパッケージ名を調整してください。

本書は**Asterisk 22 LTS**（2024年10月16日リリース。2028年10月16日までフルサポート、2029年10月16日までセキュリティ修正）を対象としています。Asterisk 22は、現在の長期サポートリリースです。Digiumは2018年に**Sangoma**によって買収され、現在AsteriskはSangomaによってスポンサーされていることに注意してください。本章全体を通して言及される「Digium」は、歴史的なハードウェアに関するレガシーブランドを指します。

## Objectives

この章を読み終えることで、以下のことができるようになります。

- Asteriskのハードウェア要件を判断する
- 必要な依存関係を備えたLinuxをインストールする
- HTTPS経由で安定版をダウンロードする
- Asteriskをコンパイルする
- 起動時にAsteriskを開始する方法を学ぶ

## Minimum Hardware Required

Asteriskを動作させるために多くのハードウェアは必要ありませんが、要件に合わせて最適なハードウェアを選択するためのヒントがいくつかあります。ハードウェアを選択する際は、以下の主要な要素を考慮する必要があります。

- 登録ユーザーの総数。1秒あたりにサポートする必要がある登録数を定義します。
- 同時通話の総数。Asteriskサーバーのネットワークアダプターおよびブリッジで処理する必要があるネットワーク会話の数を定義します。
- サポートする必要があるcodec。複雑度の高いcodecはサーバーのCPU/FPUパワーを大量に消費します。例えば、iLBCは作成者（Global IP Sound）によって、TI C54x DSP上で30 msフレームあたり約18 MIPS（20 msフレームでは約15 MIPS）と測定されています。
- エコーキャンセレーション。エコーキャンセレーションは多くのCPU/FPUを消費する可能性があるため、場合によってはテレフォニーインターフェースカード内のDSPを使用したハードウェアエコーキャンセレーションを選択する必要があります。
- 可用性。可用性を高めるためにRAID1またはRAID5を使用してください。Asteriskは24時間365日稼働するアプリケーションであることを忘れないでください。

Asteriskサーバーの主要なコンポーネントはネットワークアダプターです。優れたサーバー用ネットワークアダプターの使用を推奨します。g.729やiLBCのような複雑度の高いcodecやエコーキャンセレーションをサポートする必要がある場合、CPUは重要です。これらを専用のDSPにオフロードすることも可能です。Sangoma（旧Digium）は、120のG.729同時通話をサポート可能なTC400BというDSPカードを提供しています。

ベストプラクティスは、既知のメーカーの新しいサーバークラスのコンピューターを選択することです。特定のマシンが何件の同時通話や登録ユーザーをサポートできるかを正確に把握するには、SIPP (http://sipp.sourceforge.net) のようなストレステストツールを使用してハードウェアをテストする必要があります。Xorcom (http://www.xorcom.com) のような一部のハードウェアメーカーは、その結果をWebサイトで公開しています。

注: ConfBridgeやmusic on holdなど、一部のAsteriskアプリケーションには内部タイミングソースが必要です。現代のLinuxでは、これは組み込みの `res_timing_timerfd` モジュールによって自動的に提供されるため、テレフォニーハードウェアは不要です。（古い `dahdi_dummy` ソフトウェアタイマーは存在しなくなりました。その機能はDAHDI Linux 2.3.0でメインの `dahdi` カーネルモジュールに統合されました。）アクティブなタイマーはCLIコマンド `timing test` で確認できます。

### Hardware configuration

Asteriskのハードウェアは洗練されている必要はありません。高価なビデオカードや多数の周辺機器は不要です。ハードウェア構成に関するヒントをいくつか挙げます。

- 不要なUSB、シリアル、パラレルポートを無効にして、不必要な割り込みの消費を避けてください。
- 堅牢なネットワークインターフェースカードが不可欠です。
- テレフォニーインターフェースカードを使用する場合は特に注意してください。一部のカードは3.3ボルトのPCIバスを使用しますが、それに対応するマザーボードを見つけるのは容易ではありません。現在では、PCI expressの方が容易に入手できます。
- ハードディスクには細心の注意を払ってください。PBXは24時間365日の体制で動作しますが、デスクトップは8時間×5日の稼働を想定しています。PBXにデスクトップ用ハードウェアを使用しないでください。通常、1年以内にハードディスクが故障します。サーバーマシン、または24時間365日のアプリケーションを実行するように設計されたアプライアンスを使用することを推奨します。

### IRQ sharing (legacy PCI cards only)

この懸念は、物理的なPCI/PCI-Expressテレフォニーカード（DAHDIハードウェア）をインストールする場合**のみ**適用されます。このようなカードは大量の割り込みを生成するため、古いシングルCPUシステムでは、他のデバイスとIRQラインを共有するとドライバーが枯渇し、音声品質が低下する可能性があります。テレフォニーカードを使用する場合は、そのマシンをAsterisk専用にし、BIOSで未使用のオンボードデバイスをすべて無効にし、割り当てられた割り込みを `cat /proc/interrupts` で確認してください。MSI/MSI-X割り込みを使用する現代のマルチコアサーバーでは、実際にはIRQ共有は問題にならず、純粋なVoIP展開（カードなし）であれば、この点を心配する必要は全くありません。

## Linuxディストリビューションの選択

Asteriskは当初、Linux上で動作するように開発されました。しかし、BSD UnixやmacOS上で動作させることも可能です。Asteriskが初めてであれば、より容易なLinuxから始めることをお勧めします。Asteriskは公式にRHELファミリー（CentOS/RHEL/Fedora）、Ubuntu、Debianをターゲットとしています。現在、実用的な選択肢としては **Debian 12**、**Ubuntu 22.04 LTS / 24.04 LTS**、そして **Rocky Linux 9 / AlmaLinux 9** が挙げられます。CentOS Linuxはサポートが終了しているため、RHELファミリーのシステムではRocky LinuxまたはAlmaLinuxを優先してください。本書ではUbuntu 24.04 LTSを使用します。以下の公式リリースディレクトリから、最新の24.04ポイントリリースサーバーイメージをダウンロードしてください（正確なファイル名は現在のポイントリリースを含みます。例：`ubuntu-24.04.4-live-server-amd64.iso`）。

```
https://releases.ubuntu.com/24.04/
```

### AsteriskのためのLinuxの準備

Asteriskをコンパイルする前に、ビルドパッケージがインストールされた動作可能なLinuxシステムが必要です。仮想マシンまたは専用ボックスに **Ubuntu 24.04 LTS Server** をインストールしてください（64ビットイメージを使用してください。本書の内容はすべて64ビットを前提としていますが、Asterisk自体は依然として32ビットx86もサポートしています）。このトレーニングではVirtualBoxを使用しました。イメージは <https://releases.ubuntu.com/24.04> からダウンロードできます。Linux自体のインストールは本書の範囲外であり、基本的なLinuxの知識があることが前提となります。Linuxのインストールが完了したら、Asteriskのビルド依存関係を追加し（後述の *依存関係のインストール* を参照）、その後Asteriskをコンパイルします。

## AsteriskのためのLinuxインストール

グラフィカルデスクトップを使用せず、通常の手順でLinuxをインストールしてください。インストール中にメール転送エージェント（ここでは **exim4** を使用します）も有効にしてください。本書の後半で、Asteriskがボイスメールからメールへの通知を送信するために必要となります。**注意:** オペレーティングシステムのインストールを行うと、対象のディスクは消去されます。物理ハードウェアにインストールする場合は、事前にデータをバックアップしてください。仮想マシンへのインストールであれば、ホスト環境には影響しません。Ubuntu ServerのISO（または仮想マシンの仮想光学ドライブ）からインストーラーを起動し、プロンプトに従って回答してください。ほとんどの項目は単純明快です。

## 依存関係のインストール

Asterisk および DAHDI をインストールするには、多くのソフトウェア依存関係をインストールする必要があります。Asterisk 22 において推奨される方法は、ソースツリーに同梱されているスクリプトを使用することです。このスクリプトは、サポートされている各ディストリビューションの正しいパッケージ名を把握しています。Asterisk のソースをダウンロードして展開した後（後述の「Asterisk のコンパイル」を参照）、以下を実行してください。

```
cd /usr/src/asterisk-22.x.y
./contrib/scripts/install_prereq install
```

1. root としてログインするか、または `sudo` を使用します。
2. Debian/Ubuntu システムで依存関係を手動でインストールすることを好む場合、同等のパッケージリストは以下の通りです。

```
apt-get install build-essential git wget openssl libssl-dev libxml2-dev \
  libsqlite3-dev uuid-dev libjansson-dev libedit-dev libncurses-dev \
  libcurl4-openssl-dev pkg-config autoconf-archive
```

Asterisk のソースは現在 Git でホストされているため `subversion` は不要であり、最新の Debian/Ubuntu ではバージョン付きの `libncurses5-dev` ではなく `libncurses-dev` が提供されていることに注意してください。スクリプトは常にディストリビューションに適した正しいパッケージ名を追跡するため、手動で管理するリストよりも `./contrib/scripts/install_prereq install` を優先してください。

### DAHDI

DAHDI (Digium/Sangoma Asterisk Hardware Device Interface) は、アナログおよびデジタルカード用のドライバアーキテクチャです。アナログまたはデジタルインターフェースを使用する予定がある場合は、Asterisk をインストールする前に DAHDI をインストールすることが重要です。DAHDI は依然としてアナログ/デジタル電話カードのために存在しますが、その利用はますます限定的になっています。現代のデプロイメントのほとんどは純粋な VoIP であり、このセクションを完全にスキップできます。物理的な電話インターフェースハードウェアがある場合にのみ DAHDI をインストールしてください。以下のコマンドを使用してソースファイルを取得します。

```
wget https://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-current.tar.gz
```

以下のコマンドを使用してファイルを展開します。

```
tar -xzvf dahdi-linux-complete-current.tar.gz
```

### DAHDI ドライバのコンパイル

DAHDI モジュールをコンパイルする必要があります。`./configure` および `make menuselect` コマンドは数年前に導入されました。後者を使用すると、ビルドするユーティリティやモジュールを選択できます。以下のコマンドでこれを行います。

```
cd dahdi-linux-complete-X.Y.Z+X.Y.Z/linux   # adapt to the version downloaded
make
make install
cd ../tools
autoreconf -i
./configure
make
make install
```

`make install-config` により DAHDI が設定されました。DAHDI ハードウェアがある場合は、このシステムにインストールされている DAHDI ハードウェアのサポートのみを読み込むように `/etc/dahdi/modules` を編集することを推奨します。デフォルトでは、DAHDI の起動時にすべての DAHDI ハードウェアのサポートが読み込まれます。システム上の DAHDI ハードウェアは以下の通りであると考えられます: `usb:004/002 xpp_usb- e4e4:1150 Astribank-multi no-firmware` 上記の画面では、特定の構成に必要なドライバのみを読み込み、検出されたハードウェアを表示するように `/etc/dahdi/modules` ファイルを変更するよう求めています。`/etc/dahdi/modules` ファイルを編集し、必要なハードウェアのみを読み込んでください。私の場合、Xorcom Astribank 6FXS および 2FXO を搭載したテストマシンを使用していました。そのファイルを以下に示します。

```
# Contains the list of modules to be loaded / unloaded by /etc/init.d/dahdi.
#
# NOTE:  Please add/edit /etc/modprobe.d/dahdi or /etc/modprobe.conf if you
#        would like to add any module parameters.
#
# Format of this file: list of modules, each in its own line.
# Anything after a '#' is ignore, likewise trailing and leading
# whitespaces and empty lines.
# Digium TE205P/TE207P/TE210P/TE212P: PCI dual-port T1/E1/J1
# Digium TE405P/TE407P/TE410P/TE412P: PCI quad-port T1/E1/J1
# Digium TE220: PCI-Express dual-port T1/E1/J1
# Digium TE420: PCI-Express quad-port T1/E1/J1
#wct4xxp
# Digium TE120P: PCI single-port T1/E1/J1
# Digium TE121: PCI-Express single-port T1/E1/J1
# Digium TE122: PCI single-port T1/E1/J1
#wcte12xp
# Digium T100P: PCI single-port T1
# Digium E100P: PCI single-port E1
#wct1xxp
# Digium TE110P: PCI single-port T1/E1/J1
#wcte11xp
# Digium TDM2400P/AEX2400: up to 24 analog ports
# Digium TDM800P/AEX800: up to 8 analog ports
# Digium TDM410P/AEX410: up to 4 analog ports
#wctdm24xxp
# X100P - Single port FXO interface
# X101P - Single port FXO interface
#wcfxo
# Digium TDM400P: up to 4 analog ports
#wctdm
# Xorcom Astribank Devices
xpp_usb
```

コンピュータを再起動し、ドライバが正しく読み込まれていることを確認してください。

## どのバージョンを選択すべきか

経験則として、必要な機能が含まれているバージョンを使用すべきです。Asteriskは、LTS（長期サポート）リリースと標準リリースを交互に繰り返すリリースモデルを採用しています。本書の執筆時点では、**Asterisk 22が最新のLTSリリース**（2024年10月リリース。最新のポイントリリースは 22.10.0）であり、現時点で選択すべき最適なバージョンです。Asterisk 20は前回のLTSであり、バージョン 16（初版で使用）はサポートが終了しています。本番環境のシステムには、常にLTSリリースを選択してください。

## Asteriskのコンパイル

これまでにソフトウェアをコンパイルした経験があれば、Asteriskのコンパイルは容易な作業です。以下のコマンドを実行して、Asteriskをコンパイルおよびインストールします。make menuselectを使用して、ビルドするアプリケーションやモジュールを選択できることを覚えておいてください。ステップ1: ソースコードのダウンロード

```
cd /usr/src
wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz
tar -xzvf asterisk-22-current.tar.gz
```

ステップ2: ビルドの前提条件をインストールする（上記の「依存関係のインストール」を参照）

```
cd asterisk-22.x.y (adapt to the version downloaded)
./contrib/scripts/install_prereq install
```

ステップ3: ビルドの設定

```
./configure
```

ステップ4: ビルドするモジュールの選択

```
make menuselect
```

make menuselectを使用して、必要なモジュールのみをインストールします。Asterisk 22では、SIPチャネルは **chan_pjsip** （デフォルトでビルドされます）です。古い **chan_sip** はAsterisk 21で削除され、現在は存在しません。Opusの *pass-through* はそのまま動作します（ツリー内の `res_format_attr_opus` モジュールがSDPネゴシエーションを処理します）が、 **codec_opus** トランスコーディングモジュールは依然としてSangoma/Digiumが提供する外部のクローズドソースバイナリです。menuselectでこれを選択すると、Digiumのサーバーからダウンロードされます。このバイナリは無料です。詳細は以下の「menuselectによるモジュールの選択」を参照してください。

ステップ5: Asteriskのビルドとインストール、およびデフォルト設定とサンプルファイルの作成

```
make
make install
make samples
make config
ldconfig
```

`make install` はバイナリとモジュールをインストールし、 `make samples` はサンプル設定ファイルを `/etc/asterisk` に書き込みます。 `make config` は検出されたディストリビューション（例: Debian/Ubuntu上の `/etc/init.d/asterisk` ）用のSysV init起動スクリプトをインストールし、 `ldconfig` は共有ライブラリのキャッシュを更新します。systemdユニットもソースツリーの `contrib/systemd/asterisk.service` に同梱されていますが、 `make config` はそれを自動的にインストールしません。systemd下でAsteriskを実行したい場合は、自分で適切な場所にコピーしてください（下記参照）。

### menuselectによるモジュールの選択

`make menuselect` は、ビルドするアプリケーション、codec、チャネル、リソースを正確に選択するためのテキストベースのメニューを開きます。Asterisk 22に固有の注意点をいくつか挙げます。

- **chan_pjsip** （ *Channel Drivers* 内）は最新のSIPチャネルであり、デフォルトで有効になっています。Asterisk 22における唯一のSIPチャネルです。
- **codec_opus** （ *Codec Translators* 内）は **外部** モジュールです（menuselectの項目には「Download the Opus codec from Digium」と表示されます）。これを有効にすると、 `make` がSangoma/Digiumから無料のクローズドソースバイナリを取得します。Opusのpass-through自体には追加のモジュールは不要です。Sangomaの **codec_g729** モジュールも利用可能です。バイナリのダウンロードは無料ですが、法的にG.729のトランスコーディングを行うには、チャネルごとに購入したライセンスが必要です。
- *Core Sound Packages*、 *Music On Hold File Packages*、および *Extras Sound Packages* メニューで、必要なサウンドフォーマットと言語を選択してください。チェックを入れたものはすべて、 `make install` の実行中に自動的にダウンロードおよびインストールされます。

選択が完了したら、 **Save & Exit** を選択し、 `make` に進んでください。

## Asteriskの起動と停止

この最小限の構成で、Asteriskを正常に起動することが可能です。学習やデバッグの目的では、コンソールにアタッチした状態でAsteriskをフォアグラウンドで起動することができます。

```
/usr/sbin/asterisk -vvvgc
```

Asteriskをシャットダウンするには、CLIコマンドの`core stop now`を使用します。

```
*CLI> core stop now
```

### systemdによるAsteriskの起動

最近のLinuxディストリビューション（Debian 12、Ubuntu 22.04/24.04、Rocky/AlmaLinux 9）では、システムサービスマネージャーとして**systemd**が採用されています。Asteriskのソースツリーには`contrib/systemd/asterisk.service`にsystemdユニットファイルが含まれています。これを`/etc/systemd/system/asterisk.service`にコピーし、`systemctl daemon-reload`を実行してください。インストールが完了したら、本番環境でAsteriskを運用する推奨の方法は`systemctl`を使用することです。

```
systemctl start asterisk      # start the service
systemctl stop asterisk       # stop the service
systemctl restart asterisk    # restart the service
systemctl status asterisk     # show current status
systemctl enable asterisk     # start automatically at boot
```

Asteriskがサービスとして実行されている状態では、`asterisk -r`（接続）または`asterisk -rvvv`（詳細な出力付きで接続）を使用してCLIにアタッチします。

古いシステムでは、AsteriskはレガシーなSysV initスクリプト（`/etc/init.d/asterisk`）と、クラッシュ時に自動的にAsteriskを再起動する**safe_asterisk**ラッパーを介して起動されていました。systemdでは、自動再起動はユニットファイルの`Restart=`ディレクティブによって処理されるため、一般的に`safe_asterisk`は不要になりました。レガシーなinitや`safe_asterisk`による手法は現在も機能しますが、systemdベースのディストリビューションでは非推奨となっています。

### Asteriskの実行時オプション

Asteriskの起動プロセスは非常に単純です。パラメータを指定せずにAsteriskを実行すると、デーモンとして起動します。

```
/sbin/asterisk
```

以下のコマンドを実行することで、Asteriskコンソールにアクセスできます。複数のコンソールプロセスを同時に実行できることに注意してください。

```
/sbin/asterisk -r
```

### Asteriskで利用可能な実行時オプション

利用可能な実行時オプションは、`asterisk -h`を使用して表示できます。

```text
sipast:/usr/src/asterisk-22.x.y# asterisk -h
Asterisk 22.10.0, Copyright (C) 1999 - 2025, Sangoma Technologies Corporation and others.
Usage: asterisk [OPTIONS]
Valid Options:
   -V              Display version number and exit
   -C <configfile> Use an alternate configuration file
   -G <group>      Run as a group other than the caller
   -U <user>       Run as a user other than the caller
   -c              Provide console CLI
   -d              Increase debugging (multiple d's = more debugging)
   -f              Do not fork
   -F              Always fork
   -g              Dump core in case of a crash
   -h              This help screen
   -i              Initialize crypto keys at startup
   -L <load>       Limit the maximum load average before rejecting new calls
   -M <value>      Limit the maximum number of calls to the specified value
   -m              Mute debugging and console output on the console
   -n              Disable console colorization. Can be used only at startup.
   -p              Run as pseudo-realtime thread
   -q              Quiet mode (suppress output)
   -r              Connect to Asterisk on this machine
   -R              Same as -r, except attempt to reconnect if disconnected
   -s <socket>     Connect to Asterisk via socket <socket> (only valid with -r)
   -t              Record soundfiles in /var/tmp and move them where they
                   belong after they are done
   -T              Display the time in [Mmm dd hh:mm:ss] format for each line
                   of output to the CLI. Cannot be used with remote console mode.
   -v              Increase verbosity (multiple v's = more verbose)
   -x <cmd>        Execute command <cmd> (implies -r)
   -X              Enable use of #exec in asterisk.conf
   -W              Adjust terminal colors to compensate for a light background
```

## インストールディレクトリ

Asteriskはいくつかのディレクトリにインストールされます。これらは `asterisk.conf` ファイルで変更可能です。学習目的であれば verbose を 3 から 15 に変更することをお勧めしますが、本番環境では 3 のままにしてください。オプションの `maxcalls` と `maxload` は、システムの過負荷を防ぐための優れたオプションです。

### asterisk.conf (抜粋)

`[directories]` セクションでは、Asteriskが設定ファイル、モジュール、データ、スプール、ログを保持する場所を定義します。

```
[directories](!) ; remove the (!) to enable this
astetcdir => /etc/asterisk
astmoddir => /usr/lib/asterisk/modules
astvarlibdir => /var/lib/asterisk
astdbdir => /var/lib/asterisk
astkeydir => /var/lib/asterisk
astdatadir => /var/lib/asterisk
astagidir => /var/lib/asterisk/agi-bin
astspooldir => /var/spool/asterisk
astrundir => /var/run/asterisk
astlogdir => /var/log/asterisk
astsbindir => /usr/sbin
```

`[options]` セクションには実行時のチューニング設定が含まれています。知っておくべき最も有用なオプションを以下に示します（有効にするにはコメントアウトを解除してください）。ファイルには他にも多くのオプションが含まれており、それぞれインラインコメントで解説されています。

```
[options]
;verbose = 3      ; Console verbosity (raise to 15 for training, keep 3 in production)
;debug = 3        ; Debug level
;maxcalls = 10    ; Maximum number of simultaneous calls allowed
;maxload = 0.9    ; Stop accepting new calls when load average exceeds this
;maxfiles = 1000  ; Maximum number of open files
;runuser = asterisk   ; The user to run as
;rungroup = asterisk  ; The group to run as
```

## ログファイルとログローテーション

Asterisk PBXは、そのメッセージを `/var/log/asterisk` に記録します。ログ記録は `logger.conf` によって制御されます。重要な部分は `[logfiles]` セクションであり、各行でログチャネルとキャプチャするメッセージレベルを定義します（抜粋）：

```ini
; logger.conf (excerpt)
[general]
;dateformat = %F %T.%3q          ; ISO 8601 timestamps, with milliseconds

[logfiles]
; <logger_name> => [formatter]<levels>
console  => notice,warning,error
messages => notice,warning,error
full     => notice,warning,error,verbose,dtmf,fax
security => security              ; PJSIP/auth security events (used by Fail2Ban)
```

編集後、 `logger reload` で変更を適用し、 `logger show channels` でチャネルを確認します：

```text
*CLI> logger show channels
Channel                       Type   Formatter  Status   Configuration
/var/log/asterisk/security    File   default    Enabled  - SECURITY
/var/log/asterisk/full        File   default    Enabled  - NOTICE WARNING ERROR VERBOSE DTMF FAX
/var/log/asterisk/messages    File   default    Enabled  - NOTICE WARNING ERROR
```

ログファイルは急速に肥大化する可能性があるため、システムの `logrotate` デーモンを使用してローテーションを行います。 `/etc/logrotate.d/` 配下にファイルを追加してください：

```text
/var/log/asterisk/messages /var/log/asterisk/*log {
   missingok
   rotate 5
   weekly
   create 0640 asterisk asterisk
   postrotate
       /usr/sbin/asterisk -rx 'logger reload'
   endscript
}
```

logrotateに関する詳細情報は、以下を使用して取得できます：

```
#man logrotate
```

## Asteriskのアンインストール

Asteriskをアンインストールするには、以下を使用します。

```
make uninstall
```

Asteriskとすべての設定ファイルをアンインストールするには、以下を使用します。

```
make uninstall-all
```

## Asteriskのインストールに関する注意点

本節では、Asteriskをインストールする前に考慮すべき問題についていくつかのアドバイスを提供します。

### 本番環境

Asteriskを本番環境にインストールする場合は、システム設計に注意を払う必要があります。サーバーは、他のシステムプロセスよりもテレフォニーシステムが優先されるように最適化しなければなりません。AsteriskをX-Windowsのようなプロセッサ負荷の高いソフトウェアと一緒に実行すべきではありません。CPU負荷の高いプロセス（大規模なデータベースなど）を実行する必要がある場合は、別のサーバーを使用してください。一般的に言って、Asteriskはハードウェアの性能変動の影響を受けやすいものです。そのため、CPU使用率が40%を超えないようなハードウェア環境でAsteriskを使用するようにしてください。

### ネットワークに関するヒント

IP電話を使用する予定がある場合は、ネットワークに注意を払うことが重要です。音声プロトコルは非常に優れており、遅延やジッターにも耐性がありますが、設定が不適切なローカルエリアネットワークを使用すると、音声品質が低下します。良好な音声品質を保証するには、スイッチやルーターでQoS（Quality of Service）を使用するしかありません。ローカルエリアネットワーク内の音声は良好である傾向がありますが、LAN環境であっても、10 Mbpsのハブを使用していて衝突（コリジョン）が多すぎる場合、最終的には音声が歪んだり、ひどい品質になったりします。最高の音声品質を確保するために、以下の推奨事項に従ってください。

- 可能であれば、あるいは経済的に実現可能であれば、エンドツーエンドのQoSを使用してください。エンドツーエンドのQoSがあれば、音声品質は完璧です。言い訳は通用しません！
- 本番環境の音声通信において、10/100 Mbpsのハブを使用することは避けてください。衝突によってネットワークにジッターが発生する可能性があります。衝突が発生しないフルデュプレックスの10/100 Mbps接続が推奨されます。
- VLANを使用して、音声ネットワークにとって不要なブロードキャストを分離してください。ウイルスによるARPブロードキャストで音声ネットワークが破壊されるような事態は避けたいはずです。
- 音声ネットワークに対する期待値についてユーザーを教育してください。QoSがない場合、ほとんどのケースで完璧な音声品質は得られないため、完璧であるとは言わないでください。多くの場合、携帯電話と同程度の音声品質が達成されます。ファームウェアやハードウェア設計の問題は一般的であるため、高品質な電話機を使用してください。

## まとめ

本章では、Asteriskの最小ハードウェア要件に加え、Asteriskのダウンロード、インストール、コンパイルの方法について学びました。セキュリティ上の理由から、Asteriskはroot以外のユーザーで実行する必要があります。本番環境を開始する前に、ネットワーク環境を確認しておくべきです。

## クイズ

1. Asterisk 22において、SIPサポートを提供するチャネルドライバはどれですか。また、以前の `chan_sip` はどうなりましたか？
   - A. `chan_sip` が依然としてデフォルトであり、 `chan_pjsip` はオプションです。
   - B. `chan_pjsip` がデフォルトのSIPチャネルであり、 `chan_sip` は Asterisk 21 で削除され、現在は存在しません。
   - C. 両方がデフォルトでビルドされ、実行時にどちらかを選択します。
   - D. SIPサポートは完全に削除され、代わりに IAX2 が採用されました。
2. Asterisk 用のテレフォニーインターフェースカードには通常、デジタル信号プロセッサ (DSP) が組み込まれているため、PC の CPU リソースをあまり必要としません。
   - A. 正
   - B. 誤
3. 完璧な音声品質を実現するには、エンドツーエンドのサービス品質 (QoS) を実装する必要があります。
   - A. 正
   - B. 誤
4. 最も安定しているため、常に最新の Asterisk バージョンを選択すべきです。
   - A. 正
   - B. 誤
5. Asterisk 22 のビルド依存関係をインストールするための推奨される方法は何ですか？
6. TDM インターフェースカードがない場合でも、Linux 上の `res_timing_timerfd` モジュールによって提供される内部タイミングソースを利用できます。このタイミングは、________ や ________ といったアプリケーションで使用されます。
7. Asterisk をインストールする際は、グラフィカルインターフェースが CPU サイクルを消費するため、GNOME や KDE といったデスクトップ環境はインストールしない方が賢明です。
   - A. 正
   - B. 誤
8. Asterisk の設定ファイルは ________ ディレクトリに配置されています。
9. Asterisk のサンプル設定ファイルをインストールするには、________ というコマンドを入力します。
10. Asterisk を root 以外のユーザーとして実行することが重要なのはなぜですか？

**回答:** 1 — B · 2 — B · 3 — A · 4 — B · 5 — 展開した Asterisk ソースツリーから `./contrib/scripts/install_prereq install` を実行する · 6 — ConfBridge および Music on Hold · 7 — A · 8 — `/etc/asterisk` · 9 — `make samples` · 10 — セキュリティ（Asterisk が侵害された場合の被害を最小限に抑えるため）
