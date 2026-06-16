# Script para instalar Flutter no Windows
Write-Host "Instalando Flutter SDK..." -ForegroundColor Green

# Criar diretório C:\src se não existir
if (-not (Test-Path "C:\src")) {
    New-Item -ItemType Directory -Path "C:\src" -Force | Out-Null
    Write-Host "Diretório C:\src criado" -ForegroundColor Yellow
}

# URL do Flutter SDK (versão estável)
$flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"
$zipFile = "$env:TEMP\flutter.zip"
$flutterDir = "C:\src\flutter"

# Verificar se Flutter já está instalado
if (Test-Path $flutterDir) {
    Write-Host "Flutter já está instalado em $flutterDir" -ForegroundColor Yellow
    Write-Host "Pulando download..." -ForegroundColor Yellow
} else {
    # Baixar Flutter SDK
    Write-Host "Baixando Flutter SDK (isso pode demorar alguns minutos)..." -ForegroundColor Yellow
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $flutterUrl -OutFile $zipFile -UseBasicParsing
        Write-Host "Download concluído!" -ForegroundColor Green
        
        # Extrair arquivo
        Write-Host "Extraindo Flutter SDK..." -ForegroundColor Yellow
        Expand-Archive -Path $zipFile -DestinationPath "C:\src" -Force
        Remove-Item $zipFile
        Write-Host "Extração concluída!" -ForegroundColor Green
    } catch {
        Write-Host "Erro ao baixar Flutter: $_" -ForegroundColor Red
        Write-Host "Tente baixar manualmente de: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
        exit 1
    }
}

# Adicionar Flutter ao PATH do usuário
$flutterBinPath = "$flutterDir\bin"
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

if ($currentPath -notlike "*$flutterBinPath*") {
    Write-Host "Adicionando Flutter ao PATH..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$flutterBinPath", "User")
    $env:Path += ";$flutterBinPath"
    Write-Host "Flutter adicionado ao PATH!" -ForegroundColor Green
} else {
    Write-Host "Flutter já está no PATH" -ForegroundColor Yellow
    $env:Path += ";$flutterBinPath"
}

# Verificar instalação
Write-Host "`nVerificando instalação do Flutter..." -ForegroundColor Green
& "$flutterDir\bin\flutter.bat" --version

Write-Host "`nInstalação concluída!" -ForegroundColor Green
Write-Host "Execute 'flutter doctor' para verificar a configuração" -ForegroundColor Yellow

