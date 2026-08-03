import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cat_ui/cat_ui.dart';

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

  @override
  void initState() {
    super.initState();
    context.read<AppDatabase>().getRetentionDays().then((days) {
      if (!mounted) return;
      setState(() {
        _storedDays = days;
        _controller.text = '$days';
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
    await db.setRetentionDays(days);
    await db.purgeExpiredEntries();
    if (!mounted) return;
    setState(() => _storedDays = days);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Impostazioni salvate')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            // Applied and persisted instantly — Salva only concerns retention.
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
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Salva')),
          ],
        ),
      ),
    );
  }
}
