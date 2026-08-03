import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/db/database.dart';

class ClientsCubit extends Cubit<List<ClientWithCount>> {
  final AppDatabase db;
  StreamSubscription<List<ClientWithCount>>? _sub;

  ClientsCubit(this.db) : super(const []) {
    _sub = db.watchClientsWithCounts().listen(emit, onError: addError);
  }

  Future<void> create(String name) async {
    await db.matchOrCreateClient(name);
  }

  Future<void> rename(int id, String name) => db.renameClient(id, name);

  Future<void> setColor(int id, String colorHex) =>
      db.setClientColor(id, colorHex);

  /// False = blocked because entries exist (spec 4.3).
  Future<bool> delete(int id) => db.deleteClient(id);

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
