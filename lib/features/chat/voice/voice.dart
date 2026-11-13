import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../core/chat_session.dart';

/// رسالة صوتية اتسجلت.
class VoiceClip {
  VoiceClip(this.file, this.durationMs, this.waveform);
  final File file;
  final int durationMs;
  final List<int> waveform;
}

/// تسجيل الفويس (منفّذ في VoiceRecorder.kt).
class VoiceRecorder {
  VoiceRecorder._();

  static const _channel = MethodChannel('wasl/voice');

  static bool _recording = false;
  static String? _path;
  static Timer? _poll;
  static final List<double> _levels = [];

  /// مستوى الصوت دلوقتي (0..1) — للموجة اللي بتتحرك أثناء التسجيل.
  static final ValueNotifier<double> level = ValueNotifier(0);

  static bool get isRecording => _recording;

  /// إذن الميكروفون. false = مرفوض.
  static Future<bool> ensurePermission() async {
    final st = await Permission.microphone.status;
    if (st.isGranted) return true;
    if (st.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return (await Permission.microphone.request()).isGranted;
  }

  static Future<bool> start() async {
    if (_recording) return true;
    final dir = await Directory('${(await getTemporaryDirectory()).path}/wasl_voice').create(recursive: true);
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    bool ok;
    try {
      ok = await _channel.invokeMethod<bool>('start', {'path': path}) ?? false;
    } catch (_) {
      ok = false;
    }
    if (!ok) return false;
    _recording = true;
    _path = path;
    _levels.clear();
    HapticFeedback.mediumImpact();
    _poll = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      try {
        final a = (await _channel.invokeMethod<double>('amplitude')) ?? 0;
        // جذر تربيعي عشان الأصوات الواطية تبان برضه
        final v = math.sqrt(a.clamp(0.0, 1.0));
        _levels.add(v);
        level.value = v;
      } catch (_) {}
    });
    return true;
  }

  /// يوقف ويرجّع التسجيل (null = اتلغى أو فشل).
  static Future<VoiceClip?> stop() async {
    if (!_recording) return null;
    _recording = false;
    _poll?.cancel();
    level.value = 0;
    int ms;
    try {
      ms = (await _channel.invokeMethod<num>('stop'))?.toInt() ?? -1;
    } catch (_) {
      ms = -1;
    }
    final path = _path;
    _path = null;
    if (ms < 0 || path == null) return null;
    final f = File(path);
    if (!await f.exists()) return null;
    return VoiceClip(f, ms, _downsample(_levels, 40));
  }

  static Future<void> cancel() async {
    if (!_recording) return;
    _recording = false;
    _poll?.cancel();
    level.value = 0;
    _path = null;
    try {
      await _channel.invokeMethod('cancel');
    } catch (_) {}
  }

  static List<int> _downsample(List<double> v, int n) {
    if (v.isEmpty) return List.filled(n, 4);
    return List.generate(n, (i) {
      final from = (i * v.length / n).floor();
      final to = math.max(from + 1, ((i + 1) * v.length / n).floor());
      var peak = 0.0;
      for (var k = from; k < to && k < v.length; k++) {
        peak = math.max(peak, v[k]);
      }
      return (peak * 31).round().clamp(2, 31);
    });
  }
}

/// تشغيل الرسايل الصوتية — واحدة بس في نفس الوقت.
class VoicePlayback extends ChangeNotifier {
  VoicePlayback._() {
    _player.onPositionChanged.listen((p) {
      position = p;
      notifyListeners();
    });
    _player.onDurationChanged.listen((d) {
      duration = d;
      notifyListeners();
    });
    _player.onPlayerComplete.listen((_) {
      playing = false;
      position = Duration.zero;
      current = null;
      notifyListeners();
    });
  }

  static final VoicePlayback instance = VoicePlayback._();

  final AudioPlayer _player = AudioPlayer(playerId: 'wasl-voice');
  String? current;
  bool playing = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  bool isCurrent(String path) => current == path;

  Future<void> toggle(String path) async {
    try {
      if (current == path) {
        if (playing) {
          await _player.pause();
          playing = false;
        } else {
          await _player.resume();
          playing = true;
        }
      } else {
        await _player.stop();
        current = path;
        position = Duration.zero;
        duration = Duration.zero;
        await _player.play(DeviceFileSource(path));
        playing = true;
      }
    } catch (_) {
      playing = false;
    }
    notifyListeners();
  }

  Future<void> seek(String path, double fraction, Duration total) async {
    final target = Duration(milliseconds: (total.inMilliseconds * fraction.clamp(0.0, 1.0)).round());
    if (current != path) {
      await toggle(path);
    }
    await _player.seek(target);
    position = target;
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    current = null;
    playing = false;
    position = Duration.zero;
    notifyListeners();
  }
}

/// فقاعة رسالة صوتية: تشغيل/إيقاف + موجة + مدة (زي الواتساب).
class VoiceBubbleContent extends StatelessWidget {
  const VoiceBubbleContent({super.key, required this.message, this.onCancel});

  final ChatMessage message;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = message;
    final media = m.media!;
    final mine = m.kind == MessageKind.mine;
    final fg = mine ? p.onAccent : p.text;
    final accent = mine ? p.onAccent : p.accent;
    final totalMs = media.durationMs ?? 0;
    final wave = media.waveform ?? _fakeWave(m.id);

    return ListenableBuilder(
      listenable: VoicePlayback.instance,
      builder: (context, _) {
        final pb = VoicePlayback.instance;
        final path = media.path;
        final ready = media.ready && !m.transferring;
        final isCur = path != null && pb.isCurrent(path);
        final total = isCur && pb.duration > Duration.zero ? pb.duration : Duration(milliseconds: totalMs);
        final progress = isCur && total.inMilliseconds > 0
            ? (pb.position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;
        final shown = isCur && pb.position > Duration.zero ? pb.position : total;

        Widget button;
        if (media.failed) {
          button = Icon(Icons.error_outline_rounded, color: mine ? fg : p.danger, size: 30);
        } else if (!ready) {
          button = Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  value: media.progress <= 0 ? null : media.progress,
                  strokeWidth: 2.6,
                  color: accent,
                  backgroundColor: accent.withValues(alpha: 0.2),
                ),
              ),
              if (onCancel != null)
                InkWell(onTap: onCancel, child: Icon(Icons.close_rounded, size: 18, color: fg)),
            ],
          );
        } else {
          button = IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 34,
            onPressed: () => pb.toggle(path!),
            icon: Icon(isCur && pb.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: accent),
          );
        }

        return SizedBox(
          width: 240,
          child: Row(
            children: [
              SizedBox(width: 44, height: 44, child: Center(child: button)),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LayoutBuilder(
                      builder: (context, box) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: ready
                            ? (d) {
                                final rtl = Directionality.of(context) == TextDirection.rtl;
                                var f = d.localPosition.dx / box.maxWidth;
                                if (rtl) f = 1 - f;
                                pb.seek(path!, f, total);
                              }
                            : null,
                        child: SizedBox(
                          height: 30,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _WavePainter(
                              wave,
                              progress,
                              played: accent,
                              rest: fg.withValues(alpha: 0.35),
                              rtl: Directionality.of(context) == TextDirection.rtl,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      media.failed
                          ? (media.failReason ?? context.l10n.notDelivered)
                          : ChatSession.formatDuration(shown.inMilliseconds),
                      style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.mic_rounded, size: 20, color: accent.withValues(alpha: 0.85)),
            ],
          ),
        );
      },
    );
  }

  static List<int> _fakeWave(String seed) {
    final r = math.Random(seed.hashCode);
    return List.generate(40, (_) => 4 + r.nextInt(22));
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.wave, this.progress, {required this.played, required this.rest, required this.rtl});

  final List<int> wave;
  final double progress;
  final Color played;
  final Color rest;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (wave.isEmpty) return;
    final n = wave.length;
    final slot = size.width / n;
    final barW = math.max(2.0, slot * 0.55);
    for (var i = 0; i < n; i++) {
      final h = math.max(3.0, size.height * wave[i] / 31);
      final frac = (i + 0.5) / n;
      final x = rtl ? size.width - (i + 0.5) * slot : (i + 0.5) * slot;
      final paint = Paint()
        ..color = frac <= progress ? played : rest
        ..strokeWidth = barW
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.progress != progress || old.wave != wave || old.played != played || old.rest != rest;
}

/// الموجة اللي بتتحرك أثناء التسجيل.
class LiveWave extends StatefulWidget {
  const LiveWave({super.key, required this.color});

  final Color color;

  @override
  State<LiveWave> createState() => _LiveWaveState();
}

class _LiveWaveState extends State<LiveWave> {
  final List<int> _bars = [];

  @override
  void initState() {
    super.initState();
    VoiceRecorder.level.addListener(_onLevel);
  }

  @override
  void dispose() {
    VoiceRecorder.level.removeListener(_onLevel);
    super.dispose();
  }

  void _onLevel() {
    setState(() {
      _bars.add((VoiceRecorder.level.value * 31).round().clamp(2, 31));
      if (_bars.length > 60) _bars.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: CustomPaint(
        // نسخة جديدة كل مرة: لو بعتنا نفس القائمة بعد ما اتعدلت، الرسام بيفتكر
        // إن مفيش حاجة اتغيرت ومش بيرسم تاني (فالموجة بتبان واقفة)
        painter: _WavePainter(
          _bars.isEmpty ? const [2] : List<int>.of(_bars),
          1,
          played: widget.color,
          rest: widget.color,
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
      ),
    );
  }
}
