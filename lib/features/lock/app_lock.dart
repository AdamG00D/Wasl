import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/nav.dart';
import '../../core/settings/app_settings.dart';
import '../../core/storage/vault.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../hub/chat_hub.dart';

/// قفل التطبيق برقم سري (اختياري — مقفول افتراضياً).
///
/// القفل شاشة بتتحط **فوق** أي حاجة مفتوحة، فمفيش حاجة بتضيع: المحادثات
/// والشبكة بيفضلوا شغالين تحتها، وأول ما يتفتح ترجع لمكانك.
class AppLock with WidgetsBindingObserver {
  AppLock._();
  static final AppLock instance = AppLock._();

  bool _locked = false;
  DateTime? _pausedAt;

  bool get locked => _locked;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    ChatHub.instance.isLocked = () => _locked;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final s = AppSettings.instance;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _pausedAt;
      _pausedAt = null;
      if (!s.lockEnabled || _locked || since == null) return;
      if (DateTime.now().difference(since) >= Duration(minutes: s.lockAfterMinutes)) lock();
    }
  }

  /// يقفل دلوقتي (لو فيه رقم سري).
  void lock() {
    if (_locked || !AppSettings.instance.lockEnabled) return;
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    _locked = true;
    nav.push(PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (_, _, _) => const LockScreen(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 180),
    ));
  }

  /// بوابة البداية ظاهرة (التطبيق لسه فاتح ومقفول).
  void lockedAtStart() => _locked = AppSettings.instance.lockEnabled;

  void _unlocked() {
    _locked = false;
    ChatHub.instance.afterUnlock();
  }
}

/// شاشة الرقم السري (فوق التطبيق، أو بوابة أول ما يفتح).
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, this.onUnlocked});

  /// لو متحددة: الشاشة دي بوابة البداية ومش route فوق حاجة.
  final VoidCallback? onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _checking = false;
  bool _wrong = false;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _initBio();
  }

  Future<void> _initBio() async {
    if (!AppSettings.instance.biometric) return;
    final ok = await Vault.biometricAvailable();
    if (!mounted) return;
    setState(() => _bioAvailable = ok);
    if (ok) _bio();
  }

  Future<void> _bio() async {
    final l = context.l10n;
    final ok = await Vault.biometricAuth(title: l.lockBioTitle, subtitle: l.lockBioSubtitle);
    if (ok && mounted) _done();
  }

  void _done() {
    AppLock.instance._unlocked();
    final gate = widget.onUnlocked;
    if (gate != null) {
      gate();
      return;
    }
    // بنشيل الشاشة دي بالذات (ممكن يكون فوقها شاشة مكالمة)
    final route = ModalRoute.of(context);
    if (route != null) Navigator.of(context).removeRoute(route);
  }

  Future<void> _submit() async {
    if (_pin.length < 4 || _checking) return;
    setState(() => _checking = true);
    final ok = await AppSettings.instance.checkPin(_pin);
    if (!mounted) return;
    if (ok) {
      _done();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _checking = false;
        _wrong = true;
        _pin = '';
      });
    }
  }

  void _tap(String d) {
    if (_checking || _pin.length >= 8) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _wrong = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final call = ChatHub.instance.hasActiveCall;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(gradient: p.accentGradient, borderRadius: BorderRadius.circular(26)),
                child: Icon(Icons.lock_rounded, color: p.onAccent, size: 34),
              ),
              const SizedBox(height: 18),
              Text(
                call ? context.l10n.lockIncomingCall : context.l10n.lockEnterPin,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              AnimatedOpacity(
                opacity: _wrong ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Text(context.l10n.lockWrongPin, style: TextStyle(color: p.danger, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 20,
                child: _checking
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: p.accent))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < (_pin.length < 4 ? 4 : _pin.length); i++)
                            Container(
                              width: 14,
                              height: 14,
                              margin: const EdgeInsets.symmetric(horizontal: 7),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < _pin.length ? p.accent : Colors.transparent,
                                border: Border.all(color: i < _pin.length ? p.accent : p.textMuted, width: 1.6),
                              ),
                            ),
                        ],
                      ),
              ),
              const Spacer(),
              PinPad(
                onDigit: _tap,
                onBack: () => setState(() {
                  if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
                }),
                onOk: _pin.length >= 4 ? _submit : null,
                extra: _bioAvailable ? IconButton(onPressed: _bio, iconSize: 30, icon: const Icon(Icons.fingerprint_rounded)) : null,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// لوحة أرقام (دايماً شمال-يمين زي أي لوحة أرقام).
class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onDigit, required this.onBack, this.onOk, this.extra});

  final ValueChanged<String> onDigit;
  final VoidCallback onBack;
  final VoidCallback? onOk;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget key(String d) => _PadKey(
          onTap: () => onDigit(d),
          child: Text(d, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
        );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) key(d)]),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PadKey(onTap: onBack, plain: true, child: Icon(Icons.backspace_outlined, color: p.textMuted)),
              key('0'),
              _PadKey(
                onTap: onOk,
                plain: true,
                child: Icon(Icons.check_circle_rounded, size: 34, color: onOk == null ? p.border : p.accent),
              ),
            ],
          ),
          if (extra != null) Padding(padding: const EdgeInsets.only(top: 6), child: extra),
        ],
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({required this.child, required this.onTap, this.plain = false});

  final Widget child;
  final VoidCallback? onTap;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: plain ? Colors.transparent : p.surface,
        shape: CircleBorder(side: BorderSide(color: plain ? Colors.transparent : p.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 72, height: 72, child: Center(child: child)),
        ),
      ),
    );
  }
}
