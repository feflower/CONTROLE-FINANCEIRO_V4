@echo off
REM ============================================================
REM  Controle Financeiro Pessoal
REM  Abre o painel neste PC E libera o acesso pelo celular
REM  (o celular precisa estar no MESMO Wi-Fi deste PC).
REM ============================================================

cd /d "%~dp0"
title Controle Financeiro Pessoal

where node >nul 2>nul
if errorlevel 1 (
  echo.
  echo  [ERRO] Node.js nao encontrado. Instale com:
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
    echo  [ERRO] Falha ao instalar dependencias.
    pause
    exit /b 1
  )
)

if not exist "public\icons\icone-192.png" (
  echo  Gerando icones do app...
  call npm run icones
)

REM Abre o navegador quando o servidor ja estiver ouvindo na porta.
start "" /b powershell -NoProfile -Command "Start-Sleep -Seconds 3; Start-Process 'http://localhost:3000'"

npm run rede

echo.
echo  O servidor foi encerrado.
pause
