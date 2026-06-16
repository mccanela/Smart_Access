# Script para executar o projeto Flutter
Write-Host "Iniciando projeto Flutter..." -ForegroundColor Green

# Configurar PATH do Flutter
$env:Path = "C:\src\flutter\bin;" + $env:Path

# Verificar se Flutter está instalado
if (-not (Test-Path "C:\src\flutter\bin\flutter.bat")) {
    Write-Host "Flutter não está instalado. Execute install_flutter.ps1 primeiro." -ForegroundColor Red
    exit 1
}

# Navegar para o diretório do projeto
Set-Location $PSScriptRoot

# Executar o projeto no Chrome
Write-Host "Executando projeto no Chrome..." -ForegroundColor Yellow
C:\src\flutter\bin\flutter.bat run -d chrome

