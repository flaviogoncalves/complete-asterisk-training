# Asterisk Real-Time

如您所知，Asterisk 的配置是通过使用 /etc/asterisk 目录下的几个文本文件来实现的。尽管使用文本文件很方便，但仍存在一些已知的缺点：

- 每次更改文件后都需要重新加载 Asterisk
- 对于大量用户，内存使用量会增加
- 使用文本文件编写配置接口非常困难
- 无法与现有数据库集成

ARA 或 Asterisk Realtime（正如其名）由 Anthony Minessale II、Mark Spencer 和 Constantine Filin 创建，旨在实现与 SQL 数据库的透明集成。此外还提供 LDAP 接口。该系统也称为 Asterisk External Configuration，并在 /etc/asterisk/extconfig.conf 中进行配置。您可以将配置文件映射到数据库中的表（静态配置），并使用实时条目来动态创建对象，而无需重新加载 Asterisk。

## 目标

在本章结束时，读者应该能够：

- 理解 Asterisk Real Time 的优势与局限性。
- 使用 ODBC 以配合 ARA 使用。
- 使用 ODBC 编译并安装 ARA。
- 在实验环境中测试该系统。

## Asterisk Real Time 是如何工作的？

在新的 Real Time 架构中，所有特定于数据库的代码都被移到了通道驱动程序中。通道仅调用一个用于搜索数据库的通用例程。从源代码的角度来看，其结果是一个更简单、更整洁的流程。数据库通过以下三个函数进行访问：

- STATIC：用于在加载模块时设置静态配置。
- REALTIME：用于在呼叫或其他事件期间搜索对象。
- UPDATE：用于更新对象。

在 Asterisk 22 上，SIP endpoint 由 **PJSIP** 堆栈（`res_pjsip`）处理，该堆栈构建在 **Sorcery** 对象模型之上。通过 `realtime` 向导，Sorcery 按需从数据库加载每个 PJSIP 对象，这些对象随后作为普通的已配置 PJSIP 对象存在——而不是像旧的 SIP 驱动程序在每次呼叫后丢弃的那种一次性 realtime 对等体。

由于它们是真实的对象，NAT 遍历、qualify 和消息等待指示（MWI）对于 realtime endpoint 来说都可以正常工作。（还可以通过 `memory_cache` 向导指示 Sorcery 将对象缓存在内存中，但这属于选择性加入，与 realtime 加载是分开的。）当您更改数据库中的对象时，更改会在下一次查找时被获取；您不需要在每次编辑后都进行 reload。（已弃用的 `chan_sip` realtime 模型及其 `sippeers`/`sipusers` 系列仅在 *Legacy Channels* 一章中介绍。）

## 配置 Asterisk Real Time

在本实验中，我们假设您已经按照 CDR 章节的说明安装了 ODBC。ARA 是在 `extconfig.conf` 文本文件中配置的，其中可以清晰地看到两个部分。第一部分是静态配置文件部分，您可以在此处用数据库表替换文本配置文件。第二部分是实时配置引擎，您可以在此处为动态对象（peers/users）配置数据库表。对于静态配置使用文本文件，而对于动态条目使用数据库，这种情况并不罕见。在这种情况下，第一部分保持不变。

```
extconfig.conf file format:
;
; Static and realtime external configuration
; engine configuration
;
; Please read doc/README.extconfig for basic table
; formatting information.
```

![Asterisk Real Time 架构：配置文件和静态数据库表在 Asterisk 启动时加载，而实时数据库表提供在呼叫期间按需读取的动态配置。](../images/18-realtime-fig01.png)

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


### 静态配置部分

静态配置部分是您存储数据库中等效配置文件的地方。这些配置在 Asterisk 加载期间被读取。某些模块在您执行 reload 时会重新读取数据库。静态配置的示例如下：

```
<conf filename> => <driver>,<databasename>[,table_name]
queues.conf => mysql,asteriskdb,queues_conf
pjsip.conf => odbc,asteriskdb,pjsip_conf
iax.conf => ldap,MyBaseDN,iax
```

静态文件映射对于没有按对象实时等效项的配置文件最为有用。对于 PJSIP，建议优先使用本章稍后描述的按对象实时系列（`ps_endpoints`、`ps_aors`等），而不是将整个 `pjsip.conf` 映射为静态文件。

上面描述了三个示例。在第一个示例中，您将 `queues.conf` 绑定到 `asteriskdb` 数据库中的 `queues` 表。在第二个示例中，您将 `pjsip.conf` 绑定到 ODBC 配置中定义的 `asteriskdb` 数据库中的 `pjsip_conf` 表。在最后一个示例中，您将 `iax.conf` 绑定到 LDAP 目录。`MyBaseDN` 是要搜索的基础 DN。在前面的示例中，当 MySQL 驱动程序查询数据库并获取所需信息时，应用程序 `app_queue.so` 会被加载。

### 实时配置部分

实时配置（`extconfig.conf` 文件的第二部分）是配置、更新和卸载实时加载配置片段的地方。使用实时配置，无需重新加载配置。实时配置的语法如下：

```
<family name> => <driver>,<database name>[,table_name]
```

示例：

```
ps_endpoints => odbc,asterisk,ps_endpoints
ps_aors => odbc,asterisk,ps_aors
queues => odbc,asterisk,queue_table
queue_members => odbc,asterisk,queue_member_table
voicemail => odbc,asterisk,test
```

这里我们有五行配置。在第一行中，您将 PJSIP/Sorcery 系列 `ps_endpoints` 绑定到 `asteriskdb` 数据库中的表 `ps_endpoints`。在最后一行中，您将 `voicemail` 系列绑定到 `asteriskdb` 数据库中的 `test` 表。每个 PJSIP 对象类型（endpoint、aor、auth、contact）都有其自己的系列和表；完整集合显示在下方的“PJSIP Realtime (Sorcery)”部分。在 Asterisk 22 中，`voicemail`、`extensions`、`queues` 和 `queue_members` 系列仍然有效。

## PJSIP Realtime (Sorcery)

在 Asterisk 22 上，SIP endpoint 完全由 **PJSIP** 协议栈（`res_pjsip`）处理，该协议栈构建在 **Sorcery** 对象抽象层之上。PJSIP 不再使用单一的 SIP “peer”，而是将一个 SIP 账户拆分为多个对象类型，每个对象类型都存储在各自的 realtime 表中：

| Sorcery 对象类型 | Realtime 表 | 存储内容 |
|---------------------|----------------|---------------|
| endpoint | ps_endpoints | 账户级设置（context、codecs、DTMF 等） |
| aor (address of record) | ps_aors | 注册限制和 `qualify` 设置 |
| auth | ps_auths | `username` / `password` 凭据 |
| contact | ps_contacts | 动态注册的位置 |
| domain alias | ps_domain_aliases | endpoint 的备用 SIP 域名 |
| endpoint identifier by IP | ps_endpoint_id_ips | 通过源 IP 匹配 endpoint |

PJSIP 的 realtime 功能在两个地方启用。首先，在 `extconfig.conf` 中将 Sorcery 对象类型映射到 realtime：

```
[settings]
ps_endpoints => odbc,asterisk
ps_aors => odbc,asterisk
ps_auths => odbc,asterisk
ps_contacts => odbc,asterisk
ps_domain_aliases => odbc,asterisk
ps_endpoint_id_ips => odbc,asterisk
```

其次，在 `sorcery.conf` 中告知 Sorcery 对这些对象类型使用 `realtime` 向导。映射名称（此处为 `res_pjsip`）是您要迁移对象的模块，右侧的值指向您在 `extconfig.conf` 中定义的 family：

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

您可以混合使用静态对象和 realtime 对象。如果您在 `sorcery.conf` 中省略了某种类型，该对象类型将继续从 `pjsip.conf` 读取。一种常见的模式是将静态 transports 和全局设置保留在 `pjsip.conf` 中，同时将 endpoints、aors、auths 和 contacts 存储在数据库中。

### 使用 Alembic 创建 PJSIP realtime 模式

Asterisk 在 `contrib/ast-db-manage` 下提供了所有 realtime 模式的数据库迁移脚本。这是创建（以及版本升级）PJSIP 表的官方支持方式 —— 您不再需要手动编写 `ps_*` 表定义。 `config` 迁移集包含了 PJSIP/Sorcery 表。

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# edit config.ini → set sqlalchemy.url, e.g.
#   sqlalchemy.url = mysql+pymysql://astdb:CHANGE_ME_DB_PASSWORD@127.0.0.1/astdb
alembic -c config.ini upgrade head
```

这将创建 `ps_endpoints`、 `ps_aors`、 `ps_auths`、 `ps_contacts` 以及其他具有适用于当前运行的 Asterisk 版本正确列的 PJSIP 表。（Alembic 需要 Python 的 `alembic` 包以及一个 SQLAlchemy 驱动程序，例如用于 MySQL/MariaDB 的 `pymysql` 或用于 PostgreSQL 的 `psycopg2`。）

一个最小化的 realtime endpoint 由三个表中的各一行组成 —— 例如 endpoint `6010`：

```
ps_auths:      id=6010-auth, auth_type=userpass, username=6010, password=supersecret
ps_aors:       id=6010, max_contacts=1
ps_endpoints:  id=6010, transport=transport-udp, aors=6010, auth=6010-auth,
               context=from-internal, disallow=all, allow=ulaw,
               direct_media=no
```

插入这些行后，无需执行任何 reload 操作 —— 下一次 REGISTER/INVITE 请求会直接从数据库中提取这些对象。您可以使用以下命令确认 realtime 返回的内容：

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

## 数据库配置

现在我们已经配置好了 extconfig.conf 文件，接下来让我们创建数据表。通常来说，每个数据库列都对应相应配置文件中的一个选项名称。PJSIP `ps_*` 表遵循此规则：每个 `ps_endpoints` 列都以 `pjsip.conf` endpoint 选项命名，每个 `ps_auths` 列以 auth 选项命名，依此类推。例如，下方的 `pjsip.conf` endpoint，

```
[4000](endpoint)
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=4000
aors=4000
```

被存储为跨越三个表的一行数据。其中 `ps_endpoints` 行存储 `id=4000, context=from-internal, disallow=all, allow=ulaw, auth=4000, aors=4000`；`ps_auths` 行存储 `id=4000, auth_type=userpass, username=4000, password=supersecret`；而 `ps_aors` 行存储 `id=4000, max_contacts=1`。您只需要填充实际使用的列即可——任何留空的列（NULL）都会回退到该选项的默认值。例如，如果您想要 endpoint 上的 `callerid` 参数，请填充 `ps_endpoints` 中的 `callerid` 列（列名与 `pjsip.conf` 选项名称相同）。

voicemail 表遵循相同的理念。其列映射到 `voicemail.conf` 字段：

| uniqueid | mailbox | context | password | email | fullname |
|----------|---------|---------|----------|-------|----------|
| 1 | 4000 | default | 4000 | john@doe.com | John Doe |

`uniqueid` 对于每个 voicemail 用户应该是唯一的，并且可以是自动递增的。它不需要与 mailbox 或 context 建立任何关系。

### 使用 Asterisk Real Time 构建 dialplan

您也可以使用实时系统来创建 dialplan。ARA 使用 `switch` 语句将实时 extension 包含到 extensions.conf 文件中包含的常规 dialplan 中。extension 表应如下所示：

| context | exten | priority | app | appdata |
|---------|-------|----------|-----|---------|
| from-internal | 4000 | 1 | Dial | PJSIP/4000 |

`extensions` realtime 系列在 Asterisk 22 中没有变化；只需确保 `appdata` 列拨打的是 PJSIP 通道，例如 `PJSIP/4000`。在 dialplan 中，您必须使用 `switch` 命令来使用实时功能。

![使用 Asterisk Real Time 构建 dialplan：extensions.conf 使用 `switch => realtime` 语句从数据库表中提取 extension 行（context、exten、priority、app、data），而不是从文本文件中提取。](../images/18-realtime-fig02.png)


```
[local]
switch => realtime
```

或

```
[local]
switch => realtime/from-internal@extensions
```

## 实验：安装并创建数据库表

在本实验中，我们将准备数据库以接收 Asterisk 参数。我们将仅准备 REALTIME 表。静态配置将保留在配置文件中（很酷，不是吗？）。MySQL 中的表创建过程如下。

第 1 步：以 root 用户身份进入 MySQL 数据库。

```
mysql -u root -p
```

第 2 步：登录在 CDR 实验中创建的 MySQL 服务器。

```
mysql -u astdb -p
```

当被要求输入密码时，输入 supersecret。

第 3 步：创建必要的表。旧版的静态模式文件仍然存在于 `contrib/realtime/` 下（例如 `/usr/src/asterisk-22.x/contrib/realtime/mysql`），但在 Asterisk 22 上，构建 realtime 表——特别是 PJSIP `ps_*` 表——的推荐且版本正确的方法是使用 `contrib/ast-db-manage` 下的 **Alembic** 迁移（请参阅上文“使用 Alembic 创建 PJSIP realtime 模式”一节）。

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# set sqlalchemy.url for your astdb database, then:
alembic -c config.ini upgrade head
```

Alembic `config` 迁移集构建了 PJSIP `ps_*` 表（以及 `voicemail`、`extensions` 和其他 realtime 模式），其列与当前运行的 Asterisk 版本所预期的完全一致，因此模式始终与构建版本匹配。

使用 supersecret 作为密码。

第 4 步：验证表的创建。

```
mysql -u astdb -p astdb
mysql>use astdb;
mysql>show tables;
```

你应该能看到 PJSIP `ps_*` 表（由 Alembic `config` 迁移创建），以及 `voicemail`、`extensions` 和其他 realtime 表：

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

（Alembic 创建的表比这些更多——上面的列表显示了与本实验相关的表。）

第 5 步：数据库已针对 ODBC 完成配置（自 CDR 实验以来），因此此处无需进一步的 ODBC 设置。

第 6 步：从 MySQL 客户端检查并填充表。你不需要像 phpMyAdmin 这样的图形化工具——本章中的每一步都是简单的、可复制粘贴的 SQL，从 `mysql` 命令行运行。连接到 `astdb` 数据库（在提示时使用 `supersecret`）：

```
mysql -u astdb -p astdb
```

你可以随时使用 `DESCRIBE` 确认表的列，例如：

```
mysql> DESCRIBE ps_endpoints;
mysql> DESCRIBE ps_auths;
mysql> DESCRIBE ps_aors;
```

这些表是由 Alembic `config` 迁移创建的，因此它们的列已经与当前运行的 Asterisk 版本的 `pjsip.conf` 选项名称相匹配——你只需要填充你需要的列即可。

## 实验：配置并测试 ARA

在本实验中，我们将修改 extconfig.conf 配置，以反映我们的数据库配置和表结构。

第 1 步：配置 extconfig.conf 并重载 Asterisk。

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

请注意上述的 `ps_endpoints`、`ps_aors`、`ps_auths` 和 `ps_contacts` 系列；它们与匹配的 `sorcery.conf` 映射（参见“PJSIP Realtime (Sorcery)”一节）一起，使 PJSIP 能够从数据库中读取其账户信息。而 `voicemail` 和 `extensions` 系列则完善了此示例。

第 2 步：实时 extension 测试。通过在 `ps_auths`、`ps_aors` 和 `ps_endpoints` 中各插入一行来创建一个新的 `6010` endpoint，然后尝试使用 softphone 注册此 endpoint。在 `mysql` 客户端（`mysql -u astdb -p astdb`）中运行以下 SQL：

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

这三行共同描述了一个 SIP 账户。其余的账户设置分布在各个 PJSIP 对象中：context、codecs、DTMF 模式和媒体处理位于 endpoint 上（上述最后六列）；动态注册则位于 AOR 上。这里没有单独的“动态”标志——只要 `max_contacts` 大于零，AOR 就会接受动态 REGISTER，并且每个注册的位置都会被写入 `ps_contacts`。

在 PJSIP 中，RFC 2833 / RFC 4733 带外 DTMF 模式被命名为 `rfc4733`，而 `dtmf_mode=rfc4733` 是默认值——因此上述 `dtmf_mode` 列是可选的，仅为清晰起见而显示。

第 3 步：尝试使用用户名 `6010` 和密码 `supersecret` 将新手机注册到 softphone。在 Asterisk CLI 上确认注册情况：

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

第 4 步：将 extensions 包含在数据库中。

```
mysql -u astdb -p
```

输入密码：

当被询问时输入 supersecret，然后从 MySQL 客户端插入 extension 行：

```sql
USE astdb;
INSERT INTO extensions (id, context, exten, priority, app, appdata)
VALUES ('1', 'test', '6007', '1', 'Dial', 'PJSIP/bria');
```

第 5 步：在 dialplan 中包含 Asterisk Real Time。在 context `default` 中：

```
switch => realtime/test@extensions
```

重载 extensions 以激活更改。

```
asterisk-server*CLI> extensions reload
```

第 6 步：如果尚未操作，请将其中一部手机重新配置为用户名 `bria`。

第 7 步：从现有的手机拨打 6007；`bria` 手机应该会响铃。

## 总结

在本章中，你已经了解到 Asterisk Real Time 允许你将配置存储在数据库中。Asterisk 提供了用于 ODBC（可连接任何支持 UnixODBC 的数据库，包括 MySQL/MariaDB 和 SQLite）和 PostgreSQL 的原生实时驱动程序，以及用于目录后端的 LDAP 实时驱动程序。正如我们在本章中所做的那样，MySQL/MariaDB 是通过 ODBC 连接的（虽然也存在专门的 `res_config_mysql` 插件，但它不属于核心构建的一部分，因此 ODBC 是通用的路径）。配置分为静态配置和实时配置。静态配置用于替代配置文件，而实时配置则创建仅在呼叫或其他相关事件发生时才加载的动态对象。最后，我们通过一个关于如何安装和配置 ARA 的实践实验结束了本章。

## 测试题

1. Asterisk Realtime 是标准 Asterisk 发行版的一部分。
   - A. 正确
   - B. 错误
2. 数据库服务器的连接参数配置在以下文件中：
   - A. extensions.conf
   - B. pjsip.conf
   - C. res_odbc.conf
   - D. extconfig.conf
3. `extconfig.conf` 文件配置了 Realtime 使用的表。它有两个不同的部分（请选择两项）：
   - A. 静态配置
   - B. Realtime 配置
   - C. 出局路由
   - D. IP 地址和数据库端口
4. 在静态配置中，对象一旦从数据库加载，就会保存在 Asterisk 的内存中，并且仅在启动或重载时刷新。
   - A. 正确
   - B. 错误
5. PJSIP realtime (Sorcery) 完全支持 `qualify` 和用于 realtime endpoint 的 MWI，因为 Sorcery 将它们作为普通的已配置 PJSIP 对象加载，而不是像旧的 SIP realtime peer 那样在每次呼叫后丢弃它们。
   - A. 正确
   - B. 错误
6. 在 PJSIP realtime 中，哪些表用于存放 endpoint 及其注册的联系人？
   - A. `ps_endpoints` 和 `ps_contacts`
   - B. `ps_peers` 和 `ps_registry`
   - C. `ps_config` 和 `ps_data`
   - D. `extconfig` 和 `res_odbc`
7. 即使启用了 ARA，你仍然可以使用文本配置文件。
   - A. 正确
   - B. 错误
8. 使用 Realtime 时，phpMyAdmin 是强制要求的。
   - A. 正确
   - B. 错误
9. 数据库必须包含配置文件中存在的每一个字段。
   - A. 正确
   - B. 错误
10. 在 Asterisk 22 上，创建 PJSIP realtime 表（`ps_endpoints`, `ps_aors`, `ps_auths`, `ps_contacts`）的推荐且版本正确的方法是什么？
    - A. 手动为每个 `ps_*` 表编写 `CREATE TABLE` 语句
    - B. 从 `contrib/realtime/` 导入旧版 `mysql_config.sql`
    - C. 在 `contrib/ast-db-manage` 下运行 Alembic `config` 迁移（`alembic -c config.ini upgrade head`）
    - D. Asterisk 首次启动时会自动创建这些表

**答案：** 1 — A · 2 — C · 3 — A, B · 4 — A · 5 — A · 6 — A · 7 — A · 8 — B · 9 — B · 10 — C
