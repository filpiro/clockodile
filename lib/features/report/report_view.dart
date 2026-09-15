import 'package:clockodile/shared/widgets/empty_state.dart';
import 'package:clockodile/shared/widgets/hover_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:catui/catui.dart';

import '../../shared/widgets/client_dot.dart';
import '../../shared/utils/format.dart';
import 'cubit/report_cubit.dart';
import 'normalize.dart';
import 'report_board.dart';

/// Export with snackbar feedback — used by the page button and Ctrl+S.
Future<void> runReportExport(BuildContext context) async {
  final cubit = context.read<ReportCubit>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await cubit.exportCsv();
    if (result == null) return; // cancelled
    final (path, count) = result;
    catSnack(messenger, 'Esportate $count sessioni in $path');
  } catch (_) {
    catSnack(messenger, 'Esportazione fallita');
  }
}

/// Copies an Entry note for pasting into the portal — the tap action shared by
/// the list rows and the board tiles.
void copyNote(BuildContext context, String note) {
  Clipboard.setData(ClipboardData(text: note));
  catSnack(ScaffoldMessenger.of(context), 'Nota copiata');
}

class ReportView extends StatelessWidget {
  const ReportView({super.key});

  Future<void> _pickDay(BuildContext context, ReportState state) async {
    final cubit = context.read<ReportCubit>();
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
    return BlocBuilder<ReportCubit, ReportState>(
      builder: (context, state) {
        final total = state.rows.fold(
          Duration.zero,
          (sum, r) => sum + r.normDuration,
        );
        final perClient = clientTotals(state.rows);
        return Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final f in [
                            ReportFilter.today,
                            ReportFilter.yesterday,
                          ])
                            ChoiceChip(
                              label: Text(
                                f == ReportFilter.today ? 'Oggi' : 'Ieri',
                              ),
                              showCheckmark: false,
                              selected: state.filter == f,
                              onSelected: (_) =>
                                  context.read<ReportCubit>().setFilter(f),
                            ),
                          ChoiceChip(
                            avatar: const Icon(LucideIcons.calendar, size: 16),
                            showCheckmark: false,
                            label: Text(
                              state.pickedDay == null
                                  ? 'Data'
                                  : dmyShort(state.pickedDay!),
                            ),
                            selected: state.filter == ReportFilter.day,
                            onSelected: (_) => _pickDay(context, state),
                          ),
                          const SizedBox(width: 8),
                          // Radio pair: selecting one deselects the other,
                          // neither can be deselected into an empty state.
                          for (final m in ReportMode.values)
                            ChoiceChip(
                              tooltip: m == ReportMode.grouped
                                  ? 'Raggruppa per cliente'
                                  : 'Ordine cronologico',
                              label: Icon(
                                m == ReportMode.grouped
                                    ? LucideIcons.listClock
                                    : LucideIcons.timeline,
                                size: 18,
                                semanticLabel: m == ReportMode.grouped
                                    ? 'Raggruppa per cliente'
                                    : 'Ordine cronologico',
                              ),
                              showCheckmark: false,
                              selected: state.mode == m,
                              onSelected: (_) =>
                                  context.read<ReportCubit>().setMode(m),
                            ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: 'Esporta CSV',
                      child: FilledButton.tonal(
                        onPressed: state.rows.isEmpty
                            ? null
                            : () => runReportExport(context),
                        child: const Icon(LucideIcons.fileDown),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: switch (state) {
                  ReportState(rows: []) => const EmptyState(
                    'Nessuna sessione nel giorno scelto.',
                  ),
                  ReportState(mode: ReportMode.chronological) => ReportBoard(
                    state.rows,
                  ),
                  _ => ListView(
                    children: [
                      for (final (i, r) in state.rows.indexed) ...[
                        if (i == 0 ||
                            state.rows[i - 1].client.id != r.client.id)
                          _ClientHeader(
                            r,
                            perClient[r.client.id] ?? Duration.zero,
                          ),
                        _ReportTile(r),
                      ],
                    ],
                  ),
                },
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Spacer(),
                    Text(
                      'Totale normalizzato: ${formatHm(total)}',
                      style: Theme.of(context).textTheme.titleSmall,
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

class _ClientHeader extends StatelessWidget {
  final ReportRow r;

  /// This client's normalized time across the whole report, not just the run
  /// below — the grouped order puts all of a client's rows in one run anyway.
  final Duration total;
  const _ClientHeader(this.r, this.total);

  @override
  Widget build(BuildContext context) {
    return CatSectionHeader(
      leading: ClientDot(r.client.colorHex, size: ClientDotSize.small),
      title: r.client.name,
      trailing: Text(
        formatHm(total),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final ReportRow r;
  const _ReportTile(this.r);

  @override
  Widget build(BuildContext context) {
    final zero = r.normDuration <= Duration.zero;
    final note = r.entry.note;
    return HoverTile(
      // Stateful row: keyed so hover doesn't survive a filter change.
      key: ValueKey(r.session.id),
      dense: true,
      // No note, no tap.
      onTap: note.isEmpty ? null : () => copyNote(context, note),
      // No color dot: the client header above every run already carries it.
      title: Text(
        '${hhmm(r.normStart)}–${hhmm(r.normEnd)}'
        ' (${formatHm(r.normDuration)})'
        '${r.entry.note.isEmpty ? '' : ' — ${r.entry.note}'}',
        style: zero
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
      subtitle: Text(
        '${r.client.name}'
        ' · reale ${hhmm(r.session.start)}–${hhmm(r.session.end!)}',
      ),
    );
  }
}
