import '../features/chat/core/chat_errors.dart';
import 'lan_link.dart';
import 'mesh_link.dart';
import 'nearby_link.dart';

/// الواي فاي والبلوتوث مع بعض: الموبايل بيبقى "كوبري" بين شبكتين.
///
/// كل وصلة ليها بادئة (`w:` واي فاي، `b:` بلوتوث) والـ [MeshRouter] بيتعامل معاهم
/// كأنهم وسيلة واحدة — فالرسايل بتعدّي من هوت سبوت لهوت سبوت تاني عن طريق البلوتوث.
///
/// • لو نفس الجهاز ظاهر بالطريقتين بنكمّل بالواي فاي (أسرع) والبلوتوث بيتقفل.
/// • الإطارات الكبيرة اللي جاية من الواي فاي بتتقسم لما تعدّي على البلوتوث.
class DualLink extends MeshLink {
  DualLink(super.myId, {MeshLink? wifi, MeshLink? bluetooth})
      : wifi = wifi ?? LanLink(myId),
        bluetooth = bluetooth ?? NearbyLink(myId) {
    _wire(this.wifi, _w);
    _wire(this.bluetooth, _b);
    // الواي فاي بيتصل حتى لو فيه وصلة بلوتوث (هياخد مكانها)، والبلوتوث لأ لو فيه أي وصلة
    this.wifi.isLinked = (id) => linkOf(id)?.startsWith(_w) ?? false;
    this.bluetooth.isLinked = (id) => linkOf(id) != null;
  }

  static const _w = 'w:';
  static const _b = 'b:';

  final MeshLink wifi;
  final MeshLink bluetooth;

  void _wire(MeshLink child, String prefix) {
    child
      ..onUp = ((l) => onUp?.call('$prefix$l'))
      ..onFrame = ((l, f) => onFrame?.call('$prefix$l', f))
      ..onDown = ((l) => onDown?.call('$prefix$l'))
      ..addListener(_sync);
  }

  void _sync() {
    final phases = [wifi.phase, bluetooth.phase];
    phase = phases.contains(LinkPhase.running)
        ? LinkPhase.running
        : phases.contains(LinkPhase.starting)
            ? LinkPhase.starting
            : phases.every((p) => p == LinkPhase.failed)
                ? LinkPhase.failed
                : LinkPhase.idle;
    error = wifi.error ?? bluetooth.error;
    notifyListeners();
  }

  (MeshLink, String) _split(String link) =>
      link.startsWith(_w) ? (wifi, link.substring(2)) : (bluetooth, link.substring(2));

  bool isWifi(String link) => link.startsWith(_w);

  @override
  int get maxFrame => wifi.maxFrame;

  @override
  int frameLimit(String link) {
    final (child, id) = _split(link);
    return child.frameLimit(id);
  }

  @override
  int rank(String link) => isWifi(link) ? 1 : 0;

  @override
  bool get supportsVideo => wifi.supportsVideo;

  @override
  bool get supportsCalls => wifi.supportsCalls;

  @override
  int get directFileLimit => wifi.directFileLimit;

  /// ملفات الجروبات بتتبث للكل، يعني ممكن تعدّي على بلوتوث: بنمشي على حدّه.
  @override
  int get groupFileLimit => bluetooth.groupFileLimit;

  @override
  Duration get floodPacing => bluetooth.floodPacing;

  @override
  bool isOutgoing(String link) {
    final (child, id) = _split(link);
    return child.isOutgoing(id);
  }

  @override
  Future<void> start() async {
    await Future.wait([wifi.start(), bluetooth.start()]);
    _sync();
  }

  @override
  Future<void> stop() async {
    await Future.wait([wifi.stop(), bluetooth.stop()]);
    _sync();
  }

  @override
  Future<void> retry() async {
    await Future.wait([wifi.retry(), bluetooth.retry()]);
    _sync();
  }

  @override
  void clearError() {
    wifi.clearError();
    bluetooth.clearError();
  }

  @override
  Future<void> send(String link, String frame) {
    final (child, id) = _split(link);
    return child.send(id, frame);
  }

  @override
  void drop(String link) {
    final (child, id) = _split(link);
    child.drop(id);
  }

  /// أخطاء كل وسيلة لوحدها (للواجهة).
  List<(MeshLink, ChatError)> get errors => [
        if (wifi.error case final ChatError e) (wifi, e),
        if (bluetooth.error case final ChatError e) (bluetooth, e),
      ];

  @override
  void dispose() {
    wifi
      ..removeListener(_sync)
      ..dispose();
    bluetooth
      ..removeListener(_sync)
      ..dispose();
    super.dispose();
  }
}
