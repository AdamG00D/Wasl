import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'cartoon_avatar.dart';
import 'ui.dart';

/// بيرسم الأفاتار (كرتوني / أول حرف / أيقونة جروب) كصورة PNG — لإشعارات النظام.
class AvatarRender {
  AvatarRender._();

  static final Map<String, Uint8List> _cache = {};

  static Future<Uint8List?> png({required String name, required int color, int? cartoon, bool group = false}) async {
    final key = '${group ? 'g' : 'p'}|$color|${cartoon ?? 0}|${group || cartoon != null ? '' : initialOf(name)}';
    final hit = _cache[key];
    if (hit != null) return hit;
    try {
      const size = 144.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final base = avatarColor(color);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, size, size),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            const Offset(size, size),
            [base, Color.lerp(base, Colors.black, 0.22)!],
          ),
      );
      if (!group && CartoonAvatars.valid(cartoon)) {
        CartoonPainter(cartoon!).paint(canvas, const Size.square(size));
      } else {
        final text = TextPainter(
          textDirection: TextDirection.rtl,
          text: group
              ? TextSpan(
                  text: String.fromCharCode(Icons.groups_rounded.codePoint),
                  style: TextStyle(
                    fontFamily: Icons.groups_rounded.fontFamily,
                    package: Icons.groups_rounded.fontPackage,
                    fontSize: size * 0.5,
                    color: Colors.white,
                  ),
                )
              : TextSpan(
                  text: initialOf(name),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: size * 0.44,
                    color: Colors.white,
                  ),
                ),
        )..layout();
        text.paint(canvas, Offset((size - text.width) / 2, (size - text.height) / 2));
      }
      final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return null;
      if (_cache.length > 64) _cache.clear();
      return _cache[key] = data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
