# Recursos avançados do dialplan

O Capítulo 3 discutiu os fundamentos de um dialplan. Por razões didáticas, não explicamos todos os recursos, mas apenas alguns dos mais importantes. Este capítulo se aprofundará mais no dialplan, descrevendo técnicas avançadas, novas aplicações e conceitos.

## Objetivos

Ao final deste capítulo, você deverá ser capaz de:

- Simplificar suas entradas de extension
- Lidar com a segurança do dialplan e filtrar extensions
- Receber chamadas usando um menu de IVR
- Usar sub-rotinas para evitar reescritas desnecessárias
- Implementar alguma segurança no dialplan usando "Include"
- Implementar o recurso de follow-me usando AsteriskDB
- Implementar comportamento de horário de expediente em seu PBX
- Usar o comando switch para transferir para outro PBX
- Implementar o privacy manager
- Implementar voicemail
- Implementar um diretório corporativo

## Simplificando seu dialplan

Você pode simplificar seu dialplan usando a palavra-chave “same” para definir uma extension. Isso deve reduzir o número de erros de digitação no dialplan. Confira o exemplo abaixo:

```
exten => 4000,1,NoOp()
same  =>      n,Dial(PJSIP/005C2B313E22)
```

## Segurança do dialplan

Uma falha foi descoberta no dialplan do Asterisk que permite a um usuário injetar um novo canal e um número de discagem em seu dialplan. Vamos supor que você tenha a seguinte linha em seu servidor `exten=>_X.,1,Dial(PJSIP/${EXTEN})` e algum usuário mal-intencionado discou o número `3000&DAHDI/1/011551123456789` no softphone. O protocolo SIP, por padrão, aceita quaisquer caracteres alfanuméricos, portanto, a extension discada irá, na verdade, disparar duas chamadas: uma para o canal PJSIP/3000 e a outra para o canal DAHDI/011551123456789, que é um número internacional. Assim, qualquer usuário com acesso a uma extension pode, na verdade, discar para qualquer lugar do mundo. A maneira mais fácil de evitar esse comportamento é filtrar os números antes de chamar a aplicação dial. A função FILTER() é muito útil para isso. Exemplo:

```
exten=>_X.,1,DIAL(PJSIP/${FILTER(0-9,${EXTEN})})
```

A aplicação de filtro permitirá que você filtre todos os caracteres do número discado, exceto os números de 0 a 9. Mais informações podem ser encontradas no arquivo README-SERIOUSLY.bestpractices.txt disponível no Asterisk.

## Recebendo chamadas usando um menu IVR.

Na última seção, você recebeu todas as chamadas usando DID ou encaminhamento para a operadora. Agora você aprenderá como implementar um menu IVR, bem como criar um serviço de atendimento automático. Antes de entrar nos detalhes, vamos examinar algumas novas aplicações. Colocamos a saída do comando `core show application` abaixo simplesmente para facilitar para os leitores. Você mesmo pode obter essas descrições usando `core show application <application_name>`.

### A aplicação Background()

Esta aplicação reproduzirá a lista de arquivos fornecida enquanto aguarda que uma extension seja discada pelo canal chamador. Para continuar aguardando dígitos após esta aplicação ter terminado de reproduzir os arquivos, a aplicação WaitExten deve ser usada. A opção langoverride especifica explicitamente qual idioma tentar usar para os arquivos de som solicitados. Qualquer context especificado será o context do dialplan que esta aplicação usa ao sair para uma extension discada. Se um dos arquivos de som solicitados não existir, o processamento da chamada será encerrado. Opções:

- s - Faz com que a reprodução da mensagem seja ignorada se o canal não estiver no estado 'up' (ou seja, ainda não foi atendido). Se isso acontecer, a aplicação retornará imediatamente.
- n - Não atenda o canal antes de reproduzir os arquivos.
- m - Interrompa apenas se um dígito pressionado corresponder a uma extension de um dígito no context de destino.

### A aplicação Record()

Esta aplicação grava do canal em um nome de arquivo fornecido. Se o arquivo existir, ele será sobrescrito.

![10-dialplan-advanced-features figure 1](../images/10-dialplan-advanced-features-img01.png)

- 'format' é o formato do tipo de arquivo a ser gravado (wav, gsm, etc).
- 'silence' é o número de segundos de silêncio permitidos antes de retornar.
- 'maxduration' é a duração máxima da gravação em segundos; se estiver ausente ou for zero, não há máximo.
- 'options' pode conter qualquer uma das seguintes letras:
    - `a` — anexa a uma gravação existente em vez de substituí-la
    - `n` — não atenda, mas grave mesmo assim se a linha ainda não tiver sido atendida
    - `q` — silencioso (não reproduz um tom de bipe)
    - `s` — ignora a gravação se a linha ainda não tiver sido atendida
    - `t` — usa a tecla terminadora alternativa `*` (DTMF) em vez da padrão `#`
    - `x` — ignora todas as teclas terminadoras (DTMF) e continua gravando até o desligamento

Se o nome do arquivo contiver %d, esses caracteres serão substituídos por um número incrementado em um cada vez que o arquivo for gravado. Use core show file formats para ver os formatos disponíveis em seu sistema. O usuário pode pressionar # para encerrar a gravação e continuar para a próxima prioridade. Se o usuário desligar durante uma gravação, todos os dados serão perdidos e a aplicação será encerrada.

### A aplicação Playback()

Esta aplicação reproduz nomes de arquivos fornecidos (não inclua a extensão). Opções também podem ser incluídas após um símbolo de barra vertical (pipe). A opção 'skip' faz com que a reprodução da mensagem seja ignorada se o canal não estiver no estado 'up' (ou seja, ainda não foi atendido).

![10-dialplan-advanced-features figure 2](../images/10-dialplan-advanced-features-img02.png)

![10-dialplan-advanced-features figure 3](../images/10-dialplan-advanced-features-img03.png)

Se 'skip' for especificado, a aplicação retornará imediatamente caso o canal não esteja fora do gancho. Caso contrário, a menos que 'noanswer' seja especificado, o canal será atendido antes que o som seja reproduzido. Nem todos os canais suportam a reprodução de mensagens enquanto ainda estão no gancho. Se 'j' for especificado, a aplicação saltará para a prioridade n+101 quando o arquivo não existir, se presente. Esta aplicação define a seguinte variável de canal após a conclusão:

- PLAYBACKSTATUS — o status da tentativa de reprodução como uma string de texto, uma das seguintes:
    - `SUCCESS`
    - `FAILED`

### A aplicação Read()

Esta aplicação lê um número predeterminado de dígitos de string, um certo número de vezes, do usuário para a variável fornecida.

- filename -- arquivo a ser reproduzido antes de ler os dígitos ou tom com a opção i
- maxdigits -- número máximo aceitável de dígitos. Para de ler após maxdigits terem sido inseridos (sem exigir que o usuário pressione a tecla #). O padrão é 0 - sem limite - para aguardar que o usuário pressione a tecla #. Qualquer valor abaixo de 0 significa o mesmo. O valor máximo aceito é 255.

![10-dialplan-advanced-features figure 4](../images/10-dialplan-advanced-features-img04.png)

![10-dialplan-advanced-features figure 5](../images/10-dialplan-advanced-features-img05.png)

- option -- as opções são `s`, `i`, `n`:
    - `s` — retorna imediatamente se a linha não estiver ativa
    - `i` — reproduz filename como um tom de indicação do seu `indications.conf`
    - `n` — lê dígitos mesmo se a linha não estiver ativa
- attempts -- se maior que 1, o número de tentativas que serão feitas caso nenhum dado seja inserido
- timeout -- Um número inteiro de segundos para aguardar uma resposta de dígito. Se maior que 0, esse valor substituirá o timeout padrão.

A aplicação read() deve desconectar se a função falhar ou apresentar erros.

### A aplicação Gotoif()

Esta aplicação fará com que o canal chamador salte para o local especificado no dialplan com base na avaliação da condição fornecida. O canal continuará em 'labeliftrue' se a condição for verdadeira, ou 'labeliffalse' se a condição for falsa. Os rótulos (labels) são especificados com a mesma sintaxe usada na aplicação Goto. Se o rótulo escolhido pela condição for omitido, nenhum salto será realizado; em vez disso, a execução continua com a próxima prioridade no dialplan.

### Laboratório: Construindo um menu IVR passo a passo

Vamos criar um menu IVR com a seguinte funcionalidade. Quando discado, o IVR reproduz um arquivo de áudio com a mensagem “Bem-vindo à XYZ Corporation; pressione 1 para vendas, 2 para suporte técnico, 3 para treinamento ou aguarde para falar com um representante.” Os dígitos direcionam o chamador da seguinte forma:

- `1` — transfere para vendas (PJSIP/4001)
- `2` — transfere para suporte técnico (PJSIP/4002)
- `3` — transfere para treinamento (PJSIP/4003)
- Nenhum dígito pressionado — transfere para a operadora (PJSIP/4000)

**Passo 1 – Grave as mensagens (prompts)**

Vamos criar uma extension para gravar as mensagens. Para gravar uma mensagem, disque de um softphone para `9003<filename>` (por exemplo, `9003welcome`). Quando ouvir o bipe, comece a gravar; pressione `#` para parar. Você ouvirá um bipe e o sistema reproduzirá a mensagem gravada.

**Passo 2 – Crie a lógica do menu**

Ao discar a extension 9004, o processamento salta para o menu na extension `s`, prioridade 1.

### Correspondência conforme você disca

Este é um menu de configuração da empresa para receber chamadas. A aplicação `Background()` reproduz a mensagem de boas-vindas e então aguarda pelos dígitos, fazendo a correspondência do que o chamador disca com as extensions definidas no context atual.

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

Quando você disca para esta empresa, a mensagem de boas-vindas é reproduzida primeiro. Depois disso, o Asterisk aguarda que um dígito seja discado:

| Número discado | Ação do Asterisk |
|---------------|-----------------|
| 1 | Chama imediatamente `Dial(DAHDI/1)` |
| 2 | Aguarda o timeout, então chama `Dial(DAHDI/2)` |
| 21 | Chama imediatamente `Dial(DAHDI/3)` |
| 22 | Chama imediatamente `Dial(DAHDI/4)` |
| 3 | Aguarda o timeout, então desconecta |
| 31 | Chama imediatamente `Dial(DAHDI/5)` |
| 32 | Chama imediatamente `Dial(DAHDI/6)` |

É importante evitar ambiguidades nos menus. Todos querem ser atendidos rapidamente. Por esse motivo, você não deve usar os números 2, 21 ou 22.

### Laboratório: Usando a aplicação Read()

Por favor, tente o laboratório com a aplicação read(). A aplicação read aceita dígitos do usuário e os insere na variável especificada; você pode então usar a aplicação gotoif para redirecionar a chamada.

## Inclusão de context

Um context pode incluir o conteúdo de outro context. No exemplo acima, qualquer canal pode discar para qualquer extension no context internal, mas apenas o canal 4003 pode discar para extensions internacionais. Você pode usar a inclusão de context para facilitar a criação do dialplan. Usando a inclusão de context, você pode controlar quem tem acesso a quais extensions.

### Solucionando a mensagem “number not found”

É muito comum receber a mensagem “number not found”. A maioria das pessoas confunde o conceito de contexts incluídos porque ele realmente não é intuitivo. Como regra geral, primeiro vá para o arquivo de configuração do canal de entrada, como `pjsip.conf`, `chan_dahdi.conf` e `iax.conf`, e determine o context atual. Em seguida, vá para o dialplan no arquivo extensions.conf e verifique se o número discado pode ser encontrado naquele context. Se não, algo está errado com seu dialplan. As regras de ouro dos contexts são: 1. Um canal só pode discar números dentro do mesmo context que o canal. 2. O context onde a chamada é processada é definido no arquivo de configuração do canal de entrada (`chan_dahdi.conf`, `iax.conf`, `pjsip.conf`).

## Usando a instrução switch

Você pode enviar o processamento do dialplan para outro servidor usando o comando switch. Você precisará do nome e da chave do outro servidor. O context é o context de destino.

![10-dialplan-advanced-features figura 6](../images/10-dialplan-advanced-features-img06.png)

## Ordem de processamento do dialplan

Quando o Asterisk recebe uma chamada, ele procura no context definido pelo canal. Em alguns casos, se mais de um padrão corresponder ao número discado, o Asterisk não consegue processar a chamada exatamente da maneira que você imagina. Você pode visualizar a ordem de correspondência usando o comando CLI dialplan show. Exemplo: digamos que você queira discar 912 para rotear para um trunk analógico (DAHDI/1) e todos os outros números começando com 9 para outro trunk analógico (DAHDI/2). Você escreveria algo como:

```
[example]
exten=>_912.,1,Dial(DAHDI/1/${EXTEN})
exten=>_9.,1,Dial(DAHDI/2/${EXTEN})
```

Se dois padrões corresponderem a uma extension, você pode controlar qual extension é processada primeiro usando os contexts incluídos. Um context incluído é processado depois de um padrão no mesmo context.

## A diretiva #INCLUDE

Devemos usar um arquivo grande ou vários arquivos? Você pode usar a diretiva #include <filename> para incluir outros arquivos em seu extensions.conf. Por exemplo, poderíamos criar um users.conf para usuários locais e um services.conf para serviços especiais. Tenha cuidado para não confundir #include <filename> com o

```
include=>context statement.
```

## Sub-rotinas com GOSUB

Em versões mais antigas do Asterisk, existia o comando Macro. Este comando foi descontinuado há muito tempo em favor do GOSUB. Demonstraremos aqui como criar sub-rotinas para processamento de voicemail de uma maneira fácil e organizada. Formato do comando:

```
gosub([[context,]exten,]priority[(arg1[,...][,argN])])
```

O comando GOSUB está disponível desde o Asterisk 1.6 e suporta a passagem de argumentos (disponíveis dentro da sub-rotina como `${ARG1}`, `${ARG2}`, e assim por diante). Com argumentos, agora é possível substituir completamente os antigos comandos Macro. Macros (`app_macro`) foram removidas no Asterisk 21; você deve usar GOSUB para sub-rotinas.

### Criando a sub-rotina

A definição é muito semelhante. Observe a sub-rotina abaixo definida para voicemail com o nome stdexten (escolha o nome que desejar). Após chamar o comando Dial com o primeiro argumento (nome do canal), verificamos o ${DIALSTATUS} para enviar a lógica da chamada para o próximo passo.

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

### Chamando uma sub-rotina

Preste atenção ao chamar a sub-rotina para usar parênteses antes dos parâmetros.

```
exten=>6000,1,Gosub(stdexten,s,1(PJSIP/6000,${EXTEN}))
exten=>6001,1,Gosub(stdexten,s,1(PJSIP/6001,${EXTEN}))
exten=>6002,1,Gosub(stdexten,s,1(PJSIP/6002,${EXTEN}))
exten=>6003,1,Gosub(stdexten,s,1(PJSIP/6003,${EXTEN}))
```

## Usando o Asterisk DB

Para implementar encaminhamento de chamadas e listas negras, precisamos de alguma forma de armazenar e restaurar dados. Felizmente, o Asterisk fornece um mecanismo para armazenar e recuperar dados de um banco de dados integrado chamado AstDB. No Asterisk moderno (incluindo o Asterisk 22), o AstDB é suportado pelo **SQLite3** (o arquivo `/var/lib/asterisk/astdb.sqlite3`); o Asterisk 1.8 e versões anteriores usavam o Berkeley DB v1. Isso é semelhante ao banco de dados de registro do Windows, usando o conceito hierárquico de família e chaves. Os dados persistem entre as reinicializações do Asterisk. A API de família/chave permanece inalterada em relação ao backend mais antigo; apenas o formato de armazenamento em disco mudou.

### Funções, aplicações e comandos da CLI

Existem algumas funções, aplicações e comandos da CLI que funcionam com o AstDB:

- variable=${DB(<family/key>)}
- DB(<family/key>)=value
- DB_EXISTS(<family/key>)

Exemplos:

```
exten=_*21*XXXX,1,Set(DB(CFIM/${CALLERID(num)})=${EXTEN:4})
exten=s,1,Set(temp=${DB(CFIM/${EXTEN})})
```

Algumas aplicações podem ser usadas para manipular o AstDB:

- DB_DELETE(<family/key>) — função que retorna e exclui uma única chave
- DBdeltree(<family>) — aplicação que exclui uma família/subárvore inteira

A antiga aplicação `DBdel()` não existe mais no Asterisk 22. Exclua uma única chave com a função de dialplan `DB_DELETE()` — por exemplo, `Set(x=${DB_DELETE(family/key)})` ou, como uma operação de escrita, `Set(DB_DELETE(family/key)=)`. `DBdeltree()` (excluir uma família/subárvore inteira) ainda é uma aplicação.

É possível usar comandos da CLI para definir e excluir chaves também:

- database del
- database put
- database show <family[/key]>
- database showkey
- database deltree
- database get

![10-dialplan-advanced-features figure 7](../images/10-dialplan-advanced-features-img07.png)

![10-dialplan-advanced-features figure 8](../images/10-dialplan-advanced-features-img08.png)

### Implementando Encaminhamento de Chamadas, DND e Listas Negras

Neste exemplo, você aprenderá como implementar o encaminhamento de chamadas imediato e o encaminhamento de chamadas quando ocupado. Usaremos *21* para programar o encaminhamento de chamadas imediato e *61* para programar o encaminhamento de chamadas quando ocupado. Para cancelar a programação, use #21# e #61#, respectivamente. Use o exemplo acima para popular o banco de dados. Famílias utilizadas:

- CFIM – Call Forward Immediate (Encaminhamento Imediato)
- CFBS – Call Forward on Busy status (Encaminhamento quando Ocupado)
- DND – Do Not Disturb (Não Perturbe)

Tente popular o banco de dados discando:

- *21* (Extensão de destino para encaminhamento de chamadas imediato)
- *61* (Extensão de destino para encaminhamento de chamadas quando ocupado)
- *41* (Extensão para ativar o não perturbe)

Use o comando da CLI database show para ver as famílias, chaves e valores adicionados.

![10-dialplan-advanced-features figure 9](../images/10-dialplan-advanced-features-img09.png)

![10-dialplan-advanced-features figure 10](../images/10-dialplan-advanced-features-img10.png)

### Encaminhamento de Chamadas, Lista Negra, DND

A sub-rotina verifica se o banco de dados contém os pares chave:valor correspondentes a CFIM, CFBS ou DND e, em seguida, os trata adequadamente. A sub-rotina a seguir chama a rotina de discagem:

```
exten=_4XXX,1,gosub(stdexten,s,1(${EXTEN}))
```

## Usando uma blacklist

A antiga aplicação `LookupBlacklist()` foi **removida** do Asterisk (ela desapareceu junto com o mecanismo legado "priority+101 jump"). No Asterisk 22, você cria uma blacklist diretamente com a função `DB_EXISTS()` (que testa a existência de uma chave e, quando encontrada, expõe seu valor em `${DB_RESULT}`) somada ao `GotoIf`. Armazene cada número bloqueado como uma chave em uma família `blacklist`, então verifique o caller ID no topo do seu context de entrada:

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

`DB_EXISTS(blacklist/${CALLERID(num)})` retorna `1` quando o número do chamador está presente no banco de dados (enviando a chamada para o context `blocked`) e `0` caso contrário, permitindo que a chamada prossiga para o `Dial()` normal.

Para inserir um número na blacklist, podemos usar o mesmo recurso de antes, usando *31* seguido pelos extensions a serem bloqueados. Para remover um número da blacklist, você deve usar #31# seguido pelo número a ser removido.

```
[apps]
exten=>_*31*X.,1,Set(DB(blacklist/${EXTEN:4})=1)
exten=>_*31*X.,2,Hangup()
exten=>_#31#X.,1,Set(x=${DB_DELETE(blacklist/${EXTEN:4})})
exten=>_#31#X.,2,Hangup()
```

Você também pode inserir os números na blacklist usando a CLI do console:

```
*CLI>database put blacklist <name/number> 1
```

Nota: Qualquer valor pode ser associado à chave. O teste `DB_EXISTS()` busca pela chave, não pelo valor. Para apagar o número da blacklist, você pode usar:

```
*CLI>database del blacklist <name/number>
```

## Contextos baseados em tempo

Na figura a seguir, temos um dialplan com três contextos. O contexto [incoming] é onde as chamadas são geralmente recebidas. Incluímos quatro linhas que alteram o comportamento dependendo da hora do sistema, conforme exemplificado abaixo:

```
include => context,<times>,<weekdays>,<mdays>,<months>
```

O Asterisk moderno (incluindo o 22) separa os campos time-include com **vírgulas**, não com pipes. A forma legada com pipe (`include => context|times|weekdays|mdays|months`) é interpretada como um nome de contexto literal simples e falha silenciosamente ao aplicar qualquer condição de tempo.

Durante o horário comercial normal, o processamento será redirecionado para o mainmenu, onde provavelmente chamará uma IVR para lidar com a chamada recebida. Se a chamada ocorrer fora do horário comercial, ela chamará a extension de segurança definida na variável ${SECURITY}. Se a extension de segurança não atender a chamada, ela será enviada para a voicemail da operadora.

![10-dialplan-advanced-features figura 11](../images/10-dialplan-advanced-features-img11.png)

![10-dialplan-advanced-features figura 12](../images/10-dialplan-advanced-features-img12.png)

## Mensagens baseadas em tempo usando gotoiftime()

A sintaxe do GotoIfTime() é mostrada abaixo.

```
GotoIfTime(times,weekdays,mdays,months[,timezone]?[labeliftrue][:labeliffalse])
```

No Asterisk 22, o separador de campos é uma **vírgula**, não uma barra vertical (a forma com barra vertical foi descontinuada no Asterisk 1.6). Um campo opcional `timezone` é suportado, e cada rótulo de ramificação utiliza a forma usual `[[context,]extension,]priority`.

Esta aplicação pode substituir o context baseado em tempo e parece ser mais fácil de entender e ler. Você pode especificar o tempo da seguinte forma:

- <timerange>=<hour>':'<minute>'-'<hour>':'<minute> |"*"
- <daysofweek>=<dayname>|<dayname>'-'<dayname>|"*"
- <dayname>="sun"|"mon"|"tue"|"wed"|"thu"|"fri"|"sat"
- <daysofmonth>=<daynum>|<daynum>'-'<daynum> |"*"
- <daynum>=número de 1 a 31
- <hour>=número de 0 a 23
- <minute>=número de 0 a 59
- <months>=<monthname>|<monthname>'-'<monthname>|"*"
- <monthname>="jan"|"feb"|"mar"|"apr"|"may"|"jun"|"jul"|"aug"|"sep"|"oct"|"nov"|"dec"

Os nomes dos dias e meses não diferenciam maiúsculas de minúsculas.

```
exten=>s,1,GotoIfTime(8:00-18:00,mon-fri,*,*?normalhours,s,1)
```

A instrução anterior transfere o processamento para a extension s no context normalhours se a chamada ocorrer entre 08:00 e 18:00, de segunda a sexta-feira.

## Usando DISA para obter um novo tom de discagem

DISA, ou "direct inward system access", é um sistema que permite aos usuários receber um segundo tom de discagem. Ele permite que os usuários disque novamente para outro destino. É frequentemente usado por técnicos ao fazer chamadas de longa distância para suporte técnico nos fins de semana; em vez de discar de suas casas diretamente para o destino, eles ligam para o número DISA do escritório, recebem um tom de discagem e então ligam para o destino. As tarifas de longa distância são cobradas na empresa em vez do telefone residencial.

```
DISA(passcode|filename[,context[,cid[,mailbox[@context][,options]]]])
```

Exemplo:

```
exten => s,1,DISA(no-password,default)
```

Usando a instrução anterior, o usuário liga para o PBX e — sem exigir nenhuma senha — recebe um tom de discagem. Qualquer chamada usando DISA será processada usando o context `default`. Os argumentos para esta aplicação incluem uma senha global ou uma senha individual dentro de um arquivo. Se nenhum context for especificado, o context `disa` é assumido. Se você usar um arquivo de senha, o caminho completo deve ser especificado. Um caller ID também pode ser especificado para a discagem externa do DISA. Exemplo:

```
exten => s,1,DISA(numeric-passcode,default,"Flavio" <4830258590>)
```

O Asterisk 22 usa vírgulas como separadores de argumentos (a forma com pipe foi descontinuada na versão 1.6). O primeiro argumento é uma senha única ou o caminho para um arquivo de senhas, e o context padrão quando nenhum é fornecido é `disa`.

## Limitar chamadas simultâneas

A função GROUP() permite que você conte quantos canais ativos você tem em um grupo ao mesmo tempo. Exemplo: Você tem uma filial no Rio de Janeiro, onde os telefones seguem o padrão “_214X”. Este local é atendido por uma linha dedicada, com 64K reservados para largura de banda de voz. Neste caso, o número máximo de chamadas permitidas é 2 (G.729, cerca de 31.2K por chamada). Para limitar as chamadas para o Rio a duas:

```
exten=>_214X,1,set(GROUP()=Rio)
exten=>_214X,n,Gotoif($[${GROUP_COUNT()} > 1]?outoflimit)
exten=>_214X,n,Dial(PJSIP/${EXTEN})
exten=>_214X,n,hangup
exten=>_214X,n(outoflimit),playback(callsexceedcapacity)
exten=>_214X,n,hangup
```

## Voicemail

Voicemail é um sistema de atendimento telefônico computadorizado que grava mensagens de voz recebidas, salvando-as em disco ou enviando-as por e-mail. Às vezes, ele possui um diretório onde você pode pesquisar caixas postais por nome. No passado, os sistemas de voicemail eram muito caros. Agora, com a telefonia IP, o voicemail está se tornando um recurso padrão.

Para configurar o voicemail, você deve seguir as etapas abaixo.

**Passo 1: Edite `voicemail.conf` e defina os parâmetros gerais.**

- `format` — codec usado para gravar a mensagem (por exemplo, wav49, wav, gsm)
- `serveremail` — de quem a notificação por e-mail deve parecer vir
- `maxmsg` — número máximo de mensagens na caixa postal; após esse limite, as mensagens são descartadas
- `maxsecs` — duração máxima de uma mensagem de voicemail, em segundos
- `minsecs` — duração mínima de uma mensagem, em segundos; abaixo desse limite, nenhuma mensagem é gravada
- `maxsilence` — quantos segundos de silêncio devem ser tratados como o fim da mensagem

**Passo 2: Edite `voicemail.conf` e crie as caixas postais dos usuários.**

### Voicemail.conf

Uma caixa postal é definida com uma linha por caixa, no formato:

```
mailboxID => pincode,fullname,email,pager-email,options
```

Os campos são:

- **MailboxID** — geralmente o número da extension
- **Pincode** — senha para acessar o sistema de voicemail
- **Full name** — usado pelo aplicativo de diretório
- **E-mail** — endereço para notificação de voicemail
- **Pager e-mail** — endereço para notificação via gateway de SMS ou pager
- **Options** — opções por caixa postal (as mesmas opções que em `[general]`, mas aplicadas a esta caixa postal)

O voicemail possui várias opções que controlam seu comportamento. Por enquanto, manteremos as opções padrão e nos concentraremos na definição da caixa postal. Após a seção `[general]` no arquivo, você começa a configurar os IDs das caixas postais, cada um em seu próprio context. Exemplo:

```
[general]
[default]
1234=>1234,SomeUser,email@address.com,pager@address.com,saycid=yes|dialout=fromvm|callback=fromvm|review=yes|operator=yes
```

Por favor, verifique as opções avançadas no arquivo `voicemail.conf`.

**Passo 3: Configure o arquivo `extensions.conf`.**

A sub-rotina `stdexten` mostrada anteriormente (em *Subroutines with GOSUB*) é exatamente o manipulador de chamada/voicemail que você precisa aqui: ele disca para a extension e usa o valor da variável de canal `${DIALSTATUS}` para redirecionar o fluxo da chamada para a saudação de voicemail apropriada (`b` para ocupado, `u` para indisponível). Chame-a com `Gosub(stdexten,s,1(PJSIP/<device>,<mailbox>))` a partir de cada extension em `extensions.conf`.

## Usando a aplicação VoiceMailMain()

A aplicação voicemailmain() é usada para configurar a caixa postal. Os usuários podem discar para a aplicação, gravar sua saudação e ouvir suas mensagens de voz. Para chamar a aplicação no dialplan, use:

```
exten=>9000,1,VoiceMailMain()
```

Abaixo, você encontrará uma lista das opções disponíveis para a aplicação.

### Sintaxe da aplicação Voicemail

Esta aplicação permite que a parte chamadora deixe uma mensagem para uma lista especificada de caixas postais. Quando múltiplas caixas postais são especificadas, a saudação será obtida da primeira caixa postal especificada. A execução do dialplan será interrompida se a caixa postal especificada não existir. A sintaxe é mostrada abaixo:

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

![10-dialplan-advanced-features figura 13](../images/10-dialplan-advanced-features-img13.png)

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

Em todos os casos, o arquivo beep.gsm será reproduzido antes que a gravação comece. As mensagens de voicemail serão armazenadas no diretório inbox.

```
/var/spool/asterisk/voicemail/context/boxnumber/INBOX/
```

Se um chamador pressionar 0 (zero) durante o anúncio, ele será redirecionado para a extension ‘o’ (out) no context atual do voicemail. Isso pode ser usado para sair para a telefonista. Se, durante a gravação, o chamador pressionar # ou o limite de silêncio expirar, a gravação é interrompida e a chamada segue para a próxima prioridade. Certifique-se de tratar a chamada após o voicemail ser reproduzido, como mostrado abaixo.

```
exten=>somewhere,5,Playback(Goodbye)
exten=>somewhere,6,Hangup
```

### Marcando mensagens de voicemail como urgentes

Você pode marcar algumas mensagens como "urgentes". Dois métodos estão disponíveis para isso:

- Passe a opção ‘U’ na aplicação voicemail()
- Especifique review=yes no arquivo voicemail.conf. Se usar esta opção, o usuário poderá marcar a mensagem como urgente após gravar as instruções de voz.

## Enviando voicemail para e-mail

Em alguns casos (como o meu), nós simplesmente não usamos a aplicação voicemailmain() para ler e-mail. É mais simples e prático enviar todas as mensagens para o e-mail com o áudio anexado. Usando os parâmetros ‘attach’ e ‘delete’, você pode enviar todos os e-mails para o e-mail e excluí-los da caixa postal.

```
attach=yes
delete=yes
```

Para enviar voicemail para e-mail, a aplicação voicemail usa o message transfer agent (MTA), um componente do seu sistema operacional. O Debian usa o Exim como MTA. A aplicação que envia o e-mail é definida no parâmetro ‘mailcmd’.

```
mailcmd =/usr/sbin/sendmail -t
```

Na distribuição Debian do Linux, o MTA é o Exim. Para configurar o Exim no Debian, use:

```
dpkg-reconfigure exim4-config
```

Você pode optar por fazer seu MTA enviar um e-mail diretamente via SMTP ou um smarthost (geralmente o servidor de e-mail da sua empresa). Verifique com seu administrador de e-mail a melhor maneira de enviar e-mail do servidor Asterisk para o seu servidor de e-mail.

## Personalizando a mensagem de e-mail

Você pode controlar como as mensagens são enviadas configurando as seguintes variáveis: Variáveis para o assunto do e-mail e para o corpo do e-mail:

- VM_NAME
- VM_DUR
- VM_MSGNUM
- VM_MAILBOX
- VM_CIDNUM
- VM_CIDNAME
- VM_CALLERID
- VM_DATE

O corpo e o assunto do e-mail são criados a partir de um modelo que você define na seção `[general]` do `voicemail.conf`. Você pode modificar tanto o corpo quanto o assunto, mas o limite de tamanho da mensagem é de 512 bytes. No modelo, `\n` insere uma nova linha e `\t` insere uma tabulação.

O exemplo `emailsubject` abaixo é direto. O exemplo `emailbody` é muito próximo do padrão; o padrão exibe apenas o CIDNAME quando ele não é nulo, caso contrário, exibe o CIDNUM, ou "an unknown caller" quando ambos são nulos.

```
emailsubject=[PBX]: New message ${VM_MSGNUM} in mailbox ${VM_MAILBOX}

emailbody=Dear ${VM_NAME}:\n\n\tjust wanted to let you know you were just left a ${VM_DUR} long message (number ${VM_MSGNUM})\nin mailbox ${VM_MAILBOX} from ${VM_CALLERID}, on ${VM_DATE}, so you might\nwant to check it when you get a chance. Thanks!\n\n\t\t\t\t--Asterisk\n
```

## Interface Web de Voicemail

Existe um script Perl na distribuição de código-fonte chamado `vmail.cgi`, localizado em `contrib/scripts/vmail.cgi` na árvore de código-fonte do Asterisk (ele ainda é enviado com o Asterisk 22). O comando `make install` não instala esta interface; você deve executar `make webvmail` a partir do diretório de código-fonte. Este script requer que o interpretador de comandos Perl e um servidor web (como o Apache) estejam instalados no servidor.

```
make webvmail
```

O alvo `make webvmail` instala o script (setuid root) no diretório CGI do seu servidor web (`HTTP_CGIDIR`) e copia as imagens de suporte de `images/*.gif` para `HTTP_DOCSDIR/_asterisk` (por padrão `/var/www/html/_asterisk`). Se esses caminhos não corresponderem ao layout do seu servidor web, edite as variáveis `HTTP_CGIDIR` e `HTTP_DOCSDIR` no `Makefile` de nível superior antes de executar o alvo.

## Notificação de voicemail

Você pode configurar o voicemail para enviar uma mensagem de notificação ao seu telefone quando você tiver um novo voicemail. No Asterisk 22, a Message Waiting Indication (MWI) funciona com telefones PJSIP e SIP, bem como com telefones DAHDI. Para indicar um voicemail não ouvido, uma luz indicadora pode piscar ou o telefone pode reproduzir um tom de notificação. Você precisa configurar a mailbox no arquivo de configuração de canal correspondente. Exemplo: `pjsip.conf` (na seção endpoint):

```
mailboxes=8590
```

No PJSIP, a dica da mailbox é definida com a opção `mailboxes` dentro da seção endpoint do `pjsip.conf`, em vez do antigo `mailbox=` do `sip.conf`. As assinaturas de MWI são gerenciadas pelo módulo `res_pjsip_mwi`.

![A interface web do Comedian Mail (`vmail.cgi`): o login do Web-Voicemail do Asterisk — insira sua mailbox e senha para reproduzir, salvar, encaminhar ou excluir voicemails a partir de um navegador. Ele ainda é fornecido com o Asterisk 22 e é instalado com `make webvmail`.](../images/10-dialplan-advanced-features-img14.png)

### Laboratório: Notificação de mensagem no telefone

Este laboratório foi testado usando um softphone SIP.

1. Edite o `pjsip.conf` e adicione `mailboxes=4401` na seção endpoint para o dispositivo chamado 4401.
2. Edite o `extensions.conf` e crie uma extension para gravar um voicemail para as extensions 4401.

```
exten=9008,1,voicemail(4401,b)
```

3. Vá para o console e recarregue.
4. No SipPulse Softphone, abra as configurações da conta SIP e habilite a verificação de voicemail (message-waiting) para a conta.
5. Disque 9008 e deixe uma mensagem.
6. Observe o ícone de mensagem no telefone.

## Usando a aplicação directory

Esta aplicação permite que você encontre rapidamente um usuário para discar. A lista de nomes e as extensões correspondentes são recuperadas do arquivo de configuração de voicemail voicemail.conf. A sintaxe para a aplicação pode ser exibida usando core show application directory:

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

### Laboratório: Usando a aplicação directory

1. Edite o arquivo voicemail.conf para adicionar duas extensões no dialplan

```
[default]
; Define maximum number of messages per folder for a particular context.
;maxmsg=50
4400=>4400,Clint Eastwood,ceastwood@voip.school
4401=>4401,John Wayne,jwayne@voip.school
```

2. Crie estas extensões em seu dialplan

```
exten=9006,1,VoiceMailMain()
exten=9006,n,Hangup()
exten=9007,1,Directory(default,default)
exten=9007,n,Hangup()
```

3. Vá para o console e recarregue
4. Disque 9006 e grave um nome para cada extensão (4400, 4401)
5. Disque 9007 e selecione as três letras do sobrenome para uma extensão (Eas=327). Se esta for a opção correta, pressione ‘1’ para transferir para o nome.

## Lab: Colocando tudo em prática

Até aqui, você aprendeu vários conceitos de dialplan. Vamos colocar todas as aplicações, funções e conceitos em um exemplo de dialplan para que você possa entender como eles são usados em conjunto. Vamos guiá-lo por toda a configuração do PBX para o cenário abaixo.

- 4 trunks analógicos
- 16 extensions baseadas em SIP
- 3 classes de serviço:
    - restrict (interno, local e 1-800)
    - ld (longa distância)
    - ldi (internacional)
- Mensagem de fora do horário de expediente
- Auto attendant

### Passo 1 – Configurando canais

**Trunks analógicos (`chan_dahdi.conf`).** Primeiro, configuraremos os trunks analógicos no arquivo de configuração de canais DAHDI `chan_dahdi.conf`. Neste caso, usaremos uma placa T400P da Digium com 4 interfaces FXO. Vamos assumir que o driver já esteja carregado e que o arquivo de configuração do driver (/etc/dahdi/system.conf) esteja configurado corretamente.

![10-dialplan-advanced-features figura 16](../images/10-dialplan-advanced-features-img16.png)

```
signalling=fxs_ks
language=en
context=incoming
group=1
channel => 1-4
```

**Canais SIP (`pjsip.conf`).** Escolhemos a numeração do dialplan de 2000 a 2099. Dois codecs serão usados: G.729 e G.711 ulaw. O primeiro será usado para telefones que utilizam o Asterisk via Internet ou WAN, enquanto o segundo será usado para telefones que utilizam a rede local. Em `pjsip.conf`, arbitraremos quais dispositivos pertencerão a cada classe de serviço (restrict, ld, ldi). Para reduzir a vulnerabilidade a ataques de força bruta, usaremos os endereços MAC dos telefones como nomes de dispositivos. Recomendo fortemente que você use senhas fortes para evitar ataques de força bruta!

Definimos um transport e três templates reutilizáveis — uma base de endpoint com os codecs compartilhados, uma autenticação digest e um AOR de contato único — então anexamos cada dispositivo aos templates e sobrescrevemos apenas o que difere (seu context de classe de serviço e credenciais). `host=dynamic` torna-se um AOR no qual o telefone se registra, e `directmedia` torna-se `direct_media`:

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

### Passo 2 – Configurar o dialplan

Agora vamos começar a configurar o extensions.conf. Defina extensions internas e discagem local

```
[restrict]
exten=>_2000,1,Dial(PJSIP/00001A000002,20,t)
exten=>_2030,1,Dial(PJSIP/00001A000003,20,t)
exten=>_2040,1,Dial(PJSIP/00001A000004,20,t)
exten=>_9XXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20) ; local calls
exten=>_91800.,1,Dial(DAHDI/g1/${EXTEN:1},20); 1-800
```

Defina LD (longa distância)

```
[ld]
Include=>restrict
exten=>_9NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

Defina chamadas internacionais

```
[ldi]
include=>ld
exten=>_901X.,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

### Passo 3 - Recebendo chamadas usando um auto-attendant

Para receber chamadas, use dois contexts. O primeiro é para operação em horário comercial, onde a chamada será recebida por um auto-attendant. O segundo é para fora do horário de expediente, onde quem liga receberá uma mensagem como “você ligou para a empresa XYZ, nosso horário de funcionamento é das 08:00 às 18:00; se você souber o número da extension de destino, pode tentar discá-lo agora ou desligar.” Menus: Horário comercial, Fora do horário de expediente Nos menus abaixo, o sistema reproduzirá uma mensagem avisando a quem liga que a empresa foi contatada fora do horário normal de trabalho, permitindo que a pessoa disque o número da extension de destino (alguém pode estar trabalhando fora do horário normal).

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

Menus: Principal e Vendas Durante o horário normal de trabalho, a chamada é atendida por um menu de auto-attendant, recebendo uma mensagem como “bem-vindo à empresa XYZ; disque 1 para vendas, 2 para suporte técnico, 3 para treinamento ou o número da extension desejada”.

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

Com todas essas declarações, a funcionalidade do seu dialplan está pronta. Na próxima seção, demonstraremos como operar o PBX.

## Resumo

Neste capítulo, você aprendeu como receber chamadas usando uma IVR ou um atendimento automático. Você estudou o conceito de inclusão de context e implementou alguns exemplos. Sub-rotinas foram usadas para evitar digitação repetitiva, e o banco de dados do Asterisk (AstDB, suportado pelo SQLite3 no Asterisk 22) foi usado para funções que exigem armazenamento de dados (por exemplo, encaminhamento de chamadas, não perturbe, listas negras). Finalmente, você aprendeu como implementar o comportamento fora do horário de expediente e implementou um dialplan completo usando esses conceitos.

## Quiz

1. Uma inclusão de context dependente de tempo usa a forma `include => context,<times>,<weekdays>,<mdays>,<months>`. O que `include => normalhours,08:00-18:00,mon-fri,*,*` faz?
   - A. Executa as extension de segunda a sexta-feira, das 08:00 às 18:00
   - B. Executa as opções todos os dias em todos os meses
   - C. Nada; o formato é inválido
2. No Asterisk moderno (incluindo o Asterisk 22), os campos de um `include =>` baseado em tempo e de `GotoIfTime()` são separados por qual caractere?
   - A. O pipe `|`
   - B. A vírgula `,`
   - C. O ponto e vírgula `;`
   - D. A barra `/`
3. Para discar para vários canais de uma vez (fazendo-os tocar simultaneamente), você os separa dentro de `Dial()` com o caractere ___.
4. Um menu de voz que reproduz uma mensagem enquanto aguarda que o chamador disque uma extension é geralmente criado com a aplicação ___.
5. Você pode incluir o conteúdo de outro arquivo dentro de `extensions.conf` usando a diretiva ___ (nota: isso é diferente da diretiva de context `include =>`).
6. No Asterisk 22, o banco de dados interno AstDB é suportado por:
   - A. Berkeley DB v1
   - B. MySQL
   - C. SQLite3
   - D. PostgreSQL
7. Quando você usa `Dial(type1/identifier1&type2/identifier2)`, o Asterisk disca para cada canal em sequência, aguardando 20 segundos entre eles.
   - A. Falso
   - B. Verdadeiro
8. Com a aplicação Background(), você deve esperar até que a mensagem termine de ser reproduzida antes de poder pressionar um dígito DTMF para escolher uma opção.
   - A. Falso
   - B. Verdadeiro
9. Dada a sintaxe `Goto([[context,]extension,]priority)`, quais das seguintes são invocações válidas da aplicação Goto()? (marque todas as que se aplicam)
   - A. Goto(context,extension)
   - B. Goto(context,extension,priority)
   - C. Goto(extension,priority)
   - D. Goto(priority)
10. Para excluir uma única chave do AstDB no dialplan do Asterisk 22, você usa:
    - A. A aplicação `DBdel()`
    - B. A função `DB_DELETE()`
    - C. A aplicação `DBdeltree()`
    - D. A aplicação `LookupBlacklist()`

**Respostas:** 1 — A · 2 — B · 3 — `&` · 4 — Background() · 5 — #include · 6 — C · 7 — A · 8 — A · 9 — B, C, D · 10 — B
