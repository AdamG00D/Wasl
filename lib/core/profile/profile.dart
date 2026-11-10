import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../widgets/cartoon_avatar.dart';
import '../crypto/kdf.dart';
import '../storage/vault.dart';

/// بروفايل المستخدم + هويته الثابتة (مفتاح X25519).
///
/// المعرّف (id) = أول 8 بايت من SHA-256 للمفتاح العام، فمحدش يقدر ينتحل
/// معرّف حد تاني من غير مفتاحه الخاص.
class Profile {
  Profile({
    required this.name,
    required this.color,
    required this.keyPair,
    required this.publicKey,
    required this.id,
    required this.seed,
    this.avatarHash,
    this.cartoon,
  });

  String name;
  int color;

  /// رقم الأفاتار الكرتوني (null = من غير). الصورة لو موجودة هي اللي بتظهر.
  int? cartoon;

  /// هاش صورة البروفايل (null = من غير صورة).
  String? avatarHash;

  final SimpleKeyPair keyPair;
  final Uint8List publicKey;
  final String id;
  final Uint8List seed;

  static Future<String> idOf(List<int> publicKey) async =>
      Kdf.hex((await Kdf.sha256(publicKey)).sublist(0, 8));

  static String cleanName(String raw) {
    final n = raw.replaceAll(RegExp(r'[\u0000-\u001f|]'), '').trim();
    return n.length > 24 ? n.substring(0, 24) : n;
  }

  static Future<Profile> fromSeed(
    Uint8List seed, {
    required String name,
    required int color,
    String? avatarHash,
    int? cartoon,
  }) async {
    final kp = await X25519().newKeyPairFromSeed(seed);
    final pub = Uint8List.fromList((await kp.extractPublicKey()).bytes);
    return Profile(
      name: name,
      color: color,
      keyPair: kp,
      publicKey: pub,
      id: await idOf(pub),
      seed: seed,
      avatarHash: avatarHash,
      cartoon: cartoon,
    );
  }
}

class ProfileStore extends ChangeNotifier {
  ProfileStore._();
  static final ProfileStore instance = ProfileStore._();

  static const _file = 'profile.bin';

  Profile? current;

  Future<void> load() async {
    final j = await Vault.instance.readJson(_file);
    if (j is! Map) return;
    try {
      current = await Profile.fromSeed(
        base64.decode(j['seed'] as String),
        name: Profile.cleanName('${j['name']}'),
        color: (j['color'] as num?)?.toInt() ?? 0,
        avatarHash: j['avatar'] as String?,
        cartoon: CartoonAvatars.clean(j['cartoon']),
      );
    } catch (_) {}
  }

  Future<void> _save() async {
    final p = current!;
    await Vault.instance.writeJson(_file, {
      'seed': base64.encode(p.seed),
      'name': p.name,
      'color': p.color,
      'avatar': p.avatarHash,
      'cartoon': p.cartoon,
    });
    notifyListeners();
  }

  /// أول مرة: بروفايل جديد بهوية جديدة.
  Future<Profile> create({required String name, required int color, String? avatarFile, int? cartoon}) async {
    final p = await Profile.fromSeed(
      Kdf.randomBytes(32),
      name: Profile.cleanName(name),
      color: color,
      cartoon: CartoonAvatars.valid(cartoon) ? cartoon : null,
    );
    current = p;
    if (avatarFile != null) p.avatarHash = await Avatars.import(avatarFile);
    await _save();
    return p;
  }

  /// [avatarFile]: مسار صورة جديدة، أو '' عشان تشيل الصورة، أو null من غير تغيير.
  /// [cartoon]: رقم أفاتار كرتوني، أو 0 عشان تشيله، أو null من غير تغيير.
  Future<void> update({String? name, int? color, String? avatarFile, int? cartoon}) async {
    final p = current;
    if (p == null) return;
    if (name != null && Profile.cleanName(name).isNotEmpty) p.name = Profile.cleanName(name);
    if (color != null) p.color = color;
    if (avatarFile != null) p.avatarHash = avatarFile.isEmpty ? null : await Avatars.import(avatarFile);
    if (cartoon != null) p.cartoon = CartoonAvatars.valid(cartoon) ? cartoon : null;
    await _save();
  }
}

/// صور البروفايل (بتاعتي وبتاعة الناس) — صور صغيرة متخزنة باسم الهاش بتاعها.
class Avatars {
  Avatars._();

  /// أقصى حجم لصورة بروفايل بتتبعت على الشبكة.
  static const int maxBytes = 20 * 1024;

  static Directory get _dir => Directory('${Vault.instance.dir.path}/avatars');

  static File fileFor(String hash) => File('${_dir.path}/$hash.jpg');

  static bool has(String hash) => fileFor(hash).existsSync();

  /// يحفظ صورة (مصغّرة بالفعل) ويرجّع الهاش، أو null لو كبيرة/مش مقروءة.
  static Future<String?> import(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return await store(bytes);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> store(List<int> bytes) async {
    if (bytes.isEmpty || bytes.length > maxBytes) return null;
    // لازم تكون JPEG
    if (bytes.length < 3 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
    final hash = Kdf.hex((await Kdf.sha256(bytes)).sublist(0, 6));
    try {
      await _dir.create(recursive: true);
      final f = fileFor(hash);
      if (!await f.exists()) await f.writeAsBytes(bytes, flush: true);
      return hash;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> read(String hash) async {
    try {
      if (!RegExp(r'^[0-9a-f]{12}$').hasMatch(hash)) return null;
      final f = fileFor(hash);
      return await f.exists() ? await f.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }
}
