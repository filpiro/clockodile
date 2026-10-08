import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide showToast;

import '../../data/db/database.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/utils/format.dart';
import '../../shared/widgets/client_field.dart';
import '../../shared/widgets/date_field.dart';
import '../ai/ai_provider.dart';
import '../ai/cubit/ai_cubit.dart';
import '../ai/summary_command.dart';
import 'cubit/entries_cubit.dart';

const _pagePadding = 24.0;
const _editorMaxWidth = 1120.0;
const _twoColumnMinWidth = 720.0;

/// No [entry] → create a new Entry born active (no end field, spec).
/// With [entry] → edit client/note and the entry's sessions.
Future<void> openEntryPage(
  BuildContext context, {
  Entry? entry,
  Client? client,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => _EntryPage(entry, client),
    ),
  );
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

  Future<void> _save() async {
    final cubit = context.read<EntriesCubit>();
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
      showToast('Salvataggio fallito');
    }
  }

  /// Replaces the whole Nota with a one-line summary, or leaves it exactly as
  /// it was and says why. There is no undo: the pasted email is still in the
  /// user's mail client (ADR 0002).
  Future<void> _summarise() async {
    final ai = context.read<AiCubit>();
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
      showToast(failure.message);
    }
  }

  Future<void> _deleteSession(_EditableSession s) async {
    final cubit = context.read<EntriesCubit>();
    final ok = await cubit.deleteSession(s.id);
    if (!mounted) return;
    if (ok) {
      setState(() => _sessions!.removeWhere((x) => x.id == s.id));
    } else {
      showToast("Ultima sessione: elimina l'attività per rimuoverla.");
    }
  }

  Widget _sessionTile(_EditableSession s) {
    final isLast = _sessions!.length <= 1;
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DateTimeField(
                      formKey: FormKey(('start', s.id)),
                      label: 'Inizio',
                      value: s.start,
                      fallback: s.start,
                      onChanged: (v) => setState(() => s.start = v),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    // Open session: "in corso" until set, never cleared.
                    child: _DateTimeField(
                      formKey: FormKey(('end', s.id)),
                      label: 'Fine',
                      placeholder: 'in corso',
                      value: s.end,
                      fallback: s.start,
                      onChanged: (v) => setState(() => s.end = v),
                    ),
                  ),
                ],
              ),
              const Gap(4),
              if (s.invalid)
                Text(
                  "La fine deve essere dopo l'inizio",
                  style: TextStyle(color: theme.colorScheme.destructive),
                ).small()
              else if (s.end != null)
                Text(formatHm(s.end!.difference(s.start))).small().muted(),
            ],
          ),
        ),
        const Gap(8),
        Tooltip(
          tooltip: (_) => TooltipContainer(
            child: Text(
              isLast ? 'Ultima sessione — non eliminabile' : 'Elimina sessione',
            ),
          ),
          child: IconButton(
            variance: const ButtonStyle.ghostIcon().withForegroundColor(
              hoverColor: theme.colorScheme.destructive,
            ),
            density: ButtonDensity.icon,
            icon: const Icon(LucideIcons.trash2),
            onPressed: isLast ? null : () => _deleteSession(s),
          ),
        ),
      ],
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
          loadingProgressIndeterminate: !widget.isCreate && _sessions == null,
          headers: [
            AppBar(
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              title: Text(
                widget.isCreate ? 'Nuova attività' : 'Modifica attività',
              ),
              trailing: [
                OutlineButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annulla'),
                ),
                PrimaryButton(
                  onPressed: canSave ? _save : null,
                  child: const Text('Salva'),
                ),
              ],
            ),
          ],
          child: _body(),
        ),
      ),
    );
  }

  /// Grows from three lines to six, then scrolls rather than pushing Salva
  /// off screen. The AI button sits inside the border at the bottom right, in
  /// a strip the bottom padding reserves — a trailing feature would centre it
  /// vertically and sit in the text's way.
  Widget _noteField() {
    const buttonStrip = 40.0;
    final theme = Theme.of(context);
    // shadcn TextField's own default padding (0.75 × content padding at the
    // sides, one gap on top), bar the reserved strip.
    final side = theme.density.baseContentPadding * theme.scaling * 0.75;
    final top = theme.density.baseGap * theme.scaling;
    // The cubit only ever turns AI on under Windows.
    final ai = context.watch<AiCubit>().state;
    final aiOn = ai.enabled;
    final canSummarise =
        ai.status == LocalAiStatus.ready &&
        !_generating &&
        hasEnoughWordsForSummary(_note.text);
    return FormField(
      key: const FormKey(#note),
      label: const Text('Nota'),
      child: Stack(
        children: [
          Opacity(
            opacity: _generating ? 0.5 : 1,
            child: TextField(
              controller: _note,
              enabled: !_generating,
              minLines: 3,
              maxLines: 6,
              padding: aiOn
                  ? EdgeInsets.fromLTRB(side, top, side, buttonStrip)
                  : null,
              onChanged: (_) => setState(() {}), // the word gate moves live
            ),
          ),
          // Absent entirely with AI off: the app looks exactly as it did before.
          if (aiOn)
            Positioned(
              right: 4,
              bottom: 4,
              child: Tooltip(
                tooltip: (_) =>
                    const TooltipContainer(child: Text('Riassumi la nota')),
                child: IconButton(
                  variance: ButtonStyle.ghostIcon(),
                  density: ButtonDensity.icon,
                  onPressed: canSummarise ? _summarise : null,
                  icon: _generating
                      ? const CircularProgressIndicator()
                      : const Icon(LucideIcons.sparkles),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    final details = <Widget>[
      FormField(
        key: const FormKey(#client),
        label: const Text('Cliente'),
        child: ClientField(
          controller: _client,
          autofocus: widget.isCreate,
          onChanged: (_) => setState(() {}),
        ),
      ),
      const Gap(16),
      _noteField(),
    ];
    final times = <Widget>[
      if (widget.isCreate)
        // End hidden entirely on create: new entries are born active.
        _DateTimeField(
          formKey: const FormKey(#start),
          label: 'Inizio',
          value: _start,
          fallback: _start,
          onChanged: (v) => setState(() => _start = v),
        )
      else ...[
        const Text('Sessioni').h4(),
        const Gap(8),
        for (final s in _sessions ?? const <_EditableSession>[]) ...[
          _sessionTile(s),
          const Gap(16),
        ],
      ],
    ];
    return Padding(
      padding: const EdgeInsets.all(_pagePadding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _editorMaxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth < _twoColumnMinWidth
                ? ListView(
                    primary: false,
                    children: [...details, const Gap(16), ...times],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView(primary: false, children: details),
                      ),
                      const Gap(24),
                      const VerticalDivider(),
                      const Gap(24),
                      Expanded(
                        child: ListView(primary: false, children: times),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// A day above a time, both editing one [DateTime]. While [value]
/// is null, a pick borrows the other half from [fallback].
class _DateTimeField extends StatelessWidget {
  final FormKey<Object> formKey;
  final String label;
  final String? placeholder;
  final DateTime? value;
  final DateTime fallback;
  final ValueChanged<DateTime> onChanged;

  const _DateTimeField({
    required this.formKey,
    required this.label,
    this.placeholder,
    required this.value,
    required this.fallback,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final base = value ?? fallback;
    final hint = placeholder == null ? null : Text(placeholder!);
    return FormField(
      key: formKey,
      label: Text(label),
      // Day above time: side by side they crowd each other.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DateField(
            value: value,
            placeholder: hint,
            onChanged: (d) {
              if (d == null) return;
              onChanged(
                DateTime(d.year, d.month, d.day, base.hour, base.minute),
              );
            },
          ),
          const Gap(8),
          TimePicker(
            value: value == null ? null : TimeOfDay.fromDateTime(value!),
            placeholder: hint,
            onChanged: (t) {
              if (t == null) return;
              onChanged(
                DateTime(base.year, base.month, base.day, t.hour, t.minute),
              );
            },
          ),
        ],
      ),
    );
  }
}
