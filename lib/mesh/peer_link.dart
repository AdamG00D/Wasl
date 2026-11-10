import '../core/crypto/kdf.dart';
import '../features/chat/core/chat_session.dart';
import '../features/chat/core/frame_transport.dart';

/// بيربط [ChatSession] بشخص معين عبر الشبكة (Mesh).
///
/// كل اتصال له "رقم جلسة" عشوائي بيتحط قبل كل إطار:  `رقم|الإطار`
///  • اللي بيبدأ الاتصال بيختار الرقم، والتاني بيمشي عليه.
///  • لو وصل hello برقم جديد: الطرف التاني بدأ اتصال جديد (فتح المحادثة أو
///    رجع بعد ما فصل) — بنقفل القديم ونمشي على الجديد.
///  • لو الاتنين بدأوا في نفس اللحظة: رقم صاحب المعرّف الأصغر هو اللي بيكمّل.
///  • أي إطار برقم قديم بيترمي.
class PeerLink {
  PeerLink({
    required this.myId,
    required this.peerId,
    required this.session,
    required this.send,
    required this.maxFrame,
  });

  final String myId;
  final String peerId;
  final ChatSession session;

  /// يبعت للشخص ده عبر الشبكة.
  final Future<void> Function(String body) send;
  final int Function() maxFrame;

  CallbackTransport? _transport;
  String? _sid;
  bool _dialed = false;

  bool get busy => session.state == SessionState.ready || session.state == SessionState.securing;

  /// يبدأ اتصال جديد (لو مفيش واحد شغال أو بيتعمل).
  void dial() {
    if (busy) return;
    _dialed = true;
    _attach(Kdf.hex(Kdf.randomBytes(4)));
  }

  void _attach(String sid) {
    _sid = sid;
    final t = CallbackTransport(sender: (frame) => send('$sid|$frame'), maxFrame: maxFrame() - 16);
    _transport = t;
    session.attach(t);
  }

  static bool isHello(String body) {
    final bar = body.indexOf('|');
    return bar > 0 && body.startsWith('{"t":"hello"', bar + 1);
  }

  /// إطار وصل من الشخص ده. يرجّع true لو ده اتصال جديد هو اللي بدأه.
  bool onFrame(String body) {
    final bar = body.indexOf('|');
    if (bar <= 0 || bar > 16) return false;
    final sid = body.substring(0, bar);
    final frame = body.substring(bar + 1);
    final t = _transport;
    if (sid == _sid && t != null && !t.isClosed) {
      t.deliver(frame);
      return false;
    }
    if (!frame.startsWith('{"t":"hello"')) return false;
    final mineInProgress = _dialed && session.state == SessionState.securing;
    if (mineInProgress && myId.compareTo(peerId) < 0) return false;
    _dialed = false;
    _attach(sid);
    _transport!.deliver(frame);
    return true;
  }
}
