# 部署、监控与扩展

在实验室环境中让 Asterisk 接听电话是一回事；而将其作为一项能够应对崩溃、重启、升级和攻击的服务来运行——并且能够对其进行观察、备份和扩展——则是另一回事。本章将探讨 dialplan 正常工作之后所涉及的一切内容。我们首先介绍保持 Asterisk 持续运行的守护进程（systemd），接着讨论如何将其打包到容器中（以本书自带的 Docker 实验室作为实践示例），然后涵盖配置管理与备份、监控与可观测性，最后介绍当单台服务器无法满足需求时所采用的模式：高可用性与扩展，以及在云端托管的现实情况。

文中展示的所有内容均已在本书的 Asterisk 22 实验室环境（位于 `lab/`）中进行了验证——这与您在整本书中一直构建的容器是同一个。

## 目标

读完本章后，您应该能够：

- 在 systemd 下以非 root 用户身份可靠地运行 Asterisk 22，并实现自动重启
- 使用 Docker 对 Asterisk 进行容器化，并理解网络方面的权衡
- 将 `/etc/asterisk` 纳入版本控制并备份正确的状态
- 通过 CLI、CDR/CEL、AMI/ARI 和指标监控运行中的系统
- 应用主备高可用性和水平扩展模式
- 在 NAT 和防火墙后的云端安全地托管 Asterisk

## 在 systemd 下运行 Asterisk

在当前所有的 Linux 发行版上——包括 Debian 12、Ubuntu 22.04/24.04、Rocky/AlmaLinux 9——服务管理器均为 **systemd**。安装章节展示了 `make config` 步骤（在 `make install` 期间运行）会安装一个发行版初始化脚本（Debian 上为 `/etc/init.d/asterisk`，RedHat 上为 `rc.d` 脚本），systemd 会自动将其封装为服务；Asterisk 还在 `contrib/systemd/asterisk.service` 下提供了一个原生的 systemd 单元文件，你可以将其安装以替代原脚本，从而实现更精细的控制。
无论哪种方式，systemd 都是运行 Asterisk 的受支持的生产环境方式。关于构建本身，请参阅 *Installing Asterisk 22*；此处我们重点介绍该服务提供的功能及其操作方法。

### 服务单元及其生命周期

一旦 `make config` 安装了该服务，其生命周期管理就与普通的 systemd 一致：

```
systemctl enable asterisk     # start automatically at boot
systemctl start asterisk      # start now
systemctl status asterisk     # is it running? recent log lines
systemctl restart asterisk    # full stop + start
systemctl stop asterisk       # stop
journalctl -u asterisk        # service logs via the journal
```

几点操作注意事项：

- **`restart` 与优雅重载（graceful reload）的对比。** `systemctl restart` 会终止进程并丢弃所有通话。对于配置更改，你几乎永远不希望这样做——请改用 Asterisk CLI：`asterisk -rx 'core reload'`（或特定模块的重载，例如 `pjsip reload`）。仅在升级或进程卡死时才使用 `systemctl restart`。
- **连接到正在运行的守护进程。** 当 Asterisk 作为服务运行时，使用 `asterisk -r`（或 `asterisk -rvvv` 以获取详细输出）打开其控制台。这会通过控制套接字连接到已经在运行的守护进程；它不会启动第二个副本。

### `Restart=` 取代了 safe_asterisk

从历史上看，Asterisk 是通过 **safe_asterisk** 包装器启动的，这是一个在 Asterisk 崩溃时会重新启动它的 shell 脚本。在 systemd 下，这项工作属于单元文件的 `Restart=` 指令——systemd 会监测进程退出并将其拉起，其退避策略由 `RestartSec=` 控制，崩溃循环保护由 `StartLimitIntervalSec=`/`StartLimitBurst=` 控制。因此，在 systemd 主机上，**safe_asterisk 已被取代**，通常是不必要的。如果你的安装包自带的单元文件尚未设置此项，使用 drop-in 覆盖配置是添加“失败后重启”功能的简洁方法，且无需编辑打包好的文件：

```
# /etc/systemd/system/asterisk.service.d/override.conf
[Service]
Restart=always
RestartSec=2
```

使用 `systemctl daemon-reload && systemctl restart asterisk` 应用它。使用 drop-in（而不是编辑已安装的单元文件）意味着未来的 `make config` 不会覆盖你的更改。

### 以非 root 用户身份运行

在生产环境中，Asterisk 不应以 root 身份运行——运行在 root 权限下的进程如果存在远程代码执行漏洞，会导致整个主机被攻破；而同样的漏洞如果发生在非特权进程中，则会被限制在一定范围内。有两个互补的地方可以强制执行此操作：

- **单元文件 / asterisk.conf。** 打包好的单元文件通常以 `asterisk` 用户和组身份运行 Asterisk。你也可以（或改为）在 `asterisk.conf` 的 `[options]` 部分设置 `runuser` 和 `rungroup`，守护进程在绑定端口后降低权限时会遵循这些设置：

  ```
  [options]
  runuser = asterisk
  rungroup = asterisk
  ```

- **文件所有权。** 运行时目录必须对该用户可写。创建账户后，请确保所有权正确：

  ```
  chown -R asterisk:asterisk /var/lib/asterisk /var/log/asterisk \
        /var/spool/asterisk /var/run/asterisk /etc/asterisk
  ```

由于 SIP (5060) 和 RTP (10000+) 都是高位端口，Asterisk **不需要** root 权限来绑定它们——只有像 25 端口那样的特权端口才需要，而 Asterisk 并不使用这些端口。因此，以非特权身份运行是零成本的。（安全章节详细阐述了为何这很重要；请参阅 *Asterisk Security*。）

## 容器化 Asterisk

容器将 Asterisk 及其精确的依赖项打包成一个不可变的镜像，因此你测试的内容与你交付的内容在字节层面完全一致。其代价是实时媒体：SIP 服务器对延迟非常敏感，并且需要从外部可以访问的、广泛且可预测的 UDP 端口范围，而容器网络可能会阻碍这一点。本节的其余部分将通过本书自带的实验环境 —— `lab/Dockerfile` 和 `lab/docker-compose.yml` —— 作为具体的、可运行的示例，然后解释每个人都会遇到的一个陷阱：RTP 和桥接网络。

### 镜像：从源码构建 Asterisk

实验环境的 `Dockerfile` 在 Debian 12 上从源码构建 Asterisk 22。即使你从不亲自编写，了解它的结构也是值得的：

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

有三点需要说明：

- **版本已锁定** (`ARG ASTERISK_VERSION=22.10.0`)。可重复性是容器化的全部意义所在 —— 有意地升级版本、重新构建、重新测试。
- **`--with-pjproject-bundled` 和 `--with-jansson-bundled`** 构建与 Asterisk 版本匹配的 SIP 协议栈，因此你依赖的 apt 软件包更少，且永远不必处理与 Asterisk 不兼容的发行版 PJSIP。
- **`CMD ["asterisk", "-f", "-vvv"]`** 在*前台*运行 Asterisk (`-f`，"do not fork")。这是与 systemd 主机的主要区别：容器的主进程绝不能守护进程化，否则容器会立即退出。因此，在容器中你**不**使用 systemd 单元 —— 容器运行时 (Docker，加上 `restart:` 策略) 变成了 supervisor，而这在虚拟机上是由单元的 `Restart=` 负责的。

### 绑定挂载 `/etc/asterisk`

该镜像特意包含**无**任何配置。相反，`docker-compose.yml` 将主机的配置目录绑定挂载进来：

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

`./asterisk/etc:/etc/asterisk:ro` 将版本控制的 `lab/asterisk/etc` 目录映射到容器的 `/etc/asterisk` 上，并以只读方式挂载 (`:ro`)。这样做的好处很大：镜像保持不可变且可重用，而配置则保留在主机上，可以在主机上进行编辑，并且至关重要的是，可以保存在 git 中（下一节）。要应用配置更改，只需编辑文件并重新加载 —— `docker compose exec asterisk asterisk -rx 'core reload'` —— 无需重新构建。`restart: unless-stopped` 是 compose 层面等同于 systemd 的 `Restart=`：如果 Asterisk 退出，Docker 会重启容器，但如果你是主动停止它的，则不会重启。

### 主机网络与桥接网络 —— RTP 问题

这是容器化 Asterisk 最常见的故障，因此有必要准确理解它。默认情况下，Docker 将容器置于**桥接**网络上，你通过 `ports:` 发布单个端口。信令没问题 —— 5060 是一个端口。问题在于媒体：RTP 使用一个 UDP 端口*范围*（实验环境的 `rtp.conf` 设置了 `rtpstart=10000` / `rtpend=10100`），并且**每一个**可能承载音频的端口都必须发布。

实验环境正是这样做的：

```yaml
    ports:
      - "5060:5060/udp"
      - "10000-10100:10000-10100/udp"
```

注意 RTP 发布范围 (`10000-10100`) 与 `rtp.conf` 完全匹配。如果弄错了 —— 发布了太少的端口，或者范围与 `rtp.conf` 不同 —— 呼叫虽然能接通，但会出现**单向音频或无音频**，因为 RTP 数据包到达了 Docker 未转发的端口。在桥接模式下还有两个注意事项：

- **发布数千个端口既缓慢又沉重。** 生产环境的 RTP 范围通常是 10000–20000。Docker 创建约 10000 个用户态代理转发在启动时开销很大，并且在媒体路径中增加了一跳。实验环境特意保持了 100 个端口的小范围，因为它每次只运行一两个测试呼叫。
- **SDP 中的 NAT。** 在网桥后面，Asterisk 会看到其私有的容器 IP，并可能在 SDP 中通告它。在公共主机上，你必须在传输配置中通过 `external_media_address` / `external_signaling_address` 告知 PJSIP 其外部地址（并设置 `local_net`），这与你在任何 NAT 后面所做的一样 —— 请参阅下文的 *云托管*。

另一种选择是**主机网络** (`network_mode: host`)，它完全移除了网桥：容器共享主机的网络栈，因此 5060 和整个 RTP 范围无需端口发布且无需额外的媒体跳数即可访问。这是真正的 Asterisk 容器推荐的模式 —— 它完全避开了 RTP 范围问题。其代价是隔离性：容器可以绑定任何主机端口，并且你失去了 compose 的服务间网络隔离。（主机网络是 Linux 的一项功能；在 macOS/Windows 的 Docker Desktop 上，它的行为有所不同，这也是本教学实验使用显式发布端口的部分原因。）

### 用于 spool 和 voicemail 的持久化卷

容器的可写层是**临时**的 —— 销毁容器，它写入的任何内容都会消失。对于 Asterisk 而言，这意味着语音信箱、录音、外呼 spool 和本地数据库会在每次 `docker compose up --build` 时消失。配置之所以能保留，是因为它是从主机绑定挂载的；*状态*也需要同样的待遇。在容器内部，相关的目录树是：

```
/var/spool/asterisk        # voicemail, monitor recordings, outgoing/, etc.
/var/lib/asterisk          # astdb.sqlite3 (the internal database)
/var/log/asterisk          # full, messages, security, cdr-csv/, cel-custom/
```

（实验环境运行中的容器显示了确切的这些内容 —— `/var/spool/asterisk` 包含 `voicemail`、`monitor`、`outgoing`、`recording`；`/var/lib/asterisk` 保存了 `astdb.sqlite3`。）为了保留它们，请为保存你所关心的状态的目录挂载命名卷：

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

教学实验特意省略了这些 —— 它在设计上是无状态且可重复的，因此每次 `up` 都是一个干净的起点 —— 但生产环境的容器**必须**拥有它们，否则你在第一次重新部署时就会丢失语音信箱。

## 配置管理与备份

上述的绑定挂载（bind-mount）暗示了正确的模型：将 `/etc/asterisk` 视为**代码**，其余部分视为**数据**。

### 将 `/etc/asterisk` 纳入版本控制

配置目录是一组扁平的文本文件，其中没有无法模板化的机密信息——它非常适合使用 git 进行管理。在 `/etc/asterisk` 中初始化一个仓库（或者像本实验一样，将配置与项目放在一起并进行绑定挂载）。其优点包括：

- 每一项更改都是可审查且可回滚的（`git diff`，`git revert`）。
- 您拥有关于谁在何时更改了什么的审计追踪。
- 结合容器镜像，一个已知的良好配置提交加上一个固定的镜像标签，即可完整描述一次部署。

针对 Asterisk 配置的几点注意事项：

- **机密信息。** `pjsip.conf`（以及 `manager.conf`，`ari.conf`）包含密码。请勿将真实的机密信息以明文形式提交到共享仓库中——请对其进行模板化处理（每个环境一个文件，或在部署时使用机密管理器/环境变量替换），并仅在 git 中保留占位符。本实验中使用的简单 `Lab-6001-secret` 风格密码之所以可以接受，*仅仅*是因为它们运行在私有的 Docker 子网中。
- **环境模板化。** 在开发、测试和生产环境之间存在差异的 realtime 值（绑定地址、外部 IP、trunk 凭据、数据库 URL）正是您需要模板化的行，这样可以保持大部分配置在不同环境间的一致性。

### 需要备份的内容

git 中的配置涵盖了 dialplan 和 endpoint，但运行中的 PBX 会积累不包含在任何配置文件中的*状态*。完整的备份应包括：

| 内容 | 位置 | 原因 |
|------|-------|-----|
| 配置 | `/etc/asterisk/` | dialplan，endpoint（也在 git 中） |
| Voicemail 和录音 | `/var/spool/asterisk/` | 用户数据——不可替代 |
| 内部数据库 | `/var/lib/asterisk/astdb.sqlite3` | `DB()` 键值，设备状态 |
| CDR / CEL | `/var/log/asterisk/cdr-csv/` 或 SQL 存储 | 计费与历史记录 |
| 外部数据库 | 您的 MySQL/PostgreSQL | realtime，CDR，voicemail |

**astdb** 值得特别说明：它是 Asterisk 内置的小型键值存储（位于 `/var/lib/asterisk/astdb.sqlite3` 的 SQLite 文件），被 `DB()` dialplan 函数、设备状态、呼叫转移设置等所使用。您可以从 CLI 导出它以进行检查或备份：

```
asterisk -rx 'database show'
```

如果您的 CDR/CEL、voicemail 或 PJSIP 配置位于外部数据库中（请参阅 *Asterisk Real-Time* 和 *Asterisk Call Detail Records*），那么该数据库现在就是这些数据的真实来源，必须纳入您的常规数据库备份轮换中——仅备份 `/etc/asterisk` 是不够的。

## 监控与可观测性

你无法管理你看不见的东西。Asterisk 从快速的人工查看一直到指标流水线，在四个层面上暴露其状态：**CLI**、**CDR/CEL** 记录、**AMI/ARI** 事件以及**指标导出器（metrics exporters）**。

### CLI 健康检查

最快的“它健康吗？”检查方式是使用 CLI。以下命令在实验室环境中实时运行。首先是通道：

```
*CLI> core show channels
Channel              Location             State   Application(Data)
0 active channels
0 active calls
0 calls processed
```

在安静的系统上`0 active calls`是正常的；在繁忙的系统上，这是你的实时并发量。`core show uptime`确认了进程没有在你不知情的情况下重启：

```
*CLI> core show uptime
System uptime: 1 hour, 40 minutes, 19 seconds
Last reload: 12 minutes, 32 seconds
```

对于 SIP 健康状况，`pjsip show endpoints`显示了每个 endpoint 以及其注册的联系人是否可达。来自实验室的数据：

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

此处的`Unavailable`仅仅意味着当前没有电话注册到这些 endpoint（实验室没有实时客户端）——一旦 softphone 注册并且`qualify`确认了它，状态就会显示该联系人为可达。配套命令：`pjsip show contacts`（当前注册和往返时间）、`pjsip show transports`以及针对单个 AOR 的`pjsip show aor <name>`。这些是日常工作中“为什么 extension X 无法到达？”的排查工具。

### CDR 和 CEL

每次通话都会留下一个 **Call Detail Record** (CDR)；**Channel Event Logging** (CEL) 则添加了更细致的每个通道的事件。确认 CDR 是否处于活动状态以及哪个后端存储了它：

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

实验室显示`(none)`处于已注册后端之下，因为最小化的实验室配置没有加载任何 CDR 存储模块——所以记录会被计算但不会写入任何地方。在生产环境中，你会加载一个后端（CSV，或通过`cdr_odbc`/`cdr_adaptive_odbc`存入 MySQL/PostgreSQL），这将成为你的计费和历史记录来源。CEL **默认是禁用的**（`cel show status` 会显示` reports `CEL Logging: Disabled` in the lab) and you enable it in `），仅在需要事件级详细信息时才在 `cel.conf` 中启用。两者都在 *Asterisk Call Detail Records* 中有深入介绍；对于监控而言，重点在于 CDR/CEL 是你的*历史*记录，而 CLI 是你的*实时*视图。

### AMI 和 ARI 事件

对于程序化的实时监控，你更倾向于使用事件推送流，而不是轮询 CLI：

- **AMI (Asterisk Manager Interface)** 是长期使用的 TCP 事件/命令协议（`manager.conf`）。订阅后，你会在通话发生时收到`Newchannel`、`Hangup`、`DialBegin`、`BridgeEnter`、`PeerStatus`等类似事件——这是墙板（wallboards）和通话计费工具的骨干。在实验室中，AMI 默认是禁用的（`manager show settings`报告`Manager (AMI): No`）；你需要在`manager.conf`中启用并锁定它。
- **ARI (Asterisk REST Interface)** 是现代的 HTTP + WebSocket 接口（`ari.conf`，由内置的 HTTP 服务器提供服务）。它提供 JSON 事件流和细粒度的通话控制——这是进行新集成的正确选择。

两者都在 *Extending Asterisk with AMI and AGI* 和 *The Asterisk REST Interface (ARI)* 中有详细说明。部署相关的警告：**AMI 和 ARI 功能强大，绝不能暴露在互联网上。** 将 HTTP 服务器绑定到 localhost 或管理网络，使用强且唯一的密钥，并对端口进行防火墙限制——请参阅 *Asterisk Security*。

### 指标：Prometheus 和 Grafana

对于仪表板和告警，Asterisk 22 附带了一个 Prometheus 导出器，即 **`res_prometheus.so`**（一个具有*扩展*支持级别的模块），它在 HTTP endpoint 上暴露指标，供 Prometheus 服务器抓取。除了核心进程指标外，它还提供了可插拔的提供程序，涵盖通道、通话、endpoint、桥接和 PJSIP 出站注册：

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

你可以确认该模块是否存在于实验室构建中：

```
*CLI> module show like prometheus
Module                         Description                     Use Count  Status      Support Level
res_prometheus.so              Asterisk Prometheus Module      0          Not Running  extended
```

它显示`Not Running`，因为实验室没有配置或加载它；启用它（`prometheus.conf`加上 HTTP 服务器）会将 Asterisk 变成一个 Prometheus 目标。将 Prometheus 指向抓取 endpoint，并将 Grafana 指向 Prometheus，你就可以获得时间序列仪表板（并发通话、注册、ASR/ACD 趋势）和告警（例如“活跃通话降至零”或“注册失败激增”）。对于已经运行 Prometheus/Grafana 的团队来说，这是将 Asterisk 纳入现有可观测性体系的自然方式，而不是去解析 CLI 输出。

### 值得关注的 SIP 响应代码

无论使用哪种流水线，一些 SIP 结果都预示着问题，值得进行告警：持续的`401`/`407`质询失败或`403 Forbidden`暗示了暴力破解或配置错误的凭据攻击（请交叉参考 *Asterisk Security* 中的 Fail2Ban）；`503 Service Unavailable`指向过载或拥塞的服务器或 trunk；而`408 Request Timeout`/`480 Temporarily Unavailable`的激增通常意味着 endpoint 变得不可达（NAT 超时、qualify 失败）。

## 高可用性与扩展

单个 Asterisk 服务器是一个单点故障，且具有有限的呼叫上限。这两个问题——*保持运行*和*扩大规模*——有着不同的解决方案。

### 带有浮动 IP 的主/备模式

Asterisk 经典且成熟的 HA 模式是**主/备（active/standby）**模式（而非主/主模式——Asterisk 中的呼叫状态很难实时共享）。两台相同的服务器，一台为主，一台为备，共享一个由集群管理器（如 **keepalived** (VRRP) 或 **Pacemaker/Corosync**）管理的**浮动（虚拟）IP**。话机和 trunk 注册到浮动 IP，而不是任何一个真实的物理主机。如果主节点健康检查失败，浮动 IP 会漂移到备用节点，由其接管服务。

诚实的警告：IP 故障转移会**导致正在进行的呼叫中断**——Asterisk 不会在节点间复制实时通道状态，因此通话中的用户必须重新拨号。注册信息会在 qualify/registration 周期内重新建立。故障转移带来的好处是*服务*可以在几秒钟内无需人工干预即可恢复，对于大多数 PBX 而言，这正是目标所在。为了使备用节点真正能够接管，两个节点需要相同的配置（你通过 git 管理的 `/etc/asterisk`，部署方式完全一致）以及相同的*状态*——这就是下一点要讨论的内容。

### 使用 PJSIP Realtime 外部化状态

主/备模式只有在备用节点了解与主节点相同的 endpoint 和注册信息时才有效。实现这一目标的方法是**停止将状态保存在单台机器的平面文件中**，并将其迁移到两个节点都能读取的共享数据库中。**PJSIP Realtime**（由数据库支持的 Sorcery）正是为此而生：endpoint、AOR、auth，以及最重要的**注册信息**（`ps_contacts`表）——都存储在 MySQL/PostgreSQL 中，而不是 `pjsip.conf` 和本地内存中。两个 Asterisk 节点都指向同一个数据库，因此通过一个节点注册的话机对另一个节点也是可见的。这在*Asterisk Real-Time*（PJSIP Realtime / Sorcery 章节）中有详细介绍；此处部署的重点在于：**外部化状态是实现 HA 和水平扩展的前提**——没有它，每个节点都是一座孤岛。

将同样的逻辑应用于其余状态：将 CDR/CEL 存入共享 SQL 存储，将 voicemail 存放在共享/复制存储（或 `ODBC_STORAGE`）中，并将你所依赖的 astdb 键值存入数据库。一旦状态外部化，Asterisk 节点就更接近于可互换的前端。

### 前置 SIP 代理 (OpenSIPS)

为了扩展到*超出*单台服务器的容量，你可以在一组 Asterisk 媒体服务器前端放置一个 **SIP 代理/负载均衡器**。**OpenSIPS** 是一个专门构建的、高吞吐量的 SIP 代理（它们处理数十万次注册并路由信令，而不触及媒体流）。该代理向外界提供单一的 SIP 地址，维护注册/位置服务，并将呼叫分发到各个 Asterisk 后端。这种分离——轻量级的代理层负责注册和路由，水平可扩展的 Asterisk 层负责实际的呼叫处理（IVR、队列、会议、转码）——是大规模部署突破单机限制的方式。（SipPulse 平台本身正是出于这个原因，在其媒体/应用服务器前端使用了 OpenSIPS。）

### 媒体扩展

代理可以廉价地分发*信令*；而**媒体是昂贵的资源**。RTP 中继，尤其是 codec 之间的转码（例如 Opus ↔ G.711）或运行大型会议，是 CPU 密集型的，这才是真正限制服务器性能的瓶颈。策略如下：

- **尽可能避免转码**——协商端到端的通用 codec，以便 Asterisk 进行原生桥接（透传）而不是转码。这是提升媒体容量最有效的方法。
- **水平扩展媒体**，通过在代理后端增加 Asterisk 节点；每个节点承担一部分并发呼叫。
- **将浏览器媒体卸载**到专用的 WebRTC 网关（例如 Janus），这样 PBX 就不必同时终止和中继每个浏览器的 DTLS-SRTP 流——请参阅*WebRTC with Asterisk*，其中讨论了这种 Asterisk 与网关分离的架构。

根据**并发呼叫和转码负载**来衡量容量，而不是根据注册用户数——10,000 个大部分处于空闲状态的注册话机，其成本远低于 200 个同时进行的转码会议。

## 云托管

在云虚拟机（AWS、GCP、Azure、VPS）上运行 Asterisk 是常见的做法且效果良好，但云网络**默认经过 NAT 和防火墙处理**，这与 SIP 存在冲突。以下是部署时需要特别关注的问题。

### NAT 与 SDP

云虚拟机几乎总是在其网卡上拥有一个**私有** IP，以及一个由服务商进行 NAT 映射的独立**公网** IP。如果 Asterisk 在 SDP 中通告私有 IP，远程话机发送的 RTP 数据包就会进入黑洞——这就是典型的单向音频/无音频故障。请在传输层配置中告知 PJSIP 其公网身份：

```
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=203.0.113.10      ; the VM's PUBLIC IP
external_signaling_address=203.0.113.10
local_net=10.0.0.0/8                     ; your private/VPC range(s)
```

`external_*`让 Asterisk 将其通告给公网对端的地址重写为公网地址，而`local_net`则告知它哪些对端属于本地（不应重写）。这与上述桥接 Docker 网络中讨论的 NAT 处理方式相同——云虚拟机实际上就处于 NAT 之后。

### 防火墙与 RTP 范围

云虚拟机通常涉及两层防火墙：**服务商的**安全组/网络 ACL，以及**宿主机的** iptables。两者都必须开放相同的端口，策略应遵循安全章节中的建议。第一版中保留下来的规则集（`docs/legacy-labs/configs/Lab7/rules.v4`）概括了其形态——接受 SIP 和 RTP 范围的流量，接受已建立/相关的连接，丢弃其余流量：

```
-A INPUT -p udp -m udp --dport 5060 -j ACCEPT
-A INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -j DROP
```

安全章节中提到的两点修正在此处至关重要：如果您运行 SIP/TLS，请开放 **5061/TCP**（而非 UDP）；并请记住，防火墙中的 RTP UDP 范围必须与`rtp.conf`中的`rtpstart`/`rtpend`完全匹配——这与您在容器上发布的范围相同。请勿在此处重复构建 iptables/Fail2Ban；请**遵循《Asterisk 安全》中关于防火墙、Fail2Ban 和 TLS/SRTP 的章节**（Fail2Ban 会监控实验室环境已在`logger.conf`中启用的`security`日志通道），并在宿主机防火墙和云安全组中同时应用该策略。

### 延迟、区域与 SBC

- **选择靠近用户的区域。** 语音对延迟非常敏感——单向口耳延迟超过 ~150 ms 就会有明显感知。请将虚拟机托管在距离您的大多数话机和 trunk 最近的区域；跨洲的媒体流质量会明显下降。
- **对于任何面向互联网的部署，请在前端放置一个 SBC。** **Session Border Controller** 在边缘终结 SIP/RTP，隐藏您的拓扑结构，规范化 NAT，并在 DoS 和扫描流量到达 Asterisk 之前将其拦截。安全章节的核心建议——*不要将裸露的 Asterisk 直接暴露在互联网上*——在云环境中尤为重要，因为您的虚拟机公网 IP 在启动后几分钟内就会被扫描。SBC（或至少是一个加固的 SIP 代理，如 OpenSIPS 配合 Fail2Ban）是标准的边缘防护方案。

## 总结

部署是将可用的 dialplan 转化为可靠服务的关键环节。在虚拟机上，请以 **non-root** 用户身份运行 Asterisk，并使用 systemd，让单元文件的 `Restart=` 确保其持续运行（safe_asterisk 已被取代），同时使用 `core reload` 而非 `systemctl restart` 来应用配置更改。使用 Docker 进行 **容器化**（正如本书实验所做的那样）可以为你提供一个不可变的、版本固定的镜像，并通过 git 管理的 `/etc/asterisk` 进行 **bind-mounted** 配置；其难点在于媒体处理，因此要么使用 **host networking**，要么发布一个 **与 `rtp.conf` 完全匹配** 的 RTP 端口范围，并为 spool/voicemail/astdb 挂载 **persistent volumes**，以确保状态在重新部署后依然存在。将配置视为代码，并 **备份** 配置无法捕获的状态：voicemail、录音、`astdb.sqlite3` 以及 CDR/CEL。从四个层面 **观察** 系统：使用 CLI（`core show channels`，`pjsip show endpoints`）查看实时状态，使用 **CDR/CEL** 查看历史记录，使用 **AMI/ARI** 获取程序化事件，以及使用 **`res_prometheus`** 导出器接入 Grafana 以实现仪表盘和告警——同时务必确保 AMI/ARI 不暴露在公共互联网上。为了 **保持在线**，请使用 **floating IP** 运行 active/standby 模式（需接受故障转移会导致当前通话中断的事实）；为了 **扩展**，请通过 **PJSIP Realtime** 将状态外部化，在媒体服务器集群前端部署 **OpenSIPS**，并尽量减少转码，因为 **媒体（而非注册）才是限制服务器性能的瓶颈**。最后，在 **云端** 部署时，请将虚拟机视为处于 NAT 之后（`external_media_address`，`local_net`），在主机和云服务商的安全组中按照安全章节的要求开放防火墙，选择低延迟区域，且永远不要直接暴露原始的 Asterisk——请在边缘部署 **SBC**。

## 测试题

1. 在 systemd 主机上，什么取代了旧的 `safe_asterisk` 包装器来重启崩溃的 Asterisk？
   - A. 一个 cron 任务
   - B. 单元文件中的 `Restart=` 指令
   - C. `systemctl enable`
   - D. astdb
2. 若要在**不中断通话**的情况下应用 Asterisk 的配置更改，你应该：
   - A. `systemctl restart asterisk`
   - B. 重启服务器
   - C. `asterisk -rx 'core reload'`
   - D. 重建容器镜像
3. 一个容器化（桥接网络）的 Asterisk 可以连接通话但**没有音频**。最可能的原因是：
   - A. dialplan 配置错误
   - B. 发布的 RTP UDP 端口范围与 `rtp.conf` 中的 `rtpstart`/`rtpend` 不匹配
   - C. CDR 已禁用
   - D. CLI 无法访问
4. 哪些目录必须挂载为**持久化卷**，以确保容器重新部署时不会丢失状态？（多选）
   - A. `/var/spool/asterisk` (voicemail, recordings)
   - B. `/var/lib/asterisk` (astdb)
   - C. `/etc/asterisk` (已从主机绑定挂载)
   - D. `/usr/sbin`
5. 哪个 CLI 命令可以提供当前活跃通话的实时计数？
   - A. `cdr show status`
   - B. `core show channels`
   - C. `pjsip show transports`
   - D. `module show like prometheus`
6. 在 Asterisk 22 中，将通话/通道指标暴露给 Prometheus/Grafana 堆栈的受支持方式是：
   - A. 解析 `full` 日志文件
   - B. 使用 `res_prometheus.so` 模块
   - C. 使用 AGI 脚本
   - D. 没有这种方式
7. 实现 HA 故障转移和跨多个 Asterisk 节点水平扩展的前提条件是什么？
   - A. 以 root 用户身份运行
   - B. 外部化状态（例如在共享数据库中使用 PJSIP Realtime 注册）
   - C. 禁用 CDR
   - D. 使用桥接网络
8. 哪种资源最直接地限制了一台 Asterisk 服务器可以处理的并发通话数量？
   - A. 已注册用户的数量
   - B. 媒体处理，尤其是转码
   - C. `/etc/asterisk` 的大小
   - D. CDR 后端
9. 在云虚拟机上，哪些 `pjsip.conf` 传输设置能让 Asterisk 通告其公网地址，从而使远程音频正常工作？（多选）
   - A. `external_media_address`
   - B. `external_signaling_address`
   - C. `local_net`
   - D. `qualify_frequency`
10. 对于面向互联网的云部署，安全章节的核心规则是：
    - A. 始终运行两个网卡
    - B. 永远不要将原始 Asterisk 直接暴露在互联网上；应在边缘放置一个 SBC（或加固的代理 + Fail2Ban）
    - C. 仅使用 UDP
    - D. 禁用 TLS

**答案：** 1 — B · 2 — C · 3 — B · 4 — A, B · 5 — B · 6 — B · 7 — B · 8 — B · 9 — A, B, C · 10 — B
