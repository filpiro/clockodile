import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:catui/catui.dart';
// `show` keeps drift's Column/Table off Flutter's.
import 'package:drift/drift.dart' show Value;

import '../../data/db/database.dart';
import '../ai/ai_install_dialogs.dart';
import '../ai/cubit/ai_cubit.dart';
import '../ai/llama_config.dart';
import 'cubit/theme_cubit.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Single user, single machine: the stored value is always one of these.
  static const _retentionChoices = {
    30: '30 giorni',
    45: '45 giorni',
    60: '60 giorni',
  };

  // Null until the stored value lands; the control waits rather than show a
  // guess a tap would then compare against.
  int? _storedDays;

  @override
  void initState() {
    super.initState();
    context.read<AppDatabase>().getSettings().then((s) {
      if (!mounted) return;
      setState(() => _storedDays = s.retentionDays);
    });
  }

  Future<void> _setRetention(int days) async {
    final stored = _storedDays;
    if (stored == null || days == stored) return;
    if (days < stored) {
      final confirmed = await catConfirm(
        context,
        title: 'Eliminare le attività più vecchie?',
        message:
            'Le attività più vecchie di $days giorni verranno '
            'eliminate definitivamente.',
        confirm: 'Elimina',
        cancel: 'Annulla',
        danger: true,
      );
      if (!confirmed) return;
    }
    if (!mounted) return;
    final db = context.read<AppDatabase>();
    // Retention only: the AI switch persists itself, and writing it here
    // would overwrite it with stale page state.
    await db.saveSettings(SettingsCompanion(retentionDays: Value(days)));
    await db.purgeExpiredEntries();
    if (!mounted) return;
    setState(() => _storedDays = days);
  }

  Widget _aiSection(BuildContext context) {
    final ai = context.watch<AiCubit>();
    return CatSection(
      title: 'AI',
      // Last on the page.
      divider: false,
      children: [
        // Acts at once, like the theme: a cancelled or failed install leaves
        // state.enabled false, so the switch falls back by itself.
        CatSettingRow(
          title: 'Riassunto delle note',
          description:
              'Usa un modello locale su questo computer. Dopo '
              '${AiConfig.sleepIdleSeconds} secondi senza richieste il modello '
              'va in pausa: il riassunto successivo richiede qualche secondo '
              'in più.',
          trailing: Switch(
            value: ai.state.enabled,
            onChanged: (on) =>
                on ? runAiInstall(context, ai, update: false) : ai.disable(),
          ),
        ),
        if (ai.state.filesOnDisk)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: () => confirmAiDelete(context, ai),
            child: Text('Elimina modello ($installedSize)'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CatPage(
      // No cap: a settings page is sections, not prose. The sections stretch,
      // the controls inside them keep their own width.
      scroll: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CatSection(
            title: 'Tema',
            // First on the page.
            spaceAbove: false,
            // Applied and persisted instantly, like the AI switch.
            children: [
              BlocBuilder<ThemeCubit, ThemeMode>(
                builder: (context, mode) => CatSegmented<ThemeMode>(
                  segments: const {
                    ThemeMode.light: 'Chiaro',
                    ThemeMode.dark: 'Scuro',
                    ThemeMode.system: 'Sistema',
                  },
                  icons: const {
                    ThemeMode.light: LucideIcons.sun,
                    ThemeMode.dark: LucideIcons.moon,
                    ThemeMode.system: LucideIcons.monitor,
                  },
                  selected: mode,
                  onChanged: context.read<ThemeCubit>().setMode,
                ),
              ),
            ],
          ),
          CatSection(
            title: 'Conservazione',
            // Last wherever the AI section doesn't render.
            divider: Platform.isWindows,
            description: "Le attività più vecchie vengono eliminate all'avvio.",
            // Persisted on pick, like the theme.
            children: [
              if (_storedDays case final days?)
                CatSegmented<int>(
                  segments: _retentionChoices,
                  selected: days,
                  onChanged: _setRetention,
                ),
            ],
          ),
          // The Local Model is Windows x64 only.
          if (Platform.isWindows) _aiSection(context),
        ],
      ),
    );
  }
}
