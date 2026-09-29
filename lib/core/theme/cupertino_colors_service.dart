import 'package:flutter/cupertino.dart';

/// Serviço centralizado para as cores do padrão Cupertino (iOS).
/// Utilizar esta classe garante consistência visual e facilita a
/// manutenção do Design System do aplicativo.
class CupertinoColorsService {
  // Construtor privado para evitar instanciamento (Utility Class)
  CupertinoColorsService._();

  static Color tabBar1 =
      (CupertinoColors.systemMint as CupertinoDynamicColor).highContrastColor;
  static Color tabBar2 =
      (CupertinoColors.systemCyan as CupertinoDynamicColor).highContrastColor;

  static Color tabBar3 =
      (CupertinoColors.systemPurple as CupertinoDynamicColor).highContrastColor;

  static Color tabBar4 =
      (CupertinoColors.systemOrange as CupertinoDynamicColor).highContrastColor;

  // ---------------------------------------------------------
  // CORES DE AÇÃO (Usadas em botões, links e interações)
  // ---------------------------------------------------------
  static const Color activeBlue = CupertinoColors.activeBlue;
  static const Color activeGreen = CupertinoColors.activeGreen;
  static const Color activeOrange = CupertinoColors.activeOrange;
  static const Color destructiveRed = Color.fromARGB(255, 250, 22, 10);

  // ---------------------------------------------------------
  // CORES DO SISTEMA (Cores dinâmicas que se adaptam ao Dark/Light mode)
  // ---------------------------------------------------------

  static const Color systemRed = CupertinoColors.systemRed;

  static const Color systemOrange = CupertinoColors.systemOrange;
  static const Color systemYellow = CupertinoColors.systemYellow;
  static const Color systemGreen = CupertinoColors.systemGreen;
  static const Color systemMint = CupertinoColors.systemMint;
  static const Color systemTeal = CupertinoColors.systemTeal;
  static const Color systemCyan = CupertinoColors.systemCyan;
  static const Color systemBlue = CupertinoColors.systemBlue;
  static const Color systemIndigo = Color(0xFF7C4DFF);

  static const Color systemPurple = CupertinoColors.systemPurple;
  static const Color systemPink = CupertinoColors.systemPink;
  static const Color systemBrown = CupertinoColors.systemBrown;

  // ---------------------------------------------------------
  // TONS DE CINZA DO SISTEMA (Usados para hierarquia de UI, bordas, etc.)
  // ---------------------------------------------------------
  static const Color systemGrey = CupertinoColors.systemGrey;
  static const Color systemGrey2 = CupertinoColors.systemGrey2;
  static const Color systemGrey3 = CupertinoColors.systemGrey3;
  static const Color systemGrey4 = CupertinoColors.systemGrey4;
  static const Color systemGrey5 = CupertinoColors.systemGrey5;
  static const Color systemGrey6 = CupertinoColors.systemGrey6;

  // ---------------------------------------------------------
  // CORES BÁSICAS DE FUNDO E TEXTO
  // ---------------------------------------------------------
  static const Color black = CupertinoColors.black;
  static const Color white = CupertinoColors.white;

  // Fundos de sistema agrupados genéricos
  static const Color lightBackgroundGray = CupertinoColors.lightBackgroundGray;
  static const Color extraLightBackgroundGray =
      CupertinoColors.extraLightBackgroundGray;
  static const Color darkBackgroundGray = CupertinoColors.darkBackgroundGray;
  static const Color inactiveGray = CupertinoColors.inactiveGray;

  // ---------------------------------------------------------
  // CORES DINÂMICAS DE BACKGROUND (iOS 13+)
  // ---------------------------------------------------------
  // Estas cores ajustam automaticamente sua elevação e tom
  // dependendo se estão em base ou elevated (modais).
  static const Color systemBackground = CupertinoColors.systemBackground;
  static const Color secondarySystemBackground =
      CupertinoColors.secondarySystemBackground;
  static const Color tertiarySystemBackground =
      CupertinoColors.tertiarySystemBackground;

  static const Color systemGroupedBackground =
      CupertinoColors.systemGroupedBackground;
  static const Color secondarySystemGroupedBackground =
      CupertinoColors.secondarySystemGroupedBackground;
  static const Color tertiarySystemGroupedBackground =
      CupertinoColors.tertiarySystemGroupedBackground;

  // ---------------------------------------------------------
  // CORES DINÂMICAS DE PREENCHIMENTO (Fill Colors)
  // ---------------------------------------------------------
  static const Color systemFill = CupertinoColors.systemFill;
  static const Color secondarySystemFill = CupertinoColors.secondarySystemFill;
  static const Color tertiarySystemFill = CupertinoColors.tertiarySystemFill;
  static const Color quaternarySystemFill =
      CupertinoColors.quaternarySystemFill;

  // ---------------------------------------------------------
  // CORES DE TEXTO DINÂMICAS (Labels)
  // ---------------------------------------------------------
  static const Color label = CupertinoColors.label;
  static const Color secondaryLabel = CupertinoColors.secondaryLabel;
  static const Color tertiaryLabel = CupertinoColors.tertiaryLabel;
  static const Color quaternaryLabel = CupertinoColors.quaternaryLabel;

  /// Retorna uma cor customizada que respeita o tema atual (Claro/Escuro)
  /// Caso você precise criar cores fora do padrão estrito da Apple.
  static Color customDynamicColor({
    required Color lightColor,
    required Color darkColor,
  }) {
    return CupertinoDynamicColor.withBrightness(
      color: lightColor,
      darkColor: darkColor,
    );
  }
}
