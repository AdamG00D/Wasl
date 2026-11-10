import 'dart:math' as math;

import 'package:flutter/material.dart';

/// الأفاتارات الكرتونية: مرسومة جوه التطبيق (من غير صور)، فاللي بيتبعت في الشبكة رقمها بس.
///
/// 1..12 أشخاص • 13..24 حيوانات. الخلفية هي لون الشخص اللي اختاره.
class CartoonAvatars {
  CartoonAvatars._();

  static const int count = 24;

  static bool valid(int? index) => index != null && index >= 1 && index <= count;

  /// رقم سليم أو null (للقيم اللي جاية من الشبكة أو التخزين).
  static int? clean(Object? raw) => raw is num && valid(raw.toInt()) ? raw.toInt() : null;
}

enum _Hair { short, side, long, curly, bald, bun, hijab, cap, spiky, bob, ponytail, afro }

enum _Extra { none, glasses, beard, mustache, freckles, sunglasses }

class _Person {
  const _Person(this.skin, this.hair, this.style, this.shirt, [this.extra = _Extra.none]);
  final int skin;
  final int hair;
  final _Hair style;
  final int shirt;
  final _Extra extra;
}

const _people = <_Person>[
  _Person(0xFFF2C9A0, 0xFF3B2A20, _Hair.short, 0xFFFFFFFF),
  _Person(0xFFE0A878, 0xFF1F1A17, _Hair.long, 0xFFFFE082),
  _Person(0xFFC68658, 0xFF1F1A17, _Hair.curly, 0xFFE3F2FD, _Extra.glasses),
  _Person(0xFFF5D3B3, 0xFF8A4B20, _Hair.bun, 0xFFFFCDD2, _Extra.freckles),
  _Person(0xFFE0A878, 0xFF1F1A17, _Hair.side, 0xFF263238, _Extra.beard),
  _Person(0xFFF2C9A0, 0xFF5D4037, _Hair.hijab, 0xFFD1C4E9),
  _Person(0xFF8D5A3B, 0xFF1F1A17, _Hair.afro, 0xFFFFF59D),
  _Person(0xFFF5D3B3, 0xFFE0B040, _Hair.bob, 0xFFB2DFDB),
  _Person(0xFFC68658, 0xFF1F1A17, _Hair.cap, 0xFFFFFFFF, _Extra.mustache),
  _Person(0xFFE0A878, 0xFF6D4C41, _Hair.ponytail, 0xFFFFCCBC, _Extra.glasses),
  _Person(0xFFF2C9A0, 0xFF9E9E9E, _Hair.bald, 0xFFCFD8DC, _Extra.beard),
  _Person(0xFF8D5A3B, 0xFF1F1A17, _Hair.spiky, 0xFFFFFFFF, _Extra.sunglasses),
];

/// بيرسم الأفاتار في مربع 100×100 (بيتكبّر على حسب المساحة).
class CartoonPainter extends CustomPainter {
  const CartoonPainter(this.index);

  final int index;

  static const _ink = Color(0xFF2B2320);

  static Paint _fill(int color) => Paint()..color = Color(color);

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    if (index <= _people.length) {
      _person(canvas, _people[(index - 1).clamp(0, _people.length - 1)]);
    } else {
      _animal(canvas, index - _people.length);
    }
    canvas.restore();
  }

  // ---------------- أشخاص ----------------

  void _face(Canvas c, {double eyeY = 47, double gap = 9, double smileY = 55, bool cheeks = true}) {
    c.drawCircle(Offset(50 - gap, eyeY), 2.7, Paint()..color = _ink);
    c.drawCircle(Offset(50 + gap, eyeY), 2.7, Paint()..color = _ink);
    c.drawCircle(Offset(50 - gap + 0.9, eyeY - 0.9), 0.8, Paint()..color = Colors.white);
    c.drawCircle(Offset(50 + gap + 0.9, eyeY - 0.9), 0.8, Paint()..color = Colors.white);
    c.drawArc(Rect.fromCenter(center: Offset(50, smileY), width: 14, height: 10), 0.25, math.pi - 0.5, false,
        _stroke(_ink, 2));
    if (cheeks) {
      final blush = Paint()..color = const Color(0x55FF6F6F);
      c.drawCircle(Offset(50 - gap - 4, smileY), 3.4, blush);
      c.drawCircle(Offset(50 + gap + 4, smileY), 3.4, blush);
    }
  }

  void _person(Canvas c, _Person p) {
    final skin = _fill(p.skin);
    final hair = _fill(p.hair);
    final shade = Paint()..color = Color.lerp(Color(p.skin), Colors.black, 0.14)!;
    const head = Offset(50, 46);

    // شعر ورا الراس
    switch (p.style) {
      case _Hair.long:
        c.drawRRect(RRect.fromLTRBR(23, 26, 77, 86, const Radius.circular(24)), hair);
      case _Hair.bob:
        c.drawRRect(RRect.fromLTRBR(22, 24, 78, 68, const Radius.circular(22)), hair);
      case _Hair.afro:
        c.drawCircle(const Offset(50, 38), 33, hair);
      case _Hair.curly:
        for (final o in const [Offset(30, 34), Offset(40, 24), Offset(52, 21), Offset(64, 25), Offset(72, 35)]) {
          c.drawCircle(o, 11, hair);
        }
      case _Hair.ponytail:
        c.drawOval(const Rect.fromLTWH(68, 30, 18, 34), hair);
      case _Hair.hijab:
        c.drawRRect(RRect.fromLTRBR(19, 16, 81, 96, const Radius.circular(30)), hair);
      default:
        break;
    }

    // الكتفين والرقبة
    c.drawRRect(RRect.fromLTRBR(16, 76, 84, 124, const Radius.circular(24)), _fill(p.shirt));
    if (p.style != _Hair.hijab) c.drawRRect(RRect.fromLTRBR(43, 62, 57, 82, const Radius.circular(6)), shade);

    // الودان والراس
    if (p.style != _Hair.hijab) {
      c.drawCircle(const Offset(26.5, 48), 5, skin);
      c.drawCircle(const Offset(73.5, 48), 5, skin);
    }
    c.drawOval(Rect.fromCenter(center: head, width: 46, height: 50), skin);

    // شعر قدام
    final top = Path();
    switch (p.style) {
      case _Hair.short || _Hair.long || _Hair.ponytail || _Hair.bob:
        top
          ..moveTo(27, 44)
          ..quadraticBezierTo(26, 20, 50, 20)
          ..quadraticBezierTo(74, 20, 73, 44)
          ..quadraticBezierTo(66, 30, 50, 31)
          ..quadraticBezierTo(34, 30, 27, 44)
          ..close();
        c.drawPath(top, hair);
      case _Hair.side:
        top
          ..moveTo(27, 42)
          ..quadraticBezierTo(26, 19, 52, 20)
          ..quadraticBezierTo(75, 21, 73, 42)
          ..quadraticBezierTo(70, 31, 56, 30)
          ..quadraticBezierTo(40, 38, 27, 42)
          ..close();
        c.drawPath(top, hair);
      case _Hair.spiky:
        top.moveTo(27, 40);
        for (var i = 0; i < 6; i++) {
          top
            ..lineTo(30 + i * 8.0, 14 + (i.isEven ? 0 : 3))
            ..lineTo(35 + i * 8.0, 28);
        }
        top
          ..lineTo(73, 40)
          ..quadraticBezierTo(50, 26, 27, 40)
          ..close();
        c.drawPath(top, hair);
      case _Hair.curly || _Hair.afro:
        top
          ..moveTo(28, 40)
          ..quadraticBezierTo(50, 14, 72, 40)
          ..quadraticBezierTo(50, 28, 28, 40)
          ..close();
        c.drawPath(top, hair);
      case _Hair.bun:
        c.drawCircle(const Offset(50, 16), 9, hair);
        top
          ..moveTo(27, 44)
          ..quadraticBezierTo(26, 20, 50, 20)
          ..quadraticBezierTo(74, 20, 73, 44)
          ..quadraticBezierTo(50, 22, 27, 44)
          ..close();
        c.drawPath(top, hair);
      case _Hair.cap:
        top
          ..moveTo(26, 38)
          ..quadraticBezierTo(27, 16, 50, 16)
          ..quadraticBezierTo(73, 16, 74, 38)
          ..close();
        c.drawPath(top, _fill(0xFFE53935));
        c.drawRRect(RRect.fromLTRBR(24, 35, 88, 41, const Radius.circular(4)), _fill(0xFFB71C1C));
      case _Hair.hijab:
        // فتحة الوش
        top
          ..addRRect(RRect.fromLTRBR(19, 16, 81, 96, const Radius.circular(30)))
          ..addOval(Rect.fromCenter(center: const Offset(50, 48), width: 40, height: 44))
          ..fillType = PathFillType.evenOdd;
        c.drawPath(top, hair);
      case _Hair.bald:
        c.drawArc(const Rect.fromLTWH(27, 26, 46, 30), math.pi, 0.5, false, _stroke(Color(p.hair), 5));
        c.drawArc(const Rect.fromLTWH(27, 26, 46, 30), -0.5, 0.5, false, _stroke(Color(p.hair), 5));
    }

    _face(c);

    switch (p.extra) {
      case _Extra.none:
        break;
      case _Extra.glasses || _Extra.sunglasses:
        final dark = p.extra == _Extra.sunglasses;
        for (final x in const [41.0, 59.0]) {
          final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, 47), width: 14, height: 11),
              const Radius.circular(5));
          if (dark) c.drawRRect(r, Paint()..color = _ink);
          c.drawRRect(r, _stroke(_ink, 1.8));
        }
        c.drawLine(const Offset(48, 46), const Offset(52, 46), _stroke(_ink, 1.8));
      case _Extra.beard:
        final beard = Path()
          ..moveTo(29, 52)
          ..quadraticBezierTo(31, 74, 50, 74)
          ..quadraticBezierTo(69, 74, 71, 52)
          ..quadraticBezierTo(62, 62, 50, 61)
          ..quadraticBezierTo(38, 62, 29, 52)
          ..close();
        c.drawPath(beard, hair);
        c.drawArc(Rect.fromCenter(center: const Offset(50, 58), width: 12, height: 8), 0.3, math.pi - 0.6, false,
            _stroke(Colors.white, 1.8));
      case _Extra.mustache:
        c.drawArc(const Rect.fromLTWH(40, 50, 10, 8), math.pi, math.pi, false, _stroke(Color(p.hair), 3.2));
        c.drawArc(const Rect.fromLTWH(50, 50, 10, 8), math.pi, math.pi, false, _stroke(Color(p.hair), 3.2));
      case _Extra.freckles:
        final dot = Paint()..color = const Color(0x88A0522D);
        for (final o in const [Offset(36, 51), Offset(39, 53), Offset(61, 53), Offset(64, 51)]) {
          c.drawCircle(o, 0.9, dot);
        }
    }
  }

  // ---------------- حيوانات ----------------

  void _eyes(Canvas c, {double y = 46, double gap = 11, double r = 3.2}) {
    for (final x in [50 - gap, 50 + gap]) {
      c.drawCircle(Offset(x, y), r, Paint()..color = _ink);
      c.drawCircle(Offset(x + r * 0.3, y - r * 0.3), r * 0.32, Paint()..color = Colors.white);
    }
  }

  void _nose(Canvas c, {double y = 57, int color = 0xFF2B2320, double w = 8, double h = 5.5}) {
    c.drawOval(Rect.fromCenter(center: Offset(50, y), width: w, height: h), _fill(color));
    c.drawLine(Offset(50, y + h / 2), Offset(50, y + h / 2 + 3), _stroke(_ink, 1.6));
    c.drawArc(Rect.fromLTWH(44, y + 1, 6, 6), 0.2, math.pi - 0.6, false, _stroke(_ink, 1.6));
    c.drawArc(Rect.fromLTWH(50, y + 1, 6, 6), 0.4, math.pi - 0.6, false, _stroke(_ink, 1.6));
  }

  Path _tri(Offset a, Offset b, Offset d) => Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(d.dx, d.dy)
    ..close();

  void _animal(Canvas c, int n) {
    final headRect = Rect.fromCenter(center: const Offset(50, 54), width: 64, height: 58);
    switch (n) {
      case 1: // قطة
        final fur = _fill(0xFFF6A94A);
        c.drawPath(_tri(const Offset(20, 40), const Offset(24, 10), const Offset(46, 28)), fur);
        c.drawPath(_tri(const Offset(80, 40), const Offset(76, 10), const Offset(54, 28)), fur);
        c.drawPath(_tri(const Offset(26, 32), const Offset(27, 17), const Offset(38, 27)), _fill(0xFFFFCDD2));
        c.drawPath(_tri(const Offset(74, 32), const Offset(73, 17), const Offset(62, 27)), _fill(0xFFFFCDD2));
        c.drawOval(headRect, fur);
        c.drawOval(Rect.fromCenter(center: const Offset(50, 62), width: 30, height: 22), _fill(0xFFFFF3E0));
        _eyes(c, y: 48);
        _nose(c, y: 58, color: 0xFFE57373, w: 6, h: 4.5);
        for (final s in [-1.0, 1.0]) {
          c.drawLine(Offset(50 + s * 14, 60), Offset(50 + s * 28, 57), _stroke(_ink, 1.2));
          c.drawLine(Offset(50 + s * 14, 63), Offset(50 + s * 28, 65), _stroke(_ink, 1.2));
        }
      case 2: // كلب
        final fur = _fill(0xFFD7A86E);
        c.drawOval(headRect, fur);
        c.drawRRect(RRect.fromLTRBR(13, 28, 31, 68, const Radius.circular(10)), _fill(0xFF8D5A3B));
        c.drawRRect(RRect.fromLTRBR(69, 28, 87, 68, const Radius.circular(10)), _fill(0xFF8D5A3B));
        c.drawOval(Rect.fromCenter(center: const Offset(50, 64), width: 34, height: 26), _fill(0xFFFFF3E0));
        c.drawCircle(const Offset(61, 46), 9, _fill(0xFF8D5A3B));
        _eyes(c, y: 46);
        _nose(c, y: 59, w: 10, h: 7);
        c.drawOval(const Rect.fromLTWH(46, 68, 8, 9), _fill(0xFFEF5350));
      case 3: // دب
        final fur = _fill(0xFF8D6E63);
        c.drawCircle(const Offset(27, 28), 11, fur);
        c.drawCircle(const Offset(73, 28), 11, fur);
        c.drawCircle(const Offset(27, 28), 5.5, _fill(0xFFD7CCC8));
        c.drawCircle(const Offset(73, 28), 5.5, _fill(0xFFD7CCC8));
        c.drawOval(headRect, fur);
        c.drawOval(Rect.fromCenter(center: const Offset(50, 63), width: 28, height: 22), _fill(0xFFD7CCC8));
        _eyes(c, y: 47);
        _nose(c, y: 58);
      case 4: // باندا
        c.drawCircle(const Offset(26, 28), 11, Paint()..color = _ink);
        c.drawCircle(const Offset(74, 28), 11, Paint()..color = _ink);
        c.drawOval(headRect, _fill(0xFFFFFFFF));
        for (final x in const [38.0, 62.0]) {
          c.save();
          c.translate(x, 48);
          c.rotate(x < 50 ? -0.35 : 0.35);
          c.drawOval(Rect.fromCenter(center: Offset.zero, width: 15, height: 19), Paint()..color = _ink);
          c.restore();
          c.drawCircle(Offset(x, 48), 3.2, Paint()..color = Colors.white);
          c.drawCircle(Offset(x, 48), 1.7, Paint()..color = _ink);
        }
        _nose(c, y: 60, w: 7, h: 5);
      case 5: // أرنب
        final fur = _fill(0xFFF5F5F5);
        c.drawRRect(RRect.fromLTRBR(30, 2, 44, 44, const Radius.circular(8)), fur);
        c.drawRRect(RRect.fromLTRBR(56, 2, 70, 44, const Radius.circular(8)), fur);
        c.drawRRect(RRect.fromLTRBR(34, 8, 40, 38, const Radius.circular(4)), _fill(0xFFFFCDD2));
        c.drawRRect(RRect.fromLTRBR(60, 8, 66, 38, const Radius.circular(4)), _fill(0xFFFFCDD2));
        c.drawOval(Rect.fromCenter(center: const Offset(50, 60), width: 58, height: 50), fur);
        _eyes(c, y: 54, gap: 10);
        _nose(c, y: 63, color: 0xFFF48FB1, w: 6, h: 4.5);
        final blush = Paint()..color = const Color(0x55FF6F6F);
        c.drawCircle(const Offset(32, 64), 4, blush);
        c.drawCircle(const Offset(68, 64), 4, blush);
      case 6: // تعلب
        final fur = _fill(0xFFEF7B3C);
        c.drawPath(_tri(const Offset(18, 44), const Offset(20, 8), const Offset(46, 30)), fur);
        c.drawPath(_tri(const Offset(82, 44), const Offset(80, 8), const Offset(54, 30)), fur);
        c.drawPath(_tri(const Offset(24, 34), const Offset(24, 17), const Offset(37, 29)), Paint()..color = _ink);
        c.drawPath(_tri(const Offset(76, 34), const Offset(76, 17), const Offset(63, 29)), Paint()..color = _ink);
        c.drawPath(
          Path()
            ..moveTo(16, 44)
            ..quadraticBezierTo(50, 14, 84, 44)
            ..quadraticBezierTo(70, 76, 50, 86)
            ..quadraticBezierTo(30, 76, 16, 44)
            ..close(),
          fur,
        );
        c.drawPath(
          Path()
            ..moveTo(16, 46)
            ..quadraticBezierTo(36, 52, 50, 66)
            ..quadraticBezierTo(64, 52, 84, 46)
            ..quadraticBezierTo(70, 76, 50, 86)
            ..quadraticBezierTo(30, 76, 16, 46)
            ..close(),
          _fill(0xFFFFFFFF),
        );
        _eyes(c, y: 46, gap: 12, r: 2.8);
        c.drawOval(Rect.fromCenter(center: const Offset(50, 78), width: 8, height: 6), Paint()..color = _ink);
      case 7: // أسد
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6;
          c.drawCircle(Offset(50 + math.cos(a) * 30, 52 + math.sin(a) * 30), 11, _fill(0xFFB5651D));
        }
        c.drawOval(Rect.fromCenter(center: const Offset(50, 54), width: 54, height: 52), _fill(0xFFF6C15B));
        c.drawOval(Rect.fromCenter(center: const Offset(50, 63), width: 26, height: 20), _fill(0xFFFFF3E0));
        _eyes(c, y: 48, gap: 10);
        _nose(c, y: 59, color: 0xFF6D4C41);
      case 8: // ضفدع
        final skin = _fill(0xFF7CB342);
        c.drawCircle(const Offset(33, 30), 13, skin);
        c.drawCircle(const Offset(67, 30), 13, skin);
        c.drawOval(Rect.fromCenter(center: const Offset(50, 58), width: 70, height: 52), skin);
        for (final x in const [33.0, 67.0]) {
          c.drawCircle(Offset(x, 30), 8.5, Paint()..color = Colors.white);
          c.drawCircle(Offset(x, 31), 4.2, Paint()..color = _ink);
        }
        c.drawArc(const Rect.fromLTWH(30, 46, 40, 26), 0.2, math.pi - 0.4, false, _stroke(_ink, 2.4));
        final blush = Paint()..color = const Color(0x55FF6F6F);
        c.drawCircle(const Offset(26, 62), 4, blush);
        c.drawCircle(const Offset(74, 62), 4, blush);
      case 9: // قرد
        final fur = _fill(0xFF795548);
        c.drawCircle(const Offset(18, 52), 11, fur);
        c.drawCircle(const Offset(82, 52), 11, fur);
        c.drawCircle(const Offset(18, 52), 6, _fill(0xFFF0C8A0));
        c.drawCircle(const Offset(82, 52), 6, _fill(0xFFF0C8A0));
        c.drawOval(headRect, fur);
        c.drawOval(Rect.fromCenter(center: const Offset(40, 47), width: 22, height: 22), _fill(0xFFF0C8A0));
        c.drawOval(Rect.fromCenter(center: const Offset(60, 47), width: 22, height: 22), _fill(0xFFF0C8A0));
        c.drawOval(Rect.fromCenter(center: const Offset(50, 65), width: 38, height: 26), _fill(0xFFF0C8A0));
        _eyes(c, y: 47, gap: 9);
        c.drawCircle(const Offset(47.5, 60), 1.2, Paint()..color = _ink);
        c.drawCircle(const Offset(52.5, 60), 1.2, Paint()..color = _ink);
        c.drawArc(const Rect.fromLTWH(40, 60, 20, 12), 0.25, math.pi - 0.5, false, _stroke(_ink, 2));
      case 10: // بطريق
        c.drawOval(Rect.fromCenter(center: const Offset(50, 56), width: 66, height: 72), _fill(0xFF37474F));
        c.drawOval(Rect.fromCenter(center: const Offset(39, 52), width: 30, height: 38), _fill(0xFFFFFFFF));
        c.drawOval(Rect.fromCenter(center: const Offset(61, 52), width: 30, height: 38), _fill(0xFFFFFFFF));
        c.drawOval(Rect.fromCenter(center: const Offset(50, 70), width: 44, height: 34), _fill(0xFFFFFFFF));
        _eyes(c, y: 48, gap: 10, r: 3);
        c.drawPath(_tri(const Offset(43, 56), const Offset(57, 56), const Offset(50, 66)), _fill(0xFFFFA726));
        final blush = Paint()..color = const Color(0x55FF6F6F);
        c.drawCircle(const Offset(33, 60), 3.6, blush);
        c.drawCircle(const Offset(67, 60), 3.6, blush);
      case 11: // بومة
        final fur = _fill(0xFF8D6E63);
        c.drawPath(_tri(const Offset(22, 36), const Offset(22, 12), const Offset(42, 26)), fur);
        c.drawPath(_tri(const Offset(78, 36), const Offset(78, 12), const Offset(58, 26)), fur);
        c.drawOval(Rect.fromCenter(center: const Offset(50, 56), width: 66, height: 64), fur);
        c.drawOval(Rect.fromCenter(center: const Offset(50, 72), width: 40, height: 28), _fill(0xFFD7CCC8));
        for (final x in const [37.0, 63.0]) {
          c.drawCircle(Offset(x, 46), 13, _fill(0xFFFFF8E1));
          c.drawCircle(Offset(x, 46), 6, Paint()..color = _ink);
          c.drawCircle(Offset(x + 2, 44), 2, Paint()..color = Colors.white);
        }
        c.drawPath(_tri(const Offset(45, 54), const Offset(55, 54), const Offset(50, 64)), _fill(0xFFFFA726));
      default: // كوالا
        final fur = _fill(0xFF9E9E9E);
        c.drawCircle(const Offset(20, 36), 15, fur);
        c.drawCircle(const Offset(80, 36), 15, fur);
        c.drawCircle(const Offset(20, 36), 8, _fill(0xFFF8BBD0));
        c.drawCircle(const Offset(80, 36), 8, _fill(0xFFF8BBD0));
        c.drawOval(headRect, fur);
        _eyes(c, y: 48, gap: 12, r: 3);
        c.drawRRect(RRect.fromLTRBR(43, 48, 57, 68, const Radius.circular(7)), Paint()..color = _ink);
        c.drawArc(const Rect.fromLTWH(42, 64, 16, 10), 0.3, math.pi - 0.6, false, _stroke(_ink, 1.8));
    }
  }

  @override
  bool shouldRepaint(CartoonPainter old) => old.index != index;
}
