# Como Iniciar o Projeto Flutter com Hot Reload

## Opção 1: Usar o Script PowerShell (Recomendado)

1. Abra o PowerShell no diretório do projeto
2. Execute:
```powershell
powershell -ExecutionPolicy Bypass -File run_dev.ps1
```

## Opção 2: Executar Diretamente

1. Abra o PowerShell ou Terminal no diretório do projeto
2. Execute:
```powershell
C:\src\flutter\bin\flutter.bat run -d chrome
```

## Como Usar o Hot Reload

Após o projeto iniciar e a aplicação abrir no Chrome, você verá no terminal algo como:

```
Flutter run key commands.
r Hot reload. 🔥🔥🔥
R Hot restart.
h List all available interactive commands.
d Detach (terminate "flutter run" but leave application running).
c Clear the screen
q Quit (terminate the application on the device).
```

### Comandos Disponíveis:

- **`r`** - Hot Reload: Recarrega a aplicação após fazer alterações no código (MANTÉM O ESTADO)
- **`R`** - Hot Restart: Reinicia completamente a aplicação (PERDE O ESTADO)
- **`h`** - Mostra todos os comandos disponíveis
- **`d`** - Desanexa (termina o "flutter run" mas deixa a aplicação rodando)
- **`c`** - Limpa a tela do terminal
- **`q`** - Sair (fecha a aplicação)

## Workflow Recomendado

1. Execute o projeto usando uma das opções acima
2. Faça suas alterações no código
3. Salve o arquivo (Ctrl+S)
4. No terminal onde o Flutter está rodando, pressione **`r`** para hot reload
5. A aplicação será atualizada automaticamente no navegador

## Dica

- O hot reload funciona melhor com mudanças em widgets e lógica de UI
- Para mudanças em inicialização, constantes ou métodos `initState()`, use hot restart (`R`)
- Se houver erros, o Flutter mostrará no terminal e no navegador

## Troubleshooting

Se o hot reload não funcionar:
1. Verifique se há erros no código
2. Tente hot restart (`R`)
3. Se persistir, pare o projeto (`q`) e inicie novamente

