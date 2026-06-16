# 📁 Estrutura do Projeto Flutter - ConectCon

## 🎯 **Visão Geral**
Este projeto segue uma arquitetura organizada baseada em **Feature-First** com separação clara de responsabilidades, facilitando manutenção e escalabilidade.

## 📂 **Estrutura de Pastas**

### **🏗️ Core (Núcleo da Aplicação)**
```
core/
├── config/                 # ⚙️ Configurações da aplicação
│   ├── api_config.dart    # Configurações de API
│   └── theme.dart         # Tema e estilos globais
├── localization/          # 🌍 Internacionalização
│   └── app_localizations.dart
├── services/              # 🔧 Serviços da aplicação
│   ├── cache_service.dart # Cache local
│   ├── crypto_utils.dart  # Utilitários de criptografia
│   ├── feedback_utils.dart # Utilitários de feedback
│   ├── image_utils.dart   # Processamento de imagens
│   └── search_service.dart # Serviço de busca
└── utils/                 # 🛠️ Utilitários diversos
    ├── pdf_text_extractor.dart
    └── ui_standards.dart  # Padrões de UI
```

### **🎨 Features (Funcionalidades)**
```
features/
├── auth/                  # 🔐 Autenticação
│   └── login.dart
├── dashboard/             # 📊 Dashboard principal
│   ├── dashboard.dart     # Tela principal
│   ├── dashboard_panels.dart # Paineis do dashboard
│   └── sidebar.dart       # Barra lateral
├── modals/                # 📱 Modais da aplicação
│   ├── alertas_modal.dart
│   ├── chaves_modal.dart
│   ├── condominio_modal.dart
│   ├── ocorrencias_modal.dart
│   ├── ramais_modal.dart
│   └── turnos_modal.dart
├── encomendas/            # 📦 Sistema de encomendas
│   ├── encomenda_entrega_screen.dart
│   └── encomenda_selecao_pessoa_screen.dart
├── search/                # 🔍 Sistema de busca
│   ├── search_screen.dart
│   └── search_result.dart
├── unidades/              # 🏢 Gestão de unidades
│   └── unidade_detalhe_screen.dart
└── gate/                  # 🚪 Sistema de portaria
    └── gate_system.dart
```

### **🔄 Shared (Compartilhado)**
```
shared/
├── models/               # 📋 Modelos de dados (vazio)
├── widgets/              # 🎛️ Widgets compartilhados
│   ├── custom_buttom.dart
│   ├── custom_imput.dart
│   ├── feedback_modal.dart
│   ├── not_found.dart
│   ├── registro_dispositivos_page.dart
│   ├── screen_header.dart
│   ├── side_panel.dart
│   └── tab_button.dart
└── constants/            # 📏 Constantes
    └── document.dart
```

## 📋 **Convenções de Nomenclatura**

### **📁 Pastas**
- `snake_case` para nomes de pastas
- Nomes descritivos em português quando aplicável

### **📄 Arquivos**
- `snake_case` para nomes de arquivos
- Sufixo descritivo: `_screen.dart`, `_modal.dart`, `_service.dart`, etc.

### **🔧 Imports**
```dart
// Imports organizados por categoria:
// 1. Flutter/Dart
import 'package:flutter/material.dart';

// 2. Pacotes externos
import 'package:provider/provider.dart';

// 3. Core
import '../core/config/api_config.dart';
import '../core/services/cache_service.dart';

// 4. Shared
import '../shared/widgets/custom_button.dart';

// 5. Features (relativo)
import 'dashboard_panels.dart';
```

## 🎯 **Princípios de Organização**

### **📦 Separação por Responsabilidade**
- **Core**: Lógica central, independente de features
- **Features**: Funcionalidades específicas, autocontidas
- **Shared**: Componentes reutilizáveis

### **🔄 Dependências**
- Features podem depender de Core e Shared
- Shared pode depender apenas de Core
- Core não depende de ninguém

### **🧪 Testabilidade**
- Cada feature pode ser testada isoladamente
- Widgets compartilhados têm testes independentes

## 🚀 **Como Usar**

### **Adicionando uma Nova Feature**
```bash
# Criar estrutura
mkdir -p features/nova_feature/{screens,services,widgets}

# Arquivos
touch features/nova_feature/nova_feature_screen.dart
touch features/nova_feature/nova_feature_service.dart
```

### **Adicionando um Widget Compartilhado**
```bash
# Na pasta shared/widgets/
touch shared/widgets/meu_widget.dart
```

### **Adicionando um Serviço**
```bash
# Na pasta core/services/ ou features/*/services/
touch core/services/meu_servico.dart
```

## 🧹 **Manutenção**

### **Removendo Código Não Utilizado**
- Use `flutter pub run dart_code_metrics:metrics analyze` para detectar código morto
- Remova imports não utilizados automaticamente com VSCode
- Execute `flutter clean` regularmente

### **Atualizando Estrutura**
- Mantenha este README atualizado
- Documente mudanças significativas na estrutura
- Use commits descritivos para mudanças na organização

## 📊 **Métricas da Estrutura**

- **Total de arquivos**: ~35 arquivos .dart
- **Pastas organizacionais**: 12 pastas
- **Separação clara**: Core/Features/Shared
- **Manutenibilidade**: Alta
- **Escalabilidade**: Preparado para crescimento

---

## 🎨 **Padrões Visuais**

### **Cores Principais**
- **Primary**: Azul (#2E74FF)
- **Secondary**: Roxo (#7C4DFF)
- **Success**: Verde (#00C853)
- **Error**: Vermelho (#FF5252)

### **Componentes**
- **Botões**: Padrão transparente com ícones
- **Cards**: Fundo dinâmico com bordas sutis
- **Segmented Controls**: Ícones expansíveis
- **Modais**: Largura responsiva

### **Responsividade**
- **Mobile**: < 800px
- **Tablet**: 800px - 1366px
- **Desktop**: > 1366px

---

**Mantido por**: Equipe de Desenvolvimento ConectCon
**Última atualização**: $(date)
