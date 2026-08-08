# Usando recursos de PBX

Em sistemas SIP, a maioria dos recursos de telefonia é implementada no endpoint. Existe uma variedade de telefones SIP e fabricantes, e a interoperabilidade não é garantida. A equipe de desenvolvimento do Asterisk fez um trabalho incrível ao implementar a maioria dos recursos no próprio PBX, tornando o Asterisk quase independente do endpoint. No entanto, às vezes você encontrará a mesma função sendo executada tanto pelo telefone quanto pelo próprio Asterisk. A integração do telefone com o PBX é a próxima fronteira em usabilidade e onde os sistemas proprietários estão focando agora. Neste capítulo, você aprenderá como usar a maioria desses recursos.

## Objetivos

Ao final deste capítulo, você será capaz de entender e utilizar:

- Call Parking
- Call Pickup
- Call Transfer
- Call Conference (ConfBridge)
- Call Recording
- Music on hold

## Onde as funcionalidades são implementadas

Primeiramente, é importante entender quando as funcionalidades do PBX estão sendo executadas em comparação a quando o telefone está realizando todo o trabalho. Por exemplo, você pode transferir uma chamada usando o botão TRANSFER no telefone ou discando # (transferência incondicional executada pelo próprio PBX).

## Recursos implementados pelo Asterisk

Estes recursos são implementados no PBX pelo código do Asterisk:

- Music on hold
- Call parking
- Call pickup
- Call recording
- ConfBridge conference room
- Call transfer (blind and consultative)

## Recursos geralmente implementados pelo dialplan

Estes recursos precisam ser programados no dialplan do Asterisk (extensions.conf):

- Encaminhamento de chamada quando ocupado
- Encaminhamento imediato de chamada
- Encaminhamento de chamada quando não atendida
- Filtragem de chamadas (blacklist)
- Não perturbe
- Rediscar

## Recursos geralmente implementados pelo telefone

Estes recursos são implementados pelo firmware do telefone:

![Onde os recursos do PBX são geralmente implementados: no próprio Asterisk, no dialplan ou no telefone](../images/13-pbx-features-fig01.png)

- Chamada em espera (Call on hold)
- Transferência cega (Blind transfer)
- Transferência assistida (Consultative transfer)
- Conferência a três (Three-way conference)
- Indicador de mensagem em espera (Message waiting indicator)

## O arquivo de configuração de recursos

Alguns dos recursos apresentados neste capítulo são configurados no arquivo de configuração features.conf. É possível alterar o comportamento de alguns recursos modificando este arquivo. Incluímos o trecho relevante abaixo. Nas próximas seções deste capítulo, descreveremos cada recurso. Trecho do arquivo de exemplo (Asterisk 22)

![A seção `[featuremap]` do features.conf, com os códigos de recurso DTMF padrão](../images/13-pbx-features-fig02.png)

Desde o Asterisk 12, o estacionamento de chamadas foi removido do `features.conf` para seu próprio módulo, o `res_parking`, com configuração no `res_parking.conf`. O bloco parking-lot abaixo (`parkext`, `parkpos`, `context`, `parkingtime` e assim por diante) reside no `res_parking.conf`. A seção `[featuremap]` (os códigos de recurso DTMF, incluindo o `parkcall`) permanece no `features.conf`.

As opções de parking-lot residem no `res_parking.conf`. Um parking lot chamado `default` sempre existe, mesmo que não esteja presente no arquivo de configuração. O trecho abaixo foi retirado do `res_parking.conf.sample` do Asterisk 22:

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

Os códigos de recurso DTMF (incluindo o `parkcall` de uma etapa) permanecem na seção `[featuremap]` do `features.conf`:

```
; features.conf
[featuremap]
;blindxfer => #1                ; Blind transfer  (default is #) -- Make sure to set the T and/or t option in the Dial() or Queue() app call!
;disconnect => *0               ; Disconnect  (default is *) -- Make sure to set the H and/or h option in the Dial() or Queue() app call!
;atxfer => *2                   ; Attended transfer  -- Make sure to set the T and/or t option in the Dial() or Queue()  app call!
;parkcall => #72                ; Park call (one step parking)  -- Make sure to set the K and/or k option in the Dial() app call!
;automixmon => *3               ; One Touch Record a.k.a. Touch MixMonitor -- Make sure to set the X and/or x option in the Dial() or Queue() app call!
```

## Transferência de chamadas

A transferência de chamadas pode ser implementada pelo telefone, por um ATA ou pelo próprio Asterisk. Consulte o manual do seu telefone para entender como as chamadas são transferidas. Se o seu telefone não suportar a transferência de chamadas, você pode usar o Asterisk para realizar essa tarefa. A transferência de chamadas é implementada de duas maneiras diferentes.

A primeira maneira é usar o recurso de transferência cega (blind transfer): disque # seguido pelo número para o qual a chamada será transferida. Às vezes, você usará o recurso de transferência do seu telefone IP ou softphone IP. Você pode alterar o caractere de transferência editando o parâmetro blindxfer no arquivo features.conf.

Você pode habilitar a transferência assistida (attended transfer) no Asterisk removendo o ; antes do parâmetro atxfer no arquivo features.conf. Durante uma conversa, você deve pressionar *2. O Asterisk dirá "transfer" e fornecerá um tom de discagem. Quem ligou é enviado para a música de espera (music on hold). Depois de falar com a pessoa de destino e desligar o telefone, o sistema faz a ponte entre quem ligou e o destino.

![Transferência de chamadas: os passos para uma transferência cega (pressione # durante a chamada) e uma transferência assistida (pressione *2)](images/call_transfer.png)(../images/13-pbx-features-fig03.png)

### Lista de tarefas de configuração

1. Para um endpoint PJSIP, certifique-se de que a opção `direct_media` esteja definida como `no` (para que a mídia flua através do Asterisk e os códigos de recurso sejam detectados), ou use uma opção `t`/`T` na aplicação `Dial()`

## Estacionamento de chamadas

Este recurso é usado para estacionar uma chamada. Isso ajuda, por exemplo, quando você está atendendo a uma chamada telefônica fora da sua sala e deseja transferir a chamada de volta para a sua mesa. Você pode realizar isso estacionando a chamada em uma extension. Assim que chegar à sua mesa, basta discar o número da extension de estacionamento para recuperar a chamada.

![Estacionamento de chamadas: disque 700 para estacionar uma chamada no primeiro slot livre (701–720); o Asterisk anuncia o slot, que você disca de qualquer telefone para recuperar a chamada](../images/13-pbx-features-fig04.png)

Por padrão, a extension 700 é usada para estacionar uma chamada. No meio de uma conversa, pressione # para transferir a chamada para a extension 700. Agora, o Asterisk anunciará sua extension de estacionamento, como 701 ou 702. Desligue o telefone e o autor da chamada será colocado em espera. Vá até o telefone da sua mesa e disque a extension de estacionamento anunciada para recuperar a chamada. Se o autor da chamada ficar estacionado por muito tempo, o recurso de timeout será acionado e a extension discada originalmente tocará novamente.

### Lista de tarefas de configuração

Siga os passos abaixo para habilitar o estacionamento de chamadas. Passo 1: Torne o parking lot acessível a partir do seu dialplan (obrigatório). O `context` do parking lot padrão é `parkedcalls` (definido em `res_parking.conf`). Inclua esse context no context a partir do qual seus telefones discam, em `extensions.conf`:

```
include => parkedcalls
```

Passo 2: Teste o recurso de estacionamento de chamadas discando #700. Notas:

- A extension de estacionamento não será exibida no comando CLI dialplan show.
- É necessário recarregar o módulo de estacionamento após alterar o arquivo de configuração de estacionamento: `module reload res_parking.so`. Para alterações no features.conf, `module reload features.so`.
- Para estacionar uma chamada, você precisa transferir para #700. Verifique as opções `t` e `T` na aplicação `Dial()`.

## Call pickup

Call pickup permite que você capture uma chamada de um colega no mesmo grupo de chamada. Isso ajuda a evitar, por exemplo, ter que se levantar para atender uma chamada que está tocando para outra pessoa na sua sala, mas que não está presente. Ao discar *8, você pode capturar uma chamada dentro do seu grupo de chamada. Este número pode ser modificado no arquivo `features.conf`.

![Call pickup: membros só podem capturar chamadas dentro do seu próprio grupo; o operador (pickupgroup=1,2,3) pode capturar chamadas de todos os grupos](../images/13-pbx-features-fig05.png)

### Lista de tarefas de configuração

Siga os passos abaixo para configurar o recurso de call pickup. Passo 1: Configure um grupo de chamada para suas extensions. Isso é feito no arquivo de configuração do canal (pjsip.conf, iax.conf, chan_dahdi.conf). Para endpoints PJSIP, defina `call_group` e `pickup_group` na seção de endpoint do `pjsip.conf` (pjsip.conf usa nomes de opções em snake_case). Esta tarefa é obrigatória.

Para PJSIP (pjsip.conf):
```
[4x00]
type=endpoint
call_group=1
pickup_group=1,2
```


Passo 2: Altere o número do recurso de call-pickup (opcional). Isso é definido na seção `[general]` do `features.conf`, não no `pjsip.conf`:

```
; features.conf
[general]
pickupexten = *8   ; Configures the call pickup extension (default is *8)
```

## Conferência (chamada em conferência)

Existem diferentes maneiras de implementar uma conferência no Asterisk. A primeira opção é simplesmente usar a capacidade de conferência de três vias do telefone. Ao usar esse recurso no telefone, você não precisa de nenhum suporte no próprio servidor. No entanto, quando você deseja uma conferência com mais de 3 pessoas, você deve executar uma sala de conferência. A aplicação de conferência moderna do Asterisk é o ConfBridge (`app_confbridge`).

O ConfBridge suporta conferências de voz em HD e videoconferência. Existem algumas limitações para videoconferência, como a ausência de transcodificação — todos os participantes precisam usar o mesmo codec e perfil. A videoconferência usa um modo de "seguir o falante", exibindo a imagem da última pessoa a falar. Você pode configurar facilmente novos menus DTMF no ConfBridge.

O ConfBridge substitui a antiga aplicação MeetMe, que foi descontinuada no Asterisk 19. O MeetMe ainda é enviado na árvore de código-fonte do Asterisk 22, mas depende do DAHDI e não é compilado por padrão, portanto, em uma instalação típica de PJSIP, ele simplesmente não está disponível — o ConfBridge é a aplicação de conferência suportada. Ao contrário do MeetMe, o ConfBridge **não** requer DAHDI ou uma fonte de temporização de hardware: ele depende da interface de temporização integrada do Asterisk (`res_timing_timerfd` no Linux, ou `res_timing_pthread`), portanto, nenhum módulo `dahdi_dummy` é necessário. Se você estiver migrando de um sistema mais antigo que usava `MeetMe()` e `meetme.conf`, substitua-os por `ConfBridge()` e `confbridge.conf` conforme descrito abaixo.

### ConfBridge

Para iniciar uma sala de conferência, a sintaxe está listada abaixo.

```
ConfBridge(conference,bridge_profile,user_profile,menu)
```

Para obter uma descrição completa do comando, você pode usar core show application confbridge.

![Saída de `core show application confbridge`, mostrando a sinopse, sintaxe e os argumentos bridge_profile, user_profile e menu](../images/13-pbx-features-fig06.png)

![Vários endpoints PJSIP entram em uma conferência ConfBridge nomeada (101); um participante é o administrador. A mixagem e a temporização são tratadas pelo `app_confbridge` junto com o `bridge_softmix` e o temporizador integrado `res_timing_*` — sem necessidade de DAHDI.](../images/13-pbx-features-fig09.png)

Como você pode ver acima, existem três argumentos importantes, cada um mapeando para um tipo de seção no `confbridge.conf`. **bridge_profile** (uma seção `type=bridge`): aqui você seleciona o número máximo de participantes (`max_members`), gravação (`record_conference`), `video_mode` e muitos outros parâmetros de toda a ponte.

Não faz sentido reproduzir o arquivo de exemplo inteiro aqui, então deixe-me dar um exemplo simples de como configurar um bridge_profile no arquivo confbridge.conf.

```
[default_bridge]
type=bridge
max_members=10
record_conference=yes
```

**user_profile** (uma seção `type=user`): aqui você define opções que são específicas por usuário, como se o usuário é um administrador (`admin=yes`), se eles começam no mudo (`startmuted=yes`), música de espera e muitas outras opções por usuário. Exemplo:

```
[admin_user]
type=user
admin=yes
```

**menu** (uma seção `type=menu`): aqui você define o mapeamento do teclado (DTMF) para a conferência — por exemplo, qual tecla alterna o mudo, ajusta o volume ou sai da conferência. Verifique o arquivo `confbridge.conf.sample` para ver todas as ações disponíveis. Exemplo:

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

#### Funções do Confbridge

As opções da ponte de conferência podem ser passadas dinamicamente no dialplan usando a função CONFBRIDGE(). Veja os exemplos abaixo:

```
exten => 1,1,Answer()
exten => 1,n,Set(CONFBRIDGE(user,template)=default_user)
exten => 1,n,Set(CONFBRIDGE(user,admin)=yes)
exten => 1,n,Set(CONFBRIDGE(user,marked)=yes)
exten => 1,n,ConfBridge(sales)
```

### Comandos de administrador do ConfBridge e migração do MeetMe

Se você está vindo do MeetMe, as funções de administrador que você usava através do `MeetMeAdmin()` e da opção `a` (admin) agora são expressas através do **perfil de usuário administrador** (`admin=yes`) mais as ações de **menu**. Um administrador que entra com um perfil de administrador e um menu contendo ações de administrador pode bloquear a sala, expulsar usuários e colocar participantes no mudo ao vivo pelo teclado. As ações de menu relevantes no `confbridge.conf` são:

- `admin_kick_last` -- expulsar o último usuário que entrou
- `admin_toggle_mute_participants` -- colocar/tirar todos os participantes não administradores do mudo
- `toggle_mute` -- colocar/tirar você mesmo do mudo
- `participant_count` -- anunciar o número de participantes
- `leave_conference` -- sair da ponte e continuar no dialplan

Estes substituem as flags de opção do MeetMe `MeetMe()` (`a`, `A`, `m`, `M`, `l`, `x`, …) e os comandos `MeetMeAdmin()` (`k`, `K`, `L`, `M`, `N`, …). Em uma instalação PJSIP moderna, você não carregará o `app_meetme` de forma alguma; toda a configuração da conferência reside no `confbridge.conf` e as alterações são aplicadas com `module reload app_confbridge.so` (a lógica do ConfBridge reside no `app_confbridge`; não existe módulo `res_confbridge`).

### Exemplo de ConfBridge

Para criar uma sala de conferência acessível na extension 500, no `extensions.conf`:

```
exten => 500,1,Answer()
 same => n,ConfBridge(101,default_bridge,default_user,sample_user_menu)
```

O primeiro chamador a discar 500 cria a conferência `101`; os chamadores subsequentes entram nela. Perfis e menus referenciados aqui (`default_bridge`, `default_user`, `sample_user_menu`) são definidos no `confbridge.conf`. Para exigir um PIN, defina `pin=` no perfil de usuário; para tornar um participante um administrador de conferência, forneça a ele um perfil de usuário com `admin=yes`.

## Gravação de Chamadas

Existem várias maneiras de gravar uma chamada no Asterisk. Você pode usar a aplicação `MixMonitor()` para gravar chamadas facilmente. (A aplicação mais antiga `Monitor`, que gravava dois arquivos separados, foi removida; use `MixMonitor` em seu lugar.)

### Usando a aplicação MixMonitor

A aplicação `MixMonitor` grava o áudio no canal atual para o arquivo especificado. Se o nome do arquivo for um caminho absoluto, ele usa esse caminho. Caso contrário, ele cria o arquivo no diretório de monitoramento configurado em asterisk.conf.

![A aplicação MixMonitor(): grava e mixa o áudio de um canal em um arquivo, com opções para anexar, apenas em ponte (bridged-only) e ajuste de volume](../images/13-pbx-features-fig09.png)

### MixMonitor()

Grave uma chamada e mixe o áudio durante a gravação. Sintaxe: `MixMonitor(filename.extension[,options[,command]])`. Grava o áudio no canal atual para o arquivo especificado. Opções válidas:

- a - Anexa ao arquivo em vez de sobrescrevê-lo.
- b - Salva áudio no arquivo apenas enquanto o canal estiver em ponte (bridged).
- Nota: não inclui conferências.
- v(<x>) - Ajusta o volume audível por um fator de <x> (variando de -4 a 4)
- V(<x>) - Ajusta o volume falado por um fator de <x> (variando de -4 a 4)
- W(<x>) - Ajusta ambos os volumes, audível e falado, por um fator de <x> (variando de -4 a 4)
- <command> será executado quando a gravação terminar. Quaisquer strings correspondentes a ^{X} serão convertidas para ${X} e todas as variáveis serão avaliadas naquele momento. A variável MIXMONITOR_FILENAME conterá o nome do arquivo usado para gravar.

Um recurso interessante é a funcionalidade de gravação com um toque `automixmon`, que permite que uma das partes disque um código DTMF (o exemplo `features.conf` sugere `*3`; não há um padrão integrado, então você deve defini-lo) durante uma chamada para iniciar (e alternar para desligar) a gravação imediatamente. Ela é construída sobre o MixMonitor, portanto, grava um único arquivo mixado. Exemplo:

```
exten => _4XXX,1,Set(DYNAMIC_FEATURES=automixmon)
 same => n,Dial(PJSIP/${EXTEN},20,jtTXx) ; X and x enable one-touch MixMonitor recording
```

As opções `X` e `x` habilitam o recurso de MixMonitor com um toque para quem chama e quem recebe, respectivamente. Como o MixMonitor grava um único arquivo mixado, não há necessidade de combinar arquivos IN/OUT separados posteriormente (a abordagem antiga `automon`/`Monitor`, que produzia dois arquivos para `soxmix`, foi removida junto com a aplicação `Monitor`).

Se você não quiser usar Set() antes da aplicação Dial(), você pode definir isso na seção globals:

```
[globals]
DYNAMIC_FEATURES=automixmon
```

### Música de espera (Music on hold)

A música de espera (MOH) mudou várias vezes entre as versões 1.0, 1.2 e 1.4. Na versão mais recente, a MOH usa "FILE-BASED" como padrão. Em outras palavras, o Asterisk fornecerá os arquivos de MOH em formatos como g729, alaw, ulaw e gsm. Assim, não é necessário transcodificar a música antes de enviá-la para o canal. Isso economiza tempo de processador, o que é uma modificação bem-vinda para aqueles que trabalham com sistemas de produção.

Em versões mais antigas, a MOH era geralmente fornecida por MP3 (ainda pode ser configurada dessa forma). Fornecer MOH usando MP3 obriga o Asterisk a transcodificar, gastando um valioso poder de CPU no processo.

O novo arquivo de configuração é mostrado abaixo. Observe que a classe padrão agora usa o modo de formato de arquivo nativo mode=files. Todos os outros modos estão comentados. Cada seção é uma classe. A única classe não comentada neste momento é a default. Se você quiser ter classes diferentes para arquivos diferentes, precisará criar novas seções (classes).

![O exemplo de configuração musiconhold.conf, listando os modos de MOH válidos (quietmp3, mp3, custom, files, …)](../images/13-pbx-features-fig10.png)

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

### Tarefas de configuração de MOH

Agora, para usar música de espera, defina a classe de MOH nos arquivos de configuração de canal (chan_dahdi.conf, pjsip.conf, iax.conf, e assim por diante). Para endpoints PJSIP, defina `moh_suggest` na seção endpoint de `pjsip.conf` (o nome da opção legada `musicclass` aplica-se ao chan_dahdi e outros drivers de canal, não ao PJSIP). As músicas gratuitas instaladas estão agora no formato wav. No momento da instalação, você pode selecionar (usando make menuselect) os formatos de arquivo de MOH disponíveis. Se você quiser adicionar novos arquivos de MOH, terá que fornecê-los nos formatos necessários. Por exemplo:

Em `/etc/asterisk/chan_dahdi.conf`, adicione a linha `musiconhold`:

```
[channels]
musiconhold=default
```

Em seguida, edite `/etc/asterisk/musiconhold.conf` para definir essa classe:

```
[default]
mode=files
directory=/var/lib/asterisk/moh
```

No dialplan, você pode iniciar a música de espera em um canal com `StartMusicOnHold` (e pará-la com `StopMusicOnHold`):

```
exten => 100,1,StartMusicOnHold(default)
 same => n,Dial(PJSIP/2)
```

Para reproduzir música de espera por um tempo fixo como um teste rápido, use a aplicação `MusicOnHold` com uma duração (em segundos):

```
[local]
exten => 6601,1,MusicOnHold(default,30)
```

## Mapas de Aplicação

Os mapas de aplicação permitem que você adicione novos recursos usando a seção `[applicationmap]` do arquivo features.conf. Suponha que você precise identificar o tipo de cliente que está atendendo em um call center. Você poderia criar um mapa de aplicação para cada tipo de cliente, o que poderia contar o número de clientes atendidos por tipo.

## Resumo

Neste capítulo, você aprendeu onde residem os recursos de PBX do Asterisk — alguns no núcleo, alguns no dialplan e outros no telefone — e como os códigos de funcionalidade DTMF são mapeados na seção `[featuremap]` do `features.conf`. Você configurou **transferência de chamadas** (cega e assistida) e **estacionamento de chamadas** (`res_parking.conf`, com as opções de Dial `k`/`K` e o lote `parkedcalls`), **captura de chamadas** por grupo e **conferência** com o **ConfBridge** (perfis de bridge/user/menu `confbridge.conf`), que substitui o antigo MeetMe. Você configurou a **gravação com um toque** com o MixMonitor (`automixmon`, as opções de Dial `X`/`x` e `DYNAMIC_FEATURES`), configurou **música de espera** e viu como os **mapas de aplicação** permitem vincular sua própria lógica de dialplan a uma sequência DTMF. Com esses blocos de construção, você pode oferecer os recursos cotidianos que os usuários esperam de um PBX corporativo.

## Quiz

1. Quais afirmações são verdadeiras sobre o estacionamento de chamadas (call parking)?
   - A. Por padrão, a extension 800 é usada para o estacionamento de chamadas.
   - B. Quando você está longe da sua mesa e recebe uma chamada, você pode estacioná-la; o sistema anuncia a vaga de estacionamento, e você disca essa vaga de qualquer telefone para recuperar a chamada.
   - C. Por padrão, a extension 700 estaciona uma chamada, e as chamadas são estacionadas nas vagas 701–720.
   - D. Você disca 700 para recuperar uma chamada estacionada.
2. Para usar o recurso de call-pickup, todas as extensions devem estar no mesmo ___. Para canais DAHDI, isso é configurado no arquivo ___.
3. Ao transferir uma chamada, você pode escolher entre uma transferência ___, onde o destino não é consultado primeiro, e uma transferência ___, onde você fala com o destino antes de completar a operação.
4. Para realizar uma transferência assistida (consultiva), você usa a sequência ___; para uma transferência cega (blind), você usa ___.
   - A. #1, *2
   - B. *2, #1
   - C. #2, #1
   - D. #1, #2
5. Para hospedar conferências no Asterisk 22, você usa a aplicação ___.
6. No ConfBridge, um participante recebe privilégios de administrador (expulsar, silenciar outros, bloquear a sala) definindo ___ em seu perfil de usuário (`confbridge.conf`):
   - A. admin=yes
   - B. marked=yes
   - C. moderator=yes
   - D. type=admin
7. O melhor formato para music on hold é MP3, porque ele utiliza muito pouco poder de processamento no servidor Asterisk.
   - A. Verdadeiro
   - B. Falso
8. Para atender uma chamada de um grupo de chamada específico, você deve estar no grupo de ___ correspondente.
9. Você pode gravar uma chamada com a aplicação MixMonitor() ou com o recurso de gravação one-touch (`automixmon`). No exemplo `features.conf`, `automixmon` é mapeado para a sequência DTMF ___.
   - A. *1
   - B. *2
   - C. *3
   - D. #1
10. No ConfBridge, qual opção de perfil de usuário `confbridge.conf` faz com que um participante entre silenciado (ele pode ouvir a conferência, mas não pode ser ouvido até que o silenciamento seja removido)?
    - A. startmuted=yes
    - B. listen=only
    - C. muteall=yes
    - D. quiet=yes

**Respostas:** 1 — B, C · 2 — pickup group; `chan_dahdi.conf` · 3 — blind; attended · 4 — B · 5 — ConfBridge() · 6 — A · 7 — B · 8 — pickup · 9 — C · 10 — A
