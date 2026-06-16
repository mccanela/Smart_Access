# Deploy no Firebase Hosting

Este guia explica como fazer deploy do aplicativo Flutter Web no Firebase Hosting.

## Pré-requisitos

1. **Node.js instalado** (para usar Firebase CLI)
   - Baixe em: https://nodejs.org/
   - Instale a versão LTS

2. **Firebase CLI instalado**
   ```powershell
   npm install -g firebase-tools
   ```

3. **Conta Google e projeto Firebase**
   - Acesse: https://console.firebase.google.com/
   - Crie um projeto chamado `smart-2027` ou use um existente

## Passo a Passo

### 1. Instalar Firebase CLI (se ainda não instalado)

```powershell
npm install -g firebase-tools
```

### 2. Fazer login no Firebase

```powershell
firebase login
```

Isso abrirá o navegador para você fazer login com sua conta Google.

### 3. Verificar projeto Firebase

Certifique-se de que o projeto `smart-2027` existe no Firebase Console:
- https://console.firebase.google.com/

Se o projeto tiver outro nome, edite o arquivo `.firebaserc` e altere o nome do projeto.

### 4. Fazer build do Flutter

```powershell
flutter build web --release
```

### 5. Fazer deploy

**Opção 1: Usar o script automatizado**
```powershell
.\deploy_firebase.ps1
```

**Opção 2: Deploy manual**
```powershell
firebase deploy --only hosting
```

## Arquivos de Configuração

- `firebase.json` - Configuração do Firebase Hosting
- `.firebaserc` - ID do projeto Firebase

## URLs do App

Após o deploy, seu app estará disponível em:
- https://smart-2027.web.app
- https://smart-2027.firebaseapp.com

## Comandos Úteis

```powershell
# Ver status do deploy
firebase hosting:channel:list

# Fazer deploy em um canal de preview
firebase hosting:channel:deploy preview

# Ver logs
firebase hosting:clone
```

## Troubleshooting

### Erro: "Firebase CLI não encontrado"
- Instale Node.js: https://nodejs.org/
- Instale Firebase CLI: `npm install -g firebase-tools`

### Erro: "Não autenticado"
- Execute: `firebase login`

### Erro: "Projeto não encontrado"
- Verifique se o projeto `smart-2027` existe no Firebase Console
- Ou altere o nome do projeto no arquivo `.firebaserc`

### Erro no build do Flutter
- Execute: `flutter clean`
- Execute: `flutter pub get`
- Execute: `flutter build web --release`

