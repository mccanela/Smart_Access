import 'package:flutter/material.dart';

/// Classe para gerenciar cores dos ícones conforme especificação do design
/// Suporta modo claro e escuro com cores específicas para cada tipo de ícone
class IconColors {
  // ========================================
  // MODO CLARO (Light Mode)
  // ========================================

  /// 📷 Câmera - Azul tecnológico
  static const Color cameraLight = Color(0xFF2563EB);

  /// 🚚 Caminhão - Laranja logística
  static const Color truckLight = Color(0xFFF59E0B);

  /// 🧽 Borracha/Delete - Roxo edição
  static const Color deleteLight = Color(0xFF7C3AED);

  /// ▶️ Play - Verde ação
  static const Color playLight = Color(0xFF22C55E);

  /// 🔍 Lupa/Search - Azul claro busca
  static const Color searchLight = Color(0xFF0EA5E9);

  /// ✉️ Envelope/Mail - Verde-azulado comunicação
  static const Color mailLight = Color(0xFF14B8A6);

  /// 🚫 Badge "OFF" - Vermelho alerta
  static const Color alertLight = Color(0xFFEF4444);

  // ========================================
  // MODO ESCURO (Dark Mode)
  // ========================================

  /// 📷 Câmera - Azul suave tecnológico
  static const Color cameraDark = Color(0xFF60A5FA);

  /// 🚚 Caminhão - Laranja suave
  static const Color truckDark = Color(0xFFFBBF24);

  /// 🧽 Borracha/Delete - Roxo suave
  static const Color deleteDark = Color(0xFFA78BFA);

  /// ▶️ Play - Verde ação suave
  static const Color playDark = Color(0xFF4ADE80);

  /// 🔍 Lupa/Search - Azul claro
  static const Color searchDark = Color(0xFF38BDF8);

  /// ✉️ Envelope/Mail - Verde-água
  static const Color mailDark = Color(0xFF2DD4BF);

  /// 🚫 Badge "OFF" - Vermelho suave (alerta sem agressividade)
  static const Color alertDark = Color(0xFFF87171);

  // ========================================
  // MÉTODOS AUXILIARES
  // ========================================

  /// Retorna a cor da câmera baseada no tema atual
  static Color camera(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? cameraDark
        : cameraLight;
  }

  /// Retorna a cor do caminhão baseada no tema atual
  static Color truck(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? truckDark
        : truckLight;
  }

  /// Retorna a cor do delete/borracha baseada no tema atual
  static Color delete(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? deleteDark
        : deleteLight;
  }

  /// Retorna a cor do play baseada no tema atual
  static Color play(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? playDark
        : playLight;
  }

  /// Retorna a cor da busca/lupa baseada no tema atual
  static Color search(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? searchDark
        : searchLight;
  }

  /// Retorna a cor do mail/envelope baseada no tema atual
  static Color mail(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? mailDark
        : mailLight;
  }

  /// Retorna a cor do alerta baseada no tema atual
  static Color alert(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? alertDark
        : alertLight;
  }

  /// Retorna a opacidade para ícones inativos (80%)
  static double get inactiveOpacity => 0.8;

  /// Retorna a opacidade para ícones ativos (100%)
  static double get activeOpacity => 1.0;

  /// Aplica opacidade a uma cor
  static Color withOpacity(Color color, {bool isActive = true}) {
    return color.withValues(alpha: isActive ? activeOpacity : inactiveOpacity);
  }
}
