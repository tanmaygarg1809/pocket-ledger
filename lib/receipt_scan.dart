import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// What could be read from a receipt photo. Any field may be null: the person
/// always checks and corrects before saving.
class ReceiptInfo {
  final double? total;
  final DateTime? date;
  final String? merchant;
  final List<(String, double)> items;
  const ReceiptInfo({this.total, this.date, this.merchant, this.items = const []});
}

/// Lines like "Semi skimmed milk 1.45" -> ("Semi Skimmed Milk", 1.45).
List<(String, double)> parseReceiptItems(String text) {
  const skip = [
    'total', 'subtotal', 'sub total', 'card', 'visa', 'mastercard', 'amex', 'change', 'cash',
    'vat', 'balance', 'tender', 'payment', 'savings', 'points', 'nectar', 'clubcard', 'thank',
    'receipt', 'tel', 'www', 'tax', 'due', 'auth', 'contactless', 'items', 'discount', 'save',
    'terminal', 'merchant', 'served', 'store', 'order', 'deposit',
  ];
  final line = RegExp(r'^(.*?[A-Za-z].*?)\s+£?\s*(\d{1,4}[.,]\d{2})\s*[A-Za-z]?$');
  final out = <(String, double)>[];
  for (final raw in text.split('\n')) {
    final l = raw.trim();
    if (l.isEmpty) continue;
    final low = l.toLowerCase();
    if (skip.any(low.contains)) continue;
    final m = line.firstMatch(l);
    if (m == null) continue;
    var name = m.group(1)!.replaceAll(RegExp(r'^\d+\s*[xX]?\s+'), '').replaceAll(RegExp(r'[£*]+'), '').trim();
    final letters = RegExp(r'[A-Za-z]').allMatches(name).length;
    final price = double.tryParse(m.group(2)!.replaceAll(',', '.'));
    if (letters < 3 || price == null || price <= 0 || price > 500) continue;
    name = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
    out.add((name, price));
  }
  return out;
}

/// Pure text parsing (kept separate so it can be tested without a camera).
ReceiptInfo parseReceiptText(String text) {
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final money = RegExp(r'(?<![\d.,])(\d{1,6}[.,]\d{2})(?![\d])');
  double? val(String s) => double.tryParse(s.replaceAll(',', '.'));

  // Total: prefer lines that say total / amount due / balance, not subtotal.
  double? total;
  for (final l in lines) {
    final low = l.toLowerCase();
    if (low.contains('subtotal') || low.contains('sub total') || low.contains('sub-total')) continue;
    if (low.contains('total') || low.contains('amount due') || low.contains('balance due') || low.contains('to pay')) {
      for (final m in money.allMatches(l)) {
        final v = val(m.group(1)!);
        if (v != null && (total == null || v > total)) total = v;
      }
    }
  }
  // Otherwise the largest amount on the receipt.
  if (total == null) {
    for (final l in lines) {
      for (final m in money.allMatches(l)) {
        final v = val(m.group(1)!);
        if (v != null && (total == null || v > total)) total = v;
      }
    }
  }

  // Date: 31/12/2026, 31-12-26, 31 Dec 2026.
  DateTime? date;
  final numeric = RegExp(r'(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})');
  final named = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\.?,?\s+(\d{2,4})');
  const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
  int year(String y) => y.length == 2 ? 2000 + int.parse(y) : int.parse(y);
  for (final l in lines) {
    final n = numeric.firstMatch(l);
    if (n != null) {
      final d = int.parse(n.group(1)!), mo = int.parse(n.group(2)!), y = year(n.group(3)!);
      if (d >= 1 && d <= 31 && mo >= 1 && mo <= 12 && y >= 2000 && y <= 2100) {
        date = DateTime(y, mo, d);
        break;
      }
    }
    final w = named.firstMatch(l);
    if (w != null) {
      final mo = months.indexOf(w.group(2)!.toLowerCase()) + 1;
      final d = int.parse(w.group(1)!), y = year(w.group(3)!);
      if (mo > 0 && d >= 1 && d <= 31 && y >= 2000 && y <= 2100) {
        date = DateTime(y, mo, d);
        break;
      }
    }
  }

  // Merchant: the first line that looks like a name (letters, not an address or number).
  String? merchant;
  for (final l in lines.take(6)) {
    final letters = RegExp(r'[A-Za-z]').allMatches(l).length;
    if (letters >= 3 && letters >= l.length * 0.5 && !RegExp(r'^\d').hasMatch(l)) {
      merchant = l.length > 40 ? l.substring(0, 40) : l;
      break;
    }
  }
  if (merchant != null) {
    merchant = merchant
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
  return ReceiptInfo(
      total: total, date: date, merchant: merchant, items: parseReceiptItems(text));
}

/// Opens the camera, reads the receipt on the phone (nothing is uploaded),
/// and returns the photo path with what was found.
Future<(String, ReceiptInfo)?> scanReceipt() async {
  final shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
  if (shot == null) return null;
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(shot.path));
    return (shot.path, parseReceiptText(result.text));
  } finally {
    await recognizer.close();
  }
}
