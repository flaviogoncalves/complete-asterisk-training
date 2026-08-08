# Projetando uma rede VoIP

Voice over IP está crescendo rapidamente no mercado de telefonia. O paradigma de convergência está mudando a maneira como nos comunicamos, reduzindo custos e aprimorando a forma como trocamos informações. A voz é apenas o começo de uma era completa de comunicação multimídia, incluindo voz, vídeo e presença. No futuro, não transportaremos pessoas para o trabalho, mas o trabalho para as pessoas, porque é mais limpo, mais rápido e mais barato. VoIP é apenas parte dessa revolução. Nosso desafio neste capítulo é projetar uma rede VoIP. Para fazer isso, teremos que entender conceitos como protocolos de sessão e codec, bem como dimensionar o número de circuitos e a largura de banda.

## Objetivos

Ao final deste capítulo, você deverá ser capaz de:

- Entender os benefícios do VoIP
- Descrever como o Asterisk lida com VoIP
- Descrever os conceitos dos canais SIP e IAX
- Escolher o protocolo mais adequado para um canal de dados específico
- Escolher o codec mais adequado para um canal de dados específico
- Dimensionar o número necessário de canais
- Calcular a largura de banda necessária

## Benefícios do VoIP

Por que você deveria se importar com VoIP? O VoIP oferece benefícios tanto para empresas quanto para indivíduos. A redução de custos é certamente um deles, mas em alguns ambientes o VoIP simplifica a integração de sistemas computacionais. Vários dos benefícios estão detalhados aqui:

### Convergência

O principal benefício do VoIP é a combinação de redes de dados e voz para reduzir custos (convergência). No entanto, analisar apenas os custos dos minutos de voz pode não ser suficiente para justificar a adoção do VoIP. O preço dos minutos vendidos pelas operadoras de telefonia está se tornando rapidamente mais barato e é algo a ser considerado antes de adotar o VoIP.

### Custos de infraestrutura

O uso de uma única infraestrutura de rede reduz os custos associados a adições, remoções e alterações. Como o IP tornou-se onipresente, ele trouxe a tecnologia relacionada ao VoIP para vários novos dispositivos, como celulares, PDAs, sistemas embarcados e laptops.

### Padrões abertos

Finalmente, os padrões abertos sobre os quais o VoIP é construído oferecem a liberdade de escolher entre diferentes fornecedores. Este único benefício torna o cliente o rei, em vez de um subordinado às TELCOS e aos fabricantes de PBX.

### Integração de Telefonia com Computadores

A telefonia é muito mais antiga que a computação. Os PBXs de telefonia são baseados em comutação de circuitos, e você geralmente não tem mais do que um computador para supervisão. Com o VoIP, a telefonia é criada desde o início com base em padrões computacionais. Isso torna o uso de aplicações de Integração de Telefonia com Computadores mais barato e mais fácil do que no modelo antigo. Você pode criar rapidamente uma longa lista de aplicações de telefonia baseadas em Asterisk. Você pode desenvolver IVRs, ACDs, CTI, discadores, popups de tela e outras aplicações em uma fração do tempo necessário para PBXs tradicionais.

## Arquitetura VoIP do Asterisk

A arquitetura do Asterisk é mostrada abaixo. O Asterisk trata todos os protocolos VoIP como canais. Você pode usar qualquer codec ou qualquer protocolo. O conceito a ser aprendido aqui é que o Asterisk faz a ponte entre qualquer tipo de canal e qualquer outro. Assim, você pode traduzir protocolos de sinalização, como SIP e IAX, entre si e até mesmo com diferentes codecs. Por exemplo, você pode traduzir uma chamada de um softphone SIP na rede local usando o codec G.711 para um trunk SIP para o seu provedor VoIP usando o codec G.729. Nos próximos capítulos, explicaremos os detalhes da arquitetura SIP e IAX. O suporte a H.323 (via add-on chan_ooh323) está disponível, mas é cada vez mais raro; SIP/PJSIP é o padrão para implementações modernas.

![Arquitetura modular do Asterisk: aplicações e canais conectam-se ao núcleo do switch PBX através de APIs, com tradução de codec e módulos de formato de arquivo carregados dinamicamente.]((../images/06-voip-network-fig01.png))

## Protocolos VoIP e a pilha de rede

O VoIP utiliza um conjunto de diferentes protocolos trabalhando em conjunto. É tentador alinhá-los em relação ao modelo de referência OSI de sete camadas, e muitos diagramas antigos fazem exatamente isso — colocando SIP e H.323 na camada de "sessão" e os codecs na camada de "apresentação". Esse mapeamento sempre foi controverso. O IETF, que padroniza o SIP, não utiliza o modelo OSI; ele segue o modelo TCP/IP (DoD) de quatro camadas, mais antigo, e a RFC 3261 define o **SIP como um protocolo da camada de aplicação**. A mídia segue o mesmo padrão: RTP e os codecs residem na carga útil da aplicação, transportados sobre UDP na camada de transporte. A tabela abaixo mapeia os principais protocolos VoIP no modelo TCP/IP que o IETF realmente utiliza, com o equivalente OSI aproximado mostrado apenas para referência.

| Camada TCP/IP (IETF) | Protocolos | Equivalente OSI aproximado |
|---|---|---|
| Aplicação | SIP, H.323, MGCP, sinalização IAX2; RTP/RTCP; codecs (G.711, G.729, Opus…) | Aplicação / Apresentação / Sessão |
| Transporte | UDP, TCP | Transporte |
| Internet | IP (com QoS como DiffServ) | Rede |
| Enlace | Ethernet, PPP, Frame Relay… | Enlace de dados / Física |

Mecanismos de QoS como DiffServ operam na camada IP para priorizar pacotes de voz e melhorar a qualidade da chamada. Algumas especificidades dos protocolos:

- **SIP** utiliza UDP ou TCP na porta 5060 (TLS na 5061) para transportar a sinalização. O áudio é transportado separadamente por RTP sobre um intervalo de portas UDP configurável (o exemplo `rtp.conf` fornecido com o Asterisk utiliza de 10000 a 20000), codificado com um codec como G.711.
- **H.323** transporta a sinalização de chamada sobre TCP (sinalização de chamada H.225 na porta 1720), enquanto o canal RAS H.225 utiliza UDP na porta 1719; o RTP transporta o áudio.
- **IAX2** é incomum: ele multiplexa tanto a sinalização quanto a mídia sobre uma única porta UDP (4569), o que simplifica o NAT e o atravessamento de firewall.


## Como escolher um protocolo

Dada a grande quantidade de protocolos, como você pode escolher o melhor para a sua rede? Nesta seção, destacaremos as vantagens e desvantagens de cada protocolo.

### SIP - Session Initiated Protocol

O SIP é um padrão aberto da Internet Engineering Task Force (IETF), amplamente definido na RFC 3261. A maioria dos provedores de VoIP modernos utiliza SIP; de fato, ele está se tornando o padrão de VoIP mais popular. O ponto forte do SIP é ser um padrão baseado na IETF. O SIP é leve quando comparado ao antigo H.323. A principal fraqueza do SIP é o NAT traversal — um desafio para a maioria dos provedores de VoIP SIP. A IETF não criou o SIP pensando em faturamento, mas sim para comunicações abertas entre pares. O faturamento geralmente é uma preocupação para provedores de VoIP.

### IAX – Inter Asterisk eXchange

O IAX é um protocolo aberto desenvolvido originalmente pela Digium (agora Sangoma). O IAX é um protocolo "tudo em um", pois transporta sinalização e mídia através da mesma porta UDP (4569). Mark Spencer desenvolveu o IAX como um protocolo binário para redução de largura de banda. O principal ponto forte do IAX é seu uso reduzido de largura de banda (ele não utiliza RTP); também é muito fácil para NAT e firewall traversal, já que utiliza apenas uma porta UDP (4569).

Se um fabricante de PBX tradicional tivesse criado o IAX, provavelmente teria comercializado o protocolo como a "melhor invenção desde o sorvete"; em algumas situações, o IAX em modo trunk pode reduzir o uso de largura de banda de voz em um terço. O IAX2 (versão 2) ainda é fornecido no Asterisk 22 através do módulo `chan_iax2` e permanece útil para trunks entre Asterisk, embora seja considerado legado; SIP/PJSIP é preferível para novas implementações. O IAX2 é especificado na [RFC 5456](https://www.rfc-editor.org/rfc/rfc5456) (Informativa).

### MGCP – Media Gateway Control Protocol

O MGCP é um protocolo usado em conjunto com H.323, SIP e IAX. Sua maior vantagem é a escalabilidade. Ele é configurado no agente de chamada em vez dos gateways. Isso simplifica o processo de configuração e permite o gerenciamento centralizado. No entanto, a implementação no Asterisk não é completa, e parece que não muitas pessoas o utilizam.

### H.323

O H.323 é amplamente utilizado em VoIP. É um dos primeiros protocolos de VoIP e é essencial para conectar infraestruturas de VoIP mais antigas baseadas em gateways. O H.323 ainda é o padrão no mercado de gateways, embora o mercado esteja migrando lentamente para o SIP. Os pontos fortes do H.323 incluem a grande adoção pelo mercado e maturidade. As fraquezas do H.323 estão relacionadas à complexidade da implementação e aos custos associados aos órgãos de padronização.

### Tabela de comparação de protocolos

A tabela a seguir resume as diferenças entre os protocolos de sessão.

| Protocolo | Órgão de padronização | Módulo / status no Asterisk 22 | Usado para |
|----------|---------------|-----------------------------|----------|
| SIP | Padrão IETF | `chan_pjsip` (núcleo; o único driver SIP — `chan_sip` foi removido no Asterisk 21) | Telefones SIP; conexão com provedores de serviço SIP |
| IAX2 | RFC 5456 (Informativa) | `chan_iax2` (núcleo; ainda fornecido, considerado legado) | Trunks entre Asterisk; telefones IAX2; provedores de serviço IAX |
| H.323 | Padrão ITU | `chan_ooh323` (complemento externo da comunidade, não na compilação base) | Telefones e gateways H.323 (pode usar um gatekeeper externo, não pode ser um) |
| MGCP | IETF/ITU | `chan_mgcp` removido no Asterisk 21 — não está mais disponível | (telefones MGCP legados) |
| SCCP (Skinny) | Proprietário Cisco | `chan_skinny` removido no Asterisk 21 — não está mais disponível | (telefones Cisco legados) |

## Um endpoint por dispositivo

No Asterisk 22, a stack PJSIP modela cada telefone, trunk ou gateway como um único objeto **endpoint** em `pjsip.conf`. Um endpoint tanto realiza quanto recebe chamadas; suas credenciais residem em um objeto `auth`, seu endereço registrado em um `aor` e seu caminho de rede em um `transport`. Você configura um endpoint por dispositivo e anexa as partes de que ele precisa — não há uma função separada de "user" versus "peer" para se preocupar. (O modelo de objeto completo é abordado em *SIP & PJSIP in depth*.)

## Codecs e tradução de codec

Você usará um codec para converter a voz de uma onda analógica para um sinal digital. Os codecs diferem entre si em aspectos como qualidade de som, taxa de compressão, largura de banda e requisitos computacionais. Serviços, telefones e gateways geralmente suportam vários desses aspectos. O codec G.729 é muito popular. Ele não faz parte da compilação padrão do Asterisk 22; em vez disso, ele é fornecido como um módulo adicional externo (`codec_g729`) que você baixa da Digium (agora Sangoma). A fonte `menuselect` do Asterisk o lista com `support_level=external` e observa claramente: "Baixe o codec g729a da Digium. Uma licença deve ser adquirida para este codec." Em outras palavras, o uso legal do G.729 requer a compra de uma licença por canal. (Uma alternativa de código aberto, `bcg729`, também existe.)

![Modulação por Código de Pulso (PCM): um sinal analógico de 4000 Hz é amostrado 8000 vezes por segundo (teorema de Nyquist) e codificado em um fluxo de bits digital de 64 Kbps.](../images/06-voip-network-fig04.png)

O Asterisk 22 suporta os seguintes codecs (entre outros):

- GSM: 13 Kbps
- iLBC: 13.3 Kbps
- ITU G.711 (ulaw/alaw): 64 Kbps — qualidade padrão de PSTN; ulaw comum na América do Norte, alaw comum na Europa e América Latina
- ITU G.722: 64 Kbps — banda larga (voz HD), boa qualidade com a mesma largura de banda do G.711
- ITU G.723.1: 5.3/6.3 Kbps
- ITU G.726: 16/24/32/40 Kbps
- ITU G.729: 8 Kbps — módulo binário externo `codec_g729` baixado da Digium/Sangoma (`support_level=external`; uma licença deve ser adquirida para usá-lo)
- Speex: 2.15 a 44.2 Kbps
- LPC10: 2.4 Kbps
- **Opus**: 6–510 Kbps, variável — codec moderno de banda larga/banda total; excelente qualidade e resiliência à perda de pacotes; fornecido como um módulo binário externo `codec_opus` baixado da Digium/Sangoma (`support_level=external`; nenhuma compra de licença é mencionada, ao contrário do G.729); recomendado para WebRTC e endpoints SIP modernos. (Alternativas de compilação de código aberto existem no GitHub.)

Além disso, o Asterisk permite a tradução entre codecs. Em alguns casos, isso não é possível, como no caso do g723, que é suportado apenas no modo pass-thru. Traduzir de um codec para outro consome muitos recursos da CPU. Portanto, evite isso ao máximo sempre que possível.

## Como escolher um codec

A seleção de codec depende de várias opções, tais como:

- Qualidade de som
- Custos de licenciamento
- Consumo de processamento da CPU
- Requisitos de largura de banda
- Ocultação de perda de pacotes
- Disponibilidade para Asterisk e dispositivos telefônicos

A tabela a seguir compara os codecs mais populares. A qualidade desses codecs é considerada "toll"—em outras palavras, similar à da PSTN.

| Codec | G.711 | G.722 | Opus | G.729A | iLBC | GSM |
|---|---|---|---|---|---|---|
| Banda de áudio | Estreita | Larga (HD) | Estreita–total | Estreita | Estreita | Estreita |
| Largura de banda (Kbps) | 64 | 64 | 6–510 | 8 | 13.33 | 13 |
| Custo/canal | Gratuito | Gratuito | Gratuito | Licença¹ | Gratuito | Gratuito |
| Supressão de quadros² | Nenhuma | Baixa | Excelente | ~3% | ~5% | ~3% |
| Custo de CPU | Muito baixo | Baixo | Méd.–alto | Alto | Alto | Baixo |

Os módulos do Asterisk 22 são: G.711 `codec_ulaw` / `codec_alaw` (core), G.722 `codec_g722` (core), Opus `codec_opus` (externo), G.729 `codec_g729` (externo), iLBC `codec_ilbc` (core) e GSM `codec_gsm` (core). O Opus é "Estreita–total" porque escala de banda estreita até banda total; sua largura de banda (6–510 Kbps) é variável, e sua resistência à supressão de quadros provém de FEC/PLC integrados.

A base da PSTN é o **G.711** — ele é a referência para qualidade "toll" e faz transcodificação gratuitamente dentro do Asterisk. O **G.722** oferece voz em banda larga (HD) nos mesmos 64 Kbps e é uma boa escolha para LAN/interno. O **Opus** é o padrão moderno para WebRTC e endpoints SIP capazes: ele adapta sua taxa de bits, possui correção de erro direta integrada e resiste bem à perda de pacotes; ele é fornecido como o binário externo `codec_opus` (gratuito para download). O **G.729** continua útil em trunks WAN de baixa largura de banda, mas o uso legal requer o `codec_g729` licenciado da Sangoma (gratuito para download, licença por canal para uso) ou a implementação de código aberto **bcg729** como alternativa.

¹ O binário `codec_g729` da Sangoma é gratuito para download, mas requer uma licença comprada por canal para uso legal. O `bcg729` de código aberto é uma alternativa livre de licença.

² A resistência à supressão de quadros refere-se a quão bem a qualidade percebida (MOS) se mantém sob perda de pacotes. O ponto de cruzamento exato varia com a paquetização e as condições da rede; use esta coluna para comparação relativa, não como um valor preciso.

**Recomendações de codec para Asterisk 22:**

- **G.711 (ulaw/alaw):** Use para trunks PSTN e máxima interoperabilidade; custo zero de transcodificação dentro do Asterisk.
- **G.729:** Útil para trunks WAN de baixa largura de banda; o módulo `codec_g729` da Sangoma é gratuito para download, mas requer uma licença comprada por canal para uso.
- **G.722:** Boa escolha para banda larga (voz HD) em extensões LAN/internas; mesma largura de banda que o G.711 com melhor qualidade.
- **Opus:** Recomendado para endpoints modernos, clientes WebRTC e qualquer implementação onde o endpoint ofereça suporte. Taxa de bits adaptável, excelente resiliência à perda de pacotes, disponível gratuitamente via módulo binário `codec_opus` da Sangoma.

## Overhead causado por cabeçalhos de protocolo

Apesar do fato de que os codecs fazem pouco uso de largura de banda, precisamos considerar o overhead causado por cabeçalhos de protocolo como Ethernet, IP, UDP e RTP. Como tal, a largura de banda efetivamente consumida depende dos cabeçalhos utilizados. Em uma rede Ethernet, o requisito é maior do que em uma rede PPP, porque o cabeçalho PPP é mais curto que o Ethernet. Um único pacote de voz G.729, por exemplo, carrega apenas 20 bytes de payload, mas é encapsulado em aproximadamente 58 bytes de cabeçalhos Ethernet, IP, UDP e RTP — portanto, os cabeçalhos, e não o codec, dominam a largura de banda (veja a figura abaixo).

![Um único pacote de voz G.729 em Ethernet: 20 bytes de payload encapsulados em 58 bytes de cabeçalhos Ethernet, IP, UDP e RTP — uma conversa G.729 consome 31,2 Kbps.]((../images/06-voip-network-fig05.png))

- Ethernet (Ethernet+IP+UDP+RTP+G.711) = 95,2 Kbps
- PPP (PPP+IP+UDP+RTP+G.711) = 82,4 Kbps
- Frame-Relay (FR+IP+UDP+RTP+G.711) = 82,8 Kbps

Codec G.729 (8 Kbps)

- Ethernet (Ethernet+IP+UDP+RTP+G.729) = 31,2 Kbps
- PPP (PPP+IP+UDP+RTP+G.729) = 26,4 Kbps
- Frame-Relay (FR+IP+UDP+RTP+G.729) = 26,8 Kbps

Você pode calcular facilmente outros requisitos de largura de banda usando uma calculadora de largura de banda VoIP online, como <https://www.voip.school/bandcalc/bandcalc.php>.


## Engenharia de Tráfego

Uma questão principal no projeto de redes VoIP é o dimensionamento do número de linhas e da largura de banda necessária para um destino específico, como um escritório remoto ou um provedor de serviços. Também é importante dimensionar o número de chamadas simultâneas do Asterisk (parâmetro principal para o dimensionamento do Asterisk).

### Simplificações

A simplificação primária e mais amplamente utilizada é estimar o número de chamadas por tipo de usuário. Por exemplo:

- PBXs empresariais (uma chamada simultânea para cada cinco extension)
- Usuários residenciais (uma chamada simultânea para cada dezesseis usuários)

Exemplo #1 A sede da empresa possui 120 extension e duas filiais — a primeira com 30 extension e a segunda com 15 extension. Nosso objetivo é dimensionar o número de trunk E1 na sede e a largura de banda necessária para a rede Frame-Relay.

![Topologia de rede de exemplo (mesma cidade): a sede com 120 extension conecta-se à PSTN via linhas T1, e à filial #1 (30 extension) e filial #2 (15 extension) via uma nuvem Frame-Relay.]((../images/06-voip-network-fig06.png))

1a Número de linhas T1

- Número total de extension usando linhas T1: 120+30+15=165 linhas
- Usando um trunk para cada cinco extension para uso comercial
- Número total de linhas = 33 ou aproximadamente 2xT1 linhas

1b Requisitos de largura de banda Escolhemos o codec g.729 devido aos requisitos de largura de banda, qualidade de som e consumo médio de CPU.

Com um trunk para cada cinco extension:

- Largura de banda necessária para a filial #1 (Frame-relay): 26.8*6=160.8 Kbps
- Largura de banda necessária para a filial #2 (Frame-relay): 26.8*3= 80.4 Kbps

### Método Erlang B

Quando você possui dados históricos, pode dimensionar o trunk de forma mais científica em vez de simplificar. Usaremos o trabalho de Agner Karup Erlang (Copenhagen Telephone Company, 1909), que desenvolveu uma fórmula para calcular o número de linhas em um grupo de trunk entre duas cidades.

Um **Erlang** é uma unidade de medição de tráfego comum em telecomunicações; ele descreve o volume de tráfego durante uma hora. Por exemplo, suponha que 20 chamadas ocorram em uma hora, com uma média de 5 minutos de conversação cada:

- Minutos de tráfego na hora: 20 × 5 = 100 minutos
- Horas de tráfego dentro de uma hora: 100 / 60 = **1.66 Erlangs**

Você pode ler essas medidas a partir de um registrador de chamadas e usá-las para projetar sua rede e calcular o número de linhas necessárias. Uma vez conhecido o número de linhas, você pode calcular os requisitos de largura de banda.

**Erlang B** é o método mais comumente usado para calcular o número de linhas em um grupo de trunk. Ele assume que as chamadas chegam aleatoriamente (uma distribuição de Poisson) e que as chamadas bloqueadas são imediatamente descartadas. Ele exige que você conheça o **Busy Hour Traffic (BHT)**, que você pode obter de um registrador de chamadas ou estimar como uma simplificação: BHT = 17% dos minutos de chamada de um dia.

![Resultados da calculadora Erlang B: 5 Erlangs com 1% de bloqueio requerem 11 linhas (sede para filial #1), e 2.83 Erlangs com 1% de bloqueio requerem 8 linhas (sede para filial #2).]((../images/06-voip-network-fig07.png))

Outra variável importante é o Grade of Service (GoS), que define a probabilidade de bloqueio de chamadas por falta de linhas. Você pode arbitrar este parâmetro, que geralmente é 0.05 (5% de chamadas perdidas) ou 0.01 (1% de chamadas perdidas). Exemplo #1: Usando o mesmo exemplo de sede e duas filiais introduzido anteriormente nesta seção, forneceremos alguns dados sobre padrões de tráfego. A partir do registrador de chamadas, descobrimos estes dados: Dados do registrador de chamadas (Minutos de chamada e BHT):

- Sede para Filial #1 = 2,000 minutos, BHT = 300 minutos
- Sede para Filial #2 = 1,000 minutos, BHT = 170 minutos
- Filial #1 para Filial #2 = 0, BHT=0

Vamos arbitrar GoS=0.01

- Sede para Filial #1 - BHT=300 minutos/60 = 5 Erlangs
- Sede para Filial #2 – BHT=170 minutos/60 = 2.83 Erlangs

Usando uma calculadora Erlang como <https://www.erlang.com>

- Para a Sede para Filial #1, 11 linhas são necessárias.
- Para a Sede para Filial #2, 8 linhas são necessárias

1.b Largura de banda necessária Estamos usando uma WAN onde a perda de pacotes é rara. Escolheremos o codec g729 devido à sua boa qualidade de som e compressão de dados (8 Kbps).

Codec selecionado: g729 Camada de enlace de dados: Frame-Relay

- Largura de banda de voz estimada para Filial #1: 26.8x11 = 294.8 Kbps
- Largura de banda de voz estimada para Filial #2: 26.8x8 = 214.40 Kbps

## Reduzindo a largura de banda necessária para VoIP

Três métodos podem ser usados para reduzir a largura de banda necessária para chamadas VoIP:

- Compressão de cabeçalho RTP
- IAX Trunked
- Payload de VoIP

### Compressão de cabeçalho RTP

Em redes Frame-Relay e PPP, você pode usar a compressão de cabeçalho RTP. A compressão de cabeçalho RTP foi definida na RFC 2508. É um padrão IETF disponível em vários roteadores. No entanto, seja cauteloso, pois alguns roteadores exigem um conjunto de recursos diferente para que este recurso esteja disponível. O impacto do uso da compressão de cabeçalho RTP é fabuloso, pois reduz a largura de banda necessária em nosso exemplo de 26.8 Kbps por conversa de voz para 11.2 Kbps — uma redução de 58.2%!

### Modo trunk IAX2

Se você estiver conectando dois servidores Asterisk, pode usar o protocolo IAX2 no modo trunk. Esta tecnologia revolucionária não precisa de nenhum roteador especial e pode ser aplicada a qualquer tipo de link de dados.

![Modo trunk IAX2 em Ethernet: uma única chamada g.729 precisa de sua pilha de cabeçalho completa (31.2 Kbps), mas uma segunda chamada compartilha esses cabeçalhos e adiciona apenas um pequeno miniframe IAX2, com média de cerca de 9.6 Kbps de largura de banda extra por chamada adicional.](IAX2_trunk_mode.png)(../images/06-voip-network-fig08.png)

O modo trunk IAX2 reutiliza os mesmos cabeçalhos a partir da segunda chamada em diante. Usando g729 em um link PPP, a primeira chamada consumirá 30 Kbps de largura de banda, enquanto a segunda chamada usará o mesmo cabeçalho da primeira e reduzirá a largura de banda necessária para a chamada adicional para 9.6 Kbps. Podemos calcular a largura de banda necessária no modo trunk da seguinte forma: Filial #1 (11 chamadas) Largura de banda = 31.2 + (11-1)* 9.6 Kbps = 127.2 Kbps Filial #2 (8 chamadas) Largura de banda = 31.2 + (8-1)* 9.6 Kbps = 98.4 Kbps A primeira chamada usa 31.2 Kbps, a próxima 9.6, e assim por diante.

### Aumentando o Payload de voz

Este método é muito comum ao usar gateways VoIP pela Internet. Ao usar um payload maior, você sacrificará a latência em favor da redução da largura de banda. Você pode alterar a pacotização RTP anexando o tamanho do frame ao codec na instrução allow.

![Aumentando o payload de voz: empacotar 60 bytes de payload g.729 em um pacote (em vez de 20) amortece os 58 bytes de cabeçalhos em mais voz, reduzindo a largura de banda para cerca de 16.05 Kbps por chamada ao custo de latência adicional.](Increasing_voice_payload.png)(../images/06-voip-network-fig09.png)

Exemplo:

```
allow=ulaw:30
```

O número após os dois pontos é o intervalo de pacotização em milissegundos — quanta voz é transportada em cada pacote RTP. Um valor maior amortece a sobrecarga fixa do cabeçalho em mais áudio (menos largura de banda) ao custo de latência adicional. Cada codec tem seu próprio tamanho de frame mínimo, máximo e padrão; G.711 (`ulaw`/`alaw`), por exemplo, tem como padrão 20 ms.

## Resumo

Neste capítulo, você aprendeu que o Asterisk trata VoIP usando canais. Ele suporta SIP (via `chan_pjsip` no Asterisk 22) e IAX2; o H.323 está disponível apenas através do complemento comunitário `ooh323`, e os canais MGCP e SCCP (Skinny) mais antigos não fazem mais parte de uma compilação padrão do Asterisk 22. Você comparou e aprendeu como escolher um protocolo de sinalização e um codec para canais VoIP. O IAX2 é mais eficiente em largura de banda e pode atravessar NAT facilmente. SIP/PJSIP é o protocolo com maior suporte por fornecedores terceiros de telefones e gateways, sendo o único driver de canal SIP no Asterisk 22. O protocolo H.323 é o mais antigo e deve ser usado para conectar a infraestruturas VoIP legadas. Na seção de Engenharia de Tráfego, aprendemos como projetar e dimensionar uma rede VoIP.

## Quiz

1. Quais dos itens a seguir são benefícios do VoIP descritos neste capítulo (marque todos os que se aplicam)?
   - A. Convergência de redes de dados e voz para reduzir custos
   - B. Menor custo de infraestrutura para adições, remoções e alterações
   - C. Padrões abertos que libertam você de um único fornecedor
   - D. Integração de Telefonia por Computador (CTI) mais fácil e barata
   - E. Tarifas de chamadas por minuto garantidamente mais baixas do que qualquer companhia telefônica
2. Convergência é a integração de voz, dados e vídeo em uma única rede; seu principal benefício é a redução de custos na implementação e manutenção de redes separadas.
   - A. Falso
   - B. Verdadeiro
3. O Asterisk trata cada protocolo VoIP como um canal e pode fazer a ponte entre qualquer tipo de canal para qualquer outro, realizando a transcodificação entre codecs quando necessário.
   - A. Falso
   - B. Verdadeiro
4. No Asterisk 22, o SIP é gerenciado por qual driver de canal?
   - A. chan_sip
   - B. chan_pjsip
   - C. chan_skinny
   - D. chan_mgcp
5. No modelo TCP/IP (IETF), no qual o SIP é definido na RFC 3261, os protocolos de sinalização SIP, H.323 e IAX2 operam na camada ___.
   - A. Apresentação
   - B. Aplicação
   - C. Física
   - D. Sessão
   - E. Enlace de dados
6. O SIP é o protocolo mais adotado para telefones IP e é um padrão aberto amplamente definido pela IETF na RFC 3261.
   - A. Falso
   - B. Verdadeiro
7. O IAX2 transporta tanto a sinalização quanto a mídia sobre uma única porta UDP, o que o torna eficiente e fácil de atravessar NAT. Qual porta UDP o IAX2 utiliza?
   - A. 5060
   - B. 1720
   - C. 4569
   - D. 5061
8. O IAX foi originalmente desenvolvido pela Digium (agora Sangoma). Apesar da adoção limitada por fabricantes de telefones, o IAX é excelente quando você precisa (marque todos os que se aplicam):
   - A. Reduzir o uso de largura de banda (ele não utiliza RTP)
   - B. De um formato de mídia de vídeo
   - C. Facilidade na travessia de NAT e firewall
   - D. Modo trunk para combinar muitas chamadas Asterisk-para-Asterisk e amortizar o overhead de cabeçalho
9. No Asterisk 22, um dispositivo é configurado como um único objeto PJSIP `endpoint` que tanto realiza quanto recebe chamadas — não existe uma função separada de "user" ou "peer".
   - A. Falso
   - B. Verdadeiro
10. Com relação aos codecs no Asterisk 22, marque todas as afirmações verdadeiras:
    - A. G.711 é equivalente a PCM e utiliza 64 Kbps de largura de banda.
    - B. O módulo codec_g729 da Sangoma é gratuito para download, mas o uso legal requer a compra de uma licença por canal.
    - C. GSM é popular porque utiliza cerca de 13 Kbps e não precisa de licença.
    - D. G.711 u-law é comum na América do Norte, enquanto a-law é comum na Europa e América Latina.
    - E. G.729 é leve e utiliza poucos recursos de CPU para codificar e decodificar em comparação com o G.711.

**Respostas:** 1 — A, B, C, D · 2 — B · 3 — B · 4 — B · 5 — B (Aplicação — SIP é um protocolo de camada de aplicação no modelo TCP/IP que a IETF utiliza) · 6 — B · 7 — C · 8 — A, C, D · 9 — B · 10 — A, B, C, D
