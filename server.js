'use strict';

const { createApp, avisoDeExposicao } = require('./src/app');
const { DB_PATH } = require('./src/db');

const PORT = Number(process.env.PORT) || 3000;
const HOST = process.env.HOST || '127.0.0.1';

const app = createApp();

const server = app.listen(PORT, HOST, () => {
  const url = `http://${HOST === '0.0.0.0' ? 'localhost' : HOST}:${PORT}`;
  console.log('');
  console.log('  Controle Financeiro Pessoal');
  console.log(`  Painel   ${url}`);
  console.log(`  API      ${url}/api/health`);
  console.log(`  Banco    ${DB_PATH}`);

  const aviso = avisoDeExposicao({ host: HOST });
  if (aviso) {
    console.log('');
    console.log(aviso);
  }

  console.log('');
  console.log('  Ctrl+C para encerrar.');
  console.log('');
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`\n  A porta ${PORT} já está em uso.`);
    console.error('  Rode com outra porta:  set PORT=3001 && npm start\n');
    process.exit(1);
  }
  throw err;
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    server.close(() => process.exit(0));
  });
}
