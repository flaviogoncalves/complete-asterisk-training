# Part II — Channels & Connectivity {.unnumbered}

第II部では、Asteriskの内外でどのように通話が行われるかについて解説します。まず、Asteriskを中心としたVoIPネットワークの設計（codec、帯域幅、NATなど）から始め、次にSIPと、Asterisk 22における唯一のSIPチャネルである現代的なPJSIPの実装について深く掘り下げます。

そこから、実際の導入に必要な接続機能を追加していきます。WebRTCによるブラウザ通話、PSTNやプロバイダーに接続するためのtrunkやDID、そして現場で遭遇する可能性のあるレガシーなアナログ、デジタル（TDM）、IAX2チャネルについて学びます。この部を読み終える頃には、Asteriskを電話機、ブラウザ、通信事業者、そして旧式の機器に接続できるようになっているはずです。
