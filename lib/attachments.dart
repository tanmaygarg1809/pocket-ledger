import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Receipts, warranties and other documents kept with an entry. Files are
/// copied into the app's private folder; entries only store the file names.
class Attachments {
  static Future<Directory> _dir() async {
    final d = await getApplicationDocumentsDirectory();
    final a = Directory('${d.path}/attachments');
    if (!await a.exists()) await a.create(recursive: true);
    return a;
  }

  static const _ext = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'];

  /// Lets the person choose files; returns the stored names.
  static Future<List<String>> pick() async {
    final res = await FilePicker.platform
        .pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: _ext);
    if (res == null) return [];
    final dir = await _dir();
    final out = <String>[];
    var n = 0;
    for (final f in res.files) {
      final path = f.path;
      if (path == null) continue;
      final safe = f.name.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
      final name = '${DateTime.now().microsecondsSinceEpoch}${n++}_$safe';
      await File(path).copy('${dir.path}/$name');
      out.add(name);
    }
    return out;
  }

  /// Copies a photo or file already on the phone into the attachments folder.
  static Future<String?> saveFromPath(String path, String label) async {
    final src = File(path);
    if (!await src.exists()) return null;
    final dir = await _dir();
    final safe = label.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
    final name = '${DateTime.now().microsecondsSinceEpoch}_$safe';
    await src.copy('${dir.path}/$name');
    return name;
  }

  static Future<File?> file(String name) async {
    final f = File('${(await _dir()).path}/$name');
    return await f.exists() ? f : null;
  }

  static Future<void> delete(String name) async {
    final f = await file(name);
    if (f != null) await f.delete();
  }

  static bool isImage(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png') || n.endsWith('.webp');
  }

  /// "1731...0_Receipt.pdf" -> "Receipt.pdf"
  static String label(String name) {
    final i = name.indexOf('_');
    return i < 0 ? name : name.substring(i + 1);
  }

  /// Shows an image full screen, or hands other files to another app.
  static Future<void> open(BuildContext context, String name) async {
    final f = await file(name);
    if (!context.mounted) return;
    if (f == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This file is not on this phone.')));
      return;
    }
    if (isImage(name)) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              InteractiveViewer(child: Image.file(f)),
              Positioned(
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      await Share.shareXFiles([XFile(f.path)], text: label(name));
    }
  }
}
