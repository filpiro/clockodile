import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cat_ui/cat_ui.dart';

import '../../shared/utils/colors.dart';
import '../../shared/utils/format.dart';
import 'cubit/report_cubit.dart';
import 'normalize.dart';

/// Export with snackbar feedback — used by the page button and Ctrl+S.
Future<void> runReportExport(BuildContext context) async {
  final cubit = context.read<ReportCubit>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await cubit.exportCsv();
    if (result == null) return; // cancelled
    final (path, count) = result;
    messenger.showSnackBar(
      SnackBar(content: Text('Esportate $count sessioni in $path')),
    );
  } catch (err) {
    messenger.showSnackBar(
      SnackBar(content: Text('Esportazione fallita: $err')),
    );
  }
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
                          ChoiceChip(
                            label: const Text('Raggruppa per cliente'),
                            showCheckmark: false,
                            selected: state.grouped,
                            onSelected: (v) =>
                                context.read<ReportCubit>().setGrouped(v),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      icon: const Icon(LucideIcons.fileDown),
                      label: const Text('Esporta CSV'),
                      onPressed: state.rows.isEmpty
                          ? null
                          : () => runReportExport(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.rows.isEmpty
                    ? const EmptyState('Nessuna sessione nel giorno scelto.')
                    : ListView(
                        children: [
                          for (final (i, r) in state.rows.indexed) ...[
                            if (state.grouped &&
                                (i == 0 ||
                                    state.rows[i - 1].client.id != r.client.id))
                              _ClientHeader(r),
                            _ReportTile(r, grouped: state.grouped),
                          ],
                        ],
                      ),
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
  const _ClientHeader(this.r);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: AppTokens.dotRadiusSmall,
            backgroundColor: hexToColor(r.client.colorHex),
          ),
          const SizedBox(width: 8),
          Text(r.client.name, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final ReportRow r;

  /// Grouped rows sit under a client header that already carries the color
  /// dot — repeating it per session is noise.
  final bool grouped;
  const _ReportTile(this.r, {required this.grouped});

  @override
  Widget build(BuildContext context) {
    final zero = r.normDuration <= Duration.zero;
    final note = r.entry.note;
    return HoverTile(
      // Stateful row: keyed so hover doesn't survive a filter change.
      key: ValueKey(r.session.id),
      dense: true,
      // Tap copies the note for pasting into the portal; no note, no tap.
      onTap: note.isEmpty
          ? null
          : () {
              Clipboard.setData(ClipboardData(text: note));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Nota copiata')));
            },
      leading: grouped
          ? null
          : CircleAvatar(
              radius: AppTokens.dotRadius,
              backgroundColor: hexToColor(r.client.colorHex),
            ),
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
