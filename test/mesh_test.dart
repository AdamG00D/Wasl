import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wasl/core/crypto/box.dart';
import 'package:wasl/core/crypto/kdf.dart';
import 'package:wasl/core/profile/profile.dart';
import 'package:wasl/core/storage/chat_store.dart';
import 'package:wasl/core/storage/vault.dart';
import 'package:wasl/features/chat/core/chat_session.dart';
import 'package:wasl/features/groups/group.dart';
import 'package:wasl/features/groups/group_session.dart';
import 'package:wasl/mesh/mesh_router.dart';
import 'package:wasl/mesh/peer_link.dart';

import 'support.dart';

/// جهاز كامل للاختبار: بروفايل + موجّه + محادثات خاصة بنفس منطق التطبيق.
class Device {
  Device(this.profile, this.link, this.root) {
    router = MeshRouter(
      link: link,
      presenceEvery: const Duration(milliseconds: 150),
      nodeTtl: const Duration(milliseconds: 900),
      describe: () => {
        'n': profile.name,
        'c': profile.color,
        'k': base64.encode(profile.publicKey),
        'g': [for (final g in groups.values) g.ad.toWire()],
      },
    );
    router.onData = _onData;
    router.onGroup = (g, src, body) => groupSessions[g]?.receive(src, body);
    router.onControl = (src, m) {
      if (m['t'] == 'ga') onAdminOp(src, '${m['g']}', m['d']);
    };
  }

  /// جروبات اتشلت منها.
  final Set<String> removedFrom = {};
  final List<GroupEffectKind> effects = [];

  /// أمر إدارة مقفول للعضو ده بس (زي ChatHub).
  Future<void> sendOp(GroupInfo info, String to, Map<String, dynamic> op) async {
    final sealed = await GroupOps.seal(
      me: profile.keyPair,
      myId: id,
      peerKey: router.nodes[to]!.publicKey,
      peerId: to,
      groupId: info.id,
      op: {...op, 'n': GroupOps.nextNumber()},
    );
    await router.sendControl(to, {'t': 'ga', 'g': info.id, 'd': sealed});
  }

  Future<void> onAdminOp(String src, String gid, Object? sealed) async {
    final info = groups[gid];
    final node = router.nodes[src];
    if (info == null || node == null) return;
    final op = await GroupOps.open(
      me: profile.keyPair,
      myId: id,
      peerKey: node.publicKey,
      peerId: src,
      groupId: gid,
      sealed: sealed,
    );
    if (op == null) return;
    final e = await info.apply(src, op, myId: id);
    if (e == null) return;
    effects.add(e.kind);
    final s = groupSessions[gid]!;
    if (e.keyChanged) s.updateKey(info.key);
    if (e.kind == GroupEffectKind.removedMe) {
      removedFrom.add(gid);
      groups.remove(gid);
      router.announce();
    }
    if (e.kind == GroupEffectKind.deleted) s.removeByModerator(e.messageId!, e.target!);
  }

  final Profile profile;
  final MemoryLink link;
  final Directory root;
  late final MeshRouter router;
  final Map<String, GroupInfo> groups = {};
  final Map<String, GroupSession> groupSessions = {};
  final Map<String, ChatSession> sessions = {};
  final Map<String, PeerLink> _peers = {};

  String get id => profile.id;

  ChatSession sessionFor(String peer, {List<int>? expected}) => sessions.putIfAbsent(
        peer,
        () => ChatSession(
          myName: profile.name,
          identity: profile.keyPair,
          myStaticKey: profile.publicKey,
          expectedPeerKey: expected,
          mediaRoot: root,
          maxFileBytes: 64 * 1024 * 1024,
        ),
      );

  PeerLink _peer(String peer, {List<int>? expected}) => _peers.putIfAbsent(
        peer,
        () => PeerLink(
          myId: id,
          peerId: peer,
          session: sessionFor(peer, expected: expected),
          send: (b) => router.sendData(peer, b),
          maxFrame: () => router.maxFrame,
        ),
      );

  void dial(String peer, {List<int>? expected}) => _peer(peer, expected: expected).dial();

  void _onData(String src, String body) {
    if (!_peers.containsKey(src) && !PeerLink.isHello(body)) return;
    _peer(src).onFrame(body);
  }

  GroupSession joinGroup(GroupInfo info) {
    groups[info.id] = info;
    final s = GroupSession(
      groupId: info.id,
      groupKey: info.key,
      myId: id,
      myName: profile.name,
      transmit: (b) => router.sendGroup(info.id, b),
      online: () => router.neighborCount > 0,
      chunkSize: ChatSession.chunkSizeFor(router.maxFrame).clamp(4096, 48 * 1024),
      pacing: Duration.zero,
      allowVideo: true,
      maxFileBytes: 8 * 1024 * 1024,
      mediaRoot: root,
      isBanned: info.banned.contains,
      audience: () => [
        for (final n in router.nodes.values)
          if (n.groups.any((g) => g.id == info.id)) n.id,
      ],
    );
    groupSessions[info.id] = s;
    router.announce();
    return s;
  }

  Future<void> close() async {
    for (final s in [...sessions.values, ...groupSessions.values]) {
      s.dispose();
    }
    await router.stop();
    router.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late MemoryNet net;
  final devices = <Device>[];

  Future<Device> device(String name) async {
    final p = await Profile.fromSeed(Kdf.randomBytes(32), name: name, color: 1);
    final d = Device(p, net.add(p.id), tmp);
    devices.add(d);
    await d.router.start();
    return d;
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('wasl_test_');
    net = MemoryNet();
  });

  tearDown(() async {
    for (final d in devices) {
      await d.close();
    }
    devices.clear();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  group('الشبكة (Mesh)', () {
    test('الأجهزة بتشوف بعض عبر جهاز في النص وبتختفي لما تبعد', () async {
      final a = await device('أحمد'), b = await device('بسمة'), c = await device('كريم');
      net.connect(a.id, b.id);
      net.connect(b.id, c.id);
      await waitFor(() => a.router.reachable(c.id) && c.router.reachable(a.id), what: 'a<->c');
      expect(a.router.nodes[c.id]!.name, 'كريم');
      expect(a.router.nodes[c.id]!.hops, 2);
      expect(a.router.nodes[b.id]!.hops, 1);
      expect(a.router.isDirect(c.id), isFalse);

      net.disconnect(b.id, c.id);
      await waitFor(() => !a.router.reachable(c.id), what: 'c gone');
      expect(a.router.reachable(b.id), isTrue);
    });

    test('رسالة تحكم بتوصل لجهاز بعيد عن طريق اتنين في النص', () async {
      final a = await device('a'), b = await device('b'), c = await device('c'), d = await device('d');
      net.connect(a.id, b.id);
      net.connect(b.id, c.id);
      net.connect(c.id, d.id);
      await waitFor(() => a.router.reachable(d.id) && d.router.reachable(a.id));
      Map<String, dynamic>? got;
      String? from;
      d.router.onControl = (src, m) {
        from = src;
        got = m;
      };
      await a.router.sendControl(d.id, {'t': 'ping', 'x': 7});
      await waitFor(() => got != null);
      expect(from, a.id);
      expect(got!['x'], 7);
    });

    test('معرّف منتحل (مش هاش المفتاح) بيترفض', () async {
      final a = await device('a');
      final fake = net.add('00000000deadbeef');
      final r = MeshRouter(
        link: fake,
        presenceEvery: const Duration(milliseconds: 100),
        describe: () => {'n': 'مزيف', 'c': 0, 'k': base64.encode(Kdf.randomBytes(32))},
      );
      await r.start();
      net.connect(a.id, fake.myId);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(a.router.nodes, isEmpty);
      await r.stop();
      r.dispose();
    });

    test('جهاز اختفى من غير ما يقفل الاتصال: وصلته بتتقفل ويقدر يرجع', () async {
      final a = await device('a'), b = await device('b');
      net.connect(a.id, b.id);
      await waitFor(() => a.router.isDirect(b.id) && b.router.isDirect(a.id));
      b.link.dead = true;
      await waitFor(() => !a.router.isDirect(b.id) && !a.router.reachable(b.id), what: 'dead link dropped');
      b.link.dead = false;
      net.connect(b.id, a.id);
      await waitFor(() => a.router.isDirect(b.id) && a.router.reachable(b.id), what: 'back');
    });

    test('شبكة كاملة: البث مبيتكررش من غير لازمة', () async {
      final ds = [for (var i = 0; i < 5; i++) await device('d$i')];
      for (var i = 0; i < ds.length; i++) {
        for (var j = i + 1; j < ds.length; j++) {
          net.connect(ds[i].id, ds[j].id);
        }
      }
      await waitFor(() => ds.every((d) => d.router.nodes.length == 4));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final before = ds.map((d) => d.link.sent).toList();
      final info = await GroupInfo.create(name: 'g', mode: GroupMode.open, owner: ds[0].id);
      final sessions = [for (final d in ds) d.joinGroup(info)];
      await sessions[0].send('هاي');
      await waitFor(() => sessions.skip(1).every((s) => s.messages.any((m) => m.text == 'هاي')));
      // الباقيين كلهم جيران اللي بعت: محدش منهم يعيد إرسال رسالة الجروب
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final groupFrames = [for (var i = 1; i < ds.length; i++) ds[i].link.sent - before[i]];
      // مسموح بس بإطارات "أنا موجود" الدورية
      expect(groupFrames.every((n) => n < 40), isTrue, reason: '$groupFrames');
    });
  });

  group('المحادثة الخاصة فوق الشبكة', () {
    test('رسايل ورد وتعديل وحذف بين جهازين بينهم جهاز تالت', () async {
      final a = await device('أحمد'), b = await device('بسمة'), c = await device('كريم');
      net.connect(a.id, b.id);
      net.connect(b.id, c.id);
      await waitFor(() => a.router.reachable(c.id) && c.router.reachable(a.id));

      a.dial(c.id, expected: c.profile.publicKey);
      final sa = a.sessionFor(c.id);
      await waitFor(() => sa.canSend && (c.sessions[a.id]?.canSend ?? false), what: 'handshake');
      final sc = c.sessions[a.id]!;
      expect(sa.safetyCode, sc.safetyCode);
      expect(sc.peerName, 'أحمد');
      // الجهاز اللي في النص معندوش أي جلسة: هو بيوصّل بس
      expect(b.sessions, isEmpty);

      await sa.send('إزيك');
      await waitFor(() => sc.messages.any((m) => m.text == 'إزيك'));
      final got = sc.messages.firstWhere((m) => m.text == 'إزيك');
      await waitFor(() => sa.messages.last.status == MessageStatus.delivered);

      await sc.send('تمام', reply: sc.replyTo(got));
      await waitFor(() => sa.messages.any((m) => m.text == 'تمام'));
      expect(sa.messages.last.reply!.toMine, isTrue);

      final mine = sa.messages.firstWhere((m) => m.text == 'إزيك');
      await sa.edit(mine, 'إزيك يا كريم');
      await waitFor(() => got.text == 'إزيك يا كريم' && got.edited);
      await sa.deleteForEveryone(mine);
      await waitFor(() => !sc.messages.contains(got));
    });

    test('"بيكتب..." و"اتقرت" بيوصلوا للطرف التاني', () async {
      final a = await device('a'), b = await device('b');
      net.connect(a.id, b.id);
      await waitFor(() => a.router.reachable(b.id) && b.router.reachable(a.id));
      a.dial(b.id);
      final sa = a.sessionFor(b.id);
      await waitFor(() => sa.canSend && (b.sessions[a.id]?.canSend ?? false));
      final sb = b.sessions[a.id]!;

      sb.userTyping();
      await waitFor(() => sa.peerTyping, what: 'بيكتب');

      await sa.send('هاي');
      await waitFor(() => sb.messages.any((m) => m.text == 'هاي'));
      final mine = sa.messages.firstWhere((m) => m.kind == MessageKind.mine);
      await waitFor(() => mine.status == MessageStatus.delivered, what: 'وصلت');
      sb.markSeen();
      await waitFor(() => mine.status == MessageStatus.read, what: 'اتقرت');
    });

    test('تفاعل بإيموجي ورسالة محوّلة في الخاص', () async {
      final a = await device('a'), b = await device('b');
      net.connect(a.id, b.id);
      await waitFor(() => a.router.reachable(b.id) && b.router.reachable(a.id));
      a.dial(b.id);
      final sa = a.sessionFor(b.id);
      await waitFor(() => sa.canSend && (b.sessions[a.id]?.canSend ?? false));
      final sb = b.sessions[a.id]!;

      await sa.send('شوف دي', forwarded: true);
      await waitFor(() => sb.messages.any((m) => m.text == 'شوف دي'));
      final got = sb.messages.last, mine = sa.messages.last;
      expect(got.forwarded, isTrue);

      await sb.react(got, '❤️');
      await waitFor(() => mine.reactions[ChatSession.reactPeer] == '❤️');
      expect(got.reactions[ChatSession.reactMe], '❤️');
      await sa.react(mine, '😂');
      await waitFor(() => got.reactions[ChatSession.reactPeer] == '😂');
      await sb.react(got, null);
      await waitFor(() => !mine.reactions.containsKey(ChatSession.reactPeer));
      expect(mine.reactions[ChatSession.reactMe], '😂');

      // بيتحفظوا مع الرسالة
      final back = ChatMessage.fromJson(jsonDecode(jsonEncode(mine.toJson())))!;
      expect(back.forwarded, isTrue);
      expect(back.reactions, mine.reactions);
    });

    test('ملف بيتنقل كامل وسليم عبر جهاز في النص', () async {
      final a = await device('a'), b = await device('b'), c = await device('c');
      net.connect(a.id, b.id);
      net.connect(b.id, c.id);
      await waitFor(() => a.router.reachable(c.id) && c.router.reachable(a.id));
      a.dial(c.id);
      final sa = a.sessionFor(c.id);
      await waitFor(() => sa.canSend && (c.sessions[a.id]?.canSend ?? false));
      final sc = c.sessions[a.id]!;

      final rnd = Random(5);
      final bytes = Uint8List.fromList(List.generate(300 * 1024 + 123, (_) => rnd.nextInt(256)));
      final file = File('${tmp.path}/doc.pdf')..writeAsBytesSync(bytes);
      expect(await sa.sendMedia(file, MediaKind.file, name: 'doc.pdf'), isNull);
      await waitFor(() => sc.messages.any((m) => m.media?.ready ?? false), timeout: const Duration(seconds: 40));
      final m = sc.messages.firstWhere((m) => m.media != null);
      expect(File(m.media!.path!).readAsBytesSync(), bytes);
      expect(m.media!.name, 'doc.pdf');
      await waitFor(() => sa.messages.last.status == MessageStatus.delivered);
    });

    test('لو الشخص مش صاحب المفتاح المتوقع الاتصال بيترفض', () async {
      final a = await device('a'), b = await device('b');
      net.connect(a.id, b.id);
      await waitFor(() => a.router.reachable(b.id) && b.router.reachable(a.id));
      String? reason;
      final sa = a.sessionFor(b.id, expected: Kdf.randomBytes(32))..onChannelClosed = (r) => reason = r;
      a.dial(b.id, expected: Kdf.randomBytes(32));
      await waitFor(() => reason != null);
      expect(reason, 'protocol');
      expect(sa.canSend, isFalse);
    });

    test('الاتنين بدأوا في نفس اللحظة: بيتفقوا على جلسة واحدة', () async {
      final a = await device('a'), b = await device('b');
      net.connect(a.id, b.id);
      await waitFor(() => a.router.reachable(b.id) && b.router.reachable(a.id));
      a.dial(b.id);
      b.dial(a.id);
      await waitFor(() => a.sessionFor(b.id).canSend && b.sessionFor(a.id).canSend, what: 'both ready');
      await a.sessionFor(b.id).send('واحد');
      await waitFor(() => b.sessionFor(a.id).messages.any((m) => m.text == 'واحد'));
    });

    test('الاتصال بيرجع بعد ما الوصلة تقع والرسايل بتكمّل', () async {
      final a = await device('a'), b = await device('b');
      net.connect(a.id, b.id);
      await waitFor(() => a.router.reachable(b.id) && b.router.reachable(a.id));
      a.dial(b.id);
      final sa = a.sessionFor(b.id);
      await waitFor(() => sa.canSend && (b.sessions[a.id]?.canSend ?? false));
      final sb = b.sessions[a.id]!;
      await sa.send('قبل');
      await waitFor(() => sb.messages.any((m) => m.text == 'قبل'));

      net.disconnect(a.id, b.id);
      await sa.detach(sayBye: false);
      await sb.detach(sayBye: false);
      expect(sa.canSend, isFalse);

      // الوصلة واقعة: المحاولة بتفشل على طول (مش بعد مهلة المصافحة)
      String? reason;
      sb.onChannelClosed = (r) => reason = r;
      b.dial(a.id);
      await waitFor(() => reason != null, timeout: const Duration(seconds: 2), what: 'fast fail');
      expect(reason, 'lost');
      expect(sb.state, SessionState.disconnected);

      net.connect(a.id, b.id);
      await waitFor(() => a.router.isDirect(b.id) && b.router.isDirect(a.id), what: 'see again');
      b.dial(a.id);
      await waitFor(() => sa.canSend && sb.canSend, what: 'reconnect');
      await sb.send('بعد');
      await waitFor(() => sa.messages.any((m) => m.text == 'بعد'));
      // الرسايل القديمة لسه موجودة
      expect(sa.messages.any((m) => m.text == 'قبل'), isTrue);
    });
  });

  group('الجروبات', () {
    test('رسالة جروب بتوصل لكل الأعضاء حتى البعيد، واللي مش عضو مبيقراش', () async {
      final a = await device('أحمد'), b = await device('بسمة'), c = await device('كريم');
      net.connect(a.id, b.id);
      net.connect(b.id, c.id);
      await waitFor(() => a.router.reachable(c.id) && c.router.reachable(a.id));
      final info = await GroupInfo.create(name: 'الشلة', mode: GroupMode.ask, owner: a.id);
      final ga = a.joinGroup(info);
      // بسمة مش عضوة (بس بتوصّل)، كريم عضو
      final gc = c.joinGroup(info);
      await waitFor(() => c.router.nodes[a.id]!.groups.any((g) => g.id == info.id));
      expect(c.router.nodes[a.id]!.groups.first.name, 'الشلة');

      await ga.send('أهلاً يا شباب');
      await waitFor(() => gc.messages.any((m) => m.text == 'أهلاً يا شباب'));
      final m = gc.messages.last;
      expect(m.sender, 'أحمد');
      expect(m.senderId, a.id);
      expect(b.groupSessions, isEmpty);

      // رد في الجروب: اسم صاحب الرسالة الأصلية بيوصل
      await gc.send('أهلاً', reply: gc.replyTo(m));
      await waitFor(() => ga.messages.any((x) => x.text == 'أهلاً'));
      expect(ga.messages.last.reply!.toMine, isTrue);

      // تعديل وحذف
      final mine = ga.messages.firstWhere((x) => x.kind == MessageKind.mine);
      await ga.edit(mine, 'أهلاً يا جماعة');
      await waitFor(() => m.text == 'أهلاً يا جماعة');
      await ga.deleteForEveryone(mine);
      await waitFor(() => !gc.messages.contains(m));
    });

    test('في الجروب: بيكتب، اتقرت من مين، تفاعل، ومنشن', () async {
      final a = await device('أحمد'), b = await device('بسمة'), c = await device('كريم');
      net.connect(a.id, b.id);
      net.connect(b.id, c.id);
      await waitFor(() => a.router.reachable(c.id) && c.router.reachable(a.id));
      final info = await GroupInfo.create(name: 'g', mode: GroupMode.open, owner: a.id);
      final ga = a.joinGroup(info), gb = b.joinGroup(info), gc = c.joinGroup(info);
      await waitFor(() => a.router.nodes.values.every((n) => n.groups.isNotEmpty));

      gc.userTyping();
      await waitFor(() => ga.peerTyping && gb.peerTyping, what: 'بيكتب');
      expect(ga.typingNames, ['كريم']);

      await ga.send('يا @بسمة تعالي', mentions: {b.id: 'بسمة', c.id: 'كريم'});
      await waitFor(() => gb.messages.isNotEmpty && gc.messages.isNotEmpty);
      // المنشن اللي اسمه مش في النص بيتشال
      expect(gb.messages.last.mentions.keys, [b.id]);
      expect(gb.messages.last.mentionsMe, isTrue);
      expect(gc.messages.last.mentionsMe, isFalse);

      final mine = ga.messages.last;
      expect(mine.status, MessageStatus.sent);
      gb.markSeen();
      await waitFor(() => mine.readBy.contains(b.id), what: 'بسمة قرت');
      expect(mine.status, MessageStatus.delivered); // لسه كريم
      gc.markSeen();
      await waitFor(() => mine.status == MessageStatus.read, what: 'الكل قرا');
      expect(mine.readBy, {b.id, c.id});

      await gc.react(gc.messages.last, '👍');
      await waitFor(() => mine.reactions[c.id] == '👍' && gb.messages.last.reactions[c.id] == '👍');
      await gc.react(gc.messages.last, '👍'); // نفس الإيموجي تاني = يتشال
      await waitFor(() => mine.reactions.isEmpty);
    });

    test('محدش يبعت في الجروب باسم عضو تاني', () async {
      final a = await device('a'), b = await device('b'), c = await device('c');
      net.connect(a.id, b.id);
      net.connect(a.id, c.id);
      await waitFor(() => a.router.reachable(b.id) && a.router.reachable(c.id));
      final info = await GroupInfo.create(name: 'g', mode: GroupMode.open, owner: a.id);
      final ga = a.joinGroup(info);
      b.joinGroup(info);
      // b بيشفّر بمفتاح الجروب رسالة مكتوب فيها إن اللي بعتها c
      final forged = await Box.seal(
        info.key,
        utf8.encode(jsonEncode({'k': 'msg', 'id': 'x1', 'text': 'مزيفة', 's': c.id, 'n': 'c'})),
        utf8.encode('wasl/group/v1|${info.id}'),
      );
      await b.router.sendGroup(info.id, base64.encode(forged));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(ga.messages, isEmpty);
    });

    test('مفتاح غلط: الرسايل مبتتفكش', () async {
      final a = await device('a'), b = await device('b');
      net.connect(a.id, b.id);
      await waitFor(() => a.router.reachable(b.id) && b.router.reachable(a.id));
      final info = await GroupInfo.create(name: 'سري', mode: GroupMode.password, owner: a.id, password: 'صح');
      final wrongKey = await GroupInfo.passwordKey(info.id, 'غلط');
      expect(await GroupInfo.matches(info.ad, wrongKey), isFalse);
      expect(await GroupInfo.matches(info.ad, await GroupInfo.passwordKey(info.id, 'صح')), isTrue);

      final ga = a.joinGroup(info);
      final gb = b.joinGroup(GroupInfo(
        id: info.id,
        name: info.name,
        mode: info.mode,
        owner: info.owner,
        key: wrongKey,
        check: info.check,
      ));
      await ga.send('سر');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(gb.messages, isEmpty);
    });

    test('ملف في الجروب بيوصل سليم لعضو بعيد', () async {
      final a = await device('a'), b = await device('b'), c = await device('c');
      net.connect(a.id, b.id);
      net.connect(b.id, c.id);
      await waitFor(() => a.router.reachable(c.id) && c.router.reachable(a.id));
      final info = await GroupInfo.create(name: 'g', mode: GroupMode.open, owner: a.id);
      final ga = a.joinGroup(info), gb = b.joinGroup(info), gc = c.joinGroup(info);

      final rnd = Random(9);
      final bytes = Uint8List.fromList(List.generate(120 * 1024 + 77, (_) => rnd.nextInt(256)));
      final file = File('${tmp.path}/pic.jpg')..writeAsBytesSync(bytes);
      expect(await ga.sendMedia(file, MediaKind.image), isNull);
      await waitFor(
        () => [gb, gc].every((g) => g.messages.any((m) => m.media?.ready ?? false)),
        timeout: const Duration(seconds: 30),
      );
      for (final g in [gb, gc]) {
        final m = g.messages.firstWhere((m) => m.media != null);
        expect(File(m.media!.path!).readAsBytesSync(), bytes);
        expect(m.senderId, a.id);
      }
      expect(ga.messages.last.status, MessageStatus.sent);
    });

    test('تسليم مفتاح الجروب مشفّر للعضو الجديد بس', () async {
      final owner = await Profile.fromSeed(Kdf.randomBytes(32), name: 'o', color: 0);
      final member = await Profile.fromSeed(Kdf.randomBytes(32), name: 'm', color: 0);
      final other = await Profile.fromSeed(Kdf.randomBytes(32), name: 'x', color: 0);
      final info = await GroupInfo.create(name: 'g', mode: GroupMode.ask, owner: owner.id);
      final aad = utf8.encode('wasl/grant|${info.id}|${member.id}');
      final sealed = await Box.seal(
        await Box.pairKey(owner.keyPair, member.publicKey, 'wasl/group-grant'),
        info.key,
        aad,
      );
      final opened = await Box.open(await Box.pairKey(member.keyPair, owner.publicKey, 'wasl/group-grant'), sealed, aad);
      expect(opened, info.key);
      expect(await GroupInfo.matches(info.ad, opened!), isTrue);
      final stolen = await Box.open(await Box.pairKey(other.keyPair, owner.publicKey, 'wasl/group-grant'), sealed, aad);
      expect(stolen, isNull);
    });
  });

  group('إدارة الجروب', () {
    /// نسخة مستقلة من معلومات الجروب لكل جهاز (زي ما كل موبايل عنده نسخته).
    GroupInfo copy(GroupInfo i) => GroupInfo.fromJson(jsonDecode(jsonEncode(i.toJson())))!;

    Future<(List<Device>, List<GroupInfo>, List<GroupSession>)> trio(GroupMode mode) async {
      final a = await device('صاحب'), b = await device('بسمة'), c = await device('كريم');
      net.connect(a.id, b.id);
      net.connect(a.id, c.id);
      net.connect(b.id, c.id);
      await waitFor(() => [a, b, c].every((d) => d.router.nodes.length == 2));
      final base = await GroupInfo.create(name: 'الشلة', mode: mode, owner: a.id, password: 'سر');
      if (mode == GroupMode.ask) base.members.addAll([b.id, c.id]);
      final infos = [base, copy(base), copy(base)];
      final sessions = [a.joinGroup(infos[0]), b.joinGroup(infos[1]), c.joinGroup(infos[2])];
      await waitFor(() => [a, b, c].every((d) => d.router.nodes.values.every((n) => n.groups.isNotEmpty)));
      return ([a, b, c], infos, sessions);
    }

    test('صاحب الجروب بيشيل عضو: المفتاح بيتغير والمتشال مبيقراش الجديد', () async {
      final (ds, infos, ss) = await trio(GroupMode.ask);
      final [a, b, c] = ds;
      final [ia, ib, _] = infos;
      final oldKey = base64.encode(ia.key);

      // زي ChatHub.kickMember
      expect(ia.canKick(a.id, c.id), isTrue);
      ia
        ..banned.add(c.id)
        ..members.remove(c.id)
        ..bump();
      for (final to in [b.id, c.id]) {
        await a.sendOp(ia, to, {'op': 'kick', 'id': c.id, 'rev': ia.rev});
      }
      await ia.rotateKey();
      ss[0].updateKey(ia.key);
      await a.sendOp(ia, b.id, {'op': 'key', 'key': base64.encode(ia.key), 'kr': ia.keyRev, 'rev': ia.rev});

      await waitFor(() => c.removedFrom.contains(ia.id), what: 'كريم عرف إنه اتشال');
      await waitFor(() => ib.keyRev == 1 && ib.banned.contains(c.id), what: 'بسمة خدت المفتاح الجديد');
      expect(base64.encode(ib.key), base64.encode(ia.key));
      expect(base64.encode(ib.key), isNot(oldKey));
      expect(ib.digest, ia.digest);

      await ss[0].send('بعد الإزالة');
      await waitFor(() => ss[1].messages.any((m) => m.text == 'بعد الإزالة'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      // جلسة كريم لسه بالمفتاح القديم: مش بتفك الجديد
      expect(ss[2].messages.any((m) => m.text == 'بعد الإزالة'), isFalse);
      // ولو بعت بالمفتاح القديم محدش بيقراه
      await ss[2].send('أنا لسه هنا');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(ss[0].messages.any((m) => m.text == 'أنا لسه هنا'), isFalse);
    });

    test('في الجروب العام: رسايل المتشال بتترمي', () async {
      final (ds, infos, ss) = await trio(GroupMode.open);
      final [a, b, c] = ds;
      final [ia, ib, _] = infos;
      ia
        ..banned.add(c.id)
        ..bump();
      await a.sendOp(ia, b.id, {'op': 'kick', 'id': c.id, 'rev': ia.rev});
      await waitFor(() => ib.banned.contains(c.id));
      // كريم (تطبيق معدّل مثلاً) لسه بيبعت بمفتاح الجروب العام
      await ss[2].send('سامعيني؟');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(ss[0].messages, isEmpty);
      expect(ss[1].messages, isEmpty);
    });

    test('العضو العادي ميقدرش يشيل حد ولا ينتحل صاحب الجروب', () async {
      final (ds, infos, _) = await trio(GroupMode.open);
      final [a, b, c] = ds;
      final [ia, ib, ic] = infos;

      // كريم (عضو عادي) بيبعت أمر إزالة لبسمة
      await c.sendOp(ic, b.id, {'op': 'kick', 'id': b.id});
      await c.sendOp(ic, a.id, {'op': 'kick', 'id': b.id});
      // وبيحاول يخلّي نفسه مدير
      await c.sendOp(ic, a.id, {'op': 'admin', 'id': c.id, 'on': true});
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(b.removedFrom, isEmpty);
      expect(ia.banned, isEmpty);
      expect(ia.admins, isEmpty);

      // انتحال: أمر مقفول بمفتاح كريم بس داخل على إنه من صاحب الجروب
      final forged = await GroupOps.seal(
        me: c.profile.keyPair,
        myId: a.id,
        peerKey: b.profile.publicKey,
        peerId: b.id,
        groupId: ib.id,
        op: {'op': 'kick', 'id': b.id, 'n': GroupOps.nextNumber()},
      );
      await b.onAdminOp(a.id, ib.id, forged);
      expect(b.removedFrom, isEmpty);
      expect(ib.banned, isEmpty);
    });

    test('المدير: يشيل عضو ويمسح رسالته، وميقدرش يقرّب لصاحب الجروب', () async {
      final (ds, infos, ss) = await trio(GroupMode.open);
      final [a, b, c] = ds;
      final [ia, ib, ic] = infos;

      // صاحب الجروب بيخلّي بسمة مديرة
      ia
        ..admins.add(b.id)
        ..bump();
      for (final to in [b.id, c.id]) {
        await a.sendOp(ia, to, {'op': 'admin', 'id': b.id, 'on': true, 'rev': ia.rev});
      }
      await waitFor(() => ib.isAdmin(b.id) && ic.isAdmin(b.id));
      expect(b.effects, contains(GroupEffectKind.promoted));

      // بسمة تمسح رسالة كريم عند الكل
      await ss[2].send('رسالة وحشة');
      await waitFor(() => ss[0].messages.isNotEmpty && ss[1].messages.isNotEmpty);
      final bad = ss[1].messages.last;
      expect(ib.canDelete(b.id, c.id), isTrue);
      ss[1].removeByModerator(bad.id, c.id);
      for (final to in [a.id, c.id]) {
        await b.sendOp(ib, to, {'op': 'del', 'mid': bad.id, 'sid': c.id});
      }
      await waitFor(() => ss[0].messages.isEmpty && ss[2].messages.isEmpty, what: 'اتمسحت عند الكل');

      // بسمة متقدرش تشيل صاحب الجروب ولا تمسح رسايله ولا تعيّن مديرين
      expect(ib.canKick(b.id, a.id), isFalse);
      expect(ib.canDelete(b.id, a.id), isFalse);
      await b.sendOp(ib, c.id, {'op': 'kick', 'id': a.id});
      await b.sendOp(ib, c.id, {'op': 'admin', 'id': c.id, 'on': true});
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(ic.banned, isEmpty);
      expect(ic.admins, {b.id});

      // بس تقدر تشيل كريم
      ib
        ..banned.add(c.id)
        ..bump();
      for (final to in [a.id, c.id]) {
        await b.sendOp(ib, to, {'op': 'kick', 'id': c.id, 'rev': ib.rev});
      }
      await waitFor(() => c.removedFrom.contains(ia.id) && ia.banned.contains(c.id));

      // صاحب الجروب يشيلها من الإدارة
      ia
        ..admins.remove(b.id)
        ..bump();
      await a.sendOp(ia, b.id, {'op': 'admin', 'id': b.id, 'on': false, 'rev': ia.rev});
      await waitFor(() => !ib.isAdmin(b.id));
      expect(ib.digest, ia.digest);
    });

    test('أمر قديم ميتعادش، وحالة صاحب الجروب هي المرجع', () async {
      final owner = await Profile.fromSeed(Kdf.randomBytes(32), name: 'o', color: 0);
      final admin = await Profile.fromSeed(Kdf.randomBytes(32), name: 'a', color: 0);
      final me = await Profile.fromSeed(Kdf.randomBytes(32), name: 'm', color: 0);
      final x = await Profile.fromSeed(Kdf.randomBytes(32), name: 'x', color: 0);
      final mine = await GroupInfo.create(name: 'الشلة', mode: GroupMode.open, owner: owner.id);

      final kick = {'op': 'kick', 'id': x.id, 'n': 10, 'rev': 1};
      expect((await mine.apply(owner.id, kick, myId: me.id))?.kind, GroupEffectKind.kicked);
      expect(await mine.apply(owner.id, {'op': 'unban', 'id': x.id, 'n': 11, 'rev': 2}, myId: me.id), isNotNull);
      // نفس أمر الإزالة القديم اتبعت تاني
      expect(await mine.apply(owner.id, kick, myId: me.id), isNull);
      expect(mine.banned, isEmpty);

      // حالة من صاحب الجروب بتاخد مكان اللي عندي
      final state = {
        'op': 'state', 'n': 12, 'rev': 5, 'name': 'اسم جديد',
        'admins': [admin.id], 'banned': [x.id], 'members': <String>[], 'kr': 0,
      };
      expect((await mine.apply(owner.id, state, myId: me.id))?.kind, GroupEffectKind.synced);
      expect(mine.name, 'اسم جديد');
      expect(mine.admins, {admin.id});
      expect(mine.rev, 5);

      // حالة أقدم من مدير متتقبلش، وحالة فيها إني متشال = أنا برا
      expect(await mine.apply(admin.id, {...state, 'n': 13, 'rev': 4, 'banned': <String>[]}, myId: me.id), isNull);
      final out = await mine.apply(admin.id, {...state, 'n': 14, 'rev': 6, 'banned': [me.id]}, myId: me.id);
      expect(out?.kind, GroupEffectKind.removedMe);

      // عند صاحب الجروب: المدير ميقدرش يغيّر الاسم ولا المديرين بحالة مزوّرة
      final atOwner = await GroupInfo.create(name: 'الشلة', mode: GroupMode.open, owner: owner.id);
      atOwner.admins.add(admin.id);
      final rogue = {
        'op': 'state', 'n': 20, 'rev': 999, 'name': 'اتسرق',
        'admins': [admin.id, x.id], 'banned': [owner.id, me.id], 'members': <String>[], 'kr': 0,
      };
      await atOwner.apply(admin.id, rogue, myId: owner.id);
      expect(atOwner.name, 'الشلة');
      expect(atOwner.admins, {admin.id});
      expect(atOwner.banned, {me.id}); // الإزالة من صلاحيات المدير، بس صاحب الجروب لأ
      expect(atOwner.rev, 1000); // نسخة صاحب الجروب بقت الأحدث وهترجع للكل
    });
  });

  group('التخزين', () {
    test('المحادثة المحفوظة بترجع زي ما هي ومشفّرة على القرص', () async {
      await Vault.instance.init(root: tmp);
      final store = ChatStore.instance..reset();
      await store.load();
      const id = '0123456789abcdef';
      final messages = [
        ChatMessage(id: '1', text: 'سلام سري جداً', kind: MessageKind.mine, status: MessageStatus.read),
        ChatMessage(
          id: '2',
          text: '',
          kind: MessageKind.theirs,
          sender: 'منى',
          senderId: 'ffff',
          media: ChatMedia(kind: MediaKind.voice, size: 10, path: '/x/v.m4a', durationMs: 1500, waveform: [1, 2, 3]),
          reply: const ReplyInfo(id: '1', preview: 'سلام', toMine: true),
        ),
        ChatMessage(id: '3', text: 'نظام', kind: MessageKind.system),
        ChatMessage(id: '4', text: 'لسه', kind: MessageKind.mine, status: MessageStatus.sending),
      ];
      store.index[id] = StoredChat(id: id, isGroup: false, name: 'منى', color: 3, unread: 2, saveOverride: true);
      await store.saveMessages(id, messages);
      await store.saveIndex();

      final raw = File('${tmp.path}/wasl/chats/$id.bin').readAsBytesSync();
      expect(utf8.decode(raw, allowMalformed: true).contains('سلام'), isFalse);

      store.reset();
      await store.load();
      expect(store.index[id]!.name, 'منى');
      expect(store.index[id]!.unread, 2);
      expect(store.index[id]!.saveOverride, isTrue);
      final back = await store.loadMessages(id);
      expect(back.length, 3); // رسالة النظام مبتتحفظش
      expect(back[0].text, 'سلام سري جداً');
      expect(back[0].status, MessageStatus.read);
      expect(back[1].media!.kind, MediaKind.voice);
      expect(back[1].media!.waveform, [1, 2, 3]);
      expect(back[1].reply!.toMine, isTrue);
      expect(back[1].sender, 'منى');
      expect(back[2].status, MessageStatus.failed); // كانت لسه بتتبعت

      await store.deleteChat(id);
      expect(File('${tmp.path}/wasl/chats/$id.bin').existsSync(), isFalse);
      expect(await store.loadMessages(id), isEmpty);
    });

    test('الجروبات اللي أنا فيها والمحظورين بيتحفظوا', () async {
      await Vault.instance.init(root: tmp);
      final store = ChatStore.instance..reset();
      await store.load();
      final g = await GroupInfo.create(name: 'ج', mode: GroupMode.ask, owner: 'aaaaaaaaaaaaaaaa');
      store.groups[g.id] = g;
      store.blocked.add('bbbbbbbbbbbbbbbb');
      await store.saveGroups();
      await store.saveBlocked();
      store.reset();
      await store.load();
      expect(store.groups[g.id]!.key, g.key);
      expect(store.groups[g.id]!.mode, GroupMode.ask);
      expect(store.blocked, {'bbbbbbbbbbbbbbbb'});
    });

    test('هوية البروفايل ثابتة من نفس البذرة', () async {
      final seed = Kdf.randomBytes(32);
      final p1 = await Profile.fromSeed(seed, name: 'a', color: 0);
      final p2 = await Profile.fromSeed(seed, name: 'b', color: 1);
      expect(p1.id, p2.id);
      expect(p1.id.length, 16);
      expect(p1.id, await Profile.idOf(p1.publicKey));
    });
  });
}
