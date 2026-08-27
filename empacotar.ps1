# =============================================================
#  Empacota o projeto num .zip — para enviar a outra pessoa ou subir no
#  servidor (ver DEPLOY.md).
#
#  DEIXA DE FORA, de proposito:
#    data\          -> o banco com os SEUS lancamentos financeiros
#    backups\       -> as copias de seguranca (mesmo motivo)
#    .env           -> SEGREDOS. E' onde mora a auth key do Tailscale; se ela
#                      viajar num zip, quem receber entra na sua rede privada
#    node_modules\  -> ~70 pacotes que o npm install recria em segundos
#    .git\          -> historico de versao, se existir
#
#  O zip que sai daqui pode ser enviado sem expor dados nem segredos:
#  quem receber comeca com a base vazia.
#
#  Uso:  clique com o botao direito neste arquivo > "Executar com o PowerShell"
#        ou, num terminal:  powershell -ExecutionPolicy Bypass -File empacotar.ps1
# =============================================================

$ErrorActionPreference = 'Stop'

$raiz = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$nome = "controle-financeiro-" + (Get-Date -Format 'yyyy-MM-dd')
$areaDeTrabalho = [Environment]::GetFolderPath('Desktop')
$destino = Join-Path $areaDeTrabalho "$nome.zip"
$temp = Join-Path $env:TEMP ("empacotar-" + [guid]::NewGuid().ToString('N'))

Write-Host ""
Write-Host "Empacotando o projeto..." -ForegroundColor Cyan
Write-Host "  origem:  $raiz"
Write-Host "  destino: $destino"
Write-Host ""

New-Item -ItemType Directory -Path $temp -Force | Out-Null

try {
    # robocopy lida melhor com exclusoes e caminhos longos que Copy-Item.
    # `.env` na lista de arquivos excluidos: e' onde fica a auth key do
    # Tailscale, e um segredo nao viaja num zip.
    robocopy $raiz $temp /E `
        /XD node_modules data backups .git .vs `
        /XF *.db *.db-wal *.db-shm *.zip npm-debug.log .env `
        /NFL /NDL /NJH /NJS /NP | Out-Null

    # robocopy usa 0-7 para sucesso; 8 ou mais e' falha real.
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy falhou com codigo $LASTEXITCODE"
    }

    if (Test-Path $destino) { Remove-Item $destino -Force }
    Compress-Archive -Path (Join-Path $temp '*') -DestinationPath $destino -Force

    $tamanho = [math]::Round((Get-Item $destino).Length / 1KB, 0)
    $arquivos = (Get-ChildItem -Recurse -File $temp | Measure-Object).Count

    Write-Host "Pronto." -ForegroundColor Green
    Write-Host "  $arquivos arquivos, $tamanho KB"
    Write-Host "  $destino"
    Write-Host ""
    Write-Host "Diga a quem receber:" -ForegroundColor Yellow
    Write-Host "  1. Instalar o Node.js  ->  winget install OpenJS.NodeJS.LTS"
    Write-Host "  2. Extrair o zip"
    Write-Host "  3. Dar dois cliques em iniciar.bat"
    Write-Host ""
}
finally {
    if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
}
