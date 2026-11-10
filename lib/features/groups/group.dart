import 'dart:convert';
import 'dart:typed_data';

import '../../core/crypto/kdf.dart';
import '../../core/profile/profile.dart';
import '../../mesh/mesh_router.dart';

/// جروب أنا عضو فيه (معايا مفتاحه).
///
/// مفتاح الجروب:
///  • عام: مشتق من معرّف الجروب — أي حد شايف الجروب يقدر يدخل (ده معنى "عام").
///  • بكلمة سر: مشتق من الكلمة بـ Argon2id — اللي ميعرفهاش ميقدرش يقرا.
///  • بطلب انضمام: عشوائي، وصاحب الجروب بيسلّمه مشفّر لكل عضو يوافق عليه.
class GroupInfo {
  GroupInfo({
    required this.id,
    required this.name,
    required this.mode,
    required this.owner,
    required this.key,
    required this.check,
  });

  final String id;
  final String name;
  final GroupMode mode;
  final String owner;
  final Uint8List key;

  /// قيمة مشتقة من المفتاح: بنتأكد بيها إن كلمة السر/المفتاح صح.
  final String check;

  GroupAd get ad => GroupAd(id: id, name: name, mode: mode, owner: owner, check: mode == GroupMode.open ? null : check);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mode': mode.wire,
        'owner': owner,
        'key': base64.encode(key),
        'check': check,
      };

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
      );
    } catch (_) {
      return null;
    }
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
    );
  }

  /// عضوية من إعلان + مفتاح (بعد ما اتأكدنا إنه صح).
  static Future<GroupInfo> fromAd(GroupAd ad, Uint8List key) async =>
      GroupInfo(id: ad.id, name: ad.name, mode: ad.mode, owner: ad.owner, key: key, check: await checkOf(key));

  /// المفتاح ده بتاع الجروب ده فعلاً؟
  static Future<bool> matches(GroupAd ad, List<int> key) async {
    if (ad.mode == GroupMode.open) return Kdf.constantTimeEquals(key, await openKey(ad.id));
    final check = ad.check;
    return check != null && check == await checkOf(key);
  }
}
