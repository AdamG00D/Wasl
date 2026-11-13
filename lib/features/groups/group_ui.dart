import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../mesh/mesh_router.dart';
import '../../widgets/feedback.dart';
import '../../widgets/focus_guard.dart';
import '../../widgets/ui.dart';
import '../chat/chat_page.dart';
import '../chat/widgets/chat_widgets.dart';
import '../hub/chat_hub.dart';

String groupModeLabel(GroupMode m) => switch (m) {
      GroupMode.open => tr.modeOpen,
      GroupMode.password => tr.modePassword,
      GroupMode.ask => tr.modeAsk,
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
      showToast(context, context.l10n.groupNameNeeded, error: true);
      return;
    }
    if (_mode == GroupMode.password && _password.text.length < 4) {
      showToast(context, context.l10n.passwordTooShort, error: true);
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
        showToast(context, context.l10n.createGroupFailed, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final explain = {
      GroupMode.open: l.modeOpenExplain,
      GroupMode.password: l.modePasswordExplain,
      GroupMode.ask: l.modeAskExplain,
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
              Text(l.newGroup, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                maxLength: 24,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: l.groupName,
                  prefixIcon: const Icon(Icons.groups_rounded),
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
                            hintText: l.groupPassword,
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
              PrimaryButton(label: l.createGroupButton, icon: Icons.add_rounded, loading: _busy, onPressed: _create),
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
        showToast(context, err ?? context.l10n.joinGroupFailed, error: true);
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
          title: context.l10n.requestPendingTitle,
          message: context.l10n.requestPendingBody,
          confirm: context.l10n.cancelRequest,
          cancel: context.l10n.keepWaiting,
          destructive: true,
        );
        if (cancel) hub.cancelJoinRequest(ad.id);
        return;
      }
      final ok = await confirmDialog(
        context,
        icon: Icons.how_to_reg_rounded,
        title: context.l10n.requestJoinTitle(ad.name),
        message: context.l10n.requestJoinBody,
        confirm: context.l10n.sendRequest,
      );
      if (!ok) return;
      final err = await hub.requestJoin(ad);
      if (!context.mounted) return;
      showToast(context, err ?? context.l10n.requestSent, error: err != null);
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
              Text(context.l10n.privateGroupPassword, style: TextStyle(color: p.textMuted)),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                autofocus: true,
                obscureText: true,
                maxLength: 64,
                decoration: InputDecoration(
                  hintText: context.l10n.password,
                  prefixIcon: const Icon(Icons.key_rounded),
                  counterText: '',
                  errorText: _error,
                ),
                onSubmitted: (_) => _join(),
              ),
              const SizedBox(height: 14),
              PrimaryButton(label: context.l10n.enter, icon: Icons.login_rounded, loading: _busy, onPressed: _join),
            ],
          ),
        ),
      ),
    );
  }
}

/// نافذة كتابة نص قصير (اسم جروب...). بترجّع النص أو null.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String initial,
  String? confirm,
  int maxLength = 24,
}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: maxLength,
        decoration: const InputDecoration(counterText: ''),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: Text(confirm ?? ctx.l10n.save),
        ),
      ],
    ),
  ).whenComplete(ctrl.dispose);
}

/// دور العضو في الجروب (للعرض).
String? groupRoleLabel(GroupChat g, String id) =>
    id == g.info.owner ? tr.roleOwner : (g.info.admins.contains(id) ? tr.roleAdmin : null);

/// نافذة عضو في الجروب (زي الواتساب): رسالة خاصة • منشن • مدير • إزالة • حظر.
///
/// [onMention] بيظهر لما النافذة تتفتح من جوه الشات.
Future<void> showMemberSheet(BuildContext context, GroupChat g, String id, {String? fallbackName, VoidCallback? onMention}) async {
  final hub = ChatHub.instance;
  if (id == hub.myId) return;
  final node = hub.nodeFor(id);
  final name = node?.name ?? hub.nameOf(id) ?? fallbackName ?? context.l10n.member;
  final info = g.info;
  final p = context.palette;
  final role = groupRoleLabel(g, id);
  final blocked = hub.isBlocked(id);
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(
              name: name,
              color: node?.color ?? senderColorOf(id),
              avatarHash: node?.avatar,
              cartoon: node?.cartoon,
              size: 84,
              online: node != null,
            ),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text(
              [?role, node == null ? context.l10n.notConnectedNow : context.l10n.onlineNow].join(' • '),
              style: TextStyle(color: role != null ? p.accent : p.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (node != null && !blocked)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded),
                title: Text(ctx.l10n.privateMessage),
                subtitle: Text(ctx.l10n.privateMessageSub),
                onTap: () => Navigator.pop(ctx, 'chat'),
              ),
            if (node != null && !blocked && (hub.link?.supportsCalls ?? false))
              ListTile(
                leading: const Icon(Icons.call_outlined),
                title: Text(ctx.l10n.voiceCall),
                onTap: () => Navigator.pop(ctx, 'call'),
              ),
            if (onMention != null)
              ListTile(
                leading: const Icon(Icons.alternate_email_rounded),
                title: Text(ctx.l10n.mention),
                onTap: () => Navigator.pop(ctx, 'mention'),
              ),
            if (g.iAmOwner && !info.banned.contains(id))
              ListTile(
                leading: Icon(info.admins.contains(id) ? Icons.remove_moderator_outlined : Icons.add_moderator_outlined),
                title: Text(info.admins.contains(id) ? ctx.l10n.removeAdmin : ctx.l10n.makeAdmin),
                onTap: () => Navigator.pop(ctx, 'admin'),
              ),
            if (info.canKick(hub.myId, id) && !info.banned.contains(id))
              ListTile(
                leading: Icon(Icons.person_remove_outlined, color: p.danger),
                title: Text(ctx.l10n.removeFromGroup, style: TextStyle(color: p.danger)),
                onTap: () => Navigator.pop(ctx, 'kick'),
              ),
            if (g.iAmAdmin && info.banned.contains(id))
              ListTile(
                leading: const Icon(Icons.person_add_alt_outlined),
                title: Text(ctx.l10n.unban),
                onTap: () => Navigator.pop(ctx, 'unban'),
              ),
            ListTile(
              leading: Icon(Icons.block_rounded, color: p.danger),
              title: Text(blocked ? ctx.l10n.unblock : ctx.l10n.block, style: TextStyle(color: p.danger)),
              subtitle: blocked ? null : Text(ctx.l10n.blockSub),
              onTap: () => Navigator.pop(ctx, 'block'),
            ),
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case 'chat':
      final chat = hub.openDirect(id);
      if (chat != null) await ChatPage.open(context, chat);
    case 'call':
      final chat = hub.openDirect(id);
      if (chat != null) await ChatPage.open(context, chat, startCall: 'voice');
    case 'mention':
      onMention?.call();
    case 'admin':
      final err = await hub.setAdmin(g, id, !info.admins.contains(id));
      if (err != null && context.mounted) showToast(context, err, error: true);
    case 'kick':
      final ok = await confirmDialog(
        context,
        icon: Icons.person_remove_outlined,
        title: context.l10n.kickTitle(name),
        message: switch (info.mode) {
          GroupMode.ask => context.l10n.kickAsk,
          GroupMode.password => context.l10n.kickPassword,
          GroupMode.open => context.l10n.kickOpen,
        },
        confirm: context.l10n.kickConfirm,
        destructive: true,
      );
      if (!ok) return;
      final err = await hub.kickMember(g, id);
      if (context.mounted) showToast(context, err ?? context.l10n.kicked(name), error: err != null);
    case 'unban':
      await hub.unbanMember(g, id);
      if (context.mounted) showToast(context, context.l10n.unbanned(name));
    case 'block':
      if (!blocked) {
        final ok = await confirmDialog(
          context,
          icon: Icons.block_rounded,
          title: context.l10n.blockTitle(name),
          message: context.l10n.blockBody,
          confirm: context.l10n.block,
          destructive: true,
        );
        if (!ok) return;
      }
      await hub.setBlocked(id, !blocked);
  }
}

/// معلومات الجروب: النوع، طلبات الانضمام (لصاحبه)، الأعضاء المتصلين وأدوارهم، واللي اتشالوا.
class GroupInfoScreen extends StatelessWidget {
  const GroupInfoScreen({super.key, required this.group});

  final GroupChat group;

  static Future<void> open(BuildContext context, GroupChat g) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GroupInfoScreen(group: g)));

  Future<void> _rename(BuildContext context) async {
    final name = await promptText(context, title: context.l10n.groupName, initial: group.title);
    if (name == null || !context.mounted) return;
    final err = await ChatHub.instance.renameGroup(group, name);
    if (err != null && context.mounted) showToast(context, err, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final hub = ChatHub.instance;
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        final p = context.palette;
        final g = group;
        final info = g.info;
        // اتشلت من الجروب أو خرجت منه والشاشة لسه مفتوحة
        if (hub.groupFor(g.id) != g) {
          return AppScaffold(
            title: context.l10n.groupInfo,
            body: EmptyState(icon: Icons.link_off_rounded, title: context.l10n.notInGroup),
          );
        }
        int rank(String id) => id == info.owner ? 0 : (info.admins.contains(id) ? 1 : 2);
        final members = g.members.where((m) => !info.banned.contains(m.id)).toList()
          ..sort((a, b) {
            final r = rank(a.id).compareTo(rank(b.id));
            return r != 0 ? r : a.name.compareTo(b.name);
          });
        final owner = hub.nodeFor(info.owner);
        return AppScaffold(
          title: context.l10n.groupInfo,
          actions: [
            if (g.iAmAdmin)
              IconButton(tooltip: context.l10n.rename, onPressed: () => _rename(context), icon: const Icon(Icons.edit_rounded)),
          ],
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
                  Icon(groupModeIcon(info.mode), size: 15, color: p.textMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      [
                        context.l10n.groupOfMode(groupModeLabel(info.mode)),
                        if (g.iAmOwner) context.l10n.youOwnIt else if (owner != null) context.l10n.ownedBy(owner.name),
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.textMuted),
                    ),
                  ),
                ],
              ),
              if (g.requests.isNotEmpty) ...[
                SectionLabel(context.l10n.joinRequests(g.requests.length)),
                for (final r in g.requests.toList()) ...[
                  AppCard(
                    padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 12, 10),
                    borderColor: p.accent.withValues(alpha: 0.4),
                    child: Row(
                      children: [
                        Avatar(name: r.name, color: r.color, avatarHash: r.avatar, cartoon: r.cartoon, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                              if (info.banned.contains(r.nodeId))
                                Text(context.l10n.removedBefore, style: TextStyle(color: p.warning, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.decline,
                          onPressed: () => hub.answerRequest(r, false),
                          icon: Icon(Icons.close_rounded, color: p.danger),
                        ),
                        const SizedBox(width: 2),
                        IconButton.filled(
                          tooltip: context.l10n.accept,
                          onPressed: () => hub.answerRequest(r, true),
                          icon: const Icon(Icons.check_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              SectionLabel(context.l10n.onlineCount(members.length + 1)),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _MemberRow(
                      name: context.l10n.youName,
                      color: hub.myColor,
                      avatar: hub.myAvatar,
                      cartoon: hub.myCartoon,
                      subtitle: groupRoleLabel(g, hub.myId),
                    ),
                    for (final m in members) ...[
                      Divider(indent: 70, color: p.border),
                      _MemberRow(
                        name: m.name,
                        color: m.color,
                        avatar: m.avatar,
                        cartoon: m.cartoon,
                        subtitle: groupRoleLabel(g, m.id),
                        trailing: Icon(Icons.more_horiz_rounded, color: p.textMuted, size: 22),
                        onTap: () => showMemberSheet(context, g, m.id),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                child: Text(
                  g.iAmOwner
                      ? context.l10n.ownerHint
                      : g.iAmAdmin
                          ? context.l10n.adminHint
                          : context.l10n.memberHint,
                  style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.6),
                ),
              ),
              if (g.iAmAdmin && info.banned.isNotEmpty) ...[
                SectionLabel(context.l10n.bannedCount(info.banned.length)),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (i, id) in info.banned.indexed) ...[
                        if (i > 0) Divider(indent: 70, color: p.border),
                        _MemberRow(
                          name: hub.nameOf(id) ?? context.l10n.member,
                          color: hub.nodeFor(id)?.color ?? senderColorOf(id),
                          avatar: hub.nodeFor(id)?.avatar,
                          cartoon: hub.nodeFor(id)?.cartoon,
                          trailing: TextButton(onPressed: () => hub.unbanMember(g, id), child: Text(context.l10n.letBack)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SecondaryButton(
                label: context.l10n.leaveGroup,
                icon: Icons.logout_rounded,
                color: p.danger,
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: context.l10n.leaveGroupTitle(g.title),
                    message: context.l10n.groupMessagesErased,
                    confirm: context.l10n.leave,
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
  const _MemberRow({
    required this.name,
    required this.color,
    this.avatar,
    this.cartoon,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String name;
  final int color;
  final String? avatar;
  final int? cartoon;
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
            Avatar(name: name, color: color, avatarHash: avatar, cartoon: cartoon, size: 42),
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
