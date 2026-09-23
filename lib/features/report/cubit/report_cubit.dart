import 'dart:async';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/db/database.dart';
import '../../../shared/utils/format.dart';
import '../../../shared/widgets/date_filter_bar.dart';
import '../normalize.dart';

/// How the day is presented. Rows, total and CSV are identical in both — the
/// mode picks a renderer, nothing else. Not persisted across restarts.
enum ReportMode { grouped, chronological }

class ReportState {
  /// The one day reported; always date-only (midnight).
  final DateTime day;

  final ReportMode mode;

  /// Normalized rows for [day], in display order.
  final List<ReportRow> rows;
  ReportState(this.day, this.mode, this.rows);

  ReportState copyWith({
    DateTime? day,
    ReportMode? mode,
    List<ReportRow>? rows,
  }) => ReportState(day ?? this.day, mode ?? this.mode, rows ?? this.rows);
}

class ReportCubit extends Cubit<ReportState> {
  final AppDatabase db;
  StreamSubscription<List<SessionRow>>? _sub;

  ReportCubit(this.db)
    : super(ReportState(today(), ReportMode.grouped, const [])) {
    _watch();
  }

  void setDay(DateTime day) {
    emit(state.copyWith(day: dateOnly(day)));
    _watch();
  }

  void setMode(ReportMode mode) => emit(state.copyWith(mode: mode));

  void _watch() {
    _sub?.cancel();
    final from = state.day;
    final to = from.add(const Duration(days: 1));
    _sub = db.watchClosedSessions(from: from, to: to).listen((sessions) {
      emit(state.copyWith(rows: groupByClient(normalizeDay(sessions))));
    }, onError: addError);
  }

  /// Exports exactly the previewed rows (normalized times, current order).
  /// Null = user cancelled the save dialog.
  Future<(String path, int rowCount)?> exportCsv() async {
    final location = await getSaveLocation(
      suggestedName: 'clockodile-report-${ymd(state.day)}.csv',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    if (location == null) return null;

    final rows = state.rows;
    final csv = Csv().encode([
      ['client', 'start', 'end', 'duration_hours', 'note'],
      for (final r in rows)
        [
          r.client.name,
          isoLocal(r.normStart),
          isoLocal(r.normEnd),
          (r.normDuration.inMinutes / 60).toStringAsFixed(2),
          r.entry.note,
        ],
    ]);
    await File(location.path).writeAsString(csv);
    return (location.path, rows.length);
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
