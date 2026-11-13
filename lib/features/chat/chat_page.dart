import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/platform/secure_clipboard.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../mesh/mesh_router.dart';
import '../../widgets/feedback.dart';
import '../../widgets/focus_guard.dart';
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
  const ChatPage({super.key, required this.conversation, this.startCall});

  final Conversation conversation;

  /// يبدأ مكالمة أول ما الاتصال يجهز: 'voice' أو 'video'.
  final String? startCall;

  static Future<void> open(BuildContext context, Conversation c, {String? startCall}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChatPage(conversation: c, startCall: startCall),
    ),
  );

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
  final _scroll = ScrollController();
  final _inputKey = GlobalKey<ChatInputBarState>();

  // ---- البحث جوه المحادثة ----
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  /// معرّفات الرسايل اللي فيها كلمة البحث (الأحدث الأول).
  List<String> _matches = const [];
  int _matchAt = 0;

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _hub.setVisible(_c);
    final c = _c;
    if (c is DirectChat) {
      c.connect();
      if (widget.startCall != null) _callWhenReady(widget.startCall == 'video');
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _hub.clearVisible(_c);
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// المكالمة محتاجة القناة المشفرة تكون جاهزة: نستنى شوية وبعدين نتصل.
  Future<void> _callWhenReady(bool video) async {
    for (var i = 0; i < 40 && mounted && _s.state != SessionState.ready; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!mounted) return;
    final chat = _c;
    if (chat is DirectChat && chat.canCall && _s.state == SessionState.ready) {
      await _startCall(video: video);
    } else {
      showToast(context, context.l10n.callStartNow, error: true);
    }
  }

  bool get _alive => _c is DirectChat ? _hub.directFor(_c.id) == _c : _hub.groupFor(_c.id) == _c;

  void _startReply(ChatMessage m) {
    if (m.kind == MessageKind.system) return;
    setState(() => _reply = _s.replyTo(m));
  }

  /// أي رسالة مرسومة على الشاشة دلوقتي (عشان نعرف نتحرك لفوق ولا لتحت).
  int? _builtIndex() {
    final messages = _s.messages;
    for (var i = messages.length - 1; i >= 0; i--) {
      if (_keys[messages[i].id]?.currentContext != null) return i;
    }
    return null;
  }

  /// نروح لرسالة وننوّرها لحظة (الضغط على اقتباس، أو نتيجة بحث).
  /// القايمة بترسم اللي ظاهر بس، فلو الرسالة بعيدة بنتحرك ناحيتها لحد ما تترسم.
  Future<void> _jumpTo(String id) async {
    final index = _s.messages.indexWhere((m) => m.id == id);
    if (index < 0) {
      showToast(context, context.l10n.messageGone);
      return;
    }
    for (var step = 0; step < 80; step++) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.5);
        break;
      }
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final built = _builtIndex();
      // القايمة مقلوبة: الأقدم = إزاحة أكبر
      final older = built == null || index < built;
      final target = (pos.pixels + (older ? 1 : -1) * pos.viewportDimension * 0.8).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      if ((target - pos.pixels).abs() < 1) break;
      _scroll.jumpTo(target);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(() => _highlight = id);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _highlight = null);
    });
  }

  // ---------------- البحث ----------------

  void _openSearch() => setState(() => _searching = true);

  void _closeSearch() {
    hideKeyboard();
    setState(() {
      _searching = false;
      _matches = const [];
      _searchCtrl.clear();
    });
  }

  void _search(String raw) {
    final q = raw.trim().toLowerCase();
    final found = <String>[];
    if (q.isNotEmpty) {
      for (final m in _s.messages.reversed) {
        if (m.kind == MessageKind.system) continue;
        final hay = m.media == null ? m.text : (m.media!.name ?? '');
        if (hay.toLowerCase().contains(q)) found.add(m.id);
      }
    }
    setState(() {
      _matches = found;
      _matchAt = 0;
    });
    if (found.isNotEmpty) _jumpTo(found.first);
  }

  void _stepSearch(int delta) {
    if (_matches.isEmpty) return;
    setState(() => _matchAt = (_matchAt + delta).clamp(0, _matches.length - 1));
    _jumpTo(_matches[_matchAt]);
  }

  // ---------------- تفاعل / تحويل / معلومات ----------------

  static const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  /// اختيار أي إيموجي كتفاعل.
  Future<String?> _pickEmoji() {
    final p = context.palette;
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 320,
          child: EmojiPicker(
            onEmojiSelected: (_, emoji) => Navigator.pop(ctx, emoji.emoji),
            config: Config(
              height: 320,
              checkPlatformCompatibility: true,
              locale: const Locale('en'),
              emojiViewConfig: EmojiViewConfig(columns: 8, emojiSizeMax: 30, backgroundColor: p.surface),
              categoryViewConfig: CategoryViewConfig(
                backgroundColor: p.surface,
                indicatorColor: p.accent,
                iconColor: p.textMuted,
                iconColorSelected: p.accent,
                dividerColor: p.border,
              ),
              bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
            ),
          ),
        ),
      ),
    );
  }

  /// يحوّل الرسالة لمحادثة تانية (نص أو ملف وصل كامل).
  Future<void> _forward(ChatMessage m) async {
    final targets = _hub.conversations.where((c) => c.session.canSend).toList();
    if (targets.isEmpty) {
      showToast(context, context.l10n.noForwardTarget, error: true);
      return;
    }
    final to = await showModalBottomSheet<Conversation>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(ctx.l10n.forwardTo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              for (final c in targets)
                ListTile(
                  leading: Avatar(
                    name: c.title,
                    color: c.color,
                    avatarHash: c.avatar,
                    cartoon: c.cartoon,
                    size: 42,
                    icon: c.isGroup ? Icons.groups_rounded : null,
                  ),
                  title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(c.isGroup ? ctx.l10n.group : ctx.l10n.privateChat),
                  onTap: () => Navigator.pop(ctx, c),
                ),
            ],
          ),
        ),
      ),
    );
    if (to == null || !mounted) return;
    final media = m.media;
    String? error;
    if (media == null) {
      await to.session.send(m.text, forwarded: true);
    } else {
      error = await to.session.sendMedia(
        File(media.path!),
        media.kind,
        name: media.name,
        durationMs: media.durationMs,
        waveform: media.waveform,
        forwarded: true,
      );
    }
    if (mounted) showToast(context, error ?? context.l10n.forwardedTo(to.title), error: error != null);
  }

  /// معلومات رسالتي: وقتها وحالتها، وفي الجروب مين قراها.
  Future<void> _showInfo(ChatMessage m) async {
    final p = context.palette;
    final c = _c;
    final group = c is GroupChat ? c : null;
    String two(int v) => v.toString().padLeft(2, '0');
    final t = m.time;
    final when = '${t.day}/${t.month}/${t.year}  ${two(t.hour)}:${two(t.minute)}';
    final l = context.l10n;
    final readers = [for (final id in m.readBy) _hub.nameOf(id) ?? l.member];
    final waiting = [
      for (final n in group?.members ?? const <MeshNode>[])
        if (!m.readBy.contains(n.id) && !group!.info.banned.contains(n.id)) n.name,
    ];
    final status = switch (m.status) {
      MessageStatus.sending => l.statusSending,
      MessageStatus.sent => group != null ? l.statusSentGroup : l.statusSent,
      MessageStatus.delivered => group != null ? l.statusDeliveredGroup : l.statusDelivered,
      MessageStatus.read => group != null ? l.statusReadGroup : l.statusRead,
      MessageStatus.failed => l.statusFailed,
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              Text(l.messageInfo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _InfoLine(icon: Icons.schedule_rounded, text: when),
              _InfoLine(icon: Icons.done_all_rounded, text: status),
              if (group != null) ...[
                const SizedBox(height: 10),
                Text(
                  l.readByCount(readers.length),
                  style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (readers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(l.nobodyYet, style: TextStyle(color: p.textMuted)),
                  ),
                for (final name in readers)
                  _InfoLine(icon: Icons.done_all_rounded, text: name, color: readTickColor(p)),
                if (waiting.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    l.onlineNotReadCount(waiting.length),
                    style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  for (final name in waiting) _InfoLine(icon: Icons.done_rounded, text: name),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openSender(ChatMessage m) {
    final c = _c;
    final id = m.senderId;
    if (c is! GroupChat || id == null) return;
    final name = _hub.nodeFor(id)?.name ?? m.sender ?? context.l10n.member;
    showMemberSheet(
      context,
      c,
      id,
      fallbackName: m.sender,
      onMention: _s.canSend ? () => _inputKey.currentState?.insertMention(id, name) : null,
    );
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
        title: context.l10n.codeMismatchTitle,
        message: context.l10n.codeMismatchBody,
      );
    }
  }

  Future<void> _toggleSave() async {
    final c = _c;
    if (c.saved) {
      final ok = await confirmDialog(
        context,
        icon: Icons.bookmark_remove_rounded,
        title: context.l10n.unsaveChatTitle,
        message: context.l10n.unsaveChatBody,
        confirm: context.l10n.unsaveConfirm,
        destructive: true,
      );
      if (!ok) return;
      await _hub.setSaved(c, false);
      if (mounted) showToast(context, context.l10n.chatUnsavedToast);
    } else {
      await _hub.setSaved(c, true);
      if (mounted) showToast(context, context.l10n.chatSavedEncryptedToast);
    }
  }

  Future<void> _menu(String v) async {
    final c = _c;
    switch (v) {
      case 'save':
        await _toggleSave();
      case 'search':
        _openSearch();
      case 'mute':
        await toggleMute(context, c);
      case 'pin':
        await _hub.setPinned(c, !c.pinned);
      case 'code':
        if (_s.safetyCode != null) await _showSafetyCode();
      case 'info':
        if (c is GroupChat) await GroupInfoScreen.open(context, c);
      case 'clear':
        final ok = await confirmDialog(
          context,
          title: context.l10n.clearTitle,
          message: context.l10n.clearBody,
          confirm: context.l10n.clear,
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
            title: context.l10n.blockTitle(c.title),
            message: context.l10n.blockDirectBody,
            confirm: context.l10n.block,
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
          title: context.l10n.deleteChatQ,
          message: context.l10n.deleteChatBody,
          confirm: context.l10n.deleteAction,
          destructive: true,
        );
        if (!ok) return;
        await _hub.deleteDirect(c);
        if (mounted) Navigator.of(context).maybePop();
      case 'leave':
        if (c is! GroupChat) return;
        final ok = await confirmDialog(
          context,
          title: context.l10n.leaveGroupTitle(c.title),
          message: context.l10n.groupMessagesErased,
          confirm: context.l10n.leave,
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
    final action = await showActionSheet<String>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.canSend)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final e in _quickReactions)
                    InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => Navigator.pop(ctx, 'react:$e'),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: m.reactions[s.myReactionKey] == e ? p.accentSoft : Colors.transparent,
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 25)),
                      ),
                    ),
                  IconButton(
                    tooltip: ctx.l10n.otherEmoji,
                    onPressed: () => Navigator.pop(ctx, 'react+'),
                    icon: Icon(Icons.add_circle_outline_rounded, color: p.textMuted),
                  ),
                ],
              ),
            ),
          if (s.canSend)
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: Text(ctx.l10n.reply),
              onTap: () => Navigator.pop(ctx, 'reply'),
            ),
          if (!m.transferring && (m.media == null || m.media!.ready))
            ListTile(
              leading: const Icon(Icons.shortcut_rounded),
              title: Text(ctx.l10n.forward),
              onTap: () => Navigator.pop(ctx, 'forward'),
            ),
          if (mine)
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(ctx.l10n.messageInfo),
              onTap: () => Navigator.pop(ctx, 'info'),
            ),
          if (m.media == null)
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(ctx.l10n.copy),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
          if (group && !mine && m.senderId != null && _hub.nodeFor(m.senderId!) != null)
            ListTile(
              leading: const Icon(Icons.lock_person_rounded),
              title: Text(ctx.l10n.privateMessageTo(m.sender ?? '')),
              onTap: () => Navigator.pop(ctx, 'private'),
            ),
          if (group && !mine && m.senderId != null && s.canSend)
            ListTile(
              leading: const Icon(Icons.alternate_email_rounded),
              title: Text(ctx.l10n.mentionName(m.sender ?? '')),
              onTap: () => Navigator.pop(ctx, 'mention'),
            ),
          if (s.canEdit(m))
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text(ctx.l10n.edit),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
          if (m.transferring)
            ListTile(
              leading: Icon(Icons.cancel_rounded, color: p.danger),
              title: Text(mine ? ctx.l10n.cancelSending : ctx.l10n.cancelReceiving, style: TextStyle(color: p.danger)),
              onTap: () => Navigator.pop(ctx, 'cancel'),
            ),
          if (!m.transferring && _hub.canDeleteForAll(_c, m))
            ListTile(
              leading: Icon(Icons.delete_sweep_rounded, color: p.danger),
              title: Text(
                !group
                    ? ctx.l10n.deleteForBoth
                    : mine
                    ? ctx.l10n.deleteForAll
                    : ctx.l10n.deleteForAllAdmin,
                style: TextStyle(color: p.danger),
              ),
              onTap: () => Navigator.pop(ctx, 'del-all'),
            ),
          if (!m.transferring)
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: p.danger),
              title: Text(ctx.l10n.deleteForMe, style: TextStyle(color: p.danger)),
              onTap: () => Navigator.pop(ctx, 'del-me'),
            ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    if (action.startsWith('react:')) {
      await s.react(m, action.substring(6));
      return;
    }
    switch (action) {
      case 'react+':
        final emoji = await _pickEmoji();
        if (emoji != null) await s.react(m, emoji);
      case 'forward':
        await _forward(m);
      case 'info':
        await _showInfo(m);
      case 'reply':
        _startReply(m);
      case 'copy':
        await SecureClipboard.copy(context, m.text);
      case 'private':
        final chat = _hub.openDirect(m.senderId!);
        if (chat != null) await ChatPage.open(context, chat);
      case 'mention':
        _inputKey.currentState?.insertMention(m.senderId!, _hub.nodeFor(m.senderId!)?.name ?? m.sender ?? context.l10n.member);
      case 'edit':
        final text = await _editDialog(m.text);
        if (text != null) await s.edit(m, text);
      case 'cancel':
        await s.cancelTransfer(m);
      case 'del-all':
        await _hub.deleteForAll(_c, m);
      case 'del-me':
        await s.deleteForMe(m);
    }
  }

  Future<String?> _editDialog(String current) {
    final ctrl = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.editMessage),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
          maxLength: 4000,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(ctx.l10n.save),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _searching) _closeSearch();
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: ListenableBuilder(
          listenable: Listenable.merge([_hub, _s, AppSettings.instance]),
          builder: (context, _) {
            final c = _c;
            final s = _s;
            final direct = c is DirectChat ? c : null;
            final group = c is GroupChat ? c : null;
            final alive = _alive;
            final wifi = _hub.kind != TransportKind.bluetooth;
            final typers = s.typingNames;
            final l = context.l10n;
            final typingLabel = typers.isEmpty
                ? null
                : typers.length == 1
                ? l.typingOne(typers[0])
                : typers.length == 2
                ? l.typingTwo(typers[0], typers[1])
                : l.typingMany(typers.length);

            final (String label, Color color, IconData? icon) = () {
              if (!alive) return (l.chatClosed, p.textMuted, Icons.link_off_rounded);
              if (group != null) {
                if (typingLabel != null) return ('$typingLabel...', p.accent, null);
                final n = group.members.length;
                return (
                  n == 0 ? l.noMembersNearby : l.membersOnline(n),
                  n == 0 ? p.textMuted : p.success,
                  group.info.mode == GroupMode.open ? Icons.public_rounded : Icons.lock_rounded,
                );
              }
              final d = direct!;
              if (_hub.isBlocked(d.peerId)) return (l.blocked, p.danger, Icons.block_rounded);
              if (s.peerTyping && s.state == SessionState.ready) return (l.typing, p.accent, null);
              return switch (s.state) {
                SessionState.ready when s.verified => (l.encryptedVerified, p.success, Icons.verified_user_rounded),
                SessionState.ready => (l.e2eEncrypted, p.success, Icons.lock_rounded),
                SessionState.securing => (l.securing, p.warning, Icons.lock_clock_rounded),
                _ when d.online => (l.connecting, p.warning, Icons.sync_rounded),
                _ => (l.notConnectedNow, p.textMuted, Icons.cloud_off_rounded),
              };
            }();

            final canSend = alive && s.canSend;
            return Column(
              children: [
                if (_searching)
                  _SearchBar(
                    controller: _searchCtrl,
                    count: _matches.length,
                    at: _matchAt,
                    onChanged: _search,
                    onClose: _closeSearch,
                    onOlder: () => _stepSearch(1),
                    onNewer: () => _stepSearch(-1),
                  )
                else
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
                          tooltip: l.videoCall,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.videocam_rounded, color: p.accent),
                          onPressed: () => _startCall(video: true),
                        ),
                        IconButton(
                          tooltip: l.voiceCall,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.call_rounded, color: p.accent),
                          onPressed: () => _startCall(video: false),
                        ),
                      ],
                      if (group != null && group.requests.isNotEmpty)
                        IconButton(
                          tooltip: l.joinRequestsTooltip,
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
                              value: 'search',
                              child: _MenuRow(icon: Icons.search_rounded, text: l.searchChat),
                            ),
                            PopupMenuItem(
                              value: 'mute',
                              child: _MenuRow(
                                icon: c.muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                                text: c.muted ? l.unmuteNotifications : l.muteNotifications,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'pin',
                              child: _MenuRow(
                                icon: c.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                                text: c.pinned ? l.unpin : l.pin,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'save',
                              child: _MenuRow(
                                icon: c.saved ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined,
                                text: c.saved ? l.unsaveChat : l.saveChat,
                              ),
                            ),
                            if (group != null)
                              PopupMenuItem(
                                value: 'info',
                                child: _MenuRow(icon: Icons.groups_2_outlined, text: l.membersAndInfo),
                              ),
                            if (direct != null && s.safetyCode != null)
                              PopupMenuItem(
                                value: 'code',
                                child: _MenuRow(icon: Icons.verified_user_outlined, text: l.safetyCodeOptional),
                              ),
                            PopupMenuItem(
                              value: 'clear',
                              child: _MenuRow(icon: Icons.cleaning_services_outlined, text: l.clearMessages),
                            ),
                            if (direct != null)
                              PopupMenuItem(
                                value: 'block',
                                child: _MenuRow(
                                  icon: Icons.block_rounded,
                                  text: _hub.isBlocked(direct.peerId) ? l.unblock : l.block,
                                ),
                              ),
                            if (direct != null)
                              PopupMenuItem(
                                value: 'delete',
                                child: _MenuRow(
                                  icon: Icons.delete_outline_rounded,
                                  text: l.deleteChat,
                                  color: p.danger,
                                ),
                              ),
                            if (group != null)
                              PopupMenuItem(
                                value: 'leave',
                                child: _MenuRow(icon: Icons.logout_rounded, text: l.leaveGroup, color: p.danger),
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
                        ? l.peerOfflineWifi(c.title)
                        : l.peerOfflineBt(c.title),
                  ),
                if (alive && group != null && !s.canSend)
                  _Notice(
                    icon: Icons.cloud_off_rounded,
                    color: p.textMuted,
                    text: l.noDeviceNearby,
                  ),
                Expanded(
                  child: s.messages.isEmpty
                      ? _EmptyChat(group: group != null, saved: c.saved)
                      : MessageList(
                          messages: s.messages,
                          controller: _scroll,
                          peerTyping: s.peerTyping && alive,
                          typingLabel: group != null ? typingLabel : null,
                          myReactionKey: s.myReactionKey,
                          onReact: canSend ? (m, e) => s.react(m, e) : null,
                          senderLook: group == null
                              ? null
                              : (m) {
                                  final n = _hub.nodeFor(m.senderId!);
                                  return SenderLook(
                                    color: n?.color ?? senderColorOf(m.senderId!),
                                    avatar: n?.avatar,
                                    cartoon: n?.cartoon,
                                  );
                                },
                          onSenderTap: group == null ? null : _openSender,
                          onMessageActions: _messageActions,
                          onReply: canSend ? _startReply : null,
                          onQuoteTap: _jumpTo,
                          keyFor: _keyFor,
                          highlightId: _highlight,
                          peerName: c.title,
                          onCancelTransfer: (m) async {
                            final ok = await confirmDialog(
                              context,
                              title: m.kind == MessageKind.mine ? l.cancelSendingQ : l.cancelReceivingQ,
                              message: m.kind == MessageKind.mine
                                  ? l.cancelSendingBody
                                  : l.cancelReceivingBody,
                              confirm: l.cancelTransfer,
                              cancel: l.back,
                              destructive: true,
                            );
                            if (ok) await s.cancelTransfer(m);
                          },
                        ),
                ),
                ChatInputBar(
                  key: _inputKey,
                  link: ChatLink(s, supportsVideo: s.allowVideo),
                  enabled: canSend,
                  mentionCandidates: group == null
                      ? null
                      : () => [
                          for (final n in group.members)
                            if (!group.info.banned.contains(n.id))
                              MentionCandidate(
                                id: n.id,
                                name: n.name,
                                color: n.color,
                                avatar: n.avatar,
                                cartoon: n.cartoon,
                              ),
                        ],
                  reply: _reply,
                  replyTitle: _reply == null ? null : (_reply!.toMine ? l.you : (_reply!.author ?? c.title)),
                  onCancelReply: () {
                    if (_reply != null) setState(() => _reply = null);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// كتم إشعارات محادثة (أو إلغاء الكتم لو مكتومة).
Future<void> toggleMute(BuildContext context, Conversation c) async {
  final hub = ChatHub.instance;
  if (c.muted) {
    await hub.setMuted(c);
    if (context.mounted) showToast(context, context.l10n.notificationsBack);
    return;
  }
  final choice = await showActionSheet<int>(
    context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(ctx.l10n.muteNotifications, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ),
        for (final (hours, label) in [
          (1, ctx.l10n.muteHour),
          (8, ctx.l10n.mute8Hours),
          (24 * 7, ctx.l10n.muteWeek),
          (0, ctx.l10n.muteAlways),
        ])
          ListTile(
            leading: const Icon(Icons.notifications_off_outlined),
            title: Text(label),
            onTap: () => Navigator.pop(ctx, hours),
          ),
      ],
    ),
  );
  if (choice == null) return;
  await hub.setMuted(
    c,
    duration: choice == 0 ? null : Duration(hours: choice),
    forever: choice == 0,
  );
  if (context.mounted) {
    showToast(context, c.isGroup ? context.l10n.mutedGroupToast : context.l10n.mutedToast);
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? p.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// شريط البحث (بياخد مكان الشريط اللي فوق).
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.count,
    required this.at,
    required this.onChanged,
    required this.onClose,
    required this.onOlder,
    required this.onNewer,
  });

  final TextEditingController controller;
  final int count;
  final int at;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final VoidCallback onOlder;
  final VoidCallback onNewer;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        padding: EdgeInsetsDirectional.only(top: MediaQuery.paddingOf(context).top + 4, bottom: 8, start: 2, end: 6),
        child: Row(
          children: [
            IconButton(tooltip: context.l10n.closeSearch, icon: const BackButtonIcon(), onPressed: onClose),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: context.l10n.searchInChat,
                  filled: false,
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            if (controller.text.trim().isNotEmpty)
              Text(
                count == 0 ? context.l10n.none : '${at + 1}/$count',
                style: TextStyle(color: p.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            IconButton(
              tooltip: context.l10n.older,
              visualDensity: VisualDensity.compact,
              onPressed: at + 1 < count ? onOlder : null,
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
            IconButton(
              tooltip: context.l10n.newer,
              visualDensity: VisualDensity.compact,
              onPressed: at > 0 ? onNewer : null,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ],
        ),
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
        Flexible(
          child: Text(text, style: TextStyle(color: color, fontSize: 14.5)),
        ),
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
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        padding: EdgeInsetsDirectional.only(top: MediaQuery.paddingOf(context).top + 4, bottom: 8, start: 2, end: 2),
        child: Row(
          children: [
            IconButton(
              tooltip: context.l10n.back,
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
                        cartoon: c.cartoon,
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
                                if (c.muted) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.notifications_off_rounded, size: 14, color: p.textMuted),
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
          Expanded(
            child: Text(text, style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.6)),
          ),
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
              group ? context.l10n.startGroupTalk : context.l10n.sayHello,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              '${group ? context.l10n.emptyGroupEnc : context.l10n.emptyDirectEnc}\n'
              '${saved ? context.l10n.emptySaved : context.l10n.emptyNotSaved}',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted, height: 1.7, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}
