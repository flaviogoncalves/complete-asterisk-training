# 使用 PBX 功能

在 SIP 系统中，大多数电话功能都是在 endpoint 中实现的。市面上存在各种各样的 SIP 电话和制造商，其互操作性无法得到保证。Asterisk 开发团队在 PBX 本身中实现了大部分功能，这做得非常出色，使得 Asterisk 几乎不依赖于特定的 endpoint。然而，有时你会发现电话和 Asterisk 本身都在执行相同的功能。电话与 PBX 的集成是可用性方面的下一个前沿领域，也是目前专有系统关注的重点。在本章中，你将学习如何使用这些功能中的大部分。

## 目标

在本章结束时，你将能够理解并使用：

- 呼叫驻留 (Call Parking)
- 呼叫代接 (Call Pickup)
- 呼叫转移 (Call Transfer)
- 电话会议 (ConfBridge)
- 呼叫录音 (Call Recording)
- 保持音乐 (Music on hold)

## 功能实现的位置

首先，最重要的是要理解 PBX 功能是在何时执行的，以及何时是由话机完成所有工作的。例如，您可以通过按下话机上的 TRANSFER 按钮来转接呼叫，也可以通过拨打 #（由 PBX 本身执行的无条件转接）来完成。

## Asterisk 实现的功能

这些功能由 Asterisk 代码在 PBX 中实现：

- Music on hold
- Call parking
- Call pickup
- Call recording
- ConfBridge conference room
- Call transfer (blind and consultative)

## 通常由 dialplan 实现的功能

这些功能需要在 Asterisk 的 dialplan (extensions.conf) 中进行编程：

- 遇忙呼叫转移 (Call forward on busy)
- 无条件呼叫转移 (Call forward immediate)
- 无应答呼叫转移 (Call forward on unanswered)
- 呼叫过滤 (黑名单) (Call filtering (blacklist))
- 免打扰 (Do not disturb)
- 重拨 (Redial)

## 通常由话机实现的功能

这些功能由话机的固件实现：

![PBX 功能通常实现的位置：在 Asterisk 本身、在 dialplan 中，还是在话机中](../images/13-pbx-features-fig01.png)

- 通话保持 (Call on hold)
- 盲转 (Blind transfer)
- 咨询转接 (Consultative transfer)
- 三方会议 (Three-way conference)
- 消息等待指示灯 (Message waiting indicator)

## 功能配置文件

本章介绍的部分功能是在 features.conf 配置文件中进行配置的。通过修改此文件，可以更改某些功能的行为。我们在下方包含了相关的摘录。在本章的后续部分中，我们将详细描述每一项功能。以下是示例文件（Asterisk 22）的摘录：

![features.conf 中 `[featuremap]` 部分的截图，包含默认的 DTMF 功能代码](../images/13-pbx-features-fig02.png)

自 Asterisk 12 起，呼叫驻留（call parking）功能已从 `features.conf` 中移出，并放入其独立的模块 `res_parking` 中，其配置位于 `res_parking.conf`。下方的 parking-lot 代码块（`parkext`、`parkpos`、`context`、`parkingtime`等）位于 `res_parking.conf` 中。`[featuremap]` 部分（即 DTMF 功能代码，包括 `parkcall`）则保留在 `features.conf` 中。

驻留槽（parking-lot）选项位于 `res_parking.conf` 中。即使配置文件中未显式定义，名为 `default` 的驻留槽也始终存在。以下摘录取自 Asterisk 22 的 `res_parking.conf.sample`：

```
; res_parking.conf
[default]                       ; Default Parking Lot
parkext => 700                  ; What extension to dial to park. (optional; if
                                ; specified, extensions will be created for parkext and
                                ; the whole range of parkpos)
parkpos => 701-720              ; What range of parking spaces to use - must be numeric.
                                ; Creates these spaces as extensions if parkext is set.
context => parkedcalls          ; Which context parked calls and the default park
                                ; extension are created in
;parkingtime => 45             ; Number of seconds a call can be parked before returning
;comebacktoorigin = yes        ; When a parked call times out, attempt to send it back to
                               ; the peer that parked it (default is yes)
;courtesytone = beep           ; Sound file to play when someone picks up a parked call
;parkedplay = caller           ; Who to play courtesytone to: parked, caller, both (default caller)
;parkedcalltransfers = caller  ; Enable DTMF transfers when picking up a parked call (default no)
;parkedcallreparking = caller  ; Enable DTMF parking when picking up a parked call (default no)
;parkedcallhangup = caller     ; Enable DTMF hangups when picking up a parked call (default no)
;findslot => next              ; 'next' uses the next space after the most recently used one;
                               ; 'first' (default) uses the lowest-numbered space available
;parkedmusicclass = default    ; MOH class to use for the parked channel
```

DTMF 功能代码（包括一步式 `parkcall`）保留在 `features.conf` 的 `[featuremap]` 部分中：

```
; features.conf
[featuremap]
;blindxfer => #1                ; Blind transfer  (default is #) -- Make sure to set the T and/or t option in the Dial() or Queue() app call!
;disconnect => *0               ; Disconnect  (default is *) -- Make sure to set the H and/or h option in the Dial() or Queue() app call!
;atxfer => *2                   ; Attended transfer  -- Make sure to set the T and/or t option in the Dial() or Queue()  app call!
;parkcall => #72                ; Park call (one step parking)  -- Make sure to set the K and/or k option in the Dial() app call!
;automixmon => *3               ; One Touch Record a.k.a. Touch MixMonitor -- Make sure to set the X and/or x option in the Dial() or Queue() app call!
```

## 通话转接

通话转接可以通过话机、ATA 或 Asterisk 本身来实现。请参阅您的话机手册以了解如何进行通话转接。如果您的电话不支持通话转接，您可以使用 Asterisk 来完成此任务。通话转接有两种不同的实现方式。

第一种方式是使用盲转（blind transfer）功能：拨打 #，后跟要转接的号码。有时您会使用 IP 电话或 IP softphone 的转接功能。您可以通过编辑 features.conf 文件中的 blindxfer 参数来更改转接字符。

您可以通过删除 features.conf 文件中 atxfer 参数前的 ; 来启用 Asterisk 中的咨询转接（assisted transfer）。在通话过程中，您可以按 *2。Asterisk 会语音提示 "transfer" 并为您提供拨号音。呼叫方会被置于保持音乐（music on hold）状态。在您与目标方通话并挂断电话后，系统会将呼叫方桥接到目标方。

![通话转接：盲转（通话期间按 #）和咨询转接（按 *2）的步骤](../images/13-pbx-features-fig03.png)

### 配置任务列表

1. 对于 PJSIP endpoint，请确保选项 `direct_media` 设置为 `no`（以便媒体流经 Asterisk 并且可以检测到功能码），或者在 `Dial()` 应用程序中使用 `t`/`T` 选项。

## 呼叫驻留 (Call parking)

此功能用于驻留呼叫。例如，当您在房间外接听电话并希望将呼叫转回您的办公桌时，此功能非常有用。您可以通过将呼叫驻留到某个 extension 来实现这一点。到达办公桌后，只需拨打该驻留 extension 的号码即可恢复通话。

![呼叫驻留：拨打 700 将呼叫驻留到第一个空闲槽位（701–720）；Asterisk 会播报该槽位，您可以在任何电话上拨打该号码以取回呼叫](../images/13-pbx-features-fig04.png)

默认情况下，700 extension 用于驻留呼叫。在通话过程中，按 # 键将呼叫转接到 700 extension。此时 Asterisk 将播报您的驻留 extension，例如 701 或 702。挂断电话，呼叫者将被置于保持状态。走到您的办公桌电话旁，拨打刚才播报的驻留 extension 即可恢复通话。如果呼叫者被驻留时间过长，超时功能将触发，最初拨打的 extension 将再次振铃。

### 配置任务列表

请按照以下步骤启用呼叫驻留。第 1 步：使 parking lot 可从您的 dialplan 访问（必需）。默认 parking lot 的 `context` 是 `parkedcalls`（在 `res_parking.conf` 中设置）。在 `extensions.conf` 中，将该 context 包含在您的电话拨出所使用的 context 中：

```
include => parkedcalls
```

第 2 步：通过拨打 #700 测试呼叫驻留功能。注意：

- 驻留 extension 不会显示在 dialplan show CLI 命令中。
- 修改 parking 配置文件后，必须重新加载 parking 模块：`module reload res_parking.so`。对于 features.conf 的更改，请使用 `module reload features.so`。
- 要驻留呼叫，您需要转接到 #700。请验证 `Dial()` 应用程序中的 `t` 和 `T` 选项。

## 呼叫代答

呼叫代答功能允许您接听同一呼叫组中同事的来电。例如，当办公室里其他人的电话正在响铃但本人不在时，您无需起身即可代为接听，这非常方便。通过拨打 *8，您可以接听呼叫组内的来电。该号码可以在 `features.conf` 文件中进行修改。

![呼叫代答：成员只能接听其所在组内的来电；话务员（pickupgroup=1,2,3）可以接听所有组的来电](../images/13-pbx-features-fig05.png)

### 配置任务列表

请按照以下步骤配置呼叫代答功能。第 1 步：为您的 extension 配置呼叫组。这需要在通道配置文件（pjsip.conf, iax.conf, chan_dahdi.conf）中完成。对于 PJSIP endpoint，请在 `pjsip.conf` 的 endpoint 部分设置 `call_group` 和 `pickup_group`（pjsip.conf 使用 snake_case 格式的选项名称）。此任务为必选。

对于 PJSIP (pjsip.conf)：
```
[4x00]
type=endpoint
call_group=1
pickup_group=1,2
```


第 2 步：更改呼叫代答功能号码（可选）。此项设置在 `features.conf` 的 `[general]` 部分，而不是在 `pjsip.conf` 中：

```
; features.conf
[general]
pickupexten = *8   ; Configures the call pickup extension (default is *8)
```

## Conference (电话会议)

在 Asterisk 上实现电话会议有多种方式。第一种选择是简单地使用话机自带的三方通话功能。通过使用话机上的此功能，您不需要服务器端的任何支持。然而，当您需要超过 3 人的会议时，您应该运行一个会议室。Asterisk 现代的会议应用程序是 ConfBridge (`app_confbridge`)。

ConfBridge 支持高清语音会议和视频会议。视频会议有一些限制，例如不支持转码——所有参与者必须使用相同的 codec 和 profile。视频会议使用“跟随发言者”模式，显示最后发言者的图像。您可以在 ConfBridge 中轻松配置新的 DTMF 菜单。

ConfBridge 取代了旧的 MeetMe 应用程序，后者在 Asterisk 19 中已被弃用。MeetMe 仍然包含在 Asterisk 22 的源代码树中，但它依赖于 DAHDI 且默认不会构建，因此在典型的 PJSIP 安装中它根本不可用——ConfBridge 是受支持的会议应用程序。与 MeetMe 不同，ConfBridge **不**需要 DAHDI 或硬件定时源：它依赖于 Asterisk 内置的定时接口（Linux 上的`res_timing_timerfd`，或`res_timing_pthread`），因此不需要`dahdi_dummy`模块。如果您是从使用`MeetMe()`和`meetme.conf`的旧系统迁移而来，请按照下文所述将其替换为`ConfBridge()`和`confbridge.conf`。

### ConfBridge

要启动一个会议室，语法如下所示。

```
ConfBridge(conference,bridge_profile,user_profile,menu)
```

要获取该命令的完整描述，您可以使用 core show application confbridge。

![`core show application confbridge`的输出，显示概要、语法以及 bridge_profile、user_profile 和 menu 参数](../images/13-pbx-features-fig06.png)

![多个 PJSIP endpoint 加入一个名为 ConfBridge 的会议 (101)；其中一名参与者是管理员。混音和定时由`app_confbridge`配合`bridge_softmix`以及内置的`res_timing_*`定时器处理——无需 DAHDI。](../images/13-pbx-features-fig09.png)

如上所示，有三个重要的参数，每个参数映射到`confbridge.conf`中的一个部分类型。**bridge_profile**（一个`type=bridge`部分）：在这里您可以选择最大参与者数量 (`max_members`)、录音 (`record_conference`)、`video_mode`以及许多其他桥接范围内的参数。

在此处重现整个示例文件没有意义，因此我为您提供一个关于如何在 confbridge.conf 文件中配置 bridge_profile 的简单示例。

```
[default_bridge]
type=bridge
max_members=10
record_conference=yes
```

**user_profile**（一个`type=user`部分）：在这里您可以定义特定于用户的选项，例如用户是否为管理员 (`admin=yes`)、他们加入时是否静音 (`startmuted=yes`)、保持音乐以及许多其他针对用户的选项。示例：

```
[admin_user]
type=user
admin=yes
```

**menu**（一个`type=menu`部分）：在这里您可以定义会议的键盘 (DTMF) 映射——例如哪个按键用于切换静音、调节音量或离开会议。查看`confbridge.conf.sample`文件以了解所有可用操作。示例：

```
[my_menu]
type=menu
*=playback_and_continue
1=toggle_mute
2=decrease_listening_volume
3=increase_listening_volume
4=decrease_talking_volume
5=increase_talking_volume
6=leave_conference
```

#### Confbridge 函数

会议桥接选项可以使用 CONFBRIDGE() 函数在 dialplan 中动态传递。请参阅以下示例：

```
exten => 1,1,Answer()
exten => 1,n,Set(CONFBRIDGE(user,template)=default_user)
exten => 1,n,Set(CONFBRIDGE(user,admin)=yes)
exten => 1,n,Set(CONFBRIDGE(user,marked)=yes)
exten => 1,n,ConfBridge(sales)
```

### ConfBridge 管理命令及从 MeetMe 迁移

如果您是从 MeetMe 迁移而来，您之前通过`MeetMeAdmin()`和`a` (admin) 选项使用的管理功能，现在通过 **admin user profile** (`admin=yes`) 加上 **menu** 操作来实现。以管理员 profile 加入并拥有包含管理操作菜单的管理员，可以直接通过键盘锁定会议室、踢出用户以及将参与者静音。在`confbridge.conf`中的相关菜单操作包括：

- `admin_kick_last` -- 踢出最后加入的用户
- `admin_toggle_mute_participants` -- 将所有非管理员参与者静音/取消静音
- `toggle_mute` -- 将您自己静音/取消静音
- `participant_count` -- 播报参与者人数
- `leave_conference` -- 离开桥接并继续执行 dialplan

这些取代了 MeetMe 的`MeetMe()`选项标志 (`a`, `A`, `m`, `M`, `l`, `x`, …) 以及`MeetMeAdmin()`命令 (`k`, `K`, `L`, `M`, `N`, …)。在现代 PJSIP 安装中，您根本不需要加载`app_meetme`；所有会议配置都存在于`confbridge.conf`中，更改通过`module reload app_confbridge.so`应用（ConfBridge 逻辑存在于`app_confbridge`中；没有`res_confbridge`模块）。

### ConfBridge 示例

要在 extension 500 处创建一个可访问的会议室，请在`extensions.conf`中进行如下配置：

```
exten => 500,1,Answer()
 same => n,ConfBridge(101,default_bridge,default_user,sample_user_menu)
```

第一个拨打 500 的呼叫者创建会议`101`；随后的呼叫者加入该会议。此处引用的 profile 和菜单 (`default_bridge`, `default_user`, `sample_user_menu`) 在`confbridge.conf`中定义。要要求输入 PIN 码，请在 user profile 中设置`pin=`；要使参与者成为会议管理员，请为其提供一个带有`admin=yes`的 user profile。

## 通话录音

在 Asterisk 中有多种录音方式。你可以使用 `MixMonitor()` 应用程序轻松录制通话。（较旧的 `Monitor` 应用程序会录制两个独立的文件，现已被移除；请改用 `MixMonitor`。）

### 使用 MixMonitor 应用程序

`MixMonitor` 应用程序将当前通道的音频录制到指定文件中。如果文件名是绝对路径，它将使用该路径。否则，它会在 asterisk.conf 中配置的监控目录中创建该文件。

![MixMonitor() 应用程序：将通道音频录制并混合到一个文件中，支持追加、仅桥接模式和音量调节等选项](../images/13-pbx-features-fig09.png)

### MixMonitor()

录制通话并在录制过程中混合音频。语法：`MixMonitor(filename.extension[,options[,command]])`。将当前通道的音频录制到指定文件中。有效选项：

- a - 追加到文件末尾，而不是覆盖它。
- b - 仅在通道处于桥接状态时才将音频保存到文件。
- 注意：不包含会议。
- v(<x>) - 将听到的音量调整为 <x> 倍（范围从 -4 到 4）
- V(<x>) - 将说话的音量调整为 <x> 倍（范围从 -4 到 4）
- W(<x>) - 将听到和说话的音量同时调整为 <x> 倍（范围从 -4 到 4）
- <command> 将在录音结束时执行。任何匹配 ^{X} 的字符串都将被解义为 ${X}，并且所有变量将在此时进行求值。变量 MIXMONITOR_FILENAME 将包含用于录制的文件名。

一个有趣的功能是“一键录音”特性 `automixmon`，它允许通话方在通话期间拨打 DTMF 代码（`features.conf` 示例建议使用 `*3`；系统没有内置默认值，因此必须手动设置）来立即开始（或停止）录音。它基于 MixMonitor 构建，因此会写入一个混合后的文件。示例：

```
exten => _4XXX,1,Set(DYNAMIC_FEATURES=automixmon)
 same => n,Dial(PJSIP/${EXTEN},20,jtTXx) ; X and x enable one-touch MixMonitor recording
```

`X` 和 `x` 选项分别为呼叫方和被呼叫方启用一键 MixMonitor 功能。由于 MixMonitor 录制的是单个混合文件，因此无需在事后合并独立的 IN/OUT 文件（旧的 `automon`/`Monitor` 方法会为 `soxmix` 生成两个文件，该方法已与 `Monitor` 应用程序一同被移除）。

如果你不想在 Dial() 应用程序之前使用 Set()，可以在全局部分进行设置：

```
[globals]
DYNAMIC_FEATURES=automixmon
```

### 保持音乐 (MOH)

保持音乐 (MOH) 在 1.0、1.2 和 1.4 版本之间经历了多次变更。在最新版本中，MOH 默认为 "FILE-BASED"。换句话说，Asterisk 将以 g729、alaw、ulaw 和 gsm 等格式提供 MOH 文件。因此，在将音乐发送到通道之前无需进行转码。这节省了处理器时间，对于在生产环境中使用系统的用户来说，这是一项受欢迎的改进。

在旧版本中，MOH 通常由 MP3 提供（现在仍然可以这样配置）。使用 MP3 提供 MOH 会迫使 Asterisk 进行转码，从而消耗宝贵的 CPU 资源。

新的配置文件如下所示。请注意，默认类现在使用原生文件格式 mode=files。所有其他模式均被注释掉。每个部分都是一个类。目前唯一未被注释的类是 default。如果你想为不同的文件设置不同的类，则需要创建新的部分（类）。

![musiconhold.conf 示例配置，列出了有效的 MOH 模式（quietmp3、mp3、custom、files 等）](../images/13-pbx-features-fig10.png)

```
; Music on Hold -- Sample Configuration
;[samplemp3]
;mode=quietmp3
;directory=/var/lib/asterisk/mohmp3
;
; valid mode options:
; quietmp3      -- default
; mp3           -- loud
; mp3nb         -- unbuffered
; quietmp3nb    -- quiet unbuffered
; custom        -- run a custom application (See examples below)
; files         -- read files from a directory in any Asterisk supported
;                  media format. (See examples below)
;[manual]
;mode=custom
; Note that with mode=custom, a directory is not required, such as when reading
; from a stream.
;directory=/var/lib/asterisk/mohmp3
;application=/usr/bin/mpg123 -q -r 8000 -f 8192 -b 2048 --mono -s
;[ulawstream]
;mode=custom
;application=/usr/bin/streamplayer 192.168.100.52 888
;format=ulaw
; mpg123 on Solaris does not always exit properly; madplay may be a better
; choice
;[solaris]
;mode=custom
;directory=/var/lib/asterisk/mohmp3
;application=/site/sw/bin/madplay -Q -o raw:- --mono -R 8000 -a -12
;
;
; File-based (native) music on hold
;
; This plays files directly from the specified directory, no external
; processes are required. Files are played in normal sorting order
; (same as a sorted directory listing), and no volume or other
; sound adjustments are available. If the file is available in
; the same format as the channel's codec, then it will be played
; without transcoding (same as Playback would do in the dialplan).
; Files can be present in as many formats as you wish, and the
; 'best' format will be chosen at playback time.
;
; NOTE:
; If you are not using "autoload" in modules.conf, then you
; must ensure that the format modules for any formats you wish
; to use are loaded _before_ res_musiconhold. If you do not do
; this, res_musiconhold will skip the files it is not able to
; understand when it loads.
;
[default]
mode=files
directory=/var/lib/asterisk/moh
;
;[native-random]
;mode=files
;directory=/var/lib/asterisk/moh
;random=yes     ; Play the files in a random order
```

### MOH 配置任务

现在，要使用保持音乐，请在通道配置文件（chan_dahdi.conf、pjsip.conf、iax.conf 等）中设置 MOH 类。对于 PJSIP endpoint，请在 `pjsip.conf` 的 endpoint 部分设置 `moh_suggest`（旧版 `musicclass` 选项名称适用于 chan_dahdi 和其他通道驱动程序，不适用于 PJSIP）。安装的免费音乐现在采用 wav 格式。在安装时，你可以选择（使用 make menuselect）可用的 MOH 文件格式。如果你想添加新的 MOH 文件，则必须提供所需格式的文件。例如：

在 `/etc/asterisk/chan_dahdi.conf` 中，添加 `musiconhold` 行：

```
[channels]
musiconhold=default
```

然后编辑 `/etc/asterisk/musiconhold.conf` 来定义该类：

```
[default]
mode=files
directory=/var/lib/asterisk/moh
```

在 dialplan 中，你可以使用 `StartMusicOnHold` 在通道上启动保持音乐（并使用 `StopMusicOnHold` 停止它）：

```
exten => 100,1,StartMusicOnHold(default)
 same => n,Dial(PJSIP/2)
```

若要播放保持音乐一段固定时间作为快速测试，请使用带有持续时间（以秒为单位）的 `MusicOnHold` 应用程序：

```
[local]
exten => 6601,1,MusicOnHold(default,30)
```

## Application Maps

Application maps 允许您通过使用 features.conf 文件中的 `[applicationmap]` 部分来添加新功能。假设您需要在呼叫中心接听电话时识别客户类型。您可以为每种客户类型创建一个 application map，用于统计每种类型已接听客户的数量。

## 总结

在本章中，您了解了 Asterisk 的 PBX 功能位于何处——有些在核心中，有些在 dialplan 中，还有一些在话机上——以及 DTMF 功能码是如何在 `features.conf` 的 `[featuremap]` 部分中进行映射的。您配置了**呼叫转移**（盲转和咨询转）和**呼叫驻留**（`res_parking.conf`，使用 `k`/`K` Dial 选项和 `parkedcalls` 驻留区）、按组进行的**呼叫代答**，以及使用 **ConfBridge**（`confbridge.conf` 桥接/用户/菜单配置文件）进行的**电话会议**，它取代了旧的 MeetMe。您设置了使用 MixMonitor 进行的**一键录音**（`automixmon`、用于 Dial 的 `X`/`x` 选项以及 `DYNAMIC_FEATURES`），配置了**保持音乐**，并了解了 **application maps** 如何让您将自己的 dialplan 逻辑绑定到 DTMF 序列上。利用这些构建模块，您可以提供用户期望从企业级 PBX 中获得的日常功能。

## 测试题

1. 关于呼叫驻留（call parking），以下哪些说法是正确的？
   - A. 默认情况下，extension 800 用于呼叫驻留。
   - B. 当你离开座位时接到电话，你可以将其驻留；系统会播报驻留槽位，你可以从任何电话拨打该槽位以取回通话。
   - C. 默认情况下，拨打 extension 700 可以驻留通话，通话会被驻留在 701–720 槽位中。
   - D. 你拨打 700 来取回驻留的通话。
2. 要使用呼叫代答（call-pickup）功能，所有 extension 必须处于同一个 ___ 中。对于 DAHDI 通道，这需要在 ___ 文件中进行配置。
3. 在转接通话时，你可以选择 ___ 转接（不先咨询目的地）或 ___ 转接（在完成转接前先与目的地通话）。
4. 要进行咨询转接（attended transfer），你需要使用 ___ 序列；对于盲转（blind transfer），你需要使用 ___。
   - A. #1, *2
   - B. *2, #1
   - C. #2, #1
   - D. #1, #2
5. 要在 Asterisk 22 中托管电话会议，你需要使用 ___ 应用程序。
6. 在 ConfBridge 中，通过在用户配置文件（`confbridge.conf`）中设置 ___，可以授予参与者管理员权限（踢人、静音他人、锁定会议室）：
   - A. admin=yes
   - B. marked=yes
   - C. moderator=yes
   - D. type=admin
7. 保持音乐（music on hold）的最佳格式是 MP3，因为它在 Asterisk 服务器上占用的处理能力非常小。
   - A. 正确
   - B. 错误
8. 要从特定的呼叫组代答通话，你必须处于匹配的 ___ 组中。
9. 你可以使用 MixMonitor() 应用程序或一键录音（`automixmon`）功能来录制通话。在 `features.conf` 示例中，`automixmon` 被映射到 ___ DTMF 序列。
   - A. *1
   - B. *2
   - C. *3
   - D. #1
10. 在 ConfBridge 中，哪一个 `confbridge.conf` 用户配置文件选项可以让参与者以静音状态加入（他们可以听到会议内容，但在取消静音前无法被听到）？
    - A. startmuted=yes
    - B. listen=only
    - C. muteall=yes
    - D. quiet=yes

**答案：** 1 — B, C · 2 — pickup group; `chan_dahdi.conf` · 3 — blind; attended · 4 — B · 5 — ConfBridge() · 6 — A · 7 — B · 8 — pickup · 9 — C · 10 — A
