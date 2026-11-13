import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/crypto/kdf.dart';
import '../../../core/platform/system_bridge.dart';
import '../../../l10n/l10n.dart';
import '../core/chat_session.dart';

enum CallState {
  /// مفيش مكالمة.
  idle,

  /// بنتصل وبيرن عند التاني.
  outgoing,

  /// مكالمة واردة بترن.
  incoming,

  /// اتقبلت وجاري توصيل الصوت/الصورة.
  connecting,

  /// شغالة.
  active,
}

/// مكالمات صوت وفيديو عبر WebRTC على الشبكة المحلية (واي فاي / هوت سبوت).
///
/// الأمان: كل إشارات إعداد المكالمة (SDP وبصمات DTLS ومرشحات ICE) بتتبعت
/// جوه القناة المشفرة من طرف لطرف، فمحدش يقدر يدخل في النص؛
/// والصوت والصورة نفسهم مشفرين بـ DTLS-SRTP. من غير أي سيرفر خارجي.
class CallController extends ChangeNotifier {
  CallController(this.session) {
    session.onCallSignal = _onSignal;
    session.addListener(_onSessionChanged);
  }

  final ChatSession session;

  static const _ringTimeout = Duration(seconds: 45);
  static const _connectTimeout = Duration(seconds: 25);

  CallState state = CallState.idle;
  bool video = false;
  bool micOn = true;
  bool speakerOn = false;
  bool cameraOn = true;
  bool remoteHasVideo = false;
  DateTime? startedAt;

  /// سبب آخر انتهاء (يتعرض في شاشة المكالمة).
  String? endReason;

  /// بيتنادى لما توصل مكالمة (عشان نفتح شاشة المكالمة).
  VoidCallback? onIncoming;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;

  String? _callId;
  RTCPeerConnection? _pc;
  MediaStream? _local;
  final List<RTCIceCandidate> _pendingIce = [];
  bool _remoteSet = false;
  Timer? _timeout;
  Timer? _vibrate;
  final AudioPlayer _ring = AudioPlayer();
  bool _disposed = false;

  bool get busy => state != CallState.idle;

  // ---------------- أوامر المستخدم ----------------

  /// يبدأ مكالمة. يرجّع رسالة خطأ أو null.
  Future<String?> startCall({required bool video}) async {
    if (busy) return tr.callBusy;
    if (!session.canSend) return tr.notConnectedNow;
    final denied = await _askPermissions(video);
    if (denied != null) return denied;

    this.video = video;
    _callId = Kdf.hex(Kdf.randomBytes(6));
    endReason = null;
    _setState(CallState.outgoing);
    try {
      await session.sendCallSignal({'op': 'invite', 'cid': _callId, 'video': video});
    } catch (_) {
      await _finish(tr.notConnectedNow, notifyPeer: false);
      return tr.notConnectedNow;
    }
    unawaited(_playRing(outgoing: true));
    _timeout = Timer(_ringTimeout, () => _finish(tr.callNoAnswer));
    return null;
  }

  /// قبول مكالمة واردة. يرجّع رسالة خطأ أو null.
  Future<String?> accept() async {
    if (state != CallState.incoming) return null;
    final denied = await _askPermissions(video);
    if (denied != null) {
      await _finish(denied);
      return denied;
    }
    _stopRing();
    _timeout?.cancel();
    _setState(CallState.connecting);
    try {
      await _setupPeer();
      await session.sendCallSignal({'op': 'accept', 'cid': _callId});
      _timeout = Timer(_connectTimeout, () => _finish(tr.callConnectFailed));
    } catch (_) {
      await _finish(tr.callStartFailed);
      return tr.callMediaFailed;
    }
    return null;
  }

  Future<void> reject() => _finish(tr.callRejected, op: 'reject');

  Future<void> hangUp() => _finish(tr.callEnded);

  void toggleMic() {
    micOn = !micOn;
    for (final t in _local?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = micOn;
    }
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    speakerOn = !speakerOn;
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
    } catch (_) {}
    notifyListeners();
  }

  void toggleCamera() {
    cameraOn = !cameraOn;
    for (final t in _local?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = cameraOn;
    }
    notifyListeners();
  }

  Future<void> switchCamera() async {
    final tracks = _local?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    try {
      await Helper.switchCamera(tracks.first);
    } catch (_) {}
  }

  // ---------------- الإشارات ----------------

  Future<void> _onSignal(Map<String, dynamic> m) async {
    final op = m['op'];
    final cid = '${m['cid']}';

    if (op == 'invite') {
      if (busy) {
        session.sendCallSignal({'op': 'busy', 'cid': cid}).catchError((_) {});
        return;
      }
      _callId = cid;
      video = m['video'] == true;
      endReason = null;
      _setState(CallState.incoming);
      unawaited(_playRing(outgoing: false));
      _timeout = Timer(_ringTimeout, () => _finish(tr.callMissed, notifyPeer: false));
      onIncoming?.call();
      return;
    }
    if (cid != _callId) return; // إشارة لمكالمة قديمة

    try {
      switch (op) {
        case 'accept':
          if (state != CallState.outgoing) return;
          _stopRing();
          _timeout?.cancel();
          _setState(CallState.connecting);
          await _setupPeer();
          final offer = await _pc!.createOffer();
          await _pc!.setLocalDescription(offer);
          await session.sendCallSignal({'op': 'offer', 'cid': cid, 'sdp': offer.sdp, 'type': offer.type});
          _timeout = Timer(_connectTimeout, () => _finish(tr.callConnectFailed));
        case 'offer':
          final pc = _pc;
          if (pc == null) return;
          await pc.setRemoteDescription(RTCSessionDescription('${m['sdp']}', '${m['type']}'));
          await _flushIce();
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          await session.sendCallSignal({'op': 'answer', 'cid': cid, 'sdp': answer.sdp, 'type': answer.type});
        case 'answer':
          final pc = _pc;
          if (pc == null) return;
          await pc.setRemoteDescription(RTCSessionDescription('${m['sdp']}', '${m['type']}'));
          await _flushIce();
        case 'ice':
          final c = RTCIceCandidate(
            m['candidate'] as String?,
            m['sdpMid'] as String?,
            (m['sdpMLineIndex'] as num?)?.toInt(),
          );
          if (_remoteSet && _pc != null) {
            await _pc!.addCandidate(c);
          } else {
            _pendingIce.add(c);
          }
        case 'reject':
          await _finish(tr.callPeerRejected, notifyPeer: false);
        case 'busy':
          await _finish(tr.callPeerBusy, notifyPeer: false);
        case 'end':
          await _finish(state == CallState.incoming ? tr.callMissed : tr.callPeerHungUp, notifyPeer: false);
      }
    } catch (_) {
      await _finish(tr.callProblem);
    }
  }

  Future<void> _flushIce() async {
    _remoteSet = true;
    final pc = _pc;
    if (pc == null) return;
    for (final c in _pendingIce) {
      await pc.addCandidate(c);
    }
    _pendingIce.clear();
  }

  // ---------------- WebRTC ----------------

  Future<void> _setupPeer() async {
    if (!_renderersReady) {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _renderersReady = true;
    }
    await SystemBridge.updateChatService(microphone: true, camera: video);

    final local = await navigator.mediaDevices.getUserMedia({
      'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
              'frameRate': {'ideal': 30},
            }
          : false,
    });
    _local = local;
    if (video) localRenderer.srcObject = local;

    // على نفس الشبكة: مفيش سيرفر STUN/TURN — اتصال مباشر بين الجهازين
    final pc = await createPeerConnection({'iceServers': <Map<String, dynamic>>[], 'sdpSemantics': 'unified-plan'});
    _pc = pc;
    for (final t in local.getTracks()) {
      await pc.addTrack(t, local);
    }
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      session.sendCallSignal({
        'op': 'ice',
        'cid': _callId,
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      }).catchError((_) {});
    };
    pc.onTrack = (e) {
      if (e.streams.isNotEmpty) remoteRenderer.srcObject = e.streams.first;
      if (e.track.kind == 'video') remoteHasVideo = true;
      notifyListeners();
    };
    pc.onConnectionState = (s) {
      switch (s) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _timeout?.cancel();
          if (state != CallState.active) {
            startedAt = DateTime.now();
            _setState(CallState.active);
          }
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _finish(tr.callIceFailed);
        default:
          break;
      }
    };

    speakerOn = video; // الفيديو على السماعة الخارجية، الصوت على سماعة الأذن
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
    } catch (_) {}
  }

  Future<String?> _askPermissions(bool video) async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      return mic.isPermanentlyDenied
          ? tr.micDeniedForever
          : tr.micNeededCall;
    }
    if (video) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        return cam.isPermanentlyDenied
            ? tr.camDeniedForever
            : tr.camNeededCall;
      }
    }
    return null;
  }

  // ---------------- الرنة ----------------

  Future<void> _playRing({required bool outgoing}) async {
    try {
      await _ring.setReleaseMode(ReleaseMode.loop);
      await _ring.play(AssetSource('audio/ring.wav'), volume: outgoing ? 0.3 : 1);
    } catch (_) {}
    if (!outgoing) {
      _vibrate?.cancel();
      _vibrate = Timer.periodic(const Duration(milliseconds: 1500), (_) => HapticFeedback.vibrate());
    }
  }

  void _stopRing() {
    _vibrate?.cancel();
    _vibrate = null;
    _ring.stop().catchError((_) {});
  }

  // ---------------- الإنهاء ----------------

  void _onSessionChanged() {
    if (busy && session.state != SessionState.ready) {
      _finish(tr.callDropped, notifyPeer: false);
    }
  }

  Future<void> _finish(String reason, {bool notifyPeer = true, String op = 'end'}) async {
    if (state == CallState.idle) return;
    final cid = _callId;
    _timeout?.cancel();
    _stopRing();
    if (notifyPeer && cid != null) {
      session.sendCallSignal({'op': op, 'cid': cid}).catchError((_) {});
    }
    _callId = null;
    final pc = _pc;
    _pc = null;
    final local = _local;
    _local = null;
    _pendingIce.clear();
    _remoteSet = false;
    remoteHasVideo = false;
    startedAt = null;
    micOn = true;
    cameraOn = true;
    if (_renderersReady) {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    }
    try {
      for (final t in local?.getTracks() ?? const <MediaStreamTrack>[]) {
        await t.stop();
      }
      await local?.dispose();
      await pc?.close();
    } catch (_) {}
    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}
    await SystemBridge.updateChatService(microphone: false, camera: false);
    endReason = reason;
    _setState(CallState.idle);
  }

  void _setState(CallState s) {
    state = s;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _finish(tr.chatEnded, notifyPeer: false);
    session.removeListener(_onSessionChanged);
    if (session.onCallSignal == _onSignal) session.onCallSignal = null;
    _disposed = true;
    _ring.dispose();
    if (_renderersReady) {
      localRenderer.dispose();
      remoteRenderer.dispose();
    }
    super.dispose();
  }
}
