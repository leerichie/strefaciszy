// lib/widgets/autocomplete_text_field.dart
import 'package:flutter/material.dart';

typedef Normalize = String Function(String);

class AutocompleteTextField extends StatelessWidget {
  const AutocompleteTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.options,
    required this.normalize,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final List<String> options;
  final Normalize normalize;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue tev) {
        if (tev.text.isEmpty) return options;
        final q = normalize(tev.text);
        return options.where((o) => normalize(o).contains(q));
      },
      initialValue: TextEditingValue(text: controller.text),
      onSelected: (sel) => controller.text = sel,
      fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmit) {
        textCtrl.text = controller.text;
        textCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: textCtrl.text.length),
        );
        textCtrl.addListener(() => controller.text = textCtrl.text);

        return TextFormField(
          controller: textCtrl,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: PopupMenuButton<String>(
              icon: const Icon(Icons.arrow_drop_down_circle_outlined),
              onSelected: (val) {
                controller.text = val;
                textCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: val.length),
                );
              },
              itemBuilder: (_) => options
                  .map((o) => PopupMenuItem(value: o, child: Text(o)))
                  .toList(),
            ),
          ),
          validator: validator,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
        );
      },
    );
  }
}
