import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../crypto/kdf.dart';
import '../theme/app_theme.dart';

/// إعدادات التطبيق (الشكل، حفظ المحادثات، القفل).
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  SharedPreferences? _prefs;

  ThemeMode themeMode = ThemeMode.system;
  AccentTheme accent = AccentTheme.all.first;

  /// حفظ المحادثات على الجهاز (الافتراضي: لأ).
  bool saveChats = false;

  /// قفل التطبيق برقم سري (اختياري).
  bool get lockEnabled => _pinHash != null;
  bool biometric = false;

  /// القفل التلقائي بعد كام دقيقة في الخلفية (0 = أول ما يخرج).
  int lockAfterMinutes = 1;

  String? _pinSalt;
  String? _pinHash;

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[(p.getInt('themeMode') ?? 0).clamp(0, ThemeMode.values.length - 1)];
    accent = AccentTheme.byId(p.getString('accent'));
    saveChats = p.getBool('saveChats') ?? false;
    biometric = p.getBool('biometric') ?? false;
    lockAfterMinutes = p.getInt('lockAfter') ?? 1;
    _pinSalt = p.getString('pinSalt');
    _pinHash = p.getString('pinHash');
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await _prefs?.setInt('themeMode', m.index);
  }

  Future<void> setAccent(AccentTheme a) async {
    accent = a;
    notifyListeners();
    await _prefs?.setString('accent', a.id);
  }

  Future<void> setSaveChats(bool v) async {
    saveChats = v;
    notifyListeners();
    await _prefs?.setBool('saveChats', v);
  }

  Future<void> setBiometric(bool v) async {
    biometric = v;
    notifyListeners();
    await _prefs?.setBool('biometric', v);
  }

  Future<void> setLockAfter(int minutes) async {
    lockAfterMinutes = minutes;
    notifyListeners();
    await _prefs?.setInt('lockAfter', minutes);
  }

  /// يحط رقم سري جديد (null = يشيل القفل).
  Future<void> setPin(String? pin) async {
    if (pin == null) {
      _pinSalt = null;
      _pinHash = null;
      biometric = false;
      await _prefs?.remove('pinSalt');
      await _prefs?.remove('pinHash');
      await _prefs?.setBool('biometric', false);
    } else {
      final salt = Kdf.randomBytes(16);
      final hash = await Kdf.argon2id(utf8.encode(pin), salt);
      _pinSalt = base64.encode(salt);
      _pinHash = base64.encode(hash);
      await _prefs?.setString('pinSalt', _pinSalt!);
      await _prefs?.setString('pinHash', _pinHash!);
    }
    notifyListeners();
  }

  Future<bool> checkPin(String pin) async {
    final salt = _pinSalt, hash = _pinHash;
    if (salt == null || hash == null) return true;
    final got = await Kdf.argon2id(utf8.encode(pin), base64.decode(salt));
    return Kdf.constantTimeEquals(got, base64.decode(hash));
  }
}
