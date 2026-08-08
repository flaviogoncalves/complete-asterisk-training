# コールキュー

コールキュー（ACD: Automatic Call Distributionとも呼ばれます）は、顧客からの通話に効率的に対応するためにますます重要になっています。自動着信呼分配装置（ACD）は、コストの削減、サービスの向上、そして売上の拡大に貢献します。なぜなら、コール分配装置は数日といった短期間ではなく、長年にわたってビジネスのあり方に影響を与えるからです。コールセンター環境において最も重要な要素は「人」であり、彼らは最も高価なリソースです。エージェントの採用、トレーニング、そしてモチベーションの維持には、時間と費用、そして忍耐が必要です。ACDを導入することで、必要なエージェント数を正確に算出し、優秀な担当者とそうでない担当者を管理し、通話フローを分析することで、エージェントの生産性を最大化することができます。

## Objectives

この章を読み終えることで、以下のことができるようになります。

- コールキューを使用する理由と方法を理解する
- コールキューの基本的な理論を理解する
- キューシステムをインストールし、設定する

## キューの仕組み

コールキューは決して新しい概念ではありません。インバウンドの通話フローが多い場合、適切に通話の振り分けを行うことは困難です。すべてのエージェントの電話を同時に鳴らすグループ戦略は、エージェントの数が少ない場合を除き、うまく機能しない傾向があります。しかし、コールキューを使用すれば、一度に1人の利用可能なエージェントに通話を配信し、エージェントが空いていない場合は顧客を保留にして保留音を流すことができます。キューは、通話に応答できるエージェントが見つかるまで通話を保持することで機能します。キューの最大の利点の一つは、通話の取りこぼしを防ぎつつ、統計情報を生成できることです。

![コールキュー：着信した1-800番号の通話がキューに入り、ACD戦略（ringall、rrmemory、leastrecent、priorityなど）によって利用可能なエージェントに振り分けられる](../images/14-queues-fig01.png)

通常、コールキューは次のように動作します。

- エージェントがキューにログインします。
- 着信した通話がキューに入れられます。
- 通話を振り分けるためのキューイング戦略が使用され、エージェントに通話が送られます。
- 発信者が待機している間、保留音が流れます。
- 発信者に対して、待ち時間などを知らせるアナウンスを行うことができます。
- エージェントが通話に応答し、統計情報が生成されます。

キューの主な用途はカスタマーサービスです。キューを使用することで、エージェントが忙しいときでも通話の取りこぼしを防ぐことができます。キュー内の発信者数が増加していることがわかれば、新しいエージェントをキューに追加することも可能です。キューのもう一つの利点は、通話放棄率、平均通話時間、通話応答目標といった統計情報を取得できることです。これらの統計情報は、顧客により良いサービスを提供するために何人のエージェントを配置すべきかを判断するのに役立ちます。

### ACDアーキテクチャ

ACDアーキテクチャは、キューとエージェントによって構成されます。1人のエージェントが同時に2つのキューに所属することも可能です。キューには、エージェント、チャンネル、エージェントグループを含めることができます。

![ACDアーキテクチャ：各キュー（カスタマーサービス、インサイドセールス）に電話番号から通話が供給され、物理的なチャンネルに紐付いたエージェントに通話が配信される](../images/14-queues-fig02.png)

## Queues

Queuesは、queues.conf設定ファイルで定義されます。AgentsはログインしてQueuesのメンバーとなる担当者です。Agentsはagents.confファイルで定義されます。Queueシステムは多くのリリースを経て大幅に拡張されており、設定ファイルも広範囲にわたるものとなっています。ここでは、主要なパラメータのいくつかを説明します。注目すべき一般的なパラメータの一つが `autofill` です。

```
autofill=yes
```

Queueの古い動作はserialタイプでした。Queueは、次の通話を次のAgentに送信する前に、通話がディスパッチされるのを待機していました。もしAgentが通話に応答するのに15秒かかると、Queue内の他の通話はその通話が応答されるまで待たなければなりませんでした。大量の通話を扱うQueueにとって、この動作は非効率的でした。新しい動作であるautofill=yesは、通話が応答されるまで待機せず、並行して動作します。mixmonitorオプションを使用して、Queue内の通話を録音することができます。このモードでは、通話は同時に録音およびミキシングされます。

### Queue設定ファイル

Queuesはqueues.confファイルで設定されます。図には、Queueの動作例が示されています。

![generalセクションと、strategy、service level、announcements、recording、membersを含むcustomerservice Queueを示したqueues.confファイルの動作例](../images/14-queues-fig03.png)

### Agents

agents.confファイルでAgentsを設定できます。Agentsは任意のextensionからログインして通話を受信できます。Agentへのダイヤルは以下のように行います。

```
Dial(agent/<name>)
```

#### Agentログイン

Agent 300のログインフローは以下の通りです。

- ユーザーは `AgentLogin()` アプリケーションを実行するextensionにダイヤルします。
- `AgentLogin()` が実行され、Agentが現在のチャネルに関連付けられます。
- `agent show all` コマンドを使用して、Agentsのステータスを確認できます。

![Agents: ユーザーがagentloginアプリケーションを実行するextensionにダイヤルしてログインし、Agent 300を現在のチャネルにバインドします。Agentのステータスは `agent show all` で確認できます](../images/14-queues-fig04.png)

agents.confファイルでAgentsを定義できます。

```
; Agent configuration
[general]
persistentagents=yes
[agents]
autologoff=15
autologoffunavail=yes
ackcall=no
endcall=yes
wrapuptime=5000
musiconhold => default
;
;This section contains the agent definitions, in the form:
;
; agent => agentid,agentpassword,name
;
agent => 300,300
agent => 301,301
```

### Members

Membersは、Queueに応答するアクティブなチャネルです。Membersには、直接的なチャネル（PJSIP、DAHDI）や、通話を受信する前にログインするAgentsが含まれます。


### Strategies

通話は、以下のいずれかのStrategiesに従ってMembersに分配されます。

- ringall: 誰かが応答するまで、利用可能なすべてのチャネルを鳴らします。
- leastrecent: 最も最近の通話から最も時間が経過しているMemberに分配します。
- fewestcalls: 最も通話数が少ないMemberに分配します。
- random: ランダムなインターフェースを鳴らします。
- wrandom: ランダムなインターフェースを鳴らしますが、メトリックを計算する際にMemberのpenaltyを重みとして使用します。
- rrmemory: メモリ付きのラウンドロビンを使用します。前回のパスでどこまで通話を処理したかを記憶しています。
- rrordered: rrmemoryと同じですが、configファイル内のQueue Memberの順序が保持されます。
- linear: queues.confにリストされている順序でMembersを鳴らします。動的Membersの場合は、追加された順序で鳴らします。

以前の `roundrobin` strategyは、Asterisk 1.4で非推奨となりました。これはもはやドキュメント化されたstrategyではなく、使用すべきではありません。Asterisk 22では、パーサーは依然として `roundrobin` という単語を受け入れますが、これは `rrmemory` にマッピングされる後方互換性のためのエイリアスに過ぎません。代わりに `rrmemory` （または `rrordered` ）を明示的に使用してください。上記のリストは、Asterisk 22の `queues.conf` における `strategy` オプションに対してドキュメント化されたStrategiesのセットです。

## Agents

Agentsはプロキシチャネルとして実装されています。これらはキュー内で使用できます。Agentチャネルのもう一つの用途は、エクステンションモビリティです。ユーザーは任意の電話機を使用してログインし、自身の通話を受けることができます。これにより、ユーザーはどの部屋に行ってもそこをオフィスにすることが可能です。dialplan内で `dial(agent/<name>)` を使用してAgentを呼び出すことができます。Agentは `agents.conf` ファイルで定義します。

![Agentのモビリティ：ユーザーが任意の電話機を取り、ログイン用のextensionをダイヤルしてAgent番号とパスワードを入力します。`agentlogin()` が成功すると、そのAgent（Agent 300）は通話を受けられる状態になり、CLIコマンド `agent show all` でステータスを確認できます](../images/14-queues-fig05.png)

### Agent Groups

Agentグループを使用することもできます。この機能はACD戦略を考慮しません。通常はすべてのAgentを個別にリストアップする方が好ましいでしょう。Agentグループに転送したい場合は、 `queues.conf` を使用できます：

```
member => agent/@1    ; any agent in group 1
member => agent/:1,1  ; any agent in group 1, wait for first available
```

### Agent用の設定ファイル

Agentは `agents.conf` ファイルで定義されます。以下にこのファイルの動作例を示します。

![agents.confファイルの動作例：persistentagentsを含むgeneralセクション、デフォルトパラメータ（autologoff、ackcall、endcall、wrapuptime、musiconhold）を含むagentsセクション、および2つのAgent定義（300と301）](../images/14-queues-fig06.png)

## ACD関連アプリケーション

Asteriskのキューシステムでは、dialplan内でキューを実装するためにいくつかのアプリケーションが利用可能です。以下にその一部を紹介します。

### queue() アプリケーション

このアプリケーションは、queues.confで定義された特定のコールキューに着信をキューイングします。オプション文字列には、0個以上の1文字オプション（下図参照）を含めることができます。通話の転送に加え、通話をパークして別のユーザーがピックアップすることも可能です。オプションのURLは、チャネルがサポートしていれば呼び出し先に送信されます。オプションのAGIパラメータは、呼び出し側のチャネルがキューメンバーに接続された際に実行されるAGIスクリプトを設定します。timeoutは、タイムアウトとリトライのサイクルの間でチェックされ、指定された秒数が経過するとキューが失敗するようにします。このアプリケーションは、完了時に QUEUE ステータス変数を設定します。

![queue() アプリケーション：その構文 `Queue(queuename,options,URL,announceoverride,timeout,AGI)` — Asterisk 22では引数をカンマで区切ります（古いパイプ `|` 形式は廃止されました） — および利用可能な1文字オプション（d, h, H, n, i, r, t, T, w, W）](../images/14-queues-fig07.png)

- TIMEOUT
- FULL
- JOINEMPTY
- LEAVEEMPTY
- JOINUNAVAIL
- LEAVEUNAVAIL

### agentlogin() アプリケーション

このアプリケーションは、エージェントにシステムへのログインを要求します。常に -1 を返します。ログイン中、通話を受信するエージェントは新しい着信時にビープ音を聞きます。エージェントは * キーを押すことで通話を切断できます。

![agentlogin() アプリケーション：その構文 `AgentLogin([AgentNo][|options])` およびログイン確認をアナウンスしないサイレントログインのための `s` オプション](../images/14-queues-fig08.png)

### addQueueMember() アプリケーション

このアプリケーションは、デバイス（例: PJSIP/3000）を動的にキューに追加します。デバイスが既に存在する場合、エラーを返します。

```
AddQueueMember(queuename[|interface][|penalty]):
```

#### removeQueueMember() アプリケーション

このアプリケーションは、デバイスをキューから動的に削除します。デバイスがそのキューに属していない場合、エラーを返します。

```
RemoveQueueMember(queuename[|interface])
```

### サポートアプリケーションおよびCLIコマンド

一部のアプリケーションやコンソールコマンドは、キューの運用を支援します。以下に各アプリケーションの機能を概説します。

![サポートアプリケーション（AddQueueMember、RemoveQueueMember）および実行時にキューを管理するために使用されるCLIコマンド（agent show all、queue show、queue show <name>）](../images/14-queues-fig09.png)

## 設定タスク

以下の図は、動作するキューシステムを作成するための主要なタスクをまとめたものです。

![ACD設定タスク: (1) コールキューの作成 (必須)、(2) エージェントパラメータの定義 (オプション)、(3) エージェントの作成 (オプション)、(4) dialplanへのキューの追加 (必須)、(5) エージェント録音の設定 (オプション)、(6) agent show all および queue show による確認 (オプション)](../images/14-queues-fig10.png)

ステップ 1: queues.conf ファイルでコールキューを作成します:

```
[telemarketing]
music = default
;announce = queue-telemarketing
;context = qoutcon
timeout = 2
retry = 2
maxlen = 0
member => Agent/300
member => Agent/301
[auditing]
music = default
;announce = queue-auditing
;context = qoutcon
timeout = 15
retry = 5
maxlen = 0
member => Agent/600
member => Agent/601
```

ステップ 2: agents.conf ファイルでエージェントパラメータを定義します:

```
debian:/etc/asterisk# cat agents.conf
;
; Agent configuration
;
[agents]
; Define maxlogintries to allow agent to try max logins before
; failed.
; default to 3
maxlogintries=5
; Define autologoff times if appropriate.  This is how long
; the phone has to ring with no answer before the agent is
; automatically logged off (in seconds)
autologoff=15
; Define autologoffunavail to have agents automatically logged
; out when the extension that they are at returns a CHANUNAVAIL
; status when a call is attempted to be sent there.
; Default is "no".
;autologoffunavail=yes
; Define ackcall to require an acknowledgement by '#' when
; an agent logs in using agentcallbacklogin.  Default is "no".
;ackcall=no
; Define endcall to allow an agent to hangup a call by '*'.
; Default is "yes". Set this to "no" to ignore '*'.
;endcall=yes
; Define wrapuptime.  This is the minimum amount of time when
; after disconnecting before the caller can receive a new call
; note this is in milliseconds.
;wrapuptime=5000
; Define the default musiconhold for agents
; musiconhold => music_class
;musiconhold => default
;
; Define the default good bye sound file for agents
; default to vm-goodbye
;agentgoodbye => goodbye_file
; Define updatecdr. This is whether or not to change the source
; channel in the CDR record for this call to agent/agent_id so
; that we know which agent generates the call
;updatecdr=no
;
; Group memberships for agents (may change in mid-file)
;
;group=3
;group=1,2
;group=
```

ステップ 3: agents.conf ファイルでエージェントを作成します:

```
;agent => agentid,agentpassword,name
[agents]
agent => 300,300,Test Rep - 300
agent => 301,301,Test Rep . 301
agent => 600,600,Test Ver - 600
agent => 601,601,Test Ver . 601
```

ステップ 4: `extensions.conf` ファイルの dialplan にキューを挿入します:

```
; Telemarketing queue.
exten=>_0800XXXXXXX,1,Answer
exten=>_0800XXXXXXX,2,Set(CHANNEL(musicclass)=default)
exten=>_0800XXXXXXX,3,Set(TIMEOUT(digit)=5)
exten=>_0800XXXXXXX,4,Set(TIMEOUT(response)=10)
exten=>_0800XXXXXXX,5,Background(welcome)
exten=>_0800XXXXXXX,6,Queue(telemarketing)
; Transfer to the queue auditing
exten => 8000,1,Queue(auditing)
exten => 8000,2,Playback(demo-echotest); No auditor available
exten => 8000,3,Goto(8000,1) ; Verify auditor again
; Agent login for the telemarketing and auditing queues
exten => 9000,1,Wait(1)
exten => 9000,2,AgentLogin()
```

### キュー録音の設定

通話は Asterisk の MixMonitor アプリケーションを使用して録音できます。(スタンドアロンの Monitor アプリケーションは Asterisk 22 で削除され、queues.conf の `monitor-type` オプションは現在 MixMonitor のみを受け付けます。) 録音はキューアプリケーション内から有効にでき、通話が実際に応答された時点から開始されます。成功した通話のみが録音され、MOH を聴いている間は録音されません。モニタリングを有効にするには、単に monitor-format を指定します。この機能は、それ以外の場合は無効になっています。録音のファイル名は `Set(MONITOR_FILENAME=<filename>)` を使用して設定できます。設定しない場合は `MONITOR_FILENAME=${UNIQUEID}` が使用されます。

queues.conf ファイル内:

```
monitor-format = wav
monitor-type = MixMonitor
monitor-join = yes
```

## Queue operation

以下の例では、queue の使用方法を説明します。

1. Agent login。例: テレマーケティング queue のエージェントが電話を取り、#9000 をダイヤルします。エージェントは無効なログインメッセージを聞き、名前とパスワードを求められます。auditing queue も同じ手順に従います。
2. Queue。一度 queue に入ると、定義されている場合は MOH が聞こえます。テレマーケティング queue に着信があると、エージェントはビープ音を聞き、その通話に接続されます。
3. Call ending。エージェントが通話を終了したとき、以下の操作が可能です。
   - ‘*’ を押して切断し、queue に留まる。
   - 電話を切断し、それによって queue から切断する。
   - #8000 を押して、通話を auditing に転送する。

## 高度なリソース

Asteriskのキューシステムには、特定の顧客やエージェントに優先順位を付けたり、ユーザーメニューを有効にしたりするための高度な機能がいくつか備わっています。

### ユーザーメニュー

キューで待機中のユーザーに対して、1桁のextensionを使用したメニューを定義できます。このオプションを有効にするには、キューの設定ファイルである queues.conf 内に context を定義します。

### ペナルティ

エージェントにはペナルティを設定できます。キューは、ペナルティ値が低いエージェントから順に呼び出しを送信します。例えば、顧客がSusanの優しい声を好むことがわかっている場合、彼女に優先度 0 を割り当てることができます。一方で、経験の浅いUberというエージェントは、カスタマーサービスとしては優先度が低いため、このエージェントには優先度 10 を割り当てます。queues.conf ファイルでの設定は以下の通りです。

```
[customerservice]
member=300,0,Susan the excellent agent
member=300,10,Uber the new guy
```

### 優先度

キューは FIFO (先入れ先出し) モードで動作します。特別な顧客 (プラチナ、ゴールドなど) に優先順位を付けたい場合は、差別化された優先度を設定できます。プラチナまたはゴールドの顧客向けの設定は以下の通りです。

```
exten=>111,1,Playback(welcome)
exten=>111,2,Set(QUEUE_PRIO=10)
exten=>111,3,Queue(customerservice)
```

ブルーの顧客向けの設定は以下の通りです。

```
exten=>112,1,Playback(welcome)
exten=>112,2,Set(QUEUE_PRIO=5)
exten=>112,3,Queue(customerservice)
```

## アプリケーション agentcallbacklogin() の削除

アプリケーション `agentcallbacklogin()` は、Asterisk 1.4（2006年7月）においてDigiumにより非推奨となり、Asterisk 22では利用できなくなりました。推奨されるアプローチは、PJSIPインターフェースを使用して `AddQueueMember()` を利用し、コールバック形式のメンバーをキューに動的に追加することです。移行ガイダンスについては、以前のAsteriskの `/doc` ディレクトリに含まれていたドキュメント `queues-with-callback-members.txt` を参照してください。

古い `chan_agent` チャネルドライバも同様に削除されました。その機能は `app_agent_pool` モジュールとして書き直されており、Asterisk 22において `AgentLogin()`、 `AgentRequest()`、および `AGENT()` dialplan関数を提供しているのはこのモジュールです（これらは現在も存在しており、 `app_agent_pool.so` は標準の22ビルドに同梱されています）。しかし、現代のコールセンターにおいては、エージェントチャネルを完全にスキップし、エージェントのPJSIPデバイスを `AddQueueMember()`/`RemoveQueueMember()` を使用して直接キューに追加する（ `queues.conf` で静的に、あるいはdialplanやAMIから動的に追加する）のが標準的なパターンです。この方法はよりシンプルで、PJSIPのデバイスステートとクリーンに統合できるため、本章全体を通じてこのアプローチを採用しています。

## キューの統計情報

キューからのすべてのイベントは /var/log/asterisk/queue_log に記録されます。キューログの形式は、Asteriskドキュメントの /doc ディレクトリにある queuelog.txt というドキュメントで公開されています。以下に、記録される最も重要なイベントの一部を挙げます。

- ABANDON(position|origposition|waittime)
- AGENTDUMP
- AGENTLOGIN(channel)
- AGENTLOGOFF(channel|logintime)
- ATTENDEDTRANSFER(destexten|destcontext|holdtime|calltime|origposition)
- BLINDTRANSFER(extension|context|holdtime|calltime|origposition)
- COMPLETEAGENT(holdtime|calltime|origposition)
- COMPLETECALLER(holdtime|calltime|origposition)
- CONFIGRELOAD
- CONNECT(holdtime|bridgedchanneluniqueid)
- ENTERQUEUE(url|callerid)
- EXITEMPTY(position|origposition|waittime)
- EXITWITHKEY(key|position)
- EXITWITHTIMEOUT(position|origposition|waittime)
- QUEUESTART
- RINGNOANSWER(ringtime)
- SYSCOMPAT

これらのイベントを処理するための独自のユーティリティを構築することも、すぐに使える統計パッケージを利用することもできます。

- **QueueMetrics** (<https://www.queuemetrics.com/>) – 商用で活発にメンテナンスされているパッケージであり、`queue_log`を解析します。Asteriskコールセンター向けの最も包括的なレポートツールの1つです。
- **自作する** – 上記の`queue_log`形式は安定しており、十分に文書化されているため、小さなスクリプト（Pythonなど）で解析し、イベントをデータベースやダッシュボードに供給するのは簡単です。

`queue_log`を監視（tail）するよりもイベント駆動型のアプローチをとる場合、**Asterisk REST Interface (ARI)** および **AMI** の`QueueSummary`/`QueueStatus`アクションを使用することで、事後的なログ解析ではなく、リアルタイムのキュー状態に基づいたライブキューダッシュボードやカスタム統合を構築できます。ARIは、Asterisk 22においてこの種の作業を行うための、現代的でサポートされた統合インターフェースです。

## 概要

本章では、ACDの使用方法、そのアーキテクチャ、および設定方法について学習しました。また、優先度やペナルティといった高度な機能についても紹介しました。

## クイズ

1. `queues.conf`において有効なキューの分配戦略はどれですか（該当するものすべてを選択してください）。
   - A. ringall
   - B. roundrobin
   - C. leastrecent
   - D. fewestcalls
   - E. rrmemory
   - F. linear
2. `queues.conf`ファイルで ___ オプションを設定することで、キュー内からエージェントと顧客の通話を録音できます。
3. `queues.conf`にリストされている順序通りにメンバーを呼び出すのはどれですか（`strategy`）。
   - A. random
   - B. wrandom
   - C. linear
   - D. fewestcalls
4. テレマーケティングの例において、エージェントが通話を終了した際、どのようなアクションが可能ですか（該当するものすべてを選択してください）。
   - A. `*`を押して切断し、キューに留まる
   - B. 電話を切ってキューから切断する
   - C. `#8000`を押して監査のために通話を転送する
   - D. `#`を押してすべてのキューから即座にログオフする
5. キューを機能させるために*必須*となる2つのタスクはどれですか（該当するものすべてを選択してください）。
   - A. キューの作成
   - B. エージェントの作成
   - C. エージェントパラメータの設定
   - D. 録音の設定
   - E. dialplanへのキューの配置
6. コールキューでは、待機中に発信者がダイヤルできる1桁のメニューを提供できます。これは、キューの`queues.conf`セクションで ___ を定義することで有効になります。
   - A. agent
   - B. menu
   - C. context
   - D. application
7. サポートアプリケーションである`AddQueueMember()`および`RemoveQueueMember()`は、実行時にメンバーを追加または削除するために ___ で使用されます。
   - A. dialplan
   - B. command-line interface
   - C. queues.conf
   - D. agents.conf
8. Asterisk 21で chan_sip が削除されたため、静的なキューメンバーは`SIP/1001`ではなく、___ のようなチャネルを参照する必要があります。
9. `wrapuptime`パラメータは、エージェントが通話を切断してから、キューがそのエージェントに新しい通話を送るまでの最小時間です。
   - A. True
   - B. False
10. `Queue()`を呼び出す前に`QUEUE_PRIO`チャネル変数を設定することで、発信者を同じキュー内でより高い順位に配置できます。
    - A. True
    - B. False

**回答:** 1 — A, C, D, E, F (roundrobin はドキュメント化された戦略ではありません。Asterisk 22では rrmemory の非推奨エイリアスとしてのみ残っています) · 2 — `monitor-format` (キューからの録音は`monitor-format`を指定することで有効になります。Asterisk 22の`monitor-type`は MixMonitor のみをサポートしています) · 3 — C (linear) · 4 — A, B, C (`*`は切断して留まるためのものです。また`#`は全ログオフ用のキーではありません) · 5 — A, E · 6 — C (`context`オプション) · 7 — A (dialplan) · 8 — `PJSIP/1001` (任意の`PJSIP/`インターフェース) · 9 — True · 10 — True
