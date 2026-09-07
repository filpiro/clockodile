import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:catui/catui.dart';
// `show` keeps drift's Column/Table off Flutter's.
import 'package:drift/drift.dart' show Value;

import '../../data/db/database.dart';
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

  bool _aiEnabled = false;
  AiProvider _provider = AiProvider.claudeCode;
  String _claudeModel = 'sonnet';
  String _claudeEffort = 'high';
  bool _wslMode = false;
  // Free text, one pair per provider, so switching away and back keeps both.
  final _freeText = {
    for (final p in [AiProvider.codex, AiProvider.opencode])
      p: (model: TextEditingController(), effort: TextEditingController()),
  };

  @override
  void initState() {
    super.initState();
    context.read<AppDatabase>().getSettings().then((s) {
      if (!mounted) return;
      setState(() {
        _storedDays = s.retentionDays;
        _controller.text = '${s.retentionDays}';
        _aiEnabled = s.aiEnabled;
        _provider = AiProvider.values.firstWhere(
          (p) => p.name == s.aiProvider,
          orElse: () => AiProvider.claudeCode,
        );
        _claudeModel = s.aiClaudeModel;
        _claudeEffort = s.aiClaudeEffort;
        _freeText[AiProvider.codex]!.model.text = s.aiCodexModel;
        _freeText[AiProvider.codex]!.effort.text = s.aiCodexEffort;
        _freeText[AiProvider.opencode]!.model.text = s.aiOpencodeModel;
        _freeText[AiProvider.opencode]!.effort.text = s.aiOpencodeEffort;
        _wslMode = s.aiWslMode;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final c in _freeText.values) {
      c.model.dispose();
      c.effort.dispose();
    }
    super.dispose();
  }

  /// Returns the label of the first free-text field holding something a shell
  /// would read as syntax, or null when all pass. Empty passes.
  String? _invalidAiField() {
    // The section is inert while AI is off: leftover text blocks nothing.
    if (!_aiEnabled) return null;
    for (final p in _freeText.keys) {
      for (final field in [
        (label: 'Modello ${_providerLabel(p)}', c: _freeText[p]!.model),
        (label: 'Sforzo ${_providerLabel(p)}', c: _freeText[p]!.effort),
      ]) {
        final v = field.c.text.trim();
        if (v.isNotEmpty && !aiValuePattern.hasMatch(v)) return field.label;
      }
    }
    return null;
  }

  static String _providerLabel(AiProvider p) => switch (p) {
    AiProvider.claudeCode => 'Claude Code',
    AiProvider.codex => 'Codex',
    AiProvider.opencode => 'OpenCode',
  };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final invalid = _invalidAiField();
    if (invalid != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$invalid: caratteri non ammessi')),
      );
      return;
    }
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
    await db.saveSettings(
      SettingsCompanion(
        retentionDays: Value(days),
        aiEnabled: Value(_aiEnabled),
        aiProvider: Value(_provider.name),
        aiClaudeModel: Value(_claudeModel),
        aiClaudeEffort: Value(_claudeEffort),
        aiCodexModel: Value(_freeText[AiProvider.codex]!.model.text.trim()),
        aiCodexEffort: Value(_freeText[AiProvider.codex]!.effort.text.trim()),
        aiOpencodeModel: Value(
          _freeText[AiProvider.opencode]!.model.text.trim(),
        ),
        aiOpencodeEffort: Value(
          _freeText[AiProvider.opencode]!.effort.text.trim(),
        ),
        aiWslMode: Value(_wslMode),
      ),
    );
    await db.purgeExpiredEntries();
    if (!mounted) return;
    setState(() => _storedDays = days);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Impostazioni salvate')));
  }

  Widget _aiSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AI', style: Theme.of(context).textTheme.labelLarge),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _aiEnabled,
          onChanged: (v) => setState(() => _aiEnabled = v),
          title: const Text('Riassunto delle note'),
          subtitle: const Text('Usa una CLI installata su questa macchina.'),
        ),
        IgnorePointer(
          ignoring: !_aiEnabled,
          child: Opacity(
            opacity: _aiEnabled ? 1 : 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<AiProvider>(
                  segments: [
                    for (final p in AiProvider.values)
                      ButtonSegment(value: p, label: Text(_providerLabel(p))),
                  ],
                  selected: {_provider},
                  onSelectionChanged: (s) =>
                      setState(() => _provider = s.single),
                ),
                const SizedBox(height: 16),
                SizedBox(width: 480, child: _providerFields()),
                // Windows only: elsewhere the CLIs are simply on PATH.
                if (Platform.isWindows)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _wslMode,
                    onChanged: (v) => setState(() => _wslMode = v),
                    title: const Text('Modalità WSL'),
                    subtitle: const Text(
                      'Esegui la CLI in una shell di login WSL.',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _providerFields() {
    if (_provider == AiProvider.claudeCode) {
      return Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _claudeModel,
              decoration: const InputDecoration(labelText: 'Modello'),
              // Only these efforts: the CLI's xhigh and max are not offered.
              items: const [
                DropdownMenuItem(value: 'sonnet', child: Text('Sonnet')),
                DropdownMenuItem(value: 'opus', child: Text('Opus')),
              ],
              onChanged: (v) => setState(() => _claudeModel = v!),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _claudeEffort,
              decoration: const InputDecoration(labelText: 'Sforzo'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'high', child: Text('High')),
              ],
              onChanged: (v) => setState(() => _claudeEffort = v!),
            ),
          ),
        ],
      );
    }
    final fields = _freeText[_provider]!;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: fields.model,
            decoration: const InputDecoration(
              labelText: 'Modello',
              helperText: 'Vuoto: non passare il flag',
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: fields.effort,
            decoration: const InputDecoration(
              labelText: 'Sforzo',
              helperText: 'Vuoto: non passare il flag',
            ),
          ),
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
            // Applied and persisted instantly — the theme is the one setting
            // Salva does not concern; retention and AI wait for the button.
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
            _aiSection(context),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Salva')),
          ],
        ),
      ),
    );
  }
}
