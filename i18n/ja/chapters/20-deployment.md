# デプロイ、監視、スケーリング

ラボ環境で Asterisk に着信させることと、クラッシュ、再起動、アップグレード、攻撃に耐え、かつ監視、バックアップ、拡張が可能なサービスとして運用することは別物です。本章では、dialplan が動作した「後」に起こるすべてのことについて解説します。まずは Asterisk を稼働させ続けるためのスーパーバイザー（systemd）から始め、次にコンテナへのパッケージ化（本書の Docker ラボを実例として使用）へと進みます。その後、構成管理とバックアップ、監視と可観測性について扱い、最後にサーバー1台では不十分な場合に採用するパターン、すなわち高可用性とスケーリング、そしてクラウドホスティングの現実について説明します。

ここで紹介する内容はすべて、本書の Asterisk 22 ラボ環境である `lab/` で検証済みです。これは、本書を通じて構築してきたものと同じコンテナです。

## Objectives

この章を読み終える頃には、以下のことができるようになります。

- Asterisk 22をsystemd配下で、非rootユーザーとして、自動再起動設定付きで確実に実行する
- Dockerを使用してAsteriskをコンテナ化し、ネットワーク上のトレードオフを理解する
- `/etc/asterisk`をバージョン管理下に置き、適切な状態をバックアップする
- CLI、CDR/CEL、AMI/ARI、およびメトリクスを通じて稼働中のシステムを監視する
- アクティブ/スタンバイ構成のハイアベイラビリティ（高可用性）および水平スケーリングのパターンを適用する
- NATおよびファイアウォールの背後で、クラウド上のAsteriskを安全にホストする

## systemd下でのAsteriskの実行

現在のすべてのLinuxディストリビューション（Debian 12、Ubuntu 22.04/24.04、Rocky/AlmaLinux 9）において、サービスマネージャーは **systemd** です。インストールに関する章で示した通り、`make config`ステップ（`make install`の実行中に実行）により、ディストリビューションのinitスクリプト（Debianでは`/etc/init.d/asterisk`、RedHatでは`rc.d`スクリプト）がインストールされ、systemdがそれを自動的にサービスとしてラップします。Asteriskには、より詳細な制御を行うために代わりとしてインストール可能な、ネイティブなsystemdユニットも`contrib/systemd/asterisk.service`の下に同梱されています。
いずれにせよ、systemdはAsteriskを本番環境で実行するためのサポートされた方法です。ビルドそのものについては『*Installing Asterisk 22*』を参照してください。ここでは、サービスが提供する機能と、その操作方法に焦点を当てます。

### サービスユニットとそのライフサイクル

`make config`によってサービスがインストールされると、そのライフサイクルは通常のsystemdと同様になります。

```
systemctl enable asterisk     # start automatically at boot
systemctl start asterisk      # start now
systemctl status asterisk     # is it running? recent log lines
systemctl restart asterisk    # full stop + start
systemctl stop asterisk       # stop
journalctl -u asterisk        # service logs via the journal
```

運用上の注意点をいくつか挙げます。

- **`restart`と正常なリロードの比較。** `systemctl restart`はプロセスを強制終了し、すべての通話を切断します。設定変更の際には、これを行うことはほぼありません。代わりにAsterisk CLIを使用して`asterisk -rx 'core reload'`（または`pjsip reload`のようなモジュール固有のリロード）を実行してください。`systemctl restart`は、アップグレードやプロセスが停止してしまった場合のために取っておきましょう。
- **実行中のデーモンへの接続。** Asteriskがサービスとして実行されている状態で、コンソールを開くには`asterisk -r`（または詳細な出力が必要な場合は`asterisk -rvvv`）を使用します。これは、制御ソケットを介してすでに実行中のデーモンに接続するものであり、2つ目のコピーを起動するわけではありません。

### `Restart=`がsafe_asteriskを置き換える

歴史的に、Asteriskは **safe_asterisk** ラッパーを介して起動されていました。これは、Asteriskがクラッシュした場合に再起動を行うシェルスクリプトです。systemd環境下では、その役割はユニットの`Restart=`ディレクティブが担います。systemdはプロセスの終了を検知して再起動させ、そのバックオフは`RestartSec=`によって、クラッシュループ保護は`StartLimitIntervalSec=`/`StartLimitBurst=`によって制御されます。したがって、systemdホスト上では **safe_asteriskは不要** となり、一般的に使用されません。もし提供されているユニットに設定されていない場合でも、パッケージ化されたファイルを編集することなく、ドロップインオーバーライドを使用して再起動設定を追加するのがクリーンな方法です。

```
# /etc/systemd/system/asterisk.service.d/override.conf
[Service]
Restart=always
RestartSec=2
```

これを`systemctl daemon-reload && systemctl restart asterisk`で適用します。ドロップインを使用する（インストールされたユニットを直接編集するのではなく）ことで、将来の`make config`によって変更内容が上書きされることを防げます。

### 非rootユーザーとしての実行

Asteriskは本番環境でrootとして実行すべきではありません。rootで実行されているプロセスにリモートコード実行のバグがあった場合、ホスト全体が侵害されますが、権限のないプロセスであればそのバグの影響を封じ込めることができます。これを強制するには、以下の2つの補完的な場所を設定します。

- **ユニットファイル / asterisk.conf。** パッケージ化されたユニットは通常、Asteriskを`asterisk`ユーザーおよびグループとして実行します。また、これに加えて（あるいは代わりに）、`asterisk.conf`の`[options]`セクションで`runuser`と`rungroup`を設定することもできます。デーモンはバインド後に権限を降格させる際、この設定を尊重します。

  ```
  [options]
  runuser = asterisk
  rungroup = asterisk
  ```

- **ファイルの所有権。** ランタイムディレクトリは、そのユーザーが書き込み可能である必要があります。アカウントを作成した後、所有権を確認してください。

  ```
  chown -R asterisk:asterisk /var/lib/asterisk /var/log/asterisk \
        /var/spool/asterisk /var/run/asterisk /etc/asterisk
  ```

SIP（5060）やRTP（10000以上）はすべてハイポートであるため、Asteriskがそれらをバインドするためにroot権限は **必要ありません**。root権限が必要なのはポート25のような特権ポートのみであり、Asteriskはそれを使用しません。したがって、非特権ユーザーでの実行はコストなしで行えます。（セキュリティの章で、なぜこれが重要なのかを詳しく解説しています。『*Asterisk Security*』を参照してください。）

## Asteriskのコンテナ化

コンテナは、Asteriskとその正確な依存関係を1つの不変なイメージにパッケージ化するため、テストしたものがそのまま（バイト単位で）出荷するものとなります。これに対するトレードオフはリアルタイムメディアです。SIPサーバーはレイテンシに敏感であり、外部から到達可能なUDPポートの広範かつ予測可能な範囲を必要としますが、コンテナのネットワーク機能がその妨げとなることがあります。本節の残りの部分では、この本のラボ環境である`lab/Dockerfile`および`lab/docker-compose.yml`を具体的かつ動作する例として解説し、誰もが陥る罠であるRTPとブリッジネットワークについて説明します。

### イメージ：ソースからのAsterisk構築

ラボの`Dockerfile`は、Debian 12上でソースからAsterisk 22を構築します。たとえ自分で書くことがなくても、その構成を読んでおく価値はあります。

```dockerfile
FROM debian:12-slim

ARG ASTERISK_VERSION=22.10.0
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential wget ca-certificates pkg-config \
        libedit-dev libxml2-dev libsqlite3-dev uuid-dev libssl-dev \
        libsrtp2-dev libcurl4-openssl-dev libncurses-dev \
    && rm -rf /var/lib/apt/lists/*

# ... download + tar xzf asterisk-${ASTERISK_VERSION}.tar.gz ...

RUN ./configure --with-jansson-bundled --with-pjproject-bundled \
    && make menuselect.makeopts \
    && menuselect/menuselect --enable res_srtp --enable res_http_websocket menuselect.makeopts \
    && make -j"$(nproc)" \
    && make install \
    && make install-logrotate \
    && ldconfig

EXPOSE 5060/udp 10000-10100/udp
CMD ["asterisk", "-f", "-vvv"]
```

注目すべき点は3つあります。

- **バージョンが固定されている**（`ARG ASTERISK_VERSION=22.10.0`）。再現性はコンテナ化の最大の目的です。意図的にバージョンを上げ、再構築し、再テストを行います。
- **`--with-pjproject-bundled`および`--with-jansson-bundled`**は、Asteriskとバージョンを合わせたSIPスタックを構築します。これにより、aptパッケージへの依存を減らし、ディストリビューションのPJSIPと不整合を起こす問題を回避できます。
- **`CMD ["asterisk", "-f", "-vvv"]`**はAsteriskを*フォアグラウンド*で実行します（`-f`、「do not fork」）。これはsystemdホストとの決定的な違いです。コンテナのメインプロセスはデーモン化してはならず、さもなければコンテナは即座に終了してしまいます。そのため、コンテナ内ではsystemdユニットを一切使用**しません**。コンテナランタイム（Dockerと`restart:`ポリシー）が、VM上でユニットの`Restart=`が担っていたスーパーバイザーの役割を果たします。

### `/etc/asterisk`のバインドマウント

このイメージには意図的に設定が**含まれていません**。その代わりに、`docker-compose.yml`がホストの設定ディレクトリをバインドマウントします。

```yaml
services:
  asterisk:
    build: .
    image: astbook/asterisk:22.10.0
    container_name: astlab-asterisk
    restart: unless-stopped
    volumes:
      - ./asterisk/etc:/etc/asterisk:ro
    ports:
      - "5060:5060/udp"
      - "10000-10100:10000-10100/udp"
```

`./asterisk/etc:/etc/asterisk:ro`は、バージョン管理された`lab/asterisk/etc`ディレクトリをコンテナの`/etc/asterisk`に読み取り専用（`:ro`）でマッピングします。これによるメリットは絶大です。イメージは不変かつ再利用可能な状態に保たれ、設定はホスト上に存在するため、編集が可能であり、何よりもgitで管理（次節で説明）できます。設定変更を適用するには、ファイルを編集してリロード（`docker compose exec asterisk asterisk -rx 'core reload'`）するだけで、再構築は不要です。`restart: unless-stopped`は、systemdの`Restart=`に相当するcomposeレベルの設定です。DockerはAsteriskが終了した場合にコンテナを再起動しますが、意図的に停止した場合は再起動しません。

### ホストネットワーク対ブリッジネットワーク — RTPの問題

これはコンテナ化されたAsteriskにおいて最もよくある失敗であるため、正確に理解しておく価値があります。デフォルトでは、Dockerはコンテナを**ブリッジ**ネットワークに配置し、`ports:`を使用して個々のポートを公開します。シグナリングは問題ありません。5060は1つのポートだからです。問題はメディアです。RTPはUDPポートの*範囲*を使用し（ラボの`rtp.conf`は`rtpstart=10000` / `rtpend=10100`を設定）、音声が流れる可能性のある**すべて**のポートを公開しなければなりません。

ラボではまさにそれを行っています。

```yaml
    ports:
      - "5060:5060/udp"
      - "10000-10100:10000-10100/udp"
```

RTPの公開範囲（`10000-10100`）が`rtp.conf`と完全に一致していることに注意してください。ここを間違えて、公開するポートが少なすぎたり、`rtp.conf`と異なる範囲を指定したりすると、通話は接続されても**片方向音声または無音**になります。これは、RTPパケットがDockerによって転送されていないポートに到達してしまうためです。ブリッジモードにおけるさらなる注意点が2つあります。

- **数千ものポートを公開するのは遅く、負荷が高い。** 本番環境のRTP範囲は通常10000〜20000です。Dockerが約10000ものユーザーランドプロキシ転送を作成するのは起動時に負荷がかかり、メディアパスにホップを追加することになります。このラボでは、1〜2件のテスト通話しか行わないため、意図的に100ポートという小さな範囲に抑えています。
- **SDP内のNAT。** ブリッジの背後では、Asteriskは自身のプライベートなコンテナIPを認識しており、それをSDPでアドバタイズしてしまう可能性があります。パブリックホスト上では、トランスポート上で`external_media_address` / `external_signaling_address`を使用してPJSIPに外部アドレスを伝える必要があり（`local_net`も設定）、これはNATの背後で行うのと全く同じです。以下の*クラウドホスティング*を参照してください。

代替手段は**ホストネットワーク**（`network_mode: host`）であり、これによりブリッジを完全に取り除きます。コンテナはホストのネットワークスタックを共有するため、5060やRTP範囲全体がポート公開なしで到達可能になり、余分なメディアホップも発生しません。これは本物のAsteriskコンテナにとって推奨されるモードであり、RTP範囲の問題を完全に回避できます。その代償は分離性の低下です。コンテナは任意のホストポートにバインドできるようになり、composeのサービスごとのネットワーク機能は失われます。（ホストネットワークはLinuxの機能です。macOS/Windows用のDocker Desktopでは動作が異なるため、この学習用ラボでは明示的なポート公開を使用しています。）

### スプールとボイスメールのための永続ボリューム

コンテナの書き込み可能レイヤーは**一時的**です。コンテナを破棄すると、書き込まれたものはすべて消滅します。Asteriskの場合、ボイスメール、録音、発信コールスプール、ローカルデータベースが`docker compose up --build`のたびに消えてしまうことを意味します。設定はホストからバインドマウントされているため保持されますが、*状態*も同様の扱いが必要です。コンテナ内の関連するディレクトリツリーは以下の通りです。

```
/var/spool/asterisk        # voicemail, monitor recordings, outgoing/, etc.
/var/lib/asterisk          # astdb.sqlite3 (the internal database)
/var/log/asterisk          # full, messages, security, cdr-csv/, cel-custom/
```

（ラボの実行中のコンテナには、まさにこれらが含まれています。`/var/spool/asterisk`には`voicemail`、`monitor`、`outgoing`、`recording`が含まれ、`/var/lib/asterisk`には`astdb.sqlite3`が保持されています。）これらを保持するには、重要な状態を保持するディレクトリに対して名前付きボリュームをマウントします。

```yaml
    volumes:
      - ./asterisk/etc:/etc/asterisk:ro     # config (bind, in git)
      - ast-spool:/var/spool/asterisk        # voicemail + recordings (persist)
      - ast-lib:/var/lib/asterisk            # astdb (persist)
      - ast-log:/var/log/asterisk            # logs (persist)

volumes:
  ast-spool:
  ast-lib:
  ast-log:
```

この学習用ラボでは意図的にこれらを省略しています。設計上ステートレスで再現可能であるため、すべての`up`はクリーンな状態から始まります。しかし、本番環境のコンテナには**必ず**これらが必要であり、さもなければ再デプロイのたびにボイスメールが失われることになります。

## 設定管理とバックアップ

上記のバインドマウントは、正しいモデルを示唆しています。それは、Asteriskの`/etc/asterisk`を**コード**として扱い、残りを**データ**として扱うというものです。

### `/etc/asterisk`をバージョン管理下に置く

設定ディレクトリは、テンプレート化できない機密情報を含まないテキストファイルの集合体であり、gitでの管理に最適です。リポジトリを`/etc/asterisk`で初期化します（あるいは、このラボで行っているように、プロジェクトと一緒に設定を保持し、それをバインドマウントします）。利点は以下の通りです。

- すべての変更がレビュー可能であり、元に戻すことができます（`git diff`、`git revert`）。
- 誰がいつ何を変更したかの監査証跡が得られます。
- コンテナイメージと組み合わせることで、正常動作が確認された設定のコミットと固定されたイメージタグにより、デプロイメントの状態を完全に記述できます。

Asteriskの設定に特有の注意点がいくつかあります。

- **機密情報。** `pjsip.conf`（および`manager.conf`、`ari.conf`）にはパスワードが含まれています。実際の機密情報をプレーンテキストで共有リポジトリにコミットしてはいけません。テンプレート化し（環境ごとに1ファイル作成するか、デプロイ時にシークレットマネージャーや環境変数置換を使用します）、gitにはプレースホルダーのみを保持してください。このラボの単純な`Lab-6001-secret`形式のパスワードは、プライベートなDockerサブネット内でのみ使用しているため問題ありません。
- **環境ごとのテンプレート化。** 開発、ステージング、本番環境で異なるrealtimeの値（バインドアドレス、外部IP、trunkの認証情報、データベースのURLなど）は、まさにテンプレート化すべき行であり、設定の大部分は環境間で同一に保つことができます。

### バックアップすべきもの

gitによる設定管理はdialplanとendpointをカバーしますが、稼働中のPBXはどの設定ファイルにも含まれない*状態*を蓄積します。完全なバックアップには以下が含まれます。

| 対象 | 場所 | 理由 |
|------|-------|-----|
| 設定 | `/etc/asterisk/` | dialplan、endpoint（gitにも存在） |
| voicemailと録音データ | `/var/spool/asterisk/` | ユーザーデータ — 代替不可 |
| 内部データベース | `/var/lib/asterisk/astdb.sqlite3` | `DB()`キー、デバイス状態 |
| CDR / CEL | `/var/log/asterisk/cdr-csv/`またはSQLストア | 課金および履歴 |
| 外部データベース | MySQL/PostgreSQL | realtime、CDR、voicemail |

**astdb**については特筆すべき点があります。これはAsteriskの小さな組み込みキー/値ストアであり（`/var/lib/asterisk/astdb.sqlite3`にあるSQLiteファイル）、`DB()`のdialplan関数、デバイス状態、follow-me設定などで使用されます。調査やバックアップのために、CLIからダンプを取得できます。

```
asterisk -rx 'database show'
```

CDR/CEL、voicemail、またはPJSIPの設定が外部データベースにある場合（*Asterisk Real-Time*および*Asterisk Call Detail Records*を参照）、そのデータベースがそのデータの信頼できる唯一の情報源となるため、通常のデータベースバックアップローテーションに含める必要があります。`/etc/asterisk`だけをバックアップしても十分ではありません。

## 監視と可観測性

見えないものを運用することはできません。Asteriskは、人間が素早く確認するためのものからメトリクスパイプラインに至るまで、4つのレベルでその状態を公開しています。それは、**CLI**、**CDR/CEL**レコード、**AMI/ARI**イベント、そして**メトリクスエクスポーター**です。

### CLIによるヘルスチェック

最も迅速な「正常か？」を確認する方法はCLIです。以下のコマンドは、ラボ環境に対してライブで実行されます。まずはチャネルからです。

```
*CLI> core show channels
Channel              Location             State   Application(Data)
0 active channels
0 active calls
0 calls processed
```

`0 active calls`は静かなシステムでは正常ですが、高負荷なシステムではこれがリアルタイムの同時接続数となります。`core show uptime`は、プロセスが意図せず再起動していないことを確認します。

```
*CLI> core show uptime
System uptime: 1 hour, 40 minutes, 19 seconds
Last reload: 12 minutes, 32 seconds
```

SIPの健全性については、`pjsip show endpoints`ですべてのendpointと、その登録済みコンタクトが到達可能かどうかを表示します。ラボ環境では以下のようになります。

```
*CLI> pjsip show endpoints
 Endpoint:  6001                                                 Unavailable   0 of inf
     InAuth:  6001/6001
        Aor:  6001                                               1
 Endpoint:  6002                                                 Unavailable   0 of inf
     InAuth:  6002/6002
        Aor:  6002                                               1
 Endpoint:  sipp                                                 Unavailable   0 of inf
        Aor:  sipp                                               1
   Identify:  sipp-identify/sipp
        Match: 172.30.0.0/24
 Endpoint:  webrtc-1000                                          Unavailable   0 of inf
     InAuth:  webrtc-1000/webrtc-1000
        Aor:  webrtc-1000                                        1
Objects found: 4
```

ここでの`Unavailable`は、現在そのendpointに電話機が登録されていないことを単純に意味します（ラボにはライブのクライアントが存在しないため）。softphoneが登録され、`qualify`でそれが確認されると、状態は到達可能なコンタクトとして表示されます。関連コマンドとして、`pjsip show contacts`（現在の登録状況とラウンドトリップタイム）、`pjsip show transports`、および1つのAORに対する`pjsip show aor <name>`があります。これらは「なぜextension Xに到達できないのか？」という日常的な疑問を解決するためのツールです。

### CDRとCEL

すべての通話は**Call Detail Record**（CDR）を残します。**Channel Event Logging**（CEL）は、より詳細なチャネルごとのイベントを追加します。CDRが有効であることと、どのバックエンドに保存されているかを確認します。

```
*CLI> cdr show status

Call Detail Record (CDR) settings
----------------------------------
  Logging:                    Enabled
  Mode:                       Simple
  Log calls by default:       Yes
  Log unanswered calls:       No
...
* Registered Backends
  -------------------
    (none)
```

ラボ環境では、最小限のラボ設定ではCDRストレージモジュールが読み込まれないため、登録済みバックエンドの下に`(none)`と表示されます。つまり、レコードは計算されますがどこにも書き込まれません。本番環境ではバックエンド（CSV、またはMySQL/PostgreSQLへの`cdr_odbc`/`cdr_adaptive_odbc`）を読み込むことで、それが課金や履歴のソースとなります。CELは**デフォルトで無効**です（`cel show status`を実行すると` reports `CEL Logging: Disabled` in the lab) and you enable it in `と表示されます）。イベントレベルの詳細が必要な場合にのみcel.confで有効にします。どちらも『Asterisk Call Detail Records』で詳しく解説されていますが、監視の観点では、CDR/CELは*過去の*記録であり、CLIは*現在の*状況を確認するためのものであるという点が重要です。

### AMIとARIイベント

プログラムによるリアルタイム監視を行うには、CLIをポーリングするのではなく、イベントのプッシュ配信が必要です。

- **AMI (Asterisk Manager Interface)** は、長年利用されているTCPベースのイベント/コマンドプロトコルです（`manager.conf`）。購読することで、通話が発生するたびに`Newchannel`、`Hangup`、`DialBegin`、`BridgeEnter`、`PeerStatus`といったイベントを受信できます。これはウォールボードや通話集計ツールのバックボーンとなります。ラボ環境ではAMIはデフォルトで無効です（`manager show settings`は`Manager (AMI): No`と報告します）。有効化およびロックダウンは`manager.conf`で行います。
- **ARI (Asterisk REST Interface)** は、最新のHTTP + WebSocketインターフェースです（`ari.conf`、組み込みのHTTPサーバーによって提供されます）。JSONイベントストリームと詳細な通話制御を提供するため、新しい統合には最適な選択肢です。

どちらも『Extending Asterisk with AMI and AGI』および『The Asterisk REST Interface (ARI)』で詳しく解説されています。デプロイメントに関する重要な警告として、**AMIとARIは強力であり、決してインターネットに公開してはなりません。** HTTPサーバーをlocalhostまたは管理ネットワークにバインドし、強力でユニークなシークレットを使用し、ポートをファイアウォールで保護してください。詳細は『Asterisk Security』を参照してください。

### メトリクス: PrometheusとGrafana

ダッシュボードやアラートのために、Asterisk 22にはPrometheusエクスポーターである**`res_prometheus.so`**（*extended*サポートレベルのモジュール）が同梱されており、PrometheusサーバーがスクレイピングするためのHTTP endpointでメトリクスを公開します。コアプロセスのメトリクスに加えて、チャネル、通話、endpoint、ブリッジ、PJSIPの送信登録をカバーするプラグイン可能なプロバイダーが提供されます。

```
# core process
asterisk_core_uptime_seconds
asterisk_core_last_reload_seconds
asterisk_core_scrape_time_ms
asterisk_core_properties
# channels
asterisk_channels_count
asterisk_channels_state
asterisk_channels_duration_seconds
# calls
asterisk_calls_count
asterisk_calls_sum
# endpoints
asterisk_endpoints_count
asterisk_endpoints_state
asterisk_endpoints_channels_count
# bridges
asterisk_bridges_count
asterisk_bridges_channels_count
# PJSIP outbound registrations
asterisk_pjsip_outbound_registration_status
```

ラボ環境のビルドにモジュールが存在するかは以下で確認できます。

```
*CLI> module show like prometheus
Module                         Description                     Use Count  Status      Support Level
res_prometheus.so              Asterisk Prometheus Module      0          Not Running  extended
```

ラボ環境では設定や読み込みを行っていないため`Not Running`と表示されます。これを有効化（`prometheus.conf`とHTTPサーバーの設定）することで、AsteriskがPrometheusのターゲットになります。Prometheusをスクレイプendpointに向け、GrafanaをPrometheusに向けることで、時系列ダッシュボード（同時通話数、登録数、ASR/ACDの傾向）やアラート（例：「アクティブな通話がゼロになった」「登録失敗が急増した」など）を実現できます。すでにPrometheus/Grafanaを運用しているチームにとって、CLI出力を解析するよりも、これがAsteriskを既存の可観測性に組み込む自然な方法です。

### 監視すべきSIPレスポンスコード

パイプラインの種類に関わらず、以下のSIP結果はトラブルの兆候であり、アラートを設定する価値があります。持続的な`401`/`407`のチャレンジ失敗や`403 Forbidden`は、ブルートフォース攻撃や設定ミスの嵐を示唆しています（『Asterisk Security』のFail2Banを参照してください）。`503 Service Unavailable`はサーバーやtrunkの過負荷や輻輳を指し、`408 Request Timeout`/`480 Temporarily Unavailable`の急増は通常、endpointが到達不能になったこと（NATタイムアウト、qualify失敗など）を意味します。

## 高可用性とスケーリング

Asteriskサーバーが1台だけの場合、それは単一障害点となり、通話容量にも限界があります。*稼働し続けること*と*規模を拡大すること*という2つの課題には、それぞれ異なる解決策があります。

### 浮動IPによるアクティブ/スタンバイ構成

Asteriskにおける古典的で実績のあるHA（高可用性）パターンは、**アクティブ/スタンバイ**構成です（アクティブ/アクティブ構成ではありません。Asteriskの通話状態をライブで共有することは困難なためです）。同一のサーバーを2台用意し、1台をアクティブ、もう1台をスタンバイとして、**keepalived** (VRRP) や **Pacemaker/Corosync** といったクラスターマネージャーで管理される**浮動（仮想）IP**を共有します。電話機やtrunkは、個別のホストではなく、この浮動IPに対して登録を行います。アクティブノードのヘルスチェックが失敗すると、浮動IPはスタンバイノードに移動し、スタンバイノードが処理を引き継ぎます。

正直な注意点として、IPフェイルオーバーが発生すると**進行中の通話は切断されます**。Asteriskはノード間でライブのchannel状態を複製しないため、通話中のユーザーはかけ直す必要があります。登録情報は、qualify/registrationサイクルの中で再確立されます。フェイルオーバーによって得られる利点は、手動介入なしで数秒以内に*サービス*が復旧することであり、ほとんどのPBXにとってこれこそが目的となります。スタンバイノードが確実に引き継ぎを行えるようにするには、両方のノードで同じ設定（gitで管理された`/etc/asterisk`を同一にデプロイしたもの）と、同じ*状態*が必要です。これについては次の項目で説明します。

### PJSIP Realtimeによる状態の外部化

アクティブ/スタンバイ構成は、スタンバイノードがアクティブノードと同じendpointや登録情報を認識している場合にのみ機能します。これを実現する方法は、**1台のボックス内のフラットファイルに状態を保持するのをやめ**、両方のノードが読み取れる共有データベースに移行することです。**PJSIP Realtime**（データベースをバックエンドとするSorcery）はまさにこれを行います。endpoint、AOR、auth、そして重要な点として**登録情報**（`ps_contacts`テーブル）が、`pjsip.conf`やローカルメモリではなくMySQL/PostgreSQL内に存在するようにします。両方のAsteriskノードが同じデータベースを参照するため、一方のノードを通じて登録された電話機は、もう一方のノードからも認識されます。これについては『Asterisk Real-Time』（PJSIP Realtime / Sorceryのセクション）で解説されていますが、ここでの展開のポイントは、**状態の外部化はHAと水平スケーリングの両方にとっての前提条件である**ということです。これがないと、各ノードは孤立した島となってしまいます。

この論理を他の状態にも適用してください。CDR/CELは共有SQLストアへ、voicemailは共有/複製ストレージ（または`ODBC_STORAGE`）へ、そして依存しているastdbキーはデータベースへと移行します。状態が外部化されれば、Asteriskノードは交換可能なフロントエンドに近い存在となります。

### 前段のSIPプロキシ（OpenSIPS）

1台のサーバーの容量を*超えて*スケーリングするには、Asteriskメディアサーバーのプール（集団）の前に**SIPプロキシ/ロードバランサー**を配置します。**OpenSIPS**は、目的特化型の非常に高スループットなSIPプロキシです（メディアには触れずに、数十万件の登録を処理し、シグナリングをルーティングします）。このプロキシは世界に対して単一のSIPアドレスを提示し、登録/位置情報サービスを維持し、Asteriskバックエンド全体に通話を分散させます。この分離、つまり登録とルーティングを行う軽量なプロキシ層と、実際の通話処理（IVR、キュー、会議、トランスコーディング）を行う水平スケーリング可能なAsterisk層という構成こそが、大規模なデプロイメントが1台のボックスを超えて成長する方法です。（SipPulseプラットフォーム自体も、まさにこの理由からメディア/アプリケーションサーバーの前にOpenSIPSを使用しています。）

### メディアのスケーリング

プロキシは*シグナリング*を安価に分散させますが、**メディアは高コストなリソースです**。RTPリレー、特にcodec間のトランスコーディング（例：Opus ↔ G.711）や大規模な会議の実行はCPU負荷が高く、サーバーの限界を決定づける要因となります。戦略は以下の通りです。

- 可能な限り**トランスコーディングを回避**してください。エンドツーエンドで共通のcodecをネゴシエーションし、Asteriskがトランスコーディングではなくネイティブでブリッジ（パススルー）するようにします。これがメディア容量を増やすための最大の鍵です。
- プロキシの背後にAsteriskノードを追加することで、**メディアを水平方向にスケーリング**します。各ノードが同時通話の一部を分担します。
- **ブラウザのメディアをオフロード**し、専用のWebRTCゲートウェイ（例：Janus）を使用することで、PBXがすべてのブラウザのDTLS-SRTPストリームを終端およびリレーしないようにします。これについては『WebRTC with Asterisk』を参照してください。このAsteriskとゲートウェイの分離について詳しく解説されています。

容量の見積もりは、登録ユーザー数ではなく、**同時通話数とトランスコーディング負荷**に基づいて行ってください。ほとんどアイドル状態の10,000台の登録済み電話機は、200の同時トランスコーディング会議よりもはるかに低コストです。

## クラウドホスティング

AsteriskをクラウドVM（AWS、GCP、Azure、VPSなど）で実行することは一般的であり、十分に機能しますが、クラウドネットワークは**デフォルトでNATおよびファイアウォールが適用されている**ため、SIPと競合します。以下に、デプロイメント固有の懸念事項を挙げます。

### NATとSDP

クラウドVMには、NIC上の**プライベート**IPと、プロバイダーがNAT変換を行う別の**パブリック**IPが割り当てられることがほとんどです。AsteriskがSDP内でプライベートIPを通知すると、リモートの電話機はRTPをブラックホールに送信してしまい、典型的な「片通話」や「音声なし」という症状が発生します。トランスポート上でPJSIPにそのパブリックIDを通知してください。

```
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=203.0.113.10      ; the VM's PUBLIC IP
external_signaling_address=203.0.113.10
local_net=10.0.0.0/8                     ; your private/VPC range(s)
```

`external_*`はAsteriskがパブリックなピアに対して通知するアドレスを書き換えるように指示し、一方で`local_net`はどのピアがローカルであるか（書き換えるべきでは*ない*か）を指定します。これは前述のブリッジされたDockerネットワークで議論したNAT処理と同じであり、クラウドVMは実質的にNATの背後に存在することになります。

### ファイアウォールとRTP範囲

クラウドVMには通常、**プロバイダーの**セキュリティグループ/ネットワークACLと、**ホストの**iptablesという2つのファイアウォールが適用されます。両方で同じポートを開放する必要があり、ポリシーはセキュリティの章で説明したものに従います。第1版から引き継がれたルールセット（`docs/legacy-labs/configs/Lab7/rules.v4`）はその構成を捉えており、SIPとRTP範囲を許可し、確立済み/関連する通信を許可し、それ以外を破棄します。

```
-A INPUT -p udp -m udp --dport 5060 -j ACCEPT
-A INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -j DROP
```

セキュリティの章で述べられている、ここで重要な2つの修正点があります。SIP/TLSを実行する場合は**5061番ポートをTCPで**（UDPではなく）開放すること。そして、ファイアウォール内のRTP UDP範囲が`rtp.conf`内の`rtpstart`/`rtpend`と完全に一致していることを確認してください。これはコンテナ上で公開する範囲と同じである必要があります。ここでiptables/Fail2Banの構築を重複して行う必要はありません。*Asterisk Security*の**ファイアウォール、Fail2Ban、およびTLS/SRTPのセクションに従ってください**（Fail2Banは、ラボ環境ですでに`logger.conf`で有効にしている`security`ロガーチャネルを監視します）。そして、そのポリシーをホストのファイアウォールとクラウドのセキュリティグループの*両方*に適用してください。

### レイテンシ、リージョン、およびSBC

- **ユーザーに近いリージョンを選択してください。** 音声はレイテンシに敏感であり、口から耳までの片道レイテンシが約150 msを超えると顕著に感じられます。電話機やtrunkの大部分が位置する場所に最も近いリージョンでVMをホストしてください。大陸をまたぐメディア通信は、明らかに音質が低下します。
- **インターネットに面したデプロイメントには、前面にSBCを配置してください。** **Session Border Controller**はエッジでSIP/RTPを終端し、トポロジーを隠蔽し、NATを正規化し、Asteriskに到達する前にDoS攻撃やスキャン通信を吸収します。セキュリティの章における中心的な推奨事項である「*生のAsteriskをインターネットに直接公開しないこと*」は、クラウド環境ではさらに重要です。クラウドでは、VMのパブリックIPは起動から数分以内にスキャンされるためです。SBC（または最低限、OpenSIPSとFail2Banを組み合わせた堅牢なSIPプロキシ）が標準的なエッジとなります。

## 概要

デプロイメントとは、動作するdialplanを信頼性の高いサービスへと昇華させる工程です。VM上でAsteriskを運用する場合、**non-root**ユーザーとして**systemd**配下で実行し、ユニットの`Restart=`によってプロセスの生存を維持させます（safe_asteriskは現在では非推奨です）。また、設定変更には`systemctl restart`ではなく`core reload`を使用してください。本書のラボで行っているようにDockerで**コンテナ化**を行うと、git管理された`/etc/asterisk`から**bind-mount**された設定を持つ、不変かつ固定されたイメージを利用できます。ただし、メディア通信には注意が必要であり、**host networking**を使用するか、`rtp.conf`と**完全に一致する**RTPポート範囲を公開する必要があります。また、再デプロイ後も状態を保持できるよう、spool/voicemail/astdbには**persistent volumes**をマウントしてください。設定はコードとして扱い、設定ファイルには含まれない状態（voicemail、録音データ、`astdb.sqlite3`、CDR/CELなど）は**バックアップ**を取るようにします。システムを**監視**する際は、CLI（`core show channels`、`pjsip show endpoints`）によるライブビュー、**CDR/CEL**による履歴、**AMI/ARI**によるプログラム的なイベント、そしてGrafanaでダッシュボードやアラートを作成するための**`res_prometheus`**エクスポートという4つのレベルで行います。なお、AMI/ARIはパブリックインターネットに公開しないでください。**可用性を維持**するには、**floating IP**を使用したactive/standby構成を運用します（フェイルオーバー時に通話が切断されることは許容する必要があります）。**拡張**を行う場合は、**PJSIP Realtime**を使用して状態を外部化し、**OpenSIPS**をメディアサーバー群のフロントに配置します。また、**サーバーの限界を決めるのは登録数ではなくメディア処理である**ため、トランスコーディングを最小限に抑えてください。最後に、**クラウド**環境では、VMをNATの背後にあるものとして扱い（`external_media_address`、`local_net`）、ホスト側とプロバイダーのセキュリティグループの両方でセキュリティの章に従ってファイアウォールを開放します。低遅延のリージョンを選択し、生のAsteriskを直接公開することは避け、エッジには必ず**SBC**を配置してください。

## クイズ

1. systemd ホストにおいて、クラッシュした Asterisk を再起動するというかつての `safe_asterisk` ラッパーの役割を担うものは何ですか？
   - A. cron ジョブ
   - B. ユニットファイルの `Restart=` ディレクティブ
   - C. `systemctl enable`
   - D. astdb
2. 実行中の Asterisk に対して、**通話を切断することなく**設定変更を適用するには、どうすべきですか？
   - A. `systemctl restart asterisk`
   - B. サーバーを再起動する
   - C. `asterisk -rx 'core reload'`
   - D. コンテナイメージを再ビルドする
3. コンテナ化された（ブリッジネットワーク接続の） Asterisk で通話は接続されるが、**音声が聞こえない**場合、最も可能性の高い原因は何ですか？
   - A. dialplan が間違っている
   - B. 公開された RTP UDP ポート範囲が `rtp.conf` 内の `rtpstart`/`rtpend` と一致していない
   - C. CDR が無効になっている
   - D. CLI に到達できない
4. コンテナを再デプロイしても状態が失われないように、**永続ボリューム**としてマウントしなければならないディレクトリはどれですか？（該当するものすべてを選択してください）
   - A. `/var/spool/asterisk` (voicemail, recordings)
   - B. `/var/lib/asterisk` (astdb)
   - C. `/etc/asterisk` (ホストからバインドマウント済み)
   - D. `/usr/sbin`
5. アクティブな通話の現在の数を表示する CLI コマンドはどれですか？
   - A. `cdr show status`
   - B. `core show channels`
   - C. `pjsip show transports`
   - D. `module show like prometheus`
6. Asterisk 22 において、通話/チャネルのメトリクスを Prometheus/Grafana スタックに公開するためのサポートされている方法はどれですか？
   - A. `full` ログファイルを解析する
   - B. `res_prometheus.so` モジュール
   - C. AGI スクリプト
   - D. そのような方法はない
7. HA フェイルオーバーと複数の Asterisk ノード間での水平スケーリングの両方に必要な前提条件は何ですか？
   - A. root 権限で実行すること
   - B. 状態を外部化すること（例：共有データベースでの PJSIP Realtime 登録）
   - C. CDR を無効にすること
   - D. ブリッジネットワークを使用すること
8. 1台の Asterisk サーバーが処理できる同時通話数を最も直接的に制限するリソースは何ですか？
   - A. 登録済みユーザー数
   - B. メディア処理、特にトランスコーディング
   - C. `/etc/asterisk` のサイズ
   - D. CDR バックエンド
9. クラウド VM 上で、リモートの音声が機能するように Asterisk にパブリックアドレスを通知させる `pjsip.conf` トランスポート設定はどれですか？（該当するものすべてを選択してください）
   - A. `external_media_address`
   - B. `external_signaling_address`
   - C. `local_net`
   - D. `qualify_frequency`
10. インターネットに面したクラウドデプロイメントにおいて、セキュリティの章における中心的なルールは何ですか？
    - A. 常に2つの NIC を使用する
    - B. 生の Asterisk をインターネットに直接公開しないこと。エッジに SBC（または強化されたプロキシ + Fail2Ban）を配置する
    - C. UDP のみを使用する
    - D. TLS を無効にする

**回答:** 1 — B · 2 — C · 3 — B · 4 — A, B · 5 — B · 6 — B · 7 — B · 8 — B · 9 — A, B, C · 10 — B
