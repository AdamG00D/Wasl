import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// اشتقاق المفاتيح.
///
/// ⚠️ ملف Dart خالص (بدون Flutter) لأن `tool/set_password.dart` يستخدمه أيضاً.
/// أي تغيير في المعاملات هنا يعني إعادة تشغيل الأداة لكل الحسابات.
class Kdf {
  Kdf._();

  // معاملات Argon2id حسب توصية OWASP (19 MiB، دورتان، مسار واحد).
  static const int argonMemoryKiB = 19 * 1024;
  static const int argonIterations = 2;
  static const int argonParallelism = 1;
  static const int keyLength = 32;

  static const String _verifyInfo = 'wasl/verify/v2';
  static const String _diaryInfo = 'wasl/diary/v2';

  /// Argon2id في Isolate منفصل حتى لا تتجمد الواجهة.
  static Future<Uint8List> argon2id(List<int> secret, List<int> salt) {
    final s = Uint8List.fromList(secret);
    final n = Uint8List.fromList(salt);
    return Isolate.run(() => _argon2id(s, n));
  }

  static Future<Uint8List> _argon2id(Uint8List secret, Uint8List salt) async {
    final algorithm = Argon2id(
      parallelism: argonParallelism,
      memory: argonMemoryKiB,
      iterations: argonIterations,
      hashLength: keyLength,
    );
    final key = await algorithm.deriveKey(
      secretKey: SecretKey(secret),
      nonce: salt,
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  /// يوحّد اسم المستخدم: إزالة المسافات (نفس سلوك التطبيق الأصلي).
  static String normalizeUsername(String username) =>
      username.replaceAll(RegExp(r'\s+'), '');

  /// المفتاح الرئيسي للحساب: مشتق من اسم المستخدم + كلمة السر.
  /// لا يُخزَّن في أي مكان؛ يُحسب لحظة الدخول فقط.
  static Future<Uint8List> masterKey(
    String username,
    String password,
    List<int> salt,
  ) {
    final input = utf8.encode('${normalizeUsername(username)}\u0000$password');
    return argon2id(input, salt);
  }

  static Future<Uint8List> hkdf(List<int> ikm, String info,
      {List<int> salt = const [], int length = keyLength}) async {
    final h = Hkdf(hmac: Hmac.sha256(), outputLength: length);
    final k = await h.deriveKey(
      secretKey: SecretKey(ikm),
      nonce: salt,
      info: utf8.encode(info),
    );
    return Uint8List.fromList(await k.extractBytes());
  }

  /// القيمة المخزنة في التطبيق للتحقق من كلمة السر.
  static Future<Uint8List> verifier(List<int> master) => hkdf(master, _verifyInfo);

  /// مفتاح تشفير المذكرات.
  static Future<Uint8List> diaryKey(List<int> master) => hkdf(master, _diaryInfo);

  static Future<Uint8List> sha256(List<int> data) async =>
      Uint8List.fromList((await Sha256().hash(data)).bytes);

  static String hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static final Random _random = Random.secure();

  static Uint8List randomBytes(int length) =>
      Uint8List.fromList(List<int>.generate(length, (_) => _random.nextInt(256)));

  /// مقارنة ثابتة الزمن.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// مسح بايتات حساسة من الذاكرة.
  /// القوائم غير القابلة للتعديل (من مكتبة التشفير) تُتجاهل بأمان.
  static void wipe(List<int> bytes) {
    try {
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = 0;
      }
    } on UnsupportedError {
      // قائمة للقراءة فقط
    }
  }
}
