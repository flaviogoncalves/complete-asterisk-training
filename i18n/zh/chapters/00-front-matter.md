```{=latex}
\frontmatter
```

## 版权 {.unnumbered}

*Asterisk Guide* — 第二版 (Asterisk 22 LTS)

版权所有 © 2006–2026 Flavio E. Gonçalves。保留所有权利。

未经作者事先书面许可，不得以任何形式或任何手段复制、存储于检索系统或传播本书的任何部分，用于已发表评论中的简短摘录除外。

**版本：** 第二版。

> **[author TODO]** 分配一个新的第二版 ISBN（请勿重复使用第一版的 9781796396973），并在印刷前设定出版日期。

制造商和销售商用于区分其产品的许多名称均被声明为商标。凡本书中出现此类名称且作者知晓其商标声明之处，均以大写或首字母大写形式印刷。Asterisk、Digium、IAX 和 DUNDi 是 Sangoma Technologies 的商标（Digium 已于 2018 年被 Sangoma 收购；Asterisk 目前由 Sangoma 赞助）。

尽管在编写本书时已采取一切预防措施，但作者对错误或遗漏，或因使用此处包含的信息而导致的损害不承担任何责任。

## 前言 {.unnumbered}

本书旨在帮助任何想要学习如何安装和配置基于 Asterisk 22 LTS 的 PBX（专用小交换机）的人。Asterisk 是一个开源电话平台，它架起了 VoIP 与传统 TDM 通道之间的桥梁。

这是本书的第五代版本，本书最初名为《Asterisk 配置指南》。书中的内容源于我 2006 年为准备 Digium dCAP 认证所做的工作——我一次性通过了该认证——自那时起，这些内容已被传授给了一千多名学员。

开源 PBX 的概念具有革命性。几十年来，电话行业一直被少数几家销售昂贵专有系统的公司所垄断。Asterisk 将这种能力重新交还到了用户手中：曾经在经济上遥不可及的功能——如 CTI（计算机电话集成）、IVR（交互式语音应答）、ACD（自动呼叫分配）、voicemail 等——现在任何拥有一台 Linux 机器并愿意学习的人都可以使用。

本书本身无法让你成为一名大师——没有任何书能做到这一点——但读完本书后，你将能够构建并运行一个具备高级功能的真实 PBX。本书配有配套资源——实践实验和在线课程——位于 **VoIP School Blackbelt** (<https://voip.school>)。

## 读者对象 {.unnumbered}

本书旨在为 Asterisk 的初学者提供指导。我假设您熟悉 Linux 系统——包括 shell、文本编辑器以及基本的系统管理。如果您在学习过程中觉得在 Linux 桌面环境下操作更方便，完全可以这样做；对于实验环境，使用虚拟机也是可以的（但请注意语音质量可能会稍差）。对于生产环境，我不建议在桌面环境或资源受限的虚拟机中运行 Asterisk。如果您对 IP 网络、VoIP 以及基本的电话通信概念有所了解，将会对学习本书大有裨益。

## 第二版的新增内容 {.unnumbered}

第二版是针对 **Asterisk 22 LTS**（2024 年发布，支持至 2028 年 10 月）进行的全面现代化升级。主要变化如下：

- **PJSIP 是唯一的 SIP 通道。** `chan_sip`已在 Asterisk 21 中移除，在 22 版本中不再存在。现在所有的 SIP 示例均使用 PJSIP（`pjsip.conf`）；旧版 `sip.conf` 的相关内容仅作为迁移参考保留。
- **Sangoma 的管理。** Digium 已于 2018 年被 Sangoma 收购；该项目目前由 Sangoma 开发和赞助，全书内容已据此进行了相应更新。
- **三个新章节。** *WebRTC with Asterisk*（基于 WSS/DTLS-SRTP 的浏览器电话）、*SIP trunking, DID & the PSTN*，以及 *Deployment, monitoring & scaling*。
- **可复现的实验环境。** 书中的每一个配置和命令都已在 Asterisk 22 Docker 实验环境中进行了验证，您可以自行运行该环境。
- **现代化功能。** ConfBridge 取代了旧的 MeetMe 会议功能，引入了 ARI 并与 AMI/AGI 并列，涵盖了 PJSIP Realtime (Sorcery)，同时更新了安装、安全和 CDR 等章节。
- **全新的结构。** 本书现在分为四个部分——基础（Foundations）、通道与连接（Channels & Connectivity）、dialplan 与呼叫功能（Dialplan & Call Features），以及集成与运维（Integration & Operations）。

## 关于作者 {.unnumbered}

Flavio E. Gonçalves 于 1966 年出生在巴西。自 1983 年拥有第一台 PC 以来，他就对计算机产生了浓厚的兴趣，并于 1989 年获得了工程学学位，专注于计算机辅助设计与制造。他是巴西 SipPulse 公司的首席执行官，该公司致力于 SoftSwitch、SBC 和多租户 PBX 的研发。

在他的职业生涯中，他获得了众多认证，其中包括 Novell MCNE/MCNI、Microsoft MCSE/MCT、Cisco CCSP/CCNP/CCDP 以及 Asterisk dCAP。他开始撰写关于开源软件的书籍，是因为他坚信认证考试曾经教授材料的那种结构化方式是一种极佳的学习途径。他凭借超过 25 年的教学经验，从人们实际的学习方式出发进行创作，而不仅仅是从纯技术的角度进行阐述。

Flavio 是两个孩子的父亲，现居巴西弗洛里亚诺波利斯——世界上最美丽的地方之一——他在那里度过冲浪和航海的闲暇时光。

## 反馈、致谢与培训 {.unnumbered}

我尽力去发现并消除错误，但总会有一些漏网之鱼。如果您发现任何错误，请告知我，我会进行处理。

本书也用作培训教材。如果您希望在自己的培训中心使用本书，或者想参加配套的在线课程和实验，请访问 **VoIP School Blackbelt**，网址为 <https://voip.school>，或发送电子邮件至 <flavio@voip.school>。

**致谢。** 封面设计：Karla Braga。审校人员：Luis F. Gonçalves、Guilherme Goes (dCAP) 以及专业校对人员。我还要感谢多年来提供反馈并塑造了这些教材的众多学员，以及我的家人给予的支持。

```{=latex}
\cleardoublepage
```
