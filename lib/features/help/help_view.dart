import 'dart:io';

import 'package:catui/catui.dart';
import 'package:flutter/material.dart';

class HelpView extends StatelessWidget {
  const HelpView({super.key});

  @override
  Widget build(BuildContext context) {
    final mod = Platform.isMacOS ? 'Cmd' : 'Ctrl';
    final shortcuts = [
      ('$mod + N', 'Nuova attività'),
      ('$mod + T', "Termina l'attività in corso"),
      ('$mod + 1', 'Filtro Oggi'),
      ('$mod + 2', 'Filtro Ieri'),
      ('$mod + 3', 'Filtro Tutte'),
      (
        '$mod + S',
        'Esporta CSV normalizzato (pagina Report); '
            'salva nella pagina di modifica attività',
      ),
    ];
    return CatPage(
      // Prose: it keeps its column instead of running the window's width.
      maxWidth: AppTokens.formMaxWidth,
      scroll: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CatSectionHeader.inline(title: 'Scorciatoie da tastiera'),
          const Text(
            'Funzionano ovunque nella finestra: se necessario '
            'passano prima alla schermata Attività.',
          ),
          const SizedBox(height: 8),
          const Text(
            "Tocca un'attività nell'elenco per riattivarla: parte "
            'una nuova sessione e quella in corso viene chiusa. '
            'La matita (al passaggio del mouse) apre la modifica.',
          ),
          const SizedBox(height: 16),
          for (final (combo, description) in shortcuts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: CatTag(combo, textAlign: TextAlign.center),
                  ),
                  const SizedBox(width: 16),
                  Text(description),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'AI locale: llama.cpp (MIT) e modello Qwen3-1.7B (Apache-2.0), '
            'scaricati da GitHub e Hugging Face.',
          ),
        ],
      ),
    );
  }
}
