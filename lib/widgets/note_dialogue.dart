import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<String?> showNoteDialog(
  BuildContext context, {
  required String userName,
  DateTime? createdAt,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);

  final ts = createdAt ?? DateTime.now();
  final formatted = DateFormat('dd.MM.yyyy  ·  HH:mm').format(ts);

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
      return AnimatedPadding(
        padding: EdgeInsets.only(bottom: bottomInset),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: DraggableScrollableSheet(
          initialChildSize: 0.95,
          minChildSize: 0.5,
          maxChildSize: 1.0,
          expand: true,
          builder: (_, scrollController) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(ctx).unfocus(),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      initial.isEmpty ? 'Dodaj notatka' : 'Edytuj notatka',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    Divider(),

                    AutoSizeText(
                      '$userName  ·  $formatted',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                      maxLines: 1,
                      minFontSize: 8,
                    ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      minLines: 3,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: 'Treść notatki…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Anuluj'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            Navigator.of(ctx).pop(text);
                          },
                          child: const Text('Zapisz'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
