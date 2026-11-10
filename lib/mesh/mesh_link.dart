import 'package:flutter/foundation.dart';

import '../features/chat/core/chat_errors.dart';

enum LinkPhase { idle, starting, running, failed }

/// وسيلة ربط الجهاز بالأجهزة اللي حواليه مباشرة (جيرانه في الشبكة).
///
/// • [LanLink]: نفس الواي فاي / الهوت سبوت (UDP للاكتشاف + TCP).
/// • [NearbyLink]: بلوتوث عبر Google Nearby (P2P_CLUSTER).
///
/// الطبقة دي بتنقل "إطارات" نصية بين الجيران بس؛ التوجيه لأبعد من كده
/// (Mesh) في [MeshRouter]، والتشفير فوقهم.
abstract class MeshLink extends ChangeNotifier {
  MeshLink(this.myId);

  /// معرّف الجهاز ده في الشبكة.
  final String myId;

  LinkPhase phase = LinkPhase.idle;

  /// آخر خطأ (يُعرض للمستخدم مع الحل).
  ChatError? error;

  /// أقصى طول لإطار واحد.
  int get maxFrame;

  bool get supportsVideo;
  bool get supportsCalls;

  /// أقصى حجم لملف في المحادثة الخاصة / في الجروب.
  int get directFileLimit;
  int get groupFileLimit;

  /// مهلة صغيرة بين أجزاء ملفات الجروبات (البلوتوث أبطأ).
  Duration get floodPacing;

  // ---- بيربطهم الـ MeshRouter ----
  void Function(String link)? onUp;
  void Function(String link, String frame)? onFrame;
  void Function(String link)? onDown;

  /// الجهاز ده متوصل بيه بالفعل؟ (عشان منتصلش بيه مرتين)
  bool Function(String nodeId) isLinked = (_) => false;

  /// الوصلة دي إحنا اللي بدأناها.
  bool isOutgoing(String link);

  Future<void> start();
  Future<void> stop();
  Future<void> retry();
  Future<void> send(String link, String frame);

  /// قفل وصلة واحدة.
  void drop(String link);

  bool _disposed = false;

  @protected
  void setPhase(LinkPhase p, [ChatError? e]) {
    phase = p;
    error = e;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
