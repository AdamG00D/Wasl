import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/profile/profile.dart';
import '../../core/settings/app_settings.dart';
import '../../core/storage/chat_store.dart';
import '../../core/storage/vault.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/ui.dart';
import '../hub/chat_hub.dart';
import '../lock/app_lock.dart';
import '../onboarding/profile_editor.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettings.instance;
  final _hub = ChatHub.instance;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    Vault.biometricAvailable().then((v) {
      if (mounted) setState(() => _bioAvailable = v);
    });
    ChatStore.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _toggleSave(bool v) async {
    if (!v) {
      final ok = await confirmDialog(
        context,
        icon: Icons.bookmark_remove_rounded,
        title: 'توقف حفظ المحادثات؟',
        message: 'المحادثات المحفوظة هتتمسح من تخزين الموبايل (ما عدا اللي اخترت تحفظها بنفسك من جوه المحادثة).',
        confirm: 'وقّف الحفظ',
        destructive: true,
      );
      if (!ok) return;
    }
    await _settings.setSaveChats(v);
    if (mounted) showToast(context, v ? 'المحادثات هتتحفظ على الموبايل (مشفّرة)' : 'المحادثات مش هتتحفظ');
  }

  Future<void> _setPin() async {
    final pin = await _PinSetup.show(context);
    if (pin == null) return;
    await _settings.setPin(pin);
    if (mounted) showToast(context, 'القفل اتفعّل');
  }

  Future<void> _removePin() async {
    final pin = await _PinSetup.show(context, verifyOnly: true);
    if (pin == null) return;
    await _settings.setPin(null);
    if (mounted) showToast(context, 'القفل اتشال');
  }

  Future<void> _toggleBio(bool v) async {
    if (v) {
      final ok = await Vault.biometricAuth(title: 'تأكيد البصمة', subtitle: 'عشان تفتح Wasl بيها');
      if (!ok) return;
    }
    await _settings.setBiometric(v);
  }

  Future<void> _wipe() async {
    final ok = await confirmDialog(
      context,
      icon: Icons.delete_forever_rounded,
      title: 'مسح كل المحادثات؟',
      message: 'كل الرسايل والملفات المحفوظة هتتمسح من موبايلك نهائياً. بروفايلك والجروبات اللي إنت فيها هيفضلوا.',
      confirm: 'امسح الكل',
      destructive: true,
    );
    if (!ok) return;
    await _hub.wipeAll();
    if (mounted) showToast(context, 'اتمسح كل حاجة');
  }

  Future<void> _showBlocked() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => ListenableBuilder(
        listenable: _hub,
        builder: (ctx, _) {
          final ids = _hub.blockedIds;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('المحظورين', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (ids.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text('مفيش حد محظور.', style: TextStyle(color: ctx.palette.textMuted)),
                    ),
                  for (final id in ids)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Avatar(name: _hub.nameOf(id) ?? '؟', color: id.hashCode, size: 40),
                      title: Text(_hub.nameOf(id) ?? 'شخص (${id.substring(0, 6)})'),
                      trailing: TextButton(
                        onPressed: () => _hub.setBlocked(id, false),
                        child: const Text('إلغاء الحظر'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_settings, ProfileStore.instance]),
      builder: (context, _) {
        final p = context.palette;
        final me = ProfileStore.instance.current!;
        final s = _settings;
        return AppScaffold(
          title: 'الإعدادات',
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              AppCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfileEditor())),
                child: Row(
                  children: [
                    Avatar(name: me.name, color: me.color, avatarHash: me.avatarHash, cartoon: me.cartoon, size: 62),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(me.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('تعديل الاسم والصورة واللون', style: TextStyle(color: p.textMuted, fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_outlined, color: p.textMuted),
                  ],
                ),
              ),
              const SectionLabel('الخصوصية'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    SettingTile(
                      icon: Icons.bookmark_outline_rounded,
                      title: 'حفظ المحادثات على الموبايل',
                      subtitle: s.saveChats
                          ? 'الرسايل بتتحفظ مشفّرة وبتلاقيها لما تفتح التطبيق تاني.'
                          : 'مقفول: المحادثات بتتمسح لما تقفل التطبيق. تقدر تحفظ محادثة معينة من جواها.',
                      trailing: Switch(value: s.saveChats, onChanged: _toggleSave),
                    ),
                    Divider(indent: 68, color: p.border),
                    SettingTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'قفل التطبيق برقم سري',
                      subtitle: s.lockEnabled ? 'متفعّل — اضغط عشان تشيله' : 'اختياري. من غيره التطبيق بيفتح على طول.',
                      trailing: Switch(value: s.lockEnabled, onChanged: (v) => v ? _setPin() : _removePin()),
                      onTap: s.lockEnabled ? _removePin : _setPin,
                    ),
                    if (s.lockEnabled) ...[
                      if (_bioAvailable) ...[
                        Divider(indent: 68, color: p.border),
                        SettingTile(
                          icon: Icons.fingerprint_rounded,
                          title: 'فتح بالبصمة',
                          trailing: Switch(value: s.biometric, onChanged: _toggleBio),
                        ),
                      ],
                      Divider(indent: 68, color: p.border),
                      SettingTile(
                        icon: Icons.timer_outlined,
                        title: 'القفل التلقائي',
                        subtitle: 'بعد ما تسيب التطبيق',
                        trailing: DropdownButton<int>(
                          value: const [0, 1, 5, 15].contains(s.lockAfterMinutes) ? s.lockAfterMinutes : 1,
                          underline: const SizedBox.shrink(),
                          borderRadius: BorderRadius.circular(16),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('على طول')),
                            DropdownMenuItem(value: 1, child: Text('دقيقة')),
                            DropdownMenuItem(value: 5, child: Text('5 دقايق')),
                            DropdownMenuItem(value: 15, child: Text('15 دقيقة')),
                          ],
                          onChanged: (v) => s.setLockAfter(v ?? 1),
                        ),
                      ),
                    ],
                    Divider(indent: 68, color: p.border),
                    SettingTile(
                      icon: Icons.block_rounded,
                      title: 'المحظورين',
                      subtitle: _hub.blockedIds.isEmpty ? 'مفيش حد' : '${_hub.blockedIds.length}',
                      trailing: Icon(Icons.chevron_left_rounded, color: p.textMuted),
                      onTap: _showBlocked,
                    ),
                    Divider(indent: 68, color: p.border),
                    SettingTile(
                      icon: Icons.delete_forever_outlined,
                      title: 'مسح كل المحادثات',
                      color: p.danger,
                      onTap: _wipe,
                    ),
                  ],
                ),
              ),
              const SectionLabel('المظهر'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, label: Text('تلقائي'), icon: Icon(Icons.brightness_auto_rounded)),
                        ButtonSegment(value: ThemeMode.light, label: Text('فاتح'), icon: Icon(Icons.light_mode_rounded)),
                        ButtonSegment(value: ThemeMode.dark, label: Text('غامق'), icon: Icon(Icons.dark_mode_rounded)),
                      ],
                      selected: {s.themeMode},
                      onSelectionChanged: (v) => s.setThemeMode(v.first),
                    ),
                    const SizedBox(height: 18),
                    Text('لون التطبيق', style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final a in AccentTheme.all)
                          Tooltip(
                            message: a.label,
                            child: GestureDetector(
                              onTap: () => s.setAccent(a),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [a.accent(Theme.of(context).brightness), a.second(Theme.of(context).brightness)],
                                    begin: AlignmentDirectional.topStart,
                                    end: AlignmentDirectional.bottomEnd,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: s.accent.id == a.id ? p.text : Colors.transparent, width: 2.5),
                                ),
                                child: s.accent.id == a.id
                                    ? Icon(
                                        Icons.check_rounded,
                                        size: 20,
                                        color: Palette.onColor(a.accent(Theme.of(context).brightness)),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionLabel('عن التطبيق'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    SettingTile(
                      icon: Icons.hub_outlined,
                      title: 'إزاي Wasl بيشتغل؟',
                      subtitle: 'من غير إنترنت ومن غير سيرفر',
                      trailing: Icon(Icons.chevron_left_rounded, color: p.textMuted),
                      onTap: () => _showHow(context),
                    ),
                    Divider(indent: 68, color: p.border),
                    const SettingTile(
                      icon: Icons.info_outline_rounded,
                      title: '${AppConfig.appName} — ${AppConfig.appNameAr}',
                      subtitle: 'الإصدار ${AppConfig.appVersion}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void _showHow(BuildContext context) {
  final p = context.palette;
  Widget item(IconData icon, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(body, style: TextStyle(color: p.textMuted, height: 1.65, fontSize: 13.5)),
                ],
              ),
            ),
          ],
        ),
      );
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.82),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          children: [
            const Text('إزاي Wasl بيشتغل؟', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            item(Icons.cloud_off_rounded, 'من غير إنترنت ولا سيرفر',
                'الموبايلات بتكلم بعض مباشرة بالبلوتوث أو على نفس الواي فاي / الهوت سبوت. مفيش حساب ولا رقم موبايل.'),
            item(Icons.hub_rounded, 'شبكة Mesh',
                'كل موبايل عليه Wasl بيوصّل للي حواليه، فرسالتك تقدر تعدّي على كذا موبايل لحد ما توصل لحد بعيد عنك.'),
            item(Icons.lock_rounded, 'تشفير تلقائي',
                'الشات الخاص مشفّر من طرف لطرف بمفاتيح بتتولّد لوحدها — من غير كلمة سر. الموبايلات اللي في النص بتوصّل بس ومبتقراش حاجة.'),
            item(Icons.groups_rounded, 'الجروبات',
                'عام: أي حد قريب يدخل ويقرا. بكلمة سر أو بطلب انضمام: محدش يقرا غير الأعضاء. الجروب بيفضل ظاهر طول ما فيه عضو قريب.'),
            item(Icons.bookmark_outline_rounded, 'الحفظ اختياري',
                'الافتراضي إن المحادثات مبتتحفظش وبتتمسح مع قفل التطبيق. لو فعّلت الحفظ بتتخزن مشفّرة على موبايلك بس.'),
            item(Icons.verified_user_outlined, 'رمز الأمان',
                'لو عايز تتأكد 100% إنك بتكلم الشخص الصح، قارنوا رمز الأمان (6 أرقام) من قايمة المحادثة. اختياري.'),
          ],
        ),
      ),
    ),
  );
}

/// نافذة تحديد رقم سري جديد (مرتين) أو التأكد من الحالي.
class _PinSetup extends StatefulWidget {
  const _PinSetup({required this.verifyOnly});

  final bool verifyOnly;

  static Future<String?> show(BuildContext context, {bool verifyOnly = false}) => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _PinSetup(verifyOnly: verifyOnly),
      );

  @override
  State<_PinSetup> createState() => _PinSetupState();
}

class _PinSetupState extends State<_PinSetup> {
  String _pin = '';
  String? _first;
  String? _error;
  bool _busy = false;

  Future<void> _ok() async {
    if (_pin.length < 4 || _busy) return;
    if (widget.verifyOnly) {
      setState(() => _busy = true);
      final ok = await AppSettings.instance.checkPin(_pin);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, _pin);
      } else {
        setState(() {
          _busy = false;
          _pin = '';
          _error = 'الرقم غلط';
        });
      }
      return;
    }
    if (_first == null) {
      setState(() {
        _first = _pin;
        _pin = '';
        _error = null;
      });
    } else if (_first == _pin) {
      Navigator.pop(context, _pin);
    } else {
      setState(() {
        _first = null;
        _pin = '';
        _error = 'الرقمين مش زي بعض — ابدأ تاني';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final title = widget.verifyOnly
        ? 'اكتب الرقم السري الحالي'
        : _first == null
            ? 'اختار رقم سري (4 لـ 8 أرقام)'
            : 'اكتبه تاني للتأكيد';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SizedBox(
              height: 22,
              child: Text(_error ?? '', style: TextStyle(color: p.danger, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 20,
              child: _busy
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
            const SizedBox(height: 14),
            PinPad(
              onDigit: (d) {
                if (_pin.length < 8 && !_busy) {
                  setState(() {
                    _pin += d;
                    _error = null;
                  });
                }
              },
              onBack: () => setState(() {
                if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
              }),
              onOk: _pin.length >= 4 ? _ok : null,
            ),
          ],
        ),
      ),
    );
  }
}
