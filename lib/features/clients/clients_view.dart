import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cat_ui/cat_ui.dart';

import '../../data/db/database.dart';
import '../../shared/utils/colors.dart';
import 'cubit/clients_cubit.dart';

class ClientsView extends StatelessWidget {
  const ClientsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
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
            children: [
              for (final c in clients)
                HoverTile(
                  // Stateful row: keyed so hover doesn't survive a reorder.
                  key: ValueKey(c.client.id),
                  leading: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _pickColor(context, c.client),
                    child: CircleAvatar(
                      radius: AppTokens.dotRadiusMiddle,
                      backgroundColor: hexToColor(c.client.colorHex),
                    ),
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
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nuovo cliente'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('Crea'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await cubit.create(name);
    } catch (err) {
      messenger.showSnackBar(
        SnackBar(content: Text('Creazione fallita: $err')),
      );
    }
  }

  Future<void> _rename(BuildContext context, Client client) async {
    final cubit = context.read<ClientsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: client.name);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rinomina cliente'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == client.name) return;
    try {
      await cubit.rename(client.id, name);
    } catch (_) {
      // UNIQUE COLLATE NOCASE violation
      messenger.showSnackBar(
        SnackBar(content: Text('Esiste già un cliente chiamato "$name"')),
      );
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
              CircleAvatar(
                radius: AppTokens.dotRadiusLarge,
                backgroundColor: hslToColor(hue),
              ),
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Impossibile eliminare "${c.client.name}": ${c.entryCount} attività usano questo cliente',
          ),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Eliminare "${c.client.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Annulla'),
          ),
          DangerButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok == true) await cubit.delete(c.client.id);
  }
}
