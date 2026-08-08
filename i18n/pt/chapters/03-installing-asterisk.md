# Instalando o Asterisk 22

No primeiro capítulo, aprendemos um pouco sobre como o Asterisk é útil no ambiente de telefonia. Neste capítulo, abordaremos como baixar e instalar o Asterisk. Antes de começar, é essencial aprender como compilá-lo e instalá-lo. O processo de compilação pode parecer estranho para usuários tradicionais do Microsoft™ Windows™, mas é bastante comum no ambiente Linux™. É possível obter um código otimizado para o seu hardware ao compilar o Asterisk, que é o que faremos aqui. O Asterisk roda em vários sistemas operacionais, mas manteremos as coisas simples e usaremos apenas um: Linux. Usamos o **Ubuntu 24.04 LTS** porque suas dependências são fáceis de instalar e é uma distribuição de servidor estável, bem suportada e com baixo consumo de recursos. Se você preferir outra distribuição, ajuste os nomes dos pacotes de acordo.

Esta edição tem como alvo o **Asterisk 22 LTS** (lançado em 2024-10-16; suporte completo até 2028-10-16, correções de segurança até 2029-10-16). O Asterisk 22 é a versão atual de suporte de longo prazo. Observe que a Digium foi adquirida pela **Sangoma** em 2018, e o Asterisk agora é patrocinado pela Sangoma — as referências a "Digium" ao longo deste capítulo referem-se à marca legada para hardware histórico.

## Objetivos

Ao final deste capítulo, você deverá ser capaz de:

- Determinar os requisitos de hardware para o Asterisk;
- Instalar o Linux com as dependências necessárias;
- Baixar uma versão estável via HTTPS;
- Compilar o Asterisk; e
- Aprender como iniciar o Asterisk no momento da inicialização do sistema.

## Requisitos Mínimos de Hardware

O Asterisk não precisa de muito hardware para funcionar, no entanto, existem algumas dicas para escolher o melhor hardware para suas necessidades. Você deve levar em consideração os seguintes fatores principais ao escolher seu hardware:

- Número total de usuários registrados. Defina quantos registros por segundo você precisa suportar
- Número total de chamadas simultâneas. Defina quantas conversas de rede você precisa processar no adaptador de rede e fazer a ponte no servidor Asterisk
- Quais codecs você precisa suportar. Codecs de alta complexidade exigirão muito poder de CPU/FPU em seu servidor; o iLBC, por exemplo, foi medido por seu criador (Global IP Sound) em aproximadamente 18 MIPS por canal para quadros de 30 ms (e cerca de 15 MIPS para quadros de 20 ms) em um DSP TI C54x
- Cancelamento de eco. O cancelamento de eco pode consumir muita CPU/FPU; em alguns casos, você deve escolher o cancelamento de eco por hardware usando DSPs na placa de interface de telefonia
- Disponibilidade. Use RAID1 ou 5 para aumentar a disponibilidade. Lembre-se, o Asterisk é uma aplicação 24x7.

O principal componente para um servidor Asterisk é o adaptador de rede. Recomenda-se um bom adaptador de rede para servidor. A CPU é importante quando você precisa suportar codecs de alta complexidade, como g.729 e iLBC, e cancelamento de eco. Você pode optar por delegar isso a DSPs dedicados: a Sangoma (anteriormente Digium) fornece uma placa DSP chamada TC400B capaz de suportar 120 chamadas simultâneas em G.729.

A melhor prática é escolher um computador novo, de classe servidor, de um fabricante conhecido. Para saber exatamente quantas chamadas simultâneas ou quantos usuários registrados uma máquina específica pode suportar, você deve testar esse hardware com uma ferramenta de teste de estresse, como o SIPP (http://sipp.sourceforge.net). Alguns fabricantes de hardware, como a Xorcom (http://www.xorcom.com), publicam seus resultados no site.

Nota: Algumas aplicações do Asterisk, como ConfBridge e música em espera, precisam de uma fonte de temporização interna. No Linux moderno, isso é fornecido automaticamente pelo módulo integrado `res_timing_timerfd` — nenhum hardware de telefonia é necessário. (O antigo temporizador de software `dahdi_dummy` não existe mais; sua funcionalidade foi incorporada ao módulo principal do kernel `dahdi` no DAHDI Linux 2.3.0.) Você pode confirmar o temporizador ativo com o comando de CLI `timing test`.

### Configuração de hardware

O hardware do Asterisk não precisa ser sofisticado. Você não precisa de uma placa de vídeo cara ou de inúmeros periféricos. Algumas dicas sobre a configuração de hardware:

- Desative portas USB, seriais e paralelas não utilizadas para evitar o consumo de interrupções desnecessárias.
- Uma placa de interface de rede robusta é essencial.
- Tenha cuidado especial se estiver usando placas de interface de telefonia. Algumas placas usam um barramento PCI de 3,3 volts, e não é fácil encontrar placas-mãe para elas. Atualmente, o PCI Express é encontrado mais facilmente.
- Preste muita atenção ao disco rígido; um PBX costuma trabalhar em regime 24x7, enquanto desktops trabalham 8x5. Não use hardware de desktop para um PBX, geralmente o disco rígido falha antes do primeiro ano. Minha recomendação é usar uma máquina servidor ou um appliance projetado para executar aplicações 24x7.

### Compartilhamento de IRQ (apenas para placas PCI legadas)

Esta preocupação aplica-se **apenas** se você instalar placas de telefonia físicas PCI/PCI-Express (hardware DAHDI). Tais placas geram um grande número de interrupções e, em sistemas antigos de CPU única, compartilhar uma linha de IRQ com outro dispositivo poderia sobrecarregar o driver e degradar a qualidade da voz. Se você usar placas de telefonia, dedique a máquina ao Asterisk, desative quaisquer dispositivos integrados não utilizados no BIOS e verifique as interrupções atribuídas com `cat /proc/interrupts`. Servidores multi-core modernos que usam interrupções MSI/MSI-X tornam o compartilhamento de IRQ um problema inexistente na prática, e uma implementação puramente VoIP (sem placas) não precisa se preocupar com isso.

## Escolhendo uma distribuição Linux

O Asterisk foi desenvolvido inicialmente para rodar em Linux. No entanto, ele também pode rodar em BSD Unix ou macOS. Se você é novo no Asterisk, tente usar o Linux primeiro, já que é muito mais fácil. O Asterisk tem como alvo oficial a família RHEL (CentOS/RHEL/Fedora), Ubuntu e Debian. Boas escolhas práticas hoje em dia são **Debian 12**, **Ubuntu 22.04 LTS / 24.04 LTS** e **Rocky Linux 9 / AlmaLinux 9** — o CentOS Linux chegou ao fim da vida útil, portanto, prefira Rocky ou AlmaLinux em sistemas da família RHEL. Para este livro, usarei o Ubuntu 24.04 LTS. Baixe a imagem de servidor da versão pontual mais recente do 24.04 no diretório oficial de lançamentos abaixo (o nome exato do arquivo inclui a versão pontual atual, por exemplo, `ubuntu-24.04.4-live-server-amd64.iso`):

```
https://releases.ubuntu.com/24.04/
```

### Preparando o Linux para o Asterisk

Antes de compilar o Asterisk, você precisa de um sistema Linux funcional com os pacotes de compilação instalados. Instale o **Ubuntu 24.04 LTS Server** em uma máquina virtual ou em um servidor dedicado (use a imagem de 64 bits; tudo neste livro é de 64 bits, embora o próprio Asterisk ainda suporte x86 de 32 bits). Usamos o VirtualBox para este treinamento; você pode baixar a imagem em <https://releases.ubuntu.com/24.04>. A instalação do próprio Linux está fora do escopo deste livro — conhecimentos básicos de Linux são um pré-requisito. Com o Linux instalado, você adicionará as dependências de compilação do Asterisk (veja *Instalando dependências* abaixo) e, em seguida, compilará o Asterisk.

## Instalando o Linux para o Asterisk

Instale o Linux como de costume, sem uma interface gráfica. Durante a instalação, habilite também um agente de transferência de e-mail (usamos o **exim4**) — o Asterisk precisará dele para enviar notificações de voicemail-para-e-mail mais adiante neste livro. **Cuidado:** instalar um sistema operacional apaga o disco de destino. Se você instalar em um hardware físico, faça backup dos seus dados primeiro; a instalação em uma máquina virtual deixa seu host intacto. Inicialize o instalador a partir da ISO do Ubuntu Server (ou da unidade óptica virtual da VM) e responda às solicitações — a maioria é direta.

## Instalando dependências

Para instalar o Asterisk e o DAHDI, você precisa instalar diversas dependências de software. A maneira recomendada de fazer isso no Asterisk 22 é utilizar o script que acompanha a árvore de código-fonte, o qual conhece os nomes corretos dos pacotes para cada distribuição suportada. Após baixar e extrair o código-fonte do Asterisk (veja "Compilando o Asterisk" abaixo), execute:

```
cd /usr/src/asterisk-22.x.y
./contrib/scripts/install_prereq install
```

1. Faça login como root (ou use `sudo`).
2. Se você preferir instalar as dependências manualmente em um sistema Debian/Ubuntu, a lista de pacotes equivalente é:

```
apt-get install build-essential git wget openssl libssl-dev libxml2-dev \
  libsqlite3-dev uuid-dev libjansson-dev libedit-dev libncurses-dev \
  libcurl4-openssl-dev pkg-config autoconf-archive
```

Observe que o código-fonte do Asterisk agora está hospedado no Git, portanto o `subversion` não é mais necessário, e as versões modernas do Debian/Ubuntu fornecem o `libncurses-dev` em vez do versionado `libncurses5-dev`. Prefira o `./contrib/scripts/install_prereq install` em vez de uma lista mantida manualmente, já que o script sempre acompanha os nomes corretos dos pacotes para a sua distribuição.

### DAHDI

O DAHDI (Digium/Sangoma Asterisk Hardware Device Interface) é a arquitetura de drivers para placas analógicas e digitais. Antes de instalar o Asterisk, é importante instalar o DAHDI se você planeja usar interfaces analógicas ou digitais. O DAHDI ainda existe para placas de telefonia analógica/digital, mas é cada vez mais um nicho — a maioria das implementações modernas é puramente VoIP e pode ignorar esta seção completamente. Instale o DAHDI apenas se você possuir hardware de interface de telefonia física. Obtenha os arquivos de código-fonte usando:

```
wget https://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-current.tar.gz
```

Descompacte os arquivos usando:

```
tar -xzvf dahdi-linux-complete-current.tar.gz
```

### Compilando os drivers DAHDI

Você precisará compilar os módulos do DAHDI. Os comandos ./configure e make menuselect foram introduzidos há vários anos. Este último permite que você selecione quais utilitários e módulos compilar. Os comandos a seguir farão isso:

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

O make install-config do DAHDI foi configurado. Se você possui algum hardware DAHDI, agora é recomendado editar o arquivo /etc/dahdi/modules para carregar suporte apenas para o hardware DAHDI instalado neste sistema. Por padrão, o suporte para todo o hardware DAHDI é carregado na inicialização do DAHDI. Acredito que o hardware DAHDI que você possui em seu sistema seja: usb:004/002 xpp_usb- e4e4:1150 Astribank-multi no-firmware Esta tela (acima) solicita que você altere o arquivo /etc/dahdi/modules para carregar apenas os drivers necessários para sua configuração específica e mostrar o hardware detectado. Edite o arquivo /etc/dahdi/modules e carregue apenas o hardware necessário. No meu caso, eu estava usando uma máquina de teste com um Xorcom Astribank 6FXS e 2FXO. O arquivo é mostrado abaixo.

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

Reinicialize seu computador e verifique o carregamento correto dos drivers.

## Qual versão escolher

Como regra geral, você deve usar a versão que possua os recursos necessários. O Asterisk segue um modelo de lançamento que alterna entre versões LTS (suporte de longo prazo) e versões padrão. No momento desta edição, o **Asterisk 22 é a versão LTS atual** (lançada em outubro de 2024; a versão pontual mais recente é 22.10.0), o que a torna a melhor escolha no momento. O Asterisk 20 é a LTS anterior, e a versão 16 (usada na primeira edição) está em fim de vida útil (end-of-life). Para sistemas em produção, escolha sempre uma versão LTS.

## Compilando o Asterisk

Se você já compilou software anteriormente, compilar o Asterisk será uma tarefa fácil. Execute os comandos a seguir para compilar e instalar o Asterisk. Lembre-se, você pode escolher quais aplicações e módulos compilar usando o make menuselect. Passo 1: Baixe o código-fonte

```
cd /usr/src
wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz
tar -xzvf asterisk-22-current.tar.gz
```

Passo 2: Instale os pré-requisitos de compilação (veja "Instalando dependências" acima)

```
cd asterisk-22.x.y (adapt to the version downloaded)
./contrib/scripts/install_prereq install
```

Passo 3: Configure a compilação

```
./configure
```

Passo 4: Selecione os módulos para compilar

```
make menuselect
```

Use o make menuselect para instalar apenas os módulos necessários. No Asterisk 22, o canal SIP é o **chan_pjsip** (compilado por padrão); o antigo **chan_sip** foi removido no Asterisk 21 e não existe mais. O *pass-through* de Opus funciona nativamente (o módulo `res_format_attr_opus` incluso gerencia a negociação SDP), mas o módulo de transcodificação **codec_opus** ainda é um binário externo de código fechado da Sangoma/Digium — selecioná-lo no menuselect faz o download a partir dos servidores da Digium. O binário é gratuito. Veja "Selecionando módulos com o menuselect" abaixo para detalhes.

Passo 5: Compile e instale o Asterisk, depois crie as configurações padrão e os arquivos de exemplo

```
make
make install
make samples
make config
ldconfig
```

`make install` instala os binários e módulos, `make samples` grava os arquivos de configuração de exemplo em `/etc/asterisk`, `make config` instala o script de inicialização SysV para sua distribuição detectada (por exemplo, `/etc/init.d/asterisk` no Debian/Ubuntu), e `ldconfig` atualiza o cache de bibliotecas compartilhadas. Uma unidade systemd também é fornecida na árvore de código-fonte em `contrib/systemd/asterisk.service`, mas o `make config` não a instala automaticamente — copie-a para o local apropriado manualmente se você preferir executar o Asterisk sob o systemd (veja abaixo).

### Selecionando módulos com o menuselect

`make menuselect` abre um menu baseado em texto onde você escolhe exatamente quais aplicações, codecs, canais e recursos compilar. Algumas notas específicas para o Asterisk 22:

- **chan_pjsip** (em *Channel Drivers*) é o canal SIP moderno e está habilitado por padrão; é o único canal SIP no Asterisk 22.
- **codec_opus** (em *Codec Translators*) é um módulo **externo** (sua entrada no menuselect diz "Download the Opus codec from Digium"); habilitá-lo faz com que o `make` busque o binário gratuito de código fechado da Sangoma/Digium. O *pass-through* de Opus em si não precisa de nenhum módulo extra. O módulo **codec_g729** da Sangoma também está disponível — o binário é gratuito para download, mas a transcodificação legal de G.729 requer a compra de uma licença por canal.
- Selecione os formatos de som e idiomas que você deseja nos menus *Core Sound Packages*, *Music On Hold File Packages* e *Extras Sound Packages*; tudo o que você marcar lá será baixado e instalado automaticamente durante o `make install`.

Após fazer suas seleções, escolha **Save & Exit** e continue com o `make`.

## Iniciando e parando o Asterisk

Com esta configuração mínima, é possível iniciar o Asterisk com sucesso. Para fins de aprendizado e depuração, você pode iniciar o Asterisk em primeiro plano, conectado ao console:

```
/usr/sbin/asterisk -vvvgc
```

Use o comando da CLI `core stop now` para encerrar o Asterisk:

```
*CLI> core stop now
```

### Iniciando o Asterisk com systemd

Em distribuições Linux modernas (Debian 12, Ubuntu 22.04/24.04, Rocky/AlmaLinux 9), o gerenciador de serviços do sistema é o **systemd**. O Asterisk fornece uma unidade systemd em `contrib/systemd/asterisk.service` na árvore de código-fonte; copie-a para `/etc/systemd/system/asterisk.service` e execute `systemctl daemon-reload`. Uma vez instalado, a maneira recomendada de executar o Asterisk em produção é através do `systemctl`:

```
systemctl start asterisk      # start the service
systemctl stop asterisk       # stop the service
systemctl restart asterisk    # restart the service
systemctl status asterisk     # show current status
systemctl enable asterisk     # start automatically at boot
```

Assim que o Asterisk estiver sendo executado como um serviço, conecte-se à sua CLI com `asterisk -r` (conectar) ou `asterisk -rvvv` (conectar com saída detalhada/verbose).

Em sistemas mais antigos, o Asterisk era iniciado via script de inicialização SysV legado (`/etc/init.d/asterisk`) e o wrapper **safe_asterisk**, que reiniciava o Asterisk automaticamente caso ele travasse. Com o systemd, a reinicialização automática é tratada pela diretiva `Restart=` do arquivo de unidade, portanto, o `safe_asterisk` geralmente não é mais necessário. A abordagem legada de init/`safe_asterisk` ainda funciona, mas está obsoleta em distribuições baseadas em systemd.

### Opções de tempo de execução do Asterisk

O processo de inicialização do Asterisk é muito simples. Se o Asterisk for executado sem nenhum parâmetro, ele é iniciado como um daemon.

```
/sbin/asterisk
```

Você pode acessar o console do Asterisk executando o seguinte comando. Observe que mais de um processo de console pode ser executado ao mesmo tempo.

```
/sbin/asterisk -r
```

### Opções de tempo de execução disponíveis para o Asterisk

Você pode exibir as opções de tempo de execução disponíveis usando `asterisk -h`

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

## Diretórios de instalação

O Asterisk é instalado em diversos diretórios, os quais podem ser modificados no arquivo asterisk.conf. Para fins de treinamento, eu alteraria o verbose de 3 para 15; para produção, mantenha-o em 3. As opções `maxcalls` e `maxload` são boas opções para proteger seu sistema contra sobrecarga.

### asterisk.conf (trecho)

A seção `[directories]` define onde o Asterisk mantém suas configurações, módulos, dados, spool e logs:

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

A seção `[options]` contém o ajuste de tempo de execução (runtime tuning). As opções mais úteis de se conhecer são mostradas abaixo (remova o comentário para ativar); o arquivo é fornecido com muitas outras, cada uma documentada por um comentário em linha:

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

## Arquivos de log e rotação de logs

O Asterisk PBX registra suas mensagens em `/var/log/asterisk`. O registro em log é controlado pelo `logger.conf`. A parte principal é a seção `[logfiles]`, onde cada linha define um canal de log e os níveis de mensagem que ele captura (trecho):

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

Após editar, aplique a alteração com `logger reload` e confirme os canais com `logger show channels`:

```text
*CLI> logger show channels
Channel                       Type   Formatter  Status   Configuration
/var/log/asterisk/security    File   default    Enabled  - SECURITY
/var/log/asterisk/full        File   default    Enabled  - NOTICE WARNING ERROR VERBOSE DTMF FAX
/var/log/asterisk/messages    File   default    Enabled  - NOTICE WARNING ERROR
```

Os arquivos de log podem crescer rapidamente, portanto, faça a rotação deles com o daemon do sistema `logrotate` — adicione um arquivo em `/etc/logrotate.d/`:

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

Mais informações sobre o logrotate podem ser obtidas usando:

```
#man logrotate
```

## Desinstalando o Asterisk

Para desinstalar o Asterisk, use:

```
make uninstall
```

Para desinstalar o Asterisk e todos os arquivos de configuração, use:

```
make uninstall-all
```

## Notas de instalação do Asterisk

Esta seção fornecerá alguns conselhos sobre questões a serem abordadas antes de instalar o Asterisk.

### Sistemas de Produção

Se o Asterisk for instalado em um ambiente de produção, você deve prestar atenção ao projeto do sistema. Um servidor deve ser otimizado de tal forma que os sistemas de telefonia tenham prioridade sobre outros processos do sistema. O Asterisk não deve ser executado junto com softwares que consomem muitos recursos do processador, como o X-Windows. Se você precisar executar processos que consomem muita CPU (por exemplo, um banco de dados enorme), use um servidor separado. De modo geral, o Asterisk é suscetível a variações de desempenho de hardware. Portanto, tente usar o Asterisk em um ambiente de hardware que não exija mais de 40% de utilização da CPU.

### Dicas de Rede

Se você planeja usar telefones IP, é importante que você preste atenção à sua rede. Os protocolos de voz são muito bons e resistentes à latência e até mesmo ao jitter; no entanto, se você usar uma rede local mal configurada, a qualidade da voz sofrerá. Só é possível garantir uma boa qualidade de voz usando qualidade de serviço (QoS) em switches e roteadores. A voz em uma rede local tende a ser boa, mas mesmo em um ambiente LAN, se você tiver hubs de 10 Mbps com muitas colisões, acabará tendo uma voz distorcida ou de má qualidade. Siga estas recomendações para garantir a melhor qualidade de voz possível:

- Use QoS de ponta a ponta, se possível ou economicamente viável. Com QoS de ponta a ponta, a qualidade da voz é perfeita. Sem desculpas!
- Evite usar hubs de 10/100 Mbps para voz em um ambiente de produção. Colisões podem impor jitter na rede. Switches full duplex de 10/100 Mbps são preferíveis porque não ocorrem colisões.
- Use VLANs para separar broadcasts desnecessários da rede de voz. Você não quer um vírus destruindo sua rede de voz com broadcasts ARP.
- Eduque os usuários sobre as expectativas em uma rede de voz. Sem QoS, não afirme que a voz será perfeita, pois na maioria dos casos não será. Uma qualidade de voz semelhante à de um telefone celular será alcançada na maioria das vezes. Use telefones de qualidade, pois problemas com firmware e projeto de hardware são comuns.

## Resumo

Neste capítulo, você aprendeu sobre os requisitos mínimos de hardware, bem como a baixar, instalar e compilar o Asterisk. O Asterisk deve ser executado com um usuário não root por motivos de segurança. Você deve verificar seu ambiente de rede antes de iniciar o ambiente de produção.

## Quiz

1. No Asterisk 22, qual driver de canal fornece suporte a SIP e o que aconteceu com o antigo `chan_sip`?
   - A. `chan_sip` ainda é o padrão; `chan_pjsip` é opcional.
   - B. `chan_pjsip` é o canal SIP padrão; `chan_sip` foi removido no Asterisk 21 e não existe mais.
   - C. Ambos são compilados por padrão e você escolhe entre eles em tempo de execução.
   - D. O suporte a SIP foi removido completamente em favor do IAX2.
2. Placas de interface de telefonia para Asterisk geralmente possuem Processadores de Sinal Digital (DSPs) integrados e, portanto, não exigem muito da CPU do PC.
   - A. Verdadeiro
   - B. Falso
3. Se você deseja uma qualidade de voz perfeita, precisa implementar qualidade de serviço (QoS) de ponta a ponta.
   - A. Verdadeiro
   - B. Falso
4. Você deve sempre escolher a versão mais recente do Asterisk, pois ela é a mais estável.
   - A. Verdadeiro
   - B. Falso
5. Qual é a maneira recomendada de instalar as dependências de compilação para o Asterisk 22?
6. Se você não possui uma placa de interface TDM, ainda terá uma fonte de temporização interna para sincronização, fornecida pelo módulo `res_timing_timerfd` no Linux. Essa temporização é usada por aplicações como ________ e ________.
7. Ao instalar o Asterisk, é melhor deixar de fora ambientes de desktop como GNOME ou KDE, porque interfaces gráficas consomem ciclos de CPU.
   - A. Verdadeiro
   - B. Falso
8. Os arquivos de configuração do Asterisk estão localizados no diretório ________.
9. Para instalar os arquivos de configuração de exemplo do Asterisk, digite o comando: ________
10. Por que é importante executar o Asterisk como um usuário não root?

**Respostas:** 1 — B · 2 — B · 3 — A · 4 — B · 5 — Execute `./contrib/scripts/install_prereq install` a partir da árvore de código-fonte do Asterisk extraída · 6 — ConfBridge e Music on Hold · 7 — A · 8 — `/etc/asterisk` · 9 — `make samples` · 10 — Segurança (limita os danos caso o Asterisk seja comprometido)
