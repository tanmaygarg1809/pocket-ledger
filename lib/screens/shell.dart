import 'package:flutter/material.dart';

import '../cloud.dart';
import '../store.dart';
import 'add_txn.dart';
import 'budgets.dart';
import 'overview.dart';
import 'settings.dart';
import 'year.dart';
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
  Widget build(BuildContext context) {
    final s = widget.store;
    final pages = <Widget>[
      OverviewScreen(store: s),
      TransactionsScreen(store: s),
      BudgetsScreen(store: s),
      YearScreen(store: s),
      SettingsScreen(store: s, cloud: widget.cloud),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_index]),
      floatingActionButton: _index <= 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AddTxnScreen(store: s)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Overview'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Activity'),
          NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag),
              label: 'Budgets'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Year'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }
}
