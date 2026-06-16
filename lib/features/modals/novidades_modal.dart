import 'package:flutter/material.dart';
import '../../core/utils/ui_standards.dart';
import '../../core/config/app_version.dart';
import '../../shared/widgets/screen_header.dart';

class NovidadesModal extends StatelessWidget {
  final VoidCallback? onClose;
  const NovidadesModal({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: getBackgroundColor(context),
        border: Border(
          left: BorderSide(
            color: isDarkMode(context)
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          ScreenHeader(
            icon: Icons.new_releases_rounded,
            title: 'Novidades',
            onClose: onClose ?? () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(32),
              children: [
                _buildVersionSection(
                  context,
                  version: '2.0.0',
                  date: '01/06/2026',
                  items: [
                    _ChangeItem(
                      icon: Icons.system_update,
                      title: 'Atualização automática',
                      description:
                          'O sistema agora atualiza automaticamente quando uma nova versão é publicada.',
                    ),
                    _ChangeItem(
                      icon: Icons.info_outline,
                      title: 'Versão na sidebar',
                      description:
                          'A versão atual do sistema agora aparece na barra lateral.',
                    ),
                    _ChangeItem(
                      icon: Icons.touch_app,
                      title: 'Tooltips nos botões',
                      description:
                          'Todos os botões do dashboard agora exibem descrição ao passar o mouse.',
                    ),
                    _ChangeItem(
                      icon: Icons.palette_outlined,
                      title: 'Padronização visual',
                      description:
                          'Todas as telas laterais agora seguem o mesmo padrão de cores do dashboard.',
                    ),
                    _ChangeItem(
                      icon: Icons.local_shipping_outlined,
                      title: 'Entrega de encomendas',
                      description:
                          'Fluxo de entrega integrado com confirmação e feedback visual.',
                    ),
                    _ChangeItem(
                      icon: Icons.qr_code,
                      title: 'Identificação interna automática',
                      description:
                          'Número aleatório gerado automaticamente em cada nova encomenda.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionSection(
    BuildContext context, {
    required String version,
    required String date,
    required List<_ChangeItem> items,
  }) {
    final isCurrent = version == appVersion;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? const Color(0xFF684F8E) : getBorderColor(context),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF684F8E)
                      : getBorderColor(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'v$version',
                  style: TextStyle(
                    color: isCurrent
                        ? Colors.white
                        : getSecondaryTextColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                date,
                style: TextStyle(
                  color: getSecondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
              if (isCurrent) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Atual',
                    style: TextStyle(
                      color: Color(0xFF22C55E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          ...items.map((item) => _buildChangeRow(context, item)),
        ],
      ),
    );
  }

  Widget _buildChangeRow(BuildContext context, _ChangeItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF684F8E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              size: 18,
              color: const Color(0xFF684F8E),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: getTextColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    color: getSecondaryTextColor(context),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeItem {
  final IconData icon;
  final String title;
  final String description;
  const _ChangeItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
