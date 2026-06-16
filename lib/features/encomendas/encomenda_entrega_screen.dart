import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/widgets/screen_header.dart';
import '../../core/services/image_utils.dart';
import 'encomenda_selecao_pessoa_screen.dart';
import '../../core/services/crypto_utils.dart';
import '../../core/config/api_config.dart';
import '../../core/utils/ui_standards.dart';
import '../../shared/widgets/facial_capture_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a step
// ─────────────────────────────────────────────────────────────────────────────
class _StepInfo {
  final String label;
  final IconData icon;
  const _StepInfo(this.label, this.icon);
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────
class EncomendaEntregaScreen extends StatefulWidget {
  final Map<String, dynamic> encomenda;
  final Uint8List? fotoMorador;
  final Uint8List? fotoEncomenda;
  final VoidCallback onClose;
  final VoidCallback? onSelecionarPessoa;
  final Function(bool usarToken, String token, Uint8List? fotoMorador,
      Uint8List? fotoEncomenda)? onConfirmarEntrega;
  final ValueNotifier<Uint8List?>? fotoMoradorNotifier;

  const EncomendaEntregaScreen({
    super.key,
    required this.encomenda,
    this.fotoMorador,
    this.fotoEncomenda,
    required this.onClose,
    this.onSelecionarPessoa,
    this.onConfirmarEntrega,
    this.fotoMoradorNotifier,
  });

  @override
  State<EncomendaEntregaScreen> createState() => _EncomendaEntregaScreenState();
}

class _EncomendaEntregaScreenState extends State<EncomendaEntregaScreen> {
  // ── Palette ────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF684F8E);
  static const Color _green = Color(0xFF28A745);

  // ── Flow state ────────────────────────────────────────────────
  bool? usarToken; // null = nenhum selecionado ainda
  int _currentStep = 0;
  String? _stepError;

  // ── Form data ─────────────────────────────────────────────────
  final TextEditingController _tokenCtrl = TextEditingController();
  Uint8List? _fotoTiradaMorador;
  Uint8List? _fotoTiradaEncomenda;

  // Resolved morador photo (local or via notifier)
  Uint8List? get _fotoMoradorResolved =>
      _fotoTiradaMorador ?? widget.fotoMoradorNotifier?.value;

  // ── Overlay flags ─────────────────────────────────────────────
  bool _mostrarSelecaoPessoa = false;
  bool _mostrarCameraEncomenda = false;

  // ── Misc state ────────────────────────────────────────────────
  String _nomePorteiro = 'Carregando...';
  String? _feedbackMessage;
  bool _isSuccessFeedback = false;
  bool _isLoading = false;

  // ── Step definitions ──────────────────────────────────────────
  List<_StepInfo> get _steps => (usarToken ?? true)
      ? const [
          _StepInfo('Método', Icons.tune_outlined),
          _StepInfo('Token', Icons.dialpad_outlined),
          _StepInfo('Encomenda', Icons.inventory_2_outlined),
          _StepInfo('Revisão', Icons.check_circle_outline),
        ]
      : const [
          _StepInfo('Método', Icons.tune_outlined),
          _StepInfo('Receptor', Icons.how_to_reg),
          _StepInfo('Encomenda', Icons.inventory_2_outlined),
          _StepInfo('Revisão', Icons.check_circle_outline),
        ];

  bool _isStepComplete(int step) {
    if (step == 0) return usarToken != null; // deve escolher um modo
    if (usarToken == true) {
      switch (step) {
        case 1: return _tokenCtrl.text.trim().isNotEmpty;
        case 2: return _fotoTiradaEncomenda != null;
        case 3: return _tokenCtrl.text.trim().isNotEmpty && _fotoTiradaEncomenda != null;
      }
    } else {
      switch (step) {
        case 1: return _fotoMoradorResolved != null;
        case 2: return _fotoTiradaEncomenda != null;
        case 3: return _fotoMoradorResolved != null && _fotoTiradaEncomenda != null;
      }
    }
    return false;
  }

  String _stepErrorMessage(int step) {
    if (step == 0) return 'Selecione o modo de entrega.';
    if (usarToken == true) {
      if (step == 1) return 'Informe o token antes de continuar.';
      if (step == 2) return 'Tire a foto da encomenda antes de continuar.';
    } else {
      if (step == 1) return 'Selecione o receptor e tire a foto antes de continuar.';
      if (step == 2) return 'Tire a foto da encomenda antes de continuar.';
    }
    return 'Preencha os campos obrigatórios.';
  }

  // ── Lifecycle ─────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    usarToken = null; // nunca pré-seleciona — usuário escolhe sempre
    widget.fotoMoradorNotifier?.value = null;
    widget.fotoMoradorNotifier?.addListener(_onFotoMoradorChanged);
    _carregarNomePorteiro();
  }

  @override
  void dispose() {
    widget.fotoMoradorNotifier?.removeListener(_onFotoMoradorChanged);
    _tokenCtrl.dispose();
    super.dispose();
  }

  void _onFotoMoradorChanged() => setState(() {});

  Future<void> _carregarNomePorteiro() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enc = prefs.getString('usuario_nome') ?? '';
      setState(() => _nomePorteiro = enc.isNotEmpty ? decryptText(enc) : 'Porteiro');
    } catch (_) {
      setState(() => _nomePorteiro = 'Porteiro');
    }
  }

  // ── Navigation ────────────────────────────────────────────────
  void _goNext() {
    if (!_isStepComplete(_currentStep)) {
      setState(() => _stepError = _stepErrorMessage(_currentStep));
      return;
    }
    setState(() {
      _stepError = null;
      if (_currentStep < _steps.length - 1) {
        _currentStep++;
        // Auto-abre overlay ao entrar no step Receptor (sem token, sem foto ainda)
        if (usarToken == false && _currentStep == 1 && _fotoMoradorResolved == null) {
          _mostrarSelecaoPessoa = true;
        }
      }
    });
  }

  void _goBack() => setState(() {
        _stepError = null;
        if (_currentStep > 0) _currentStep--;
      });

  void _setMode(bool token) {
    if (usarToken == token) return;
    setState(() {
      usarToken = token;
      _currentStep = 0;
      _stepError = null;
      if (token) {
        _fotoTiradaMorador = null;
        widget.fotoMoradorNotifier?.value = null;
      } else {
        _tokenCtrl.clear();
      }
    });
  }

  // ── Confirm delivery ────────────────────────────────────────────
  Future<void> _confirmarEntrega() async {
    if (!_isStepComplete(_currentStep) || _isLoading) return;

    // Delegar para o dashboard via callback (fecha tela, mostra feedback no card)
    if (widget.onConfirmarEntrega != null) {
      final tokenTratado = (usarToken ?? false) ? _tokenCtrl.text : '';
      widget.onConfirmarEntrega!(
        usarToken ?? false,
        tokenTratado,
        _fotoMoradorResolved,
        _fotoTiradaEncomenda,
      );
      return;
    }

    // Fallback: chamada direta (caso não tenha callback)
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';

      final encomenda = widget.encomenda;
      final avisoId =
          encomenda['aviso_id'] ?? encomenda['avisoentrega_id'] ?? encomenda['id'];
      final tokenTratado = (usarToken ?? false) ? _tokenCtrl.text : '';
      final nomePara = encomenda['nome_para']?.toString() ??
          encomenda['nomepara']?.toString() ??
          encomenda['nome']?.toString() ??
          'Sistema';

      final url = Uri.parse(ApiConfig.getEndpoint('encomendas', 'entrega'));
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          'avisoentrega_id': avisoId,
          'statusentrega_id': 123,
          'retiradoPor': nomePara,
          'entreguePor': _nomePorteiro,
          'tokenRetirou': tokenTratado,
          'mensagem': 'Entrega realizada via sistema',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final responseData = jsonDecode(response.body);

      // Token inválido (erro == 1 conforme PRD)
      if (responseData['erro'] == 1) {
        if (mounted) {
          setState(() {
            _feedbackMessage =
                responseData['message'] ?? 'Token inválido. Tente novamente.';
            _isSuccessFeedback = false;
            _isLoading = false;
          });
        }
        return;
      }

      // Upload das fotos (sem bloquear o fluxo em caso de falha)
      final protocoloId = int.tryParse(avisoId.toString());
      if (protocoloId != null) {
        if (_fotoMoradorResolved != null) {
          final usuarioparaId =
              encomenda['usuario_id'] ?? encomenda['usuario_para_id'] ?? 0;
          await _uploadFotoPessoa(
              usuarioparaId.toString(), _fotoMoradorResolved!);
        }
        if (_fotoTiradaEncomenda != null) {
          await _uploadFotoEncomenda(protocoloId, _fotoTiradaEncomenda!);
        }
      }

      if (mounted) {
        setState(() {
          _feedbackMessage = 'Entregue com sucesso';
          _isSuccessFeedback = true;
          _isLoading = false;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _isSuccessFeedback) widget.onClose();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedbackMessage = 'Erro ao registrar: $e';
          _isSuccessFeedback = false;
          _isLoading = false;
        });
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _feedbackMessage = null);
        });
      }
    }
  }

  Future<void> _uploadFotoPessoa(String usuarioId, Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';
      final condominioId = await ApiConfig.getCondominioId();

      await http.post(
        Uri.parse('${ApiConfig.gateUrl}/FotoRegistrar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          'condominio_id': int.tryParse(condominioId) ?? 0,
          'tipoUSU': 'USU',
          'ordem_num': 1,
          'pessoacadastro_id': int.tryParse(usuarioId) ?? 0,
          'foto': base64Encode(bytes),
        }),
      );
    } catch (_) {}
  }

  Future<void> _uploadFotoEncomenda(int protocoloId, Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';

      await http.post(
        Uri.parse(ApiConfig.getEndpoint('encomendas', 'imagem')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          'id': protocoloId,
          'index': '0',
          'base64': base64Encode(bytes),
        }),
      );
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            ScreenHeader(
              icon: Icons.local_shipping,
              title: 'Entrega de Encomenda',
              subtitle: 'Confirmação de entrega e registro fotográfico',
              onClose: widget.onClose,
            ),
            _buildResponsavelBar(),
            _buildStepperIndicator(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.topLeft,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: child,
                ),
                child: KeyedSubtree(
                  key: ValueKey('step_${_currentStep}_$usarToken'),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: _buildStepContent(_currentStep),
                  ),
                ),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
        if (_mostrarSelecaoPessoa) _buildSelecaoPessoaOverlay(),
        if (_mostrarCameraEncomenda) _buildCameraEncomendaOverlay(),
      ],
    );
  }

  // ── Responsável bar ───────────────────────────────────────────
  Widget _buildResponsavelBar() {
    final unidadeCompleta = widget.encomenda['unidade']?.toString() ?? '';
    final partes = unidadeCompleta.split('<br>');
    final unidade = partes.isNotEmpty ? partes[0].trim() : '';
    final nomeOriginal = partes.length > 1 ? partes[1].trim() : '';
    String nomeMascarado = nomeOriginal;
    if (nomeOriginal.isNotEmpty) {
      final p = nomeOriginal.split(' ');
      if (p.length > 1) nomeMascarado = '${p[0]} ${p[1][0]}.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: getCardColor(context),
        border: Border(bottom: BorderSide(color: getBorderColor(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha 1 — Responsável
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: getSecondaryTextColor(context)),
              const SizedBox(width: 6),
              Text('Responsável:',
                  style: TextStyle(fontSize: 12, color: getSecondaryTextColor(context))),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _nomePorteiro,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: getTextColor(context)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Linha 2 — Unidade (mesmo padrão)
          if (nomeMascarado.isNotEmpty || unidade.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.home_outlined, size: 14, color: getSecondaryTextColor(context)),
                const SizedBox(width: 6),
                Text('Unidade:',
                    style: TextStyle(fontSize: 12, color: getSecondaryTextColor(context))),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    nomeMascarado.isNotEmpty
                        ? '$nomeMascarado · $unidade'
                        : unidade,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: getTextColor(context)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Stepper indicator ─────────────────────────────────────────
  Widget _buildStepperIndicator() {
    final steps = _steps;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: getCardColor(context),
        border: Border(bottom: BorderSide(color: getBorderColor(context))),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final completed = _currentStep > i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: completed ? _green : getBorderColor(context),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }
          final idx = i ~/ 2;
          final isActive = idx == _currentStep;
          final isCompleted = idx < _currentStep;
          return _stepCircle(steps[idx], idx, isActive, isCompleted);
        }),
      ),
    );
  }

  Widget _stepCircle(
      _StepInfo info, int idx, bool isActive, bool isCompleted) {
    final Color ringColor;
    final Color labelColor;
    final Widget inner;

    if (isCompleted) {
      ringColor = _green;
      labelColor = _green;
      inner = const Icon(Icons.check, color: Colors.white, size: 13);
    } else if (isActive) {
      ringColor = _primary;
      labelColor = _primary;
      inner = Text('${idx + 1}',
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold));
    } else {
      ringColor = getBorderColor(context);
      labelColor = getSecondaryTextColor(context);
      inner = Text('${idx + 1}',
          style: TextStyle(
              color: getSecondaryTextColor(context),
              fontSize: 11,
              fontWeight: FontWeight.bold));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: (isCompleted || isActive) ? ringColor : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: ringColor, width: isActive ? 2 : 1.5),
          ),
          child: Center(child: inner),
        ),
        const SizedBox(height: 4),
        Text(
          info.label,
          style: TextStyle(
            fontSize: 10,
            color: labelColor,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ── Step router ───────────────────────────────────────────────
  Widget _buildStepContent(int step) {
    if (step == 0) return _buildStepMode();
    if (step == _steps.length - 1) return _buildStepReview();
    if (usarToken == true) {
      if (step == 1) return _buildStepToken();
      if (step == 2) return _buildStepPackagePhoto();
    } else {
      if (step == 1) return _buildStepReceptor();
      if (step == 2) return _buildStepPackagePhoto();
    }
    return const SizedBox.shrink();
  }

  // ════════════════════════════════════════════════════════════════
  // STEP 0 — Modo
  // ════════════════════════════════════════════════════════════════
  Widget _buildStepMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading(
          'Como confirmar a entrega?',
          'Escolha o modo de identificação do receptor.',
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _modeCard(
                label: 'Com Token',
                description: 'Receptor informa um código de 7 dígitos',
                icon: Icons.dialpad_outlined,
                isSelected: usarToken == true,
                onTap: () { _setMode(true); _goNext(); },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _modeCard(
                label: 'Sem Token',
                description: 'Identificação do receptor por foto',
                icon: Icons.how_to_reg,
                isSelected: usarToken == false,
                onTap: () { _setMode(false); _goNext(); },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _modeCard({
    required String label,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    final bg = isSelected
        ? _primary.withValues(alpha: 0.07)
        : getCardColor(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primary : getBorderColor(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? _primary
                    : getBorderColor(context).withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: isSelected
                      ? Colors.white
                      : getSecondaryTextColor(context),
                  size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? _primary : getTextColor(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            AnimatedOpacity(
              opacity: isSelected ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Selecionado',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // STEP 1A — Token
  // ════════════════════════════════════════════════════════════════
  Widget _buildStepToken() {
    final hasToken = _tokenCtrl.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading(
          'Informe o token de entrega',
          'Solicite o código de 7 dígitos ao receptor.',
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _tokenCtrl,
          keyboardType: TextInputType.number,
          maxLength: 7,
          autofocus: true,
          style: TextStyle(
            color: getTextColor(context),
            fontSize: 30,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          textAlign: TextAlign.center,
          decoration: inputDecorationPadrao(context, hintText: '0000000')
              .copyWith(
            counterText: '',
            prefixIcon: const Icon(Icons.key, color: _primary),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          ),
          onChanged: (_) => setState(() => _stepError = null),
        ),
        const SizedBox(height: 16),
        AnimatedOpacity(
          opacity: hasToken ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: _statusChip(
              icon: Icons.check_circle, label: 'Token informado', color: _green),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // STEP 1B — Receptor
  // ════════════════════════════════════════════════════════════════
  Widget _buildStepReceptor() {
    final foto = _fotoMoradorResolved;
    final hasFoto = foto != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading(
          'Identificar receptor',
          'Selecione o morador/colaborador e registre uma foto.',
        ),
        const SizedBox(height: 20),
        hasFoto
            ? _photoPreviewCard(
                foto: foto,
                label: 'Receptor identificado',
                onRetake: _capturarFotoMorador,
              )
            : _captureAreaButton(
                icon: Icons.person_search,
                title: 'Selecionar Receptor',
                subtitle: 'Toque para abrir a lista de moradores',
                onTap: _capturarFotoMorador,
              ),
        if (widget.fotoMorador != null) ...[
          const SizedBox(height: 20),
          _miniLabel('Foto cadastrada do morador'),
          const SizedBox(height: 8),
          _smallPhotoThumb(widget.fotoMorador!),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // STEP 2 — Foto da Encomenda
  // ════════════════════════════════════════════════════════════════
  Widget _buildStepPackagePhoto() {
    final foto = _fotoTiradaEncomenda;
    final hasFoto = foto != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading(
          'Fotografar a encomenda',
          'Tire uma foto da encomenda para registro.',
        ),
        const SizedBox(height: 20),
        hasFoto
            ? _photoPreviewCard(
                foto: foto,
                label: 'Foto da encomenda registrada',
                onRetake: _capturarFotoEncomenda,
              )
            : _captureAreaButton(
                icon: Icons.camera_alt_outlined,
                title: 'Fotografar Encomenda',
                subtitle: 'Toque para abrir a câmera',
                onTap: _capturarFotoEncomenda,
              ),
        if (widget.fotoEncomenda != null) ...[
          const SizedBox(height: 20),
          _miniLabel('Foto atual da encomenda'),
          const SizedBox(height: 8),
          _smallPhotoThumb(widget.fotoEncomenda!),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // STEP 3 — Revisão
  // ════════════════════════════════════════════════════════════════
  Widget _buildStepReview() {
    final isValid = _isStepComplete(_currentStep);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading(
          'Revisar e confirmar',
          'Confira os dados antes de confirmar a entrega.',
        ),
        const SizedBox(height: 20),
        // Summary card
        Container(
          decoration: BoxDecoration(
            color: getCardColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: getBorderColor(context)),
          ),
          child: Column(
            children: [
              _reviewTextRow(
                icon: (usarToken == true) ? Icons.key : Icons.face,
                label: 'Modo',
                value: (usarToken == true) ? 'Com token' : 'Sem token',
                valueColor: _primary,
              ),
              _divider(),
              if (usarToken == true) ...[
                _reviewTextRow(
                  icon: Icons.pin,
                  label: 'Token',
                  value: _tokenCtrl.text.trim(),
                  valueColor: getTextColor(context),
                  mono: true,
                ),
              ] else ...[
                _reviewPhotoRow(
                  icon: Icons.person,
                  label: 'Foto do receptor',
                  photo: _fotoMoradorResolved,
                ),
              ],
              _divider(),
              _reviewPhotoRow(
                icon: Icons.inventory_2,
                label: 'Foto da encomenda',
                photo: _fotoTiradaEncomenda,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        isValid
            ? _statusChip(
                icon: Icons.check_circle,
                label: 'Pronto para entregar!',
                color: _green)
            : _statusChip(
                icon: Icons.warning_amber,
                label: 'Preencha todos os campos obrigatórios',
                color: Colors.orange),
        if (_feedbackMessage != null) ...[
          const SizedBox(height: 10),
          _statusChip(
            icon: _isSuccessFeedback ? Icons.check_circle : Icons.error,
            label: _feedbackMessage!,
            color: _isSuccessFeedback ? _green : Colors.red,
          ),
        ],
      ],
    );
  }

  Widget _reviewTextRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 17, color: _primary),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(fontSize: 13, color: getSecondaryTextColor(context))),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor,
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
              letterSpacing: mono ? 4 : 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewPhotoRow({
    required IconData icon,
    required String label,
    required Uint8List? photo,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: _primary),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(fontSize: 13, color: getSecondaryTextColor(context))),
          const Spacer(),
          photo != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.memory(photo,
                      width: 56, height: 56, fit: BoxFit.cover),
                )
              : Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child:
                      const Icon(Icons.close, color: Colors.red, size: 20),
                ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // BOTTOM NAVIGATION
  // ════════════════════════════════════════════════════════════════
  Widget _buildBottomNav() {
    // Step 0 não precisa de nav — o card já avança automaticamente
    if (_currentStep == 0) return const SizedBox.shrink();

    final isLast = _currentStep == _steps.length - 1;
    final isValid = _isStepComplete(_currentStep);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: getCardColor(context),
        border: Border(top: BorderSide(color: getBorderColor(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_stepError != null) ...[
            _statusChip(
                icon: Icons.error_outline,
                label: _stepError!,
                color: Colors.red),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (_currentStep >= 1) ...[
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: _goBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: getTextColor(context),
                      side: BorderSide(color: getBorderColor(context)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.arrow_back_ios_new, size: 13),
                        SizedBox(width: 6),
                        Text('Voltar',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 3,
                child: isLast
                    ? _confirmButton(isValid)
                    : ElevatedButton(
                        onPressed: _goNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('Próximo',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_ios, size: 13),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _confirmButton(bool isValid) {
    return ElevatedButton(
      focusNode: FocusNode(skipTraversal: true),
      onPressed: (isValid && !_isLoading) ? _confirmarEntrega : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF28A745),
        disabledBackgroundColor: Colors.grey.shade300,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 18),
                SizedBox(width: 8),
                Text('CONFIRMAR ENTREGA',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0)),
              ],
            ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // OVERLAYS (original integration preserved)
  // ════════════════════════════════════════════════════════════════
  Widget _buildSelecaoPessoaOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: EncomendaSelecaoPessoaScreen(
            onClose: () => setState(() => _mostrarSelecaoPessoa = false),
            encomenda: widget.encomenda,
            onFotoTirada: (Uint8List foto) {
              if (widget.fotoMoradorNotifier != null) {
                widget.fotoMoradorNotifier!.value = foto;
              }
              setState(() {
                _fotoTiradaMorador = foto;
                _mostrarSelecaoPessoa = false;
                _stepError = null;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCameraEncomendaOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: FacialCaptureModal(
          isFrontal: false,
          title: 'Foto da Encomenda',
          onClose: () => setState(() => _mostrarCameraEncomenda = false),
          onCapture: (String photoDataUrl) async {
            if (photoDataUrl.isNotEmpty) {
              final compressed =
                  await ImageUtils.compressImageToMaxSize(photoDataUrl);
              final bytes = base64Decode(compressed.split(',').last);
              setState(() {
                _fotoTiradaEncomenda = Uint8List.fromList(bytes);
                _mostrarCameraEncomenda = false;
                _stepError = null;
              });
            }
          },
        ),
      ),
    );
  }

  void _capturarFotoMorador() =>
      setState(() => _mostrarSelecaoPessoa = true);

  void _capturarFotoEncomenda() =>
      setState(() => _mostrarCameraEncomenda = true);

  // ════════════════════════════════════════════════════════════════
  // SHARED UI HELPERS
  // ════════════════════════════════════════════════════════════════
  Widget _stepHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: getTextColor(context))),
        const SizedBox(height: 4),
        Text(subtitle,
            style: TextStyle(fontSize: 13, color: getSecondaryTextColor(context))),
      ],
    );
  }

  Widget _miniLabel(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
              color: _primary, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: getTextColor(context))),
      ],
    );
  }

  Widget _captureAreaButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 190,
        width: double.infinity,
        decoration: BoxDecoration(
          color: getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _primary.withValues(alpha: 0.4), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _primary, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    color: _primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle,
                style:
                    TextStyle(fontSize: 12, color: getSecondaryTextColor(context))),
          ],
        ),
      ),
    );
  }

  Widget _photoPreviewCard({
    required Uint8List foto,
    required String label,
    required VoidCallback onRetake,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: _green, size: 15),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        color: _green,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: onRetake,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _primary.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, size: 12, color: _primary),
                        SizedBox(width: 4),
                        Text('Refazer',
                            style: TextStyle(
                                fontSize: 11,
                                color: _primary,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
              child: SizedBox(
                width: 220,
                height: 220,
                child: Image.memory(foto, fit: BoxFit.cover),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallPhotoThumb(Uint8List foto) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.memory(foto, fit: BoxFit.cover),
      ),
    );
  }

  Widget _statusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: getBorderColor(context), indent: 16, endIndent: 16);
}
