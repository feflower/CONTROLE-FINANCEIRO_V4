# Publicar o Controle Financeiro

Guia para deixar o app funcionando **24 horas, com o seu PC desligado**, acessível
do celular de qualquer lugar, **sem endereço público na internet**.

---

## Como isso funciona

```
   Celular  ──┐
              │   rede privada Tailscale (criptografada)
   Notebook ──┼────────────────────────►  servidor na nuvem
              │                            ├─ tailscale  (HTTPS, atende você)
   PC casa  ──┘                            ├─ app        (sem porta pública)
                                           └─ backup     (cópia diária)
```

O ponto central: **o app não abre nenhuma porta no servidor**. Ele compartilha a
pilha de rede do container do Tailscale, e quem atende o celular é o Tailscale,
com HTTPS, dentro da sua rede privada.

Consequências práticas:

- **Não existe endereço público** para alguém descobrir, varrer ou vazar. Isso é
  o que substitui o login que o app não tem.
- Como tem HTTPS de verdade, o **app instala na tela inicial** com todos os
  recursos, inclusive no Android.
- Nem o firewall do servidor precisa liberar a porta 3000.

---

## Passo 1 — Escolher o servidor

O banco é um **arquivo SQLite**. O servidor precisa de disco que sobreviva a
reinícios. Isso descarta plano gratuito da Render, Vercel e Netlify.

| Opção | Custo | Observação |
|---|---|---|
| **Hetzner CX22** | ~€ 3,79/mês | 2 vCPU, 4 GB, 40 GB SSD. Simples e estável. **Recomendado.** |
| **Oracle Cloud Always Free** | grátis | ARM com 4 vCPU e 24 GB. Generoso, mas a Oracle às vezes não tem capacidade na região e pode recuperar instâncias ociosas. |
| **DigitalOcean / Vultr** | ~US$ 5-6/mês | Equivalentes, mais caros. |
| **Raspberry Pi em casa** | ~R$ 400 uma vez | Sem mensalidade, dados ficam na sua casa. Precisa de energia e internet estáveis. |

Qualquer distribuição serve; os comandos abaixo assumem **Ubuntu 24.04**.

O app consome pouco: com 700 lançamentos ele responde o painel em ~4 ms. O
menor servidor de qualquer provedor dá conta.

> **O usuário do SSH muda por provedor.** Hetzner e DigitalOcean entram como
> `root`; as imagens Ubuntu da Oracle e da AWS entram como `ubuntu` e exigem
> `sudo`. Nos comandos abaixo, troque `USUARIO@SEU_SERVIDOR` pelo que vale no
> seu caso.

---

## Passo 1b — Se você escolheu a Oracle Cloud

**Qual serviço:** menu ☰ → **Compute → Instances → Create instance**. É uma
máquina virtual comum. *Não* é Container Instances (não é gratuito), nem OKE
(Kubernetes, desnecessário aqui), nem Autonomous Database (o banco deste app é
um arquivo, não precisa de serviço de banco).

### Criando a instância

1. **Região** — você escolhe na criação da conta e **não pode mudar depois**.
   Para o Brasil, São Paulo (`sa-saopaulo-1`) ou Vinhedo (`sa-vinhedo-1`).
2. *Create instance* → **Name:** `financeiro`
3. Em **Image and shape → Edit**:
   - **Image:** *Change image* → **Canonical Ubuntu** → **24.04**
     (o padrão vem Oracle Linux)
   - **Shape:** *Change shape* → aba **Ampere** → `VM.Standard.A1.Flex` →
     **1 OCPU, 6 GB**
4. **Networking** — deixe criar uma VCN nova e mantenha *Assign a public IPv4
   address* (é por onde vai o primeiro SSH).
5. **Add SSH keys** — cole a sua chave pública, ou escolha *Generate a key pair
   for me* e **baixe a chave privada**: ela aparece uma única vez.
6. **Boot volume** — 50 GB (o padrão) está dentro dos 200 GB gratuitos.
7. *Create*.

Depois, conecte:

```bash
ssh -i sua-chave.key ubuntu@IP_DA_INSTANCIA
```

### As duas armadilhas da Oracle

**1. "Out of capacity" no shape ARM.** É o erro mais comum do free tier. O que
tentar, nessa ordem:

- trocar o **Availability Domain** (AD-1, AD-2, AD-3) na própria tela de criação;
- tentar de novo em outro horário — a capacidade abre e fecha;
- cair para `VM.Standard.E2.1.Micro` (x86, 1 OCPU, **1 GB**), que quase sempre
  tem vaga. Com 1 GB, **crie swap antes de construir a imagem**, senão o
  `npm ci` pode morrer por falta de memória:

```bash
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
```

```bash
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

**2. Recuperação de instância ociosa.** A Oracle pode recuperar instâncias
*Always Free* que passam 7 dias com pouco uso de CPU e rede. Este app fica
ocioso quase todo o tempo, então **o risco é real**. O caminho usual é fazer
upgrade da conta para **Pay As You Go**: os recursos Always Free continuam
gratuitos, e a conta deixa de estar sujeita à recuperação por ociosidade. Em
troca, o cartão fica ativo — se algum dia você criar recurso fora do free tier,
passa a ser cobrado.

> Não consigo verificar a política atual da Oracle daqui. Confirme na página de
> *Always Free* antes de decidir, porque esses termos mudam.

### Uma vantagem inesperada aqui

Na Oracle, o que mais atrapalha quem publica são **três firewalls empilhados**:
Security List da VCN, Network Security Group e o `iptables` que a imagem Ubuntu
já traz configurado. Muita gente perde horas nisso.

**Você não vai precisar tocar em nenhum dos três.** O Tailscale só faz conexão
**de saída**, então nenhuma porta de entrada precisa ser aberta além do SSH, que
já vem liberado. É consequência direta de o app não ter porta pública.

### Antes de seguir

A imagem Ubuntu da Oracle não traz o `unzip`:

```bash
sudo apt update && sudo apt install -y unzip
```

**ARM funciona?** Sim. `node:24-alpine` e `tailscale/tailscale` publicam imagens
arm64, então o build roda direto na Ampere sem emulação.

---

## Passo 2 — Preparar o Tailscale

Antes de tocar no servidor, na sua conta Tailscale (<https://login.tailscale.com>):

1. **Ativar MagicDNS** — em *DNS*, botão **Enable MagicDNS**.
2. **Ativar HTTPS** — na mesma página, **Enable HTTPS Certificates**.
   Sem isto o `serve.json` não consegue emitir o certificado e o app não abre.
3. **Gerar a auth key** — *Settings → Keys → Generate auth key*:
   - marque **Reusable** (para poder subir o container mais de uma vez);
   - deixe **Ephemeral desmarcado** (o servidor precisa continuar na rede);
   - copie a chave — ela aparece **uma única vez**. Formato:
     `tskey-auth-XXXXXXXXXX-XXXXXXXXXXXXXXXXXXXX`.

Instale o Tailscale também **no celular** (App Store / Play Store) e entre com a
mesma conta.

---

## Passo 3 — Instalar o Docker no servidor

Conecte por SSH e rode:

```bash
curl -fsSL https://get.docker.com | sh
```

Se você entrou como `ubuntu` (Oracle, AWS), libere o Docker sem `sudo`:

```bash
sudo usermod -aG docker $USER && newgrp docker
```

Confirme:

```bash
docker --version && docker compose version
```

---

## Passo 4 — Levar o código para o servidor

No **seu PC**, gere o pacote com o script que já existe:

```powershell
powershell -ExecutionPolicy Bypass -File empacotar.ps1
```

Isso cria um `.zip` de ~90 KB na Área de Trabalho, **sem os seus dados** e sem o
`node_modules`. Envie para o servidor:

```bash
scp "$HOME/OneDrive - Grupo Trigo/Área de Trabalho/controle-financeiro-*.zip" USUARIO@SEU_SERVIDOR:/tmp/
```

No servidor:

```bash
sudo mkdir -p /opt/controle-financeiro && sudo chown $USER /opt/controle-financeiro
```

```bash
unzip /tmp/controle-financeiro-*.zip -d /opt/controle-financeiro && cd /opt/controle-financeiro
```

> Em imagens que entram como `ubuntu`, `/opt` pertence ao root: por isso o
> `chown` antes de descompactar. Em servidores onde você entra como `root`,
> pode pular essa linha.

---

## Passo 5 — Configurar e subir

Crie o `.env` com a auth key:

```bash
cp .env.deploy.example .env && nano .env
```

Cole a chave em `TS_AUTHKEY=` e salve (`Ctrl+O`, `Enter`, `Ctrl+X`).

Suba:

```bash
docker compose up -d --build
```

A primeira vez leva 1-2 minutos (constrói a imagem). Acompanhe:

```bash
docker compose logs -f
```

Você deve ver o Tailscale autenticando e, depois, o banner do app. Confirme que
o servidor entrou na rede:

```bash
docker compose exec tailscale tailscale status
```

---

## Passo 6 — Levar os seus dados atuais

Você já tem lançamentos no PC. Não recomece do zero.

No **seu PC**, gere uma cópia limpa e consistente:

```powershell
npm run backup
```

Envie o arquivo gerado (em `Backups Financeiro`) para o servidor:

```bash
scp "$HOME/OneDrive - Grupo Trigo/Área de Trabalho/Backups Financeiro/financeiro-*.db" USUARIO@SEU_SERVIDOR:/tmp/meu-banco.db
```

No servidor, com o app parado (para não escrever durante a troca):

```bash
cd /opt/controle-financeiro
docker compose stop app backup
docker cp /tmp/meu-banco.db financeiro-app:/data/financeiro.db
docker compose start app backup
```

Confira que os dados chegaram:

```bash
docker compose exec app node --disable-warning=ExperimentalWarning -e "const{db}=require('./src/db');console.log('lançamentos:',db.prepare('SELECT COUNT(*) AS n FROM transactions').get().n)"
```

> **Por que usar o arquivo de backup e não copiar `data/financeiro.db` direto:**
> o SQLite mantém gravações recentes num arquivo `.db-wal` ao lado. Copiar só o
> `.db` pode chegar sem os últimos lançamentos — ou corrompido. O `npm run
> backup` usa `VACUUM INTO`, que produz uma cópia íntegra.

---

## Passo 7 — Abrir no celular

1. No celular, abra o app do **Tailscale** e confirme que ele está conectado.
2. No navegador, acesse:

```
https://financeiro.SUA-TAILNET.ts.net
```

O nome exato aparece no admin do Tailscale, na lista de máquinas.

3. Instale na tela inicial:
   - **Android (Chrome):** menu **⋮** → **Adicionar à tela inicial**
   - **iPhone (Safari):** **Compartilhar** → **Adicionar à Tela de Início**

Como aqui existe HTTPS de verdade, a instalação funciona completa nos dois — o
app abre em tela cheia, sem barra de navegador.

---

## Passo 8 — Fechar o servidor (opcional)

O app já não tem porta pública. O que ainda fica aberto é o SSH, e reduzir isso
é um ganho pequeno com risco real de se trancar fora. Leia antes de rodar.

### Na Oracle: NÃO habilite o ufw

A imagem Ubuntu da Oracle **já vem com regras `iptables`** configuradas, e
habilitar o `ufw` por cima costuma derrubar o SSH e deixar você sem acesso — a
instância continua rodando, inacessível. É um dos jeitos mais comuns de perder
uma VM da Oracle.

Na Oracle, se quiser restringir o SSH, faça pela **Security List da VCN** no
console (que continua acessível pelo navegador mesmo se você errar): limite a
porta 22 ao seu IP, em vez de `0.0.0.0/0`.

### Em Hetzner, DigitalOcean e afins

Aí o `ufw` é o caminho normal:

```bash
ufw default deny incoming
```

```bash
ufw default allow outgoing
```

```bash
ufw allow 22/tcp
```

```bash
ufw allow in on tailscale0
```

```bash
ufw --force enable
```

> **Opcional e arriscado:** dá para remover `ufw allow 22/tcp` e acessar SSH
> apenas pela rede Tailscale. Só faça isso **depois** de confirmar, numa segunda
> janela de terminal, que você consegue entrar pelo endereço Tailscale. Senão
> você se tranca fora do servidor.

---

## Manutenção

**Atualizar o app** depois de mexer no código no PC: gere o zip, envie, e no
servidor:

```bash
cd /opt/controle-financeiro && docker compose up -d --build
```

O volume `dados` não é tocado — seus lançamentos continuam.

**Backups.** O container `backup` já grava em `/opt/controle-financeiro/backups`
a cada 24 h e mantém os 30 mais recentes. Traga uma cópia para o PC de vez em
quando:

```bash
scp USUARIO@SEU_SERVIDOR:/opt/controle-financeiro/backups/*.db .
```

Backup fora do servidor é o único que protege contra o servidor sumir.

**Restaurar** um backup: mesmo procedimento do Passo 6.

**Ver o que está rodando:**

```bash
docker compose ps && docker compose logs --tail=50 app
```

---

## Se algo não funcionar

| Sintoma | Causa provável |
|---|---|
| O endereço `.ts.net` não abre | MagicDNS ou HTTPS Certificates não estão ativos no admin do Tailscale |
| `TS_AUTHKEY` recusada | A chave expirou (validade padrão 90 dias) ou não é *reusable* |
| Container do Tailscale reinicia em laço | Falta `/dev/net/tun` — alguns provedores exigem `TS_USERSPACE: "true"` |
| App responde, mas sem dados | O volume `dados` não foi montado, ou o banco não foi copiado (Passo 6) |
| Lançamentos desaparecem a cada deploy | Falta o volume persistente — confira `docker volume ls` |
| Celular não acha o endereço | Tailscale desconectado no celular, ou a máquina não aparece no admin |
| `Out of capacity` ao criar a VM | Shape ARM sem vaga na Oracle: troque o Availability Domain ou use `E2.1.Micro` |
| `npm ci` morre durante o build | Pouca memória (E2.1.Micro de 1 GB): crie o swap do Passo 1b |
| Perdi o SSH depois de mexer no firewall | `ufw` habilitado sobre o `iptables` da Oracle. Recupere pelo *Cloud Shell* ou pela console serial no console da Oracle |
| A instância desapareceu | Recuperação por ociosidade do Always Free (ver Passo 1b) |

---

## O que eu não pude testar

Este guia foi escrito e revisado, mas **não executado de ponta a ponta**: não há
Docker nesta máquina, nem servidor, nem sua conta Tailscale. O que **foi**
verificado:

- o `docker-compose.yml` é YAML válido, e o serviço `app` realmente não publica
  porta nenhuma (`ports` ausente, `network_mode: service:tailscale`);
- o `deploy/serve.json` é JSON válido no formato que o `TS_SERVE_CONFIG` espera;
- o comando do `HEALTHCHECK` do Dockerfile retorna 0 contra o app rodando;
- `npm ci --omit=dev` instala as 70 dependências com o `package-lock.json` atual;
- o app funciona com `DB_PATH` apontando para outro diretório, como faz no
  container, criando o banco e as 13 categorias padrão.

O que pode precisar de ajuste na primeira execução real: as permissões do
`/dev/net/tun` no seu provedor e o nome exato da sua tailnet.
