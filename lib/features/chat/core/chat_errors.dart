import 'package:flutter/material.dart';

enum ChatErrorKind {
  permission,
  bluetoothOff,
  locationOff,
  noGoogleServices,
  radio,
  rejected,
  peerGone,
  timeout,
  network,
  generic,
}

/// خطأ مفهوم للمستخدم: السبب + ماذا يفعل.
class ChatError {
  const ChatError(this.kind, this.title, this.hint, {this.icon = Icons.error_outline_rounded});

  final ChatErrorKind kind;
  final String title;
  final String hint;
  final IconData icon;

  /// هل الأفضل اقتراح وضع الشبكة المحلية بدلاً من Nearby؟
  bool get suggestLan => kind == ChatErrorKind.noGoogleServices || kind == ChatErrorKind.radio;

  static const rejected = ChatError(
    ChatErrorKind.rejected,
    'الطرف التاني رفض الاتصال',
    'اطلب منه يقبل الطلب لما يظهر عنده، وجرّب تاني.',
    icon: Icons.block_rounded,
  );

  static const peerGone = ChatError(
    ChatErrorKind.peerGone,
    'الجهاز التاني مش ظاهر دلوقتي',
    'اتأكد إنه لسه فاتح شاشة الدردشة وقريب منك (أقل من 10 متر تقريباً).',
    icon: Icons.person_search_rounded,
  );

  static const reconnectTimeout = ChatError(
    ChatErrorKind.timeout,
    'معرفناش نرجّع الاتصال',
    'غالباً الجهاز التاني بعد أو قفل الشاشة. افتحوا الدردشة على الجهازين وابدأوا تاني.',
    icon: Icons.portable_wifi_off_rounded,
  );

  static const noNetwork = ChatError(
    ChatErrorKind.network,
    'مش متوصل بأي شبكة',
    'شغّل الواي فاي واتوصل بشبكة، أو افتح نقطة اتصال (Hotspot) من الإعدادات وخلّي التاني يتوصل بيها.',
    icon: Icons.wifi_off_rounded,
  );

  static const handshakeFailed = ChatError(
    ChatErrorKind.generic,
    'معرفناش نأمّن الاتصال',
    'حصل خطأ أثناء تبادل مفاتيح التشفير. تأكد إن الجهازين عليهم آخر نسخة من Wasl وجرّب تاني.',
    icon: Icons.gpp_maybe_rounded,
  );

  /// يحوّل أخطاء Nearby Connections (أكواد Google) لرسائل واضحة.
  static ChatError fromNearby(Object error) {
    final s = error.toString();
    bool has(List<String> keys) => keys.any(s.contains);

    if (has(['17:', 'API_UNAVAILABLE', 'SERVICE_MISSING', 'SERVICE_INVALID', 'SERVICE_DISABLED', 'API_NOT_CONNECTED'])) {
      return const ChatError(
        ChatErrorKind.noGoogleServices,
        'الدردشة القريبة محتاجة خدمات Google Play',
        'الجهاز ده مفيهوش خدمات Google أو محتاجة تحديث. حدّث "خدمات Google Play" من المتجر، أو استخدم الدردشة عبر الواي فاي.',
        icon: Icons.extension_off_rounded,
      );
    }
    if (has(['MISSING_PERMISSION', '8030', '8031', '8032', '8033', '8034', '8035', '8036', '8037', '8038', '8039'])) {
      return const ChatError(
        ChatErrorKind.permission,
        'ناقص إذن',
        'التطبيق محتاج إذن "الأجهزة القريبة" عشان يلاقي الجهاز التاني. اسمح بيه وجرّب تاني.',
        icon: Icons.privacy_tip_outlined,
      );
    }
    if (has(['8007', 'RADIO_ERROR', 'BLUETOOTH_ERROR', '8010'])) {
      return const ChatError(
        ChatErrorKind.radio,
        'البلوتوث أو الواي فاي مش مستجيب',
        'اقفل البلوتوث وافتحه تاني (ولو ينفع الواي فاي كمان)، وبعدين جرّب. لو المشكلة استمرت اعمل ريستارت للموبايل.',
        icon: Icons.bluetooth_disabled_rounded,
      );
    }
    if (has(['8004', 'CONNECTION_REJECTED'])) return rejected;
    if (has(['8011', 'ENDPOINT_UNKNOWN', '8013', 'ENDPOINT_IO_ERROR', '8012'])) return peerGone;
    if (has(['8003', 'ALREADY_CONNECTED'])) {
      return const ChatError(
        ChatErrorKind.generic,
        'فيه اتصال قديم لسه مفتوح',
        'اقفل شاشة الدردشة على الجهازين وافتحها تاني.',
        icon: Icons.sync_problem_rounded,
      );
    }
    if (has(['15:', 'TIMEOUT', 'TIMED_OUT'])) {
      return const ChatError(
        ChatErrorKind.timeout,
        'الاتصال أخد وقت أطول من اللازم',
        'قرّب الجهازين من بعض وجرّب تاني.',
        icon: Icons.timer_off_rounded,
      );
    }
    return const ChatError(
      ChatErrorKind.generic,
      'حصلت مشكلة في الاتصال',
      'جرّب تقفل الدردشة وتفتحها تاني على الجهازين. لو المشكلة فضلت، اقفل البلوتوث وافتحه.',
    );
  }

  static ChatError fromSocket(Object error) {
    final s = error.toString();
    if (s.contains('Connection refused')) {
      return const ChatError(
        ChatErrorKind.network,
        'الجهاز التاني مش مستني اتصال',
        'اتأكد إنه داس "استضافة" وإن العنوان مكتوب صح.',
        icon: Icons.wifi_find_rounded,
      );
    }
    if (s.contains('timed out') || s.contains('Timeout')) {
      return const ChatError(
        ChatErrorKind.network,
        'مفيش رد من العنوان ده',
        'الجهازين لازم يكونوا على نفس شبكة الواي فاي (أو واحد فاتح Hotspot والتاني متوصل بيه). بعض الراوترات العامة بتمنع الأجهزة تكلم بعض.',
        icon: Icons.wifi_off_rounded,
      );
    }
    if (s.contains('Network is unreachable') || s.contains('No route')) {
      return const ChatError(
        ChatErrorKind.network,
        'مش متوصل بشبكة',
        'شغّل الواي فاي واتوصل بنفس الشبكة اللي عليها الجهاز التاني.',
        icon: Icons.wifi_off_rounded,
      );
    }
    return const ChatError(
      ChatErrorKind.network,
      'تعذّر الاتصال',
      'اتأكد من العنوان وإن الجهازين على نفس الشبكة.',
      icon: Icons.wifi_off_rounded,
    );
  }
}
