import 'dart:async';

import 'package:flutter/material.dart';

import 'app_lock.dart';
import 'cloud.dart';
import 'crypto.dart';
import 'reminders.dart';
import 'quick_add.dart';
import 'screens/shell.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await Crypto.init();
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
  await Crypto.init();
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
  bool _locked = false;
  bool _authing = false;
  DateTime? _pausedAt;
  Timer? _remindTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_onStoreChanged);
    if (widget.store.appLock) {
      _locked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
    _onStoreChanged();
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    _remindTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Keeps bill reminders in step with your recurring bills.
  String _remindKey = '';
  void _onStoreChanged() {
    final s = widget.store;
    final key =
        '${s.remindOn}|${s.remindDays}|${s.payDay}|${s.payOverrides}|${s.rules.map((r) => r.toJson()).toList()}';
    if (key == _remindKey) return;
    _remindKey = key;
    _remindTimer?.cancel();
    _remindTimer = Timer(const Duration(seconds: 3), () => Reminders.reschedule(s));
  }

  Future<void> _unlock() async {
    if (_authing) return;
    _authing = true;
    final ok = await AppLock.authenticate('Unlock Kharcha');
    _authing = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    }
    // Entries may have been added via the widget popup, or on another phone.
    if (state == AppLifecycleState.resumed) {
      final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
      if (widget.store.appLock && away > const Duration(seconds: 45) && !_locked) {
        setState(() => _locked = true);
        _unlock();
      }
      unawaited(widget.store.load().then((_) => widget.cloud.syncNow()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => MaterialApp(
        title: 'Kharcha',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: AppTheme.mode(widget.store.themeMode),
        builder: (context, child) => Stack(
          children: [
            if (child != null) child,
            if (_locked) Positioned.fill(child: LockScreen(onRetry: _unlock)),
          ],
        ),
        home: Shell(store: widget.store, cloud: widget.cloud),
      ),
    );
  }
}
