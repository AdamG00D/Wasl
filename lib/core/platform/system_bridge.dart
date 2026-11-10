import 'package:flutter/services.dart';

/// جسر لمعلومات وإعدادات النظام (منفّذ في MainActivity.kt).
class SystemBridge {
  SystemBridge._();

  static const _channel = MethodChannel('wasl/system');

  static int? _sdk;

  /// إصدار أندرويد (API level).
  static Future<int> sdkInt() async =>
      _sdk ??= await _channel.invokeMethod<int>('sdkInt') ?? 0;

  static Future<bool> bluetoothSupported() async =>
      await _channel.invokeMethod<bool>('bluetoothSupported') ?? false;

  static Future<bool> bluetoothEnabled() async =>
      await _channel.invokeMethod<bool>('bluetoothEnabled') ?? false;

  /// يطلب تشغيل البلوتوث (نافذة النظام).
  static Future<void> requestBluetoothOn() =>
      _channel.invokeMethod('requestBluetoothOn');

  static Future<bool> locationEnabled() async =>
      await _channel.invokeMethod<bool>('locationEnabled') ?? false;

  static Future<void> openLocationSettings() =>
      _channel.invokeMethod('openLocationSettings');

  static Future<void> openWifiSettings() =>
      _channel.invokeMethod('openWifiSettings');

  static Future<bool> wifiEnabled() async =>
      await _channel.invokeMethod<bool>('wifiEnabled') ?? false;

  // ---------------- الشبكة ----------------

  /// لازم عشان استقبال إعلانات الأجهزة (broadcast) على الواي فاي.
  static Future<void> acquireMulticastLock() async {
    try {
      await _channel.invokeMethod('acquireMulticastLock');
    } catch (_) {}
  }

  static Future<void> releaseMulticastLock() async {
    try {
      await _channel.invokeMethod('releaseMulticastLock');
    } catch (_) {}
  }

  // ---------------- الدردشة في الخلفية ----------------

  /// خدمة في المقدمة تخلي الدردشة شغالة لما التطبيق يبقى في الخلفية.
  static Future<void> startChatService() async {
    try {
      await _channel.invokeMethod('startChatService');
    } catch (_) {}
  }

  /// تحديث نوع الخدمة أثناء المكالمات (أندرويد 14 بيشترط تعلن عن الميكروفون/الكاميرا
  /// عشان المكالمة تكمل لو التطبيق راح الخلفية).
  static Future<void> updateChatService({required bool microphone, required bool camera}) async {
    try {
      await _channel.invokeMethod('updateChatService', {'microphone': microphone, 'camera': camera});
    } catch (_) {}
  }

  static Future<void> stopChatService() async {
    try {
      await _channel.invokeMethod('stopChatService');
    } catch (_) {}
  }

  /// إشعار من غير أي تفاصيل: 'message' = رسالة جديدة، 'request' = طلب محادثة.
  static Future<void> notify(String kind) async {
    try {
      await _channel.invokeMethod('notify', {'kind': kind});
    } catch (_) {}
  }

  /// يودّي التطبيق للخلفية من غير ما يقفله (زي زرار الهوم).
  static Future<void> moveToBack() async {
    try {
      await _channel.invokeMethod('moveToBack');
    } catch (_) {}
  }

  // ---------------- شكل التطبيق برا ----------------

  /// يغيّر أيقونة التطبيق واسمه على الشاشة الرئيسية (activity-alias).
  static Future<bool> setLauncher(String target, List<String> all) async {
    try {
      return await _channel.invokeMethod<bool>('setLauncher', {'target': target, 'all': all}) ?? false;
    } catch (_) {
      return false;
    }
  }

  // ---------------- الفيديو ----------------

  static const _video = MethodChannel('wasl/video');

  /// الفيديو كبير/مش H.264 ومحتاج يتضغط قبل الإرسال عشان يشتغل عند أي حد.
  static Future<bool> videoNeedsCompression(String path) async {
    try {
      return await _video.invokeMethod<bool>('needsCompression', {'path': path}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// يضغط الفيديو (H.264، أطول ضلع 1280). null = فشل أو اتلغى.
  static Future<String?> compressVideo(String path) async {
    try {
      return await _video.invokeMethod<String>('compress', {'path': path});
    } catch (_) {
      return null;
    }
  }

  /// نسبة الضغط (0..100) أو -1.
  static Future<int> videoProgress() async {
    try {
      return await _video.invokeMethod<int>('progress') ?? -1;
    } catch (_) {
      return -1;
    }
  }

  static Future<void> cancelVideoCompression() async {
    try {
      await _video.invokeMethod('cancel');
    } catch (_) {}
  }

  // ---------------- الملفات ----------------

  /// يصغّر صورة لـ JPEG (أقصى ضلع [maxSide]). null = مش صورة أو فشل.
  static Future<String?> compressImage(String path, {int maxSide = 2048, int quality = 82}) async {
    try {
      return await _channel.invokeMethod<String>('compressImage', {
        'path': path,
        'maxSide': maxSide,
        'quality': quality,
      });
    } catch (_) {
      return null;
    }
  }

  /// يفتح ملف بالتطبيق المناسب (PDF، مستند...). false = مفيش تطبيق يفتحه.
  static Future<bool> openFile(String path, String name) async {
    try {
      return await _channel.invokeMethod<bool>('openFile', {'path': path, 'name': name}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// يحفظ نسخة في Download/Wasl.
  static Future<bool> saveToDownloads(String path, String name) async {
    try {
      return await _channel.invokeMethod<bool>('saveToDownloads', {'path': path, 'name': name}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearNotifications() async {
    try {
      await _channel.invokeMethod('clearNotifications');
    } catch (_) {}
  }
}
