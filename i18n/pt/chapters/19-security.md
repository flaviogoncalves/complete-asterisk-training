# Segurança do Asterisk

Desde o início, a questão da segurança para o Asterisk é crítica. O SIP, Session Initiation Protocol, é o protocolo mais atacado na Internet de acordo com o CERT.BR. Qualquer pessoa que opere um honeypot pode confirmar isso. O problema da fraude de compartilhamento de receita na Internet (Internet Revenue Share Fraud) é muito sério e pode levar a prejuízos superiores a centenas de milhares de dólares. Você nunca deve instalar um servidor Asterisk conectado à Internet sem a devida segurança. Neste capítulo, você aprenderá como identificar os principais tipos de ataques que pode receber e como preveni-los usando uma política de segurança adequada. Por último, mas não menos importante, você aprenderá como implementar a política de segurança sugerida.

Este capítulo tem como alvo o **Asterisk 22 LTS**, onde o PJSIP (`res_pjsip` / `chan_pjsip`) é o único canal SIP. (O antigo driver `chan_sip` foi removido no Asterisk 21 — consulte o capítulo *Legacy Channels* se você estiver migrando um sistema mais antigo.) Uma consequência relevante para a segurança: falhas de autenticação agora são emitidas através do **security event framework** do Asterisk e do canal de log dedicado `security`, o que altera a forma como o Fail2Ban é configurado (abordado mais adiante neste capítulo).

## Objetivos

Ao final deste capítulo, você deverá ser capaz de:

- Identificar os principais tipos de ataques feitos frequentemente a servidores Asterisk
- Definir uma política de segurança eficaz
- Implementar a política de segurança
- Instalar e configurar o IPTABLES para Asterisk
- Instalar e configurar o Fail2Ban para Asterisk
- Instalar e configurar TLS e SRTP para criptografia

## Principais ataques à telefonia IP

Os principais ataques à telefonia IP podem ser classificados como DOS/DDOS, Roubo de Serviço/Fraude de Tarifação (Toll Fraud) e Escuta (Eavesdropping). Alguns dos nomes podem ser confusos e diferentes fontes às vezes usam nomes diferentes para o mesmo ataque. Roubo de Serviço, Fraude de Tarifação, Fraude de Compartilhamento de Receita na Internet e Fraude Telefônica são nomes diferentes para hackers que usam seu PBX para bombear tráfego para um Número de Tarifa Premium e obter reembolsos do provedor.

### DDoS/DOS

Negação de Serviço (Denial of Service) e Negação de Serviço Distribuída (Distributed Denial of Service) são ataques populares a qualquer infraestrutura de TI. Não é diferente com SIP e outros protocolos de Voice over IP. A negação de serviço distribuída é geralmente perpetrada por uma botnet, enquanto o DOS é realizado apenas por um único computador. Em fevereiro de 2011, a botnet Sality realizou uma varredura furtiva e coordenada de todo o espaço de endereçamento IPv4 em busca de servidores SIP vulneráveis — pesquisadores que observaram o Telescópio de Rede da UCSD atribuíram isso a aproximadamente três milhões de IPs de origem distintos sondando a porta UDP 5060, muito provavelmente para realizar ataques de força bruta em contas SIP para fraude de tarifação.[^sality]

[^sality]: A. Dainotti et al., "Analysis of a '/0' Stealth Scan from a Botnet," *IEEE/ACM Transactions on Networking*, 2015 (DOI 10.1109/TNET.2013.2297678).

![Uma botnet peer-to-peer direcionando milhares de tentativas de registro SIP a um servidor](../images/19-security-fig01.png)

O DOS é aplicado geralmente por meio de técnicas como fuzzing e flooding. O flooding pode usar SIP, IAX, RTP e outros protocolos. Eles podem parar o serviço completamente ou degradar a qualidade da voz. Eles são muito difíceis de mitigar se as portas estiverem abertas para a Internet. Abaixo estão algumas das ferramentas usadas pelos atacantes:

**Fuzzing:**

- **PROTOS Test Suite (c07-sip)** — da Universidade de Oulu OUSPG. Envia milhares de pacotes malformados para provocar um mau funcionamento, como um estouro de buffer (buffer overflow) que interrompe o software.
- **Voiper** — gera mais de 200.000 testes cobrindo todos os atributos SIP e verifica se o seu servidor consegue processar as mensagens efetivamente. <http://voiper.sourceforge.net/>

**Flooding:**

- **INVITE Flooder** — inunda o servidor com solicitações SIP INVITE. <http://www.hackingvoip.com/tools/inviteflood.tar.gz>
- **IAX Flooder** — inunda o servidor com tráfego IAX2. <http://www.hackingvoip.com/tools/iaxflood.tar.gz>
- **RTP Flooder** — inunda sessões de mídia ativas com pacotes RTP para degradar a qualidade da voz. <http://www.hackingvoip.com/tools/rtpflood.tar.gz>

### Técnicas de mitigação para DoS/DDoS

Minhas recomendações são:

1. Não exponha seu servidor Asterisk na Internet, a menos que seja necessário e com a proteção adequada (SBC).
2. Na rede interna, use uma Virtual LAN para voz, principalmente se você estiver em uma Universidade ou Faculdade onde o número de usuários é alto.
3. Use VPN ou TLS para acesso externo.

### Fraude de Compartilhamento de Receita na Internet

Esta fraude é um pouco complicada de entender. O segredo é compreender o conceito de um Número Internacional de Tarifa Premium (IPRN).

![As três etapas da Fraude de Compartilhamento de Receita na Internet: comprar um número de tarifa premium, encontrar um dispositivo VoIP vulnerável e ligar para o número, então coletar o pagamento](../images/19-security-fig02.png)

Um IPRN é um número que você pode alocar gratuitamente em algumas empresas de telefonia via internet específicas. Pesquise por Provedores de Números de Tarifa Premium na Internet e você encontrará vários deles. Nesse tipo de operadora, você pode alocar, por exemplo, um número em uma rede de satélite como a Iridium, um destino que custa dezenas de dólares por minuto para quem liga. O provedor de IPRN pagará de volta uma porcentagem da receita (10 a 20% da renda) para cada minuto recebido.

![Uma lista de preços de um provedor de IPRN mostrando taxas de pagamento por país e números de teste](../images/19-security-fig03.png)

Após a fase de alocação, o hacker tenta encontrar qualquer servidor Asterisk aberto capaz de discar para o IPRN alocado. O PBX da vítima, controlado pelo hacker, fará centenas de chamadas para o número IPRN, gerando um grande retorno financeiro para o hacker e uma conta telefônica enorme para a vítima. Muitas vezes, superior a centenas de milhares de dólares em um único fim de semana.

Principais ferramentas usadas por hackers para atacar um PBX:

1. **SIPVicious**: http://code.google.com/p/sipvicious/. Sipvicious é um conjunto de ferramentas de segurança fácil de usar. Seu objetivo principal é reconhecer PBXs vulneráveis e quebrar as senhas SIP usando um ataque de força bruta. A ferramenta mais usada é o svcrack. A ferramenta é capaz de testar milhares de senhas por segundo.
2. **Vulnerabilidades de telefone**. Outro ponto frequentemente usado por hackers como vetor de ataque é o próprio telefone. Muitas pessoas que instalam o Asterisk não alteram a senha padrão na interface web do telefone. Uma vez que esses telefones estão abertos na Internet, os hackers podem tentar usar a senha de interface padrão para baixar a configuração, onde muitas vezes podem encontrar a senha SIP secreta.

#### TFTPTheft:

Se você está usando o provisionamento automático de telefones via TFTP, você provavelmente está aberto a esse tipo de ataque. TFTP é uma forma simples e insegura de um Protocolo de Transferência de Arquivos.

![Um atacante baixando arquivos .cfg adivinháveis de um servidor TFTP, coletando credenciais em texto simples dos arquivos de configuração](../images/19-security-fig04.png)

O nome dos arquivos de configuração é facilmente adivinhável usando o endereço MAC seguido de .cfg (por exemplo, 001A2B3C4D5E.cfg). Um hacker experiente pode facilmente criar um utilitário para tentar todos os endereços MAC sequencialmente ou simplesmente baixar uma ferramenta para fazê-lo. O arquivo de configuração geralmente não é criptografado e contém a senha SIP secreta dentro dele.

#### Mitigação para ataques de força bruta e TFTPTheft

Para mitigar esses ataques, você pode aplicar as soluções abaixo. Força bruta: A melhor solução para mitigar ataques de força bruta é prevenir tentativas não autorizadas sequenciais. Quase qualquer instalador do Asterisk usa o utilitário fail2ban para isso. Quando o fail2ban detecta múltiplas tentativas com a senha ou nome de usuário incorretos, ele bane o IP do atacante por um determinado período de tempo. A segunda medida contra força bruta é usar senhas fortes, com mais de 12 caracteres e pelo menos um caractere especial. TFTPTheft: Para prevenir o TFTPTheft, configure o provisionamento para usar https com nome de usuário e senha. O arquivo é transmitido criptografado e um nome de usuário e senha impedem que atacantes tentem baixar quaisquer arquivos.

### Escuta (Eavesdropping)

Não vemos muitos desses tipos de ataque porque, na maioria dos casos, eles simplesmente não são detectados. A escuta é muito difícil de detectar em um ambiente IP. Utilitários como o UCsniff, disponíveis gratuitamente, são capazes de interceptar uma chamada VoIP na maioria das redes. A técnica principal é usar ARP spoofing para forçar o tráfego através do computador que executa o UCsniff e gravar as chamadas.

#### Mitigação para escuta

Você pode prevenir a escuta criptografando seu tráfego VoIP. A outra maneira é prevenir ataques de homem no meio (MITM) em sua rede. A inspeção ARP é muito eficaz para prevenir MITM em redes de camada 2. Verifique com o suporte técnico da sua rede para entender como implementar. Mais adiante neste livro, aprenderemos como instalar a criptografia baseada em TLS e SRTP. Você também pode usar o ARPWatch para descobrir se alguém está abusando do protocolo ARP para atacar sua rede.

## Política de segurança para o Asterisk

A melhor maneira de implementar segurança é criar uma política de segurança. Para este treinamento, sugerirei uma política de segurança para a maioria das instalações do Asterisk. Use-a como ponto de partida e altere-a de acordo com suas necessidades. A política de segurança sugerida segue abaixo:

1. Nenhuma porta UDP/TCP desnecessária aberta
2. Nenhum acesso a qualquer interface administrativa (SSH/HTTPS) aberto na Internet.
3. Para acessar SSH e/ou HTTP/HTTPS, deve haver exceções explícitas no firewall IPTABLES
4. Senhas fortes com 12 caracteres e pelo menos um caractere especial
5. Banir endereços IP que falharem mais de 10 vezes na autenticação usando Fail2ban
6. Confirmação de senha para chamadas internacionais
7. Limitar o acesso à porta SIP ao seu intervalo conhecido de endereços IP

Se você precisar de acesso externo ao seu PBX, existem duas possibilidades. Use um SBC (Session Border Controller) para proteger seu servidor contra DOS/DDOS ou use uma VPN sempre que desejar acesso externo. Se você deixar a porta 5060 aberta na Internet sem um SBC ou VPN, você estará exposto a um ataque de DOS/DDOS. O risco é seu.

### Endurecimento (hardening) na era PJSIP (Asterisk 22)

Além do firewall e do Fail2Ban, a stack PJSIP do Asterisk 22 fornece vários controles em nível de configuração que devem fazer parte da sua política de segurança. Eles complementam (não substituem) os controles de rede acima:

- **Autenticação por endpoint.** Todo endpoint deve referenciar uma seção `type=auth` dedicada com uma `password` forte e única (`auth_type=digest`). Nunca reutilize credenciais entre endpoints.
- **Tratamento de chamadas anônimas integrado.** O PJSIP não revela se um nome de usuário existe quando a autenticação falha. Para aceitar chamadas anônimas, você deve criar explicitamente um endpoint chamado `anonymous` e usar seções `type=identify` (correspondendo ao IP de origem) para mapear peers conhecidos para endpoints. Se você não deseja chamadas anônimas, simplesmente não crie um endpoint `anonymous`, e as solicitações não correspondentes serão desafiadas/rejeitadas.
- **ACLs.** Restrinja quem pode acessar um endpoint com ACLs nomeadas `/etc/asterisk/acl.conf`, referenciadas a partir do endpoint com `acl=` (ACL de sinalização/origem) e `contact_acl=` (restringe o endereço de contato/registro). Você também pode definir permit/deny diretamente no endpoint.
- **`qualify`.** Defina `qualify_frequency` (e `qualify_timeout`) no AOR para que o Asterisk monitore ativamente a acessibilidade dos contatos registrados e remova os inativos.
- **Endurecimento de transporte PJSIP / Proteção contra DoS.** O `type=transport` não expõe um limite de clientes por transporte, portanto, a proteção contra inundação de conexões (connection-flood) vem do firewall (as regras de iptables/Fail2Ban neste capítulo) em vez de uma opção do PJSIP. O que o transporte *oferece* é o ajuste de keep-alive TCP (`tcp_keepalive_enable`, `tcp_keepalive_idle_time`, `tcp_keepalive_interval_time`, `tcp_keepalive_probe_count`) para encerrar conexões inativas/semiabertas, e configurações de `local_net`/`external_*` para o tratamento correto de NAT. Combine-os com as regras de firewall para mitigar ataques de inundação de conexões.
- **TLS + SRTP para mídia.** Criptografe a sinalização com um transporte TLS e a mídia com `media_encryption=sdes` (ou `dtls` para WebRTC) no endpoint — abordado mais adiante neste capítulo.
- **Controle de acesso AMI/ARI.** Restrinja a Asterisk Manager Interface (`manager.conf`) e a ARI (`ari.conf` / `http.conf`) ao localhost ou a uma rede de gerenciamento confiável, use segredos fortes e únicos, vincule o servidor HTTP a uma interface privada e nunca exponha esses serviços à Internet.

Todos os nomes de opções acima foram confirmados no Asterisk 22.10: a seção `type=transport` expõe `tcp_keepalive_enable`, `tcp_keepalive_idle_time`, `tcp_keepalive_interval_time`, `tcp_keepalive_probe_count`, `tos`, `cos`, `local_net` e a família `external_*`, mas **não** possui uma opção `max_clients` — a proteção contra inundação de conexões vem do firewall, não do transporte. As opções de endpoint `acl` e `contact_acl` utilizam nomes de seção de `acl.conf`, e a correspondência de IP de origem para peers não autenticados é feita com seções `type=identify` (`match=`).

### Removendo portas desnecessárias

Em vez de descobrir todas as vulnerabilidades associadas a todos os protocolos do Asterisk, vamos simplificar o problema removendo as portas desnecessárias. Para listar todas as portas abertas pelo servidor Asterisk, use:

```
netstat -pantu |grep asterisk
```

A saída do comando é mostrada abaixo.

![saída do netstat mostrando as muitas portas vinculadas pelo Asterisk, incluindo 4569 (IAX) e 2727 (MGCP)](../images/19-security-fig05.png)

Se você observar a saída, descobrirá que muitas portas estão abertas. Precisamos delas? Não necessariamente, 2727 é o protocolo MGCP (chan_mgcp), 4569 é o IAX (chan_iax2). Se você não estiver usando esses protocolos, pode simplesmente remover o módulo no arquivo de configuração modules.conf.

Você pode notar o Asterisk vinculando uma porta UDP de número alto. Isso ocorre devido ao resolvedor do `res_pjsip` fazendo consultas DNS de saída (a porta de origem é efêmera, como qualquer consulta DNS de cliente), não de um ouvinte de entrada — seu firewall só precisa permitir tráfego de retorno **established/related** para isso (a regra de iptables `conntrack ESTABLISHED,RELATED` mostrada abaixo já cobre isso). Você **não** precisa abrir um amplo intervalo de portas UDP de entrada apenas para o DNS do PJSIP.

Para remover as portas desnecessárias, desabilite os módulos que você não usa. Edite o arquivo modules.conf e adicione linhas `noload` para os canais e protocolos que você não está usando. **Não** faça noload em `res_pjsip`, `res_pjproject` ou `chan_pjsip` — eles são necessários para SIP no Asterisk 22:

```
; res_pjsip / res_pjproject / chan_pjsip are REQUIRED in Asterisk 22 - keep them loaded
noload => chan_iax2.so
noload => chan_unistim.so
```

(No Asterisk 22, você não precisa mais fazer noload em `chan_mgcp` ou `chan_skinny` — esses drivers foram *removidos* no Asterisk 21 e não fazem parte de uma compilação padrão do 22.) Com as instruções acima, removi todos os canais desnecessários, mantendo apenas o PJSIP. Você pode escolher quais módulos de protocolo desejar, apenas remova os não utilizados. O resultado é mostrado na captura de tela abaixo — apenas a porta SIP (5060) vinculada pelo seu transporte PJSIP está agora exposta para entrada.

![saída do netstat após desabilitar os módulos não utilizados: apenas a porta UDP 5060 permanece vinculada pelo Asterisk](../images/19-security-fig06.png)

### Implementando a política de segurança com IPTABLES

O IPTABLES ou netfilter é um firewall padrão presente na maioria das distribuições Linux. Neste laboratório, configuraremos o iptables e o fail2ban. O objetivo é implementar a política de segurança recomendada para o Asterisk e bloquear todo o tráfego desnecessário. Siga os passos abaixo:

1. Bloquear todo o tráfego externo
2. Permitir tráfego SSH de uma rede interna ou host único
3. Permitir tráfego SIP em UDP e TCP nas portas 5060
4. Permitir tráfego RTP no intervalo de portas de mídia UDP. Não existe um padrão interno único — o próprio `rtp.conf` do Asterisk volta para as portas 5000–31000 quando nada é definido, mas o arquivo `rtp.conf.sample` fornecido configura `rtpstart=10000` / `rtpend=20000`, então usamos esse intervalo de exemplo aqui. Corresponda sua regra de firewall ao que você realmente definiu em `rtpstart`/`rtpend` no arquivo `rtp.conf`.

Certifique-se de ter acesso ao console do servidor, você não quer se bloquear fora do sistema. Tenha cuidado.

1. Instale o pacote net-persistent.

   ```
   sudo apt-get install iptables-persistent
   ```

2. Permitir todo o tráfego do loopback

   ```
   sudo iptables -I INPUT -i lo -j ACCEPT
   sudo iptables -I OUTPUT -o lo -j ACCEPT
   ```

3. Permitir conexões estabelecidas

   ```
   sudo iptables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
   ```

4. Permitir tráfego SSH/HTTPS da rede 192.168.0.0

   ```
   sudo iptables -I INPUT -p tcp -s 192.168.0.0/16 --dport 22 -m conntrack --ctstate
   NEW,ESTABLISHED -j ACCEPT
   sudo iptables -I INPUT -p tcp -s 192.168.0.0/16 --dport 443 -m conntrack --ctstate
   NEW,ESTABLISHED -j ACCEPT
   ```

5. Insira as regras do Asterisk

   ```
   sudo iptables -I INPUT -p udp -m udp --dport 5060 -j ACCEPT
   sudo iptables -I INPUT -p tcp -m tcp --dport 5060 -j ACCEPT
   sudo iptables -I INPUT -p tcp -m tcp --dport 5061 -j ACCEPT
   sudo iptables -I INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT
   ```

   Observe que a porta 5061 (SIP sobre TLS) é **TCP**, não UDP. As regras acima abrem a 5060 em UDP e TCP e a 5061 em TCP. Se você usa apenas TLS, pode descartar totalmente as regras simples da 5060. Abra apenas as portas às quais seus transportes PJSIP realmente se vinculam.

   `-I` significa PREPEND (inserir no início)

6. A última regra deve ser um drop

   ```
   sudo iptables -A INPUT -j DROP
   ```

   `-A` significa APPEND (adicionar ao final). Nota: Tenha cuidado ao manter novas regras, você deve adicionar regras antes do DROP. Use PREPEND para novas regras `-I`

7. Salve as regras e reinicie o iptables

   ```
   sudo iptables-save >/etc/iptables/rules.v4
   sudo /etc/init.d/netfilter-persistent restart
   ```

### Usando o Fail2Ban para bloquear múltiplas tentativas falhas de autenticação

O Fail2Ban é quase um padrão para o Asterisk. A maioria dos usuários o implementa para aumentar a segurança. Este utilitário verifica os logs do Asterisk em busca de tentativas falhas e bane os endereços IP dos atacantes. Abaixo, forneço as instruções para instalar o Fail2Ban.

No Asterisk 22, o PJSIP relata autenticações falhas e outros eventos de segurança através do **framework de eventos de segurança** do Asterisk, gravado no canal de log dedicado **`security`**. Para fazer o Fail2Ban funcionar, você deve:

1. Habilitar o canal de segurança em `/etc/asterisk/logger.conf`. A sintaxe é `<filename> => <levels>`, então para enviar o nível de segurança para um arquivo chamado `security`, escreva:

```
[logfiles]
security => security
```

então execute `logger reload` a partir da CLI. Isso produz `/var/log/asterisk/security` com uma linha por evento de segurança, na forma:

```
[2026-01-15 10:23:45] SECURITY[1234] res_security_log.c: SecurityEvent="InvalidPassword",...,RemoteAddress="IPV4/UDP/203.0.113.7/5060",...
```

Os eventos com os quais o Fail2Ban se preocupa são `InvalidPassword`, `ChallengeResponseFailed`, `InvalidAccountID` e `FailedACL`, cada um carregando um campo `RemoteAddress="IPV4/UDP/<ip>/<port>"` que identifica o infrator. (Observe que o endereço é envolvido como `IPV4/UDP/.../...`, não um IP puro — seu filtro deve extrair o host de dentro dessa string.)

2. Aponte a jail `asterisk` para esse arquivo (`logpath = /var/log/asterisk/security`) e use um filtro que analise esse formato de evento de segurança.

O Fail2Ban moderno vem com um filtro `asterisk` cujo `failregex` já corresponde aos eventos acima e extrai `<HOST>` do campo `RemoteAddress`, por exemplo:

```
failregex = ^SecurityEvent="(?:FailedACL|InvalidAccountID|ChallengeResponseFailed|InvalidPassword)".*,RemoteAddress="IPV[46]/[^/"]+/<HOST>/\d+"
```

Distribuições de PBX (FreePBX/Sangoma) fornecem filtros equivalentes. Prefira o filtro empacotado em vez de escrever um manualmente, já que as strings exatas dos eventos dependem da versão. Um aviso a ser observado: um aviso agora corrigido (GHSA-5743-x3p5-3rg7) mostrou que tráfego PJSIP criado especificamente poderia injetar linhas de log falsas — mantenha tanto o Asterisk quanto seu filtro Fail2Ban atualizados.

Abaixo, forneço as instruções para instalar o Fail2Ban

1. Instale o fail2ban no Linux

   ```
   sudo apt-get install fail2ban
   ```

2. Ative o fail2ban para Asterisk e SSH

   ```
   sudo vi /etc/fail2ban/jails.d/defaults-debian.conf
   ```

   Adicione as seguintes linhas para ativar o fail2ban para ssh e asterisk

   ```
   [sshd]
   enabled = true
   [asterisk]
   enabled=true
   ```

3. Reinicie o fail2ban

   ```
   /etc/init.d/fail2ban restart
   ```

4. Verifique. Altere o segredo do seu softphone e tente registrar-se novamente 10 vezes. Usando `iptables -L`, verifique se o endereço do softphone foi incluído como um endereço bloqueado.
5. Remova o endereço do banimento (suponha que o endereço seja 192.168.0.5)

   ```
   sudo fail2ban-client set asterisk unbanip 192.168.0.5
   ```

Nota: No comando, substitua 192.168.0.5 pelo endereço IP do seu telefone

### Implementando TLS e SRTP

Dividirei esta seção em duas. Na primeira parte, abordaremos o TLS para criptografar a sinalização e, na segunda parte, o SRTP para criptografar a mídia. O objetivo aqui é configurar o Asterisk para esses recursos.

#### TLS

TLS (Transport Layer Security) é o mecanismo de criptografia definido para proteger a sinalização SIP. A tabela abaixo resume contra quais ataques o TLS protege:

| Tipo de ataque | Protegido? | Notas |
|----------------|-----------|-------|
| Ataques de sinalização | Sim | O TLS garante a integridade das mensagens |
| Man in the middle | Sim | O TLS verifica o certificado do servidor |
| Eavesdropping | Não | O TLS criptografa a sinalização, não a mídia |

Para criptografia de mídia (voz/vídeo), use SRTP.

#### Certificados digitais autoassinados

Existem dois tipos de certificados que você pode usar: autoassinados e comerciais. Certificados autoassinados são assinados pelo seu próprio servidor, enquanto certificados comerciais são assinados por uma autoridade externa. Para VoIP, você pode ser sua própria autoridade certificadora. Não há necessidade de um certificado externo como GoDaddy e Verisign, essa é uma despesa desnecessária. Geraremos nossos próprios certificados usando ast_tls_cert.

#### Configurando TLS com certificados autoassinados

Abaixo está um guia passo a passo sobre como implementar o TLS. Primeiro, geramos os certificados, depois configuramos o transporte TLS do PJSIP (veja "Configurando TLS com chan_pjsip") e, finalmente, apontamos o softphone para ele. Usaremos o SipPulse Softphone, que suporta TLS e SRTP nativamente. (Qualquer softphone SIP capaz de TLS/SRTP funciona da mesma maneira.)

**Passo 1.** Crie uma chave RSA privada usando criptografia 3DES com comprimento de 4096 bits para nossa autoridade de certificação. O comando abaixo, presente em /usr/src/asterisk-22.x.y/contrib/scripts, criará a Autoridade de Certificação e o Certificado do Asterisk. Como de costume, adapte as instruções se necessário; as versões mudam, os diretórios mudam. Por favor, preste atenção no que você está fazendo. Use seu domínio ou endereço IP na opção –C. O comando ast_tls_cert tem três opções.

- -C host ou endereço IP (usei 192.168.0.74, o endereço IP da minha VM)
- -O Nome organizacional
- -d Diretório onde armazenar as chaves

```
mkdir /etc/asterisk/keys
cd /usr/src/asterisk-22.0.0/contrib/scripts
root@asterisk:/usr/src/asterisk-22.0.0/contrib/scripts# ./ast_tls_cert -C 192.168.0.74 -O "AsteriskGuide" -d /etc/asterisk/keys
No config file specified, creating '/etc/asterisk/keys/tmp.cfg'
You can use this config file to create additional certs without
re-entering the information for the fields in the certificate
Creating CA key /etc/asterisk/keys/ca.key
Generating RSA private key, 4096 bit long modulus
........................................................++
........................................................++
e is 65537 (0x010001)
Enter pass phrase for /etc/asterisk/keys/ca.key:
Verifying - Enter pass phrase for /etc/asterisk/keys/ca.key:
Creating CA certificate /etc/asterisk/keys/ca.crt
Enter pass phrase for /etc/asterisk/keys/ca.key:
Creating certificate /etc/asterisk/keys/asterisk.key
Generating RSA private key, 2048 bit long modulus
........................++++++
......................++++++
e is 65537 (0x010001)
Creating signing request /etc/asterisk/keys/asterisk.csr
Creating certificate /etc/asterisk/keys/asterisk.crt
Signature ok
subject=CN = 192.168.0.74, O = AsteriskGuide
Getting CA Private Key
Enter pass phrase for /etc/asterisk/keys/ca.key:
Combining key and crt into /etc/asterisk/keys/asterisk.pem
root@asterisk:/usr/src/asterisk-22.0.0/contrib/scripts#
```

Não vou gerar um certificado de cliente porque não vamos usar o certificado para autenticar o cliente. O cliente não é obrigado a apresentar seu próprio certificado.

**Passo 2.** Configure o Asterisk para suportar nosso cliente via TLS. Isso é feito em `pjsip.conf` (um transporte TLS mais as configurações de endpoint) — a configuração completa é mostrada na próxima seção, "Configurando TLS com chan_pjsip". Não estamos autenticando usando certificados, apenas criptografando o tráfego.

**Passo 3.** Instale um softphone SIP capaz de TLS (o autor usa o SipPulse Softphone).

**Passo 4.** Copie a autoridade de certificação para o computador que executa o softphone. Após instalá-lo, copie o arquivo `/etc/asterisk/keys/ca.crt` para o computador que executa o softphone (use scp ou WinSCP no Windows) se você estiver usando um certificado autoassinado.

**Passo 5.** Crie a conta no softphone. Na tela de conta, adicione a conta normalmente como qualquer outra conta SIP. Use a senha correta; a autenticação ainda é baseada na senha.

**Passo 6.** Defina TLS como o transporte nas configurações da conta. Na tela de conta do SipPulse Softphone (abaixo), escolha **TLS** como o transporte e use a porta 5061. Ajuste seu firewall para abrir a porta TCP 5061.

![A tela de conta do SipPulse Softphone — insira o Servidor (seu IP ou domínio do Asterisk), Nome de Usuário, Senha e Nome de Exibição, então escolha o Transporte (UDP, TCP ou TLS).](../images/softphone/sipphone-account.png){width=35%}

**Passo 7.** Confie na autoridade de certificação. Se o seu certificado TLS do Asterisk for assinado por uma CA pública (por exemplo, Let's Encrypt — veja o capítulo *Implantação*), um softphone moderno como o SipPulse Softphone confia nele automaticamente através do armazenamento de certificados do sistema, sem importação manual. Se você usar um certificado autoassinado, importe sua CA (`/etc/asterisk/keys/ca.crt`) para o cliente ou para o armazenamento de confiança do sistema operacional, ou aceite-o quando solicitado.

**Passo 8.** Você **não** precisa de um certificado de cliente. Um equívoco comum é que cada telefone precisa de seu próprio certificado para autenticar — não precisa. Neste ponto, o Asterisk apenas *criptografa* a sessão; a autenticação ainda é nome de usuário e senha. O Asterisk não verifica certificados de cliente por padrão, portanto, não há necessidade de distribuir um certificado por cliente.

**Passo 9.** Após alterar o certificado ou o transporte, reinicie totalmente o softphone (saia e reinicie, não apenas feche a janela) para que ele se reconecte através do novo transporte.

### Configurando TLS com chan_pjsip

Agora vamos aprender como configurar o PJSIP para TLS. O PJSIP é o único canal SIP no Asterisk 22, então não há nada para trocar — apenas certifique-se de que `res_pjsip`, `res_pjproject` e `chan_pjsip` estejam carregados. Passo 1: Confirme se o PJSIP está habilitado em /etc/asterisk/modules.conf.

```
; res_pjsip / res_pjproject / chan_pjsip must be loaded (do NOT noload them)
noload => chan_iax2.so
noload => chan_unistim.so
```

Passo 2: Configure o PJSIP para suportar TLS. Adicione uma seção para o transporte TLS no arquivo /etc/asterisk/pjsip.conf

```
[transport-tls]
type=transport
protocol=tls
bind=0.0.0.0:5061
cert_file=/etc/asterisk/keys/asterisk.crt
priv_key_file=/etc/asterisk/keys/asterisk.key
method=tlsv1_2
```

Use `method=tlsv1_2` (ou `tlsv1_3` se sua compilação de OpenSSL/PJSIP suportar) — TLS 1.0/1.1 são obsoletos e inseguros e não devem ser usados.

Passo 3: Configure o endpoint para o blink. Edite `pjsip.conf` e edite a seção para o blink. Deixe o PJSIP escolher o transporte automaticamente.

```
[blink]
type=endpoint
aors=blink
auth=blink
context=from-internal
disallow=all
allow=ulaw
dtmf_mode=rfc4733
media_encryption=sdes
[blink]
type=aor
max_contacts=2
remove_existing=yes
[blink]
type=auth
auth_type=digest
username=blink
password=supersecret
```

Passo 4: Verificando. Para verificar se o registro ocorreu via TLS, use o seguinte comando no console do Asterisk.

```text
asterisk*CLI> pjsip show aor blink

      Aor:  <Aor.............................................>  <MaxContact>
    Contact:  <Aor/ContactUri........................> <Hash....> <Status> <RTT(ms)..>
==========================================================================================

      Aor:  blink                                                2
    Contact:  blink/sip:03694827@192.168.0.67:56295;transp 620d91556d NonQual    nan
 ParameterName        : ParameterValue
 ====================================================================
 authenticate_qualify : false
 contact              : sip:03694827@192.168.0.67:56295;transport=tls
 default_expiration   : 3600
 max_contacts         : 2
 maximum_expiration   : 7200
 minimum_expiration   : 60
 qualify_frequency    : 0
 qualify_timeout      : 3.000000
 remove_existing      : true
 support_path         : false
```

### Fazendo chamadas seguras usando SRTP

O protocolo responsável pela criptografia de mídia é o Secure Real Time Protocol (SRTP), definido na RFC3711. Uma das deficiências do protocolo é a falta de uma maneira padronizada de trocar chaves. O Asterisk usa chaves de troca SDES sobre o protocolo SDP, protegido pela criptografia de sinalização fornecida pelo TLS. Existem também outros métodos, como MIKEY e ZRTP. O ZRTP, desenvolvido por Philipp Zimmermann, é um dos métodos mais sofisticados para troca de chaves e criptografia de mídia. Alguns softphones e telefones físicos permitem ZRTP. No entanto, a maneira padrão ainda é o SDES e você encontrará esse método em quase qualquer telefone disponível no mercado. Abaixo, um exemplo de uma solicitação com as chaves criptográficas definidas no SDP nas linhas a=crypto:1 e a=crypto:2.

```
INVITE sip:8000@192.168.1.237 SIP/2.0
Via:
SIP/2.0/tls
192.168.1.192:65525;rport;branch=z9hG4bKPj9fa224a14b17488ea15625ead833ea3a
Max-Forwards: 70
From:
"Flavio"
<sip:flavio@192.168.1.237>;tag=35afe6cc11274934867b24e43c805638
To: <sip:8000@192.168.1.237>
Contact: <sip:pyhkxnjz@192.168.1.192:65524;transport=tls>
Call-ID: 530a339c72af47f0a76e7ecb2a58ac43
CSeq: 5669 INVITE
Allow: SUBSCRIBE, NOTIFY, PRACK, INVITE, ACK, BYE, CANCEL, UPDATE, MESSAGE
Supported: 100rel
User-Agent: Blink 0.2.5 (Windows)
Authorization: Digest username="flavio", realm="asterisk", nonce="72ff51ad",
uri="sip:8000@192.168.1.237",
response="ba8c10672751baa7007d82eb34e2340e",
algorithm=MD5
Content-Type: application/sdp
Content-Length: 544
v=0
o=- 3509174186 3509174186 IN IP4 192.168.1.192
s=Blink 0.2.5 (Windows)
c=IN IP4 192.168.1.192
t=0 0
m=audio 50004 RTP/SAVP 9 104 103 102 0 8 101
a=rtcp:50005
a=rtpmap:9 G722/8000
a=rtpmap:104 speex/32000
a=rtpmap:103 speex/16000
a=rtpmap:102 speex/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-15
a=crypto:1
AES_CM_128_HMAC_SHA1_80
inline:WrtZH82ztz93albRNT8o+oMcK9GvlAHRoaR1STvJ
a=crypto:2
AES_CM_128_HMAC_SHA1_32
inline:4Ma9jJOCEEGMPzzkmgyf6ttp1qhN16yumdXB7eRv
a=sendrecv
```

#### Configurando SRTP no Asterisk

Configurar o SRTP no Asterisk é muito simples. Defina `media_encryption=sdes` no endpoint; você também pode exigi-lo com `media_encryption_optimistic=no` para que a mídia não criptografada seja rejeitada em vez de silenciosamente permitida. Observe que o SDES requer que a sinalização seja executada sobre TLS para que as chaves não sejam enviadas em texto claro.

**Passo 1.** Configuração do Asterisk

Defina o seguinte na seção `type=endpoint` em `pjsip.conf`:

```
[blink]
type=endpoint
aors=blink
auth=blink
context=from-internal
disallow=all
allow=ulaw
transport=transport-tls
media_encryption=sdes
media_encryption_optimistic=no
```

**Passo 2.** Configuração do softphone

No softphone, habilite o SRTP para a mídia da conta (defina a opção **SRTP (Media Encryption)** como *Mandatory*) para que a voz seja criptografada.

![As configurações de conta do SipPulse Softphone (seção inferior) — defina **Transport** como TLS e **SRTP (Media Encryption)** como *Mandatory* para que a sinalização e a mídia sejam ambas criptografadas.](../images/softphone/sipphone-config.png){width=35%}

## Habilitando autenticação de dois fatores para chamadas internacionais

Às vezes, a melhor maneira é não ter rotas internacionais. No entanto, se você realmente precisa discar para o exterior, use uma senha extra. Vamos usar a aplicação do Asterisk vmauthenticate para solicitar a senha do voicemail antes de discar internacionalmente. Isso é configurado no dialplan no arquivo extensions.conf. Veja o exemplo abaixo. Assim, um hacker, mesmo após descobrir a senha de um peer ou comprometer um telefone, ainda precisará da senha do voicemail para discar para este destino.

```
exten=_9011.,1,Playback(pleasedialyourvmpassword)
exten=_9011.,2,VMAuthenticate(${CALLERID(num)}@default,s)
exten=_9011.,3,Dial(PJSIP/${EXTEN:1}@my_trunk,20,tT)
exten=_9011.,4,Hangup()
```

`VMAuthenticate` ainda é uma aplicação padrão no Asterisk 22. O `Dial()` acima roteia a chamada através de um trunk SIP/PJSIP (`PJSIP/<number>@<trunk>`), que é como a maioria das instalações modernas alcança a PSTN — adapte `my_trunk` para o nome do seu próprio trunk e use `DAHDI/g1/...` apenas se você realmente possuir uma span DAHDI. A defesa contra fraude de tarifação no dialplan — um segundo fator como este, combinado com a restrição de quais contexts podem acessar suas rotas de saída e internacionais — continua sendo uma das proteções mais importantes que você pode implementar.

## Resumo

Neste capítulo, você aprendeu sobre os riscos de ter um IP PBX conectado à Internet. Em seguida, aprendemos como proteger nosso PBX implementando uma política de segurança. Nesta política de segurança, implementamos iptables, fail2ban, TLS, SRTP e autenticação de dois fatores para chamadas internacionais. Espero que você tenha aproveitado este capítulo.

## Quiz

1. Qual é a contramedida mais importante contra a fraude de compartilhamento de receita (Revenue Share Fraud) na Internet?
   - A. Implementar SRTP
   - B. Manter o Asterisk atualizado
   - C. Implementar TLS
   - D. Usar senhas fortes
2. O SIP fuzzing é definido como:
   - A. Um ataque de DoS usando solicitações e respostas malformadas
   - B. Roubo de serviço onde senhas são descobertas por força bruta
   - C. Escuta de chamadas em curso
   - D. Um DDoS com uma inundação de solicitações SIP
3. O TFTPTheft ocorre quando o servidor fornece arquivos de configuração via TFTP. Você pode evitá-lo usando:
   - A. FTP
   - B. HTTP
   - C. HTTPS com nome de usuário e senha
   - D. SCP
4. Ataques de Man-in-the-middle usam uma técnica chamada:
   - A. TFTP theft
   - B. ARP spoofing
   - C. MAC poisoning
   - D. dsniff
5. Para SRTP, o Asterisk usa o seguinte sistema para trocar chaves:
   - A. MIKEY
   - B. SDES
   - C. ZRTP
   - D. Pluto
6. O utilitário que gera a autoridade de certificação e os certificados, encontrado em `/usr/src/asterisk-22.x.y/contrib/scripts`, é:
   - A. ast_tls_cert
   - B. gen_tls
   - C. gen_ast_tls
   - D. tls_generator
7. Estratégias válidas para prevenir a escuta (marque todas as que se aplicam):
   - A. Implementar detectores de escuta analógica
   - B. Usar o utilitário ARPwatch para detectar ARP spoofing
   - C. Habilitar a detecção de ARP-spoofing nos switches
   - D. Usar SRTP
8. O Asterisk suporta autenticação forte verificando certificados de cliente. (O transporte TLS do PJSIP pode exigir e verificar o certificado do cliente.)
   - A. Verdadeiro
   - B. Falso
9. No Asterisk 22, qual configuração de endpoint PJSIP ativa a criptografia de mídia SRTP usando chaves in-SDP (SDES)?
   - A. `encryption=yes`
   - B. `media_encryption=sdes`
   - C. `srtp=mandatory`
   - D. `transport=tls`
10. No Asterisk 22, o Fail2Ban deve ler eventos de falha de autenticação PJSIP do canal de log dedicado ________ (habilitado em `logger.conf`).
   - A. `console`
   - B. `messages`
   - C. `security`
   - D. `verbose`

**Respostas:** 1 — D · 2 — A · 3 — C · 4 — B · 5 — B · 6 — A · 7 — B, C, D · 8 — A · 9 — B · 10 — C
