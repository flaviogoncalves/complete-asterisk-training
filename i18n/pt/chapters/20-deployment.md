# Implantação, monitoramento e escalabilidade

Fazer o Asterisk atender a uma chamada em um laboratório é uma coisa; executá-lo como um serviço que sobrevive a falhas, reinicializações, atualizações e atacantes — e que você pode observar, fazer backup e expandir — é outra. Este capítulo trata de tudo o que acontece *após* o dialplan funcionar. Começamos com o supervisor que mantém o Asterisk ativo (systemd), passamos para o empacotamento em um container (usando o laboratório Docker do próprio livro como exemplo prático), depois cobrimos gerenciamento de configuração e backups, monitoramento e observabilidade e, finalmente, os padrões que você utiliza quando um servidor não é suficiente: alta disponibilidade e escalabilidade, e as realidades da hospedagem na nuvem.

Tudo o que é mostrado foi verificado no laboratório Asterisk 22 do livro em `lab/` — o mesmo container no qual você tem trabalhado ao longo do livro.

## Objetivos

Ao final deste capítulo, você deverá ser capaz de:

- Executar o Asterisk 22 de forma confiável sob o systemd, como um usuário não root, com reinicialização automática
- Containerizar o Asterisk com Docker e entender as compensações de rede
- Manter o `/etc/asterisk` em controle de versão e realizar o backup do estado correto
- Monitorar um sistema em execução através da CLI, CDR/CEL, AMI/ARI e métricas
- Aplicar padrões de alta disponibilidade ativo/passivo e escalabilidade horizontal
- Hospedar o Asterisk na nuvem com segurança atrás de NAT e um firewall

## Executando o Asterisk sob o systemd

Em todas as distribuições Linux atuais — Debian 12, Ubuntu 22.04/24.04, Rocky/AlmaLinux 9 — o gerenciador de serviços é o **systemd**. O capítulo de instalação mostrou que o passo `make config` (executado durante o `make install`) instala um script de inicialização da distribuição (`/etc/init.d/asterisk` no Debian, um script `rc.d` no RedHat), que o systemd então encapsula automaticamente como um serviço; o Asterisk também fornece uma unidade nativa do systemd em `contrib/systemd/asterisk.service` que você pode instalar em seu lugar para um controle mais refinado.
De qualquer forma, o systemd é a maneira suportada e recomendada para executar o Asterisk em produção. Consulte *Installing Asterisk 22* para a compilação em si; aqui, focamos no que o serviço oferece a você e como operá-lo.

### A unidade de serviço e seu ciclo de vida

Uma vez que o `make config` tenha instalado o serviço, o ciclo de vida é o padrão do systemd:

```
systemctl enable asterisk     # start automatically at boot
systemctl start asterisk      # start now
systemctl status asterisk     # is it running? recent log lines
systemctl restart asterisk    # full stop + start
systemctl stop asterisk       # stop
journalctl -u asterisk        # service logs via the journal
```

Algumas notas operacionais:

- **`restart` vs. um recarregamento gracioso.** O `systemctl restart` encerra o processo e derruba todas as chamadas. Para alterações de configuração, você quase nunca deseja isso — use a CLI do Asterisk em vez disso: `asterisk -rx 'core reload'` (ou um recarregamento específico de módulo, como `pjsip reload`). Reserve o `systemctl restart` para atualizações ou para um processo travado.
- **Conectar-se ao daemon em execução.** Com o Asterisk rodando como um serviço, abra seu console com `asterisk -r` (ou `asterisk -rvvv` para saída detalhada). Isso se conecta ao daemon já em execução através de seu socket de controle; ele não inicia uma segunda cópia.

### O `Restart=` substitui o safe_asterisk

Historicamente, o Asterisk era iniciado através do wrapper **safe_asterisk**, um script shell que reiniciava o Asterisk caso ele travasse. Sob o systemd, essa tarefa pertence à diretiva `Restart=` da unidade — o systemd percebe a saída do processo e o reinicia, com o intervalo controlado por `RestartSec=` e a proteção contra loop de falhas por `StartLimitIntervalSec=`/`StartLimitBurst=`. Portanto, em um host com systemd, o **safe_asterisk é substituído** e geralmente é desnecessário. Se a sua unidade fornecida ainda não o definir, um arquivo de substituição (drop-in) é a maneira limpa de adicionar a reinicialização em caso de falha sem editar o arquivo empacotado:

```
# /etc/systemd/system/asterisk.service.d/override.conf
[Service]
Restart=always
RestartSec=2
```

Aplique-o com `systemctl daemon-reload && systemctl restart asterisk`. Usar um arquivo drop-in (em vez de editar a unidade instalada) significa que um futuro `make config` não sobrescreverá sua alteração.

### Executando como um usuário não root

O Asterisk não deve rodar como root em produção — um bug de execução remota de código em um processo rodando como root é um comprometimento total do host, enquanto o mesmo bug em um processo sem privilégios é contido. Existem dois locais complementares onde isso é aplicado:

- **A unidade / asterisk.conf.** A unidade empacotada normalmente executa o Asterisk como o usuário e grupo `asterisk`. Você também pode (ou alternativamente) definir `runuser` e `rungroup` na seção `[options]` do `asterisk.conf`, que o daemon respeita quando ele descarta privilégios após a vinculação:

  ```
  [options]
  runuser = asterisk
  rungroup = asterisk
  ```

- **Propriedade de arquivos.** Os diretórios de tempo de execução devem ter permissão de escrita para esse usuário. Após criar a conta, garanta a propriedade:

  ```
  chown -R asterisk:asterisk /var/lib/asterisk /var/log/asterisk \
        /var/spool/asterisk /var/run/asterisk /etc/asterisk
  ```

Como o SIP (5060) e o RTP (10000+) são portas altas, o Asterisk **não** precisa de root para vinculá-las — apenas portas privilegiadas do tipo porta 25 precisariam, as quais o Asterisk não utiliza. Portanto, rodar sem privilégios não tem custo. (O capítulo de Segurança expande sobre por que isso é importante; veja *Asterisk Security*.)

## Containerizando o Asterisk

Um container empacota o Asterisk e suas dependências exatas em uma imagem imutável, de modo que o que você testa é, byte por byte, o que você entrega. A compensação é a mídia em tempo real: um servidor SIP é sensível à latência e precisa de uma faixa ampla e previsível de portas UDP acessíveis a partir do exterior, e a rede de containers pode atrapalhar. O restante desta seção percorre o próprio laboratório do livro — `lab/Dockerfile` e `lab/docker-compose.yml` — como um exemplo concreto e funcional, e então explica a armadilha em que todos caem: RTP e rede em bridge.

### A imagem: compilando o Asterisk a partir do código-fonte

O `Dockerfile` do laboratório compila o Asterisk 22 a partir do código-fonte no Debian 12. Vale a pena ler sua estrutura, mesmo que você nunca escreva uma por conta própria:

```dockerfile
FROM debian:12-slim

ARG ASTERISK_VERSION=22.10.0
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential wget ca-certificates pkg-config \
        libedit-dev libxml2-dev libsqlite3-dev uuid-dev libssl-dev \
        libsrtp2-dev libcurl4-openssl-dev libncurses-dev \
    && rm -rf /var/lib/apt/lists/*

# ... download + tar xzf asterisk-${ASTERISK_VERSION}.tar.gz ...

RUN ./configure --with-jansson-bundled --with-pjproject-bundled \
    && make menuselect.makeopts \
    && menuselect/menuselect --enable res_srtp --enable res_http_websocket menuselect.makeopts \
    && make -j"$(nproc)" \
    && make install \
    && make install-logrotate \
    && ldconfig

EXPOSE 5060/udp 10000-10100/udp
CMD ["asterisk", "-f", "-vvv"]
```

Três pontos a destacar:

- **A versão é fixada** (`ARG ASTERISK_VERSION=22.10.0`). A reprodutibilidade é o objetivo principal da containerização — altere-a deliberadamente, recompile, reteste.
- **`--with-pjproject-bundled` e `--with-jansson-bundled`** compilam a stack SIP com a versão correspondente ao Asterisk, para que você dependa de menos pacotes apt e nunca precise lidar com um PJSIP da distribuição que esteja defasado.
- **`CMD ["asterisk", "-f", "-vvv"]`** executa o Asterisk em *foreground* (`-f`, "do not fork"). Esta é a diferença fundamental em relação a um host systemd: o processo principal de um container não deve se tornar um daemon, ou o container encerraria imediatamente. Portanto, em um container, você **não** usa a unidade do systemd — o runtime do container (Docker, mais a política `restart:`) torna-se o supervisor que o `Restart=` da unidade era em uma VM.

### Bind-mount do `/etc/asterisk`

A imagem deliberadamente **não** contém configuração. Em vez disso, o `docker-compose.yml` faz um bind-mount do diretório de configuração do host:

```yaml
services:
  asterisk:
    build: .
    image: astbook/asterisk:22.10.0
    container_name: astlab-asterisk
    restart: unless-stopped
    volumes:
      - ./asterisk/etc:/etc/asterisk:ro
    ports:
      - "5060:5060/udp"
      - "10000-10100:10000-10100/udp"
```

O `./asterisk/etc:/etc/asterisk:ro` mapeia o diretório `lab/asterisk/etc` sob controle de versão para o `/etc/asterisk` do container, como somente leitura (`:ro`). A vantagem é grande: a imagem permanece imutável e reutilizável, enquanto a configuração reside no host, onde pode ser editada e, crucialmente, mantida no git (próxima seção). Para aplicar uma alteração de configuração, você edita o arquivo e recarrega — `docker compose exec asterisk asterisk -rx 'core reload'` — sem necessidade de recompilação. O `restart: unless-stopped` é o equivalente no compose ao `Restart=` do systemd: o Docker reinicia o container se o Asterisk encerrar, mas não se você o tiver parado deliberadamente.

### Rede host vs. bridge — o problema do RTP

Esta é a falha mais comum em Asterisk containerizado, por isso vale a pena entendê-la com precisão. Por padrão, o Docker coloca um container em uma rede **bridge** e você publica portas individuais com o `ports:`. A sinalização funciona bem — 5060 é apenas uma porta. O problema é a mídia: o RTP usa uma *faixa* de portas UDP (o `rtp.conf` do laboratório define `rtpstart=10000` / `rtpend=10100`), e **toda** porta que possa transportar áudio deve ser publicada.

O laboratório faz exatamente isso:

```yaml
    ports:
      - "5060:5060/udp"
      - "10000-10100:10000-10100/udp"
```

Observe que a faixa de publicação RTP (`10000-10100`) corresponde exatamente ao `rtp.conf`. Se você errar isso — publicar poucas portas ou uma faixa diferente do `rtp.conf` — as chamadas conectarão, mas terão **áudio unidirecional ou nenhum áudio**, porque os pacotes RTP chegam a uma porta que o Docker não está encaminhando. Duas precauções adicionais com o modo bridge:

- **Publicar milhares de portas é lento e pesado.** Uma faixa RTP de produção é tipicamente 10000–20000. O Docker criar cerca de 10000 encaminhamentos de proxy em userland é custoso na inicialização e adiciona um salto no caminho da mídia. O laboratório mantém uma faixa deliberadamente pequena de 100 portas porque executa apenas uma ou duas chamadas de teste.
- **NAT no SDP.** Atrás da bridge, o Asterisk vê seu IP de container privado e pode anunciá-lo no SDP. Em um host público, você deve informar ao PJSIP seu endereço externo com `external_media_address` / `external_signaling_address` no transporte (e definir o `local_net`), exatamente como faria atrás de qualquer NAT — veja *Cloud hosting* abaixo.

A alternativa é a **rede host** (`network_mode: host`), que remove a bridge completamente: o container compartilha a stack de rede do host, portanto, a 5060 e toda a faixa RTP ficam acessíveis sem publicação de portas e sem salto de mídia extra. Este é o modo recomendado para um container Asterisk real — ele evita completamente o problema da faixa RTP. O custo é o isolamento: o container pode vincular qualquer porta do host e você perde a rede por serviço do compose. (A rede host é um recurso do Linux; no Docker Desktop para macOS/Windows, ele se comporta de maneira diferente, o que é parte do motivo pelo qual este laboratório de ensino usa portas publicadas explicitamente.)

### Volumes persistentes para spool e voicemail

A camada gravável de um container é **efêmera** — destrua o container e tudo o que ele escreveu desaparecerá. Para o Asterisk, isso significa que voicemail, gravações, o spool de chamadas de saída e o banco de dados local desapareceriam a cada `docker compose up --build`. A configuração sobrevive porque é montada via bind-mount a partir do host; o *estado* precisa do mesmo tratamento. Dentro do container, as árvores relevantes são:

```
/var/spool/asterisk        # voicemail, monitor recordings, outgoing/, etc.
/var/lib/asterisk          # astdb.sqlite3 (the internal database)
/var/log/asterisk          # full, messages, security, cdr-csv/, cel-custom/
```

(O container em execução do laboratório mostra exatamente estas — `/var/spool/asterisk` contém `voicemail`, `monitor`, `outgoing`, `recording`; o `/var/lib/asterisk` mantém o `astdb.sqlite3`.) Para preservá-los, monte volumes nomeados para os diretórios que contêm o estado que lhe interessa:

```yaml
    volumes:
      - ./asterisk/etc:/etc/asterisk:ro     # config (bind, in git)
      - ast-spool:/var/spool/asterisk        # voicemail + recordings (persist)
      - ast-lib:/var/lib/asterisk            # astdb (persist)
      - ast-log:/var/log/asterisk            # logs (persist)

volumes:
  ast-spool:
  ast-lib:
  ast-log:
```

O laboratório de ensino omite isso propositalmente — ele é stateless e reprodutível por design, portanto, cada `up` é um ambiente limpo — mas um container de produção **deve** tê-los, ou você perderá o voicemail no primeiro redeploy.

## Gerenciamento de configuração e backups

O bind-mount acima sugere o modelo correto: trate `/etc/asterisk` como **código** e o restante como **dados**.

### Mantenha `/etc/asterisk` sob controle de versão

O diretório de configuração é um conjunto simples de arquivos de texto sem segredos que não possam ser modelados — é ideal para o git. Inicialize um repositório em `/etc/asterisk` (ou, como o laboratório faz, mantenha a configuração junto ao projeto e faça o bind-mount). Benefícios:

- Cada alteração é revisável e reversível (`git diff`, `git revert`).
- Você possui um registro de auditoria de quem alterou o quê e quando.
- Combinado com uma imagem de container, um commit de configuração validado mais uma tag de imagem fixada descrevem completamente uma implantação.

Algumas precauções específicas para a configuração do Asterisk:

- **Segredos.** `pjsip.conf` (e `manager.conf`, `ari.conf`) contêm senhas. Não envie segredos reais para um repositório compartilhado em texto simples — utilize modelos (um arquivo por ambiente, ou um gerenciador de segredos / substituição de variáveis de ambiente no momento da implantação) e mantenha apenas placeholders no git. As senhas triviais do tipo `Lab-6001-secret` do laboratório são aceitáveis *apenas* porque residem em uma sub-rede privada do Docker.
- **Modelagem por ambiente.** Os valores de realtime que diferem entre desenvolvimento, homologação e produção (endereços de bind, IPs externos, credenciais de trunk, URLs de banco de dados) são exatamente as linhas que você deve modelar, mantendo a maior parte da configuração idêntica entre os ambientes.

### O que fazer backup

A configuração no git cobre o dialplan e os endpoints, mas um PBX em operação acumula *estado* que não está em nenhum arquivo de configuração. Um backup completo consiste em:

| O que | Onde | Por que |
|------|-------|-----|
| Configuração | `/etc/asterisk/` | dialplan, endpoints (também no git) |
| Voicemail e gravações | `/var/spool/asterisk/` | dados do usuário — insubstituíveis |
| Banco de dados interno | `/var/lib/asterisk/astdb.sqlite3` | chaves `DB()`, estado do dispositivo |
| CDR / CEL | `/var/log/asterisk/cdr-csv/` ou armazenamento SQL | faturamento e histórico |
| Bancos de dados externos | seu MySQL/PostgreSQL | realtime, CDR, voicemail |

O **astdb** merece uma nota: é o pequeno armazenamento chave/valor embutido do Asterisk (um arquivo SQLite em `/var/lib/asterisk/astdb.sqlite3`) usado por funções de dialplan `DB()`, estados de dispositivo, configurações de follow-me e similares. Você pode exportá-lo para inspeção ou backup a partir da CLI:

```
asterisk -rx 'database show'
```

Se o seu CDR/CEL ou voicemail ou configuração de PJSIP reside em um banco de dados externo (veja *Asterisk Real-Time* e *Asterisk Call Detail Records*), esse banco de dados agora é a fonte da verdade para esses dados e deve estar na sua rotina normal de backup de banco de dados — fazer backup apenas de `/etc/asterisk` não é suficiente.

## Monitoramento e observabilidade

Você não pode operar o que não consegue ver. O Asterisk expõe seu estado em quatro níveis, desde uma rápida verificação humana até um pipeline de métricas: a **CLI**, os registros **CDR/CEL**, eventos **AMI/ARI** e **exportadores de métricas**.

### Verificações de integridade na CLI

A verificação mais rápida de "está saudável?" é a CLI. Os comandos abaixo são executados ao vivo no laboratório. Primeiro, os canais:

```
*CLI> core show channels
Channel              Location             State   Application(Data)
0 active channels
0 active calls
0 calls processed
```

`0 active calls` em um sistema ocioso é normal; em um sistema ocupado, esta é sua concorrência em tempo real. `core show uptime` confirma que o processo não foi reiniciado:

```
*CLI> core show uptime
System uptime: 1 hour, 40 minutes, 19 seconds
Last reload: 12 minutes, 32 seconds
```

Para a integridade do SIP, `pjsip show endpoints` mostra cada endpoint e se seus contatos registrados estão acessíveis. Do laboratório:

```
*CLI> pjsip show endpoints
 Endpoint:  6001                                                 Unavailable   0 of inf
     InAuth:  6001/6001
        Aor:  6001                                               1
 Endpoint:  6002                                                 Unavailable   0 of inf
     InAuth:  6002/6002
        Aor:  6002                                               1
 Endpoint:  sipp                                                 Unavailable   0 of inf
        Aor:  sipp                                               1
   Identify:  sipp-identify/sipp
        Match: 172.30.0.0/24
 Endpoint:  webrtc-1000                                          Unavailable   0 of inf
     InAuth:  webrtc-1000/webrtc-1000
        Aor:  webrtc-1000                                        1
Objects found: 4
```

`Unavailable` aqui significa simplesmente que nenhum telefone está registrado atualmente nesses endpoints (o laboratório não possui clientes ativos) — assim que um softphone se registra e `qualify` confirma, o estado mostra o contato como acessível. Comandos complementares: `pjsip show contacts` (registros atuais e tempo de ida e volta), `pjsip show transports` e `pjsip show aor <name>` para um AOR. Estas são as ferramentas do dia a dia para responder "por que a extension X não pode ser alcançada?".

### CDR e CEL

Cada chamada deixa um **Call Detail Record** (CDR); o **Channel Event Logging** (CEL) adiciona eventos mais detalhados por canal. Confirme se o CDR está ativo e qual backend o armazena:

```
*CLI> cdr show status

Call Detail Record (CDR) settings
----------------------------------
  Logging:                    Enabled
  Mode:                       Simple
  Log calls by default:       Yes
  Log unanswered calls:       No
...
* Registered Backends
  -------------------
    (none)
```

O laboratório mostra `(none)` em backends registrados porque a configuração mínima do laboratório não carrega nenhum módulo de armazenamento de CDR — portanto, os registros são calculados, mas não gravados em lugar nenhum. Em produção, você carrega um backend (CSV, ou `cdr_odbc`/`cdr_adaptive_odbc` para MySQL/PostgreSQL) e isso se torna sua fonte de faturamento e histórico. O CEL é **desativado por padrão** (`cel show status` reports `CEL Logging: Disabled` in the lab) and you enable it in `cel.conf` apenas quando você precisar de detalhes em nível de evento. Ambos são abordados em profundidade em *Asterisk Call Detail Records*; para monitoramento, o ponto principal é que CDR/CEL são seu registro *histórico*, enquanto a CLI é sua visão *ao vivo*.

### Eventos AMI e ARI

Para monitoramento programático em tempo real, você deseja um feed de eventos (push) em vez de consultar a CLI:

- **AMI (Asterisk Manager Interface)** é o protocolo de eventos/comandos TCP de longa data (`manager.conf`). Inscreva-se e você receberá `Newchannel`, `Hangup`, `DialBegin`, `BridgeEnter`, `PeerStatus` e eventos similares conforme as chamadas ocorrem — a espinha dorsal de painéis de monitoramento e ferramentas de contabilização de chamadas. No laboratório, o AMI é desativado por padrão (`manager show settings` relata `Manager (AMI): No`); você o ativa e protege em `manager.conf`.
- **ARI (Asterisk REST Interface)** é a interface moderna HTTP + WebSocket (`ari.conf`, servida pelo servidor HTTP integrado). Ela fornece um fluxo de eventos JSON e controle refinado de chamadas — a escolha certa para novas integrações.

Ambos são detalhados em *Extending Asterisk with AMI and AGI* e *The Asterisk REST Interface (ARI)*. O aviso relevante para a implantação: **AMI e ARI são poderosos e nunca devem ser expostos à internet.** Vincule o servidor HTTP ao localhost ou a uma rede de gerenciamento, use segredos fortes e exclusivos e proteja as portas com firewall — veja *Asterisk Security*.

### Métricas: Prometheus e Grafana

Para painéis e alertas, o Asterisk 22 vem com um exportador Prometheus, **`res_prometheus.so`** (um módulo com nível de suporte *extended*), que expõe métricas em um endpoint HTTP que um servidor Prometheus coleta. Além das métricas principais do processo, ele fornece provedores conectáveis que cobrem canais, chamadas, endpoints, bridges e registros de saída PJSIP:

```
# core process
asterisk_core_uptime_seconds
asterisk_core_last_reload_seconds
asterisk_core_scrape_time_ms
asterisk_core_properties
# channels
asterisk_channels_count
asterisk_channels_state
asterisk_channels_duration_seconds
# calls
asterisk_calls_count
asterisk_calls_sum
# endpoints
asterisk_endpoints_count
asterisk_endpoints_state
asterisk_endpoints_channels_count
# bridges
asterisk_bridges_count
asterisk_bridges_channels_count
# PJSIP outbound registrations
asterisk_pjsip_outbound_registration_status
```

Você pode confirmar se o módulo está presente na compilação do laboratório:

```
*CLI> module show like prometheus
Module                         Description                     Use Count  Status      Support Level
res_prometheus.so              Asterisk Prometheus Module      0          Not Running  extended
```

Ele mostra `Not Running` porque o laboratório não o configura nem o carrega; ativá-lo (`prometheus.conf` mais o servidor HTTP) transforma o Asterisk em um alvo do Prometheus. Aponte o Prometheus para o endpoint de coleta e o Grafana para o Prometheus, e você obterá painéis de séries temporais (chamadas simultâneas, registros, tendências de ASR/ACD) e alertas (por exemplo, "chamadas ativas caíram para zero" ou "picos de falhas de registro"). Para equipes que já executam Prometheus/Grafana, esta é a maneira natural de integrar o Asterisk à observabilidade existente, em vez de analisar a saída da CLI.

### Códigos de resposta SIP que merecem atenção

Independentemente do pipeline, alguns resultados SIP sinalizam problemas e merecem alertas: falhas persistentes de desafio `401`/`407` ou `403 Forbidden` sugerem um ataque de força bruta ou uma tempestade de credenciais mal configuradas (faça referência cruzada com o Fail2Ban em *Asterisk Security*); `503 Service Unavailable` aponta para um servidor ou trunk sobrecarregado ou congestionado; e um pico em `408 Request Timeout`/`480 Temporarily Unavailable` geralmente significa que os endpoints ficaram inacessíveis (timeout de NAT, falhas de qualify).

## Alta disponibilidade e escalabilidade

Um servidor Asterisk é um ponto único de falha e possui um limite finito de chamadas. Os dois problemas — *manter-se ativo* e *crescer* — possuem respostas diferentes.

### Ativo/standby com um IP flutuante

O padrão de HA clássico e amplamente utilizado para o Asterisk é o **ativo/standby** (não ativo/ativo — o estado da chamada no Asterisk é difícil de compartilhar em tempo real). Dois servidores idênticos, um ativo e um standby, compartilham um **IP flutuante (virtual)** gerenciado por um gerenciador de cluster, como o **keepalived** (VRRP) ou **Pacemaker/Corosync**. Telefones e trunks registram-se no IP flutuante, e não em qualquer um dos hosts reais. Se o nó ativo falhar em sua verificação de integridade, o IP flutuante move-se para o standby, que assume o controle.

A ressalva honesta: um failover de IP **derruba chamadas em andamento** — o Asterisk não replica o estado do canal em tempo real entre nós, portanto, qualquer pessoa no meio de uma chamada deve rediscar. Os registros são restabelecidos dentro de um ciclo de qualify/registration. O que o failover lhe proporciona é que o *serviço* se recupera em segundos sem intervenção manual, o que, para a maioria dos PBXs, é exatamente o objetivo. Para tornar o standby genuinamente capaz de assumir o controle, ambos os nós precisam da mesma configuração (seu `/etc/asterisk` via git, implantado de forma idêntica) e do mesmo *estado* — que é o próximo ponto.

### Externalizar o estado com PJSIP Realtime

O modo ativo/standby só funciona se o standby conhecer os mesmos endpoints e registros que o nó ativo. A maneira de conseguir isso é **parar de manter o estado em arquivos simples em uma única máquina** e movê-lo para um banco de dados compartilhado que ambos os nós leem. O **PJSIP Realtime** (Sorcery suportado por um banco de dados) faz exatamente isso: endpoints, AORs, auths — e, importante, **registros** (a tabela `ps_contacts`) — residem no MySQL/PostgreSQL em vez de `pjsip.conf` e memória local. Ambos os nós Asterisk apontam para o mesmo banco de dados, portanto, um telefone registrado através de um nó fica visível para o outro. Isso é abordado em *Asterisk Real-Time* (a seção PJSIP Realtime / Sorcery); aqui, o ponto da implantação é que **externalizar o estado é o pré-requisito tanto para HA quanto para escalabilidade horizontal** — sem isso, cada nó é uma ilha.

Aplique a mesma lógica ao restante do seu estado: CDR/CEL em um armazenamento SQL compartilhado, voicemail em armazenamento compartilhado/replicado (ou `ODBC_STORAGE`), e as chaves astdb das quais você depende em um banco de dados. Uma vez que o estado é externo, os nós Asterisk tornam-se mais próximos de front-ends intercambiáveis.

### Proxies SIP na frente (OpenSIPS)

Para escalar *além* da capacidade de um servidor, você coloca um **proxy SIP/balanceador de carga** na frente de um pool de servidores de mídia Asterisk. O **OpenSIPS** é um proxy SIP de altíssimo desempenho, construído para esse propósito (eles lidam com centenas de milhares de registros e roteiam sinalização sem tocar na mídia). O proxy apresenta um único endereço SIP para o mundo, mantém o serviço de registro/localização e distribui chamadas entre os back-ends Asterisk. Essa separação — uma camada de proxy leve fazendo registro e roteamento, uma camada Asterisk escalável horizontalmente fazendo o processamento real da chamada (IVR, filas, conferências, transcodificação) — é como grandes implantações crescem além de uma única máquina. (A própria plataforma SipPulse usa o OpenSIPS na frente de seus servidores de mídia/aplicação exatamente por esse motivo.)

### Escalabilidade de mídia

O proxy distribui a *sinalização* de forma barata; **a mídia é o recurso caro**. O retransmissor de RTP, e especialmente a transcodificação entre codecs (por exemplo, Opus ↔ G.711) ou a execução de grandes conferências, é limitado pela CPU e é o que realmente limita um servidor. Estratégias:

- **Evite a transcodificação** sempre que possível — negocie um codec comum de ponta a ponta para que o Asterisk faça a ponte nativamente (pass-through) em vez de transcodificar. Esta é a maior vantagem de capacidade de mídia.
- **Escale a mídia horizontalmente** adicionando nós Asterisk atrás do proxy; cada um carrega uma parte das chamadas simultâneas.
- **Descarregue a mídia do navegador** para um gateway WebRTC dedicado (por exemplo, Janus) para que o PBX não precise também terminar e retransmitir cada fluxo DTLS-SRTP do navegador — veja *WebRTC with Asterisk*, que discute exatamente essa divisão entre Asterisk e gateway.

Dimensione a capacidade por **chamadas simultâneas e carga de transcodificação**, não por usuários registrados — 10.000 telefones registrados que estão majoritariamente ociosos são muito mais baratos do que 200 conferências transcodificadas simultâneas.

## Hospedagem em nuvem

Executar o Asterisk em uma VM na nuvem (AWS, GCP, Azure, uma VPS) é comum e funciona bem, mas a rede em nuvem é **NAT'd e protegida por firewall por padrão**, o que entra em conflito com o SIP. A seguir, apresentamos as preocupações específicas de implantação.

### NAT e o SDP

Uma VM na nuvem quase sempre possui um IP **privado** em sua NIC e um IP **público** separado que o provedor mapeia via NAT para ela. Se o Asterisk anunciar o IP privado no SDP, os telefones remotos enviarão o RTP para um buraco negro — o sintoma clássico de áudio unidirecional ou sem áudio. Informe ao PJSIP sua identidade pública no transporte:

```
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=203.0.113.10      ; the VM's PUBLIC IP
external_signaling_address=203.0.113.10
local_net=10.0.0.0/8                     ; your private/VPC range(s)
```

`external_*` faz com que o Asterisk reescreva o endereço que ele anuncia para pares públicos, enquanto `local_net` informa quais pares são locais (e *não* devem ser reescritos). Este é o mesmo tratamento de NAT discutido para redes Docker em ponte acima — uma VM na nuvem está, na prática, atrás de um NAT.

### Firewall e o intervalo de RTP

Dois firewalls geralmente se aplicam em uma VM na nuvem: o grupo de segurança / ACL de rede do **provedor** e o iptables do **host**. Ambos devem abrir as mesmas portas, e a política é a do capítulo de Segurança. O conjunto de regras da 1ª edição recuperado (`docs/legacy-labs/configs/Lab7/rules.v4`) captura o formato — aceite SIP e o intervalo de RTP, aceite conexões estabelecidas/relacionadas, descarte o restante:

```
-A INPUT -p udp -m udp --dport 5060 -j ACCEPT
-A INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -j DROP
```

Duas correções que o capítulo de Segurança faz e que importam aqui: abra a **5061 em TCP** (não UDP) se você executar SIP/TLS, e lembre-se de que o intervalo UDP de RTP no seu firewall deve corresponder exatamente a `rtpstart`/`rtpend` em `rtp.conf` — o mesmo intervalo que você publica em um container. Não duplique a configuração de iptables/Fail2Ban aqui; **siga as seções de firewall, Fail2Ban e TLS/SRTP do *Asterisk Security*** (o Fail2Ban monitora o canal de log `security` que o laboratório já habilita em `logger.conf`) e aplique essa política *tanto* no firewall do host quanto no grupo de segurança da nuvem.

### Latência, região e o SBC

- **Escolha uma região próxima aos seus usuários.** A voz é sensível à latência — uma latência de boca-a-ouvido unidirecional acima de ~150 ms é perceptível. Hospede a VM na região mais próxima da maior parte dos seus telefones e trunks; mídia entre continentes é audivelmente pior.
- **Coloque um SBC na frente para qualquer implantação voltada para a internet.** Um **Session Border Controller** termina o SIP/RTP na borda, oculta sua topologia, normaliza o NAT e absorve tráfego de DoS e varredura antes que ele chegue ao Asterisk. A recomendação principal do capítulo de Segurança — *não exponha o Asterisk bruto à internet* — aplica-se duplamente na nuvem, onde o IP público da sua VM é varrido minutos após ser ativado. Um SBC (ou, no mínimo, um proxy SIP reforçado como o OpenSIPS mais Fail2Ban) é o padrão de borda.

## Resumo

A implantação é onde um dialplan funcional se torna um serviço confiável. Em uma VM, execute o Asterisk sob o **systemd** como um usuário **non-root**, deixando o `Restart=` da unidade mantê-lo ativo (o safe_asterisk foi substituído) e usando o `core reload` em vez de `systemctl restart` para alterações de configuração. A **containerização** com Docker — como o laboratório do livro faz — oferece uma imagem imutável e fixada com a configuração **bind-mounted** a partir de um `/etc/asterisk` versionado no git; o problema é a mídia, portanto, use **host networking** ou publique um intervalo de portas RTP que **corresponda exatamente ao `rtp.conf`**, e monte **persistent volumes** para spool/voicemail/astdb para que o estado sobreviva a uma reimplantação. Trate a configuração como código e **faça backup do estado** que a configuração não captura: voicemail, gravações, `astdb.sqlite3` e CDR/CEL. **Observe** o sistema em quatro níveis — a CLI (`core show channels`, `pjsip show endpoints`) para a visão em tempo real, **CDR/CEL** para o histórico, **AMI/ARI** para eventos programáticos e o exportador `res_prometheus` para o Grafana para painéis e alertas — mantendo o AMI/ARI fora da internet pública. Para **permanecer ativo**, execute em modo active/standby com um **floating IP** (aceitando que o failover derruba chamadas ativas); para **crescer**, externalize o estado com **PJSIP Realtime**, coloque um pool de servidores de mídia atrás do **OpenSIPS** e minimize a transcodificação, pois **a mídia — e não os registros — é o que limita um servidor**. Finalmente, na **nuvem**, trate a VM como se estivesse atrás de NAT (`external_media_address`, `local_net`), abra o firewall conforme o capítulo de Segurança tanto no host quanto no grupo de segurança do provedor, escolha uma região de baixa latência e nunca exponha o Asterisk diretamente — coloque um **SBC** na borda.

## Quiz

1. Em um host systemd, o que substitui a função do antigo `safe_asterisk` de reiniciar um Asterisk que travou?
   - A. Um job cron
   - B. A diretiva `Restart=` do arquivo unit
   - C. `systemctl enable`
   - D. O astdb
2. Para aplicar uma alteração de configuração em um Asterisk em execução **sem derrubar chamadas**, você deve:
   - A. `systemctl restart asterisk`
   - B. Reiniciar o servidor
   - C. `asterisk -rx 'core reload'`
   - D. Reconstruir a imagem do container
3. Um Asterisk conteinerizado (rede em bridge) conecta chamadas, mas **não tem áudio**. A causa mais provável é:
   - A. O dialplan está incorreto
   - B. O intervalo de portas UDP RTP publicado não corresponde a `rtpstart`/`rtpend` em `rtp.conf`
   - C. O CDR está desativado
   - D. A CLI está inacessível
4. Quais diretórios devem ser montados como **volumes persistentes** para que uma reimplantação de container não perca o estado? (marque todas as que se aplicam)
   - A. `/var/spool/asterisk` (voicemail, gravações)
   - B. `/var/lib/asterisk` (astdb)
   - C. `/etc/asterisk` (já montado via bind a partir do host)
   - D. `/usr/sbin`
5. Qual comando da CLI fornece a contagem em tempo real de chamadas ativas?
   - A. `cdr show status`
   - B. `core show channels`
   - C. `pjsip show transports`
   - D. `module show like prometheus`
6. No Asterisk 22, a maneira suportada de expor métricas de chamadas/canais para uma stack Prometheus/Grafana é:
   - A. Analisar o arquivo de log `full`
   - B. O módulo `res_prometheus.so`
   - C. Scripts AGI
   - D. Não existe nenhuma
7. Qual é o pré-requisito tanto para failover de HA quanto para escalonamento horizontal entre múltiplos nós Asterisk?
   - A. Executar como root
   - B. Externalizar o estado (por exemplo, registros PJSIP Realtime em um banco de dados compartilhado)
   - C. Desativar o CDR
   - D. Usar rede em bridge
8. Qual recurso limita mais diretamente quantas chamadas simultâneas um servidor Asterisk pode manipular?
   - A. O número de usuários registrados
   - B. Processamento de mídia, especialmente transcodificação
   - C. O tamanho de `/etc/asterisk`
   - D. O backend de CDR
9. Em uma VM na nuvem, quais configurações de transporte `pjsip.conf` fazem com que o Asterisk anuncie seu endereço público para que o áudio remoto funcione? (marque todas as que se aplicam)
   - A. `external_media_address`
   - B. `external_signaling_address`
   - C. `local_net`
   - D. `qualify_frequency`
10. Para uma implantação na nuvem voltada para a internet, a regra principal do capítulo de Segurança é:
    - A. Sempre usar duas placas de rede (NICs)
    - B. Nunca expor o Asterisk diretamente à internet; coloque um SBC (ou proxy endurecido + Fail2Ban) na borda
    - C. Usar apenas UDP
    - D. Desativar TLS

**Respostas:** 1 — B · 2 — C · 3 — B · 4 — A, B · 5 — B · 6 — B · 7 — B · 8 — B · 9 — A, B, C · 10 — B
