# Dial Plan 高级功能

第 3 章讨论了 dialplan 的基础知识。出于教学原因，我们并未解释所有功能，仅介绍了其中最重要的一部分。本章将深入探讨 dialplan，描述高级技术、新的应用程序和相关概念。

## 目标

读完本章后，您应该能够：

- 简化您的 extension 条目
- 处理 dialplan 安全性和过滤 extension
- 使用 IVR 菜单接收呼叫
- 使用子程序以避免不必要的重写
- 使用 “Include” 实现部分 dialplan 安全性
- 使用 AsteriskDB 实现呼叫转移（Follow-me）
- 在您的 PBX 中实现下班后行为
- 使用 switch 命令转移到另一个 PBX
- 实现隐私管理器（Privacy Manager）
- 实现 voicemail
- 实现企业通讯录

## 简化您的 dialplan

您可以使用关键字 “same” 来定义 extension，从而简化您的 dialplan。这应该能减少 dialplan 中拼写错误的数量。请查看以下示例：

```
exten => 4000,1,NoOp()
same  =>      n,Dial(PJSIP/005C2B313E22)
```

## Dial Plan 安全性

在 Asterisk dialplan 中发现了一个漏洞，该漏洞允许用户向您的 dialplan 中注入新的通道和拨号号码。假设您的服务器中存在以下行 `exten=>_X.,1,Dial(PJSIP/${EXTEN})`，并且某个恶意用户在 softphone 中拨打了号码 `3000&DAHDI/1/011551123456789`。SIP 协议默认接受任何字母数字字符，因此拨打的 extension 实际上会触发两个呼叫：一个针对通道 PJSIP/3000，另一个针对通道 DAHDI/011551123456789（这是一个国际号码）。因此，任何有权访问 extension 的用户实际上都可以拨打世界上的任何地方。避免这种行为的最简单方法是在调用 dial 应用程序之前过滤号码。FILTER() 函数对此非常方便。示例：

```
exten=>_X.,1,DIAL(PJSIP/${FILTER(0-9,${EXTEN})})
```

该应用程序过滤器将允许您过滤掉拨打号码中除 0 到 9 以外的所有字符。更多信息可以在 Asterisk 提供的 README-SERIOUSLY.bestpractices.txt 文件中找到。

## 使用 IVR 菜单接收呼叫。

在上一节中，您通过 DID 或转接至话务员的方式接收了所有呼叫。现在，您将学习如何实现 IVR 菜单以及创建自动总机服务。在进入具体细节之前，让我们先了解一些新的应用程序。我们将 `core show application` 命令的输出放在下面，只是为了方便读者阅读。您可以自行使用 `core show application <application_name>` 获取这些描述。

### Background() 应用程序

此应用程序将播放给定的文件列表，同时等待呼叫通道拨打 extension。要在该应用程序播放完文件后继续等待数字输入，应使用 WaitExten 应用程序。langoverride 选项明确指定了尝试为所请求的声音文件使用的语言。任何指定的 context 都将成为该应用程序在退出到已拨 extension 时所使用的 dialplan context。如果所请求的声音文件之一不存在，呼叫处理将被终止。选项：

- s - 如果通道未处于 'up' 状态（即尚未接听），则跳过消息的播放。如果发生这种情况，应用程序将立即返回。
- n - 在播放文件之前不接听通道。
- m - 仅当按下的数字与目标 context 中的一位数 extension 匹配时才中断。

### Record() 应用程序

此应用程序将来自通道的内容录制到给定的文件名中。如果文件已存在，它将被覆盖。

![10-dialplan-advanced-features figure 1](../images/10-dialplan-advanced-features-img01.png)

- 'format' 是要录制的文件类型格式（wav, gsm 等）。
- 'silence' 是返回前允许的静音秒数。
- 'maxduration' 是最大录制时长（以秒为单位）；如果缺失或为零，则没有最大限制。
- 'options' 可能包含以下任意字母：
    - `a` — 追加到现有录音而不是替换它
    - `n` — 不接听，但如果线路尚未接听，仍进行录制
    - `q` — 静音（不播放蜂鸣音）
    - `s` — 如果线路尚未接听，则跳过录制
    - `t` — 使用替代的 `*` 终止键 (DTMF) 代替默认的 `#`
    - `x` — 忽略所有终止键 (DTMF) 并持续录制直到挂断

如果文件名包含 %d，这些字符将在每次录制文件时被递增的数字替换。使用 core show file formats 查看系统上可用的格式。用户可以按 # 键终止录制并继续执行下一个优先级。如果用户在录制过程中挂断，所有数据都将丢失，应用程序将终止。

### Playback() 应用程序

此应用程序回放给定的文件名（不包含扩展名）。选项也可以包含在管道符号之后。'skip' 选项会导致如果通道未处于 'up' 状态（即尚未接听），则跳过消息的播放。

![10-dialplan-advanced-features figure 2](../images/10-dialplan-advanced-features-img02.png)

![10-dialplan-advanced-features figure 3](../images/10-dialplan-advanced-features-img03.png)

如果指定了 'skip'，且通道未摘机，应用程序将立即返回。否则，除非指定了 'noanswer'，否则通道将在播放声音之前被接听。并非所有通道都支持在未摘机时播放消息。如果指定了 'j'，当文件不存在时，应用程序将跳转到优先级 n+101（如果存在）。此应用程序在完成后设置以下通道变量：

- PLAYBACKSTATUS — 回放尝试的状态，作为文本字符串，为以下之一：
    - `SUCCESS`
    - `FAILED`

### Read() 应用程序

此应用程序从用户处读取预定数量的字符串数字，读取一定次数，并存入给定的变量中。

- filename -- 在读取数字或使用 i 选项播放提示音之前要播放的文件
- maxdigits -- 可接受的最大数字位数。在输入 maxdigits 位数字后停止读取（无需用户按 # 键）。默认为 0 - 无限制 - 等待用户按 # 键。任何小于 0 的值含义相同。最大可接受值为 255。

![10-dialplan-advanced-features figure 4](../images/10-dialplan-advanced-features-img04.png)

![10-dialplan-advanced-features figure 5](../images/10-dialplan-advanced-features-img05.png)

- option -- 选项为 `s`, `i`, `n`：
    - `s` — 如果线路未接通，则立即返回
    - `i` — 将 filename 作为来自您的 `indications.conf` 的提示音播放
    - `n` — 即使线路未接通也读取数字
- attempts -- 如果大于 1，则表示在未输入数据的情况下将进行的尝试次数
- timeout -- 等待数字响应的整数秒数。如果大于 0，该值将覆盖默认的超时时间。

如果函数失败或出错，read() 应用程序应断开连接。

### Gotoif() 应用程序

此应用程序将根据给定条件的评估结果，使呼叫通道跳转到 dialplan 中的指定位置。如果条件为真，通道将继续在 labeliftrue 处执行；如果条件为假，则在 'labeliffalse' 处执行。标签的语法与 Goto 应用程序中使用的语法相同。如果条件选择的标签被省略，则不执行跳转；相反，执行将继续 dialplan 中的下一个优先级。

### 实验：逐步构建 IVR 菜单

让我们创建一个具有以下功能的 IVR 菜单。拨打时，IVR 会播放一段音频文件，内容为：“欢迎致电 XYZ 公司；按 1 转销售部，按 2 转技术支持，按 3 转培训部，或等待与人工代表通话。” 数字将呼叫者路由如下：

- `1` — 转接至销售部 (PJSIP/4001)
- `2` — 转接至技术支持 (PJSIP/4002)
- `3` — 转接至培训部 (PJSIP/4003)
- 未按任何数字 — 转接至话务员 (PJSIP/4000)

**第 1 步 – 录制提示音**

让我们创建一个 extension 来录制提示音。要录制提示音，请从 softphone 拨打至 `9003<filename>`（例如，`9003welcome`）。听到蜂鸣音后，开始录制；按 `#` 停止。您将听到一声蜂鸣，系统将回放录制的提示音。

**第 2 步 – 创建菜单逻辑**

拨打 9004 extension 时，处理过程跳转到 `s` extension 的菜单，优先级为 1。

### 拨号时匹配

这是一个用于接收呼叫的公司设置菜单。`Background()` 应用程序播放欢迎提示音，然后等待数字输入，将呼叫者拨打的号码与当前 context 中定义的 extensions 进行匹配。

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

当您拨打该公司电话时，首先会播放欢迎消息。之后，Asterisk 等待拨入数字：

| 拨打号码 | Asterisk 动作 |
|---------------|-----------------|
| 1 | 立即呼叫 `Dial(DAHDI/1)` |
| 2 | 等待超时，然后呼叫 `Dial(DAHDI/2)` |
| 21 | 立即呼叫 `Dial(DAHDI/3)` |
| 22 | 立即呼叫 `Dial(DAHDI/4)` |
| 3 | 等待超时，然后断开连接 |
| 31 | 立即呼叫 `Dial(DAHDI/5)` |
| 32 | 立即呼叫 `Dial(DAHDI/6)` |

避免菜单中的歧义非常重要。每个人都希望被快速应答。因此，您不应该同时使用数字 2、21 或 22。

### 实验：使用 Read() 应用程序

请尝试使用 read() 应用程序进行实验。Read 接收用户输入的数字并将其插入到指定的变量中；然后您可以使用 gotoif 应用程序来重定向呼叫。

## Context inclusion

一个 context 可以包含另一个 context 的内容。在上面的示例中，任何 channel 都可以拨打 internal context 中的任何 extension，但只有 4003 channel 可以拨打国际 extension。你可以使用 context inclusion 来简化 dialplan 的创建。通过使用 context inclusion，你可以控制谁有权访问哪些 extension。

### 排查“number not found”消息

收到“number not found”消息是非常常见的。大多数人会混淆 included contexts 的概念，因为它确实不太直观。作为经验法则，首先转到传入 channel 的配置文件，例如 `pjsip.conf`、`chan_dahdi.conf` 和 `iax.conf`，并确定当前的 context。然后，转到 extensions.conf 文件中的 dialplan，检查拨打的号码是否可以在该 context 中找到。如果没有，说明你的 dialplan 有问题。关于 context 的黄金法则是：1. 一个 channel 只能拨打与该 channel 处于同一 context 内的号码。2. 处理呼叫的 context 是在传入 channel 的配置文件（`chan_dahdi.conf`、`iax.conf`、`pjsip.conf`）中定义的。

## 使用 switch 语句

你可以使用 switch 命令将 dialplan 处理过程发送到另一台服务器。你需要提供另一台服务器的名称和密钥。context 是目标 context。

![10-dialplan-advanced-features 图 6](../images/10-dialplan-advanced-features-img06.png)

## Dial plan 处理顺序

当 Asterisk 收到呼入呼叫时，它会在通道定义的 context 中进行查找。在某些情况下，如果多个模式与拨打的号码匹配，Asterisk 可能无法按照您预想的方式处理呼叫。您可以使用 dialplan show CLI 命令查看匹配顺序。例如：假设您希望拨打 912 时路由到模拟 trunk (DAHDI/1)，而所有其他以 9 开头的号码路由到另一个模拟 trunk (DAHDI/2)。您可以编写如下内容：

```
[example]
exten=>_912.,1,Dial(DAHDI/1/${EXTEN})
exten=>_9.,1,Dial(DAHDI/2/${EXTEN})
```

如果两个模式都匹配同一个 extension，您可以使用包含的 context 来控制哪个 extension 被优先处理。被包含的 context 的处理优先级低于同一 context 中的模式。

## #INCLUDE 语句

我们应该使用一个大文件还是多个文件？你可以使用 #include <filename> 语句在 extensions.conf 中包含其他文件。例如，我们可以创建一个用于本地用户的 users.conf 和一个用于特殊服务的 services.conf。请注意不要将 #include <filename> 与

```
include=>context statement.
```

## 使用 GOSUB 的子程序

在旧版本的 Asterisk 中，您可以使用 Macro 命令。该命令早已被弃用，取而代之的是 GOSUB。我们将在此演示如何以简单且有序的方式创建用于 voicemail 处理的子程序。命令格式如下：

```
gosub([[context,]exten,]priority[(arg1[,...][,argN])])
```

GOSUB 命令自 Asterisk 1.6 版本起便已提供，并支持传递参数（在子程序内部可作为 `${ARG1}`、`${ARG2}` 等使用）。有了参数，现在完全可以替代旧的 Macro 命令。Macros（`app_macro`）已在 Asterisk 21 中被移除；您必须使用 GOSUB 来实现子程序。

### 创建子程序

其定义方式非常相似。请查看下方为 voicemail 定义的名为 stdexten 的子程序（您可以选择自己喜欢的名称）。在使用第一个参数（通道名称）调用 Dial 命令后，我们检查 ${DIALSTATUS} 以将呼叫逻辑发送到下一步。

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

### 调用子程序

调用子程序时，请注意在参数前使用括号。

```
exten=>6000,1,Gosub(stdexten,s,1(PJSIP/6000,${EXTEN}))
exten=>6001,1,Gosub(stdexten,s,1(PJSIP/6001,${EXTEN}))
exten=>6002,1,Gosub(stdexten,s,1(PJSIP/6002,${EXTEN}))
exten=>6003,1,Gosub(stdexten,s,1(PJSIP/6003,${EXTEN}))
```

## 使用 Asterisk DB

为了实现呼叫转移和黑名单功能，我们需要一种存储和恢复数据的方法。幸运的是，Asterisk 提供了一种机制，用于从名为 AstDB 的内置数据库中存储和检索数据。在现代 Asterisk（包括 Asterisk 22）中，AstDB 由 **SQLite3** 提供支持（文件为 `/var/lib/asterisk/astdb.sqlite3`）；Asterisk 1.8 及更早版本使用 Berkeley DB v1。这类似于 Windows 注册表数据库，使用了家族（family）和键（key）的层级概念。数据在 Asterisk 重启后依然存在。family/key API 与旧的后端相比没有变化；仅磁盘上的存储格式发生了改变。

### 函数、应用程序和 CLI 命令

有一些函数、应用程序和 CLI 命令可以与 AstDB 配合使用：

- variable=${DB(<family/key>)}
- DB(<family/key>)=value
- DB_EXISTS(<family/key>)

示例：

```
exten=_*21*XXXX,1,Set(DB(CFIM/${CALLERID(num)})=${EXTEN:4})
exten=s,1,Set(temp=${DB(CFIM/${EXTEN})})
```

一些应用程序可用于操作 AstDB：

- DB_DELETE(<family/key>) — 返回并删除单个键的函数
- DBdeltree(<family>) — 删除整个家族/子树的应用程序

旧的 `DBdel()` 应用程序在 Asterisk 22 中已不再存在。使用 `DB_DELETE()` dialplan 函数删除单个键 — 例如 `Set(x=${DB_DELETE(family/key)})`，或者作为写操作使用 `Set(DB_DELETE(family/key)=)`。 `DBdeltree()`（删除整个家族/子树）仍然是一个应用程序。

也可以使用 CLI 命令来设置和删除键：

- database del
- database put
- database show <family[/key]>
- database showkey
- database deltree
- database get

![10-dialplan-advanced-features figure 7](../images/10-dialplan-advanced-features-img07.png)

![10-dialplan-advanced-features figure 8](../images/10-dialplan-advanced-features-img08.png)

### 实现呼叫转移、DND 和黑名单

在此示例中，您将学习如何实现立即呼叫转移和遇忙呼叫转移。我们将使用 *21* 来设置立即呼叫转移，使用 *61* 来设置遇忙呼叫转移。要取消设置，请分别使用 #21# 和 #61#。使用上面的示例来填充数据库。使用的家族包括：

- CFIM – 立即呼叫转移 (Call Forward Immediate)
- CFBS – 遇忙呼叫转移 (Call Forward on Busy status)
- DND – 免打扰 (Do Not Disturb)

尝试通过拨号来填充数据库：

- *21* (立即呼叫转移的目标 extension)
- *61* (遇忙呼叫转移的目标 extension)
- *41* (设置为免打扰的 extension)

使用 CLI 命令 database show 查看添加的家族、键和值。

![10-dialplan-advanced-features figure 9](../images/10-dialplan-advanced-features-img09.png)

![10-dialplan-advanced-features figure 10](../images/10-dialplan-advanced-features-img10.png)

### 呼叫转移、黑名单、DND

该子程序验证数据库是否包含对应于 CFIM、CFBS 或 DND 的 key:value 对，然后进行相应的处理。以下子程序调用了拨号例程：

```
exten=_4XXX,1,gosub(stdexten,s,1(${EXTEN}))
```

## 使用黑名单

旧的 `LookupBlacklist()` 应用程序已从 Asterisk 中**移除**（它与传统的“priority+101 jump”机制一同消失了）。在 Asterisk 22 中，你可以直接使用 `DB_EXISTS()` 函数（该函数既能测试键是否存在，若存在还能在 `${DB_RESULT}` 中暴露其值）配合 `GotoIf` 来构建黑名单。将每个被拦截的号码作为键存储在 `blacklist` 系列中，然后在入站 context 的顶部检查主叫号码：

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

当主叫号码存在于数据库中时，`DB_EXISTS(blacklist/${CALLERID(num)})` 会返回 `1`（将呼叫发送至 `blocked` context），否则返回 `0`，从而使呼叫继续进入正常的 `Dial()`。

要将号码加入黑名单，我们可以使用与之前相同的资源，拨打 *31* 后跟要加入黑名单的 extension。要从黑名单中移除号码，应拨打 #31# 后跟要移除的号码。

```
[apps]
exten=>_*31*X.,1,Set(DB(blacklist/${EXTEN:4})=1)
exten=>_*31*X.,2,Hangup()
exten=>_#31#X.,1,Set(x=${DB_DELETE(blacklist/${EXTEN:4})})
exten=>_#31#X.,2,Hangup()
```

你也可以使用控制台 CLI 将号码插入黑名单：

```
*CLI>database put blacklist <name/number> 1
```

注意：任何值都可以与该键关联。`DB_EXISTS()` 测试仅搜索键，而不搜索值。要从黑名单中删除该号码，你可以使用：

```
*CLI>database del blacklist <name/number>
```

## 基于时间的 context

在下图中，我们有一个包含三个 context 的 dialplan。[incoming] context 是通常接收呼叫的地方。我们包含了四行根据系统时间改变行为的代码，示例如下：

```
include => context,<times>,<weekdays>,<mdays>,<months>
```

现代 Asterisk（包括 22 版本）使用**逗号**而不是管道符来分隔 time-include 字段。旧版的管道符形式（`include => context|times|weekdays|mdays|months`）会被解析为普通的字面量 context 名称，并且在应用时间条件时会静默失败。

在正常工作时间内，处理过程将被重定向到 mainmenu，在那里它可能会调用一个 IVR 来处理呼叫。如果呼叫发生在下班时间，它将呼叫 ${SECURITY} 变量中定义的 security extension。如果 security extension 没有应答呼叫，呼叫将被发送到接线员的 voicemail。

![10-dialplan-advanced-features figure 11](../images/10-dialplan-advanced-features-img11.png)

![10-dialplan-advanced-features figure 12](../images/10-dialplan-advanced-features-img12.png)

## 使用 gotoiftime() 实现基于时间的呼叫处理

GotoIfTime() 的语法如下所示。

```
GotoIfTime(times,weekdays,mdays,months[,timezone]?[labeliftrue][:labeliffalse])
```

在 Asterisk 22 中，字段分隔符为**逗号**，而非竖线（竖线形式在 Asterisk 1.6 中已被弃用）。支持可选的 `timezone` 字段，每个分支标签均使用常见的 `[[context,]extension,]priority` 格式。

此应用程序可以替代基于时间的 context，并且看起来更易于理解和阅读。您可以按如下方式指定时间：

- <timerange>=<hour>':'<minute>'-'<hour>':'<minute> |"*"
- <daysofweek>=<dayname>|<dayname>'-'<dayname>|"*"
- <dayname>="sun"|"mon"|"tue"|"wed"|"thu"|"fri"|"sat"
- <daysofmonth>=<daynum>|<daynum>'-'<daynum> |"*"
- <daynum>=1 到 31 之间的数字
- <hour>=0 到 23 之间的数字
- <minute>=0 到 59 之间的数字
- <months>=<monthname>|<monthname>'-'<monthname>|"*"
- <monthname>="jan"|"feb"|"mar"|"apr"|"may"|"jun"|"jul"|"aug"|"sep"|"oct"|"nov"|"dec"

星期和月份的名称不区分大小写。

```
exten=>s,1,GotoIfTime(8:00-18:00,mon-fri,*,*?normalhours,s,1)
```

如果呼叫发生在周一至周五的 08:00AM 到 06:00PM 之间，上述语句会将处理流程转移到 normalhours context 中的 extension s。

## 使用 DISA 获取新的拨号音

DISA，即“直接向内系统访问”（direct inward system access），是一个允许用户获取第二个拨号音的系统。它允许用户再次拨号到另一个目的地。技术人员经常在周末拨打长途电话进行技术支持时使用它；他们无需从家中直接拨打目的地，而是拨打办公室的 DISA 号码，获取拨号音，然后再拨打目的地。长途费用由公司承担，而不是由家庭电话承担。

```
DISA(passcode|filename[,context[,cid[,mailbox[@context][,options]]]])
```

示例：

```
exten => s,1,DISA(no-password,default)
```

使用上述语句，用户拨打 PBX，无需任何密码即可获得拨号音。任何使用 DISA 的呼叫都将使用 `default` context 进行处理。此应用程序的参数包括全局密码或文件中的个人密码。如果未指定 context，则默认为 `disa` context。如果您使用密码文件，则必须指定完整路径。也可以为 DISA 外部拨号指定主叫号码（caller ID）。示例：

```
exten => s,1,DISA(numeric-passcode,default,"Flavio" <4830258590>)
```

Asterisk 22 使用逗号作为参数分隔符（管道符形式在 1.6 版本中已被弃用）。第一个参数可以是单个密码或密码文件的路径，当未指定 context 时，默认值为 `disa`。

## 限制并发呼叫

GROUP() 函数允许您统计同一组中同时处于活动状态的通道数量。例如：您在里约热内卢有一个分支机构，那里的电话遵循 “_214X” 模式。该地点由一条租用线路提供服务，预留了 64K 的语音带宽。在这种情况下，允许的最大呼叫数为 2（G.729，每个呼叫约 31.2K）。要将里约的呼叫限制为两个，请执行以下操作：

```
exten=>_214X,1,set(GROUP()=Rio)
exten=>_214X,n,Gotoif($[${GROUP_COUNT()} > 1]?outoflimit)
exten=>_214X,n,Dial(PJSIP/${EXTEN})
exten=>_214X,n,hangup
exten=>_214X,n(outoflimit),playback(callsexceedcapacity)
exten=>_214X,n,hangup
```

## Voicemail

Voicemail 是一种计算机化的电话应答系统，它记录传入的语音消息，将其保存在磁盘上或通过电子邮件发送。有时它包含一个目录，您可以通过姓名查找 voicemail 信箱。过去，voicemail 系统非常昂贵。现在，随着 IP 电话技术的发展，voicemail 正成为一项标准功能。

要配置 voicemail，您应该按照以下步骤进行操作。

**第 1 步：编辑 `voicemail.conf` 并设置常规参数。**

- `format` — 用于录制消息的 codec（例如：wav49, wav, gsm）
- `serveremail` — 电子邮件通知应显示的发件人
- `maxmsg` — 信箱中消息的最大数量；超过此阈值后，消息将被丢弃
- `maxsecs` — voicemail 消息的最大长度（以秒为单位）
- `minsecs` — 消息的最小长度（以秒为单位）；低于此阈值，将不会录制消息
- `maxsilence` — 多少秒的静音将被视为消息结束

**第 2 步：编辑 `voicemail.conf` 并创建用户的信箱。**

### Voicemail.conf

信箱定义为每个信箱一行，格式如下：

```
mailboxID => pincode,fullname,email,pager-email,options
```

各字段含义如下：

- **MailboxID** — 通常是 extension 号码
- **Pincode** — 访问 voicemail 系统的密码
- **Full name** — 由目录应用程序使用
- **E-mail** — 用于 voicemail 通知地址
- **Pager e-mail** — 通过 SMS 网关或寻呼机进行通知的地址
- **Options** — 每个信箱的选项（与 `[general]` 中的选项相同，但应用于此信箱）

Voicemail 有几个控制其行为的选项。目前，我们将坚持使用默认选项，并专注于信箱定义。在文件中的 `[general]` 部分之后，您可以开始配置信箱 ID，每个 ID 都在其自己的 context 中。示例：

```
[general]
[default]
1234=>1234,SomeUser,email@address.com,pager@address.com,saycid=yes|dialout=fromvm|callback=fromvm|review=yes|operator=yes
```

请在文件 `voicemail.conf` 中查看高级选项。

**第 3 步：配置文件 `extensions.conf`。**

前面（在 *Subroutines with GOSUB* 下）显示的 `stdexten` 子程序正是您此处所需的呼叫/voicemail 处理程序：它拨打 extension 并使用通道变量 `${DIALSTATUS}` 的值将呼叫流重定向到正确的 voicemail 问候语（`b` 表示忙线，`u` 表示不可用）。在 `extensions.conf` 中的每个 extension 使用 `Gosub(stdexten,s,1(PJSIP/<device>,<mailbox>))` 调用它。

## 使用 VoiceMailMain() 应用程序

应用程序 voicemailmain() 用于配置语音信箱。用户可以拨打该应用程序，录制问候语并收听语音留言。要在 dialplan 中调用该应用程序，请使用：

```
exten=>9000,1,VoiceMailMain()
```

以下是该应用程序可用选项的列表。

### Voicemail 应用程序语法

该应用程序允许呼叫方为指定的邮箱列表留言。当指定多个邮箱时，问候语将取自第一个指定的邮箱。如果指定的邮箱不存在，dialplan 的执行将停止。语法如下所示：

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

![10-dialplan-advanced-features 图 13](../images/10-dialplan-advanced-features-img13.png)

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

在所有情况下，beep.gsm 文件都会在录音开始前播放。语音留言将存储在 inbox 目录中。

```
/var/spool/asterisk/voicemail/context/boxnumber/INBOX/
```

如果呼叫者在通知期间按下 0（零），呼叫将被转移到当前 voicemail context 中的 ‘o’ (out) extension。这可用于转接至话务员。如果在录音过程中呼叫者按下 # 或静音限制超时，录音将停止，呼叫将进入下一个优先级。请确保在播放语音留言后处理呼叫，如下所示。

```
exten=>somewhere,5,Playback(Goodbye)
exten=>somewhere,6,Hangup
```

### 将语音留言标记为紧急

您可以将某些留言标记为“紧急”。为此有两种可用方法：

- 在应用程序 voicemail() 中传递选项 ‘U’
- 在文件 voicemail.conf 中指定 review=yes。如果使用此选项，用户将能够在录制语音指令后将留言标记为紧急。

## 将语音留言发送至电子邮件

在某些情况下（比如我的情况），我们根本不会使用 `voicemailmain()` 应用程序来读取语音留言。将所有留言连同音频附件一起发送到电子邮件中会更简单、更实用。通过使用 `attach` 和 `delete` 参数，您可以将所有邮件发送到电子邮件，并将其从邮箱中删除。

```
attach=yes
delete=yes
```

为了将语音留言发送至电子邮件，Asterisk 的语音留言应用程序会使用邮件传输代理（MTA），这是您操作系统的一个组件。Debian 使用 Exim 作为 MTA。发送电子邮件的应用程序在 `mailcmd` 参数中定义。

```
mailcmd =/usr/sbin/sendmail -t
```

在 Debian 发行版的 Linux 中，MTA 是 Exim。要在 Debian 中配置 Exim，请使用：

```
dpkg-reconfigure exim4-config
```

您可以选择让您的 MTA 通过 SMTP 或智能主机（通常是您公司的邮件服务器）直接发送电子邮件。请与您的电子邮件管理员确认从 Asterisk 服务器发送电子邮件到您的电子邮件服务器的最佳方式。

## 自定义电子邮件消息

您可以通过设置以下变量来控制消息的发送方式：电子邮件主题和电子邮件正文的变量：

- VM_NAME
- VM_DUR
- VM_MSGNUM
- VM_MAILBOX
- VM_CIDNUM
- VM_CIDNAME
- VM_CALLERID
- VM_DATE

电子邮件正文和主题是根据您在 `voicemail.conf` 的 `[general]` 部分中设置的模板构建的。您可以修改正文和主题，但消息的大小限制为 512 字节。在模板中，`\n` 插入一个换行符，`\t` 插入一个制表符。

下面的 `emailsubject` 示例非常直观。而 `emailbody` 示例与默认设置非常接近；默认设置仅在 CIDNAME 不为空时显示它，否则显示 CIDNUM，如果两者都为空，则显示 "an unknown caller"。

```
emailsubject=[PBX]: New message ${VM_MSGNUM} in mailbox ${VM_MAILBOX}

emailbody=Dear ${VM_NAME}:\n\n\tjust wanted to let you know you were just left a ${VM_DUR} long message (number ${VM_MSGNUM})\nin mailbox ${VM_MAILBOX} from ${VM_CALLERID}, on ${VM_DATE}, so you might\nwant to check it when you get a chance. Thanks!\n\n\t\t\t\t--Asterisk\n
```

## Voicemail Web 界面

在 Asterisk 源码发行版中有一个名为 `vmail.cgi` 的 Perl 脚本，它位于 Asterisk 源码树中的 `contrib/scripts/vmail.cgi`（它在 Asterisk 22 中仍然随附）。命令 `make install` 不会安装此界面；你必须从源码目录运行 `make webvmail`。此脚本需要服务器上安装 Perl 命令解释器和一个 Web 服务器（例如 Apache）。

```
make webvmail
```

`make webvmail` 目标会将该脚本（setuid root）安装到你 Web 服务器的 CGI 目录（`HTTP_CGIDIR`）中，并将支持图像从 `images/*.gif` 复制到 `HTTP_DOCSDIR/_asterisk`（默认情况下为 `/var/www/html/_asterisk`）。如果这些路径与你的 Web 服务器布局不匹配，请在运行该目标之前编辑顶层 `Makefile` 中的 `HTTP_CGIDIR` 和 `HTTP_DOCSDIR` 变量。

## Voicemail notification

您可以配置 voicemail，以便在您有新的 voicemail 时向您的电话发送通知消息。在 Asterisk 22 中，Message Waiting Indication (MWI) 可与 PJSIP 和 SIP 电话以及 DAHDI 电话配合使用。为了指示有未收听的 voicemail，指示灯可能会闪烁，或者电话可能会播放提示音。您需要在相应的通道配置文件中配置邮箱。示例：`pjsip.conf`（在 endpoint 部分中）：

```
mailboxes=8590
```

在 PJSIP 中，邮箱提示是通过 `pjsip.conf` 的 endpoint 部分内的 `mailboxes` 选项设置的，而不是 `sip.conf` 的旧版 `mailbox=`。MWI 订阅由 `res_pjsip_mwi` 模块处理。

![Comedian Mail Web 界面（`vmail.cgi`）：Asterisk Web-Voicemail 登录界面 — 输入您的邮箱和密码，即可通过浏览器播放、保存、转发或删除 voicemail。它仍然随 Asterisk 22 一起发布，并随 `make webvmail` 一起安装。](../images/10-dialplan-advanced-features-img14.png)

### 实验：电话上的消息通知

本实验使用 SIP softphone 进行了测试。

1. 编辑 `pjsip.conf` 并在名为 4401 的设备对应的 endpoint 部分中添加 `mailboxes=4401`。
2. 编辑 `extensions.conf` 并创建一个 extension，用于将 voicemail 录制到 4401 extensions。

```
exten=9008,1,voicemail(4401,b)
```

3. 进入控制台并重新加载。
4. 在 SipPulse softphone 中，打开 SIP 账户设置并启用该账户的 voicemail (message-waiting) 检查功能。
5. 拨打 9008 并留言。
6. 观察电话上的消息图标。

## 使用 directory 应用程序

此应用程序允许您快速查找要拨打的用户。姓名列表和对应的 extension 是从 voicemail 配置文件 voicemail.conf 中检索的。可以使用 core show application directory 查看该应用程序的语法：

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

### 实验：使用 directory 应用程序

1. 编辑 voicemail.conf 文件，在 dialplan 中添加两个 extension

```
[default]
; Define maximum number of messages per folder for a particular context.
;maxmsg=50
4400=>4400,Clint Eastwood,ceastwood@voip.school
4401=>4401,John Wayne,jwayne@voip.school
```

2. 在您的 dialplan 中创建这些 extension

```
exten=9006,1,VoiceMailMain()
exten=9006,n,Hangup()
exten=9007,1,Directory(default,default)
exten=9007,n,Hangup()
```

3. 进入控制台并执行 reload
4. 拨打 9006 并为每个 extension (4400, 4401) 录制一个姓名
5. 拨打 9007 并为其中一个 extension 选择姓氏的前三个字母 (Eas=327)。如果这是正确的选项，请按 ‘1’ 转接到该姓名。

## 实验：综合应用

到目前为止，您已经学习了几个 dialplan 概念。让我们将所有的应用程序、函数和概念整合到一个 dialplan 示例中，以便您了解它们是如何协同工作的。我们将引导您完成以下场景的整个 PBX 配置。

- 4 个模拟 trunk
- 16 个基于 SIP 的 extension
- 3 种服务等级：
    - restrict（内部、本地和 1-800）
    - ld（长途）
    - ldi（国际）
- 下班后留言
- 自动总机

### 第 1 步 – 配置通道

**模拟 trunk (`chan_dahdi.conf`)。** 首先，我们将在 DAHDI 通道配置文件 `chan_dahdi.conf` 中配置模拟 trunk。在本例中，我们将使用带有 4 个 FXO 接口的 T400P Digium 卡。假设驱动程序已加载，并且驱动程序配置文件 (/etc/dahdi/system.conf) 已正确配置。

![10-dialplan-advanced-features figure 16](../images/10-dialplan-advanced-features-img16.png)

```
signalling=fxs_ks
language=en
context=incoming
group=1
channel => 1-4
```

**SIP 通道 (`pjsip.conf`)。** 我们选择了从 2000 到 2099 的 dialplan 编号。将使用两种 codec：G.729 和 G.711 ulaw。前者将用于通过 Internet 或 WAN 使用 Asterisk 的电话，而后者将用于使用本地网络的电话。在 `pjsip.conf` 中，我们将仲裁哪些设备将属于每个服务等级（restrict、ld、ldi）。为了降低对暴力破解攻击的脆弱性，我们将使用电话的 MAC 地址作为设备名称。我强烈建议您使用强密码以避免暴力破解攻击！

我们定义了一个 transport 和三个可重用的模板——一个带有共享 codec 的 endpoint 基础模板、一个摘要认证和一个单联系人 AOR——然后将每个设备附加到模板上，并仅覆盖不同的部分（其服务等级 context 和凭据）。`host=dynamic` 成为电话注册的 AOR，而 `directmedia` 成为 `direct_media`：

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

### 第 2 步 – 配置 dialplan

现在让我们开始配置 extensions.conf。定义内部 extension 和本地拨号

```
[restrict]
exten=>_2000,1,Dial(PJSIP/00001A000002,20,t)
exten=>_2030,1,Dial(PJSIP/00001A000003,20,t)
exten=>_2040,1,Dial(PJSIP/00001A000004,20,t)
exten=>_9XXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20) ; local calls
exten=>_91800.,1,Dial(DAHDI/g1/${EXTEN:1},20); 1-800
```

定义 LD（长途）

```
[ld]
Include=>restrict
exten=>_9NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

定义国际呼叫

```
[ldi]
include=>ld
exten=>_901X.,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

### 第 3 步 - 使用自动总机接收呼叫

要接收呼叫，请使用两个 context。第一个用于正常工作时间的运行，呼叫将由自动总机接收。第二个用于下班后，呼叫者将收到一条消息，例如“您已拨打 XYZ 公司，我们的正常工作时间是上午 08:00 到下午 06:00；如果您知道目标 extension 号码，现在可以尝试拨打，或者挂断。” 菜单：正常工作时间、下班后。在下面的菜单中，系统将播放一条消息，警告呼叫者是在正常工作时间之外拨入的，允许呼叫者拨打目标 extension 号码（可能有人在正常工作时间之后工作）。

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

菜单：主菜单和销售部。在正常工作时间内，呼叫由自动总机菜单应答，接收到一条消息，例如“欢迎致电 XYZ 公司；拨 1 转销售部，拨 2 转技术支持，拨 3 转培训部，或拨打所需 extension 号码”。

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

有了所有这些语句，您的拨号计划功能现已就绪。在下一节中，我们将演示如何操作 PBX。

## 总结

在本章中，您学习了如何使用 IVR 或自动话务员来接收呼叫。您研究了 context 包含的概念并实现了一些示例。我们使用了子程序来避免重复输入，并使用 Asterisk 数据库（AstDB，在 Asterisk 22 中由 SQLite3 提供支持）来实现需要数据存储的功能（例如呼叫转移、免打扰、黑名单）。最后，您学习了如何实现下班后的行为，并使用这些概念实现了一个完整的 dialplan。

## 测试题

1. 基于时间的 context 包含使用格式 `include => context,<times>,<weekdays>,<mdays>,<months>`。那么 `include => normalhours,08:00-18:00,mon-fri,*,*` 的作用是什么？
   - A. 在周一至周五的 08:00 到 18:00 执行 extension
   - B. 在每个月的所有日期执行选项
   - C. 无效；该格式无效
2. 在现代 Asterisk（包括 Asterisk 22）中，基于时间的 `include =>` 和 `GotoIfTime()` 的字段由哪个字符分隔？
   - A. 竖线 `|`
   - B. 逗号 `,`
   - C. 分号 `;`
   - D. 斜杠 `/`
3. 若要同时拨打多个通道（让它们同时振铃），需要在 `Dial()` 中使用 ___ 字符将它们分隔开。
4. 在等待呼叫者拨打 extension 时播放提示音的语音菜单通常使用 ___ 应用程序创建。
5. 你可以使用 ___ 语句将另一个文件的内容包含在 `extensions.conf` 中（注意：这与 `include =>` context 语句不同）。
6. 在 Asterisk 22 中，内置的 AstDB 数据库由以下哪项提供支持：
   - A. Berkeley DB v1
   - B. MySQL
   - C. SQLite3
   - D. PostgreSQL
7. 当你使用 `Dial(type1/identifier1&type2/identifier2)` 时，Asterisk 会依次拨打每个通道，并在它们之间等待 20 秒。
   - A. 错误
   - B. 正确
8. 使用 Background() 应用程序时，必须等待消息播放完毕才能按下 DTMF 数字来选择选项。
   - A. 错误
   - B. 正确
9. 给定语法 `Goto([[context,]extension,]priority)`，以下哪些是 Goto() 应用程序的有效调用方式？（标记所有适用项）
   - A. Goto(context,extension)
   - B. Goto(context,extension,priority)
   - C. Goto(extension,priority)
   - D. Goto(priority)
10. 若要在 Asterisk 22 dialplan 中从 AstDB 删除单个键，应使用：
    - A. `DBdel()` 应用程序
    - B. `DB_DELETE()` 函数
    - C. `DBdeltree()` 应用程序
    - D. `LookupBlacklist()` 应用程序

**答案：** 1 — A · 2 — B · 3 — `&` · 4 — Background() · 5 — #include · 6 — C · 7 — A · 8 — A · 9 — B, C, D · 10 — B
