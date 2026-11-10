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
///   msg  رسالة نص            del  حذف عند الكل          edit تعديل
///   fs / fc / fe  ملف (بداية / جزء / نهاية بالهاش)       fx  إلغاء ملف
///   join / leave  حد دخل / خرج
class GroupSession extends ChatSession {
  GroupSession({
    required this.groupId,
    required this.groupKey,
    required this.myId,
    required super.myName,
    required this.transmit,
    required this.online,
    required this.chunkSize,
    required this.pacing,
    required super.allowVideo,
    required super.maxFileBytes,
    super.mediaRoot,
  }) : _aad = utf8.encode('wasl/group/v1|$groupId') {
    state = SessionState.ready;
    _stallTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkStalled());
  }

  final String groupId;
  final List<int> groupKey;
  final String myId;

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
    final box = await Box.seal(groupKey, utf8.encode(jsonEncode(packet)), _aad);
    await transmit(base64.encode(box));
  }

  // ---------------- الإرسال ----------------

  @override
  Future<void> send(String raw, {ReplyInfo? reply}) async {
    final text = raw.trim();
    if (text.isEmpty || !canSend) return;
    final clipped =
        text.length > SecureChannel.maxTextLength ? text.substring(0, SecureChannel.maxTextLength) : text;
    final msg = ChatMessage(
      id: newId(),
      text: clipped,
      kind: MessageKind.mine,
      status: MessageStatus.sending,
      reply: reply,
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
      });
      msg.status = MessageStatus.sent;
    } catch (_) {
      msg.status = MessageStatus.failed;
    }
    notifyListeners();
  }

  @override
  void markSeen() {}

  @override
  void userTyping() {}

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

  /// حزمة جروب وصلت من الشبكة.
  void receive(String body) {
    if (_closed || body.length > 400 * 1024) return;
    _inQueue = _inQueue.then((_) => _handle(body)).catchError((Object _) {});
  }

  Future<void> _handle(String body) async {
    final List<int>? clear;
    try {
      clear = await Box.open(groupKey, base64.decode(body), _aad);
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
        );
        messages.add(msg);
        HapticFeedback.lightImpact();
        notifyListeners();
        onIncomingMessage?.call(msg);
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
        );
        _incoming[id] = _GroupIncoming(msg, file, file.openWrite(), total);
        messages.add(msg);
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
    for (final f in _incoming.values) {
      f.sink.close().catchError((Object _) {});
    }
    _incoming.clear();
    super.dispose();
  }
}
