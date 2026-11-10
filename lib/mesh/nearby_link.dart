import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';

import '../core/config.dart';
import '../features/chat/core/chat_errors.dart';
import 'mesh_link.dart';

/// الربط بالبلوتوث عبر Google Nearby Connections (من غير إنترنت أو اقتران).
///
/// الاستراتيجية P2P_CLUSTER: كل جهاز بيعلن وبيدوّر في نفس الوقت وبيتوصل
/// بأكتر من جهاز، فالأجهزة بتكوّن شبكة والرسايل بتعدّي من جهاز لجهاز (Mesh).
class NearbyLink extends MeshLink {
  NearbyLink(super.myId);

  static const _strategy = Strategy.P2P_CLUSTER;

  /// البلوتوث مبيستحملش وصلات كتير في نفس الوقت.
  static const _maxLinks = 5;

  final Nearby _nearby = Nearby();

  /// endpointId ← معرّف الجهاز (الاسم المُعلن).
  final Map<String, String> _found = {};
  final Map<String, DateTime> _firstSeen = {};
  final Map<String, DateTime> _lastTry = {};
  final Set<String> _pending = {};
  final Set<String> _connected = {};
  final Set<String> _outgoing = {};

  /// إطارات وصلت قبل ما النظام يبلّغنا إن الوصلة اتفتحت (بتتسلّم أول ما تتفتح).
  final Map<String, List<String>> _early = {};
  Timer? _timer;
  bool _running = false;

  @override
  int get maxFrame => 30000;

  @override
  bool get supportsVideo => false;

  @override
  bool get supportsCalls => false;

  @override
  int get directFileLimit => 50 * 1024 * 1024;

  @override
  int get groupFileLimit => 8 * 1024 * 1024;

  @override
  Duration get floodPacing => const Duration(milliseconds: 60);

  @override
  bool isOutgoing(String link) => _outgoing.contains(link);

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    setPhase(LinkPhase.starting);
    try {
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
      await _nearby.stopAllEndpoints();
    } catch (_) {}
    try {
      await _nearby.startAdvertising(
        myId,
        _strategy,
        onConnectionInitiated: _onInitiated,
        onConnectionResult: _onResult,
        onDisconnected: _onDisconnected,
        serviceId: AppConfig.nearbyServiceId,
      );
      await _nearby.startDiscovery(
        myId,
        _strategy,
        onEndpointFound: _onFound,
        onEndpointLost: _onLost,
        serviceId: AppConfig.nearbyServiceId,
      );
    } catch (e) {
      final s = e.toString();
      if (!s.contains('8001') && !s.contains('8002')) {
        _running = false;
        try {
          await _nearby.stopAdvertising();
          await _nearby.stopDiscovery();
        } catch (_) {}
        setPhase(LinkPhase.failed, ChatError.fromNearby(e));
        return;
      }
    }
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _sweep());
    setPhase(LinkPhase.running);
  }

  @override
  Future<void> retry() async {
    await stop();
    await start();
  }

  void _onFound(String endpointId, String name, String serviceId) {
    if (serviceId.isNotEmpty && serviceId != AppConfig.nearbyServiceId) return;
    if (name == myId || !RegExp(r'^[0-9a-f]{16}$').hasMatch(name)) return;
    _found[endpointId] = name;
    _firstSeen.putIfAbsent(endpointId, DateTime.now);
    _maybeRequest(endpointId);
  }

  void _onLost(String? endpointId) {
    if (endpointId == null) return;
    _found.remove(endpointId);
    _firstSeen.remove(endpointId);
  }

  void _sweep() {
    for (final id in _found.keys.toList()) {
      _maybeRequest(id);
    }
  }

  void _maybeRequest(String endpointId) {
    final node = _found[endpointId];
    if (!_running || node == null) return;
    if (_connected.contains(endpointId) || _pending.contains(endpointId) || isLinked(node)) return;
    if (_connected.length + _pending.length >= _maxLinks) return;
    final now = DateTime.now();
    // صاحب المعرّف الأصغر بيبدأ؛ التاني بيجرب بعد شوية لو مفيش حاجة حصلت
    final myTurn = myId.compareTo(node) < 0 ||
        now.difference(_firstSeen[endpointId] ?? now) > const Duration(seconds: 12);
    if (!myTurn) return;
    final last = _lastTry[endpointId];
    if (last != null && now.difference(last) < const Duration(seconds: 8)) return;
    _lastTry[endpointId] = now;
    _pending.add(endpointId);
    _outgoing.add(endpointId);
    _nearby
        .requestConnection(
          myId,
          endpointId,
          onConnectionInitiated: _onInitiated,
          onConnectionResult: _onResult,
          onDisconnected: _onDisconnected,
        )
        .catchError((Object _) {
      _pending.remove(endpointId);
      _outgoing.remove(endpointId);
      return false;
    });
  }

  void _onInitiated(String endpointId, ConnectionInfo info) {
    if (!_running) return;
    if (info.isIncomingConnection) {
      if (_connected.length >= _maxLinks + 1) {
        _nearby.rejectConnection(endpointId).catchError((Object _) => false);
        return;
      }
      _pending.add(endpointId);
    }
    // القبول تلقائي: الأمان في التشفير من طرف لطرف فوق الشبكة، مش في الوصلة نفسها
    _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: (id, payload) {
        final bytes = payload.bytes;
        if (payload.type != PayloadType.BYTES || bytes == null || bytes.length > 64 * 1024) return;
        final frame = utf8.decode(bytes, allowMalformed: true);
        if (!_connected.contains(id)) {
          final q = _early.putIfAbsent(id, () => []);
          if (q.length < 32) q.add(frame);
          return;
        }
        onFrame?.call(id, frame);
      },
    ).catchError((Object _) {
      _pending.remove(endpointId);
      return false;
    });
  }

  void _onResult(String endpointId, Status result) {
    _pending.remove(endpointId);
    if (result == Status.CONNECTED && _running) {
      _connected.add(endpointId);
      onUp?.call(endpointId);
      for (final frame in _early.remove(endpointId) ?? const <String>[]) {
        onFrame?.call(endpointId, frame);
      }
    } else {
      _outgoing.remove(endpointId);
      _early.remove(endpointId);
    }
  }

  void _onDisconnected(String endpointId) {
    _pending.remove(endpointId);
    _outgoing.remove(endpointId);
    _early.remove(endpointId);
    if (_connected.remove(endpointId)) onDown?.call(endpointId);
  }

  @override
  Future<void> send(String link, String frame) async {
    if (!_connected.contains(link)) throw StateError('closed');
    await _nearby.sendBytesPayload(link, Uint8List.fromList(utf8.encode(frame)));
  }

  @override
  void drop(String link) {
    _nearby.disconnectFromEndpoint(link).catchError((Object _) {});
    _onDisconnected(link);
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    try {
      await _nearby.stopAdvertising();
    } catch (_) {}
    try {
      await _nearby.stopDiscovery();
    } catch (_) {}
    try {
      await _nearby.stopAllEndpoints();
    } catch (_) {}
    for (final id in _connected.toList()) {
      _connected.remove(id);
      onDown?.call(id);
    }
    _found.clear();
    _firstSeen.clear();
    _lastTry.clear();
    _pending.clear();
    _outgoing.clear();
    _early.clear();
    setPhase(LinkPhase.idle);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
