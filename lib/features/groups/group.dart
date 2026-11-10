import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../core/crypto/box.dart';
import '../../core/crypto/kdf.dart';
import '../../core/profile/profile.dart';
import '../../mesh/mesh_router.dart';

/// جروب أنا عضو فيه (معايا مفتاحه).
///
/// مفتاح الجروب:
///  • عام: مشتق من معرّف الجروب — أي حد شايف الجروب يقدر يدخل (ده معنى "عام").
///  • بكلمة سر: مشتق من الكلمة بـ Argon2id — اللي ميعرفهاش ميقدرش يقرا.
///  • بطلب انضمام: عشوائي، وصاحب الجروب بيسلّمه مشفّر لكل عضو يوافق عليه.
///
/// الإدارة: صاحب الجروب ثابت ومحدش يقدر يشيله أو يغيّره. هو بيعيّن مديرين،
/// والمديرين يشيلوا أعضاء عاديين ويمسحوا رسايلهم ويغيّروا اسم الجروب.
class GroupInfo {
  GroupInfo({
    required this.id,
    required this.name,
    required this.mode,
    required this.owner,
    required this.key,
    required this.check,
    Set<String>? admins,
    Set<String>? banned,
    Set<String>? members,
    this.keyRev = 0,
    this.rev = 0,
    Map<String, int>? opSeen,
  })  : admins = admins ?? {},
        banned = banned ?? {},
        members = members ?? {},
        opSeen = opSeen ?? {};

  final String id;
  String name;
  final GroupMode mode;
  final String owner;
  Uint8List key;

  /// قيمة مشتقة من المفتاح: بنتأكد بيها إن كلمة السر/المفتاح صح.
  String check;

  /// المديرين (غير صاحب الجروب).
  final Set<String> admins;

  /// اللي اتشالوا من الجروب.
  final Set<String> banned;

  /// جروب بطلب انضمام: اللي اتوافق عليهم (عشان المفتاح الجديد يتسلّم لهم بس).
  final Set<String> members;

  /// رقم نسخة المفتاح (بيزيد مع كل تغيير مفتاح بعد إزالة عضو).
  int keyRev;

  /// رقم نسخة حالة الإدارة: بيزيد مع كل تغيير، والأحدث هو اللي بيمشي.
  int rev;

  static const int _maxRev = 1 << 50;

  /// تغيير محلي في حالة الإدارة (قبل ما يتبعت للأعضاء).
  void bump() => rev++;

  /// آخر رقم أمر إدارة اتقبل من كل مرسل (ضد إعادة إرسال أمر قديم).
  final Map<String, int> opSeen;

  static const int maxAdmins = 16;
  static const int maxBanned = 128;
  static const int maxMembers = 256;

  bool isAdmin(String who) => who == owner || admins.contains(who);

  /// [by] يقدر يشيل [target] من الجروب؟
  bool canKick(String by, String target) {
    if (target == owner || target == by) return false;
    if (by == owner) return true;
    return admins.contains(by) && !admins.contains(target);
  }

  /// [by] يقدر يمسح رسالة [author] عند الكل؟
  bool canDelete(String by, String author) => by == author || (isAdmin(by) && (author != owner || by == owner));

  /// بصمة قصيرة لحالة الإدارة (بتتبعت مع إعلان الجروب): لو مختلفة عند عضو، صاحب الجروب
  /// أو مدير بيبعتله الحالة. مش للأمان — الحالة نفسها بتتبعت موثّقة.
  String get digest {
    final parts = [
      name,
      (admins.toList()..sort()).join(','),
      (banned.toList()..sort()).join(','),
      (members.toList()..sort()).join(','),
      '$keyRev',
      '$rev',
    ].join('|');
    var h = 0x811c9dc5;
    for (final c in utf8.encode(parts)) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  GroupAd get ad => GroupAd(
        id: id,
        name: name,
        mode: mode,
        owner: owner,
        check: mode == GroupMode.open ? null : check,
        digest: digest,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mode': mode.wire,
        'owner': owner,
        'key': base64.encode(key),
        'check': check,
        if (admins.isNotEmpty) 'admins': admins.toList(),
        if (banned.isNotEmpty) 'banned': banned.toList(),
        if (members.isNotEmpty) 'members': members.toList(),
        if (keyRev != 0) 'kr': keyRev,
        if (rev != 0) 'rev': rev,
        if (opSeen.isNotEmpty) 'seen': opSeen,
      };

  static Set<String> _ids(Object? raw, int max) =>
      {for (final e in (raw as List? ?? const []).take(max)) if (e is String && MeshRouter.isId(e)) e};

  static GroupInfo? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final mode = GroupMode.fromWire(raw['mode']);
      final key = base64.decode(raw['key'] as String);
      if (mode == null || key.length != 32) return null;
      return GroupInfo(
        id: raw['id'] as String,
        name: raw['name'] as String,
        mode: mode,
        owner: raw['owner'] as String,
        key: key,
        check: raw['check'] as String,
        admins: _ids(raw['admins'], maxAdmins),
        banned: _ids(raw['banned'], maxBanned),
        members: _ids(raw['members'], maxMembers),
        keyRev: (raw['kr'] as num?)?.toInt() ?? 0,
        rev: (raw['rev'] as num?)?.toInt() ?? 0,
        opSeen: {
          for (final e in (raw['seen'] as Map? ?? const {}).entries)
            if (e.key is String && e.value is num) e.key as String: (e.value as num).toInt(),
        },
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------- أوامر الإدارة ----------------

  /// الحالة كاملة (بيبعتها صاحب الجروب أو مدير لعضو حالته قديمة).
  Map<String, dynamic> stateOp({required bool withKey}) => {
        'op': 'state',
        'rev': rev,
        'name': name,
        'admins': admins.toList(),
        'banned': banned.toList(),
        'members': members.toList(),
        'kr': keyRev,
        if (withKey && mode == GroupMode.ask) 'key': base64.encode(key),
      };

  Future<bool> _takeKey(Object? raw, int rev) async {
    if (mode != GroupMode.ask || raw is! String || rev <= keyRev) return false;
    final Uint8List k;
    try {
      k = base64.decode(raw);
    } catch (_) {
      return false;
    }
    if (k.length != 32) return false;
    key = k;
    keyRev = rev;
    check = await checkOf(k);
    return true;
  }

  /// يطبّق أمر إدارة وصل من [from] (بعد ما اتأكدنا إنه هو اللي بعته — شوف [GroupOps]).
  /// يرجّع اللي حصل، أو null لو الأمر مرفوض (مش من صلاحياته / قديم / مش مفهوم).
  Future<GroupEffect?> apply(String from, Map<String, dynamic> op, {required String myId}) async {
    if (!isAdmin(from) || banned.contains(from)) return null;
    final n = (op['n'] as num?)?.toInt() ?? 0;
    if (n <= (opSeen[from] ?? 0)) return null;
    final fromOwner = from == owner;
    final target = '${op['id'] ?? ''}';
    final opRev = ((op['rev'] as num?)?.toInt() ?? rev + 1).clamp(0, _maxRev);
    GroupEffect? effect;
    switch (op['op']) {
      case 'kick':
        if (!MeshRouter.isId(target) || !canKick(from, target)) return null;
        if (banned.length < maxBanned) banned.add(target);
        admins.remove(target);
        members.remove(target);
        effect = GroupEffect(target == myId ? GroupEffectKind.removedMe : GroupEffectKind.kicked, target: target);
      case 'unban':
        if (!MeshRouter.isId(target) || !banned.remove(target)) return null;
        effect = GroupEffect(GroupEffectKind.unbanned, target: target);
      case 'admin':
        if (!fromOwner || !MeshRouter.isId(target) || target == owner || banned.contains(target)) return null;
        final on = op['on'] == true;
        if (on ? (admins.length >= maxAdmins || !admins.add(target)) : !admins.remove(target)) return null;
        effect = GroupEffect(on ? GroupEffectKind.promoted : GroupEffectKind.demoted, target: target);
      case 'name':
        final clean = Profile.cleanName('${op['name'] ?? ''}');
        if (clean.length < 2 || clean == name) return null;
        name = clean;
        effect = const GroupEffect(GroupEffectKind.renamed);
      case 'del':
        final mid = '${op['mid'] ?? ''}', sid = '${op['sid'] ?? ''}';
        if (mid.isEmpty || mid.length > 80 || !MeshRouter.isId(sid) || !canDelete(from, sid)) return null;
        effect = GroupEffect(GroupEffectKind.deleted, target: sid, messageId: mid);
      case 'key':
        if (!await _takeKey(op['key'], (op['kr'] as num?)?.toInt() ?? 0)) return null;
        effect = const GroupEffect(GroupEffectKind.rekeyed);
      case 'state':
        final newBans = _ids(op['banned'], maxBanned)..remove(owner);
        final rekeyed = await _takeKey(op['key'], (op['kr'] as num?)?.toInt() ?? 0);
        if (myId == owner) {
          // أنا صاحب الجروب: من المدير باخد اللي شالهم بس، ونسختي هي اللي بتمشي بعدها
          final before = banned.length;
          banned.addAll(newBans.where((b) => !admins.contains(b)).take(maxBanned - banned.length));
          members.removeAll(banned);
          if (opRev >= rev || banned.length != before) rev = (opRev > rev ? opRev : rev) + 1;
        } else {
          // صاحب الجروب هو المرجع. من غيره: الأحدث يمشي، ولو متساويين العضو يمشي ورا المدير
          final newer = fromOwner
              ? opRev >= rev
              : opRev > rev || (opRev == rev && (!isAdmin(myId) || from.compareTo(myId) < 0));
          if (!newer && !rekeyed) return null;
          if (newer) {
            final clean = Profile.cleanName('${op['name'] ?? ''}');
            if (clean.length >= 2) name = clean;
            admins
              ..clear()
              ..addAll(_ids(op['admins'], maxAdmins)..remove(owner));
            banned
              ..clear()
              ..addAll(newBans);
            members
              ..clear()
              ..addAll(_ids(op['members'], maxMembers));
            admins.removeAll(banned);
            members.removeAll(banned);
            rev = opRev;
          }
        }
        opSeen[from] = n;
        return GroupEffect(
          banned.contains(myId) ? GroupEffectKind.removedMe : GroupEffectKind.synced,
          rekeyed: rekeyed,
        );
      default:
        return null;
    }
    opSeen[from] = n;
    if (opSeen.length > 64) opSeen.remove(opSeen.keys.first);
    if (opRev > rev) rev = opRev;
    return effect;
  }

  static Future<Uint8List> openKey(String id) => Kdf.sha256(utf8.encode('wasl-open-group|$id'));

  static Future<Uint8List> passwordKey(String id, String password) async {
    final salt = (await Kdf.sha256(utf8.encode('wasl-group-salt|$id'))).sublist(0, 16);
    return Kdf.argon2id(utf8.encode(password), salt);
  }

  static Future<String> checkOf(List<int> key) async => Kdf.hex(await Kdf.hkdf(key, 'wasl/group/check', length: 8));

  /// جروب جديد أنا صاحبه.
  static Future<GroupInfo> create({
    required String name,
    required GroupMode mode,
    required String owner,
    String? password,
  }) async {
    final id = Kdf.hex(Kdf.randomBytes(8));
    final key = switch (mode) {
      GroupMode.open => await openKey(id),
      GroupMode.password => await passwordKey(id, password ?? ''),
      GroupMode.ask => Kdf.randomBytes(32),
    };
    return GroupInfo(
      id: id,
      name: Profile.cleanName(name),
      mode: mode,
      owner: owner,
      key: key,
      check: await checkOf(key),
      members: mode == GroupMode.ask ? {owner} : null,
    );
  }

  /// عضوية من إعلان + مفتاح (بعد ما اتأكدنا إنه صح).
  static Future<GroupInfo> fromAd(GroupAd ad, Uint8List key) async =>
      GroupInfo(id: ad.id, name: ad.name, mode: ad.mode, owner: ad.owner, key: key, check: await checkOf(key));

  /// مفتاح جديد للجروب (بعد إزالة عضو من جروب بطلب انضمام).
  Future<void> rotateKey() async {
    key = Kdf.randomBytes(32);
    keyRev++;
    check = await checkOf(key);
  }

  /// المفتاح ده بتاع الجروب ده فعلاً؟
  static Future<bool> matches(GroupAd ad, List<int> key) async {
    if (ad.mode == GroupMode.open) return Kdf.constantTimeEquals(key, await openKey(ad.id));
    final check = ad.check;
    return check != null && check == await checkOf(key);
  }
}

enum GroupEffectKind {
  /// أنا اللي اتشلت من الجروب.
  removedMe,
  kicked,
  unbanned,
  promoted,
  demoted,
  renamed,

  /// رسالة اتمسحت عند الكل.
  deleted,
  rekeyed,
  synced,
}

/// نتيجة تطبيق أمر إدارة.
class GroupEffect {
  const GroupEffect(this.kind, {this.target, this.messageId, this.rekeyed = false});

  final GroupEffectKind kind;

  /// العضو المقصود (أو صاحب الرسالة الممسوحة).
  final String? target;
  final String? messageId;

  /// المفتاح اتغيّر مع الأمر ده.
  final bool rekeyed;

  bool get keyChanged => rekeyed || kind == GroupEffectKind.rekeyed;
}

/// أوامر إدارة الجروب بين جهازين.
///
/// رسايل الجروب العادية متشفّرة بمفتاح الجروب اللي مع كل الأعضاء، فأي عضو يقدر يكتب
/// اللي هو عايزه جواها. عشان كده أوامر الإدارة مبتتبعتش كده: كل أمر بيتقفل لكل عضو لوحده
/// بمفتاح مشترك بين هوية المرسل وهوية المستلم ([Box.pairKey])، فالمستلم متأكد إن اللي
/// بعته هو صاحب المعرّف ده فعلاً — ومحدش يقدر يزوّر أمر باسم صاحب الجروب أو مدير.
class GroupOps {
  GroupOps._();

  static const _info = 'wasl/group-admin';
  static int _last = 0;

  /// رقم متزايد لكل أمر (ضد إعادة الإرسال).
  static int nextNumber() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return _last = now > _last ? now : _last + 1;
  }

  static List<int> _aad(String groupId, String from, String to) => utf8.encode('wasl/ga|$groupId|$from|$to');

  /// يقفل الأمر للعضو [peerId] بس.
  static Future<String> seal({
    required SimpleKeyPair me,
    required String myId,
    required List<int> peerKey,
    required String peerId,
    required String groupId,
    required Map<String, dynamic> op,
  }) async {
    final pair = await Box.pairKey(me, peerKey, _info);
    return base64.encode(await Box.seal(pair, utf8.encode(jsonEncode(op)), _aad(groupId, myId, peerId)));
  }

  /// null = مش من الشخص ده / مش ليّا / اتعدّل في السكة.
  static Future<Map<String, dynamic>?> open({
    required SimpleKeyPair me,
    required String myId,
    required List<int> peerKey,
    required String peerId,
    required String groupId,
    required Object? sealed,
  }) async {
    if (sealed is! String || sealed.length > 64 * 1024) return null;
    try {
      final pair = await Box.pairKey(me, peerKey, _info);
      final clear = await Box.open(pair, base64.decode(sealed), _aad(groupId, peerId, myId));
      if (clear == null) return null;
      final m = jsonDecode(utf8.decode(clear));
      return m is Map<String, dynamic> ? m : null;
    } catch (_) {
      return null;
    }
  }
}
