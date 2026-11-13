import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

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

/// نص كل خطأ (العنوان + إيه اللي يتعمل) — بيتقرا باللغة الحالية وقت العرض.
enum ChatText {
  rejected,
  peerGone,
  reconnect,
  noNetwork,
  handshake,
  noPlay,
  permission,
  radio,
  alreadyConnected,
  timeout,
  generic,
  refused,
  noReply,
  unreachable,
  failed,
  lanStart,
}

/// خطأ مفهوم للمستخدم: السبب + ماذا يفعل.
class ChatError {
  const ChatError(this.kind, this.text, {this.icon = Icons.error_outline_rounded});

  final ChatErrorKind kind;
  final ChatText text;
  final IconData icon;

  String get title {
    final l = tr;
    return switch (text) {
      ChatText.rejected => l.errRejectedTitle,
      ChatText.peerGone => l.errPeerGoneTitle,
      ChatText.reconnect => l.errReconnectTitle,
      ChatText.noNetwork => l.errNoNetworkTitle,
      ChatText.handshake => l.errHandshakeTitle,
      ChatText.noPlay => l.errNoPlayTitle,
      ChatText.permission => l.errPermissionTitle,
      ChatText.radio => l.errRadioTitle,
      ChatText.alreadyConnected => l.errAlreadyConnectedTitle,
      ChatText.timeout => l.errTimeoutTitle,
      ChatText.generic => l.errGenericTitle,
      ChatText.refused => l.errRefusedTitle,
      ChatText.noReply => l.errNoReplyTitle,
      ChatText.unreachable => l.errUnreachableTitle,
      ChatText.failed => l.errFailedTitle,
      ChatText.lanStart => l.errLanStartTitle,
    };
  }

  String get hint {
    final l = tr;
    return switch (text) {
      ChatText.rejected => l.errRejectedHint,
      ChatText.peerGone => l.errPeerGoneHint,
      ChatText.reconnect => l.errReconnectHint,
      ChatText.noNetwork => l.errNoNetworkHint,
      ChatText.handshake => l.errHandshakeHint,
      ChatText.noPlay => l.errNoPlayHint,
      ChatText.permission => l.errPermissionHint,
      ChatText.radio => l.errRadioHint,
      ChatText.alreadyConnected => l.errAlreadyConnectedHint,
      ChatText.timeout => l.errTimeoutHint,
      ChatText.generic => l.errGenericHint,
      ChatText.refused => l.errRefusedHint,
      ChatText.noReply => l.errNoReplyHint,
      ChatText.unreachable => l.errUnreachableHint,
      ChatText.failed => l.errFailedHint,
      ChatText.lanStart => l.errLanStartHint,
    };
  }

  /// هل الأفضل اقتراح وضع الشبكة المحلية بدلاً من Nearby؟
  bool get suggestLan => kind == ChatErrorKind.noGoogleServices || kind == ChatErrorKind.radio;

  static const rejected = ChatError(
    ChatErrorKind.rejected,
    ChatText.rejected,
    icon: Icons.block_rounded,
  );

  static const peerGone = ChatError(
    ChatErrorKind.peerGone,
    ChatText.peerGone,
    icon: Icons.person_search_rounded,
  );

  static const reconnectTimeout = ChatError(
    ChatErrorKind.timeout,
    ChatText.reconnect,
    icon: Icons.portable_wifi_off_rounded,
  );

  static const noNetwork = ChatError(
    ChatErrorKind.network,
    ChatText.noNetwork,
    icon: Icons.wifi_off_rounded,
  );

  static const handshakeFailed = ChatError(
    ChatErrorKind.generic,
    ChatText.handshake,
    icon: Icons.gpp_maybe_rounded,
  );

  /// يحوّل أخطاء Nearby Connections (أكواد Google) لرسائل واضحة.
  static ChatError fromNearby(Object error) {
    final s = error.toString();
    bool has(List<String> keys) => keys.any(s.contains);

    if (has(['17:', 'API_UNAVAILABLE', 'SERVICE_MISSING', 'SERVICE_INVALID', 'SERVICE_DISABLED', 'API_NOT_CONNECTED'])) {
      return const ChatError(
        ChatErrorKind.noGoogleServices,
        ChatText.noPlay,
        icon: Icons.extension_off_rounded,
      );
    }
    if (has(['MISSING_PERMISSION', '8030', '8031', '8032', '8033', '8034', '8035', '8036', '8037', '8038', '8039'])) {
      return const ChatError(
        ChatErrorKind.permission,
        ChatText.permission,
        icon: Icons.privacy_tip_outlined,
      );
    }
    if (has(['8007', 'RADIO_ERROR', 'BLUETOOTH_ERROR', '8010'])) {
      return const ChatError(
        ChatErrorKind.radio,
        ChatText.radio,
        icon: Icons.bluetooth_disabled_rounded,
      );
    }
    if (has(['8004', 'CONNECTION_REJECTED'])) return rejected;
    if (has(['8011', 'ENDPOINT_UNKNOWN', '8013', 'ENDPOINT_IO_ERROR', '8012'])) return peerGone;
    if (has(['8003', 'ALREADY_CONNECTED'])) {
      return const ChatError(
        ChatErrorKind.generic,
        ChatText.alreadyConnected,
        icon: Icons.sync_problem_rounded,
      );
    }
    if (has(['15:', 'TIMEOUT', 'TIMED_OUT'])) {
      return const ChatError(
        ChatErrorKind.timeout,
        ChatText.timeout,
        icon: Icons.timer_off_rounded,
      );
    }
    return const ChatError(
      ChatErrorKind.generic,
      ChatText.generic,
    );
  }

  static ChatError fromSocket(Object error) {
    final s = error.toString();
    if (s.contains('Connection refused')) {
      return const ChatError(
        ChatErrorKind.network,
        ChatText.refused,
        icon: Icons.wifi_find_rounded,
      );
    }
    if (s.contains('timed out') || s.contains('Timeout')) {
      return const ChatError(
        ChatErrorKind.network,
        ChatText.noReply,
        icon: Icons.wifi_off_rounded,
      );
    }
    if (s.contains('Network is unreachable') || s.contains('No route')) {
      return const ChatError(
        ChatErrorKind.network,
        ChatText.unreachable,
        icon: Icons.wifi_off_rounded,
      );
    }
    return const ChatError(
      ChatErrorKind.network,
      ChatText.failed,
      icon: Icons.wifi_off_rounded,
    );
  }
}
