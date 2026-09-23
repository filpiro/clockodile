import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'data/db/database.dart';
import 'features/ai/ai_toast.dart';
import 'features/ai/cubit/ai_cubit.dart';
import 'features/ai/llama_config.dart';
import 'features/ai/llama_installer.dart';
import 'features/ai/llama_provider.dart';
import 'features/ai/llama_runtime.dart';
import 'features/clients/clients_view.dart';
import 'features/clients/cubit/clients_cubit.dart';
import 'features/entries/cubit/entries_cubit.dart';
import 'shared/widgets/date_filter_bar.dart';
import 'features/entries/entries_view.dart';
import 'features/entries/entry_edit_page.dart';
import 'features/help/help_view.dart';
import 'features/report/cubit/report_cubit.dart';
import 'features/report/report_view.dart';
import 'features/settings/cubit/theme_cubit.dart';
import 'features/settings/settings_view.dart';
import 'shared/theme.dart';
import 'shared/widgets/app_toast.dart';
import 'shadcn_it.dart';

const _instancePort = 38573;

/// Single-instance lock: the bound socket doubles as IPC — any incoming
/// connection means a second instance launched, so come to front.
/// Rationale and known holes: docs/adr/0001-single-instance-loopback-socket.md
Future<void> _acquireInstanceLockOrExit() async {
  try {
    final socket = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      _instancePort,
    );
    socket.listen((client) async {
      client.destroy();
      // show() alone doesn't un-minimize on Windows. focus() may still be
      // denied by the OS foreground lock — taskbar flashes instead.
      if (await windowManager.isMinimized()) await windowManager.restore();
      await windowManager.show();
      await windowManager.focus();
    });
  } on SocketException {
    // Another instance holds the port: poke it to the foreground, then die.
    try {
      final s = await Socket.connect(
        InternetAddress.loopbackIPv4,
        _instancePort,
        timeout: const Duration(seconds: 2),
      );
      s.destroy();
    } catch (_) {}
    exit(0);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await _acquireInstanceLockOrExit();

  // Native title bar hidden: _TitleBar below draws a themed one instead.
  const options = WindowOptions(
    size: Size(900, 640),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final db = AppDatabase();
  // A delete on a local file: milliseconds, and the window is still hidden.
  await db.purgeExpiredEntries();
  final aiPaths = LlamaPaths.production();
  runApp(
    RepositoryProvider.value(
      value: db,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => EntriesCubit(db)),
          BlocProvider(create: (_) => ClientsCubit(db)),
          BlocProvider(create: (_) => ReportCubit(db)),
          BlocProvider(create: (_) => ThemeCubit(db)),
          // Not lazy: the Local Model starts when the app opens. Created
          // after the instance lock, so a second instance never touches it.
          BlocProvider(
            lazy: false,
            create: (_) => AiCubit(
              db: db,
              paths: aiPaths,
              installer: LlamaInstaller(aiPaths),
              runtime: LlamaRuntime(aiPaths),
              providerFor: LlamaCppProvider.new,
            )..init(),
          ),
        ],
        child: const ClockodileApp(),
      ),
    ),
  );
}

class ClockodileApp extends StatelessWidget {
  const ClockodileApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeCubit>().state;
    return ShadcnApp(
      title: 'Clockodile',
      navigatorKey: navigatorKey,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: const [
        ShadcnLocalizationsIt.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.keyW, control: true):
            VoidCallbackIntent(windowManager.close),
      },
      actions: {
        ...WidgetsApp.defaultActions,
        VoidCallbackIntent: VoidCallbackAction(),
      },
      // Caption and the Local Model listener sit above the Navigator so they
      // survive pushed routes. Toasts are ShadcnApp's own layer, above both.
      builder: (context, child) => Column(
        children: [
          const _TitleBar(),
          Expanded(
            child: AiToastHost(navigatorKey: navigatorKey, child: child!),
          ),
        ],
      ),
      home: const HomeShell(),
    );
  }
}

/// Drag to move, double-click to maximise, and the three window buttons.
/// Hand-made: window_manager's WindowCaption is a Material widget.
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  Future<void> _toggleMaximize() async => await windowManager.isMaximized()
      ? windowManager.unmaximize()
      : windowManager.maximize();

  @override
  Widget build(BuildContext context) {
    Widget button(
      IconData icon,
      VoidCallback onPressed, {
      AbstractButtonStyle variance = const ButtonStyle.ghostIcon(),
    }) => IconButton(
      variance: variance,
      density: ButtonDensity.icon,
      size: ButtonSize.small,
      icon: Icon(icon),
      onPressed: onPressed,
    );
    return Container(
      height: kWindowCaptionHeight,
      color: Theme.of(context).colorScheme.background,
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: const Text('Clockodile').small().muted(),
                ),
              ),
            ),
          ),
          button(LucideIcons.minus, windowManager.minimize),
          const Gap(8),
          button(LucideIcons.square, _toggleMaximize),
          const Gap(8),
          // White on red, as shadcn's own destructive button does.
          button(
            LucideIcons.x,
            windowManager.close,
            variance: const ButtonStyle.ghostIcon()
                .withBackgroundColor(
                  hoverColor: Theme.of(context).colorScheme.destructive,
                )
                .withForegroundColor(hoverColor: Colors.white),
          ),
          const Gap(4),
        ],
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WindowListener {
  static const _reportIndex = 2;
  static const _helpIndex = 3;
  static const _settingsIndex = 4;
  int _index = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    // Close waits for the Local Model to be killed; Ctrl+W takes this path
    // too. A crash skips it, and the PID file covers that on the next start.
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    // close() below re-emits this event.
    if (_closing) return;
    _closing = true;
    await context.read<AiCubit>().shutdown();
    // Not destroy(): on Windows it only posts WM_QUIT, so the engine tears
    // down after the message loop is gone and the window hangs "Not
    // responding" for ~10s. A real close destroys the window inside the loop.
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  /// Shortcuts act on the Attività screen: switch to it first, then run.
  /// CallbackShortcuts is focus-scoped, so an open modal dialog (own focus
  /// scope) suppresses them automatically.
  void _onEntries(void Function(EntriesCubit cubit) act) {
    setState(() => _index = 0);
    act(context.read<EntriesCubit>());
  }

  Widget _navItem(int index, IconData icon, String label) {
    // Icon-only rail: the label lives in the tooltip, to the right. The
    // default (below) has no room at the window's bottom edge and flips
    // over the pointer, which closes it at once.
    return Tooltip(
      alignment: Alignment.centerLeft,
      anchorAlignment: Alignment.centerRight,
      tooltip: (_) => TooltipContainer(child: Text(label)),
      child: NavigationItem(
        selected: _index == index,
        onChanged: (_) => setState(() => _index = index),
        child: Icon(icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMac = Platform.isMacOS;
    SingleActivator mod(LogicalKeyboardKey key) =>
        SingleActivator(key, control: !isMac, meta: isMac);
    return CallbackShortcuts(
      bindings: {
        mod(LogicalKeyboardKey.keyN): () =>
            _onEntries((_) => openEntryPage(context)),
        mod(LogicalKeyboardKey.keyT): () => _onEntries((cubit) {
          if (cubit.state.active != null) cubit.stop();
        }),
        mod(LogicalKeyboardKey.digit1): () =>
            _onEntries((c) => c.setFilter(DateFilter.today)),
        mod(LogicalKeyboardKey.digit2): () =>
            _onEntries((c) => c.setFilter(DateFilter.yesterday)),
        mod(LogicalKeyboardKey.digit3): () =>
            _onEntries((c) => c.setFilter(DateFilter.all)),
        // Export lives on the Report screen: switch there, then export.
        mod(LogicalKeyboardKey.keyS): () {
          setState(() => _index = _reportIndex);
          runReportExport(context);
        },
      },
      child: Focus(
        autofocus: true,
        child: Row(
          children: [
            NavigationRail(
              labelType: NavigationLabelType.none,
              footer: [
                _navItem(
                  _settingsIndex,
                  LucideIcons.settings,
                  'Impostazioni',
                ),
                _navItem(_helpIndex, LucideIcons.circleHelp, 'Aiuto'),
              ],
              children: [
                _navItem(0, LucideIcons.listTodo, 'Attività'),
                _navItem(1, LucideIcons.users, 'Clienti'),
                _navItem(_reportIndex, LucideIcons.fileChartColumn, 'Report'),
              ],
            ),
            const VerticalDivider(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: const [
                  EntriesView(),
                  ClientsView(),
                  ReportView(),
                  HelpView(),
                  SettingsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
