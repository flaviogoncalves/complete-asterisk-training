# SIP & PJSIP em profundidade

SIP é o protocolo; PJSIP é como o Asterisk 22 o utiliza. **PJSIP** (`chan_pjsip`, configurado via `pjsip.conf`) é o único driver de canal SIP no Asterisk 22 LTS. Este capítulo aborda os fundamentos do protocolo SIP (que são de nível de protocolo e permanecem 100% válidos) e o modelo de objetos e a configuração do PJSIP que você utiliza diariamente. O driver legado descontinuado e um guia de migração são abordados no capítulo *Legacy channels*.

## Objetivos

Ao final deste capítulo, você deverá ser capaz de:

- Explicar o papel dos SIP user agents, proxies, registrar e gateways;
- Acompanhar um fluxo básico de chamada SIP (REGISTER, INVITE, respostas provisórias e finais, ACK, BYE) e ler uma mensagem SIP;
- Descrever como o SDP negocia a sessão de mídia e como o NAT afeta a sinalização SIP e o RTP;
- Mapear o modelo de objetos do PJSIP — `endpoint`, `auth`, `aor`, `transport`, `identify` e `registration` — e como os objetos referenciam uns aos outros;
- Configurar SIP phones e trunks em `pjsip.conf`, incluindo as opções de NAT-traversal; e
- Verificar e solucionar problemas de endpoints com os comandos CLI `pjsip show …`.

## Fundamentos do protocolo SIP

O Session Initiation Protocol (SIP) é um protocolo baseado em texto, semelhante ao HTTP e ao SMTP, que foi projetado para inicializar, manter e encerrar sessões de comunicação interativa entre usuários. Essas sessões podem incluir voz, vídeo, chat, jogos interativos e outros. O SIP foi definido pela IETF e tornou-se o padrão *de facto* para comunicações de voz. É muito importante entender como o SIP funciona. No Asterisk 22, a configuração SIP reside em `pjsip.conf`, que é um dos arquivos editados com mais frequência em um sistema baseado em SIP (logo após o `extensions.conf`).

### Teoria de operação

O SIP é um protocolo de sinalização com os seguintes componentes: User Agent Client, User Agent Servers, SIP Proxies e SIP Gateways. A figura a seguir descreve os relacionamentos entre esses componentes.

- UAC (user agent client) – O cliente ou terminal que inicializa a sinalização SIP.
- UAS (user agent server) – O servidor que responde a uma sinalização SIP vinda de um UAC.
- UA (user agent) – O terminal SIP (telefones ou gateways que contêm tanto UAC quanto UAS).
- Proxy Server – Recebe solicitações de um UA e as transfere para outros SIP Proxies se a estação específica não estiver sob sua administração.
- Redirect Server – Recebe solicitações e as envia de volta ao UA, incluindo dados de destino, em vez de encaminhá-las diretamente ao destino.
- Location Server – Recebe solicitações de um UA e atualiza o banco de dados de localização com essas informações.

Geralmente, os servidores proxy, redirect e location são hospedados no mesmo hardware e usam o mesmo software, que chamamos de SIP proxy. O SIP proxy é responsável pela manutenção do banco de dados de localização, estabelecimento de conexão e encerramento de sessão.

![Os principais componentes SIP: user agents (UAC/UAS/UA), o servidor de registrar/proxy/redirect e um gateway para a PSTN, com a mídia RTP fluindo diretamente entre os endpoints](../images/07-sip-and-pjsip-fig01.png)

#### Processo de registro SIP

Antes que um telefone possa receber chamadas, ele precisa ser registrado em um banco de dados de localização. No banco de dados de localização, o endereço IP será vinculado ao nome. No exemplo a seguir, a extension 8500 será vinculada ao endereço IP 200.180.1.1. Você não precisa necessariamente usar números de telefone. Na arquitetura SIP, a extension registrada poderia ser flavio@voip.school também.

![Registro SIP: o telefone envia um REGISTER vinculando a extension 8500 ao seu endereço IP, o registrar armazena o contato no banco de dados de localização e responde com 200 OK](../images/07-sip-and-pjsip-fig02.png)

#### Operação de proxy

Ao operar como um SIP proxy, o servidor SIP permanece no meio da sinalização e é capaz de realizar roteamento avançado e faturamento. O fluxo de mídia, baseado no real time protocol (RTP), ainda passa diretamente entre os endpoints.

![Operação de proxy: o SIP proxy permanece no caminho da sinalização (INVITE/200 OK) e consulta o destinatário no location server, enquanto a mídia RTP flui diretamente entre os dois endpoints](../images/07-sip-and-pjsip-fig03.png)

#### Operação de redirecionamento

Ao redirecionar, o servidor SIP simplesmente envia uma mensagem (por exemplo, 302 moved temporarily) para o user agent e permanece fora do caminho das novas mensagens. É muito leve em termos de uso de recursos, mas você não tem controle algum. O redirecionamento é às vezes usado em projetos de balanceamento de carga.

![Operação de redirecionamento: o redirect server responde ao INVITE com um 302 Moved Temporarily contendo o contato, então se afasta enquanto o chamador reenvia o INVITE/ACK diretamente para a nova localização](../images/07-sip-and-pjsip-fig04.png)

#### Como o Asterisk lida com o SIP

É importante entender que o Asterisk não é um SIP proxy nem um SIP redirector. O Asterisk pode desempenhar o papel de registrar e location server; no entanto, ele apenas conecta dois UACs a si mesmo. Portanto, o Asterisk é considerado um back-to-back user agent (B2BUA). Em outras palavras, ele conecta dois canais SIP, fazendo uma ponte entre eles. O Asterisk possui um mecanismo de re-invite que pode fazer com que os canais SIP conversem entre si diretamente, em vez de passar pelo Asterisk. Em um endpoint PJSIP, isso é controlado pelo parâmetro `direct_media`. Ao usar `direct_media=yes`, o fluxo RTP vai diretamente de um endpoint para outro, liberando recursos do servidor.

#### Operação SIP com direct_media=yes

![Operação SIP com directmedia=yes: a sinalização SIP flui através do Asterisk enquanto o áudio RTP vai diretamente entre os dois telefones, liberando recursos do servidor](../images/07-sip-and-pjsip-fig05.png)

No entanto, se você precisar transferir ou gravar a chamada usando o Asterisk, você pode usar o parâmetro `direct_media=no` para forçar o fluxo RTP através do servidor Asterisk.

#### Operação SIP com direct_media=no

![Operação SIP com directmedia=no: tanto a sinalização SIP quanto o áudio RTP são ancorados através do Asterisk, permitindo que ele grave, transcodifique ou transfira a chamada](../images/07-sip-and-pjsip-fig06.png)

#### Mensagens SIP

As mensagens SIP básicas são:

- INVITE – estabelecimento de conexão
- ACK – confirmação
- BYE – encerramento de conexão
- CANCEL – encerramento de conexão para uma chamada não estabelecida
- REGISTER – registra um UAC em um SIP proxy
- OPTIONS – pode ser usado para verificar disponibilidade
- REFER – transfere uma chamada SIP para outra pessoa
- SUBSCRIBE – inscreve-se em eventos de notificação
- NOTIFY – envia informações do canal
- INFO – envia várias mensagens (por exemplo, DTMF)
- MESSAGE – envia mensagens instantâneas

As respostas SIP estão em formato de texto e são facilmente legíveis (semelhante às mensagens HTTP). As respostas mais importantes são:

- 1XX – Mensagens de informação (100–trying, 180–ringing, 183–progress)
- 2XX – Solicitação bem-sucedida concluída (200 – OK)
- 3XX – Redirecionamento de chamada, a solicitação deve ser direcionada para outro lugar (302 – moved temporarily, 305 – use proxy)
- 4XX – Erro (403 – Forbidden)
- 5XX – Erro de servidor (500 – Internal Server Error; 501 – Not implemented)
- 6XX – Falha global (606 – Not acceptable)

Por exemplo:

```
INVITE sip:2000@192.168.1.133 SIP/2.0
Via: SIP/2.0/UDP
192.168.1.116;rport;branch=z9hG4bKc0a8017400000063452fafbb00006967000000d2
From: "unknown"<sip:2001@192.168.1.133>;tag=1556140623845
To: <sip:2000@192.168.1.133>
Contact: <sip:2001@192.168.1.116>
Call-ID: 64B4C8EC-FCFC-49E9-98B1-90982EEEBED3@192.168.1.116
CSeq: 2 INVITE
Max-Forwards: 70
User-Agent: SJphone/1.61.312b (SJ Labs)
Content-Length: 335
Content-Type: application/sdp
Proxy-Authorization: Digest
username="2001",realm="asterisk",nonce="6c55905e",uri="sip:2000@192.168.1.133",
response="983c0099eea125d8cdfe93b0ec99f3ec",algorithm=MD5
```

#### Session description protocol (SDP)

O SDP foi originalmente definido na IETF RFC 2327, agora obsoleta pela RFC 4566. Ele se destina a descrever sessões multimídia para fins de anúncio de sessão, convite de sessão e outras formas de iniciação de sessão multimídia. O SDP inclui:

- Protocolo de transporte (RTP/UDP/IP)
- Tipo de mídia (texto, áudio, vídeo)
- Formato de mídia ou codec (vídeo H.261, áudio g.711, etc.)
- Informações necessárias para receber essas mídias (endereços, portas, etc.)

O exemplo a seguir é uma transcrição de um SDP descrevendo uma chamada entre dois telefones.

```
v=0
o=- 3369741883 3369741883 IN IP4 192.168.1.116
s=SJphone
c=IN IP4 192.168.1.116
t=0 0
a=setup:active
m=audio 49160 RTP/AVP 3 97 98 8 0 101
a=rtpmap:3 GSM/8000
a=rtpmap:97 iLBC/8000
a=rtpmap:98 iLBC/8000
a=fmtp:98 mode=20
a=rtpmap:8 PCMA/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-11,16
```

### NAT Traversal SIP

Network Address Translation (NAT) é um recurso usado pela maioria das redes para economizar endereços IP da Internet. Geralmente, uma empresa recebe um pequeno bloco de endereços IP, e os usuários finais recebem um endereço IP dinamicamente quando conectados à Internet. O NAT resolve o problema de endereçamento mapeando endereços internos para endereços externos. Ele armazena um mapeamento de endereços internos para externos em sua memória. Esse mapeamento é válido por um período específico, após o qual o mapeamento é descartado. O mapeamento usa pares IP:porta para os endereços internos e externos. Existem quatro tipos de NAT:

- Full Cone
- Restricted Cone
- Port Restricted Cone
- Symmetric

A teoria de NAT abaixo — os quatro tipos de NAT, o problema do cabeçalho Contact, keep-alives e o forçamento de mídia através do servidor — é de nível de protocolo e se aplica a qualquer implementação SIP. A maneira como você configura cada comportamento no Asterisk 22 (PJSIP) é abordada mais adiante neste capítulo em *Nat traversal on res_pjsip*.

#### Full Cone

O primeiro NAT, full cone, representa um mapeamento estático de um par IP:porta externo para um par IP:porta interno. Qualquer computador externo pode se conectar a ele usando o par IP:porta externo. Este é o caso em firewalls sem estado implementados com o uso de filtros.

![Full Cone NAT: o host interno (10.0.0.1:8000) é mapeado estaticamente para o par externo 200.180.4.168:1234, portanto, qualquer computador externo pode enviar pacotes para esse par e alcançar o host interno](../images/07-sip-and-pjsip-fig11.png)

#### Restricted Cone

No cenário de restricted cone, o par IP:porta externo é aberto apenas quando o computador interno envia dados para um endereço externo. No entanto, o NAT restricted cone bloqueia quaisquer pacotes de entrada de um endereço diferente. Em outras palavras, o computador interno precisa enviar dados para um computador externo antes que ele possa enviar dados de volta.

#### Port Restricted Cone

O firewall port restricted cone é quase idêntico ao restricted cone. A única diferença é que, agora, o pacote de entrada precisa vir exatamente do mesmo IP e porta do pacote enviado.

#### Symmetric

O último tipo de NAT é chamado de symmetric. Ele é diferente dos três primeiros, pois um mapeamento específico é feito para cada endereço externo. Apenas endereços externos específicos têm permissão para retornar pelo mapeamento NAT. Não é possível prever o par IP:porta externo que será usado pelo dispositivo NAT. Os outros três tipos de NAT permitem o uso de um servidor externo para descobrir o endereço IP externo para comunicação. Com o NAT symmetric, mesmo que você consiga se conectar a um servidor externo, o endereço descoberto não pode ser usado para nenhum outro dispositivo, exceto para este servidor.

![Symmetric NAT: uma porta de origem externa diferente é alocada para cada destino, portanto, o mapeamento descoberto em direção a um servidor não pode ser reutilizado por outro host, o que quebra o traversal baseado em STUN](../images/07-sip-and-pjsip-fig12.png)

#### Tabela de firewall NAT

A tabela a seguir resume os quatro tipos de NAT.

| Tipo de NAT | Deve enviar dados primeiro | Pode determinar o IP:porta externo para pacotes de retorno | Restringe pacotes de entrada ao IP:porta de destino |
| --- | --- | --- | --- |
| Full Cone | Não | Sim | Não |
| Restricted Cone | Sim | Sim | Apenas IP |
| Port Restricted Cone | Sim | Sim | Sim |
| Symmetric | Sim | Não | Sim |

#### Sinalização SIP e RTP sobre NAT

Alguns dos maiores problemas no NAT traversal são que você precisa resolver dois problemas: sinalização SIP e áudio (RTP). A maioria dos problemas de áudio unidirecional está relacionada ao NAT. Uma coisa interessante sobre o SIP é que, quando um UAC envia um pacote, ele incorpora o endereço IP no campo de cabeçalho “Contact” do SIP. Geralmente, este é um endereço interno (RFC1918); as respostas a este pacote não podem ser roteadas pela Internet de volta para o UAC. As correções conceituais são sempre as mesmas:

- **Ignore o endereço Contact/Via e responda para onde o pacote realmente veio.** Este é o comportamento definido na RFC 3581 (`rport`). No PJSIP, é `force_rport=yes`, e `rewrite_contact=yes` reescreve o contato armazenado para o endereço de origem.
- **Envie a mídia de volta para o endereço de onde o RTP realmente veio** (RTP simétrico, historicamente chamado de *comedia*). No PJSIP, isso é `rtp_symmetric=yes`.
- **Mantenha o mapeamento NAT aberto.** Se o mapeamento expirar, o Asterisk não poderá mais enviar um INVITE para o UAC — o telefone pode fazer chamadas, mas não recebê-las. Enviar um OPTIONS periódico (um *qualify*) mantém o pinhole aberto. No PJSIP, isso é `qualify_frequency=` no AOR.

Se o NAT do usuário for do tipo symmetric, não é possível enviar pacotes de um UAC para outro diretamente; nesse caso, você deve forçar o RTP através do Asterisk com `direct_media=no`. Essas configurações são apropriadas para a maioria dos casos. É possível otimizar o tráfego usando técnicas avançadas como Simple Traversal of UDP over NAT (STUN), que é útil com full cone, restricted cone e port restricted cone, e Application Layer Gateway (ALG). Infelizmente, a maioria dos firewalls hoje — até mesmo roteadores DSL/cabo domésticos — são symmetric, tornando o STUN inutilizável. O ALG poderia resolver o problema, mas não é suportado, não está implementado ou apresenta erros na maioria dos casos.

#### Asterisk atrás de NAT

Às vezes, o próprio servidor Asterisk é implementado atrás de um firewall com NAT — uma situação muito comum quando você implanta na nuvem. Nesse caso, é necessário fazer alguma configuração extra para que o Asterisk anuncie seu endereço **público** nos cabeçalhos SIP e SDP em vez do seu endereço privado.

Conceitualmente, existem três etapas:

- Encaminhe a porta de sinalização SIP (UDP 5060 por padrão) do firewall para o servidor Asterisk.
- Encaminhe o intervalo de portas de mídia RTP (UDP 10000–20000 por padrão, definido em `rtp.conf`) do firewall para o servidor Asterisk.
- Informe ao Asterisk seu endereço externo e qual rede é local, para que ele saiba quando substituir o endereço público nos cabeçalhos.

No PJSIP, esses dois últimos itens mapeiam para `external_media_address` / `external_signaling_address` e `local_net=` no **transport**, e o intervalo de portas RTP ainda é configurado em `rtp.conf`:

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

A configuração PJSIP completa e funcional para um servidor Asterisk atrás de NAT é fornecida mais adiante neste capítulo em *Asterisk Server behind NAT*.

### Limitações do SIP

O Asterisk usa o fluxo RTP de entrada para sincronizar o fluxo de saída. Se o fluxo de entrada for interrompido (supressão de silêncio), a música de espera (music-on-hold) será cortada. Em outras palavras, você não deve usar supressão de silêncio em telefones ou provedores com Asterisk.

## PJSIP: o canal SIP

PJSIP é o canal SIP no Asterisk. Ele foi introduzido pela primeira vez no Asterisk 12 e, após anos de desenvolvimento, tornou-se o canal SIP padrão e recomendado; no Asterisk 22 (a versão LTS atual), ele é o único driver de canal SIP. O PJSIP é baseado no projeto da Teluu chamado pjproject. A stack pjproject é utilizada por muitos softphones e implementações comerciais de SIP. É uma stack SIP versátil e madura.

### Por que usar PJSIP

O PJSIP foi um redesenho completo de como o Asterisk fala SIP, e vale a pena entender os recursos que o tornaram o padrão.

#### Recursos

O canal suporta muitos recursos, alguns dos quais merecem menção aqui:

- Múltiplos registros: Você pode usar mais de um telefone conectado ao mesmo Address of Record. Em outras palavras, você pode conectar dois telefones ao mesmo endpoint.
- Interface de Programação de Aplicação (API) amigável. A API é modular e fácil de estender, construída a partir de muitos pequenos módulos cooperativos em vez de um grande bloco de código.
- Múltiplos transportes: Você pode escutar em múltiplos endereços, portas e transportes ao usar PJSIP. Você não está limitado a um único endereço de bind para todos os seus dispositivos. O PJSIP é muito flexível.

#### Uma nota sobre a configuração

A configuração do PJSIP é mais detalhada: ela exige um pouco mais de esforço e mais linhas de configuração, já que cada dispositivo é descrito por vários objetos relacionados em vez de um único bloco de peer. Essa estrutura extra é o que dá ao PJSIP sua flexibilidade, e o assistente de configuração (abordado mais adiante) mantém o provisionamento diário curto.

### Módulos PJSIP

O canal PJSIP é implementado por muitos módulos descritos abaixo:

#### res_pjsip

Esta é a camada base do PJSIP e o módulo principal. Ele é responsável por alguns dos principais serviços.

#### res_pjsip_session

Este módulo é responsável pelas sessões de mídia, processamento do protocolo de descrição de sessão (SDP) e alguns complementos.

#### res_pjsip_messaging

Processa mensagens SIP e analisa cabeçalhos SIP.

#### res_pjsip_registrar

Responsável por lidar com registros SIP.

#### res_pjsip_pubsub

Responsável por processar subscribe, notify e publish. Essas mensagens são responsáveis por lidar com presença SIP e BLF (Busy Lamp Field).

### Configuração do PJSIP

O PJSIP possui muitas seções diferentes. O formato da seção é:

```
[Section Name]
Option = Value
Option = Value
```

#### Seção Endpoint

O objeto de configuração mais importante é o endpoint. A configuração do endpoint possui funcionalidade central e deve ser associada a uma seção AOR e Transport. Exemplo:

```
[softphone]
type=endpoint
transport=transport-udp-main
context=from-internal
disallow=all
allow=ulaw
aors=softphone
auth=softphone
```

Se você observar o exemplo acima, o endpoint é uma espécie de cola que une todas as seções. Ele especifica um transporte, o address of record e a autenticação para um telefone. Também define a parte mais importante, o ponto de entrada de contexto no dialplan.

#### Address of Record (AOR)

Este objeto diz ao Asterisk onde contatar o endpoint. Ele armazena os endereços de contato. Também permite a configuração de caixas postais. Exemplo:

```
[softphone]
type=aor
max_contacts=2
```

#### Autenticação

Esta seção é responsável pela autenticação de entrada e saída. A documentação é encontrada no arquivo de exemplo pjsip.conf. Exemplo:

```
[softphone]
type=auth
auth_type=digest
username=softphone
password=#supersecret#
```

#### Transporte

A seção de transporte permite definir endereços IPV4 e IPV6 e o protocolo de transporte, TCP, UDP, TLS, Websockets e assim por diante. Você também pode configurar endereços NAT nesta seção. Você pode criar múltiplos transportes, mas eles não podem compartilhar o mesmo IP e porta, e você não pode vincular múltiplos transportes TCP ou TLS da mesma versão de IP. Exemplo:

```
[transport-udp-main]
type=transport
protocol=udp
bind=0.0.0.0:5060
```

#### Registro

Este objeto é usado para configurar um registro de saída. Exemplo:

```
[siptrunk]
type=registration
outbound_auth=siptrunk
server_uri=sip:1020@sip.flagonc.com:5600
client_uri=sip:1020@sip.flagonc.com
contact_user=9999
```

#### Identificação (Identify)

Este objeto controla qual solicitação SIP pertence a cada endpoint. Se você não tiver uma seção de identificação, o sistema corresponderá o conteúdo do cabeçalho “From” com o nome do endpoint. Usando esta seção, você pode atribuir endereços IP específicos a endpoints específicos, identificados por nome de usuário ou IP. Exemplo:

```
[siptrunk]
type=identify
endpoint=siptrunk
match=52.37.87.85
```

#### ACL

O objeto ACL permite configurar redes específicas com acesso ao endpoint. Agora, as ACLs são definidas em uma seção específica ou no acl.conf. Exemplo:

```
[acl]
type=acl
deny=0.0.0.0/0.0.0.0
permit=209.16.236.0
permit=209.16.236.1
```

### Relacionamento entre entidades

O relacionamento entre os objetos de configuração proporciona uma grande flexibilidade para a configuração. No entanto, parece um pouco complexo para quem está começando.

![Relacionamentos entre objetos de configuração PJSIP: o endpoint conecta-se ao transporte, autenticação e AOR (que mantém os contatos); o registro vincula-se ao transporte e autenticação; a identificação aponta para o endpoint, enquanto ACL e alias de domínio são independentes](../images/07-sip-and-pjsip-fig14.png)

O gráfico acima significa:

#### Relacionamentos:

| Objetos | Cardinalidade |
| --- | --- |
| ENDPOINT / AOR | muitos para muitos |
| ENDPOINT / AUTH | zero para muitos, para zero para um |
| ENDPOINT / IDENTIFY | zero para um |
| ENDPOINT / TRANSPORT | zero para muitos, para pelo menos um |
| REGISTRATION / AUTH | zero para muitos, para zero para um |
| REGISTRATION / TRANSPORT | zero para muitos, para pelo menos um |
| AOR / CONTACT | muitos para muitos |

ACL e DOMAIN_ALIAS não possuem um relacionamento de configuração direto com os outros objetos.

### Configurando um Softphone

Para configurar um softphone, você precisa definir muitas seções diferentes. Abaixo, um exemplo de como configurar um softphone. Para o lado do cliente, você pode usar o SipPulse Softphone (https://www.sippulse.com/produtos/softphone), que você pode baixar e registrar no endpoint abaixo.

```
[transport-udp-main]
type=transport
protocol=udp
bind=0.0.0.0:5060
[softphone]
type=endpoint
transport=transport-udp-main
context=from-internal
disallow=all
allow=ulaw
aors=softphone
auth=softphone
[softphone]
type=auth
auth_type=digest
username=softphone
password=#supersecret#
[softphone]
type=aor
max_contacts=2
```

A configuração acima define um transporte para UDP na porta 5060, define um endpoint, sua autenticação por nome de usuário e senha e, em seguida, o Address of Record com um máximo de dois contatos.

### Configurando um trunk SIP

Para configurar um trunk SIP, você precisa ter o endereço IP ou Host do trunk SIP, nome e senha. Você deve criar uma nova seção de registro para este propósito.

```
[siptrunk]
type=endpoint
transport=transport-udp-main
context=from-siptrunk
direct_media=no
disallow=all
allow=ulaw
outbound_auth=siptrunk
aors=siptrunk
[siptrunk]
type=aor
contact=sip:sip.flagonc.com:5600
[siptrunk]
type=auth
auth_type=digest
username=1020
password=supersecret
[siptrunk]
type=registration
outbound_auth=siptrunk
server_uri=sip:1020@sip.flagonc.com:5600
client_uri=sip:1020@sip.flagonc.com
contact_user=9999
[siptrunk]
type=identify
endpoint=siptrunk
match=sip.flagonc.com
```

### Travessia de NAT no res_pjsip

A Tradução de Endereço de Rede (NAT) foi criada há muito tempo como uma forma de lidar com a escassez de endereços IP versão 4. Muitas pessoas também usam NAT como um recurso de segurança, ocultando os endereços internos de uma rede da Internet pública. Às vezes, você terá que lidar com a travessia de NAT. Em alguns casos, o servidor pode estar atrás de NAT, como quando você está implantando o servidor na nuvem. Muitas vezes, se você estiver implantando na nuvem, seus usuários também estarão atrás de um roteador NAT. Para organizar as coisas, dividiremos isso em duas partes. A primeira é o servidor Asterisk atrás de NAT, como em uma implantação na nuvem. Na segunda seção, abordaremos como oferecer suporte a clientes atrás de NAT usando res_pjsip.

#### Servidor Asterisk atrás de NAT

Quando o servidor Asterisk está atrás de NAT, você deve informar os endereços locais externos e internos na seção de transporte. Teremos as seguintes diretivas.

##### direct_media

A mídia flui diretamente de peer para peer ou através do servidor? Para NAT, ela deve fluir através do servidor. Para NAT, selecione no. Exemplo:

```
direct_media=no
```

##### external_media_address

Endereço de mídia para lidar com RTP externo. Geralmente o mesmo que o external_signaling_address. Use o endereço IP público do seu servidor para mídia e sinalização. Exemplo:

```
external_media_address=54.232.1.20
```

##### external_signaling_address

Endereço SIP externo onde receber mensagens. Exemplo:

```
external_signaling_address=54.232.1.20
```

##### local_net

A rede que você considera sua rede local. Exemplo:

```
local_net=172.16.30.0/24
local_net=127.0.0.1/32
```

#### Exemplo completo de transporte para um servidor Asterisk atrás de NAT

Para usar um servidor Asterisk atrás de NAT, você deve realizar dois passos. Primeiro, defina um transporte atrás de NAT. Segundo, associe este transporte ao endpoint.

##### Criando o transporte atrás de NAT

Para criar o transporte atrás de NAT no arquivo pjsip.conf, crie uma seção como abaixo.

```
[tnat]
type=transport
protocol=udp
bind=0.0.0.0
local_net=172.16.30.0/24
local_net=127.0.0.1/32
external_media_address=54.232.1.20
external_signaling_address=54.232.1.20
```

Associe o transporte a um endpoint

```
[6000]
type=endpoint
transport=tnat
context=from-internal
direct_media=no
auth=6000
aors=6000
```

Para trunks SIP, você também deve associar o transporte à seção de registro, como abaixo.

```
[siptrunk_reg]
type=registration
transport=tnat
server_uri=sip:sip.flagonc.com:5600
outbound_auth=siptrunk_auth
client_uri=sip:23456789@flagonc.com
contact_user=9999
```

#### Usando Asterisk com clientes atrás de NAT

Para usar telefones atrás de NAT, você deve configurar alguns parâmetros adicionais por endpoint.

##### direct_media

A mídia flui diretamente de peer para peer ou através do servidor? Para NAT, ela deve fluir através do servidor. Exemplo:

```
direct_media=no
```

##### rtp_symmetric

Isso é o que chamamos de comedia. Em vez de confiar no endereço definido neste cabeçalho SDP como de costume no SIP, use o endereço de onde você recebe o primeiro pacote RTP e envie de volta a partir do mesmo endereço. Exemplo:

```
rtp_symmetric=yes
```

##### force_rport

Este é o comportamento definido na RFC3581. Em vez de usar o endereço no cabeçalho VIA, envie as respostas de volta para onde as solicitações estão vindo. Exemplo:

```
force_rport=yes
```

##### qualify_frequency

Esta configuração deve ser aplicada ao AOR (não ao endpoint). Há também o último passo, configurar a opção qualify. Você deve sempre ter alguns pacotes fazendo ping no destino para manter o mapeamento NAT aberto. Isso é definido na seção AOR. Exemplo:

- qualify_frequency=15

Exemplo completo de um endpoint onde o servidor e o cliente estão atrás de NAT

```
[6000]
type=endpoint
transport=tnat
context=from-internal
direct_media=no
force_rport=yes
rtp_symmetric=yes
auth=6000
aors=6000
[6000]
type=aor
qualify_frequency=15
```

### Nomenclatura de canal

Como de costume, um dos aspectos importantes de um canal é sua nomenclatura, e o PJSIP tem alguns detalhes interessantes. Você disca para um endpoint PJSIP com a tecnologia `PJSIP/`:

```
exten=>6000,1,Dial(PJSIP/6000,20,tT)
```

Um recurso útil é a possibilidade de discar para todos os contatos registrados em um AOR de uma só vez. A função PJSIP_DIAL_CONTACTS será traduzida para a lista de contatos a serem discados.

```
exten=>6000,1,Dial(${PJSIP_DIAL_CONTACTS(6000)},20,tT)
```

Discar para um trunk é ligeiramente diferente. Suponha que o trunk não será registrado em sua plataforma ou não tenha um endereço IP associado ao seu Address of Record. Você pode especificar o endereço do trunk diretamente na linha. Usando uma discagem internacional como exemplo.

```
exten=>9011.,1,Dial(PJSIP/siptrunk/sip:${EXTEN:1}@sip.flagonc.com)
```

Se você preferir especificar o endereço do trunk na seção AOR, você também pode usar.

```
exten=>9011.,1,Dial(PJSIP/${EXTEN:1}@siptrunk)
```

### Assistente de configuração PJSIP

O PJSIP é poderoso, mas detalhado para configurar: muitas seções diferentes e modelos que podem ser confusos no início. A boa notícia é o assistente de configuração PJSIP. Ao definir cada canal em poucas linhas, ele permite criar modelos e simplificar a configuração de novos dispositivos. Use o arquivo pjsip_wizard.conf para configurar. Você ainda precisa definir as seções de transporte e globais no arquivo pjsip.conf. Pessoalmente, prefiro usar o assistente apenas para telefones; para trunks SIP, geralmente o número não é grande e você pode configurar diretamente no pjsip. A maior vantagem do assistente é a possibilidade de usar modelos e criar telefones rapidamente.

```
[phone_default](!)
type = wizard
accepts_auth = yes
accepts_registrations = yes
transport = tnat
endpoint/allow = ulaw
endpoint/context = from-internal
endpoint/direct_media=no
endpoint/force_rport=yes
endpoint/rtp_symmetric=yes
aor/qualify_frequency=15
[alice](phone_default)
inbound_auth/username = alice
inbound_auth/password = supersecret
[bob](phone_default)
inbound_auth/username = bob
inbound_auth/password = supersecret
```

### Carregando e descarregando PJSIP

O PJSIP é o único canal SIP no Asterisk 22, e seus módulos são carregados por padrão. Em casos raros, você ainda pode querer controlar o carregamento de módulos a partir do arquivo modules.conf — por exemplo, para desativar o PJSIP em um servidor que usa apenas IAX2 ou DAHDI.

#### Para desativar o PJSIP

Edite o arquivo modules.conf e adicione as seguintes linhas.

```
noload => res_pjsip.so
noload => res_pjsip_pubsub.so
noload => res_pjsip_session.so
noload => chan_pjsip.so
noload => res_pjsip_exten_state.so
```

### Comandos de console

Agora que você configurou seus endpoints PJSIP, é hora de ver como verificar sua configuração. Existem muitos comandos de console para ajudá-lo nesta tarefa. Após editar o pjsip.conf, recarregue a configuração com:

```
module reload res_pjsip.so
```

Um `reload` simples (ou `core reload`) recarrega todos os módulos, incluindo o PJSIP. (Observe que não existe um comando `pjsip reload` puro — o `pjsip reload` só existe na forma `pjsip reload qualify aor|endpoint`.) Você pode listar todos os comandos de console PJSIP disponíveis com `help pjsip`.

#### pjsip show endpoints

Este comando mostra os endpoints disponíveis. Na imagem abaixo, temos uma captura de tela. Você pode ver o endereço do endpoint do softphone e ver que ele está disponível.

![Saída de `pjsip show endpoints` listando os endpoints blink, siptrunk e softphone com seu AOR, autenticação, transporte e disponibilidade — o contato do softphone está registrado (Avail)](../images/07-sip-and-pjsip-fig15.png)

#### pjsip show endpoint <endpoint>

Com o comando acima, você pode ver cada parâmetro do endpoint. A lista abaixo foi cortada para menos da metade dos parâmetros atuais.

![Saída de `pjsip show endpoint softphone` mostrando a lista completa de parâmetros para um único endpoint, de 100rel e allow=(ulaw) até callerid e connected_line_method](../images/07-sip-and-pjsip-fig16.png)

#### pjsip show aors

Este comando lista os objetos Address of Record configurados e seus contatos, para que você possa confirmar para onde o Asterisk enviará chamadas para cada endpoint.

#### pjsip show registrations

O comando abaixo mostra os registros feitos pelo nosso próprio servidor.

![Saída de `pjsip show registrations`: o registro de saída siptrunk/sip:1020@sip.flagonc.com:5600 é mostrado com status Registered](../images/07-sip-and-pjsip-fig17.png)

#### pjsip list

O comando list é um pouco mais amigável e mostra menos dados, mas melhor estruturados. Listando endpoints:

![Saída de `pjsip list endpoints`: uma listagem compacta de uma linha por endpoint (blink, siptrunk, softphone) com seu estado e contagem de canais](../images/07-sip-and-pjsip-fig18.png)

Listando contatos:

![Saída de `pjsip list contacts` mostrando os URIs de contato do siptrunk e softphone com seu hash e status de qualify](../images/07-sip-and-pjsip-fig19.png)

#### pjsip set logger on

O comando de solução de problemas mais útil é o logger de pacotes SIP. Ele imprime cada solicitação e resposta SIP no console à medida que é enviada ou recebida, o que é inestimável ao diagnosticar problemas de registro e configuração de chamadas.

```
pjsip set logger on
pjsip set logger off
```

Você também pode restringir o log a um único host com `pjsip set logger host <ip>`.

#### pjsip set history on

Uma ótima adição ao PJSIP é o conceito de histórico. Você pode capturar e analisar solicitações e respostas SIP em tempo real de uma maneira fácil. Para iniciar o histórico, use o comando abaixo.

![Executar `pjsip set history on` retorna "PJSIP History enabled"](../images/07-sip-and-pjsip-fig20.png)

Agora você pode mostrar o histórico:

![Saída de `pjsip show history`: uma tabela numerada de mensagens SIP capturadas — REGISTER, 401 Unauthorized, REGISTER, 200 OK — com carimbos de data/hora, direção e endereço](../images/07-sip-and-pjsip-fig21.png)

Então, para ver uma solicitação ou resposta específica, mostre o item do histórico:

![Saída de `pjsip show history entry`: o texto completo de uma única mensagem SIP capturada — aqui a resposta `404 Not Found` do Asterisk 22 para uma sonda OPTIONS — mostrando os cabeçalhos Via (com `rport`/`received`), Call-ID, From, To e CSeq, as capacidades `Allow`/`Supported` e o cabeçalho `Server: Asterisk PBX 22.10.0`](../images/07-sip-and-pjsip-fig22.png)

Muito fácil, não é? Você também pode limpar o histórico sempre que quiser usando `pjsip set history clear`.

> **Migrando um sistema chan_sip/sip.conf existente?** O driver legado `chan_sip`
> e um **guia completo de migração sip.conf → pjsip.conf** (incluindo a
> tabela de mapeamento de conceitos e o script de conversão `sip_to_pjsip.py`) são abordados
> no capítulo *Legacy channels*.

## Resumo

SIP é o protocolo de sinalização da IETF que estabelece, modifica e encerra sessões de mídia. Seus agentes de usuário, proxies, registradores e gateways trocam mensagens baseadas em texto — REGISTER, INVITE, as respostas provisórias e finais, ACK e BYE — enquanto o SDP negocia os codecs e o RTP transporta a mídia. Essa teoria de protocolo é atemporal e se aplica a qualquer implementação SIP.

No Asterisk 22, você utiliza SIP através do **PJSIP** (`chan_pjsip`), configurado em `pjsip.conf`. Em vez de um peer monolítico, um dispositivo é modelado como um conjunto de pequenos objetos com referências cruzadas: `endpoint` (comportamento de chamada e codecs), `auth` (credenciais), `aor` (onde ele está acessível) e `transport` (o ouvinte), além de `identify` (corresponder a um trunk por IP) e `registration` (registrar saída) para provedores de serviço. Você viu como esses objetos se encaixam, como configurar tanto telefones quanto trunks, como as opções de travessia de NAT (`force_rport`, `rewrite_contact`, `rtp_symmetric`, `direct_media` e o `external_*`/`local_net` do transporte) resolvem implementações no mundo real, e como inspecionar tudo isso com `pjsip show endpoints`, `aors`, `contacts` e `registrations`.

## Quiz

1. Na arquitetura SIP, qual componente recebe uma solicitação e responde com uma resposta de redirecionamento (como `302 Moved Temporarily`) contendo a nova localização, permanecendo fora do caminho das mensagens subsequentes?
   - A. Proxy server
   - B. Redirect server
   - C. Location server
   - D. Registrar

2. Qual papel o Asterisk desempenha quando gerencia uma chamada SIP entre dois telefones?
   - A. Um SIP proxy que permanece apenas no caminho de sinalização
   - B. Um SIP redirect server
   - C. Um back-to-back user agent (B2BUA) que faz a ponte entre dois canais SIP
   - D. Um SIP load balancer stateless

3. Qual método SIP é usado por um telefone para informar ao registrar seu endereço IP atual, para que ele possa receber chamadas posteriormente?
   - A. INVITE
   - B. OPTIONS
   - C. SUBSCRIBE
   - D. REGISTER

4. Verdadeiro ou Falso: No Asterisk 22, `chan_sip` e `sip.conf` ainda estão disponíveis como um fallback legado ao lado do PJSIP.

5. Com quais objetos de configuração um endpoint deve estar associado para que o Asterisk saiba qual socket de escuta usar e para onde enviar chamadas para aquele dispositivo? (Escolha todas as opções aplicáveis.)
   - A. `type=transport`
   - B. `type=aor`
   - C. `type=identify`
   - D. `type=registration`

6. Em um objeto PJSIP `aor`, qual configuração mantém o mapeamento NAT aberto ao qualificar periodicamente o contato, e qual é a sua unidade?
   - A. `qualify=yes` (booleano)
   - B. `qualify_frequency` (segundos)
   - C. `rtp_timeout` (milissegundos)
   - D. `nat=force_rport`

7. Preencha a lacuna: Para fazer com que o Asterisk combine uma solicitação SIP de entrada com um endpoint específico pelo endereço IP de origem (em vez de pelo cabeçalho `From`), você cria uma seção com `type=________`.

8. Qual objeto PJSIP é usado para configurar um registro **de saída** do Asterisk para um provedor de trunk SIP?
   - A. `type=aor`
   - B. `type=identify`
   - C. `type=registration`
   - D. `type=auth`

9. Na CLI do Asterisk 22, qual comando habilita o registrador de pacotes SIP que imprime cada solicitação e resposta SIP no console?
   - A. `sip set debug on`
   - B. `pjsip set logger on`
   - C. `pjsip debug on`
   - D. `sip show registry`

10. Em um endpoint PJSIP que atende um telefone atrás de um NAT simétrico, qual par de configurações faz com que o Asterisk responda ao endereço de origem da solicitação (RFC 3581) e envie a mídia de volta para onde o RTP realmente chega?
    - A. `direct_media=yes` e `srvlookup=yes`
    - B. `force_rport=yes` e `rtp_symmetric=yes`
    - C. `allowguest=yes` e `insecure=invite`
    - D. `qualify=yes` e `nat=no`

**Respostas:** 1 — B · 2 — C · 3 — D · 4 — Falso · 5 — A, B · 6 — B · 7 — identify · 8 — C · 9 — B · 10 — B
