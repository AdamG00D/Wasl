import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/crypto/kdf.dart';
import '../core/profile/profile.dart';
import '../widgets/cartoon_avatar.dart';
import 'mesh_link.dart';

/// نوع الجروب.
enum GroupMode {
  /// عام: أي حد يدخل.
  open('o'),

  /// خاص بكلمة سر.
  password('p'),

  /// خاص بطلب انضمام (صاحب الجروب بيوافق).
  ask('a');

  const GroupMode(this.wire);
  final String wire;

  static GroupMode? fromWire(Object? w) {
    for (final m in values) {
      if (m.wire == w) return m;
    }
    return null;
  }
}

/// إعلان عن جروب (بيتبعت مع "أنا موجود" من كل عضو فيه).
class GroupAd {
  const GroupAd({
    required this.id,
    required this.name,
    required this.mode,
    required this.owner,
    this.check,
    this.digest,
  });

  final String id;
  final String name;
  final GroupMode mode;

  /// معرّف صاحب الجروب.
  final String owner;

  /// للجروبات بكلمة سر: قيمة نتأكد بيها إن الكلمة صح (من غير ما نكشفها).
  final String? check;

  /// بصمة حالة الإدارة عند العضو ده (الاسم، المديرين، اللي اتشالوا).
  final String? digest;

  Map<String, dynamic> toWire() => {'i': id, 'n': name, 'm': mode.wire, 'o': owner, 'c': ?check, 'h': ?digest};

  static GroupAd? fromWire(Object? raw) {
    if (raw is! Map) return null;
    final id = '${raw['i'] ?? ''}';
    final owner = '${raw['o'] ?? ''}';
    final mode = GroupMode.fromWire(raw['m']);
    final name = Profile.cleanName('${raw['n'] ?? ''}');
    if (!MeshRouter.isId(id) || !MeshRouter.isId(owner) || mode == null || name.isEmpty) return null;
    final check = raw['c'];
    final digest = raw['h'];
    return GroupAd(
      id: id,
      name: name,
      mode: mode,
      owner: owner,
      check: check is String && check.length <= 64 ? check : null,
      digest: digest is String && digest.length <= 16 ? digest : null,
    );
  }
}

/// جهاز في الشبكة (جار مباشر أو واصلين له عن طريق أجهزة تانية).
class MeshNode {
  MeshNode(this.id, this.publicKey);

  final String id;
  final Uint8List publicKey;
  String name = '';
  int color = 0;
  String? avatar;

  /// رقم الأفاتار الكرتوني (لو مختار واحد).
  int? cartoon;
  List<GroupAd> groups = const [];
  DateTime lastSeen = DateTime.now();

  /// عدد القفزات لحد الجهاز ده (1 = جار مباشر).
  int hops = 1;

  /// آخر "أنا موجود" منه (عشان نوصّله للجيران الجداد على طول).
  String? _lastPresence;
}

class _Assembly {
  _Assembly(this.fid, this.total);
  final String fid;
  final int total;
  final StringBuffer buffer = StringBuffer();
  int next = 0;
}

/// موجّه الشبكة (Mesh): بيعرف مين موجود، وبيوصّل الرسايل لأبعد من الجيران المباشرين.
///
/// شكل الإطار:  `نوع|مصدر|وجهة|رقم|قفزات|المحتوى`
///   P  أنا موجود (بث للكل)         X  أنا خارج (بث)
///   D  بيانات محادثة خاصة (لجهاز)   U  رسالة تحكم JSON (لجهاز)
///   G  رسالة جروب (بث، الوجهة = معرّف الجروب)
///   H  تعارف بين جارين (مش بيتوجّه)
///   F  جزء من إطار أكبر من اللي الوصلة تستحمله: `F|رقم|جزء|العدد|المحتوى` (بين جارين بس)
///
/// • البث: كل جهاز بيعيد الإرسال مرة واحدة (بنتجاهل المكرر) لحد ما القفزات تخلص،
///   ومبنبعتش لجار إحنا عارفين إن اللي بعتلنا جاره هو كمان.
/// • الموجّه لجهاز: بنمشي في الطريق اللي آخر رسالة منه جت منه، ولو مش معروف بنبث.
/// • الموجّه مبيفهمش المحتوى: المحادثات الخاصة مشفرة من طرف لطرف فوقه.
class MeshRouter extends ChangeNotifier {
  MeshRouter({
    required this.link,
    required this.describe,
    this.presenceEvery = const Duration(seconds: 3),
    this.nodeTtl = const Duration(seconds: 11),
  }) : myId = link.myId {
    link
      ..onUp = _onLinkUp
      ..onFrame = _onLinkFrame
      ..onDown = _onLinkDown
      ..isLinked = _nodeToLink.containsKey
      ..linkOf = ((id) => _nodeToLink[id]);
  }

  static const int maxHops = 6;

  /// أقصى طول لإطار بعد تجميع أجزائه.
  static const int maxAssembled = 256 * 1024;
  static const int _maxFragments = 64;
  static final RegExp _idPattern = RegExp(r'^[0-9a-f]{16}$');
  static bool isId(String s) => _idPattern.hasMatch(s);

  final MeshLink link;
  final String myId;

  /// بيانات "أنا موجود": {n: الاسم, c: اللون, k: المفتاح العام, a: هاش الصورة, e: أفاتار كرتوني, g: الجروبات}.
  final Map<String, dynamic> Function() describe;

  final Duration presenceEvery;
  final Duration nodeTtl;

  /// الأجهزة اللي واصلين لها دلوقتي.
  final Map<String, MeshNode> nodes = {};

  void Function(String src, String body)? onData;
  void Function(String group, String src, String body)? onGroup;
  void Function(String src, Map<String, dynamic> message)? onControl;
  void Function(MeshNode node)? onNodeUp;
  void Function(MeshNode node)? onNodeDown;

  final Map<String, String> _linkToNode = {};
  final Map<String, String> _nodeToLink = {};
  final Map<String, Timer> _unidentified = {};
  final Map<String, Set<String>> _neighborsOf = {};
  final Map<String, String> _routes = {};
  final Map<String, Future<void>> _queues = {};
  final Map<String, DateTime> _lastRx = {};
  final LinkedHashSet<String> _seen = LinkedHashSet<String>();
  final Map<String, String> _verifiedKeys = {};
  final String _epoch = Kdf.hex(Kdf.randomBytes(3));
  int _counter = 0;
  int _fragCounter = 0;
  final Map<String, _Assembly> _assembling = {};
  Timer? _presenceTimer;
  Timer? _pruneTimer;
  Timer? _presenceSoon;
  bool _running = false;
  bool _disposed = false;

  bool get running => _running;

  /// وصلة ساكتة أكتر من كده تعتبر ميتة (كل جار بيبعت "أنا موجود" كل [presenceEvery]).
  Duration get linkTtl => presenceEvery * 3 + const Duration(milliseconds: 1500);

  /// عدد الجيران المباشرين.
  int get neighborCount => _nodeToLink.length;

  bool isDirect(String id) => _nodeToLink.containsKey(id);

  /// الوصلة المباشرة للجهاز ده (null = مش جار مباشر).
  String? linkOf(String id) => _nodeToLink[id];

  /// نقدر نوصل للجهاز ده دلوقتي؟
  bool reachable(String id) => _nodeToLink.isNotEmpty && nodes.containsKey(id);

  int get maxFrame => link.maxFrame - 128;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _presenceTimer = Timer.periodic(presenceEvery, (_) => _sendPresence());
    _pruneTimer = Timer.periodic(const Duration(seconds: 2), (_) => _prune());
    await link.start();
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _presenceTimer?.cancel();
    _pruneTimer?.cancel();
    _presenceSoon?.cancel();
    try {
      await _broadcast(_frame('X', '*', ''), null).timeout(const Duration(seconds: 1));
    } catch (_) {}
    await link.stop();
    for (final t in _unidentified.values) {
      t.cancel();
    }
    _unidentified.clear();
    _assembling.clear();
    final gone = nodes.values.toList();
    nodes.clear();
    _routes.clear();
    _neighborsOf.clear();
    for (final n in gone) {
      onNodeDown?.call(n);
    }
    notifyListeners();
  }

  /// يبعت "أنا موجود" دلوقتي (بعد تغيير الاسم/الصورة/الجروبات).
  void announce() {
    _presenceSoon?.cancel();
    _presenceSoon = Timer(const Duration(milliseconds: 250), _sendPresence);
  }

  // ---------------- الإرسال ----------------

  /// بيانات محادثة خاصة لجهاز (ممكن تعدّي على أجهزة تانية).
  Future<void> sendData(String dst, String body) => _unicast(_frame('D', dst, body), dst, null);

  /// رسالة تحكم لجهاز.
  Future<void> sendControl(String dst, Map<String, dynamic> message) =>
      _unicast(_frame('U', dst, jsonEncode(message)), dst, null);

  /// رسالة لكل أعضاء جروب (بث).
  Future<void> sendGroup(String groupId, String body) {
    if (_nodeToLink.isEmpty) return Future.error(StateError('alone'));
    return _broadcast(_frame('G', groupId, body), null);
  }

  String _frame(String kind, String dst, String body) {
    final pid = '$_epoch${(_counter++).toRadixString(36)}';
    _markSeen('$myId$pid');
    return '$kind|$myId|$dst|$pid|$maxHops|$body';
  }

  Future<void> _sendTo(String linkId, String frame) {
    final prev = _queues[linkId] ?? Future<void>.value();
    final next = prev.then((_) => _sendWhole(linkId, frame));
    _queues[linkId] = next.catchError((Object _) {});
    return next;
  }

  /// الإطار اللي أكبر من طاقة الوصلة (مثلاً جاي من الواي فاي ورايح بلوتوث) بيتقسم أجزاء.
  Future<void> _sendWhole(String linkId, String frame) async {
    final limit = link.frameLimit(linkId);
    if (frame.length <= limit) return link.send(linkId, frame);
    final size = limit - 40;
    final n = (frame.length + size - 1) ~/ size;
    if (size < 256 || n > _maxFragments) throw StateError('frame too big');
    final fid = (_fragCounter++).toRadixString(36);
    for (var i = 0; i < n; i++) {
      final end = (i + 1) * size;
      await link.send(linkId, 'F|$fid|$i|$n|${frame.substring(i * size, end > frame.length ? frame.length : end)}');
    }
  }

  Future<void> _broadcast(String frame, String? fromLink) {
    final from = fromLink == null ? null : _linkToNode[fromLink];
    final skip = from == null ? const <String>{} : (_neighborsOf[from] ?? const <String>{});
    final sends = <Future<void>>[];
    for (final e in _nodeToLink.entries) {
      if (e.value == fromLink || skip.contains(e.key)) continue;
      sends.add(_sendTo(e.value, frame).catchError((Object _) {}));
    }
    return Future.wait(sends);
  }

  Future<void> _unicast(String frame, String dst, String? fromLink) {
    final direct = _nodeToLink[dst];
    if (direct != null) return _sendTo(direct, frame);
    final via = _nodeToLink[_routes[dst] ?? ''];
    if (via != null && via != fromLink) return _sendTo(via, frame);
    if (_nodeToLink.isEmpty) return Future.error(StateError('unreachable'));
    // الطريق مش معروف: بث (الجهاز المقصود هيرد فالطريق يتعرف)
    final sends = <Future<void>>[];
    for (final l in _nodeToLink.values) {
      if (l != fromLink) sends.add(_sendTo(l, frame).catchError((Object _) {}));
    }
    return Future.wait(sends);
  }

  void _sendPresence() {
    if (!_running || _nodeToLink.isEmpty) return;
    final body = jsonEncode({...describe(), 'nb': _nodeToLink.keys.toList()});
    _broadcast(_frame('P', '*', body), null);
  }

  // ---------------- الوصلات ----------------

  void _onLinkUp(String linkId) {
    // لازم يعرّف نفسه خلال 8 ثواني
    _unidentified[linkId] = Timer(const Duration(seconds: 8), () => link.drop(linkId));
    _sendTo(linkId, 'H|$myId').catchError((Object _) {});
  }

  void _onLinkDown(String linkId) {
    _unidentified.remove(linkId)?.cancel();
    _queues.remove(linkId);
    _lastRx.remove(linkId);
    _assembling.remove(linkId);
    final node = _linkToNode.remove(linkId);
    if (node == null) return;
    if (_nodeToLink[node] == linkId) {
      _nodeToLink.remove(node);
      _neighborsOf.remove(node);
      _routes.removeWhere((_, via) => via == node);
      // لو مفيش طريق تاني ليه هيختفي بسرعة (بدل ما نستنى المهلة كلها)
      final n = nodes[node];
      if (n != null) {
        final soon = DateTime.now().subtract(nodeTtl - const Duration(seconds: 4));
        if (n.lastSeen.isAfter(soon)) n.lastSeen = soon;
      }
      announce();
      notifyListeners();
    }
  }

  void _onHello(String linkId, String node) {
    if (!isId(node) || node == myId) {
      link.drop(linkId);
      return;
    }
    _unidentified.remove(linkId)?.cancel();
    final existing = _nodeToLink[node];
    if (existing != null && existing != linkId) {
      // وصلتين لنفس الجهاز: نخلّي اللي بدأها صاحب المعرّف الأصغر (الطرفين بيختاروا نفس الوصلة)
      // — إلا لو القديمة ساكتة (الجهاز قفل ورجع): الجديدة هي اللي شغالة.
      final smallerIsMe = myId.compareTo(node) < 0;
      final existingBySmaller = link.isOutgoing(existing) == smallerIsMe;
      final newBySmaller = link.isOutgoing(linkId) == smallerIsMe;
      final last = _lastRx[existing];
      final existingFresh = last != null && DateTime.now().difference(last) < presenceEvery * 2;
      // وصلة أسرع (واي فاي) بتاخد مكان الأبطأ (بلوتوث)، والعكس لأ
      final better = link.rank(linkId) - link.rank(existing);
      if (existingFresh && (better < 0 || (better == 0 && existingBySmaller && !newBySmaller))) {
        _linkToNode.remove(linkId);
        link.drop(linkId);
        return;
      }
      _linkToNode.remove(existing);
      _nodeToLink.remove(node);
      link.drop(existing);
    }
    _linkToNode[linkId] = node;
    _nodeToLink[node] = linkId;
    _routes.remove(node);
    // الجار الجديد يعرف على طول مين موجود
    for (final n in nodes.values) {
      final p = n._lastPresence;
      if (p != null && n.id != node) _sendTo(linkId, p).catchError((Object _) {});
    }
    _sendPresence();
    notifyListeners();
  }

  void _markSeen(String key) {
    _seen.add(key);
    if (_seen.length > 6000) {
      final drop = _seen.take(1500).toList();
      _seen.removeAll(drop);
    }
  }

  void _onLinkFrame(String linkId, String frame) {
    if (!_running || frame.length > maxAssembled + 512) return;
    _lastRx[linkId] = DateTime.now();
    if (frame.startsWith('F|')) {
      final whole = _assemble(linkId, frame);
      if (whole != null) _onWholeFrame(linkId, whole);
      return;
    }
    _onWholeFrame(linkId, frame);
  }

  /// بيجمّع أجزاء إطار كبير (بتوصل بالترتيب على نفس الوصلة). يرجّع الإطار لما يكمل.
  String? _assemble(String linkId, String frame) {
    final a = frame.indexOf('|', 2);
    final b = a < 0 ? -1 : frame.indexOf('|', a + 1);
    final c = b < 0 ? -1 : frame.indexOf('|', b + 1);
    if (c < 0 || a > 12) return null;
    final fid = frame.substring(2, a);
    final i = int.tryParse(frame.substring(a + 1, b)) ?? -1;
    final n = int.tryParse(frame.substring(b + 1, c)) ?? 0;
    if (n < 2 || n > _maxFragments || i < 0 || i >= n) return null;
    var asm = _assembling[linkId];
    if (i == 0) {
      asm = _assembling[linkId] = _Assembly(fid, n);
    } else if (asm == null || asm.fid != fid || asm.total != n || asm.next != i) {
      _assembling.remove(linkId);
      return null;
    }
    asm.buffer.write(frame.substring(c + 1));
    asm.next++;
    if (asm.buffer.length > maxAssembled) {
      _assembling.remove(linkId);
      return null;
    }
    if (asm.next < n) return null;
    _assembling.remove(linkId);
    return asm.buffer.toString();
  }

  void _onWholeFrame(String linkId, String frame) {
    if (frame.startsWith('H|')) {
      _onHello(linkId, frame.substring(2));
      return;
    }
    final neighbor = _linkToNode[linkId];
    if (neighbor == null) return; // لسه معرّفش نفسه
    // نوع|مصدر|وجهة|رقم|قفزات|محتوى
    final parts = <String>[];
    var start = 0;
    for (var i = 0; i < 5; i++) {
      final bar = frame.indexOf('|', start);
      if (bar == -1) return;
      parts.add(frame.substring(start, bar));
      start = bar + 1;
    }
    final kind = parts[0], src = parts[1], dst = parts[2], pid = parts[3];
    final ttl = int.tryParse(parts[4]) ?? 0;
    if (!isId(src) || src == myId || pid.isEmpty || pid.length > 24 || ttl < 1 || ttl > maxHops) return;
    final key = '$src$pid';
    if (_seen.contains(key)) return;
    _markSeen(key);
    final body = frame.substring(start);

    // الطريق لصاحب الرسالة = الجار اللي جابها الأول
    if (src != neighbor) _routes[src] = neighbor;

    String forwarded() => '$kind|$src|$dst|$pid|${ttl - 1}|$body';

    switch (kind) {
      case 'P':
        _onPresence(src, body, hops: maxHops - ttl + 1, raw: ttl > 1 ? forwarded() : null);
        if (ttl > 1) _broadcast(forwarded(), linkId);
      case 'X':
        _removeNode(src);
        if (ttl > 1) _broadcast(forwarded(), linkId);
      case 'G':
        if (!isId(dst)) return;
        if (ttl > 1) _broadcast(forwarded(), linkId);
        onGroup?.call(dst, src, body);
      case 'D' || 'U':
        if (dst == myId) {
          if (kind == 'D') {
            onData?.call(src, body);
          } else {
            try {
              final m = jsonDecode(body);
              if (m is Map<String, dynamic>) onControl?.call(src, m);
            } catch (_) {}
          }
        } else if (ttl > 1 && isId(dst)) {
          _unicast(forwarded(), dst, linkId).catchError((Object _) {});
        }
    }
  }

  // ---------------- مين موجود ----------------

  Future<void> _onPresence(String src, String body, {required int hops, String? raw}) async {
    if (body.length > 6000) return;
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final k = m['k'];
    if (k is! String || k.length > 64) return;
    // المعرّف لازم يكون هاش المفتاح العام (محدش ينتحل معرّف غيره)
    if (_verifiedKeys[src] != k) {
      final Uint8List pub;
      try {
        pub = base64.decode(k);
      } catch (_) {
        return;
      }
      if (pub.length != 32 || await Profile.idOf(pub) != src) return;
      _verifiedKeys[src] = k;
    }
    if (!_running) return;
    final isNew = !nodes.containsKey(src);
    final node = nodes[src] ??= MeshNode(src, base64.decode(k));
    final name = Profile.cleanName('${m['n'] ?? ''}');
    final color = (m['c'] as num?)?.toInt() ?? 0;
    final avatar = m['a'] is String && RegExp(r'^[0-9a-f]{12}$').hasMatch(m['a'] as String) ? m['a'] as String : null;
    final cartoon = CartoonAvatars.clean(m['e']);
    final groups = <GroupAd>[
      for (final g in (m['g'] as List? ?? const []).take(16))
        if (GroupAd.fromWire(g) case final GroupAd ad) ad,
    ];
    final direct = isDirect(src);
    final newHops = direct ? 1 : hops.clamp(2, maxHops);
    final changed = isNew ||
        node.name != name ||
        node.color != color ||
        node.avatar != avatar ||
        node.cartoon != cartoon ||
        node.hops != newHops ||
        !_sameGroups(node.groups, groups);
    node
      ..name = name.isEmpty ? 'مجهول' : name
      ..color = color
      ..avatar = avatar
      ..cartoon = cartoon
      ..groups = groups
      ..hops = newHops
      ..lastSeen = DateTime.now()
      .._lastPresence = raw;
    if (direct) {
      _neighborsOf[src] = {
        for (final n in (m['nb'] as List? ?? const []).take(32))
          if (n is String && isId(n)) n,
      };
    }
    if (isNew) onNodeUp?.call(node);
    if (changed) notifyListeners();
  }

  static bool _sameGroups(List<GroupAd> a, List<GroupAd> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].name != b[i].name || a[i].mode != b[i].mode || a[i].check != b[i].check || a[i].digest != b[i].digest) {
        return false;
      }
    }
    return true;
  }

  void _removeNode(String id) {
    final n = nodes.remove(id);
    if (n == null) return;
    _routes.remove(id);
    onNodeDown?.call(n);
    notifyListeners();
  }

  void _prune() {
    final now = DateTime.now();
    // وصلة ميتة (الجهاز اختفى من غير ما يقفل الاتصال): نقفلها عشان يقدر يرجع بوصلة جديدة
    for (final linkId in _linkToNode.keys.toList()) {
      final last = _lastRx[linkId];
      if (last != null && now.difference(last) > linkTtl) link.drop(linkId);
    }
    for (final n in nodes.values.toList()) {
      if (now.difference(n.lastSeen) > nodeTtl) _removeNode(n.id);
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _presenceTimer?.cancel();
    _pruneTimer?.cancel();
    _presenceSoon?.cancel();
    for (final t in _unidentified.values) {
      t.cancel();
    }
    super.dispose();
  }
}
