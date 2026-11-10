import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wasl/core/crypto/kdf.dart';
import 'package:wasl/core/profile/profile.dart';
import 'package:wasl/mesh/dual_link.dart';
import 'package:wasl/mesh/mesh_link.dart';
import 'package:wasl/mesh/mesh_router.dart';

import 'support.dart';

/// الكوبري: موبايل شغّال واي فاي + بلوتوث بيوصّل شبكتين ببعض.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryNet wifi, bt;
  final routers = <MeshRouter>[];

  Future<Profile> person(String name) => Profile.fromSeed(Kdf.randomBytes(32), name: name, color: 1);

  Future<MeshRouter> start(Profile p, MeshLink link) async {
    final r = MeshRouter(
      link: link,
      presenceEvery: const Duration(milliseconds: 150),
      nodeTtl: const Duration(milliseconds: 900),
      describe: () => {'n': p.name, 'c': p.color, 'k': base64.encode(p.publicKey)},
    );
    routers.add(r);
    await r.start();
    return r;
  }

  MemoryLink onWifi(Profile p) => wifi.add(p.id)..maxFrame = 200 * 1024;
  MemoryLink onBt(Profile p) => bt.add(p.id)..maxFrame = 30000;
  DualLink dual(Profile p) => DualLink(p.id, wifi: onWifi(p), bluetooth: onBt(p));

  setUp(() {
    wifi = MemoryNet();
    bt = MemoryNet();
  });

  tearDown(() async {
    for (final r in routers) {
      await r.stop();
      r.dispose();
    }
    routers.clear();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  test('اللي على الواي فاي بيوصل للي على البلوتوث عن طريق موبايل شغّال الاتنين', () async {
    final pa = await person('واي فاي'), pb = await person('كوبري'), pc = await person('بلوتوث');
    final a = await start(pa, onWifi(pa));
    final b = await start(pb, dual(pb));
    final c = await start(pc, onBt(pc));
    wifi.connect(pa.id, pb.id);
    bt.connect(pb.id, pc.id);
    await waitFor(() => a.reachable(pc.id) && c.reachable(pa.id), what: 'a<->c عبر الكوبري');
    expect(a.nodes[pc.id]!.hops, 2);
    expect(b.isDirect(pa.id) && b.isDirect(pc.id), isTrue);

    Map<String, dynamic>? got;
    c.onControl = (src, m) => got = m;
    await a.sendControl(pc.id, {'t': 'ping', 'x': 1});
    await waitFor(() => got != null);
    expect(got!['x'], 1);
  });

  test('إطار كبير من الواي فاي بيتقسم على البلوتوث ويتجمّع سليم', () async {
    final pa = await person('a'), pb = await person('b'), pc = await person('c');
    final a = await start(pa, onWifi(pa));
    await start(pb, dual(pb));
    final c = await start(pc, onBt(pc));
    wifi.connect(pa.id, pb.id);
    bt.connect(pb.id, pc.id);
    await waitFor(() => a.reachable(pc.id) && c.reachable(pa.id));

    final big = base64.encode(Kdf.randomBytes(90 * 1024)); // ~120 ألف حرف > حد البلوتوث
    final got = <String>[];
    c.onData = (src, body) => got.add(body);
    await a.sendData(pc.id, big);
    await a.sendData(pc.id, 'صغيرة');
    await waitFor(() => got.length == 2, what: 'الإطارين وصلوا');
    expect(got[0], big);
    expect(got[1], 'صغيرة');
  });

  test('جهازين شايفين بعض بالطريقتين: بيكمّلوا بالواي فاي والبلوتوث بيتقفل', () async {
    final pa = await person('a'), pb = await person('b');
    final la = dual(pa), lb = dual(pb);
    final a = await start(pa, la);
    final b = await start(pb, lb);

    // البلوتوث لقاهم الأول
    bt.connect(pa.id, pb.id);
    await waitFor(() => a.isDirect(pb.id) && b.isDirect(pa.id));
    expect(la.isWifi(a.linkOf(pb.id)!), isFalse);
    // وبعدين دخلوا نفس الواي فاي
    wifi.connect(pa.id, pb.id);
    await waitFor(
      () => (a.linkOf(pb.id)?.startsWith('w:') ?? false) && (b.linkOf(pa.id)?.startsWith('w:') ?? false),
      what: 'اتحوّلوا للواي فاي',
    );
    // وصلة بلوتوث جديدة مبتاخدش مكان الواي فاي
    bt.connect(pa.id, pb.id);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(la.isWifi(a.linkOf(pb.id)!), isTrue);
    expect(lb.isWifi(b.linkOf(pa.id)!), isTrue);
    expect(a.reachable(pb.id), isTrue);
  });
}
