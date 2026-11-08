import 'dart:async';

import 'package:flutter/material.dart';

import 'cloud.dart';
import 'quick_add.dart';
import 'screens/shell.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  final cloud = CloudService(store);
  await cloud.init(); // quick; sync itself runs in the background
  runApp(PocketLedgerApp(store: store, cloud: cloud));
}

/// Second entry point, started by QuickAddActivity (home-screen widget and
/// launcher shortcut). Local only: the main app syncs the entry later.
/// Must stay top-level and annotated.
@pragma('vm:entry-point')
Future<void> quickAddMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(QuickAddApp(store: store));
}

class PocketLedgerApp extends StatefulWidget {
  final AppStore store;
  final CloudService cloud;
  const PocketLedgerApp({super.key, required this.store, required this.cloud});

  @override
  State<PocketLedgerApp> createState() => _PocketLedgerAppState();
}

class _PocketLedgerAppState extends State<PocketLedgerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Entries may have been added via the widget popup, or on another phone.
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.store.load().then((_) => widget.cloud.syncNow()));
    }
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF00796B);
    return MaterialApp(
      title: 'Pocket Ledger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: Shell(store: widget.store, cloud: widget.cloud),
    );
  }
}
