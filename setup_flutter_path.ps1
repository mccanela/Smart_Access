# Script para configurar o PATH do Flutter permanentemente
Write-Host "Configurando PATH do Flutter..." -ForegroundColor Green

$flutterBinPath = "C:\src\flutter\bin"
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

# Verificar se Flutter já está no PATH
if ($currentPath -notlike "*$flutterBinPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$flutterBinPath", "User")
    Write-Host "Flutter adicionado ao PATH permanentemente!" -ForegroundColor Green
    Write-Host "Por favor, feche e reabra o terminal para aplicar as mudanças" -ForegroundColor Yellow
} else {
    Write-Host "Flutter já está no PATH" -ForegroundColor Yellow
}

# Tentar habilitar o Modo de Desenvolvedor (requer privilégios de administrador)
Write-Host "`nVerificando Modo de Desenvolvedor..." -ForegroundColor Green
try {
    $devMode = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
    
    if (-not $devMode -or $devMode.AllowDevelopmentWithoutDevLicense -eq 0) {
        Write-Host "Modo de Desenvolvedor não está habilitado" -ForegroundColor Yellow
        Write-Host "Para habilitar:" -ForegroundColor Yellow
        Write-Host "1. Pressione Windows + I para abrir Configurações" -ForegroundColor Yellow
        Write-Host "2. Vá para 'Privacidade e segurança' > 'Para desenvolvedores'" -ForegroundColor Yellow
        Write-Host "3. Ative 'Modo de desenvolvedor'" -ForegroundColor Yellow
        Write-Host "OU execute: start ms-settings:developers" -ForegroundColor Yellow
        
        # Tentar abrir as configurações
        Start-Process "ms-settings:developers"
    } else {
        Write-Host "Modo de Desenvolvedor já está habilitado!" -ForegroundColor Green
    }
} catch {
    Write-Host "Não foi possível verificar o Modo de Desenvolvedor (pode exigir privilégios de administrador)" -ForegroundColor Yellow
}

Write-Host "`nConfiguração concluída!" -ForegroundColor Green

