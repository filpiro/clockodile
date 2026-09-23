import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/widgets/app_toast.dart';
import 'ai_install_dialogs.dart';
import 'cubit/ai_cubit.dart';
import 'llama_config.dart';
import 'llama_protocol.dart';

/// Turns the Local Model's starting, broken and out-of-date states into a
/// sticky toast. It renders nothing itself, so it sits above the Navigator as a
/// listener and opens its dialogs through [navigatorKey].
class AiToastHost extends StatefulWidget {
  const AiToastHost({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<AiToastHost> createState() => _AiToastHostState();
}

class _AiToastHostState extends State<AiToastHost> {
  @override
  void initState() {
    super.initState();
    // The cubit starts before this mounts, so the first state needs showing
    // by hand; the listener only sees what changes after it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _show(context.read<AiCubit>().state);
    });
  }

  void _show(AiState state) {
    final cubit = context.read<AiCubit>();
    final (
      String text,
      String? action,
      VoidCallback? onAction,
      bool spinner,
      // AI off reads as `ready`: nothing to say, same as a model that runs.
    ) = switch (state.enabled ? state.status : LocalAiStatus.ready) {
      LocalAiStatus.notInstalled => (
        'File AI mancanti o da aggiornare',
        'Aggiorna (${formatBytes(state.pendingBytes)})',
        () => runAiInstall(
          widget.navigatorKey.currentContext!,
          cubit,
          update: true,
        ),
        false,
      ),
      LocalAiStatus.starting => ('Avvio AI locale…', null, null, true),
      LocalAiStatus.error => (
        state.noFreePort
            ? 'AI locale non avviata: nessuna porta libera '
                  '(${AiConfig.portRangeStart}–${AiConfig.portRangeEnd})'
            : 'AI locale non avviata',
        'Riprova',
        cubit.retry,
        false,
      ),
      LocalAiStatus.installing ||
      LocalAiStatus.ready => ('', null, null, false),
    };
    // A resolved state has nothing to say: its toast goes.
    if (text.isEmpty) {
      dismissToast();
    } else {
      showToast(
        text,
        action: action,
        onAction: onAction,
        spinner: spinner,
        sticky: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<AiCubit, AiState>(
    // AiState has no value equality, so every tick is a new object: without
    // naming the fields the toast reads, an install's progress ticks would
    // re-show it a few times a second. Keep this in step with [_show].
    listenWhen: (a, b) =>
        a.status != b.status ||
        a.enabled != b.enabled ||
        a.noFreePort != b.noFreePort ||
        a.pendingBytes != b.pendingBytes,
    listener: (_, state) => _show(state),
    child: widget.child,
  );
}
