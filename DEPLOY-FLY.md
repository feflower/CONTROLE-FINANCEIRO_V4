# Publicar no Fly.io

Caminho mais curto para o app ficar no ar 24 horas, com o seu PC desligado,
**sem reescrever nada**. Cinco comandos.

O Fly.io aceita o container como ele é: SQLite, lançamentos fixos, backup — tudo
continua funcionando. É o que a Vercel não consegue fazer.

---

## Por que a Vercel não serviu

Vale entender para não tentar de novo:

| Bloqueio | Detalhe |
|---|---|
| **Sem disco** | O banco é um arquivo. Na Vercel o sistema de arquivos é somente-leitura, e `/tmp` é apagado a cada requisição. Cada lançamento desapareceria em segundos. |
| **Serverless** | O app é um servidor com processo vivo (`app.listen`). Na Vercel cada requisição sobe uma função nova e morre. |
| **URL pública** | Proteção por senha na Vercel é recurso do plano Pro. |

O Fly.io resolve os três: container com volume persistente, processo vivo e a
senha embutida no próprio app.

---

## Antes de começar

Você vai precisar de **cartão de crédito** para verificar a conta. O uso deste
app fica dentro ou perto da faixa mínima: uma máquina `shared-cpu-1x` de 512 MB
que hiberna quando ninguém está usando, mais 1 GB de volume. Na prática, alguns
centavos a poucos dólares por mês. **Confirme os preços atuais no site** — não
consigo verificar daqui e eles mudam.

---

## Passo 1 — Instalar o flyctl

No PowerShell do seu PC:

```powershell
iwr https://fly.io/install.ps1 -useb | iex
```

Feche e reabra o PowerShell, depois entre na conta (abre o navegador):

```powershell
fly auth login
```

---

## Passo 2 — Escolher o nome do app

Abra `fly.toml` e troque a primeira linha:

```toml
app = "controle-financeiro"
```

O nome é global no Fly, então provavelmente já está tomado. Use algo seu, tipo
`financeiro-felipe-2026`. Ele define a URL: `https://SEU-NOME.fly.dev`.

---

## Passo 3 — Criar o app e o volume

Na pasta do projeto (`C:\apps\controle-financeiro`):

```powershell
fly launch --no-deploy --copy-config --name SEU-NOME --region gru
```

`--no-deploy` é de propósito: **o volume tem que existir antes do primeiro
deploy**, senão a máquina sobe sem disco e o banco nasce num lugar que será
apagado.

```powershell
fly volumes create dados --size 1 --region gru --yes
```

`gru` é São Paulo. `fly platform regions` lista as outras.

---

## Passo 4 — Definir a senha

**Este passo não é opcional.** A URL `.fly.dev` é pública: sem senha, qualquer
pessoa que descobrir o endereço vê e edita seus lançamentos.

```powershell
fly secrets set SENHA_ACESSO="uma-senha-longa-que-so-voce-sabe"
```

Use algo longo. Você digita uma vez por aparelho e o navegador guarda por 60
dias.

Como funciona: com essa variável definida, a API passa a exigir a senha e o app
mostra uma tela pedindo. **No seu PC, sem a variável, nada muda** — continua
abrindo direto.

Para mudar a senha depois, rode o mesmo comando com outro valor. Isso invalida
todos os aparelhos autorizados de uma vez, porque o token é assinado com a
própria senha.

---

## Passo 5 — Conferir a pasta antes de subir

Este passo existe porque um deploy já falhou aqui. O `fly launch` acrescenta
linhas ao `.dockerignore`, e uma delas pode excluir um diretório de que a
imagem precisa. O build então morre com `Cannot find module`, no meio do log,
longe da causa.

Rode na pasta do projeto:

```powershell
npm run verificar
```

Ele confere os 28 arquivos essenciais, os ícones, o `scripts/`, a sintaxe do
código e — principalmente — se alguma regra do `.dockerignore` está excluindo
algo necessário. Se acusar problema, ele diz qual linha apagar.

---

## Passo 6 — Subir

```powershell
fly deploy
```

O primeiro build leva 2-3 minutos. Depois:

```powershell
fly status
```

```powershell
fly logs
```

Abra `https://SEU-NOME.fly.dev`, informe a senha, e está no ar.

---

## Passo 7 — Levar os seus dados

Você já tem lançamentos no PC. Gere uma cópia consistente:

```powershell
npm run backup
```

Suba o arquivo gerado (está em `Backups Financeiro`):

```powershell
fly ssh sftp shell
```

Dentro do prompt do sftp:

```
put "C:\Users\felipe.floriano\OneDrive - Grupo Trigo\Área de Trabalho\Backups Financeiro\financeiro-XXXX.db" /data/novo.db
```

(troque `XXXX` pelo nome real do arquivo, e digite `quit` para sair)

Agora troque o banco, com o app parado para não escrever no meio:

```powershell
fly ssh console -C "sh -c 'mv /data/novo.db /data/financeiro.db && rm -f /data/financeiro.db-wal /data/financeiro.db-shm'"
```

```powershell
fly apps restart SEU-NOME
```

Confira:

```powershell
fly ssh console -C "node --disable-warning=ExperimentalWarning -e \"const{db}=require('/app/src/db');console.log('lançamentos:',db.prepare('SELECT COUNT(*) AS n FROM transactions').get().n)\""
```

> **Por que usar o arquivo de backup e não copiar `data/financeiro.db` direto:**
> o SQLite mantém gravações recentes num `.db-wal` ao lado. Copiar só o `.db`
> pode chegar sem os últimos lançamentos, ou corrompido. O `npm run backup` usa
> `VACUUM INTO`, que produz uma cópia íntegra — e por isso também apagamos o
> `-wal` antigo ao trocar.

---

## Passo 8 — Instalar no celular

A URL do Fly já vem com HTTPS, então a instalação funciona completa:

- **Android (Chrome):** menu **⋮** → **Adicionar à tela inicial**
- **iPhone (Safari):** **Compartilhar** → **Adicionar à Tela de Início**

Na primeira abertura ele pede a senha. Depois disso, abre direto por 60 dias.

---

## Manutenção

**Atualizar** depois de mexer no código: `fly deploy` na pasta do projeto. O
volume não é tocado.

**Backup para fora do Fly** — o mais importante, porque backup dentro do mesmo
servidor não protege contra o servidor sumir:

```powershell
fly ssh console -C "node --disable-warning=ExperimentalWarning /app/scripts/backup.js /data/backups"
```

```powershell
fly ssh sftp get /data/backups/financeiro-XXXX.db
```

**Ver o que está gastando:** `fly dashboard` abre a página de uso.

**Parar de pagar:** `fly apps destroy SEU-NOME` e `fly volumes destroy`. Baixe
um backup antes.

---

## Detalhes que estão no `fly.toml` e importam

**Uma máquina só, sem escala automática.** SQLite é um arquivo: duas máquinas
escrevendo no mesmo volume corrompem o banco. Por isso `min_machines_running`
fica em 0 e não há réplica.

**`auto_stop_machines = "suspend"`.** A máquina hiberna quando ninguém está
usando e volta em cerca de um segundo — em vez de reiniciar do zero. Isso é o
que mantém o custo baixo sem tornar o app lento de abrir.

**`force_https = true`.** Além de proteger o tráfego, é o que faz o app instalar
na tela inicial com todos os recursos.

---

## Se algo não funcionar

| Sintoma | Causa provável |
|---|---|
| `Name has already been taken` | O nome do app é global. Escolha outro em `fly.toml` e no `--name`. |
| Lançamentos desaparecem a cada deploy | O volume não foi criado, ou o `[[mounts]]` não bate com o nome. `fly volumes list` mostra. |
| `could not find a deployable app` | Você não está na pasta do projeto. |
| `Cannot find module` durante o build | O `.dockerignore` está excluindo um diretório necessário. Rode `npm run verificar` — foi exatamente isso que quebrou o primeiro deploy. |
| A senha não é aceita | O secret não subiu: `fly secrets list` deve mostrar `SENHA_ACESSO`. Depois de definir, é preciso um deploy ou restart. |
| Abre sem pedir senha | `SENHA_ACESSO` não está definida — e a URL está pública. Resolva agora. |
| App demora ~1 s para abrir | Normal: é a máquina saindo da hibernação. |
| `no volumes available` na inicialização | O volume está em outra região. Ele precisa estar na mesma de `primary_region`. |

---

## O que eu não pude testar

Não há Docker nem conta Fly nesta máquina: **não executei nenhum destes
comandos**. O que **foi** verificado:

- a barreira de senha, com 33 testes automatizados: bloqueio de 9 rotas sem
  senha, `/api/health` livre para o healthcheck, cookie HttpOnly e SameSite,
  token forjado recusado, limite de tentativas na 11ª e sair revogando o
  aparelho;
- que **sem** `SENHA_ACESSO` nada muda e o app abre direto, como no seu PC;
- o comando do `HEALTHCHECK` do Dockerfile retorna 0 contra o app rodando;
- `npm ci --omit=dev` instala as dependências com o `package-lock.json` atual;
- o app funciona com `DB_PATH` apontando para outro diretório, como faz em
  `/data`.

O que pode precisar de ajuste na primeira execução real: o nome do app (quase
certamente tomado), a região disponível na sua conta, e a sintaxe exata do
`fly ssh sftp`, que muda entre versões do flyctl.
