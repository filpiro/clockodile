import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/db/database.dart';

enum DateFilter { today, yesterday, day, all }

class EntriesState {
  final DateFilter filter;

  /// Day selected via the picker chip; kept when switching filters so the
  /// chip remembers its last date. Only applied when [filter] == day.
  final DateTime? pickedDay;

  /// The Active Entry (owner of the Open Session), pinned above the list in
  /// every filter. Null when idle.
  final ActiveEntry? active;

  /// Closed sessions matching [filter], newest first.
  final List<SessionRow> rows;
  final int limit; // only applies to DateFilter.all
  EntriesState(this.filter, this.pickedDay, this.active, this.rows, this.limit);

  EntriesState copyWith({
    DateFilter? filter,
    DateTime? pickedDay,
    ActiveEntry? Function()? active,
    List<SessionRow>? rows,
    int? limit,
  }) => EntriesState(
    filter ?? this.filter,
    pickedDay ?? this.pickedDay,
    active == null ? this.active : active(),
    rows ?? this.rows,
    limit ?? this.limit,
  );

  /// True when "all" may have more rows beyond the current page.
  bool get canLoadMore => filter == DateFilter.all && rows.length >= limit;
}

const _pageSize = 50;

class EntriesCubit extends Cubit<EntriesState> {
  final AppDatabase db;
  StreamSubscription<List<SessionRow>>? _sub;
  StreamSubscription<ActiveEntry?>? _activeSub;

  EntriesCubit(this.db)
    : super(EntriesState(DateFilter.today, null, null, const [], _pageSize)) {
    _activeSub = db.watchActiveEntry().listen(
      (a) => emit(state.copyWith(active: () => a)),
      onError: addError,
    );
    _watch();
  }

  void setFilter(DateFilter filter) {
    emit(state.copyWith(filter: filter, limit: _pageSize));
    _watch();
  }

  void setDay(DateTime day) {
    emit(
      state.copyWith(
        filter: DateFilter.day,
        pickedDay: DateTime(day.year, day.month, day.day),
        limit: _pageSize,
      ),
    );
    _watch();
  }

  void loadMore() {
    emit(state.copyWith(limit: state.limit + _pageSize));
    _watch();
  }

  (DateTime?, DateTime?) _filterRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (state.filter) {
      DateFilter.today => (today, null),
      DateFilter.yesterday => (today.subtract(const Duration(days: 1)), today),
      DateFilter.day => (
        state.pickedDay!,
        state.pickedDay!.add(const Duration(days: 1)),
      ),
      DateFilter.all => (null, null),
    };
  }

  void _watch() {
    _sub?.cancel();
    final (from, to) = _filterRange();
    final limit = state.filter == DateFilter.all ? state.limit : null;
    _sub = db
        .watchClosedSessions(from: from, to: to, limit: limit)
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
