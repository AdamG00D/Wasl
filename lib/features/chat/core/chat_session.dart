import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/crypto/kdf.dart';
import 'frame_transport.dart';
import 'secure_channel.dart';

enum MessageKind { mine, theirs, system }

/// sending ← sent ← delivered (✓✓) ← read (✓✓ ملونين).
enum MessageStatus { sending, sent, delivered, read, failed }

enum MediaKind { image, video, file, voice }

/// رد على رسالة (اقتباس صغير فوق الرسالة زي الواتساب).
class ReplyInfo {
  const ReplyInfo({required this.id, required this.preview, required this.toMine, this.author, this.authorId});

  /// في الجروبات: اسم صاحب الرسالة الأصلية ومعرّفه.
  final String? author;
  final String? authorId;

  /// رقم الرسالة الأصلية.
  final String id;

  /// نص قصير منها (أو "📷 صورة"...).
  final String preview;

  /// الرسالة الأصلية بتاعتي أنا (من ناحية الجهاز ده).
  final bool toMine;

  /// للإرسال: 'by' من ناحية اللي بيبعت.
  Map<String, dynamic> toWire() => {
        'id': id,
        'pv': preview,
        'by': toMine ? 'me' : 'you',
        'bn': ?author,
        'bi': ?authorId,
      };

  Map<String, dynamic> toJson() => {'id': id, 'pv': preview, 'mine': toMine, 'au': ?author, 'ai': ?authorId};

  static ReplyInfo? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return ReplyInfo(
      id: '${raw['id']}',
      preview: '${raw['pv'] ?? ''}',
      toMine: raw['mine'] == true,
      author: raw['au'] as String?,
      authorId: raw['ai'] as String?,
    );
  }

  /// رد وصل في جروب: "بتاعتي" = صاحب الرسالة الأصلية هو أنا.
  static ReplyInfo? fromGroupWire(Object? raw, String myId) {
    if (raw is! Map) return null;
    final id = '${raw['id'] ?? ''}';
    final pv = '${raw['pv'] ?? ''}';
    if (id.isEmpty || id.length > 80) return null;
    final bn = raw['bn'], bi = raw['bi'];
    return ReplyInfo(
      id: id,
      preview: pv.length > 160 ? pv.substring(0, 160) : pv,
      toMine: bi == myId,
      author: bn is String && bn.length <= 40 ? bn : null,
      authorId: bi is String && bi.length <= 32 ? bi : null,
    );
  }

  static ReplyInfo? fromWire(Object? raw) {
    if (raw is! Map) return null;
    final id = '${raw['id'] ?? ''}';
    final pv = '${raw['pv'] ?? ''}';
    if (id.isEmpty || id.length > 80) return null;
    // 'me' عند اللي بعت = رسالته هو = مش بتاعتي أنا
    return ReplyInfo(id: id, preview: pv.length > 160 ? pv.substring(0, 160) : pv, toMine: raw['by'] == 'you');
  }
}

/// صورة أو فيديو أو ملف داخل رسالة.
class ChatMedia {
  ChatMedia({
    required this.kind,
    required this.size,
    this.path,
    this.name,
    this.progress = 0,
    this.durationMs,
    this.waveform,
  });

  /// مدة الرسالة الصوتية.
  final int? durationMs;

  /// شكل الموجة للرسالة الصوتية (قيم 0..31).
  final List<int>? waveform;

  final MediaKind kind;
  final int size;

  /// اسم الملف الأصلي (للملفات).
  final String? name;

  /// مسار الملف على الجهاز (null = لسه بيتستلم).
  String? path;

  /// نسبة اللي وصل فعلاً للطرف التاني / اللي استلمناه (0..1).
  double progress;
  bool failed = false;

  /// سبب الفشل بالظبط (بيظهر للمستخدم).
  String? failReason;

  /// الإرسال/الاستلام اتلغى.
  bool canceled = false;

  /// الاتصال وقف والنقل مستني يرجع (هيكمّل من مكانه).
  bool paused = false;

  bool get ready => path != null && !failed && !canceled;

  Map<String, dynamic> toJson() => {
        'k': kind.name,
        'size': size,
        'name': ?name,
        'path': ?path,
        'dur': ?durationMs,
        'wave': ?waveform,
        if (failed) 'failed': true,
        if (canceled) 'canceled': true,
      };

  static ChatMedia fromJson(Map<dynamic, dynamic> j) {
    final m = ChatMedia(
      kind: MediaKind.values.where((k) => k.name == j['k']).firstOrNull ?? MediaKind.file,
      size: (j['size'] as num?)?.toInt() ?? 0,
      name: j['name'] as String?,
      path: j['path'] as String?,
      durationMs: (j['dur'] as num?)?.toInt(),
      waveform: (j['wave'] as List?)?.whereType<num>().map((v) => v.toInt()).toList(),
      progress: 1,
    );
    m.canceled = j['canceled'] == true;
    // ملف مكملش قبل ما التطبيق يتقفل
    m.failed = j['failed'] == true || (m.path == null && !m.canceled);
    if (m.failed) m.failReason ??= 'مكملش';
    return m;
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.text,
    required this.kind,
    DateTime? time,
    this.status = MessageStatus.sent,
    this.media,
    this.reply,
    this.sender,
    this.senderId,
  }) : time = time ?? DateTime.now();

  /// في الجروبات: اسم اللي بعت الرسالة ومعرّفه.
  final String? sender;
  final String? senderId;

  /// الرسالة دي رد على رسالة تانية.
  final ReplyInfo? reply;

  final String id;
  String text;
  final MessageKind kind;
  final DateTime time;
  MessageStatus status;
  final ChatMedia? media;

  /// الرسالة اتعدلت بعد ما اتبعتت.
  bool edited = false;

  /// النقل لسه شغال (إرسال أو استلام).
  bool get transferring {
    final m = media;
    if (m == null || m.failed || m.canceled) return false;
    return kind == MessageKind.mine ? status == MessageStatus.sending : m.path == null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        't': text,
        'k': kind.index,
        'ts': time.millisecondsSinceEpoch,
        'st': status.index,
        if (edited) 'e': true,
        's': ?sender,
        'si': ?senderId,
        'rp': ?reply?.toJson(),
        'm': ?media?.toJson(),
      };

  static ChatMessage? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final kind = MessageKind.values[(raw['k'] as num).toInt()];
      var status = MessageStatus.values[(raw['st'] as num).toInt()];
      final media = raw['m'] is Map ? ChatMedia.fromJson(raw['m'] as Map) : null;
      if (status == MessageStatus.sending) {
        status = MessageStatus.failed;
        if (media != null && kind == MessageKind.mine) {
          media.failed = true;
          media.failReason = 'مكملش';
        }
      }
      return ChatMessage(
        id: '${raw['id']}',
        text: '${raw['t'] ?? ''}',
        kind: kind,
        time: DateTime.fromMillisecondsSinceEpoch((raw['ts'] as num).toInt()),
        status: status,
        media: media,
        reply: ReplyInfo.fromJson(raw['rp']),
        sender: raw['s'] as String?,
        senderId: raw['si'] as String?,
      )..edited = raw['e'] == true;
    } catch (_) {
      return null;
    }
  }
}

/// ملف بيتبعت: بيكمّل من مكانه لو الاتصال وقف ورجع.
class _OutgoingFile {
  _OutgoingFile(this.message, this.file, this.ext, this.chunkSize, this.window);

  final ChatMessage message;
  final File file;
  final String ext;
  final int chunkSize;

  /// أقصى عدد أجزاء "في الطريق" من غير تأكيد (عشان الذاكرة متتملاش عند المستلم).
  final int window;

  int get total => math.max(1, (message.media!.size + chunkSize - 1) ~/ chunkSize);
  int get ackEvery => math.max(1, window ~/ 4);

  int next = 0; // الجزء الجاي اللي هيتبعت
  int acked = 0; // اللي المستلم أكد إنه وصله
  bool canceled = false;
  bool done = false;
  SecureChannel? announcedOn;
  bool awaitingResume = false;
  int? resumeFrom;
  int? resendFrom;
  Completer<void>? _wake;

  void wake() {
    final w = _wake;
    _wake = null;
    if (w != null && !w.isCompleted) w.complete();
  }

  Future<void> sleep(Duration max) {
    final w = _wake ??= Completer<void>();
    return w.future.timeout(max, onTimeout: () {});
  }
}

/// ملف بيتستلم.
class _IncomingFile {
  _IncomingFile(this.message, this.file, this.sink, this.chunkSize, this.total, this.ackEvery);

  final ChatMessage message;
  final File file;
  final IOSink sink;
  final int chunkSize;
  final int total;
  final int ackEvery;
  final hash = const DartSha256().newHashSink();
  int received = 0;
  int next = 0;
  double notified = 0;
}

enum SessionState {
  /// لم يتصل بعد.
  idle,

  /// متصل وجاري تبادل المفاتيح.
  securing,

  /// قناة مشفرة جاهزة.
  ready,

  /// انقطع الاتصال (قد يعود).
  disconnected,

  /// انتهت المحادثة.
  ended,
}

/// المحادثة: الرسائل + حالة التشفير + نقل الملفات.
/// تبقى حية عبر إعادة الاتصال (الرسايل والملفات اللي بتتنقل بتكمّل).
class ChatSession extends ChangeNotifier {
  ChatSession({
    required this.myName,
    this.allowVideo = true,
    this.maxFileBytes = 1024 * 1024 * 1024,
    Directory? mediaRoot,
    this.identity,
    this.myStaticKey,
    this.expectedPeerKey,
    this.peerName,
    this.keepMedia = false,
    this.heartbeatEvery = const Duration(seconds: 5),
    this.lostAfter = const Duration(seconds: 15),
  }) : _mediaRoot = mediaRoot;

  /// مفتاح الهوية الثابت بتاعي (من البروفايل).
  final SimpleKeyPair? identity;
  final List<int>? myStaticKey;

  /// مفتاح هوية الشخص اللي المحادثة دي معاه.
  final List<int>? expectedPeerKey;

  /// المحادثة محفوظة: الملفات المستلمة متتمسحش مع قفل الجلسة.
  bool keepMedia;

  /// فولدر ثابت لملفات المحادثة (لو محفوظة) — بيتغير مع تفعيل/إلغاء الحفظ.
  Directory? fixedMediaDir;

  String myName;

  /// الفيديو مسموح؟ (البلوتوث: صور وملفات بس).
  final bool allowVideo;

  /// أقصى حجم للفيديو أو الملف (الواي فاي أكبر بكتير من البلوتوث).
  final int maxFileBytes;

  final Duration heartbeatEvery;
  final Duration lostAfter;

  static const int maxImageBytes = 25 * 1024 * 1024;

  /// الملفات بتستنى الاتصال يرجع المدة دي قبل ما تفشل.
  static const Duration transferResumeWindow = Duration(seconds: 90);

  final Directory? _mediaRoot;
  Directory? _mediaDir;


  final Map<String, _IncomingFile> _incomingFiles = {};
  final Map<String, _OutgoingFile> _outgoing = {};
  final Set<String> _completedIncoming = {};
  Future<void> _fileQueue = Future.value();
  Timer? _transferTimeout;

  /// إشارات المكالمات (offer/answer/ice...) من الطرف التاني.
  void Function(Map<String, dynamic> signal)? onCallSignal;

  final List<ChatMessage> messages = [];
  SessionState state = SessionState.idle;
  String? peerName;
  String? safetyCode;
  String? _peerKey;
  /// المفتاح اللي رمز الأمان اتأكد معاه (بيتحفظ مع المحادثة).
  String? verifiedPeerKey;

  /// يُستدعى عند انقطاع القناة (ليقرر المتحكم إعادة الاتصال).
  void Function(String reason)? onChannelClosed;

  /// تأكيد إضافي إن مفتاح هوية الطرف التاني هو المتوقع (لو مكناش عارفينه قبل الاتصال).
  Future<bool> Function(String peerKey)? verifyPeer;

  /// الاسم بييجي من الشبكة (البروفايل) مش من المصافحة.
  bool nameFromNetwork = false;

  /// يُستدعى مع كل رسالة واردة (للإشعارات).
  void Function(ChatMessage message)? onIncomingMessage;

  /// الطرف التاني بيكتب دلوقتي.
  bool peerTyping = false;
  Timer? _typingTimer;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);

  /// رسايل وصلت ولسه مبعتناش إنها اتقرت.
  final List<String> _unseen = [];

  /// "اتقرت" وصلت لملف لسه بيكمّل (بنطبّقها أول ما يوصل).
  final Set<String> _earlyRead = {};

  /// شاشة الدردشة ظاهرة والتطبيق قدام (عشان الملفات اللي بتكمّل وصول تتعلّم "اتقرت").
  bool viewing = false;

  SecureChannel? _channel;
  StreamSubscription<ChannelPacket>? _packetSub;
  bool _disposed = false;
  int _counter = 0;

  /// رمز الأمان اتأكد (اختياري).
  bool get verified => _peerKey != null && _peerKey == verifiedPeerKey;
  bool get canSend => state == SessionState.ready;
  bool get everConnected => _everReady;
  bool _everReady = false;

  /// ربط وسيلة نقل جديدة (اتصال أول أو إعادة اتصال).
  Future<void> attach(FrameTransport transport) async {
    await _dropChannel();
    if (_disposed) {
      await transport.close();
      return;
    }
    // مفتاح مؤقت جديد لكل اتصال
    final (keyPair, publicKey) = await SecureChannel.newIdentity();
    if (_disposed) {
      await transport.close();
      return;
    }
    final channel = SecureChannel(
      transport: transport,
      identity: keyPair,
      myPublicKey: publicKey,
      staticIdentity: identity!,
      myStaticKey: myStaticKey!,
      expectedPeerKey: expectedPeerKey,
      myName: myName,
      heartbeatEvery: heartbeatEvery,
      lostAfter: lostAfter,
    );
    _channel = channel;
    _setState(SessionState.securing);

    unawaited(channel.closed.then((reason) {
      if (_channel != channel) return; // قناة قديمة
      _channel = null;
      _packetSub?.cancel();
      _typingTimer?.cancel();
      peerTyping = false;
      for (final m in messages) {
        if (m.status == MessageStatus.sending && m.media == null) m.status = MessageStatus.failed;
      }
      if (state != SessionState.ended) {
        _setState(SessionState.disconnected);
        _pauseTransfers();
        onChannelClosed?.call(reason);
      }
    }));

    _packetSub = channel.packets.listen(_onPacket);

    try {
      await channel.start();
    } catch (_) {
      // أول إطار مخرجش أصلاً (الطريق للشخص وقع): منستناش مهلة المصافحة
      if (_channel == channel) {
        await _dropChannel();
        _setState(SessionState.disconnected);
        onChannelClosed?.call('lost');
      }
      return;
    }
    try {
      final ready = await channel.ready;
      if (_channel != channel || _disposed) return;
      final check = verifyPeer;
      if (check != null && !await check(ready.peerKey)) {
        // المفتاح ده مش بتاع الشخص اللي المحادثة معاه
        if (_channel == channel) {
          await _dropChannel();
          _setState(SessionState.disconnected);
          onChannelClosed?.call('protocol');
        }
        return;
      }
      if (_channel != channel || _disposed) return;
      if (!nameFromNetwork) peerName = ready.peerName;
      safetyCode = ready.safetyCode;
      _peerKey = ready.peerKey;
      _everReady = true;
      _setState(SessionState.ready);
      if (messages.isEmpty) addSystem('المحادثة مشفرة من طرف لطرف 🔒');
      _resumeTransfers();
    } catch (_) {
      // فشل المصافحة: سيُبلّغ عبر closed
    }
  }

  /// المستخدم أكّد أن رمز الأمان متطابق على الجهازين.
  void confirmSafetyCode() {
    if (_peerKey == null) return;
    verifiedPeerKey = _peerKey;
    addSystem('تم التحقق من رمز الأمان ✓');
    notifyListeners();
  }

  /// نص قصير يوصف الرسالة (للرد عليها).
  static String previewOf(ChatMessage m) {
    final media = m.media;
    if (media == null) {
      final t = m.text.replaceAll('\n', ' ');
      return t.length > 100 ? '${t.substring(0, 100)}…' : t;
    }
    return switch (media.kind) {
      MediaKind.image => '📷 صورة',
      MediaKind.video => '🎥 فيديو',
      MediaKind.voice => '🎤 رسالة صوتية${media.durationMs == null ? '' : ' (${formatDuration(media.durationMs!)})'}',
      MediaKind.file => '📄 ${media.name ?? 'ملف'}',
    };
  }

  static String formatDuration(int ms) {
    final s = (ms / 1000).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  ReplyInfo replyTo(ChatMessage m) =>
      ReplyInfo(id: m.id, preview: previewOf(m), toMine: m.kind == MessageKind.mine);

  ChatMessage? findById(String id) {
    for (final m in messages.reversed) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<void> send(String raw, {ReplyInfo? reply}) async {
    final text = raw.trim();
    final channel = _channel;
    if (text.isEmpty || channel == null || !canSend) return;
    final clipped = text.length > SecureChannel.maxTextLength
        ? text.substring(0, SecureChannel.maxTextLength)
        : text;
    final msg = ChatMessage(
      id: _newId(),
      text: clipped,
      kind: MessageKind.mine,
      status: MessageStatus.sending,
      reply: reply,
    );
    messages.add(msg);
    notifyListeners();
    try {
      await channel.sendMessage(msg.id, clipped, reply: reply?.toWire());
      if (msg.status == MessageStatus.sending) msg.status = MessageStatus.sent;
    } catch (_) {
      msg.status = MessageStatus.failed;
    }
    notifyListeners();
  }

  // ---------------- قرأ / حذف / تعديل ----------------

  /// شاشة الدردشة ظاهرة: نبلّغ الطرف التاني إن رسايله اتقرت.
  ///
  /// الصور والفيديو والفويس والملفات بتتعلّم "اتقرت" بس بعد ما توصل كاملة
  /// (قبل كده الطرف التاني لسه بيبعت ومش هيقبلها، فكانت بتضيع).
  void markSeen() {
    final channel = _channel;
    if (_unseen.isEmpty || channel == null || !canSend) return;
    final ids = <String>[];
    _unseen.removeWhere((id) {
      final m = findById(id);
      if (m == null) return true;
      final media = m.media;
      if (media != null && !media.ready) {
        // لسه بيوصل: نسيبه للمرة الجاية — إلا لو فشل أو اتلغى
        return media.failed || media.canceled;
      }
      ids.add(id);
      return true;
    });
    if (ids.isEmpty) return;
    channel.sendPacket('read', {'ids': ids}).catchError((_) {
      _unseen.insertAll(0, ids); // نحاول تاني المرة الجاية
    });
  }

  /// حذف رسالة عندي وعند الطرف التاني.
  Future<void> deleteForEveryone(ChatMessage m) async {
    if (m.kind != MessageKind.mine) return;
    _cancelOutgoing(m.id, notify: false);
    _removeLocal(m);
    try {
      await _channel?.sendPacket('del', {'id': m.id});
    } catch (_) {}
  }

  /// حذف رسالة من عندي بس.
  Future<void> deleteForMe(ChatMessage m) async {
    if (m.transferring) await cancelTransfer(m);
    _removeLocal(m);
  }

  /// يقدر يعدّل رسالته لو نص ووصلت.
  bool canEdit(ChatMessage m) =>
      m.kind == MessageKind.mine && m.media == null && m.status != MessageStatus.failed && canSend;

  Future<void> edit(ChatMessage m, String raw) async {
    final text = raw.trim();
    if (!canEdit(m) || text.isEmpty || text == m.text) return;
    final clipped = text.length > SecureChannel.maxTextLength ? text.substring(0, SecureChannel.maxTextLength) : text;
    m.text = clipped;
    m.edited = true;
    notifyListeners();
    try {
      await _channel?.sendPacket('edit', {'id': m.id, 'text': clipped});
    } catch (_) {}
  }

  /// إلغاء إرسال أو استلام ملف.
  /// • لو أنا اللي ببعت: الرسالة بتختفي عندي وعنده.
  /// • لو أنا اللي بستلم: بتختفي عندي، وعنده بتظهر إن الاستلام اتلغى.
  Future<void> cancelTransfer(ChatMessage m) async {
    if (m.kind == MessageKind.mine) {
      _cancelOutgoing(m.id, notify: false);
      _removeLocal(m);
    } else {
      await _abortFile(m.id, remove: true);
    }
    try {
      await _channel?.sendPacket('file-cancel', {'id': m.id});
    } catch (_) {}
  }

  void _removeLocal(ChatMessage m) {
    messages.remove(m);
    _unseen.remove(m.id);
    final path = m.media?.path;
    // ملفات الطرف التاني بس (ملفاتي الأصلية في المعرض متتمسحش)
    if (m.kind == MessageKind.theirs && path != null) _deleteQuietly(File(path));
    notifyListeners();
  }

  // ---------------- الصور والفيديو والملفات ----------------

  int limitFor(MediaKind kind) => kind == MediaKind.image || kind == MediaKind.voice ? maxImageBytes : maxFileBytes;

  /// نوع الملف من محتواه نفسه (مش من اسمه): image / video / null.
  static Future<MediaKind?> sniffKind(File file) async {
    List<int> h;
    try {
      final raf = await file.open();
      h = await raf.read(16);
      await raf.close();
    } catch (_) {
      return null;
    }
    bool at(int i, List<int> sig) {
      if (h.length < i + sig.length) return false;
      for (var k = 0; k < sig.length; k++) {
        if (h[i + k] != sig[k]) return false;
      }
      return true;
    }

    if (at(0, [0xFF, 0xD8, 0xFF]) || at(0, [0x89, 0x50, 0x4E, 0x47]) || at(0, [0x47, 0x49, 0x46, 0x38])) {
      return MediaKind.image;
    }
    if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) return MediaKind.image; // WEBP
    if (at(4, [0x66, 0x74, 0x79, 0x70])) {
      // ftyp: نفس الغلاف للفيديو (mp4/mov/3gp) والصور (HEIC/AVIF)
      final brand = String.fromCharCodes(h.sublist(8, 12));
      const imageBrands = {'heic', 'heix', 'hevc', 'heim', 'heis', 'mif1', 'msf1', 'avif', 'avis'};
      return imageBrands.contains(brand) ? MediaKind.image : MediaKind.video;
    }
    if (at(0, [0x1A, 0x45, 0xDF, 0xA3])) return MediaKind.video; // mkv/webm
    if (at(0, [0x00, 0x00, 0x01, 0xBA])) return MediaKind.video; // mpeg
    return null;
  }

  /// يبعت صورة أو فيديو أو ملف (مشفر من طرف لطرف، متقسم لأجزاء).
  /// يرجّع رسالة خطأ للمستخدم أو null لو بدأ.
  Future<String?> sendMedia(
    File file,
    MediaKind kind, {
    String? name,
    ReplyInfo? reply,
    int? durationMs,
    List<int>? waveform,
  }) async {
    final channel = _channel;
    if (channel == null || !canSend) return 'مش متصل دلوقتي';
    if (kind == MediaKind.video && !allowVideo) {
      return 'الفيديو متاح في دردشة الواي فاي بس';
    }
    final int size;
    try {
      size = await file.length();
    } catch (_) {
      return 'معرفناش نقرا الملف';
    }
    final limit = limitFor(kind);
    if (size == 0) return 'الملف فاضي';
    if (kind == MediaKind.video && await sniffKind(file) == MediaKind.image) {
      // حماية: منبعتش صورة على إنها فيديو (التاني مش هيعرف يشغّلها)
      return 'الملف ده مش فيديو سليم — اختاره تاني من المعرض';
    }
    if (size > limit) return 'الملف أكبر من ${_mb(limit)}';

    final cleanName = name == null ? null : _cleanFileName(name);
    final media = ChatMedia(
      kind: kind,
      size: size,
      path: file.path,
      name: cleanName,
      durationMs: durationMs,
      waveform: waveform,
    );
    final msg = ChatMessage(
      id: _newId(),
      text: '',
      kind: MessageKind.mine,
      status: MessageStatus.sending,
      media: media,
      reply: reply,
    );
    messages.add(msg);
    notifyListeners();

    final chunk = chunkSizeFor(channel.transport.maxFrame);
    // حوالي 4 ميجا في الطريق بالكتير
    final window = (4 * 1024 * 1024 ~/ chunk).clamp(8, 64);
    final o = _OutgoingFile(msg, file, _safeExt(cleanName ?? file.path, kind), chunk, window);
    _outgoing[msg.id] = o;
    unawaited(_runOutgoing(o));
    return null;
  }

  static String _mb(int bytes) => bytes >= 1024 * 1024 * 1024
      ? '${bytes ~/ (1024 * 1024 * 1024)} جيجا'
      : '${bytes ~/ (1024 * 1024)} ميجا';

  Future<void> _runOutgoing(_OutgoingFile o) async {
    final msg = o.message;
    final media = msg.media!;
    final hash = const DartSha256().newHashSink();
    var hashed = 0;
    var everAnnounced = false;
    RandomAccessFile? raf;
    SecureChannel? endSentOn;
    String? sha;

    // لو الاتصال وقع وإحنا بنبعت، ده مش فشل: بنستنى يرجع ونكمّل من مكاننا
    Future<bool> trySend(SecureChannel ch, String kind, Map<String, dynamic> data) async {
      try {
        await ch.sendPacket(kind, data);
        return true;
      } catch (_) {
        await o.sleep(const Duration(seconds: 1));
        return false;
      }
    }

    try {
      raf = await o.file.open();
      while (!o.canceled && !_disposed) {
        final ch = _channel;
        if (ch == null || !canSend) {
          await o.sleep(const Duration(seconds: 2));
          continue;
        }
        // قناة جديدة (أول مرة أو بعد ما الاتصال رجع): نعلن عن الملف ونعرف وصل لفين
        if (o.announcedOn != ch) {
          final resume = everAnnounced;
          endSentOn = null;
          o.awaitingResume = resume;
          o.resumeFrom = null;
          final sent = await trySend(ch, 'file-start', {
            'id': msg.id,
            'mk': media.kind.name,
            'size': media.size,
            'ext': o.ext,
            if (media.name != null) 'name': media.name,
            'cs': o.chunkSize,
            'n': o.total,
            'ae': o.ackEvery,
            if (media.durationMs != null) 'dur': media.durationMs,
            if (media.waveform != null) 'wave': media.waveform,
            if (msg.reply != null) 'rp': msg.reply!.toWire(),
          });
          if (!sent) continue;
          o.announcedOn = ch;
          everAnnounced = true;
          if (resume) {
            final until = DateTime.now().add(const Duration(seconds: 15));
            while (o.resumeFrom == null && !o.canceled && _channel == ch && DateTime.now().isBefore(until)) {
              await o.sleep(const Duration(seconds: 1));
            }
            o.awaitingResume = false;
            final from = o.resumeFrom;
            if (from == null) {
              o.announcedOn = null; // نعلن تاني
              continue;
            }
            o.next = from.clamp(0, o.total);
            o.acked = o.next;
          }
          media.paused = false;
          notifyListeners();
        }
        if (o.done) break;
        if (o.resendFrom != null) {
          // المستلم ناقصه أجزاء: نكمّل من عنده
          o.next = o.resendFrom!.clamp(0, o.total);
          o.acked = o.next;
          o.resendFrom = null;
          endSentOn = null;
        }
        if (o.next >= o.total) {
          if (endSentOn != ch) {
            sha ??= Kdf.hex((await _finishHash(hash, hashed, o.total)).bytes);
            if (!await trySend(ch, 'file-end', {'id': msg.id, 'n': o.total, 'sha': sha})) continue;
            endSentOn = ch;
          }
          await o.sleep(const Duration(seconds: 2)); // مستنيين التأكيد النهائي
          continue;
        }
        // التحكم في السرعة: منبعتش أكتر من [window] جزء من غير تأكيد
        if (o.next - o.acked >= o.window) {
          await o.sleep(const Duration(seconds: 2));
          continue;
        }
        final i = o.next;
        await raf.setPosition(i * o.chunkSize);
        final bytes = await raf.read(math.min(o.chunkSize, media.size - i * o.chunkSize));
        if (bytes.isEmpty) throw StateError('short read');
        if (i == hashed) {
          hash.add(bytes);
          hashed++;
        }
        if (await trySend(ch, 'file-chunk', {'id': msg.id, 'i': i, 'd': base64.encode(bytes)})) {
          if (o.next == i) o.next = i + 1;
        }
      }
    } catch (_) {
      // مشكلة في قراية الملف نفسه
      if (!o.canceled && !o.done) {
        media.failed = true;
        media.failReason ??= 'معرفناش نقرا الملف من الموبايل';
        msg.status = MessageStatus.failed;
      }
    } finally {
      await raf?.close();
      _outgoing.remove(msg.id);
      notifyListeners();
    }
  }

  static Future<Hash> _finishHash(HashSink sink, int hashed, int total) async {
    if (hashed != total) throw StateError('hash incomplete');
    sink.close();
    return sink.hash();
  }

  void _onFileAck(ChannelPacket p) {
    final o = _outgoing[p.data['id']];
    if (o == null) return;
    final got = (p.data['got'] as num?)?.toInt() ?? 0;
    if (o.awaitingResume && o.resumeFrom == null) o.resumeFrom = got;
    if (p.data['need'] == true && got < o.total) o.resendFrom = got;
    if (got > o.acked) o.acked = math.min(got, o.total);
    final media = o.message.media!;
    final progress = o.acked / o.total;
    if (progress - media.progress >= 0.01 || progress >= 1) {
      media.progress = progress;
      notifyListeners();
    }
    o.wake();
  }

  void _cancelOutgoing(String id, {bool notify = true, bool failed = false, String? reason}) {
    final o = _outgoing.remove(id);
    if (o == null) return;
    o.canceled = true;
    if (failed) {
      o.message.media!.failed = true;
      o.message.media!.failReason = reason;
      o.message.status = MessageStatus.failed;
    }
    o.wake();
    if (notify) notifyListeners();
  }

  /// الاتصال وقف: الملفات بتستنى ترجع لمدة [transferResumeWindow].
  void _pauseTransfers() {
    var any = false;
    for (final o in _outgoing.values) {
      o.message.media!.paused = true;
      any = true;
    }
    for (final f in _incomingFiles.values) {
      f.message.media!.paused = true;
      any = true;
    }
    if (!any) return;
    _transferTimeout?.cancel();
    _transferTimeout = Timer(transferResumeWindow, () {
      if (!canSend) abortTransfers();
    });
    notifyListeners();
  }

  void _resumeTransfers() {
    _transferTimeout?.cancel();
    for (final o in _outgoing.values) {
      o.wake();
    }
    for (final f in _incomingFiles.values) {
      f.message.media!.paused = false;
    }
    markSeen();
  }

  /// الاتصال خلص نهائياً: أي ملف لسه بيتنقل يفشل.
  void abortTransfers() {
    _transferTimeout?.cancel();
    for (final id in _outgoing.keys.toList()) {
      _cancelOutgoing(id, failed: true, notify: false, reason: 'الاتصال وقف قبل ما يكمل');
    }
    for (final id in _incomingFiles.keys.toList()) {
      _abortFile(id, reason: 'الاتصال وقف قبل ما يكمل');
    }
    notifyListeners();
  }

  /// حجم الجزء الخام بحيث الإطار المشفر (Base64 مرتين) يفضل تحت الحد.
  static int chunkSizeFor(int maxFrame) => math.max(4096, (((maxFrame - 64) * 3 ~/ 4) - 256) * 3 ~/ 4);

  static String safeExt(String path, MediaKind kind) => _safeExt(path, kind);
  static String cleanFileName(String name) => _cleanFileName(name);
  static Future<String> fixVideoExtension(File file, MediaKind kind) => _fixVideoExtension(file, kind);
  static Future<void> deleteQuietly(FileSystemEntity e) => _deleteQuietly(e);
  static String mb(int bytes) => _mb(bytes);

  static String _safeExt(String path, MediaKind kind) {
    final dot = path.lastIndexOf('.');
    final ext = dot == -1 ? '' : path.substring(dot + 1).toLowerCase();
    if (RegExp(r'^[a-z0-9]{1,6}$').hasMatch(ext)) return ext;
    return switch (kind) {
      MediaKind.video => 'mp4',
      MediaKind.image => 'jpg',
      MediaKind.voice => 'm4a',
      MediaKind.file => 'bin',
    };
  }

  static String _cleanFileName(String name) {
    var n = name.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'[\u0000-\u001f<>:"|?*]'), '').trim();
    if (n.isEmpty) n = 'ملف';
    return n.length > 80 ? n.substring(n.length - 80) : n;
  }

  /// فولدر ملفات المحادثة: الثابت لو محفوظة، وإلا فولدر مؤقت بيتمسح.
  Future<Directory> mediaDirectory() async {
    final fixed = fixedMediaDir;
    if (fixed != null) {
      await fixed.create(recursive: true);
      return fixed;
    }
    final existing = _mediaDir;
    if (existing != null) return existing;
    final root = _mediaRoot ?? await getTemporaryDirectory();
    final dir = Directory('${root.path}/wasl_chat_${Kdf.hex(Kdf.randomBytes(6))}');
    await dir.create(recursive: true);
    return _mediaDir = dir;
  }

  void _onFilePacket(ChannelPacket p) {
    _fileQueue = _fileQueue.then((_) => _handleFilePacket(p)).catchError((_) {});
  }

  Future<void> _ackFile(String id, int got) async {
    try {
      await _channel?.sendPacket('file-ack', {'id': id, 'got': got});
    } catch (_) {}
  }

  Future<void> _handleFilePacket(ChannelPacket p) async {
    final d = p.data;
    final id = '${d['id']}';
    if (id.isEmpty || id.length > 80) return;
    switch (p.kind) {
      case 'file-start':
        // ملف وصل كامل قبل كده (الاتصال وقع قبل ما التأكيد يوصل)
        if (_completedIncoming.contains(id)) {
          final n = (d['n'] as num?)?.toInt() ?? 0;
          await _ackFile(id, n);
          _channel?.sendAck(id).catchError((_) {});
          return;
        }
        final existing = _incomingFiles[id];
        if (existing != null) {
          // استكمال بعد ما الاتصال رجع
          existing.message.media!.paused = false;
          notifyListeners();
          await _ackFile(id, existing.next);
          return;
        }
        final kind = MediaKind.values.where((k) => k.name == d['mk']).firstOrNull ?? MediaKind.file;
        if (kind == MediaKind.video && !allowVideo) return;
        final size = (d['size'] as num?)?.toInt() ?? 0;
        final cs = (d['cs'] as num?)?.toInt() ?? 0;
        final total = (d['n'] as num?)?.toInt() ?? 0;
        final ackEvery = ((d['ae'] as num?)?.toInt() ?? 1).clamp(1, 1024);
        if (size <= 0 || size > limitFor(kind) || cs < 1024 || cs > 1024 * 1024) return;
        if (total != (size + cs - 1) ~/ cs) return;
        final rawName = d['name'] as String?;
        final name = rawName == null ? null : _cleanFileName(rawName);
        final ext = _safeExt('x.${d['ext'] ?? ''}', kind);
        final dir = await mediaDirectory();
        final file = File('${dir.path}/${Kdf.hex(Kdf.randomBytes(8))}.$ext');
        final dur = (d['dur'] as num?)?.toInt();
        final wave = (d['wave'] as List?)
            ?.whereType<num>()
            .take(80)
            .map((v) => v.toInt().clamp(0, 31))
            .toList();
        final msg = ChatMessage(
          id: id,
          text: '',
          kind: MessageKind.theirs,
          media: ChatMedia(
            kind: kind,
            size: size,
            name: name,
            durationMs: dur == null || dur < 0 || dur > 24 * 3600 * 1000 ? null : dur,
            waveform: wave,
          ),
          reply: ReplyInfo.fromWire(d['rp']),
        );
        _incomingFiles[id] = _IncomingFile(msg, file, file.openWrite(), cs, total, ackEvery);
        messages.add(msg);
        _unseen.add(id);
        _typingTimer?.cancel();
        peerTyping = false;
        HapticFeedback.lightImpact();
        notifyListeners();
        onIncomingMessage?.call(msg);
        await _ackFile(id, 0);
      case 'file-chunk':
        final f = _incomingFiles[id];
        if (f == null) return;
        final i = (d['i'] as num?)?.toInt() ?? -1;
        if (i < f.next) return; // جزء مكرر بعد الاستكمال
        final bytes = base64.decode('${d['d']}');
        final media = f.message.media!;
        if (i != f.next || f.received + bytes.length > media.size) {
          await _abortFile(id, reason: 'وصل ناقص');
          _channel?.sendPacket('file-cancel', {'id': id, 'why': 'corrupt'}).catchError((_) {});
          return;
        }
        f.sink.add(bytes);
        f.hash.add(bytes);
        f.received += bytes.length;
        f.next++;
        media.progress = f.received / media.size;
        if (f.next % f.ackEvery == 0) await _ackFile(id, f.next);
        if (media.progress - f.notified >= 0.01) {
          f.notified = media.progress;
          notifyListeners();
        }
      case 'file-end':
        final f = _incomingFiles[id];
        if (f == null) {
          if (_completedIncoming.contains(id)) _channel?.sendAck(id).catchError((_) {});
          return;
        }
        final media = f.message.media!;
        if (f.received != media.size || f.next != f.total) {
          // ناقص أجزاء: نطلب نكمّل من عندنا
          try {
            await _channel?.sendPacket('file-ack', {'id': id, 'got': f.next, 'need': true});
          } catch (_) {}
          return;
        }
        _incomingFiles.remove(id);
        await f.sink.flush();
        await f.sink.close();
        f.hash.close();
        final sha = Kdf.hex((await f.hash.hash()).bytes);
        if (sha != '${d['sha']}') {
          // الملف وصل بس مختلف عن الأصلي — منعرضوش
          media.failed = true;
          media.failReason = 'وصل مختلف عن الأصلي';
          await _deleteQuietly(f.file);
          _channel?.sendPacket('file-cancel', {'id': id, 'why': 'corrupt'}).catchError((_) {});
        } else {
          media.path = await _fixVideoExtension(f.file, media.kind);
          media.progress = 1;
          _completedIncoming.add(id);
          await _ackFile(id, f.total);
          _channel?.sendAck(id).catchError((_) {});
          // وصل كامل والشاشة مفتوحة: يتعلّم "اتقرت" على طول
          if (viewing) markSeen();
        }
        notifyListeners();
      case 'file-cancel':
        if (_outgoing.containsKey(id)) {
          // المستلم لغى الاستلام أو الملف وصله بايظ
          _cancelOutgoing(
            id,
            failed: true,
            reason: d['why'] == 'corrupt' ? 'وصل بايظ عند التاني — ابعته تاني' : 'التاني لغى الاستلام',
          );
        } else {
          // الطرف التاني لغى الإرسال: الرسالة بتختفي
          await _abortFile(id, remove: true);
        }
    }
  }

  /// الفيديو بيتحفظ بامتداد نوعه الحقيقي (من محتوى الملف نفسه) عشان المشغّل يعرفه.
  static Future<String> _fixVideoExtension(File file, MediaKind kind) async {
    if (kind != MediaKind.video) return file.path;
    try {
      final raf = await file.open();
      final head = await raf.read(12);
      await raf.close();
      String? ext;
      if (head.length >= 12 && String.fromCharCodes(head.sublist(4, 8)) == 'ftyp') {
        ext = String.fromCharCodes(head.sublist(8, 12)) == 'qt  ' ? 'mov' : 'mp4';
      } else if (head.length >= 4 && head[0] == 0x1A && head[1] == 0x45 && head[2] == 0xDF && head[3] == 0xA3) {
        ext = 'mkv';
      } else if (head.length >= 4 && head[0] == 0x00 && head[1] == 0x00 && head[2] == 0x01 && head[3] == 0xBA) {
        ext = 'mpg';
      }
      if (ext == null || file.path.endsWith('.$ext')) return file.path;
      final dot = file.path.lastIndexOf('.');
      final renamed = await file.rename('${dot == -1 ? file.path : file.path.substring(0, dot)}.$ext');
      return renamed.path;
    } catch (_) {
      return file.path;
    }
  }

  Future<void> _abortFile(String id, {bool remove = false, String? reason}) async {
    final f = _incomingFiles.remove(id);
    if (f != null) {
      f.message.media!.failed = true;
      f.message.media!.failReason = reason;
      try {
        await f.sink.close();
      } catch (_) {}
      await _deleteQuietly(f.file);
    }
    if (remove) {
      final m = messages.where((m) => m.id == id && m.kind == MessageKind.theirs).firstOrNull;
      if (m != null) _removeLocal(m);
    }
    notifyListeners();
  }

  static Future<void> _deleteQuietly(FileSystemEntity e) async {
    try {
      await e.delete(recursive: true);
    } catch (_) {}
  }

  /// مسح كل الصور والفيديوهات والملفات المستلمة من الجهاز.
  Future<void> _wipeMedia() async {
    abortTransfers();
    final dir = _mediaDir;
    _mediaDir = null;
    if (dir != null && !keepMedia) await _deleteQuietly(dir);
  }

  /// الفولدر المؤقت الحالي (لو فيه) — عشان ننقل ملفاته لما المحادثة تتحفظ.
  Directory? get tempMediaDir => _mediaDir;

  // ---------------- المكالمات ----------------

  /// إشارة مكالمة مشفرة للطرف التاني.
  Future<void> sendCallSignal(Map<String, dynamic> signal) async {
    final channel = _channel;
    if (channel == null || !canSend) throw StateError('not connected');
    await channel.sendPacket('call', signal);
  }

  void addSystem(String text) {
    messages.add(ChatMessage(id: _newId(), text: text, kind: MessageKind.system));
    notifyListeners();
  }

  void clearMessages() {
    // الملفات اللي لسه بتتنقل بتفضل
    for (final m in messages) {
      final path = m.media?.path;
      if (!m.transferring && m.kind == MessageKind.theirs && path != null) _deleteQuietly(File(path));
    }
    messages.removeWhere((m) => !m.transferring);
    _unseen.clear();
    notifyListeners();
  }

  /// قطع الاتصال الحالي من غير ما المحادثة تخلص (الرسايل بتفضل، والملفات بتستنى).
  Future<void> detach({bool sayBye = true}) async {
    if (_channel == null) return;
    await _dropChannel(sayBye: sayBye);
    _typingTimer?.cancel();
    peerTyping = false;
    for (final m in messages) {
      if (m.status == MessageStatus.sending && m.media == null) m.status = MessageStatus.failed;
    }
    if (state != SessionState.ended) {
      _setState(SessionState.disconnected);
      _pauseTransfers();
    }
  }

  /// إنهاء المحادثة نهائياً.
  Future<void> end() async {
    if (state == SessionState.ended) return;
    _setState(SessionState.ended);
    await _dropChannel(sayBye: true);
    await _wipeMedia();
  }

  /// يُستدعى مع كل تغيير في خانة الكتابة (بنبعت "بيكتب" كل 2.5 ثانية بالكتير).
  void userTyping() {
    final channel = _channel;
    if (channel == null || !canSend) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingSent) < const Duration(milliseconds: 2500)) return;
    _lastTypingSent = now;
    channel.sendTyping().catchError((_) {});
  }

  void _setPeerTyping(bool typing) {
    _typingTimer?.cancel();
    if (typing) _typingTimer = Timer(const Duration(seconds: 4), () => _setPeerTyping(false));
    if (peerTyping == typing) return;
    peerTyping = typing;
    notifyListeners();
  }

  ChatMessage? _find(String? id, MessageKind kind) {
    if (id == null) return null;
    for (final m in messages.reversed) {
      if (m.id == id && m.kind == kind) return m;
    }
    return null;
  }

  void _onPacket(ChannelPacket p) {
    switch (p.kind) {
      case 'typing':
        _setPeerTyping(true);
      case 'msg':
        final id = p.id ?? _newId();
        if (_find(id, MessageKind.theirs) != null) return;
        final msg = ChatMessage(
          id: id,
          text: p.text ?? '',
          kind: MessageKind.theirs,
          reply: ReplyInfo.fromWire(p.data['rp']),
        );
        messages.add(msg);
        _unseen.add(id);
        _typingTimer?.cancel();
        peerTyping = false;
        HapticFeedback.lightImpact();
        notifyListeners();
        onIncomingMessage?.call(msg);
        _channel?.sendAck(id).catchError((_) {});
      case 'file-start' || 'file-chunk' || 'file-end' || 'file-cancel':
        _onFilePacket(p);
      case 'file-ack':
        _onFileAck(p);
      case 'call':
        onCallSignal?.call(Map<String, dynamic>.from(p.data)..remove('k')..remove('seq'));
      case 'ack':
        final m = _find(p.id, MessageKind.mine);
        if (m == null) return;
        if (m.status != MessageStatus.read) {
          m.status = _earlyRead.remove(m.id) ? MessageStatus.read : MessageStatus.delivered;
        }
        final o = _outgoing[m.id];
        if (o != null) {
          // آخر تأكيد للملف: وصل كامل وسليم
          o.done = true;
          m.media!.progress = 1;
          o.wake();
        }
        notifyListeners();
      case 'read':
        final ids = (p.data['ids'] as List?)?.map((e) => '$e').toSet() ?? const <String>{};
        var changed = false;
        for (final m in messages) {
          if (m.kind == MessageKind.mine && ids.contains(m.id) && m.status != MessageStatus.failed) {
            if (m.transferring) {
              _earlyRead.add(m.id); // هتتطبق مع آخر تأكيد للملف
              continue;
            }
            m.status = MessageStatus.read;
            changed = true;
          }
        }
        if (changed) notifyListeners();
      case 'del':
        final m = _find(p.data['id'] as String?, MessageKind.theirs);
        if (m == null) return;
        if (_incomingFiles.containsKey(m.id)) {
          _abortFile(m.id, remove: true);
        } else {
          _removeLocal(m);
        }
      case 'edit':
        final m = _find(p.data['id'] as String?, MessageKind.theirs);
        final text = '${p.data['text'] ?? ''}';
        if (m == null || m.media != null || text.isEmpty || text.length > SecureChannel.maxTextLength) return;
        m.text = text;
        m.edited = true;
        notifyListeners();
    }
  }

  Future<void> _dropChannel({bool sayBye = false}) async {
    final c = _channel;
    _channel = null;
    await _packetSub?.cancel();
    _packetSub = null;
    if (c != null) await c.close(sayBye: sayBye);
  }

  String newId() => _newId();

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_counter++}-${Kdf.hex(Kdf.randomBytes(3))}';

  @protected
  void setState(SessionState s) => _setState(s);

  void _setState(SessionState s) {
    if (state == s) return;
    state = s;
    if (!_disposed) notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _typingTimer?.cancel();
    _transferTimeout?.cancel();
    for (final o in _outgoing.values) {
      o.canceled = true;
      o.wake();
    }
    _dropChannel(sayBye: true);
    _wipeMedia();
    super.dispose();
  }
}
