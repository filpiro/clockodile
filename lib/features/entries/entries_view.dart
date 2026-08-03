import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cat_ui/cat_ui.dart';

import '../../data/db/database.dart';
import '../../shared/utils/colors.dart';
import '../../shared/utils/format.dart';
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

  Future<void> _pickDay(BuildContext context, EntriesState state) async {
    final cubit = context.read<EntriesCubit>();
    final day = await showDatePicker(
      context: context,
      initialDate: state.pickedDay ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day != null) cubit.setDay(day);
  }

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
          floatingActionButton: FloatingActionButton(
            heroTag: null,
            tooltip: 'Nuova attività',
            onPressed: () => openEntryPage(context),
            child: const Icon(LucideIcons.plus),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final f in [
                            DateFilter.today,
                            DateFilter.yesterday,
                          ])
                            ChoiceChip(
                              label: Text(
                                f == DateFilter.today ? 'Oggi' : 'Ieri',
                              ),
                              showCheckmark: false,
                              selected: state.filter == f,
                              onSelected: (_) =>
                                  context.read<EntriesCubit>().setFilter(f),
                            ),
                          ChoiceChip(
                            avatar: const Icon(LucideIcons.calendar, size: 16),
                            showCheckmark: false,
                            label: Text(
                              state.pickedDay == null
                                  ? 'Data'
                                  : dmyShort(state.pickedDay!),
                            ),
                            selected: state.filter == DateFilter.day,
                            onSelected: (_) => _pickDay(context, state),
                          ),
                          ChoiceChip(
                            label: const Text('Tutte'),
                            showCheckmark: false,
                            selected: state.filter == DateFilter.all,
                            onSelected: (_) => context
                                .read<EntriesCubit>()
                                .setFilter(DateFilter.all),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (state.active != null) _ActiveEntryTile(state.active!),
              Expanded(
                child: state.rows.isEmpty && state.active == null
                    ? const EmptyState('Nessuna attività.')
                    : ListView(
                        children: [
                          for (final day in byDay.entries) ...[
                            _DayHeader(day.key, day.value.values.toList()),
                            for (final g in day.value.values) _EntryDayTile(g),
                          ],
                          if (state.canLoadMore)
                            TextButton(
                              onPressed: () =>
                                  context.read<EntriesCubit>().loadMore(),
                              child: const Text('Carica altre'),
                            ),
                        ],
                      ),
              ),
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
/// edit via hover pencil, stop via "Termina".
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
    final scheme = Theme.of(context).colorScheme;
    final running = DateTime.now().difference(a.openSession.start);
    final total = a.closedTotal + running;
    final hasPast = a.closedTotal > Duration.zero;
    return HoverTile(
      leading: CircleAvatar(
        radius: AppTokens.dotRadius,
        backgroundColor: hexToColor(a.client.colorHex),
      ),
      title: Row(
        children: [
          Flexible(child: Text(a.client.name)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'in corso',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        'dalle ${hhmm(a.openSession.start)}'
        ' · sessione ${formatHm(running)}'
        '${hasPast ? ' · totale ${formatHm(total)}' : ''}'
        '${a.entry.note.isEmpty ? '' : ' — ${a.entry.note}'}',
      ),
      actions: [
        EditIconButton(
          onPressed: () =>
              openEntryPage(context, entry: a.entry, client: a.client),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          // Same hover treatment as delete, by explicit choice: in this app
          // red marks a strong action, not only irreversible data loss.
          // 48 tall, not the stock 40: it fills the tap box it already
          // occupies, so the row doesn't grow, and it stops reading as
          // smaller than the edit button's 40px hover disc.
          style:
              intentHoverStyle(
                idle: scheme.onSecondaryContainer,
                accent: scheme.error,
              ).copyWith(
                minimumSize: const WidgetStatePropertyAll(
                  Size(64, AppTokens.pillMinHeight),
                ),
              ),
          icon: const Icon(LucideIcons.circleStop),
          label: const Text('Termina'),
          onPressed: () => context.read<EntriesCubit>().stop(),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            italianDayLabel(day),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const Spacer(),
          Text(formatHm(total), style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

/// An Entry's sessions within one day. Tap = activate (reactivation opens a
/// new session; no-op if already active). Edit and delete on hover.
class _EntryDayTile extends StatelessWidget {
  final _EntryDayGroup g;
  const _EntryDayTile(this.g);

  @override
  Widget build(BuildContext context) {
    final n = g.sessions.length;
    final spans = n == 1
        ? '${hhmm(g.sessions.single.start)}–${hhmm(g.sessions.single.end!)}'
        : '$n sessioni';
    return HoverTile(
      // HoverTile keeps hover state; without a key it is reused by position
      // and a deleted row hands its highlight to whichever row slides up.
      // Keyed by first session, not entry: an Entry spanning two days appears
      // twice in this list, and duplicate sibling keys throw.
      key: ValueKey(g.sessions.first.id),
      leading: CircleAvatar(
        radius: AppTokens.dotRadius,
        backgroundColor: hexToColor(g.client.colorHex),
      ),
      title: Text(g.client.name),
      subtitle: Text(
        '$spans (${formatHm(g.total)})'
        '${g.entry.note.isEmpty ? '' : ' — ${g.entry.note}'}',
      ),
      onTap: () => context.read<EntriesCubit>().activate(g.entry.id),
      actions: [
        EditIconButton(
          onPressed: () =>
              openEntryPage(context, entry: g.entry, client: g.client),
        ),
        DeleteIconButton(
          onPressed: () async {
            final cubit = context.read<EntriesCubit>();
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text("Eliminare l'attività?"),
                content: const Text(
                  'Verranno eliminate tutte le sue sessioni, anche in altri giorni.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Annulla'),
                  ),
                  DangerButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Elimina'),
                  ),
                ],
              ),
            );
            if (ok == true) cubit.deleteEntry(g.entry.id);
          },
        ),
      ],
    );
  }
}
