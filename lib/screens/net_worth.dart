import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Category;
import 'package:intl/intl.dart';

import '../store.dart';
import 'debts.dart';
import '../wealth.dart';
import 'account_detail.dart';
import 'add_account.dart';
import 'add_policy.dart';
import 'compare_worth.dart';
import 'members.dart';

const _coral = Color(0xFFFF6B5E);
const _green = Color(0xFF2EAD6B);

/// Whole-pound money (net worth does not need pennies).
String wMoney(AppStore s, double v, {bool sign = false}) {
  final txt = '${s.currency}${NumberFormat('#,##0').format(v.abs())}';
  if (v < 0) return '-$txt';
  return sign && v > 0 ? '+$txt' : txt;
}

Color groupColor(String g) {
  switch (g) {
    case 'Cash & bank':
      return _green;
    case 'Investments':
      return const Color(0xFF3B82F6);
    case 'Pensions':
      return const Color(0xFF8B5CF6);
    case 'Gold & valuables':
      return const Color(0xFFF5B83D);
    case 'Property':
      return _coral;
    case 'Debts':
    case 'Debts paid down':
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF78909C);
  }
}

IconData kindIcon(AccountKind k) {
  switch (k) {
    case AccountKind.bank:
      return Icons.account_balance;
    case AccountKind.savings:
      return Icons.savings;
    case AccountKind.cash:
      return Icons.payments;
    case AccountKind.investment:
      return Icons.trending_up;
    case AccountKind.pension:
      return Icons.account_balance_wallet;
    case AccountKind.gold:
      return Icons.workspace_premium;
    case AccountKind.jewellery:
      return Icons.diamond;
    case AccountKind.property:
      return Icons.home;
    case AccountKind.other:
      return Icons.category;
    case AccountKind.loan:
      return Icons.credit_card;
  }
}

Color kindColor(AccountKind k) => k.isDebt ? _coral : groupColor(k.group);

/// Smooth line of values over time, with a few labels underneath.
class WealthLine extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final double height;
  const WealthLine({
    super.key,
    required this.values,
    required this.labels,
    this.color = const Color(0xFF0A8A7C),
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: 60,
        child: Center(
          child: Text('Add values over time to see growth.',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      );
    }
    var lo = values.first, hi = values.first;
    for (final v in values) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    final pad = (hi - lo) == 0 ? (hi.abs() * 0.05 + 1) : (hi - lo) * 0.2;
    final step = (values.length / 6).ceil().clamp(1, 100).toInt();
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: lo - pad,
          maxY: hi + pad,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  final show = i >= 0 &&
                      i < labels.length &&
                      (i % step == 0 || i == labels.length - 1);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(show ? labels[i] : '',
                        style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.15)),
            ),
          ],
        ),
      ),
    );
  }
}

class NetWorthScreen extends StatefulWidget {
  final AppStore store;
  const NetWorthScreen({super.key, required this.store});

  @override
  State<NetWorthScreen> createState() => _NetWorthScreenState();
}

class _NetWorthScreenState extends State<NetWorthScreen> {
  int _months = 12; // 3, 6, 12, or 0 = all

  AppStore get store => widget.store;

  int _span() {
    if (_months != 0) return _months;
    DateTime? first;
    for (final a in store.wealth.listed) {
      for (final p in a.history) {
        if (first == null || p.date.isBefore(first)) first = p.date;
      }
    }
    if (first == null) return 12;
    final n = DateTime.now();
    return ((n.year - first.year) * 12 + n.month - first.month + 1).clamp(2, 120).toInt();
  }

  void _add() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Account or asset'),
              subtitle: const Text('Bank, savings, gold, pension, property, a loan...'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AddAccountScreen(store: store)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Insurance policy'),
              subtitle: const Text('Life, home, car, health... kept for reference'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AddPolicyScreen(store: store)));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final w = store.wealth;
        final f0 = store.wealthFilter;
        final String? f =
            (f0 != null && f0 != Wealth.joint && !w.people.any((m) => m.id == f0)) ? null : f0;
        final text = Theme.of(context).textTheme;
        final scheme = Theme.of(context).colorScheme;
        final series = w.series(_span() + 1, owner: f);
        final values = [for (final p in series) p.value];
        final labels = [for (final p in series) DateFormat('MMM').format(p.date)];
        final prevMonth = series.length >= 2 ? series[series.length - 2].value : 0.0;
        final first = series.first.value;
        final owed = f == null ? store.totalOwed : 0.0;
        final nw = w.netWorthOf(f) - owed;
        final monthChange = nw - prevMonth;
        final rangeChange = nw - first;
        final title = f == null ? 'Family net worth' : '${w.ownerName(f)}${f == Wealth.joint ? '' : "'s"} net worth';

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(w.hasFamily ? 'Family' : 'Net worth',
                        style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => MembersScreen(store: store))),
                    icon: const Icon(Icons.group_add_outlined, size: 20),
                    label: Text(w.people.length > 1 ? 'People' : 'Add family'),
                  ),
                ],
              ),
              if (w.hasFamily) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Everyone'),
                      selected: f == null,
                      onSelected: (_) => store.setWealthFilter(null),
                    ),
                    for (final m in w.people)
                      ChoiceChip(
                        label: Text(m.name),
                        selected: f == m.id,
                        onSelected: (_) => store.setWealthFilter(m.id),
                      ),
                    if (w.listed.any((a) => a.owner == Wealth.joint))
                      ChoiceChip(
                        label: const Text('Joint'),
                        selected: f == Wealth.joint,
                        onSelected: (_) => store.setWealthFilter(Wealth.joint),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0A8A7C), Color(0xFF19B59E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(wMoney(store, nw),
                          style: text.headlineLarge?.copyWith(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      if (owed > 0)
                        InkWell(
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => DebtsScreen(store: store))),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                                'After ${wMoney(store, owed)} owed in Debts (tap to open)',
                                style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      if (!w.isEmpty)
                        Text(
                          '${monthChange >= 0 ? '▲' : '▼'} ${wMoney(store, monthChange.abs())} this month'
                          '   ${rangeChange >= 0 ? '▲' : '▼'} ${wMoney(store, rangeChange.abs())} over the period',
                          style: const TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
              if (w.isEmpty && owed > 0) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _Tile('Assets', wMoney(store, 0), null)),
                  const SizedBox(width: 8),
                  Expanded(child: _Tile('Debts', '-${wMoney(store, owed)}', _coral)),
                ]),
                ..._loans(context, owed),
              ] else if (w.isEmpty)
                Card(
                  margin: const EdgeInsets.only(top: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start with one account',
                            style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text(
                            'Add your bank accounts, savings, gold, pension, property and debts. '
                            'Update the values now and then, and this page shows how your net worth grows.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _add,
                          icon: const Icon(Icons.add),
                          label: const Text('Add the first one'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: 12),
                WealthLine(values: values, labels: labels),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final e in const [
                          MapEntry('3M', 3),
                          MapEntry('6M', 6),
                          MapEntry('1Y', 12),
                          MapEntry('All', 0),
                        ])
                          ChoiceChip(
                            label: Text(e.key),
                            selected: _months == e.value,
                            onSelected: (_) => setState(() => _months = e.value),
                          ),
                      ],
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CompareWorthScreen(store: store))),
                      child: const Text('Compare ›'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _Tile('Assets', wMoney(store, w.assetsOf(f)), null)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _Tile(
                            'Debts',
                            (w.debtsOf(f) + owed) > 0
                                ? '-${wMoney(store, w.debtsOf(f) + owed)}'
                                : wMoney(store, 0),
                            _coral)),
                  ],
                ),
                if (f == null && w.hasFamily) _ByPerson(store: store),
                _Allocation(store: store, owner: f),
                for (final g in wealthGroups) ..._group(context, g, scheme, f),
                if (owed > 0) ..._loans(context, owed),
              ],
              _Policies(store: store),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _loans(BuildContext context, double owed) => [
    const Divider(height: 28),
    Row(children: [
      Expanded(
        child: Text('LOANS YOU OWE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold, letterSpacing: 0.6)),
      ),
      Text('-${wMoney(store, owed)}',
          style: const TextStyle(fontWeight: FontWeight.bold)),
    ]),
    for (final d in store.debts.where((d) => !d.cleared))
      ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DebtsScreen(store: store))),
        leading: const CircleAvatar(
            backgroundColor: _coral,
            child: Icon(Icons.account_balance_outlined, color: Colors.white, size: 20)),
        title: Text(d.lender, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${(d.fraction * 100).round()}% repaid'),
        trailing: Text('-${wMoney(store, d.left)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: _coral)),
      ),
      ];

  List<Widget> _group(BuildContext context, String g, ColorScheme scheme, String? f) {
    final items = store.wealth.listed
        .where((a) => a.kind.group == g && (f == null || a.owner == f))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (items.isEmpty) return const [];
    final isDebt = g == 'Debts';
    final total = items.where((a) => a.include).fold(0.0, (s, a) => s + a.value);
    return [
      const Divider(height: 28),
      Row(
        children: [
          Expanded(
            child: Text(g.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold, letterSpacing: 0.6)),
          ),
          Text(isDebt ? '-${wMoney(store, total)}' : wMoney(store, total),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      for (final a in items)
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AccountDetailScreen(store: store, id: a.id))),
          leading: CircleAvatar(
            backgroundColor: kindColor(a.kind),
            child: Icon(kindIcon(a.kind), color: Colors.white, size: 20),
          ),
          title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text([
            if (f == null && store.wealth.hasFamily) store.wealth.ownerName(a.owner),
            if (a.provider.isNotEmpty) a.provider,
            if (a.updated != null) 'Updated ${DateFormat('d MMM').format(a.updated!)}',
            if (!a.include) 'not counted',
          ].join(' · ')),
          trailing: Text(
            a.kind.isDebt ? '-${wMoney(store, a.value)}' : wMoney(store, a.value),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: a.kind.isDebt ? _coral : null),
          ),
        ),
    ];
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Tile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}

class _Allocation extends StatelessWidget {
  final AppStore store;
  final String? owner;
  const _Allocation({required this.store, this.owner});

  @override
  Widget build(BuildContext context) {
    final alloc = store.wealth.allocation(owner: owner);
    final total = alloc.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return const SizedBox.shrink();
    final entries = alloc.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where it sits',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  for (final e in entries)
                    Expanded(
                      flex: (e.value / total * 1000).round().clamp(1, 1000).toInt(),
                      child: Container(color: groupColor(e.key)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final e in entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            color: groupColor(e.key), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('${e.key} ${(e.value / total * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Policies extends StatelessWidget {
  final AppStore store;
  const _Policies({required this.store});

  @override
  Widget build(BuildContext context) {
    final list = store.wealth.listedPolicies;
    if (list.isEmpty) return const SizedBox.shrink();
    final w = store.wealth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
        Row(
          children: [
            Expanded(
              child: Text('Policies & protection',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Text('not counted in net worth', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _Tile('Total cover', wMoney(store, w.totalCover), null)),
            const SizedBox(width: 8),
            Expanded(child: _Tile('Monthly cost', store.money(w.monthlyPremiums), null)),
          ],
        ),
        for (final p in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AddPolicyScreen(store: store, existing: p))),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF3B82F6),
              child: Icon(Icons.shield_outlined, color: Colors.white, size: 20),
            ),
            title: Text('${p.type} · ${p.provider}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text([
              'Cover ${wMoney(store, p.cover)}',
              if (p.renewal != null) 'renews ${DateFormat('d MMM yyyy').format(p.renewal!)}',
            ].join(' · ')),
            trailing: Text('${store.money(p.premium)}/mo',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}

/// Each person's share of the family net worth.
class _ByPerson extends StatelessWidget {
  final AppStore store;
  const _ByPerson({required this.store});

  @override
  Widget build(BuildContext context) {
    final w = store.wealth;
    final owners = [
      for (final m in w.people) m.id,
      if (w.listed.any((a) => a.owner == Wealth.joint)) Wealth.joint,
    ];
    final values = {for (final o in owners) o: w.netWorthOf(o)};
    final maxAbs = values.values.fold(0.0, (a, b) => a.abs() > b.abs() ? a.abs() : b.abs());
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By person',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          for (final o in owners)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(w.ownerName(o))),
                      Text(wMoney(store, values[o]!),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: maxAbs <= 0 ? 0.0 : (values[o]!.abs() / maxAbs).clamp(0.0, 1.0).toDouble(),
                      minHeight: 10,
                      color: o == Wealth.joint
                          ? const Color(0xFFF5B83D)
                          : Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
