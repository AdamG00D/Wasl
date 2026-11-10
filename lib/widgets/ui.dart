import 'dart:io';

import 'package:flutter/material.dart';

import '../core/profile/profile.dart';
import '../core/theme/app_theme.dart';

/// أول حرف من الاسم (للأفاتار) — آمن مع الأسماء الفاضية.
String initialOf(String name) {
  final t = name.trim();
  return t.isEmpty ? '؟' : t.characters.first;
}

/// صورة البروفايل: الصورة لو موجودة، وإلا أول حرف على لون الشخص.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    required this.color,
    this.avatarHash,
    this.file,
    this.size = 48,
    this.online,
    this.icon,
  });

  final String name;
  final int color;

  /// هاش صورة متخزنة (بتاعتي أو بتاعة حد من الشبكة).
  final String? avatarHash;

  /// صورة من ملف مباشرة (معاينة قبل الحفظ).
  final File? file;
  final double size;

  /// نقطة الحالة (null = من غير نقطة).
  final bool? online;

  /// أيقونة بدل الحرف (للجروبات).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = avatarColor(color);
    final hash = avatarHash;
    final f = file ?? (hash != null && Avatars.has(hash) ? Avatars.fileFor(hash) : null);
    final radius = size * 0.36;
    Widget body = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [c, Color.lerp(c, Colors.black, 0.22)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: icon != null
          ? Icon(icon, color: Colors.white, size: size * 0.5)
          : Text(
              initialOf(name),
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.42, height: 1.2),
            ),
    );
    if (f != null) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.file(
          f,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => body,
        ),
      );
    }
    if (online == null) return body;
    final dot = size * 0.28;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          body,
          PositionedDirectional(
            end: -2,
            bottom: -2,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: online! ? p.success : p.textMuted.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(color: p.bg, width: 2.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scaffold موحّد.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.showAppBar = true,
    this.floatingActionButton,
    this.bottom,
    this.leading,
    this.safeTop = true,
  });

  /// لو false والـ AppBar مخفي، الصفحة نفسها مسؤولة عن مسافة شريط الحالة.
  final bool safeTop;
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final bool showAppBar;
  final Widget? floatingActionButton;
  final Widget? bottom;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: showAppBar
          ? AppBar(
              title: title == null ? null : Text(title!),
              actions: actions,
              leading: leading,
            )
          : null,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottom,
      body: showAppBar || !safeTop ? body : SafeArea(bottom: false, child: body),
    );
  }
}

/// بطاقة سطحية بحدود ناعمة.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: color ?? p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor ?? p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// زر أساسي (ممتلئ بلون التطبيق).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 54,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bg = color ?? p.accent;
    final fg = Palette.onColor(bg);
    final enabled = onPressed != null && !loading;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.45),
          disabledForegroundColor: fg.withValues(alpha: 0.8),
          minimumSize: Size(64, height),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2.6)),
        ),
        child: loading
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }
}

/// زر ثانوي (هادي).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.height = 50,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = color ?? p.text;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: color == null ? p.surfaceAlt : fg.withValues(alpha: 0.10),
          minimumSize: Size(64, height),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2.6)),
          textStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 8)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// أيقونة في مربع ملوّن ناعم.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.color, this.size = 46, this.filled = false});

  final IconData icon;
  final Color? color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: p.isDark ? 0.18 : 0.11),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, color: filled ? Palette.onColor(c) : c, size: size * 0.5),
    );
  }
}

/// عنوان قسم صغير.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 18, 6, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// حالة فاضية: أيقونة + عنوان + شرح + زر اختياري.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(32)),
              child: Icon(icon, size: 42, color: p.accent),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, textAlign: TextAlign.center, style: TextStyle(color: p.textMuted, height: 1.7)),
            ],
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}

/// شارة صغيرة (عدد الرسايل الجديدة...).
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(11)),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(color: p.onAccent, fontSize: 12, fontWeight: FontWeight.w700, height: 1.1),
      ),
    );
  }
}

/// صف إعدادات: أيقونة + عنوان + شرح + حاجة في الآخر.
class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconBadge(icon: icon, size: 40, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: color ?? p.text)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.5)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
