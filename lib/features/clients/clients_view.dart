import 'package:clockodile/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:catui/catui.dart';

import '../../data/db/database.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/identicon.dart';
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
                  leading: Identicon(c.client.id),
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
      showToast('Esiste già un cliente chiamato "$name"');
    }
  }

  Future<void> _rename(BuildContext context, Client client) async {
    final cubit = context.read<ClientsCubit>();
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
