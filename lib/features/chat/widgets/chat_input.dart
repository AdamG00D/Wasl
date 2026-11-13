import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/feedback.dart';
import '../../../widgets/focus_guard.dart';
import '../../../widgets/ui.dart';
import '../core/chat_link.dart';
import '../core/chat_session.dart';
import '../voice/voice.dart';
import 'media_widgets.dart';

enum _RecState { idle, holding, locked }

/// عضو ممكن يتعمله منشن في الجروب.
class MentionCandidate {
  const MentionCandidate({required this.id, required this.name, required this.color, this.avatar, this.cartoon});
  final String id;
  final String name;
  final int color;
  final String? avatar;
  final int? cartoon;
}

/// خانة الكتابة زي الواتساب:
/// [إيموجي | النص | 📎 | 📷]  (🎤 / ➤)
/// • الميكروفون: اضغط واستمر عشان تسجّل، اسحب يمين تلغي، اسحب لفوق تقفل التسجيل.
/// • الإيموجي بيتبدّل مع الكيبورد.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.link,
    required this.enabled,
    this.reply,
    this.replyTitle,
    this.onCancelReply,
    this.mentionCandidates,
  });

  /// في الجروبات: الأعضاء اللي ينفع يتعملهم منشن (اكتب @ عشان يظهروا).
  final List<MentionCandidate> Function()? mentionCandidates;

  final ChatLink link;
  final bool enabled;

  /// الرسالة اللي بنرد عليها (لو فيه).
  final ReplyInfo? reply;

  /// "انت" أو اسم التاني.
  final String? replyTitle;
  final VoidCallback? onCancelReply;

  @override
  State<ChatInputBar> createState() => ChatInputBarState();
}

class ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;
  bool _emoji = false;
  double _keyboardHeight = 280;

  // ---- المنشن ----
  /// اللي اتعملهم منشن في الرسالة اللي بتتكتب: المعرّف ← الاسم.
  final Map<String, String> _mentions = {};
  List<MentionCandidate> _suggestions = const [];
  int _mentionStart = -1;

  // ---- التسجيل ----
  _RecState _rec = _RecState.idle;
  Offset? _downAt;
  Offset _drag = Offset.zero;
  DateTime? _recStart;
  Timer? _recTicker;
  bool _starting = false;

  static const _cancelDistance = 110.0;
  static const _lockDistance = 80.0;

  ChatSession get _session => widget.link.session;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has) _session.userTyping();
      if (has != _hasText) setState(() => _hasText = has);
      _updateSuggestions();
    });
    _focus.addListener(() {
      if (_focus.hasFocus && _emoji) setState(() => _emoji = false);
    });
  }

  @override
  void dispose() {
    _recTicker?.cancel();
    if (_rec != _RecState.idle) VoiceRecorder.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty || !widget.enabled) return;
    _session.send(t, reply: widget.reply, mentions: _mentions.isEmpty ? null : Map.of(_mentions));
    _mentions.clear();
    _ctrl.clear();
    widget.onCancelReply?.call();
  }

  /// بنعرض الأعضاء لما المستخدم يكتب @ وبعدها أول حروف الاسم.
  void _updateSuggestions() {
    final candidates = widget.mentionCandidates;
    if (candidates == null) return;
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset;
    var list = const <MentionCandidate>[];
    var start = -1;
    if (cursor > 0 && cursor <= text.length) {
      final at = text.lastIndexOf('@', cursor - 1);
      if (at >= 0 && (at == 0 || text[at - 1].trim().isEmpty)) {
        final query = text.substring(at + 1, cursor);
        if (!query.contains('\n') && query.length <= 24) {
          list = candidates().where((c) => c.name.contains(query)).take(6).toList();
          start = at;
        }
      }
    }
    if (list.isEmpty && _suggestions.isEmpty) return;
    setState(() {
      _suggestions = list;
      _mentionStart = list.isEmpty ? -1 : start;
    });
  }

  void _pickMention(MentionCandidate c) {
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset.clamp(0, text.length);
    final start = _mentionStart.clamp(0, cursor);
    final insert = '@${c.name} ';
    _mentions[c.id] = c.name;
    _ctrl.value = TextEditingValue(
      text: text.replaceRange(start, cursor, insert),
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
  }

  /// منشن من برا خانة الكتابة (الضغط على عضو في الشات).
  void insertMention(String id, String name) {
    if (!widget.enabled) return;
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset < 0 ? text.length : _ctrl.selection.baseOffset.clamp(0, text.length);
    final space = cursor > 0 && text[cursor - 1].trim().isNotEmpty ? ' ' : '';
    final insert = '$space@$name ';
    _mentions[id] = name;
    _ctrl.value = TextEditingValue(
      text: text.replaceRange(cursor, cursor, insert),
      selection: TextSelection.collapsed(offset: cursor + insert.length),
    );
    _focus.requestFocus();
  }

  void _toggleEmoji() {
    if (_emoji) {
      setState(() => _emoji = false);
      _focus.requestFocus();
    } else {
      hideKeyboard();
      setState(() => _emoji = true);
    }
  }

  // ---------------- التسجيل ----------------

  Future<void> _onMicDown(PointerDownEvent e) async {
    if (!widget.enabled || _rec != _RecState.idle || _starting) return;
    _starting = true;
    _downAt = e.position;
    _drag = Offset.zero;
    final allowed = await VoiceRecorder.ensurePermission();
    if (!allowed) {
      _starting = false;
      if (mounted) {
        showToast(context, context.l10n.micNeededRecord, error: true);
      }
      return;
    }
    // ممكن يكون ساب الزرار وإحنا بنطلب الإذن
    if (_downAt == null) {
      _starting = false;
      return;
    }
    final ok = await VoiceRecorder.start();
    _starting = false;
    if (!mounted) return;
    if (!ok) {
      showToast(context, context.l10n.micStartFailed, error: true);
      return;
    }
    if (_downAt == null) {
      // ساب قبل ما التسجيل يبدأ
      await VoiceRecorder.cancel();
      return;
    }
    setState(() {
      _rec = _RecState.holding;
      _recStart = DateTime.now();
    });
    _recTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onMicMove(PointerMoveEvent e) {
    final down = _downAt;
    if (_rec != _RecState.holding || down == null) return;
    setState(() => _drag = e.position - down);
    // الواجهة عربي: الإلغاء بالسحب ناحية الخانة (يمين)، والقفل لفوق
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final towardCancel = rtl ? _drag.dx : -_drag.dx;
    if (towardCancel > _cancelDistance) {
      HapticFeedback.heavyImpact();
      _cancelRecording();
    } else if (-_drag.dy > _lockDistance) {
      HapticFeedback.mediumImpact();
      setState(() {
        _rec = _RecState.locked;
        _drag = Offset.zero;
      });
    }
  }

  void _onMicUp(PointerEvent _) {
    _downAt = null;
    if (_rec == _RecState.holding) _finishRecording();
  }

  Future<void> _cancelRecording() async {
    _recTicker?.cancel();
    _downAt = null;
    setState(() {
      _rec = _RecState.idle;
      _drag = Offset.zero;
    });
    await VoiceRecorder.cancel();
  }

  Future<void> _finishRecording() async {
    _recTicker?.cancel();
    final started = _recStart;
    setState(() {
      _rec = _RecState.idle;
      _drag = Offset.zero;
    });
    if (started != null &&
        DateTime.now().difference(started) <
            const Duration(milliseconds: 700)) {
      await VoiceRecorder.cancel();
      if (mounted) {
        showToast(context, context.l10n.holdToRecord);
      }
      return;
    }
    final clip = await VoiceRecorder.stop();
    if (clip == null) {
      if (mounted) showToast(context, context.l10n.recordFailed, error: true);
      return;
    }
    final error = await _session.sendMedia(
      clip.file,
      MediaKind.voice,
      durationMs: clip.durationMs,
      waveform: clip.waveform,
      reply: widget.reply,
    );
    if (!mounted) return;
    if (error != null) {
      showToast(context, error, error: true);
    } else {
      widget.onCancelReply?.call();
    }
  }

  String get _elapsed {
    final s = _recStart == null
        ? 0
        : DateTime.now().difference(_recStart!).inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ---------------- الشكل ----------------

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    if (insets > 150 && (insets - _keyboardHeight).abs() > 1) {
      _keyboardHeight = insets;
    }

    final recording = _rec != _RecState.idle;
    final showSend = _hasText || _rec == _RecState.locked;

    return PopScope(
      canPop: !_emoji,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _emoji) setState(() => _emoji = false);
      },
      child: SafeArea(
        top: false,
        bottom: !_emoji,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_suggestions.isNotEmpty && !recording)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final c in _suggestions)
                                    InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => _pickMention(c),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        child: Row(
                                          children: [
                                            Avatar(
                                              name: c.name,
                                              color: c.color,
                                              avatarHash: c.avatar,
                                              cartoon: c.cartoon,
                                              size: 30,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                c.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  Divider(height: 8, color: p.border),
                                ],
                              ),
                            ),
                          if (widget.reply != null && !recording)
                            _ReplyPreview(
                              title: widget.replyTitle ?? '',
                              preview: widget.reply!.preview,
                              onClose: widget.onCancelReply,
                            ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            child: recording ? _recordingRow(p) : _fieldRow(p),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _mainButton(p, showSend),
                ],
              ),
            ),
            if (_emoji)
              SizedBox(
                height: _keyboardHeight,
                child: EmojiPicker(
                  textEditingController: _ctrl,
                  config: Config(
                    height: _keyboardHeight,
                    checkPlatformCompatibility: true,
                    locale: const Locale('en'),
                    viewOrderConfig: const ViewOrderConfig(
                      top: EmojiPickerItem.searchBar,
                      middle: EmojiPickerItem.emojiView,
                      bottom: EmojiPickerItem.categoryBar,
                    ),
                    emojiViewConfig: EmojiViewConfig(
                      columns: 8,
                      emojiSizeMax: 30,
                      backgroundColor: p.surface,
                      noRecents: Text(
                        context.l10n.emojiNoRecents,
                        style: TextStyle(color: p.textMuted, fontSize: 14),
                      ),
                    ),
                    categoryViewConfig: CategoryViewConfig(
                      backgroundColor: p.surface,
                      indicatorColor: p.accent,
                      iconColor: p.textMuted,
                      iconColorSelected: p.accent,
                      backspaceColor: p.accent,
                      dividerColor: p.border,
                    ),
                    bottomActionBarConfig: BottomActionBarConfig(
                      backgroundColor: p.surface,
                      buttonColor: p.surface,
                      buttonIconColor: p.textMuted,
                    ),
                    searchViewConfig: SearchViewConfig(
                      backgroundColor: p.surface,
                      buttonIconColor: p.textMuted,
                      hintText: context.l10n.emojiSearch,
                    ),
                    skinToneConfig: SkinToneConfig(
                      dialogBackgroundColor: p.surfaceAlt,
                      indicatorColor: p.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fieldRow(Palette p) {
    final enabled = widget.enabled;
    return Row(
      key: const ValueKey('field'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          tooltip: _emoji ? context.l10n.keyboard : context.l10n.emoji,
          onPressed: enabled ? _toggleEmoji : null,
          icon: Icon(
            _emoji ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
            color: p.textMuted,
          ),
        ),
        Expanded(
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            enabled: enabled,
            minLines: 1,
            maxLines: 6,
            maxLength: 4000,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            onTap: () {
              if (_emoji) setState(() => _emoji = false);
            },
            style: const TextStyle(fontSize: 16, height: 1.35),
            decoration: InputDecoration(
              hintText: enabled ? context.l10n.messageHint : context.l10n.waitingConnection,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
            ),
          ),
        ),
        Transform.rotate(
          angle: -0.6,
          child: IconButton(
            tooltip: context.l10n.attachments,
            onPressed: enabled
                ? () => showAttachSheet(
                    context,
                    widget.link,
                    reply: widget.reply,
                    onSent: widget.onCancelReply,
                  )
                : null,
            icon: Icon(Icons.attach_file_rounded, color: p.textMuted),
          ),
        ),
        if (!_hasText)
          GestureDetector(
            onLongPress: enabled && widget.link.supportsVideo
                ? () => sendFromCamera(
                    context,
                    widget.link,
                    video: true,
                    reply: widget.reply,
                    onSent: widget.onCancelReply,
                  )
                : null,
            child: IconButton(
              tooltip: widget.link.supportsVideo
                  ? context.l10n.photoHoldVideo
                  : context.l10n.photo,
              onPressed: enabled
                  ? () => sendFromCamera(
                      context,
                      widget.link,
                      reply: widget.reply,
                      onSent: widget.onCancelReply,
                    )
                  : null,
              icon: Icon(Icons.photo_camera_outlined, color: p.textMuted),
            ),
          ),
      ],
    );
  }

  Widget _recordingRow(Palette p) {
    final locked = _rec == _RecState.locked;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final slide = (rtl ? _drag.dx : -_drag.dx).clamp(0.0, _cancelDistance);
    return SizedBox(
      key: const ValueKey('rec'),
      height: 48,
      child: Row(
        children: [
          if (locked)
            IconButton(
              tooltip: context.l10n.delete,
              onPressed: _cancelRecording,
              icon: Icon(Icons.delete_outline_rounded, color: p.danger),
            )
          else
            const SizedBox(width: 14),
          _BlinkingDot(color: p.danger),
          const SizedBox(width: 8),
          Text(
            _elapsed,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: locked
                ? LiveWave(color: p.accent)
                : Opacity(
                    opacity: (1 - slide / _cancelDistance).clamp(0.2, 1.0),
                    child: Transform.translate(
                      offset: Offset(rtl ? slide : -slide, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            rtl
                                ? Icons.chevron_right_rounded
                                : Icons.chevron_left_rounded,
                            color: p.textMuted,
                          ),
                          Text(
                            context.l10n.slideToCancel,
                            style: TextStyle(
                              color: p.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _mainButton(Palette p, bool showSend) {
    final holding = _rec == _RecState.holding;
    final circle = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: holding ? 64 : 50,
      height: holding ? 64 : 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: p.accentGradient,
      ),
      child: Icon(
        showSend ? Icons.send_rounded : Icons.mic_rounded,
        color: p.onAccent,
        size: holding ? 30 : 24,
      ),
    );

    if (showSend) {
      return GestureDetector(
        onTap: _rec == _RecState.locked ? _finishRecording : _send,
        child: Opacity(opacity: widget.enabled ? 1 : 0.45, child: circle),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // مؤشر القفل فوق الميكروفون وانت ماسك
        if (holding)
          Positioned(
            bottom: 74 + (-_drag.dy).clamp(0.0, _lockDistance) * 0.4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: p.border),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: p.textMuted,
                  ),
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 20,
                    color: p.textMuted,
                  ),
                ],
              ),
            ),
          ),
        Listener(
          onPointerDown: _onMicDown,
          onPointerMove: _onMicMove,
          onPointerUp: _onMicUp,
          onPointerCancel: _onMicUp,
          child: Transform.translate(
            offset: holding
                ? Offset(
                    _drag.dx.clamp(-_cancelDistance, _cancelDistance) * 0.5,
                    0,
                  )
                : Offset.zero,
            child: Opacity(opacity: widget.enabled ? 1 : 0.45, child: circle),
          ),
        ),
      ],
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.title,
    required this.preview,
    this.onClose,
  });

  final String title;
  final String preview;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 2, 6),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: BorderDirectional(start: BorderSide(color: p.accent, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, size: 20, color: p.textMuted),
          ),
        ],
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot({required this.color});

  final Color color;

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.25, end: 1.0).animate(_c),
      child: Icon(Icons.mic_rounded, color: widget.color, size: 22),
    );
  }
}
