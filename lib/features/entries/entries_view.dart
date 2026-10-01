import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../data/db/database.dart';
import '../../shared/widgets/app_list_row.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/identicon.dart';
import '../../shared/widgets/date_filter_bar.dart';
import '../../shared/utils/format.dart';
import 'clocky.dart';
import 'cubit/entries_cubit.dart';
import 'entry_edit_page.dart';

/// One list row: an Entry's closed sessions within a single day.
class _EntryDayGroup {
  final Entry entry;
  final Client client;
  final List<Session> sessions = [];
  _EntryDayGroup(this.entry, this.client);

  Duration get total => sessions.fold(
    Duration.zero,
    (sum, s) => sum + s.end!.difference(s.start),
  );
}

class EntriesView extends StatelessWidget {
  const EntriesView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EntriesCubit, EntriesState>(
      builder: (context, state) {
        // Day → (entryId → group). Rows arrive newest first, so both maps
        // preserve that order.
        final byDay = <DateTime, Map<int, _EntryDayGroup>>{};
        for (final r in state.rows) {
          final t = r.session.start;
          final day = DateTime(t.year, t.month, t.day);
          byDay
              .putIfAbsent(day, () => {})
              .putIfAbsent(r.entry.id, () => _EntryDayGroup(r.entry, r.client))
              .sessions
              .add(r.session);
        }
        return Scaffold(
          headers: [
            AppBar(
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              title: DateFilterBar(
                day: state.day,
                onDay: context.read<EntriesCubit>().setDay,
              ),
              trailing: [
                PrimaryButton(
                  leading: const Icon(LucideIcons.plus),
                  onPressed: () => openEntryPage(context),
                  child: const Text('Nuova attività'),
                ),
              ],
            ),
          ],
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.active != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _ActiveEntryTile(state.active!),
                    ),
                    const Divider(),
                  ],
                  Expanded(
                    child: state.rows.isEmpty && state.active == null
                        ? const EmptyState('Nessuna attività.')
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                            children: [
                              for (final day in byDay.entries) ...[
                                _DayHeader(day.key, day.value.values.toList()),
                                for (final g in day.value.values)
                                  _EntryDayTile(g),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
              Positioned.fill(child: Clocky(visible: state.active != null)),
            ],
          ),
        );
      },
    );
  }
}

/// Pinned above the list in every filter. Shows both the running session's
/// elapsed time and the entry's total accumulated time (ticking every
/// minute). Tap is a no-op (activation of the active entry does nothing);
/// edit via the pencil, stop via "Termina".
class _ActiveEntryTile extends StatefulWidget {
  final ActiveEntry active;
  const _ActiveEntryTile(this.active);

  @override
  State<_ActiveEntryTile> createState() => _ActiveEntryTileState();
}

class _ActiveEntryTileState extends State<_ActiveEntryTile> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.active;
    final running = DateTime.now().difference(a.openSession.start);
    final total = a.closedTotal + running;
    final hasPast = a.closedTotal > Duration.zero;
    return AppListRow(
      leading: Identicon(a.client.id, size: Identicon.small),
      title: Row(
        children: [
          Flexible(child: Text(a.client.name)),
          const Gap(8),
          const PrimaryBadge(child: Text('in corso')),
        ],
      ),
      subtitle: Text(
        'dalle ${hhmm(a.openSession.start)}'
        ' · sessione ${formatHm(running)}'
        '${hasPast ? ' · totale ${formatHm(total)}' : ''}'
        '${a.entry.note.isEmpty ? '' : ' — ${a.entry.note}'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RowAction(
            icon: LucideIcons.pencil,
            tooltip: 'Modifica',
            onPressed: () =>
                openEntryPage(context, entry: a.entry, client: a.client),
          ),
          const Gap(8),
          // Red by explicit choice: in this app red marks a strong action,
          // not only irreversible data loss.
          DestructiveButton(
            leading: const Icon(LucideIcons.circleStop),
            onPressed: () => context.read<EntriesCubit>().stop(),
            child: const Text('Termina'),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime day;
  final List<_EntryDayGroup> groups;
  const _DayHeader(this.day, this.groups);

  @override
  Widget build(BuildContext context) {
    final total = groups.fold(Duration.zero, (sum, g) => sum + g.total);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(child: Text(italianDayLabel(day)).h4()),
          Text(formatHm(total)).h4(),
        ],
      ),
    );
  }
}

/// An Entry's sessions within one day. Tap = activate (reactivation opens a
/// new session; no-op if already active). Edit and delete always visible.
class _EntryDayTile extends StatelessWidget {
  final _EntryDayGroup g;
  const _EntryDayTile(this.g);

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<EntriesCubit>();
    final ok = await showOverlay<bool>(
      context,
      const DialogConfiguration(),
      builder: (context) => AlertDialog(
        title: const Text("Eliminare l'attività?"),
        content: const Text(
          'Verranno eliminate tutte le sue sessioni, anche in altri giorni.',
        ),
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
    if (ok == true) cubit.deleteEntry(g.entry.id);
  }

  @override
  Widget build(BuildContext context) {
    final n = g.sessions.length;
    final spans = n == 1
        ? '${hhmm(g.sessions.single.start)}–${hhmm(g.sessions.single.end!)}'
        : '$n sessioni';
    return AppListRow(
      // The row keeps hover state; without a key it is reused by position
      // and a deleted row hands its highlight to whichever row slides up.
      // Keyed by first session, not entry: an Entry spanning two days appears
      // twice in this list, and duplicate sibling keys throw.
      key: ValueKey(g.sessions.first.id),
      leading: Identicon(g.client.id, size: Identicon.small),
      title: Text(g.client.name),
      subtitle: Text(
        '$spans (${formatHm(g.total)})'
        '${g.entry.note.isEmpty ? '' : ' — ${g.entry.note}'}',
      ),
      onTap: () => context.read<EntriesCubit>().activate(g.entry.id),
      onEdit: () => openEntryPage(context, entry: g.entry, client: g.client),
      onDelete: () => _delete(context),
    );
  }
}
