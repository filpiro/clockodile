import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:catui/catui.dart';
import 'package:window_manager/window_manager.dart';

import 'data/db/database.dart';
import 'features/clients/clients_view.dart';
import 'features/clients/cubit/clients_cubit.dart';
import 'features/entries/cubit/entries_cubit.dart';
import 'features/entries/entries_view.dart';
import 'features/entries/entry_edit_page.dart';
import 'features/help/help_view.dart';
import 'features/report/cubit/report_cubit.dart';
import 'features/report/report_view.dart';
import 'features/settings/cubit/theme_cubit.dart';
import 'features/settings/settings_view.dart';
import 'shared/theme.dart';

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

  // Native title bar hidden: WindowCaption below draws a themed one instead.
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
  final purge = db.purgeExpiredEntries();
  runApp(
    RepositoryProvider.value(
      value: db,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => EntriesCubit(db)),
          BlocProvider(create: (_) => ClientsCubit(db)),
          BlocProvider(create: (_) => ReportCubit(db)),
          BlocProvider(create: (_) => ThemeCubit(db)),
        ],
        child: ClockodileApp(purge: purge),
      ),
    ),
  );
}

class ClockodileApp extends StatelessWidget {
  const ClockodileApp({super.key, required this.purge});

  final Future<void> purge;

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeCubit>().state;
    return MaterialApp(
      title: 'Clockodile',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.keyW, control: true):
            VoidCallbackIntent(windowManager.close),
      },
      actions: {
        ...WidgetsApp.defaultActions,
        VoidCallbackIntent: VoidCallbackAction(),
      },
      // Caption sits above the Navigator so it survives pushed routes.
      builder: (context, child) => Column(
        children: [
          SizedBox(
            height: kWindowCaptionHeight,
            child: WindowCaption(
              title: const Text('Clockodile'),
              backgroundColor: Theme.of(context).colorScheme.surface,
              brightness: Theme.of(context).brightness,
            ),
          ),
          Expanded(child: child!),
        ],
      ),
      home: FutureBuilder<void>(
        future: purge,
        builder: (context, snap) => snap.connectionState == ConnectionState.done
            ? const HomeShell()
            : const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _reportIndex = 2;
  static const _helpIndex = 3;
  static const _settingsIndex = 4;
  int _index = 0;

  /// Shortcuts act on the Attività screen: switch to it first, then run.
  /// CallbackShortcuts is focus-scoped, so an open modal dialog (own focus
  /// scope) suppresses them automatically.
  void _onEntries(void Function(EntriesCubit cubit) act) {
    setState(() => _index = 0);
    act(context.read<EntriesCubit>());
  }

  Widget _navButton(int index, IconData icon, String tooltip) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 20,
      isSelected: _index == index,
      icon: Icon(icon),
      onPressed: () => setState(() => _index = index),
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
        child: Scaffold(
          body: Row(
            children: [
              // Uniform sidebar: every destination is the same icon-only
              // IconButton (tooltip + isSelected tint), top or bottom.
              SizedBox(
                width: 64,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _navButton(0, LucideIcons.listTodo, 'Attività'),
                    _navButton(1, LucideIcons.users, 'Clienti'),
                    _navButton(2, LucideIcons.fileChartColumn, 'Report'),
                    const Spacer(),
                    _navButton(
                      _settingsIndex,
                      LucideIcons.settings,
                      'Impostazioni',
                    ),
                    _navButton(_helpIndex, LucideIcons.circleHelp, 'Aiuto'),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
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
      ),
    );
  }
}
