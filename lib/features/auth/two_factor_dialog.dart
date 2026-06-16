import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/api_config.dart';

/// Shows the two-factor authentication dialog.
/// Returns `true` if 2FA was validated successfully, `false` if cancelled.
Future<bool> showTwoFactorDialog({
  required BuildContext context,
  required String token,
  required int usuarioId,
  required int condominioId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _TwoFactorDialog(
      token: token,
      usuarioId: usuarioId,
      condominioId: condominioId,
    ),
  );
  return result ?? false;
}

class _TwoFactorDialog extends StatefulWidget {
  final String token;
  final int usuarioId;
  final int condominioId;

  const _TwoFactorDialog({
    required this.token,
    required this.usuarioId,
    required this.condominioId,
  });

  @override
  State<_TwoFactorDialog> createState() => _TwoFactorDialogState();
}

class _TwoFactorDialogState extends State<_TwoFactorDialog> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  bool _sending = false;
  String? _error;

  // Cores padrão do app (sidebar spec)
  static const Color _roxoEscuro = Color(0xFF451D6B);
  static const Color _roxoMedio = Color(0xFF9B3CBC);
  static const Color _azulEscuro = Color(0xFF10133E);
  static const Color _preto = Color(0xFF000000);
  // Cores dos campos (padrão login)
  static const Color _fieldBg = Color(0xFFF8FAFC);
  static const Color _fieldBorder = Color(0xFFE2E8F0);
  static const Color _fieldText = Color(0xFF0F172A);
  static const Color _fieldHint = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final url = Uri.parse(ApiConfig.getEndpoint('auth', 'sendTwoFactor'));
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'usuario_id': widget.usuarioId,
          'condominio_id': widget.condominioId,
        }),
      );
    } catch (e) {
      // Silently fail — user can tap resend
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _validateCode() async {
    final code = _code;
    if (code.length != 6) {
      setState(() => _error = 'Digite todos os 6 dígitos.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url =
          Uri.parse(ApiConfig.getEndpoint('auth', 'validateTwoFactor'));
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'usuario_id': widget.usuarioId,
          'condominio_id': widget.condominioId,
          'code': code,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // TODO: adjust success check based on actual API response structure
        final success = data['success'] == true ||
            data['status'] == true ||
            data['validated'] == true ||
            response.statusCode == 200;
        if (success) {
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
      }

      setState(() {
        _error = 'Código inválido. Tente novamente.';
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      });
    } catch (e) {
      setState(() => _error = 'Erro de conexão. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_code.length == 6) {
      _validateCode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top section — logo on dark purple (same as sidebar top)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: const BoxDecoration(
                  color: _roxoEscuro,
                ),
                child: Column(
                  children: [
                    // Logo — same as sidebar bottom logo
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: _preto,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _roxoMedio.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Image.asset(
                        'assets/images/0dc836ea-409a-4737-83c0-89532a174dcc-md-removebg-preview.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.security_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Two-Factor Authentication',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter the 6-digit verification code',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Middle section — form on dark blue (same as sidebar middle)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                color: _azulEscuro,
                child: Column(
                  children: [
                    // Error message (same style as login error)
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                const Color(0xFFEF4444).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFEF4444), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 6-digit input — fields match login style
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        return Container(
                          width: 48,
                          height: 56,
                          margin: EdgeInsets.only(
                            left: index == 0 ? 0 : 5,
                            right: index == 5 ? 0 : 5,
                          ),
                          decoration: BoxDecoration(
                            color: _fieldBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _fieldBorder),
                          ),
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            enabled: !_loading,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            style: const TextStyle(
                              color: _fieldText,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              hintText: '-',
                              hintStyle: const TextStyle(
                                color: _fieldHint,
                                fontSize: 20,
                              ),
                            ),
                            onChanged: (value) =>
                                _onDigitChanged(index, value),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    // Verify button — same style as login CONECTAR button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _validateCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _roxoMedio,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              _roxoMedio.withValues(alpha: 0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'VERIFY',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Resend & Cancel
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _sending ? null : _sendCode,
                          child: Text(
                            _sending ? 'Sending...' : 'Resend Code',
                            style: TextStyle(
                              color: _sending
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : _roxoMedio,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom section — black bar with branding (same as sidebar bottom)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                color: _preto,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Image.asset(
                        'assets/images/0dc836ea-409a-4737-83c0-89532a174dcc-md-removebg-preview.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ConectCon\u00AE - Blindagem Condominial',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
