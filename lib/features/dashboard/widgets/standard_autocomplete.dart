import 'package:flutter/material.dart';
import '../../../core/utils/ui_standards.dart';
import '../../../shared/widgets/character_counter_field.dart';

Widget buildStandardAutocomplete<T extends Object>({
  Key? key,
  required BuildContext context,
  required String labelText,
  required List<T> items,
  required String Function(T) itemAsString,
  required T? selectedItem,
  required Function(T?) onSelected,
  required BoxConstraints constraints,
  IconData? prefixIcon,
  TextEditingController? controller,
}) {
  return RawAutocomplete<T>(
    key: key,
    textEditingController: controller,
    initialValue: controller == null
        ? TextEditingValue(
            text: selectedItem != null ? itemAsString(selectedItem) : '',
          )
        : null,
    optionsBuilder: (TextEditingValue textEditingValue) {
      if (textEditingValue.text.isEmpty) {
        return items;
      }
      return items.where((T option) {
        return itemAsString(option)
            .toLowerCase()
            .contains(textEditingValue.text.toLowerCase());
      });
    },
    displayStringForOption: itemAsString,
    onSelected: onSelected,
    fieldViewBuilder:
        (context, textEditingController, focusNode, onFieldSubmitted) {
      // Mantém a sincronia quando uma opção é efetivamente selecionada pelo usuário
      if (selectedItem != null &&
          textEditingController.text != itemAsString(selectedItem)) {
        textEditingController.text = itemAsString(selectedItem);
        textEditingController.selection = TextSelection.fromPosition(
            TextPosition(offset: textEditingController.text.length));
      }

      // O bloco que apagava a digitação indevidamente durante os eventos do SignalR foi removido.

      // Envolvemos em um listener reativo para que o "X" apareça e suma instantaneamente
      return ValueListenableBuilder<TextEditingValue>(
        valueListenable: textEditingController,
        builder: (context, value, child) {
          return CharacterCounterField(
            controller: textEditingController,
            focusNode: focusNode,
            labelText: labelText,
            decoration:
                inputDecorationPadrao(context, labelText: labelText).copyWith(
              prefixIcon:
                  prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
              // Se há texto digitado ou item selecionado, mostra o botão X
              suffixIcon: value.text.isNotEmpty || selectedItem != null
                  ? IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: Colors.redAccent),
                      onPressed: () {
                        textEditingController.clear();
                        onSelected(
                            null); // Dispara o evento avisando a tela pai (dashboard) que a seleção foi anulada
                        focusNode.requestFocus();
                      },
                    )
                  : const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ),
          );
        },
      );
    },
    optionsViewBuilder: (context, onSelectedOption, options) {
      return Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: getCardColor(context),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 200,
              maxWidth: constraints.maxWidth,
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (BuildContext context, int index) {
                final T option = options.elementAt(index);
                return InkWell(
                  onTap: () => onSelectedOption(option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDarkMode(context)
                              ? Colors.white12
                              : Colors.black12,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      itemAsString(option),
                      style: TextStyle(
                        color: getTextColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
