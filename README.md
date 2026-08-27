# Controle Financeiro Pessoal

Aplicação web para controle de gastos: lançamentos, limites, alertas automáticos
e um painel analítico com projeção de fechamento do mês.

Uso pessoal: **abre direto, sem login** no seu PC, e com **senha por variável de
ambiente** ao publicar. Tem **lançamentos fixos automáticos** e é **instalável no
celular** (PWA), com tela de entrada rápida desenhada para o polegar.

Interface em português do Brasil, valores em real. Duas dependências: `express` e
`chart.js`. O banco é um arquivo SQLite, via módulo nativo do Node — nada para
compilar.

---

## Índice

- [Rodar no PC](#rodar-no-pc)
- [Usar no celular](#usar-no-celular)
- [Acesso e segurança](#acesso-e-segurança)
- [O que a aplicação faz](#o-que-a-aplicação-faz)
- [Como os números são calculados](#como-os-números-são-calculados)
- [Publicar num servidor](#publicar-num-servidor)
- [Variáveis de ambiente](#variáveis-de-ambiente)
- [Estrutura](#estrutura)
- [API](#api)
- [Backup](#backup)
- [Notas de design](#notas-de-design)

---

## Rodar no PC

**Windows, caminho curto:** dois cliques em **`iniciar.bat`**. Ele confere o
Node, instala as dependências na primeira vez, gera os ícones, sobe o servidor e
abre o navegador.

Pelo terminal:

```bash
npm install
```

```bash
npm start
```

Depois abra <http://localhost:3000>. Abre direto no painel, sem login.

Outros comandos:

| Comando | O que faz |
|---|---|
| `npm run dev` | Recarrega o servidor a cada alteração no código |
| `npm run rede` | Abre para a rede local e mostra o endereço para o celular |
| `npm run backup` | Copia de segurança do banco (funciona com o app aberto) |
| `npm run seed` | Popula com 14 meses de dados de exemplo |
| `npm run icones` | Regera os ícones PNG e o `.ico` do atalho |

### Onde o projeto mora

`C:\apps\controle-financeiro`, **fora do OneDrive** de propósito: o SQLite grava
num arquivo auxiliar `.db-wal` enquanto o app roda, e sincronização no meio de
uma gravação pode gerar conflito de arquivo. A cópia para a nuvem passa a ser
feita de forma controlada por `npm run backup` (veja [Backup](#backup)).

Atalhos na área de trabalho:

| Atalho | O que abre |
|---|---|
| **Controle Financeiro** | Painel no PC **e** acesso pelo celular na mesma rede |
| **Controle Financeiro (so neste PC)** | Painel apenas neste computador |

---

## Usar no celular

### Opção 1 — Na mesma rede Wi-Fi (rápido, sem publicar nada)

1. No PC, dois cliques em **`iniciar-rede.bat`** (ou `npm run rede`).
2. O terminal mostra um endereço tipo `http://192.168.0.15:3000`.
3. No Windows, permita o acesso quando o firewall perguntar — marque
   **Redes privadas**.
4. No celular, no **mesmo Wi-Fi**, abra esse endereço no navegador. Pronto —
   sem login, os mesmos dados.

O PC precisa ficar ligado com a janela aberta. O IP muda quando o roteador
reinicia — rode o comando de novo para ver o atual.

**Limitação real:** por HTTP puro (sem HTTPS) o Android não oferece a instalação
completa do app. O site funciona, mas para o ícone na tela inicial com todos os
recursos você precisa de HTTPS — ou seja, publicar (opção 2).

### Opção 2 — De qualquer lugar (exige publicar com HTTPS)

Depois de publicar (**[DEPLOY-FLY.md](DEPLOY-FLY.md)** é o caminho mais curto),
instale o app na tela inicial:

**Android (Chrome)**
1. Abra o endereço `https://...` no Chrome.
2. Toque no menu **⋮** → **Adicionar à tela inicial** (ou aceite o convite
   "Instalar" que a própria página mostra).
3. Confirme. O ícone aparece na gaveta de apps como qualquer outro.

**iPhone (Safari — tem que ser o Safari)**
1. Abra o endereço `https://...` no **Safari**.
2. Toque em **Compartilhar** (o quadrado com a seta para cima).
3. Role e toque em **Adicionar à Tela de Início** → **Adicionar**.

No Chrome ou Firefox do iPhone essa opção não existe: no iOS, só o Safari
instala atalho como app.

### A tela "Lançar"

É a tela pensada para o celular, no botão **＋** no centro da barra de baixo:

- teclado próprio na página — o teclado do sistema não cobre o botão de salvar;
- categoria em chips roláveis, um toque;
- data em atalhos (Hoje / Ontem / Anteontem) ou calendário;
- descrição opcional e salvar.

O resto da navegação fica na barra inferior: **Painel · Extrato · ＋ · Limites ·
Alertas**. No celular a lista de lançamentos vira cartões (a tabela de seis
colunas viraria rolagem lateral), e os gráficos ficam mais baixos.

### O que funciona sem internet

Instalado como app, ele **abre** offline (a interface fica em cache), mas mostra
um aviso de "sem conexão" e não carrega dados nem grava lançamentos: saldo e
limites vêm do servidor. Valor de dinheiro velho em cache seria pior do que
dizer a verdade.

---

## Acesso e segurança

**No uso local, não há tela de login:** o app abre direto no painel.

**Ao publicar, defina uma senha.** Uma variável de ambiente liga a barreira:

```
SENHA_ACESSO=uma-senha-longa-que-so-voce-sabe
```

Com ela definida, a API passa a exigir a senha e o app mostra uma tela pedindo.
Você digita **uma vez por aparelho** e ele fica autorizado por 60 dias
(`ACESSO_DIAS`). Sem a variável, nada muda — é por isso que o seu PC continua
abrindo direto.

Como funciona: o token do cookie é assinado com HMAC usando a própria senha como
chave, então não há tabela de sessões, não há estado no servidor, e **trocar a
senha invalida todos os aparelhos de uma vez**.

O que ela protege: 10 tentativas erradas por IP em 15 minutos e o acesso é
bloqueado; comparação em tempo constante; cookie `HttpOnly` e `SameSite=Lax`,
com `Secure` quando a conexão é HTTPS. A rota `/api/health` fica livre, para o
healthcheck da hospedagem funcionar.

**Alternativa, se você preferir não digitar senha:** uma barreira externa
(Tailscale, Cloudflare Access, basic auth no proxy). Nesse caso não defina
`SENHA_ACESSO` e suba com `ACESSO_PROTEGIDO=1`, só para silenciar o aviso.

O servidor **avisa no console** quando sobe aberto na rede sem senha e sem
barreira declarada.

O que o app ainda protege por conta própria:

- **CSP restritiva** (`script-src 'self'`, sem inline), `X-Frame-Options: DENY`,
  `nosniff`, `Referrer-Policy: same-origin`.
- Escritas exigem `Content-Type: application/json` — um `<form>` em outro site
  não consegue disparar requisição de escrita entre origens.
- Toda entrada é validada no servidor: valores, datas, meses, ids e limites de
  tamanho. Nada de SQL montado por concatenação.
- Saída escapada no front-end, contra HTML injetado em descrições.

---

## O que a aplicação faz

### Lançamentos

Despesas e receitas com valor, data, categoria, descrição, meio de pagamento e
observação. O campo de valor aceita o formato brasileiro (`1.234,56`), com `R$` e
espaços. Registrar em outro mês leva o painel para aquele mês.

Categorias vêm pré-cadastradas e podem ser criadas, editadas ou removidas.
Remover **preserva** os lançamentos: eles passam a contar como "Sem categoria".

### Lançamentos fixos

Aluguel, assinaturas, plano de saúde: cadastre uma vez em **Orçamentos →
Lançamentos fixos** e o sistema lança todo mês, sozinho.

Duas regras que evitam os erros clássicos desse recurso:

1. **Nada de lançamento no futuro.** Uma conta do dia 25 só entra quando o dia 25
   chegar. Materializar antes inflaria o gasto do mês e faria os alertas de
   estouro dispararem por dinheiro que ainda não saiu. O que falta vencer
   aparece no painel em **"Ainda vai sair este mês"**, como previsão.
2. **Nunca duplica.** A garantia é do banco, não da aplicação: existe um índice
   único por (lançamento fixo, mês). Recarregar a página, abrir em dois
   aparelhos ou clicar duas vezes não gera cópia.

Dia 31 em fevereiro cai no último dia do mês. Pausar interrompe sem apagar
nada. Excluir **preserva o histórico** — foram gastos que aconteceram de
verdade; para apagar também os gerados, use `?apagarDoMes=AAAA-MM`.

### Limites e alertas

Limite global do mês e limites por categoria. Sobre eles rodam onze regras:

| Regra | Severidade |
|---|---|
| Limite global ou de categoria estourado | Crítico |
| Saldo do mês negativo | Crítico |
| Projeção de fechamento acima do limite (com margem) | Atenção |
| Categoria muito acima da média dos 3 meses anteriores | Atenção |
| Ritmo diário acima do sustentável | Atenção |
| Maior gasto dos últimos 12 meses | Atenção |
| Limite acima do percentual de aviso (padrão 80%) | Aviso |
| Concentração excessiva numa única categoria | Aviso |
| Categorias relevantes sem limite definido | Aviso |
| Nenhum limite configurado | Aviso |
| Meta de poupança batida | Positivo |

Todos os limiares são configuráveis em **Ajustes**.

### Painel

Um número herói (saldo do mês), a nota de saúde financeira, seis indicadores, os
alertas prioritários e sete visualizações: ritmo de gasto do mês, composição por
categoria, fluxo de caixa de 12 meses, patrimônio acumulado, taxa de poupança,
calendário de gastos e gasto por dia da semana. Mais os medidores de consumo dos
limites, a lista dos maiores gastos e — quando houver — o que ainda vai vencer
de lançamento fixo no mês.

Cada gráfico tem um botão **Tabela** com os mesmos dados — todo valor é legível
sem depender de cor nem de tooltip.

---

## Como os números são calculados

**Projeção de fechamento.** Este é o ponto onde a maioria dos aplicativos erra.
A projeção linear (média diária × dias do mês) superestima muito, porque aluguel,
condomínio, plano de saúde e assinaturas caem quase todos na primeira quinzena:
no dia 14 você já pagou boa parte do mês, e dobrar esse valor inventa um estouro
que não vai acontecer.

Em vez disso, o sistema mede a **forma real do seu mês** — que fração do gasto
costuma ter acontecido até cada dia — nos últimos 6 meses, e projeta sobre essa
curva. Três detalhes importam:

1. A curva é calculada **por categoria**. "Assinaturas" cobra tudo antes do dia
   15; "Alimentação" se espalha pelo mês. Projetar as duas com o mesmo fator
   inventaria estouros.
2. Usa a **mediana** entre os meses, não a média, para que um mês atípico não
   arraste a curva.
3. Com pouco histórico a curva **encolhe** em direção a uma referência mais
   ampla — a curva da categoria encolhe para a curva do gasto total, e essa
   encolhe para a diagonal linear. Sem histórico, cai na média diária. O
   indicador mostra qual método foi usado.

**Comparações são do mesmo período.** No mês corrente, o delta compara com o
**mesmo intervalo de dias** do mês anterior. Comparar 14 dias de agosto com julho
inteiro produziria uma "queda de 40%" que não existe. A base fica escrita na tela.

**Taxa de poupança.** `(receita − despesa) ÷ receita` do mês.

**Gasto seguro por dia.** Quanto resta do limite dividido pelos dias que faltam.

**Nota de saúde financeira.** Começa em 100 e desconta por taxa de poupança
abaixo da meta, saldo negativo, limites estourados, alertas abertos e categorias
sem limite. Sem movimento no mês, aparece como "Sem dados" em vez de 100.

---

## Publicar num servidor

> **Dois guias, escolha um:**
> - **[DEPLOY-FLY.md](DEPLOY-FLY.md)** — Fly.io em cinco comandos. Mais curto.
> - **[DEPLOY.md](DEPLOY.md)** — servidor próprio (Oracle, Hetzner) atrás do
>   Tailscale. Mais passos, mais privado, sem digitar senha.
>
> Esta seção só explica a arquitetura e as duas armadilhas.

O arranjo pronto no projeto: um servidor na nuvem que **entra na sua rede
Tailscale**. O PC pode ficar desligado, e o app **não abre porta pública
nenhuma** — quem atende o celular é o Tailscale, com HTTPS, dentro da rede
privada. É isso que substitui o login que o app não tem.

Arquivos envolvidos:

| Arquivo | Papel |
|---|---|
| `Dockerfile` | Imagem do app, com healthcheck |
| `fly.toml` | Configuração do Fly.io (volume, região, hibernação) |
| `docker-compose.yml` | App + Tailscale + backup diário (servidor próprio) |
| `deploy/serve.json` | Diz ao Tailscale para servir o app em HTTPS |
| `.env.deploy.example` | Modelo do `.env` com a auth key do Tailscale |

### Armadilha 1: o banco é um arquivo

O SQLite grava em `DB_PATH`. Sem **disco persistente** nesse caminho, todo
lançamento desaparece no próximo deploy. Isso elimina o plano gratuito da
Render, a Vercel e a Netlify. O `docker-compose.yml` já monta um volume em
`/data`.

### Armadilha 2: publicar antes de proteger

Se a proteção não estiver de pé **antes** do primeiro deploy, existe uma janela
em que a URL responde sem nada. No Fly.io, defina `SENHA_ACESSO` como secret
antes do `fly deploy`. No arranjo com Tailscale a janela não existe, porque
nunca há endereço público.

### Servidor: quanto custa

| Opção | Custo | Observação |
|---|---|---|
| **Hetzner CX22** | ~€ 3,79/mês | Simples e estável. Recomendado. |
| **Oracle Cloud Always Free** | grátis | Generoso, mas sujeito a falta de capacidade e recuperação de instâncias ociosas. |
| **Raspberry Pi em casa** | ~R$ 400 uma vez | Sem mensalidade, dados na sua casa. |

O app é leve: com 700 lançamentos responde o painel em ~4 ms. O menor servidor
de qualquer provedor dá conta.

---

## Variáveis de ambiente

Nenhuma é obrigatória. Veja `.env.example`.

| Variável | Padrão | Para que serve |
|---|---|---|
| `PORT` | `3000` | Porta de escuta |
| `HOST` | `127.0.0.1` | `0.0.0.0` aceita conexões da rede |
| `DB_PATH` | `./data/financeiro.db` | Arquivo do banco |
| `SENHA_ACESSO` | — | **Define a senha e liga a barreira.** Vazio = sem senha |
| `ACESSO_DIAS` | `60` | Dias que o aparelho fica autorizado |
| `TRUST_PROXY` | — | `1` atrás de proxy/CDN, para o IP real chegar |
| `ACESSO_PROTEGIDO` | — | `1` silencia o aviso quando a barreira é externa |
| `BACKUP_DIR` | Área de trabalho | Destino padrão do `npm run backup` |

---

## Estrutura

```
server.js                    inicialização do servidor HTTP
Dockerfile                   imagem para publicar
iniciar.bat                  atalho de dois cliques (Windows)
iniciar-rede.bat             abre para a rede local (celular)
empacotar.ps1                gera um .zip para enviar a outra pessoa
src/
  app.js                     Express: middlewares, CSP, porteiro de sessão
  db.js                      schema, migração, defaults, helpers
  http.js                    erros tipados e validação de entrada
  routes/
    transactions.js          CRUD e listagem filtrada
    categories.js            CRUD de categorias
    budgets.js               limites global e por categoria
    recurrences.js           lançamentos fixos
    dashboard.js             painel, alertas, meses, ajustes, export, demo
  services/
    acesso.js                barreira de senha opcional (HMAC, sem banco)
    recurrences.js           materialização e previsão dos fixos
    util.js                  datas, dinheiro em centavos, janelas de mês
    analytics.js             KPIs, séries, curva de ritmo, projeções
    alerts.js                motor de alertas e nota de saúde
    demo.js                  gerador de dados de exemplo
public/
  index.html                 estrutura da interface
  manifest.json              metadados do app instalável
  sw.js                      service worker (abre offline)
  css/styles.css             tokens de design, layout e camada mobile
  icons/                     PNGs gerados por scripts/gerar-icones.js
  js/
    format.js                formatação pt-BR e parsing de valores
    tokens.js                ponte entre tokens CSS e os gráficos
    api.js                   cliente da API
    charts.js                construtores dos gráficos (Chart.js)
    render.js                renderização do DOM
    quick.js                 tela "Lançar" (teclado próprio)
    app.js                   estado, navegação e eventos
scripts/
  seed.js                    popula dados de exemplo
  backup.js                  cópia de segurança consistente (VACUUM INTO)
  rede.js                    sobe para a rede local e mostra o endereço
  gerar-icones.js            codificador PNG próprio, sem dependências
data/financeiro.db           banco SQLite (criado na primeira execução)
```

**Dinheiro em centavos.** Valores são gravados como `INTEGER` de centavos e
convertidos para reais apenas na borda da API, para não acumular erro de ponto
flutuante.

---

## API

Todas as rotas devolvem JSON e recebem valores em reais. Se `SENHA_ACESSO`
estiver definida, todas exigem o cookie de acesso, exceto `/api/health` e
`/api/acesso/*` — ver [Acesso e segurança](#acesso-e-segurança).

| Método | Rota | O que faz |
|---|---|---|
| `GET` | `/api/health` | status do servidor (livre, sem senha) |
| `GET` | `/api/acesso/estado` | se há senha configurada e se este aparelho passou |
| `POST` | `/api/acesso/entrar` | informa a senha e autoriza o aparelho |
| `POST` | `/api/acesso/sair` | revoga este aparelho |
| `GET` | `/api/dashboard?month=AAAA-MM` | painel completo + alertas + previstos |
| `GET` | `/api/alerts?month=AAAA-MM` | alertas e nota de saúde |
| `GET` | `/api/months` | meses com movimento |
| `GET` | `/api/transactions` | lista filtrada (`month`, `from`, `to`, `type`, `categoryId`, `search`, `limit`, `offset`) |
| `POST` | `/api/transactions` | cria lançamento |
| `POST` | `/api/transactions/bulk` | cria em lote (tudo ou nada) |
| `PUT` `DELETE` | `/api/transactions/:id` | atualiza / remove |
| `GET` `POST` | `/api/categories` | lista / cria |
| `PUT` `DELETE` | `/api/categories/:id` | atualiza / remove |
| `GET` | `/api/budgets?month=AAAA-MM` | limites cadastrados, efetivos e situação |
| `PUT` | `/api/budgets` | grava um limite (`categoryId: 0` = global) |
| `PUT` | `/api/budgets/bulk` | grava vários; valor zero remove |
| `GET` | `/api/recurrences?month=AAAA-MM` | lançamentos fixos, previstos e resumo |
| `POST` | `/api/recurrences` | cria lançamento fixo |
| `PUT` `DELETE` | `/api/recurrences/:id` | atualiza (inclui pausar) / remove |
| `POST` | `/api/recurrences/gerar` | força a geração dos fixos vencidos |
| `GET` `PUT` | `/api/settings` | limiares de alerta |
| `GET` | `/api/export.csv` | backup dos lançamentos em CSV |
| `POST` | `/api/demo` | dados de exemplo (`{"force": true}`) |
| `POST` | `/api/reset` | apaga lançamentos e limites (`{"confirm": true}`) |

---

## Backup

Dois cliques em **`backup.bat`** (ou `npm run backup`). Funciona **com o app
aberto** e salva em `OneDrive - Grupo Trigo\Área de Trabalho\Backups Financeiro`,
com data e hora no nome. Mantém os 30 mais recentes e apaga os antigos.

Para escolher outro destino:

```bash
npm run backup -- "D:\meus-backups"
```

**Por que não simplesmente copiar o `.db`:** o SQLite mantém gravações recentes
num arquivo `.db-wal` ao lado. Uma cópia manual do `.db` sozinho pode chegar sem
os últimos lançamentos — ou corrompida, se o copiador pegar o arquivo no meio de
uma escrita. O script usa `VACUUM INTO`, que produz uma cópia consistente e
compactada mesmo com o servidor gravando, e confere a integridade do resultado
antes de terminar.

Se preferir copiar à mão, **pare o servidor primeiro**.

Para um formato legível em planilha, use **Exportar CSV** (com BOM, o Excel em
pt-BR abre os acentos corretamente).

---

## Notas de design

A paleta não foi escolhida por gosto. As oito cores categóricas, a rampa
sequencial do calendário e as cores de status são valores validados: cada modo
(claro e escuro) passa em testes de faixa de luminosidade, piso de croma,
separação sob protanopia e deuteranopia (ΔE OKLab ≥ 8 entre pares adjacentes) e
contraste contra a superfície. O modo escuro tem passos próprios — não é uma
inversão automática do claro.

Consequências práticas para quem for alterar o código:

- Trocar um slot de cor exige revalidar o conjunto, não só olhar.
- A cor segue a entidade, nunca a posição no ranking: filtrar a lista não
  repinta quem sobrou. Por isso a categoria guarda um `color_slot` no banco.
- Nenhum gráfico tem dois eixos verticais. Duas escalas no mesmo plot inventam
  uma correlação que não está nos dados.
- Texto nunca veste a cor da série. Quem carrega identidade é a marca colorida
  ao lado do rótulo.
- Severidade nunca depende só da cor: todo alerta tem ícone e rótulo textual.
- Todo gráfico tem uma tabela gêmea.
- No celular, alvos de toque de 44px ou mais, e campos com `font-size: 16px`
  para o iOS não dar zoom ao focar.
