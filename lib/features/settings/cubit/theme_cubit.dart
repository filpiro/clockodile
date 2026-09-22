import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show ThemeMode;

import '../../../data/db/database.dart';

/// App-wide theme choice, persisted in Settings. Applied instantly on change.
class ThemeCubit extends Cubit<ThemeMode> {
  final AppDatabase db;

  ThemeCubit(this.db) : super(ThemeMode.dark) {
    db.getThemeMode().then((v) => emit(_parse(v)));
  }

  Future<void> setMode(ThemeMode mode) async {
    emit(mode);
    await db.setThemeMode(mode.name);
  }

  static ThemeMode _parse(String v) => switch (v) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
}
