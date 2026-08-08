# Canais legados: analógico, TDM e IAX2

Em um mundo puramente VoIP em 2026, os tipos de canal neste capítulo são cada vez mais raros: a maioria das novas implementações utiliza trunks SIP e endpoints PJSIP via Ethernet, sem nenhum hardware de telefonia. O Asterisk 22, no entanto, ainda oferece suporte total à maioria deles. A conectividade analógica (FXO/FXS) e digital TDM (E1/T1/ISDN PRI/BRI) é fornecida através do DAHDI — a pilha de drivers desenvolvida originalmente pela Digium, que foi adquirida pela Sangoma em 2018, após os drivers Zaptel anteriores serem renomeados devido a uma disputa de marca registrada. A conectividade servidor-a-servidor via IAX2 é fornecida pelo `chan_iax2`, que ainda é distribuído e suportado, mas que agora é firmemente um protocolo legado.

Este capítulo também reúne o material sobre **SIP legado**: o antigo driver `chan_sip` e sua configuração `sip.conf` — removidos no Asterisk 21 e ausentes no Asterisk 22 — juntamente com um guia completo para migrar um sistema `sip.conf` existente para PJSIP. Se você está operando um ambiente puramente SIP com PJSIP, sem placas de telefonia, sem trunks IAX2 e sem `sip.conf` legado para converter, você pode pular este capítulo com segurança.

## Objetivos

Ao final deste capítulo, você deverá ser capaz de:

- Conectar o Asterisk a linhas e telefones analógicos com interfaces FXO/FXS através do DAHDI;
- Reconhecer a conectividade TDM digital (E1/T1, ISDN PRI/BRI) e como ela é configurada;
- Configurar o IAX2 (`chan_iax2`) para trunks entre servidores e entender por que ele é agora considerado legado;
- Identificar o driver aposentado `chan_sip` e a sintaxe `sip.conf` que você ainda pode encontrar; e
- Migrar um sistema `chan_sip`/`sip.conf` existente para PJSIP.

## Canais analógicos (FXO/FXS)

A partir do Asterisk 22, o DAHDI e as placas de telefonia analógica permanecem totalmente suportados, e o DAHDI ainda é compilado com kernels atuais. A maioria das novas implementações, no entanto, é puramente VoIP (trunks SIP, PJSIP), portanto, o hardware analógico/TDM é agora uma escolha de nicho — encontrada principalmente em ambientes legados, conectividade PSTN rural ou mercados regulamentados. Tudo abaixo ainda se aplica a esses cenários.

Existem várias maneiras de conectar à rede telefônica pública comutada (PSTN). A melhor maneira depende de como a companhia telefônica disponibiliza essa conexão em sua área. A maneira mais simples é usar uma linha analógica, semelhante à linha que você usa em casa. Nesta seção, mostraremos como configurar placas analógicas da Sangoma™ (anteriormente Digium™) e Xorcom™.

### Objetivos

Ao final deste capítulo, você deverá ser capaz de:

- Reconhecer os principais termos e siglas de telefonia;
- Entender quando usar circuitos digitais e analógicos;
- Reconhecer a diferença entre FXS e FXO; e
- Configurar o Asterisk para FXS e FXO.

### Noções básicas de telefonia

A maioria das implementações analógicas usa um par de fios de cobre chamado tip e ring. Quando um loop é fechado, o telefone recebe o tom de discagem da central telefônica (ou do PBX privado). A sinalização mais utilizada é a loop-start; outros tipos menos comuns de sinalização incluem ground-start, que é usada em vários países. As três categorias de sinalização são:

- Sinalização de supervisão
- Sinalização de endereçamento
- Sinalização de informação

#### Sinalização de supervisão

As principais sinalizações de supervisão são on-hook, off-hook e ringing.

- **On-Hook** – Quando um usuário coloca o telefone no gancho, o PBX interrompe e não permite a passagem de corrente elétrica. Nesse estado, o circuito é chamado de on-hook. Nesta posição, apenas a campainha está ativa.
- **Off-Hook** – Antes de iniciar uma chamada telefônica, o telefone precisa passar para o estado off-hook. Retirar o monofone do gancho fecha o loop e indica ao PBX que o usuário pretende fazer uma chamada. Ao receber essa indicação, o PBX gera um tom de discagem, indicando ao usuário que está pronto para aceitar o endereço de destino (ou seja, o número de telefone).
- **Ringing** – Quando um usuário liga para outro telefone, ele gera uma voltagem para a campainha que avisa o outro usuário sobre uma chamada sendo recebida. A sinalização varia de acordo com o país, com tons diferentes para países diferentes.

Você pode personalizar os tons do Asterisk para o seu país modificando o arquivo indications.conf. Por exemplo:

```
[br]
description=Brazil
ringcadance=1000,4000
dial=425
busy=425/250,0/250
ring=425/1000,0/4000
congestion=425/250,0/250,425/750,0/250
callwaiting=425/50,0/1000
```

#### Sinalização de endereçamento

Você pode usar dois tipos de sinalização para discagem. O primeiro e mais comum é o dual tone multi-frequency (dtmf), enquanto o outro é a discagem por pulso (usada em telefones antigos de disco). Os telefones possuem um teclado para discagem, e cada botão está associado a duas frequências: uma alta e uma baixa. No caso da sinalização dtmf, a combinação desses tons indica qual dígito está sendo pressionado. MFC/R2 usa um tom multifrequencial diferente do dtmf.

#### Sinalização de informação

A sinalização de informação mostra o progresso da chamada e diferentes eventos.

- Tom de discagem
- Tom de ocupado
- Ringback
- Congestionamento
- Número inválido
- Tom de confirmação

### Interfaces PSTN

Como no caso de PBXs antigos, muitas vezes é necessário conectar o PBX Asterisk à PSTN. Aqui mostraremos como fazer isso. Geralmente, você tem três opções para linhas telefônicas.

- Analógica: A forma mais comum para residências e pequenas empresas, geralmente entregue com um par metálico de fios de cobre.
- Digital: Usada quando muitas linhas são necessárias. Uma linha digital é geralmente entregue por um CSU/DSU ou um multiplexador de fibra. O conector do usuário final é geralmente um RJ45. Em alguns países, as linhas E1 são entregues usando dois conectores BNC coaxiais; neste caso, você precisará de um balun para conectar ao jack RJ45 da placa de telefonia.
- SIP: Esta opção foi desenvolvida recentemente. A linha telefônica é entregue usando uma conexão de dados com sinalização SIP (VoIP). Esta é uma boa opção para usar com o Asterisk, já que você não precisará comprar uma placa de telefonia. As chamadas telefônicas serão entregues diretamente na porta Ethernet. Outra vantagem é que você pode liberar recursos da sua CPU evitando a transcodificação de codec.

### Interfaces analógicas FXS, FXO e E&M

Vários tipos de interfaces analógicas estão disponíveis. É fundamental entender as diferenças entre essas interfaces para aprender como se conectar à rede telefônica, bem como a outros PBXs. Aqui, mostraremos a interface E&M. Embora não esteja disponível atualmente para o Asterisk e tenha sido descontinuada por vários fabricantes, você pode encontrar roteadores e PBXs com esse tipo de interface, por isso é melhor saber com o que você está lidando.

#### Interfaces Foreign eXchange (FX)

As interfaces FX são analógicas. O termo “Foreign eXchange” é aplicado a trunks de acesso a uma central telefônica (CO) da PSTN. Foreign eXchange Office (FXO)

![Asterisk entre um telefone analógico (FXS) e a linha da operadora (FXO): o lado FXS fornece tom de discagem e campainha para o telefone, enquanto o lado FXO recebe o tom de discagem da central telefônica.](../images/10-legacy-fig01.png)

A interface FXO é usada para conectar a uma central telefônica (CO) ou à extensão de outro PBX. Ela se comunica diretamente com uma linha telefônica vinda da PSTN. Outra opção é conectar a interface FXO a um PBX existente, permitindo a comunicação entre o Asterisk e o PBX legado. Conectar o Asterisk a uma porta de PBX e entregar uma extensão remota usando VoIP é frequentemente chamado de off-premises extension (OPX). Uma interface FXO recebe um tom de discagem. Foreign eXchange Station (FXS) A interface FXS alimenta um telefone analógico, modem ou fax. O FXS fornece o tom de discagem e a energia para um telefone.

#### Sinalização de trunk

- Loop-Start
- Ground-Start
- Kewlstart

O uso da sinalização kewlstart no Asterisk é quase padrão. Kewlstart não é uma sinalização em si, mas adiciona inteligência ao circuito monitorando o que está acontecendo do outro lado. Kewlstart é baseado em loop-start. A maioria das centrais não suporta esse recurso, que é usado para obter a notificação de desligamento.

- Loopstart: Usado na maioria das linhas analógicas, permite que o telefone indique “on-hook” e “off-hook” e que a central indique “ring” e “no-ring”. Isso é provavelmente o que a maioria das pessoas tem em casa. O nome vem do fato de que a linha está sempre aberta. Quando você fecha o loop, a central fornece um tom de discagem. Uma chamada recebida é sinalizada por uma voltagem de campainha de 100V sobre o par aberto.

![Asterisk operando como um gateway VoIP: uma porta FXO conecta-se a uma extensão de PBX legado enquanto um Asterisk remoto entrega essa linha a um telefone analógico via IP através de uma porta FXS (uma off-premises extension, ou OPX).](../images/10-legacy-fig02.png)

- Groundstart: Semelhante ao Loopstart. Quando você deseja fazer uma chamada, um lado da linha é colocado em curto-circuito. Quando a central identifica esse estado, ela inverte a voltagem através do par aberto e, então, o loop é fechado. Consequentemente, a linha primeiro se torna ocupada antes de ser oferecida ao chamador.
- Kewlstart: Adiciona inteligência aos circuitos, permitindo o monitoramento do outro lado. Kewlstart incorpora muitas vantagens do loop-start.

### Configuração de canais de telefonia Asterisk

Para configurar uma placa de interface de telefonia, várias etapas são necessárias. Neste capítulo, mostraremos três dos cenários mais comuns:

- Conexão analógica usando FXS
- Conexão analógica usando FXO
- Conexão de um Astribank™ com interfaces FXS e FXO

### Procedimento de configuração (válido em ambos os casos)

Antes de escolher o hardware para o Asterisk, você deve considerar o número de chamadas simultâneas, serviços e codecs que serão instalados e habilitados. O Asterisk é uma aplicação que consome muitos recursos de CPU, e é por isso que recomendamos uma máquina dedicada para o Asterisk. O número de placas de interface instaladas no computador é limitado pelo número de slots e interrupções disponíveis. É preferível instalar uma única placa com oito interfaces de voz do que duas placas com quatro. Outra opção é usar um channel bank USB, como o Xorcom Astribank. Recentemente, alguns fabricantes (por exemplo, CIANET) começaram a produzir channel banks TDMoE, tornando ainda mais fácil conectar dezenas de interfaces analógicas.

![Um Xorcom Astribank: um channel bank USB de montagem em rack de 19 polegadas que expõe dezenas de portas FXS/FXO (aqui uma unidade de 32 portas) sem consumir slots PCI no host.](../images/10-legacy-fig03.png)

#### Exemplo 1: Instalação de um FXO e um FXS

Neste exemplo, usaremos uma placa de interface de telefonia Sangoma TDM400 (anteriormente vendida como Digium TDM400) com um módulo FXS e um FXO. As etapas necessárias estão listadas abaixo:

1. Instale a placa analógica FXS, FXO ou ambas.
2. Configure o arquivo `/etc/dahdi/system.conf` (anteriormente `/etc/zaptel.conf`).
3. Gere os arquivos de configuração usando `dahdi_genconf`.
4. Carregue o driver para a interface DAHDI.
5. Execute `dahdi_test` para verificar perdas de interrupção.
6. Execute `dahdi_cfg` para configurar o driver.
7. Configure o canal DAHDI no arquivo `chan_dahdi.conf`, então carregue o Asterisk.

##### Etapa 1: Instalar a placa TDM400

A placa TDM404P contém módulos FXS e FXO. Conecte os módulos FXS (S110M, verde) e FXO (X100M, vermelho). Se você estiver usando módulos FXS, conecte a placa diretamente à fonte de alimentação usando um conector molex. Por favor, use proteção eletrostática antes de manusear placas de interface para evitar danos ao hardware. As placas analógicas Sangoma (anteriormente Digium) também suportam um módulo de cancelamento de eco de hardware VPMADT032.

##### Etapa 2: Gerar a configuração com dahdi_genconf

A boa notícia sobre a configuração é o novo utilitário `dahdi_genconf`, que detecta e gera automaticamente a configuração para interfaces DAHDI. O utilitário gera dois arquivos:

- `/etc/dahdi/system.conf`
- `/etc/asterisk/dahdi-channels.conf`
- `/etc/asterisk/users.conf` (com a opção `users`)
- Todos esses arquivos usam a opção `chan_dahdi full`

Antes de poder executar `dahdi_genconf`, é importante configurar o arquivo `genconf_parameters` (frequentemente referido como `gen_parameters.conf`):

![Uma placa analógica Sangoma/Digium TDM404P: até quatro módulos FXS ou FXO conectam-se às portas numeradas, com uma placa filha opcional de cancelamento de eco de hardware e um conector de alimentação dedicado de 12 V para módulos FXS.](../images/10-legacy-fig04.png)

```
#
# /etc/dahdi/genconf_parameters
#
# This file contains parameters that affect the
# dahdi_genconf configurator generator.
#
#base_exten          4000
#fxs_immediate       no
#fxs_default_start   ks
#lc_country          il
#context_lines       from-pstn
#context_phones      from-internal
#context_input       astbank-input
#context_output      astbank-output
#group_phones        0
#group_lines         5
#brint_overlap
#bri_sig_style       bri_ptmp
#
# The echo canceller to use. If you have a hardware echo canceller, just
# leave it be, as this one won't be used anyway.
#
# The default is mg2, but it may change in the future. E.g: a packager
# that bundles a better echo canceller may set it as the default, or
# dahdi_genconf will scan for the "best" echo canceller.
#
#echo_can            hpec
#echo_can            oslec
#echo_can            none   # to avoid echo cancellers altogether
# bri_hardhdlc: If this parameter is set to 'yes', in the entries for
# BRI cards 'hardhdlc' will be used instead of 'dchan' (an alias for
# 'fcshdlc').
#
#bri_hardhdlc        yes
# For MFC/R2 Support
#pri_connection_type R2
#r2_idle_bits        1101
# pri_types contains a list of settings:
# Currently the only setting is for TE or NT (the default is TE)
#
#pri_termtype
# SPAN/2              NT
# SPAN/4              NT
```

O arquivo `genconf_parameters` permite que você personalize sua configuração. Os parâmetros mais importantes para linhas analógicas são:

```
base_exten          4000
fxs_immediate       no
fxs_default_start   ks
lc_country          br
context_lines       from-pstn
context_phones      from-internal
context_input       astbank-input
context_output      astbank-output
group_phones        0
group_lines         5
#echo_can           hpec
#echo_can           oslec
echo_can            MG2
```

Aviso: É necessário que você configure pelo menos o algoritmo de cancelamento de eco para os canais. O parâmetro base_exten define o dialplan básico para extensões FXS. Neste caso, o primeiro canal FXS receberá o número de extensão 4000, o segundo 4001, e assim por diante. O context no qual as linhas (context_phones) e trunks (context_lines) são criados é muito importante. Após gerar os arquivos, você deve incluir o arquivo `/etc/asterisk/dahdi-channels.conf` no arquivo `/etc/asterisk/chan_dahdi.conf`:

```
#include dahdi-channels.conf
```

Nota: A sinalização analógica é um pouco confusa; é sempre o inverso da placa. Placas FXS são sinalizadas com FXO, enquanto placas FXO são sinalizadas com FXS. O Asterisk fala com esses dispositivos como se estivesse no lado oposto.

##### Etapa 3: Carregar drivers de kernel

Agora você precisa carregar o módulo chan_dahdi e o driver de kernel da placa correspondente. Use dahdi_hardware para detectar sua placa e o nome do driver. Por exemplo:

| Placa | Driver | Descrição |
| --- | --- | --- |
| TE410P | wct4xxp | 4xE1/T1 - 3.3V PCI |
| TE405P | wct4xxp | 4xE1/T1 - 5V PCI |
| TDM400P | wctdm | 4 FXS/FXO |
| T100P | wct1xxp | 1 T1 |
| E100P | wct1xxp | 1 E1 |
| X100P | wcfxo | 1 FXO |

Comandos para carregar os drivers:

```
modprobe dahdi
modprobe wctdm
```

##### Etapa 4: Usar o utilitário dahdi_test

Um utilitário importante é o dahdi_test, que é usado para verificar perdas de interrupção na placa DAHDI. Problemas de qualidade de áudio estão frequentemente relacionados a conflitos de interrupção. Para verificar se sua placa DAHDI não está compartilhando uma interrupção com outras placas, use o seguinte comando:

```
#cat /proc/interrupts
```

Você pode verificar o número de perdas de interrupção usando o utilitário dahdi_test compilado com as placas DAHDI. Um número abaixo de 99.987% indica possíveis problemas.

##### Etapa 5: Usar o utilitário dahdi_cfg para configurar o driver

O DAHDI tem um sistema incomum para carregar os drivers. Primeiro configure o /etc/dahdi/system.conf e, em seguida, aplique essas configurações ao driver DAHDI usando dahdi_cfg. Neste caso, o dahdi_cfg é usado para configurar a sinalização para as interfaces FX. Para ver os resultados, você pode adicionar “-vvvvv” ao comando para modo detalhado (verbose).

```
#
/sbin/dahdi_cfg -vv
Dahdi Configuration
======================
Channel map:
Channel 01: FXS Kewlstart (Default) (Slaves: 01)
Channel 02: FXO Kewlstart (Default) (Slaves: 02)
2 channels configured.
```

Se os canais foram carregados com sucesso, você verá uma saída semelhante à mostrada acima. Os usuários frequentemente configuram incorretamente o chan_dahdi.conf com sinalização invertida entre os canais. Se isso acontecer, você verá uma mensagem como a mostrada abaixo:

```
DAHDI_CHANCONFIG failed on channel 1: Invalid argument (22)
Did you forget that FXS interfaces are configured with FXO signalling
and that FXO interfaces use FXS signalling?
```

Após configurar o hardware com sucesso, você pode prosseguir para a configuração do Asterisk.

##### Etapa 6: Configurar o arquivo /etc/asterisk/chan_dahdi.conf

Parece estranho, mas após configurar o /etc/dahdi/system.conf, você configurou a placa em si. O DAHDI pode ser usado para outros fins, como roteamento e SS7. Para usá-lo com o Asterisk, você deve configurar os canais DAHDI do Asterisk. Cada canal no Asterisk tem que ser definido; canais SIP/PJSIP são definidos em pjsip.conf (nota: chan_sip e sip.conf foram removidos no Asterisk 21), enquanto canais TDM são definidos em chan_dahdi.conf. Isso cria os canais TDM lógicos a serem usados no seu dialplan.

```
signalling=fxs_ks;                  ; FXS signaling for the FXO interface
group=1;                            ; channel group
context=incoming;                   ; context
channel => 1;                       ; channel number
signalling=fxo_ks;                  ; FXO signaling for the FXS interface
group=2;                            ; channel group
context=extensions;                 ; context
channel => 2                        ; channel number
```

### Opções de configuração

Várias opções estão disponíveis no arquivo chan_dahdi.conf. Uma descrição de todas as opções seria entediante e contraproducente; em vez disso, focaremos nos principais grupos de opções disponíveis para fácil entendimento.

#### Opções gerais (independentes de canal)

Estas opções funcionam para qualquer canal: context: Define o context de entrada.

```
context=default
```

channel: Define o canal ou intervalo de canais. Cada definição de canal herdará as opções definidas antes da declaração. Canais podem ser identificados individualmente ou na mesma linha por separação de vírgula. Intervalos podem ser definidos usando “-”.

```
Channel=>1-15
Channel=>16
Channel=>17,18
```

group: Permite que os canais sejam tratados como um grupo. Se você discar um número de grupo em vez de um número de canal, o primeiro canal disponível é usado. Se os canais forem telefones, quando você chamar um grupo, todos os telefones tocarão simultaneamente. Com vírgulas, você pode especificar mais de um grupo para o mesmo canal.

```
group=1
group=3,5
```

language: Ativa a internacionalização e configura um idioma. Este recurso configurará as mensagens do sistema para um idioma específico. Inglês é o único idioma com prompts completos disponíveis através da instalação padrão. musiconhold: Seleciona a classe de música em espera.

#### Opções de Caller ID

Existem muitas opções de callerid. Algumas podem ser desativadas, embora a maioria esteja ativada por padrão. usecallerid: Ativa ou desativa a transmissão de callerid para os canais subsequentes (Yes/No). Nota: Se o seu sistema recebe dois toques antes de atender, tente desativar este recurso. Ele deve atender imediatamente. hidecallerid: Define se deve ou não ocultar o callerid de saída (Yes/No). callerid: Configura uma string de callerid para um canal específico. O chamador pode ser configurado com asreceived. Isso é usado principalmente em interfaces de trunk para indicar o callerid de entrada.

```
callerid = "Flavio Eduardo Gonçalves" <48 30258500>
```

callwaitingcallerid: Suporta callerid durante a chamada em espera. useincomingcalleridondahditransfer: Usa o callerid de entrada em uma transferência.

#### Chamada em espera (Call Waiting)

O Asterisk suporta chamada em espera em canais FXS. O usuário receberá um tom de espera se alguém tentar a extensão. Para ativar a chamada em espera:

```
callwaiting=yes
```

Para suportar callerid na chamada em espera:

```
callwaitingcallerid=yes
```

#### Opções de qualidade de áudio

Ajustar o cancelamento de eco é metade técnica, metade arte. Essas opções ajustam certos parâmetros do Asterisk que afetam a qualidade de áudio nos canais DAHDI. Eles podem ajudar a melhorar a qualidade de áudio em interfaces analógicas.

#### O utilitário fxotune

O fxotune é um utilitário usado para ajustar finamente certos parâmetros para módulos FXO. Esse ajuste fino é necessário para corrigir o descasamento de impedância causado pelo híbrido. O utilitário tem três modos de operação:

- Detecção (-i): detecta e corrige os canais FXO existentes e salva a configuração em

```
fxotune.conf
```

- Modo de despejo (-d): gera os arquivos de forma de onda para fxotune_dump.vals
- Modo de inicialização (-s): lê o arquivo fxotune.conf e o aplica aos módulos FXO

É importante entender que você terá que inserir a instrução fxotune –s no carregamento do sistema antes de iniciar o Asterisk:

```
#modprobe dahdi
#modprobe wctdm
#fxotune -s
```

### Cancelamento de eco

A maioria dos algoritmos de cancelamento de eco opera gerando múltiplas cópias do sinal recebido, nas quais cada uma é atrasada por uma quantidade específica de tempo. O número de taps do filtro determina o tamanho do atraso de eco que precisa ser cancelado. Essas cópias atrasadas são então ajustadas e subtraídas do sinal recebido. O truque é ajustar apenas o sinal atrasado para remover o eco sem usar muitos ciclos de CPU. Da perspectiva dos usuários, é importante escolher um algoritmo de cancelamento de eco apropriado. O padrão é MG2; no entanto, duas outras opções estão disponíveis: o High Performance Echo Cancellation (HPEC) da Sangoma (anteriormente Digium) e o cancelamento de eco de código aberto (OSLEC) desenvolvido por David Rowe.

O OSLEC (https://www.rowetel.com/?page_id=454) foi mesclado ao kernel Linux — ele reside na área `drivers/staging/echo` do kernel — e o DAHDI é compilado com ele em vez de fornecer um download separado. Para alterar o algoritmo de cancelamento de eco, defina o parâmetro `echo_can` em `/etc/dahdi/system.conf`. Por exemplo:

```
echo_can=oslec
```

O cancelamento de eco no Asterisk é controlado por três parâmetros no arquivo /etc/asterisk/chan-

```
dahdi.conf.
```

- **echocancel**: Desativa ou ativa o cancelamento de eco. Você deve manter esse recurso ativado. Ele aceita "yes" ou o número de taps. (Explicação: Como funciona o cancelamento de eco? A maioria dos algoritmos de cancelamento de eco opera gerando múltiplas cópias de um sinal recebido, com cada uma sendo atrasada por um pequeno intervalo. Esse pequeno fluxo é chamado de "tap". O número de taps determina o atraso de eco que pode ser cancelado. Essas cópias são atrasadas, ajustadas e subtraídas do sinal original. O truque é ajustar o sinal atrasado exatamente para o que é necessário para remover o eco.)
- **echocancelwhenbridged**: Ativa ou desativa o cancelador de eco durante uma chamada TDM pura. Isso geralmente não é necessário.
- **rxgain**: Ajusta o ganho de recepção de áudio para aumentar ou diminuir o volume de recepção (-100% a 100%).
- **txgain**: Ajusta o ganho de transmissão de áudio para aumentar ou diminuir o volume de transmissão (-100% a 100%).

Por exemplo:

```
echocancel=yes
echocancelwhenbridged=yes
txgain=-10%
rxgain=10%
```

#### Opções de faturamento

Essas opções alteram como as informações de chamada são registradas no banco de dados de registros detalhados de chamadas (CDR). amaflags: Configura as flags AMA que afetam a categorização do CDR. Ele aceita os seguintes valores:

- billing
- documentation
- omit
- default

accountcode: Configura um código de conta para um canal específico. Pode conter qualquer valor alfanumérico — geralmente o departamento ou nome do usuário.

```
accountcode=finance
amaflags=billing
```

### Opções de progresso de chamada

Esses itens são usados para adquirir informações sobre o progresso da chamada. Em interfaces públicas, pode ser útil detectar o progresso da chamada e determinar se ela foi atendida ou se estava ocupada. A detecção de ocupado é altamente experimental e regulada por parâmetros específicos.

```
busydetect=yes
busycount=4
busypattern=500,500
callprogress=yes
progzone=br
```

Esses parâmetros (acima) especificam se a interface tentará detectar o tom de ocupado, quantos tons serão usados para uma detecção bem-sucedida e qual é o padrão de ocupado. A detecção de ocupado é amplamente experimental, e alguns parâmetros adicionais podem ser alterados no Makefile. Para detectar o atendimento de uma chamada, o que é essencial para um faturamento preciso, é possível usar a inversão de polaridade para sinalizar o tempo exato de atendimento. Isso é importante se você planeja cobrar pela chamada ou apenas deseja ter um faturamento preciso para comparação. Geralmente, você precisa entrar em contato com a companhia telefônica para solicitar esse serviço.

```
answeronpolarityswitch=yes
```

Em alguns países, é possível detectar o desligamento da chamada usando a inversão de polaridade também.

```
hanguponpolarityswitch=yes
```

#### Opções para telefones

Essas opções são usadas para telefones conectados às interfaces FXS. Todas as funcionalidades entregues aos telefones analógicos conectados diretamente às interfaces DAHDI são controladas pelo Asterisk.

- **adsi** (Analog Display Services Interface): Este é um conjunto de padrões de telecomunicações usados por algumas operadoras para oferecer serviços como compra de ingressos.
- **cancallforward**: Ativa ou desativa o encaminhamento de chamadas (*72 para ativar e *73 para desativar).
- **calleridcallwaiting**: Ativa o callerid recebido durante uma indicação de chamada em espera (Yes/No).
- **immediate**: No modo imediato, em vez de fornecer um tom de discagem, o canal pula imediatamente para a extensão "s" no context definido. Isso é usado para criar linhas diretas (hotlines).
- **threewaycalling**: Ativa ou desativa a conferência a três.
- **mailbox**: Avisa o usuário sobre mensagens de correio de voz disponíveis. Pode ser um sinal audível ou um indicador visual (se o telefone suportar esse recurso). O argumento é o número da caixa postal.
- **callgroup**: Agrupa telefones para discar ou para atender.
- **pickupgroup**: Grupo de telefones para captura de chamadas.

### Comandos CLI DAHDI úteis

Uma vez que o Asterisk esteja rodando com os canais DAHDI carregados, você pode inspecionar o status do canal a partir da CLI do Asterisk. Esses comandos permanecem atuais no Asterisk 22:

```
*CLI> dahdi show channels
*CLI> dahdi show channel 1
*CLI> module reload chan_dahdi.so
```

### Formato de canal DAHDI

Canais DAHDI usam o seguinte formato no dialplan:

```
DAHDI/[g]<identifier>[c][r<cadence>]
<identifier> - Physical channel numeric identifier
[g] - Group identifier
[c] - Answer confirmation. A number is not considered until the callee presses "#"
[r] - customized ringing
[cadence] - Integer from 1 to 4
```

Por exemplo:

```
DAHDI/2     - channel 2
DAHDI/g1    - First available channel in group 1
```

## Canais digitais (E1/T1/PRI / TDM)

A partir do Asterisk 22, o DAHDI e a libpri permanecem totalmente suportados, mas os troncos digitais TDM (E1/T1/ISDN PRI) estão sendo cada vez mais substituídos por troncos SIP em novas implementações. Esta seção permanece totalmente aplicável onde a conectividade TDM for necessária; em ambientes novos (greenfield), o trunking SIP (Capítulo 3) geralmente oferece a mesma densidade de canais sem a necessidade de hardware de telefonia.

Canais digitais são extremamente comuns, portanto, você precisará aprender como implementar esses canais se quiser focar em grandes clientes. Quando o número de canais é alto — geralmente mais de 8 — é bastante comum utilizar interfaces digitais como T1/E1/J1. O T1 é muito comum nos EUA, enquanto o E1 é comum na Europa e o J1 no Japão. Esses tipos de canais permitem uma boa densidade de circuitos — 24 por canal T1 e 30 para canais E1.

Na América Latina, China e África, é comum usar um tipo de sinalização associada por canal (CAS) conhecida como MFC/R2. Este capítulo examinará como implementar MFC/R2 usando a biblioteca OpenR2. Nos EUA e na Europa, a sinalização ISDN PRI é a mais comum. O capítulo também discutirá a ISDN Basic Rate Interface (BRI), que é muito comum na Europa em aplicações de médio porte.

Todos os exemplos no livro concentram-se em canais DAHDI. Algumas placas são implementadas usando canais proprietários, portanto, verifique com seu fabricante para obter mais detalhes sobre como configurar sua placa específica.

### Objetivos

Ao final deste capítulo, você será capaz de:

- Reconhecer os principais termos usados na telefonia digital
- Diferenciar sinalização CAS e CCS
- Diferenciar sinalização R2 e ISDN
- Configurar interfaces com sinalização ISDN
- Configurar interfaces com sinalização R2

### Linhas digitais E1/T1

As linhas digitais E1/T1 são uma opção sempre que você precisar implementar um grande número de canais. Um único circuito E1 é capaz de realizar 30 chamadas simultâneas, e você pode ter recursos como DID (Direct Inward Dial), Caller ID (identificação de chamadas) e sinalização avançada. A linha E1/T1 pode chegar à sua empresa de várias maneiras, usando par trançado, fibra e micro-ondas, dependendo do seu país. As linhas digitais são entregues à sua empresa usando UTP, fibra ou micro-ondas. Modems e multiplexadores (MUX) são usados para entregar a linha física. A conexão com uma linha T1 é sempre baseada em um conector RJ45. No entanto, linhas E1 também podem ser provisionadas usando BNC. É muito importante saber o tipo de conector que você receberá com antecedência, principalmente em linhas E1. Geralmente, todo o equipamento até o RJ45 é fornecido pela operadora (TELCO).

![Como os circuitos E1/T1 são provisionados: a operadora pode entregar o tronco via cobre UTP (modem HDSL para E1, ou uma conexão direta de placa para T1), via fibra óptica através de um multiplexador óptico, ou via link de rádio micro-ondas.](../images/10-legacy-fig05.png)

![UTP ou BNC? A maioria das placas digitais usa conectores RJ45 (UTP), mas algumas linhas E1 são entregues em par coaxial BNC duplo, caso em que um balun é necessário para adaptar o par coaxial ao conector RJ45 da placa.](../images/10-legacy-fig06.png)

#### Como a voz é convertida em bits?

O sinal analógico é amostrado 8.000 vezes por segundo para criar uma versão digital da voz analógica. Essa codificação é conhecida como modulação por código de pulso (PCM). Nos EUA e no Japão, o sinal é codificado usando a lei mu (no Asterisk, referida como ulaw). No resto do mundo, a codificação é alaw.

![Modulação por código de pulso (PCM): o sinal de voz analógico de 4 kHz é amostrado 8.000 vezes por segundo (Nyquist) e codificado em um fluxo digital de bits de 64 Kbps.](../images/10-legacy-fig07.png)

#### Multiplexação por Divisão de Tempo

Linhas analógicas fazem sentido quando você precisa de apenas alguns canais. Ao usar multiplexação por divisão de tempo (TDM), é possível agrupar vários canais em uma única conexão de dados. Quando você deseja um grande número de circuitos, a companhia telefônica geralmente fornecerá um tronco digital, que é um circuito de dados no qual a voz é transportada em formato digital usando PCM. Cada intervalo de tempo (timeslot) usa 64 Kbps de largura de banda para transportar um único canal de voz.

![Multiplexação por divisão de tempo em E1 e T1: um quadro E1 transporta 32 intervalos de tempo a 2048 Kbps (DS0 #0 para sincronização de quadro, DS0 #16 para sinalização), enquanto um quadro T1 transporta 24 intervalos de tempo a 1544 Kbps usando um bit para sincronização e um esquema de "bit roubado" para sinalização.](../images/10-legacy-fig08.png)

Nos EUA, o tronco digital mais comum é o T1, que possui 24 linhas disponíveis; na Europa e na América Latina, os troncos E1 possuem 30 linhas. Algumas empresas fornecem um T1/E1 fracionado com menos canais. Sinalização por bit roubado: Às vezes, um tronco T1 usa um esquema de bit roubado onde um bit é tomado emprestado para sinalização. Em troncos T1, o canal de dados/voz é transmitido com 56 Kbps em cada intervalo de tempo. Como você pode observar, quando você usa o bit roubado, o circuito T1 não perde dois slots para sincronização e sinalização.

#### Código de linha T1/E1

T1s e E1s são, na verdade, circuitos de dados e possuem uma codificação de dados que determina a maneira pela qual os bits são interpretados. Para E1s, o código de linha mais comum é HDB3 para a camada 1 e CCS para a camada 2. A maneira mais fácil de saber como seu tronco digital está configurado é perguntar à operadora (TELCO) sobre essas informações. Você precisará dessas informações para configurar o arquivo /etc/dahdi/system.conf.

#### Sinalização T1/E1

É importante entender que as linhas T1/E1 podem ser entregues usando diferentes tipos de sinalização, tais como:

- T1 com sinalização por bit roubado
- T1 com sinalização ISDN
- E1 com MFC/R2 (CAS - Channel Associated Signaling)
- E1 com sinalização ISDN

ISDN é frequentemente usada na Europa e nos EUA. É uma rede de voz digital, padronizada pela União Internacional de Telecomunicações (ITU) em 1984. A ISDN fornece dois tipos de canais:

- Canais portadores (Bearer channels)
  - Voz
  - Dados
- Canais de dados
  - Sinalização fora de banda
  - Sinalização LAPD
  - Q.931

Geralmente, uma linha ISDN é fornecida usando dois meios físicos:

- Basic rate interface (BRI)
  - Conhecida como 2B+D
  - Dois canais portadores (64K) e um canal de dados (16K)
  - Usa um par de fios de cobre com 148Kbps.
- Primary rate interface (PRI)
  - Entregue usando um tronco T1/E1
  - 23B+D para T1s
  - 30B+D para E1s

Às vezes, circuitos E1 usam um esquema de sinalização CAS chamado MFC/R2, que foi definido pela ITU como um padrão conhecido como Q.421/Q441. Isso é frequentemente encontrado na América Latina e na Ásia. Várias empresas de telefonia nesses países usam variantes personalizadas de MFC/R2. Portanto, você precisará saber a variação correta do país para fazê-lo funcionar.

### ISDN BRI

Canais usando sinalização ISDN BRI são muito populares na Europa. A maioria das placas ISDN BRI para Asterisk suporta uma interface S/T com capacidades NT e TE. A conexão TE (terminal) é a usada para conectar à operadora (TELCO) ou a outros PBXs configurados como terminação de rede (NT). O NT é usado para conectar telefones e PBXs configurados como TE. A ISDN BRI fornece dois canais de dados/voz e um canal de sinalização. Placas ISDN BRI estão disponíveis em vários fornecedores de placas de interface para Asterisk.

### Escolhendo uma placa de telefonia para seu servidor Asterisk

Existem vários fabricantes de placas digitais compatíveis com Asterisk. A escolha de uma placa depende de alguns dos seguintes fatores:

#### Barramento de dados

Existem vários tipos de barramento em seu PC. É muito importante que você tenha a placa certa para o seu servidor. A visão geral a seguir descreve as placas usadas com mais frequência:

- PCI 32 Bits 5V encontrado na maioria dos computadores, incluindo desktops
  - Sangoma (anteriormente Digium) TE405, TE407, TE205, TE207, TE120, TE122, B410, TDM2400, TDM800, TDM410 e TC400
  - Sangoma A101, A102 e A104
- PCI 32/64 bits 3.3V, basicamente encontrado em servidores
  - Sangoma (anteriormente Digium) TE410, TE412, TE210, TE212, TE120, TE122, B410, TDM2400, TDM800, TDM410 e TC400
- PCI Express encontrado em desktops e servidores
  - Sangoma (anteriormente Digium) TE420, TE220, TE121, AEX2400 e AEX800
  - Sangoma A101, A102 e A104

Essas famílias de placas originaram-se na Digium, que a Sangoma adquiriu em 2018; elas agora são vendidas e suportadas sob a marca Sangoma. Muitos dos SKUs mais antigos listados aqui foram descontinuados, portanto, confirme a disponibilidade do modelo atual em www.sangoma.com antes de comprar.

- MiniPCI encontrado em sistemas embarcados
  - OpenVOX A100M(FXO), B100M(ISDN BRI), B200M(ISDN BRI) e B400M(ISDN BRI)
- USB 2.0 encontrado na maioria dos PCs modernos. Soluções baseadas em USB permitem uma grande densidade de canais analógicos e digitais. Este barramento suporta 480 Mbps, e cada canal de voz ocupa 64 Kbps. Ao usar hubs USB, é possível obter densidades de até mil portas analógicas em uma única porta.
  - Xorcom Astribank (FXS, FXO, E1-ISDN, E1-R2)
- Ethernet. A maior vantagem da Ethernet é permitir que a placa seja conectada por mais de um servidor. Soluções de alta disponibilidade são geralmente a principal aplicação para esses dispositivos. O ponto forte desta solução é o uso de servidores sem slots PCI livres ou servidores blade.
  - Redfone FoneBridge (até quatro circuitos E1)

### Usando cancelamento de eco por hardware

O cancelamento de eco por hardware reduz a carga na CPU do host. Para placas com mais de uma interface E1, o cancelamento de eco por hardware pode ajudar a aliviar seu processador. Novos canceladores de eco por software aprimorados, como o OSLEC, estão reduzindo a necessidade de um cancelador de eco por hardware. Para escolher entre canceladores de eco por hardware e software, você deve considerar a quantidade de poder de processamento disponível em seu servidor e o número de circuitos E1. Um processo de cancelamento de eco pode usar até nove MIPS (milhões de instruções por segundo) por canal de voz com 128 taps de amplitude usando OSLEC (Referência: Xorcom Ltd.). Se você considerar 1 ciclo de CPU para cada instrução (o que nem sempre é correto com base no processador e na implementação do software em si), estamos falando de 1.080 Ghz para quatro E1s.

#### Tipo de sinalização

Selecionar o tipo de sinalização (por exemplo, T1 CAS, T1 PRI, E1 CAS R2 ou E1 CAS ISDN) não é uma tarefa fácil. Realmente depende do que você tem disponível em sua área e a que preço. A Sinalização por Canal Comum (CCS) é frequentemente melhor do que a sinalização associada por canal (CAS). No entanto, muitas vezes não está disponível. Nos EUA, você geralmente pode escolher, já que a maioria das operadoras oferece T1 CAS para usuários comuns e T1 PRI para usuários avançados (por exemplo, call centers). Na América Latina, o E1 CAS R2 é predominante, mas o ISDN PRI está disponível em algumas cidades.

![A arquitetura de software DAHDI: o Asterisk conversa com o driver de canal `chan_dahdi`, que por sua vez carrega as bibliotecas de protocolo libpri (ISDN), libopenr2 (MFC/R2) e libss7 (SS7); estas ficam sobre a interface `/dev/dahdi`, o driver de kernel DAHDI e o driver de kernel da interface específica da placa.](../images/10-legacy-fig09.png)

Implementar R2 é necessário para instalar uma biblioteca conhecida como OpenR2 (www.libopenr2.org), desenvolvida por Moises Silva, e para aplicar um patch no Asterisk antes da instalação — um procedimento simples mostrado mais adiante neste capítulo. A biblioteca passou por vários testes e está em produção em vários de nossos clientes. ISDN é, na minha opinião, sempre a melhor escolha, se disponível. Alguns provedores podem ter acesso ao sistema de sinalização 7 (SS7), que é uma sinalização CCS disponível entre companhias telefônicas. Soluções proprietárias e de código aberto estão disponíveis para SS7. A biblioteca libss7 é usada para suportar SS7 no Asterisk.

### Configuração de canais de telefonia Asterisk

Configurar uma placa de interface de telefonia envolve várias etapas necessárias. Neste capítulo, mostraremos três dos cenários mais comuns:

- Conexão digital usando ISDN PRI
- Conexão digital usando ISDN BRI
- Conexão digital usando MFC/R2

Existem duas maneiras de configurar canais DAHDI. A primeira é configurá-lo manualmente com controle total de todos os parâmetros. A segunda maneira é usar o utilitário dahdi_genconf para detectar e configurar as placas.

#### Detecção e configuração automática

Graças à equipe de desenvolvimento do DAHDI, agora temos detecção e configuração automática das placas. Passo 1: Para gerar a configuração automaticamente, use o utilitário dahdi_genconf, que detectará a placa e gerará os arquivos /etc/dahdi/system.conf e dahdi-channels.conf.

```
dahdi_genconf
```

Passo 2: Na última linha do arquivo chan_dahdi.conf, inclua o arquivo dahdi-channels.conf

```
#include dahdi_channels.conf
```

Passo 3: Comente todos os módulos não utilizados no arquivo modules ou simplesmente use:

```
dahdi_genconf modules
```

#### Configuração manual

Outra opção é configurar as interfaces manualmente. Abaixo estão alguns exemplos da configuração para canais DAHDI.

##### Exemplo #1 – Dois canais T1/E1 usando ISDN

Etapas necessárias:

1. Instalação da TE205P ou TE210P
2. Configuração do arquivo `/etc/dahdi/system.conf`
3. Carregamento do driver DAHDI
4. Utilitário `dahdi_test`
5. Utilitário `dahdi_cfg`
6. Configuração do arquivo `chan_dahdi.conf`
7. Carregamento e teste do Asterisk

Passo 1: Instalação da TE205P. Antes de instalar a TE205P, é importante entender as diferenças entre as placas TE205P e TE210P. A placa TE210P usa um barramento de 64 bits alimentado por 3,3 volts, encontrado quase apenas nas placas-mãe de servidores. Tenha cuidado se você especificar esta placa de interface; certifique-se de que seu hardware suporte um barramento de 64 bits e 3,3V. A placa TE205P usa um PCI de 5V, que é frequentemente encontrado em computadores desktop. Escolhemos a placa de interface TE205P com dois spans para este exemplo porque é mais fácil reduzi-la para uma placa de um span ou expandi-la para a placa de quatro spans. Essas placas agora são vendidas sob a marca Sangoma (anteriormente Digium).

![Uma placa E1/T1 de span duplo Sangoma/Digium TE205P: as duas portas RJ45 aceitam os troncos digitais, e um jumper na placa (o seletor E1/T1/J1) define o padrão da linha.](../images/10-legacy-fig10.png)

```
Step 2: /etc/dahdi/system.conf configuration file
```

A configuração de placas digitais TDM é um pouco diferente da configuração de suas contrapartes analógicas. Primeiro, precisaremos configurar os spans da placa e depois os canais. Os spans são numerados sequencialmente dependendo da ordem de reconhecimento das placas. Em outras palavras, se você tiver mais de uma placa de interface, é difícil saber a qual delas cada span pertence. Use dahdi_hardware para verificar qual hardware está instalado em cada span. Exemplo #1 (2xT1 PRI)

```
span=1,1,0,esf,b8zs
span=2,0,0,esf,b8zs
bchan=1-23
dchan=24
bchan=25-47
dchan=48
defaultzone=us
loadzone=us
```

Exemplo #2 (2xE1 PRI)

```
span=1,1,0,ccs,hdb3,crc4 # not always necessary, consult Telco.
span=2,0,0,ccs,hdb3,crc4
bchan=1-15, 17-31
dchan=16
bchan=33-47, 49-63
dchan=48
defaultzone=br
loadzone=br
```

Exemplo #3 (4xBRI)

```
loadzone=de
defaultzone=de
span=1,1,0,ccs,ami
bchan=1,2
hardhdlc=3
span=2,0,0,ccs,ami
bchan=4,5
hardhdlc=6
span=3,0,0.ccs.ami
bchan=7,8
hardhdlc=9
span=4,0,0,ccs,ami
bchan=10,11
hardhdlc=12
```

Passo 3: Carregando drivers de kernel. Verifique qual driver você precisa instalar usando dahdi_hardware.

```
dahdi_hardware
pci:0000:04:02.0     wcte2xxp    e159:0001 Sangoma Wildcard TE205P T1/E1 Board
```

Para carregar, use:

```
modprobe dahdi
modprobe wct2xxp
```

Passo 4: Usando dahdi_test, verifique as interrupções perdidas. Você pode verificar o número de interrupções perdidas usando o utilitário dahdi_test compilado com as placas DAHDI. Um número abaixo de 99,987% indica possíveis problemas. Você encontrará o dahdi_test em

```
/usr/sbin.
#./dahdi_test
Opened pseudo zap interface, measuring accuracy...
99.987793% 100.000000% 100.000000% 100.000000% 100.000000% 100.000000%
100.000000%
100.000000% 100.000000% 100.000000% 100.000000% 100.000000% 100.000000%
100.000000% 100.000000%
100.000000% 100.000000% 100.000000% 100.000000% 99.987793% 100.000000%
100.000000% 100.000000%
100.000000% 100.000000% 100.000000%
--- Results after 26 passes ---
Best: 100.000000 -- Worst: 99.987793 -- Average: 99.999061
```

Passo 5: Usando o utilitário dahdi_cfg. Esta é a saída correta do dahdi_cfg para um span E1 fracionado (15 portas) e duas portas FXO.

```
#./dahdi_cfg -vvvv
Dahdi configuration
======================
SPAN 1: CCS/HDB3 Build-out: 0 db (CSU)/0-133 feet (DSX-1)
Channel map:
Channel 01: Clear channel (Default) (Slaves: 01)
Channel 02: Clear channel (Default) (Slaves: 02)
Channel 03: Clear channel (Default) (Slaves: 03)
Channel 04: Clear channel (Default) (Slaves: 04)
Channel 05: Clear channel (Default) (Slaves: 05)
Channel 06: Clear channel (Default) (Slaves: 06)
Channel 07: Clear channel (Default) (Slaves: 07)
Channel 08: Clear channel (Default) (Slaves: 08)
Channel 09: Clear channel (Default) (Slaves: 09)
Channel 10: Clear channel (Default) (Slaves: 10)
Channel 11: Clear channel (Default) (Slaves: 11)
Channel 12: Clear channel (Default) (Slaves: 12)
Channel 13: Clear channel (Default) (Slaves: 13)
Channel 14: Clear channel (Default) (Slaves: 14)
Channel 15: Clear channel (Default) (Slaves: 15)
Channel 16: D-channel (Default) (Slaves: 16)
16 channels configured.
```

Passo 6: Configuração do DAHDI no arquivo /etc/asterisk/chan_dahdi.conf. Exemplo #1 (2xT1)

```
callerid="John Doe"<(555)555-1111>
switchtype=national
signalling =pri_cpe
context=from-pstn
group = 1
channel => 1-23
group =2
channel => 25-47
```

Exemplo #2 (2xE1)

```
callerid="Flavio Eduardo" <4830258580>
switchtype=euroisdn
signalling = pri_cpe
group = 1
channel => 1-15;17-31
group =2
channel => 32-46;48-62
```

Exemplo #3 (4xBRI)

```
signaling=bri_cpe
switchtype=euroisdn
group=1
context=from-pstn
channel=>1,2,4,5,7,8,10,11
```

Use signaling=bri_cpe_ptmp para BRI ponto-a-multiponto. Atualmente, BRI ponto-a-multiponto não é suportado no modo NT.

#### Carregando os drivers de kernel

Após configurar os drivers, você pode simplesmente reiniciar o servidor. Se você instalou o DAHDI com make config, não precisará fazer nada extra. O driver de kernel será carregado e configurado automaticamente. No entanto, às vezes é útil carregar e descarregar os drivers manualmente. Exemplo:

```
modprobe wct11xp
dahdi_cfg -vvvvv
```

O primeiro comando carrega o driver e o segundo, dahdi_cfg, aplica a configuração ao driver de kernel.

### Solução de problemas

Às vezes, as coisas não funcionam na primeira vez. Vamos verificar alguns recursos para solução de problemas do DAHDI. Passo 1: Verifique se a placa está sendo reconhecida pelo sistema operacional. Placas Sangoma/Digium são geralmente reconhecidas como o modem ISDN.

```
lspci -v
00:00.0 Host bridge: Intel Corporation E7230/3000/3010 Memory Controller Hub
00:01.0 PCI bridge: Intel Corporation E7230/3000/3010 PCI Express Root Port
00:1c.0 PCI bridge: Intel Corporation 82801G (ICH7 Family) PCI Express Port 1 (rev 01)
00:1c.4 PCI bridge: Intel Corporation 82801GR/GH/GHM (ICH7 Family) PCI Express Port 5 (rev
01)
00:1c.5 PCI bridge: Intel Corporation 82801GR/GH/GHM (ICH7 Family) PCI Express Port 6 (rev
01)
00:1d.0 USB Controller: Intel Corporation 82801G (ICH7 Family) USB UHCI Controller #1 (rev
01)
00:1d.1 USB Controller: Intel Corporation 82801G (ICH7 Family) USB UHCI Controller #2 (rev
01)
00:1d.2 USB Controller: Intel Corporation 82801G (ICH7 Family) USB UHCI Controller #3 (rev
01)
00:1d.7 USB Controller: Intel Corporation 82801G (ICH7 Family) USB2 EHCI Controller (rev 01)
00:1e.0 PCI bridge: Intel Corporation 82801 PCI Bridge (rev e1)
00:1f.0 ISA bridge: Intel Corporation 82801GB/GR (ICH7 Family) LPC Interface Bridge (rev 01)
00:1f.1 IDE interface: Intel Corporation 82801G (ICH7 Family) IDE Controller (rev 01)
00:1f.2 IDE interface: Intel Corporation 82801GB/GR/GH (ICH7 Family) SATA IDE Controller (rev
01)
00:1f.3 SMBus: Intel Corporation 82801G (ICH7 Family) SMBus Controller (rev 01)
01:00.0 PCI bridge: Intel Corporation 6702PXH PCI Express-to-PCI Bridge A (rev 09)
01:00.1 PIC: Intel Corporation 6700/6702PXH I/OxAPIC Interrupt Controller A (rev 09)
02:08.0 SCSI storage controller: LSI Logic / Symbios Logic SAS1068 PCI-X Fusion-MPT SAS (rev
01)
03:00.0 PCI bridge: Intel Corporation 6702PXH PCI Express-to-PCI Bridge A (rev 09)
04:02.0 Network controller: Tiger Jet Network Inc. Tiger3XX Modem/ISDN interface
05:00.0 Ethernet controller: Broadcom Corporation NetXtreme BCM5721 Gig. Eth.PCI Express (rev
11)
07:00.0 Ethernet controller: Realtek Semiconductor Co., Ltd. RTL-8139/8139C/8139C+ (rev 10)
07:05.0 VGA compatible controller: ATI Technologies Inc ES1000 (rev 02)
```

Passo 2: Verifique se o driver de kernel está carregando corretamente usando:

```
modprobe wct11xp
dmesg
TE110P: Setting up global serial parameters for E1 FALC V1.2
TE110P: Successfully initialized serial bus for card
TE110P: Span configured for CAS/HDB3
Calling startup (flags is 4099)
Found a Wildcard: Sangoma Wildcard TE110P T1/E1
TE110P: Span configured for CCS/HDB3/CRC4
Calling startup (flags is 4099)
dahdi: Registered tone zone 0 (United States / North America)
wcte1xxp: Setting yellow alarm
```

Passo 3: Verifique o status dos alarmes relacionados à camada física da conexão. Para verificar a camada física da conexão E1, você pode usar o seguinte comando da CLI do Asterisk.

```
dahdi show status
```

Os alarmes indicam problemas com a porta: Alarme Vermelho: Não é possível manter a sincronização com o switch remoto. Isso geralmente é um problema físico, como código de linha ou incompatibilidade de enquadramento. Alarme Amarelo: Sinaliza que o switch remoto está em alarme vermelho. Isso indica que o switch remoto não está recebendo suas transmissões. Alarme Azul: Recebe todos os 1s sem enquadramento em todos os intervalos de tempo; o dahdi_tool atualmente não detecta um alarme azul. Loopback: A porta está em loopback local ou remoto.

```
vtsvoffice*CLI> dahdi show status
Description                              Alarms     IRQ        bpviol     CRC4
Sangoma Wildcard E100P E1/PRA Card 0      OK         0          0          0
Wildcard X100P Board 1                   OK         0          0          0
Wildcard X100P Board 2                   RED        0          0          0
```

Passo 4: Para detectar problemas com o DAHDI no servidor Asterisk, primeiro verifique se os canais estão sendo reconhecidos usando:

```
dahdi show channels
pabxip01*CLI> dahdi show channels
   Chan Extension  Context         Language   MOH Interpret
 pseudo            default                    default
      1            from-pstn                  default
      2            from-pstn                  default
      3            from-pstn                  default
      4            from-pstn                  default
      5            from-pstn                  default
      6            from-pstn                  default
      7            from-pstn                  default
      8            from-pstn                  default
      9            from-pstn                  default
     10            from-pstn                  default
     11            from-pstn                  default
     12            from-pstn                  default
     13            from-pstn                  default
     14            from-pstn                  default
     15            from-pstn                  default
     17            from-pstn                  default
     18            from-pstn                  default
     19            from-pstn                  default
     20            from-pstn                  default
     21            from-pstn                  default
     22            from-pstn                  default
     23            from-pstn                  default
     24            from-pstn                  default
     25            from-pstn                  default
     26            from-pstn                  default
     27            from-pstn                  default
     28            from-pstn                  default
     29            from-pstn                  default
     30 2171       from-pstn                  default
     31 2171       from-pstn                  default
```

Passo 5: Verifique o status da camada 3 ISDN, também conhecida como q.931. Você pode verificar se a camada 3 ISDN está ativa usando: `pri show spans` (para listar todos os spans) ou `pri show span <n>` para um span específico:

```
vtsvoffice*CLI> pri show span 1
Primary D-channel: 16
Status: Provisioned, Up, Active
Switchtype: EuroISDN
Type: CPE
Window Length: 0/7
Sentrej: 0
SolicitFbit: 0
Retrans: 0
Busy: 0
Overlap Dial: 0
T200 Timer: 1000
T203 Timer: 10000
T305 Timer: 30000
T308 Timer: 4000
T313 Timer: 4000
N200 Counter: 3
```

Use `pri show spans` (plural) para listar o status de todos os spans PRI configurados de uma só vez.

Verifique um canal específico. dahdi show channel x:

```
vtsvoffice*CLI> dahdi show channel 1
Channel: 1
File Descriptor: 21
Span: 1
Extension:
Dialing: no
Context: entrada
Caller ID: 4832341689
Calling TON: 33
Caller ID name:
Destroy: 0
InAlarm: 0
Signalling Type: PRI Signalling
Radio: 0
Owner: <None>
Real: <None>
Callwait: <None>
Threeway: <None>
Confno: -1
Propagated Conference: -1
Real in conference: 0
DSP: no
Relax DTMF: no
Dialing/CallwaitCAS: 0/0
Default law: alaw
```

debug pri span x: Se depois de tudo você ainda tiver problemas, comece a depurar o span pri. Este comando habilita uma depuração detalhada das chamadas ISDN. É um comando importante quando você acha que algo não está correto. Você pode detectar dígitos sendo discados incorretamente e outros problemas. Abaixo, apresentamos o exemplo de uma saída de depuração para uma chamada bem-sucedida. Consulte este exemplo se precisar comparar uma chamada malsucedida com uma sem problemas. Uma dica é usar core set verbose=0 para receber apenas as mensagens ISDN q.931.

```
-- Making new call for cr 32833
> Protocol Discriminator: Q.931 (8)  len=57
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: SETUP (5)
> [04 03 80 90 a3]
> Bearer Capability (len= 5) [ Ext: 1  Q.931 Std: 0  Info transfer capability: Speech (0)
>                              Ext: 1  Trans mode/rate: 64kbps, circuit-mode (16)
>                              Ext: 1  User information layer 1: A-Law (35)
> [18 03 a9 83 81]
> Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
>                        ChanSel: Reserved
>                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
>                       Ext: 1  Channel: 1 ]
> [28 0e 46 6c 61 76 69 6f 20 45 64 75 61 72 64 6f]
> Display (len=14) @h@>[ Flavio Eduardo ]
> [6c 0c 21 80 34 38 33 30 32 35 38 35 39 30]
> Calling Number (len=14) [ Ext: 0  TON: National Number (2)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1)
>                           Presentation: Presentation permitted, user number not screened
(0) '4830258590' ]
> [70 09 a1 33 32 32 34 38 35 38 30]
> Called Number (len=11) [ Ext: 1  TON: National Number (2)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1) '32248580' ]
> [a1]
> Sending Complete (len= 1)
< Protocol Discriminator: Q.931 (8)  len=10
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: CALL PROCEEDING (2)
< [18 03 a9 83 81]
< Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
<                        ChanSel: Reserved
<                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
<                       Ext: 1  Channel: 1 ]
-- Processing IE 24 (cs0, Channel Identification)
< Protocol Discriminator: Q.931 (8)  len=9
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: ALERTING (1)
< [1e 02 84 88]
< Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Public network serving the remote user (4)
<                               Ext: 1  Progress Description: Inband information or
appropriate pattern now available. (8) ]
-- Processing IE 30 (cs0, Progress Indicator)
< Protocol Discriminator: Q.931 (8)  len=64
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: SETUP (5)
< [04 03 80 90 a3]
< Bearer Capability (len= 5) [ Ext: 1  Q.931 Std: 0  Info transfer capability: Speech (0)
<                              Ext: 1  Trans mode/rate: 64kbps, circuit-mode (16)
<                              Ext: 1  User information layer 1: A-Law (35)
< [18 03 a1 83 82]
< Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Preferred Dchan: 0
<                        ChanSel: Reserved
<                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
<                       Ext: 1  Channel: 2 ]
< [1c 15 91 a1 12 02 01 bc 02 01 0f 30 0a 02 01 01 0a 01 00 a1 02 82 00]
< Facility (len=23, codeset=0) [ 0x91, 0xa1, 0x12, 0x02, 0x01, 0xbc, 0x02, 0x01, 0x0f, '0',
0x0a, 0x02, 0x01, 0x01, 0x0a, 0x01, 0x00, 0xa1, 0x02, 0x82, 0x00 ]
< [1e 02 82 83]
< Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Public network serving the local user (2)
<                               Ext: 1  Progress Description: Calling equipment is non-ISDN.
(3) ]
< [6c 0c 21 83 34 38 33 32 32 34 38 35 38 30]
< Calling Number (len=14) [ Ext: 0  TON: National Number (2)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1)
<                           Presentation: Presentation allowed of network provided number (3)
'4832248580' ]
< [70 05 c1 38 35 38 30]
< Called Number (len= 7) [ Ext: 1  TON: Subscriber Number (4)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1) '8580' ]
< [a1]
< Sending Complete (len= 1)
-- Making new call for cr 5720
-- Processing Q.931 Call Setup
-- Processing IE 4 (cs0, Bearer Capability)
-- Processing IE 24 (cs0, Channel Identification)
-- Processing IE 28 (cs0, Facility)
Handle Q.932 ROSE Invoke component
-- Processing IE 30 (cs0, Progress Indicator)
-- Processing IE 108 (cs0, Calling Party Number)
-- Processing IE 112 (cs0, Called Party Number)
-- Processing IE 161 (cs0, Sending Complete)
> Protocol Discriminator: Q.931 (8)  len=10
> Call Ref: len= 2 (reference 5720/0x1658) (Terminator)
> Message type: CALL PROCEEDING (2)
> [18 03 a9 83 82]
> Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
>                        ChanSel: Reserved
>                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
>                       Ext: 1  Channel: 2 ]
> Protocol Discriminator: Q.931 (8)  len=14
> Call Ref: len= 2 (reference 5720/0x1658) (Terminator)
> Message type: CONNECT (7)
> [18 03 a9 83 82]
> Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
>                        ChanSel: Reserved
>                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
>                       Ext: 1  Channel: 2 ]
> [1e 02 81 82]
> Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Private network serving the local user (1)
>                               Ext: 1  Progress Description: Called equipment is non-ISDN.
(2) ]
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: CONNECT ACKNOWLEDGE (15)
< Protocol Discriminator: Q.931 (8)  len=9
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: PROGRESS (3)
< [1e 02 84 82]
< Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Public network serving the remote user (4)
<                               Ext: 1  Progress Description: Called equipment is non-ISDN.
(2) ]
-- Processing IE 30 (cs0, Progress Indicator)
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: CONNECT (7)
> Protocol Discriminator: Q.931 (8)  len=5
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: CONNECT ACKNOWLEDGE (15)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Active, peerstate Connect Request
> Protocol Discriminator: Q.931 (8)  len=9
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: DISCONNECT (69)
> [08 02 81 90]
> Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Private network
serving the local user (1)
>                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: RELEASE (77)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Null, peerstate Release Request
> Protocol Discriminator: Q.931 (8)  len=9
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: RELEASE COMPLETE (90)
> [08 02 81 90]
> Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Private network
serving the local user (1)
>                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Null, peerstate Null
NEW_HANGUP DEBUG: Destroying the call, ourstate Null, peerstate Null
< Protocol Discriminator: Q.931 (8)  len=9
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: DISCONNECT (69)
< [08 02 82 90]
< Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Public network
serving the local user (2)
<                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
-- Processing IE 8 (cs0, Cause)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Disconnect Indication, peerstate Disconnect
Request
> Protocol Discriminator: Q.931 (8)  len=9
> Call Ref: len= 2 (reference 5720/0x1658) (Terminator)
> Message type: RELEASE (77)
> [08 02 81 90]
> Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Private network
serving the local user (1)
>                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: RELEASE COMPLETE (90)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Null, peerstate Null
NEW_HANGUP DEBUG: Destroying the call, ourstate Null, peerstate Null
```

### Opções de configuração no chan_dahdi.conf

Várias opções estão disponíveis no arquivo chan_dahdi.conf. Uma descrição de todas as opções seria entediante e contraproducente. Aqui, detalharemos os principais grupos de opções disponíveis para fornecer uma melhor compreensão.

#### Opções gerais (independentes de canal)

context: Define o contexto de entrada.

```
context=default
```

channel: Define o canal ou intervalo de canais. Cada definição de canal herdará as opções definidas antes da declaração. Os canais podem ser identificados individualmente ou na mesma linha com separação por vírgula. Intervalos podem ser definidos usando “-”.

```
Channel=>1-15
Channel=>16
Channel=>17,18
```

group: Permite que os canais sejam tratados como um grupo. Se você discar um número de grupo em vez de um número de canal, o primeiro canal disponível será usado. Se os canais forem telefones, quando você chamar um grupo, todos os telefones tocarão simultaneamente. Usando vírgulas, você pode especificar mais de um grupo para o mesmo canal.

```
group=1
group=3,5
```

language: Ativa a internacionalização e configura um idioma. Este recurso configurará as mensagens do sistema para um idioma específico. Inglês é o único idioma com prompts completos disponíveis na instalação padrão. musiconhold: Seleciona a classe de música em espera.

#### Opções ISDN

switchtype: Depende do PBX ou switch usado. Na Europa e na América Latina, o EuroISDN é comum.

- 5ess: Lucent 5ESS
- euroisdn: EuroISDN
- national: National ISDN
- dms100: Nortel DMS100
- 4ess: AT&T 4ESS
- Qsig: Q.SIG

```
switchtype = EuroISDN
```

pridialplan: Necessário para alguns switches que precisam de uma especificação de plano de discagem. Esta opção é ignorada por muitos switches. As opções válidas são private, national, international e unknown.

```
pridialplan = unknown
```

prilocaldialplan: Necessário para alguns switches, geralmente unknown.

```
prilocaldialplan = unknown
```

overlapdial: A discagem por sobreposição (overlap dialing) é usada quando você passa dígitos após a conexão ser estabelecida. Você pode usar o modo de numeração em bloco (overlapdial=no) ou o modo de dígito (overlapdial=yes). O modo de bloco é frequentemente usado por operadoras. signaling: Configura o tipo de sinalização para os canais subsequentes. Esses parâmetros devem corresponder aos do arquivo chan_dahdi.conf. As escolhas corretas baseiam-se no canal disponível. Para ISDN, você pode escolher cinco opções:

- pri_cpe: Usado quando o dispositivo é um CPE, às vezes referido como cliente, usuário ou escravo. Esta é a forma mais simples e usada de sinalização. Às vezes, quando você tenta se conectar a um PBX privado, o PBX também foi configurado como um CPE. Nesse caso, use a sinalização pri_net no Asterisk.
- pri_net: Usado quando o Asterisk está conectado a um PBX privado configurado como um CPE. A sinalização é frequentemente referida como host, mestre ou rede.
- bri_cpe: Usado quando o Asterisk está conectado como um CPE a um tronco ISDN BRI.
- bri_net: Usado quando o Asterisk está conectado a um telefone ISDN ou PBX configurado como um terminal (TE).
- bri_cpe_ptmp: O mesmo que bri_cpe, mas em uma arquitetura ponto-a-multiponto.

#### Opções de CallerID

Muitas opções de Caller ID estão disponíveis. Algumas podem ser desativadas, embora a maioria esteja ativada por padrão. usecallerid: Ativa ou desativa a transmissão do Caller ID para os canais subsequentes (Yes/No). Nota: Se o seu sistema exigir dois toques antes de atender, tente desativar este recurso para que ele atenda imediatamente. hidecallerid: Oculta o Caller ID (Yes/No). calleridcallwaiting: Ativa o recebimento de Caller ID durante uma indicação de chamada em espera (Yes/No). callerid: Configura uma string de Caller ID para um canal específico. O chamador pode ser configurado com “asreceived” em interfaces de tronco para passar o Caller ID adiante.

```
callerid = "Flavio Eduardo Gonçalves" <48 30258500>
```

Nota: A maioria das operadoras (TELCOs) exige que você configure seu Caller ID correto. Se você não passar o Caller ID correto, você não deverá conseguir discar para fora através da operadora. Por outro lado, você poderá receber chamadas mesmo sem configurar o Caller ID.

#### Opções de qualidade de áudio

Essas opções ajustam certos parâmetros do Asterisk que afetam a qualidade do áudio nos canais DAHDI.

- **echocancel**: Desativa ou ativa o cancelamento de eco. Você deve manter este recurso ativado. Ele aceita "yes" ou o número de taps. (Explicação: Como funciona o cancelamento de eco? A maioria dos algoritmos de cancelamento de eco opera gerando múltiplas cópias de um sinal recebido, cada uma sendo atrasada por um pequeno intervalo. Esse pequeno fluxo é chamado de "tap". O número de taps determina o atraso de eco que pode ser cancelado. Essas cópias são atrasadas, ajustadas e subtraídas do sinal original. O truque é ajustar o sinal atrasado exatamente ao que é necessário para remover o eco.)
- **echocancelwhenbridged**: Ativa ou desativa o cancelador de eco durante uma chamada TDM pura. Isso geralmente não é necessário.
- **rxgain**: Ajusta o ganho de recepção de áudio para aumentar ou diminuir o volume de recepção (-100% a 100%).
- **txgain**: Ajusta o ganho de transmissão de áudio para aumentar ou diminuir o volume de transmissão (-100% a 100%).

Exemplo:

```
echocancel=yes
echocancelwhenbridged=yes
txgain=-10%
rxgain=10%
```

#### Opções de faturamento

Essas opções alteram a maneira como as informações de chamada são registradas no banco de dados de registros detalhados de chamadas (CDR). amaflags: Afeta a categorização do CDR. Aceita estes valores:

- billing
- documentation
- omit
- default

accountcode: Configura um código de conta para um canal específico. Pode conter qualquer valor alfanumérico, geralmente o departamento ou nome do usuário.

```
accountcode=finance
amaflags=billing
```

### Configuração MFC/R2

O MFC/R2 é usado em vários países da América Latina, China e África, bem como em alguns países europeus. A ISDN é superior e preferida se disponível em sua área.

#### Entendendo o problema

A placa usada para sinalizar MFC/R2 é a mesma usada para sinalizar ISDN. É possível usar MFC/R2 em canais DAHDI usando a biblioteca chamada libopenR2 (www.libopenr2.com). Esta biblioteca não fazia parte de versões do Asterisk anteriores à 1.6.2.

##### Entendendo o protocolo MFC/R2

O protocolo MFC/R2 combina sinalização dentro da banda (in-band) e fora da banda (out-of-band). A sinalização de endereço é encaminhada dentro da banda usando um conjunto de tons, enquanto as informações do canal são transmitidas sobre o intervalo de tempo 16 como sinalização fora da banda.

**Sinalização de Linha (ITU-T Q.421).** No intervalo de tempo 16, cada canal de voz usa quatro bits ABCD para sinalizar seus estados e controle de chamada. Os bits C e D são raramente usados. Em alguns países, eles podem ser usados para medição (medição por pulso para faturamento). Em uma conversa normal, temos ambos os lados trabalhando: o lado chamador e o lado chamado. A sinalização do lado chamador é referida como sinalização de encaminhamento (forward signaling), enquanto o lado chamado usa sinalização de retorno (backward signaling). Designaremos Af e Bf para sinalização de encaminhamento e Ab e Bb para sinalização de retorno.

| Estado | ABCD encaminhamento | ABCD retorno |
| --- | --- | --- |
| Ocioso/Liberado | 1001 | 1001 |
| Tomada (Seized) | 0001 | 1001 |
| Confirmação de Tomada | 0001 | 1101 |
| Atendido | 0001 | 0101 |
| ClearBack | 0001 | 1101 |
| ClearFwd (antes do clear-back) | 1001 | 0101 |
| ClearFwd (confirmação de desconexão) | 1001 | 1001 |
| Bloqueado | 1001 | 1101 |

O MFC/R2 foi definido pela ITU. Infelizmente, vários países personalizaram o padrão para suas próprias necessidades. Como resultado, surgiram variações nos padrões entre os países.

**Sinais entre registros (ITU-T Q.441).** A sinalização MFC/R2 usa uma combinação de dois tons. As tabelas abaixo mostram o padrão ITU.

Grupo de sinal I (encaminhamento):

| Descrição | Sinal de encaminhamento |
| --- | --- |
| Dígito 1 | I-1 |
| Dígito 2 | I-2 |
| Dígito 3 | I-3 |
| Dígito 4 | I-4 |
| Dígito 5 | I-5 |
| Dígito 6 | I-6 |
| Dígito 7 | I-7 |
| Dígito 8 | I-8 |
| Dígito 9 | I-9 |
| Dígito 0 | I-10 |
| Indicador de código de país, supressor de eco de meia via necessário | I-11 |
| Indicador de código de país, nenhum supressor de eco necessário | I-12 |
| Indicador de chamada de teste | I-13 |
| Indicador de código de país, supressor de eco de meia via inserido | I-14 |
| Não usado | I-15 |

Grupo de sinal II (encaminhamento):

| Descrição | Sinal de encaminhamento |
| --- | --- |
| Assinante sem prioridade | II-1 |
| Assinante com prioridade | II-2 |
| Equipamento de manutenção | II-3 |
| Reserva | II-4 |
| Operador | II-5 |
| Transmissão de dados | II-6 |
| Assinante ou operador sem facilidade de transferência de encaminhamento | II-7 |
| Transmissão de dados | II-8 |
| Assinante com prioridade | II-9 |
| Operador com facilidade de transferência de encaminhamento | II-10 |
| Reserva | II-11 |
| Reserva | II-12 |
| Reserva | II-13 |
| Reserva | II-14 |
| Reserva | II-15 |

Grupo de sinal A (retorno):

| Descrição | Sinal de retorno |
| --- | --- |
| Enviar próximo dígito (n+1) | A-1 |
| Enviar penúltimo dígito (n-1) | A-2 |
| Endereço completo, mudança para recepção de sinais do Grupo B | A-3 |
| Congestionamento na rede nacional | A-4 |
| Enviar categoria da parte chamadora | A-5 |
| Endereço completo, cobrança, estabelecer condições de fala | A-6 |
| Enviar antepenúltimo dígito (n-2) | A-7 |
| Enviar ante-antepenúltimo dígito (n-3) | A-8 |
| Reserva | A-9 |
| Reserva | A-10 |
| Enviar indicador de código de país | A-11 |
| Enviar dígito de idioma ou discriminação | A-12 |
| Enviar natureza do circuito | A-13 |
| Solicitar informações sobre o uso de supressor de eco | A-14 |
| Congestionamento em uma central internacional ou em sua saída | A-15 |

Grupo de sinal B (retorno):

| Descrição | Sinal de retorno |
| --- | --- |
| Reserva | B-1 |
| Enviar tom de informação especial | B-2 |
| Linha do assinante ocupada | B-3 |
| Congestionamento (após mudança do grupo A para B) | B-4 |
| Número não alocado | B-5 |
| Linha do assinante livre, com cobrança | B-6 |
| Linha do assinante livre, sem cobrança | B-7 |
| Linha do assinante fora de serviço | B-8 |
| Reserva | B-9 |
| Reserva | B-10 |
| Reserva | B-11 |
| Reserva | B-12 |
| Reserva | B-13 |
| Reserva | B-14 |
| Reserva | B-15 |

#### Sequência MFC/R2

A sequência a seguir ilustra uma chamada originada de um ramal do Asterisk para um terminal na PSTN. A PSTN derruba a chamada e encerra a comunicação.

![Um fluxo completo de chamada MFC/R2 entre o Asterisk e a operadora: a sinalização de linha (Ocioso, Tomada, Confirmação de Tomada, Atendido, Clearback, Clear Forward) é trocada no intervalo de tempo 16, os dígitos discados e os sinais de retorno "enviar próximo dígito" (grupos I/A/B) viajam dentro da banda, e os tons audíveis chegam ao assinante.](../images/10-legacy-fig11.png)

### Como usar o driver libopenr2

O projeto iniciado por Moises Silva foi inspirado no driver de canal Unicall escrito por Steve Underwood. A biblioteca OpenR2 é atualmente a solução de software mais estável para Asterisk. Com esta solução, podemos usar qualquer placa digital compatível com DAHDI. Anteriormente, apenas soluções proprietárias estavam disponíveis para MFC/R2; uma das melhores que usei é a disponibilizada pela Khomp, www.khomp.com.br. No Asterisk 22, o suporte a MFC/R2 via libopenR2 é integrado quando a biblioteca está presente no momento da compilação — nenhum patch externo é necessário. As etapas abaixo mostram a instalação manual histórica para referência; em sistemas modernos, instale `libopenr2-dev` do gerenciador de pacotes da sua distribuição antes de executar `./configure`, então ative `chan_dahdi` em `make menuselect`.

As etapas abaixo compilam o openr2 e o Asterisk a partir de seus repositórios Git atuais. Elas são mantidas como referência para sites que compilam a partir do código-fonte; em uma distribuição moderna, você geralmente pode ignorá-las inteiramente instalando o pacote `libopenr2-dev` e uma compilação do Asterisk 22 empacotada, já que o `chan_dahdi` compila o suporte a R2 diretamente contra a libopenr2 sem nenhum patch externo.

Passo 1: Instale as ferramentas de compilação necessárias.

```
apt-get install git
```

Passo 2: Clone a biblioteca openr2 e o código-fonte do Asterisk. Nenhuma árvore com patch especial é necessária no Asterisk 22 — um checkout padrão compila o suporte a R2 desde que a libopenr2 esteja presente.

```
cd /usr/src
git clone https://github.com/moises-silva/openr2.git
git clone https://github.com/asterisk/asterisk.git
```

Passo 3: Compile e instale. Por favor, FAÇA BACKUP do seu servidor antes de prosseguir.

```
cd /usr/src/openr2
./configure && make && make install && ldconfig
cd /usr/src/asterisk
./configure && make menuselect && make && make install
```

Nota: Não execute “make samples” para evitar sobrescrever seus arquivos de configuração.

```
Step 4: Changing the file /etc/dahdi/system.conf:
vim /etc/dahdi/system.conf
```

Vamos supor que você tenha uma placa com uma interface E1.

```
span=1,1,0,cas,hdb3
cas=1-15:1101
cas=17-31:1101
dchan=16
loadzone=br
defaultzone=br
```

Passo 5: Execute o comando dahdi_cfg para aplicar as alterações ao driver:

```
dahdi_cfg -vvvvvvvv
Dahdi Version:SVN-branch-1.4-r4348
Echo Canceller: MG2
Configuration
======================
SPAN 1: CAS/HDB3 Build-out: 0 db (CSU)/0-133 feet (DSX-1)
Channel map:
Channel 01: CAS / User (Default) (Slaves: 01)
Channel 02: CAS / User (Default) (Slaves: 02)
Channel 03: CAS / User (Default) (Slaves: 03)
Channel 04: CAS / User (Default) (Slaves: 04)
Channel 05: CAS / User (Default) (Slaves: 05)
Channel 06: CAS / User (Default) (Slaves: 06)
Channel 07: CAS / User (Default) (Slaves: 07)
Channel 08: CAS / User (Default) (Slaves: 08)
Channel 09: CAS / User (Default) (Slaves: 09)
Channel 10: CAS / User (Default) (Slaves: 10)
Channel 11: CAS / User (Default) (Slaves: 11)
Channel 12: CAS / User (Default) (Slaves: 12)
Channel 13: CAS / User (Default) (Slaves: 13)
Channel 14: CAS / User (Default) (Slaves: 14)
Channel 15: CAS / User (Default) (Slaves: 15)
Channel 16: D-channel (Default) (Slaves: 16)
Channel 17: CAS / User (Default) (Slaves: 17)
Channel 18: CAS / User (Default) (Slaves: 18)
Channel 19: CAS / User (Default) (Slaves: 19)
Channel 20: CAS / User (Default) (Slaves: 20)
Channel 21: CAS / User (Default) (Slaves: 21)
Channel 22: CAS / User (Default) (Slaves: 22)
Channel 23: CAS / User (Default) (Slaves: 23)
Channel 24: CAS / User (Default) (Slaves: 24)
Channel 25: CAS / User (Default) (Slaves: 25)
Channel 26: CAS / User (Default) (Slaves: 26)
Channel 27: CAS / User (Default) (Slaves: 27)
Channel 28: CAS / User (Default) (Slaves: 28)
Channel 29: CAS / User (Default) (Slaves: 29)
Channel 30: CAS / User (Default) (Slaves: 30)
Channel 31: CAS / User (Default) (Slaves: 31)
31 channels to configure.
-----------------------------------------------------------------------
```

Passo 5: Altere o arquivo chan_dahdi.conf

```
vim /etc/asterisk/chan_dahdi.conf
[channels]
usecallerid=yes
callwaiting=yes
usecallingpres=yes
callwaitingcallerid=yes
threewaycalling=yes
transfer=yes
canpark=yes
cancallforward=yes
callreturn=yes
echocancel=yes
echotrainning=yes
echocancelwhenbridged=yes
signalling=mfcr2
mfcr2_variant=br
mfcr2_get_ani_first=no
mfcr2_max_ani=20
mfcr2_max_dnis=4
mfcr2_category=national_subscriber
mfcr2_logdir=span1
mfcr2_logging=all
group=1
callgroup=1
pickupgroup=1
callerid=asreceived
context=from-mfcr2
channel => 1-15,17-31
```

Passo 6: Altere o plano de discagem no arquivo extensions.conf

```
vim /etc/asterisk/extensions.conf
[default]
exten => _XXXXXXXX,1,Set(CALLERID(num)=1145678990)
exten => _XXXXXXXX,n,Dial(DAHDI/g1/${EXTEN},60,tT)
```

Nota: Algumas operadoras (TELCOs) não aceitam chamadas sem o Caller ID. Por favor, defina o Caller ID para um dos números DID atribuídos pela operadora. Em alguns países, esta etapa não é necessária. Passo 7: Teste a solução: Agora, com um ramal no contexto from-internal, chame qualquer número e observe o console. Verifique se algum erro está ocorrendo. -- Executing Set("SIP/8564-081ca5d8", "CALLERID(num)=1145678990") in new stack -- Executing Dial("SIP/8564-081ca5d8", "DAHDI/g1/35678899|60|tT") in new stack

#### Depurando o OpenR2

Para detectar erros nas chamadas, você pode ativar a depuração. Para fazer isso, siga as etapas abaixo.

1. Edite o arquivo `chan_dahdi.conf` e adicione as três linhas a seguir à configuração:

```
mfcr2_logdir=span1
mfcr2_logging=all
mfcr2_call_files=yes
```

2. Reinicie o servidor Asterisk
3. Teste a chamada e verifique os arquivos de chamada em `/var/log/asterisk/mfcr2/span1`

Abaixo está um rastreamento para uma chamada normal. Compare-o com o que você recebe em sua chamada.

```
[15:05:47:710] [Thread: 3078019984] [Chan 1] - Call started at Mon Jul  6 15:05:47 2009 on
chan 1
[15:05:47:710] [Thread: 3078019984] [Chan 1] - CAS Tx >> [SEIZE] 0x00
[15:05:47:710] [Thread: 3078019984] [Chan 1] - CAS Raw Tx >> 0x01
[15:05:47:951] [Thread: 3078019984] [Chan 1] - Bits changed from 0x08 to 0x0C
[15:05:47:951] [Thread: 3078019984] [Chan 1] - CAS Rx << [SEIZE ACK] 0x0C
[15:05:47:951] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 2
[15:05:47:951] [Thread: 3078019984] [Chan 1] - timer id 2 found, cancelling it now
[15:05:47:951] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 3
[15:05:47:951] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [ON]
[15:05:48:070] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:070] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:070] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:070] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [OFF]
[15:05:48:150] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:150] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 0
[15:05:48:150] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [ON]
[15:05:48:150] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:250] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:250] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:250] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:250] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [OFF]
[15:05:48:350] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:350] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 2
[15:05:48:350] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [ON]
[15:05:48:350] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:450] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:450] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:450] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:450] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [OFF]
[15:05:48:550] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:550] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 5
[15:05:48:550] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [ON]
[15:05:48:550] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:650] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:650] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:650] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:650] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [OFF]
[15:05:48:750] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:750] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 8
[15:05:48:750] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [ON]
[15:05:48:750] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:850] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:850] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:850] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:850] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [OFF]
[15:05:48:950] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:950] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 5
[15:05:48:950] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [ON]
[15:05:48:950] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:49:050] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:49:050] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:050] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:050] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [OFF]
[15:05:49:150] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:49:150] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 8
[15:05:49:150] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [ON]
[15:05:49:150] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:49:250] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:49:250] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:250] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:250] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [OFF]
[15:05:49:330] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:49:330] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 4
[15:05:49:330] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [ON]
[15:05:49:330] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:49:590] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:49:590] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:590] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:590] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [OFF]
[15:05:49:670] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:49:670] [Thread: 3078019984] [Chan 1] - Sending category National Subscriber
[15:05:49:670] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:49:770] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:49:770] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:770] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:770] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:49:850] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:49:850] [Thread: 3078019984] [Chan 1] - Sending ANI digit 4
[15:05:49:850] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [ON]
[15:05:49:930] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:49:930] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:930] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:930] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [OFF]
[15:05:50:030] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:030] [Thread: 3078019984] [Chan 1] - Sending ANI digit 8
[15:05:50:030] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [ON]
[15:05:50:130] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:130] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:130] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:130] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [OFF]
[15:05:50:230] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:230] [Thread: 3078019984] [Chan 1] - Sending ANI digit 3
[15:05:50:230] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [ON]
[15:05:50:330] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:330] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:330] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:330] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [OFF]
[15:05:50:430] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:430] [Thread: 3078019984] [Chan 1] - Sending ANI digit 0
[15:05:50:430] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [ON]
[15:05:50:530] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:530] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:530] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:530] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [OFF]
[15:05:50:610] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:610] [Thread: 3078019984] [Chan 1] - Sending ANI digit 2
[15:05:50:610] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [ON]
[15:05:50:710] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:710] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:710] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:710] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [OFF]
[15:05:50:810] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:810] [Thread: 3078019984] [Chan 1] - Sending ANI digit 7
[15:05:50:810] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [ON]
[15:05:50:910] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:910] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:910] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:910] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [OFF]
[15:05:51:010] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:010] [Thread: 3078019984] [Chan 1] - Sending ANI digit 2
[15:05:51:010] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [ON]
[15:05:51:110] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:110] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:110] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:110] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [OFF]
[15:05:51:210] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:210] [Thread: 3078019984] [Chan 1] - Sending ANI digit 1
[15:05:51:210] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:51:310] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:310] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:310] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:310] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:51:410] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:410] [Thread: 3078019984] [Chan 1] - Sending ANI digit 7
[15:05:51:410] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [ON]
[15:05:51:510] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:510] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:510] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:510] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [OFF]
[15:05:51:610] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:610] [Thread: 3078019984] [Chan 1] - Sending ANI digit 1
[15:05:51:610] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:51:710] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:710] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:710] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:710] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:51:810] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:810] [Thread: 3078019984] [Chan 1] - Sending more ANI unavailable
[15:05:51:810] [Thread: 3078019984] [Chan 1] - MF Tx >> F [ON]
[15:05:51:990] [Thread: 3078019984] [Chan 1] - MF Rx << 3 [ON]
[15:05:51:990] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:990] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:990] [Thread: 3078019984] [Chan 1] - MF Tx >> F [OFF]
[15:05:52:090] [Thread: 3078019984] [Chan 1] - MF Rx << 3 [OFF]
[15:05:52:090] [Thread: 3078019984] [Chan 1] - Sending category National Subscriber
[15:05:52:090] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:53:350] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:53:350] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:53:350] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:53:350] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:53:430] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:06:03:322] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:06:03:322] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:06:03:322] [Thread: 3078019984] [Chan 1] - CAS Tx >> [CLEAR FORWARD] 0x08
[15:06:03:322] [Thread: 3078019984] [Chan 1] - CAS Raw Tx >> 0x09
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Bits changed from 0x0C to 0x08
[15:06:03:569] [Thread: 3085228944] [Chan 1] - CAS Rx << [IDLE] 0x08
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Call ended
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Attempting to cancel timer timer 0
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Cannot cancel timer 0
```

#### Configuração MFC/R2

As opções estão documentadas dentro do arquivo chan_dahdi.conf. Algumas das opções mais importantes são detalhadas aqui. Parâmetros obrigatórios: mfcr2_variant, mfcr2_max_ani e mfcr2_max_dnis. mfcr2_variant: Variante do país.

```
r2test -l
Variant Code        Country
AR                  Argentina
BR                  Brazil
CN                  China
CZ                  Czech Republic
CO                  Colombia
EC                  Ecuador
ITU                 International Telecommunication Union
MX                  Mexico
PH                  Philippines
VE                  Venezuela
```

mfcr2_max_ani: Quantidade máxima de dígitos ANI a solicitar. mfcr2_max_dnis: Quantidade máxima de dígitos DNIS a solicitar. mfcr2_get_ani_first: Se deve ou não obter ANI antes do DNIS (exigido por algumas operadoras). mfcr2_category: Categoria do chamador. Você pode definir a variável MFCR2_CATEGORY antes de iniciar a chamada. mfcr2_logdir: Diretório para registrar os arquivos de chamada. (/var/log/asterisk/mfcr2/directory) mfcr2_call_files: Se deve ou não registrar as chamadas.

- mfcr2_logging: valores de registro
- cas – bits ABCD para tx e rx
- mf – tons multifrequenciais
- stack – saída detalhada da pilha de canal e contexto
- all – todas as atividades
- nothing – não registrar nada

mfcr2_mfback_timeout: Este valor merece ser mencionado. Às vezes, se você estiver ligando para um celular ou qualquer chamada que leve muito tempo para ser concluída, este parâmetro pode expirar, por isso é frequentemente alterado para ajuste fino. Se algumas de suas chamadas não estiverem sendo concluídas, este é o parâmetro que você deve alterar primeiro. mfcr2_metering_pulse_timeout: Pulsos são usados por algumas variantes R2 para indicar custos. mfcr2_allow_collect_calls: No Brasil, o tom II-8 é usado para indicar uma chamada a cobrar; este parâmetro permite que você bloqueie chamadas a cobrar. mfcr2_double_answer: Também usado para evitar chamadas a cobrar quando uma resposta dupla é necessária. Com double_answer=yes, você bloqueia as chamadas a cobrar. mfcr2_immediate_accept: Permite que você pule o uso de sinais de grupo B/II e vá diretamente para o estado aceito. mfcr2_forced_release: Permite que você acelere a liberação da chamada; funciona para a variante brasileira.

#### ANI e DNIS

A Identificação Automática de Número (ANI) é o número do chamador. O Serviço de Identificação de Número Discado (DNIS) é o número chamado ou, em outras palavras, o número discado. Quando uma chamada é recebida, geralmente os últimos quatro números são passados para o PBX em um processo referido como DID (Direct Inward Dial). O número ANI é, na verdade, o Caller ID. O ANI terá o ramal do chamador ao discar, enquanto o DNIS conterá o destino da chamada. É importante que esses parâmetros sejam configurados corretamente. Alguns switches enviam apenas os últimos quatro dígitos, enquanto outros enviam o número completo.

### Formato de canal DAHDI

Os canais DAHDI usam o seguinte formato no plano de discagem:

```
DAHDI/[g]<identifier>[c][r<cadence>]
<identifier> - Physical channel numeric identifier
[g] - Group identifier
[c] - Answer confirmation. A number is not considered until the callee presses "#"
[r] - customized ringing
[cadence] - Integer from 1 to 4
```

Exemplos:

```
DAHDI/2     - channel 2
DAHDI/g1    - First available channel in group 1
```

## O protocolo IAX2

Neste capítulo, aprenderemos sobre o protocolo Inter-Asterisk eXchange (IAX), incluindo seus pontos fortes e fracos. Detalhes como o modo trunk e a interconexão de dois servidores Asterisk também serão abordados. Todas as referências neste documento correspondem à versão 2 do IAX.

O protocolo IAX fornece transporte de mídia e sinalização para voz e vídeo. O IAX é muito inovador; ele economiza largura de banda no modo trunk e é muito mais simples que o SIP quando você precisa atravessar NAT. O uso principal do IAX hoje em dia é interconectar servidores Asterisk. O IAX foi criado principalmente para voz, mas também pode acomodar vídeo e outros fluxos multimídia.

O IAX foi inspirado em outros protocolos VoIP, como SIP e MGCP. Em vez de usar dois protocolos separados para sinalização e mídia, o IAX os unificou para criar um protocolo único. O IAX não usa RTP para transporte de mídia; em vez disso, ele incorpora a mídia na mesma conexão UDP.

**Status no Asterisk 22.** `chan_iax2` ainda está incluído e totalmente suportado no Asterisk 22 LTS, portanto, tudo nesta seção permanece válido. O IAX2 é, no entanto, um protocolo legado que vê relativamente poucas novas implementações: a indústria convergiu amplamente para o SIP (via `chan_pjsip` no Asterisk 22) tanto para trunking de provedores quanto para interconexão de servidores. A principal vantagem restante do IAX2 é seu design de porta única — toda a sinalização e mídia fluem por uma única porta UDP (4569 por padrão), o que simplifica a configuração de firewall e NAT em comparação com o SIP e seus fluxos RTP separados. Para um novo trunk Asterisk-para-Asterisk onde NAT não é uma preocupação, um trunk PJSIP é a abordagem moderna recomendada; o IAX2 é abordado aqui porque permanece uma escolha válida, especialmente onde apenas uma porta UDP pode ser aberta através de um firewall.

### Objetivos

Ao final deste capítulo, você deverá ser capaz de:

- Identificar os pontos fortes e fracos do protocolo IAX
- Descrever cenários de uso para o protocolo IAX
- Descrever as vantagens do modo trunk do IAX
- Configurar o iax.conf para telefones
- Configurar o iax.conf para conexão com um provedor VoIP
- Configurar o iax.conf para interconexão de Asterisk
- Entender a autenticação IAX

### Design do IAX

Os principais objetivos para o design do IAX são:

- Reduzir a largura de banda necessária para transporte de mídia e sinalização
- Fornecer transparência de NAT
- Ser capaz de transmitir as informações do dialplan
- Suportar o uso eficiente de paging e intercomunicação

O IAX é um protocolo de sinalização e mídia peer-to-peer semelhante ao SIP, sem usar RTP. A abordagem básica é multiplexar os fluxos multimídia sobre uma única conexão UDP entre dois hosts. O maior benefício desta abordagem é sua simplicidade ao atravessar conexões via NAT, comumente encontradas em modems xDSL. O IAX usa uma única porta, UDP 4569 por padrão, e então usa um número de chamada com 15 bits para multiplexar todos os fluxos. O protocolo IAX usa processos de registro e autenticação semelhantes ao protocolo SIP. Uma descrição do protocolo pode ser encontrada em http://www.ietf.org/internet-drafts/draft-guy-iax-05.txt

![O protocolo IAX multiplexa muitas chamadas entre dois endpoints sobre uma única porta UDP (4569 por padrão), usando um número de chamada de 15 bits para manter os fluxos separados — o que torna a travessia de NAT simples.](../images/10-legacy-fig12.png)

### Uso de largura de banda

A largura de banda usada em redes VoIP é afetada por vários fatores; codecs e cabeçalhos de protocolo são os mais importantes. O protocolo IAX tem um recurso surpreendente chamado modo trunk, pelo qual ele multiplexa várias chamadas usando um único cabeçalho. Ao brincar com a calculadora de largura de banda do Asterisk, você verá como os trunks IAX podem economizar até 80% do tráfego com múltiplas chamadas.

![Comparando o overhead de IAX e SIP: duas chamadas SIP/RTP precisam de dois pacotes (40 bytes de payload carregados sob 156 bytes de overhead), enquanto o modo trunk do IAX2 carrega ambas as chamadas em um único pacote (40 bytes de payload sob apenas 66 bytes de overhead) ao compartilhar um cabeçalho IP/UDP entre muitos mini-frames.](../images/10-legacy-fig13.png)

### Nomenclatura de canais

É importante entender as convenções de nomenclatura de canais, pois você usará esses nomes ao especificar um canal no dialplan. O formato de um nome de canal IAX usado para canais de saída é:

```
IAX/[<user>[:<secret>]@]<peer>[:<portno>][/<exten>[@<context>][/<options>]
```

- `<user>` — UserID no peer remoto, ou nome do cliente configurado no iax.conf
- `<secret>` — A senha. Alternativamente, pode ser o nome do arquivo para uma chave RSA sem a extensão final (.key ou .pub) e entre colchetes
- `<peer>` — Nome do servidor para conectar
- `<portno>` — Número da porta para conexão
- `<exten>` — Extension no servidor Asterisk remoto
- `<context>` — Context no servidor Asterisk remoto
- `<options>` — A única opção disponível é 'a', significando 'request autoanswer'

#### Exemplo de canais de saída:

Canais de saída são vistos no console do Asterisk.

- `IAX2/8590:secret@myserver/8590@default` — Chamar a extension 8590 em myserver. Usa 8590:secret como o par nome/senha
- `IAX2/iaxphone` — Chamar "iaxphone"
- `IAX2/judy:[judyrsa]@somewhere.com` — Chamar somewhere.com usando judy como nome de usuário e uma chave RSA para autenticação

#### O formato de um canal IAX de entrada é:

Canais de entrada são vistos no console do Asterisk.

```
IAX2/[<username>@]<host>]-<callno>
```

- `<username>` — Nome de usuário, se conhecido
- `<host>` — Host que está conectando
- `<callno>` — Número da chamada local

Exemplo de canal de entrada:

- `IAX2[flavio@8.8.30.34]/10` — Número de chamada 10 do endereço IP 8.8.30.34 usando flavio como usuário.
- `IAX2[8.8.30.50]/11` — Número de chamada 11 do endereço IP 8.8.30.50.

### Usando IAX

Você pode usar o IAX de várias maneiras. Nesta seção, mostraremos como configurar o IAX para vários cenários, incluindo:

- Conectar um softphone usando IAX
- Conectar IAX a um provedor VoIP usando IAX
- Conectar dois servidores usando IAX
- Conectar dois servidores usando IAX em modo trunk
- Depurar uma conexão IAX
- Usar pares de chaves RSA para autenticação

#### Conectar um softphone usando IAX

O Asterisk suporta telefones IP baseados em IAX, como o ATCOM e o antigo ATA da Digium (chamado IAXy), bem como softphones que ainda implementam o protocolo IAX2. O processo para softphones, ATAs e hard-phones é semelhante. Para configurar um dispositivo IAX, você precisa editar o arquivo iax.conf em /etc/asterisk

```
directory.
```

Usaremos um softphone compatível com IAX2 como exemplo.

1. Faça um backup do arquivo original `iax.conf` usando:

```
#cd /etc/asterisk
#mv iax.conf iax.conf.backup
```

2. Comece a editar um novo arquivo `iax.conf`:

```
[general]
bindport=4569
bindaddr=8.8.1.4
bandwidth=high
```

- ; Parâmetro muito importante, ele altera os codecs disponíveis

```
disallow=all
allow=ulaw
jitterbuffer=no
forcejitterbuffer=no
tos=lowdelay
autokill=yes
[guest]
type=user
context=guest
callerid="Guest IAX User"
; Trust Caller*ID Coming from iaxtel.com
;
[iaxtel]
type=user
context=default
auth=rsa
inkeys=iaxtel
;
; Trust Caller*ID Coming from iax.fwdnet.net
;
[iaxfwd]
type=user
context=default
auth=rsa
inkeys=freeworlddialup
;
; Trust callerid delivered over DUNDi/e164
;
;
;[dundi]
;type=user
;dbsecret=dundi/secret
;context=dundi-e164-local
[2003]
type=friend
context=default
secret=senha
host=dynamic
```

Tentei preservar as linhas padrão (não comentadas) do arquivo de exemplo. Os seguintes parâmetros foram modificados:

```
bandwidth=high
```

Esta linha afeta a seleção de codec. Usar a configuração high permite a seleção de um codec de alta largura de banda e alta qualidade, como o g.711 definido pela palavra-chave ulaw. Se você mantiver o parâmetro padrão, não poderá escolher ulaw. Nesse caso, o Asterisk lhe dará a mensagem “no codec available” para a configuração abaixo.

```
disallow=all
allow=ulaw
```

Nos comandos descritos acima, desativamos todos os codecs e ativamos apenas o ulaw. Em LANs, a maioria das pessoas prefere usar ulaw porque não é intensivo para o processador e economiza ciclos de CPU. Mesmo usando mais largura de banda, este codec é preferível porque em LANs você geralmente tem uma Ethernet de 100 megabits ou até mesmo Gigabit. Uma chamada de voz usando ulaw usa quase 100 kilobits por segundo de largura de banda da sua rede, o que é um uso muito leve para as LANs de alta velocidade de hoje. Em redes WAN ou Internet, você geralmente desativará o ulaw, trocando alguns ciclos de CPU disponíveis por compressão de voz para melhor uso da largura de banda. Os codecs gsm, g729 e ilbc também fornecem um bom fator de compressão.

```
[2003]
type=friend
context=default
secret=senha
host=dynamic
```

Nos comandos acima, definimos um friend chamado [2003]. O context é o default (nos primeiros laboratórios sempre usamos o context default para evitar confusão; este context será totalmente explicado quando abordarmos o dialplan). A linha “host=dynamic” fornece um registro dinâmico do endereço IP do telefone.

3. Baixe e instale um softphone compatível com IAX2. Você pode escolher qualquer softphone que ainda suporte o protocolo IAX2 para o laboratório.
4. Configure uma conta IAX no cliente (normalmente *Add account* → IAX). Observe que o SipPulse Softphone é apenas SIP e não pode registrar via IAX2, portanto, para testes IAX, você precisa de um cliente que ainda suporte o protocolo.

5. Configure o arquivo `extensions.conf` para testar seu dispositivo IAX.

```
[default]
exten=>2000,1,Dial(SIP/2000)
exten=>2001,1,Dial(SIP/2001)
exten=>2003,1,Dial(IAX2/2003)
```

Agora você pode discar entre os telefones SIP criados no Capítulo 3 e o telefone IAX criado no laboratório.

#### Conectar a um provedor VoIP usando IAX

Poucos provedores VoIP suportam IAX. Você pode encontrar facilmente um provedor IAX pesquisando por “IAX providers”. Usar um provedor IAX faz muito sentido, pois o IAX pode economizar muita largura de banda, atravessa facilmente NAT e pode autenticar usando pares de chaves RSA.

![Um Asterisk de cliente conectado a um provedor VoIP via um trunk IAX através da Internet: um único trunk carrega todas as chamadas de e para o provedor.](../images/10-legacy-fig14.png)

O número de provedores VoIP comerciais compatíveis com IAX diminuiu drasticamente ao longo das últimas versões do Asterisk; a maioria dos provedores agora oferece trunks SIP/PJSIP exclusivamente. Antes de se comprometer com um provedor IAX, confirme se eles mantêm ativamente sua infraestrutura IAX. Para uma nova integração de provedor, um trunk PJSIP (Capítulo 3) é a alternativa recomendada.

#### Conectar a um provedor usando IAX

Passo 1: Abra uma conta no seu provedor favorito. Seu provedor fornecerá três coisas.

- Nome
- Secret
- Endereço IP ou nome de Host
- Chave pública RSA

Passo 2: Configure o arquivo iax.conf para registrar seu Asterisk com seu provedor. Adicione as seguintes linhas à seção [general] do arquivo.

```
[general]
register=>name:secret@hostname/2003
```

Nas instruções descritas acima, você se registrou no seu provedor usando sua conta e senha. No momento em que você receber uma chamada, ela será encaminhada para a extension 2003.

```
[name]
```

- ; Seu nome de conta ou número

```
type=peer
secret=secret
; Your password
host=hostname
```

Nas instruções descritas acima, criamos um peer correspondente ao provedor para fins de discagem.

```
[nameiax]
type=user
context=default
auth=rsa
inkeys=hostname
```

Isso é necessário para autenticação RSA. Usar a chave pública do seu provedor permite que você tenha certeza de que a chamada recebida é realmente do provedor verdadeiro. Se qualquer outra pessoa tentar usar o mesmo caminho, ela não conseguirá autenticar porque não possui a chave privada correspondente. Passo 4: Tente a conexão. Para testar a conexão, disque qualquer número. Alguns fornecedores fornecem um teste de eco. Para realizar isso, edite o arquivo extensions.conf.

```
[default]
exten=>*98,1,Dial(IAX2/name:secret@hostname/*98,20,r)
```

Vá para o CLI do Asterisk e emita um reload. Para verificar se o Asterisk está registrado no provedor, use o próximo comando.

```
*CLI>reload
*CLI>iax2 show register
```

Agora simplesmente disque *98 no softphone conectado ao servidor Asterisk.

#### Conectar dois servidores Asterisk através de um trunk IAX

É muito fácil conectar um servidor a outro. Você não precisará registrá-los porque os endereços IP já são conhecidos. Você terá que criar os peers e users no arquivo iax.conf. Todas as extensions no site da Matriz (HQ) começam com 20 seguidas por dois dígitos (por exemplo, 2000). Na Filial (Branch), todas as extensions começam com 22 seguidas por dois dígitos (por exemplo, 2200). Usaremos o trunk. Você precisará de uma fonte de temporização DAHDI para habilitar este recurso. Passo 1: Edite o arquivo iax.conf no servidor da Filial.

![Conectando dois servidores Asterisk com um trunk IAX: o servidor da Matriz (192.168.1.1, extensions 20xx) e o servidor da Filial (192.168.1.2, extensions 22xx) alcançam um ao outro sobre um único trunk IAX — nenhum registro é necessário porque ambos os endereços IP são fixos e conhecidos.](../images/10-legacy-fig15.png)

```
[general]
bindport=4569                   ; bindport and bindaddr may be specified
bindaddr=0.0.0.0                ; more than once to bind to multiple
disallow=all
allow=ulaw
;allow=gsm
[Branch]
type=user
context=default
secret=password
host=192.168.2.10
trunk=yes
notransfer=yes
[HQ]
type=peer
context=default
username=HQ
secret=password
host=192.168.2.10
callerID='HQ'
trunk=yes
notransfer=yes
[2200]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2000'
[2201]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2001'
```

Passo 2: Configure o arquivo extensions.conf no servidor da Filial

```
[general]
static=yes
writeprotect=no
autofallthrough=yes
clearglobalvars=no
priorityjumping=no
[default]
exten=>_20XX,1,dial(IAX2/HQ/${EXTEN},20)
exten=>_20XX,2,hangup
exten=>_22XX,1,dial(IAX2/${EXTEN},20)
exten=>_22XX,2,hangup
```

Passo 3: Configure o arquivo iax.conf no servidor da Matriz

```
[general]
bindaddr=0.0.0.0
bindport=4569
disallow=all
allow=ulaw
allow=gsm
[Branch]
type=peer
context=default
username=Branch
secret=password
host=192.168.2.9
callerid="Branch"
trunk=yes
notransfer=yes
[HQ]
type=user
secret=password
context=default
host=192.168.2.9
callerid="HQ"
trunk=yes
notransfer=yes
[2000]
type=friend
auth=md5
context=default
secret=password
callerid="2200"
host=dynamic
[2001]
type=friend
auth=md5
context=default
secret=password
callerid="2201"
host=dynamic
```

Passo 4: Configure o arquivo extensions.conf no servidor da Matriz.

```
[general]
static=yes
writeprotect=no
autofallthrough=yes
clearglobalvars=no
priorityjumping=no
[default]
exten=>_22XX,1,Dial(IAX2/Branch/${EXTEN})
exten=>_22XX,2,hangup
exten=>_20XX,1,Dial(IAX2/${EXTEN})
exten=>_20XX,2,hangup
```

Passo 5: Teste uma chamada do telefone 2000 no servidor da Matriz para o telefone 2200 no servidor da Filial.

### Autenticação IAX

Agora vamos analisar o processo de autenticação IAX do ponto de vista prático para ajudá-lo a escolher o melhor método para cada requisito específico.

#### Conexões de entrada

![O fluxo de decisão de autenticação IAX para uma chamada de entrada: o Asterisk ramifica dependendo se um nome de usuário é fornecido, se ele corresponde a uma seção, se o IP de origem é permitido e se o secret (texto simples, MD5 ou RSA) corresponde — aceitando a chamada com o context e as opções de peer daquela seção, ou negando-a.](../images/10-legacy-fig16.png)

Quando o Asterisk recebe uma conexão de entrada, as informações iniciais podem incluir um nome de usuário (do campo "username=") ou não. A conexão de entrada também tem um endereço IP, que o Asterisk usa para autenticação também.

Se um usuário for fornecido, o Asterisk:

1. Procura no iax.conf por uma entrada com type=user (ou type=friend com um nome de seção correspondente ao nome de usuário). Se não encontrar, o Asterisk recusa a conexão.
2. Se a entrada encontrada tiver configurações de deny/allow, ele compara o endereço IP do chamador para determinar se aceita a chamada ou não, dependendo das cláusulas deny/allow.
3. Ele verifica a senha (secret) usando texto simples, md5 ou RSA.
4. Ele aceita a conexão e envia a chamada para o context especificado na linha "context=" do arquivo iax.conf.

Se um nome de usuário não for fornecido, o Asterisk:

1. Procura por uma entrada contendo type=user (ou type=friend) no arquivo iax.conf sem um secret especificado. Ele verifica as cláusulas deny/allow também. Se uma entrada for encontrada, a conexão é aceita e o nome da seção é usado como o nome do usuário.
2. Procura por uma entrada contendo type=user (ou type=friend) no arquivo iax.conf com um secret ou chave RSA especificada. Ele verifica as cláusulas deny/allow. Se uma entrada for encontrada, ele tenta autenticar o chamador usando o secret especificado; se corresponder, ele aceita a conexão. O nome da seção é o nome do usuário.

Vamos supor que seu arquivo iax.conf tenha as seguintes entradas:

```
[guest]
type=user
context=guest
[iaxtel]
type=user
context=incoming
auth=rsa
inkeys=iaxtel
[iax-gateway]
type=friend
allow=192.168.0.1
context=incoming
host=192.168.0.1
[iax-friend]
type=user
secret=this_is_secret
auth=md5
context=incoming
```

Se uma chamada tiver um nome de usuário especificado, como:

- guest
- iaxtel
- iax-gateway
- iax-friend

O Asterisk tentará autenticar a chamada usando apenas a entrada correspondente no arquivo iax.conf. Se outros nomes forem especificados, a chamada seria rejeitada. Se nenhum usuário for especificado, o Asterisk tentará autenticar a conexão como guest. No entanto, se guest não existir, ele tentará quaisquer outras conexões com um secret correspondente. Em outras palavras, se você não tiver uma seção guest no seu arquivo iax.conf, um usuário mal-intencionado poderia tentar adivinhar qualquer secret correspondente não especificando o nome de usuário. As restrições de deny/allow de endereços IP também se aplicam. Uma boa maneira de evitar a adivinhação de secret é usar autenticação RSA. Outro método é restringir os endereços IP permitidos a chamar.

#### Restrições de endereço IP

O acesso é controlado com as linhas `permit` e `deny`:

```
permit = <ipaddr>/<netmask>
deny = <ipaddr>/<netmask>
```

As regras são interpretadas em sequência, e todas elas são avaliadas (este conceito é diferente dos ACLs geralmente encontrados em roteadores e firewalls). A última instrução correspondente substitui as anteriores.

Exemplo #1:

```
permit=0.0.0.0/0.0.0.0
deny=192.168.0.0/255.255.255.0
```

Isso negará qualquer pacote da rede 192.168.0.0/24.

Exemplo #2:

```
deny=192.168.0.0/255.255.255.0
permit=0.0.0.0/0.0.0.0
```

Isso permitirá qualquer pacote, porque a última instrução substitui a primeira.

#### Conexões de saída

Conexões de saída adquirem informações de autenticação usando os seguintes métodos:

- A descrição do canal IAX2 passada pela aplicação dial().
- Uma entrada com type=peer ou type=friend no arquivo iax.conf.
- Uma combinação de ambos os métodos.

#### Conectar dois servidores Asterisk usando chaves RSA

É possível usar IAX com autenticação forte usando chaves RSA assimétricas. De acordo com o código-fonte (res_krypto.c), o Asterisk usa chaves RSA com um algoritmo SHA-1 para resumos de mensagens em vez do MD5, que é mais fraco. Abaixo está um guia passo a passo para configurar dois servidores usando chaves RSA.

##### Configurando o servidor para a filial

Passo 1: Gere as chaves RSA no servidor da filial

```
astgenkey -n
```

Quando solicitado, use o nome de chave branch. Usamos o parâmetro –n para evitar passar uma senha sempre que o Asterisk reinicializar. Se você quiser melhorar a segurança, não use o –n e inicie o Asterisk com asterisk -i Passo 2: Copie as chaves para o diretório /var/lib/asterisk/keys

```
cp branch.* /var/lib/asterisk/keys
```

Passo 3: Copie a chave pública para o servidor da Matriz

```
scp branch.pub root@hq_ip_address:/var/lib/asterisk/keys
```

Passo 4: Edite o arquivo iax.conf no servidor da Filial.

```
[general]
bindport=4569                   ; bindport and bindaddr may be specified
bindaddr=0.0.0.0                ; more than once to bind to multiple
disallow=all
allow=ulaw
;Create an entry for the HQ server
[hq]
type=user
context=default
host=192.168.2.10
trunk=yes
notransfer=yes
auth=rsa
inkeys=hq
[2200]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2200'
[2201]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2201'
```

Passo 8: Configure o arquivo extensions.conf no servidor da Filial

```
 [default]
exten=>_20XX,1,dial(IAX2/branch:[branch]@192.168.2.10/${EXTEN},20)
exten=>_20XX,2,hangup
exten=>_22XX,1,dial(IAX2/${EXTEN},20)
exten=>_22XX,2,hangup
```

##### Configurando o servidor para a matriz

Passo 1: Gere as chaves RSA no servidor da Matriz

```
astgenkey -n
```

Quando solicitado, use o nome de chave hq. Passo 2: Copie as chaves para o diretório /var/lib/asterisk/keys

```
cp hq.* /var/lib/asterisk/keys
```

Passo 3: Copie a chave pública para o servidor da FILIAL

```
scp hq.pub root@branch_ip_address:/var/lib/asterisk/keys
```

Passo 4: Configure o arquivo iax.conf no servidor da Matriz

```
[general]
bindaddr=0.0.0.0
bindport=4569
disallow=all
allow=ulaw
allow=gsm
;Configure an entry for the branch server
[branch]
type=user
context=default
host=192.168.2.9
trunk=yes
notransfer=yes
auth=rsa
inkeys=branch
[2000]
type=friend
auth=md5
context=default
secret=password
callerid="2000"
host=dynamic
[2001]
type=friend
auth=md5
context=default
secret=password
callerid="2001"
host=dynamic
```

Passo 10: Configure o arquivo extensions.conf no servidor da Matriz.

```
[default]
exten=>_22XX,1,Dial(IAX2/hq:[hq]@192.168.2.9/${EXTEN})
exten=>_22XX,2,hangup
exten=>_20XX,1,Dial(IAX2/${EXTEN})
exten=>_20XX,2,hangup
```

Passo 11: Teste uma chamada do telefone 2000 no servidor da Matriz para o telefone 2200 no servidor da Filial.

### A configuração do arquivo iax.conf

O arquivo iax.conf tem vários parâmetros; discutir cada parâmetro um por um seria entediante e contraproducente. Todos os parâmetros, juntamente com uma descrição, podem ser encontrados no arquivo de exemplo. Na wiki www.voip-info.org você encontrará informações detalhadas sobre cada um. Aqui mostraremos alguns dos parâmetros mais importantes para a configuração da seção general, peers e users.

#### Seção [General]

Endereços do servidor:

- `bindport = <portnum>` — Configura a porta UDP IAX. O padrão é 4569.
- `bindaddr = <ipaddr>` — Use 0.0.0.0 para vincular o Asterisk a todas as interfaces, ou especifique o endereço IP de uma interface específica.

Seleção de codec:

- `bandwidth = [low|medium|high]` — High = todos os codecs; Medium = todos os codecs exceto ulaw e alaw; Low = codecs de baixa largura de banda.
- `allow/disallow = [alaw|ulaw|gsm|g.729| etc.]` — Ajuste fino da seleção de codec.

### Jitter buffer

Jitter é a variação de atraso entre pacotes. É o fator mais importante que afeta a qualidade da voz. Um Jitter buffer é usado para compensar a variação de atraso. Ele sacrifica a latência em favor de um jitter menor. Você pode fazer uma analogia entre o jitter buffer e um tanque de água. Ambos podem receber pacotes ou água em intervalos irregulares, mas acabarão entregando um fluxo regular.

![O jitter buffer como um tanque de água: os pacotes chegam irregularmente da rede e enchem o buffer, que então os libera a uma taxa constante para produzir um fluxo de voz suave. O tamanho do buffer (em ms) troca um pouco de latência por um jitter menor; a banda de excess-buffer permite que o Asterisk aumente ou diminua o buffer conforme as condições da rede mudam.](../images/10-legacy-fig17.png)

Um jitter pequeno (ou seja, abaixo de 20 ms) é geralmente imperceptível. No entanto, um jitter acima deste nível é irritante. A latência ou atraso deve ser mantido abaixo de 150ms. Criar um jitter buffer sacrificará algum atraso por um jitter menor — um conceito conhecido como “delay-budget”. Você pode afetar o jitter buffer usando estes parâmetros:

- Jitterbuffer=<yes/no> – Ativa ou desativa
- Dropcount=<number> - Quantidade máxima de quadros que devem ser atrasados nos últimos dois segundos. A configuração recomendada é 3 (1,5% de quadros descartados)
- Maxjitterbuffer=<ms> - Geralmente abaixo de 100 ms
- Maxexcessbuffer=<ms> - Se o atraso da rede melhorar, o jitter buffer pode ficar superdimensionado. Consequentemente, o Asterisk tentará reduzi-lo.
- Minexcessbuffer=<ms> - Uma vez que o excess buffer cai para este valor, o Asterisk começa a aumentar o tamanho do buffer.

### Marcação de quadros (Frame tagging)

O parâmetro abaixo marca o pacote IP no campo de tipo de serviço. Os roteadores podem ler esta tag, priorizando assim o tráfego. O Asterisk usa códigos DSCP para este campo (RFC 2474). Os valores permitidos são CS0, CS1, CS2, CS3, CS4, CS5, CS6, CS7, AF11, AF12, AF13, AF21, AF22, AF23, AF31, AF32, AF33, AF41, AF42, AF43 e ef (ou seja, expedited forwarding).

```
tos=ef
```

### Criptografia IAX2

O IAX suporta criptografia de chamadas usando uma chave simétrica, cifra de bloco de 128 bits chamada AES (Advanced Encryption Standard). É muito simples ativar a criptografia entre trunks IAX. No arquivo iax.conf use:

```
encryption=yes
```

Para forçar a criptografia:

```
forceencryption=yes
```

Para garantir a compatibilidade com versões mais antigas, você pode precisar desativar a rotação de chaves usando:

```
keyrotate=no
```

### Comandos de depuração IAX2

Abaixo estão alguns dos comandos de console de solução de problemas mais importantes para o Asterisk.

```
iax2 show netstats
vtsvoffice*CLI> iax2 show netstats
                        -------- LOCAL ---------------------  -------- REMOTE ---------------
-----
Channel           RTT  Jit  Del  Lost   %  Drop  OOO  Kpkts  Jit  Del  Lost   %  Drop  OOO
Kpkts
IAX2/8590-1        16   -1    0    -1  -1     0   -1      1   60  110     3   0     0    0
0
iax2 show channels
vtsvoffice*CLI> iax2 show channels
Channel       Peer             Username    ID (Lo/Rem)  Seq (Tx/Rx)  Lag      Jitter  JitBuf
Format
IAX2/8590-2   8.8.30.43        8590        00002/26968  00004/00003  00000ms  -0001ms  0000ms
unknow
iax2 show peers
vtsvoffice*CLI> iax2 show peers
Name/Username    Host                 Mask             Port          Status
8584             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8564             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8576             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8572             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8571             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8585             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8589             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8590             8.8.30.43       (D)  255.255.255.255  4569          OK (16 ms)
3232             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
9 iax2 peers [1 online, 8 offline, 0 unmonitored]
iax2 debug
```

Olhando para esta saída, identifique o início e o fim da chamada. Observe as informações de atraso e jitter obtidas usando pacotes poke e pong. Esses pacotes ajudam a criar a saída do comando “iax2 show netstats”.

```
vtsvoffice*CLI> iax2 debug
IAX2 Debugging Enabled
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: REGREQ
   Timestamp: 00003ms  SCall: 26975  DCall: 00000 [8.8.30.43:4569]
   USERNAME        : 8590
   REFRESH         : 60
Tx-Frame Retry[000] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: REGAUTH
   Timestamp: 00009ms  SCall: 00003  DCall: 26975 [8.8.30.43:4569]
   AUTHMETHODS     : 2
   CHALLENGE       : 137472844
   USERNAME        : 8590
Rx-Frame Retry[ No] -- OSeqno: 001 ISeqno: 001 Type: IAX     Subclass: REGREQ
   Timestamp: 00016ms  SCall: 26975  DCall: 00003 [8.8.30.43:4569]
   USERNAME        : 8590
   REFRESH         : 60
   MD5 RESULT      : f772b6512e77fa4a44c2f74ef709e873
Tx-Frame Retry[000] -- OSeqno: 001 ISeqno: 002 Type: IAX     Subclass: REGACK
   Timestamp: 00025ms  SCall: 00003  DCall: 26975 [8.8.30.43:4569]
   USERNAME        : 8590
   DATE TIME       : 2006-04-17  16:03:00
   REFRESH         : 60
   APPARENT ADDRES : IPV4 8.8.30.43:4569
   CALLING NUMBER  : 4830258590
   CALLING NAME    : Flavio
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 002 Type: IAX     Subclass: ACK
   Timestamp: 00025ms  SCall: 26975  DCall: 00003 [8.8.30.43:4569]
Tx-Frame Retry[000] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: POKE
   Timestamp: 00003ms  SCall: 00006  DCall: 00000 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: ACK
   Timestamp: 00003ms  SCall: 26976  DCall: 00006 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: PONG
   Timestamp: 00003ms  SCall: 26976  DCall: 00006 [8.8.30.43:4569]
   RR_JITTER       : 0
   RR_LOSS         : 0
   RR_PKTS         : 1
   RR_DELAY        : 40
   RR_DROPPED      : 0
   RR_OUTOFORDER   : 0
Tx-Frame Retry[-01] -- OSeqno: 001 ISeqno: 001 Type: IAX     Subclass: ACK
   Timestamp: 00003ms  SCall: 00006  DCall: 26976 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: NEW
   Timestamp: 00003ms  SCall: 26977  DCall: 00000 [8.8.30.43:4569]
   VERSION         : 2
   CALLING NUMBER  : 8590
   CALLING NAME    : 4830258590
   FORMAT          : 2
   CAPABILITY      : 1550
   USERNAME        : 8590
   CALLED NUMBER   : 8580
   DNID            : 8580
Tx-Frame Retry[000] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: AUTHREQ
   Timestamp: 00007ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
   AUTHMETHODS     : 2
   CHALLENGE       : 190271661
   USERNAME        : 8590
Rx-Frame Retry[Yes] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: NEW
   Timestamp: 00003ms  SCall: 26977  DCall: 00000 [8.8.30.43:4569]
   VERSION         : 2
   CALLING NUMBER  : 8590
   CALLING NAME    : 4830258590
   FORMAT          : 2
   CAPABILITY      : 1550
   USERNAME        : 8590
   CALLED NUMBER   : 8580
   DNID            : 8580
Tx-Frame Retry[-01] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: ACK
   Timestamp: 00003ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 001 ISeqno: 001 Type: IAX     Subclass: AUTHREP
   Timestamp: 00063ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
   MD5 RESULT      : 57cc5c48affba14106c29439944413a1
Tx-Frame Retry[000] -- OSeqno: 001 ISeqno: 002 Type: IAX     Subclass: ACCEPT
   Timestamp: 00054ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
   FORMAT          : 1024
Tx-Frame Retry[000] -- OSeqno: 002 ISeqno: 002 Type: CONTROL Subclass: ANSWER
   Timestamp: 00057ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Tx-Frame Retry[000] -- OSeqno: 003 ISeqno: 002 Type: VOICE   Subclass: 138
   Timestamp: 00090ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 002 Type: IAX     Subclass: ACK
   Timestamp: 00054ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 003 Type: IAX     Subclass: ACK
   Timestamp: 00057ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 004 Type: IAX     Subclass: ACK
   Timestamp: 00090ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 004 Type: VOICE   Subclass: 138
   Timestamp: 00210ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Tx-Frame Retry[-01] -- OSeqno: 004 ISeqno: 003 Type: IAX     Subclass: ACK
   Timestamp: 00210ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 003 ISeqno: 004 Type: IAX     Subclass: PING
   Timestamp: 02083ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Tx-Frame Retry[000] -- OSeqno: 004 ISeqno: 004 Type: IAX     Subclass: PONG
   Timestamp: 02083ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
   RR_JITTER       : 0
   RR_LOSS         : 0
   RR_PKTS         : 1
   RR_DELAY        : 40
   RR_DROPPED      : 0
   RR_OUTOFORDER   : 0
Rx-Frame Retry[ No] -- OSeqno: 004 ISeqno: 005 Type: IAX     Subclass: ACK
   Timestamp: 02083ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 004 ISeqno: 005 Type: IAX     Subclass: HANGUP
   Timestamp: 08693ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
   CAUSE           : Dumped Call
```

Para desativar a depuração, use:

```
vtsvoffice*CLI>iax2 no debug
```

### Resumo

Este capítulo revisou os pontos fortes e fracos do protocolo IAX. Demonstrou como o IAX funciona em vários cenários, como softphones e um trunk entre dois servidores Asterisk. O modo trunk permite economizar largura de banda carregando mais de uma chamada em um único pacote. Finalmente, você aprendeu comandos de console que pode usar para verificar o status e depurar o protocolo.

## Legacy SIP: chan_sip e sip.conf (removido no Asterisk 21+)

> **Legado / histórico:** Tudo nesta seção utiliza o antigo driver `chan_sip` e seu arquivo de configuração `sip.conf`. O `chan_sip` foi descontinuado por várias versões e **removido no Asterisk 21**, portanto, ele **não existe no Asterisk 22**. Nenhum dos exemplos de `sip.conf` abaixo funcionará em um sistema atual — eles são mantidos aqui apenas para documentar como as implementações legadas funcionavam e para ajudá-lo a migrá-las. Para a forma moderna e suportada de fazer qualquer uma dessas coisas, consulte a seção *PJSIP: the SIP channel* do capítulo *SIP & PJSIP in depth*. A teoria do *protocolo* SIP (métodos, registro, proxy/redirect, SDP, tipos de NAT) é de nível de protocolo e reside naquele capítulo; o que se segue é puramente a **configuração** do `chan_sip` removido.

Em sistemas legados até o Asterisk 20, o SIP era configurado no `/etc/asterisk/sip.conf`, que costumava ser o segundo arquivo mais alterado (logo após o `extensions.conf`). As seções abaixo mostram como o `chan_sip` conectava o Asterisk a um provedor SIP, como conectar dois Asterisks usando SIP, suporte a domínio, presença, opções de codec/DTMF/QoS, autenticação e NAT — seguido por um guia para migrar tudo isso para PJSIP.

### Conectando o Asterisk a um provedor SIP (sip.conf)

O Asterisk é frequentemente usado para se conectar a um provedor VoIP SIP. Provedores VoIP geralmente possuem tarifas melhores para chamadas telefônicas do que provedores tradicionais. Outro ponto interessante e atraente dos provedores VoIP é a possibilidade de comprar números DID em outras cidades — até mesmo em países estrangeiros. Estas são boas razões para usar VoIP para telecomunicações. Nesta seção, você aprenderá como o `chan_sip` legado conectava o Asterisk a um provedor VoIP. Três etapas são necessárias para conectar o Asterisk a um provedor SIP. Testes podem ser conduzidos estabelecendo uma conta com seu provedor favorito. Passo 1: Registrando-se em um provedor SIP no sip.conf Para conectar-se a um provedor SIP, você precisará das seguintes informações do provedor:

![Asterisk conectado a um provedor de serviço VoIP via Internet ou WAN privada, com telefones SIP locais registrados no servidor Asterisk](../images/07-sip-and-pjsip-fig07.png)

- nome de usuário (username)
- segredo (secret) e segredo remoto (remotesecret) (Use secret para autenticar solicitações de entrada e remotesecret para solicitações de saída)
- nome do host (hostname)
- domínio (domain)
- codecs permitidos

Esta configuração permitirá que seu provedor localize o endereço IP do Asterisk. Na instrução a seguir, estamos dizendo ao Asterisk para se registrar em um provedor SIP definido pelo hostname e informar ao provedor o endereço IP do Asterisk. A instrução diz que você deseja receber chamadas na extension 4100. Na seção [general] do arquivo sip.conf, insira a seguinte linha:

```
register=>name:secret@hostname/4100
```

Passo 2: Configure o [peer] no sip.conf Crie uma entrada do tipo peer para o provedor desejado para simplificar a discagem do Asterisk.

```
[provider]
context=incoming
type=friend
dtmfmode=rfc2833
directmedia=no
username=username
remotesecret=secret
host=hostname
fromuser=username
fromdomain=domain
insecure=invite
disallow=all
allow=ulaw ; or any other codec available from your provider
```

Passo 3: Crie uma rota para o provedor no dialplan Escolheremos os dígitos 010 como a rota de destino para o provedor. Para discar #610000 dentro do provedor, simplesmente disque 010610000.

```
exten=>_010.,1,Set(CALLERID(num)=username)
exten=>_010.,n,Set(CALLERID(Name)="Flavio Gonçalves")
exten=>_010.,n,Dial(SIP/${EXTEN:3}@provider)
exten=>_010.,n,Hangup
```

#### Opções SIP específicas para o cenário de provedor

A discussão a seguir examina os detalhes das opções definidas no arquivo sip.conf para conexão com um provedor VoIP.

```
register=>username:password@hostname/4100
```

A instrução register no arquivo sip.conf é usada para registrar-se em um provedor. A transação de registro é autenticada com o nome e o segredo. Você pode usar uma barra (“/”) para fornecer uma extension para chamadas recebidas. Tecnicamente falando, a extension será colocada no campo de cabeçalho “Contact” da solicitação SIP. O comportamento de registro pode ser controlado por certos parâmetros:

```
registertimeout=20
registerattempts=10
```

Para verificar se o registro foi bem-sucedido, o comando de console legado era `sip show registry`. No Asterisk 22, o comando equivalente é `pjsip show registrations` (registros de saída) e `pjsip show endpoints` para status de endpoint.

O parâmetro “username” é usado no digest de autenticação. O digest é calculado usando username, secret e realm:

```
username=username
```

Host define o endereço ou nome do provedor VoIP:

```
host=hostname
```

Os parâmetros Fromuser e Fromdomain são às vezes necessários para autenticação. Esses parâmetros são usados no campo de cabeçalho SIP From:

```
fromuser=username
fromdomain=hostname
```

Quando você se conecta a um provedor VoIP, credenciais são necessárias. Após o convite inicial, o provedor envia uma mensagem chamada “407 Proxy Authentication Required”; você fornece as credenciais na mensagem INVITE subsequente. Para chamadas recebidas, seu servidor Asterisk solicitará credenciais para o provedor. Obviamente, o provedor não possui uma credencial válida para seu servidor Asterisk. Quando você usa insecure=invite, você está dizendo ao Asterisk para não enviar o “407 Proxy Authentication Required” para o provedor e aceitar chamadas recebidas. Você também pode usar insecure=port, invite para corresponder ao peer com base no endereço IP sem corresponder ao número da porta.

```
insecure=invite, port
```

### Conectando dois servidores Asterisk usando SIP (sip.conf)

Você pode usar SIP para interconectar duas caixas Asterisk. É importante prestar atenção ao dialplan antes de prosseguir com esta configuração. Os usuários geralmente desejam conectar outros PBXs com o mínimo de esforço. A ideia aqui é usar um número de extension apenas para conectar ao outro PBX. Passo 1: Edite o arquivo sip.conf no servidor A:

```
[B]
type=user
secret=B
host=A
disallow=all
allow=ulaw
directmedia=no
[B-out]
type=peer
fromuser=A
username=A
remotesecret=A
host=B
disallow=all
allow=ulaw
directmedia=no
```

Passo 2: Edite o arquivo sip.conf no servidor B:

```
[A]
type=user
host=B
secret=A
disallow=all
allow=ulaw
directmedia=no
[A-out]
```

![Conectando dois servidores Asterisk usando SIP: servidor A (extensions 4400/4401) e servidor B (extensions 4500/4501) trocam sinalização SIP para que usuários em cada PBX possam discar para o outro](../images/07-sip-and-pjsip-fig08.png)

```
type=peer
host=A
fromuser=B
username=B
remotesecret=B
disallow=all
allow=ulaw
directmedia=no
```

Passo 3: Edite o arquivo extensions.conf no servidor A:

```
[default]
exten=_44XX,1,dial(SIP/${EXTEN},20)
exten=_44XX,2,hangup()
exten=_45XX,1,dial(SIP/B-out/${EXTEN})
exten=_45XX,2,hangup()
```

Passo 4: Edite o arquivo extensions.conf no servidor B:

```
[default]
exten=_44XX,1,dial(SIP/A-out/${EXTEN})
exten=_44XX,2,hangup()
exten=_45XX,1,dial(SIP/${EXTEN})
exten=_45XX,2,hangup()
```

### Suporte a domínio no Asterisk (sip.conf)

O protocolo SIP segue a arquitetura da Internet. A primeira coisa a fazer antes de configurar o SIP é definir corretamente os servidores DNS. Em um ambiente SIP, você pode chamar um usuário localizado em qualquer proxy SIP, e outros usuários também podem chamá-lo usando seu Identificador de Recurso Uniforme (URI) SIP. Para definir um servidor DNS para SIP, você deve adicionar registros SRV ao seu servidor DNS.

```
; SIP server/proxy and its backup server/proxy
sip1.yourdomain.com
21600 IN A
200.180.4.169
sip2.yourdomain.com
21600 IN A
200.175.61.150
;
; DNS SRV records for SIP
_sip._udp.yourdomain.com  21600 IN SRV 10 0 5060 sip1.voip.school.
_sip._udp.yourdomain.com  21600 IN SRV 20 0 5060 sip2.voip.school.
```

Após configurar o DNS, você pode usar o URI, que aponta para um usuário SIP, telefone SIP ou extension telefônica. Um URI SIP parece um endereço de e-mail (por exemplo, sip:chuck@yourpartnerdomain.com). Usando URIs SIP, nenhum número de telefone é necessário para fazer uma chamada de um telefone SIP para outro. Para discar para um usuário externo, simplesmente use uma instrução como a mostrada abaixo.

```
exten=4000,1,dial(SIP/chuck@yourpartnerdomain.com)
```

Certos parâmetros podem controlar o comportamento do domínio.

```
srvlookup=yes
```

Este parâmetro habilita consultas DNS SRV em chamadas de saída. Usando este parâmetro, é possível discar chamadas usando nomes SIP baseados em domínio.

```
allowguest=yes
```

Este parâmetro permite que um convite externo seja processado sem autenticação. Ele processa a chamada dentro do context definido na seção general ou na instrução domain. Aviso: Se você definir um context na seção general com acesso à PSTN, um usuário externo pode discar para a PSTN através do seu PBX. Nesse caso, você incorrerá em quaisquer cobranças. Permita apenas suas próprias extensions no context definido na seção general.

![Conectando a outros servidores SIP por domínio: youdomain.com e yourpartnerdomain.com trocam sinalização SIP, para que usuários como lee e bruce possam chamar chuck e norris usando URIs SIP](../images/07-sip-and-pjsip-fig09.png)

```
domain=acme.com,default
```

O comando domain permite que você gerencie mais de um domínio dentro do Asterisk. Se uma chamada vier de um domínio específico, ela é direcionada para um context específico.

```
;autodomain=yes
```

Este parâmetro inclui o IP local e o hostname nos domínios permitidos.

```
;allowexternaldomains=no
```

O padrão é yes. Remova o comentário da linha para não permitir chamadas para domínios externos.

### Configurações avançadas de SIP (sip.conf)

Esta seção explica alguns parâmetros avançados do canal SIP legado, como presença, seleção de codec, opções de DTMF e marcação de pacotes QoS. Os **conceitos** (BLF/presença, negociação de codec, modos DTMF, marcação DSCP) são transferidos para o PJSIP, mas os nomes de parâmetros `sip.conf` mostrados aqui **não** existem no Asterisk 22. No PJSIP, o modo DTMF é `dtmf_mode=` em um endpoint, e os codecs são definidos com `allow=`/`disallow=`.

#### Presença SIP

A presença SIP é parcialmente implementada no Asterisk. O Asterisk suporta solicitações como SUBSCRIBE e NOTIFY para usuários, dependendo do estado de um canal. O Asterisk não suporta o método SIP PUBLISH. Em outras palavras, você pode se inscrever nos estados (ocupado, ocioso e tocando) de um canal, mas não pode publicar informações como “ausente” ou “não perturbe”. O cenário mais comum para presença é o busy lamp field (BLF), no qual você simula o comportamento de um sistema KS com lâmpadas para cada extension e trunk. Parâmetros SIP para presença:

- allowsubscribe=yes: Permitir métodos de inscrição SIP
- subscribecontext=sip_subscribers: Context onde procurar por hints
- notifyring=yes: Enviar SIP NOTIFY ao tocar
- notifyhold=yes: Enviar SIP NOTIFY ao colocar em espera
- counteronpeer (renomeado de limitonpeer para Asterisk 1.4.x): Aplicar o contador apenas no lado do peer
- callcounter=yes: Habilitar contadores de chamadas no dispositivo.
- busylevel=1: Limite para o número de chamadas para considerar o dispositivo como ocupado.

Por exemplo: Passo 1: Testar a presença SIP com o Asterisk não é tão difícil. Primeiro, vamos configurar os arquivos sip.conf e extensions.conf.

No arquivo sip.conf

```
[general]
bindaddr=0.0.0.0
bindport=5060
disallow=all
allow=ulaw
allowsubscribe=yes
notifyringing=yes
notifyhold=yes
limitonpeer=yes
counteronpeer=yes
subscribecontext=default
[2000]
type=friend
host=dynamic
context=default
dtmfmode=rfc2833
secret=senha
callcounter=yes
busylevel=1
[2001]
type=friend
host=dynamic
context=default
dtmfmode=rfc2833
secret=senha
callcounter=yes
busylevel=1
In the file extensions.conf
[default]
exten=2000,hint,SIP/2000
exten=2001,hint,SIP/2001
exten=_20XX,1,dial(SIP/${EXTEN})
exten=_20XX,n,Hangup()
```

Passo 2: Agora configure o softphone para usar presença. Mostraremos como configurar o SipPulse Softphone.

- Sequência: clique com o botão direito->SIP Account Settings->Properties->Presence
- Altere o modelo de presença de peer-to-peer para presence agent, o que fará com que o softphone inscreva o Asterisk para eventos SIP.

Passo 3: Adicione o contato a outros softphones. Neste exemplo, o SipPulse Softphone é a conta 2000, então adicionaremos um contato para a conta 2001. Sequência: Abra o painel direito (painel de presença no softphone)->Clique em Contacts->Add a contact. Preencha o nome 2001. Exiba como 2001 e não se esqueça de marcar a caixa Show this contact’s availability.

Passo 4: Agora chame a extension 2001 e verifique o status do telefone no painel direito do softphone. Use o comando de console `core show hints` para ver o status de presença mudando no servidor (no chan_sip legado, `sip show inuse` mostrava quantas chamadas você tinha em cada linha). No Asterisk 22, use `pjsip show endpoints` para inspecionar o estado do endpoint e do canal. O status de presença/BLF aparece nos contatos ou no painel BLF do softphone — exatamente como ele é mostrado depende do cliente.

#### Configuração de codec

A configuração de codec é simples e direta. Você pode definir as palavras allow e disallow na seção [general] ou na seção peer/user. A melhor prática é padronizar o codec para evitar transcodificação, que consome muito processador. Por favor, use o mesmo codec para mensagens e prompts.

```
[general]
disallow=all
allow=g729
```

#### Opções de DTMF

Em certas ocasiões, você passará dígitos para uma aplicação como voicemail ou resposta interativa de voz (IVR). É importante passar o DTMF corretamente. O método mais simples para passar DTMF é chamado inband. Ele é definido na seção [general] ou peer/user do arquivo sip.conf. Quando você define dtmfmode=inband, os tons DTMF são gerados como sons no canal de áudio. O principal problema com este método é que, quando você comprime o canal de áudio usando um codec como g729, os sons são distorcidos e os tons DTMF não são reconhecidos corretamente. Se você planeja usar dtmfmode=inband, use o codec g.711 (ulaw e alaw).

```
dtmfmode=inband
```

Outra abordagem é usar RFC2833, que permite que você passe tons DTMF como eventos nomeados nos pacotes RTP.

```
dtmfmode=rfc2833
```

Finalmente, você pode passar dígitos DTMF dentro de pacotes SIP, em vez de pacotes RTP. Este método é definido na RFC3265 (eventos de sinalização) e RFC2976.

```
dtmfmode=info
```

Após o lançamento da versão 1.2, agora é possível usar:

```
dtmfmode=auto
```

Isso tenta usar o RFC2833; se não for possível, usa tons de banda.

#### Configuração de marcação de qualidade de serviço (QoS)

QoS é um conjunto de técnicas responsáveis pela qualidade de voz. O QoS é implementado de forma a reduzir largura de banda, latência e jitter. As principais funções de QoS são agendamento de pacotes, fragmentação e compressão de cabeçalho. O QoS é implementado em switches e roteadores, não pelo próprio Asterisk. No entanto, o Asterisk pode ajudar roteadores e switches marcando pacotes para entrega expressa. A marcação é feita usando pontos de código de serviços diferenciados (DSCP) definidos nas RFCs 2474 e RFC2475.

```
tos_sip=cs3
tos_audio=ef
tos_video=af41
```

A partir da versão 1.4, você pode especificar códigos diferentes para sinalização (SIP), áudio (RTP) e vídeo (RTP).

### Autenticação SIP (sip.conf)

Quando o `chan_sip` legado recebia uma chamada SIP, ele seguia as regras descritas no diagrama a seguir. Três parâmetros desempenhavam um papel importante na autenticação SIP. No Asterisk 22, a autenticação é configurada com objetos PJSIP `auth` (`type=auth`, `auth_type=userpass`, `username=`, `password=`) referenciados por um endpoint, e o controle de acesso IP é feito com `permit=`/`deny=` no endpoint ou via um `acl`.

![Fluxo de decisão de autenticação chan_sip legado: Asterisk verifica o cabeçalho From em relação ao sip.conf, tenta a seção type=user/peer correspondente e credenciais MD5, e recorre a insecure=invite ou allowguest antes de permitir ou negar a chamada](../images/07-sip-and-pjsip-fig10.png)

```
allowguest=yes/no
```

Este parâmetro controla se um usuário sem um peer correspondente pode se autenticar sem um nome e segredo. Discutimos este parâmetro na seção de suporte a domínio.

```
insecure=invite,port
```

Quando usamos insecure=invite, o Asterisk não gera a mensagem “407 Proxy Authentication Required”. Sem esta mensagem, o usuário pode fazer uma chamada sem autenticação. Isso é frequentemente usado para conectar a provedores de serviço VoIP. As chamadas vindas do provedor de serviço VoIP geralmente não são autenticadas.

```
autocreatepeer=yes/no
```

Este comando é usado quando o Asterisk está conectado a um proxy SIP. Ele cria dinamicamente um peer para cada chamada. Quando esta opção está habilitada, qualquer UAC pode se conectar ao servidor Asterisk. É importante limitar a conexão IP ao proxy SIP. O proxy SIP, por sua vez, cuida do controle de acesso. A configuração do peer é baseada nas opções gerais, bem como no campo de cabeçalho “Contact” do pacote SIP. Aviso: Use isso com extrema cautela, pois abre completamente o Asterisk.

```
secret=secret, remotesecret=secret
```

Este parâmetro configura o segredo para autenticação; use secret para solicitações de entrada e remotesecret para solicitações de saída. Se você não quiser apresentar os segredos em arquivos de texto, você pode usar md5secret para incluir um hash em vez do segredo. Para gerar o segredo MD5, você pode usar:

```
echo -n "username:realm:secret" |md5sum
```

Em seguida, use a seguinte instrução:

```
md5secret=0b0e5d467890....
```

Aviso: Não se esqueça de usar o parâmetro –n; o retorno de carro será usado no cálculo do md5.

```
deny=0.0.0.0/0.0.0.0
permit=192.168.1.0/255.255.255.0
```

As instruções acima negarão todos os endereços IP e permitirão UAC apenas da rede local (192.168.1.0/24).

#### Opções RTP

É possível controlar alguns parâmetros RTP.

```
rtptimeout=60
```

Isso encerra chamadas sem atividade RTP por mais de 60 segundos quando não estão em espera.

```
rtpholdtimeout=120
```

Isso encerra chamadas sem atividade RTP mesmo em espera (deve ser maior que rtptimeout).

### Travessia NAT SIP (sip.conf)

A *teoria* de NAT (os quatro tipos de NAT, o problema do cabeçalho Contact, keep-alives e forçar mídia através do servidor) é de nível de protocolo e é abordada no capítulo *SIP & PJSIP in depth*. Os parâmetros `sip.conf` mostrados aqui (`nat=`, `qualify=`, `directmedia=`, `externaddr=`, `localnet=`) são do **chan_sip legado** e foram removidos no Asterisk 21+. No PJSIP, eles mapeiam para configurações de transporte/endpoint como `rewrite_contact=yes`, `force_rport=yes`, `rtp_symmetric=yes`, `direct_media=no`, `external_media_address`, `external_signaling_address` e `local_net=` no transporte, além de `qualify_frequency=` no AOR.

No chan_sip legado, o parâmetro `nat` tinha cinco opções:

- nat = no — Não fazer nenhum tratamento especial de NAT além do RFC3581
- nat = force_rport — Fingir que havia um parâmetro rport mesmo que não houvesse
- nat = comedia — Enviar mídia para a porta de onde o Asterisk a recebeu, independentemente de onde o SDP diz para enviar
- nat = auto_force_rport — Definir a opção force_rport se o Asterisk detectar NAT (padrão)
- nat = auto_comedia — Definir a opção comedia se o Asterisk detectar NAT

Quando você coloca a instrução “nat=force_rport” no arquivo sip.conf, você está dizendo ao Asterisk para ignorar o endereço contido no campo de cabeçalho “Contact” do cabeçalho SIP e usar o endereço IP de origem e a porta no cabeçalho IP do pacote, e também para enviar a mídia de volta para o endereço de onde ela foi recebida, ignorando o conteúdo do cabeçalho SDP.

```
nat=force_rport,comedia
```

É necessário manter o mapeamento NAT aberto. Se o NAT expirar, o Asterisk não poderá enviar um convite para o UAC. O UAC é capaz de enviar chamadas, mas não de receber nenhuma. A instrução a seguir pode ser usada para manter o NAT aberto.

```
qualify=yes
```

Qualify enviará um pacote SIP usando o método OPTIONS regularmente, o que ajudará a manter o NAT aberto. Qualify envia um OPTIONS a cada 60 segundos e a cada 10 segundos quando o host não está acessível. Você pode usar “sip show peers” para ver a latência dos peers. Se o NAT do usuário for do tipo simétrico, não é possível enviar pacotes de um UAC para outro diretamente; nesse caso, você deve forçar o RTP através do Asterisk usando:

```
directmedia=no
```

#### Asterisk atrás de NAT (sip.conf)

Todos os cenários anteriores assumem que o servidor Asterisk possui um endereço de Internet externo (válido). Às vezes, o servidor Asterisk é implementado atrás de um firewall com NAT. Nesse caso, é necessário fazer algumas configurações extras.

![Asterisk atrás de NAT: um firewall mapeia o endereço público 200.180.4.168 para o servidor Asterisk interno (192.168.1.100), encaminhando SIP em UDP 5060 e o intervalo RTP UDP 10000–20000 definido em rtp.conf](../images/07-sip-and-pjsip-fig13.png)

1. Configure o firewall para redirecionar a porta UDP 5060 estaticamente para o servidor Asterisk.
2. Configure o firewall para redirecionar as portas UDP de 10000 a 20000 estaticamente.

Se você quiser restringir o número de portas abertas, você pode editar o arquivo `rtp.conf` para alterar o intervalo de portas RTP. Outra maneira é usar um firewall inteligente que suporte o protocolo SIP para abrir as portas RTP dinamicamente.

```
; RTP Configuration
;
[general]
;
; RTP start and RTP end configure start and end addresses
;
rtpstart=10000
rtpend=20000
```

Passo 3: Configure o Asterisk para incluir o endereço externo nos campos de cabeçalho dos pacotes SIP, incluindo o Session Description Protocol (SDP). Você pode realizar isso adicionando as duas instruções a seguir ao arquivo sip.conf:

```
externaddr=200.180.4.168
;External IP address
localnet=192.168.1.0/255.255.255.0
;Internal Network Address
nat=force_rport,comedia
```

O primeiro parâmetro externaddr diz ao Asterisk para incluir o endereço IP externo dentro dos cabeçalhos SIP para destinos externos. O segundo parâmetro localnet permite que o Asterisk diferencie entre endereços externos e internos. Opcionalmente, você pode usar externhost se você usar um DNS Dinâmico com um endereço DHCP no servidor.

### Strings de discagem SIP (chan_sip)

A tecnologia de string de discagem `SIP/...` mostrada abaixo é o driver chan_sip removido. No Asterisk 22, use a tecnologia `PJSIP/...` em vez disso — por exemplo, `Dial(PJSIP/2000)` ou `Dial(PJSIP/${EXTEN}@provider)`. As formas e o significado são, de outra forma, análogos.

Você pode chamar um destino SIP legado usando diferentes strings de discagem:

```
SIP/peer
```

- ; Precisa ter um peer definido no sip.conf

```
SIP/flavio@voffice.com.br ; By the URI
SIP/[exten@]peer[:portno]
SIP/[user:password@domain/extension
```

Exemplos incluem:

```
exten=>s,1,Dial(SIP/ipphone)
exten=>s,1,Dial(SIP/info@voffice.com.br)
exten=>s,1,Dial(SIP/192.168.1.8:5060,20)
exten=>s,1,Dial(SIP/8500@sip.com:9876)
```

## Migrando um sistema legado chan_sip para PJSIP

Como o `chan_sip` foi removido no Asterisk 21 e não existe mais no Asterisk 22, qualquer implementação existente de `sip.conf` deve ser migrada para PJSIP. A maior mudança conceitual é que um único `sip.conf` `[peer]` ou `[friend]` é dividido em vários objetos PJSIP, cada um com um `type=`: um **endpoint** (configurações de chamada/codec/mídia), um ou mais objetos **aor** (onde o dispositivo pode ser alcançado / registro), um objeto **auth** (credenciais) e um **transport** compartilhado (o socket de escuta, endereços NAT). A tabela a seguir mapeia os conceitos mais comuns.

| Conceito legado sip.conf | Equivalente PJSIP (pjsip.conf) |
| --- | --- |
| Bloco `[peer]` / `[friend]` | `type=endpoint` + `type=aor` + `type=auth` (referenciados via `auth=` e `aors=`) |
| `type=friend` / `type=peer` / `type=user` | um único `type=endpoint` (PJSIP não possui distinção entre friend/peer/user) |
| `host=dynamic` (dispositivo registra) | `type=aor` com `max_contacts=1`; o dispositivo faz REGISTER para atualizar seu contato |
| `host=<ip/hostname>` (estático) | `type=aor` com um `contact=sip:host:port` estático |
| `register=>user:secret@host/ext` (saída) | `type=registration` (`server_uri=`, `client_uri=`, `outbound_auth=`) |
| `secret=` / `username=` | `type=auth`, `auth_type=userpass`, `username=`, `password=` |
| `context=` | `context=` no endpoint |
| `disallow=all` / `allow=ulaw` | `disallow=all` / `allow=ulaw` no endpoint (mesma sintaxe) |
| `dtmfmode=rfc2833` | `dtmf_mode=rfc4733` (PJSIP) — também `inband`, `info`, `auto` |
| `directmedia=yes/no` | `direct_media=yes/no` no endpoint |
| `nat=force_rport,comedia` | `force_rport=yes`, `rewrite_contact=yes`, `rtp_symmetric=yes` (endpoint) |
| `qualify=yes` | `qualify_frequency=` (segundos) no **aor** |
| `externaddr=` | `external_media_address=` e `external_signaling_address=` no **transport** |
| `localnet=` | `local_net=` no **transport** |
| `insecure=invite` (provedor, sem autenticação) | omita `auth=`/`outbound_auth=` e use `identify` (`type=identify`, `match=`) |
| `allowguest=yes` | endpoint `anonymous` + `allow_unauthenticated_options` (use com cuidado) |
| `tos_sip` / `tos_audio` | `tos_audio` / `tos_video` (e `cos_audio` / `cos_video`) no endpoint |

Uma extension com registro que parecia com isto no `sip.conf` legado:

```
[2000]
type=friend
host=dynamic
context=default
dtmfmode=rfc2833
disallow=all
allow=ulaw
secret=senha
```

torna-se o seguinte no `pjsip.conf` no Asterisk 22:

```
[2000]
type=endpoint
context=default
disallow=all
allow=ulaw
dtmf_mode=rfc4733
direct_media=no
auth=2000
aors=2000

[2000]
type=auth
auth_type=userpass
username=2000
password=senha

[2000]
type=aor
max_contacts=1
qualify_frequency=60
```

### O script de conversão sip_to_pjsip.py

O Asterisk vem com um script auxiliar, **`sip_to_pjsip.py`**, que lê um `sip.conf` existente e produz um `pjsip.conf`. Você pode executá-lo diretamente no diretório /etc/asterisk. O utilitário está na árvore de fontes do Asterisk em `contrib/scripts/sip_to_pjsip/`, onde `${PATH_TO_ASTERISK_SOURCE}` é o caminho onde os arquivos de fonte do Asterisk são encontrados (geralmente /usr/src/asterisk-22.x.y/):

```
${PATH_TO_ASTERISK_SOURCE}/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py
```

Se você executá-lo com a opção `--help`, verá suas opções:

```
-h, --help                help
-p, --prefix PREFIX       prefix to use for the included config files
-q, --quiet               suppress warnings and informational messages
```

Ele também aceita argumentos posicionais opcionais — `[input-file [output-file]]`, com padrão para `sip.conf` e `pjsip.conf` no diretório atual.

Trate sua saída como um **ponto de partida**: revise cada objeto gerado, especialmente transports, configurações de NAT e listas de codec, e teste minuciosamente antes de colocar em produção.

Vamos migrar o sip.conf em nossos laboratórios complementares na VoIP School Blackbelt (voip.school)

#### sip.conf

```
[general]
bindport=5060
bindaddr=0.0.0.0
context=dummy
disallow=all
allow=ulaw
alwaysauthreject=yes
allowguest=no
register=>1020:supersecret@sip.flagonc.com:5600/9999
[alice]
type=friend
secret=#supersecret#
host=dynamic
qualify=yes
directmedia=no
context=from-internal
[bob]
type=friend
secret=#supersecret#
host=dynamic
qualify=yes
directmedia=no
context=from-internal
[siptrunk]
type=peer
defaultuser=1020
secret=supersecret
port=5600 ; nor 5060, 5600
insecure=invite
host=sip.flagonc.com
fromuser=1020
fromdomain=sip.flagonc.com
context=from-siptrunk
```

#### pjsip.conf

```
;--
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[general]
bindport = 5060
[alice]
qualify = yes
[bob]
qualify = yes
[siptrunk]
defaultuser = 1020
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
--;
[transport-udp]
type = transport
protocol = udp
bind = 0.0.0.0:5060
[reg_sip.flagonc.com]
type = registration
retry_interval = 20
max_retries = 10
contact_user = 9999
expiration = 120
transport = transport-udp
outbound_auth = auth_reg_sip.flagonc.com
client_uri = sip:1020@sip.flagonc.com:5600
server_uri = sip:sip.flagonc.com:5600
[auth_reg_sip.flagonc.com]
type = auth
password = supersecret
username = 1020
[alice]
type = aor
max_contacts = 1
[alice]
type = auth
username = alice
password = #supersecret#
[alice]
type = endpoint
context = from-internal
disallow = all
allow = ulaw
direct_media = no
auth = alice
outbound_auth = alice
aors = alice
[bob]
type = aor
max_contacts = 1
[bob]
type = auth
username = bob
password = #supersecret#
[bob]
type = endpoint
context = from-internal
disallow = all
allow = ulaw
direct_media = no
auth = bob
outbound_auth = bob
aors = bob
[siptrunk]
type = aor
contact = sip:1020@sip.flagonc.com:5600
[siptrunk]
type = identify
endpoint = siptrunk
match = sip.flagonc.com
[siptrunk]
type = auth
username = siptrunk
password = supersecret
[siptrunk]
type = endpoint
context = from-siptrunk
disallow = all
allow = ulaw
from_user = 1020
from_domain = sip.flagonc.com
auth = siptrunk
outbound_auth = siptrunk
aors = siptrunk
```

Embora a conversão pareça correta, podemos ver que alguns elementos, como qualify=yes, não podem ser mapeados diretamente. Para corrigir, você deve adicionar à seção aor o comando qualify_frequency=time em segundos. Exemplo abaixo.

```
[bob]
type = aor
max_contacts = 1
qualify_frequency=15
```

A configuração completa do PJSIP é abordada no capítulo *SIP & PJSIP in depth*, e a documentação oficial em docs.asterisk.org possui cobertura completa do canal. Em nossos laboratórios complementares na voip.school, o laboratório 5 permite que você pratique o que acabou de aprender.

## Resumo

Este capítulo reuniu as tecnologias de canal que antecedem as implementações puramente VoIP de hoje, mas que o Asterisk 22 ainda suporta. Você viu como linhas e telefones **analog** se conectam através de interfaces **FXO/FXS** no DAHDI, como links **digital TDM** (E1/T1 e ISDN PRI/BRI) são provisionados, e como o **IAX2** (`chan_iax2`) ainda serve como um trunk servidor-para-servidor eficiente e amigável ao NAT, embora seja agora firmemente um legado. Você também revisitou o driver **`chan_sip`** aposentado e sua sintaxe `sip.conf` — que você encontrará em sistemas mais antigos, mas que não existe mais no Asterisk 22 — e trabalhou na migração de tal sistema para PJSIP com a tabela de mapeamento de conceitos e o script `sip_to_pjsip.py`. A regra prática é: recorra a qualquer coisa neste capítulo apenas quando hardware real ou um sistema legado existente forçar sua mão; tudo o que for novo (green-field) é PJSIP sobre IP.

## Quiz

1. Com relação às duas interfaces analógicas Foreign eXchange, marque as afirmações corretas (escolha todas as que se aplicam):
   - A. Uma interface FXO conecta-se à central telefônica da PSTN e obtém o tom de discagem a partir dela.
   - B. Uma interface FXS fornece tom de discagem e energia de toque para um telefone analógico, fax ou modem padrão.
   - C. Uma interface FXS é a maneira correta de conectar o Asterisk a uma linha telefônica.
   - D. Uma interface FXO também pode ser conectada a uma porta de extensão de um PBX legado.
2. A sinalização de supervisão em uma linha analógica inclui qual das seguintes opções (escolha todas as que se aplicam)?
   - A. On-hook
   - B. Off-hook
   - C. Ringing
   - D. DTMF
3. Eco, estalos e ruído em uma placa analógica DAHDI são causados, na maioria das vezes, por:
   - A. A maneira como o Asterisk foi compilado
   - B. Conflitos de interrupção PCI
   - C. Um codec SIP incorreto
   - D. Um dialplan ausente
4. Para um faturamento preciso em canais analógicos, você deve detectar exatamente quando a outra ponta atende. Qual recurso você ativa no Asterisk (e solicita à operadora) para fazer isso?
   - A. Answer reversal
   - B. Billing reversal
   - C. Polarity reversal
   - D. Dial-tone generation
5. O hardware DAHDI é independente do Asterisk: a placa física é configurada em `/etc/dahdi/system.conf`, enquanto `chan_dahdi.conf` define os canais do Asterisk, não o hardware em si.
   - A. Verdadeiro
   - B. Falso
6. Com relação à capacidade e sinalização de trunk digital, marque as afirmações corretas (escolha todas as que se aplicam):
   - A. Um trunk E1 transporta 30 canais de voz e um trunk T1 transporta 24.
   - B. Um ISDN PRI usa 30B+D em um E1 e 23B+D em um T1.
   - C. ISDN é um exemplo de sinalização CCS, enquanto MFC/R2 é um exemplo de sinalização CAS.
   - D. T1 é o trunk digital mais comumente usado na Europa e na América Latina.
7. Qual utilitário detecta automaticamente placas DAHDI e gera `/etc/dahdi/system.conf` e `dahdi-channels.conf`?
   - A. dahdi_generator
   - B. dahdi_genconf
   - C. dahdi_cfg
   - D. generate_dahdi
8. Ao migrar um `sip.conf` `[friend]` legado para PJSIP, um único bloco deve ser dividido em vários objetos. Qual conjunto de objetos `type=` do PJSIP normalmente substitui um `[friend]` com registro?
   - A. `type=endpoint`, `type=aor` e `type=auth`
   - B. `type=peer` e `type=user`
   - C. Apenas `type=sip`
   - D. `type=channel` e `type=device`
9. Qual é a principal vantagem prática de usar o modo trunk IAX2 entre dois servidores Asterisk?
   - A. Ele criptografa todas as chamadas com TLS por padrão
   - B. Ele transporta várias chamadas sob um único cabeçalho, economizando largura de banda
   - C. Ele remove a necessidade de qualquer codec
   - D. Ele aloca uma porta UDP separada por chamada para melhor qualidade
10. Chaves RSA podem ser usadas para autenticação IAX2. Qual chave você deve manter em segredo e qual você fornece ao outro servidor?
    - A. Mantenha a chave pública em segredo; compartilhe a chave privada
    - B. Mantenha a chave privada em segredo; compartilhe a chave pública
    - C. Mantenha a chave compartilhada em segredo; compartilhe a chave privada
    - D. Ambas as chaves devem ser compartilhadas

**Respostas:** 1 — A, B, D · 2 — A, B, C · 3 — B · 4 — C · 5 — A · 6 — A, B, C · 7 — B · 8 — A · 9 — B · 10 — B
