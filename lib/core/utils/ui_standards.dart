import 'package:flutter/material.dart';

//===============================================================//
// PADRÕES VISUAIS UNIFICADOS PARA TODAS AS TELAS DO SISTEMA
//===============================================================//

// Paleta de cores padrão
class AppColors {
  static const ColorScheme colorScheme = ColorScheme.light(
    primary: Color(0xFF684F8E), // Roxo padronizado
    secondary: Color(0xFF7C5BBE), // Roxo claro
    surface: Colors.white, // Fundo das superfícies
    outline: Color(0xFFE53E3E), // Bordas vermelhas dos cards
  );

  // Omitir constantes para cores de texto para forçar o uso de helpers com context
  static const Color primary = Color(0xFF684F8E);
  static const Color secondary = Color(0xFF7C5BBE);
  static const Color surface = Colors.white;
  static const Color outline =
      Color(0xFFE53E3E); // Vermelho para bordas dos cards
}

//===============================================================//
// CONSTANTES DE ESPAÇAMENTO E LAYOUT
//===============================================================//

class AppSpacing {
  static const double containerPadding = 12.0;
  static const double containerMargin = 8.0;
  static const double fieldSpacing = 12.0; // Espaçamento entre campos
  static const double buttonHeight = 48.0; // Altura padrão dos botões
}

//===============================================================//
// MÉTODOS DE COR COMPARTILHADOS (PADRÃO DASHBOARD)
//===============================================================//

bool isDarkMode(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

Color getBackgroundColor(BuildContext context) {
  return isDarkMode(context) ? Colors.black : Colors.white;
}

Color getSurfaceColor(BuildContext context) {
  return isDarkMode(context) ? const Color(0xFF121212) : Colors.white;
}

Color getCardColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color(0xFF1E1E1E)
      : Colors.white;
}

Color getFormGrisColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color.fromARGB(255, 30, 30, 30)
      : const Color(0xFFF9FAFB);
}

Color getTextColor(BuildContext context) {
  return isDarkMode(context) ? Colors.white : Colors.black;
}

Color getSecondaryTextColor(BuildContext context) {
  return isDarkMode(context) ? Colors.white70 : Colors.black87;
}

Color getBorderColor(BuildContext context) {
  return isDarkMode(context) 
      ? const Color(0xFF4B5563) 
      : const Color(0xFFD1D5DB);
}

Color getDividerColor(BuildContext context) {
  return isDarkMode(context) ? Colors.grey[700]! : Colors.grey.shade200;
}

Color getShadowColor(BuildContext context) {
  return isDarkMode(context)
      ? Colors.black.withValues(alpha: 0.3)
      : Colors.black.withValues(alpha: 0.04);
}

Color getSecondaryBackgroundColor(BuildContext context) {
  return isDarkMode(context) ? const Color(0xFF4B5563) : Colors.grey.shade100;
}

//===============================================================//
// DECORAÇÃO PADRONIZADA PARA CONTAINERS
//===============================================================//

BoxDecoration containerDecoration() {
  return BoxDecoration(
    color: Colors.white,
    border: Border.all(color: Colors.black26, width: 1),
    borderRadius: BorderRadius.circular(10),
  );
}

BoxDecoration cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    border: Border.all(color: Colors.black26, width: 1),
    borderRadius: BorderRadius.circular(10),
  );
}

//-----------------------------//
// WIDGET DE SEÇÃO PADRONIZADO
//-----------------------------//
class FramedSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxConstraints? constraints;

  const FramedSection({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: constraints,
      decoration: containerDecoration(),
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin,
      child: child,
    );
  }
}

//===============================================================//
// DECORAÇÃO PADRONIZADA PARA CAMPOS DE TEXTO
//===============================================================//

InputDecoration inputDecorationPadrao(
  BuildContext context, {
  String? hintText,
  String? labelText,
  Widget? label,
  Widget? suffixIcon,
  Widget? prefixIcon,
  String? actualHint,
}) {
  final isDark = isDarkMode(context);
  return InputDecoration(
    labelText: label != null ? null : (labelText ?? hintText),
    label: label,
    hintText: null,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    labelStyle: TextStyle(
      color: isDark ? Colors.white70 : Colors.black,
      fontSize: 16,
      fontWeight: FontWeight.w300,
    ),
    hintStyle: TextStyle(
      color: isDark ? Colors.white38 : Colors.black38,
      fontSize: 16,
      fontWeight: FontWeight.w300,
    ),
    filled: true,
    fillColor: isDark ? const Color.fromARGB(255, 40, 40, 40) : Colors.white,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
        width: 1,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
        width: 1,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(
        color: AppColors.primary,
        width: 1.5,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(
        color: Colors.red,
        width: 1.5,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(
        color: Colors.red,
        width: 1.5,
      ),
    ),
    isDense: true,
  );
}

//===============================================================//
// CAMPOS DE TEXTO RESPONSIVOS
//===============================================================//

class AppTextField {
  static Widget responsiveTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      maxLines: maxLines,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: inputDecorationPadrao(
        context,
        labelText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
      style: TextStyle(
        fontSize: 16,
        color: getTextColor(context),
        fontWeight: FontWeight.w400,
      ),
      onChanged: onChanged,
    );
  }
}

//===============================================================//
// BOTÕES PADRONIZADOS
//===============================================================//

class AppButtons {
  static ElevatedButton primaryButton({
    required VoidCallback? onPressed,
    required String text,
    bool loading = false,
    IconData? icon,
    double? width,
  }) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        minimumSize: Size(width ?? double.infinity, AppSpacing.buttonHeight),
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                Flexible(
                    child: Text(text,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold))),
              ],
            ),
    );
  }

  static ElevatedButton secondaryButton({
    required VoidCallback? onPressed,
    required String text,
    bool loading = false,
    IconData? icon,
    double? width,
  }) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        elevation: 1,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        minimumSize: Size(width ?? double.infinity, AppSpacing.buttonHeight),
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 8)],
                Flexible(
                    child: Text(text,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500))),
              ],
            ),
    );
  }

  static OutlinedButton outlineButton({
    required BuildContext context,
    required VoidCallback? onPressed,
    required String text,
    IconData? icon,
    double? width,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: getTextColor(context),
        side: BorderSide(color: getBorderColor(context), width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        minimumSize: Size(width ?? double.infinity, AppSpacing.buttonHeight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 8)],
          Flexible(
              child: Text(text,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

//===============================================================//
// TIPOGRAFIA PADRONIZADA
//===============================================================//

class AppTextStyles {
  static TextStyle title(BuildContext context) => getStyle(
    context,
    weight: FontWeight.bold,
    size: 16,
  );

  static TextStyle subtitle(BuildContext context) => getStyle(
    context,
    weight: FontWeight.w400,
    size: 16,
    isSecondary: true,
  );

  static TextStyle body(BuildContext context) => getStyle(
    context,
    weight: FontWeight.w400,
    size: 16,
  );

  static TextStyle getStyle(BuildContext context,
      {FontWeight weight = FontWeight.w400,
      double size = 16,
      bool isSecondary = false,
      bool isHint = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color;
    if (isHint) {
      color = isDark ? Colors.white54 : Colors.black54;
    } else if (isSecondary) {
      color = isDark ? Colors.white70 : Colors.black87;
    } else {
      color = isDark ? Colors.white : Colors.black;
    }
    return TextStyle(fontSize: size, fontWeight: weight, color: color);
  }
}

//===============================================================//
// LAYOUT PADRONIZADO
//===============================================================//

class AppLayout {
  static Widget twoColumnLayout({
    required Widget leftColumn,
    required Widget rightColumn,
    double spacing = 24.0,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Padding(padding: EdgeInsets.only(right: spacing / 2), child: leftColumn)),
          SizedBox(width: spacing),
          Expanded(child: Padding(padding: EdgeInsets.only(left: spacing / 2), child: rightColumn)),
        ],
      ),
    );
  }
}

//===============================================================//
// COMPONENTES DE ESTADO
//===============================================================//

class AppEmptyState {
  static Widget noData({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(message, style: AppTextStyles.getStyle(null as dynamic, isSecondary: true), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class AppLoading {
  static Widget loadingIndicator({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message),
          ],
        ],
      ),
    );
  }
}
