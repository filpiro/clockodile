import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ai_install_dialogs.dart';
import 'cubit/ai_cubit.dart';
import 'llama_config.dart';
import 'llama_protocol.dart';

/// A thin line under the whole app for the Local Model's starting, broken and
/// out-of-date states. Takes no space when all is well. Sits above the
/// Navigator, so its dialogs open through [navigatorKey].
class AiStatusStrip extends StatelessWidget {
  const AiStatusStrip({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AiCubit>();
    final state = cubit.state;
    if (!state.enabled) return const SizedBox.shrink();
    final (
      String text,
      String? action,
      VoidCallback? onAction,
    ) = switch (state.status) {
      LocalAiStatus.notInstalled => (
        'File AI mancanti o da aggiornare',
        'Aggiorna (${formatBytes(state.pendingBytes)})',
        () => runAiInstall(navigatorKey.currentContext!, cubit, update: true),
      ),
      LocalAiStatus.starting => ('Avvio AI locale…', null, null),
      LocalAiStatus.error => (
        state.noFreePort
            ? 'AI locale non avviata: nessuna porta libera '
                  '(${AiConfig.portRangeStart}–${AiConfig.portRangeEnd})'
            : 'AI locale non avviata',
        'Riprova',
        cubit.retry,
      ),
      LocalAiStatus.installing || LocalAiStatus.ready => ('', null, null),
    };
    if (text.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isError = state.status == LocalAiStatus.error;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onSurfaceVariant;
    return Material(
      color: isError ? scheme.errorContainer : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            if (state.status == LocalAiStatus.starting) ...[
              const SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ),
            if (action != null)
              TextButton(
                // Stock button padding turns the strip into a 48px bar; this
                // keeps it a line of text with a link on the end.
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.bodySmall,
                ),
                onPressed: onAction,
                child: Text(action),
              ),
          ],
        ),
      ),
    );
  }
}
