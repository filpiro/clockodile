import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../shared/theme.dart';

const _pagePadding = 24.0;
// Key-cap column: descriptions line up on one edge.
const _comboWidth = 110.0;

class HelpView extends StatelessWidget {
  const HelpView({super.key});

  @override
  Widget build(BuildContext context) {
    final isMac = Platform.isMacOS;
    SingleActivator mod(LogicalKeyboardKey key) =>
        SingleActivator(key, control: !isMac, meta: isMac);
    final shortcuts = [
      (mod(LogicalKeyboardKey.keyN), 'Nuova attività'),
      (mod(LogicalKeyboardKey.keyT), "Termina l'attività in corso"),
      (mod(LogicalKeyboardKey.digit1), 'Filtro Oggi'),
      (mod(LogicalKeyboardKey.digit2), 'Filtro Ieri'),
      (mod(LogicalKeyboardKey.digit3), 'Filtro Tutte'),
      (
        mod(LogicalKeyboardKey.keyS),
        'Esporta CSV normalizzato (pagina Report); '
            'salva nella pagina di modifica attività',
      ),
    ];
    return Scaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(_pagePadding),
        child: Align(
          alignment: Alignment.topLeft,
          // Prose: it keeps its column instead of running the window's width.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: formMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Scorciatoie da tastiera').h4(),
                const Gap(8),
                const Text(
                  'Funzionano ovunque nella finestra: se necessario '
                  'passano prima alla schermata Attività.',
                ),
                const Gap(8),
                const Text(
                  "Tocca un'attività nell'elenco per riattivarla: parte "
                  'una nuova sessione e quella in corso viene chiusa. '
                  'La matita (al passaggio del mouse) apre la modifica.',
                ),
                const Gap(16),
                for (final (activator, description) in shortcuts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: _comboWidth,
                          child: KeyboardDisplay.fromActivator(
                            activator: activator,
                          ),
                        ),
                        const Gap(16),
                        // Expanded, not a bare Text: inside the width cap a
                        // long description has to wrap instead of overflowing.
                        Expanded(child: Text(description)),
                      ],
                    ),
                  ),
                const Gap(16),
                const Text(
                  'AI locale: llama.cpp (MIT) e modello Qwen3-1.7B (Apache-2.0), '
                  'scaricati da GitHub e Hugging Face.',
                ).small().muted(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
