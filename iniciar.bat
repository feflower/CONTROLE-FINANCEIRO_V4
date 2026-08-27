@echo off
REM ============================================================
REM  Controle Financeiro Pessoal - atalho de inicializacao
REM  Basta dar dois cliques neste arquivo.
REM  (Sem acentos de proposito: o console do Windows usa outra
REM   tabela de caracteres e mostraria os acentos errados.)
REM ============================================================

cd /d "%~dp0"
title Controle Financeiro Pessoal

where node >nul 2>nul
if errorlevel 1 (
  echo.
  echo  [ERRO] O Node.js nao foi encontrado.
  echo.
  echo  Instale o Node.js e abra este arquivo novamente:
  echo    winget install OpenJS.NodeJS.LTS
  echo  ou baixe em https://nodejs.org
  echo.
  pause
  exit /b 1
)

if not exist "node_modules\" (
  echo.
  echo  Primeira execucao: instalando as dependencias...
  echo.
  call npm install --no-audit --no-fund
  if errorlevel 1 (
    echo.
    echo  [ERRO] Falha ao instalar as dependencias.
    echo.
    pause
    exit /b 1
  )
)

if not exist "public\icons\icone-192.png" (
  echo  Gerando icones do app...
  call npm run icones
)

REM Abre o navegador alguns segundos depois, quando o servidor ja
REM estiver ouvindo na porta.
start "" /b powershell -NoProfile -Command "Start-Sleep -Seconds 3; Start-Process 'http://localhost:3000'"

echo.
echo  Servidor iniciando. O navegador abre em instantes.
echo  Para encerrar, feche esta janela ou pressione Ctrl+C.
echo.

npm start

REM Se o servidor cair, a janela fica aberta para mostrar o erro.
echo.
echo  O servidor foi encerrado.
pause
