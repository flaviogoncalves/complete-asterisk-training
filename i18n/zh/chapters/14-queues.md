# 呼叫队列

呼叫队列，也称为 ACD（自动呼叫分配），对于高效应答客户来电正变得日益重要。自动呼叫分配器可以帮助降低成本、提升服务并促进销售，因为呼叫分配器会影响企业的运作方式——这不仅是短期影响，而是长达多年的深远影响。在呼叫中心环境中，首要因素是人员；他们是最昂贵的资源。招聘、培训和激励座席需要时间、金钱和耐心。借助 ACD，您可以通过精确测算所需的座席数量、管控座席表现以及分析呼叫流程，从而最大化座席的生产力。

## 目标

在本章结束时，您应该能够：

- 理解为何以及如何使用呼叫队列
- 理解呼叫队列的基本理论
- 安装并配置队列系统

## 队列是如何工作的？

呼叫队列并不是什么新鲜事。当您有大量的呼入呼叫流时，很难适当地分配这些呼叫。使用那种让所有座席电话同时振铃的组策略似乎并不奏效，除非您只有少数几个座席。然而，呼叫队列每次只会将呼叫分配给一个可用的座席，并在没有可用座席时让客户保持在等待状态并播放保持音乐。队列的工作原理是保留呼叫，同时寻找空闲的座席来接听。队列最大的好处之一是避免丢失呼叫，同时还能提供生成统计数据的可能性。

![一个呼叫队列：呼入的 1-800 呼叫进入队列，ACD 策略（ringall、rrmemory、leastrecent、priority 等）将其分配给可用座席](../images/14-queues-fig01.png)

通常，呼叫队列的工作方式如下：

- 座席登录到队列。
- 呼入呼叫进入队列。
- 使用队列分配策略将呼叫发送给座席。
- 在呼叫者等待时播放保持音乐。
- 可以向呼叫者发布公告，通知他们等待时间。
- 呼叫由座席接听并生成统计数据。

队列的主要应用场景是客户服务。使用队列，您可以避免在座席忙碌时丢失呼叫。如果您发现队列中的呼叫者数量在增加，可以向队列中添加新的座席。队列的另一个优势是，您现在可以获得诸如呼叫放弃率、平均通话时长和呼叫接听目标等统计数据。这些统计数据将帮助您确定需要多少座席来为客户提供更好的服务。

### ACD 架构

ACD 架构由队列和座席组成。一个座席可以同时处于两个队列中。一个队列可以包含座席、通道和座席组。

![ACD 架构：每个队列（客户服务、内部销售）由一个电话号码接入，并将呼叫分发给座席，座席进而绑定到物理通道](../images/14-queues-fig02.png)

## Queues

队列在 queues.conf 配置文件中定义。座席（Agents）是登录并成为队列成员的接线员。座席在 agents.conf 文件中定义。队列系统在多个版本中得到了显著发展，使得配置文件变得非常庞大。我们将解释其中一些主要的参数。一个值得强调的通用参数是 `autofill`：

```
autofill=yes
```

队列的旧行为是串行类型。队列在分发后续呼叫给下一个座席之前，会等待当前呼叫被处理。如果一个座席需要 15 秒才能接听呼叫，队列中的其他呼叫就必须等待直到该呼叫被接听。对于高并发队列，这种行为效率低下。新的行为 autofill=yes 不会等待呼叫被接听，而是并行工作。你可以使用 mixmonitor 选项录制队列中的呼叫。在此模式下，呼叫会被同时录制和混音。

### 队列配置文件

队列在 queues.conf 文件中进行配置。在图中，你将找到一个队列的工作示例。

![queues.conf 文件的工作示例，显示了 general 部分以及一个包含 strategy、service level、announcements、recording 和 members 的 customerservice 队列](../images/14-queues-fig03.png)

### 座席

你可以在 agents.conf 文件中配置你的座席。座席可以从任何 extension 登录以接收呼叫。你可以使用以下方式拨打座席：

```
Dial(agent/<name>)
```

#### 座席登录

Agent 300 的登录流程如下：

- 用户拨打一个运行 `AgentLogin()` 应用程序的 extension。
- 执行 `AgentLogin()`，座席将与当前 channel 关联。
- 你可以使用命令 `agent show all` 检查座席的状态。

![座席：用户通过拨打运行 agentlogin 应用程序的 extension 进行登录，该程序将 Agent 300 绑定到当前 channel；你可以使用 `agent show all` 检查座席状态](../images/14-queues-fig04.png)

你可以在 agents.conf 文件中定义座席

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

### 成员

成员是响应队列的活动 channel。成员可以是直接的 channel（PJSIP、DAHDI），也可以是在接收呼叫前登录的座席。


### 策略

呼叫根据以下策略之一在成员之间进行分配：

- ringall：响铃所有可用的 channel，直到有人接听。
- leastrecent：分配给最近最少通话的成员。
- fewestcalls：分配给通话次数最少的成员。
- random：随机响铃接口。
- wrandom：随机响铃接口，但在计算指标时将成员的 penalty 作为权重。
- rrmemory：使用带记忆的轮询（round robin）；它会记住上一次呼叫分发到的位置。
- rrordered：与 rrmemory 相同，但保留了配置文件中队列成员的顺序。
- linear：按照 queues.conf 中列出的顺序响铃成员；对于动态成员，则按照它们被添加的顺序。

较旧的 `roundrobin` 策略早在 Asterisk 1.4 中就被弃用了。它不再是一个有文档记录的策略，也不应该再使用：在 Asterisk 22 中，解析器仍然接受 `roundrobin` 这个词，但仅作为映射到 `rrmemory` 的向后兼容别名。请显式使用 `rrmemory`（或 `rrordered`）。以上列表是 Asterisk 22 `queues.conf` 中 `strategy` 选项所记录的策略集合。

## 代理（Agents）

代理（Agents）作为代理通道（proxy channels）实现。它们可以在队列（queues）内部使用。代理通道的另一个用途是分机移动性（extension mobility）。用户可以使用任何电话登录并接收其呼叫。这允许用户前往任何房间将其作为办公室。你可以在 dialplan 中使用 `dial(agent/<name>)` 来拨打代理。你可以在 `agents.conf` 文件中定义代理。

![代理移动性：用户拿起任何电话，拨打登录分机，并输入代理号码和密码；在 `agentlogin()` 成功后，该代理（Agent 300）即可准备接听呼叫，你可以使用 CLI 命令 `agent show all` 来检查状态](../images/14-queues-fig05.png)

### 代理组（Agent Groups）

你可以选择使用代理组。此功能不会考虑 ACD 策略。你可能更倾向于单独列出所有代理。如果你想转接到一个代理组，可以使用 `queues.conf`：

```
member => agent/@1    ; any agent in group 1
member => agent/:1,1  ; any agent in group 1, wait for first available
```

### 代理配置文件

代理在 `agents.conf` 文件中定义。以下是该文件的一个工作示例。

![agents.conf 文件的工作示例：包含 persistentagents 的通用部分，包含默认参数（autologoff、ackcall、endcall、wrapuptime、musiconhold）的代理部分，以及两个代理定义（300 和 301）](../images/14-queues-fig06.png)

## 与 ACD 相关的应用程序

Asterisk 队列系统提供了多个应用程序，用于在 dialplan 中实现队列。下面我们将展示其中的一些。

### 应用程序 queue()

此应用程序将呼入电话排入 `queues.conf` 中定义的特定呼叫队列。选项字符串可以包含零个或多个单字母选项（如下图所示）。除了转接呼叫外，呼叫还可以被驻留，然后由其他用户接听。如果通道支持，可选的 URL 将被发送给被叫方。可选的 AGI 参数将设置一个 AGI 脚本，在呼叫方连接到队列成员后在其通道上执行。超时设置将导致队列在指定的秒数后失败，该时间在每个超时和重试周期之间进行检查。此应用程序在完成后会设置 QUEUE 状态变量：

![queue() 应用程序：其语法 `Queue(queuename,options,URL,announceoverride,timeout,AGI)` — Asterisk 22 使用逗号分隔参数（旧的管道符 `|` 形式已被弃用）— 以及可用的单字母选项 (d, h, H, n, i, r, t, T, w, W)](../images/14-queues-fig07.png)

- TIMEOUT
- FULL
- JOINEMPTY
- LEAVEEMPTY
- JOINUNAVAIL
- LEAVEUNAVAIL

### 应用程序 agentlogin()

此应用程序要求坐席登录到系统。它总是返回 -1。在登录期间，接收呼叫的坐席在有新呼叫进入时会听到提示音。坐席可以通过按 * 键挂断呼叫。

![agentlogin() 应用程序：其语法 `AgentLogin([AgentNo][|options])` 以及用于静默登录（不播报登录确认）的 `s` 选项](../images/14-queues-fig08.png)

### 应用程序 addQueueMember()

此应用程序动态地将设备（例如 PJSIP/3000）添加到队列中。如果该设备已存在，它将返回错误。

```
AddQueueMember(queuename[|interface][|penalty]):
```

#### 应用程序 removeQueueMember()

此应用程序动态地从队列中移除设备。如果该设备不属于该队列，它将返回错误。

```
RemoveQueueMember(queuename[|interface])
```

### 支持应用程序和 CLI 命令

一些应用程序和控制台命令有助于处理队列工作。以下概述了每个应用程序的功能：

![支持应用程序 (AddQueueMember, RemoveQueueMember) 和用于在运行时管理队列的 CLI 命令 (agent show all, queue show, queue show <name>)](../images/14-queues-fig09.png)

## 配置任务

下图总结了创建工作队列系统的主要任务。

![ACD 配置任务：(1) 创建呼叫队列（必需），(2) 定义座席参数（可选），(3) 创建座席（可选），(4) 将队列放入 dialplan（必需），(5) 配置座席录音（可选），以及 (6) 使用 agent show all 和 queue show 进行验证（可选）](../images/14-queues-fig10.png)

第 1 步：在 queues.conf 文件中创建呼叫队列：

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

第 2 步：在 agents.conf 文件中定义座席参数：

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

第 3 步：在 agents.conf 文件中创建座席：

```
;agent => agentid,agentpassword,name
[agents]
agent => 300,300,Test Rep - 300
agent => 301,301,Test Rep . 301
agent => 600,600,Test Ver - 600
agent => 601,601,Test Ver . 601
```

第 4 步：将队列插入到 dialplan 中，在文件 `extensions.conf` 中：

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

### 配置队列录音

呼叫可以使用 Asterisk 的 MixMonitor 应用程序进行录音。（独立的 Monitor 应用程序已在 Asterisk 22 中移除，现在的 queues.conf `monitor-type` 选项仅接受 MixMonitor。）录音功能可以在队列应用程序内启用，从呼叫实际被接听时开始。只有成功的呼叫才会被录音，当用户在收听 MOH 时不会进行录音。要启用监控，只需指定 monitor-format。此功能在其他情况下是禁用的。您可以使用 `Set(MONITOR_FILENAME=<filename>)` 设置录音的文件名；否则它将使用 `MONITOR_FILENAME=${UNIQUEID}`。

在 queues.conf 文件中：

```
monitor-format = wav
monitor-type = MixMonitor
monitor-join = yes
```

## 队列操作

以下示例说明了如何使用队列。

1. 座席登录。示例：电话营销队列中的一名座席拿起电话并拨打 #9000。座席会听到无效登录提示，并被要求输入姓名和密码。审计队列遵循相同的程序。
2. 队列。一旦进入队列，座席将听到 MOH（如果已定义）。当有呼叫进入电话营销队列时，座席会听到一声蜂鸣音，并被连接到该呼叫。
3. 结束呼叫。当座席完成呼叫时，他/她可以：
   - 按 ‘*’ 断开连接并留在队列中。
   - 挂断电话，从而从队列中退出。
   - 按 #8000 将呼叫转接至审计。

## 高级资源

Asterisk 队列系统具有一些高级功能，可以优先处理特定客户和座席，并启用用户菜单。

### 用户菜单

您可以使用一位数的 extension 在用户等待队列时为其定义菜单。要启用此选项，请在队列配置文件 queues.conf 中定义一个 context。

### 惩罚值 (Penalty)

可以为座席配置惩罚值 (penalty)。队列将首先把呼叫发送给惩罚值较低的用户。例如，由于我们知道客户喜欢 Susan 和她柔和的声音，我们可以选择为她分配优先级 0。相反，名为 Uber 的座席经验较少，在客户服务中不太受青睐；因此，我们为该座席分配优先级 10。在 queues.conf 文件中：

```
[customerservice]
member=300,0,Susan the excellent agent
member=300,10,Uber the new guy
```

### 优先级 (Priority)

队列以 FIFO（先进先出）模式运行。如果您想为特殊客户（白金、黄金）提供优先权，可以设置差异化的优先级。对于白金或黄金客户：

```
exten=>111,1,Playback(welcome)
exten=>111,2,Set(QUEUE_PRIO=10)
exten=>111,3,Queue(customerservice)
```

蓝色客户：

```
exten=>112,1,Playback(welcome)
exten=>112,2,Set(QUEUE_PRIO=5)
exten=>112,3,Queue(customerservice)
```

## 应用程序 agentcallbacklogin() 已被移除

应用程序 `agentcallbacklogin()` 在 Asterisk 1.4（2006 年 7 月）中被 Digium 弃用，且在 Asterisk 22 中不再可用。推荐的方法是使用 `AddQueueMember()` 配合 PJSIP 接口，以动态方式向队列添加回调风格的成员。文档 `queues-with-callback-members.txt` 曾包含在旧版 Asterisk `/doc` 目录中，用于提供迁移指导。

旧的 `chan_agent` 通道驱动程序也已被移除；其功能已重写为 `app_agent_pool` 模块，该模块在 Asterisk 22 中提供了 `AgentLogin()`、`AgentRequest()` 以及 `AGENT()` dialplan 函数（这些功能仍然存在 —— `app_agent_pool.so` 随标准的 22 版本发布）。然而，对于现代呼叫中心而言，标准模式是完全跳过 agent 通道，并使用 `AddQueueMember()`/`RemoveQueueMember()` 直接将 agent 的 PJSIP 设备添加到队列中（在 `queues.conf` 中静态添加，或通过 dialplan 或 AMI 动态添加）。这种方法更简单，能与 PJSIP 设备状态完美集成，也是本章所采用的方法。

## 队列统计信息

所有来自队列的事件都会被记录到 /var/log/asterisk/queue_log 中。队列日志的格式发布在 Asterisk 文档目录 /doc 下的 queuelog.txt 文件中。以下是一些最重要的记录事件。

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

您可以构建自己的实用程序来处理这些事件，或者使用现成的统计软件包：

- **QueueMetrics** (<https://www.queuemetrics.com/>) – 一个商业化且维护积极的软件包，它可以解析 `queue_log`，并且仍然是 Asterisk 呼叫中心最完整的报告工具之一。
- **自行开发** – 由于上述 `queue_log` 格式稳定且文档齐全，使用小型脚本（如 Python 等）对其进行解析并将事件馈送到数据库或仪表板中非常简单。

对于比跟踪 `queue_log` 更具事件驱动力的方法，**Asterisk REST Interface (ARI)** 以及 **AMI** 的 `QueueSummary`/`QueueStatus` 操作允许您构建实时队列仪表板和自定义集成，从而针对实时的队列状态进行操作，而不是事后解析日志。ARI 是 Asterisk 22 中用于此类工作的现代且受支持的集成接口。

## 总结

在本章中，您学习了如何使用 ACD、其架构以及如何进行配置。此外，还介绍了优先级和惩罚机制等一些高级功能。

## 测试题

1. 以下哪些是 `queues.conf` 中有效的队列分配策略（请选择所有适用项）？
   - A. ringall
   - B. roundrobin
   - C. leastrecent
   - D. fewestcalls
   - E. rrmemory
   - F. linear
2. 你可以通过在 `queues.conf` 文件中设置 ___ 选项，在队列内录制座席与客户之间的通话。
3. 哪种 `strategy` 会按照在 `queues.conf` 中列出的确切顺序呼叫成员？
   - A. random
   - B. wrandom
   - C. linear
   - D. fewestcalls
4. 在电话营销示例中，当座席结束通话时，他们可以采取哪些操作（请选择所有适用项）？
   - A. 按 `*` 断开连接并保持在队列中
   - B. 挂断电话并从队列中断开连接
   - C. 按 `#8000` 转接通话以进行审计
   - D. 按 `#` 立即从所有队列中注销
5. 要使队列正常工作，需要完成哪两项任务（请选择所有适用项）？
   - A. 创建队列
   - B. 创建座席
   - C. 配置座席参数
   - D. 配置录音
   - E. 将队列放入 dialplan 中
6. 在呼叫队列中，你可以提供一个单数字菜单，供呼叫者在等待时拨打。这是通过在队列的 `queues.conf` 部分定义一个 ___ 来启用的：
   - A. agent
   - B. menu
   - C. context
   - D. application
7. 支持应用程序 `AddQueueMember()` 和 `RemoveQueueMember()` 用于在 ___ 中运行时添加或删除成员：
   - A. dial plan
   - B. command-line interface
   - C. queues.conf
   - D. agents.conf
8. 由于 chan_sip 已在 Asterisk 21 中移除，静态队列成员必须引用如 ___ 之类的通道，而不是 `SIP/1001`。
9. `wrapuptime` 参数是座席断开通话后，队列向该座席发送新呼叫之前所需的最短时间。
   - A. 正确
   - B. 错误
10. 通过在调用 `Queue()` 之前设置 `QUEUE_PRIO` 通道变量，可以使呼叫者在同一个队列中获得更高的排队位置。
    - A. 正确
    - B. 错误

**答案：** 1 — A, C, D, E, F (roundrobin 不是记录在案的策略；在 Asterisk 22 中，它仅作为 rrmemory 的弃用别名存在) · 2 — `monitor-format` (通过指定 `monitor-format` 启用队列录音；在 Asterisk 22 中，`monitor-type` 仅支持 MixMonitor) · 3 — C (linear) · 4 — A, B, C (`*` 断开连接并保持；`#` 不是注销所有队列的按键) · 5 — A, E · 6 — C (`context` 选项) · 7 — A (dial plan) · 8 — `PJSIP/1001` (任何 `PJSIP/` 接口) · 9 — 正确 · 10 — 正确
