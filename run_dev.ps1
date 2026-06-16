# Script para executar o projeto Flutter em modo de desenvolvimento (hot reload)
Write-Host "Iniciando projeto Flutter em modo de desenvolvimento..." -ForegroundColor Green
Write-Host "Após a compilação, você pode:" -ForegroundColor Yellow
Write-Host "  - Pressionar 'r' para hot reload (recarregar após alterações)" -ForegroundColor Cyan
Write-Host "  - Pressionar 'R' para hot restart (reiniciar completamente)" -ForegroundColor Cyan
Write-Host "  - Pressionar 'q' para sair" -ForegroundColor Cyan
Write-Host ""

# Configurar PATH do Flutter
$env:Path = "C:\src\flutter\bin;" + $env:Path

# Verificar se Flutter está instalado
if (-not (Test-Path "C:\src\flutter\bin\flutter.bat")) {
    Write-Host "Flutter não está instalado. Execute install_flutter.ps1 primeiro." -ForegroundColor Red
    exit 1
}

# Navegar para o diretório do projeto
Set-Location $PSScriptRoot

# Executar o projeto no Chrome com hot reload habilitado
Write-Host "Executando projeto no Chrome..." -ForegroundColor Yellow
C:\src\flutter\bin\flutter.bat run -d chrome

