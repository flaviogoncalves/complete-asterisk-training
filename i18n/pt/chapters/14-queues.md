# Filas de Chamadas

Filas de chamadas, também conhecidas como ACD (Distribuição Automática de Chamadas), estão se tornando cada vez mais importantes para atender chamadas de clientes de forma eficiente. Um distribuidor automático de chamadas pode ajudar a reduzir custos, aumentar o nível de serviço e melhorar as vendas, já que os distribuidores de chamadas afetam a forma como sua empresa opera — não apenas por alguns dias, mas por muitos anos. Em um ambiente de call center, o fator número um são as pessoas; elas são o recurso mais caro. É preciso tempo, dinheiro e paciência para contratar, treinar e motivar agentes. Com um ACD, você pode maximizar a produtividade dos agentes dimensionando com precisão o número de agentes necessários, controlando o desempenho dos atendentes e analisando o fluxo de chamadas.

## Objetivos

Ao final deste capítulo, você deverá ser capaz de:

- Entender por que e como usar filas de chamadas
- Entender a teoria básica das filas de chamadas
- Instalar e configurar o sistema de filas

## Como as filas funcionam?

Filas de chamadas não são exatamente uma novidade. Quando você tem um alto fluxo de chamadas recebidas, é difícil distribuir as chamadas de forma apropriada. Usar uma estratégia de grupo onde o telefone toca simultaneamente em todos os agentes não parece funcionar, a menos que você tenha apenas alguns poucos agentes. No entanto, uma fila de chamadas entregará chamadas apenas para um único agente disponível de cada vez e colocará o cliente em espera com música quando não houver agentes disponíveis. A fila funciona retendo a chamada enquanto encontra um agente desocupado para atendê-la. Um dos maiores benefícios da fila é evitar a perda de chamadas, ao mesmo tempo em que oferece a possibilidade de gerar estatísticas.

![Uma fila de chamadas: chamadas recebidas 1-800 entram na fila e uma estratégia ACD (ringall, rrmemory, leastrecent, priority e outras) as distribui para os agentes disponíveis](../images/14-queues-fig01.png)

Normalmente, uma fila de chamadas funciona assim:

- Os agentes fazem login na fila.
- As chamadas recebidas são colocadas na fila.
- Uma estratégia de enfileiramento para distribuir as chamadas é usada para enviar as chamadas aos agentes.
- Música de espera é tocada enquanto o chamador aguarda.
- Anúncios podem ser feitos aos chamadores, notificando-os sobre o tempo de espera.
- A chamada é atendida pelo agente e estatísticas são geradas.

A principal aplicação para filas é o atendimento ao cliente. Ao usar filas, você evita perder chamadas quando seus agentes estão ocupados. Você pode adicionar novos agentes à fila se perceber que o número de chamadores na fila está aumentando. Outra vantagem das filas é que agora você pode ter estatísticas como taxa de abandono de chamadas, duração média da chamada e meta de atendimento de chamadas. Essas estatísticas ajudarão você a determinar quantos agentes usar para fornecer um melhor serviço ao seu cliente.

### Arquitetura ACD

A arquitetura ACD é formada por filas e agentes. Um agente pode estar em duas filas ao mesmo tempo. Uma fila pode ter agentes, canais e grupos de agentes.

![Arquitetura ACD: cada fila (Atendimento ao Cliente, Vendas Internas) é alimentada por um número de telefone e entrega chamadas aos agentes, que por sua vez estão vinculados a canais físicos](../images/14-queues-fig02.png)

## Queues

As filas (Queues) são definidas no arquivo de configuração queues.conf. Agentes são atendentes que fazem login e são membros de filas. Agentes são definidos no arquivo agents.conf. O sistema de filas cresceu significativamente ao longo de muitas versões, tornando o arquivo de configuração extenso. Explicaremos alguns dos principais parâmetros. Um parâmetro geral que vale a pena destacar é `autofill`:

```
autofill=yes
```

O comportamento antigo da fila era do tipo serial. A fila esperava que uma chamada fosse atendida antes de enviar a chamada seguinte para o próximo agente. Se um agente levasse 15 segundos para atender uma chamada, as outras chamadas na fila tinham que esperar até que aquela chamada fosse atendida. Para filas de alto volume, esse comportamento era ineficiente. O novo comportamento autofill=yes não espera até que uma chamada seja atendida, mas trabalha em paralelo. Você pode gravar as chamadas na fila usando a opção mixmonitor. Nesse modo, as chamadas são gravadas e mixadas ao mesmo tempo.

### Arquivo de configuração de filas

As filas são configuradas no arquivo queues.conf. Na figura, você encontrará um exemplo funcional de uma fila.

![Um exemplo funcional do arquivo queues.conf, mostrando a seção geral e uma fila de atendimento ao cliente (customerservice) com estratégia, nível de serviço, anúncios, gravação e membros](../images/14-queues-fig03.png)

### Agentes

Você pode configurar seus agentes no arquivo agents.conf. Os agentes podem fazer login a partir de qualquer extension para receber chamadas. Você pode discar para um agente usando:

```
Dial(agent/<name>)
```

#### Login de agente

O fluxo de login para o Agente 300 funciona assim:

- O usuário disca uma extension que executa a aplicação `AgentLogin()`.
- `AgentLogin()` é executado e o agente é associado ao canal atual.
- Você pode verificar o status dos agentes usando o comando `agent show all`.

![Agentes: um usuário faz login discando uma extension que executa a aplicação agentlogin, que vincula o Agente 300 ao canal atual; você pode verificar o status do agente com `agent show all`](../images/14-queues-fig04.png)

Você pode definir os agentes no arquivo agents.conf

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

### Membros

Membros são canais ativos respondendo à fila. Membros podem ser canais diretos (PJSIP, DAHDI) ou agentes que fazem login antes de receber chamadas.


### Estratégias

As chamadas são distribuídas entre os membros de acordo com uma destas estratégias:

- ringall: Chama todos os canais disponíveis até que alguém atenda.
- leastrecent: Distribui para o membro menos recente.
- fewestcalls: Distribui para o membro com menos chamadas.
- random: Chama uma interface aleatória.
- wrandom: Chama uma interface aleatória, mas usa a penalidade do membro como um peso ao calcular sua métrica.
- rrmemory: Usa round robin com memória; ele lembra onde parou com a chamada na última passagem.
- rrordered: O mesmo que rrmemory, exceto que a ordem dos membros da fila no arquivo de configuração é preservada.
- linear: Chama os membros na ordem em que estão listados em queues.conf; para membros dinâmicos, na ordem em que foram adicionados.

A estratégia mais antiga `roundrobin` foi descontinuada no Asterisk 1.4. Ela não é mais uma estratégia documentada e não deve ser usada: no Asterisk 22, o analisador ainda aceita a palavra `roundrobin`, mas apenas como um alias de compatibilidade com versões anteriores que mapeia para `rrmemory`. Use `rrmemory` (ou `rrordered`) explicitamente. A lista acima é o conjunto de estratégias documentadas para a opção `strategy` no Asterisk 22 `queues.conf`.

## Agentes

Agentes são implementados como canais proxy. Eles podem ser usados dentro de filas. Outro uso para os canais de agente é a mobilidade de extension. O usuário pode fazer login usando qualquer telefone e receber suas chamadas. Isso permite que um usuário vá para qualquer sala para transformá-la em um escritório. Você pode discar para um agente no dialplan usando dial(agent/<name>). Você define os agentes no arquivo agents.conf.

![Mobilidade do agente: o usuário atende qualquer telefone, disca uma extension de login e informa o número do agente e a senha; após o sucesso de agentlogin(), o agente (Agent 300) está pronto para receber chamadas, e você pode verificar o status com o comando de CLI `agent show all`](../images/14-queues-fig05.png)

### Grupos de Agentes

Você pode optar por usar grupos de agentes. Esta função não leva em consideração estratégias de ACD. Você provavelmente preferirá listar todos os agentes individualmente. Se você quiser transferir para um grupo de agentes, pode usar `queues.conf`:

```
member => agent/@1    ; any agent in group 1
member => agent/:1,1  ; any agent in group 1, wait for first available
```

### O arquivo de configuração para agentes

Os agentes são definidos no arquivo agents.conf. Abaixo está um exemplo funcional do arquivo.

![Um exemplo funcional do arquivo agents.conf: uma seção geral com persistentagents, uma seção de agentes com os parâmetros padrão (autologoff, ackcall, endcall, wrapuptime, musiconhold) e duas definições de agente (300 e 301)](../images/14-queues-fig06.png)

## Aplicações relacionadas a ACD

O sistema de filas do Asterisk disponibiliza diversas aplicações para implementar filas no dialplan. Abaixo, mostramos algumas delas.

### A aplicação queue()

Esta aplicação coloca chamadas recebidas em uma fila de chamadas específica, conforme definido em queues.conf. A string de opções pode conter zero ou mais opções de uma única letra (mostradas na figura abaixo). Além de transferir a chamada, uma chamada pode ser estacionada e, em seguida, atendida por outro usuário. A URL opcional será enviada à parte chamada se o canal oferecer suporte a isso. O parâmetro AGI opcional configurará um script AGI para ser executado no canal da parte chamadora assim que ela for conectada a um membro da fila. O timeout fará com que a fila falhe após um número especificado de segundos, verificado entre cada ciclo de timeout e retry. Esta aplicação define a variável de status QUEUE após a conclusão:

![A aplicação queue(): sua sintaxe `Queue(queuename,options,URL,announceoverride,timeout,AGI)` — o Asterisk 22 separa os argumentos com vírgulas (a forma antiga com pipe `|` não existe mais) — e as opções de uma única letra disponíveis (d, h, H, n, i, r, t, T, w, W)](../images/14-queues-fig07.png)

- TIMEOUT
- FULL
- JOINEMPTY
- LEAVEEMPTY
- JOINUNAVAIL
- LEAVEUNAVAIL

### A aplicação agentlogin()

Esta aplicação solicita que o agente faça login no sistema. Ela sempre retorna -1. Enquanto estiver logado, o agente que recebe chamadas ouvirá um bipe quando uma nova chamada chegar. O agente pode encerrar a chamada pressionando a tecla *.

![A aplicação agentlogin(): sua sintaxe `AgentLogin([AgentNo][|options])` e a opção `s` para um login silencioso que não anuncia a confirmação de login](../images/14-queues-fig08.png)

### A aplicação addQueueMember()

Esta aplicação adiciona dinamicamente um dispositivo (por exemplo, PJSIP/3000) a uma fila. Se o dispositivo já existir, ela retornará um erro.

```
AddQueueMember(queuename[|interface][|penalty]):
```

#### A aplicação removeQueueMember()

Esta aplicação remove dinamicamente um dispositivo da fila. Se o dispositivo não pertencer à fila, ela retornará um erro.

```
RemoveQueueMember(queuename[|interface])
```

### Aplicações de suporte e comandos CLI

Algumas aplicações e comandos de console são capazes de auxiliar no trabalho com filas. O que se segue descreve o que cada aplicação faz:

![Aplicações de suporte (AddQueueMember, RemoveQueueMember) e comandos CLI (agent show all, queue show, queue show <name>) usados para gerenciar filas em tempo de execução](../images/14-queues-fig09.png)

## Tarefas de configuração

A figura abaixo resume as principais tarefas para criar um sistema de fila funcional.

![As tarefas de configuração do ACD: (1) criar a fila de chamadas (obrigatório), (2) definir parâmetros do agente (opcional), (3) criar agentes (opcional), (4) colocar a fila no dialplan (obrigatório), (5) configurar a gravação do agente (opcional) e (6) verificar com agent show all e queue show (opcional)](../images/14-queues-fig10.png)

Passo 1: Criar a fila de chamadas no arquivo queues.conf:

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

Passo 2: Definir parâmetros do agente no arquivo agents.conf:

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

Passo 3: Criar os agentes no arquivo agents.conf:

```
;agent => agentid,agentpassword,name
[agents]
agent => 300,300,Test Rep - 300
agent => 301,301,Test Rep . 301
agent => 600,600,Test Ver - 600
agent => 601,601,Test Ver . 601
```

Passo 4: Inserir a fila no dialplan, no arquivo `extensions.conf`:

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

### Configurar a gravação da fila

As chamadas podem ser gravadas usando a aplicação MixMonitor do Asterisk. (A aplicação independente Monitor foi removida no Asterisk 22, e a opção `monitor-type` do queues.conf agora aceita apenas MixMonitor.) A gravação pode ser ativada dentro da aplicação de fila, começando quando a chamada é efetivamente atendida. Apenas chamadas bem-sucedidas são gravadas, e nenhuma gravação é realizada enquanto as pessoas estão ouvindo MOH. Para habilitar o monitoramento, basta especificar monitor-format. Este recurso é desativado por padrão. Você pode definir o nome do arquivo para a gravação usando `Set(MONITOR_FILENAME=<filename>)`; caso contrário, ele usará `MONITOR_FILENAME=${UNIQUEID}`.

No arquivo queues.conf:

```
monitor-format = wav
monitor-type = MixMonitor
monitor-join = yes
```

## Operação de fila

Os exemplos a seguir explicam como usar a fila.

1. Login do agente. Exemplo: Um agente na fila de telemarketing atende o telefone e disca #9000. O agente ouve uma mensagem de login inválido e é solicitado a informar seu nome e senha. A fila de auditoria segue o mesmo procedimento.
2. Fila. Uma vez na fila, o agente ouvirá MOH, se definido. Quando uma chamada entrar na fila de telemarketing, o agente ouvirá um bipe e será conectado a essa chamada.
3. Finalização da chamada. Quando o agente termina a chamada, ele/ela pode:
   - Pressionar ‘*’ para desconectar e permanecer na fila.
   - Desconectar o telefone, desconectando-se assim da fila.
   - Pressionar #8000 para transferir a chamada para auditoria.

## Recursos avançados

O sistema de filas do Asterisk possui alguns recursos avançados para priorizar determinados clientes e agentes, bem como habilitar um menu de usuário.

### Menu de usuário

Você pode definir um menu para um usuário enquanto ele aguarda na fila usando extensões de um único dígito. Para habilitar esta opção, defina um context na configuração de filas queues.conf.

### Penalidade

Agentes podem ser configurados com uma penalidade. Uma fila enviará as chamadas primeiro para os usuários com valores de penalidade mais baixos. Por exemplo, como sabemos que nossos clientes adoram a Susan e sua voz suave, podemos optar por atribuir a prioridade 0 a ela. Alternativamente, o agente chamado Uber, que tem menos experiência, é menos preferido para o atendimento ao cliente; portanto, atribuímos uma prioridade 10 a este agente. No arquivo queues.conf:

```
[customerservice]
member=300,0,Susan the excellent agent
member=300,10,Uber the new guy
```

### Prioridade

As filas operam no modo FIFO (primeiro a entrar, primeiro a sair). Se você quiser dar prioridade a clientes especiais (platinum, gold), você pode configurar prioridades diferenciadas. Para clientes platinum ou gold:

```
exten=>111,1,Playback(welcome)
exten=>111,2,Set(QUEUE_PRIO=10)
exten=>111,3,Queue(customerservice)
```

Clientes blue:

```
exten=>112,1,Playback(welcome)
exten=>112,2,Set(QUEUE_PRIO=5)
exten=>112,3,Queue(customerservice)
```

## A aplicação agentcallbacklogin() foi removida

A aplicação `agentcallbacklogin()` foi descontinuada pela Digium no Asterisk 1.4 (julho de 2006) e não está mais disponível no Asterisk 22. A abordagem recomendada é utilizar `AddQueueMember()` com uma interface PJSIP para adicionar dinamicamente membros do tipo callback a uma fila. O documento `queues-with-callback-members.txt` foi incluído em diretórios de versões mais antigas do Asterisk `/doc` para orientação de migração.

O antigo driver de canal `chan_agent` foi igualmente removido; sua funcionalidade foi reescrita como o módulo `app_agent_pool`, que é o que fornece `AgentLogin()`, `AgentRequest()` e a função de dialplan `AGENT()` no Asterisk 22 (estes ainda estão presentes — `app_agent_pool.so` acompanha uma compilação padrão do 22). Para call centers modernos, no entanto, o padrão é ignorar completamente os canais de agente e adicionar o dispositivo PJSIP do agente diretamente à fila com `AddQueueMember()`/`RemoveQueueMember()` (estaticamente em `queues.conf`, ou dinamicamente a partir do dialplan ou AMI). Isso é mais simples, integra-se perfeitamente ao device state do PJSIP e é a abordagem utilizada ao longo deste capítulo.

## Estatísticas de fila

Todos os eventos das filas são registrados em /var/log/asterisk/queue_log. O formato do log de fila é publicado no documento queuelog.txt no diretório /doc da documentação do Asterisk. Abaixo estão alguns dos eventos mais importantes registrados.

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

Você pode criar seu próprio utilitário para processar esses eventos ou usar um pacote de estatísticas pronto para uso:

- **QueueMetrics** (<https://www.queuemetrics.com/>) – um pacote comercial, mantido ativamente, que analisa o `queue_log` e permanece como uma das ferramentas de relatório mais completas para call centers Asterisk.
- **Desenvolva o seu próprio** – como o formato `queue_log` acima é estável e bem documentado, é simples analisá-lo com um pequeno script (Python, etc.) e alimentar os eventos em um banco de dados ou painel.

Para uma abordagem mais orientada a eventos do que monitorar o `queue_log`, a **Asterisk REST Interface (ARI)** e as ações do **AMI** `QueueSummary`/`QueueStatus` permitem que você crie painéis de fila ao vivo e integrações personalizadas baseadas no estado da fila em tempo real, em vez de analisar logs após o fato. A ARI é a superfície de integração moderna e suportada para esse tipo de trabalho no Asterisk 22.

## Resumo

Neste capítulo, você aprendeu como utilizar um ACD, sua arquitetura e como configurá-lo. Alguns recursos avançados, como prioridades e penalidades, também foram apresentados.

## Quiz

1. Quais das seguintes são estratégias de distribuição de fila válidas no `queues.conf` (escolha todas as que se aplicam)?
   - A. ringall
   - B. roundrobin
   - C. leastrecent
   - D. fewestcalls
   - E. rrmemory
   - F. linear
2. Você pode gravar uma conversa entre um agente e um cliente a partir de dentro da fila configurando a opção ___ no arquivo `queues.conf`.
3. Qual `strategy` chama os membros na ordem exata em que estão listados no `queues.conf`?
   - A. random
   - B. wrandom
   - C. linear
   - D. fewestcalls
4. Quando o agente termina uma chamada no exemplo de telemarketing, quais ações ele pode tomar (escolha todas as que se aplicam)?
   - A. Pressionar `*` para desconectar e permanecer na fila
   - B. Desligar o telefone e desconectar da fila
   - C. Pressionar `#8000` para transferir a chamada para auditoria
   - D. Pressionar `#` para sair de todas as filas imediatamente
5. Quais duas tarefas são *necessárias* para obter uma fila funcional (escolha todas as que se aplicam)?
   - A. Criar a fila
   - B. Criar os agentes
   - C. Configurar os parâmetros do agente
   - D. Configurar a gravação
   - E. Colocar a fila no dialplan
6. Em uma fila de chamadas, você pode oferecer um menu de dígito único que o chamador pode discar enquanto aguarda. Isso é habilitado definindo um(a) ___ na seção `queues.conf` da fila:
   - A. agent
   - B. menu
   - C. context
   - D. application
7. As aplicações de suporte `AddQueueMember()` e `RemoveQueueMember()` são usadas no ___ para adicionar ou remover membros em tempo de execução:
   - A. dialplan
   - B. command-line interface
   - C. queues.conf
   - D. agents.conf
8. Como o chan_sip foi removido no Asterisk 21, um membro de fila estático deve referenciar um canal como ___ em vez de `SIP/1001`.
9. O parâmetro `wrapuptime` é o tempo mínimo após um agente desconectar uma chamada antes que a fila envie uma nova chamada para esse agente.
   - A. True
   - B. False
10. Um chamador pode receber uma posição mais alta na mesma fila definindo a variável de canal `QUEUE_PRIO` antes de chamar `Queue()`.
    - A. True
    - B. False

**Respostas:** 1 — A, C, D, E, F (roundrobin não é uma estratégia documentada; no Asterisk 22, ela sobrevive apenas como um alias obsoleto para rrmemory) · 2 — `monitor-format` (a gravação a partir da fila é habilitada especificando `monitor-format`; no Asterisk 22, `monitor-type` suporta apenas MixMonitor) · 3 — C (linear) · 4 — A, B, C (`*` desconecta e permanece; `#` não é uma tecla de saída de todas as filas) · 5 — A, E · 6 — C (a opção `context`) · 7 — A (o dialplan) · 8 — `PJSIP/1001` (qualquer interface `PJSIP/`) · 9 — True · 10 — True
