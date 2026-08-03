import 'dart:async';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/db/database.dart';
import '../../../shared/utils/format.dart';
import '../normalize.dart';

enum ReportFilter { today, yesterday, day }

class ReportState {
  final ReportFilter filter;

  /// Day selected via the picker chip; only applied when [filter] == day.
  final DateTime? pickedDay;

  /// Presentation only: group rows by client. Normalization is unaffected.
  final bool grouped;

  /// Normalized rows for the selected day, in display order.
  final List<ReportRow> rows;
  ReportState(this.filter, this.pickedDay, this.grouped, this.rows);

  ReportState copyWith({
    ReportFilter? filter,
    DateTime? pickedDay,
    bool? grouped,
    List<ReportRow>? rows,
  }) => ReportState(
    filter ?? this.filter,
    pickedDay ?? this.pickedDay,
    grouped ?? this.grouped,
    rows ?? this.rows,
  );

  DateTime get day {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (filter) {
      ReportFilter.today => today,
      ReportFilter.yesterday => today.subtract(const Duration(days: 1)),
      ReportFilter.day => pickedDay!,
    };
  }
}

class ReportCubit extends Cubit<ReportState> {
  final AppDatabase db;
  StreamSubscription<List<SessionRow>>? _sub;
  List<ReportRow> _normalized = const [];

  ReportCubit(this.db)
    : super(ReportState(ReportFilter.today, null, true, const [])) {
    _watch();
  }

  void setFilter(ReportFilter filter) {
    emit(state.copyWith(filter: filter));
    _watch();
  }

  void setDay(DateTime day) {
    emit(
      state.copyWith(
        filter: ReportFilter.day,
        pickedDay: DateTime(day.year, day.month, day.day),
      ),
    );
    _watch();
  }

  void setGrouped(bool grouped) {
    emit(
      state.copyWith(
        grouped: grouped,
        rows: orderRows(_normalized, grouped: grouped),
      ),
    );
  }

  void _watch() {
    _sub?.cancel();
    final from = state.day;
    final to = from.add(const Duration(days: 1));
    _sub = db.watchClosedSessions(from: from, to: to).listen((sessions) {
      _normalized = normalizeDay(sessions);
      emit(
        state.copyWith(rows: orderRows(_normalized, grouped: state.grouped)),
      );
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
