import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/feedback.dart';

/// نسخ مؤقت: يُمسح النص من الحافظة تلقائياً بعد 30 ثانية
/// (إذا لم يُنسخ شيء آخر مكانه).
class SecureClipboard {
  SecureClipboard._();

  static const clearAfter = Duration(seconds: 30);
  static Timer? _timer;

  static Future<void> copy(BuildContext context, String text) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    _timer?.cancel();
    _timer = Timer(clearAfter, () async {
      try {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        if (current?.text == text) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {}
    });
    if (context.mounted) {
      showToast(context, 'تم النسخ — هيتمسح من الحافظة بعد 30 ثانية');
    }
  }
}
