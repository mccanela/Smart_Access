# Remoção de Filtragem de IDs no SignalR

## Data: 2026-02-11

## Objetivo
Remover a comparação de `condominio_id` no processamento de dados do SignalR para mostrar **TODOS** os dados que o servidor envia, sem filtrar por condomínio.

## Mudanças Realizadas

### 1. `dashboard.dart` (linhas 2297-2328)
**Antes:** Havia uma lógica complexa de filtragem que comparava o `condominio_id` de cada item recebido com o `_cachedCondominioId` e descartava itens de outros condomínios.

**Depois:** Removida toda a lógica de filtragem. Agora todos os dados recebidos são processados e exibidos. Adicionados logs detalhados para cada item:
- ID
- Nome
- Documento
- Condominio ID (de qualquer condomínio)
- Tipo
- Data
- Unidade
- Todos os campos completos

### 2. `dashboard.dart` (linhas 2222-2230)
**Adicionado:** Logs detalhados no início do handler de atualização do SignalR:
- Total de itens recebidos
- Dados brutos dos primeiros 3 itens
- Separadores visuais para facilitar leitura dos logs

### 3. `dashboard_isolate.dart` (linhas 10-41)
**Antes:** Havia filtragem por `condominio_id` no processamento isolado (compute).

**Depois:** 
- Removida toda a lógica de filtragem
- Removida a variável `condominioId` não utilizada
- Adicionados logs detalhados para cada item processado no isolate

## Resultado Esperado
Agora o sistema irá:
1. ✅ Receber todos os dados do SignalR sem filtrar
2. ✅ Mostrar logs detalhados de TUDO que chega do servidor
3. ✅ Exibir cards de todos os condomínios (se o servidor enviar)
4. ✅ Permitir debug completo do que o SignalR está trazendo

## Como Verificar
1. Abra o console do navegador (F12)
2. Observe os logs com os seguintes prefixos:
   - `🔔 [SignalR] RECEBIDO ATUALIZAÇÃO DO SERVIDOR`
   - `📦 [SignalR] DADOS RECEBIDOS:`
   - `🔍 [Isolate] Processando item:`
3. Verifique se todos os dados estão sendo mostrados nos logs
4. Verifique se os cards aparecem na tela (independente do condominio_id)

## Observações
- Esta mudança remove a segurança de isolamento por condomínio
- Útil para debug e testes
- Em produção, considere restaurar a filtragem para segurança

## Correção Adicional: Erro de Fetch API

### Problema Encontrado
Após as mudanças, surgiu um erro:
```
Fetch API cannot load wss://signalr.conectcon.net.br:10901/client/negotiate?condominio_id=1772. 
URL scheme "wss" is not supported.
```

### Causa
O navegador estava tentando usar a Fetch API para conectar ao WebSocket, mas a Fetch API não suporta o esquema `wss://`.

### Solução Aplicada
Adicionado configuração explícita de transporte WebSocket no `signalr_service.dart`:
```dart
HttpConnectionOptions(
  accessTokenFactory: () async => bearerToken,
  withCredentials: false,
  transport: HttpTransportType.webSockets,  // ✅ Adicionado
  skipNegotiation: true,                     // ✅ Adicionado
)
```

Isso força o SignalR a usar WebSocket diretamente, pulando a negociação HTTP que estava causando o erro.

## Comando do Servidor

O servidor espera receber o comando `PassagemListar` com o `condominio_id`:

```dart
await _hubConnection!.invoke("PassagemListar", args: [condominioId]);
```

**Importante:** Conforme solicitado, removemos o uso do comando `Comandos` e restauramos a filtragem de `condominio_id` no cliente para garantir que apenas os dados do condomínio logado sejam exibidos, mesmo que o servidor envie dados de outros condomínios.


## Processamento de Fotos via link_foto

Os dados do SignalR agora incluem o campo `link_foto` com a URL da imagem:
```json
{
  "link_foto": "https://pub-9313ea4eec6c404c845254ee76d0a174.r2.dev/geral/botoeira.jpg"
}
```

### Implementação
Adicionamos processamento automático para converter `link_foto` em `foto`:

**No dashboard.dart:**
```dart
// Processar link_foto se existir
if (p.containsKey('link_foto') && p['link_foto'] != null && p['link_foto'].toString().isNotEmpty) {
  // Se tem link_foto, usar diretamente (já é uma URL)
  p['foto'] = p['link_foto'];
  print('   ✅ Foto configurada: ${p['foto']}');
}
```

**No dashboard_isolate.dart:**
```dart
// Processar link_foto se existir (prioridade)
if (p.containsKey('link_foto') && p['link_foto'] != null && p['link_foto'].toString().isNotEmpty) {
  p['foto'] = p['link_foto'];
  print('   ✅ [Isolate] Foto configurada via link_foto: ${p['foto']}');
} 
// Se não tem link_foto, processar foto como array de bytes (legado)
else if (p.containsKey('foto') && p['foto'] != null) {
  // ... processamento de bytes
}
```

Agora as passagens devem aparecer com as fotos corretas nos cards! 📸



