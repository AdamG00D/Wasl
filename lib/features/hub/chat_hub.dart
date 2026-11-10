import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/crypto/box.dart';
import '../../core/crypto/kdf.dart';
import '../../core/nav.dart';
import '../../core/platform/system_bridge.dart';
import '../../core/profile/profile.dart';
import '../../core/settings/app_settings.dart';
import '../../core/storage/chat_store.dart';
import '../../mesh/dual_link.dart';
import '../../mesh/lan_link.dart';
import '../../mesh/mesh_link.dart';
import '../../mesh/mesh_router.dart';
import '../../mesh/nearby_link.dart';
import '../../mesh/peer_link.dart';
import '../chat/call/call_controller.dart';
import '../chat/call/call_screen.dart';
import '../chat/core/chat_session.dart';
import '../groups/group.dart';
import '../groups/group_session.dart';

enum TransportKind {
  bluetooth,
  wifi,

  /// الاتنين مع بعض: الموبايل بيوصّل شبكة الواي فاي بالناس اللي على البلوتوث.
  both,
}

/// محادثة (خاصة أو جروب) عايشة طول ما الشبكة شغالة.
abstract class Conversation {
  Conversation(this.hub);

  final ChatHub hub;

  String get id;
  bool get isGroup;
  String get title;
  int get color;
  String? get avatar;
  ChatSession get session;

  /// رسايل وصلت والمحادثة مش مفتوحة.
  int unread = 0;

  /// اختيار المستخدم للمحادثة دي (null = زي الإعداد العام).
  bool? saveOverride;

  /// المحادثة دي بتتحفظ على الجهاز؟
  bool get saved => saveOverride ?? AppSettings.instance.saveChats;

  DateTime lastActivity = DateTime.fromMillisecondsSinceEpoch(0);

  /// آخر رسالة حقيقية (مش رسالة نظام).
  ChatMessage? get lastMessage {
    for (final m in session.messages.reversed) {
      if (m.kind != MessageKind.system) return m;
    }
    return null;
  }

  Timer? _saveTimer;
  int _lastCount = 0;
}

/// محادثة خاصة مع شخص (مشفرة من طرف لطرف، وممكن تعدّي على أجهزة تانية في النص).
class DirectChat extends Conversation {
  DirectChat(super.hub, {required this.peerId, required this.publicKey, required String name, required int color, String? avatar})
      : _title = name,
        _color = color,
        _avatar = avatar;

  final String peerId;

  /// مفتاح هوية الشخص (null = لسه معرفناهوش، هنتأكد منه وقت الاتصال).
  Uint8List? publicKey;

  String _title;
  int _color;
  String? _avatar;

  @override
  late final ChatSession session;

  /// المكالمات (الواي فاي بس) — بتتجهز أول مرة نحتاجها.
  CallController? call;

  /// وسيلة الاتصال الحالية بتدعم المكالمات؟
  bool get canCall {
    final l = hub.link;
    if (l == null || !l.supportsCalls) return false;
    if (l is! DualLink) return true;
    // المكالمة محتاجة نفس شبكة الواي فاي (مبتعدّيش على البلوتوث)
    final direct = hub.router?.linkOf(peerId);
    return direct != null && l.isWifi(direct);
  }

  late final PeerLink _peer;
  int _attempts = 0;
  Timer? _redial;

  /// المحادثة دي فيها نشاط (أنا فتحتها أو هو): نحافظ على الاتصال.
  bool active = false;

  /// أنا اللي فتحتها (فتظهر في القايمة حتى لو لسه فاضية).
  bool opened = false;

  @override
  String get id => peerId;

  @override
  bool get isGroup => false;

  @override
  String get title => _title;

  @override
  int get color => _color;

  @override
  String? get avatar => _avatar;

  /// الشخص واصلين له دلوقتي (مباشرة أو عن طريق أجهزة تانية).
  bool get online => hub.router?.reachable(peerId) ?? false;

  bool get blocked => ChatStore.instance.blocked.contains(peerId);

  /// يفتح قناة مشفرة مع الشخص (لو واصلين له ومفيش قناة شغالة).
  void connect() {
    active = true;
    if (hub.router == null || !online || blocked) return;
    _peer.dial();
  }

  void _onClosed(String reason) {
    _redial?.cancel();
    if (!active || reason == 'protocol' || reason == 'bye' || reason == 'local') return;
    // الاتصال وقع والشخص لسه موجود: نجرب تاني (بمهلة بتزيد)
    if (_attempts >= 4) return;
    final wait = Duration(seconds: 2 + _attempts * 4);
    _attempts++;
    _redial = Timer(wait, () {
      if (online && session.state == SessionState.disconnected) connect();
    });
  }

  void _dispose() {
    _redial?.cancel();
    _saveTimer?.cancel();
    call?.dispose();
    session.dispose();
  }
}

/// طلب انضمام لجروب (بيظهر لصاحب الجروب).
class JoinRequest {
  JoinRequest(this.groupId, this.nodeId, this.name, this.color, this.avatar);
  final String groupId;
  final String nodeId;
  final String name;
  final int color;
  final String? avatar;
}

/// جروب أنا عضو فيه.
class GroupChat extends Conversation {
  GroupChat(super.hub, this.info);

  final GroupInfo info;

  @override
  late final GroupSession session;

  @override
  String get id => info.id;

  @override
  bool get isGroup => true;

  @override
  String get title => info.name;

  @override
  int get color => int.parse(info.id.substring(0, 6), radix: 16);

  @override
  String? get avatar => null;

  bool get iAmOwner => info.owner == hub.myId;

  /// طلبات انضمام مستنية موافقتي (لو أنا صاحب الجروب).
  final List<JoinRequest> requests = [];

  /// الأعضاء اللي واصلين لهم دلوقتي.
  List<MeshNode> get members => hub.membersOf(info.id);

  void _dispose() {
    _saveTimer?.cancel();
    session.dispose();
  }
}

/// جروب ظاهر حواليك ولسه مدخلتوش.
class NearbyGroup {
  NearbyGroup(this.ad, this.members);
  final GroupAd ad;
  final int members;
}

/// مركز الشات: الشبكة (Mesh) + المحادثات + الجروبات + الإشعارات.
///
/// بيشتغل لما المستخدم يختار بلوتوث أو واي فاي، وبيفضل شغال (بخدمة في المقدمة)
/// لحد ما يرجع لصفحة الاختيار أو يقفل التطبيق.
class ChatHub extends ChangeNotifier with WidgetsBindingObserver {
  ChatHub._() {
    WidgetsBinding.instance.addObserver(this);
    AppSettings.instance.addListener(_onSettingsChanged);
    ProfileStore.instance.addListener(_onProfileChanged);
  }
  static final ChatHub instance = ChatHub._();

  final ChatStore _store = ChatStore.instance;

  TransportKind? kind;
  MeshLink? link;
  MeshRouter? router;

  final Map<String, DirectChat> _directs = {};
  final Map<String, GroupChat> _groups = {};

  /// جروبات بعتنا طلب انضمام ليها ومستنيين الرد.
  final Set<String> pendingJoins = {};

  /// آخر نتيجة لطلب انضمام (للواجهة): معرّف الجروب ← اتقبل؟
  final StreamController<(GroupAd, bool)> _joinResults = StreamController.broadcast();
  Stream<(GroupAd, bool)> get joinResults => _joinResults.stream;

  final Map<String, GroupAd> _requestedAds = {};
  final Map<String, DateTime> _avatarAsked = {};
  Conversation? _visible;
  bool _foreground = true;
  bool _pendingCallScreen = false;
  DirectChat? _callChat;
  bool _disposed = false;

  /// لو التطبيق مقفول بالرقم السري: شاشة المكالمة تستنى لحد ما يتفتح.
  bool Function() isLocked = () => false;

  Profile get _me => ProfileStore.instance.current!;
  String get myId => _me.id;
  int get myColor => _me.color;
  String? get myAvatar => _me.avatarHash;
  bool get running => router != null;

  // ---------------- التشغيل ----------------

  /// يبدأ الشبكة على البلوتوث أو الواي فاي.
  Future<void> start(TransportKind k) async {
    await stop();
    await _store.load();
    kind = k;
    final MeshLink l = switch (k) {
      TransportKind.wifi => LanLink(myId),
      TransportKind.bluetooth => NearbyLink(myId),
      TransportKind.both => DualLink(myId),
    };
    link = l;
    l.addListener(notifyListeners);
    final r = MeshRouter(link: l, describe: _describe);
    router = r;
    r
      ..onData = _onData
      ..onGroup = _onGroup
      ..onControl = _onControl
      ..onNodeUp = _onNodeUp
      ..onNodeDown = _onNodeDown
      ..addListener(_onRouterChanged);

    // المحادثات المحفوظة والجروبات اللي أنا فيها
    for (final sc in _store.index.values.toList()) {
      if (sc.isGroup) continue;
      final pk = sc.publicKey;
      final chat = _newDirect(
        sc.id,
        pk == null ? null : base64.decode(pk),
        sc.name,
        sc.color,
        sc.avatar,
      )
        ..saveOverride = sc.saveOverride
        ..unread = sc.unread
        ..lastActivity = DateTime.fromMillisecondsSinceEpoch(sc.lastActivity);
      chat.session.verifiedPeerKey = sc.verifiedKey;
      await _loadSaved(chat);
    }
    for (final g in _store.groups.values.toList()) {
      final chat = _newGroup(g);
      final sc = _store.index[g.id];
      if (sc != null) {
        chat
          ..saveOverride = sc.saveOverride
          ..unread = sc.unread
          ..lastActivity = DateTime.fromMillisecondsSinceEpoch(sc.lastActivity);
        await _loadSaved(chat);
      }
    }
    notifyListeners();

    // إذن الإشعارات (أندرويد 13+) — للإشعار الثابت وإشعار الرسايل
    try {
      final st = await Permission.notification.status;
      if (!st.isGranted && !st.isPermanentlyDenied) await Permission.notification.request();
    } catch (_) {}
    await SystemBridge.startChatService();
    await r.start();
    notifyListeners();
  }

  /// يقفل الشبكة. المحادثات اللي مش محفوظة بتتمسح.
  Future<void> stop() async {
    final r = router;
    final l = link;
    if (r == null || l == null) return;
    router = null;
    link = null;
    kind = null;
    _visible = null;
    _pendingCallScreen = false;
    _callChat = null;
    pendingJoins.clear();
    _requestedAds.clear();
    // نحفظ آخر حالة وبعدين نبلّغ الناس إننا خارجين
    for (final c in [..._directs.values, ..._groups.values]) {
      c._saveTimer?.cancel();
      await _persist(c);
    }
    try {
      await Future.wait([
        for (final c in _directs.values) c.session.detach(),
      ]).timeout(const Duration(milliseconds: 1200));
    } catch (_) {}
    for (final c in _directs.values) {
      c._dispose();
    }
    for (final g in _groups.values) {
      g._dispose();
    }
    _directs.clear();
    _groups.clear();
    r.removeListener(_onRouterChanged);
    l.removeListener(notifyListeners);
    await r.stop();
    r.dispose();
    l.dispose();
    await SystemBridge.stopChatService();
    await SystemBridge.clearNotifications();
    notifyListeners();
  }

  Map<String, dynamic> _describe() => {
        'n': _me.name,
        'c': _me.color,
        'k': base64.encode(_me.publicKey),
        'a': ?_me.avatarHash,
        'g': [for (final g in _groups.values.take(16)) g.info.ad.toWire()],
      };

  // ---------------- القوايم (للواجهة) ----------------

  /// كل المحادثات (الأحدث فوق).
  List<Conversation> get conversations {
    final list = <Conversation>[
      ..._directs.values.where((c) => c.lastMessage != null || c.opened),
      ..._groups.values,
    ];
    list.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return list;
  }

  List<DirectChat> get directChats => conversations.whereType<DirectChat>().toList();
  List<GroupChat> get groupChats => conversations.whereType<GroupChat>().toList();

  /// الناس اللي واصلين لهم دلوقتي.
  List<MeshNode> get people {
    final list = (router?.nodes.values ?? const <MeshNode>[])
        .where((n) => !_store.blocked.contains(n.id))
        .toList();
    list.sort((a, b) {
      final h = a.hops.compareTo(b.hops);
      return h != 0 ? h : a.name.compareTo(b.name);
    });
    return list;
  }

  /// جروبات ظاهرة حواليك ومدخلتهاش.
  List<NearbyGroup> get nearbyGroups {
    final ads = <String, GroupAd>{};
    final count = <String, int>{};
    for (final n in router?.nodes.values ?? const <MeshNode>[]) {
      if (_store.blocked.contains(n.id)) continue;
      for (final g in n.groups) {
        if (_groups.containsKey(g.id)) continue;
        ads.putIfAbsent(g.id, () => g);
        count[g.id] = (count[g.id] ?? 0) + 1;
      }
    }
    final list = [for (final a in ads.values) NearbyGroup(a, count[a.id] ?? 0)];
    list.sort((a, b) => a.ad.name.compareTo(b.ad.name));
    return list;
  }

  List<MeshNode> membersOf(String groupId) => [
        for (final n in router?.nodes.values ?? const <MeshNode>[])
          if (n.groups.any((g) => g.id == groupId)) n,
      ];

  int get totalUnread =>
      _directs.values.fold(0, (s, c) => s + c.unread) + _groups.values.fold(0, (s, c) => s + c.unread);

  int get directUnread => _directs.values.fold(0, (s, c) => s + c.unread);
  int get groupUnread =>
      _groups.values.fold(0, (s, c) => s + c.unread) + _groups.values.fold(0, (s, c) => s + c.requests.length);

  DirectChat? directFor(String peerId) => _directs[peerId];
  GroupChat? groupFor(String groupId) => _groups[groupId];
  MeshNode? nodeFor(String id) => router?.nodes[id];

  // ---------------- المحادثات الخاصة ----------------

  DirectChat _newDirect(String peerId, Uint8List? pub, String name, int color, String? avatar) {
    final l = link!;
    final chat = DirectChat(this, peerId: peerId, publicKey: pub, name: name, color: color, avatar: avatar);
    final s = ChatSession(
      myName: _me.name,
      allowVideo: l.supportsVideo,
      maxFileBytes: l.directFileLimit,
      identity: _me.keyPair,
      myStaticKey: _me.publicKey,
      expectedPeerKey: pub,
      peerName: name,
    )..nameFromNetwork = true;
    chat.session = s;
    final r = router!;
    chat._peer = PeerLink(
      myId: myId,
      peerId: peerId,
      session: s,
      send: (body) => r.sendData(peerId, body),
      maxFrame: () => r.maxFrame,
    );
    s
      ..verifyPeer = (key) async {
        final bytes = base64.decode(key);
        if (await Profile.idOf(bytes) != peerId) return false;
        chat.publicKey ??= bytes;
        return true;
      }
      ..onChannelClosed = chat._onClosed
      ..onIncomingMessage = ((m) => _onIncoming(chat, m))
      ..addListener(() => _onSessionChanged(chat));
    if (l.supportsCalls) {
      // أول إشارة مكالمة توصل بتجهّز المتحكم وبعدين بتتسلّمله
      late final void Function(Map<String, dynamic>) first;
      first = (signal) {
        ensureCall(chat);
        // المتحكم بدّل المعالج بتاعه مكان ده
        if (!identical(s.onCallSignal, first)) s.onCallSignal?.call(signal);
      };
      s.onCallSignal = first;
    }
    _directs[peerId] = chat;
    return chat;
  }

  /// يفتح (أو ينشئ) محادثة خاصة مع شخص ظاهر في الشبكة.
  DirectChat? openDirect(String peerId) {
    var chat = _directs[peerId];
    if (chat == null) {
      final node = router?.nodes[peerId];
      if (node == null || link == null) return null;
      chat = _newDirect(peerId, node.publicKey, node.name, node.color, node.avatar);
      chat.lastActivity = DateTime.now();
    }
    chat
      ..opened = true
      .._attempts = 0
      ..connect();
    notifyListeners();
    return chat;
  }

  void _onData(String src, String body) {
    if (_store.blocked.contains(src)) return;
    var chat = _directs[src];
    if (chat == null) {
      if (!PeerLink.isHello(body)) return;
      final node = router?.nodes[src];
      chat = _newDirect(src, node?.publicKey, node?.name ?? 'شخص قريب', node?.color ?? 0, node?.avatar);
      chat.lastActivity = DateTime.now();
    }
    if (chat._peer.onFrame(body)) chat.active = true;
  }

  void _onNodeUp(MeshNode n) {
    _syncNode(n);
    final chat = _directs[n.id];
    if (chat != null && chat.active && chat.session.state != SessionState.ready) {
      chat._attempts = 0;
      // صاحب المعرّف الأصغر بيبدأ على طول، والتاني بعد لحظة لو مفيش حاجة حصلت
      final delay = myId.compareTo(n.id) < 0 ? Duration.zero : const Duration(seconds: 3);
      chat._redial?.cancel();
      chat._redial = Timer(delay, () {
        if (chat.online && chat.session.state != SessionState.ready) chat.connect();
      });
    }
    // صاحب جروب كنا مستنيين نبعتله طلب
    for (final id in pendingJoins.toList()) {
      final ad = _requestedAds[id];
      if (ad != null && ad.owner == n.id) router?.sendControl(n.id, {'t': 'gj', 'g': id}).catchError((Object _) {});
    }
  }

  void _onNodeDown(MeshNode n) {
    final chat = _directs[n.id];
    if (chat != null) {
      chat._redial?.cancel();
      chat.session.detach(sayBye: false);
    }
    for (final g in _groups.values) {
      g.requests.removeWhere((r) => r.nodeId == n.id);
    }
  }

  /// الاسم/اللون/الصورة اتغيروا عند حد: نحدّث محادثته.
  void _syncNode(MeshNode n) {
    final chat = _directs[n.id];
    if (chat != null) {
      final changed = chat._title != n.name || chat._color != n.color || chat._avatar != n.avatar;
      chat
        .._title = n.name
        .._color = n.color
        .._avatar = n.avatar
        ..publicKey ??= n.publicKey;
      chat.session.peerName = n.name;
      if (changed) _schedulePersist(chat);
    }
    final a = n.avatar;
    if (a != null && !Avatars.has(a)) {
      final last = _avatarAsked[a];
      if (last == null || DateTime.now().difference(last) > const Duration(seconds: 20)) {
        _avatarAsked[a] = DateTime.now();
        router?.sendControl(n.id, {'t': 'av?', 'h': a}).catchError((Object _) {});
      }
    }
  }

  void _onRouterChanged() {
    for (final n in router?.nodes.values ?? const <MeshNode>[]) {
      _syncNode(n);
    }
    notifyListeners();
  }

  // ---------------- الجروبات ----------------

  GroupChat _newGroup(GroupInfo info) {
    final l = link!;
    final r = router!;
    final chat = GroupChat(this, info);
    final s = GroupSession(
      groupId: info.id,
      groupKey: info.key,
      myId: myId,
      myName: _me.name,
      transmit: (body) => r.sendGroup(info.id, body),
      online: () => r.neighborCount > 0,
      chunkSize: ChatSession.chunkSizeFor(r.maxFrame).clamp(4096, 48 * 1024),
      pacing: l.floodPacing,
      allowVideo: l.supportsVideo,
      maxFileBytes: l.groupFileLimit,
    );
    chat.session = s;
    s
      ..peerName = info.name
      ..onIncomingMessage = ((m) => _onIncoming(chat, m))
      ..addListener(() => _onSessionChanged(chat));
    _groups[info.id] = chat;
    return chat;
  }

  Future<GroupChat> _enter(GroupInfo info, {required bool announce}) async {
    _store.groups[info.id] = info;
    await _store.saveGroups();
    final chat = _newGroup(info)..lastActivity = DateTime.now();
    pendingJoins.remove(info.id);
    _requestedAds.remove(info.id);
    router?.announce();
    if (announce) unawaited(chat.session.announce('join'));
    notifyListeners();
    return chat;
  }

  /// ينشئ جروب جديد (عام / بكلمة سر / بطلب انضمام).
  Future<GroupChat> createGroup({required String name, required GroupMode mode, String? password}) async {
    final info = await GroupInfo.create(name: name, mode: mode, owner: myId, password: password);
    final chat = await _enter(info, announce: false);
    chat.session.addSystem(switch (mode) {
      GroupMode.open => 'الجروب اتعمل — أي حد قريب يقدر يدخل',
      GroupMode.password => 'الجروب اتعمل — الدخول بكلمة السر',
      GroupMode.ask => 'الجروب اتعمل — الدخول بموافقتك',
    });
    return chat;
  }

  /// يدخل جروب عام، أو جروب بكلمة سر. يرجّع الجروب أو رسالة خطأ.
  Future<(GroupChat?, String?)> joinGroup(GroupAd ad, {String? password}) async {
    final existing = _groups[ad.id];
    if (existing != null) return (existing, null);
    if (router == null) return (null, 'الشبكة مش شغالة');
    final Uint8List key;
    switch (ad.mode) {
      case GroupMode.open:
        key = await GroupInfo.openKey(ad.id);
      case GroupMode.password:
        key = await GroupInfo.passwordKey(ad.id, password ?? '');
        if (!await GroupInfo.matches(ad, key)) return (null, 'كلمة السر غلط');
      case GroupMode.ask:
        return (null, 'الجروب ده محتاج موافقة صاحبه');
    }
    return (await _enter(await GroupInfo.fromAd(ad, key), announce: true), null);
  }

  /// يبعت طلب انضمام لصاحب الجروب. يرجّع رسالة خطأ أو null.
  Future<String?> requestJoin(GroupAd ad) async {
    final r = router;
    if (r == null) return 'الشبكة مش شغالة';
    if (!r.reachable(ad.owner)) return 'صاحب الجروب مش متصل دلوقتي — جرّب لما يكون قريب';
    pendingJoins.add(ad.id);
    _requestedAds[ad.id] = ad;
    notifyListeners();
    try {
      await r.sendControl(ad.owner, {'t': 'gj', 'g': ad.id});
      return null;
    } catch (_) {
      pendingJoins.remove(ad.id);
      notifyListeners();
      return 'معرفناش نبعت الطلب';
    }
  }

  void cancelJoinRequest(String groupId) {
    pendingJoins.remove(groupId);
    _requestedAds.remove(groupId);
    notifyListeners();
  }

  /// صاحب الجروب بيرد على طلب انضمام.
  Future<void> answerRequest(JoinRequest req, bool accept) async {
    final g = _groups[req.groupId];
    final r = router;
    if (g == null || r == null) return;
    g.requests.remove(req);
    notifyListeners();
    try {
      if (!accept) {
        await r.sendControl(req.nodeId, {'t': 'gr', 'g': g.id});
        return;
      }
      final node = r.nodes[req.nodeId];
      if (node == null) return;
      // مفتاح الجروب بيتسلّم مشفّر للشخص ده بس
      final pair = await Box.pairKey(_me.keyPair, node.publicKey, 'wasl/group-grant');
      final sealed = await Box.seal(pair, g.info.key, utf8.encode('wasl/grant|${g.id}|${req.nodeId}'));
      await r.sendControl(req.nodeId, {'t': 'gk', 'g': g.id, 'd': base64.encode(sealed)});
    } catch (_) {}
  }

  /// الخروج من جروب (ورسايله بتتمسح من الجهاز).
  Future<void> leaveGroup(GroupChat g) async {
    await g.session.announce('leave');
    _groups.remove(g.id);
    _store.groups.remove(g.id);
    await _store.saveGroups();
    await _store.deleteChat(g.id);
    if (_visible == g) _visible = null;
    g._dispose();
    router?.announce();
    notifyListeners();
  }

  void _onGroup(String groupId, String src, String body) {
    if (_store.blocked.contains(src)) return;
    _groups[groupId]?.session.receive(body);
  }

  Future<void> _onControl(String src, Map<String, dynamic> m) async {
    if (_store.blocked.contains(src)) return;
    final r = router;
    if (r == null) return;
    final gid = '${m['g'] ?? ''}';
    switch (m['t']) {
      case 'av?':
        final h = _me.avatarHash;
        if (h == null || m['h'] != h) return;
        final bytes = await Avatars.read(h);
        if (bytes != null) {
          r.sendControl(src, {'t': 'av', 'h': h, 'd': base64.encode(bytes)}).catchError((Object _) {});
        }
      case 'av':
        final d = m['d'];
        if (d is! String || d.length > Avatars.maxBytes * 2) return;
        try {
          final hash = await Avatars.store(base64.decode(d));
          if (hash != null && hash == m['h']) notifyListeners();
        } catch (_) {}
      case 'gj':
        // حد عايز يدخل جروب أنا صاحبه
        final g = _groups[gid];
        final node = r.nodes[src];
        if (g == null || !g.iAmOwner || node == null) return;
        if (g.info.mode != GroupMode.ask) return;
        if (g.requests.any((q) => q.nodeId == src)) return;
        g.requests.add(JoinRequest(gid, src, node.name, node.color, node.avatar));
        notifyListeners();
        if (!_foreground) SystemBridge.notify('request');
      case 'gk':
        final ad = _requestedAds[gid];
        final node = r.nodes[src];
        final d = m['d'];
        if (ad == null || node == null || ad.owner != src || d is! String || !pendingJoins.contains(gid)) return;
        try {
          final pair = await Box.pairKey(_me.keyPair, node.publicKey, 'wasl/group-grant');
          final key = await Box.open(pair, base64.decode(d), utf8.encode('wasl/grant|$gid|$myId'));
          if (key == null || key.length != 32 || !await GroupInfo.matches(ad, key)) return;
          await _enter(await GroupInfo.fromAd(ad, Uint8List.fromList(key)), announce: true);
          _joinResults.add((ad, true));
        } catch (_) {}
      case 'gr':
        final ad = _requestedAds[gid];
        if (ad == null || ad.owner != src) return;
        pendingJoins.remove(gid);
        _requestedAds.remove(gid);
        notifyListeners();
        _joinResults.add((ad, false));
    }
  }

  // ---------------- الرسايل والإشعارات ----------------

  /// المحادثة المفتوحة قدام المستخدم دلوقتي (null = مفيش).
  void setVisible(Conversation? c) {
    _visible = c;
    for (final d in _directs.values) {
      d.session.viewing = identical(d, c) && _foreground;
    }
    if (c != null) markRead(c);
  }

  void markRead(Conversation c) {
    if (_foreground) c.session.markSeen();
    if (c.unread == 0) return;
    c.unread = 0;
    _schedulePersist(c);
    notifyListeners();
  }

  void _onIncoming(Conversation c, ChatMessage m) {
    if (c is DirectChat) c.active = true;
    if (identical(_visible, c) && _foreground) {
      c.session.markSeen();
      return;
    }
    c.unread++;
    notifyListeners();
    if (!_foreground) SystemBridge.notify('message');
  }

  void _onSessionChanged(Conversation c) {
    final count = c.session.messages.length;
    if (count != c._lastCount) {
      c._lastCount = count;
      if (c.lastMessage != null) c.lastActivity = DateTime.now();
    }
    if (c is DirectChat && c.session.state == SessionState.ready) c._attempts = 0;
    _schedulePersist(c);
    notifyListeners();
  }

  /// متحكم المكالمات للمحادثة دي (بيتعمل أول مرة بس).
  CallController? ensureCall(DirectChat chat) {
    if (!chat.canCall) return null;
    return chat.call ??= CallController(chat.session)..onIncoming = () => _onIncomingCall(chat);
  }

  void _onIncomingCall(DirectChat chat) {
    _callChat = chat;
    if (!_foreground) {
      _pendingCallScreen = true;
      SystemBridge.notify('call');
      return;
    }
    showCallScreen(chat);
  }

  /// يفتح شاشة المكالمة الشغالة مع الشخص ده.
  void showCallScreen(DirectChat chat) {
    final call = chat.call;
    final nav = rootNavigatorKey.currentState;
    if (call == null || nav == null || !call.busy) return;
    _callChat = chat;
    if (isLocked()) {
      _pendingCallScreen = true;
      return;
    }
    _pendingCallScreen = false;
    CallScreen.show(nav, call, chat.title);
  }

  /// القفل اتفتح: لو فيه مكالمة بترن نروحلها.
  void afterUnlock() {
    final chat = _callChat;
    if (chat != null && (chat.call?.busy ?? false)) {
      showCallScreen(chat);
    } else {
      _pendingCallScreen = false;
    }
  }

  bool get hasActiveCall => _callChat?.call?.busy ?? false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached && router != null) {
      for (final c in _directs.values) {
        c.session.detach();
      }
    }
    final fg = state == AppLifecycleState.resumed;
    if (fg == _foreground) return;
    _foreground = fg;
    final v = _visible;
    for (final d in _directs.values) {
      d.session.viewing = identical(d, v) && fg;
    }
    if (fg) {
      SystemBridge.clearNotifications();
      if (v != null) markRead(v);
      if (_pendingCallScreen && _callChat != null) showCallScreen(_callChat!);
    } else {
      // رايح الخلفية: نكتب أي حاجة لسه متكتبتش
      for (final c in [..._directs.values, ..._groups.values]) {
        if (c._saveTimer?.isActive ?? false) {
          c._saveTimer!.cancel();
          _persist(c);
        }
      }
    }
  }

  // ---------------- الحفظ على الجهاز ----------------

  Future<void> _loadSaved(Conversation c) async {
    final messages = await _store.loadMessages(c.id);
    c.session.messages.addAll(messages);
    c._lastCount = c.session.messages.length;
    if (c.saved) {
      c.session
        ..keepMedia = true
        ..fixedMediaDir = _store.mediaDir(c.id);
    }
  }

  void _schedulePersist(Conversation c) {
    if (!c.saved && !_store.index.containsKey(c.id)) return;
    c._saveTimer?.cancel();
    c._saveTimer = Timer(const Duration(milliseconds: 900), () => _persist(c));
  }

  Future<void> _persist(Conversation c) async {
    if (!c.saved) return;
    c.session
      ..keepMedia = true
      ..fixedMediaDir = _store.mediaDir(c.id);
    await _adoptMedia(c);
    _store.index[c.id] = StoredChat(
      id: c.id,
      isGroup: c.isGroup,
      name: c.title,
      color: c.color,
      avatar: c.avatar,
      publicKey: c is DirectChat && c.publicKey != null ? base64.encode(c.publicKey!) : null,
      saveOverride: c.saveOverride,
      unread: c.unread,
      verifiedKey: c.session.verifiedPeerKey,
      lastActivity: c.lastActivity.millisecondsSinceEpoch,
    );
    await _store.saveMessages(c.id, c.session.messages);
    await _store.saveIndex();
  }

  /// ملفات المحادثة المحفوظة بتتنقل لفولدر ثابت (المؤقت بيتمسح).
  Future<void> _adoptMedia(Conversation c) async {
    final dir = _store.mediaDir(c.id);
    for (final m in c.session.messages.toList()) {
      final media = m.media;
      final path = media?.path;
      if (media == null || path == null || !media.ready || m.transferring) continue;
      if (path.startsWith(dir.path)) continue;
      try {
        final src = File(path);
        if (!await src.exists()) continue;
        await dir.create(recursive: true);
        final dot = path.lastIndexOf('.');
        final ext = dot > path.lastIndexOf('/') ? path.substring(dot) : '';
        final dst = '${dir.path}/${Kdf.hex(Kdf.randomBytes(8))}$ext';
        if (m.kind == MessageKind.theirs) {
          try {
            await src.rename(dst);
          } catch (_) {
            await src.copy(dst);
            await ChatSession.deleteQuietly(src);
          }
          media.path = dst;
        } else if (media.size <= 64 * 1024 * 1024) {
          // ملفاتي: نسخة (الأصل في المعرض بيفضل زي ما هو)
          await src.copy(dst);
          media.path = dst;
        }
      } catch (_) {}
    }
  }

  /// يشيل المحادثة من التخزين، وملفاتها ترجع مؤقتة (تتمسح مع قفل التطبيق).
  Future<void> _unpersist(Conversation c) async {
    c._saveTimer?.cancel();
    c.session
      ..keepMedia = false
      ..fixedMediaDir = null;
    final dir = _store.mediaDir(c.id);
    try {
      if (await dir.exists()) {
        final tmp = await c.session.mediaDirectory();
        for (final m in c.session.messages) {
          final media = m.media;
          final path = media?.path;
          if (media == null || path == null || !path.startsWith(dir.path)) continue;
          final dst = '${tmp.path}/${path.split('/').last}';
          try {
            await File(path).rename(dst);
          } catch (_) {
            await File(path).copy(dst);
          }
          media.path = dst;
        }
      }
    } catch (_) {}
    await _store.deleteChat(c.id);
  }

  /// المستخدم بيختار يحفظ المحادثة دي أو يلغي حفظها.
  Future<void> setSaved(Conversation c, bool save) async {
    c.saveOverride = save == AppSettings.instance.saveChats ? null : save;
    if (c.saved) {
      await _persist(c);
    } else {
      await _unpersist(c);
    }
    notifyListeners();
  }

  void _onSettingsChanged() {
    if (router == null) {
      _purgeUnsaved();
      return;
    }
    for (final c in [..._directs.values, ..._groups.values]) {
      final stored = _store.index.containsKey(c.id);
      if (c.saved && !stored) {
        _persist(c);
      } else if (!c.saved && stored) {
        _unpersist(c);
      }
    }
  }

  /// الشبكة مقفولة والمستخدم قفل "حفظ المحادثات": نمسح اللي كان محفوظ بسبب الإعداد العام.
  Future<void> _purgeUnsaved() async {
    if (ProfileStore.instance.current == null) return;
    await _store.load();
    if (AppSettings.instance.saveChats) return;
    for (final c in _store.index.values.toList()) {
      if (c.saveOverride != true) await _store.deleteChat(c.id);
    }
  }

  /// يمسح كل المحادثات والرسايل من الموبايل (الجروبات اللي إنت فيها بتفضل، من غير رسايلها).
  Future<void> wipeAll() async {
    await _store.load();
    for (final c in _directs.values.toList()) {
      await c.session.detach();
      c._dispose();
    }
    _directs.clear();
    for (final g in _groups.values) {
      g._saveTimer?.cancel();
      g.session.clearMessages();
      g
        ..unread = 0
        ..saveOverride = null;
    }
    _visible = null;
    for (final id in _store.index.keys.toList()) {
      await _store.deleteChat(id);
    }
    notifyListeners();
  }

  /// اسم شخص من معرّفه (لو نعرفه).
  String? nameOf(String id) => router?.nodes[id]?.name ?? _directs[id]?.title ?? _store.index[id]?.name;

  List<String> get blockedIds => _store.blocked.toList();

  void _onProfileChanged() {
    final r = router;
    if (r == null) return;
    for (final c in [..._directs.values, ..._groups.values]) {
      c.session.myName = _me.name;
    }
    r.announce();
  }

  /// يمسح رسايل المحادثة (من الشاشة ومن التخزين).
  Future<void> clearMessages(Conversation c) async {
    c.session.clearMessages();
    c.unread = 0;
    if (_store.index.containsKey(c.id)) await _persist(c);
    notifyListeners();
  }

  /// يمسح محادثة خاصة خالص.
  Future<void> deleteDirect(DirectChat c) async {
    await c.session.detach();
    _directs.remove(c.id);
    if (_visible == c) _visible = null;
    c._dispose();
    await _store.deleteChat(c.id);
    notifyListeners();
  }

  Future<void> setBlocked(String peerId, bool blocked) async {
    if (blocked) {
      _store.blocked.add(peerId);
      await _directs[peerId]?.session.detach();
    } else {
      _store.blocked.remove(peerId);
    }
    await _store.saveBlocked();
    notifyListeners();
  }

  bool isBlocked(String peerId) => _store.blocked.contains(peerId);

  /// ملفات مؤقتة من تشغيل قبل كده.
  static Future<void> cleanLeftovers() async {
    try {
      await ChatStore.cleanTemp(await getTemporaryDirectory());
    } catch (_) {}
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    AppSettings.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
