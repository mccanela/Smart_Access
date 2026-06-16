part of '../dashboard.dart';

class _UsuarioDetalhesPanel extends StatefulWidget {
  final String userId;
  final String? userName;
  final Map<String, dynamic>? userData;

  const _UsuarioDetalhesPanel({
    required this.userId,
    this.userName,
    this.userData,
  });

  @override
  State<_UsuarioDetalhesPanel> createState() => _UsuarioDetalhesPanelState();
}
class _UsuarioDetalhesPanelState extends State<_UsuarioDetalhesPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getBackgroundColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.userName ?? 'Usuário ${widget.userId}',
            style: TextStyle(
              color: getTextColor(context),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.userData != null)
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(widget.userData),
                  style: TextStyle(color: getSecondaryTextColor(context)),
                ),
              ),
            )
          else
            Text(
              'Sem dados adicionais para este usuário.',
              style: TextStyle(color: getSecondaryTextColor(context)),
            ),
        ],
      ),
    );
  }
}
