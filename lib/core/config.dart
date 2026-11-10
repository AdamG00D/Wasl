class AppConfig {
  AppConfig._();

  static const String appName = 'Wasl';
  static const String appNameAr = 'وَصْل';
  static const String appVersion = '1.1';

  /// معرّف خدمة الشبكة القريبة (Nearby Connections).
  static const String nearbyServiceId = 'com.adam.wasl.mesh';

  /// منفذ اتصالات الشبكة المحلية (TCP).
  static const int lanPort = 47331;

  /// منفذ الإعلان عن الأجهزة على الشبكة (UDP).
  static const int lanBeaconPort = 47332;
}
