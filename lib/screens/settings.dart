import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../cloud.dart';
import '../store.dart';
import 'auth.dart';
import 'categories.dart';
import 'recurring.dart';
import 'review.dart';

class SettingsScreen extends StatelessWidget {
  final AppStore store;
  final CloudService cloud;
  const SettingsScreen({super.key, required this.store, required this.cloud});

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _export(BuildContext context) async {
    try {
      final dir = await getTemporaryDirectory();
      final name =
          'pocket-ledger-backup-${DateFormat('yyyyMMdd').format(DateTime.now())}.json';
      final file = File('${dir.path}/$name');
      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(store.backupJson()));
      await Share.shareXFiles([XFile(file.path)], text: 'Pocket Ledger backup');
    } catch (_) {
      if (context.mounted) _snack(context, 'Could not create the backup file.');
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      final res = await FilePicker.platform
          .pickFiles(type: FileType.any, withData: true);
      if (res == null || res.files.isEmpty) return;
      final bytes = res.files.single.bytes;
      if (bytes == null) {
        if (context.mounted) _snack(context, 'Could not read that file.');
        return;
      }
      final msg = await store.restoreBackup(utf8.decode(bytes));
      if (context.mounted) _snack(context, msg);
    } catch (_) {
      if (context.mounted) _snack(context, 'Could not read that file.');
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String body,
      String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _signOut(BuildContext context) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'Your data stays safe in your account. What should happen to the copy on this phone?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'remove'),
              child: const Text('Remove from phone')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'keep'),
              child: const Text('Keep on phone')),
        ],
      ),
    );
    if (choice == null) return;
    await cloud.signOut(removeLocalData: choice == 'remove');
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await _confirm(
      context,
      'Delete your account?',
      'This permanently deletes your account and everything stored in the '
          'cloud. Data on this phone is kept.',
      'Delete account',
    );
    if (!ok) return;
    final err = await cloud.deleteAccount();
    if (context.mounted) _snack(context, err ?? 'Account deleted.');
  }

  Widget _accountTiles(BuildContext context) {
    if (!cloud.available) {
      return const ListTile(
        leading: Icon(Icons.cloud_off_outlined),
        title: Text('Cloud sync not set up'),
        subtitle: Text('Your data is stored on this phone only.'),
      );
    }
    final u = cloud.user;
    if (u == null) {
      return ListTile(
        leading: const Icon(Icons.cloud_outlined),
        title: const Text('Sign in to sync'),
        subtitle: const Text('Back up your data and use it on more than one phone'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AuthScreen(cloud: cloud))),
      );
    }
    final status = cloud.syncing
        ? 'Syncing…'
        : cloud.error ??
            (cloud.lastSync == null
                ? 'Not synced yet'
                : 'Synced ${DateFormat('HH:mm').format(cloud.lastSync!)}');
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(u.email ?? 'Signed in'),
          subtitle: Text(status),
          trailing: IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: cloud.syncing ? null : cloud.syncNow,
          ),
        ),
        if (!u.emailVerified)
          ListTile(
            leading: const Icon(Icons.mark_email_unread_outlined),
            title: const Text('Verify your email'),
            subtitle: const Text('Tap to resend the verification email'),
            onTap: () async {
              await cloud.resendVerification();
              if (context.mounted) _snack(context, 'Verification email sent.');
            },
          ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: () => _signOut(context),
        ),
        ListTile(
          leading: const Icon(Icons.person_remove_outlined),
          title: const Text('Delete account'),
          subtitle: const Text('Removes your account and cloud data'),
          onTap: () => _deleteAccount(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, cloud]),
      builder: (context, _) {
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Settings',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            _accountTiles(context),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Categories & groups'),
              subtitle: const Text('Add your own, group them, mark savings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CategoriesScreen(store: store))),
            ),
            ListTile(
              leading: const Icon(Icons.rule),
              title: const Text('Review entries in "Other"'),
              subtitle: Text(store.needsReview.isEmpty
                  ? 'Nothing to review'
                  : '${store.needsReview.length} to sort'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ReviewScreen(store: store))),
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat),
              title: const Text('Recurring transactions'),
              subtitle: const Text('Rent, subscriptions, salary'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RecurringScreen(store: store))),
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Currency symbol'),
              subtitle: Wrap(
                spacing: 8,
                children: [
                  for (final c in currencies)
                    ChoiceChip(
                      label: Text(c),
                      selected: store.currency == c,
                      onSelected: (_) => store.setCurrency(c),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Appearance'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'light', label: Text('Light')),
                    ButtonSegment(value: 'dark', label: Text('Dark')),
                    ButtonSegment(value: 'system', label: Text('Phone')),
                  ],
                  selected: {store.themeMode},
                  onSelectionChanged: (v) => store.setThemeMode(v.first),
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Back up to a file'),
              subtitle: const Text('Save or share a backup (e.g. to Drive)'),
              onTap: () => _export(context),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Restore from a file'),
              subtitle: const Text('Merges with what is already here'),
              onTap: () => _restore(context),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('Copy data as CSV'),
              subtitle: const Text('Paste into a spreadsheet or notes app'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: store.toCsv()));
                if (context.mounted) _snack(context, 'CSV copied to clipboard');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text('Delete all data'),
              subtitle: Text(cloud.user == null
                  ? 'Removes everything from this device'
                  : 'Removes everything, including from your account'),
              onTap: () async {
                final ok = await _confirm(context, 'Delete all data?',
                    'This cannot be undone.', 'Delete');
                if (ok) await store.clearAll();
              },
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Privacy'),
              subtitle: Text(
                  'Data is stored on your device. If you create an account, a private copy is stored in your account so it can sync. We never sell or share it.'),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Pocket Ledger 1.2.0'),
              subtitle: Text(
                  'For personal record-keeping only. Not financial advice.'),
            ),
          ],
        );
      },
    );
  }
}
