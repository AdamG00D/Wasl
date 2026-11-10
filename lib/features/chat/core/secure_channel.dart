import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';

import '../../../core/crypto/kdf.dart';
import 'frame_transport.dart';

/// رسالة داخل القناة المشفرة.
class ChannelPacket {
  ChannelPacket(this.kind, {this.id, this.text, this.time, this.data = const {}});

  /// msg | ack | typing | read | del | edit | file-* | call
  final String kind;
  final String? id;
  final String? text;
  final DateTime? time;

  /// بيانات الحزمة كاملة.
  final Map<String, dynamic> data;
}

class ChannelReady {
  ChannelReady({required this.peerName, required this.peerKey, required this.safetyCode});

  final String peerName;

  /// مفتاح الهوية الثابت للطرف الآخر (Base64) — بيعرّفه وبنتذكر بيه التحقق.
  final String peerKey;

  /// رمز الأمان (6 أرقام، اختياري) — نفس الرقم على الجهازين.
  final String safetyCode;
}

/// قناة مشفرة من طرف لطرف فوق أي [FrameTransport].
///
/// البروتوكول (Wasl v1):
///   1) كل طرف يرسل hello: {name, مفتاح X25519 مؤقت للجلسة, مفتاح الهوية الثابت, nonce}.
///   2) سرّين X25519 (مؤقت×مؤقت + هوية×هوية) → HKDF-SHA256 (salt = هاش المصافحة)
///      → مفتاح لكل اتجاه + مفتاح تأكيد لكل طرف.
///      • المؤقت: لو مفتاح الهوية اتسرق بعدين، الرسايل القديمة متتفكش.
///      • الهوية: محدش يقدر ينتحل شخصية حد (ولا يقعد في النص) من غير مفتاحه الخاص.
///   3) كل طرف يبعت HMAC يثبت إنه وصل لنفس المفاتيح (يعني معاه مفتاح هويته فعلاً).
///   4) الرسائل: AES-256-GCM + عدّاد متزايد ضد إعادة الإرسال.
///   5) نبضة كل 5 ثواني: لو مفيش أي حاجة وصلت 15 ثانية يبقى الاتصال وقع ('lost').
///   6) رمز الأمان (اختياري) = 6 أرقام من هاش مفتاحي الهوية — ثابت لنفس الشخصين.
class SecureChannel {
  SecureChannel({
    required this.transport,
    required this.identity,
    required this.myPublicKey,
    required this.staticIdentity,
    required this.myStaticKey,
    required this.myName,
    this.expectedPeerKey,
    this.handshakeTimeout = const Duration(seconds: 20),
    this.heartbeatEvery = const Duration(seconds: 5),
    this.lostAfter = const Duration(seconds: 15),
  });

  static const int protocolVersion = 1;
  static const int maxTextLength = 4000;

  /// الحزم الأكبر من كده بتتشفر في خيط منفصل عشان الشاشة متهنّجش.
  static const int _isolateThreshold = 24 * 1024;

  final FrameTransport transport;
  /// مفتاح مؤقت للجلسة دي بس.
  final SimpleKeyPair identity;
  final List<int> myPublicKey;

  /// مفتاح الهوية الثابت (من البروفايل).
  final SimpleKeyPair staticIdentity;
  final List<int> myStaticKey;
  final String myName;

  /// مفتاح الهوية المتوقع للطرف التاني (لو عارفينه): أي حد تاني بيترفض.
  final List<int>? expectedPeerKey;
  final Duration handshakeTimeout;
  final Duration heartbeatEvery;
  final Duration lostAfter;

  final List<int> _myNonce = Kdf.randomBytes(16);

  Uint8List? _sendKey;
  Uint8List? _recvKey;
  List<int>? _peerConfirmKey;
  List<int>? _transcript;
  ChannelReady? _pendingReady;
  bool _confirmed = false;
  int _sendSeq = 0;
  int _recvSeq = 0;
  bool _helloReceived = false;
  bool _closed = false;

  StreamSubscription<String>? _sub;
  Timer? _timeout;
  Timer? _heartbeat;
  DateTime _lastRx = DateTime.now();
  DateTime _lastTx = DateTime.now();

  // معالجة الإطارات والإرسال بالترتيب (العدّاد يعتمد على الترتيب)
  Future<void> _inQueue = Future.value();
  Future<void> _outQueue = Future.value();
  int _inPending = 0;

  final _ready = Completer<ChannelReady>();
  final _packets = StreamController<ChannelPacket>.broadcast();
  final _closedReason = Completer<String>();

  /// يكتمل عند نجاح المصافحة.
  Future<ChannelReady> get ready => _ready.future;

  Stream<ChannelPacket> get packets => _packets.stream;

  /// سبب الإغلاق ('remote' | 'lost' | 'bye' | 'timeout' | 'protocol' | 'local').
  Future<String> get closed => _closedReason.future;

  bool get isReady => _confirmed;
  bool get isClosed => _closed;

  /// عدد الإطارات اللي وصلت ولسه بتتفك (للتحكم في سرعة الإرسال).
  int get backlog => _inPending;

  Future<void> start() async {
    // لو اتقفلت قبل ما حد يستنى ready، الخطأ ميبقاش "غير معالَج"
    _ready.future.ignore();
    _sub = transport.frames.listen(
      (f) {
        _lastRx = DateTime.now();
        _inPending++;
        _inQueue = _inQueue.then((_) => _onFrame(f)).catchError((_) {}).whenComplete(() => _inPending--);
      },
      // بعد معالجة كل الإطارات المستلمة (عشان سبب الإغلاق يبقى صح)
      onDone: () => _inQueue = _inQueue.then((_) => _close('remote')),
      onError: (_) => _inQueue = _inQueue.then((_) => _close('remote')),
    );
    _timeout = Timer(handshakeTimeout, () {
      if (!isReady) _close('timeout');
    });
    await _sendRaw({
      't': 'hello',
      'v': protocolVersion,
      'name': myName,
      'pub': base64.encode(myPublicKey),
      'id': base64.encode(myStaticKey),
      'n': base64.encode(_myNonce),
    });
  }

  Future<void> sendMessage(String id, String text, {Map<String, dynamic>? reply}) => _sendEncrypted({
        'k': 'msg',
        'id': id,
        'text': text,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'rp': ?reply,
      });

  Future<void> sendAck(String id) => _sendEncrypted({'k': 'ack', 'id': id});

  Future<void> sendTyping() => _sendEncrypted({'k': 'typing'});

  /// أنواع الحزم المسموحة عبر [sendPacket].
  static const _extraKinds = {
    'read', // الرسايل اتقرت
    'del', // حذف رسالة عند الكل
    'edit', // تعديل رسالة
    'file-start',
    'file-chunk',
    'file-end',
    'file-ack', // المستلم وصله لحد فين (تحكم في السرعة + استكمال)
    'file-cancel',
    'call',
  };

  /// حزمة مشفرة عامة.
  Future<void> sendPacket(String kind, Map<String, dynamic> data) {
    assert(_extraKinds.contains(kind));
    return _sendEncrypted({...data, 'k': kind});
  }

  Future<void> close({bool sayBye = true}) async {
    if (_closed) return;
    if (sayBye && isReady) {
      try {
        await _sendEncrypted({'k': 'bye'}).timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    await _close('local');
  }

  // ---------------- داخلي ----------------

  Future<void> _onFrame(String frame) async {
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(frame) as Map<String, dynamic>;
    } catch (_) {
      return; // إطار غير مفهوم — تجاهل
    }
    switch (map['t']) {
      case 'hello':
        await _onHello(map);
      case 'confirm':
        await _onConfirm(map);
      case 'e':
        await _onEncrypted(map);
    }
  }

  Future<void> _onHello(Map<String, dynamic> m) async {
    if (_helloReceived) return;
    _helloReceived = true;
    try {
      if (m['v'] != protocolVersion) {
        await _close('protocol');
        return;
      }
      final peerPub = base64.decode(m['pub'] as String);
      final peerNonce = base64.decode(m['n'] as String);
      final peerName = _cleanName('${m['name'] ?? ''}');
      final peerId = base64.decode(m['id'] as String);
      if (peerPub.length != 32 || peerNonce.length != 16 || peerId.length != 32) {
        await _close('protocol');
        return;
      }
      final expected = expectedPeerKey;
      if (expected != null && !Kdf.constantTimeEquals(expected, peerId)) {
        await _close('protocol'); // مش الشخص اللي المفروض نكلمه
        return;
      }

      final order = _compare(myStaticKey, peerId);
      if (order == 0 || _compare(myPublicKey, peerPub) == 0) {
        await _close('protocol'); // انعكاس لنفس المفتاح
        return;
      }
      final iAmA = order < 0;
      final pubA = iAmA ? myPublicKey : peerPub;
      final pubB = iAmA ? peerPub : myPublicKey;
      final idA = iAmA ? myStaticKey : peerId;
      final idB = iAmA ? peerId : myStaticKey;
      final nonceA = iAmA ? _myNonce : peerNonce;
      final nonceB = iAmA ? peerNonce : _myNonce;

      final x = X25519();
      final ee = await (await x.sharedSecretKey(
        keyPair: identity,
        remotePublicKey: SimplePublicKey(peerPub, type: KeyPairType.x25519),
      ))
          .extractBytes();
      final ss = await (await x.sharedSecretKey(
        keyPair: staticIdentity,
        remotePublicKey: SimplePublicKey(peerId, type: KeyPairType.x25519),
      ))
          .extractBytes();
      final ikm = Uint8List.fromList([...ee, ...ss]);
      final transcript = await Kdf.sha256([
        ...utf8.encode('wasl-chat-v1'),
        ...pubA,
        ...pubB,
        ...idA,
        ...idB,
        ...nonceA,
        ...nonceB,
      ]);

      final keyA = await Kdf.hkdf(ikm, 'wasl/chat/v1/A->B', salt: transcript);
      final keyB = await Kdf.hkdf(ikm, 'wasl/chat/v1/B->A', salt: transcript);
      final confirmA = await Kdf.hkdf(ikm, 'wasl/chat/v1/confirm-A', salt: transcript);
      final confirmB = await Kdf.hkdf(ikm, 'wasl/chat/v1/confirm-B', salt: transcript);
      Kdf.wipe(ikm);
      _sendKey = iAmA ? keyA : keyB;
      _recvKey = iAmA ? keyB : keyA;
      _peerConfirmKey = iAmA ? confirmB : confirmA;
      _transcript = transcript;

      final sas = await Kdf.sha256([...utf8.encode('wasl-sas-v1'), ...idA, ...idB]);
      final number = ((sas[0] << 24) | (sas[1] << 16) | (sas[2] << 8) | sas[3]) & 0x7fffffff;
      final code = (number % 1000000).toString().padLeft(6, '0');

      _pendingReady = ChannelReady(
        peerName: peerName.isEmpty ? 'الطرف الآخر' : peerName,
        peerKey: base64.encode(peerId),
        safetyCode: '${code.substring(0, 3)} ${code.substring(3)}',
      );

      final myMac = await _confirmMac(iAmA ? confirmA : confirmB, transcript);
      await _sendRaw({'t': 'confirm', 'm': base64.encode(myMac)});
    } catch (_) {
      await _close('protocol');
    }
  }

  Future<void> _onConfirm(Map<String, dynamic> m) async {
    final key = _peerConfirmKey;
    final transcript = _transcript;
    if (key == null || transcript == null || _confirmed) return;
    try {
      final expected = await _confirmMac(key, transcript);
      final got = base64.decode(m['m'] as String);
      if (!Kdf.constantTimeEquals(expected, got)) {
        await _close('protocol');
        return;
      }
      _confirmed = true;
      _timeout?.cancel();
      _startHeartbeat();
      if (!_ready.isCompleted) _ready.complete(_pendingReady!);
    } catch (_) {
      await _close('protocol');
    }
  }

  /// نبضة: نبعت ping لو ساكتين، ونقفل لو الطرف التاني ساكت أكتر من [lostAfter].
  void _startHeartbeat() {
    _lastRx = DateTime.now();
    final tick = Duration(milliseconds: (heartbeatEvery.inMilliseconds / 2).round().clamp(200, 2500));
    _heartbeat = Timer.periodic(tick, (_) {
      if (_closed) return;
      final now = DateTime.now();
      if (now.difference(_lastRx) > lostAfter) {
        _close('lost');
        return;
      }
      if (now.difference(_lastTx) >= heartbeatEvery) {
        _sendEncrypted({'k': 'ping'}).catchError((_) {});
      }
    });
  }

  static Future<List<int>> _confirmMac(List<int> key, List<int> transcript) async {
    final mac = await Hmac.sha256().calculateMac(transcript, secretKey: SecretKey(key));
    return mac.bytes;
  }

  Future<void> _onEncrypted(Map<String, dynamic> m) async {
    final key = _recvKey;
    if (key == null || !_confirmed) return;
    try {
      final encoded = m['d'] as String;
      final List<int>? clear = encoded.length > _isolateThreshold
          ? await _openInIsolate(key, encoded)
          : await _openBox(key, encoded);
      if (clear == null) return;
      final p = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      final seq = p['seq'] as int;
      if (seq <= _recvSeq) return; // إعادة إرسال قديمة — تجاهل
      _recvSeq = seq;
      switch (p['k']) {
        case 'ping':
          break;
        case 'msg':
          final text = '${p['text'] ?? ''}';
          if (text.isEmpty || text.length > maxTextLength) return;
          _packets.add(ChannelPacket(
            'msg',
            id: '${p['id']}',
            text: text,
            time: DateTime.fromMillisecondsSinceEpoch((p['ts'] as num?)?.toInt() ?? 0),
            data: p,
          ));
        case 'ack':
          _packets.add(ChannelPacket('ack', id: '${p['id']}'));
        case 'typing':
          _packets.add(ChannelPacket('typing'));
        case final String k when _extraKinds.contains(k):
          _packets.add(ChannelPacket(k, id: p['id'] as String?, data: p));
        case 'bye':
          await _close('bye');
      }
    } catch (_) {
      // رسالة معدلة أو بمفتاح خاطئ — تُرفض بصمت
    }
  }

  static final List<int> _aad = utf8.encode('wasl/chat/v1');

  /// فك صندوق AES-GCM (بيشتغل في الخيط الرئيسي أو في خيط منفصل).
  static Future<List<int>?> _openBox(List<int> key, String encoded) async {
    final data = base64.decode(encoded);
    if (data.length < 12 + 16) return null;
    final box = SecretBox(
      data.sublist(12, data.length - 16),
      nonce: data.sublist(0, 12),
      mac: Mac(data.sublist(data.length - 16)),
    );
    return AesGcm.with256bits().decrypt(box, secretKey: SecretKey(key), aad: _aad);
  }

  // ---- الحزم الكبيرة (أجزاء الملفات) ----
  // الأول بنجرب تشفير أندرويد نفسه (أسرع بكتير)، ولو مش متاح (الاختبارات) خيط منفصل.

  static const _native = MethodChannel('wasl/crypto');
  static bool _nativeAvailable = true;

  static Future<List<int>?> _openInIsolate(List<int> key, String encoded) async {
    if (_nativeAvailable) {
      try {
        return await _native.invokeMethod<Uint8List>('open', {
          'key': Uint8List.fromList(key),
          'data': base64.decode(encoded),
          'aad': Uint8List.fromList(_aad),
        });
      } on MissingPluginException {
        _nativeAvailable = false;
      } on PlatformException {
        // نكمّل بالطريقة التانية
      }
    }
    // دوال static عشان الـ closure ميمسكش `this` (مينفعش يتبعت لخيط تاني)
    return Isolate.run(() => _openBox(key, encoded));
  }

  static Future<String> _sealInIsolate(List<int> key, List<int> clear) async {
    if (_nativeAvailable) {
      try {
        final box = await _native.invokeMethod<Uint8List>('seal', {
          'key': Uint8List.fromList(key),
          'data': clear is Uint8List ? clear : Uint8List.fromList(clear),
          'aad': Uint8List.fromList(_aad),
        });
        if (box != null) return base64.encode(box);
      } on MissingPluginException {
        _nativeAvailable = false;
      } on PlatformException {
        // نكمّل بالطريقة التانية
      }
    }
    return Isolate.run(() => _sealBox(key, clear));
  }

  static Future<String> _sealBox(List<int> key, List<int> clear) async {
    final box = await AesGcm.with256bits().encrypt(
      clear,
      secretKey: SecretKey(key),
      nonce: Kdf.randomBytes(12),
      aad: _aad,
    );
    return base64.encode([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  Future<void> _sendEncrypted(Map<String, dynamic> payload) {
    final task = _outQueue.then((_) => _encryptAndSend(payload));
    _outQueue = task.catchError((_) {});
    return task;
  }

  Future<void> _encryptAndSend(Map<String, dynamic> payload) async {
    final key = _sendKey;
    if (key == null || !_confirmed || _closed) throw StateError('not ready');
    payload['seq'] = ++_sendSeq;
    final clear = utf8.encode(jsonEncode(payload));
    final sealed = clear.length > _isolateThreshold
        ? await _sealInIsolate(key, clear)
        : await _sealBox(key, clear);
    if (_closed) throw StateError('closed');
    await _sendRaw({'t': 'e', 'd': sealed});
  }

  Future<void> _sendRaw(Map<String, dynamic> map) {
    _lastTx = DateTime.now();
    return transport.send(jsonEncode(map));
  }

  Future<void> _close(String reason) async {
    if (_closed) return;
    _closed = true;
    _timeout?.cancel();
    _heartbeat?.cancel();
    await _sub?.cancel();
    if (!_ready.isCompleted) _ready.completeError(StateError(reason));
    if (!_closedReason.isCompleted) _closedReason.complete(reason);
    await _packets.close();
    try {
      await transport.close();
    } catch (_) {}
    for (final k in [_sendKey, _recvKey]) {
      if (k != null) Kdf.wipe(k);
    }
  }

  static String _cleanName(String name) {
    final n = name.replaceAll(RegExp(r'[\u0000-\u001f]'), '').trim();
    return n.length > 40 ? n.substring(0, 40) : n;
  }

  static int _compare(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }

  /// يولّد مفتاح مؤقت للجلسة.
  static Future<(SimpleKeyPair, Uint8List)> newIdentity() async {
    final kp = await X25519().newKeyPair();
    final pub = await kp.extractPublicKey();
    return (kp, Uint8List.fromList(pub.bytes));
  }
}
