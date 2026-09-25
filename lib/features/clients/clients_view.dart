import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide showToast;

import '../../data/db/database.dart';
import '../../shared/widgets/app_list_row.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/identicon.dart';
import 'cubit/clients_cubit.dart';

const _pagePadding = 24.0;

class ClientsView extends StatelessWidget {
  const ClientsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          padding: const EdgeInsets.fromLTRB(
            _pagePadding,
            _pagePadding,
            _pagePadding,
            8,
          ),
          trailing: [
            PrimaryButton(
              leading: const Icon(LucideIcons.plus),
              onPressed: () => _create(context),
              child: const Text('Nuovo cliente'),
            ),
          ],
        ),
      ],
      child: BlocBuilder<ClientsCubit, List<ClientWithCount>>(
        builder: (context, clients) {
          if (clients.isEmpty) {
            return const EmptyState('Nessun cliente.');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              for (final c in clients)
                AppListRow(
                  // Stateful row: keyed so hover doesn't survive a reorder.
                  key: ValueKey(c.client.id),
                  leading: Identicon(c.client.id),
                  title: Text(c.client.name),
                  subtitle: Text('${c.entryCount} attività'),
                  onTap: () => _rename(context, c.client),
                  onDelete: () => _delete(context, c),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final cubit = context.read<ClientsCubit>();
    final name = await _askName(context, title: 'Nuovo cliente', confirm: 'Crea');
    if (name == null) return;
    try {
      await cubit.create(name);
    } catch (_) {
      // UNIQUE COLLATE NOCASE violation
      showToast('Esiste già un cliente chiamato "$name"');
    }
  }

  Future<void> _rename(BuildContext context, Client client) async {
    final cubit = context.read<ClientsCubit>();
    final name = await _askName(
      context,
      title: 'Rinomina cliente',
      confirm: 'Salva',
      initial: client.name,
    );
    if (name == null || name == client.name) return;
    try {
      await cubit.rename(client.id, name);
    } catch (_) {
      // UNIQUE COLLATE NOCASE violation
      showToast('Esiste già un cliente chiamato "$name"');
    }
  }

  Future<void> _delete(BuildContext context, ClientWithCount c) async {
    final cubit = context.read<ClientsCubit>();
    if (c.entryCount > 0) {
      // spec 4.3: surface why deletion is blocked
      showToast(
        'Impossibile eliminare "${c.client.name}": ${c.entryCount} attività usano questo cliente',
      );
      return;
    }
    final ok = await showOverlay<bool>(
      context,
      const DialogConfiguration(),
      builder: (context) => AlertDialog(
        title: Text('Eliminare "${c.client.name}"?'),
        actions: [
          OutlineButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          DestructiveButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    ).future;
    if (ok == true) await cubit.delete(c.client.id);
  }
}

/// Trimmed non-empty name, or null on cancel.
Future<String?> _askName(
  BuildContext context, {
  required String title,
  required String confirm,
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  void submit(BuildContext context) {
    final name = controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  final name = await showOverlay<String>(
    context,
    const DialogConfiguration(),
    builder: (context) => AlertDialog(
      title: Text(title),
      // A TextField takes all the width it gets; without this the dialog
      // spans the window.
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: controller,
          autofocus: true,
          placeholder: const Text('Nome'),
          onSubmitted: (_) => submit(context),
        ),
      ),
      actions: [
        OutlineButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        PrimaryButton(onPressed: () => submit(context), child: Text(confirm)),
      ],
    ),
  ).future;
  controller.dispose();
  return name;
}
