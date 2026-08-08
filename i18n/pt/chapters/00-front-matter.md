```{=latex}
\frontmatter
```

## Copyright {.unnumbered}

*Asterisk Guide* — Segunda Edição (Asterisk 22 LTS)

Copyright © 2006–2026 Flavio E. Gonçalves. Todos os direitos reservados.

Nenhuma parte deste livro pode ser reproduzida, armazenada em um sistema de recuperação ou transmitida de qualquer forma ou por qualquer meio sem o consentimento prévio por escrito do autor, exceto para breves trechos utilizados em resenhas publicadas.

**Edição:** Segunda Edição.

> **[author TODO]** Atribua um novo ISBN para a 2ª edição (não reutilize o ISBN da 1ª edição 9781796396973) e defina a data de publicação antes da impressão.

Muitas das designações usadas por fabricantes e vendedores para distinguir seus produtos são reivindicadas como marcas registradas. Onde essas designações aparecem neste livro e o autor estava ciente de uma reivindicação de marca registrada, elas foram impressas em letras maiúsculas ou com iniciais maiúsculas. Asterisk, Digium, IAX e DUNDi são marcas registradas da Sangoma Technologies (a Digium foi adquirida pela Sangoma em 2018; o Asterisk é agora patrocinado pela Sangoma).

Embora todas as precauções tenham sido tomadas na preparação deste livro, o autor não assume nenhuma responsabilidade por erros ou omissões, ou por danos resultantes do uso das informações aqui contidas.

## Prefácio {.unnumbered}

Este livro é para qualquer pessoa que queira aprender a instalar e configurar um PBX (Private Branch Exchange) baseado no Asterisk 22 LTS. O Asterisk é uma plataforma de telefonia open source que faz a ponte entre VoIP e canais TDM tradicionais.

Esta é a quinta geração de um livro que começou como o *Asterisk Configuration Guide*. O material surgiu do trabalho que realizei para me preparar para a certificação Digium dCAP em 2006 — a qual passei na primeira tentativa — e tem sido ensinado a mais de mil alunos desde então.

O conceito de PBX open source é revolucionário. Por décadas, a telefonia foi dominada por um punhado de empresas que vendiam sistemas proprietários caros. O Asterisk devolveu esse poder às mãos dos usuários: recursos que antes eram economicamente inalcançáveis — CTI (computer-telephony integration), IVR (interactive voice response), ACD (automatic call distribution), voicemail e muito mais — estão agora disponíveis para qualquer pessoa com uma máquina Linux e disposição para aprender.

Este livro não fará de você um guru por si só — nenhum livro pode — mas, ao final dele, você será capaz de construir e operar um PBX real com recursos avançados. O livro possui um complemento — laboratórios práticos e um curso online — na **VoIP School Blackbelt** (<https://voip.school>).

## Público-alvo {.unnumbered}

Este livro é destinado a leitores que são novos no Asterisk. Presumo que você esteja familiarizado com Linux — o shell, um editor de texto e a administração básica de sistemas. Você pode acompanhar em um desktop Linux se for mais fácil durante o aprendizado, e uma máquina virtual é adequada para os laboratórios (espere uma qualidade de voz ligeiramente inferior). Para sistemas em produção, não recomendo executar o Asterisk em um ambiente de desktop ou dentro de uma VM com poucos recursos. Alguma familiaridade com redes IP, Voice over IP (VoIP) e conceitos básicos de telefonia ajudará.

## O que há de novo na segunda edição {.unnumbered}

A segunda edição é uma modernização completa para o **Asterisk 22 LTS** (lançado em 2024, com suporte até outubro de 2028). As principais mudanças são:

- **PJSIP é o único canal SIP.** `chan_sip` foi removido no Asterisk 21 e não existe na versão 22. Todos os exemplos de SIP agora utilizam PJSIP (`pjsip.conf`); o material legado do `sip.conf` é mantido apenas como referência de migração.
- **Gestão da Sangoma.** A Digium foi adquirida pela Sangoma em 2018; o projeto agora é desenvolvido e patrocinado pela Sangoma, e o texto reflete isso em todo o conteúdo.
- **Três novos capítulos.** *WebRTC with Asterisk* (telefones baseados em navegador via WSS/DTLS-SRTP), *SIP trunking, DID & the PSTN* e *Deployment, monitoring & scaling*.
- **Um laboratório reproduzível.** Cada configuração e comando no livro é verificado em um laboratório Docker do Asterisk 22 que você mesmo pode executar.
- **Recursos modernizados.** O ConfBridge substitui a antiga conferência MeetMe, o ARI é introduzido juntamente com AMI/AGI, o PJSIP Realtime (Sorcery) é abordado, e os capítulos de instalação, segurança e CDR foram atualizados.
- **Uma nova estrutura.** O livro agora está organizado em quatro partes — Fundamentos, Canais e Conectividade, Dialplan e Recursos de Chamada, e Integração e Operações.

## Sobre o autor {.unnumbered}

Flavio E. Gonçalves nasceu em 1966 no Brasil. Ele tem um forte interesse em
computadores desde que adquiriu seu primeiro PC em 1983, e obteve um diploma de engenharia em 1989
com foco em design e manufatura auxiliados por computador. Ele é o CEO da SipPulse no
Brasil, uma empresa dedicada a SoftSwitch, SBC e
PBXs multitenant.

Ao longo de sua carreira, ele obteve uma longa lista de certificações — Novell MCNE/MCNI, Microsoft
MCSE/MCT, Cisco CCSP/CCNP/CCDP e Asterisk dCAP, entre elas. Ele começou a escrever sobre
software de código aberto porque acredita que a maneira estruturada como as certificações ensinavam
seu material antigamente é uma ótima forma de aprender, e ele utilizou mais de 25 anos de
experiência em ensino para escrever focando em como as pessoas realmente aprendem, em vez de apenas
partir de um ponto de vista técnico.

Flavio é pai de dois filhos e mora em Florianópolis, Brasil — um dos lugares mais
bonitos do mundo — onde passa seu tempo livre surfando e velejando.

## Feedback, créditos e treinamento {.unnumbered}

Eu me esforço muito para encontrar e eliminar erros, mas alguns sempre passam despercebidos. Se você encontrar algo errado, por favor, me avise e eu tomarei as providências.

Este livro também é utilizado como material de treinamento. Se você gostaria de usá-lo em seu próprio centro de treinamento, ou fazer o curso online e os laboratórios complementares, visite a **VoIP School Blackbelt** em <https://voip.school> ou envie um e-mail para <flavio@voip.school>.

**Créditos.** Arte da capa: Karla Braga. Revisores: Luis F. Gonçalves, Guilherme Goes (dCAP) e revisores profissionais. Meus agradecimentos também aos muitos alunos cujo feedback ao longo dos anos moldou este material, e à minha família pelo apoio.

```{=latex}
\cleardoublepage
```
