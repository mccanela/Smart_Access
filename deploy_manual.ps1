# Script simplificado para deploy manual no Firebase
# Execute estes comandos em ordem:

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DEPLOY MANUAL NO FIREBASE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "PASSO 1: Verificar se Node.js está instalado" -ForegroundColor Yellow
try {
    $nodeVersion = node --version
    Write-Host "✓ Node.js instalado: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Node.js não instalado!" -ForegroundColor Red
    Write-Host ""
    Write-Host "BAIXE E INSTALE O NODE.JS:" -ForegroundColor Yellow
    Write-Host "  https://nodejs.org/" -ForegroundColor White
    Write-Host "  Baixe a versão LTS (recomendada)" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "PASSO 2: Instalar Firebase CLI" -ForegroundColor Yellow
Write-Host "Execute no PowerShell (como administrador):" -ForegroundColor White
Write-Host "  npm install -g firebase-tools" -ForegroundColor Cyan
Write-Host ""

Write-Host "PASSO 3: Fazer login no Firebase" -ForegroundColor Yellow
Write-Host "Execute no PowerShell:" -ForegroundColor White
Write-Host "  firebase login" -ForegroundColor Cyan
Write-Host ""

Write-Host "PASSO 4: Verificar projeto no Firebase Console" -ForegroundColor Yellow
Write-Host "Acesse: https://console.firebase.google.com/" -ForegroundColor White
Write-Host "Verifique se existe o projeto: smart-2027" -ForegroundColor White
Write-Host "Se não existir, crie um novo projeto" -ForegroundColor White
Write-Host ""

Write-Host "PASSO 5: Fazer build do Flutter" -ForegroundColor Yellow
Write-Host "Execute no PowerShell:" -ForegroundColor White
Write-Host "  flutter build web --release" -ForegroundColor Cyan
Write-Host ""

Write-Host "PASSO 6: Fazer deploy" -ForegroundColor Yellow
Write-Host "Execute no PowerShell:" -ForegroundColor White
Write-Host "  firebase deploy --only hosting" -ForegroundColor Cyan
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "  URLs APÓS O DEPLOY:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  https://smart-2027.web.app" -ForegroundColor Cyan
Write-Host "  https://smart-2027.firebaseapp.com" -ForegroundColor Cyan
Write-Host ""

Write-Host "INSTRUÇÕES DETALHADAS EM: DEPLOY_FIREBASE.md" -ForegroundColor Yellow
