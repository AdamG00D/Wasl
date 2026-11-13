import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../l10n/l10n.dart';

/// رسالة قصيرة بتظهر فوق أي حاجة (حتى النوافذ والقوائم) وبتختفي لوحدها.
///
/// مش SnackBar: الـ SnackBar بيترسم في الصفحة اللي ورا النافذة فبيستخبى تحتها.
void showToast(BuildContext context, String message, {bool error = false}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _Toast.show(overlay, context.palette, message, error: error);
}

class _Toast {
  static OverlayEntry? _entry;
  static GlobalKey<_ToastViewState>? _key;

  static void show(OverlayState overlay, Palette p, String message, {required bool error}) {
    _key?.currentState?.dismiss(immediately: true);
    _entry?.remove();
    final key = GlobalKey<_ToastViewState>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastView(
        key: key,
        palette: p,
        message: message,
        error: error,
        onGone: () {
          if (identical(_entry, entry)) {
            _entry = null;
            _key = null;
          }
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _entry = entry;
    _key = key;
    overlay.insert(entry);
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    super.key,
    required this.palette,
    required this.message,
    required this.error,
    required this.onGone,
  });

  final Palette palette;
  final String message;
  final bool error;
  final VoidCallback onGone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  Timer? _timer;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    // الرسايل الطويلة تقعد شوية أكتر
    final ms = (2600 + widget.message.length * 25).clamp(2600, 5000);
    _timer = Timer(Duration(milliseconds: ms), dismiss);
  }

  Future<void> dismiss({bool immediately = false}) async {
    if (_gone) return;
    _gone = true;
    _timer?.cancel();
    if (!immediately && mounted) await _anim.reverse();
    widget.onGone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final mq = MediaQuery.of(context);
    final bottom = (mq.viewInsets.bottom > 0 ? mq.viewInsets.bottom : mq.padding.bottom) + 20;
    final curve = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(curve),
          child: GestureDetector(
            onTap: dismiss,
            onVerticalDragEnd: (_) => dismiss(),
            child: Material(
              color: p.isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              elevation: 6,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      widget.error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                      color: widget.error ? const Color(0xFFFCA5A5) : p.isDark ? p.accent : p.second,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// قايمة اختيارات بتطلع من تحت. [builder] بيرجّع `Column(mainAxisSize: MainAxisSize.min)`.
///
/// بتطول لحد 85% من الشاشة، ولو الاختيارات أكتر من كده بتعمل سكرول — عشان آخر اختيار
/// (زي "حذف عند الكل") ميتقصّش أبداً على الشاشات الصغيرة.
Future<T?> showActionSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(8, 0, 8, 8),
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
          child: SingleChildScrollView(padding: padding, child: builder(ctx)),
        ),
      ),
    );

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirm,
  String? cancel,
  bool destructive = false,
  IconData? icon,
}) async {
  final p = context.palette;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: icon == null ? null : Icon(icon, color: destructive ? p.danger : p.accent, size: 32),
      title: Text(title, textAlign: icon == null ? null : TextAlign.center),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: p.textMuted),
          child: Text(cancel ?? ctx.l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(90, 44),
            backgroundColor: destructive ? p.danger : p.accent,
            foregroundColor: destructive ? Colors.white : p.onAccent,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm ?? ctx.l10n.confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> infoDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? ok,
  IconData? icon,
  bool error = false,
}) {
  final p = context.palette;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: icon == null ? null : Icon(icon, color: error ? p.danger : p.accent, size: 32),
      title: Text(title, textAlign: icon == null ? null : TextAlign.center),
      content: Text(message),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
          onPressed: () => Navigator.pop(ctx),
          child: Text(ok ?? ctx.l10n.ok),
        ),
      ],
    ),
  );
}
