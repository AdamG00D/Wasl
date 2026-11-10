import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/config.dart';
import '../core/platform/system_bridge.dart';
import '../features/chat/core/chat_errors.dart';
import 'mesh_link.dart';

class _Conn {
  _Conn(this.id, this.socket, this.outgoing);
  final String id;
  final Socket socket;
  final bool outgoing;
  StreamSubscription<String>? sub;
  bool closed = false;
}

class _Sighting {
  _Sighting(this.address, this.port) : first = DateTime.now();
  String address;
  int port;
  final DateTime first;
  DateTime last = DateTime.now();
  DateTime? lastDial;
  bool dialing = false;
}

/// الربط عبر نفس شبكة الواي فاي أو نقطة الاتصال (Hotspot).
///
/// • كل جهاز بيعلن عن نفسه (UDP broadcast) كل ثانية ونص.
/// • أول ما جهازين يشوفوا بعض بيفتحوا بينهم اتصال TCP واحد تلقائياً
///   (صاحب المعرّف الأصغر هو اللي بيبدأ عشان ميتفتحش اتصالين).
class LanLink extends MeshLink {
  LanLink(super.myId);

  static const _beaconEvery = Duration(milliseconds: 1500);
  static const _maxLine = 256 * 1024;

  ServerSocket? _server;
  RawDatagramSocket? _udp;
  Timer? _beaconTimer;
  Timer? _pruneTimer;
  int _port = AppConfig.lanPort;
  int _counter = 0;
  bool _running = false;

  final Map<String, _Conn> _conns = {};
  final Map<String, _Sighting> _sightings = {};
  List<String> localAddresses = const [];

  bool get hasNetwork => localAddresses.isNotEmpty;

  @override
  int get maxFrame => 200 * 1024;

  @override
  bool get supportsVideo => true;

  @override
  bool get supportsCalls => true;

  @override
  int get directFileLimit => 1024 * 1024 * 1024;

  @override
  int get groupFileLimit => 30 * 1024 * 1024;

  @override
  Duration get floodPacing => Duration.zero;

  @override
  bool isOutgoing(String link) => _conns[link]?.outgoing ?? false;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    setPhase(LinkPhase.starting);
    localAddresses = await findLocalAddresses();
    try {
      try {
        _server = await ServerSocket.bind(InternetAddress.anyIPv4, AppConfig.lanPort, shared: true);
      } catch (_) {
        // المنفذ مشغول: أي منفذ فاضي (بنعلن عنه في الإعلان)
        _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      }
      _port = _server!.port;
      _server!.listen((s) => _adopt(s, outgoing: false), onError: (_) {});
    } catch (_) {
      _running = false;
      setPhase(
        LinkPhase.failed,
        const ChatError(
          ChatErrorKind.network,
          'معرفناش نبدأ على الشبكة',
          'اقفل التطبيق وافتحه تاني. لو المشكلة فضلت اعمل ريستارت للواي فاي.',
        ),
      );
      return;
    }
    await SystemBridge.acquireMulticastLock();
    try {
      _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, AppConfig.lanBeaconPort, reuseAddress: true);
      _udp!
        ..broadcastEnabled = true
        ..listen((e) {
          if (e == RawSocketEvent.read) _onDatagram();
        });
    } catch (_) {
      // من غير الاستقبال لسه نقدر نتصل بالعنوان يدوياً
    }
    _beaconTimer = Timer.periodic(_beaconEvery, (_) => _beacon());
    _pruneTimer = Timer.periodic(const Duration(seconds: 2), (_) => _prune());
    _beacon();
    setPhase(LinkPhase.running);
  }

  @override
  Future<void> retry() async {
    if (_running) {
      localAddresses = await findLocalAddresses();
      clearError();
      _beacon();
    } else {
      await start();
    }
  }

  static Future<List<String>> findLocalAddresses() async {
    final result = <String>[];
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      for (final i in interfaces) {
        for (final a in i.addresses) {
          if (!a.isLinkLocal) result.add(a.address);
        }
      }
    } catch (_) {}
    int score(String ip) => ip.startsWith('192.168.')
        ? 0
        : ip.startsWith('10.')
            ? 1
            : ip.startsWith('172.')
                ? 2
                : 3;
    result.sort((a, b) => score(a).compareTo(score(b)));
    return result;
  }

  // ---------------- الإعلان والاكتشاف ----------------

  void _beacon() {
    final udp = _udp;
    if (udp == null) return;
    final data = utf8.encode(jsonEncode({'wasl': 1, 'id': myId, 'port': _port}));
    final targets = <String>{'255.255.255.255'};
    for (final ip in localAddresses) {
      final parts = ip.split('.');
      if (parts.length == 4) targets.add('${parts[0]}.${parts[1]}.${parts[2]}.255');
    }
    for (final t in targets) {
      try {
        udp.send(data, InternetAddress(t), AppConfig.lanBeaconPort);
      } catch (_) {}
    }
  }

  void _onDatagram() {
    final dg = _udp?.receive();
    if (dg == null || dg.data.length > 512) return;
    try {
      final m = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
      if (m['wasl'] != 1) return;
      final id = '${m['id']}';
      if (id == myId || !RegExp(r'^[0-9a-f]{16}$').hasMatch(id)) return;
      final port = (m['port'] as num?)?.toInt() ?? AppConfig.lanPort;
      if (port <= 0 || port > 65535) return;
      final s = _sightings[id];
      if (s == null) {
        _sightings[id] = _Sighting(dg.address.address, port);
      } else {
        s
          ..address = dg.address.address
          ..port = port
          ..last = DateTime.now();
      }
      _maybeDial(id);
    } catch (_) {}
  }

  void _maybeDial(String id) {
    final s = _sightings[id];
    if (s == null || s.dialing || isLinked(id) || !_running) return;
    final now = DateTime.now();
    // صاحب المعرّف الأصغر بيبدأ؛ التاني بيستنى شوية وبعدين يجرب هو (لو الأول معرفش)
    final myTurn = myId.compareTo(id) < 0 || now.difference(s.first) > const Duration(seconds: 6);
    if (!myTurn) return;
    if (s.lastDial != null && now.difference(s.lastDial!) < const Duration(seconds: 4)) return;
    s.lastDial = now;
    s.dialing = true;
    _dial(s.address, s.port).whenComplete(() => s.dialing = false);
  }

  Future<bool> _dial(String address, int port) async {
    try {
      final socket = await Socket.connect(address, port, timeout: const Duration(seconds: 5));
      if (!_running) {
        socket.destroy();
        return false;
      }
      _adopt(socket, outgoing: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// اتصال يدوي بعنوان IP (لو الشبكة مانعة الاكتشاف التلقائي).
  Future<bool> connectToAddress(String ip) => _dial(ip, AppConfig.lanPort);

  void _prune() {
    final now = DateTime.now();
    _sightings.removeWhere((_, s) => now.difference(s.last) > const Duration(seconds: 8));
    for (final id in _sightings.keys.toList()) {
      _maybeDial(id);
    }
    // الشبكة ممكن تتغير (واي فاي اتقفل / هوت سبوت اتفتح)
    findLocalAddresses().then((a) {
      if (a.join() == localAddresses.join()) return;
      localAddresses = a;
      notifyListeners();
      if (a.isEmpty) {
        for (final c in _conns.values.toList()) {
          _close(c);
        }
      } else {
        _beacon();
      }
    });
  }

  // ---------------- الوصلات ----------------

  void _adopt(Socket socket, {required bool outgoing}) {
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}
    final c = _Conn('tcp${_counter++}', socket, outgoing);
    _conns[c.id] = c;
    c.sub = socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        if (line.isEmpty || line.length > _maxLine || c.closed) return;
        onFrame?.call(c.id, line);
      },
      onDone: () => _close(c),
      onError: (_) => _close(c),
      cancelOnError: true,
    );
    onUp?.call(c.id);
  }

  void _close(_Conn c) {
    if (c.closed) return;
    c.closed = true;
    _conns.remove(c.id);
    c.sub?.cancel();
    c.socket.destroy();
    onDown?.call(c.id);
  }

  @override
  Future<void> send(String link, String frame) async {
    final c = _conns[link];
    if (c == null || c.closed) throw StateError('closed');
    try {
      c.socket.write('$frame\n');
      await c.socket.flush();
    } catch (e) {
      _close(c);
      rethrow;
    }
  }

  @override
  void drop(String link) {
    final c = _conns[link];
    if (c != null) _close(c);
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _beaconTimer?.cancel();
    _pruneTimer?.cancel();
    for (final c in _conns.values.toList()) {
      _close(c);
    }
    _sightings.clear();
    await _server?.close();
    _server = null;
    _udp?.close();
    _udp = null;
    await SystemBridge.releaseMulticastLock();
    setPhase(LinkPhase.idle);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
