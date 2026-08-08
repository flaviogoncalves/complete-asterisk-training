# Asterisk Real-Time

ご存知の通り、Asteriskの設定は /etc/asterisk ディレクトリにある複数のテキストファイルを使用して行われます。テキストファイルを使用することには手軽さがある一方で、以下のような既知の欠点も存在します。

- ファイルを変更するたびに Asterisk をリロードする必要がある
- 大量のユーザーを扱う場合にメモリ使用量が増加する
- テキストファイルを使用してプロビジョニングインターフェースをコーディングするのが困難である
- 既存のデータベースとの統合ができない

ARA（Asterisk Realtime）は、Anthony Minessale II、Mark Spencer、および Constantine Filin によって作成され、SQLデータベースとの透過的な統合を可能にするように設計されました。LDAPインターフェースも利用可能です。このシステムは Asterisk External Configuration としても知られており、/etc/asterisk/extconfig.conf で設定されます。設定ファイルをデータベース内のテーブルにマッピング（静的設定）したり、Asterisk をリロードすることなくオブジェクトを動的に作成するためのリアルタイムエントリを使用したりすることができます。

## Objectives

この章を読み終えることで、読者は以下のことができるようになります。

- Asterisk Real Timeの利点と制限を理解する。
- ARAで使用するためにODBCを使用する。
- ODBCを使用してARAをコンパイルおよびインストールする。
- ラボ環境でシステムをテストする。

## Asterisk Real Timeはどのように動作するか？

新しいReal Timeアーキテクチャでは、データベース固有のコードはすべてチャネルドライバに移動されました。チャネルは、データベースを検索する汎用的なルーチンを呼び出すだけです。その結果、ソースコードの観点から見ると、はるかにシンプルでクリーンなプロセスになっています。データベースには、以下の3つの関数によってアクセスされます。

- STATIC: モジュールがロードされたときに静的な設定をセットアップするために使用されます。
- REALTIME: 通話中やその他のイベント中にオブジェクトを検索するために使用されます。
- UPDATE: オブジェクトを更新するために使用されます。

Asterisk 22では、SIP endpointは**Sorcery**オブジェクトモデル上に構築された**PJSIP**スタック（`res_pjsip`）によって処理されます。Sorceryは`realtime`ウィザードを使用して、各PJSIPオブジェクトをデータベースからオンデマンドでロードします。これらのオブジェクトは、古いSIPドライバが通話のたびに破棄していた使い捨てのrealtimeピアではなく、通常の構成済みPJSIPオブジェクトとして存在します。

これらは実在するオブジェクトであるため、NAT traversal、qualify、およびmessage waiting indication（MWI）はすべて、realtime endpointに対して正常に機能します。（Sorceryには、追加で`memory_cache`ウィザードを介してオブジェクトをメモリにキャッシュするように指示することもできますが、これはオプトインであり、realtimeロードとは別個の機能です。）データベース内のオブジェクトを変更すると、次回の検索時にその変更が反映されます。編集のたびにリロードする必要はありません。（`sippeers`/`sipusers`ファミリーを使用した、廃止された`chan_sip`realtimeモデルについては、*Legacy Channels*の章でのみ扱います。）

## Asterisk Real Timeの設定

このラボでは、CDRの章でODBCがすでにインストールされていることを前提とします。ARAは `extconfig.conf` テキストファイルで設定され、そこでは2つのセクションが容易に確認できます。最初のセクションは静的設定ファイルセクションであり、テキスト設定ファイルをデータベーステーブルに置き換えることができます。2番目のセクションはrealtime設定エンジンであり、動的オブジェクト（peers/users）用のデータベーステーブルを設定します。静的設定にはテキストファイルを、動的エントリにはデータベースを使用することは珍しくありません。この場合、最初のセクションはそのまま変更せずに残します。

```
extconfig.conf file format:
;
; Static and realtime external configuration
; engine configuration
;
; Please read doc/README.extconfig for basic table
; formatting information.
```

![Asterisk Real Timeアーキテクチャ：設定ファイルと静的データベーステーブルはAsteriskの起動時に読み込まれますが、realtimeデータベーステーブルは通話中に必要に応じて読み込まれる動的な設定を提供します。]((../images/18-realtime-fig01.png))

```
;
[settings]
;
; Static configuration files:
;
; file.conf => driver,database[,table]
;
; maps a particular configuration file to the given
; database driver, database and table (or uses the
; name of the file as the table if not specified)
;
;uncomment to load queues.conf via the odbc engine.
;
;queues.conf => odbc,asterisk,ast_config
;
; The following files CANNOT be loaded from Realtime storage:
;       asterisk.conf
;       extconfig.conf (this file)
;       logger.conf
;
; Additionally, the following files cannot be loaded from
; Realtime storage unless the storage driver is loaded
; early using 'preload' statements in modules.conf:
;       manager.conf
;       cdr.conf
;       rtp.conf
;
; Realtime configuration engine
;
; maps a particular family of realtime
; configuration to a given database driver,
; database and table (or uses the name of
; the family if the table is not specified
;
;example => odbc,asterisk,alttable
;ps_endpoints => odbc,asterisk
;ps_aors => odbc,asterisk
;ps_auths => odbc,asterisk
;ps_contacts => odbc,asterisk
;voicemail => odbc,asterisk
;extensions => odbc,asterisk
;queues => odbc,asterisk
;queue_members => odbc,asterisk
```


### 静的設定セクション

静的設定セクションは、設定ファイルと同等の内容をデータベースに保存する場所です。これらの設定は Asterisk の読み込み時に読み取られます。一部のモジュールは、リロード時にデータベースを再読み込みします。静的設定の例は以下の通りです。

```
<conf filename> => <driver>,<databasename>[,table_name]
queues.conf => mysql,asteriskdb,queues_conf
pjsip.conf => odbc,asteriskdb,pjsip_conf
iax.conf => ldap,MyBaseDN,iax
```

静的ファイルマッピングは、オブジェクトごとのrealtime相当が存在しない設定ファイルに対して最も有用です。PJSIPについては、本章の後半で説明するオブジェクトごとのrealtimeファミリー（`ps_endpoints`、`ps_aors`など）を使用することを推奨します。これらを`pjsip.conf`全体を静的ファイルとしてマッピングするよりも優先してください。

上記には3つの例が記載されています。最初の例では、queues.confをasteriskdbデータベース内のqueuesテーブルにバインドしています。2番目の例では、pjsip.confをodbc設定で定義されたデータベースasteriskdb内のpjsip_confテーブルにバインドしています。最後の例では、iax.confをLDAPディレクトリにバインドしています。MyBaseDNは検索対象となるベースDNです。前の例では、MySQLドライバがデータベースにクエリを実行して必要な情報を取得する間、アプリケーションapp_queue.soが読み込まれます。

### Real Time設定セクション

Real Time設定（extconfig.confファイルの後半部分）は、読み込まれる設定パーツをリアルタイムで設定、更新、およびアンロードするための場所です。Real Timeを使用する場合、設定をリロードする必要はありません。Real Timeの構文は以下の通りです。

```
<family name> => <driver>,<database name>[,table_name]
```

申し訳ありませんが、翻訳対象となるMarkdownテキストが入力されていないようです。翻訳したいテキストを貼り付けていただければ、指定されたルールに従って直ちに翻訳いたします。

```
ps_endpoints => odbc,asterisk,ps_endpoints
ps_aors => odbc,asterisk,ps_aors
queues => odbc,asterisk,queue_table
queue_members => odbc,asterisk,queue_member_table
voicemail => odbc,asterisk,test
```

ここでは5つの設定行を紹介します。最初の行では、PJSIP/Sorceryファミリーの`ps_endpoints`をasteriskdbデータベース内のテーブル`ps_endpoints`にバインドします。最後の行では、voicemailファミリーをasteriskdbデータベース内のtestテーブルにバインドします。各PJSIPオブジェクトタイプ（endpoint、aor、auth、contact）にはそれぞれ独自のファミリーとテーブルが割り当てられます。完全なセットは以下の「PJSIP Realtime (Sorcery)」セクションに示されています。`voicemail`、`extensions`、`queues`、および`queue_members`の各ファミリーは、Asterisk 22でも引き続き有効です。

## PJSIP Realtime (Sorcery)

Asterisk 22では、SIP endpointはすべて **PJSIP** スタック（`res_pjsip`）によって処理されます。これは **Sorcery** オブジェクト抽象化レイヤー上に構築されています。PJSIPでは、単一のSIP「ピア」ではなく、SIPアカウントをいくつかのオブジェクトタイプに分割し、それぞれを独自のrealtimeテーブルに格納します。

| Sorcery object type | Realtime table | What it holds |
|---------------------|----------------|---------------|
| endpoint | ps_endpoints | アカウントごとの設定 (context, codecs, DTMFなど) |
| aor (address of record) | ps_aors | 登録制限および `qualify` 設定 |
| auth | ps_auths | `username` / `password` 認証情報 |
| contact | ps_contacts | 動的に登録された場所 |
| domain alias | ps_domain_aliases | endpoint用の代替SIPドメイン |
| endpoint identifier by IP | ps_endpoint_id_ips | 送信元IPによるendpointの照合 |

PJSIPのrealtimeは2箇所で有効化します。まず、Sorceryオブジェクトタイプを`extconfig.conf`でrealtimeにマッピングします。

```
[settings]
ps_endpoints => odbc,asterisk
ps_aors => odbc,asterisk
ps_auths => odbc,asterisk
ps_contacts => odbc,asterisk
ps_domain_aliases => odbc,asterisk
ps_endpoint_id_ips => odbc,asterisk
```

次に、それらのオブジェクトタイプに対して`realtime`ウィザードを使用するよう`sorcery.conf`でSorceryに指示します。マッピング名（ここでは`res_pjsip`）はオブジェクトを移行するモジュールであり、右側の値は`extconfig.conf`で定義したファミリーを指します。

```
[res_pjsip]
endpoint=realtime,ps_endpoints
aor=realtime,ps_aors
auth=realtime,ps_auths
domain_alias=realtime,ps_domain_aliases
contact=realtime,ps_contacts

[res_pjsip_endpoint_identifier_ip]
identify=realtime,ps_endpoint_id_ips
```

静的オブジェクトとrealtimeオブジェクトを混在させることも可能です。`sorcery.conf`からタイプを省略した場合、そのオブジェクトタイプは引き続き`pjsip.conf`から読み込まれます。一般的なパターンとして、静的なtransportsやグローバル設定は`pjsip.conf`に保持し、endpoints、aors、auths、contactsはデータベースに格納する方法があります。

### Alembicを使用したPJSIP realtimeスキーマの作成

Asteriskには、すべてのrealtimeスキーマ用のデータベースマイグレーションが`contrib/ast-db-manage`に含まれています。これがPJSIPテーブルを作成（およびバージョンアップグレード）するためのサポートされた方法であり、手動で`ps_*`のテーブル定義を記述する必要はもうありません。`config`マイグレーションセットには、PJSIP/Sorceryテーブルが含まれています。

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# edit config.ini → set sqlalchemy.url, e.g.
#   sqlalchemy.url = mysql+pymysql://astdb:CHANGE_ME_DB_PASSWORD@127.0.0.1/astdb
alembic -c config.ini upgrade head
```

これにより、実行中のAsteriskバージョンに適したカラムを持つ`ps_endpoints`、`ps_aors`、`ps_auths`、`ps_contacts`およびその他のPJSIPテーブルが作成されます。（AlembicにはPythonの`alembic`パッケージに加え、MySQL/MariaDB用の`pymysql`やPostgreSQL用の`psycopg2`といったSQLAlchemyドライバが必要です。）

最小限のrealtime endpointは、3つのテーブルのそれぞれに1行ずつ、例えばendpoint`6010`のように構成されます。

```
ps_auths:      id=6010-auth, auth_type=userpass, username=6010, password=supersecret
ps_aors:       id=6010, max_contacts=1
ps_endpoints:  id=6010, transport=transport-udp, aors=6010, auth=6010-auth,
               context=from-internal, disallow=all, allow=ulaw,
               direct_media=no
```

行を挿入した後はリロードの必要はありません。次のREGISTER/INVITEでデータベースからオブジェクトが取得されます。realtimeが何を返したかは、以下のコマンドで確認できます。

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

## データベース設定

extconfig.conf ファイルの設定が完了したので、次はテーブルを作成しましょう。一般的に、各データベースの列は対応する設定ファイルのオプション名と一致します。PJSIP の `ps_*` テーブルはこのルールに従っており、すべての `ps_endpoints` 列は `pjsip.conf` endpoint オプションにちなんで命名され、すべての `ps_auths` 列は auth オプションにちなんで命名されるといった具合です。例えば、以下の `pjsip.conf` endpoint は、

```
[4000](endpoint)
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=4000
aors=4000
```

3つのテーブルにまたがる1行として保存されます。`ps_endpoints` 行は `id=4000, context=from-internal, disallow=all, allow=ulaw, auth=4000, aors=4000` を保持し、`ps_auths` 行は `id=4000, auth_type=userpass, username=4000, password=supersecret` を保持し、`ps_aors` 行は `id=4000, max_contacts=1` を保持します。実際に使用する列のみを入力すればよく、NULL のままにした列はオプションのデフォルト値にフォールバックされます。例えば、endpoint で `callerid` パラメータを使用したい場合は、`ps_endpoints` の `callerid` 列に入力します（列名は `pjsip.conf` オプション名と同じです）。

voicemail テーブルも同じ考え方に基づいています。その列は `voicemail.conf` フィールドに対応しています。

| uniqueid | mailbox | context | password | email | fullname |
|----------|---------|---------|----------|-------|----------|
| 1 | 4000 | default | 4000 | john@doe.com | John Doe |

`uniqueid` は各 voicemail ユーザーに対して一意である必要があり、自動インクリメントにすることができます。mailbox や context との関係性を持つ必要はありません。

### Asterisk Real Time を使用した dialplan の構築

real-time システムを使用して dialplan を作成することも可能です。ARA は `switch` ステートメントを使用して、extensions.conf ファイルに含まれる通常の dialplan に real-time の extension を組み込みます。extension テーブルは以下のようになります。

| context | exten | priority | app | appdata |
|---------|-------|----------|-----|---------|
| from-internal | 4000 | 1 | Dial | PJSIP/4000 |

`extensions` realtime ファミリーは Asterisk 22 でも変更されていません。単に `appdata` 列が PJSIP チャネル（例：`PJSIP/4000`）をダイヤルするようにしてください。dialplan 内で real time を使用するには、`switch` コマンドを使用する必要があります。

![Asterisk Real Time を使用した dialplan の構築: extensions.conf は `switch => realtime` ステートメントを使用して、テキストファイルからではなくデータベーステーブルから extension 行（context, exten, priority, app, data）を取得します。]((../images/18-realtime-fig02.png))


```
[local]
switch => realtime
```

または

```
[local]
switch => realtime/from-internal@extensions
```

## Lab: データベーステーブルのインストールと作成

このラボでは、Asteriskのパラメータを受け入れるためのデータベースを準備します。ここではREALTIMEテーブルのみを準備します。静的な設定は設定テキストファイルに任せることにします（素晴らしいでしょう？）。以下にMySQLでのテーブル作成手順を示します。

ステップ 1: rootとしてMySQLデータベースにログインします。

```
mysql -u root -p
```

ステップ 2: CDRラボで作成したMySQLサーバーにログインします。

```
mysql -u astdb -p
```

パスワードを求められたら、supersecretと入力してください。

ステップ 3: 必要なテーブルを作成します。レガシーな静的スキーマファイルは依然として`contrib/realtime/`（例：`/usr/src/asterisk-22.x/contrib/realtime/mysql`）の下に同梱されていますが、Asterisk 22においてREALTIMEテーブル、特にPJSIP `ps_*`テーブルを構築するための推奨されるバージョン整合性の取れた方法は、`contrib/ast-db-manage`の下にある**Alembic**マイグレーションを使用することです（上記の「Alembicを使用したPJSIP REALTIMEスキーマの作成」セクションを参照してください）。

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# set sqlalchemy.url for your astdb database, then:
alembic -c config.ini upgrade head
```

Alembic `config`マイグレーションセットは、実行中のAsteriskバージョンが期待する正確なカラム構成でPJSIP `ps_*`テーブル（および`voicemail`、`extensions`、その他のREALTIMEスキーマ）を構築するため、スキーマは常にビルドと一致します。

パスワードにはsupersecretを使用してください。

ステップ 4: テーブルの作成を確認します。

```
mysql -u astdb -p astdb
mysql>use astdb;
mysql>show tables;
```

（Alembic `config`マイグレーションによって作成された）PJSIP `ps_*`テーブルと、それに加えて`voicemail`、`extensions`、およびその他のREALTIMEテーブルが表示されるはずです：

```
mysql> show tables;
+----------------------------+
| Tables_in_astdb            |
+----------------------------+
| ps_aors                    |
| ps_auths                   |
| ps_contacts                |
| ps_domain_aliases          |
| ps_endpoint_id_ips         |
| ps_endpoints               |
| ps_registrations           |
| extensions                 |
| voicemail                  |
+----------------------------+
```

（Alembicはこれらよりも多くのテーブルを作成しますが、上記のリストはこのラボに関連するものを示しています。）

ステップ 5: データベースは（CDRラボの時点で）すでにODBC用に設定されているため、ここでの追加のODBC設定は不要です。

ステップ 6: MySQLクライアントからテーブルを調査し、データを投入します。phpMyAdminのようなグラフィカルツールは必要ありません。この章のすべてのステップは、単純なコピー＆ペースト可能なSQLであり、`mysql`コマンドラインから実行します。`astdb`データベースに接続します（プロンプトが表示されたら`supersecret`を使用してください）：

```
mysql -u astdb -p astdb
```

いつでも`DESCRIBE`を使用してテーブルのカラムを確認できます。例：

```
mysql> DESCRIBE ps_endpoints;
mysql> DESCRIBE ps_auths;
mysql> DESCRIBE ps_aors;
```

これらのテーブルはAlembic `config`マイグレーションによって作成されたため、そのカラムは実行中のAsteriskバージョンの`pjsip.conf`オプション名とすでに一致しています。必要なカラムのみを埋めてください。

## ラボ: ARAの設定とテスト

このラボでは、データベース構成とテーブルを反映させるために `extconfig.conf` 設定を変更します。

ステップ 1: `extconfig.conf` を設定し、Asterisk をリロードします。

```
; Realtime configuration engine
;
; maps a particular family of realtime
; configuration to a given database driver,
; database and table (or uses the name of
; the family if the table is not specified
;
ps_endpoints => odbc,cdr
ps_aors => odbc,cdr
ps_auths => odbc,cdr
ps_contacts => odbc,cdr
voicemail => odbc,cdr,voicemail
extensions => odbc,cdr,extensions
```

上記の `ps_endpoints`、`ps_aors`、`ps_auths`、および `ps_contacts` ファミリーに注目してください。これらは対応する `sorcery.conf` マッピング（「PJSIP Realtime (Sorcery)」セクションを参照）と組み合わさることで、PJSIP がデータベースからアカウント情報を読み取れるようにします。また、`voicemail` および `extensions` ファミリーがこの例を補完します。

ステップ 2: Real Time エクステンションのテスト。各 `ps_auths`、`ps_aors`、および `ps_endpoints` に1行ずつ挿入して新しい `6010` endpoint を作成し、その endpoint を softphone で登録してみてください。以下の SQL を `mysql` クライアント（`mysql -u astdb -p astdb`）で実行します。

```sql
INSERT INTO ps_auths (id, auth_type, username, password)
VALUES ('6010-auth', 'userpass', '6010', 'supersecret');

INSERT INTO ps_aors (id, max_contacts)
VALUES ('6010', 1);

INSERT INTO ps_endpoints
  (id, transport, aors, auth, context, disallow, allow, dtmf_mode, direct_media)
VALUES
  ('6010', 'transport-udp', '6010', '6010-auth', 'from-internal',
   'all', 'ulaw', 'rfc4733', 'no');
```

これら3つの行を合わせて1つの SIP アカウントを記述します。残りのアカウント設定は PJSIP オブジェクト全体に分散しています。context、codec、DTMF モード、およびメディア処理は endpoint に存在し（上記の最後の6列）、動的な登録は AOR に存在します。個別の「dynamic」フラグは存在しません。AOR は `max_contacts` が 0 より大きい限り動的な REGISTER を受け入れ、登録された各場所は `ps_contacts` に書き込まれます。

PJSIP において、RFC 2833 / RFC 4733 の帯域外 DTMF モードは `rfc4733` と呼ばれ、デフォルトは `dtmf_mode=rfc4733` です。そのため、上記の `dtmf_mode` カラムはオプションであり、明確にするためだけに示されています。

ステップ 3: ユーザー名 `6010` とパスワード `supersecret` を使用して、新しい電話機を softphone で登録してみてください。Asterisk CLI で登録を確認します。

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

ステップ 4: データベースに extension を含めます。

```
mysql -u astdb -p
```

パスワードを入力してください:

求められたら supersecret と入力し、MySQL クライアントから extension の行を挿入します。

```sql
USE astdb;
INSERT INTO extensions (id, context, exten, priority, app, appdata)
VALUES ('1', 'test', '6007', '1', 'Dial', 'PJSIP/bria');
```

ステップ 5: dialplan に Asterisk Real Time を含めます。context `default` において以下のようにします。

```
switch => realtime/test@extensions
```

変更を有効にするために extensions をリロードします。

```
asterisk-server*CLI> extensions reload
```

ステップ 6: まだ行っていない場合は、電話機のいずれかをユーザー名 `bria` に再設定します。

ステップ 7: 既存の電話機から 6007 にダイヤルします。`bria` の電話機が鳴るはずです。

## まとめ

本章では、Asterisk Real Timeを使用することで設定をデータベースに格納できることを学びました。Asteriskには、ODBC（MySQL/MariaDBやSQLiteを含む、UnixODBCがサポートするあらゆるデータベースに接続可能）およびPostgreSQL用のネイティブなrealtimeドライバが標準で付属しており、さらにディレクトリバックエンド用のLDAP realtimeドライバも用意されています。本章で行ったように、MySQL/MariaDBにはODBC経由で接続します（専用の`res_config_mysql`アドオンも存在しますが、これはコアビルド外で提供されるため、ODBCを使用するのが一般的な手法です）。設定は静的設定とrealtime設定に分かれています。静的設定は設定ファイルを置き換えるものですが、realtime設定は通話やその他の関連イベントが発生したときにのみ読み込まれる動的なオブジェクトを作成します。最後に、ARAのインストールと設定方法に関する実践的なラボを行いました。

## クイズ

1. Asterisk Realtimeは、標準のAsteriskディストリビューションの一部です。
   - A. 正
   - B. 誤
2. データベースサーバーの接続パラメータは、どのファイルで設定されますか？
   - A. extensions.conf
   - B. pjsip.conf
   - C. res_odbc.conf
   - D. extconfig.conf
3. `extconfig.conf`ファイルは、Realtimeで使用されるテーブルを設定します。これには2つの異なるセクションがあります（2つ選択してください）：
   - A. 静的設定 (Static configuration)
   - B. Realtime設定 (Realtime configuration)
   - C. アウトバウンドルート
   - D. IPアドレスとデータベースポート
4. 静的設定では、オブジェクトがデータベースから読み込まれると、Asteriskのメモリ内に保持され、起動時またはリロード時にのみ更新されます。
   - A. 正
   - B. 誤
5. PJSIP realtime (Sorcery) は、Realtimeのendpointに対して`qualify`とMWIを完全にサポートしています。これは、Sorceryが古いSIP realtimeのpeerのように通話ごとに破棄するのではなく、通常のPJSIP設定オブジェクトとして読み込むためです。
   - A. 正
   - B. 誤
6. PJSIP realtimeにおいて、endpointとその登録済みコンタクトを保持するテーブルはどれですか？
   - A. `ps_endpoints`および`ps_contacts`
   - B. `ps_peers`および`ps_registry`
   - C. `ps_config`および`ps_data`
   - D. `extconfig`および`res_odbc`
7. ARAを有効にした後でも、テキスト設定ファイルを使用することは可能です。
   - A. 正
   - B. 誤
8. Realtimeを使用する場合、phpMyAdminは必須です。
   - A. 正
   - B. 誤
9. データベースは、設定ファイルに存在するすべてのフィールドを含めて作成しなければなりません。
   - A. 正
   - B. 誤
10. Asterisk 22において、PJSIP realtimeテーブル（`ps_endpoints`、`ps_aors`、`ps_auths`、`ps_contacts`）を作成するための推奨されるバージョン対応の方法は何ですか？
    - A. 各`ps_*`テーブルに対して`CREATE TABLE`文を手動で記述する
    - B. `contrib/realtime/`からレガシーな`mysql_config.sql`をインポートする
    - C. `contrib/ast-db-manage`（`alembic -c config.ini upgrade head`）の下でAlembicの`config`マイグレーションを実行する
    - D. Asteriskが最初に起動したときにテーブルが自動的に作成される

**回答:** 1 — A · 2 — C · 3 — A, B · 4 — A · 5 — A · 6 — A · 7 — A · 8 — B · 9 — B · 10 — C
