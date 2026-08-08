# Asteriskのセキュリティ

当初より、Asteriskにおけるセキュリティの問題は極めて重要です。CERT.BRによると、SIP（Session Initiation Protocol）はインターネット上で最も攻撃を受けているプロトコルです。ハニーポットを運用している人であれば誰でもそれを確認できるでしょう。インターネットにおける収益分配詐欺（Revenue Share Fraud）の問題は非常に深刻であり、数十万ドルを超える損失につながる可能性があります。適切なセキュリティ対策を講じずに、インターネットに接続されたAsteriskサーバーをインストールすることは決して避けるべきです。本章では、受ける可能性のある主な攻撃の種類を特定する方法と、適切なセキュリティポリシーを用いてそれらを防ぐ方法を学びます。最後に、提案されたセキュリティポリシーを実装する方法を学びます。

本章は **Asterisk 22 LTS** を対象としており、PJSIP（`res_pjsip` / `chan_pjsip`）が唯一のSIPチャネルとなっています。（古い `chan_sip` ドライバは Asterisk 21 で削除されました。古いシステムから移行する場合は *Legacy Channels* の章を参照してください。）セキュリティに関連する重要な変更点として、認証失敗が Asterisk の **security event framework** および専用の `security` ロガーチャネルを通じて出力されるようになりました。これにより、Fail2Banの設定方法が変更されています（本章の後半で解説します）。

## Objectives

この章を読み終えることで、以下のことができるようになります。

- Asteriskサーバーに対して頻繁に行われる主な攻撃の種類を特定する
- 効果的なセキュリティポリシーを定義する
- セキュリティポリシーを実装する
- Asteriskのために IPTABLES をインストールおよび設定する
- Asteriskのために Fail2Ban をインストールおよび設定する
- 暗号化のために TLS および SRTP をインストールおよび設定する

## IP電話に対する主な攻撃

IP電話に対する主な攻撃は、DOS/DDOS、サービス窃取/Toll Fraud（通話料金詐欺）、および盗聴に分類できます。名称が紛らわしい場合があり、情報源によって同じ攻撃を指していても呼び方が異なることがあります。サービス窃取、Toll Fraud、インターネット収益分配詐欺（Internet Revenue Share Fraud）、電話詐欺などは、ハッカーがあなたのPBXを悪用してプレミアムレート番号へトラフィックを流し、プロバイダーからリベートを得る行為を指す異なる名称です。

### DDoS/DOS

Denial of Service（サービス拒否）およびDistributed Denial of Service（分散型サービス拒否）は、あらゆるITインフラに対する一般的な攻撃です。SIPやその他のVoice over IPプロトコルにおいても状況は変わりません。Distributed denial of serviceは通常ボットネットによって実行されますが、DOSは単一のコンピュータによって行われます。2011年2月、Salityボットネットは、脆弱なSIPサーバーを探し出すためにIPv4アドレス空間全体を対象とした隠密かつ組織的なスキャンを実行しました。UCSD Network Telescopeで観測した研究者は、約300万の異なるソースIPがUDPポート 5060を調査していたと結論付けており、そのほとんどがToll Fraudを目的としたSIPアカウントへのブルートフォース攻撃であったと推測されています。[^sality]

[^sality]: A. Dainotti et al., "Analysis of a '/0' Stealth Scan from a Botnet," *IEEE/ACM Transactions on Networking*, 2015 (DOI 10.1109/TNET.2013.2297678).

![数千件のSIP登録試行をサーバーに向けるピア・ツー・ピアのボットネット](../images/19-security-fig01.png)

DOSは通常、ファジングやフラッディングといった手法を通じて行われます。フラッディングにはSIP、IAX、RTPなどのプロトコルが使用されます。これらはサービスを完全に停止させるか、音声品質を低下させます。ポートがインターネットに公開されている場合、これらの攻撃を緩和することは非常に困難です。以下に、攻撃者が使用するツールの一部を挙げます。

**ファジング:**

- **PROTOS Test Suite (c07-sip)** — オウル大学OUSPGによるツール。数千の不正なパケットを送信し、ソフトウェアを停止させるバッファオーバーフローなどの誤作動を引き起こします。
- **Voiper** — すべてのSIP属性を網羅する20万以上のテストを生成し、サーバーがメッセージを効果的に処理できるかを検証します。<http://voiper.sourceforge.net/>

**フラッディング:**

- **INVITE Flooder** — SIP INVITEリクエストでサーバーをフラッド攻撃します。<http://www.hackingvoip.com/tools/inviteflood.tar.gz>
- **IAX Flooder** — IAX2トラフィックでサーバーをフラッド攻撃します。<http://www.hackingvoip.com/tools/iaxflood.tar.gz>
- **RTP Flooder** — RTPパケットでアクティブなメディアセッションをフラッド攻撃し、音声品質を低下させます。<http://www.hackingvoip.com/tools/rtpflood.tar.gz>

### DoS/DDoSに対する緩和策

私からの推奨事項は以下の通りです。

1. 適切な保護（SBC）を伴う必要性がない限り、Asteriskサーバーをインターネットに公開しないでください。
2. 内部ネットワークでは、特にユーザー数が多い大学やカレッジなどの環境では、音声用にVirtual LANを使用してください。
3. 外部アクセスにはVPNまたはTLSを使用してください。

### インターネット収益分配詐欺（Internet Revenue Share Fraud）

この詐欺は理解するのが少し厄介です。鍵となるのは、International premium rate number (IPRN) という概念を理解することです。

![インターネット収益分配詐欺の3つのステップ：プレミアムレート番号を購入し、脆弱なVoIPデバイスを見つけてその番号へ発信し、報酬を受け取る](../images/19-security-fig02.png)

IPRNとは、特定のインターネット電話会社で無料で割り当てることができる番号です。Internet Premium Rate Number Providersを検索すれば、多くのプロバイダーが見つかります。この種の事業者では、例えばIridiumのような衛星ネットワーク上の番号を割り当てることができ、発信者には1分あたり数十ドルのコストがかかります。IPRNプロバイダーは、着信した通話1分ごとに収益の一定割合（収入の10〜20%）をあなたに還元します。

![国別の支払いレートとテスト番号を示すIPRNプロバイダーの価格表](../images/19-security-fig03.png)

割り当てフェーズの後、ハッカーは割り当てられたIPRNに発信可能な、公開されているAsteriskサーバーを探します。ハッカーに制御された被害者のPBXは、IPRN番号に対して数百回の通話を行い、ハッカーには多額の報酬を、被害者には莫大な電話料金を発生させます。多くの場合、週末だけで数十万ドルを超える請求が発生することもあります。

ハッカーがPBXを攻撃するために使用する主なツール：

1. **SIPVicious**: http://code.google.com/p/sipvicious/。Sipviciousは使いやすいセキュリティツールセットです。主な目的は、脆弱なPBXを特定し、ブルートフォース攻撃を使用してSIPパスワードをクラックすることです。最も使用されるツールはsvcrackです。このツールは1秒間に数千のパスワードをテストできます。
2. **電話機の脆弱性**。ハッカーが攻撃ベクトルとして頻繁に使用するもう一つのポイントは、電話機そのものです。Asteriskをインストールする多くの人が、電話機のWebインターフェースのデフォルトパスワードを変更していません。これらの電話機がインターネットに公開されると、ハッカーはデフォルトのインターフェースパスワードを使用して設定をダウンロードし、多くの場合、そこに記載されているSIPのシークレットパスワードを入手できます。

#### TFTPTheft:

TFTPを使用して電話機の自動プロビジョニングを行っている場合、おそらくこの種の攻撃に対して無防備です。TFTPは、File Transfer Protocolの単純で安全ではない形式です。

![TFTPサーバーから推測可能な.cfgファイルをダウンロードし、設定ファイルから平文の認証情報を収集する攻撃者](../images/19-security-fig04.png)

設定ファイルの名前は、MACアドレスの後に.cfgを付けることで簡単に推測できます（例: 001A2B3C4D5E.cfg）。賢いハッカーであれば、すべてのMACアドレスを順番に試すユーティリティを簡単に作成するか、単にそれを行うためのツールをダウンロードするでしょう。設定ファイルは通常暗号化されておらず、内部にSIPのシークレットパスワードが含まれています。

#### ブルートフォース攻撃およびTFTPTheftの緩和策

これらの攻撃を緩和するために、以下の解決策を適用できます。ブルートフォース攻撃：ブルートフォース攻撃を緩和する最善の解決策は、連続した不正な試行を防ぐことです。ほぼすべてのAsteriskインストーラーは、この目的のためにfail2banユーティリティを使用しています。fail2banは、パスワードやユーザー名の間違いによる複数回の試行を検出すると、攻撃者のIPを一定時間ブロックします。ブルートフォースに対する2つ目の対策は、12文字以上で少なくとも1つの特殊文字を含む強力なパスワードを使用することです。TFTPTheft：TFTPTheftを防ぐには、プロビジョニングで名前とパスワードを伴うhttpsを使用するように設定してください。ファイルは暗号化されて送信され、名前とパスワードによって攻撃者がファイルをダウンロードしようとするのを防ぐことができます。

### 盗聴

これらの攻撃は多くの場合単に検出されないため、あまり目にすることはありません。IP環境において盗聴を検出することは非常に困難です。UCsniffのような無料で利用可能なユーティリティは、ほとんどのネットワークでVoIP通話を盗聴することが可能です。主な手法は、ARPスプーフィングを使用してトラフィックをUCsniffを実行しているコンピュータ経由で強制的に流し、通話を記録することです。

#### 盗聴に対する緩和策

VoIPトラフィックを暗号化することで盗聴を防ぐことができます。もう一つの方法は、ネットワーク上での中間者攻撃（MITM）を防ぐことです。ARPインスペクションは、レイヤー2ネットワークにおけるMITMを防ぐのに非常に効果的です。実装方法については、ネットワークの技術サポートに確認してください。本書の後半では、TLSとSRTPに基づいた暗号化のインストール方法を学びます。また、ARPWatchを使用して、誰かがネットワークを攻撃するためにARPプロトコルを悪用していないかを確認することもできます。

## Asteriskのセキュリティポリシー

セキュリティを実装する最善の方法は、セキュリティポリシーを作成することです。このトレーニングでは、ほとんどのAsteriskインストールに適したセキュリティポリシーを提案します。これをベースラインとして使用し、必要に応じて変更してください。推奨されるセキュリティポリシーは以下の通りです。

1. 不要なUDP/TCPポートを開放しない
2. インターネット上に管理インターフェース（SSH/HTTPS）へのアクセスを公開しない
3. SSHやHTTP/HTTPSにアクセスする場合は、IPTABLESファイアウォールで明示的な例外を設定する
4. 12文字以上で、少なくとも1つの特殊文字を含む強力なパスワードを使用する
5. Fail2banを使用して、認証に10回以上失敗したIPアドレスを禁止する
6. 国際電話の発信にはパスワード確認を必須とする
7. SIPポートへのアクセスを、既知のIPアドレス範囲に制限する

PBXへの外部アクセスが必要な場合は、2つの可能性があります。SBC（Session Border Controller）を使用してサーバーをDOS/DDOS攻撃から保護するか、外部アクセスが必要なときは常にVPNを使用してください。SBCやVPNなしでポート5060をインターネットに開放したままにすると、DOS/DDOS攻撃に対して無防備になります。リスクは自己責任となります。

### PJSIP時代の強化（Asterisk 22）

ファイアウォールやFail2Banに加え、Asterisk 22のPJSIPスタックには、セキュリティポリシーの一部として組み込むべき設定レベルの制御がいくつか用意されています。これらは上記のネットワーク制御を補完するものであり、置き換えるものではありません。

- **エンドポイントごとの認証。** すべてのエンドポイントは、強力で一意な`password`（`auth_type=digest`）を持つ専用の`type=auth`セクションを参照する必要があります。エンドポイント間で認証情報を再利用しないでください。
- **匿名呼び出しの処理は組み込み済み。** PJSIPは、認証失敗時にユーザー名が存在するかどうかを明かしません。匿名呼び出しを完全に受け入れるには、明示的に`anonymous`という名前のエンドポイントを作成し、`type=identify`セクション（送信元IPで一致）を使用して既知のピアをエンドポイントにマッピングする必要があります。匿名呼び出しを許可したくない場合は、単に`anonymous`エンドポイントを作成しなければ、一致しないリクエストはチャレンジまたは拒否されます。
- **ACL。** `/etc/asterisk/acl.conf`という名前のACLを使用してエンドポイントへの到達範囲を制限し、エンドポイントから`acl=`（シグナリング/送信元ACL）および`contact_acl=`（連絡先/登録アドレスを制限）で参照します。エンドポイントに対して直接permit/denyを設定することも可能です。
- **`qualify`。** AORに`qualify_frequency`（および`qualify_timeout`）を設定することで、Asteriskが登録済み連絡先の到達可能性を能動的に監視し、無効なものを削除するようにします。
- **PJSIPトランスポートの強化 / DoS保護。** `type=transport`にはトランスポートごとのクライアント上限設定がないため、接続フラッド攻撃からの保護はPJSIPオプションではなくファイアウォール（本章のiptables/Fail2Banルール）によって行われます。トランスポートが提供するのは、無効または半開きの接続を回収するためのTCPキープアライブ調整（`tcp_keepalive_enable`、`tcp_keepalive_idle_time`、`tcp_keepalive_interval_time`、`tcp_keepalive_probe_count`）と、適切なNAT処理のための`local_net`/`external_*`設定です。これらをファイアウォールルールと組み合わせることで、接続フラッド攻撃を緩和します。
- **メディア用のTLS + SRTP。** エンドポイント上でTLSトランスポートによるシグナリングの暗号化と、`media_encryption=sdes`（WebRTCの場合は`dtls`）によるメディアの暗号化を行います。これについては本章の後半で説明します。
- **AMI/ARIのアクセス制御。** Asterisk Manager Interface（`manager.conf`）およびARI（`ari.conf` / `http.conf`）へのアクセスをlocalhostまたは信頼できる管理ネットワークに制限し、強力で一意なシークレットを使用し、HTTPサーバーをプライベートインターフェースにバインドしてください。これらをインターネットに公開してはいけません。

上記のオプション名はすべてAsterisk 22.10で確認済みです。`type=transport`セクションは`tcp_keepalive_enable`、`tcp_keepalive_idle_time`、`tcp_keepalive_interval_time`、`tcp_keepalive_probe_count`、`tos`、`cos`、`local_net`および`external_*`ファミリーを公開していますが、`max_clients`オプションは**ありません**。接続フラッド保護はトランスポートではなくファイアウォールによって行われます。`acl`および`contact_acl`エンドポイントオプションは`acl.conf`からセクション名を取得し、認証されていないピアの送信元IP一致は`type=identify`セクション（`match=`）で行われます。

### 不要なポートの削除

Asteriskのすべてのプロトコルに関連する脆弱性をすべて発見する代わりに、不要なポートを削除して問題を単純化しましょう。Asteriskサーバーによって開かれているすべてのポートをリストするには、以下を使用します。

```
netstat -pantu |grep asterisk
```

コマンドの出力は以下の通りです。

![4569 (IAX) や 2727 (MGCP) を含む、Asteriskによってバインドされた多数のポートを示すnetstatの出力](../images/19-security-fig05.png)

出力を見ると、多くのポートが開いていることがわかります。これらは必要でしょうか？必ずしもそうではありません。2727はMGCPプロトコル（chan_mgcp）、4569はIAX（chan_iax2）です。これらのプロトコルを使用していない場合は、設定ファイルmodules.confでモジュールを削除するだけで済みます。

Asteriskが大きな番号のUDPポートをバインドしていることに気づくかもしれません。これは`res_pjsip`のリゾルバーがアウトバウンドのDNSクエリを行うため（送信元ポートはクライアントのDNSルックアップと同様にエフェメラルです）であり、インバウンドのリスナーによるものではありません。ファイアウォールでは、これに対する**確立済み/関連（established/related）**の戻りトラフィックのみを許可すれば十分です（以下に示すiptablesの`conntrack ESTABLISHED,RELATED`ルールで既にカバーされています）。PJSIPのDNSのためだけに、広範囲のインバウンド高UDPポートを開放する必要は**ありません**。

不要なポートを削除するには、使用しないモジュールを無効にします。modules.confファイルを編集し、使用していないチャネルやプロトコルの`noload`行を追加します。`res_pjsip`、`res_pjproject`、または`chan_pjsip`をnoloadしないでください。これらはAsterisk 22のSIPに必要です。

```
; res_pjsip / res_pjproject / chan_pjsip are REQUIRED in Asterisk 22 - keep them loaded
noload => chan_iax2.so
noload => chan_unistim.so
```

（Asterisk 22では、`chan_mgcp`や`chan_skinny`をnoloadする必要はもうありません。これらのドライバーはAsterisk 21で*削除*されており、標準の22ビルドには含まれていません。）上記の手順により、PJSIPのみを残してすべての不要なチャネルを削除しました。使用したいプロトコルモジュールは自由に選択できますが、使用しないものは削除してください。結果は以下のスクリーンショットの通りです。PJSIPトランスポートによってバインドされたSIPポート（5060）のみがインバウンドとして公開されています。

![未使用のモジュールを無効にした後のnetstat出力：AsteriskによってバインドされているのはUDPポート5060のみ](../images/19-security-fig06.png)

### IPTABLESによるセキュリティポリシーの実装

IPTABLESまたはnetfilterは、ほとんどのLinuxディストリビューションに存在する標準的なファイアウォールです。このラボでは、iptablesとfail2banを設定します。目的は、Asteriskに推奨されるセキュリティポリシーを実装し、すべての不要なトラフィックをブロックすることです。以下の手順に従ってください。

1. すべての外部トラフィックをブロックする
2. 内部ネットワークまたは単一ホストからのSSHトラフィックを許可する
3. UDPおよびTCPのポート5060でのSIPトラフィックを許可する
4. UDPメディアポート範囲でのRTPトラフィックを許可する。組み込みのデフォルト値は単一ではありません。Asterisk自身の`rtp.conf`は何も設定されていない場合5000–31000のポートにフォールバックしますが、同梱の`rtp.conf.sample`は`rtpstart=10000` / `rtpend=20000`を設定しているため、ここではその例の範囲を使用します。ファイアウォールルールを、実際に`rtp.conf`で設定した`rtpstart`/`rtpend`に合わせてください。

サーバーへのコンソールアクセス権があることを確認してください。システムから締め出されないように注意が必要です。慎重に行ってください。

1. パッケージnet-persistentをインストールします。

   ```
   sudo apt-get install iptables-persistent
   ```

2. ループバックからのすべてのトラフィックを許可します。

   ```
   sudo iptables -I INPUT -i lo -j ACCEPT
   sudo iptables -I OUTPUT -o lo -j ACCEPT
   ```

3. 確立された接続を許可します。

   ```
   sudo iptables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
   ```

4. ネットワーク192.168.0.0からのSSH/HTTPSトラフィックを許可します。

   ```
   sudo iptables -I INPUT -p tcp -s 192.168.0.0/16 --dport 22 -m conntrack --ctstate
   NEW,ESTABLISHED -j ACCEPT
   sudo iptables -I INPUT -p tcp -s 192.168.0.0/16 --dport 443 -m conntrack --ctstate
   NEW,ESTABLISHED -j ACCEPT
   ```

5. Asteriskルールを挿入します。

   ```
   sudo iptables -I INPUT -p udp -m udp --dport 5060 -j ACCEPT
   sudo iptables -I INPUT -p tcp -m tcp --dport 5060 -j ACCEPT
   sudo iptables -I INPUT -p tcp -m tcp --dport 5061 -j ACCEPT
   sudo iptables -I INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT
   ```

   ポート5061（TLS経由のSIP）はUDPではなく**TCP**であることに注意してください。上記のルールは5060をUDPとTCPの両方で、5061をTCPで開放します。TLSのみを実行する場合は、通常の5060ルールを完全に削除できます。PJSIPトランスポートが実際にバインドしているポートのみを開放してください。

   `-I`はPREPEND（先頭への挿入）を意味します。

6. 最後のルールはドロップ（破棄）である必要があります。

   ```
   sudo iptables -A INPUT -j DROP
   ```

   `-A`はAPPEND（末尾への追加）を意味します。注意：新しいルールを維持する際は、DROPの前にルールを追加する必要があります。新しいルールにはPREPENDを使用してください`-I`。

7. ルールを保存し、iptablesを再起動します。

   ```
   sudo iptables-save >/etc/iptables/rules.v4
   sudo /etc/init.d/netfilter-persistent restart
   ```

### Fail2Banを使用して複数回の認証失敗をブロックする

Fail2BanはAsteriskにとってほぼ標準的なツールです。ほとんどのユーザーがセキュリティを強化するために実装しています。このユーティリティはAsteriskのログをスキャンし、認証に失敗した攻撃者のIPアドレスを禁止します。以下にFail2Banのインストール手順を示します。

Asterisk 22では、PJSIPは認証失敗やその他のセキュリティイベントを、専用の**`security`ロガーチャネル**に書き込まれるAsteriskの**セキュリティイベントフレームワーク**を通じて報告します。Fail2Banを機能させるには、以下を行う必要があります。

1. `/etc/asterisk/logger.conf`でセキュリティチャネルを有効にします。構文は`<filename> => <levels>`であるため、セキュリティレベルを`security`という名前のファイルに送信するには以下のように記述します。

```
[logfiles]
security => security
```

次に、CLIから`logger reload`を実行します。これにより、セキュリティイベントごとに1行ずつ、以下の形式で`/var/log/asterisk/security`が生成されます。

```
[2026-01-15 10:23:45] SECURITY[1234] res_security_log.c: SecurityEvent="InvalidPassword",...,RemoteAddress="IPV4/UDP/203.0.113.7/5060",...
```

Fail2Banが監視するイベントは`InvalidPassword`、`ChallengeResponseFailed`、`InvalidAccountID`、および`FailedACL`であり、それぞれが攻撃者を特定する`RemoteAddress="IPV4/UDP/<ip>/<port>"`フィールドを持っています。（アドレスは単なるIPではなく`IPV4/UDP/.../...`のようにラップされていることに注意してください。フィルターは、その文字列内からホストを抽出する必要があります。）

2. `asterisk`ジェイルをそのファイル（`logpath = /var/log/asterisk/security`）に向け、このセキュリティイベント形式を解析するフィルターを使用します。

最新のFail2Banには`asterisk`フィルターが同梱されており、その`failregex`は既に上記のイベントと一致し、`RemoteAddress`フィールドから`<HOST>`を抽出します。例：

```
failregex = ^SecurityEvent="(?:FailedACL|InvalidAccountID|ChallengeResponseFailed|InvalidPassword)".*,RemoteAddress="IPV[46]/[^/"]+/<HOST>/\d+"
```

PBXディストリビューション（FreePBX/Sangoma）には同等のフィルターが同梱されています。正確なイベント文字列はバージョンに依存するため、自作するよりもパッケージ化されたフィルターを優先してください。注意すべき点として、修正済みの勧告（GHSA-5743-x3p5-3rg7）で示されたように、細工されたPJSIPトラフィックが偽のログ行を注入する可能性があるため、AsteriskとFail2Banフィルターの両方を最新の状態に保ってください。

以下にFail2Banのインストール手順を示します。

1. Linuxにfail2banをインストールします。

   ```
   sudo apt-get install fail2ban
   ```

2. AsteriskおよびSSH用のfail2banを有効にします。

   ```
   sudo vi /etc/fail2ban/jails.d/defaults-debian.conf
   ```

   sshおよびasterisk用のfail2banを有効にするために、以下の行を追加します。

   ```
   [sshd]
   enabled = true
   [asterisk]
   enabled=true
   ```

3. fail2banを再起動します。

   ```
   /etc/init.d/fail2ban restart
   ```

4. 検証します。ソフトフォンからシークレットを変更し、10回再登録を試みます。`iptables -L`を使用して、ソフトフォンのアドレスがブロックされたアドレスとして含まれているか確認します。
5. 禁止リストからアドレスを削除します（アドレスが192.168.0.5であると仮定）。

   ```
   sudo fail2ban-client set asterisk unbanip 192.168.0.5
   ```

注意：コマンド内の192.168.0.5は、お使いの電話のIPアドレスに置き換えてください。

### TLSとSRTPの実装

このセクションを2つに分けます。前半ではシグナリングを暗号化するためのTLSを、後半ではメディアを暗号化するためのSRTPを扱います。ここでの目的は、これらのリソースのためにAsteriskを設定することです。

#### TLS

TLS（Transport Layer Security）は、SIPシグナリングを保護するために定義された暗号化メカニズムです。以下の表は、TLSがどの攻撃から保護するかをまとめたものです。

| 攻撃の種類 | 保護対象か | 備考 |
|----------------|-----------|-------|
| シグナリング攻撃 | はい | TLSはメッセージの整合性を保証します |
| 中間者攻撃 | はい | TLSはサーバー証明書をチェックします |
| 盗聴 | いいえ | TLSはシグナリングを暗号化しますが、メディアは暗号化しません |

メディア（音声/ビデオ）の暗号化にはSRTPを使用してください。

#### 自己署名デジタル証明書

使用できる証明書には、自己署名証明書と商用証明書の2種類があります。自己署名証明書は自身のサーバーによって署名され、商用証明書は外部の認証局によって署名されます。VoIPの場合、自分自身が認証局になることができます。GoDaddyやVerisignのような外部証明書は不要であり、無駄な出費です。ast_tls_certを使用して独自の証明書を生成します。

#### 自己署名証明書によるTLSの設定

以下はTLSを実装するためのステップバイステップガイドです。まず証明書を生成し、次にPJSIP TLSトランスポートを設定し（「chan_pjsipによるTLSの設定」を参照）、最後にソフトフォンをそれらに向けます。ここでは、TLSとSRTPをネイティブでサポートするSipPulse Softphoneを使用します。（TLS/SRTP対応のSIPソフトフォンであれば同様の手順で動作します。）

**ステップ 1.** 認証局のために、4096ビットの長さの3DES暗号化を使用したプライベートRSAキーを作成します。/usr/src/asterisk-22.x.y/contrib/scriptsにある以下のコマンドは、認証局とAsterisk証明書を作成します。通常通り、必要に応じて手順を適応させてください。バージョンやディレクトリは変更される可能性があります。作業内容に注意してください。–CオプションにはドメインまたはIPアドレスを使用してください。ast_tls_certコマンドには3つのオプションがあります。

- -C ホストまたはIPアドレス（私はVMのIPアドレスである192.168.0.74を使用しました）
- -O 組織名
- -d キーを保存するディレクトリ

```
mkdir /etc/asterisk/keys
cd /usr/src/asterisk-22.0.0/contrib/scripts
root@asterisk:/usr/src/asterisk-22.0.0/contrib/scripts# ./ast_tls_cert -C 192.168.0.74 -O "AsteriskGuide" -d /etc/asterisk/keys
No config file specified, creating '/etc/asterisk/keys/tmp.cfg'
You can use this config file to create additional certs without
re-entering the information for the fields in the certificate
Creating CA key /etc/asterisk/keys/ca.key
Generating RSA private key, 4096 bit long modulus
........................................................++
........................................................++
e is 65537 (0x010001)
Enter pass phrase for /etc/asterisk/keys/ca.key:
Verifying - Enter pass phrase for /etc/asterisk/keys/ca.key:
Creating CA certificate /etc/asterisk/keys/ca.crt
Enter pass phrase for /etc/asterisk/keys/ca.key:
Creating certificate /etc/asterisk/keys/asterisk.key
Generating RSA private key, 2048 bit long modulus
........................++++++
......................++++++
e is 65537 (0x010001)
Creating signing request /etc/asterisk/keys/asterisk.csr
Creating certificate /etc/asterisk/keys/asterisk.crt
Signature ok
subject=CN = 192.168.0.74, O = AsteriskGuide
Getting CA Private Key
Enter pass phrase for /etc/asterisk/keys/ca.key:
Combining key and crt into /etc/asterisk/keys/asterisk.pem
root@asterisk:/usr/src/asterisk-22.0.0/contrib/scripts#
```

クライアントの認証に証明書を使用するわけではないため、クライアント証明書は生成しません。クライアントが独自の証明書を提示する必要はありません。

**ステップ 2.** TLS経由でクライアントをサポートするようにAsteriskを設定します。これは`pjsip.conf`で行われます（TLSトランスポートとエンドポイント設定）。完全な設定は次のセクション「chan_pjsipによるTLSの設定」で示します。ここでは証明書を使用した認証は行わず、トラフィックの暗号化のみを行います。

**ステップ 3.** TLS対応のSIPソフトフォンをインストールします（著者はSipPulse Softphoneを使用しています）。

**ステップ 4.** 認証局の証明書をソフトフォンを実行しているコンピュータにコピーします。インストール後、自己署名証明書を使用している場合は、ファイル`/etc/asterisk/keys/ca.crt`をソフトフォンを実行しているコンピュータにコピーします（scp、またはWindowsの場合はWinSCPを使用）。

**ステップ 5.** ソフトフォンでアカウントを作成します。アカウント画面で、他のSIPアカウントと同様に通常通りアカウントを追加します。正しいパスワードを使用してください。認証は依然としてパスワードに基づいています。

**ステップ 6.** アカウント設定でトランスポートとしてTLSを設定します。SipPulse Softphoneのアカウント画面（下記）で、トランスポートとして**TLS**を選択し、ポート5061を使用します。ファイアウォールを調整してTCPポート5061を開放してください。

![SipPulse Softphoneのアカウント画面 — サーバー（AsteriskのIPまたはドメイン）、ユーザー名、パスワード、表示名を入力し、トランスポート（UDP、TCP、またはTLS）を選択します。](../images/softphone/sipphone-account.png){width=35%}

**ステップ 7.** 認証局を信頼します。AsteriskのTLS証明書がパブリックCA（Let's Encryptなど — *展開*の章を参照）によって署名されている場合、SipPulse Softphoneのような最新のソフトフォンは、手動インポートなしでシステム証明書ストアを通じて自動的に信頼します。自己署名証明書を使用する場合は、そのCA（`/etc/asterisk/keys/ca.crt`）をクライアントまたはオペレーティングシステムの信頼ストアにインポートするか、プロンプトが表示されたら受け入れてください。

**ステップ 8.** クライアント証明書は**不要**です。各電話機が認証のために独自の証明書を必要とするというのは一般的な誤解ですが、そうではありません。この時点でAsteriskはセッションを*暗号化*するだけであり、認証は依然としてユーザー名とパスワードで行われます。Asteriskはデフォルトでクライアント証明書を検証しないため、クライアントごとに証明書を配布する必要はありません。

**ステップ 9.** 証明書やトランスポートを変更した後は、ソフトフォンを完全に再起動してください（ウィンドウを閉じるだけでなく、終了して再起動します）。これにより、新しいトランスポート経由で再接続されます。

### chan_pjsipによるTLSの設定

次に、PJSIPをTLS用に設定する方法を学びます。PJSIPはAsterisk 22における唯一のSIPチャネルであるため、切り替える必要はありません。`res_pjsip`、`res_pjproject`および`chan_pjsip`がロードされていることを確認するだけです。ステップ1：/etc/asterisk/modules.confでPJSIPが有効になっていることを確認します。

```
; res_pjsip / res_pjproject / chan_pjsip must be loaded (do NOT noload them)
noload => chan_iax2.so
noload => chan_unistim.so
```

ステップ2：TLSをサポートするようにPJSIPを設定します。/etc/asterisk/pjsip.confファイルにTLSトランスポート用のセクションを追加します。

```
[transport-tls]
type=transport
protocol=tls
bind=0.0.0.0:5061
cert_file=/etc/asterisk/keys/asterisk.crt
priv_key_file=/etc/asterisk/keys/asterisk.key
method=tlsv1_2
```

`method=tlsv1_2`（またはOpenSSL/PJSIPビルドがサポートしていれば`tlsv1_3`）を使用してください。TLS 1.0/1.1は廃止されており安全ではないため、使用すべきではありません。

ステップ3：blink用のエンドポイントを設定します。`pjsip.conf`を編集し、blink用のセクションを編集します。PJSIPが自動的にトランスポートを選択するようにします。

```
[blink]
type=endpoint
aors=blink
auth=blink
context=from-internal
disallow=all
allow=ulaw
dtmf_mode=rfc4733
media_encryption=sdes
[blink]
type=aor
max_contacts=2
remove_existing=yes
[blink]
type=auth
auth_type=digest
username=blink
password=supersecret
```

ステップ4：検証。登録がTLS経由で行われたことを確認するには、Asteriskコンソールで以下のコマンドを使用します。

```text
asterisk*CLI> pjsip show aor blink

      Aor:  <Aor.............................................>  <MaxContact>
    Contact:  <Aor/ContactUri........................> <Hash....> <Status> <RTT(ms)..>
==========================================================================================

      Aor:  blink                                                2
    Contact:  blink/sip:03694827@192.168.0.67:56295;transp 620d91556d NonQual    nan
 ParameterName        : ParameterValue
 ====================================================================
 authenticate_qualify : false
 contact              : sip:03694827@192.168.0.67:56295;transport=tls
 default_expiration   : 3600
 max_contacts         : 2
 maximum_expiration   : 7200
 minimum_expiration   : 60
 qualify_frequency    : 0
 qualify_timeout      : 3.000000
 remove_existing      : true
 support_path         : false
```

### SRTPを使用したセキュアな通話

メディア暗号化を担当するプロトコルは、RFC3711で定義されているSecure Real Time Protocol（SRTP）です。このプロトコルの欠点の1つは、鍵交換の方法が標準化されていないことです。Asteriskは、TLSによって提供されるシグナリング暗号化で保護されたSDPプロトコル上でSDES交換鍵を使用します。MIKEYやZRTPなどの他の方法もあります。Philipp Zimmermannによって開発されたZRTPは、鍵交換とメディア暗号化のための最も洗練された方法の1つです。一部のソフトフォンやハードフォンはZRTPを許可しています。しかし、標準的な方法は依然としてSDESであり、市場に出回っているほぼすべての電話機でこの方法を見つけることができます。以下は、SDPのa=crypto:1およびa=crypto:2行で定義された暗号鍵を含むリクエストの例です。

```
INVITE sip:8000@192.168.1.237 SIP/2.0
Via:
SIP/2.0/tls
192.168.1.192:65525;rport;branch=z9hG4bKPj9fa224a14b17488ea15625ead833ea3a
Max-Forwards: 70
From:
"Flavio"
<sip:flavio@192.168.1.237>;tag=35afe6cc11274934867b24e43c805638
To: <sip:8000@192.168.1.237>
Contact: <sip:pyhkxnjz@192.168.1.192:65524;transport=tls>
Call-ID: 530a339c72af47f0a76e7ecb2a58ac43
CSeq: 5669 INVITE
Allow: SUBSCRIBE, NOTIFY, PRACK, INVITE, ACK, BYE, CANCEL, UPDATE, MESSAGE
Supported: 100rel
User-Agent: Blink 0.2.5 (Windows)
Authorization: Digest username="flavio", realm="asterisk", nonce="72ff51ad",
uri="sip:8000@192.168.1.237",
response="ba8c10672751baa7007d82eb34e2340e",
algorithm=MD5
Content-Type: application/sdp
Content-Length: 544
v=0
o=- 3509174186 3509174186 IN IP4 192.168.1.192
s=Blink 0.2.5 (Windows)
c=IN IP4 192.168.1.192
t=0 0
m=audio 50004 RTP/SAVP 9 104 103 102 0 8 101
a=rtcp:50005
a=rtpmap:9 G722/8000
a=rtpmap:104 speex/32000
a=rtpmap:103 speex/16000
a=rtpmap:102 speex/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-15
a=crypto:1
AES_CM_128_HMAC_SHA1_80
inline:WrtZH82ztz93albRNT8o+oMcK9GvlAHRoaR1STvJ
a=crypto:2
AES_CM_128_HMAC_SHA1_32
inline:4Ma9jJOCEEGMPzzkmgyf6ttp1qhN16yumdXB7eRv
a=sendrecv
```

#### AsteriskでのSRTPの設定

AsteriskでのSRTPの設定は非常に簡単です。エンドポイントで`media_encryption=sdes`を設定します。また、`media_encryption_optimistic=no`を使用して必須にすることで、暗号化されていないメディアを黙認するのではなく拒否することもできます。SDESはシグナリングがTLS経由で実行されることを必要とするため、鍵が平文で送信されることはありません。

**ステップ 1.** Asteriskの設定

`pjsip.conf`の`type=endpoint`セクションに以下を設定します。

```
[blink]
type=endpoint
aors=blink
auth=blink
context=from-internal
disallow=all
allow=ulaw
transport=transport-tls
media_encryption=sdes
media_encryption_optimistic=no
```

**ステップ 2.** ソフトフォンの設定

ソフトフォンで、アカウントメディアのSRTPを有効にします（**SRTP (Media Encryption)** オプションを *Mandatory* に設定）。これにより音声が暗号化されます。

![SipPulse Softphoneのアカウント設定（下部） — **Transport** を TLS に、**SRTP (Media Encryption)** を *Mandatory* に設定し、シグナリングとメディアの両方が暗号化されるようにします。](../images/softphone/sipphone-config.png){width=35%}

## 国際電話に対する二要素認証の有効化

国際電話のルートを設けないことが最善策である場合もあります。しかし、どうしても国際電話をかける必要がある場合は、追加のパスワードを使用してください。ここでは、国際電話をかける前に voicemail のパスワードを要求するために、Asterisk のアプリケーションである vmauthenticate を使用します。これは extensions.conf 内の dialplan で設定します。以下の例を参照してください。これにより、ハッカーが peer のパスワードを発見したり、電話機を乗っ取ったりした場合でも、この宛先に発信するには voicemail のパスワードが必要となります。

```
exten=_9011.,1,Playback(pleasedialyourvmpassword)
exten=_9011.,2,VMAuthenticate(${CALLERID(num)}@default,s)
exten=_9011.,3,Dial(PJSIP/${EXTEN:1}@my_trunk,20,tT)
exten=_9011.,4,Hangup()
```

`VMAuthenticate` は Asterisk 22 においても標準的なアプリケーションです。上記の `Dial()` は SIP/PJSIP trunk (`PJSIP/<number>@<trunk>`) を経由して通話をルーティングします。これは、現代のほとんどのインストール環境で PSTN に接続するための方法です。ご自身の trunk 名に合わせて `my_trunk` を調整し、実際に DAHDI span を持っている場合にのみ `DAHDI/g1/...` を使用してください。dialplan における通話詐欺対策として、このような二要素認証を、どの context がアウトバウンドルートや国際ルートにアクセスできるかを制限することと組み合わせることは、導入可能な最も重要な保護策の一つであり続けます。

## まとめ

本章では、インターネットに接続された IP PBX が抱えるリスクについて学びました。続いて、セキュリティポリシーを実装することで PBX を保護する方法を学習しました。このセキュリティポリシーでは、iptables、fail2ban、TLS、SRTP、および国際電話に対する双方向認証を実装しました。本章を楽しんでいただけたなら幸いです。

## クイズ

1. インターネット収益分配詐欺（Internet Revenue Share Fraud）に対する最も重要な対策は何ですか？
   - A. SRTPを実装する
   - B. Asteriskを最新の状態に保つ
   - C. TLSを実装する
   - D. 強力なパスワードを使用する
2. SIPファジング（SIP fuzzing）の定義は次のうちどれですか？
   - A. 不正な形式の要求と応答を使用したDoS攻撃
   - B. パスワードを総当たり攻撃（ブルートフォース）してサービスを盗用すること
   - C. 現在の通話を盗聴すること
   - D. SIP要求を大量に送りつけるDDoS攻撃
3. TFTPによる盗難（TFTPTheft）は、サーバーがTFTP経由で設定ファイルを提供する場合に発生します。これを回避する方法は次のうちどれですか？
   - A. FTP
   - B. HTTP
   - C. ユーザー名とパスワードを使用したHTTPS
   - D. SCP
4. 中間者攻撃（Man-in-the-middle attacks）で使用される手法は次のうちどれですか？
   - A. TFTP盗難
   - B. ARPスプーフィング
   - C. MACポイズニング
   - D. dsniff
5. SRTPのために、Asteriskは鍵交換にどのシステムを使用しますか？
   - A. MIKEY
   - B. SDES
   - C. ZRTP
   - D. Pluto
6. `/usr/src/asterisk-22.x.y/contrib/scripts`にあり、認証局と証明書を生成するユーティリティはどれですか？
   - A. ast_tls_cert
   - B. gen_tls
   - C. gen_ast_tls
   - D. tls_generator
7. 盗聴を防ぐための有効な戦略はどれですか（該当するものすべてを選択してください）：
   - A. アナログ盗聴検知器を実装する
   - B. ARPwatchユーティリティを使用してARPスプーフィングを検知する
   - C. スイッチでARPスプーフィング検知を有効にする
   - D. SRTPを使用する
8. Asteriskはクライアント証明書を検証することで強力な認証をサポートしています。（PJSIP TLSトランスポートは、クライアントの証明書を要求および検証できます。）
   - A. 正
   - B. 誤
9. Asterisk 22において、in-SDP (SDES) 鍵を使用してSRTPメディア暗号化を有効にするPJSIP endpoint設定はどれですか？
   - A. `encryption=yes`
   - B. `media_encryption=sdes`
   - C. `srtp=mandatory`
   - D. `transport=tls`
10. Asterisk 22において、Fail2BanはPJSIPの認証失敗イベントを専用の ________ ロガーチャネル（`logger.conf`で有効化）から読み取る必要があります。
   - A. `console`
   - B. `messages`
   - C. `security`
   - D. `verbose`

**回答:** 1 — D · 2 — A · 3 — C · 4 — B · 5 — B · 6 — A · 7 — B, C, D · 8 — A · 9 — B · 10 — C
