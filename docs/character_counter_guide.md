# Contador de Caracteres - Guia de Implementação

## Visão Geral

O widget `CharacterCounterField` foi criado para adicionar um contador de caracteres elegante e discreto a todos os campos de entrada de texto do sistema. O contador aparece automaticamente quando o usuário clica/foca no campo e desaparece quando o foco é perdido.

## Características

- ✅ **Aparece apenas ao focar**: O contador só fica visível quando o campo está em foco
- ✅ **Atualização em tempo real**: Mostra a contagem de caracteres conforme o usuário digita
- ✅ **Design elegante**: Posicionado no canto superior direito com visual moderno
- ✅ **Indicador de limite**: Muda de cor quando se aproxima do limite máximo
- ✅ **Totalmente compatível**: Funciona com todos os parâmetros do TextField padrão

## Como Usar

### Substituindo um TextField Existente

**ANTES:**
```dart
TextField(
  controller: _documentoController,
  maxLength: 14,
  buildCounter: _buildContador, // Remover esta linha
  focusNode: _documentoFocusNode,
  decoration: _getInputDecoration(context, 'Documento', 'documento'),
  onSubmitted: (_) {
    // sua lógica
  },
)
```

**DEPOIS:**
```dart
CharacterCounterField(
  controller: _documentoController,
  maxLength: 14,
  labelText: 'Documento', // Adicionar o nome do campo
  focusNode: _documentoFocusNode,
  decoration: _getInputDecoration(context, 'Documento', 'documento'),
  onSubmitted: (_) {
    // sua lógica
  },
)
```

### Parâmetros Principais

| Parâmetro | Tipo | Obrigatório | Descrição |
|-----------|------|-------------|-----------|
| `controller` | TextEditingController | ✅ Sim | Controlador do campo |
| `decoration` | InputDecoration | ✅ Sim | Decoração do campo |
| `maxLength` | int? | ❌ Não | Limite máximo de caracteres (padrão: 255) |
| `labelText` | String? | ❌ Não | Nome do campo exibido no contador |
| `focusNode` | FocusNode? | ❌ Não | Nó de foco (criado automaticamente se não fornecido) |
| `onChanged` | ValueChanged<String>? | ❌ Não | Callback quando o texto muda |
| `onSubmitted` | ValueChanged<String>? | ❌ Não | Callback quando o usuário submete |
| `maxLines` | int? | ❌ Não | Número máximo de linhas (padrão: 1) |
| `readOnly` | bool | ❌ Não | Se o campo é somente leitura (padrão: false) |

### Exemplo Completo

```dart
CharacterCounterField(
  controller: _observacaoController,
  maxLength: 255,
  labelText: 'Observação',
  focusNode: _observacaoFocusNode,
  maxLines: 3,
  decoration: _getInputDecoration(
    context,
    'Observação',
    'observacao',
  ),
  onChanged: (value) {
    // Lógica quando o texto muda
  },
  onSubmitted: (value) {
    // Lógica quando o usuário pressiona Enter
  },
)
```

## Comportamento Visual

### Estado Normal (sem foco)
- O campo aparece normalmente, sem contador visível
- Funciona exatamente como um TextField padrão

### Estado Focado
- Um badge aparece no canto superior direito do campo
- Mostra: `[Nome do Campo]  [atual] / [máximo]`
- Exemplo: `Documento  5 / 14`

### Indicador de Limite
- **Verde/Cinza**: Quando está abaixo de 90% do limite
- **Laranja**: Quando ultrapassa 90% do limite (alerta visual)

## Aplicação em Todo o Sistema

Para aplicar este widget em todo o sistema, siga estes passos:

### 1. Importar o Widget

No topo do arquivo onde você quer usar:

```dart
import '../../shared/widgets/character_counter_field.dart';
```

### 2. Identificar Campos para Substituir

Procure por padrões como:
- `TextField(` com `maxLength`
- `TextField(` com `buildCounter`
- Qualquer campo de entrada de texto que se beneficiaria de um contador

### 3. Substituir Gradualmente

Recomendamos substituir os campos em ordem de prioridade:

**Alta Prioridade:**
- ✅ Campos de formulários principais (Dashboard, Cadastros)
- ✅ Campos com limite de caracteres visível

**Média Prioridade:**
- ⏳ Campos de filtros e buscas
- ⏳ Campos de modais e diálogos

**Baixa Prioridade:**
- ⏳ Campos raramente usados
- ⏳ Campos de configuração

## Exemplos de Uso no Sistema

### Dashboard - Entrada de Visitantes

```dart
// Campo Documento
CharacterCounterField(
  controller: _documentoController,
  maxLength: 14,
  labelText: 'Documento',
  focusNode: _documentoFocusNode,
  decoration: _getInputDecoration(context, 'Documento', 'documento'),
)

// Campo Nome
CharacterCounterField(
  controller: _nomeController,
  maxLength: 50,
  labelText: 'Nome e Sobrenome',
  focusNode: _nomeFocusNode,
  decoration: _getInputDecoration(context, 'Nome e Sobrenome', 'nome'),
)

// Campo Observação
CharacterCounterField(
  controller: _obsController,
  maxLength: 255,
  labelText: 'Observação',
  focusNode: _obsFocusNode,
  maxLines: 3,
  decoration: _getInputDecoration(context, 'Observação', 'observacao'),
)
```

### Filtros

```dart
CharacterCounterField(
  controller: _filtroNomeController,
  maxLength: 50,
  labelText: 'Nome',
  decoration: _getInputDecoration(context, 'Nome', 'filtro_nome'),
)
```

## Notas Técnicas

### Gerenciamento de Estado
- O widget gerencia seu próprio estado de foco
- Se você não fornecer um `FocusNode`, um será criado automaticamente
- O widget se inscreve nos listeners do controller para atualizar em tempo real

### Performance
- O contador só renderiza quando o campo está focado
- Usa `AnimatedOpacity` para transições suaves
- Não impacta a performance de campos não focados

### Compatibilidade
- Funciona com todos os tipos de `InputDecoration`
- Compatível com temas claro e escuro
- Respeita todas as propriedades do TextField padrão

## Troubleshooting

### O contador não aparece
- ✅ Verifique se `maxLength` está definido
- ✅ Verifique se o campo está recebendo foco
- ✅ Verifique se não há overlays bloqueando a visualização

### O contador está cortado
- ✅ Certifique-se de que o widget pai tem espaço suficiente no topo
- ✅ Adicione padding superior se necessário: `padding: EdgeInsets.only(top: 24)`

### O nome do campo não aparece corretamente
- ✅ Defina explicitamente o parâmetro `labelText`
- ✅ O widget tenta extrair do `decoration.labelText` se não fornecido

## Próximos Passos

1. ✅ Widget criado e testado
2. ✅ Exemplos implementados no Dashboard
3. ⏳ Aplicar em todos os formulários principais
4. ⏳ Aplicar em filtros e buscas
5. ⏳ Aplicar em modais e diálogos
6. ⏳ Documentar casos especiais

## Suporte

Para dúvidas ou problemas, consulte:
- Este documento
- Exemplos no arquivo `dashboard.dart` (linhas 3545-3596)
- Código fonte: `lib/shared/widgets/character_counter_field.dart`
