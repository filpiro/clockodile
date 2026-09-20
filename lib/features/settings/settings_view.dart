import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _storedDays = AppDatabase.defaultRetentionDays;

  @override
  void initState() {
    super.initState();
    context.read<AppDatabase>().getSettings().then((s) {
      if (!mounted) return;
      setState(() {
        _storedDays = s.retentionDays;
        _controller.text = '${s.retentionDays}';
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final days = int.parse(_controller.text);
    if (days < _storedDays) {
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
    catSnack(ScaffoldMessenger.of(context), 'Impostazioni salvate');
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
      body: Form(
        key: _formKey,
        child: Column(
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
              description:
                  'Le attività più vecchie vengono eliminate '
                  "all'avvio. Minimo ${AppDatabase.minRetentionDays} giorni.",
              // Retention is the only setting that waits for a button, so the
              // button sits right under it.
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppTokens.formMaxWidth,
                  ),
                  child: TextFormField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onFieldSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                      labelText: 'Giorni di conservazione delle attività',
                    ),
                    validator: (value) {
                      final days = int.tryParse(value ?? '');
                      if (days == null || days < AppDatabase.minRetentionDays) {
                        return 'Inserire almeno '
                            '${AppDatabase.minRetentionDays} giorni';
                      }
                      return null;
                    },
                  ),
                ),
                FilledButton(onPressed: _save, child: const Text('Salva')),
              ],
            ),
            // The Local Model is Windows x64 only.
            if (Platform.isWindows) _aiSection(context),
          ],
        ),
      ),
    );
  }
}
