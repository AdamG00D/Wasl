import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../crypto/kdf.dart';

/// التخزين المشفّر على الجهاز.
///
/// كل ملف بيتشفّر بـ AES-256-GCM بـ "مفتاح التخزين"، ومفتاح التخزين نفسه
/// متشفّر بمفتاح جوه Android Keystore (مبيطلعش برا الجهاز).
class Vault {
  Vault._();
  static final Vault instance = Vault._();

  static const _channel = MethodChannel('wasl/vault');
  static final List<int> _aad = utf8.encode('wasl/vault/v1');

  Uint8List? _key;
  Directory? _dir;

  bool get ready => _key != null;

  /// فولدر بيانات التطبيق الخاصة.
  Directory get dir => _dir!;

  /// [root] للاختبارات (من غير Keystore).
  Future<void> init({Directory? root}) async {
    if (_key != null && root == null) return;
    final base = root ?? await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/wasl');
    await dir.create(recursive: true);
    _dir = dir;
    final file = File('${dir.path}/vault.key');
    if (await file.exists()) {
      final s = (await file.readAsString()).trim();
      try {
        if (s.startsWith('ks:')) {
          final clear = await _channel.invokeMethod<Uint8List>('unwrap', {'data': base64.decode(s.substring(3))});
          if (clear != null && clear.length == 32) _key = clear;
        } else if (s.startsWith('raw:')) {
          _key = base64.decode(s.substring(4));
        }
      } catch (_) {}
    }
    if (_key != null) return;
    // مفتاح جديد (أول تشغيل، أو المفتاح القديم مبقاش يتفك: البيانات القديمة مش هتتقرا)
    try {
      if (await file.exists()) await file.copy('${file.path}.bak');
    } catch (_) {}
    final key = Kdf.randomBytes(32);
    String stored;
    try {
      final wrapped = await _channel.invokeMethod<Uint8List>('wrap', {'data': key});
      stored = 'ks:${base64.encode(wrapped!)}';
    } catch (_) {
      stored = 'raw:${base64.encode(key)}';
    }
    await file.writeAsString(stored, flush: true);
    _key = key;
  }

  File _file(String name) => File('${dir.path}/$name');

  Future<Uint8List> seal(List<int> clear) async {
    final box = await AesGcm.with256bits().encrypt(
      clear,
      secretKey: SecretKey(_key!),
      nonce: Kdf.randomBytes(12),
      aad: _aad,
    );
    return Uint8List.fromList([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  Future<List<int>?> open(List<int> data) async {
    if (data.length < 12 + 16) return null;
    try {
      return await AesGcm.with256bits().decrypt(
        SecretBox(
          data.sublist(12, data.length - 16),
          nonce: data.sublist(0, 12),
          mac: Mac(data.sublist(data.length - 16)),
        ),
        secretKey: SecretKey(_key!),
        aad: _aad,
      );
    } catch (_) {
      return null;
    }
  }

  /// يكتب JSON مشفّر (كتابة آمنة: ملف مؤقت وبعدين تبديل).
  Future<void> writeJson(String name, Object? json) async {
    final f = _file(name);
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(await seal(utf8.encode(jsonEncode(json))), flush: true);
    await tmp.rename(f.path);
  }

  /// null = الملف مش موجود أو مبيتفكش.
  Future<dynamic> readJson(String name) async {
    final f = _file(name);
    try {
      if (!await f.exists()) return null;
      final clear = await open(await f.readAsBytes());
      return clear == null ? null : jsonDecode(utf8.decode(clear));
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String name) async {
    try {
      final f = _file(name);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ---------------- البصمة ----------------

  static Future<bool> biometricAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('biometricAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> biometricAuth({required String title, String subtitle = ''}) async {
    try {
      return await _channel.invokeMethod<bool>('biometricAuth', {'title': title, 'subtitle': subtitle}) ?? false;
    } catch (_) {
      return false;
    }
  }
}
