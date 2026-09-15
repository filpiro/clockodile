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
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminare le attività più vecchie?'),
          content: Text(
            'Le attività più vecchie di $days giorni verranno '
            'eliminate definitivamente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            DangerButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    final db = context.read<AppDatabase>();
    // Retention only: the AI switch persists itself, and writing it here
    // would overwrite it with stale page state.
    await db.saveSettings(SettingsCompanion(retentionDays: Value(days)));
    await db.purgeExpiredEntries();
    if (!mounted) return;
    setState(() => _storedDays = days);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Impostazioni salvate')));
  }

  Widget _aiSection(BuildContext context) {
    final ai = context.watch<AiCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AI', style: Theme.of(context).textTheme.labelLarge),
        // Acts at once, like the theme: a cancelled or failed install leaves
        // state.enabled false, so the switch falls back by itself.
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: ai.state.enabled,
          onChanged: (on) =>
              on ? runAiInstall(context, ai, update: false) : ai.disable(),
          title: const Text('Riassunto delle note'),
          subtitle: const Text(
            'Usa un modello locale su questo computer. Dopo '
            '${AiConfig.sleepIdleSeconds} secondi senza richieste il modello '
            'va in pausa: il riassunto successivo richiede qualche secondo '
            'in più.',
          ),
        ),
        if (ai.state.filesOnDisk)
          DangerButton(
            onPressed: () => confirmAiDelete(context, ai),
            child: Text('Elimina modello ($installedSize)'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Impostazioni', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Tema', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            // Applied and persisted instantly, like the AI switch; only
            // retention waits for the button.
            BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, mode) => SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Chiaro'),
                    icon: Icon(LucideIcons.sun),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Scuro'),
                    icon: Icon(LucideIcons.moon),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Sistema'),
                    icon: Icon(LucideIcons.monitor),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) =>
                    context.read<ThemeCubit>().setMode(s.single),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 320,
              child: TextFormField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Giorni di conservazione delle attività',
                  helperText:
                      'Le attività più vecchie vengono eliminate '
                      "all'avvio. Minimo ${AppDatabase.minRetentionDays} giorni.",
                ),
                validator: (value) {
                  final days = int.tryParse(value ?? '');
                  if (days == null || days < AppDatabase.minRetentionDays) {
                    return 'Inserire almeno ${AppDatabase.minRetentionDays} giorni';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            // The Local Model is Windows x64 only.
            if (Platform.isWindows) ...[
              _aiSection(context),
              const SizedBox(height: 16),
            ],
            FilledButton(onPressed: _save, child: const Text('Salva')),
          ],
        ),
      ),
    );
  }
}
