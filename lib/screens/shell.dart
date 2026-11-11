import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cloud.dart';
import '../store.dart';
import 'add_txn.dart';
import 'auth.dart';
import 'paid_to.dart';
import 'debts.dart';
import 'income.dart';
import 'overview.dart';
import 'settings.dart';
import 'net_worth.dart';
import 'transactions.dart';

class Shell extends StatefulWidget {
  final AppStore store;
  final CloudService cloud;
  const Shell({super.key, required this.store, required this.cloud});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeWelcome());
  }

  /// First time the app opens with accounts available: offer to sign in.
  Future<void> _maybeWelcome() async {
    final cloud = widget.cloud;
    if (!cloud.available || cloud.user != null) return;
    final p = await SharedPreferences.getInstance();
    if (p.getBool('welcome_seen_v1') == true) return;
    await p.setBool('welcome_seen_v1', true);
    if (!mounted) return;
    final go = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_done_outlined, size: 40),
              const SizedBox(height: 12),
              Text('Keep your data safe',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'Create a free account to back up your data and use it on more than one phone. '
                  'Only you can see it. You can also skip this and add an account later in Settings.'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sign in or create account')),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Not now')),
              ),
            ],
          ),
        ),
      ),
    );
    if (go == true && mounted) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => AuthScreen(cloud: cloud)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final pages = <Widget>[
      OverviewScreen(store: s),
      TransactionsScreen(store: s),
      PaidToScreen(store: s),
      DebtsScreen(store: s),
      NetWorthScreen(store: s),
    ];
    Widget item(IconData icon, String label, Widget Function() page) => ListTile(
          leading: Icon(icon),
          title: Text(label),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => page()));
          },
        );
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Text('Kharcha',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              item(Icons.south_west, 'Income', () => IncomeScreen(store: s)),
              item(
                  Icons.settings_outlined,
                  'Settings and backup',
                  () => Scaffold(
                        appBar: AppBar(title: const Text('Settings')),
                        body: SafeArea(child: SettingsScreen(store: s, cloud: widget.cloud)),
                      )),
            ],
          ),
        ),
      ),
      body: SafeArea(child: pages[_index]),
      floatingActionButton: _index <= 1
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFFD3F5F0),
                      foregroundColor: const Color(0xFF0F766E)),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => AddTxnScreen(store: s, initialMode: 1)),
                  ),
                  icon: const Icon(Icons.south_west, size: 16),
                  label: const Text('Money in', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'add_expense',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AddTxnScreen(store: s)),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Paid out'),
                ),
              ],
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Expense entries'),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Report'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_outlined),
              selectedIcon: Icon(Icons.account_balance),
              label: 'Debts'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Net worth'),
        ],
      ),
    );
  }
}
