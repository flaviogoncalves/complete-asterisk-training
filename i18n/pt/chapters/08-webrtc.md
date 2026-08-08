# WebRTC com Asterisk

O WebRTC (Web Real-Time Communication) permite que um navegador web faça e receba chamadas sem a necessidade de plugins ou softphone externo — apenas JavaScript, um microfone e uma conexão segura com o Asterisk. O Asterisk tem sido capaz de atuar como um servidor WebRTC desde o Asterisk 11, e desde que a stack PJSIP (`res_pjsip`) chegou no Asterisk 12, ela tem sido a maneira recomendada de fazê-lo; no Asterisk 22, a configuração se consolidou em um punhado de opções bem compreendidas. Este capítulo mostra como transformar um endpoint PJSIP em um telefone de navegador, como o caminho de mídia segura funciona e quando você deve optar pelo suporte nativo a WebRTC do Asterisk em vez de um gateway dedicado.

Tudo neste capítulo foi verificado com o laboratório do livro utilizando Asterisk 22; a configuração mostrada é a mesma em `lab/asterisk/etc`.

## Objetivos

Ao final deste capítulo, você deverá ser capaz de:

- Explicar o que o WebRTC adiciona ao Asterisk e quando utilizá-lo
- Descrever como a segurança de mídia do WebRTC (DTLS-SRTP) e o ICE diferem do SIP convencional
- Habilitar o servidor HTTP do Asterisk e o endpoint WebSocket seguro (`wss`)
- Configurar um transporte PJSIP `wss` e um endpoint WebRTC com `webrtc=yes`
- Conectar um softphone de navegador (SIP.js) e realizar uma chamada
- Decidir entre o WebRTC nativo do Asterisk e um gateway de mídia como o Janus

## Por que WebRTC com Asterisk

Um endpoint WebRTC é, do ponto de vista do Asterisk, apenas mais um endpoint PJSIP. O que muda é *como* o navegador chega até ele e como a mídia é protegida. Usos típicos incluem:

- **Click-to-call** em um site — um visitante liga para uma fila ou uma extension a partir de uma página web.
- **Agentes baseados na web** — um agente de contact-center trabalha inteiramente no navegador, sem softphone de desktop para instalar ou atualizar.
- **Chamadas incorporadas** em sua própria aplicação web — por exemplo, o softphone web SipPulse falando com o Asterisk.
- **Telefones internos com instalação zero** — a equipe usa uma aba do navegador em vez de um telefone físico ou cliente instalado.

A grande vantagem é o alcance: todo navegador moderno já fala WebRTC. O custo é que o WebRTC é rigoroso — ele *exige* mídia criptografada e um transporte seguro, portanto, há mais coisas para configurar do que em um telefone SIP UDP comum.

## Como o WebRTC difere do SIP convencional

Um telefone SIP comum sinaliza via UDP/TCP e geralmente transporta áudio como RTP simples. Um cliente de navegador WebRTC é diferente de três maneiras importantes, e o Asterisk precisa corresponder a cada uma delas:

- **A sinalização trafega em um WebSocket.** Em vez de SIP sobre a porta UDP 5060, o navegador abre um WebSocket seguro (`wss://`) para o servidor HTTP integrado do Asterisk. As mensagens SIP viajam dentro desse WebSocket.
- **A mídia é sempre criptografada com DTLS-SRTP.** Os navegadores recusam RTP simples. Os dois lados realizam um handshake DTLS (autenticado por impressões digitais de certificado trocadas no SDP) e derivam chaves SRTP a partir dele.
- **A conectividade é negociada com ICE.** Em vez de assumir um IP e porta acessíveis, ambos os lados coletam endereços candidatos (host, STUN-reflexive, TURN-relayed) e os testam até que um funcione. RTP e RTCP são geralmente multiplexados em uma única porta (`rtcp_mux`).

A boa notícia: no Asterisk 22, uma única opção de endpoint, `webrtc=yes`, ativa tudo isso com configurações padrão sensatas. Veremos exatamente o que ela define.

## Passo 1 — o servidor HTTP e o WebSocket

A sinalização WebRTC é servida pelo servidor HTTP integrado do Asterisk (`res_http_websocket`
expõe o caminho `/ws` nele). Navegadores exigem um WebSocket *seguro*, portanto, habilitamos
TLS. Edite o `http.conf`:

```
[general]
enabled=yes
bindaddr=0.0.0.0
bindport=8088

; TLS / WSS for WebRTC. Browsers require a secure WebSocket (wss://).
tlsenable=yes
tlsbindaddr=0.0.0.0:8089
tlscertfile=/etc/asterisk/keys/asterisk.crt
tlsprivatekey=/etc/asterisk/keys/asterisk.key
```

Recarregue (`module reload res_http_websocket` ou reinicie) e confirme:

```
*CLI> http show status
HTTP Server Status:
Server: Asterisk/22.10.0
Server Enabled and Bound to 0.0.0.0:8088

HTTPS Server Enabled and Bound to 0.0.0.0:8089

Enabled URI's:
/ws => Asterisk HTTP WebSocket
```

O navegador se conectará ao `wss://your-asterisk:8089/ws`.

### Sobre o certificado

O certificado TLS aqui protege o *WebSocket* (o canal de sinalização). Em um laboratório,
um certificado autoassinado é suficiente — você o aceita uma vez no navegador. Em
produção, use um certificado real (por exemplo, Let's Encrypt) cujo nome corresponda
ao host ao qual o navegador se conecta; caso contrário, o navegador recusará o WebSocket.

Para o laboratório, o `lab/make-certs.sh` gera um certificado autoassinado com
`CN=localhost` (mais SANs `localhost`/`127.0.0.1`) e o grava em
`asterisk/etc/keys/`. Para uma implantação pública, obtenha um certificado real — por
exemplo, com Let's Encrypt:

```
certbot certonly --standalone -d voip.example.com
```

Em seguida, aponte o `http.conf` para os arquivos emitidos e recarregue o `res_http_websocket`:

```
tlscertfile=/etc/letsencrypt/live/voip.example.com/fullchain.pem
tlsprivatekey=/etc/letsencrypt/live/voip.example.com/privkey.pem
```

Certifique-se de que o nome do certificado corresponda ao host ao qual o navegador se conecta e renove-o
(o timer do certbot faz isso automaticamente) antes que ele expire, ou o WebSocket falhará.

Este certificado **não** é o mesmo que o certificado DTLS usado para criptografar a
mídia — o Asterisk gera esse automaticamente, como veremos.

## Passo 2 — o transporte WSS

O PJSIP precisa de um transporte do tipo `wss`. Adicione-o ao `pjsip.conf`:

```
[transport-wss]
type=transport
protocol=wss
bind=0.0.0.0
```

Verifique se ele foi carregado:

```
*CLI> pjsip show transports
Transport:  transport-udp             udp      0      0  0.0.0.0:5060
Transport:  transport-wss             wss      0      0  0.0.0.0:5060
```

Não se deixe enganar pelo `0.0.0.0:5060` exibido para o transporte `wss` — o WebSocket
**não** é servido na porta 5060. A sinalização WebRTC é servida pelo servidor HTTP que
você configurou no Passo 1 (porta 8089 para `wss`). O transporte PJSIP `wss` é uma camada fina
sobre o `res_http_websocket`, portanto o endereço `bind` impresso para ele é cosmético e pode ser
ignorado; a porta que importa é a `tlsbindaddr` no `http.conf`.

## Passo 3 — o endpoint WebRTC

Agora o endpoint em si. A chave é `webrtc=yes`:

```
[webrtc-1000]
type=endpoint
context=internal
disallow=all
allow=opus,ulaw
webrtc=yes
transport=transport-wss
aors=webrtc-1000
auth=webrtc-1000

[webrtc-1000]
type=auth
auth_type=digest
username=webrtc-1000
password=Lab-webrtc-secret

[webrtc-1000]
type=aor
max_contacts=1
```

`webrtc=yes` é uma opção de conveniência. Ela é equivalente a definir manualmente todas as opções exigidas pelo WebRTC. Você pode confirmar exatamente o que ela ativou:

```
*CLI> pjsip show endpoint webrtc-1000
 dtls_auto_generate_cert            : Yes
 dtls_fingerprint                   : SHA-256
 dtls_setup                         : actpass
 ice_support                        : true
 media_encryption                   : dtls
 rtcp_mux                           : true
 use_avpf                           : true
 webrtc                             : yes
```

Lendo essa saída:

- `media_encryption: dtls` e `dtls_auto_generate_cert: Yes` — a mídia é DTLS-SRTP, e o Asterisk gera automaticamente o certificado DTLS, portanto você **não** precisa criar um. A impressão digital (fingerprint) é anunciada no SDP (`SHA-256`).
- `ice_support: true` — o Asterisk coleta e negocia candidatos ICE.
- `rtcp_mux: true` — RTP e RTCP compartilham uma única porta, conforme esperado pelos navegadores.
- `use_avpf: true` — o perfil RTP AVPF (feedback), exigido pelo WebRTC.

`allow=opus` é recomendado — Opus é o codec que os navegadores preferem. O Asterisk 22 vem com *passthrough* de Opus no núcleo (o módulo `res_format_attr_opus`), o que é suficiente para retransmitir Opus entre duas pontas compatíveis com Opus sem re-codificação. *Transcodificar* Opus para outro codec requer o módulo separado `codec_opus`, que o guia oficial de WebRTC lista como opcional, mas altamente recomendado, e que você instala sobre a compilação base; veja a discussão sobre codecs em *Designing a VoIP network*. Mantenha `ulaw` como um fallback para fazer a ponte com pontas não-WebRTC que não suportam Opus.

## Passo 4 — ICE, STUN e TURN

Em uma LAN plana, o ICE com candidatos de host é suficiente e nada mais é necessário. Através da internet, você geralmente adiciona um servidor STUN para que o Asterisk e o navegador possam descobrir seus endereços públicos, e um servidor TURN para os casos em que a mídia direta é impossível (NAT simétrico, firewalls restritivos). Aponte o Asterisk para eles em `rtp.conf`:

```
[general]
icesupport=yes
stunaddr=stun.l.google.com:19302
; turnaddr=turn.example.com:3478
; turnusername=...
; turnpassword=...
```

O navegador é configurado com seus próprios servidores ICE em JavaScript (a lista `RTCPeerConnection` `iceServers`). Para uma implementação puramente interna, você pode ignorar o STUN/TURN completamente.

`turnaddr` aceita uma porta opcional (padrão `3478`); `turnusername` e `turnpassword` autenticam no relay. O STUN apenas ajuda um peer a *descobrir* seu endereço público — quando ambas as pontas estão atrás de NAT simétrico ou de um firewall restritivo, a mídia direta é impossível e um relay TURN é a única coisa que faz o áudio fluir.

**Recomendação de produção:** um servidor STUN público (como o do Google) é bom para a descoberta de endereços, mas **não** confie em TURN público para tráfego real — o TURN faz o relay de toda a sua mídia, então você deve mantê-lo sob seu controle. Execute seu próprio servidor [coturn](https://github.com/coturn/coturn). Um `/etc/turnserver.conf` mínimo com credenciais de longo prazo parece com isto:

```
listening-port=3478
fingerprint
lt-cred-mech
user=asterisk:Strong-TURN-secret
realm=voip.example.com
external-ip=203.0.113.10
```

Em seguida, aponte o Asterisk para ele em `rtp.conf`:

```
[general]
icesupport=yes
stunaddr=stun.l.google.com:19302
turnaddr=turn.example.com:3478
turnusername=asterisk
turnpassword=Strong-TURN-secret
```

Forneça ao navegador o mesmo servidor TURN em sua lista `iceServers` para que ambas as pernas possam fazer o relay. Para produção com usuários em redes móveis ou atrás de firewalls corporativos, um coturn auto-hospedado é efetivamente obrigatório.

## Passo 5 — o cliente de navegador

Qualquer biblioteca SIP WebRTC funciona; duas amplamente utilizadas são **SIP.js** e **JsSIP**. O laboratório inclui um softphone SIP.js minimalista em `lab/webrtc/index.html`. A parte essencial é a URL de transporte e as credenciais:

```javascript
const ua = new SIP.UserAgent({
  uri: SIP.UserAgent.makeURI('sip:webrtc-1000@your-asterisk'),
  transportOptions: { server: 'wss://your-asterisk:8089/ws' },
  authorizationUsername: 'webrtc-1000',
  authorizationPassword: 'Lab-webrtc-secret',
});
await ua.start();
await new SIP.Registerer(ua).register();
// place a call to the echo test
const inviter = new SIP.Inviter(ua, SIP.UserAgent.makeURI('sip:600@your-asterisk'));
await inviter.invite();
```

Duas realidades do navegador para lembrar:

- **Contexto seguro.** `getUserMedia` (acesso ao microfone) só funciona em páginas `https://` ou `http://localhost`. Sirva a página via HTTPS em produção.
- **Aceite o certificado uma vez.** Com um certificado de laboratório autoassinado, visite `https://your-asterisk:8089/ws` no mesmo navegador primeiro e aceite o aviso, ou o WebSocket falhará silenciosamente.

O softphone web SipPulse é um cliente de referência de nível de produção construído sobre essas mesmas primitivas.

## Verificando uma chamada WebRTC

Com o navegador registrado, `pjsip show contacts` mostra o contato dinâmico, e uma chamada acende o canal:

```
*CLI> pjsip show contacts
  Contact:  webrtc-1000/sip:webrtc-1000@... NonQual Avail
*CLI> core show channels
PJSIP/webrtc-1000-00000001  internal  600  Up  Echo
```

Se o áudio for unidirecional ou inexistente, quase sempre é um problema de ICE ou de certificado — veja a solução de problemas abaixo.

## Asterisk WebRTC vs um media gateway

O Asterisk pode terminar WebRTC diretamente, mas nem sempre é a ferramenta certa:

- **Use o WebRTC nativo do Asterisk** quando o navegador for um *phone* no seu PBX — um agente, uma extension interna, um click-to-call que cai no seu dialplan. O navegador é apenas mais um endpoint e tudo (queues, voicemail, IVR) funciona.
- **Use um gateway dedicado (por exemplo, Janus)** quando precisar escalar muitas sessões de navegador independentemente do controle de chamadas, realizar encaminhamento seletivo para grandes conferências/streaming ou manter o plano de mídia separado do PBX. Um gateway faz a ponte entre WebRTC e SIP comum, e o Asterisk então enxerga uma perna SIP comum.

Muitos sistemas reais combinam ambos: Asterisk para controle de chamadas, um gateway para escalonamento de mídia do lado do navegador. (Esta é a arquitetura por trás da própria stack da SipPulse.)

## Solução de problemas

- **O WebSocket não conecta:** o navegador rejeitou o certificado TLS. Abra
  `https://host:8089/ws` diretamente e aceite-o, ou instale um certificado confiável.
- **Registra, mas sem áudio:** falha no ICE — adicione STUN, e TURN se estiver atrás de NAT. Verifique
  `pjsip set logger on` e observe os candidatos SDP.
- **Áudio unidirecional:** geralmente NAT/ICE em um dos lados, ou um codec sem correspondência comum —
  certifique-se de que `allow=opus,ulaw`.
- **Chamada cai ao atender:** falha no handshake DTLS; confirme se `dtls_auto_generate_cert`
  está como `Yes` e se o relógio do sistema está correto (certificados são sensíveis ao tempo).

## Laboratório

1. Execute `./lab.sh up`, depois `bash lab/make-certs.sh` e reinicie o Asterisk.
2. Sirva o `lab/webrtc/index.html` (`python3 -m http.server` a partir de `lab/webrtc`) e abra-o; aceite o certificado em `https://localhost:8089/ws`.
3. Registre-se como `webrtc-1000` e ligue para `600` (teste de eco) — você deve ouvir a si mesmo.
4. A partir do SipPulse Softphone registrado como `6001`, disque `1000` para chamar o navegador.
5. Inspecione a negociação: `pjsip set logger on`, faça uma chamada e encontre a impressão digital DTLS e os candidatos ICE no SDP.

## Resumo

O WebRTC transforma um navegador em um endpoint Asterisk de primeira classe. A receita é pequena, mas rigorosa: habilite o servidor HTTP com TLS para que o navegador possa abrir um WebSocket seguro, adicione um transporte PJSIP `wss` e defina `webrtc=yes` no endpoint — o que ativa DTLS-SRTP (com um certificado gerado automaticamente), ICE, multiplexação RTP/RTCP e o perfil AVPF. Adicione STUN/TURN ao atravessar NAT, sirva sua página via HTTPS e aponte um cliente SIP.js (ou JsSIP) para `wss://asterisk:8089/ws`. Para telefones baseados em navegador no seu PBX, o WebRTC nativo do Asterisk é o caminho mais simples; para mídia em larga escala, combine-o com um gateway.

## Quiz

1. Qual transporte um cliente de navegador WebRTC utiliza para levar a sinalização SIP ao Asterisk?
   - A. UDP simples na porta 5060
   - B. Um WebSocket seguro (`wss://`) para o servidor HTTP do Asterisk
   - C. TLS na porta 5061
   - D. Um socket TCP bruto na porta 8088

2. A mídia WebRTC entre o navegador e o Asterisk é criptografada usando qual mecanismo?
   - A. SDES-SRTP (chaves trocadas no SDP)
   - B. DTLS-SRTP (chaves derivadas de um handshake DTLS)
   - C. IPsec
   - D. RTP simples — o WebRTC não criptografa a mídia

3. Verdadeiro ou falso: ao definir `webrtc=yes`, você deve gerar e instalar manualmente o certificado DTLS usado para criptografar a mídia.

4. Em qual porta o servidor HTTP do Asterisk do laboratório expõe o WebSocket **seguro** para WebRTC?
   - A. 5060
   - B. 5061
   - C. 8088
   - D. 8089

5. Qual das opções a seguir o `webrtc=yes` ativa por padrão? (Escolha todas as que se aplicam.)
   - A. `media_encryption: dtls`
   - B. `ice_support: true`
   - C. `rtcp_mux: true`
   - D. `use_avpf: true`
   - E. `transport: transport-udp`

6. Preencha a lacuna: o WebRTC negocia a conectividade fazendo com que ambos os lados coletem e testem endereços candidatos (host, STUN-reflexive, TURN-relayed) usando o framework ________.

7. Em `rtp.conf`, quais duas configurações apontam o Asterisk para um servidor externo para que ele possa descobrir seu endereço público e retransmitir mídia quando os caminhos diretos falharem? (Escolha todas as que se aplicam.)
   - A. `icesupport=yes`
   - B. `stunaddr=`
   - C. `turnaddr=`
   - D. `tlsbindaddr=`

8. O caminho da URL que o `res_http_websocket` do Asterisk expõe para a sinalização WebRTC é ________.

9. De acordo com o capítulo, quando você deve recorrer a um gateway de mídia dedicado (como o Janus) em vez do WebRTC nativo do Asterisk?
   - A. Sempre que qualquer navegador precisar fazer uma chamada
   - B. Quando você precisar escalar muitas sessões de mídia de navegador independentemente do controle de chamadas, fazer encaminhamento seletivo para grandes conferências ou manter o plano de mídia separado do PBX
   - C. Apenas quando o navegador não suportar DTLS
   - D. Quando você quiser que o voicemail e a IVR funcionem para o endpoint do navegador

10. Verdadeiro ou falso: o `getUserMedia` (acesso ao microfone) funciona em qualquer página `http://`, portanto, servir o softphone via navegador por HTTPS é opcional.

**Respostas:** 1 — B · 2 — B · 3 — Falso (o Asterisk gera automaticamente o certificado DTLS; `dtls_auto_generate_cert: Yes`) · 4 — D · 5 — A, B, C, D · 6 — ICE · 7 — B, C · 8 — `/ws` · 9 — B · 10 — Falso (contexto seguro necessário: `getUserMedia` só funciona em `https://` ou `http://localhost`)
