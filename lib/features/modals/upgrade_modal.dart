import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/ui_standards.dart';
import '../../shared/widgets/screen_header.dart';

/// Painel Lateral de Upgrade para o Smart Access
class UpgradeModal extends StatefulWidget {
  final VoidCallback? onClose;
  const UpgradeModal({super.key, this.onClose});

  @override
  State<UpgradeModal> createState() => _UpgradeModalState();
}

class _UpgradeModalState extends State<UpgradeModal> {
  bool _isSmartAccess = false; // se tem SmartAccess

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isSmartAccess = prefs.getBool('is_smart_access') ?? false;
        });
      }
    } catch (e) {
      print('Erro ao carregar is_smart_access: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    final onCloseCallback = widget.onClose ?? () => Navigator.of(context).pop();

    // Se o usuário já tiver Smart Access, exibe uma mensagem de sucesso no painel
    if (_isSmartAccess) {
      return Container(
        decoration: BoxDecoration(
          color: getBackgroundColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: isDarkMode(context)
                  ? Colors.white.withOpacity(0.2)
                  : Colors.transparent,
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            ScreenHeader(
              icon: Icons.rocket_launch,
              title: 'Upgrade Smart Access',
              onClose: onCloseCallback,
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Colors.green, size: 60),
                    const SizedBox(height: 16),
                    const Text(
                      'Você já possui o Smart Access!',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: onCloseCallback,
                      child: const Text('Fechar'),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Painel principal de vendas
    return Container(
      width: double.infinity, // Ocupa toda a largura do painel lateral
      height: double.infinity, // Ocupa toda a altura do painel lateral
      decoration: BoxDecoration(
        color: getBackgroundColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: isDarkMode(context)
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Cabeçalho da janela
          ScreenHeader(
            icon: Icons.auto_awesome,
            title: 'Upgrade Smart Access',
            onClose: onCloseCallback,
          ),
          // Imagem flexível ocupando 100% do espaço restante
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  // Abre o WhatsApp em uma nova aba
                  html.window.open(
                    'https://wa.me/5511934896606?text=Sou%20cliente%20e%20gostaria%20de%20conhecer%20a%20solu%C3%A7%C3%A3o%20SMART%20ACCESS.',
                    '_blank',
                  );
                },
                child: ClipRRect(
                  // Mantendo o design arredondado nas pontas inferiores do painel
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: Image.network(
                    'https://pub-9313ea4eec6c404c845254ee76d0a174.r2.dev/geral/novia-c-upsell.jpg',
                    fit: BoxFit
                        .cover, // Isso garante que a imagem estique para cobrir 100% do container, sem sobrar bordas pretas/brancas!
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
