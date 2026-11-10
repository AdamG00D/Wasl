import 'dart:convert';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';

import 'kdf.dart';

/// صندوق AES-256-GCM: `nonce(12) + ciphertext + tag(16)`.
///
/// الحزم الكبيرة بتتشفر بتشفير أندرويد نفسه (أسرع بكتير)، ولو مش متاح
/// (الاختبارات) في خيط منفصل عشان الشاشة متهنّجش.
class Box {
  Box._();

  static const int _bigThreshold = 24 * 1024;
  static const _native = MethodChannel('wasl/crypto');
  static bool _nativeAvailable = true;

  static Future<Uint8List> seal(List<int> key, List<int> clear, List<int> aad) async {
    if (clear.length > _bigThreshold) {
      if (_nativeAvailable) {
        try {
          final box = await _native.invokeMethod<Uint8List>('seal', {
            'key': Uint8List.fromList(key),
            'data': clear is Uint8List ? clear : Uint8List.fromList(clear),
            'aad': Uint8List.fromList(aad),
          });
          if (box != null) return box;
        } on MissingPluginException {
          _nativeAvailable = false;
        } on PlatformException {
          // نكمّل بالطريقة التانية
        }
      }
      return Isolate.run(() => _seal(key, clear, aad));
    }
    return _seal(key, clear, aad);
  }

  /// null = المفتاح غلط أو البيانات اتعدلت.
  static Future<List<int>?> open(List<int> key, List<int> box, List<int> aad) async {
    if (box.length < 12 + 16) return null;
    if (box.length > _bigThreshold) {
      if (_nativeAvailable) {
        try {
          return await _native.invokeMethod<Uint8List>('open', {
            'key': Uint8List.fromList(key),
            'data': box is Uint8List ? box : Uint8List.fromList(box),
            'aad': Uint8List.fromList(aad),
          });
        } on MissingPluginException {
          _nativeAvailable = false;
        } on PlatformException {
          // نكمّل بالطريقة التانية
        }
      }
      return Isolate.run(() => _open(key, box, aad));
    }
    return _open(key, box, aad);
  }

  static Future<Uint8List> _seal(List<int> key, List<int> clear, List<int> aad) async {
    final box = await AesGcm.with256bits().encrypt(
      clear,
      secretKey: SecretKey(key),
      nonce: Kdf.randomBytes(12),
      aad: aad,
    );
    return Uint8List.fromList([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<List<int>?> _open(List<int> key, List<int> data, List<int> aad) async {
    try {
      return await AesGcm.with256bits().decrypt(
        SecretBox(
          data.sublist(12, data.length - 16),
          nonce: data.sublist(0, 12),
          mac: Mac(data.sublist(data.length - 16)),
        ),
        secretKey: SecretKey(key),
        aad: aad,
      );
    } catch (_) {
      return null;
    }
  }

  /// مفتاح مشترك بين هويتين (X25519 ثابت×ثابت) — لرسايل التحكم الخاصة بين جهازين
  /// (زي تسليم مفتاح جروب لعضو جديد).
  static Future<Uint8List> pairKey(SimpleKeyPair mine, List<int> theirPublicKey, String info) async {
    final shared = await X25519().sharedSecretKey(
      keyPair: mine,
      remotePublicKey: SimplePublicKey(theirPublicKey, type: KeyPairType.x25519),
    );
    return Kdf.hkdf(await shared.extractBytes(), info, salt: utf8.encode('wasl-pair-v1'));
  }
}
