import 'chat_session.dart';

/// اللي شاشة الدردشة محتاجاه عشان تبعت: الجلسة + إمكانيات وسيلة الاتصال.
class ChatLink {
  const ChatLink(this.session, {required this.supportsVideo});

  final ChatSession session;

  /// إرسال فيديو (الواي فاي بس — البلوتوث أبطأ من كده).
  final bool supportsVideo;
}
