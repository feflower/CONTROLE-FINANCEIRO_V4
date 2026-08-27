@echo off
REM Copia de seguranca do banco. Funciona com o app aberto.
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo  [ERRO] Node.js nao encontrado.
  pause
  exit /b 1
)
npm run backup
echo.
pause
