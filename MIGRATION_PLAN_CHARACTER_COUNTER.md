# 📋 Plano de Migração: TextField → CharacterCounterField

## ✅ Widget Existente
Já existe um widget `CharacterCounterField` em:
```
lib/shared/widgets/character_counter_field.dart
```

## 📊 Status Atual
- **Total de TextFields**: ~44
- **Já migrados**: 4
- **Pendentes**: ~40

## 🎯 Objetivo
Substituir todos os `TextField` por `CharacterCounterField` para ter contador de caracteres consistente em todos os campos digitáveis.

## 📝 Como Migrar

### Passo 1: Importar o Widget
Adicione no topo do arquivo (se ainda não estiver):
```dart
import '../../shared/widgets/character_counter_field.dart';
```

### Passo 2: Substituir TextField

#### ❌ ANTES:
```dart
TextField(
  controller: _nomeController,
  decoration: InputDecoration(
    labelText: 'Nome',
    border: OutlineInputBorder(),
  ),
  maxLength: 50,
  keyboardType: TextInputType.text,
  onChanged: (value) {
    setState(() {});
  },
)
```

#### ✅ DEPOIS:
```dart
CharacterCounterField(
  controller: _nomeController,
  labelText: 'Nome',  // ← IMPORTANTE: Adicionar esta propriedade
  maxLength: 50,
  decoration: InputDecoration(
    border: OutlineInputBorder(),
    // NÃO incluir labelText aqui, vai no parâmetro labelText acima
  ),
  keyboardType: TextInputType.text,
  onChanged: (value) {
    setState(() {});
  },
)
```

### ⚠️ IMPORTANTE
- **Mova `labelText` da `decoration` para um parâmetro direto**
- **Remova `labelText` de dentro de `InputDecoration`**
- **Mantenha outras propriedades da `decoration` (border, prefixIcon, etc.)**

## 📍 Campos Prioritários para Migrar

### Dashboard - Aba "Passagens"
```dart
// Linha ~5918 - Campo de busca de documento
CharacterCounterField(
  controller: _documentoHistoricoController,
  labelText: 'Documento',
  maxLength: 14,
  decoration: _getInputDecoration(context, 'Documento', 'documento'),
  keyboardType: TextInputType.number,
  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
)

// Linha ~5931 - Campo de nome
CharacterCounterField(
  controller: _nomeHistoricoController,
  labelText: 'Nome',
  maxLength: 100,
  decoration: _getInputDecoration(context, 'Nome', 'nome'),
)

// Linha ~5950 - Campo de placa
CharacterCounterField(
  controller: _placaHistoricoController,
  labelText: 'Placa',
  maxLength: 7,
  decoration: _getInputDecoration(context, 'Placa', 'placa'),
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
  ],
)
```

### Dashboard - Aba "Unidades"
```dart
// Linha ~6880 - Campo de busca
CharacterCounterField(
  controller: _unidadeSearchController,
  labelText: 'Buscar unidade',
  maxLength: 50,
  decoration: InputDecoration(
    prefixIcon: Icon(Icons.search),
    border: OutlineInputBorder(),
  ),
)
```

### Dashboard - Modal de Cadastro
```dart
// Linha ~9667 - Nome
CharacterCounterField(
  controller: _nomeController,
  labelText: 'Nome',
  maxLength: 100,
  decoration: InputDecoration(border: OutlineInputBorder()),
)

// Linha ~9714 - RG
CharacterCounterField(
  controller: _rgController,
  labelText: 'RG',
  maxLength: 20,
  decoration: InputDecoration(border: OutlineInputBorder()),
)

// Linha ~9843 - Placa
CharacterCounterField(
  controller: _placaController,
  labelText: 'Placa',
  maxLength: 7,
  decoration: InputDecoration(border: OutlineInputBorder()),
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
  ],
)

// Linha ~9896 - Modelo
CharacterCounterField(
  controller: _modeloController,
  labelText: 'Modelo',
  maxLength: 50,
  decoration: InputDecoration(border: OutlineInputBorder()),
)
```

## 🔍 Como Encontrar Campos para Migrar

### Método 1: Busca por Padrão
Procure por:
```
TextField(
```

### Método 2: Busca por LabelText
Procure por:
```
labelText: '
```
E veja se o TextField pai já é `CharacterCounterField`

### Método 3: Busca por MaxLength
Procure por:
```
maxLength:
```
Todos os campos com `maxLength` DEVEM usar `CharacterCounterField`

## ✅ Checklist de Migração

### Dashboard (dashboard.dart)
- [x] Documento (linha 4610) ✅ JÁ MIGRADO
- [x] Nome (linha 4649) ✅ JÁ MIGRADO  
- [x] Documento (linha 4780) ✅ JÁ MIGRADO
- [x] Nome (linha 4819) ✅ JÁ MIGRADO
- [ ] Campo de busca (linha ~623)
- [ ] Campo de filtro (linha ~3877)
- [ ] Placa (linha ~4946)
- [ ] Modelo (linha ~4963)
- [ ] RG (linha ~4983)
- [ ] Observações (linha ~5004)
- [ ] Autorizante (linha ~5026)
- [ ] Documento histórico (linha ~5918)
- [ ] Nome histórico (linha ~5931)
- [ ] Placa histórico (linha ~5950)
- [ ] Data histórico (linha ~5963)
- [ ] Busca unidade (linha ~6880)
- [ ] Filtro unidade (linha ~6905)
- [ ] Código barras (linha ~6962)
- [ ] Observações encomenda (linha ~7254)
- [ ] Nome cadastro (linha ~9667)
- [ ] RG cadastro (linha ~9714)
- [ ] Placa cadastro (linha ~9843)
- [ ] Modelo cadastro (linha ~9896)
- [ ] E mais ~20 campos...

### Outras Telas
- [ ] Encomendas (encomenda_*.dart)
- [ ] Unidades (unidade_*.dart)
- [ ] Sidebar (sidebar.dart)

## 🚀 Benefícios Após Migração

✅ **Consistência Visual**: Todos os campos terão o mesmo padrão
✅ **Melhor UX**: Usuário sempre sabe quantos caracteres pode digitar
✅ **Validação Visual**: Fácil ver quando está chegando no limite
✅ **Profissional**: Interface mais polida e moderna

## 💡 Dica de Produtividade

Use "Find & Replace" com Regex no VS Code:

**Buscar:**
```regex
TextField\(\s*controller:\s*(\w+),\s*decoration:\s*InputDecoration\(\s*labelText:\s*'([^']+)',
```

**Substituir por:**
```
CharacterCounterField(
  controller: $1,
  labelText: '$2',
  decoration: InputDecoration(
```

⚠️ **ATENÇÃO**: Sempre revise manualmente após usar Find & Replace!

---

**Criado em**: 2026-02-10
**Status**: 🟡 Em Progresso (4/44 migrados)
