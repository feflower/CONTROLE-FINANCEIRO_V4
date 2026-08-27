# Imagem para publicar a aplicacao (Fly.io, Railway, VPS, etc).
#
# DOIS PONTOS QUE NAO PODEM SER ESQUECIDOS:
#
# 1. O banco e um ARQUIVO em /data. Sem um disco persistente montado nesse
#    caminho, todo lancamento desaparece no proximo deploy ou reinicio.
#
# 2. Esta aplicacao NAO TEM LOGIN. Publicar sem uma barreira na frente
#    (Cloudflare Access, Tailscale, basic auth no proxy) deixa o extrato
#    financeiro aberto para quem tiver a URL. Configure a barreira ANTES do
#    primeiro deploy e suba com ACESSO_PROTEGIDO=1.
#
# Ver a secao "Publicar na internet" no README.

FROM node:24-alpine

# `tini` como PID 1 para que SIGTERM chegue ao Node e ele feche o servidor
# (e o SQLite) direito, em vez de morrer no meio de uma gravacao.
RUN apk add --no-cache tini

WORKDIR /app

# As dependencias entram primeiro: assim a camada de instalacao so e refeita
# quando o package.json muda, nao a cada alteracao de codigo.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY . .

# Os icones do app instalavel sao ARQUIVOS DO PROJETO, copiados junto — nao
# gerados aqui. A versao anterior deste Dockerfile excluia `public/icons` no
# .dockerignore e rodava `node scripts/gerar-icones.js` para recria-los; isso
# tornava o build dependente do diretorio scripts/ e falhava com
# "Cannot find module" quando ele nao chegava no contexto.
#
# A checagem abaixo falha cedo e com mensagem util, em vez de gerar uma imagem
# que sobe mas nao instala no celular por falta de icone.
RUN test -f public/icons/icone-192.png && test -f public/icons/apple-touch-icon.png || \
    ( echo ""; \
      echo "ERRO: public/icons/ nao chegou na imagem."; \
      echo "  - confirme que a pasta existe no diretorio de deploy;"; \
      echo "  - confirme que o .dockerignore NAO exclui public/icons;"; \
      echo "  - se faltar, rode 'npm run icones' antes do deploy."; \
      echo ""; \
      exit 1 )

# Diretorio do banco. MONTE UM VOLUME AQUI.
RUN mkdir -p /data
ENV DB_PATH=/data/financeiro.db

ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0 \
    TRUST_PROXY=1

EXPOSE 3000

# O orquestrador usa isto para saber se o container subiu de verdade. Nao usa
# curl: a imagem alpine nao traz, e instalar so' para isso engorda a imagem.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# Sem shell no meio: o sinal vai direto para o processo.
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "--disable-warning=ExperimentalWarning", "server.js"]
