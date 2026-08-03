import 'dart:io';

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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scorciatoie da tastiera',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(combo, textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(description),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
