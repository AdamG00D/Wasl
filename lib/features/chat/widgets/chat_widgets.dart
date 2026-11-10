import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/ui.dart';
import '../core/chat_errors.dart';
import '../core/chat_session.dart';
import 'media_widgets.dart';

/// قائمة الرسائل (الأحدث في الأسفل).
class MessageList extends StatelessWidget {
  const MessageList({
    super.key,
    required this.messages,
    this.peerTyping = false,
    this.onMessageActions,
    this.onCancelTransfer,
    this.onReply,
    this.onQuoteTap,
    this.keyFor,
    this.highlightId,
    this.peerName = 'الطرف التاني',
    this.controller,
  });

  final List<ChatMessage> messages;
  final bool peerTyping;

  /// ضغطة طويلة على رسالة (نسخ / تعديل / حذف / إلغاء).
  final ValueChanged<ChatMessage>? onMessageActions;

  /// زرار ✕ على ملف بيتنقل.
  final ValueChanged<ChatMessage>? onCancelTransfer;

  /// سحب الرسالة للجنب = رد عليها.
  final ValueChanged<ChatMessage>? onReply;

  /// الضغط على الاقتباس = يروح للرسالة الأصلية.
  final ValueChanged<String>? onQuoteTap;
  final GlobalKey Function(String id)? keyFor;

  /// رسالة بتنور لحظة (بعد ما نروحلها).
  final String? highlightId;
  final String peerName;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final extra = peerTyping ? 1 : 0;
    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      itemCount: messages.length + extra,
      itemBuilder: (_, index) {
        if (peerTyping && index == 0) return const _TypingBubble();
        final i = index - extra;
        final m = messages[messages.length - 1 - i];
        return m.kind == MessageKind.system
            ? _SystemLine(text: m.text)
            : _SwipeToReply(
                key: keyFor?.call(m.id) ?? ValueKey(m.id),
                onReply: onReply == null ? null : () => onReply!(m),
                child: _Bubble(
                  message: m,
                  peerName: peerName,
                  highlight: highlightId == m.id,
                  onLongPress: onMessageActions == null ? null : () => onMessageActions!(m),
                  onCancel: onCancelTransfer == null ? null : () => onCancelTransfer!(m),
                  onQuoteTap: onQuoteTap,
                ),
              );
      },
    );
  }
}

/// فقاعة "بيكتب..." بنقط متحركة.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.border),
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(20),
            topEnd: Radius.circular(20),
            bottomStart: Radius.circular(6),
            bottomEnd: Radius.circular(20),
          ),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Opacity(
                    opacity: 0.35 + 0.65 * (((_c.value * 3 - i) % 3) < 1 ? 1 - ((_c.value * 3 - i) % 1) : 0),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: p.textMuted, shape: BoxShape.circle),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemLine extends StatelessWidget {
  const _SystemLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// لون ثابت لاسم كل عضو في الجروب (من معرّفه).
int senderColorOf(String id) {
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

/// لون علامتين الصح لما الرسالة تتقرا (زي الواتساب) — بيتظبط حسب لون الفقاعة.
Color readTickColor(Palette p) =>
    p.onAccent.computeLuminance() > 0.5 ? const Color(0xFFB3E5FC) : const Color(0xFF0B57D0);

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.peerName,
    this.highlight = false,
    this.onLongPress,
    this.onCancel,
    this.onQuoteTap,
  });

  final ChatMessage message;
  final String peerName;
  final bool highlight;
  final VoidCallback? onLongPress;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onQuoteTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = message;
    final mine = m.kind == MessageKind.mine;
    String two(int v) => v.toString().padLeft(2, '0');
    final time = '${two(m.time.hour)}:${two(m.time.minute)}';
    final fg = mine ? p.onAccent : p.text;

    IconData? statusIcon;
    Color statusColor = fg.withValues(alpha: 0.7);
    switch (m.status) {
      case MessageStatus.sending:
        statusIcon = Icons.schedule_rounded;
      case MessageStatus.sent:
        statusIcon = Icons.done_rounded;
      case MessageStatus.delivered:
        statusIcon = Icons.done_all_rounded;
      case MessageStatus.read:
        statusIcon = Icons.done_all_rounded;
        statusColor = readTickColor(p);
      case MessageStatus.failed:
        statusIcon = Icons.error_outline_rounded;
        statusColor = mine ? fg : p.danger;
    }

    final bubble = Align(
      // رسائلي في جهة end (يسار الواجهة العربية) مثل تطبيقات المحادثة
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: m.media != null
            ? const EdgeInsets.fromLTRB(5, 5, 5, 6)
            : const EdgeInsets.fromLTRB(14, 9, 14, 6),
        decoration: BoxDecoration(
          gradient: mine ? p.accentGradient : null,
          color: mine ? null : p.surface,
          border: mine ? null : Border.all(color: p.border),
          borderRadius: BorderRadiusDirectional.only(
            topStart: Radius.circular(mine ? 22 : 8),
            topEnd: Radius.circular(mine ? 8 : 22),
            bottomStart: const Radius.circular(22),
            bottomEnd: const Radius.circular(22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine && m.sender != null)
              Padding(
                padding: EdgeInsetsDirectional.only(start: m.media != null ? 8 : 0, end: 8, top: m.media != null ? 3 : 0, bottom: 3),
                child: Text(
                  m.sender!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: avatarColor(senderColorOf(m.senderId ?? m.sender!)),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            if (m.reply != null)
              _QuoteBox(
                reply: m.reply!,
                mine: mine,
                peerName: peerName,
                onTap: onQuoteTap == null ? null : () => onQuoteTap!(m.reply!.id),
              ),
            if (m.media != null)
              MediaBubbleContent(message: m, onCancel: onCancel)
            else
              Text(
                m.text,
                style: TextStyle(color: fg, fontSize: 15.5, height: 1.5, fontWeight: FontWeight.w500),
              ),
            const SizedBox(height: 2),
            Padding(
              padding: m.media != null ? const EdgeInsets.symmetric(horizontal: 6) : EdgeInsets.zero,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.edited) ...[
                    Text('معدّلة', style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 10.5)),
                    const SizedBox(width: 6),
                  ],
                  Text(time, style: TextStyle(color: fg.withValues(alpha: 0.65), fontSize: 11)),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(statusIcon, size: 15, color: statusColor),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final lit = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: highlight ? p.accent.withValues(alpha: 0.18) : Colors.transparent,
      child: bubble,
    );
    if (onLongPress == null) return lit;
    return GestureDetector(onLongPress: onLongPress, behavior: HitTestBehavior.translucent, child: lit);
  }
}

/// الاقتباس فوق رسالة الرد.
class _QuoteBox extends StatelessWidget {
  const _QuoteBox({required this.reply, required this.mine, required this.peerName, this.onTap});

  final ReplyInfo reply;
  final bool mine;
  final String peerName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = mine ? p.onAccent : p.text;
    final barColor = mine ? p.onAccent : p.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: (mine ? Colors.black : p.accent).withValues(alpha: mine ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: BorderDirectional(start: BorderSide(color: barColor, width: 3.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              reply.toMine ? 'انت' : (reply.author ?? peerName),
              style: TextStyle(color: barColor, fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
            Text(
              reply.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// اسحب الرسالة للجنب عشان ترد عليها (زي الواتساب).
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({super.key, required this.child, this.onReply});

  final Widget child;
  final VoidCallback? onReply;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> with SingleTickerProviderStateMixin {
  static const _trigger = 64.0;
  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))
    ..addListener(() => setState(() => _dx = _from * (1 - _back.value)));
  double _dx = 0;
  double _from = 0;
  bool _fired = false;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onReply == null) return widget.child;
    final p = context.palette;
    // الواجهة عربي: السحب ناحية الشمال (عكس اتجاه الكتابة) زي الواتساب العربي
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sign = rtl ? -1.0 : 1.0;
    final progress = (_dx.abs() / _trigger).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        _back.stop();
        _fired = false;
      },
      onHorizontalDragUpdate: (d) {
        final next = (_dx + d.delta.dx);
        // بس في اتجاه الرد
        final clamped = sign > 0 ? next.clamp(0.0, _trigger * 1.4) : next.clamp(-_trigger * 1.4, 0.0);
        setState(() => _dx = clamped);
        if (!_fired && _dx.abs() >= _trigger) {
          _fired = true;
          HapticFeedback.lightImpact();
        }
      },
      onHorizontalDragEnd: (_) {
        if (_fired) widget.onReply!();
        _from = _dx;
        _back.forward(from: 0);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Align(
              alignment: rtl ? Alignment.centerRight : Alignment.centerLeft,
              child: Opacity(
                opacity: progress,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: p.surfaceAlt,
                    child: Icon(Icons.reply_rounded, size: 18, color: p.accent),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}

/// بطاقة التحقق من رمز الأمان.
class SafetyCodeCard extends StatelessWidget {
  const SafetyCodeCard({
    super.key,
    required this.code,
    required this.peerName,
    required this.onMatch,
    required this.onMismatch,
  });

  final String code;
  final String peerName;
  final VoidCallback onMatch;
  final VoidCallback onMismatch;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      borderColor: p.accent.withValues(alpha: 0.45),
      child: Column(
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.verified_user_rounded, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'قارن رمز الأمان مع $peerName',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              code,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: 6,
                color: p.accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تأكيد إضافي (اختياري): لو نفس الرقم ظاهر على الموبايل التاني يبقى متأكدين ١٠٠٪ إن محدش في النص.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textMuted, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'مختلف',
                  icon: Icons.close_rounded,
                  color: p.danger,
                  height: 46,
                  onPressed: onMismatch,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: 'متطابق',
                  icon: Icons.check_rounded,
                  height: 46,
                  onPressed: onMatch,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// بطاقة خطأ: السبب + الحل + أزرار.
class ChatErrorCard extends StatelessWidget {
  const ChatErrorCard({super.key, required this.error, this.actions = const [], this.onDismiss});

  final ChatError error;
  final List<Widget> actions;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      borderColor: p.danger.withValues(alpha: 0.4),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon: error.icon, color: p.danger, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(error.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(error.hint, style: TextStyle(color: p.textMuted, height: 1.6, fontSize: 13.5)),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                  icon: Icon(Icons.close_rounded, color: p.textMuted, size: 20),
                ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: actions),
            ),
          ],
        ],
      ),
    );
  }
}

/// رادار متحرك أثناء البحث.
class RadarPulse extends StatefulWidget {
  const RadarPulse({super.key, this.size = 180, this.icon = Icons.wifi_tethering_rounded});

  final double size;
  final IconData icon;

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Builder(builder: (_) {
                final t = (_c.value + i / 3) % 1;
                return Opacity(
                  opacity: (1 - t) * 0.55,
                  child: Container(
                    width: widget.size * (0.35 + 0.65 * t),
                    height: widget.size * (0.35 + 0.65 * t),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: p.accent, width: 2),
                    ),
                  ),
                );
              }),
            Container(
              width: widget.size * 0.34,
              height: widget.size * 0.34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: p.accentGradient,
                boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.4), blurRadius: 24)],
              ),
              child: Icon(widget.icon, color: p.onAccent, size: widget.size * 0.16),
            ),
          ],
        ),
      ),
    );
  }
}
