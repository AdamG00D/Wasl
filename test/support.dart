import 'dart:async';

import 'package:wasl/mesh/mesh_link.dart';

/// شبكة وهمية في الذاكرة: بنوصّل الأجهزة ببعض زي ما نحب (خط، نجمة...).
class MemoryNet {
  final Map<String, MemoryLink> links = {};
  int _counter = 0;

  MemoryLink add(String id) => links[id] = MemoryLink(id, this);

  /// وصلة مباشرة بين جهازين.
  void connect(String a, String b) {
    final la = links[a]!, lb = links[b]!;
    final id = 'w${_counter++}';
    la._wires[id] = (lb, true);
    lb._wires[id] = (la, false);
    la.onUp?.call(id);
    lb.onUp?.call(id);
  }

  void disconnect(String a, String b) {
    final la = links[a]!, lb = links[b]!;
    for (final id in la._wires.keys.toList()) {
      if (identical(la._wires[id]!.$1, lb)) {
        la._wires.remove(id);
        lb._wires.remove(id);
        la.onDown?.call(id);
        lb.onDown?.call(id);
      }
    }
  }
}

class MemoryLink extends MeshLink {
  MemoryLink(super.myId, this.net);

  final MemoryNet net;
  final Map<String, (MemoryLink, bool)> _wires = {};
  int sent = 0;

  /// الجهاز "مات" من غير ما يقفل الاتصال: اللي بيتبعتله بيضيع، وهو مبيبعتش.
  bool dead = false;

  @override
  int maxFrame = 30000;

  @override
  bool get supportsVideo => true;

  @override
  bool get supportsCalls => false;

  @override
  int get directFileLimit => 64 * 1024 * 1024;

  @override
  int get groupFileLimit => 8 * 1024 * 1024;

  @override
  Duration get floodPacing => Duration.zero;

  @override
  bool isOutgoing(String link) => _wires[link]?.$2 ?? false;

  @override
  Future<void> start() async => setPhase(LinkPhase.running);

  @override
  Future<void> stop() async => setPhase(LinkPhase.idle);

  @override
  Future<void> retry() async {}

  @override
  Future<void> send(String link, String frame) async {
    final w = _wires[link];
    if (w == null) throw StateError('closed');
    if (dead || w.$1.dead) return;
    sent++;
    // التسليم في دورة تانية زي الشبكة الحقيقية
    await Future<void>.delayed(Duration.zero);
    if (w.$1._wires.containsKey(link)) w.$1.onFrame?.call(link, frame);
  }

  @override
  void drop(String link) {
    final w = _wires.remove(link);
    if (w == null) return;
    w.$1._wires.remove(link);
    onDown?.call(link);
    w.$1.onDown?.call(link);
  }
}

Future<void> waitFor(bool Function() test, {Duration timeout = const Duration(seconds: 10), String? what}) async {
  final end = DateTime.now().add(timeout);
  while (!test()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('waitFor timed out${what == null ? '' : ': $what'}');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
