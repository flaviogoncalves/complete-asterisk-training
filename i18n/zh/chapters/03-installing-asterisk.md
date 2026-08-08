# 安装 Asterisk 22

在第一章中，我们了解了 Asterisk 在电话通信环境中的一些用途。在本章中，我们将介绍如何下载和安装 Asterisk。在开始之前，学习如何编译和安装它至关重要。对于传统的 Microsoft™ Windows™ 用户来说，编译过程可能看起来很奇怪，但这在 Linux™ 环境中相当普遍。编译 Asterisk 时，可以获得针对您的硬件优化的代码，这也是我们在此要做的。Asterisk 可以在多种操作系统上运行，但为了简化，我们仅使用一种：Linux。我们使用 **Ubuntu 24.04 LTS**，因为它的依赖项易于安装，而且它是一个稳定、支持良好且占用资源少的服务器发行版。如果您更喜欢其他发行版，请相应地调整软件包名称。

本版针对 **Asterisk 22 LTS**（发布于 2024-10-16；全面支持至 2028-10-16，安全修复至 2029-10-16）。Asterisk 22 是当前的长期支持版本。请注意，Digium 已于 2018 年被 **Sangoma** 收购，Asterisk 现在由 Sangoma 赞助——本章中提到的“Digium”均指代该传统硬件品牌的历史名称。

## 目标

在本章结束时，你应该能够：

- 确定 Asterisk 的硬件需求；
- 安装带有必要依赖项的 Linux；
- 通过 HTTPS 下载稳定版本；
- 编译 Asterisk；以及
- 学习如何在系统启动时运行 Asterisk。

## 最低硬件要求

Asterisk 运行并不需要太高端的硬件，但为了满足您的需求，在选择最佳硬件时仍有一些建议。在选择硬件时，您应考虑以下主要因素：

- 注册用户的总数。确定您需要支持每秒多少次注册。
- 同时通话的总数。确定您需要在 Asterisk 服务器的网络适配器和桥接器中处理多少个网络会话。
- 您需要支持哪些 codec。高复杂度的 codec 会占用服务器大量的 CPU/FPU 资源；例如，iLBC 的创建者（Global IP Sound）测得在 TI C54x DSP 上，30 ms 帧大约需要每通道 18 MIPS（20 ms 帧大约需要 15 MIPS）。
- 回声消除。回声消除可能会占用大量的 CPU/FPU 资源，在某些情况下，您应该选择使用电话接口卡上的 DSP 进行硬件回声消除。
- 可用性。使用 RAID1 或 5 来提高可用性。请记住，Asterisk 是 24x7 全天候运行的应用程序。

Asterisk 服务器的主要组件是网络适配器。建议使用高质量的服务器网络适配器。当您需要支持 g.729 和 iLBC 等高复杂度 codec 以及回声消除时，CPU 非常重要。您可以选择将其卸载到专用的 DSP 上：Sangoma（前身为 Digium）提供了一款名为 TC400B 的 DSP 卡，能够支持 120 路 G.729 同时通话。

最佳实践是选择知名制造商生产的全新服务器级计算机。要准确了解特定机器可以支持多少路同时通话或多少个注册用户，您应该使用压力测试工具（如 SIPP (http://sipp.sourceforge.net)）对该硬件进行测试。一些硬件制造商（如 Xorcom (http://www.xorcom.com)）会在其网站上发布测试结果。

注意：某些 Asterisk 应用程序（如 ConfBridge 和 music on hold）需要内部定时源。在现代 Linux 系统上，这由内置的 `res_timing_timerfd` 模块自动提供——无需任何电话硬件。 （旧的 `dahdi_dummy` 软件定时器已不再存在；其功能已在 DAHDI Linux 2.3.0 中合并到主要的 `dahdi` 内核模块中。）您可以使用 CLI 命令 `timing test` 来确认当前活动的定时器。

### 硬件配置

Asterisk 的硬件不需要非常复杂。您不需要昂贵的显卡或众多的外围设备。关于硬件配置的一些建议：

- 禁用未使用的 USB、串口和并口，以避免不必要的中断消耗。
- 坚固的网络接口卡至关重要。
- 如果您正在使用电话接口卡，请特别注意。有些卡使用 3.3 伏 PCI 总线，很难找到适配的主板。如今，PCI express 更容易找到。
- 请密切关注硬盘，PBX 通常在 24x7 模式下工作，而台式机通常在 8x5 模式下工作。不要将台式机硬件用于 PBX，通常硬盘在第一年内就会发生故障。我的建议是使用服务器机器或专为运行 24x7 应用程序而设计的设备。

### IRQ 共享（仅限传统 PCI 卡）

此问题**仅**在您安装物理 PCI/PCI-Express 电话卡（DAHDI 硬件）时适用。此类卡会产生大量中断，在较旧的单 CPU 系统上，与其他设备共享 IRQ 线路可能会导致驱动程序资源匮乏并降低语音质量。如果您使用电话卡，请将机器专用于 Asterisk，在 BIOS 中禁用任何未使用的板载设备，并使用 `cat /proc/interrupts` 检查分配的中断。使用 MSI/MSI-X 中断的现代多核服务器在实践中使 IRQ 共享不再成为问题，而纯 VoIP 部署（无卡）则完全无需担心这一点。

## 选择 Linux 发行版

Asterisk 最初是为在 Linux 上运行而开发的。不过，它也可以在 BSD Unix 或 macOS 上运行。如果您是 Asterisk 的新手，请先尝试使用 Linux，因为这样会容易得多。Asterisk 官方支持 RHEL 系列（CentOS/RHEL/Fedora）、Ubuntu 和 Debian。目前比较好的实际选择是 **Debian 12**、**Ubuntu 22.04 LTS / 24.04 LTS** 以及 **Rocky Linux 9 / AlmaLinux 9** —— 由于 CentOS Linux 已停止维护，因此在 RHEL 系列系统上建议优先选择 Rocky 或 AlmaLinux。本书中我将使用 Ubuntu 24.04 LTS。请从下方的官方发布目录下载最新的 24.04 点版本服务器镜像（确切的文件名包含当前点版本，例如 `ubuntu-24.04.4-live-server-amd64.iso`）：

```
https://releases.ubuntu.com/24.04/
```

### 为 Asterisk 准备 Linux 环境

在编译 Asterisk 之前，您需要一个已安装构建包且可正常工作的 Linux 系统。请在虚拟机或专用服务器上安装 **Ubuntu 24.04 LTS Server**（请使用 64 位镜像；本书中的所有内容均为 64 位，尽管 Asterisk 本身仍支持 32 位 x86）。我们在此次培训中使用了 VirtualBox；您可以从 <https://releases.ubuntu.com/24.04> 下载镜像。安装 Linux 本身超出了本书的范围 —— 基础的 Linux 知识是前提条件。在安装好 Linux 后，您将添加 Asterisk 的构建依赖项（请参阅下方的 *Installing dependencies*），然后编译 Asterisk。

## 安装用于 Asterisk 的 Linux

像往常一样安装 Linux，无需安装图形桌面。在安装过程中，请同时启用邮件传输代理（我们使用 **exim4**）—— Asterisk 在本书后续章节中需要它来发送语音信箱到电子邮件的通知。**警告：** 安装操作系统会擦除目标磁盘。如果您在物理硬件上安装，请先备份数据；安装到虚拟机中则不会影响您的宿主机。从 Ubuntu Server ISO（或虚拟机的虚拟光驱）启动安装程序并回答提示信息——大多数提示都很直观。

## 安装依赖项

要安装 Asterisk 和 DAHDI，您必须安装许多软件依赖项。在 Asterisk 22 中，推荐的方法是使用随源代码树一起提供的脚本，该脚本知道每个受支持发行版对应的正确软件包名称。在下载并解压 Asterisk 源代码（请参阅下文“编译 Asterisk”）后，运行：

```
cd /usr/src/asterisk-22.x.y
./contrib/scripts/install_prereq install
```

1. 以 root 用户身份登录（或使用 `sudo`）。
2. 如果您更喜欢在 Debian/Ubuntu 系统上手动安装依赖项，等效的软件包列表如下：

```
apt-get install build-essential git wget openssl libssl-dev libxml2-dev \
  libsqlite3-dev uuid-dev libjansson-dev libedit-dev libncurses-dev \
  libcurl4-openssl-dev pkg-config autoconf-archive
```

请注意，Asterisk 源代码现在托管在 Git 上，因此不再需要 `subversion`，并且现代的 Debian/Ubuntu 发行版提供的是 `libncurses-dev` 而不是带版本号的 `libncurses5-dev`。建议优先使用 `./contrib/scripts/install_prereq install` 而不是手动维护的列表，因为该脚本始终会跟踪您发行版中正确的软件包名称。

### DAHDI

DAHDI (Digium/Sangoma Asterisk Hardware Device Interface) 是用于模拟和数字卡的驱动程序架构。如果您计划使用模拟或数字接口，在安装 Asterisk 之前安装 DAHDI 非常重要。DAHDI 仍然存在于模拟/数字电话卡中，但已变得越来越小众——大多数现代部署都是纯 VoIP，可以完全跳过本节。仅当您拥有物理电话接口硬件时才安装 DAHDI。使用以下命令获取源文件：

```
wget https://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-current.tar.gz
```

使用以下命令解压文件：

```
tar -xzvf dahdi-linux-complete-current.tar.gz
```

### 编译 DAHDI 驱动程序

您需要编译 DAHDI 模块。`./configure` 和 `make menuselect` 命令是几年前引入的。后者使您能够选择要构建的实用程序和模块。以下命令将执行此操作：

```
cd dahdi-linux-complete-X.Y.Z+X.Y.Z/linux   # adapt to the version downloaded
make
make install
cd ../tools
autoreconf -i
./configure
make
make install
```

`make install-config` DAHDI 已配置完成。如果您有任何 DAHDI 硬件，现在建议您编辑 /etc/dahdi/modules，以便仅加载系统中已安装的 DAHDI 硬件的支持。默认情况下，所有 DAHDI 硬件的支持都会在 DAHDI 启动时加载。我认为您系统上的 DAHDI 硬件是：usb:004/002 xpp_usb- e4e4:1150 Astribank-multi no-firmware 此屏幕（上方）要求您更改 /etc/dahdi/modules 文件，以仅为您的特定配置加载所需的驱动程序并显示检测到的硬件。编辑 /etc/dahdi/modules 文件并仅加载所需的硬件。就我而言，我使用的是一台带有 Xorcom Astribank 6FXS 和 2FXO 的测试机器。该文件如下所示。

```
# Contains the list of modules to be loaded / unloaded by /etc/init.d/dahdi.
#
# NOTE:  Please add/edit /etc/modprobe.d/dahdi or /etc/modprobe.conf if you
#        would like to add any module parameters.
#
# Format of this file: list of modules, each in its own line.
# Anything after a '#' is ignore, likewise trailing and leading
# whitespaces and empty lines.
# Digium TE205P/TE207P/TE210P/TE212P: PCI dual-port T1/E1/J1
# Digium TE405P/TE407P/TE410P/TE412P: PCI quad-port T1/E1/J1
# Digium TE220: PCI-Express dual-port T1/E1/J1
# Digium TE420: PCI-Express quad-port T1/E1/J1
#wct4xxp
# Digium TE120P: PCI single-port T1/E1/J1
# Digium TE121: PCI-Express single-port T1/E1/J1
# Digium TE122: PCI single-port T1/E1/J1
#wcte12xp
# Digium T100P: PCI single-port T1
# Digium E100P: PCI single-port E1
#wct1xxp
# Digium TE110P: PCI single-port T1/E1/J1
#wcte11xp
# Digium TDM2400P/AEX2400: up to 24 analog ports
# Digium TDM800P/AEX800: up to 8 analog ports
# Digium TDM410P/AEX410: up to 4 analog ports
#wctdm24xxp
# X100P - Single port FXO interface
# X101P - Single port FXO interface
#wcfxo
# Digium TDM400P: up to 4 analog ports
#wctdm
# Xorcom Astribank Devices
xpp_usb
```

重新初始化您的计算机并验证驱动程序是否正确加载。

## 选择哪个版本

根据经验法则，你应该选择具备所需功能的版本。Asterisk 遵循 LTS（长期支持）版本与标准版本交替的发布模式。在本书编写时，**Asterisk 22 是当前的 LTS 版本**（发布于 2024 年 10 月；最新的点版本为 22.10.0），这使其成为目前最佳的选择。Asterisk 20 是上一个 LTS 版本，而版本 16（第一版中使用）已停止支持。对于生产系统，请务必选择 LTS 版本。

## 编译 Asterisk

如果您之前编译过软件，那么编译 Asterisk 将是一项简单的任务。运行以下命令来编译并安装 Asterisk。请记住，您可以使用 make menuselect 来选择要构建的应用程序和模块。第 1 步：下载源代码

```
cd /usr/src
wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz
tar -xzvf asterisk-22-current.tar.gz
```

第 2 步：安装构建先决条件（请参阅上文的“安装依赖项”）

```
cd asterisk-22.x.y (adapt to the version downloaded)
./contrib/scripts/install_prereq install
```

第 3 步：配置构建

```
./configure
```

第 4 步：选择要构建的模块

```
make menuselect
```

使用 make menuselect 仅安装必要的模块。在 Asterisk 22 中，SIP 通道是 **chan_pjsip**（默认构建）；旧的 **chan_sip** 已在 Asterisk 21 中移除，不再存在。Opus *透传*（pass-through）开箱即用（内置的 `res_format_attr_opus` 模块处理 SDP 协商），但 **codec_opus** 转码模块仍然是来自 Sangoma/Digium 的外部闭源二进制文件——在 menuselect 中选择它会从 Digium 的服务器下载该文件。该二进制文件是免费的。有关详细信息，请参阅下文的“使用 menuselect 选择模块”。

第 5 步：构建并安装 Asterisk，然后创建默认配置和示例文件

```
make
make install
make samples
make config
ldconfig
```

`make install` 安装二进制文件和模块，`make samples` 将示例配置文件写入 `/etc/asterisk`，`make config` 为您检测到的发行版（例如 Debian/Ubuntu 上的 `/etc/init.d/asterisk`）安装 SysV init 启动脚本，而 `ldconfig` 则刷新共享库缓存。源代码树的 `contrib/systemd/asterisk.service` 中也提供了一个 systemd 单元文件，但 `make config` 不会自动安装它——如果您更喜欢在 systemd 下运行 Asterisk，请自行将其复制到相应位置（见下文）。

### 使用 menuselect 选择模块

`make menuselect` 会打开一个基于文本的菜单，您可以在其中精确选择要构建的应用程序、codec、通道和资源。关于 Asterisk 22 的几点说明：

- **chan_pjsip**（在 *Channel Drivers* 下）是现代的 SIP 通道，默认启用；它是 Asterisk 22 中唯一的 SIP 通道。
- **codec_opus**（在 *Codec Translators* 下）是一个**外部**模块（其 menuselect 条目显示为“Download the Opus codec from Digium”）；启用它会使 `make` 从 Sangoma/Digium 获取免费的闭源二进制文件。Opus 透传本身不需要额外的模块。Sangoma 的 **codec_g729** 模块也可用——该二进制文件可免费下载，但合法的 G.729 转码需要购买每个通道的许可证。
- 在 *Core Sound Packages*、*Music On Hold File Packages* 和 *Extras Sound Packages* 菜单中选择您想要的音频格式和语言；您在其中勾选的任何内容都会在 `make install` 期间自动下载并安装。

完成选择后，选择 **Save & Exit** 并继续执行 `make`。

## 启动和停止 Asterisk

通过这种最小化配置，可以成功启动 Asterisk。为了学习和调试，您可以将 Asterisk 以前台模式启动并附加到控制台：

```
/usr/sbin/asterisk -vvvgc
```

使用 CLI 命令 `core stop now` 来关闭 Asterisk：

```
*CLI> core stop now
```

### 使用 systemd 启动 Asterisk

在现代 Linux 发行版（Debian 12、Ubuntu 22.04/24.04、Rocky/AlmaLinux 9）上，系统服务管理器是 **systemd**。Asterisk 在源码树的 `contrib/systemd/asterisk.service` 中提供了一个 systemd 单元文件；将其复制到 `/etc/systemd/system/asterisk.service` 并运行 `systemctl daemon-reload`。安装完成后，在生产环境中运行 Asterisk 的推荐方式是通过 `systemctl`：

```
systemctl start asterisk      # start the service
systemctl stop asterisk       # stop the service
systemctl restart asterisk    # restart the service
systemctl status asterisk     # show current status
systemctl enable asterisk     # start automatically at boot
```

一旦 Asterisk 作为服务运行，可以使用 `asterisk -r`（连接）或 `asterisk -rvvv`（连接并输出详细信息）附加到其 CLI。

在较旧的系统上，Asterisk 是通过传统的 SysV init 脚本（`/etc/init.d/asterisk`）和 **safe_asterisk** 包装器启动的，后者会在 Asterisk 崩溃时自动重启它。使用 systemd 时，自动重启由单元文件中的 `Restart=` 指令处理，因此通常不再需要 `safe_asterisk`。传统的 init/`safe_asterisk` 方法仍然有效，但在基于 systemd 的发行版上已被弃用。

### Asterisk 运行时选项

Asterisk 的启动过程非常简单。如果运行 Asterisk 时不带任何参数，它将作为守护进程启动。

```
/sbin/asterisk
```

您可以通过执行以下命令访问 Asterisk 控制台。请注意，可以同时运行多个控制台进程。

```
/sbin/asterisk -r
```

### Asterisk 可用的运行时选项

您可以使用 `asterisk -h` 查看可用的运行时选项。

```text
sipast:/usr/src/asterisk-22.x.y# asterisk -h
Asterisk 22.10.0, Copyright (C) 1999 - 2025, Sangoma Technologies Corporation and others.
Usage: asterisk [OPTIONS]
Valid Options:
   -V              Display version number and exit
   -C <configfile> Use an alternate configuration file
   -G <group>      Run as a group other than the caller
   -U <user>       Run as a user other than the caller
   -c              Provide console CLI
   -d              Increase debugging (multiple d's = more debugging)
   -f              Do not fork
   -F              Always fork
   -g              Dump core in case of a crash
   -h              This help screen
   -i              Initialize crypto keys at startup
   -L <load>       Limit the maximum load average before rejecting new calls
   -M <value>      Limit the maximum number of calls to the specified value
   -m              Mute debugging and console output on the console
   -n              Disable console colorization. Can be used only at startup.
   -p              Run as pseudo-realtime thread
   -q              Quiet mode (suppress output)
   -r              Connect to Asterisk on this machine
   -R              Same as -r, except attempt to reconnect if disconnected
   -s <socket>     Connect to Asterisk via socket <socket> (only valid with -r)
   -t              Record soundfiles in /var/tmp and move them where they
                   belong after they are done
   -T              Display the time in [Mmm dd hh:mm:ss] format for each line
                   of output to the CLI. Cannot be used with remote console mode.
   -v              Increase verbosity (multiple v's = more verbose)
   -x <cmd>        Execute command <cmd> (implies -r)
   -X              Enable use of #exec in asterisk.conf
   -W              Adjust terminal colors to compensate for a light background
```

## 安装目录

Asterisk 安装在多个目录中，这些目录可以在 asterisk.conf 文件中进行修改。出于培训目的，我会将 verbose 从 3 修改为 15，但在生产环境中请保持为 3。选项 `maxcalls` 和 `maxload` 是保护系统免受过载影响的良好选项。

### asterisk.conf (摘录)

`[directories]` 部分定义了 Asterisk 存放其配置、模块、数据、spool 和日志的位置：

```
[directories](!) ; remove the (!) to enable this
astetcdir => /etc/asterisk
astmoddir => /usr/lib/asterisk/modules
astvarlibdir => /var/lib/asterisk
astdbdir => /var/lib/asterisk
astkeydir => /var/lib/asterisk
astdatadir => /var/lib/asterisk
astagidir => /var/lib/asterisk/agi-bin
astspooldir => /var/spool/asterisk
astrundir => /var/run/asterisk
astlogdir => /var/log/asterisk
astsbindir => /usr/sbin
```

`[options]` 部分包含运行时调优设置。最值得了解的选项如下所示（取消注释即可启用）；该文件附带了更多选项，每个选项都有内联注释说明：

```
[options]
;verbose = 3      ; Console verbosity (raise to 15 for training, keep 3 in production)
;debug = 3        ; Debug level
;maxcalls = 10    ; Maximum number of simultaneous calls allowed
;maxload = 0.9    ; Stop accepting new calls when load average exceeds this
;maxfiles = 1000  ; Maximum number of open files
;runuser = asterisk   ; The user to run as
;rungroup = asterisk  ; The group to run as
```

## 日志文件与日志轮转

Asterisk PBX 将其消息记录在 `/var/log/asterisk` 中。日志记录由 `logger.conf` 控制。关键部分是 `[logfiles]` 部分，其中每一行定义了一个日志通道及其捕获的消息级别（摘录）：

```ini
; logger.conf (excerpt)
[general]
;dateformat = %F %T.%3q          ; ISO 8601 timestamps, with milliseconds

[logfiles]
; <logger_name> => [formatter]<levels>
console  => notice,warning,error
messages => notice,warning,error
full     => notice,warning,error,verbose,dtmf,fax
security => security              ; PJSIP/auth security events (used by Fail2Ban)
```

编辑完成后，使用 `logger reload` 应用更改，并使用 `logger show channels` 确认通道：

```text
*CLI> logger show channels
Channel                       Type   Formatter  Status   Configuration
/var/log/asterisk/security    File   default    Enabled  - SECURITY
/var/log/asterisk/full        File   default    Enabled  - NOTICE WARNING ERROR VERBOSE DTMF FAX
/var/log/asterisk/messages    File   default    Enabled  - NOTICE WARNING ERROR
```

日志文件可能会迅速增长，因此请使用系统 `logrotate` 守护进程对其进行轮转——在 `/etc/logrotate.d/` 下添加一个文件：

```text
/var/log/asterisk/messages /var/log/asterisk/*log {
   missingok
   rotate 5
   weekly
   create 0640 asterisk asterisk
   postrotate
       /usr/sbin/asterisk -rx 'logger reload'
   endscript
}
```

有关 logrotate 的更多信息，可以使用以下命令获取：

```
#man logrotate
```

## 卸载 Asterisk

要卸载 Asterisk，请使用：

```
make uninstall
```

要卸载 Asterisk 及所有配置文件，请使用：

```
make uninstall-all
```

## Asterisk 安装注意事项

本节将提供一些关于在安装 Asterisk 之前需要解决的问题的建议。

### 生产系统

如果 Asterisk 安装在生产环境中，您应该注意系统设计。服务器必须进行优化，以便电话系统优先于其他系统进程。Asterisk 不应与处理器密集型软件（例如 X-Windows）同时运行。如果您需要运行 CPU 密集型进程（例如大型数据库），请使用单独的服务器。总的来说，Asterisk 对硬件性能波动比较敏感。因此，请尽量在 CPU 利用率不超过 40% 的硬件环境中使用 Asterisk。

### 网络提示

如果您计划使用 IP 电话，请务必注意您的网络。语音协议非常优秀，能够抵抗延迟甚至抖动；然而，如果您使用配置不当的局域网，语音质量将会受到影响。只有在交换机和路由器中使用服务质量 (QoS)，才有可能保证良好的语音质量。局域网中的语音质量通常不错，但即使在 LAN 环境中，如果您使用 10 Mbps 的集线器且存在过多的冲突，最终也会导致语音失真或质量低劣。请遵循以下建议以确保获得最佳的语音质量：

- 如果可能或在经济上可行，请使用端到端 QoS。有了端到端 QoS，语音质量将非常完美。别找借口！
- 在生产环境中，避免将 10/100 Mbps 集线器用于语音传输。冲突会给网络带来抖动。首选全双工 10/100 Mbps 设备，因为这样不会发生冲突。
- 使用 VLAN 来隔离语音网络中不必要的广播。您肯定不希望病毒通过 ARP 广播破坏您的语音网络。
- 让用户了解语音网络的预期效果。如果没有 QoS，不要承诺语音质量会像大多数情况下那样完美。通常可以达到类似于移动电话的语音质量。请使用高质量的电话，因为固件和硬件设计方面的问题很常见。

## 总结

在本章中，您已经了解了最低硬件要求，以及如何下载、安装和编译 Asterisk。出于安全考虑，Asterisk 应以非 root 用户身份运行。在启动生产环境之前，您应该检查您的网络环境。

## 测试题

1. 在 Asterisk 22 中，哪个通道驱动程序提供 SIP 支持，旧的 `chan_sip` 发生了什么变化？
   - A. `chan_sip` 仍然是默认选项；`chan_pjsip` 是可选的。
   - B. `chan_pjsip` 是默认的 SIP 通道；`chan_sip` 已在 Asterisk 21 中被移除，不再存在。
   - C. 两者默认都会构建，您可以在运行时进行选择。
   - D. SIP 支持已被完全移除，转而支持 IAX2。
2. 用于 Asterisk 的电话接口卡通常内置了数字信号处理器 (DSP)，因此不需要 PC 提供太多的 CPU 资源。
   - A. 正确
   - B. 错误
3. 如果您想要完美的语音质量，则需要实现端到端的服务质量 (QoS)。
   - A. 正确
   - B. 错误
4. 您应该始终选择最新的 Asterisk 版本，因为它是最稳定的。
   - A. 正确
   - B. 错误
5. 安装 Asterisk 22 构建依赖项的推荐方法是什么？
6. 如果您没有 TDM 接口卡，您仍然可以通过 Linux 上的 `res_timing_timerfd` 模块获得用于同步的内部时序源。此定时功能被诸如 ________ 和 ________ 之类的应用程序所使用。
7. 安装 Asterisk 时，最好不要安装 GNOME 或 KDE 等桌面环境，因为图形界面会消耗 CPU 周期。
   - A. 正确
   - B. 错误
8. Asterisk 配置文件位于 ________ 目录中。
9. 要安装 Asterisk 示例配置文件，请输入命令： ________
10. 为什么以非 root 用户身份运行 Asterisk 很重要？

**答案：** 1 — B · 2 — B · 3 — A · 4 — B · 5 — 在解压后的 Asterisk 源码树中运行 `./contrib/scripts/install_prereq install` · 6 — ConfBridge 和 Music on Hold · 7 — A · 8 — `/etc/asterisk` · 9 — `make samples` · 10 — 安全性（如果 Asterisk 被攻破，可以限制损害范围）
