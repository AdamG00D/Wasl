import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cryptography/dart.dart';
import 'package:flutter/services.dart';

import '../../core/crypto/box.dart';
import '../../core/crypto/kdf.dart';
import '../chat/core/chat_session.dart';
import '../chat/core/secure_channel.dart';

class _GroupIncoming {
  _GroupIncoming(this.message, this.file, this.sink, this.total);
  final ChatMessage message;
  final File file;
  final IOSink sink;
  final int total;
  final hash = const DartSha256().newHashSink();
  int next = 0;
  int received = 0;
  double notified = 0;
  DateTime last = DateTime.now();
}

/// محادثة جروب: نفس واجهة [ChatSession] (فالشاشة والإدخال والفقاعات هي هي)
/// بس الرسايل بتتبث لكل الأعضاء مشفرة بمفتاح الجروب.
///
/// الحزمة (قبل التشفير): {k: النوع, s: معرّف المرسل, n: اسمه, ...}
///   msg  رسالة نص (+ mn منشن، fw محوّلة)   del  حذف عند الكل      edit تعديل
///   fs / fc / fe  ملف (بداية / جزء / نهاية بالهاش)       fx  إلغاء ملف
///   join / leave  حد دخل / خرج
///   typ  بيكتب دلوقتي          rd  قريت الرسايل دي         rx  تفاعل بإيموجي
///
/// المعرّف `s` لازم يساوي مصدر الإطار في الشبكة، واللي اتشال من الجروب رسايله بتترمي.
/// أوامر الإدارة (إزالة عضو، مديرين، حذف رسالة حد تاني) مش هنا: بتتبعت موثّقة لكل عضو
/// لوحده — شوف [GroupOps].
class GroupSession extends ChatSession {
  GroupSession({
    required this.groupId,
    required List<int> groupKey,
    required this.myId,
    required super.myName,
    required this.transmit,
    required this.online,
    required this.chunkSize,
    required this.pacing,
    required super.allowVideo,
    required super.maxFileBytes,
    super.mediaRoot,
    this.isBanned,
    this.audience,
  })  : _key = groupKey,
        _aad = utf8.encode('wasl/group/v1|$groupId') {
    state = SessionState.ready;
    _stallTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkStalled());
  }

  final String groupId;
  final String myId;

  List<int> _key;
  List<int> get groupKey => _key;

  /// مفتاح جديد للجروب (بعد إزالة عضو من جروب بطلب انضمام).
  void updateKey(List<int> key) => _key = key;

  /// العضو ده متشال من الجروب؟ (رسايله بتترمي)
  final bool Function(String id)? isBanned;

  /// عضو بعت حاجة اتفكت بمفتاح الجروب الحالي (يعني معاه المفتاح).
  void Function(String id)? onMemberSeen;

  /// الأعضاء اللي واصلين لهم دلوقتي (عشان نعرف "الكل قرا").
  final Iterable<String> Function()? audience;

  @override
  String get myReactionKey => myId;

  /// رسايل وصلت ولسه مبلّغناش إنها اتقرت.
  final List<String> _unread = [];

  /// اللي بيكتبوا دلوقتي: المعرّف ← (الاسم، مؤقت الإخفاء).
  final Map<String, (String, Timer)> _typers = {};
  DateTime _lastTyping = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  List<String> get typingNames => [for (final t in _typers.values) t.$1];

  /// يبث حزمة مشفرة لأعضاء الجروب.
  final Future<void> Function(String body) transmit;

  /// فيه حد واصلين له دلوقتي؟
  final bool Function() online;

  final int chunkSize;
  final Duration pacing;
  final List<int> _aad;

  final Map<String, _GroupIncoming> _incoming = {};
  final Set<String> _canceledOut = {};
  final Set<String> _sendingOut = {};
  Future<void> _inQueue = Future.value();
  Timer? _stallTimer;
  bool _closed = false;

  @override
  bool get canSend => !_closed && online();

  @override
  int limitFor(MediaKind kind) => math.min(super.limitFor(kind), maxFileBytes);

  @override
  ReplyInfo replyTo(ChatMessage m) => ReplyInfo(
        id: m.id,
        preview: ChatSession.previewOf(m),
        toMine: m.kind == MessageKind.mine,
        author: m.kind == MessageKind.mine ? myName : m.sender,
        authorId: m.kind == MessageKind.mine ? myId : m.senderId,
      );

  Future<void> _emit(Map<String, dynamic> packet) async {
    packet['s'] = myId;
    packet['n'] = myName;
    final box = await Box.seal(_key, utf8.encode(jsonEncode(packet)), _aad);
    await transmit(base64.encode(box));
  }

  // ---------------- الإرسال ----------------

  @override
  Future<void> send(String raw, {ReplyInfo? reply, Map<String, String>? mentions, bool forwarded = false}) async {
    final text = raw.trim();
    if (text.isEmpty || !canSend) return;
    // المنشن اللي اسمه لسه موجود في النص بس
    final mn = <String, String>{
      for (final e in (mentions ?? const <String, String>{}).entries)
        if (text.contains('@${e.value}')) e.key: e.value,
    };
    final clipped =
        text.length > SecureChannel.maxTextLength ? text.substring(0, SecureChannel.maxTextLength) : text;
    final msg = ChatMessage(
      id: newId(),
      text: clipped,
      kind: MessageKind.mine,
      status: MessageStatus.sending,
      reply: reply,
      forwarded: forwarded,
      mentions: mn,
    );
    messages.add(msg);
    notifyListeners();
    try {
      await _emit({
        'k': 'msg',
        'id': msg.id,
        'text': clipped,
        'ts': msg.time.millisecondsSinceEpoch,
        'rp': ?reply?.toWire(),
        if (mn.isNotEmpty) 'mn': mn,
        if (forwarded) 'fw': true,
      });
      msg.status = MessageStatus.sent;
    } catch (_) {
      msg.status = MessageStatus.failed;
    }
    notifyListeners();
  }

  /// الجروب مفتوح قدامي: نبلّغ الأعضاء إني قريت (الملفات بعد ما توصل كاملة).
  @override
  void markSeen() {
    if (_unread.isEmpty || !canSend) return;
    final ids = <String>[];
    _unread.removeWhere((id) {
      final m = findById(id);
      if (m == null) return true;
      final media = m.media;
      if (media != null && !media.ready) return media.failed || media.canceled;
      ids.add(id);
      return true;
    });
    for (var i = 0; i < ids.length; i += 40) {
      final part = ids.sublist(i, math.min(i + 40, ids.length));
      _emit({'k': 'rd', 'ids': part}).catchError((Object _) {
        _unread.insertAll(0, part);
      });
    }
  }

  @override
  void userTyping() {
    if (!canSend) return;
    final now = DateTime.now();
    if (now.difference(_lastTyping) < const Duration(seconds: 3)) return;
    _lastTyping = now;
    _emit({'k': 'typ'}).catchError((Object _) {});
  }

  void _setTyping(String id, String? name) {
    _typers.remove(id)?.$2.cancel();
    if (name != null) {
      _typers[id] = (name, Timer(const Duration(seconds: 5), () => _setTyping(id, null)));
    }
    final typing = _typers.isNotEmpty;
    if (typing != peerTyping || name != null) {
      peerTyping = typing;
      notifyListeners();
    }
  }

  /// ✓✓ رمادي = حد قرا • ✓✓ ملوّن = كل اللي واصلين لهم قروا.
  void _refreshStatus(ChatMessage m) {
    if (m.readBy.isEmpty || m.status == MessageStatus.failed || m.status == MessageStatus.sending) return;
    final all = audience?.call().every(m.readBy.contains) ?? true;
    m.status = all ? MessageStatus.read : MessageStatus.delivered;
  }

  @override
  Future<void> react(ChatMessage m, String? emoji) async {
    if (m.kind == MessageKind.system || !canSend) return;
    final next = emoji == null || m.reactions[myId] == emoji ? null : emoji;
    if (next != null && !ChatSession.validReaction(next)) return;
    if (next == null) {
      m.reactions.remove(myId);
    } else {
      m.reactions[myId] = next;
    }
    notifyListeners();
    try {
      await _emit({'k': 'rx', 'id': m.id, 'e': next ?? '', 'o': m.kind == MessageKind.mine ? myId : m.senderId});
    } catch (_) {}
  }

  /// مدير الجروب حذف رسالة العضو ده عند الكل (الأمر نفسه بيتأكد منه برا).
  void removeByModerator(String messageId, String senderId) {
    for (final m in messages.toList()) {
      if (m.id != messageId) continue;
      final owner = m.kind == MessageKind.mine ? myId : m.senderId;
      if (owner != senderId) continue;
      if (m.kind == MessageKind.mine) _canceledOut.add(m.id);
      if (_incoming.containsKey(m.id)) {
        _abortIncoming(m.id, remove: true);
      } else {
        _remove(m);
      }
      return;
    }
  }

  @override
  bool canEdit(ChatMessage m) =>
      m.kind == MessageKind.mine && m.media == null && m.status != MessageStatus.failed && canSend;

  @override
  Future<void> edit(ChatMessage m, String raw) async {
    final text = raw.trim();
    if (!canEdit(m) || text.isEmpty || text == m.text) return;
    final clipped =
        text.length > SecureChannel.maxTextLength ? text.substring(0, SecureChannel.maxTextLength) : text;
    m.text = clipped;
    m.edited = true;
    notifyListeners();
    try {
      await _emit({'k': 'edit', 'id': m.id, 'text': clipped});
    } catch (_) {}
  }

  @override
  Future<void> deleteForEveryone(ChatMessage m) async {
    if (m.kind != MessageKind.mine) return;
    _canceledOut.add(m.id);
    _remove(m);
    try {
      await _emit({'k': 'del', 'id': m.id});
    } catch (_) {}
  }

  @override
  Future<void> deleteForMe(ChatMessage m) async {
    if (m.transferring) {
      await cancelTransfer(m);
    } else {
      _remove(m);
    }
  }

  @override
  Future<void> cancelTransfer(ChatMessage m) async {
    if (m.kind == MessageKind.mine) {
      _canceledOut.add(m.id);
      _remove(m);
      try {
        await _emit({'k': 'fx', 'id': m.id});
      } catch (_) {}
    } else {
      await _abortIncoming(m.id, remove: true);
    }
  }

  void _remove(ChatMessage m) {
    messages.remove(m);
    _unread.remove(m.id);
    final path = m.media?.path;
    if (m.kind == MessageKind.theirs && path != null) ChatSession.deleteQuietly(File(path));
    notifyListeners();
  }

  @override
  Future<String?> sendMedia(
    File file,
    MediaKind kind, {
    String? name,
    ReplyInfo? reply,
    int? durationMs,
    List<int>? waveform,
    bool forwarded = false,
  }) async {
    if (!canSend) return 'مفيش حد من الجروب واصلين له دلوقتي';
    if (kind == MediaKind.video && !allowVideo) return 'الفيديو متاح في الواي فاي بس';
    final int size;
    try {
      size = await file.length();
    } catch (_) {
      return 'معرفناش نقرا الملف';
    }
    if (size == 0) return 'الملف فاضي';
    if (kind == MediaKind.video && await ChatSession.sniffKind(file) == MediaKind.image) {
      return 'الملف ده مش فيديو سليم — اختاره تاني من المعرض';
    }
    final limit = limitFor(kind);
    if (size > limit) return 'أقصى حجم في الجروبات ${ChatSession.mb(limit)}';

    final cleanName = name == null ? null : ChatSession.cleanFileName(name);
    final media = ChatMedia(
      kind: kind,
      size: size,
      path: file.path,
      name: cleanName,
      durationMs: durationMs,
      waveform: waveform,
    );
    final msg = ChatMessage(
      id: newId(),
      text: '',
      kind: MessageKind.mine,
      status: MessageStatus.sending,
      media: media,
      reply: reply,
      forwarded: forwarded,
    );
    messages.add(msg);
    notifyListeners();
    unawaited(_runOutgoing(msg, file, ChatSession.safeExt(cleanName ?? file.path, kind)));
    return null;
  }

  Future<void> _runOutgoing(ChatMessage msg, File file, String ext) async {
    final media = msg.media!;
    final total = math.max(1, (media.size + chunkSize - 1) ~/ chunkSize);
    final hash = const DartSha256().newHashSink();
    RandomAccessFile? raf;
    _sendingOut.add(msg.id);
    try {
      raf = await file.open();
      await _emit({
        'k': 'fs',
        'id': msg.id,
        'mk': media.kind.name,
        'size': media.size,
        'ext': ext,
        'name': ?media.name,
        'cs': chunkSize,
        'cn': total,
        'ts': msg.time.millisecondsSinceEpoch,
        'dur': ?media.durationMs,
        'wave': ?media.waveform,
        'rp': ?msg.reply?.toWire(),
        if (msg.forwarded) 'fw': true,
      });
      for (var i = 0; i < total; i++) {
        if (_canceledOut.contains(msg.id) || _closed) return;
        final bytes = await raf.read(math.min(chunkSize, media.size - i * chunkSize));
        if (bytes.isEmpty) throw StateError('short read');
        hash.add(bytes);
        await _emit({'k': 'fc', 'id': msg.id, 'i': i, 'd': base64.encode(bytes)});
        final progress = (i + 1) / total;
        if (progress - media.progress >= 0.01 || i + 1 == total) {
          media.progress = progress;
          notifyListeners();
        }
        if (pacing > Duration.zero) await Future<void>.delayed(pacing);
      }
      hash.close();
      await _emit({'k': 'fe', 'id': msg.id, 'sha': Kdf.hex((await hash.hash()).bytes)});
      media.progress = 1;
      msg.status = MessageStatus.sent;
    } catch (_) {
      if (!_canceledOut.contains(msg.id)) {
        media.failed = true;
        media.failReason = online() ? 'معرفناش نبعت الملف' : 'الاتصال وقف قبل ما يكمل';
        msg.status = MessageStatus.failed;
        _emit({'k': 'fx', 'id': msg.id}).catchError((Object _) {});
      }
    } finally {
      await raf?.close();
      _sendingOut.remove(msg.id);
      _canceledOut.remove(msg.id);
      notifyListeners();
    }
  }

  /// إشعار للأعضاء: دخلت / خرجت.
  Future<void> announce(String what) async {
    try {
      await _emit({'k': what});
    } catch (_) {}
  }

  // ---------------- الاستقبال ----------------

  /// حزمة جروب وصلت من الشبكة ([src] = الجهاز اللي بعتها أصلاً).
  void receive(String src, String body) {
    if (_closed || body.length > 400 * 1024) return;
    _inQueue = _inQueue.then((_) => _handle(src, body)).catchError((Object _) {});
  }

  Future<void> _handle(String src, String body) async {
    final List<int>? clear;
    try {
      clear = await Box.open(_key, base64.decode(body), _aad);
    } catch (_) {
      return;
    }
    if (clear == null || _closed) return;
    final Map<String, dynamic> p;
    try {
      p = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final sender = '${p['s'] ?? ''}';
    if (sender.isEmpty || sender.length > 32 || sender == myId) return;
    // محدش يبعت باسم حد تاني، واللي اتشال من الجروب مبنسمعلوش
    if (sender != src || (isBanned?.call(sender) ?? false)) return;
    onMemberSeen?.call(sender);
    var name = '${p['n'] ?? ''}'.replaceAll(RegExp(r'[\u0000-\u001f]'), '').trim();
    if (name.isEmpty) name = 'مجهول';
    if (name.length > 24) name = name.substring(0, 24);
    final id = '${p['id'] ?? ''}';

    ChatMessage? theirs() {
      for (final m in messages.reversed) {
        if (m.id == id && m.kind == MessageKind.theirs && m.senderId == sender) return m;
      }
      return null;
    }

    switch (p['k']) {
      case 'msg':
        final text = '${p['text'] ?? ''}';
        if (id.isEmpty || id.length > 80 || text.isEmpty || text.length > SecureChannel.maxTextLength) return;
        if (findById(id) != null) return;
        final msg = ChatMessage(
          id: id,
          text: text,
          kind: MessageKind.theirs,
          sender: name,
          senderId: sender,
          reply: ReplyInfo.fromGroupWire(p['rp'], myId),
          forwarded: p['fw'] == true,
          mentions: cleanMentions(p['mn']),
        );
        msg.mentionsMe = msg.mentions.containsKey(myId);
        messages.add(msg);
        _unread.add(id);
        _setTyping(sender, null);
        HapticFeedback.lightImpact();
        notifyListeners();
        onIncomingMessage?.call(msg);
      case 'typ':
        _setTyping(sender, name);
      case 'rd':
        var changed = false;
        for (final raw in (p['ids'] as List? ?? const []).take(64)) {
          final m = findById('$raw');
          if (m == null || m.kind != MessageKind.mine) continue;
          if (m.readBy.length < 256 && m.readBy.add(sender)) changed = true;
          _refreshStatus(m);
        }
        if (changed) notifyListeners();
      case 'rx':
        final owner = '${p['o'] ?? ''}';
        final e = '${p['e'] ?? ''}';
        ChatMessage? target;
        for (final m in messages.reversed) {
          if (m.id != id) continue;
          if (owner == myId ? m.kind == MessageKind.mine : m.senderId == owner) target = m;
          break;
        }
        if (target == null) return;
        if (e.isEmpty) {
          target.reactions.remove(sender);
        } else if (ChatSession.validReaction(e) && target.reactions.length < 64) {
          target.reactions[sender] = e;
          if (target.kind == MessageKind.mine) onReaction?.call(target, e, name);
        }
        notifyListeners();
      case 'edit':
        final m = theirs();
        final text = '${p['text'] ?? ''}';
        if (m == null || m.media != null || text.isEmpty || text.length > SecureChannel.maxTextLength) return;
        m.text = text;
        m.edited = true;
        notifyListeners();
      case 'del' || 'fx':
        final m = theirs();
        if (m == null) return;
        if (_incoming.containsKey(id)) {
          await _abortIncoming(id, remove: true);
        } else {
          _remove(m);
        }
      case 'join':
        addSystem('$name دخل الجروب');
      case 'leave':
        _setTyping(sender, null);
        addSystem('$name خرج من الجروب');
      case 'fs':
        if (id.isEmpty || id.length > 80 || findById(id) != null) return;
        final kind = MediaKind.values.where((k) => k.name == p['mk']).firstOrNull ?? MediaKind.file;
        if (kind == MediaKind.video && !allowVideo) return;
        final size = (p['size'] as num?)?.toInt() ?? 0;
        final cs = (p['cs'] as num?)?.toInt() ?? 0;
        final total = (p['cn'] as num?)?.toInt() ?? 0;
        if (size <= 0 || size > limitFor(kind) || cs < 1024 || cs > 1024 * 1024) return;
        if (total != (size + cs - 1) ~/ cs) return;
        final rawName = p['name'] as String?;
        final dur = (p['dur'] as num?)?.toInt();
        final wave = (p['wave'] as List?)?.whereType<num>().take(80).map((v) => v.toInt().clamp(0, 31)).toList();
        final dir = await mediaDirectory();
        final file = File('${dir.path}/${Kdf.hex(Kdf.randomBytes(8))}.${ChatSession.safeExt('x.${p['ext'] ?? ''}', kind)}');
        final msg = ChatMessage(
          id: id,
          text: '',
          kind: MessageKind.theirs,
          sender: name,
          senderId: sender,
          media: ChatMedia(
            kind: kind,
            size: size,
            name: rawName == null ? null : ChatSession.cleanFileName(rawName),
            durationMs: dur == null || dur < 0 || dur > 24 * 3600 * 1000 ? null : dur,
            waveform: wave,
          ),
          reply: ReplyInfo.fromGroupWire(p['rp'], myId),
          forwarded: p['fw'] == true,
        );
        _incoming[id] = _GroupIncoming(msg, file, file.openWrite(), total);
        messages.add(msg);
        _unread.add(id);
        _setTyping(sender, null);
        HapticFeedback.lightImpact();
        notifyListeners();
        onIncomingMessage?.call(msg);
      case 'fc':
        final f = _incoming[id];
        if (f == null || f.message.senderId != sender) return;
        final i = (p['i'] as num?)?.toInt() ?? -1;
        if (i < f.next) return;
        final bytes = base64.decode('${p['d']}');
        final media = f.message.media!;
        if (i != f.next || f.received + bytes.length > media.size) {
          await _abortIncoming(id, reason: 'وصل ناقص');
          return;
        }
        f.sink.add(bytes);
        f.hash.add(bytes);
        f.received += bytes.length;
        f.next++;
        f.last = DateTime.now();
        media.progress = f.received / media.size;
        if (media.progress - f.notified >= 0.01) {
          f.notified = media.progress;
          notifyListeners();
        }
      case 'fe':
        final f = _incoming[id];
        if (f == null || f.message.senderId != sender) return;
        final media = f.message.media!;
        if (f.received != media.size || f.next != f.total) {
          await _abortIncoming(id, reason: 'وصل ناقص');
          return;
        }
        _incoming.remove(id);
        await f.sink.flush();
        await f.sink.close();
        f.hash.close();
        if (Kdf.hex((await f.hash.hash()).bytes) != '${p['sha']}') {
          media.failed = true;
          media.failReason = 'وصل مختلف عن الأصلي';
          await ChatSession.deleteQuietly(f.file);
        } else {
          media.path = await ChatSession.fixVideoExtension(f.file, media.kind);
          media.progress = 1;
        }
        notifyListeners();
        if (viewing) markSeen();
    }
  }

  Future<void> _abortIncoming(String id, {bool remove = false, String? reason}) async {
    final f = _incoming.remove(id);
    if (f != null) {
      f.message.media!.failed = true;
      f.message.media!.failReason = reason;
      try {
        await f.sink.close();
      } catch (_) {}
      await ChatSession.deleteQuietly(f.file);
      if (remove) messages.remove(f.message);
    }
    notifyListeners();
  }

  /// ملف وقف يوصل (اللي بيبعته بعد أو قفل).
  void _checkStalled() {
    final now = DateTime.now();
    for (final e in _incoming.entries.toList()) {
      if (now.difference(e.value.last) > const Duration(seconds: 40)) {
        _abortIncoming(e.key, reason: 'الإرسال وقف قبل ما يكمل');
      }
    }
  }

  @override
  void abortTransfers() {
    for (final id in _incoming.keys.toList()) {
      _abortIncoming(id, reason: 'الاتصال وقف قبل ما يكمل');
    }
  }

  @override
  void dispose() {
    _closed = true;
    _stallTimer?.cancel();
    for (final t in _typers.values) {
      t.$2.cancel();
    }
    _typers.clear();
    for (final f in _incoming.values) {
      f.sink.close().catchError((Object _) {});
    }
    _incoming.clear();
    super.dispose();
  }
}
