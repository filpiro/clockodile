import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:catui/catui.dart';

import '../../data/db/database.dart';
import '../../shared/utils/format.dart';
import '../../shared/widgets/client_field.dart';
import '../ai/ai_provider.dart';
import '../ai/cubit/ai_cubit.dart';
import '../ai/summary_command.dart';
import 'cubit/entries_cubit.dart';

/// No [entry] → create a new Entry born active (no end field, spec).
/// With [entry] → edit client/note and the entry's sessions.
Future<void> openEntryPage(
  BuildContext context, {
  Entry? entry,
  Client? client,
}) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => _EntryPage(entry, client)));
}

/// Local editable copy of one session row.
class _EditableSession {
  final int id;
  DateTime start;
  DateTime? end;
  final bool wasOpen;
  _EditableSession(Session s)
    : id = s.id,
      start = s.start,
      end = s.end,
      wasOpen = s.end == null;

  bool get invalid => end != null && end!.isBefore(start);
}

class _EntryPage extends StatefulWidget {
  final Entry? entry;
  final Client? client;
  const _EntryPage(this.entry, this.client);

  bool get isCreate => entry == null;

  @override
  State<_EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<_EntryPage> {
  late final _client = TextEditingController(text: widget.client?.name ?? '');
  late final _note = TextEditingController(text: widget.entry?.note ?? '');
  // Create mode only: start of the first session, backdating allowed.
  DateTime _start = DateTime.now();
  // Edit mode only: the entry's sessions, loaded once.
  List<_EditableSession>? _sessions;
  // Non-null while a summary is in flight; completing it abandons the request.
  Completer<void>? _cancel;

  bool get _invalid => _sessions?.any((s) => s.invalid) ?? false;
  bool get _generating => _cancel != null;

  @override
  void initState() {
    super.initState();
    if (!widget.isCreate) {
      context.read<EntriesCubit>().sessionsOfEntry(widget.entry!.id).then((
        rows,
      ) {
        if (mounted) {
          setState(() => _sessions = rows.map(_EditableSession.new).toList());
        }
      });
    }
  }

  @override
  void dispose() {
    // Leaving abandons a summary still in flight.
    if (_cancel?.isCompleted == false) _cancel!.complete();
    _client.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    final cubit = context.read<EntriesCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (widget.isCreate) {
        await cubit.createEntry(
          clientName: _client.text,
          startTime: _start,
          note: _note.text,
        );
      } else {
        await cubit.updateEntryFields(
          widget.entry!.id,
          clientName: _client.text,
          note: _note.text,
        );
        for (final s in _sessions ?? const <_EditableSession>[]) {
          await cubit.updateSession(s.id, start: s.start, end: s.end);
        }
      }
      navigator.pop();
    } catch (_) {
      catSnack(messenger, 'Salvataggio fallito');
    }
  }

  /// Replaces the whole Nota with a one-line summary, or leaves it exactly as
  /// it was and says why. There is no undo: the pasted email is still in the
  /// user's mail client (ADR 0002).
  Future<void> _summarise() async {
    final ai = context.read<AiCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final cancel = Completer<void>();
    setState(() => _cancel = cancel);

    AiFailure? failure;
    String? summary;
    try {
      summary = await ai.summarize(_note.text, cancelled: cancel.future);
    } on AiFailure catch (err) {
      failure = err;
    }
    if (!mounted) return;
    setState(() {
      _cancel = null;
      if (summary != null) _note.text = summary;
    });
    if (failure != null && failure is! AiCancelled) {
      catSnack(messenger, failure.message);
    }
  }

  Future<void> _deleteSession(_EditableSession s) async {
    final cubit = context.read<EntriesCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await cubit.deleteSession(s.id);
    if (!mounted) return;
    if (ok) {
      setState(() => _sessions!.removeWhere((x) => x.id == s.id));
    } else {
      catSnack(
        messenger,
        "Ultima sessione: elimina l'attività per rimuoverla.",
      );
    }
  }

  Widget _sessionTile(_EditableSession s) {
    final isLast = _sessions!.length <= 1;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Row(
                  children: [
                    _stamp('Inizio', s.start, (v) => s.start = v),
                    const SizedBox(width: 12),
                    s.end == null && s.wasOpen
                        ? _openEnd(s)
                        : _stamp('Fine', s.end!, (v) => s.end = v),
                  ],
                ),
                subtitle: s.invalid
                    ? Text(
                        "La fine deve essere dopo l'inizio",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : (s.end == null
                          ? null
                          : Text(formatHm(s.end!.difference(s.start)))),
              ),
            ),
            DeleteIconButton(
              tooltip: isLast
                  ? 'Ultima sessione — non eliminabile'
                  : 'Elimina sessione',
              onPressed: isLast ? null : () => _deleteSession(s),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stamp(String label, DateTime value, void Function(DateTime) set) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          final v = await _pick(value);
          if (v != null) setState(() => set(v));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text('${dmy(value)} ${hhmm(value)}'),
          ],
        ),
      ),
    );
  }

  /// Open session's end: empty and settable — manual close with custom
  /// timestamp. Never clearable once set (no reopening).
  Widget _openEnd(_EditableSession s) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          final v = await _pick(DateTime.now());
          if (v != null) setState(() => s.end = v);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fine', style: Theme.of(context).textTheme.labelSmall),
            const Text('non impostata — in corso'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_invalid && _client.text.trim().isNotEmpty;
    final isMac = Platform.isMacOS;
    return CallbackShortcuts(
      bindings: {
        SingleActivator(
          LogicalKeyboardKey.keyS,
          control: !isMac,
          meta: isMac,
        ): () {
          if (canSave) _save();
        },
      },
      // The route's own focus scope suppresses the HomeShell shortcuts; a
      // focused node inside this subtree is needed for ours to fire. On
      // create the client field autofocuses; on edit the wrapper does.
      child: Focus(
        autofocus: !widget.isCreate,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.isCreate ? 'Nuova attività' : 'Modifica attività',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: canSave ? _save : null,
                child: const Text('Salva'),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: _body(),
        ),
      ),
    );
  }

  /// Grows from three lines to eight, then scrolls rather than pushing Salva
  /// off screen. The AI button sits inside the border at the bottom right, in
  /// a strip the content padding reserves — a `suffixIcon` would centre it
  /// vertically and sit in the text's way.
  Widget _noteField() {
    const buttonStrip = 40.0;
    // The cubit only ever turns AI on under Windows.
    final ai = context.watch<AiCubit>().state;
    final aiOn = ai.enabled;
    final canSummarise =
        ai.status == LocalAiStatus.ready &&
        !_generating &&
        hasEnoughWordsForSummary(_note.text);
    return Stack(
      children: [
        Opacity(
          opacity: _generating ? 0.5 : 1,
          child: TextField(
            controller: _note,
            enabled: !_generating,
            minLines: 3,
            maxLines: 8,
            onChanged: (_) => setState(() {}), // the word gate moves live
            decoration: InputDecoration(
              labelText: 'Nota',
              // Without it the label floats in the middle of a multi-line box.
              alignLabelWithHint: true,
              contentPadding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                aiOn ? buttonStrip : 12,
              ),
            ),
          ),
        ),
        // Absent entirely with AI off: the app looks exactly as it did before.
        if (aiOn)
          Positioned(
            right: 4,
            bottom: 0,
            child: IconButton(
              tooltip: 'Riassumi la nota',
              onPressed: canSummarise ? _summarise : null,
              icon: _generating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.sparkles),
            ),
          ),
      ],
    );
  }

  Widget _body() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTokens.formMaxWidth),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ClientField(
              controller: _client,
              autofocus: widget.isCreate,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (widget.isCreate)
              // End hidden entirely on create: new entries are born active.
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Inizio'),
                subtitle: Text('${dmy(_start)} ${hhmm(_start)}'),
                trailing: const Icon(LucideIcons.calendarClock),
                onTap: () async {
                  final v = await _pick(_start);
                  if (v != null) setState(() => _start = v);
                },
              )
            else ...[
              Text('Sessioni', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              if (_sessions == null)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                for (final s in _sessions!) _sessionTile(s),
            ],
            const SizedBox(height: 16),
            _noteField(),
          ],
        ),
      ),
    );
  }
}
