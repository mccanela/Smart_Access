import 'package:flutter/material.dart';
import '../../core/utils/ui_standards.dart';

//-----------------------------//
// MODAL DE AJUSTES E CORREÇÕES
//-----------------------------//

class AjustesModal extends StatelessWidget {
  final VoidCallback? onClose;
  const AjustesModal({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    final onCloseCallback = onClose;

    return Scaffold(
      backgroundColor: getBackgroundColor(context),
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: getTextColor(context)),
            const SizedBox(width: 12),
            Text(
              'Ajustes',
              style: TextStyle(
                color: getTextColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: getBackgroundColor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: getTextColor(context)),
          onPressed: () {
            if (onCloseCallback != null) {
              onCloseCallback();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: getBorderColor(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: getBorderColor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ajustes',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: getTextColor(context),
                  ),
                ),
                const SizedBox(height: 24),
                _buildAjusteItem(context, '1',
                    'Mensagem de concluído, reenviado, etc (Padrão modal para todos)', 'Ajustado'),
                _buildAjusteItem(context, '2',
                    'Câmeras é smart não há testes até o momento', 'Testes depois da integração'),
                _buildAjusteItem(context, '3',
                    'Tela teste não haverá na versão final, é somente para validar as infos para fins de testes', 'Será removido na versão final'),
                _buildAjusteItem(context, '4',
                    'Anunciar visitantes', 'Cor ajustada para o padrão'),
                _buildAjusteItem(context, '5',
                    'Convidados Encontrados', 'Ajustado'),
                _buildAjusteItem(context, '6',
                    'Verificar', 'Em verificação'),
                _buildAjusteItem(context, '7',
                    'Icons de agendamentos', 'Ajustados'),
                _buildAjusteItem(context, '8',
                    'Os icons se escondendo', 'Isso por conta do tamanho da tela, tem um scroll em telas menores'),
                _buildAjusteItem(context, '9',
                    'Dias de selecionar período', 'Ajustado'),
                _buildAjusteItem(context, '10',
                    'teste', 'teste'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAjusteItem(
    BuildContext context,
    String numero,
    String descricao,
    String status,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getCardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF684F8E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                numero,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descricao,
                  style: TextStyle(
                    color: getTextColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  status,
                  style: TextStyle(
                    color: getSecondaryTextColor(context),
                    fontSize: 13,
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
