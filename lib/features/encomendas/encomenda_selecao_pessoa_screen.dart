import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/widgets/screen_header.dart';
import '../../core/services/image_utils.dart';
import '../../core/services/crypto_utils.dart';

import '../../core/config/api_config.dart';
import '../../shared/widgets/facial_capture_modal.dart';
import '../../core/utils/ui_standards.dart';

class EncomendaSelecaoPessoaScreen extends StatefulWidget {
  final VoidCallback onClose;
  final Function(Uint8List)? onFotoTirada;
  final Map<String, dynamic> encomenda;
  const EncomendaSelecaoPessoaScreen({
    super.key,
    required this.onClose,
    this.onFotoTirada,
    required this.encomenda,
  });

  @override
  State<EncomendaSelecaoPessoaScreen> createState() =>
      _EncomendaSelecaoPessoaScreenState();
}

class _PessoaMorador {
  final String id;
  final String nome;
  Uint8List? foto;

  _PessoaMorador({required this.id, required this.nome});
}

class _EncomendaSelecaoPessoaScreenState
    extends State<EncomendaSelecaoPessoaScreen> {
  static const _purple = Color(0xFF684F8E);
  static const _green = Color(0xFF28A745);

  String? _pessoaSelecionada;
  Uint8List? _fotoTirada;
  List<_PessoaMorador> _moradores = [];
  bool _carregando = true;
  final Map<String, Uint8List?> _cacheFotos = {};
  bool _mostrarCameraPessoa = false;

  @override
  void initState() {
    super.initState();
    _carregarMoradores();
  }

  @override
  Widget build(BuildContext context) {
    final selecionada = _pessoaSelecionada != null
        ? _moradores.firstWhere(
            (p) => p.id == _pessoaSelecionada,
            orElse: () => _PessoaMorador(id: '', nome: ''),
          )
        : null;

    final temConfirmacao = _fotoTirada != null && selecionada != null;

    return Container(
      color: getBackgroundColor(context),
      child: Stack(
        children: [
          Column(
            children: [
              ScreenHeader(
                icon: Icons.how_to_reg,
                title: 'Selecionar Receptor',
                subtitle: 'Selecione e tire a foto do receptor',
                onClose: widget.onClose,
              ),
              _buildInstructionBanner(),
              Expanded(
                child: _buildGrid(),
              ),
              // Espaço para o bar de confirmação não cobrir o conteúdo
              if (temConfirmacao) const SizedBox(height: 88),
            ],
          ),
          // Bottom bar de confirmação
          if (temConfirmacao)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildConfirmBar(selecionada),
            ),
          // Overlay da câmera
          if (_mostrarCameraPessoa)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: FacialCaptureModal(
                  isFrontal: true,
                  title: 'Foto do Receptor',
                  onClose: () => setState(() => _mostrarCameraPessoa = false),
                  onCapture: (String photoDataUrl) async {
                    if (photoDataUrl.isNotEmpty) {
                      final compressed =
                          await ImageUtils.compressImageToMaxSize(photoDataUrl);
                      final bytes = base64Decode(compressed.split(',').last);
                      setState(() {
                        _fotoTirada = Uint8List.fromList(bytes);
                        _mostrarCameraPessoa = false;
                      });
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInstructionBanner() {
    if (_pessoaSelecionada != null && _fotoTirada == null) {
      // Pessoa selecionada, aguardando foto
      final nome = _moradores
          .firstWhere((p) => p.id == _pessoaSelecionada,
              orElse: () => _PessoaMorador(id: '', nome: ''))
          .nome;
      final isDarkBanner = isDarkMode(context);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isDarkBanner
            ? const Color(0xFF856404).withValues(alpha: 0.2)
            : const Color(0xFFFFF3CD),
        child: Row(
          children: [
            const Icon(Icons.camera_alt_outlined,
                size: 18, color: Color(0xFF856404)),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Câmera aberta para ',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF856404)),
                  children: [
                    TextSpan(
                      text: nome,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: '. Aguardando captura...'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_pessoaSelecionada == null) {
      final isDark = isDarkMode(context);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color:
            isDark ? _purple.withValues(alpha: 0.15) : const Color(0xFFEDE9F5),
        child: Row(
          children: [
            Icon(Icons.touch_app_outlined, size: 18, color: _purple),
            const SizedBox(width: 8),
            Text(
              'Toque em um morador para selecionar e tirar a foto.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : const Color(0xFF4A3770),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildGrid() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_purple),
        ),
      );
    }

    if (_moradores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Sem moradores com foto cadastrada',
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Moradores e Colaboradores',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.88,
              ),
              itemCount: _moradores.length,
              itemBuilder: (context, index) => _personCard(_moradores[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personCard(_PessoaMorador pessoa) {
    final isSelected = _pessoaSelecionada == pessoa.id;
    final initials = pessoa.nome
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();

    return GestureDetector(
      onTap: () {
        setState(() {
          _pessoaSelecionada = pessoa.id;
          _fotoTirada = null;
        });
        _tirarFotoPessoa();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _green : getBorderColor(context),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _green.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Foto ou avatar com iniciais
              if (pessoa.foto != null)
                Image.memory(pessoa.foto!, fit: BoxFit.cover)
              else
                Container(
                  color: getCardColor(context),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _purple.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              // Gradiente + nome
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.70),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    pessoa.nome.split(' ').first,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // Badge de selecionado
              if (isSelected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.check, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmBar(_PessoaMorador pessoa) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        border: Border(
          top: BorderSide(color: getBorderColor(context), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail da foto
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _fotoTirada!,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pessoa.nome,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: getTextColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Foto capturada',
                  style: TextStyle(fontSize: 12, color: _green),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Refazer
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _fotoTirada = null);
              _tirarFotoPessoa();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refazer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: getTextColor(context),
              side: BorderSide(color: getBorderColor(context)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          // Confirmar
          ElevatedButton.icon(
            onPressed: () {
              widget.onFotoTirada?.call(_fotoTirada!);
              widget.onClose();
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Confirmar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  void _tirarFotoPessoa() {
    setState(() => _mostrarCameraPessoa = true);
  }

  Future<void> _carregarMoradores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';

      final aptoId = widget.encomenda['aptopara_id']?.toString() ?? '';
      final condominioId = await ApiConfig.getCondominioId();

      final url = Uri.parse('https://gate.conectcon.net.br/pt-br/unidadelist');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          'apto_id': aptoId,
          'condominio_id': condominioId,
          'flg_principal': 'N',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          final lista = data['data']?['unidades'] ?? [];
          final moradores = <_PessoaMorador>[];

          for (var item in lista) {
            moradores.add(_PessoaMorador(
              id: item['usuario_id']?.toString() ?? '',
              nome: item['nome'] ?? 'Morador',
            ));
          }

          setState(() {
            _moradores = moradores;
            _carregando = false;
          });

          await _carregarFotosViaUnidadeFoto();
        } else {
          setState(() => _carregando = false);
        }
      } else {
        setState(() => _carregando = false);
      }
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  Future<void> _carregarFotosViaUnidadeFoto() async {
    try {
      final moradoresComFoto = <_PessoaMorador>[];

      for (final morador in _moradores) {
        try {
          final temFoto = await _carregarFotoMoradorViaAPI(morador);
          if (temFoto && morador.foto != null) {
            moradoresComFoto.add(morador);
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _moradores = moradoresComFoto;
        });
      }
    } catch (_) {}
  }

  Future<bool> _carregarFotoMoradorViaAPI(_PessoaMorador morador) async {
    if (_cacheFotos.containsKey(morador.id)) {
      final fotoCache = _cacheFotos[morador.id];
      if (fotoCache != null) {
        morador.foto = fotoCache;
        return true;
      }
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';

      final url = Uri.parse(
          'https://social.conectcon.net.br/pt-br/unidadefoto?id=${morador.id}&tipo=USU');

      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $tokenSessao'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 200 && jsonResponse['data'] != null) {
          final fotobase64 = jsonResponse['data']['fotobase64'];
          if (fotobase64 is String && fotobase64.isNotEmpty) {
            String base64String = fotobase64.trim();
            if (base64String.startsWith('"') && base64String.endsWith('"')) {
              base64String = base64String.substring(1, base64String.length - 1);
            }

            if (RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(base64String)) {
              final bytes = base64Decode(base64String);
              if (bytes.length > 4 &&
                  ((bytes[0] == 0xFF && bytes[1] == 0xD8) ||
                      (bytes[0] == 0x89 && bytes[1] == 0x50) ||
                      (bytes[0] == 0x47 && bytes[1] == 0x49))) {
                _cacheFotos[morador.id] = bytes;
                if (mounted) {
                  setState(() => morador.foto = bytes);
                }
                return true;
              }
            }
          }
        }
      }

      _cacheFotos[morador.id] = null;
      return false;
    } catch (_) {
      return false;
    }
  }
}
