import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/platform/system_bridge.dart';

enum RequirementState { ok, missing, blocked }

/// متطلب واحد للدردشة القريبة (إذن أو إعداد).
class Requirement {
  Requirement({
    required this.id,
    required this.icon,
    required this.title,
    required this.why,
    required this.state,
    required this.fixLabel,
  });

  final String id;
  final IconData icon;
  final String title;
  final String why;
  final RequirementState state;
  final String fixLabel;

  bool get ok => state == RequirementState.ok;
}

/// يحدد ما يحتاجه Nearby حسب إصدار أندرويد ويطلبه.
///
///  • أندرويد 13+: الأجهزة القريبة (بلوتوث) + أجهزة الواي فاي القريبة.
///  • أندرويد 12: الأجهزة القريبة + الموقع (مطلوب من النظام للواي فاي).
///  • أندرويد 11 وأقدم: الموقع + تشغيل خدمة الموقع (النظام يشترطها لأي بحث).
class NearbyRequirements {
  NearbyRequirements._();

  static Future<List<Permission>> _permissions() async {
    final sdk = await SystemBridge.sdkInt();
    if (sdk >= 33) {
      return [
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.nearbyWifiDevices,
      ];
    }
    if (sdk >= 31) {
      return [
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ];
    }
    return [Permission.locationWhenInUse];
  }

  static Future<List<Requirement>> check() async {
    final sdk = await SystemBridge.sdkInt();
    final perms = await _permissions();
    final statuses = <Permission, PermissionStatus>{
      for (final p in perms) p: await p.status,
    };

    RequirementState stateOf(Iterable<Permission> ps) {
      final list = ps.where(statuses.containsKey).map((p) => statuses[p]!).toList();
      if (list.isEmpty || list.every((s) => s.isGranted || s.isLimited)) {
        return RequirementState.ok;
      }
      if (list.any((s) => s.isPermanentlyDenied || s.isRestricted)) {
        return RequirementState.blocked;
      }
      return RequirementState.missing;
    }

    final result = <Requirement>[];

    if (sdk >= 31) {
      final st = stateOf([
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ]);
      result.add(Requirement(
        id: 'nearby',
        icon: Icons.devices_other_rounded,
        title: 'إذن الأجهزة القريبة',
        why: 'عشان Wasl يلاقي الموبايلات القريبة ويتصل بيها بالبلوتوث. مش بيستخدم موقعك.',
        state: st,
        fixLabel: st == RequirementState.blocked ? 'افتح الإعدادات' : 'اسمح',
      ));
    }
    if (sdk >= 33) {
      final st = stateOf([Permission.nearbyWifiDevices]);
      result.add(Requirement(
        id: 'wifi',
        icon: Icons.wifi_tethering_rounded,
        title: 'إذن أجهزة الواي فاي القريبة',
        why: 'بيخلي الرسايل تتنقل أسرع بالواي فاي المباشر لما الجهازين قريبين.',
        state: st,
        fixLabel: st == RequirementState.blocked ? 'افتح الإعدادات' : 'اسمح',
      ));
    }
    if (sdk <= 32) {
      final st = stateOf([Permission.locationWhenInUse]);
      result.add(Requirement(
        id: 'location',
        icon: Icons.location_on_outlined,
        title: 'إذن الموقع',
        why: 'أندرويد ${sdk <= 30 ? '11 وأقدم' : '12'} بيشترط إذن الموقع لأي بحث عن أجهزة قريبة. Wasl مش بيقرا موقعك ولا بيحفظه.',
        state: st,
        fixLabel: st == RequirementState.blocked ? 'افتح الإعدادات' : 'اسمح',
      ));
    }

    final btSupported = await SystemBridge.bluetoothSupported();
    if (btSupported) {
      final on = await SystemBridge.bluetoothEnabled();
      result.add(Requirement(
        id: 'bluetooth',
        icon: Icons.bluetooth_rounded,
        title: 'تشغيل البلوتوث',
        why: 'الجهازين بيلاقوا بعض عن طريق البلوتوث.',
        state: on ? RequirementState.ok : RequirementState.missing,
        fixLabel: 'شغّل',
      ));
    }

    if (sdk <= 30) {
      final on = await SystemBridge.locationEnabled();
      result.add(Requirement(
        id: 'locationService',
        icon: Icons.my_location_rounded,
        title: 'تشغيل خدمة الموقع (GPS)',
        why: 'في الإصدار ده من أندرويد البحث عن الأجهزة مش بيشتغل غير والموقع شغال.',
        state: on ? RequirementState.ok : RequirementState.missing,
        fixLabel: 'شغّل',
      ));
    }
    return result;
  }

  /// يحاول إصلاح متطلب واحد.
  static Future<void> fix(Requirement r) async {
    if (r.state == RequirementState.blocked) {
      await openAppSettings();
      return;
    }
    switch (r.id) {
      case 'nearby':
        await [
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
        ].request();
      case 'wifi':
        await Permission.nearbyWifiDevices.request();
      case 'location':
        await Permission.locationWhenInUse.request();
      case 'bluetooth':
        await SystemBridge.requestBluetoothOn();
      case 'locationService':
        await SystemBridge.openLocationSettings();
    }
  }

  /// يطلب كل الأذونات الناقصة مرة واحدة (بدون الإعدادات).
  static Future<void> requestAllPermissions() async {
    final perms = await _permissions();
    final missing = <Permission>[];
    for (final p in perms) {
      final s = await p.status;
      if (!s.isGranted && !s.isLimited && !s.isPermanentlyDenied) missing.add(p);
    }
    if (missing.isNotEmpty) await missing.request();
  }
}
