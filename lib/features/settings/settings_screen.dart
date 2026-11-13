import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../../core/config.dart';
import '../../core/platform/system_bridge.dart';
import '../../core/profile/profile.dart';
import '../../core/settings/app_settings.dart';
import '../../core/storage/chat_store.dart';
import '../../core/storage/vault.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
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
    final l = context.l10n;
    if (!v) {
      final ok = await confirmDialog(
        context,
        icon: Icons.bookmark_remove_rounded,
        title: l.stopSavingTitle,
        message: l.stopSavingBody,
        confirm: l.stopSavingConfirm,
        destructive: true,
      );
      if (!ok) return;
    }
    await _settings.setSaveChats(v);
    if (mounted) showToast(context, v ? l.savingOnToast : l.savingOffToast);
  }

  Future<void> _setPin() async {
    final pin = await _PinSetup.show(context);
    if (pin == null) return;
    await _settings.setPin(pin);
    if (mounted) showToast(context, context.l10n.lockOnToast);
  }

  Future<void> _removePin() async {
    final pin = await _PinSetup.show(context, verifyOnly: true);
    if (pin == null) return;
    await _settings.setPin(null);
    if (mounted) showToast(context, context.l10n.lockOffToast);
  }

  Future<void> _toggleBio(bool v) async {
    if (v) {
      final l = context.l10n;
      final ok = await Vault.biometricAuth(title: l.bioConfirmTitle, subtitle: l.bioConfirmSubtitle);
      if (!ok) return;
    }
    await _settings.setBiometric(v);
  }

  Future<void> _wipe() async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      icon: Icons.delete_forever_rounded,
      title: l.wipeTitle,
      message: l.wipeBody,
      confirm: l.wipeConfirm,
      destructive: true,
    );
    if (!ok) return;
    await _hub.wipeAll();
    if (mounted) showToast(context, l.wipeDone);
  }

  Future<void> _showBlocked() async {
    await showActionSheet<void>(
      context,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      builder: (ctx) => ListenableBuilder(
        listenable: _hub,
        builder: (ctx, _) {
          final ids = _hub.blockedIds;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ctx.l10n.blockedTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (ids.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(ctx.l10n.blockedEmpty, style: TextStyle(color: ctx.palette.textMuted)),
                ),
              for (final id in ids)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(name: _hub.nameOf(id) ?? '؟', color: id.hashCode, size: 40),
                  title: Text(_hub.nameOf(id) ?? ctx.l10n.personShort(id.substring(0, 6))),
                  trailing: TextButton(
                    onPressed: () => _hub.setBlocked(id, false),
                    child: Text(ctx.l10n.unblock),
                  ),
                ),
            ],
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _copyRepo({String? message}) async {
    await Clipboard.setData(const ClipboardData(text: AppConfig.repoUrl));
    if (mounted) showToast(context, message ?? context.l10n.linkCopied);
  }

  Future<void> _openRepo() async {
    final ok = await SystemBridge.openUrl(AppConfig.repoUrl);
    if (!ok && mounted) await _copyRepo(message: context.l10n.noBrowser);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_settings, ProfileStore.instance]),
      builder: (context, _) {
        final p = context.palette;
        final l = context.l10n;
        final me = ProfileStore.instance.current!;
        final s = _settings;
        return AppScaffold(
          title: l.settingsTitle,
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
                          Text(l.editProfileHint, style: TextStyle(color: p.textMuted, fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_outlined, color: p.textMuted),
                  ],
                ),
              ),
              SectionLabel(l.privacy),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    SettingTile(
                      icon: Icons.bookmark_outline_rounded,
                      title: l.saveChats,
                      subtitle: s.saveChats ? l.saveChatsOn : l.saveChatsOff,
                      trailing: Switch(value: s.saveChats, onChanged: _toggleSave),
                    ),
                    Divider(indent: 68, color: p.border),
                    SettingTile(
                      icon: Icons.lock_outline_rounded,
                      title: l.appLock,
                      subtitle: s.lockEnabled ? l.appLockOn : l.appLockOff,
                      trailing: Switch(value: s.lockEnabled, onChanged: (v) => v ? _setPin() : _removePin()),
                      onTap: s.lockEnabled ? _removePin : _setPin,
                    ),
                    if (s.lockEnabled) ...[
                      if (_bioAvailable) ...[
                        Divider(indent: 68, color: p.border),
                        SettingTile(
                          icon: Icons.fingerprint_rounded,
                          title: l.unlockWithFingerprint,
                          trailing: Switch(value: s.biometric, onChanged: _toggleBio),
                        ),
                      ],
                      Divider(indent: 68, color: p.border),
                      SettingTile(
                        icon: Icons.timer_outlined,
                        title: l.autoLock,
                        subtitle: l.autoLockSub,
                        trailing: DropdownButton<int>(
                          value: const [0, 1, 5, 15].contains(s.lockAfterMinutes) ? s.lockAfterMinutes : 1,
                          underline: const SizedBox.shrink(),
                          borderRadius: BorderRadius.circular(16),
                          items: [
                            DropdownMenuItem(value: 0, child: Text(l.lockNow)),
                            DropdownMenuItem(value: 1, child: Text(l.lockMinute)),
                            DropdownMenuItem(value: 5, child: Text(l.lock5)),
                            DropdownMenuItem(value: 15, child: Text(l.lock15)),
                          ],
                          onChanged: (v) => s.setLockAfter(v ?? 1),
                        ),
                      ),
                    ],
                    Divider(indent: 68, color: p.border),
                    SettingTile(
                      icon: Icons.block_rounded,
                      title: l.blockedTitle,
                      subtitle: _hub.blockedIds.isEmpty ? l.blockedNone : '${_hub.blockedIds.length}',
                      trailing: Icon(Icons.chevron_right_rounded, color: p.textMuted),
                      onTap: _showBlocked,
                    ),
                    Divider(indent: 68, color: p.border),
                    SettingTile(
                      icon: Icons.delete_forever_outlined,
                      title: l.wipeAll,
                      color: p.danger,
                      onTap: _wipe,
                    ),
                  ],
                ),
              ),
              SectionLabel(l.appearance),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text(l.themeAuto),
                          icon: const Icon(Icons.brightness_auto_rounded),
                        ),
                        ButtonSegment(value: ThemeMode.light, label: Text(l.themeLight), icon: const Icon(Icons.light_mode_rounded)),
                        ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark), icon: const Icon(Icons.dark_mode_rounded)),
                      ],
                      selected: {s.themeMode},
                      onSelectionChanged: (v) => s.setThemeMode(v.first),
                    ),
                    const SizedBox(height: 18),
                    Text(l.appColor, style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final a in AccentTheme.all)
                          Tooltip(
                            message: a.label(l),
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
              SectionLabel(l.language),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: '', label: Text(l.languageAuto), icon: const Icon(Icons.translate_rounded)),
                        // اسم كل لغة بيتكتب بلغتها هي
                        const ButtonSegment(value: 'ar', label: Text('العربية')),
                        const ButtonSegment(value: 'en', label: Text('English')),
                      ],
                      selected: {s.language ?? ''},
                      onSelectionChanged: (v) => s.setLanguage(v.first.isEmpty ? null : v.first),
                    ),
                    const SizedBox(height: 10),
                    Text(l.languageAutoHint, style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.5)),
                  ],
                ),
              ),
              SectionLabel(l.about),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    const _AboutHeader(),
                    Divider(indent: 68, color: p.border),
                    SettingTile(
                      icon: Icons.code_rounded,
                      title: l.sourceCode,
                      subtitle: AppConfig.repoUrl.replaceFirst('https://', ''),
                      trailing: Icon(Icons.open_in_new_rounded, color: p.textMuted, size: 20),
                      onTap: _openRepo,
                      onLongPress: () => _copyRepo(),
                    ),
                    Divider(indent: 68, color: p.border),
                    SettingTile(
                      icon: Icons.hub_outlined,
                      title: l.howItWorks,
                      subtitle: l.howItWorksSub,
                      trailing: Icon(Icons.chevron_right_rounded, color: p.textMuted),
                      onTap: () => _showHow(context),
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

/// اسم التطبيق ورقم الإصدار في أول كارت "عن التطبيق".
class _AboutHeader extends StatelessWidget {
  const _AboutHeader();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [p.accent, p.second],
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.forum_rounded, color: p.onAccent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الاسمين في نصين منفصلين عشان العربي والإنجليزي ميتلخبطوش في سطر واحد
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    const Text(AppConfig.appName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(AppConfig.appNameAr, style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.aboutTagline(AppConfig.license),
                  style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(20)),
            child: Text(
              'v${AppConfig.appVersion}',
              textDirection: TextDirection.ltr,
              style: TextStyle(color: p.accent, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

void _showHow(BuildContext context) {
  final p = context.palette;
  final l = context.l10n;
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
            Text(l.howItWorks, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            item(Icons.cloud_off_rounded, l.howNoInternetTitle, l.howNoInternetBody),
            item(Icons.hub_rounded, l.howMeshTitle, l.howMeshBody),
            item(Icons.lock_rounded, l.howEncryptionTitle, l.howEncryptionBody),
            item(Icons.swap_horiz_rounded, l.howBothTitle, l.howBothBody),
            item(Icons.groups_rounded, l.howGroupsTitle, l.howGroupsBody),
            item(Icons.admin_panel_settings_outlined, l.howAdminTitle, l.howAdminBody),
            item(Icons.notifications_none_rounded, l.howNotifTitle, l.howNotifBody),
            item(Icons.bookmark_outline_rounded, l.howSaveTitle, l.howSaveBody),
            item(Icons.verified_user_outlined, l.howSafetyTitle, l.howSafetyBody),
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
          _error = context.l10n.pinWrong;
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
        _error = context.l10n.pinMismatch;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final title = widget.verifyOnly
        ? l.pinEnterCurrent
        : _first == null
            ? l.pinChoose
            : l.pinRepeat;
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
