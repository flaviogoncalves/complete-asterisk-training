# Dial Planの高度な機能

第3章では、dialplanの基礎について説明しました。教育的な理由から、すべての機能ではなく、最も重要な機能のみを解説しました。本章では、dialplanをより深く掘り下げ、高度なテクニック、新しいアプリケーション、そして概念について説明します。

## Objectives

この章を読み終えることで、以下のことができるようになります。

- extension のエントリを簡素化する
- dialplan のセキュリティと extension のフィルタリングに対処する
- IVR メニューを使用して着信を受ける
- サブルーチンを使用して不要な書き換えを回避する
- Include を使用して dialplan のセキュリティを実装する
- AsteriskDB を使用して follow-me を実装する
- PBX で営業時間外の動作を実装する
- switch コマンドを使用して別の PBX に転送する
- privacy manager を実装する
- voicemail を実装する
- 企業ディレクトリを実装する

## dialplan の簡素化

キーワード「same」を使用することで、extension を定義する dialplan を簡素化できます。これにより、dialplan 内のタイプミスを減らすことができるはずです。以下の例を確認してください。

```
exten => 4000,1,NoOp()
same  =>      n,Dial(PJSIP/005C2B313E22)
```

## Dial Planのセキュリティ

Asteriskのdialplanにおいて、ユーザーが新しいチャネルを注入し、dialplan内の番号へ発信できてしまうという欠陥が発見されました。サーバーの`exten=>_X.,1,Dial(PJSIP/${EXTEN})`に以下の行があり、悪意のあるユーザーがsoftphoneで`3000&DAHDI/1/011551123456789`という番号にダイヤルしたと仮定します。SIPプロトコルはデフォルトで任意の英数字を受け入れるため、ダイヤルされたextensionは実際には2つの通話を引き起こします。1つはチャネルPJSIP/3000への通話、もう1つは国際電話番号であるチャネルDAHDI/011551123456789への通話です。したがって、extensionへのアクセス権を持つユーザーであれば誰でも、世界中のどこへでもダイヤルできてしまいます。この挙動を回避する最も簡単な方法は、dialアプリケーションを呼び出す前に番号をフィルタリングすることです。FILTER()関数は、この目的のために非常に便利です。例：

```
exten=>_X.,1,DIAL(PJSIP/${FILTER(0-9,${EXTEN})})
```

このアプリケーションフィルタを使用すると、ダイヤルされた番号から0から9までの数字以外のすべての文字を除去できます。詳細については、Asteriskから入手可能なファイルREADME-SERIOUSLY.bestpractices.txtを参照してください。

## IVRメニューを使用した着信の受信

前節では、DIDを使用するか、オペレーターに転送することで、すべての着信を受信しました。ここでは、IVRメニューの実装方法と、自動応答サービスの作成方法を学びます。詳細に入る前に、いくつかの新しいアプリケーションについて確認しましょう。読者の利便性を高めるため、コマンド`core show application`の出力を以下に記載します。これらの説明は、自身で`core show application <application_name>`を使用して取得することも可能です。

### Background() アプリケーション

このアプリケーションは、指定されたファイルのリストを再生しながら、呼び出し側のチャネルによってextensionがダイヤルされるのを待機します。このアプリケーションによるファイルの再生終了後も数字の入力を待機し続けるには、WaitExtenアプリケーションを使用する必要があります。langoverrideオプションは、要求された音声ファイルに対して試行する言語を明示的に指定します。指定されたcontextは、ダイヤルされたextensionへ移行する際にこのアプリケーションが使用するdialplanのcontextとなります。要求された音声ファイルのいずれかが存在しない場合、通話処理は終了します。オプション：

- s - チャネルが 'up' 状態（つまり、まだ応答されていない）でない場合、メッセージの再生をスキップします。この場合、アプリケーションは直ちに終了します。
- n - ファイルを再生する前にチャネルに応答しません。
- m - 入力された数字が宛先context内の1桁のextensionと一致した場合にのみ中断します。

### Record() アプリケーション

このアプリケーションは、チャネルから指定されたファイル名へ録音を行います。ファイルが存在する場合は上書きされます。

![10-dialplan-advanced-features figure 1](../images/10-dialplan-advanced-features-img01.png)

- 'format' は、録音するファイル形式（wav、gsmなど）です。
- 'silence' は、終了するまでに許容される無音の秒数です。
- 'maxduration' は、秒単位での最大録音時間です。省略または0の場合、制限はありません。
- 'options' には以下の文字を含めることができます：
    - `a` — 既存の録音を置き換えるのではなく、末尾に追加します
    - `n` — 応答しないが、回線がまだ応答されていない場合でも録音します
    - `q` — 静音（ビープ音を鳴らさない）
    - `s` — 回線がまだ応答されていない場合は録音をスキップします
    - `t` — デフォルトの`#`の代わりに、代替の`*`終了キー（DTMF）を使用します
    - `x` — すべての終了キー（DTMF）を無視し、切断されるまで録音を続けます

ファイル名に %d が含まれている場合、ファイルが録音されるたびに、これらの文字は1ずつ増加する数字に置き換えられます。システムで使用可能な形式を確認するには、core show file formats を使用してください。ユーザーは # を押すことで録音を終了し、次の優先順位に進むことができます。録音中にユーザーが切断した場合、すべてのデータは失われ、アプリケーションは終了します。

### Playback() アプリケーション

このアプリケーションは、指定されたファイル名（拡張子は含めない）を再生します。パイプ記号の後にオプションを含めることもできます。'skip' オプションは、チャネルが 'up' 状態（つまり、まだ応答されていない）でない場合にメッセージの再生をスキップさせます。

![10-dialplan-advanced-features figure 2](../images/10-dialplan-advanced-features-img02.png)

![10-dialplan-advanced-features figure 3](../images/10-dialplan-advanced-features-img03.png)

'skip' が指定されている場合、チャネルがオフフック状態でなければ、アプリケーションは直ちに終了します。それ以外の場合、'noanswer' が指定されていない限り、音声が再生される前にチャネルが応答されます。すべてのチャネルがオンフック状態でメッセージの再生をサポートしているわけではありません。'j' が指定されている場合、ファイルが存在しない場合に優先順位 n+101 にジャンプします。このアプリケーションは、完了時に以下のチャネル変数を設定します：

- PLAYBACKSTATUS — 再生試行のステータスを示すテキスト文字列。以下のいずれか：
    - `SUCCESS`
    - `FAILED`

### Read() アプリケーション

このアプリケーションは、ユーザーから指定された回数だけ、あらかじめ決められた桁数の数字を読み取り、指定された変数に格納します。

- filename -- 数字やトーンを読み取る前に再生するファイル（オプション i を使用）
- maxdigits -- 許容される最大桁数。maxdigits に達すると読み取りを停止します（ユーザーが # キーを押す必要はありません）。デフォルトは 0（制限なし）で、ユーザーが # キーを押すのを待ちます。0 未満の値も同様です。最大許容値は 255 です。

![10-dialplan-advanced-features figure 4](../images/10-dialplan-advanced-features-img04.png)

![10-dialplan-advanced-features figure 5](../images/10-dialplan-advanced-features-img05.png)

- option -- オプションは`s`、`i`、`n`です：
    - `s` — 回線が up 状態でなければ直ちに終了します
    - `i` — filename を`indications.conf`からの通知トーンとして再生します
    - `n` — 回線が up 状態でなくても数字を読み取ります
- attempts -- 1 より大きい場合、データが入力されなかった場合に試行される回数です
- timeout -- 数字の応答を待機する秒数（整数）。0 より大きい場合、その値がデフォルトのタイムアウトを上書きします。

関数が失敗またはエラーになった場合、read() アプリケーションは切断されるべきです。

### Gotoif() アプリケーション

このアプリケーションは、指定された条件の評価に基づいて、呼び出し側のチャネルをdialplan内の指定された場所にジャンプさせます。条件が真であれば labeliftrue に、偽であれば 'labeliffalse' にチャネルが継続します。ラベルは Goto アプリケーション内で使用されるものと同じ構文で指定されます。条件によって選択されたラベルが省略された場合、ジャンプは実行されず、dialplan内の次の優先順位で実行が継続されます。

### ラボ：IVRメニューの段階的な構築

以下の機能を持つIVRメニューを作成しましょう。ダイヤルされると、IVRは「XYZコーポレーションへようこそ。営業は1を、技術サポートは2を、トレーニングは3を押してください。担当者につながるまでお待ちください」という音声ファイルを再生します。数字によって発信者は以下のようにルーティングされます：

- `1` — 営業へ転送 (PJSIP/4001)
- `2` — 技術サポートへ転送 (PJSIP/4002)
- `3` — トレーニングへ転送 (PJSIP/4003)
- 数字が押されない場合 — オペレーターへ転送 (PJSIP/4000)

**ステップ 1 – プロンプトの録音**

プロンプトを録音するためのextensionを作成しましょう。プロンプトを録音するには、softphoneから`9003<filename>`（例：`9003welcome`）にダイヤルします。ビープ音が聞こえたら録音を開始し、`#`を押して停止します。ビープ音が鳴り、システムが録音されたプロンプトを再生します。

**ステップ 2 – メニューロジックの作成**

9004 extensionにダイヤルすると、処理は`s` extensionの優先順位1のメニューにジャンプします。

### ダイヤル中のマッチング

これは着信を受信するための会社設定メニューです。`Background()`アプリケーションはウェルカムプロンプトを再生し、その後数字を待機し、発信者がダイヤルした内容を現在のcontextで定義されたextensionと照合します。

```
[incoming]
exten=>s,1,Background(welcome)
exten=>1,1,Dial(DAHDI/1)
exten=>2,1,Dial(DAHDI/2)
exten=>21,1,Dial(DAHDI/3)
exten=>22,1,Dial(DAHDI/4)
exten=>31,1,Dial(DAHDI/5)
exten=>32,1,Dial(DAHDI/6)
```

この会社にダイヤルすると、最初にウェルカムメッセージが再生されます。その後、Asteriskは数字がダイヤルされるのを待機します：

| ダイヤルされた番号 | Asteriskの動作 |
|---------------|-----------------|
| 1 | 直ちに`Dial(DAHDI/1)`を呼び出す |
| 2 | タイムアウトまで待機し、その後`Dial(DAHDI/2)`を呼び出す |
| 21 | 直ちに`Dial(DAHDI/3)`を呼び出す |
| 22 | 直ちに`Dial(DAHDI/4)`を呼び出す |
| 3 | タイムアウトまで待機し、その後切断する |
| 31 | 直ちに`Dial(DAHDI/5)`を呼び出す |
| 32 | 直ちに`Dial(DAHDI/6)`を呼び出す |

メニュー内の曖昧さを避けることは重要です。誰もが迅速に応答されることを望んでいます。このため、番号 2、21、または 22 を使用すべきではありません。

### ラボ：Read() アプリケーションの使用

read() アプリケーションを使用したラボを試してください。Readはユーザーから数字を受け取り、指定された変数に挿入します。その後、gotoif アプリケーションを使用して通話をリダイレクトできます。

## Context inclusion

Contextは、別のContextの内容をインクルード（含める）ことができます。上記の例では、どのチャネルもinternal Context内のどのextensionにもダイヤルできますが、国際電話のextensionにダイヤルできるのは4003チャネルだけです。Context inclusionを使用すると、dialplanの作成が容易になります。Context inclusionを利用することで、誰がどのextensionにアクセスできるかを制御できます。

### “number not found” メッセージのトラブルシューティング

“number not found” というメッセージを受け取ることは非常によくあります。多くの人は、included contextの概念を混同してしまいます。これは直感的ではないためです。経験則として、まずは `pjsip.conf`、`chan_dahdi.conf`、`iax.conf` といった着信チャネルの設定ファイルを確認し、現在のContextを特定してください。次に、extensions.conf ファイル内の dialplan に移動し、ダイヤルした番号がその Context 内で見つかるかどうかを確認します。もし見つからない場合、dialplan に何らかの問題があります。Context に関する黄金律は以下の通りです。1. チャネルは、そのチャネルと同じ Context 内の番号にしかダイヤルできない。2. 通話が処理される Context は、着信チャネルの設定ファイル（`chan_dahdi.conf`、`iax.conf`、`pjsip.conf`）で定義される。

## switch ステートメントの使用

switch コマンドを使用すると、dialplan の処理を別のサーバーに送信できます。その際、相手先サーバーの名前とキーが必要になります。context は送信先の context です。

![10-dialplan-advanced-features figure 6](../images/10-dialplan-advanced-features-img06.png)

## dialplan の処理順序

Asterisk が着信を受けると、そのチャネルで定義された context 内を検索します。場合によっては、ダイヤルされた番号に複数のパターンが一致してしまい、Asterisk が意図した通りに呼び出しを処理できないことがあります。CLI コマンドの `dialplan show` を使用すると、一致の優先順位を確認できます。例として、912 をダイヤルした場合はアナログ trunk (DAHDI/1) にルーティングし、9 で始まるその他のすべての番号は別のアナログ trunk (DAHDI/2) にルーティングしたいとします。その場合、以下のように記述します。

```
[example]
exten=>_912.,1,Dial(DAHDI/1/${EXTEN})
exten=>_9.,1,Dial(DAHDI/2/${EXTEN})
```

2 つのパターンが同じ extension に一致する場合、included context を使用することで、どの extension を先に処理するかを制御できます。included context は、同じ context 内のパターンよりも後に処理されます。

## #INCLUDE ステートメント

大きなファイルを1つ使うべきでしょうか、それとも複数のファイルに分けるべきでしょうか？ `extensions.conf` 内で `#include <filename>` ステートメントを使用すると、他のファイルを読み込むことができます。例えば、ローカルユーザー用に `users.conf` を、特別なサービス用に `services.conf` を作成するといったことが可能です。#include <filename> と混同しないよう注意してください。

```
include=>context statement.
```

## GOSUBによるサブルーチン

古いバージョンの Asterisk には Macro というコマンドがありました。このコマンドは随分前に非推奨となり、現在は GOSUB が推奨されています。ここでは、ボイスメール処理のためのサブルーチンを簡単かつ整理された方法で作成する方法を説明します。コマンドの形式は以下の通りです。

```
gosub([[context,]exten,]priority[(arg1[,...][,argN])])
```

GOSUB コマンドは Asterisk 1.6 から利用可能であり、引数の受け渡し（サブルーチン内では `${ARG1}`、 `${ARG2}` などとして利用可能）をサポートしています。引数を使用することで、古い Macro コマンドを完全に置き換えることが可能になりました。Macro（`app_macro`）は Asterisk 21 で削除されたため、サブルーチンには必ず GOSUB を使用しなければなりません。

### サブルーチンの作成

定義方法は非常によく似ています。以下は、stdexten という名前（好きな名前を選択してください）で定義されたボイスメール用のサブルーチンです。第1引数（チャネル名）を指定して Dial コマンドを呼び出した後、${DIALSTATUS} をチェックして、通話ロジックを次のステップへ送ります。

```
[stdexten]
exten=>s,1,Dial(${ARG1},20,tT)
exten=>s,n,Goto(${DIALSTATUS})
exten=>s,n,hangup()
exten=>s,n(BUSY),voicemail(${ARG2},b)
exten=>s,n,hangup()
exten=>s,n(NOANSWER),voicemail(${ARG2},u)
exten=>s,n,hangup()
exten=>s,n(CANCEL),hangup
exten=>s,n(CHANUNAVAIL),hangup
exten=>s,n(CONGESTION),hangup
```

### サブルーチンの呼び出し

サブルーチンを呼び出す際は、パラメータの前に括弧を使用することに注意してください。

```
exten=>6000,1,Gosub(stdexten,s,1(PJSIP/6000,${EXTEN}))
exten=>6001,1,Gosub(stdexten,s,1(PJSIP/6001,${EXTEN}))
exten=>6002,1,Gosub(stdexten,s,1(PJSIP/6002,${EXTEN}))
exten=>6003,1,Gosub(stdexten,s,1(PJSIP/6003,${EXTEN}))
```

## Using Asterisk DB

コール転送やブラックリストを実装するには、データを保存および復元する手段が必要です。幸いなことに、AsteriskにはAstDBと呼ばれる組み込みデータベースからデータを保存および取得するためのメカニズムが用意されています。最新のAsterisk（Asterisk 22を含む）では、AstDBは **SQLite3** （ファイル `/var/lib/asterisk/astdb.sqlite3`）によってバックアップされています。Asterisk 1.8以前ではBerkeley DB v1が使用されていました。これは、familyとkeyの階層概念を使用するWindowsレジストリデータベースに似ています。データはAsteriskの再起動後も保持されます。family/key APIは古いバックエンドから変更されておらず、ディスク上のストレージ形式のみが変更されました。

### Functions, applications, and CLI commands

AstDBを操作するための関数、アプリケーション、およびCLIコマンドがいくつか存在します。

- variable=${DB(<family/key>)}
- DB(<family/key>)=value
- DB_EXISTS(<family/key>)

例:

```
exten=_*21*XXXX,1,Set(DB(CFIM/${CALLERID(num)})=${EXTEN:4})
exten=s,1,Set(temp=${DB(CFIM/${EXTEN})})
```

AstDBを操作するために使用できるアプリケーションもあります。

- DB_DELETE(<family/key>) — 単一のキーを返して削除する関数
- DBdeltree(<family>) — family全体/サブツリー全体を削除するアプリケーション

古い `DBdel()` アプリケーションはAsterisk 22には存在しません。単一のキーを削除するには `DB_DELETE()` dialplan関数を使用します。例： `Set(x=${DB_DELETE(family/key)})` 、または書き込み操作として `Set(DB_DELETE(family/key)=)` を使用します。 `DBdeltree()` （family全体/サブツリー全体の削除）は現在もアプリケーションとして存在します。

CLIコマンドを使用してキーを設定および削除することも可能です。

- database del
- database put
- database show <family[/key]>
- database showkey
- database deltree
- database get

![10-dialplan-advanced-features figure 7](../images/10-dialplan-advanced-features-img07.png)

![10-dialplan-advanced-features figure 8](../images/10-dialplan-advanced-features-img08.png)

### Implementing Call Forward, DND, and Blacklists

この例では、無条件転送（Call Forward Immediate）と話中時転送（Call Forward on Busy）の実装方法を学びます。無条件転送のプログラムには *21* を、話中時転送のプログラムには *61* を使用します。プログラムをキャンセルするには、それぞれ #21# と #61# を使用します。上記の例を使用してデータベースに値を設定してください。使用するfamilyは以下の通りです。

- CFIM – Call Forward Immediate（無条件転送）
- CFBS – Call Forward on Busy status（話中時転送）
- DND – Do Not Disturb（おやすみモード）

以下のダイヤル操作でデータベースに値を設定してみてください。

- *21* （無条件転送先のextension）
- *61* （話中時転送先のextension）
- *41* （おやすみモードにするextension）

CLIコマンド database show を使用して、追加されたfamily、key、および値を確認してください。

![10-dialplan-advanced-features figure 9](../images/10-dialplan-advanced-features-img09.png)

![10-dialplan-advanced-features figure 10](../images/10-dialplan-advanced-features-img10.png)

### Call Forward, Blacklist, DND

このサブルーチンは、データベースにCFIM、CFBS、またはDNDに対応するkey:valueペアが含まれているかどうかを検証し、それに応じて適切に処理します。以下のサブルーチンはダイヤルルーチンを呼び出します。

```
exten=_4XXX,1,gosub(stdexten,s,1(${EXTEN}))
```

## ブラックリストの使用

古い `LookupBlacklist()` アプリケーションは Asterisk から **削除** されました（これはレガシーな「priority+101ジャンプ」メカニズムとともに廃止されました）。Asterisk 22 では、ブラックリストを `DB_EXISTS()` 関数（キーの存在をテストし、見つかった場合はその値を `${DB_RESULT}` に展開します）と `GotoIf` を組み合わせて直接構築します。ブロックする各番号を `blacklist` ファミリーのキーとして保存し、着信用の context の先頭で発信者番号を確認します。

```
[incoming]
exten => s,1,GotoIf($[${DB_EXISTS(blacklist/${CALLERID(num)})}]?blocked,s,1)
exten => s,n,Dial(PJSIP/4000,20,tT)
exten => s,n,Hangup()
[blocked]
exten => s,1,Answer()
exten => s,2,Playback(blockedcall)
exten => s,3,Hangup()
```

`DB_EXISTS(blacklist/${CALLERID(num)})` は、発信者の番号がデータベースに存在する場合に `1` を返し（通話を `blocked` context に送信します）、それ以外の場合は `0` を返すため、通話は通常の `Dial()` へと進みます。

ブラックリストに番号を追加するには、以前と同じリソースを使用し、*31* に続けてブラックリストに追加する extension を入力します。ブラックリストから番号を削除するには、#31# に続けて削除する番号を入力します。

```
[apps]
exten=>_*31*X.,1,Set(DB(blacklist/${EXTEN:4})=1)
exten=>_*31*X.,2,Hangup()
exten=>_#31#X.,1,Set(x=${DB_DELETE(blacklist/${EXTEN:4})})
exten=>_#31#X.,2,Hangup()
```

コンソールの CLI を使用してブラックリストに番号を挿入することもできます。

```
*CLI>database put blacklist <name/number> 1
```

注意: キーには任意の値を関連付けることができます。`DB_EXISTS()` テストは値ではなくキーを検索します。ブラックリストから番号を消去するには、以下を使用できます。

```
*CLI>database del blacklist <name/number>
```

## 時間ベースのコンテキスト

以下の図では、3つのコンテキストを持つdialplanを示しています。 [incoming] コンテキストは、通常、通話が着信する場所です。以下に例示するように、システム時刻に応じて動作を変更する4つの行を含めています。

```
include => context,<times>,<weekdays>,<mdays>,<months>
```

最新の Asterisk（22を含む）では、time-include フィールドをパイプではなく**カンマ**で区切ります。従来のパイプ形式（`include => context|times|weekdays|mdays|months`）は、単なるリテラルのコンテキスト名として解析され、時間条件は適用されずに黙示的に失敗します。

通常の営業時間中は、処理が mainmenu にリダイレクトされ、そこで着信を処理するために IVR が呼び出されるのが一般的です。営業時間外に通話が行われた場合は、${SECURITY} 変数で定義された security extension が呼び出されます。もし security extension が応答しない場合は、オペレーターの voicemail に転送されます。

![10-dialplan-advanced-features figure 11](../images/10-dialplan-advanced-features-img11.png)

![10-dialplan-advanced-features figure 12](../images/10-dialplan-advanced-features-img12.png)

## gotoiftime() を使用した時間ベースのメッセージ

GotoIfTime() の構文を以下に示します。

```
GotoIfTime(times,weekdays,mdays,months[,timezone]?[labeliftrue][:labeliffalse])
```

Asterisk 22 では、フィールド区切り文字はパイプではなく**カンマ**です（パイプ形式は Asterisk 1.6 で非推奨となりました）。オプションの `timezone` フィールドがサポートされており、各分岐ラベルは通常の `[[context,]extension,]priority` 形式を使用します。

このアプリケーションは時間ベースの context を置き換えることができ、理解しやすく読みやすいものとなっています。時間は以下のように指定できます。

- <timerange>=<hour>':'<minute>'-'<hour>':'<minute> |"*"
- <daysofweek>=<dayname>|<dayname>'-'<dayname>|"*"
- <dayname>="sun"|"mon"|"tue"|"wed"|"thu"|"fri"|"sat"
- <daysofmonth>=<daynum>|<daynum>'-'<daynum> |"*"
- <daynum>=1 から 31 までの数値
- <hour>=0 から 23 までの数値
- <minute>=0 から 59 までの数値
- <months>=<monthname>|<monthname>'-'<monthname>|"*"
- <monthname>="jan"|"feb"|"mar"|"apr"|"may"|"jun"|"jul"|"aug"|"sep"|"oct"|"nov"|"dec"

曜日と月の名前は大文字と小文字を区別しません。

```
exten=>s,1,GotoIfTime(8:00-18:00,mon-fri,*,*?normalhours,s,1)
```

上記のステートメントは、月曜日から金曜日の午前8時から午後6時の間に通話があった場合、処理を normalhours context 内の extension s に転送します。

## DISAを使用して新しいダイヤルトーンを取得する

DISA（Direct Inward System Access：ダイレクトインワードシステムアクセス）は、ユーザーが2つ目のダイヤルトーンを受け取ることができるシステムです。これにより、ユーザーは別の宛先へ再度ダイヤルすることが可能になります。これは、技術者が週末にテクニカルサポートのために長距離電話をかける際によく使用されます。自宅から直接宛先にダイヤルする代わりに、オフィスのDISA番号に電話をかけてダイヤルトーンを受け取り、そこから宛先に発信します。その結果、長距離通話料金は自宅の電話ではなく会社側に請求されます。

```
DISA(passcode|filename[,context[,cid[,mailbox[@context][,options]]]])
```

例：

```
exten => s,1,DISA(no-password,default)
```

上記のステートメントを使用すると、ユーザーはPBXにダイヤルし、パスワードを要求されることなくダイヤルトーンを受け取ります。DISAを使用した通話はすべて、`default` contextを使用して処理されます。このアプリケーションの引数には、グローバルパスワードまたはファイル内の個別パスワードが含まれます。contextが指定されていない場合は、`disa` contextが想定されます。パスワードファイルを使用する場合は、完全なパスを指定する必要があります。DISAによる外部発信には、発信者番号（Caller ID）を指定することも可能です。例：

```
exten => s,1,DISA(numeric-passcode,default,"Flavio" <4830258590>)
```

Asterisk 22では、引数の区切り文字としてカンマを使用します（パイプ形式は1.6で非推奨となりました）。最初の引数は単一のパスコードかパスコードファイルへのパスのいずれかであり、何も指定されない場合のデフォルトのcontextは`disa`です。

## 同時通話数の制限

GROUP() 関数を使用すると、特定のグループ内で同時にアクティブなチャネルがいくつあるかをカウントできます。例として、リオデジャネイロに支店があり、電話番号が「_214X」というパターンに従っているとします。この拠点には専用線が引かれており、音声帯域幅として64Kが確保されています。この場合、許可される最大通話数は2（G.729を使用し、1通話あたり約31.2K）となります。リオへの通話を2つまでに制限するには、以下のように設定します。

```
exten=>_214X,1,set(GROUP()=Rio)
exten=>_214X,n,Gotoif($[${GROUP_COUNT()} > 1]?outoflimit)
exten=>_214X,n,Dial(PJSIP/${EXTEN})
exten=>_214X,n,hangup
exten=>_214X,n(outoflimit),playback(callsexceedcapacity)
exten=>_214X,n,hangup
```

## Voicemail

Voicemailは、着信した音声メッセージを録音し、ディスクに保存したり電子メールで送信したりするコンピュータ化された電話応答システムです。名前でボイスメールボックスを検索できるディレクトリ機能が備わっていることもあります。かつて、Voicemailシステムは非常に高価なものでした。現在では、IP電話の普及により、Voicemailは標準的な機能になりつつあります。

Voicemailを設定するには、以下の手順を実行する必要があります。

**ステップ 1: `voicemail.conf`を編集し、一般的なパラメータを設定します。**

- `format` — メッセージの録音に使用するcodec（例: wav49, wav, gsm）
- `serveremail` — 電子メール通知の送信元として表示される名前
- `maxmsg` — メールボックスに保存できるメッセージの最大数。このしきい値を超えると、メッセージは破棄されます
- `maxsecs` — Voicemailメッセージの最大長（秒単位）
- `minsecs` — メッセージの最小長（秒単位）。このしきい値を下回ると、メッセージは録音されません
- `maxsilence` — メッセージの終了とみなす無音時間（秒単位）

**ステップ 2: `voicemail.conf`を編集し、ユーザーのメールボックスを作成します。**

### Voicemail.conf

メールボックスは、1行につき1つのメールボックスを以下の形式で定義します。

```
mailboxID => pincode,fullname,email,pager-email,options
```

各フィールドの意味は以下の通りです。

- **MailboxID** — 通常はextension番号
- **Pincode** — Voicemailシステムにアクセスするためのパスワード
- **Full name** — ディレクトリアプリケーションで使用される名前
- **E-mail** — Voicemail通知用のアドレス
- **Pager e-mail** — SMSゲートウェイやポケットベル経由の通知用アドレス
- **Options** — メールボックスごとのオプション（`[general]`と同じオプションですが、このメールボックスにのみ適用されます）

Voicemailには、その動作を制御するためのいくつかのオプションがあります。ここではデフォルトのオプションを使用し、メールボックスの定義に集中します。ファイル内の`[general]`セクションの後に、それぞれのcontext内でメールボックスIDの設定を開始します。例:

```
[general]
[default]
1234=>1234,SomeUser,email@address.com,pager@address.com,saycid=yes|dialout=fromvm|callback=fromvm|review=yes|operator=yes
```

詳細なオプションについては、ファイル`voicemail.conf`を確認してください。

**ステップ 3: ファイル`extensions.conf`を設定します。**

前述の（*Subroutines with GOSUB*の項にある）サブルーチン`stdexten`は、ここで必要となる通話/Voicemailハンドラそのものです。これはextensionを呼び出し、チャネル変数`${DIALSTATUS}`の値を使用して、通話フローを適切なVoicemail応答へリダイレクトします（話中時は`b`、不在時は`u`）。`extensions.conf`内の各extensionから`Gosub(stdexten,s,1(PJSIP/<device>,<mailbox>))`を使用して呼び出してください。

## VoiceMailMain() アプリケーションの使用

voicemailmain() アプリケーションは、voicemail メールボックスを設定するために使用されます。ユーザーはこのアプリケーションをダイヤルすることで、自身の応答メッセージを録音したり、voicemail を聴取したりできます。dialplan でこのアプリケーションを呼び出すには、以下のように記述します。

```
exten=>9000,1,VoiceMailMain()
```

以下に、このアプリケーションで使用可能なオプションの一覧を示します。

### Voicemail アプリケーションの構文

このアプリケーションを使用すると、発信者は指定されたメールボックスのリストに対してメッセージを残すことができます。複数のメールボックスが指定された場合、応答メッセージは最初に指定されたメールボックスのものが使用されます。指定されたメールボックスが存在しない場合、dialplan の実行は停止します。構文は以下の通りです。

```
 [Synopsis]
Leave a Voicemail message.
[Description]
This application allows the calling party to leave a message for the specified
list of mailboxes. When multiple mailboxes are specified, the greeting will
be taken from the first mailbox specified. Dialplan execution will stop if
the specified mailbox does not exist.
The Voicemail application will exit if any of the following DTMF digits are
received:
    0 - Jump to the 'o' extension in the current dialplan context.
    * - Jump to the 'a' extension in the current dialplan context.
This application will set the following channel variable upon completion:
${VMSTATUS}: This indicates the status of the execution of the VoiceMail
application.
    SUCCESS
    USEREXIT
    FAILED
[Syntax]
VoiceMail(mailbox[@context][&mailbox[@context][&...]][,options])
[Arguments]
options
```

![10-dialplan-advanced-features figure 13](../images/10-dialplan-advanced-features-img13.png)

```
    b: Play the 'busy' greeting to the calling party.
    d([c]): Accept digits for a new extension in context <c>, if played
    during the greeting. Context defaults to the current context.
    g(#): Use the specified amount of gain when recording the voicemail
    message. The units are whole-number decibels (dB). Only works on supported
    technologies, which is DAHDI only.
    s: Skip the playback of instructions for leaving a message to the
    calling party.
    u: Play the 'unavailable' greeting.
    U: Mark message as 'URGENT'.
    P: Mark message as 'PRIORITY'.
```

いずれの場合も、録音が開始される前に beep.gsm ファイルが再生されます。voicemail メッセージは inbox ディレクトリに保存されます。

```
/var/spool/asterisk/voicemail/context/boxnumber/INBOX/
```

アナウンス中に発信者が 0 （ゼロ）を押すと、現在の voicemail context 内の 'o' (out) extension に転送されます。これはオペレーターに接続するために使用できます。録音中に発信者が # を押すか、無音制限時間が経過すると、録音は停止し、通話は次の優先順位へ進みます。以下に示すように、voicemail が再生された後の通話処理を必ず記述するようにしてください。

```
exten=>somewhere,5,Playback(Goodbye)
exten=>somewhere,6,Hangup
```

### voicemail メッセージを緊急としてタグ付けする

一部のメッセージを「緊急」としてタグ付けすることができます。これには2つの方法があります。

- voicemail() アプリケーションで 'U' オプションを渡す
- voicemail.conf ファイルで review=yes を指定する。このオプションを使用すると、ユーザーは音声ガイダンスの録音後にメッセージを緊急としてタグ付けできるようになります。

## ボイスメールの電子メール送信

（私の場合のように）ボイスメールを確認するために `voicemailmain()` アプリケーションを使用しないケースもあります。すべてのメッセージを音声ファイルとして添付し、電子メールで送信する方が、よりシンプルで実用的です。`attach` および `delete` パラメータを使用することで、すべてのメールを電子メールに送信し、メールボックスから削除することができます。

```
attach=yes
delete=yes
```

ボイスメールを電子メールに送信するために、voicemail アプリケーションはオペレーティングシステムのコンポーネントであるメッセージ転送エージェント（MTA）を使用します。Debian では MTA として Exim を使用します。電子メールを送信するアプリケーションは `mailcmd` パラメータで定義されます。

```
mailcmd =/usr/sbin/sendmail -t
```

Linux の Debian ディストリビューションでは、MTA は Exim です。Debian で Exim を設定するには、以下を使用します。

```
dpkg-reconfigure exim4-config
```

MTA が SMTP を介して直接電子メールを送信するように設定するか、スマートホスト（通常は会社のメールサーバー）を経由するように設定するかを選択できます。Asterisk サーバーから電子メールサーバーへ電子メールを送信する最適な方法については、電子メール管理者に確認してください。

## 電子メールメッセージのカスタマイズ

以下の変数を設定することで、メッセージの送信方法を制御できます。電子メールの件名および本文用の変数です。

- VM_NAME
- VM_DUR
- VM_MSGNUM
- VM_MAILBOX
- VM_CIDNUM
- VM_CIDNAME
- VM_CALLERID
- VM_DATE

電子メールの本文と件名は、`voicemail.conf`の`[general]`セクションで設定するテンプレートから構築されます。本文と件名の両方を変更できますが、メッセージのサイズ制限は 512 バイトです。テンプレート内では、`\n`で改行を挿入し、`\t`でタブを挿入します。

以下の`emailsubject`の例は単純なものです。`emailbody`の例はデフォルト設定に非常に近いものです。デフォルトでは、CIDNAME が null でない場合は CIDNAME を表示し、そうでない場合は CIDNUM を表示します。両方が null の場合は「an unknown caller」と表示されます。

```
emailsubject=[PBX]: New message ${VM_MSGNUM} in mailbox ${VM_MAILBOX}

emailbody=Dear ${VM_NAME}:\n\n\tjust wanted to let you know you were just left a ${VM_DUR} long message (number ${VM_MSGNUM})\nin mailbox ${VM_MAILBOX} from ${VM_CALLERID}, on ${VM_DATE}, so you might\nwant to check it when you get a chance. Thanks!\n\n\t\t\t\t--Asterisk\n
```

## Voicemail Web interface

Asteriskのソース配布物には、Asteriskソースツリー内の`contrib/scripts/vmail.cgi`に配置されている`vmail.cgi`というPerlスクリプトが含まれています（これはAsterisk 22にも同梱されています）。`make install`コマンドではこのインターフェースはインストールされません。ソースディレクトリから`make webvmail`を実行する必要があります。このスクリプトを使用するには、サーバーにPerlコマンドインタープリタとWebサーバー（Apacheなど）がインストールされている必要があります。

```
make webvmail
```

`make webvmail`ターゲットは、スクリプトを（setuid rootで）WebサーバーのCGIディレクトリ（`HTTP_CGIDIR`）にインストールし、サポート用の画像を`images/*.gif`から`HTTP_DOCSDIR/_asterisk`（デフォルトでは`/var/www/html/_asterisk`）へコピーします。これらのパスがWebサーバーの構成と一致しない場合は、ターゲットを実行する前に、トップレベルの`Makefile`にある`HTTP_CGIDIR`および`HTTP_DOCSDIR`変数を編集してください。

## Voicemail notification

新しいボイスメールが届いた際に電話機へ通知メッセージを送信するようにボイスメールを設定できます。Asterisk 22では、Message Waiting Indication (MWI) はPJSIPおよびSIP電話機、そしてDAHDI電話機で動作します。未聴のボイスメールがあることを示すために、インジケーターライトが点滅したり、電話機がシャッター音を鳴らしたりすることがあります。対応するチャネル設定ファイルでメールボックスを設定する必要があります。例: `pjsip.conf` (endpointセクション内):

```
mailboxes=8590
```

PJSIPでは、メールボックスのヒントは`sip.conf`の古い`mailbox=`ではなく、`pjsip.conf`のendpointセクション内にある`mailboxes`オプションで設定されます。MWIサブスクリプションは`res_pjsip_mwi`モジュールによって処理されます。

![The Comedian Mail Webインターフェース (`vmail.cgi`): Asterisk Web-Voicemailのログイン画面 — メールボックスとパスワードを入力して、ブラウザからボイスメールの再生、保存、転送、削除を行います。これはAsterisk 22にも同梱されており、`make webvmail`でインストールされます。](../images/10-dialplan-advanced-features-img14.png)

### ラボ: 電話機でのメッセージ通知

このラボはSIP softphoneを使用してテストされました。

1. `pjsip.conf`を編集し、4401という名前のデバイスのendpointセクションに`mailboxes=4401`を追加します。
2. `extensions.conf`を編集し、4401 extensionへのボイスメールを録音するためのextensionを作成します。

```
exten=9008,1,voicemail(4401,b)
```

3. コンソールに移動し、リロードします。
4. SipPulse Softphoneで、SIPアカウント設定を開き、そのアカウントのボイスメール (message-waiting) チェックを有効にします。
5. 9008にダイヤルし、メッセージを残します。
6. 電話機のメッセージアイコンを確認します。

## directory アプリケーションの使用

このアプリケーションを使用すると、ダイヤルするユーザーを素早く検索できます。名前とそれに対応する extension のリストは、voicemail の設定ファイルである voicemail.conf から取得されます。このアプリケーションの構文は、core show application directory を使用して確認できます。

```
-= Info about application 'Directory' =-
[Synopsis]
Provide directory of voicemail extensions.
[Description]
This application will present the calling channel with a directory of
extensions from which they can search by name. The list of names and
corresponding extensions is retrieved from the voicemail configuration file,
"voicemail.conf".
This application will immediately exit if one of the following DTMF digits
are received and the extension to jump to exists:
'0' - Jump to the 'o' extension, if it exists.
'*' - Jump to the 'a' extension, if it exists.
[Syntax]
Directory([vm-context][,dial-context[,options]])
[Arguments]
vm-context
    This is the context within voicemail.conf to use for the Directory.
    If not specified and 'searchcontexts=no' in "voicemail.conf", then
    'default' will be assumed.
dial-context
    This is the dialplan context to use when looking for an extension
    that the user has selected, or when jumping to the 'o' or 'a' extension.
options
    e: In addition to the name, also read the extension number to the
    caller before presenting dialing options.
    f(n): Allow the caller to enter the first name of a user in the
    directory instead of using the last name.  If specified, the optional
    number argument will be used for the number of characters the user should
    enter.
    l(n): Allow the caller to enter the last name of a user in the
    directory.  This is the default.  If specified, the optional number
    argument will be used for the number of characters the user should enter.
    b(n):  Allow the caller to enter either the first or the last name
    of a user in the directory.  If specified, the optional number argument
    will be used for the number of characters the user should enter.
    m: Instead of reading each name sequentially and asking for
    confirmation, create a menu of up to 8 names.
    p(n): Pause for n milliseconds after the digits are typed.  This
    is helpful for people with cellphones, who are not holding the receiver
    to their ear while entering DTMF.
    NOTE: Only one of the <f>, <l>, or <b> options may be specified.
    *If more than one is specified*, then Directory will act as  if <b> was
    specified.  The number of characters for the user to type defaults to
    '3'.
```

### 実習: directory アプリケーションの使用

1. voicemail.conf ファイルを編集し、dialplan に2つの extension を追加します。

```
[default]
; Define maximum number of messages per folder for a particular context.
;maxmsg=50
4400=>4400,Clint Eastwood,ceastwood@voip.school
4401=>4401,John Wayne,jwayne@voip.school
```

2. dialplan にこれらの extension を作成します。

```
exten=9006,1,VoiceMailMain()
exten=9006,n,Hangup()
exten=9007,1,Directory(default,default)
exten=9007,n,Hangup()
```

3. コンソールに移動し、リロードを実行します。
4. 9006 にダイヤルし、各 extension (4400, 4401) の名前を録音します。
5. 9007 にダイヤルし、いずれかの extension の姓の最初の3文字を選択します (Eas=327)。これが正しい選択肢であれば、「1」を押してその名前に転送します。

## Lab: Putting it all together

これまでに、dialplanのいくつかの概念を学習してきました。これまでに学んだすべてのアプリケーション、関数、概念を1つのdialplanの例にまとめ、それらがどのように組み合わせて使用されるかを理解しましょう。以下のシナリオに基づき、PBX設定の全体を通してガイドします。

- 4つのアナログtrunk
- 16のSIPベースのextension
- 3つのサービスクラス:
    - restrict (内線、市内通話、および 1-800)
    - ld (長距離通話)
    - ldi (国際通話)
- 営業時間外メッセージ
- 自動応答 (Auto attendant)

### Step 1 – Configuring channels

**アナログtrunk (`chan_dahdi.conf`)。** まず、DAHDIチャネル設定ファイル `chan_dahdi.conf` でアナログtrunkを設定します。ここでは、4つのFXOインターフェースを備えたT400P Digiumカードを使用します。ドライバはすでにロードされており、ドライバ設定ファイル (/etc/dahdi/system.conf) が正しく設定されているものとします。

![10-dialplan-advanced-features figure 16](../images/10-dialplan-advanced-features-img16.png)

```
signalling=fxs_ks
language=en
context=incoming
group=1
channel => 1-4
```

**SIPチャネル (`pjsip.conf`)。** dialplanの番号体系として 2000 から 2099 を選択しました。G.729 と G.711 ulaw の2つのcodecを使用します。前者はインターネットまたはWAN経由で Asterisk を使用する電話機用、後者はローカルネットワークを使用する電話機用です。`pjsip.conf` では、どのデバイスがどのサービスクラス (restrict, ld, ldi) に属するかを決定します。ブルートフォース攻撃に対する脆弱性を減らすため、デバイス名として電話機のMACアドレスを使用します。ブルートフォース攻撃を避けるため、強力なパスワードを使用することを強く推奨します！

トランスポートと3つの再利用可能なテンプレート（共有codecを持つendpointベース、ダイジェスト認証、および単一のcontact AOR）を定義し、各デバイスをテンプレートに紐付けて、異なる部分（サービスクラスのcontextと認証情報）のみを上書きします。`host=dynamic` は電話機が登録を行うAORとなり、`directmedia` は `direct_media` となります：

```ini
; pjsip.conf
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[endpoint-base](!)
type=endpoint
disallow=all
allow=ulaw,gsm
direct_media=yes

[auth-digest](!)
type=auth
auth_type=digest

[aor-single](!)
type=aor
max_contacts=1

[00001A000002](endpoint-base)
context=restrict
auth=00001A000002
aors=00001A000002
mailboxes=20
[00001A000002](auth-digest)
username=00001A000002
password=#s2cr2t#
[00001A000002](aor-single)

[00001A000003](endpoint-base)
context=ld
dtmf_mode=rfc4733
auth=00001A000003
aors=00001A000003
mailboxes=20
[00001A000003](auth-digest)
username=00001A000003
password=#s3cr3t#
[00001A000003](aor-single)

[00001A000004](endpoint-base)
context=ldi
dtmf_mode=rfc4733
auth=00001A000004
aors=00001A000004
mailboxes=20
[00001A000004](auth-digest)
username=00001A000004
password=#s3cr3t#
[00001A000004](aor-single)
```

### Step 2 – Configure the dial plan

それでは extensions.conf の設定を開始しましょう。内線番号と市内通話のダイヤルを定義します。

```
[restrict]
exten=>_2000,1,Dial(PJSIP/00001A000002,20,t)
exten=>_2030,1,Dial(PJSIP/00001A000003,20,t)
exten=>_2040,1,Dial(PJSIP/00001A000004,20,t)
exten=>_9XXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20) ; local calls
exten=>_91800.,1,Dial(DAHDI/g1/${EXTEN:1},20); 1-800
```

LD（長距離通話）を定義します。

```
[ld]
Include=>restrict
exten=>_9NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

国際通話を定義します。

```
[ldi]
include=>ld
exten=>_901X.,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

### Step 3 - Receiving calls using an auto-attendant

着信を受けるには、2つのcontextを使用します。1つ目は通常営業時間用で、自動応答が着信を受けます。2つ目は営業時間外用で、発信者は「XYZ社にお電話ありがとうございます。当社の営業時間は午前8時から午後6時までです。内線番号をご存知の場合はそのままダイヤルするか、電話をお切りください」といったメッセージを受け取ります。メニュー：通常営業時間、営業時間外。以下のメニューでは、システムが発信者に対して営業時間外であることを警告するメッセージを再生し、発信者が内線番号をダイヤルできるようにします（営業時間外でも誰かが働いている可能性があるためです）。

```
[incoming]
include=>normalhours,08:00-18:00,mon-fri,*,*
include=>afterhours,18:00-23:59,*,*,*
include=>afterhours,00:00-07:59,*,*,*
include=>afterhours,*,sat-sun,*,*
[normalhours]
exten=>s,1,Goto(mainmenu,s,1)
[afterhours]
exten=>s,1,Background(afterhours)
exten=>s,2,hangup()
exten=>i,1,hangup()
exten=>t,1,hangup()
include=>restrict
```

メニュー：メインおよび営業。通常営業時間中、着信は自動応答メニューによって応答され、「XYZ社へようこそ。営業は1を、技術サポートは2を、トレーニングは3を、またはご希望の内線番号をダイヤルしてください」といったメッセージが流れます。

```
[globals]
OPERATOR=PJSIP/2060
SALES=PJSIP/2035
TECHSUPPORT=PJSIP/2004
TRAINING=PJSIP/2036
[mainmenu]
exten=> s,1,Background(welcome)
exten=>1,1,Goto(sales,s,1)
exten=>2,1,Goto(techsupport,s,1)
exten=>3,1,Goto(training,s,1)
exten=>i,1,Playback(Invalid)
exten=>i,2,hangup()
exten=>t,1,Dial(${OPERATOR},20,Tt)
include=>restrict
[sales]
exten=>s,1,Dial(${SALES},20,Tt)
[techsupport]
exten=>s,1,Dial(${TECHSUPPORT},20,Tt)
[training]
exten=>s,1,Dial(${TRAINING},20,Tt)
```

これらのステートメントにより、dialplanの機能は準備完了です。次のセクションでは、PBXの操作方法を説明します。

## まとめ

本章では、IVRや自動音声応答装置を使用して着信を処理する方法を学びました。また、contextのインクルードという概念を学習し、いくつかの実装例を確認しました。繰り返し入力を避けるためにサブルーチンを使用し、データ保存が必要な機能（転送、着信拒否、ブラックリストなど）にはAsteriskデータベース（Asterisk 22ではSQLite3でバックアップされるAstDB）を使用しました。最後に、営業時間外の動作を実装する方法を学び、これらの概念を組み合わせて完全なdialplanを実装しました。

## クイズ

1. 時間依存の context include は `include => context,<times>,<weekdays>,<mdays>,<months>` という形式を使用します。では `include => normalhours,08:00-18:00,mon-fri,*,*` は何を行いますか？
   - A. 月曜日から金曜日の 08:00 から 18:00 まで extension を実行する
   - B. 毎日、すべての月でオプションを実行する
   - C. 何もしない。この形式は無効である
2. 最新の Asterisk (Asterisk 22 を含む) において、時間ベースの `include =>` および `GotoIfTime()` のフィールドはどの文字で区切られますか？
   - A. パイプ `|`
   - B. カンマ `,`
   - C. セミコロン `;`
   - D. スラッシュ `/`
3. 複数のチャンネルに同時にダイヤル（一斉呼び出し）するには、それらを `Dial()` 内で ___ という文字で区切ります。
4. 発信者が extension をダイヤルするのを待つ間にプロンプトを再生する音声メニューは、通常 ___ アプリケーションを使用して作成されます。
5. 別のファイルの内容を `extensions.conf` 内に含めるには、___ ステートメントを使用します（注：これは `include =>` context ステートメントとは異なります）。
6. Asterisk 22 において、組み込みの AstDB データベースのバックエンドは何ですか？
   - A. Berkeley DB v1
   - B. MySQL
   - C. SQLite3
   - D. PostgreSQL
7. `Dial(type1/identifier1&type2/identifier2)` を使用すると、Asterisk は各チャンネルを順番にダイヤルし、その間で 20 秒間待機します。
   - A. 偽
   - B. 真
8. Background() アプリケーションを使用する場合、DTMF の数字を押してオプションを選択するには、メッセージの再生が終了するまで待たなければなりません。
   - A. 偽
   - B. 真
9. 構文 `Goto([[context,]extension,]priority)` が与えられた場合、Goto() アプリケーションの呼び出しとして有効なものはどれですか？（該当するものすべてを選択してください）
   - A. Goto(context,extension)
   - B. Goto(context,extension,priority)
   - C. Goto(extension,priority)
   - D. Goto(priority)
10. Asterisk 22 の dialplan で AstDB から単一のキーを削除するには、以下を使用します：
    - A. `DBdel()` アプリケーション
    - B. `DB_DELETE()` 関数
    - C. `DBdeltree()` アプリケーション
    - D. `LookupBlacklist()` アプリケーション

**回答:** 1 — A · 2 — B · 3 — `&` · 4 — Background() · 5 — #include · 6 — C · 7 — A · 8 — A · 9 — B, C, D · 10 — B
