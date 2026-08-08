# Asterisk Call Detail Records

Asteriskは、他の電話プラットフォームと同様に、通話料金の請求を可能にします。市場には、PBXによって生成された記録をインポートできるプログラムがいくつか存在します。これらの記録は、請求金額の正確性の検証や統計の作成など、さまざまな目的で使用されます。

## Objectives

この章を読み終えることで、読者は以下のことができるようになります。

- レコードがどこで、どのような形式で生成されるかを説明する
- ODBC (Open Database Connectivity) を使用してレコードを生成する
- 課金システムと統合された認証スキームを実装する

## Asterisk CDRフォーマット

Asteriskは、各通話に対して通話詳細記録（CDR）を生成します。これらの記録はデフォルトで、/var/log/asterisk/cdr-csvにあるカンマ区切り値（CSV）形式のテキストファイルに保存されます。ファイルは以下のフィールドで構成されています。

| フィールド | 説明 | 型 |
|-------|-------------|------|
| Accountcode | 使用するアカウント番号 | String |
| Src | 発信者ID番号 | String |
| Dst | 宛先extension | String |
| Dcontext | 宛先context | String |
| Clid | テキスト付き発信者ID | String |
| Channel | 使用されたチャネル | String |
| Dstchannel | 宛先チャネル | String |
| Lastapp | 最後に実行されたアプリケーション | String |
| Lastdata | 最後に実行されたアプリケーションのデータ | String |
| Start | 通話開始時刻 | Date/Time |
| Answer | 通話応答時刻 | Date/Time |
| End | 通話終了時刻 | Date/Time |
| Duration | ダイヤルから切断までの時間 | Integer (seconds) |
| Billsec | 応答から切断までの時間 | Integer (seconds) |
| Disposition | 通話の結果 (ANSWERED, NO ANSWER, BUSY, FAILED, CONGESTION) | String |
| Amaflags | フラグ (DEFAULT, OMIT, BILLING, DOCUMENTATION) | String |
| Userfield | ユーザー定義フィールド | String |

CSVファイルのサンプルです。各行が1つのレコードであり、フィールドは上記の表と同じ順序で並んでいます（`accountcode`が最初、`amaflags`が最後です）。

```text
# accountcode,src,dst,dcontext,clid,channel,dstchannel,lastapp,lastdata,
#   start,answer,end,duration,billsec,disposition,amaflags
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-5f30","PJSIP/8584-9153","Dial","PJSIP/8584,30,tT","2006-03-27 16:05:00","2006-03-27 16:05:00","2006-03-27 16:05:00","0","0","ANSWERED","DOCUMENTATION"
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-96f5","PJSIP/8584-3312","Dial","PJSIP/8584,30,tT","2006-03-27 16:16:00","2006-03-27 16:16:00","2006-03-27 16:16:00","0","0","ANSWERED","BILLING"
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-74ac","PJSIP/8584-297b","Dial","PJSIP/8584,30,tT","2006-03-27 16:22:00","2006-03-27 16:22:00","2006-03-27 16:22:00","0","0","ANSWERED","BILLING"
"1234","4830258576","2012348584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-2c5d","PJSIP/8584-9870","Dial","PJSIP/8584,30,tT","2006-03-27 16:37:00","2006-03-27 16:37:00","2006-03-27 16:37:00","0","0","ANSWERED","BILLING"
"1234","4830258584","2012348576","default","""Luis Sample"" <4830258584>","PJSIP/8584-03fd","PJSIP/8576-645c","Dial","PJSIP/8576,30,tT","2006-03-27 16:37:00","2006-03-27 16:37:00","2006-03-27 16:37:00","0","0","ANSWERED","BILLING"
```

## アカウントコードと自動メッセージアカウンティング

各チャネルに対して、アカウントコードと ama フラグを指定することができます。通常、これはチャネル設定ファイル（例: chan_dahdi.conf, pjsip.conf）で行われます。amaflags パラメータは、CDR レコードの扱いを定義します。amaflag に指定可能な値は以下の通りです。

- Default
- Omit
- Billing
- Documentation

レコードを課金用やドキュメント用にフラグ付けするのと同様に、各レコードにアカウントコードを設定できます。アカウントコードは自由形式の文字列であり（`accountcode` endpoint オプションは任意の String を受け取り、CDR レコードはそれを80文字のフィールドに格納します）、通常はレコードを部門やビジネスユニットに割り当てるために使用されます。例：pjsip.conf の endpoint セクション

```
[8576]
type=endpoint
accountcode=Support
```

AMA フラグは Asterisk 22 においては`pjsip.conf` endpoint オプションではありません。通話ごとに dialplan から`CHANNEL`関数（例：`Set(CHANNEL(amaflags)=billing)`）を使用して設定するか、または`Set(CDR(amaflags)=billing)`を使用して設定してください。

## CSVおよびCDRフォーマットの変更

cdr_custom.confファイルを変更することで、CSVフォーマットを変更できます。

```
;
; Mappings for custom config file
;
[mappings]
Master.csv =>
"${CDR(clid)}","${CDR(src)}","${CDR(dst)}","${CDR(dcontext)}","${CDR(channel)}"
,"${CDR(dstchannel)}","${CDR(lastapp)}","${CDR(lastdata)}","${CDR(start)}","${C
DR(answer)}","${CDR(end)}","${CDR(duration)}","${CDR(billsec)}","${CDR(disposit
ion)}","${CDR(amaflags)}","${CDR(accountcode)}","${CDR(uniqueid)}","${CDR(userf
ield)}"
```

cdr_custom.confファイル内でCDRフォーマットを変更することが可能です。

## CDR Storage

CDRの保存にはいくつかの方法があります。最も重要な方法は、スプレッドシートに簡単にインポートできるCSVテキストファイルを使用することです。小規模なビジネスであれば、通常はこれで十分です。一部の課金ソフトウェアは、デフォルトでCSVファイルを受け入れます。しかし、CDRをデータベースに保存する方がはるかに優れており、安全です。Asteriskはいくつかのデータベースの種類をサポートしています。市場には課金用のグラフィカルなインターフェースもいくつか存在します。これほど多くのドライバがある中で、どれを選択すべきでしょうか？

### 利用可能なストレージドライバ

- cdr_csv – カンマ区切り値テキストファイル
- cdr_custom – カスタマイズ可能なカンマ区切り値テキストファイル
- cdr_adaptive_odbc – Adaptive ODBCバックエンド（データベース保存に推奨）
- cdr_odbc – unixODBCサポートデータベース（レガシー、cdr_adaptive_odbcが推奨）
- cdr_pgsql – Postgresデータベース
- cdr_tds (cdr_freetds) – FreeTDS経由のSybaseおよびMSSQLデータベース
- cdr_manager – Manager InterfaceへのCDR出力
- cdr_radius – CDR RADIUSインターフェース
- cdr_sqlite3_custom – SQLite3カスタムCDRモジュール

古いガイドで推奨されていた`cdr_addon_mysql` (cdr_mysql) モジュールはAsterisk 19で削除されたため、Asterisk 22にはネイティブのMySQL CDRドライバは存在しません。CDRをMySQL/MariaDBに書き込むには、本章で使用するアプローチである、MySQL ODBCドライバと組み合わせた`cdr_adaptive_odbc`を使用してください。

CDRの記録は、/etc/asterisk/modules.confファイルに読み込まれているすべてのアクティブなモジュールに対して行われます。パラメータautoload=yesが設定されている場合、すべてのモジュールが読み込まれます。現在システムにどのcdr_driversが読み込まれているかを確認するには、以下のコマンドを使用します。

```
asterisk*CLI> module show like cdr_
Module                 Description                              Use Count  Status
Support Level
cdr_adaptive_odbc.so   Adaptive ODBC CDR backend                0          Running
core
cdr_csv.so             Comma Separated Values CDR Backend       0          Running
extended
cdr_custom.so          Customizable Comma Separated Values CDR  0          Running
core
cdr_manager.so         Asterisk Manager Interface CDR Backend   0          Running
core
cdr_odbc.so            ODBC CDR Backend                         0          Running
extended
cdr_sqlite3_custom.so  SQLite3 Custom CDR Module                0          Not Running
extended
6 modules loaded
```

上記のスクリーンショットが表示されていれば、少なくともcdr_adaptive_odbc、cdr_csv、cdr_custom、cdr_manager、cdr_odbc、およびcdr_sqlite3_customが実行されています。近年のAstriconを経て、AsteriskチームがODBCを推奨していることが私にとって明確になりました。これはコネクションプーリングをサポートする唯一のドライバです。コネクションプーリングは、操作のたびに新しい接続を開く必要がないため、パフォーマンスの面で大きな利点があります。本章は以前cdr_mysqlを使用して執筆されていましたが、設定が少し複雑であることを承知の上で、今回の版ではcdr_adaptive_odbcに移行しました。cdr_adaptive_odbcを選択することで、CDRをカスタマイズすることも可能になります。dialplanで新しいCDR変数を設定し、対応するカラムをデータベースに追加するだけで済みます。例えば、音声のjitterを記録するには以下のようにします。

```
Set(CDR(jitter)=${RTPAUDIOQOSJITTER})
```

### CSV Storage

前述の通り、デフォルトではAsteriskはcdr_csv.soモジュールを使用してすべてのCDRをCSVテキストファイルに送信します。/var/log/asterisk/cdr-csvにファイルが見当たらない場合は、CLIコマンドmodule showを使用してモジュールが読み込まれているか確認してください。読み込まれていない場合は、modules.confを確認してください。本章では、バックアップとしてcdr_csvにもCDRを送信します。

### Configuring the file modules.conf

適切なモジュールのみを読み込むには、modules.confファイルに以下の行を使用します。

```
noload => cdr_custom.so
noload => cdr_odbc.so
noload => cdr_manager.so
noload => cdr_sqlite3_custom.so
```

これで、cdr_csvとcdr_adaptive_odbcのみが読み込まれた状態になります。

## Ubuntu 22.04へのODBCのインストールと設定

書籍に詳細な手順を掲載することは、常に後悔を伴うものです。書籍が出版されるよりも早く手順が変わってしまうことがあるからです。バージョンやモジュールは変更されるため、ここにあるコマンドを自身の状況に合わせて調整してください。ほとんどの場合、わずかな変更でインストールを再現できます。経験豊富なLinuxユーザーであってもODBCドライバーのインストールは難しいと感じる可能性があるため、各ステップに注意を払ってください。

ステップ 1 - 必要なパッケージをインストールします：

```
apt-get install mysql-server unixodbc unixodbc-dev libltdl-dev libtool
```

ステップ 2 - データベースとユーザーを作成します：

```
mysql -u root -p
```

(mysqlサーバー作成時に定義したパスワードを使用してください) mysqlコマンドラインで以下のコマンドを入力します。

```
CREATE USER 'astdb'@'%' IDENTIFIED BY 'supersecret';
CREATE DATABASE cdr;
GRANT ALL PRIVILEGES ON cdr.* TO 'astdb'@'%';
FLUSH PRIVILEGES;
EXIT
```

ステップ 3 - データベースを作成します。

```
cd /usr/src/asterisk-22.*/contrib/scripts/realtime/mysql
mysql -u root -p astdb <mysql_cdr.sql
```

ステップ 4: OracleからMySQL ODBCコネクタをダウンロードします。以下のコマンドでオペレーティングシステムを確認してください：`lsb_release -a`。Ubuntu 22.04 (x86_64) の場合は、https://dev.mysql.com/downloads/connector/odbc/ にアクセスし、Ubuntu 22.04向けの最新の 8.x または 9.x リリースを選択してください。正確なファイル名やバージョン番号は時間とともに変化するため、以下の`VER`には現在のLinux glibcビルドの名称を設定してください。

```
cd /usr/src
# Pick the current Linux (glibc) build for your platform from
# https://dev.mysql.com/downloads/connector/odbc/ and set VER to its name:
VER=mysql-connector-odbc-9.0.0-linux-glibc2.28-x86-64bit
wget https://dev.mysql.com/get/Downloads/Connector-ODBC/9.0/$VER.tar.gz
tar -xzvf $VER.tar.gz
```

ステップ 5: ODBCドライバーをインストールします。

```
cd /usr/src/$VER
cp bin/* /usr/local/bin
cp lib/* /usr/local/lib
myodbc-installer -a -d -n "MySQL" -t "Driver=/usr/local/lib/libmyodbc9w.so"
```

ステップ 6 - ODBCコネクタを設定します。/etc/odbc.ini ファイルを編集してDSN (Data Source Name) を作成します。

```
[astconn]
Description = MySQL connector for astdb database
Driver = /usr/local/lib/libmyodbc9w.so
Database = astdb
Server = localhost
Port = 3306
```

ステップ 7: iSQLを使用してドライバーのアクセスをテストします。iSQLは、unixodbc経由でデータベースに接続するためのコマンドラインユーティリティです。

```
isql -v astconn astdb supersecret
>show tables
```

isqlコマンドの結果が確認できない場合は、Asteriskの設定に進まないでください。

### AsteriskでのODBC設定

cdr_adaptive_odbcを設定する前に、まずODBCリソースファイルを設定する必要があります。

ステップ 1 - AsteriskをODBCに接続します。res_odbc.conf ファイルを編集します：

```
[cdr]
enabled => yes
dsn => astconn
username => astdb
password => supersecret
pre-connect => yes
```

ステップ 2 – Asteriskを再起動し、以下を使用してテストします。

```
asterisk*CLI> odbc show
```

出力結果は以下の通りです。

```
asterisk*CLI> odbc show
ODBC DSN Settings
-----------------
Name:   cdr
DSN:    astconn
  Number of active connections: 1 (out of 20)
```

ステップ 3 – /etc/asterisk/cdr_adaptive_odbc.conf でadaptive ODBCドライバーを設定します。

```
[cdr]
connection=cdr
table=cdr
```

ここで`connection`は`res_odbc.conf`で定義された`[cdr]`接続セクションを指し、`table`はCDRが書き込まれるデータベーステーブルです。

ステップ 4 – cdr_adaptive_odbc.so モジュールをリロードします：

```
asterisk*CLI> reload cdr_adaptive_odbc
```

ステップ 5 – いくつか通話を行い、データベースに新しいレコードがあるか確認します。データベースを確認するには以下を実行します：

```
mysql -u root -p
>use astdb
>select * from cdr;
```

## アプリケーションと関数

課金に関連するアプリケーションがいくつか存在します。

### CDR(accountcode)

dial() アプリケーションを呼び出す前にアカウントコードを設定します。例: 形式:

```
Set(CDR(accountcode)=account)
```

アカウントコードは、チャネル変数 ${CDR(accountcode)} を使用して確認できます。

### CDR(amaflags)

課金目的のフラグを設定します。オプションには default、omit、documentation、billing があります。

```
Set(CDR(amaflags)=amaflags)
```

### Set(CDR_PROP(disable)=1)

現在のチャネルの CDR 記録を無効にします。これにより、ファイルやデータベースに CDR が書き込まれなくなります。これを `0` に戻すと、記録が再度有効になります。

```
Set(CDR_PROP(disable)=1)
```

以前の版でこれに使用されていた `NoCDR()` アプリケーションは Asterisk 21 で削除されました。Asterisk 22 では、代わりに `Set(CDR_PROP(disable)=1)` を使用してチャネルの CDR を無効にします。

### ResetCDR()

Call Data Record をリセットします。すなわち、開始時刻（`start`）および（応答済みであれば）応答時刻（`answer`）が現在時刻に設定され、すべての CDR 変数が消去されます。もし `v` オプションが設定されている場合、リセット中も CDR 変数は保持されます。

### Set(CDR(userfield)=Value)

このコマンドは、CDR 内のユーザーフィールドを設定します。`cdr_adaptive_odbc` を使用する場合、CDR テーブルに `userfield` カラムが存在すれば、ソースコードの再コンパイルなしでユーザーフィールドが自動的に保存されます。CSV テキストファイルの場合、ユーザーフィールドを使用するにはソースコード (cdr_csv.c) を編集し、Asterisk を再コンパイルする必要があります。

以前の版では、`cdr_addon_mysql` モジュール (`cdr_mysql.conf`) を使用して MySQL に CDR を保存していました。そのモジュールは Asterisk 19 で削除されたため、Asterisk 22 では利用できません。現在サポートされているパスは、MySQL ODBC ドライバを使用した `cdr_adaptive_odbc` です。これは、アダプティブカラムマッピングを通じて、ユーザーフィールドやその他のカスタムカラムをネイティブに保存します。

### ユーザーフィールドへの追記

以前の版では、CDR ユーザーフィールドにデータを追記するために `AppendCDRUserField()` アプリケーションを使用していました。そのアプリケーションは Asterisk から削除されました。Asterisk 22 では、ユーザーフィールドを読み取ってから `CDR` 関数で再設定することで追記を行います。例: `Set(CDR(userfield)=${CDR(userfield)}extra)`。

![13-call-detail-records figure 1](../images/13-call-detail-records-img01.png)

## ユーザー認証

一部の企業では、従業員に対して通話料金を請求しています。Asteriskでは、認証されたユーザーをCDR（通話詳細記録）上で課金対象にできる認証スキームを設定可能です。この認証は、Authenticateアプリケーションにパラメータとして渡されるパスワードを使用して実行できます。パスワードは、パラメータの前に / （スラッシュ）を付けることで指定するパスワードファイル、またはAsteriskデータベースキー（`d`オプションを使用）のいずれかとなります。形式は以下の通りです。

```
Authenticate(password[,options[,maxdigits[,prompt]]])
Authenticate(/passwdfile[,options])
```

オプション:

- a – チャネルのaccount codeを入力されたパスワードに設定します。
- d – 指定されたパスをリテラルなファイルではなく、Asterisk DBキーとして解釈します。
- m – パスを`accountcode:passwordhash`行のファイルとして解釈します。
- r – 認証成功後にデータベースキーを削除します（`d`との併用時のみ有効）。

発信者が3回試行しても認証に失敗した場合、チャネルは切断されます。dialplanの実行は継続されないため、失敗時の処理は`Authenticate()`の次の行で行う必要があります。例（国際電話）:

```
exten=_9011.,1,Authenticate(/password,d)
 same=>n,Dial(DAHDI/g1/${EXTEN:1},20,tT)
 same=>n,Hangup()
```

古い`j`オプション（失敗時に優先度 n+101 へジャンプする機能）および`+101`優先度の慣習は、ずっと前にAsteriskから削除されました。失敗した`Authenticate()`は単に切断されます。

コンソールからDBキーにパスワードを挿入するには、以下のようにします:

```
asterisk*CLI> database put senha 123456 1
```

## ボイスメールのパスワードを使用する

このアプリケーションは authenticate と同様の動作を行いますが、パスワードの照合に voicemail の設定ファイルを使用します。

```
VMAuthenticate([mailbox][@context][,options])
```

メールボックスが指定された場合、そのメールボックスのパスワードのみが有効とみなされます。メールボックスが指定されていない場合、認証されたメールボックスがチャネル変数 `${AUTH_MAILBOX}` に設定されます。オプション `s` が設定されている場合、初期プロンプトはスキップされます。例（国際電話）：

```
exten=_9011.,1,VMAuthenticate(${CALLERID(num)}@local,s)
 same=>n,Dial(DAHDI/g1/${EXTEN:1},20,tT)
 same=>n,Hangup()
```

## Channel Event Logging (CEL)

CDRレコードは、通話ごとに1行の要約を提供します。個々のチャネル状態の遷移、ブリッジへの参加/退出イベント、アテンデッド転送のレグなど、より詳細なイベント追跡のために、Asterisk 22には **Channel Event Logging (CEL)** が含まれており、これは `/etc/asterisk/cel.conf` を介して設定され、 `cel_odbc` や `cel_custom` といったバックエンドを通じて保存されます。

CELはCDRを置き換えるものではなく、補完するものです。CDRは課金要約の標準として残り、CELは不正検出、品質監視、高度なレポート作成に役立つ詳細なイベントごとのデータを提供します。

`cel.conf` の設定パターンは `cdr.conf` を模倣しています。まず `cel.conf` の `[general]` セクションで必要なイベントタイプを有効にし、次に各ストレージバックエンドをそれぞれのファイルで設定します。CSVの場合は `cel_custom.conf` 、ODBCデータベース（CDRで使われるものと同じ `res_odbc.conf` 接続）の場合は `cel_odbc.conf` を使用します。CELがアクティブかどうかは、CLI上で `cel show status` を実行して確認できます。

## まとめ

本章では、テキストファイルおよび MySQL データベースに CDR を記録する実装方法を学びました。また、amaflags と account codes の設定方法についても学習しました。章の最後では、CDR および課金システムと統合された認証スキームの使用方法を学びました。

## クイズ

1. デフォルトでは、AsteriskはCDRを /var/log/asterisk/cdr-csv ディレクトリに記録します。
   - A. 偽
   - B. 真
2. AsteriskがCDRを書き込める先はどれですか（該当するものすべてを選択してください）：
   - A. MySQL
   - B. Native Oracle
   - C. Microsoft SQL Server
   - D. CSVテキストファイル
   - E. unixODBCでサポートされているデータベース
3. Asteriskは一度に1種類のストレージに対してのみCDRを生成します。
   - A. 偽
   - B. 真
4. 利用可能なAsteriskのamaflagsはどれですか？
   - A. DEFAULT
   - B. OMIT
   - C. TAX
   - D. RATE
   - E. BILLING
   - F. DOCUMENTATION
5. 部門をCDRに関連付けるには ___ コマンドを使用し、アカウントコードは ___ チャネル変数で読み取ることができます。
6. `Set(CDR_PROP(disable)=1)` と `ResetCDR()` の違いは、CDRを無効にするとレコードの書き込みが一切行われなくなるのに対し、 `ResetCDR()` は現在のレコードをリセット（ゼロクリア）する点です。（以前CDRを無効にしていた `NoCDR()` アプリケーションは、Asterisk 21で削除されました。）
   - A. 偽
   - B. 真
7. `cdr_csv.so` モジュールでユーザー定義フィールドを使用するには、ソースコードを編集してAsteriskを再コンパイルする必要があります。
   - A. 偽
   - B. 真
8. Authenticate() アプリケーションで利用可能な3つの認証方法はどれですか：
   - A. パスワード
   - B. パスワードファイル
   - C. Asterisk DB (dbput および dbget)
   - D. Voicemail
9. Voicemailのパスワードは `voicemail.conf` の別のセクションで指定され、Voicemailユーザーのものとは異なります。
   - A. 偽
   - B. 真
10. Channel Event Logging (CEL) はAsterisk 22でCDRに取って代わります。CELが有効になると、CDRの課金サマリーは生成されなくなります。
    - A. 偽
    - B. 真

**回答:** 1 — B · 2 — A, B, C, D, E · 3 — A · 4 — A, B, E, F · 5 — `Set(CDR(accountcode)=...)`; `${CDR(accountcode)}` · 6 — B · 7 — A · 8 — A, B, C · 9 — B · 10 — A
