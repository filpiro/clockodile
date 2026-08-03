import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/db/database.dart';

/// App-wide theme choice, persisted in Settings. Applied instantly on change.
class ThemeCubit extends Cubit<ThemeMode> {
  final AppDatabase db;

  ThemeCubit(this.db) : super(ThemeMode.system) {
    db.getThemeMode().then((v) => emit(_parse(v)));
  }

  Future<void> setMode(ThemeMode mode) async {
    emit(mode);
    await db.setThemeMode(mode.name);
  }

  static ThemeMode _parse(String v) => switch (v) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
