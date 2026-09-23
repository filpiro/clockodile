import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/db/database.dart';
import '../../../shared/widgets/date_filter_bar.dart';

class EntriesState {
  /// The one day shown; always date-only (midnight).
  final DateTime day;

  /// The Active Entry (owner of the Open Session), pinned above the list on
  /// every day. Null when idle.
  final ActiveEntry? active;

  /// Closed sessions of [day], newest first.
  final List<SessionRow> rows;
  EntriesState(this.day, this.active, this.rows);

  EntriesState copyWith({
    DateTime? day,
    ActiveEntry? Function()? active,
    List<SessionRow>? rows,
  }) => EntriesState(
    day ?? this.day,
    active == null ? this.active : active(),
    rows ?? this.rows,
  );
}

class EntriesCubit extends Cubit<EntriesState> {
  final AppDatabase db;
  StreamSubscription<List<SessionRow>>? _sub;
  StreamSubscription<ActiveEntry?>? _activeSub;

  EntriesCubit(this.db) : super(EntriesState(today(), null, const [])) {
    _activeSub = db.watchActiveEntry().listen(
      (a) => emit(state.copyWith(active: () => a)),
      onError: addError,
    );
    _watch();
  }

  void setDay(DateTime day) {
    emit(state.copyWith(day: dateOnly(day)));
    _watch();
  }

  void _watch() {
    _sub?.cancel();
    _sub = db
        .watchClosedSessions(
          from: state.day,
          to: state.day.add(const Duration(days: 1)),
        )
        .listen((rows) => emit(state.copyWith(rows: rows)), onError: addError);
  }

  /// Creates a new Entry born active; any current Open Session is closed.
  Future<void> createEntry({
    required String clientName,
    required DateTime startTime,
    required String note,
  }) => db.createEntry(clientName, note, startTime: startTime);

  /// Activation: no-op when [entryId] is already the Active Entry.
  Future<void> activate(int entryId) => db.activateEntry(entryId);

  /// Stop: closes the Open Session, zero active afterwards.
  Future<void> stop() => db.stopOpenSession();

  Future<void> updateEntryFields(
    int id, {
    required String clientName,
    required String note,
  }) => db.updateEntryFields(id, clientName: clientName, note: note);

  Future<void> updateSession(
    int id, {
    required DateTime start,
    DateTime? end,
  }) => db.updateSession(id, start: start, end: end);

  /// False when blocked: an entry's last session can't be deleted.
  Future<bool> deleteSession(int id) => db.deleteSession(id);

  Future<List<Session>> sessionsOfEntry(int entryId) =>
      db.sessionsOfEntry(entryId);

  Future<void> deleteEntry(int id) => db.deleteEntry(id);

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await _activeSub?.cancel();
    return super.close();
  }
}
