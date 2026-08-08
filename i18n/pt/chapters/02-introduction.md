# Introdução ao Asterisk PBX

A popularidade de distribuições prontas para uso, como FreePBX e Issabel, cresceu recentemente. Neste livro, abordaremos o Asterisk clássico, que é a base para a compreensão dessas distribuições. Asterisk PBX é um software de código aberto capaz de transformar um PC comum em um poderoso PBX multiprotocolo. Neste capítulo, aprenderemos sobre as possibilidades desta nova tecnologia e sua arquitetura básica.

## Objetivos

Ao final deste capítulo, você deverá ser capaz de:

- Explicar o que é o Asterisk e o que ele faz;
- Descrever o papel da Digium™ e de sua sucessora Sangoma;
- Reconhecer a arquitetura básica do Asterisk e seus componentes;
- Apontar diversos cenários de uso; e
- Identificar fontes de informação e ajuda.

## O que é o Asterisk

Asterisk é um software de PBX de código aberto que transforma um computador comum em um PBX completo para usuários domésticos, empresas, provedores de serviços VoIP e companhias telefônicas. O Asterisk também é tanto uma comunidade de código aberto quanto um projeto patrocinado pela Sangoma Technologies (que adquiriu a Digium em 2018). Você é livre para usar e modificar o Asterisk para atender às suas necessidades. O Asterisk permite a conectividade em tempo real entre redes PSTN e VoIP. Como o Asterisk é muito mais do que um PBX, você não apenas tem uma atualização excepcional para o seu PBX existente, mas também pode realizar novas tarefas em telefonia, tais como:

- Conectar funcionários que trabalham de casa a um PBX de escritório através de Internet banda larga;
- Conectar vários escritórios em locais diferentes através de uma rede IP, rede privada ou até mesmo pela própria Internet;
- Oferecer aos seus funcionários um voicemail integrado à web e ao e-mail;
- Construir aplicações como IVRs que permitem conexões ao seu sistema de pedidos ou outras aplicações;
- Dar a usuários em viagem acesso ao PBX da empresa de qualquer lugar com uma simples conexão de banda larga ou VPN; e
- muito mais....

O Asterisk inclui diversos recursos avançados anteriormente encontrados apenas em sistemas de alto nível, tais como:

- Música para clientes em espera em filas de chamadas, com suporte a streaming de mídia e arquivos MP3;
- Filas de chamadas, onde uma equipe de agentes pode atender chamadas e monitorar filas;
- Integração com text-to-speech e reconhecimento de voz;
- Registros detalhados transferidos tanto para arquivos de texto quanto para bancos de dados SQL; e
- Conectividade PSTN através de linhas digitais e analógicas.

## O que é o AsteriskNOW (Histórico) e o FreePBX

O Asterisk em sua forma mais pura, também conhecido como "classic asterisk" (denominação do pacote Debian), é considerado mais uma ferramenta de desenvolvimento do que um produto acabado por si só. O AsteriskNOW foi uma iniciativa para transformar o Asterisk em um soft-appliance. A distribuição incluía o CentOS como sistema operacional e o FreePBX como interface gráfica. O AsteriskNOW foi descontinuado desde então.

Hoje, a distribuição padrão pronta para uso do Asterisk é o **FreePBX** (mantido pela Sangoma), que agrupa o Asterisk com uma GUI de administração baseada na web e um ecossistema de módulos. O FreePBX é licenciado de acordo com a GPL e pode ser baixado gratuitamente em www.freepbx.org. Para implementações comerciais, a Sangoma também oferece a **FreePBX Distro** (uma imagem Linux completa) e seu produto comercial **PBXact**.

## Papel da Digium™ e da Sangoma

A Digium, uma empresa localizada em Huntsville, Alabama, foi a criadora e principal desenvolvedora do Asterisk desde a sua fundação em 1999. Além de ser a principal patrocinadora do desenvolvimento do Asterisk, a Digium produzia placas de interface de telefonia e outros hardwares para PBXs Asterisk, e criou produtos comerciais como o Switchvox (voltado para o mercado de PMEs). Em 2018, a Digium foi adquirida pela **Sangoma Technologies**, uma empresa canadense de comunicações unificadas. Desde a aquisição, a Sangoma continuou a patrocinar o desenvolvimento do Asterisk e atua como sua principal administradora, mantendo o projeto de código aberto em www.asterisk.org.

Historicamente, a Digium oferecia o Asterisk sob três tipos de contratos de licença:

- Asterisk sob a General Public License (GPL). Esta é a versão mais utilizada. Inclui todos os recursos e é gratuita para ser usada e modificada de acordo com os termos da licença GPL.
- Asterisk Business Edition era uma versão comercial do Asterisk. Algumas empresas usavam a edição business porque não queriam ou não podiam usar a licença GPL — geralmente porque não queriam liberar seu código-fonte junto com o Asterisk. **Nota:** O Asterisk Business Edition foi descontinuado; hoje o Asterisk é distribuído exclusivamente sob a GPL.
- Licenciamento OEM do Asterisk. Depois que a Digium parou de vender o Asterisk Business Edition no varejo, ela continuou a licenciar essa edição comercial para clientes OEM — fornecedores de equipamentos que desejavam construir produtos proprietários sobre o Asterisk sem liberar seu próprio código-fonte sob a GPL.

### O projeto Zapata e seu relacionamento com o Asterisk

O projeto Zapata foi desenvolvido por Jim Dixon, que também foi responsável pelo design de hardware revolucionário usado com o Asterisk. O hardware também é de código aberto; como tal, pode ser usado por qualquer empresa, e hoje vários fabricantes produzem placas compatíveis com essa arquitetura.

O projeto Zapata produziu uma arquitetura chamada Zaptel, posteriormente renomeada para DAHDI (Digium/Asterisk Hardware Device Interface). Um dos principais benefícios dessa arquitetura é a capacidade de usar a CPU do PC para processar streaming de mídia, cancelamento de eco e transcodificação. Em contraste, a maioria das placas existentes usa processadores de sinal digital (DSP) para realizar essas tarefas. O uso da CPU do PC em vez de DSPs dedicados reduz drasticamente o preço da placa. Assim, essas placas são significativamente mais baratas do que as interfaces anteriormente disponíveis de outros fabricantes. Por outro lado, essas placas exigem muita CPU; um uso indevido da CPU do PC pode impactar significativamente a qualidade da voz. Recentemente, a Digium lançou uma placa coprocessadora que usa DSPs para codificar e decodificar G.729 e G.723, permitindo melhor escalabilidade para um grande número de canais.

## Por que Asterisk?

Lembro-me do meu primeiro contato com o Asterisk. Geralmente, a primeira reação a algo novo — especialmente algo que compete com o que você já conhece — é rejeitá-lo! Foi exatamente isso que aconteceu em 2003. O Asterisk estava competindo com uma solução que eu estava vendendo para um cliente (Gateway VoIP de 4 E1), e era dez vezes mais barato do que o que eu estava cobrando pela solução que eu já conhecia. Esse preço desproporcional me levou a começar a estudar o Asterisk para identificar possíveis armadilhas e desvantagens. Por exemplo, descobri que a CPU do PC daquela época não suportaria 120 sessões simultâneas de g.729; no fim das contas, ganhei a proposta com minha solução de Gateway.

No entanto, esse exercício me levou à descoberta de que o Asterisk poderia resolver uma variedade de problemas muito caros para minha base de clientes. Estávamos com problemas devido a orçamentos caros para IVR, mensagens unificadas, gravação de chamadas e discadores; com o dimensionamento apropriado, os problemas de CPU poderiam ser contornados. De fato, em apenas três anos, o Asterisk tornou-se o principal produto da minha empresa (na verdade, decidi abrir outra empresa apenas para o negócio de Asterisk). Na minha opinião, o Asterisk é uma revolução nas telecomunicações que representa para a telefonia IP o que o Apache representa para os serviços web.

### Redução extrema de custos

Se você comparar um PBX tradicional com o Asterisk em relação a interfaces digitais e telefones, o Asterisk é ligeiramente mais barato do que esses PBXs. No entanto, o Asterisk realmente compensa quando você adiciona recursos avançados como voicemail, ACD, IVR e CTI. Com esses recursos avançados, o Asterisk torna-se significativamente menos caro do que os PBXs tradicionais. Na verdade, comparar PBXs Asterisk com PBXs analógicos de baixo custo é injusto, porque o Asterisk oferece muitos recursos não disponíveis em sistemas analógicos de baixo custo.

### Controle e independência do sistema de telefonia

Um dos benefícios do Asterisk mais citados pelos clientes é a independência que ele proporciona. Alguns dos fabricantes atuais nem sequer fornecem ao cliente a senha do sistema ou a documentação de configuração. Com a abordagem "faça você mesmo" do Asterisk, o usuário obtém total liberdade; como bônus, o usuário tem acesso a uma interface padrão.

### Ambiente de desenvolvimento fácil e rápido

O Asterisk pode ser estendido usando linguagens de script como PHP e Perl com interfaces AMI e AGI. O Asterisk é open-source, e seu código-fonte pode ser modificado pelo usuário. O código-fonte é escrito principalmente na linguagem de programação ANSI C.

### Rico em recursos

O Asterisk possui vários recursos que não são encontrados ou são opcionais em PBXs tradicionais (por exemplo, voicemail, CTI, ACD, IVR, música de espera integrada e gravação). Os custos desses recursos em algumas plataformas excedem o preço da própria plataforma.

### Conteúdo dinâmico no telefone

O Asterisk é programado usando a linguagem C e outras linguagens comuns no ambiente de desenvolvimento atual. A possibilidade de fornecer conteúdo dinâmico é praticamente ilimitada.

### Dialplan flexível e poderoso

Outro avanço do Asterisk é seu poderoso dialplan. Em PBXs tradicionais, até mesmo recursos simples como o roteamento de menor custo (LCR) não são viáveis ou são opcionais. Com o Asterisk, escolher a melhor rota é fácil e limpo.

### Open-source rodando sobre Linux

Uma das maiores características do Asterisk é sua comunidade. Vários recursos estão disponíveis, incluindo a documentação oficial do Asterisk (docs.asterisk.org), a wiki VoIP-Info mantida pela comunidade (www.voip-info.org <http://www.voip-info.org>), listas de distribuição de e-mail e fóruns. À medida que o Asterisk se torna cada vez mais adotado, bugs são encontrados e corrigidos rapidamente. Com uma grande base de usuários e uma equipe de desenvolvimento ativa, o Asterisk está entre as plataformas de PBX mais testadas do mundo, o que ajuda a manter a base de código estável e madura.

### Limitações da arquitetura do Asterisk

Algumas limitações no Asterisk decorrem do uso do design de telefonia Zapata. Nesse design, o Asterisk usa a CPU do PC para processar canais de voz em vez de processadores de sinal digital (DSPs) dedicados, que são comuns em outras plataformas. Embora isso permita uma enorme redução de custos na interface de hardware, o sistema torna-se dependente da CPU do PC. Minha recomendação é executar o Asterisk em uma máquina dedicada e ser conservador quanto ao dimensionamento do hardware. Você também pode usar o Asterisk em uma VLAN separada para evitar broadcasts excessivos que consomem a CPU (tempestades de broadcast causadas por loops ou vírus). Algumas placas de interface mais novas de vários fornecedores agora estão incluindo DSPs para processar cancelamento de eco, codecs e outros recursos, o que tornará o Asterisk ainda melhor.

## Principais objeções ao Asterisk PBX

É comum ouvir objeções à adoção do Asterisk, as quais abordaremos aqui.

### A participação de mercado do Asterisk é muito pequena

A participação de mercado é geralmente medida pelo número de PBXs vendidos. Essas estatísticas são geralmente adquiridas dos maiores distribuidores. O Asterisk é um software livre que pode ser baixado e implantado sem que nenhuma venda seja registrada, portanto, ele é sistematicamente subcontado nesses números. Mesmo assim, o Asterisk impulsiona uma base instalada muito grande em todo o mundo — desde PBXs de escritório em servidor único até grandes implementações de operadoras e contact-centers — e permanece como o motor dominante por trás do ecossistema de PBX open-source (incluindo distribuições prontas para uso, como o FreePBX).

### Se é gratuito, como o fabricante sobrevive?

Na verdade, não existe um fabricante de software open-source no sentido tradicional. A Digium desenvolveu o Asterisk desde 1999, sustentando-se através de vendas de placas de interface de telefonia, produtos de PBX comerciais como o Switchvox e softwares relacionados. Em 2018, a Sangoma Technologies adquiriu a Digium. A Sangoma continua a financiar o desenvolvimento do Asterisk e gera receita através de produtos comerciais (módulos comerciais do FreePBX, PBXact, Switchvox), vendas de hardware e serviços profissionais.

### É difícil encontrar suporte técnico!

A Sangoma fornece suporte técnico comercial para o Asterisk através de seu ecossistema de parceiros e diretamente por meio de suas ofertas de produtos. Uma rede global de profissionais certificados fornece suporte de primeira linha e serviços profissionais. O suporte da comunidade permanece ativo através dos fóruns do Asterisk e listas de discussão em www.asterisk.org.

### O Asterisk suporta mais de 200 extensions?

Sim, absolutamente. Um único servidor Asterisk bem dimensionado pode lidar com um grande número de extensions, e o Asterisk escala ainda mais distribuindo usuários em vários servidores com balanceamento de carga e failover, permitindo grandes implementações em vários locais.

### Apenas "geeks" são capazes de instalar o Asterisk

Com o FreePBX (disponível como uma distribuição independente da Sangoma), até mesmo profissionais com conhecimento limitado sobre Linux são capazes de instalar e configurar um PBX de média complexidade. Com a ajuda de uma GUI, é possível configurar um PBX inteiro em apenas algumas horas.

### E se o servidor falhar?

Uma das principais vantagens do Asterisk é sua capacidade de rodar em sistemas tolerantes a falhas. É relativamente simples e barato ter dois servidores rodando em paralelo. Eu desafio você a tentar isso com um PBX convencional!

### Nossa empresa não usa software open-source

Sua empresa provavelmente usa software open-source sem nem perceber. Vários dispositivos usam Linux como seu sistema operacional. Além disso, suporte comercial e implementações gerenciadas estão disponíveis através da Sangoma e sua rede de parceiros certificados.

### Usar a CPU do PC para processar sinalização e mídia não é recomendado

O Asterisk usa a CPU do servidor para processar sinalização e mídia para canais de voz em vez de ter DSPs dedicados. Embora isso permita uma redução de custos de até cinco vezes, torna o sistema dependente do desempenho da CPU principal. Com o dimensionamento correto, o Asterisk é capaz de lidar com grandes volumes. Se você ainda quiser liberar a CPU principal dessas tarefas, você também pode usar cancelamento de eco por hardware e até mesmo placas transcodificadoras, como a Sangoma (anteriormente Digium) TC400B baseada em DSPs.

## Arquitetura do Asterisk

Esta seção explicará como a arquitetura do Asterisk funciona. A figura abaixo mostra a arquitetura básica do Asterisk. A seguir, explicaremos conceitos relacionados à arquitetura, incluindo channels, codecs e aplicações.

![A arquitetura do Asterisk](../images/01-introduction-fig01.png)

### Channels

Um channel é o equivalente a uma linha telefônica, mas em formato digital. Ele geralmente consiste em um sistema de sinalização analógico ou digital (TDM) ou uma combinação de codec e protocolo de sinalização (por exemplo, SIP-GSM, IAX-uLaw). Inicialmente, todas as conexões de telefonia eram analógicas e suscetíveis a eco e ruído. Mais tarde, a maioria dos sistemas foi convertida para sistemas digitais, com o som analógico convertido para um formato digital usando modulação por código de pulso (PCM) na maioria dos casos. Este formato permite a transmissão de voz em 64 kilobits/segundo sem compressão.

Channels que fazem interface com a PSTN:

- `chan_dahdi`: placas TDM analógicas (FXO/FXS) e digitais (E1/T1/PRI) da Sangoma (anteriormente Digium), Xorcom e outros. Compilados separadamente contra DAHDI — veja o capítulo *Legacy channels*.

Channels que fazem interface com Voice over IP:

- `chan_pjsip`: SIP — o principal e único driver de channel SIP no Asterisk 22 LTS. Dial string: `PJSIP/endpoint_name`. (**Nota:** o antigo `chan_sip` foi removido no Asterisk 21 e não existe no Asterisk 22. Veja *Building your first PBX with PJSIP* para configuração.)
- `chan_iax2`: o protocolo IAX2 — ainda é fornecido no Asterisk 22, mas é legado; SIP/PJSIP é preferido para novas implementações. Dial string: `IAX2/peer`.
- `chan_unistim`: telefones Nortel/Avaya UNISTIM. Ainda disponível (suporte estendido), mas raramente usado.

Os channels VoIP mais antigos não fazem mais parte de uma instalação padrão do Asterisk 22: `chan_h323` (H.323) sobrevive apenas como o add-on da comunidade `ooh323`, e `chan_mgcp` (MGCP) e `chan_skinny` (Cisco SCCP) foram descontinuados e removidos do conjunto moderno de channels. Se você precisar interoperar com esses protocolos, um gateway na frente do Asterisk é a abordagem usual.

Channels diversos:

- **Local**: um pseudo-channel (integrado ao core) que faz um loop de volta para o dialplan em um context diferente — útil para roteamento recursivo e para distribuir uma chamada para múltiplos destinos. Dial string: `Local/extension@context`.

### Codec e tradução de codec

Geralmente tentamos colocar o maior número possível de conexões de voz em uma rede de dados. Codecs habilitam novos recursos na voz digital, incluindo compressão, que é um dos recursos mais importantes, pois permite taxas de compressão superiores a 8 para 1. Muitos codecs também definem recursos como detecção de atividade de voz (supressão de silêncio), ocultação de perda de pacotes e geração de ruído de conforto, embora o Asterisk por si só não gere ruído de conforto nem execute supressão de silêncio. Vários codecs estão disponíveis para o Asterisk e podem ser traduzidos de forma transparente de um para outro. Internamente, o Asterisk usa slinear como formato de fluxo quando precisa converter de um codec para outro. Alguns codecs no Asterisk são suportados apenas no modo pass-through; esses codecs não podem ser traduzidos. Para verificar quais codecs estão instalados em seu sistema, você pode usar o comando de console:

```
CLI>core show translation
```

Os seguintes codecs são suportados:

- G.711 ulaw (EUA) - (64 Kbps).
- G.711 alaw (Europa) - (64 Kbps).
- G.722 (Alta Definição) – (64 Kbps)
- G.723.1 - Apenas modo pass-through
- G.726 - (16/24/32/40kbps)
- G.729 - Módulo de codec binário distribuído pela Sangoma; o download é gratuito, mas o uso legal requer a compra de uma licença por channel (8Kbps)
- GSM - (12-13 Kbps)
- iLBC - (15 Kbps)
- LPC10 - (2.4 Kbps)
- Speex - (2.15-44.2 Kbps)
- Opus - (6-510 Kbps)

### Protocolos

Enviar dados de um telefone para outro deveria ser fácil, desde que os dados encontrassem um caminho para o outro telefone por conta própria. Infelizmente, não acontece dessa forma, e um protocolo de sinalização é necessário para estabelecer conexões entre telefones, descobrir dispositivos finais e implementar sinalização de telefonia. SIP é o protocolo de sinalização dominante em implementações modernas e é o único channel SIP disponível no Asterisk 22 LTS (via chan_pjsip). IAX2 ainda está disponível, mas é considerado legado. O Asterisk suporta os seguintes protocolos.

- SIP — via `chan_pjsip`
- IAX2 — legado, ainda fornecido no Asterisk 22
- UNISTIM — telefones Nortel/Avaya (suporte estendido)
- H.323, MGCP e SCCP (Cisco Skinny) — protocolos legados que não estão mais em uma instalação padrão do Asterisk 22 (H.323 apenas via add-on da comunidade `ooh323`)

### Aplicações

Para conectar chamadas de um telefone para outro, a aplicação dial() é usada. A maioria dos recursos do Asterisk (por exemplo, voicemail e conferência) são implementados como aplicações. Você pode ver as aplicações do Asterisk disponíveis usando o comando de console core show applications.

```
CLI>core show applications
```

Você pode adicionar aplicações a partir de add-ons do Asterisk, provedores terceiros ou até mesmo aquelas que você mesmo desenvolve.

## Visão geral de um sistema Asterisk

O Asterisk é um PBX de código aberto que atua como um PBX híbrido, integrando tecnologias como TDM e telefonia IP. O Asterisk está pronto para implementar funcionalidades como IVR e distribuição automática de chamadas (ACD); além disso, como mencionado anteriormente, ele é aberto ao desenvolvimento de novas aplicações. Esta figura mostra como o Asterisk se conecta à PSTN e a PBXs existentes usando interfaces analógicas e digitais, além de suportar telefones analógicos e IP. Ele pode atuar como um SoftSwitch, media gateway, voicemail, conferência de áudio e também possui música de espera integrada.

![Visão geral de um sistema Asterisk](../images/01-introduction-fig02.png)

## Comparando o velho e o novo mundo

No antigo modelo de SoftSwitch, todos os componentes eram vendidos separadamente, o que significava que você precisava adquirir cada componente individualmente e então integrá-lo ao ambiente de PBX ou SoftSwitch. Os custos e riscos eram altos e a maior parte do equipamento era proprietária.

![O velho mundo: componentes comprados e integrados separadamente](../images/01-introduction-fig03.png)

### Telefonia usando Asterisk

Todas as funções são integradas na plataforma Asterisk, na mesma caixa ou em caixas diferentes, de acordo com o dimensionamento, e todas possuem licença GPL. Às vezes, é mais fácil instalar o Asterisk do que licenciar alguns dos IP-PBXs convencionais.

![Telefonia usando Asterisk: as funções são integradas](../images/01-introduction-fig04.png)

## Construindo um sistema de teste

Ao implementar uma solução Asterisk, nosso primeiro passo é geralmente construir um sistema de teste. O objetivo é um **1×1 PBX** mínimo — um telefone que pode ligar para outro — para que você possa experimentar endpoints, dialplan e recursos antes de tocar na produção. Hoje, isso é inteiramente via software: você não precisa de nenhum hardware de telefonia.

![Um sistema de teste Asterisk simples](../images/01-introduction-fig05.png)

### A maneira moderna: um laboratório de software (recomendado)

O sistema de teste mais rápido é o Asterisk 22 rodando em um container ou máquina virtual, com **softphones** para os endpoints e, opcionalmente, um **SIP trunk** para alcançar a rede pública:

- **Asterisk 22** em uma pequena máquina Linux, VM ou container Docker. Este livro disponibiliza um laboratório Docker pronto para uso (veja o guia do laboratório) que inicializa um Asterisk 22 totalmente configurado com um único comando — sem compilação, sem hardware.
- **Dois softphones** registrados como endpoints PJSIP, para que você possa realizar uma chamada real entre eles. Ao longo deste livro, usamos o **SipPulse Softphone** (download gratuito: <https://www.sippulse.com/produtos/softphone>), disponível para desktop e mobile.
- **Um SIP trunk** (opcional) de um provedor VoIP, para quando você quiser alcançar a PSTN. Sem placa e sem linha analógica — apenas credenciais.

É assim que cada exemplo neste livro é construído e verificado, e você pode reproduzi-lo em qualquer laptop.

### A maneira legada: placas analógicas/digitais

Antes do VoIP, um PBX de teste precisava de interfaces físicas: uma porta **FXO** para conectar a uma linha telefônica existente e uma porta **FXS** para conectar um telefone analógico, que juntos formavam um PBX 1×1. Uma única placa contendo uma interface FXO e uma FXS era o kit inicial clássico. Essas placas baseadas em DAHDI (da Sangoma, anteriormente Digium) ainda existem para locais que precisam terminar linhas analógicas ou T1/E1, mas hoje são um nicho — a maioria das implementações é puramente VoIP. Se você só precisa conectar telefones ou linhas analógicas, veja o capítulo *Legacy Channels*; caso contrário, você pode ignorar o hardware de telefonia completamente.

## Cenários do Asterisk

O Asterisk pode ser utilizado em diversos cenários diferentes. Listaremos alguns deles e explicaremos as vantagens e possíveis limitações de cada um.

### IP PBX

O cenário mais comum é a instalação de um novo PBX ou a substituição de um já existente. Se você comparar o Asterisk com outras alternativas, descobrirá que ele é mais barato e mais rico em recursos do que a maioria dos PBXs disponíveis atualmente no mercado. Diversas empresas estão mudando suas especificações para o Asterisk em vez de outros PBXs de marca.

![Asterisk como um IP PBX](../images/01-introduction-fig06.png)

### Habilitando IP em PBXs legados

A imagem a seguir ilustra uma das configurações mais utilizadas. Grandes empresas geralmente não querem correr riscos significativos ao investir em novas tecnologias e, simultaneamente, desejam preservar seus investimentos em equipamentos legados. Habilitar IP em um PBX legado pode ser muito caro; portanto, conectar um Asterisk PBX usando linhas T1/E1 pode ser uma boa alternativa para clientes preocupados com custos. Outro benefício é a possibilidade de se conectar a um provedor de serviços VoIP com melhores tarifas de telefonia.

![Habilitando IP em um PBX legado](../images/01-introduction-fig07.png)

### Toll Bypass

Uma aplicação muito útil para VoIP é conectar filiais através da Internet ou de uma WAN. Usar uma conexão de dados existente permite que você ignore as tarifas de chamadas cobradas em conexões de telecomunicações entre a sede e as filiais.

![Toll bypass entre escritórios através de uma WAN](../images/01-introduction-fig08.png)

### Servidor de Aplicação (IVR, Conferência, Voicemail)

O Asterisk pode ser usado como um servidor de aplicação para o PBX existente ou ser conectado diretamente à PSTN. O Asterisk oferece serviços como voicemail, recepção de fax, gravação de chamadas, IVR conectado a um banco de dados e um servidor de conferência de áudio. Se você integrar o voicemail e o fax a um servidor de e-mail existente, terá um sistema de mensagens unificadas, que geralmente é uma solução cara. Usar o Asterisk como um servidor de aplicação proporciona uma redução extrema de custos em comparação com outras soluções.

![Asterisk como um servidor de aplicação](../images/01-introduction-fig09.png)

### Media Gateway

A maioria dos provedores de serviços de voz sobre IP usa um SIP proxy para hospedar todo o registro, localização e autenticação de usuários SIP. Eles ainda precisam enviar chamadas para a PSTN diretamente ou roteá-las através de um provedor de terminação de chamadas no atacado usando uma conexão de voz sobre IP SIP ou H.323. O Asterisk pode atuar como um back-to-back user agent (B2BUA) ou media gateway, substituindo SoftSwitch ou media gateways muito caros. Compare o preço de um gateway de quatro E1/T1 dos principais fabricantes do mercado com o Asterisk. A solução Asterisk pode custar várias vezes menos do que outras soluções e é capaz de traduzir protocolos de sinalização (H.323, SIP, IAX…) e codecs (G.711, G.729…).

![Asterisk como um media gateway](../images/01-introduction-fig10.png)

### Plataforma de Contact Center

Um contact center é uma solução muito complexa que combina diversas tecnologias, como distribuição automática de chamadas (ACD), resposta interativa de voz (IVR) e supervisão de chamadas. Basicamente, três tipos de contact centers estão disponíveis: receptivo (inbound), ativo (outbound) e misto (blended).

Os contact centers receptivos são muito sofisticados e geralmente exigem ACD, IVR, CTI, gravação, supervisão e relatórios. O Asterisk possui um ACD integrado para colocar as chamadas em fila. O IVR pode ser feito usando Asterisk Gateway Interface (AGI) ou mecanismos internos, como a aplicação background(). A integração de telefonia por computador (CTI) é alcançada usando Asterisk Manager Interface (AMI); a gravação e os relatórios já vêm integrados ao Asterisk.

Para um contact center ativo, um discador preditivo ou automático é um dos principais componentes. Embora vários discadores estejam disponíveis para o Asterisk de código aberto, não é difícil construir o seu próprio para a plataforma, se assim desejar. Um contact center misto permite a operação simultânea de entrada e saída, economizando dinheiro ao garantir um melhor uso do tempo do agente. É possível usar o Asterisk e seu mecanismo de ACD para implementar uma solução mista.

![Uma plataforma de contact center Asterisk](../images/01-introduction-fig11.png)

## Encontrando informações e ajuda

Esta seção fornecerá algumas das principais fontes de informação relacionadas ao Asterisk.

- Site oficial do Asterisk: <https://www.asterisk.org> Aqui você pode encontrar informações sobre:
- Documentação & Wiki -> <https://docs.asterisk.org>
- Fórum da comunidade -> <https://community.asterisk.org>
- Rastreamento de bugs -> <https://github.com/asterisk/asterisk/issues>
- Wiki (legado, amplamente substituído pelo docs.asterisk.org) -> <https://wiki.asterisk.org>

### Fórum da comunidade

O fórum da comunidade Asterisk substituiu em grande parte as antigas listas de discussão e é o local para fazer perguntas. Tente reunir o máximo de informações possível antes de postar. Ninguém o ajudará se você não tiver feito sua lição de casa — tente pelo menos uma vez resolver o problema por conta própria.

- <https://community.asterisk.org>

## Resumo

Asterisk é um software licenciado sob a GPL que permite que um PC comum atue como uma poderosa plataforma de IP PBX. Mark Spencer, da Digium, criou o Asterisk no final da década de 1990, e a Digium sustentou-se vendendo hardware e produtos comerciais relacionados ao Asterisk. A Digium foi adquirida pela Sangoma Technologies em 2018; a Sangoma agora patrocina o desenvolvimento do Asterisk. O design da interface de hardware originou-se no projeto Zapata, desenvolvido por Jim Dixon, que deu origem ao DAHDI.

A arquitetura do Asterisk possui os seguintes componentes principais:

- CHANNELS: Analógicos, digitais ou voz sobre IP. No Asterisk 22 LTS, o SIP é tratado exclusivamente pelo `chan_pjsip`.
- PROTOCOLS: Protocolos de comunicação, que são responsáveis pela sinalização das chamadas, incluindo SIP (via PJSIP), H.323, MGCP e IAX2.
- CODECS: Traduzem formatos digitais de voz, permitindo compressão e ocultação de perda de pacotes. Observe que o Asterisk, por si só, não realiza supressão de silêncio (detecção de atividade de voz) ou geração de ruído de conforto; quando os endpoints utilizam VAD, o ruído de conforto deve ser desativado no lado do cliente.
- APPLICATIONS: Responsáveis pela funcionalidade de PBX do Asterisk. Conferência, voicemail e fax são exemplos de aplicações do Asterisk.

O Asterisk pode ser utilizado em vários cenários, desde um pequeno IP PBX até um sofisticado contact center. Você pode encontrar ajuda facilmente em www.asterisk.org e docs.asterisk.org.

## Quiz

1. Qual empresa adquiriu a Digium em 2018 e agora atua como a principal mantenedora do projeto de código aberto Asterisk?
   - A. Cisco Systems
   - B. Sangoma Technologies
   - C. Nortel Networks
   - D. Red Hat

2. No Asterisk 22 LTS, qual driver de canal fornece conectividade SIP?
   - A. `chan_sip`
   - B. `chan_skinny`
   - C. `chan_pjsip`
   - D. `chan_h323`

3. Verdadeiro ou Falso: O driver de canal `chan_sip` foi removido no Asterisk 21 e não está presente em uma compilação padrão do Asterisk 22.

4. Quais dos seguintes canais/protocolos **não fazem mais** parte de uma compilação padrão do Asterisk 22? (Escolha todas as opções aplicáveis.)
   - A. MGCP (`chan_mgcp`)
   - B. SCCP / Cisco Skinny (`chan_skinny`)
   - C. IAX2 (`chan_iax2`)
   - D. H.323 (`chan_h323`, sobrevivendo apenas como o complemento comunitário `ooh323`)

5. A arquitetura de hardware do projeto Zapata, originalmente chamada de Zaptel, foi posteriormente renomeada para ____.
   - A. DAHDI
   - B. PJSIP
   - C. PRI
   - D. mISDN

6. Quando o Asterisk precisa converter áudio de um codec para outro, através de qual formato de fluxo interno ele realiza a tradução?
   - A. G.711 ulaw
   - B. GSM
   - C. slinear (signed linear)
   - D. Opus

7. De acordo com o capítulo, qual é a situação de licenciamento do módulo de codec G.729 distribuído pela Sangoma?
   - A. É GPL e totalmente gratuito para qualquer uso.
   - B. O download é gratuito, mas o uso legal requer a compra de uma licença por canal.
   - C. Não pode ser obtido de forma alguma sem comprar o Asterisk Business Edition.
   - D. Funciona apenas em modo pass-through e não pode ser instalado.

8. Qual aplicação do Asterisk é usada para realizar a ponte de uma chamada de um telefone para outro?
   - A. `Background()`
   - B. `Dial()`
   - C. `Queue()`
   - D. `Goto()`

9. O que é o canal `Local` no Asterisk?
   - A. Uma interface FXS de hardware para telefones analógicos.
   - B. Um trunk SIP para um provedor de serviços local.
   - C. Um pseudo-canal que redireciona uma chamada de volta para o dialplan em um context diferente.
   - D. Um codec usado para chamadas on-net.

10. Em qual cenário de uso o Asterisk atua como um back-to-back user agent (B2BUA), traduzindo entre protocolos de sinalização e codecs para substituir SoftSwitch caros?
    - A. Habilitar IP em um PBX legado
    - B. Toll bypass
    - C. Media Gateway
    - D. Plataforma de Contact Center

**Respostas:** 1 — B · 2 — C · 3 — Verdadeiro · 4 — A, B, D · 5 — A · 6 — C · 7 — B · 8 — B · 9 — C · 10 — C
