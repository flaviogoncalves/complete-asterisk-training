# Registros de Detalhes de Chamadas (CDR) do Asterisk

O Asterisk, assim como outras plataformas de telefonia, permite a tarifação de chamadas telefônicas. Diversos programas no mercado podem importar os registros gerados por PBXs. Esses registros são usados para verificar o valor correto da fatura e estatísticas, entre outras coisas.

## Objetivos

Ao final deste capítulo, o leitor deverá ser capaz de:

- Descrever onde e em que formato os registros são gerados
- Gerar registros usando ODBC (Open Database Connectivity)
- Implementar um esquema de autenticação integrado com faturamento

## Formato de CDR do Asterisk

O Asterisk gera um registro detalhado de chamadas (CDR) para cada chamada. Esses registros são armazenados, por padrão, em um arquivo de texto no formato de valores separados por vírgula (CSV) em /var/log/asterisk/cdr-csv. O arquivo é organizado nos seguintes campos:

| Campo | Descrição | Tipo |
|-------|-------------|------|
| Accountcode | Número da conta a ser utilizado | String |
| Src | Número do identificador de chamadas (Caller ID) | String |
| Dst | extension de destino | String |
| Dcontext | context de destino | String |
| Clid | Caller ID com texto | String |
| Channel | Canal utilizado | String |
| Dstchannel | Canal de destino | String |
| Lastapp | Última aplicação | String |
| Lastdata | Dados da última aplicação | String |
| Start | Início da chamada | Data/Hora |
| Answer | Atendimento da chamada | Data/Hora |
| End | Fim da chamada | Data/Hora |
| Duration | Tempo, da discagem até o desligamento | Inteiro (segundos) |
| Billsec | Tempo, do atendimento até o desligamento | Inteiro (segundos) |
| Disposition | O que aconteceu com a chamada (ANSWERED, NO ANSWER, BUSY, FAILED, CONGESTION) | String |
| Amaflags | Flags (DEFAULT, OMIT, BILLING, DOCUMENTATION) | String |
| Userfield | Campo definido pelo usuário | String |

Exemplo de um arquivo CSV. Cada linha é um registro; os campos aparecem na mesma ordem da tabela acima (`accountcode` primeiro, `amaflags` por último):

```text
# accountcode,src,dst,dcontext,clid,channel,dstchannel,lastapp,lastdata,
#   start,answer,end,duration,billsec,disposition,amaflags
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-5f30","PJSIP/8584-9153","Dial","PJSIP/8584,30,tT","2006-03-27 16:05:00","2006-03-27 16:05:00","2006-03-27 16:05:00","0","0","ANSWERED","DOCUMENTATION"
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-96f5","PJSIP/8584-3312","Dial","PJSIP/8584,30,tT","2006-03-27 16:16:00","2006-03-27 16:16:00","2006-03-27 16:16:00","0","0","ANSWERED","BILLING"
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-74ac","PJSIP/8584-297b","Dial","PJSIP/8584,30,tT","2006-03-27 16:22:00","2006-03-27 16:22:00","2006-03-27 16:22:00","0","0","ANSWERED","BILLING"
"1234","4830258576","2012348584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-2c5d","PJSIP/8584-9870","Dial","PJSIP/8584,30,tT","2006-03-27 16:37:00","2006-03-27 16:37:00","2006-03-27 16:37:00","0","0","ANSWERED","BILLING"
"1234","4830258584","2012348576","default","""Luis Sample"" <4830258584>","PJSIP/8584-03fd","PJSIP/8576-645c","Dial","PJSIP/8576,30,tT","2006-03-27 16:37:00","2006-03-27 16:37:00","2006-03-27 16:37:00","0","0","ANSWERED","BILLING"
```

## Códigos de conta e contabilização automática de mensagens

Você pode especificar códigos de conta e flags ama em cada canal. Geralmente, isso é feito no arquivo de configuração do canal (por exemplo, chan_dahdi.conf, pjsip.conf). O parâmetro amaflags define o que fazer com o registro de CDR. Os valores possíveis para amaflag são:

- Default
- Omit
- Billing
- Documentation

De forma semelhante à maneira como um registro pode ser marcado para faturamento ou documentação, um código de conta pode ser definido em cada registro. O código de conta é uma string de formato livre (a opção de endpoint `accountcode` aceita qualquer String, e o registro de CDR o armazena em um campo de 80 caracteres) geralmente usada para atribuir um registro a um departamento ou unidade de negócios. Exemplo: seção de endpoint no pjsip.conf

```
[8576]
type=endpoint
accountcode=Support
```

A flag AMA não é uma opção de endpoint `pjsip.conf` no Asterisk 22; defina-a por chamada a partir do dialplan com a função `CHANNEL` (por exemplo, `Set(CHANNEL(amaflags)=billing)`), ou com `Set(CDR(amaflags)=billing)`.

## Alterando o formato CSV e/ou CDR

Você pode alterar o formato CSV modificando o arquivo cdr_custom.conf.

```
;
; Mappings for custom config file
;
[mappings]
Master.csv =>
"${CDR(clid)}","${CDR(src)}","${CDR(dst)}","${CDR(dcontext)}","${CDR(channel)}"
,"${CDR(dstchannel)}","${CDR(lastapp)}","${CDR(lastdata)}","${CDR(start)}","${C
DR(answer)}","${CDR(end)}","${CDR(duration)}","${CDR(billsec)}","${CDR(disposit
ion)}","${CDR(amaflags)}","${CDR(accountcode)}","${CDR(uniqueid)}","${CDR(userf
ield)}"
```

Você pode alterar o formato CDR no arquivo cdr_custom.conf.

## Armazenamento de CDR

O armazenamento de CDR pode ser realizado de várias maneiras. A forma mais importante é através de arquivos de texto CSV, que podem ser facilmente importados para planilhas. Para pequenas empresas, isso geralmente é suficiente. Alguns softwares de faturamento aceitam arquivos CSV por padrão. No entanto, armazenar CDRs em um banco de dados é muito melhor e mais seguro. O Asterisk suporta diversos tipos de bancos de dados. Existem algumas interfaces gráficas para faturamento no mercado. Com tantos drivers, qual escolher?

### Drivers de armazenamento disponíveis

- cdr_csv – Arquivos de texto com valores separados por vírgula
- cdr_custom – Arquivos de texto personalizáveis com valores separados por vírgula
- cdr_adaptive_odbc – Backend ODBC adaptativo (preferencial para armazenamento em banco de dados)
- cdr_odbc – Bancos de dados suportados por unixODBC (legado; cdr_adaptive_odbc é preferencial)
- cdr_pgsql – Bancos de dados Postgres
- cdr_tds (cdr_freetds) – Bancos de dados Sybase e MSSQL via FreeTDS
- cdr_manager – CDR para a Manager Interface
- cdr_radius – Interface RADIUS para CDR
- cdr_sqlite3_custom – Módulo de CDR personalizado para SQLite3

O módulo `cdr_addon_mysql` (cdr_mysql) que guias mais antigos recomendavam foi removido no Asterisk 19, portanto, não existe um driver de CDR MySQL nativo no Asterisk 22. Para gravar CDRs no MySQL/MariaDB, utilize o `cdr_adaptive_odbc` em conjunto com um driver ODBC para MySQL — a abordagem utilizada neste capítulo.

A gravação de CDR é feita para todos os módulos ativos carregados no arquivo /etc/asterisk/modules.conf. Se o parâmetro autoload=yes estiver definido, todos os módulos serão carregados. Para verificar quais cdr_drivers estão carregados atualmente no sistema, utilize o comando abaixo:

```
asterisk*CLI> module show like cdr_
Module                 Description                              Use Count  Status
Support Level
cdr_adaptive_odbc.so   Adaptive ODBC CDR backend                0          Running
core
cdr_csv.so             Comma Separated Values CDR Backend       0          Running
extended
cdr_custom.so          Customizable Comma Separated Values CDR  0          Running
core
cdr_manager.so         Asterisk Manager Interface CDR Backend   0          Running
core
cdr_odbc.so            ODBC CDR Backend                         0          Running
extended
cdr_sqlite3_custom.so  SQLite3 Custom CDR Module                0          Not Running
extended
6 modules loaded
```

Se você visualizar a captura de tela acima, pelo menos cdr_adaptive_odbc, cdr_csv, cdr_custom, cdr_manager, cdr_odbc e cdr_sqlite3_custom estarão em execução. Nos últimos anos, após alguns Astricons, ficou claro para mim que a equipe do Asterisk estava priorizando o ODBC. É o único driver que suporta pool de conexões. O pool de conexões é uma grande vantagem em termos de desempenho, pois você não precisa abrir uma nova conexão para cada operação. Este capítulo foi escrito anteriormente utilizando cdr_mysql. Mudei para o cdr_adaptive_odbc nesta edição, mesmo sabendo que é um pouco mais complexo de configurar. A escolha pelo cdr_adaptive_odbc também nos permite personalizar o CDR. Você pode simplesmente definir uma nova variável de CDR no dialplan e adicionar a coluna correspondente ao banco de dados. Por exemplo, para registrar o jitter de áudio:

```
Set(CDR(jitter)=${RTPAUDIOQOSJITTER})
```

### Armazenamento em CSV

Como dissemos anteriormente, por padrão, o Asterisk envia todos os CDRs para um arquivo de texto CSV usando o módulo cdr_csv.so. Se você não conseguir visualizar os arquivos em /var/log/asterisk/cdr-csv, verifique se o módulo está sendo carregado usando o comando CLI module show. Se não estiver carregado, verifique o modules.conf. Neste capítulo, enviaremos os CDRs para o cdr_csv como um backup.

### Configurando o arquivo modules.conf

Para carregar apenas os módulos apropriados, utilize as linhas abaixo no arquivo modules.conf

```
noload => cdr_custom.so
noload => cdr_odbc.so
noload => cdr_manager.so
noload => cdr_sqlite3_custom.so
```

Agora temos apenas o cdr_csv e o cdr_adaptive_odbc carregados.

## Instalando e configurando o ODBC no Ubuntu 22.04

Eu sempre lamento publicar instruções detalhadas em livros. Elas mudam às vezes antes mesmo de o livro ser publicado. Versões mudam, módulos mudam, então tente adaptar os comandos aqui para a sua própria situação. Na maioria das vezes, pequenas alterações são suficientes para reproduzir a instalação. Preste atenção nos passos, pois até usuários experientes de Linux acharão difícil instalar os drivers ODBC.

Passo 1 - Instale os pacotes necessários:

```
apt-get install mysql-server unixodbc unixodbc-dev libltdl-dev libtool
```

Passo 2 - Crie um banco de dados e um usuário:

```
mysql -u root -p
```

(Use a senha definida quando você criou o servidor mysql) Digite estes comandos na linha de comando do mysql

```
CREATE USER 'astdb'@'%' IDENTIFIED BY 'supersecret';
CREATE DATABASE cdr;
GRANT ALL PRIVILEGES ON cdr.* TO 'astdb'@'%';
FLUSH PRIVILEGES;
EXIT
```

Passo 3 - Crie o banco de dados

```
cd /usr/src/asterisk-22.*/contrib/scripts/realtime/mysql
mysql -u root -p astdb <mysql_cdr.sql
```

Passo 4: Baixe o conector ODBC do MySQL da Oracle. Verifique seu sistema operacional usando: `lsb_release -a`. Para Ubuntu 22.04 (x86_64), visite https://dev.mysql.com/downloads/connector/odbc/ e escolha a versão 8.x ou 9.x atual para Ubuntu 22.04. O nome exato do arquivo e o número da versão mudam com o tempo, então defina `VER` (abaixo) para o nome que for a compilação glibc do Linux atual.

```
cd /usr/src
# Pick the current Linux (glibc) build for your platform from
# https://dev.mysql.com/downloads/connector/odbc/ and set VER to its name:
VER=mysql-connector-odbc-9.0.0-linux-glibc2.28-x86-64bit
wget https://dev.mysql.com/get/Downloads/Connector-ODBC/9.0/$VER.tar.gz
tar -xzvf $VER.tar.gz
```

Passo 5: Instale o driver ODBC

```
cd /usr/src/$VER
cp bin/* /usr/local/bin
cp lib/* /usr/local/lib
myodbc-installer -a -d -n "MySQL" -t "Driver=/usr/local/lib/libmyodbc9w.so"
```

Passo 6 - Configure o conector ODBC editando o arquivo /etc/odbc.ini para criar o DSN (Data Source Name)

```
[astconn]
Description = MySQL connector for astdb database
Driver = /usr/local/lib/libmyodbc9w.so
Database = astdb
Server = localhost
Port = 3306
```

Passo 7: Teste o acesso ao driver usando o iSQL. O iSQL é um utilitário de linha de comando para conectar ao banco de dados via unixodbc.

```
isql -v astconn astdb supersecret
>show tables
```

Por favor, não prossiga com a configuração do Asterisk se você não conseguir ver o resultado do comando isql.

### Configurando o ODBC no Asterisk

Antes de configurar o cdr_adaptive_odbc, você deve primeiro configurar o arquivo de recursos ODBC.

Passo 1 - Conecte o Asterisk ao ODBC. Edite o arquivo res_odbc.conf:

```
[cdr]
enabled => yes
dsn => astconn
username => astdb
password => supersecret
pre-connect => yes
```

Passo 2 – Reinicie o Asterisk e teste usando

```
asterisk*CLI> odbc show
```

A saída é mostrada abaixo.

```
asterisk*CLI> odbc show
ODBC DSN Settings
-----------------
Name:   cdr
DSN:    astconn
  Number of active connections: 1 (out of 20)
```

Passo 3 – Configure o driver ODBC adaptativo em /etc/asterisk/cdr_adaptive_odbc.conf

```
[cdr]
connection=cdr
table=cdr
```

Aqui `connection` aponta para a seção de conexão `[cdr]` definida em `res_odbc.conf`, e `table` é a tabela do banco de dados onde os CDRs são gravados.

Passo 4 – Recarregue o módulo cdr_adaptive_odbc.so:

```
asterisk*CLI> reload cdr_adaptive_odbc
```

Passo 5 – Faça algumas chamadas e verifique o banco de dados em busca de novos registros. Para verificar o banco de dados:

```
mysql -u root -p
>use astdb
>select * from cdr;
```

## Aplicações e funções

Diversas aplicações estão relacionadas ao faturamento.

### CDR(accountcode)

Define um código de conta antes de chamar outra aplicação dial(); por exemplo: Formato:

```
Set(CDR(accountcode)=account)
```

O código da conta pode ser verificado usando a variável de canal ${CDR(accountcode)}

### CDR(amaflags)

Define uma flag para fins de faturamento. As opções são default, omit, documentation e billing.

```
Set(CDR(amaflags)=amaflags)
```

### Set(CDR_PROP(disable)=1)

Desativa a gravação de CDR para o canal atual, de modo que nenhum CDR seja gravado no arquivo ou banco de dados. Definir novamente para `0` reativa a gravação.

```
Set(CDR_PROP(disable)=1)
```

A aplicação `NoCDR()` que edições anteriores usavam para isso foi removida no Asterisk 21; no Asterisk 22, você desativa o CDR de um canal com `Set(CDR_PROP(disable)=1)` em vez disso.

### ResetCDR()

Redefine o Call Data Record: o tempo de `start` (e, se atendida, o tempo de `answer`) é definido para o horário atual e todas as variáveis de CDR são apagadas. Se a opção `v` for definida, as variáveis de CDR são preservadas durante a redefinição.

### Set(CDR(userfield)=Value)

Este comando define um campo de usuário no CDR. Ao usar `cdr_adaptive_odbc`, o campo de usuário é armazenado automaticamente se uma coluna `userfield` existir na tabela de CDR — sem necessidade de recompilação do código-fonte. Para arquivos de texto CSV, você precisa editar o código-fonte (cdr_csv.c) e recompilar o Asterisk se quiser usar campos de usuário.

Edições anteriores armazenavam CDRs no MySQL com o módulo `cdr_addon_mysql` (`cdr_mysql.conf`). Esse módulo foi removido no Asterisk 19, portanto, não está disponível no Asterisk 22. O caminho suportado agora é `cdr_adaptive_odbc` com um driver ODBC para MySQL, que armazena o campo de usuário — e qualquer outra coluna personalizada — nativamente através de seu mapeamento adaptativo de colunas.

### Adicionando ao campo de usuário

Edições anteriores usavam a aplicação `AppendCDRUserField()` para adicionar dados ao campo de usuário do CDR. Essa aplicação foi removida do Asterisk; no Asterisk 22, você adiciona ao campo de usuário lendo e redefinindo-o com a função `CDR`, por exemplo `Set(CDR(userfield)=${CDR(userfield)}extra)`.

![13-call-detail-records figura 1](../images/13-call-detail-records-img01.png)

## Autenticação de usuário

Algumas empresas cobram as chamadas de seus funcionários. No Asterisk, você pode definir um esquema de autenticação que permite cobrar o usuário autenticado no CDR. Essa autenticação pode ser feita usando uma senha passada como parâmetro para a aplicação Authenticate — um arquivo de senha, indicado por uma / (barra) antes do parâmetro, ou uma chave do banco de dados do Asterisk (usando a opção `d`). Formato:

```
Authenticate(password[,options[,maxdigits[,prompt]]])
Authenticate(/passwdfile[,options])
```

Opções:

- a – Define o account code do canal para a senha inserida.
- d – Interpreta o caminho fornecido como uma chave do banco de dados do Asterisk em vez de um arquivo literal.
- m – Interpreta o caminho como um arquivo de linhas `accountcode:passwordhash`.
- r – Remove a chave do banco de dados após a autenticação bem-sucedida (válido apenas com `d`).

Se o chamador falhar em todas as três tentativas, o canal é encerrado; a execução do dialplan não continua, portanto, trate o caminho de falha na linha após `Authenticate()`. Exemplo (Chamadas Internacionais):

```
exten=_9011.,1,Authenticate(/password,d)
 same=>n,Dial(DAHDI/g1/${EXTEN:1},20,tT)
 same=>n,Hangup()
```

A antiga opção `j` (pular para a prioridade n+101 em caso de falha) e a convenção de prioridade `+101` foram removidas do Asterisk há muito tempo; uma falha no `Authenticate()` simplesmente encerra a chamada.

Para inserir a senha em uma chave do banco de dados a partir do console:

```
asterisk*CLI> database put senha 123456 1
```

## Usando senhas do voicemail

Esta aplicação faz o mesmo que o authenticate, mas utiliza o arquivo de configuração do voicemail para a senha.

```
VMAuthenticate([mailbox][@context][,options])
```

Se uma mailbox for especificada, apenas a senha daquela mailbox será considerada válida. Se a mailbox não for especificada, a variável de canal `${AUTH_MAILBOX}` será definida com a mailbox autenticada. Se a opção `s` estiver definida, os prompts iniciais são ignorados. Exemplo (Chamadas Internacionais):

```
exten=_9011.,1,VMAuthenticate(${CALLERID(num)}@local,s)
 same=>n,Dial(DAHDI/g1/${EXTEN:1},20,tT)
 same=>n,Hangup()
```

## Channel Event Logging (CEL)

Registros de CDR fornecem uma linha de resumo por chamada. Para um rastreamento de eventos mais detalhado — como transições de estado de canal individuais, eventos de entrada/saída de bridge e partes de transferências assistidas — o Asterisk 22 inclui o **Channel Event Logging (CEL)**, configurado via `/etc/asterisk/cel.conf` e armazenado através de backends como `cel_odbc` ou `cel_custom`.

O CEL complementa o CDR em vez de substituí-lo: o CDR permanece o padrão para resumos de faturamento, enquanto o CEL fornece dados granulares por evento, úteis para detecção de fraudes, monitoramento de qualidade e relatórios avançados.

O padrão de configuração `cel.conf` espelha o `cdr.conf`: você habilita os tipos de evento que deseja na seção `[general]` do `cel.conf` e, em seguida, configura cada backend de armazenamento em seu próprio arquivo — `cel_custom.conf` para CSV, `cel_odbc.conf` para um banco de dados ODBC (a mesma conexão `res_odbc.conf` usada para CDRs). Você pode confirmar se o CEL está ativo com `cel show status` na CLI.

## Resumo

Neste capítulo, aprendemos como implementar o registro de CDR em arquivos de texto e em um banco de dados MySQL. Também aprendemos como definir amaflags e account codes. Ao final do capítulo, aprendemos como utilizar um esquema de autenticação integrado com CDR e faturamento.

## Quiz

1. Por padrão, o Asterisk grava o CDR no diretório /var/log/asterisk/cdr-csv.
   - A. Falso
   - B. Verdadeiro
2. O Asterisk pode gravar CDRs em (selecione todas as opções aplicáveis):
   - A. MySQL
   - B. Native Oracle
   - C. Microsoft SQL Server
   - D. Arquivos de texto CSV
   - E. Bancos de dados suportados por unixODBC
3. O Asterisk gera um CDR para apenas um tipo de armazenamento por vez.
   - A. Falso
   - B. Verdadeiro
4. Quais amaflags do Asterisk estão disponíveis?
   - A. DEFAULT
   - B. OMIT
   - C. TAX
   - D. RATE
   - E. BILLING
   - F. DOCUMENTATION
5. Para associar um departamento a um CDR, você usa o comando ___ e o account code pode ser lido com a variável de canal ___.
6. A diferença entre `Set(CDR_PROP(disable)=1)` e `ResetCDR()` é que desabilitar o CDR impede que qualquer registro seja gravado, enquanto `ResetCDR()` redefine (zera) o registro atual. (A aplicação `NoCDR()` que anteriormente desabilitava CDRs foi removida no Asterisk 21.)
   - A. Falso
   - B. Verdadeiro
7. Para usar um campo definido pelo usuário com o módulo `cdr_csv.so`, você deve editar o código-fonte e recompilar o Asterisk.
   - A. Falso
   - B. Verdadeiro
8. Os três métodos de autenticação disponíveis para a aplicação Authenticate() são:
   - A. Senha
   - B. Arquivo de senhas
   - C. Asterisk DB (dbput e dbget)
   - D. Voicemail
9. As senhas de voicemail são especificadas em uma seção separada do `voicemail.conf` e não são as mesmas dos usuários de voicemail.
   - A. Falso
   - B. Verdadeiro
10. O Channel Event Logging (CEL) substitui o CDR no Asterisk 22 — uma vez que o CEL é habilitado, os resumos de faturamento do CDR não são mais produzidos.
    - A. Falso
    - B. Verdadeiro

**Respostas:** 1 — B · 2 — A, B, C, D, E · 3 — A · 4 — A, B, E, F · 5 — `Set(CDR(accountcode)=...)`; `${CDR(accountcode)}` · 6 — B · 7 — A · 8 — A, B, C · 9 — B · 10 — A
