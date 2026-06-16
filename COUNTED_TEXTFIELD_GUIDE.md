# Guia de Uso: CountedTextField

## 📝 Descrição
O `CountedTextField` é um widget customizado que adiciona automaticamente um contador de caracteres no label de campos de texto, mostrando o formato "Label X/Y" onde:
- **X** = número atual de caracteres digitados
- **Y** = limite máximo de caracteres

## 🎯 Como Usar

### 1. Importar o Widget
```dart
import '../../shared/widgets/counted_text_field.dart';
```

### 2. Substituir TextField por CountedTextField

#### ❌ ANTES (TextField normal):
```dart
TextField(
  controller: _documentoController,
  decoration: InputDecoration(
    labelText: 'Documento',
    border: OutlineInputBorder(),
  ),
  maxLength: 14,
  keyboardType: TextInputType.number,
  onChanged: (value) {
    // ...
  },
)
```

#### ✅ DEPOIS (CountedTextField):
```dart
CountedTextField(
  controller: _documentoController,
  labelText: 'Documento',
  maxLength: 14,
  keyboardType: TextInputType.number,
  onChanged: (value) {
    // ...
  },
)
```

### 3. Exemplos de Uso

#### Exemplo 1: Campo de Documento (CPF/CNPJ)
```dart
CountedTextField(
  controller: _documentoController,
  labelText: 'Documento',
  maxLength: 14,
  keyboardType: TextInputType.number,
  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  onChanged: (value) => _onDocumentoChanged(value),
)
```

#### Exemplo 2: Campo de Nome
```dart
CountedTextField(
  controller: _nomeController,
  labelText: 'Nome',
  maxLength: 50,
  textCapitalization: TextCapitalization.words,
  onChanged: (value) => setState(() {}),
)
```

#### Exemplo 3: Campo de Placa
```dart
CountedTextField(
  controller: _placaController,
  labelText: 'Placa',
  maxLength: 7,
  textCapitalization: TextCapitalization.characters,
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
  ],
)
```

#### Exemplo 4: Campo de Observações (Multilinha)
```dart
CountedTextField(
  controller: _obsController,
  labelText: 'Observações',
  maxLength: 200,
  maxLines: 3,
  minLines: 1,
)
```

## 🔧 Propriedades Disponíveis

| Propriedade | Tipo | Obrigatório | Descrição |
|------------|------|-------------|-----------|
| `labelText` | String | ✅ Sim | Texto do label (sem o contador) |
| `maxLength` | int? | ❌ Não | Limite máximo de caracteres |
| `controller` | TextEditingController? | ❌ Não | Controller do campo |
| `keyboardType` | TextInputType? | ❌ Não | Tipo de teclado |
| `inputFormatters` | List<TextInputFormatter>? | ❌ Não | Formatadores de entrada |
| `onChanged` | ValueChanged<String>? | ❌ Não | Callback ao mudar o texto |
| `enabled` | bool | ❌ Não | Se o campo está habilitado (padrão: true) |
| `readOnly` | bool | ❌ Não | Se o campo é somente leitura (padrão: false) |
| `obscureText` | bool | ❌ Não | Se o texto deve ser obscurecido (padrão: false) |
| `textCapitalization` | TextCapitalization | ❌ Não | Capitalização automática |
| `maxLines` | int? | ❌ Não | Número máximo de linhas |
| `prefixIcon` | Widget? | ❌ Não | Ícone no início do campo |
| `suffixIcon` | Widget? | ❌ Não | Ícone no final do campo |
| `hintText` | String? | ❌ Não | Texto de dica |
| `decoration` | InputDecoration? | ❌ Não | Decoração customizada |

## 📋 Checklist de Migração

Para migrar todos os campos do projeto:

### Dashboard (dashboard.dart)
- [ ] Campo "Documento" (linha ~4613)
- [ ] Campo "Documento" (linha ~4783)
- [ ] Campo "Nome" (buscar por `labelText: 'Nome'`)
- [ ] Campo "Placa" (buscar por `labelText: 'Placa'`)
- [ ] Campo "Modelo" (buscar por `labelText: 'Modelo'`)
- [ ] Outros campos de texto...

### Outras Telas
- [ ] Encomendas (encomenda_*.dart)
- [ ] Unidades (unidade_*.dart)
- [ ] Sidebar (sidebar.dart)
- [ ] Outras telas com TextField

## 💡 Dicas

1. **Sempre defina `maxLength`** quando usar `CountedTextField` para mostrar o contador
2. **Remova `counterText: ''`** da decoração, o widget já faz isso automaticamente
3. **Use `textCapitalization`** para campos de nome (words) e placa (characters)
4. **Combine com `inputFormatters`** para validação de entrada

## 🚀 Benefícios

✅ **Consistência**: Todos os campos terão o mesmo padrão visual
✅ **Feedback**: Usuário sabe quantos caracteres pode digitar
✅ **Reutilizável**: Um único widget para todos os campos
✅ **Manutenível**: Mudanças no padrão afetam todos os campos
✅ **Acessível**: Melhor UX para o usuário

---

**Criado em**: 2026-02-10
**Autor**: Antigravity AI Assistant
