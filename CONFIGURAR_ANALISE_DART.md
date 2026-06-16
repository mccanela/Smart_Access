# Como Habilitar a Análise de Código no IDE

## Problema
Os erros e avisos do código (linhas azuis, amarelas, etc.) não estão aparecendo no IDE.

## Soluções

### 1. Verificar se o Dart Analysis Server está rodando

#### No VS Code:
1. Abra a paleta de comandos (Ctrl+Shift+P)
2. Digite: `Dart: Restart Analysis Server`
3. Pressione Enter
4. Aguarde alguns segundos para o servidor reiniciar

#### No Android Studio / IntelliJ:
1. Vá em `File` > `Invalidate Caches / Restart`
2. Selecione `Invalidate and Restart`
3. Aguarde o IDE reiniciar

### 2. Verificar configurações do IDE

#### No VS Code:
1. Abra as configurações (Ctrl+,)
2. Procure por "dart.analysisExcludedFolders"
3. Certifique-se de que não está excluindo pastas importantes
4. Procure por "dart.showTodos"
5. Certifique-se de que está habilitado

#### No Android Studio / IntelliJ:
1. Vá em `File` > `Settings` (ou `Preferences` no Mac)
2. Navegue até `Editor` > `Inspections` > `Dart`
3. Certifique-se de que as inspeções estão habilitadas
4. Verifique se o nível de severidade está configurado corretamente

### 3. Verificar o arquivo analysis_options.yaml

O arquivo `analysis_options.yaml` já foi configurado para mostrar todos os erros e avisos. Verifique se o arquivo está salvo corretamente.

### 4. Executar análise manualmente

Abra o terminal e execute:
```bash
flutter analyze
```

Isso mostrará todos os erros e avisos no terminal.

### 5. Verificar extensões do IDE

#### No VS Code:
- Certifique-se de que a extensão "Dart" está instalada e habilitada
- Certifique-se de que a extensão "Flutter" está instalada e habilitada

#### No Android Studio / IntelliJ:
- Certifique-se de que o plugin "Dart" está instalado e habilitado
- Certifique-se de que o plugin "Flutter" está instalado e habilitado

### 6. Reiniciar o IDE

Às vezes, simplesmente reiniciar o IDE resolve o problema:
1. Feche completamente o IDE
2. Abra novamente
3. Aguarde alguns segundos para o Dart Analysis Server inicializar

### 7. Verificar logs do Dart Analysis Server

#### No VS Code:
1. Abra o Output (Ctrl+Shift+U)
2. Selecione "Dart" no dropdown
3. Verifique se há erros ou avisos

#### No Android Studio / IntelliJ:
1. Vá em `Help` > `Show Log in Explorer`
2. Procure por erros relacionados ao Dart Analysis Server

## Comandos úteis

### Reiniciar o servidor de análise
```bash
# No VS Code: Ctrl+Shift+P > "Dart: Restart Analysis Server"
# No terminal (se necessário):
flutter clean
flutter pub get
```

### Verificar se o Flutter está funcionando
```bash
flutter doctor
flutter analyze
```

## Resultado esperado

Após seguir os passos acima, você deve ver:
- **Linhas vermelhas** = Erros (erros que impedem a compilação)
- **Linhas amarelas** = Avisos (warnings)
- **Linhas azuis** = Informações (info, como `avoid_print`)
- **Sublinhados** = Problemas de código que devem ser corrigidos

## Notas

- O arquivo `analysis_options.yaml` foi configurado para mostrar todos os tipos de problemas
- Alguns avisos podem ser ignorados (como `avoid_print`), mas é recomendado corrigi-los
- O Dart Analysis Server pode demorar alguns segundos para analisar o código, especialmente em projetos grandes

