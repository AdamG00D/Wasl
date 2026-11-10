import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/platform/secure_clipboard.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../mesh/mesh_router.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui.dart';
import '../groups/group_ui.dart';
import '../hub/chat_hub.dart';
import 'call/call_controller.dart';
import 'core/chat_link.dart';
import 'core/chat_session.dart';
import 'widgets/chat_input.dart';
import 'widgets/chat_widgets.dart';

/// شاشة المحادثة (خاصة أو جروب): الرسائل + الحالة + الإدخال.
///
/// الخروج من الشاشة مش بيقفل المحادثة؛ بتفضل شغالة والرسايل بتوصل.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.conversation});

  final Conversation conversation;

  static Future<void> open(BuildContext context, Conversation c) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChatPage(conversation: c)));

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _hub = ChatHub.instance;
  Conversation get _c => widget.conversation;
  ChatSession get _s => _c.session;

  /// الرسالة اللي بنرد عليها.
  ReplyInfo? _reply;
  String? _highlight;
  Timer? _highlightTimer;
  final Map<String, GlobalKey> _keys = {};

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _hub.setVisible(_c);
    final c = _c;
    if (c is DirectChat) c.connect();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _hub.setVisible(null);
    super.dispose();
  }

  bool get _alive => _c is DirectChat ? _hub.directFor(_c.id) == _c : _hub.groupFor(_c.id) == _c;

  void _startReply(ChatMessage m) {
    if (m.kind == MessageKind.system) return;
    setState(() => _reply = _s.replyTo(m));
  }

  /// الضغط على الاقتباس: نروح للرسالة الأصلية وننوّرها لحظة.
  void _jumpTo(String id) {
    final ctx = _keys[id]?.currentContext;
    if (ctx == null) {
      showToast(context, 'الرسالة دي مبقتش موجودة على الشاشة');
      return;
    }
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.5);
    setState(() => _highlight = id);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _highlight = null);
    });
  }

  Future<void> _startCall({required bool video}) async {
    final chat = _c as DirectChat;
    final call = _hub.ensureCall(chat);
    if (call == null) return;
    if (call.busy) {
      _hub.showCallScreen(chat);
      return;
    }
    final err = await call.startCall(video: video);
    if (!mounted) return;
    if (err != null) {
      showToast(context, err, error: true);
      return;
    }
    if (call.state != CallState.idle) _hub.showCallScreen(chat);
  }

  /// رمز الأمان (اختياري): تأكيد إن محدش في النص.
  Future<void> _showSafetyCode() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SafetyCodeCard(
            code: _s.safetyCode!,
            peerName: _c.title,
            onMatch: () => Navigator.pop(ctx, true),
            onMismatch: () => Navigator.pop(ctx, false),
          ),
        ),
      ),
    );
    if (result == true) _s.confirmSafetyCode();
    if (result == false && mounted) {
      await infoDialog(
        context,
        icon: Icons.gpp_bad_rounded,
        error: true,
        title: 'الرمز مختلف؟',
        message: 'ده معناه إن ممكن حد منتحل شخصية الطرف التاني. متبعتش حاجة حساسة، واحظره من القايمة لو مش متأكد منه.',
      );
    }
  }

  Future<void> _toggleSave() async {
    final c = _c;
    if (c.saved) {
      final ok = await confirmDialog(
        context,
        icon: Icons.bookmark_remove_rounded,
        title: 'إلغاء حفظ المحادثة؟',
        message: 'الرسايل هتتمسح من تخزين الموبايل، وهتفضل قدامك لحد ما تقفل التطبيق بس.',
        confirm: 'إلغاء الحفظ',
        destructive: true,
      );
      if (!ok) return;
      await _hub.setSaved(c, false);
      if (mounted) showToast(context, 'المحادثة مبقتش بتتحفظ');
    } else {
      await _hub.setSaved(c, true);
      if (mounted) showToast(context, 'المحادثة بتتحفظ على الموبايل (مشفّرة)');
    }
  }

  Future<void> _menu(String v) async {
    final c = _c;
    switch (v) {
      case 'save':
        await _toggleSave();
      case 'code':
        if (_s.safetyCode != null) await _showSafetyCode();
      case 'info':
        if (c is GroupChat) await GroupInfoScreen.open(context, c);
      case 'clear':
        final ok = await confirmDialog(
          context,
          title: 'مسح الرسايل؟',
          message: 'الرسايل هتتمسح من عندك بس.',
          confirm: 'مسح',
          destructive: true,
        );
        if (ok) await _hub.clearMessages(c);
      case 'block':
        if (c is! DirectChat) return;
        final blocked = _hub.isBlocked(c.peerId);
        if (!blocked) {
          final ok = await confirmDialog(
            context,
            icon: Icons.block_rounded,
            title: 'حظر ${c.title}؟',
            message: 'مش هيقدر يبعتلك رسايل ولا هيظهر في القريبين. تقدر تلغي الحظر من الإعدادات.',
            confirm: 'حظر',
            destructive: true,
          );
          if (!ok) return;
        }
        await _hub.setBlocked(c.peerId, !blocked);
        if (!blocked && mounted) Navigator.of(context).maybePop();
      case 'delete':
        if (c is! DirectChat) return;
        final ok = await confirmDialog(
          context,
          title: 'حذف المحادثة؟',
          message: 'المحادثة ورسايلها هتتمسح من موبايلك.',
          confirm: 'حذف',
          destructive: true,
        );
        if (!ok) return;
        await _hub.deleteDirect(c);
        if (mounted) Navigator.of(context).maybePop();
      case 'leave':
        if (c is! GroupChat) return;
        final ok = await confirmDialog(
          context,
          title: 'الخروج من "${c.title}"؟',
          message: 'رسايل الجروب هتتمسح من موبايلك.',
          confirm: 'خروج',
          destructive: true,
        );
        if (!ok) return;
        await _hub.leaveGroup(c);
        if (mounted) Navigator.of(context).maybePop();
    }
  }

  /// ضغطة طويلة على رسالة.
  Future<void> _messageActions(ChatMessage m) async {
    if (m.kind == MessageKind.system) return;
    HapticFeedback.selectionClick();
    final p = context.palette;
    final s = _s;
    final mine = m.kind == MessageKind.mine;
    final group = _c.isGroup;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (s.canSend)
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('رد'),
                  onTap: () => Navigator.pop(ctx, 'reply'),
                ),
              if (m.media == null)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('نسخ'),
                  onTap: () => Navigator.pop(ctx, 'copy'),
                ),
              if (group && !mine && m.senderId != null && _hub.nodeFor(m.senderId!) != null)
                ListTile(
                  leading: const Icon(Icons.lock_person_rounded),
                  title: Text('رسالة خاصة لـ ${m.sender ?? ''}'),
                  onTap: () => Navigator.pop(ctx, 'private'),
                ),
              if (s.canEdit(m))
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('تعديل'),
                  onTap: () => Navigator.pop(ctx, 'edit'),
                ),
              if (m.transferring)
                ListTile(
                  leading: Icon(Icons.cancel_rounded, color: p.danger),
                  title: Text(mine ? 'إلغاء الإرسال' : 'إلغاء الاستلام', style: TextStyle(color: p.danger)),
                  onTap: () => Navigator.pop(ctx, 'cancel'),
                ),
              if (mine && !m.transferring)
                ListTile(
                  leading: Icon(Icons.delete_sweep_rounded, color: p.danger),
                  title: Text(group ? 'حذف عند الكل' : 'حذف عندي وعنده', style: TextStyle(color: p.danger)),
                  onTap: () => Navigator.pop(ctx, 'del-all'),
                ),
              if (!m.transferring)
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: p.danger),
                  title: Text('حذف عندي بس', style: TextStyle(color: p.danger)),
                  onTap: () => Navigator.pop(ctx, 'del-me'),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'reply':
        _startReply(m);
      case 'copy':
        await SecureClipboard.copy(context, m.text);
      case 'private':
        final chat = _hub.openDirect(m.senderId!);
        if (chat != null) await ChatPage.open(context, chat);
      case 'edit':
        final text = await _editDialog(m.text);
        if (text != null) await s.edit(m, text);
      case 'cancel':
        await s.cancelTransfer(m);
      case 'del-all':
        await s.deleteForEveryone(m);
      case 'del-me':
        await s.deleteForMe(m);
    }
  }

  Future<String?> _editDialog(String current) {
    final ctrl = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الرسالة'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
          maxLength: 4000,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.bg,
      body: ListenableBuilder(
        listenable: Listenable.merge([_hub, _s, AppSettings.instance]),
        builder: (context, _) {
          final c = _c;
          final s = _s;
          final direct = c is DirectChat ? c : null;
          final group = c is GroupChat ? c : null;
          final alive = _alive;
          final wifi = _hub.kind == TransportKind.wifi;

          final (String label, Color color, IconData? icon) = () {
            if (!alive) return ('المحادثة اتقفلت', p.textMuted, Icons.link_off_rounded);
            if (group != null) {
              final n = group.members.length;
              return (
                n == 0 ? 'مفيش حد من الأعضاء قريب دلوقتي' : '$n ${n == 1 ? 'عضو' : 'أعضاء'} متصلين دلوقتي',
                n == 0 ? p.textMuted : p.success,
                group.info.mode == GroupMode.open ? Icons.public_rounded : Icons.lock_rounded,
              );
            }
            final d = direct!;
            if (_hub.isBlocked(d.peerId)) return ('محظور', p.danger, Icons.block_rounded);
            if (s.peerTyping && s.state == SessionState.ready) return ('بيكتب...', p.accent, null);
            return switch (s.state) {
              SessionState.ready when s.verified => ('مشفّرة • الرمز متأكد', p.success, Icons.verified_user_rounded),
              SessionState.ready => ('مشفّرة من طرف لطرف', p.success, Icons.lock_rounded),
              SessionState.securing => ('بنأمّن الاتصال...', p.warning, Icons.lock_clock_rounded),
              _ when d.online => ('جاري الاتصال...', p.warning, Icons.sync_rounded),
              _ => ('مش متصل دلوقتي', p.textMuted, Icons.cloud_off_rounded),
            };
          }();

          final canSend = alive && s.canSend;
          return Column(
            children: [
              _Header(
                conversation: c,
                online: direct?.online,
                status: label,
                statusColor: color,
                statusIcon: icon,
                onTitleTap: group == null ? null : () => GroupInfoScreen.open(context, group),
                actions: [
                  if (direct != null && direct.canCall && s.state == SessionState.ready) ...[
                    IconButton(
                      tooltip: 'مكالمة فيديو',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.videocam_rounded, color: p.accent),
                      onPressed: () => _startCall(video: true),
                    ),
                    IconButton(
                      tooltip: 'مكالمة صوتية',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.call_rounded, color: p.accent),
                      onPressed: () => _startCall(video: false),
                    ),
                  ],
                  if (group != null && group.requests.isNotEmpty)
                    IconButton(
                      tooltip: 'طلبات انضمام',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => GroupInfoScreen.open(context, group),
                      icon: Badge(
                        label: Text('${group.requests.length}'),
                        child: Icon(Icons.person_add_alt_1_rounded, color: p.accent),
                      ),
                    ),
                  if (alive)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: p.textMuted),
                      onSelected: _menu,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'save',
                          child: _MenuRow(
                            icon: c.saved ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined,
                            text: c.saved ? 'إلغاء حفظ المحادثة' : 'حفظ المحادثة على الموبايل',
                          ),
                        ),
                        if (group != null)
                          const PopupMenuItem(
                            value: 'info',
                            child: _MenuRow(icon: Icons.groups_2_outlined, text: 'الأعضاء ومعلومات الجروب'),
                          ),
                        if (direct != null && s.safetyCode != null)
                          const PopupMenuItem(
                            value: 'code',
                            child: _MenuRow(icon: Icons.verified_user_outlined, text: 'رمز الأمان (اختياري)'),
                          ),
                        const PopupMenuItem(
                          value: 'clear',
                          child: _MenuRow(icon: Icons.cleaning_services_outlined, text: 'مسح الرسايل'),
                        ),
                        if (direct != null)
                          PopupMenuItem(
                            value: 'block',
                            child: _MenuRow(
                              icon: Icons.block_rounded,
                              text: _hub.isBlocked(direct.peerId) ? 'إلغاء الحظر' : 'حظر',
                            ),
                          ),
                        if (direct != null)
                          PopupMenuItem(
                            value: 'delete',
                            child: _MenuRow(icon: Icons.delete_outline_rounded, text: 'حذف المحادثة', color: p.danger),
                          ),
                        if (group != null)
                          PopupMenuItem(
                            value: 'leave',
                            child: _MenuRow(icon: Icons.logout_rounded, text: 'الخروج من الجروب', color: p.danger),
                          ),
                      ],
                    ),
                ],
              ),
              if (alive && direct != null && !direct.online && !_hub.isBlocked(direct.peerId))
                _Notice(
                  icon: Icons.cloud_off_rounded,
                  color: p.textMuted,
                  text: wifi
                      ? '${c.title} مش على الشبكة دلوقتي. أول ما يفتح التطبيق على نفس الواي فاي هتقدر تكلمه.'
                      : '${c.title} مش قريب دلوقتي. أول ما يقرب ويفتح التطبيق هتقدر تكلمه.',
                ),
              if (alive && group != null && !s.canSend)
                _Notice(
                  icon: Icons.cloud_off_rounded,
                  color: p.textMuted,
                  text: 'مفيش أي جهاز قريب دلوقتي — الرسايل بتتبعت لما يبقى فيه حد واصلين له.',
                ),
              Expanded(
                child: s.messages.isEmpty
                    ? _EmptyChat(group: group != null, saved: c.saved)
                    : MessageList(
                        messages: s.messages,
                        peerTyping: s.peerTyping && direct != null,
                        onMessageActions: _messageActions,
                        onReply: canSend ? _startReply : null,
                        onQuoteTap: _jumpTo,
                        keyFor: _keyFor,
                        highlightId: _highlight,
                        peerName: c.title,
                        onCancelTransfer: (m) async {
                          final ok = await confirmDialog(
                            context,
                            title: m.kind == MessageKind.mine ? 'إلغاء الإرسال؟' : 'إلغاء الاستلام؟',
                            message: m.kind == MessageKind.mine
                                ? 'الملف هيتشال من المحادثة عندك وعند الطرف التاني.'
                                : 'الملف هيتشال من عندك ومش هيكمّل.',
                            confirm: 'إلغاء النقل',
                            cancel: 'رجوع',
                            destructive: true,
                          );
                          if (ok) await s.cancelTransfer(m);
                        },
                      ),
              ),
              ChatInputBar(
                link: ChatLink(s, supportsVideo: s.allowVideo),
                enabled: canSend,
                reply: _reply,
                replyTitle: _reply == null ? null : (_reply!.toMine ? 'انت' : (_reply!.author ?? c.title)),
                onCancelReply: () {
                  if (_reply != null) setState(() => _reply = null);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(icon, size: 20, color: color ?? p.textMuted),
        const SizedBox(width: 12),
        Flexible(child: Text(text, style: TextStyle(color: color, fontSize: 14.5))),
      ],
    );
  }
}

/// الشريط اللي فوق: رجوع • صورة • اسم وحالة • أزرار.
class _Header extends StatelessWidget {
  const _Header({
    required this.conversation,
    required this.online,
    required this.status,
    required this.statusColor,
    required this.statusIcon,
    required this.actions,
    this.onTitleTap,
  });

  final Conversation conversation;
  final bool? online;
  final String status;
  final Color statusColor;
  final IconData? statusIcon;
  final List<Widget> actions;
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = conversation;
    return Material(
      color: p.surface,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
        padding: EdgeInsetsDirectional.only(
          top: MediaQuery.paddingOf(context).top + 4,
          bottom: 8,
          start: 2,
          end: 2,
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'رجوع',
              icon: const BackButtonIcon(),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: InkWell(
                onTap: onTitleTap,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Avatar(
                        name: c.title,
                        color: c.color,
                        avatarHash: c.avatar,
                        size: 42,
                        online: online,
                        icon: c.isGroup ? Icons.groups_rounded : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    c.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.35),
                                  ),
                                ),
                                if (c.saved) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.bookmark_rounded, size: 14, color: p.textMuted),
                                ],
                              ],
                            ),
                            Row(
                              children: [
                                if (statusIcon != null) ...[
                                  Icon(statusIcon, size: 12.5, color: statusColor),
                                  const SizedBox(width: 4),
                                ],
                                Flexible(
                                  child: Text(
                                    status,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.6))),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.group, required this.saved});

  final bool group;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(group ? Icons.forum_outlined : Icons.lock_outline_rounded, size: 44, color: p.textMuted),
            const SizedBox(height: 14),
            Text(
              group ? 'ابدأ الكلام في الجروب' : 'قول أهلاً 👋',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              '${group ? 'رسايل الجروب مشفّرة بمفتاحه ومبتعدّيش على أي سيرفر.' : 'الرسايل مشفّرة من طرف لطرف تلقائياً — من غير كلمة سر ومن غير إنترنت.'}\n'
              '${saved ? 'المحادثة دي بتتحفظ على موبايلك.' : 'المحادثة دي مش بتتحفظ: هتتمسح لما تقفل التطبيق.'}',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted, height: 1.7, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}
