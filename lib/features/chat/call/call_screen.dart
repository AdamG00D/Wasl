import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/feedback.dart';
import '../../../widgets/ui.dart';
import 'call_controller.dart';

/// شاشة المكالمة (واردة / بتتصل / شغالة) — زي الواتساب:
/// • الفيديو بتاع التاني بملء الشاشة وبتاعك مربع صغير تقدر تسحبه لأي ركن.
/// • تدوس على المربع الصغير يتبدّلوا.
/// • الاسم والأزرار ومدة المكالمة بيختفوا، وبيظهروا لما تلمس الشاشة.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.controller, required this.peerName});

  final CallController controller;
  final String peerName;

  static bool _open = false;

  /// يفتح الشاشة مرة واحدة بس حتى لو اتنادت أكتر من مرة.
  static Future<void> show(NavigatorState nav, CallController c, String peerName) async {
    if (_open) return;
    _open = true;
    try {
      await nav.push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CallScreen(controller: c, peerName: peerName),
      ));
    } finally {
      _open = false;
    }
  }

  @override
  State<CallScreen> createState() => _CallScreenState();
}

enum _Corner { topStart, topEnd, bottomStart, bottomEnd }

class _CallScreenState extends State<CallScreen> {
  static const _pipW = 112.0;
  static const _pipH = 164.0;
  static const _margin = 14.0;

  Timer? _ticker;
  Timer? _hideTimer;
  bool _closing = false;

  /// true = أنا الفيديو الكبير والتاني الصغير.
  bool _swapped = false;
  bool _controlsVisible = true;

  /// مكان المربع الصغير (بيتسحب) — null = الركن الافتراضي.
  Offset? _pip;
  bool _dragging = false;
  _Corner _corner = _Corner.topEnd;

  CallController get c => widget.controller;

  bool get _videoActive => c.video && c.state == CallState.active;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    c.addListener(_onChange);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && c.state == CallState.active && _controlsVisible) setState(() {});
    });
    _scheduleHide();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _ticker?.cancel();
    _hideTimer?.cancel();
    c.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    if (c.state == CallState.active) _scheduleHide();
    if (c.state == CallState.idle && !_closing) {
      _closing = true;
      _showControls();
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  // ---------------- إظهار/إخفاء الأزرار ----------------

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_videoActive) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _videoActive) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    if (!_videoActive) return;
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  /// أي ضغطة على زرار بتأخر الإخفاء.
  VoidCallback _keep(VoidCallback action) => () {
        action();
        _scheduleHide();
      };

  // ---------------- المربع الصغير ----------------

  Offset _cornerOffset(_Corner corner, Size screen, EdgeInsets safe) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final startIsLeft = !rtl;
    final left = _margin + safe.left;
    final right = screen.width - _pipW - _margin - safe.right;
    final top = _margin + safe.top + (_controlsVisible ? 64 : 0);
    final bottom = screen.height - _pipH - _margin - safe.bottom - (_controlsVisible ? 120 : 0);
    return switch (corner) {
      _Corner.topStart => Offset(startIsLeft ? left : right, top),
      _Corner.topEnd => Offset(startIsLeft ? right : left, top),
      _Corner.bottomStart => Offset(startIsLeft ? left : right, bottom),
      _Corner.bottomEnd => Offset(startIsLeft ? right : left, bottom),
    };
  }

  void _snap(Size screen, EdgeInsets safe) {
    final pos = _pip;
    if (pos == null) return;
    final center = pos + const Offset(_pipW / 2, _pipH / 2);
    var best = _corner;
    var bestDist = double.infinity;
    for (final corner in _Corner.values) {
      final o = _cornerOffset(corner, screen, safe) + const Offset(_pipW / 2, _pipH / 2);
      final d = (o - center).distanceSquared;
      if (d < bestDist) {
        bestDist = d;
        best = corner;
      }
    }
    setState(() {
      _dragging = false;
      _corner = best;
      _pip = null;
    });
  }

  String get _status {
    switch (c.state) {
      case CallState.incoming:
        return c.video ? context.l10n.callIncomingVideo : context.l10n.callIncomingVoice;
      case CallState.outgoing:
        return context.l10n.callRinging;
      case CallState.connecting:
        return context.l10n.callConnecting;
      case CallState.active:
        final d = DateTime.now().difference(c.startedAt ?? DateTime.now());
        final h = d.inHours;
        final m = (d.inMinutes % 60).toString().padLeft(2, '0');
        final s = (d.inSeconds % 60).toString().padLeft(2, '0');
        return h > 0 ? '$h:$m:$s' : '$m:$s';
      case CallState.idle:
        return c.endReason ?? context.l10n.callEnded;
    }
  }

  Future<void> _accept() async {
    final err = await c.accept();
    if (err != null && mounted) showToast(context, err, error: true);
  }

  // ---------------- الرسم ----------------

  Widget _remoteView() => c.remoteHasVideo
      ? RTCVideoView(c.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
      : _CameraOff(name: widget.peerName, label: context.l10n.cameraOff);

  Widget _localView() => c.cameraOn
      ? RTCVideoView(c.localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
      : _CameraOff(name: context.l10n.me, label: context.l10n.cameraOff);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mq = MediaQuery.of(context);
    final screen = mq.size;
    final safe = mq.padding;

    // قبل ما الطرف التاني يرد في مكالمة فيديو: الكاميرا بتاعتي بملء الشاشة (زي الواتساب)
    final ringingVideo = c.video &&
        c.cameraOn &&
        (c.state == CallState.outgoing || c.state == CallState.connecting);
    final showPip = _videoActive;
    final controlsShown = _controlsVisible || !_videoActive;

    Widget background;
    if (_videoActive) {
      background = _swapped ? _localView() : _remoteView();
    } else if (ringingVideo) {
      background = _localView();
    } else {
      background = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.accent.withValues(alpha: 0.35), const Color(0xFF05080F)],
          ),
        ),
      );
    }

    final pipPos = _pip ?? _cornerOffset(_corner, screen, safe);

    return PopScope(
      canPop: c.state == CallState.idle,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: const Color(0xFF05080F),
          body: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                child: background,
              ),

              // تدرّج خفيف ورا الكلام والأزرار عشان يبانوا فوق الفيديو
              if (_videoActive || ringingVideo)
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: controlsShown ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xB3000000)],
                          stops: [0, 0.22, 0.65, 1],
                        ),
                      ),
                    ),
                  ),
                ),

              // ---- معلومات المتصل ----
              if (_videoActive)
                // أثناء مكالمة الفيديو: سطر صغير فوق (بيختفي مع الأزرار)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !controlsShown,
                    child: AnimatedOpacity(
                      opacity: controlsShown ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                          child: Column(
                            children: [
                              Text(
                                widget.peerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_rounded, size: 12, color: Colors.white.withValues(alpha: 0.7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _status,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      if (!ringingVideo) ...[
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          child: Text(
                            initialOf(widget.peerName),
                            style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      Text(
                        widget.peerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _status,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 16,
                          shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 14, color: Colors.white.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.e2eEncrypted,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // ---- الأزرار ----
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: !controlsShown,
                  child: AnimatedSlide(
                    offset: controlsShown ? Offset.zero : const Offset(0, 0.4),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: controlsShown ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                          child: _Controls(controller: c, onAccept: _accept, keep: _keep),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ---- المربع الصغير (بيتسحب، والضغط عليه بيبدّل) ----
              if (showPip)
                AnimatedPositioned(
                  duration: _dragging ? Duration.zero : const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: pipPos.dx,
                  top: pipPos.dy,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _swapped = !_swapped);
                      _showControls();
                    },
                    onPanStart: (_) => setState(() {
                      _dragging = true;
                      _pip = pipPos;
                    }),
                    onPanUpdate: (d) => setState(() {
                      final next = (_pip ?? pipPos) + d.delta;
                      _pip = Offset(
                        next.dx.clamp(0, screen.width - _pipW),
                        next.dy.clamp(safe.top, screen.height - _pipH - safe.bottom),
                      );
                    }),
                    onPanEnd: (_) => _snap(screen, safe),
                    child: Container(
                      width: _pipW,
                      height: _pipH,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: _swapped ? _remoteView() : _localView(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// مكان الفيديو لما الكاميرا مقفولة.
class _CameraOff extends StatelessWidget {
  const _CameraOff({required this.name, required this.label});

  final String name;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF111827),
      child: LayoutBuilder(
        builder: (context, box) {
          final small = box.maxWidth < 200;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: small ? 24 : 52,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                child: Text(
                  initialOf(name),
                  style: TextStyle(color: Colors.white, fontSize: small ? 20 : 40, fontWeight: FontWeight.w700),
                ),
              ),
              if (!small) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off_rounded, size: 16, color: Colors.white.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                  ],
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(Icons.videocam_off_rounded, size: 16, color: Colors.white.withValues(alpha: 0.6)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.onAccept, required this.keep});

  final CallController controller;
  final VoidCallback onAccept;
  final VoidCallback Function(VoidCallback) keep;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.state == CallState.idle) return const SizedBox(height: 72);

    if (c.state == CallState.incoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundAction(icon: Icons.call_end_rounded, label: context.l10n.decline, color: const Color(0xFFE5484D), onTap: c.reject),
          _RoundAction(
            icon: c.video ? Icons.videocam_rounded : Icons.call_rounded,
            label: context.l10n.accept,
            color: const Color(0xFF22C55E),
            onTap: onAccept,
          ),
        ],
      );
    }

    // شريط واحد زي الواتساب: (قلب الكاميرا) (الكاميرا) (الميكروفون) (السماعة) (إنهاء)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xCC1F2937),
        borderRadius: BorderRadius.circular(36),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (c.video) ...[
            _ToggleAction(
              icon: Icons.cameraswitch_rounded,
              tooltip: context.l10n.flipCamera,
              active: false,
              onTap: keep(c.switchCamera),
            ),
            _ToggleAction(
              icon: c.cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              tooltip: context.l10n.camera,
              active: !c.cameraOn,
              onTap: keep(c.toggleCamera),
            ),
          ],
          _ToggleAction(
            icon: c.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            tooltip: c.micOn ? context.l10n.mute : context.l10n.muted,
            active: !c.micOn,
            onTap: keep(c.toggleMic),
          ),
          _ToggleAction(
            icon: c.speakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
            tooltip: c.speakerOn ? context.l10n.speaker : context.l10n.earpiece,
            active: c.speakerOn,
            onTap: keep(c.toggleSpeaker),
          ),
          _RoundAction(icon: Icons.call_end_rounded, color: const Color(0xFFE5484D), onTap: c.hangUp, size: 58),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.color, required this.onTap, this.label, this.size = 72});

  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: size, height: size, child: Icon(icon, color: Colors.white, size: size * 0.44)),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(label!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }
}

class _ToggleAction extends StatelessWidget {
  const _ToggleAction({required this.icon, required this.tooltip, required this.active, required this.onTap});

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: active ? Colors.black : Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
