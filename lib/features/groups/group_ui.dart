import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../mesh/mesh_router.dart';
import '../../widgets/feedback.dart';
import '../../widgets/focus_guard.dart';
import '../../widgets/ui.dart';
import '../chat/chat_page.dart';
import '../hub/chat_hub.dart';

String groupModeLabel(GroupMode m) => switch (m) {
      GroupMode.open => 'عام',
      GroupMode.password => 'بكلمة سر',
      GroupMode.ask => 'بطلب انضمام',
    };

IconData groupModeIcon(GroupMode m) => switch (m) {
      GroupMode.open => Icons.public_rounded,
      GroupMode.password => Icons.key_rounded,
      GroupMode.ask => Icons.how_to_reg_rounded,
    };

/// نافذة إنشاء جروب جديد. بترجّع الجروب لو اتعمل.
Future<GroupChat?> showCreateGroupSheet(BuildContext context) => showModalBottomSheet<GroupChat>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateGroupSheet(),
    );

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet();

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  GroupMode _mode = GroupMode.open;
  bool _busy = false;
  bool _show = false;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      showToast(context, 'اكتب اسم للجروب', error: true);
      return;
    }
    if (_mode == GroupMode.password && _password.text.length < 4) {
      showToast(context, 'كلمة السر 4 حروف على الأقل', error: true);
      return;
    }
    hideKeyboard();
    setState(() => _busy = true);
    try {
      final g = await ChatHub.instance.createGroup(
        name: name,
        mode: _mode,
        password: _mode == GroupMode.password ? _password.text : null,
      );
      if (mounted) Navigator.pop(context, g);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showToast(context, 'معرفناش نعمل الجروب', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const explain = {
      GroupMode.open: 'أي حد قريب يشوف الجروب ويدخل على طول.',
      GroupMode.password: 'الجروب ظاهر، بس محدش يدخل ولا يقرا غير اللي معاه كلمة السر.',
      GroupMode.ask: 'اللي عايز يدخل يبعتلك طلب، وإنت توافق أو ترفض.',
    };
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('جروب جديد', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                maxLength: 24,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'اسم الجروب',
                  prefixIcon: Icon(Icons.groups_rounded),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              for (final m in GroupMode.values) ...[
                AppCard(
                  radius: 18,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  color: _mode == m ? p.accentSoft : p.surfaceAlt,
                  borderColor: _mode == m ? p.accent : Colors.transparent,
                  onTap: () => setState(() => _mode = m),
                  child: Row(
                    children: [
                      Icon(groupModeIcon(m), color: _mode == m ? p.accent : p.textMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(groupModeLabel(m), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(explain[m]!, style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.5)),
                          ],
                        ),
                      ),
                      if (_mode == m) Icon(Icons.check_circle_rounded, color: p.accent, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: _mode != GroupMode.password
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextField(
                          controller: _password,
                          obscureText: !_show,
                          maxLength: 64,
                          decoration: InputDecoration(
                            hintText: 'كلمة سر الجروب',
                            prefixIcon: const Icon(Icons.key_rounded),
                            counterText: '',
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _show = !_show),
                              icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(label: 'إنشاء الجروب', icon: Icons.add_rounded, loading: _busy, onPressed: _create),
            ],
          ),
        ),
      ),
    );
  }
}

/// الدخول لجروب ظاهر: عام = على طول، بكلمة سر = يسأل عنها، بطلب = يبعت طلب.
Future<void> joinGroupFlow(BuildContext context, GroupAd ad) async {
  final hub = ChatHub.instance;
  switch (ad.mode) {
    case GroupMode.open:
      final (g, err) = await hub.joinGroup(ad);
      if (!context.mounted) return;
      if (g != null) {
        await ChatPage.open(context, g);
      } else {
        showToast(context, err ?? 'معرفناش ندخل الجروب', error: true);
      }
    case GroupMode.password:
      final g = await showModalBottomSheet<GroupChat>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _PasswordSheet(ad: ad),
      );
      if (g != null && context.mounted) await ChatPage.open(context, g);
    case GroupMode.ask:
      if (hub.pendingJoins.contains(ad.id)) {
        final cancel = await confirmDialog(
          context,
          icon: Icons.hourglass_top_rounded,
          title: 'الطلب لسه مستني',
          message: 'صاحب الجروب لسه مردّش على طلبك.',
          confirm: 'إلغاء الطلب',
          cancel: 'هستنى',
          destructive: true,
        );
        if (cancel) hub.cancelJoinRequest(ad.id);
        return;
      }
      final ok = await confirmDialog(
        context,
        icon: Icons.how_to_reg_rounded,
        title: 'طلب انضمام لـ "${ad.name}"',
        message: 'هنبعت طلب لصاحب الجروب، وأول ما يوافق هتدخل تلقائياً.',
        confirm: 'ابعت الطلب',
      );
      if (!ok) return;
      final err = await hub.requestJoin(ad);
      if (!context.mounted) return;
      showToast(context, err ?? 'الطلب اتبعت — مستنيين الموافقة', error: err != null);
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({required this.ad});

  final GroupAd ad;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_ctrl.text.isEmpty || _busy) return;
    hideKeyboard();
    setState(() {
      _busy = true;
      _error = null;
    });
    final (g, err) = await ChatHub.instance.joinGroup(widget.ad, password: _ctrl.text);
    if (!mounted) return;
    if (g != null) {
      Navigator.pop(context, g);
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('"${widget.ad.name}"', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('الجروب ده خاص — اكتب كلمة السر عشان تدخل.', style: TextStyle(color: p.textMuted)),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                autofocus: true,
                obscureText: true,
                maxLength: 64,
                decoration: InputDecoration(
                  hintText: 'كلمة السر',
                  prefixIcon: const Icon(Icons.key_rounded),
                  counterText: '',
                  errorText: _error,
                ),
                onSubmitted: (_) => _join(),
              ),
              const SizedBox(height: 14),
              PrimaryButton(label: 'دخول', icon: Icons.login_rounded, loading: _busy, onPressed: _join),
            ],
          ),
        ),
      ),
    );
  }
}

/// معلومات الجروب: النوع، طلبات الانضمام (لصاحبه)، والأعضاء المتصلين.
class GroupInfoScreen extends StatelessWidget {
  const GroupInfoScreen({super.key, required this.group});

  final GroupChat group;

  static Future<void> open(BuildContext context, GroupChat g) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GroupInfoScreen(group: g)));

  @override
  Widget build(BuildContext context) {
    final hub = ChatHub.instance;
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        final p = context.palette;
        final g = group;
        final members = g.members..sort((a, b) => a.name.compareTo(b.name));
        final owner = hub.nodeFor(g.info.owner);
        return AppScaffold(
          title: 'معلومات الجروب',
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              Center(
                child: Avatar(name: g.title, color: g.color, size: 96, icon: Icons.groups_rounded),
              ),
              const SizedBox(height: 14),
              Text(
                g.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(groupModeIcon(g.info.mode), size: 15, color: p.textMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'جروب ${groupModeLabel(g.info.mode)}${g.iAmOwner ? ' • إنت صاحبه' : owner == null ? '' : ' • صاحبه ${owner.name}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.textMuted),
                    ),
                  ),
                ],
              ),
              if (g.requests.isNotEmpty) ...[
                SectionLabel('طلبات انضمام (${g.requests.length})'),
                for (final r in g.requests.toList()) ...[
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    borderColor: p.accent.withValues(alpha: 0.4),
                    child: Row(
                      children: [
                        Avatar(name: r.name, color: r.color, avatarHash: r.avatar, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                        ),
                        IconButton(
                          tooltip: 'رفض',
                          onPressed: () => hub.answerRequest(r, false),
                          icon: Icon(Icons.close_rounded, color: p.danger),
                        ),
                        const SizedBox(width: 2),
                        IconButton.filled(
                          tooltip: 'قبول',
                          onPressed: () => hub.answerRequest(r, true),
                          icon: const Icon(Icons.check_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              SectionLabel('متصلين دلوقتي (${members.length + 1})'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _MemberRow(name: 'إنت', color: hub.myColor, avatar: hub.myAvatar, subtitle: g.iAmOwner ? 'صاحب الجروب' : null),
                    for (final m in members) ...[
                      Divider(indent: 70, color: p.border),
                      _MemberRow(
                        name: m.name,
                        color: m.color,
                        avatar: m.avatar,
                        subtitle: m.id == g.info.owner ? 'صاحب الجروب' : null,
                        trailing: Icon(Icons.chat_bubble_outline_rounded, color: p.accent, size: 20),
                        onTap: () {
                          final chat = hub.openDirect(m.id);
                          if (chat != null) ChatPage.open(context, chat);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                child: Text(
                  'اضغط على أي عضو عشان تكلمه شات خاص — مشفّر بينكم انتوا الاتنين بس، حتى باقي الجروب مش بيشوفه.',
                  style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.6),
                ),
              ),
              const SizedBox(height: 22),
              SecondaryButton(
                label: 'الخروج من الجروب',
                icon: Icons.logout_rounded,
                color: p.danger,
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'الخروج من "${g.title}"؟',
                    message: 'رسايل الجروب هتتمسح من موبايلك.',
                    confirm: 'خروج',
                    destructive: true,
                  );
                  if (!ok) return;
                  await hub.leaveGroup(g);
                  if (context.mounted) Navigator.of(context).popUntil((r) => r.settings.name == 'home' || r.isFirst);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.name, required this.color, this.avatar, this.subtitle, this.trailing, this.onTap});

  final String name;
  final int color;
  final String? avatar;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Avatar(name: name, color: color, avatarHash: avatar, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  if (subtitle != null) Text(subtitle!, style: TextStyle(color: p.accent, fontSize: 12)),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
