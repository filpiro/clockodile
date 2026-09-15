import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:catui/catui.dart';

import 'cubit/ai_cubit.dart';
import 'llama_config.dart';
import 'llama_protocol.dart';

/// Confirm with the real size, then the blocking download modal. With nothing
/// to download there is no confirm and no modal: AI just turns on.
/// [update] is the strip's Aggiorna: AI is already on.
Future<void> runAiInstall(
  BuildContext context,
  AiCubit cubit, {
  required bool update,
}) async {
  final install = update ? cubit.update : cubit.enable;
  if (cubit.state.pendingBytes == 0) return install();
  final size = formatBytes(cubit.state.pendingBytes);
  final ok = await catConfirm(
    context,
    title: update ? 'Aggiornare i file AI?' : "Attivare l'AI locale?",
    message: update
        ? 'Serve un download di circa $size.'
        : 'Clockodile scaricherà il motore llama.cpp e il modello Qwen3 '
              '1.7B (circa $size) nella cartella dell\'app. Il testo delle '
              'note non lascia mai questo computer.',
    confirm: 'Scarica',
    cancel: 'Annulla',
  );
  if (!ok || !context.mounted) return;

  final navigator = Navigator.of(context);
  // The modal stays open only to show a failure; success and cancel close it.
  Future<void> attempt() async {
    await install();
    if (cubit.state.installFailure == null) navigator.pop();
  }

  final closed = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _InstallModal(onRetry: attempt),
    ),
  );
  attempt();
  await closed;
}

class _InstallModal extends StatelessWidget {
  const _InstallModal({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AiCubit>();
    final state = cubit.state;
    final failure = state.installFailure;
    final progress = state.progress;
    return AlertDialog(
      title: const Text('Download AI locale'),
      content: SizedBox(
        width: 360,
        child: failure != null
            ? Text(installFailureMessage(failure, state.pendingBytes))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_progressLine(progress)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress?.total == null
                        ? null
                        : progress!.received / progress.total!,
                  ),
                ],
              ),
      ),
      actions: failure != null
          ? [
              TextButton(
                onPressed: () {
                  cubit.dismissInstallFailure();
                  Navigator.pop(context);
                },
                child: const Text('Chiudi'),
              ),
              FilledButton(onPressed: onRetry, child: const Text('Riprova')),
            ]
          : [
              TextButton(
                onPressed: cubit.cancelInstall,
                child: const Text('Annulla'),
              ),
            ],
    );
  }

  static String _progressLine(InstallProgress? p) {
    if (p == null) return 'Connessione…';
    if (p.total == null) return p.label;
    return '${p.label} — ${_amount(p.received, p.total!)}';
  }

  /// `12 / 18 MB`, `0,4 / 1,3 GB`: both in the total's unit.
  static String _amount(int received, int total) {
    final t = formatBytes(total);
    final unit = t.endsWith('GB') ? 'GB' : 'MB';
    final r = unit == 'GB'
        ? (received / 1e9).toStringAsFixed(1).replaceAll('.', ',')
        : '${(received / 1e6).round()}';
    return '$r / $t';
  }
}

/// Asks before removing the files; [AiCubit.deleteFiles] on Elimina.
Future<void> confirmAiDelete(BuildContext context, AiCubit cubit) async {
  final ok = await catConfirm(
    context,
    title: "Eliminare l'AI locale?",
    message:
        'llama.cpp e il modello verranno rimossi da questo computer. '
        "Potrai riscaricarli riattivando l'AI.",
    confirm: 'Elimina',
    cancel: 'Annulla',
    danger: true,
  );
  if (ok) await cubit.deleteFiles();
}

/// The size "Elimina modello" frees.
final installedSize = formatBytes(
  AiConfig.llamaUnpackedBytes + AiConfig.modelBytes,
);
