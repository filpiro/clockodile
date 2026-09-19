import 'package:clockodile/shared/widgets/empty_state.dart';
import 'package:clockodile/shared/widgets/hover_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:catui/catui.dart';

import '../../data/db/database.dart';
import '../../shared/utils/colors.dart';
import '../../shared/widgets/client_dot.dart';
import 'cubit/clients_cubit.dart';

class ClientsView extends StatelessWidget {
  const ClientsView({super.key});

  @override
  Widget build(BuildContext context) {
    return CatPage(
      fab: FloatingActionButton(
        heroTag: null,
        tooltip: 'Nuovo cliente',
        onPressed: () => _create(context),
        child: const Icon(LucideIcons.plus),
      ),
      body: BlocBuilder<ClientsCubit, List<ClientWithCount>>(
        builder: (context, clients) {
          if (clients.isEmpty) {
            return const EmptyState('Nessun cliente.');
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: AppTokens.fabClearance),
            children: [
              for (final c in clients)
                HoverTile(
                  // Stateful row: keyed so hover doesn't survive a reorder.
                  key: ValueKey(c.client.id),
                  leading: ClientDot(
                    c.client.colorHex,
                    size: ClientDotSize.tappable,
                    onTap: () => _pickColor(context, c.client),
                  ),
                  title: Text(c.client.name),
                  subtitle: Text('${c.entryCount} attività'),
                  onTap: () => _rename(context, c.client),
                  actions: [
                    DeleteIconButton(onPressed: () => _delete(context, c)),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final cubit = context.read<ClientsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final name = await catTextInput(
      context,
      title: 'Nuovo cliente',
      label: 'Nome',
      confirm: 'Crea',
      cancel: 'Annulla',
    );
    if (name == null) return;
    try {
      await cubit.create(name);
    } catch (_) {
      // UNIQUE COLLATE NOCASE violation
      catSnack(messenger, 'Esiste già un cliente chiamato "$name"');
    }
  }

  Future<void> _rename(BuildContext context, Client client) async {
    final cubit = context.read<ClientsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final name = await catTextInput(
      context,
      title: 'Rinomina cliente',
      label: 'Nome',
      confirm: 'Salva',
      cancel: 'Annulla',
      initial: client.name,
    );
    if (name == null || name == client.name) return;
    try {
      await cubit.rename(client.id, name);
    } catch (_) {
      // UNIQUE COLLATE NOCASE violation
      catSnack(messenger, 'Esiste già un cliente chiamato "$name"');
    }
  }

  Future<void> _pickColor(BuildContext context, Client client) async {
    final cubit = context.read<ClientsCubit>();
    // ponytail: hue slider with fixed S/L instead of a full color picker —
    // keeps the readability-by-construction guarantee and avoids a dependency.
    var hue = HSLColor.fromColor(hexToColor(client.colorHex)).hue;
    final picked = await showDialog<double>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: const Text('Colore cliente'),
          content: Row(
            children: [
              ClientDot.color(hslToColor(hue), size: ClientDotSize.large),
              Expanded(
                child: Slider(
                  min: 0,
                  max: 360,
                  value: hue,
                  onChanged: (v) => setState(() => hue = v),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, hue),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await cubit.setColor(client.id, colorToHex(hslToColor(picked)));
    }
  }

  Future<void> _delete(BuildContext context, ClientWithCount c) async {
    final cubit = context.read<ClientsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    if (c.entryCount > 0) {
      // spec 4.3: surface why deletion is blocked
      catSnack(
        messenger,
        'Impossibile eliminare "${c.client.name}": ${c.entryCount} attività usano questo cliente',
      );
      return;
    }
    final ok = await catConfirm(
      context,
      title: 'Eliminare "${c.client.name}"?',
      confirm: 'Elimina',
      cancel: 'Annulla',
      danger: true,
    );
    if (ok) await cubit.delete(c.client.id);
  }
}
