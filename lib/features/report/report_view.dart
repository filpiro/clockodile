import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide showToast;

import '../../shared/widgets/app_list_row.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/date_filter_bar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/identicon.dart';
import '../../shared/utils/format.dart';
import 'cubit/report_cubit.dart';
import 'normalize.dart';
import 'report_board.dart';

const _pagePadding = 24.0;

/// Export with toast feedback — used by the page button and Ctrl+S.
Future<void> runReportExport(BuildContext context) async {
  final cubit = context.read<ReportCubit>();
  try {
    final result = await cubit.exportCsv();
    if (result == null) return; // cancelled
    final (path, count) = result;
    showToast('Esportate $count sessioni in $path');
  } catch (_) {
    showToast('Esportazione fallita');
  }
}

/// Copies an Entry note for pasting into the portal — the tap action shared by
/// the list rows and the board tiles.
void copyNote(String note) {
  Clipboard.setData(ClipboardData(text: note));
  showToast('Nota copiata');
}

class ReportView extends StatelessWidget {
  const ReportView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportCubit, ReportState>(
      builder: (context, state) {
        final cubit = context.read<ReportCubit>();
        final total = state.rows.fold(
          Duration.zero,
          (sum, r) => sum + r.normDuration,
        );
        final perClient = clientTotals(state.rows);
        Widget modeToggle(ReportMode m, IconData icon, String label) => Toggle(
          value: state.mode == m,
          onChanged: (_) => cubit.setMode(m),
          style: const ButtonStyle.outline(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icon), const Gap(8), Text(label)],
          ),
        );
        return Scaffold(
          headers: [
            AppBar(
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              title: Wrap(
                spacing: 24,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DateFilterBar(day: state.day, onDay: cubit.setDay),
                  Wrap(
                    spacing: 8,
                    children: [
                      modeToggle(
                        ReportMode.grouped,
                        LucideIcons.listTree,
                        'Raggruppa per cliente',
                      ),
                      modeToggle(
                        ReportMode.chronological,
                        LucideIcons.chartGantt,
                        'Ordine cronologico',
                      ),
                    ],
                  ),
                ],
              ),
              trailing: [
                Tooltip(
                  tooltip: (_) =>
                      const TooltipContainer(child: Text('Esporta CSV')),
                  child: IconButton(
                    variance: ButtonStyle.ghostIcon(),
                    density: ButtonDensity.icon,
                    icon: const Icon(LucideIcons.fileDown),
                    enabled: state.rows.isNotEmpty,
                    onPressed: () => runReportExport(context),
                  ),
                ),
              ],
            ),
          ],
          footers: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _pagePadding,
                8,
                _pagePadding,
                _pagePadding,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('Totale normalizzato: ${formatHm(total)}').h4(),
              ),
            ),
          ],
          child: switch (state) {
            ReportState(rows: []) => const EmptyState(
              'Nessuna sessione nel giorno scelto.',
            ),
            ReportState(mode: ReportMode.chronological) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
              child: ReportBoard(state.rows),
            ),
            _ => ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                for (final (i, r) in state.rows.indexed) ...[
                  if (i == 0 || state.rows[i - 1].client.id != r.client.id)
                    _ClientHeader(r, perClient[r.client.id] ?? Duration.zero),
                  _ReportTile(r),
                ],
              ],
            ),
          },
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Identicon(r.client.id, size: Identicon.small),
          const Gap(8),
          Expanded(child: Text(r.client.name).h4()),
          Text(formatHm(total)).h4(),
        ],
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
    return AppListRow(
      // Stateful row: keyed so hover doesn't survive a filter change.
      key: ValueKey(r.session.id),
      // No note, no tap.
      onTap: note.isEmpty ? null : () => copyNote(note),
      // No identicon: the client header above every run already carries it.
      title: Text(
        '${hhmm(r.normStart)}–${hhmm(r.normEnd)}'
        ' (${formatHm(r.normDuration)})'
        '${note.isEmpty ? '' : ' — $note'}',
        style: zero
            ? TextStyle(color: Theme.of(context).colorScheme.destructive)
            : null,
      ),
      subtitle: Text(
        '${r.client.name}'
        ' · reale ${hhmm(r.session.start)}–${hhmm(r.session.end!)}',
      ),
    );
  }
}
