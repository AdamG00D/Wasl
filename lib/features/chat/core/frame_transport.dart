import 'dart:async';

/// قناة نقل "إطارات" نصية بين جهازين (فوق الشبكة — شوف PeerLink).
/// التشفير يتم فوقها في [SecureChannel].
abstract class FrameTransport {
  /// الإطارات الواردة. يكتمل الـ Stream عند انقطاع الاتصال.
  Stream<String> get frames;

  Future<void> send(String frame);

  Future<void> close();

  /// أقصى حجم لإطار واحد (بالحروف) — الملفات بتتقسم على أساسه.
  int get maxFrame;
}

/// نقل يعتمد على دوال خارجية (الإرسال عن طريق موجّه الشبكة).
class CallbackTransport implements FrameTransport {
  CallbackTransport({
    required Future<void> Function(String) sender,
    this.onClose,
    this.maxFrame = 30000,
  }) : _sender = sender;

  @override
  final int maxFrame;

  final Future<void> Function(String) _sender;
  final Future<void> Function()? onClose;
  final StreamController<String> _incoming = StreamController<String>();
  bool _closed = false;

  @override
  Stream<String> get frames => _incoming.stream;

  bool get isClosed => _closed;

  /// إطار وارد من الطرف الآخر.
  void deliver(String frame) {
    if (!_closed) _incoming.add(frame);
  }

  /// الطرف الآخر قطع الاتصال.
  void remoteClosed() {
    if (_closed) return;
    _closed = true;
    _incoming.close();
  }

  @override
  Future<void> send(String frame) {
    if (_closed) return Future.error(StateError('closed'));
    return _sender(frame);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _incoming.close();
    await onClose?.call();
  }
}
