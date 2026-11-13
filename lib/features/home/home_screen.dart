import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/platform/system_bridge.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../mesh/dual_link.dart';
import '../../mesh/lan_link.dart';
import '../../mesh/mesh_link.dart';
import '../../mesh/mesh_router.dart';
import '../../widgets/feedback.dart';
import '../../widgets/focus_guard.dart';
import '../../widgets/ui.dart';
import '../chat/chat_page.dart';
import '../chat/core/chat_errors.dart';
import '../chat/core/chat_session.dart';
import '../chat/core/nearby_requirements.dart';
import '../chat/widgets/chat_widgets.dart';
import '../groups/group_ui.dart';
import '../hub/chat_hub.dart';
import '../settings/settings_screen.dart';

/// الصفحة الرئيسية بعد اختيار بلوتوث/واي فاي: المحادثات • الجروبات • القريبين.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.kind});

  final TransportKind kind;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _hub = ChatHub.instance;
  final _pages = PageController();
  int _tab = 0;
  List<Requirement>? _requirements;
  bool _checking = false;
  bool _starting = false;
  bool _leaving = false;
  StreamSubscription<(GroupAd, bool)>? _joinSub;
  StreamSubscription<String>? _noticeSub;

  /// البلوتوث شغال (لوحده أو مع الواي فاي): محتاجين أذوناته الأول.
  bool get _isBluetooth => widget.kind != TransportKind.wifi;
  bool get _ready => !_isBluetooth || (_requirements != null && _requirements!.every((r) => r.ok));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _joinSub = _hub.joinResults.listen((e) {
      if (!mounted) return;
      final (ad, ok) = e;
      showToast(context, ok ? context.l10n.joinAccepted(ad.name) : context.l10n.joinRejected(ad.name), error: !ok);
    });
    _noticeSub = _hub.notices.listen((text) {
      if (mounted) showToast(context, text, error: true);
    });
    _hub.onOpenConversation = _openConversation;
    if (_isBluetooth) {
      _check(autoRequest: true);
    } else {
      _start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _joinSub?.cancel();
    _noticeSub?.cancel();
    if (_hub.onOpenConversation == _openConversation) _hub.onOpenConversation = null;
    _pages.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // المستخدم ممكن يكون رجع من إعدادات الأذونات/البلوتوث
    if (state == AppLifecycleState.resumed && _isBluetooth && !_ready) _check();
  }

  Future<void> _start() async {
    if (_starting || _hub.running) return;
    _starting = true;
    try {
      await _hub.start(widget.kind);
    } finally {
      _starting = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _check({bool autoRequest = false}) async {
    if (_checking) return;
    _checking = true;
    try {
      var reqs = await NearbyRequirements.check();
      if (autoRequest &&
          reqs.any((r) => r.state == RequirementState.missing && r.id != 'bluetooth' && r.id != 'locationService')) {
        await NearbyRequirements.requestAllPermissions();
        reqs = await NearbyRequirements.check();
      }
      if (!mounted) return;
      setState(() => _requirements = reqs);
      if (_ready) await _start();
    } finally {
      _checking = false;
    }
  }

  Future<void> _fix(Requirement r) async {
    await NearbyRequirements.fix(r);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _check();
  }

  /// الرجوع لصفحة الاختيار = قفل الشبكة.
  Future<void> _leave() async {
    if (_leaving) return;
    if (_hub.running && _hub.conversations.isNotEmpty) {
      final unsaved = _hub.conversations.any((c) => !c.saved && c.lastMessage != null);
      final ok = await confirmDialog(
        context,
        icon: Icons.power_settings_new_rounded,
        title: context.l10n.leaveTitle,
        message: unsaved ? context.l10n.leaveBodyUnsaved : context.l10n.leaveBody,
        confirm: context.l10n.disconnect,
        destructive: unsaved,
      );
      if (!ok) return;
    }
    _leaving = true;
    await _hub.stop();
    if (mounted) Navigator.of(context).pop();
  }

  void _goTo(int tab) {
    if (!_pages.hasClients) return;
    _pages.animateToPage(tab, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _openPeople() => _goTo(2);

  /// فتح محادثة من إشعار: نرجع للرئيسية ونفتحها فوقها.
  void _openConversation(Conversation c) {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.settings.name == 'home' || r.isFirst);
    ChatPage.open(context, c);
  }

  Future<void> _createGroup() async {
    final g = await showCreateGroupSheet(context);
    if (g != null && mounted) await ChatPage.open(context, g);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: ListenableBuilder(
        listenable: _hub,
        builder: (context, _) {
          final running = _hub.running;
          final link = _hub.link;
          final Widget body;
          if (!_ready) {
            body = _RequirementsView(requirements: _requirements, onFix: _fix);
          } else if (!running || link == null) {
            body = const Center(child: CircularProgressIndicator());
          } else {
            body = Column(
              children: [
                _LinkProblems(link: link),
                Expanded(
                  // اسحب يمين وشمال عشان تتنقل بين الصفحات
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (i) => setState(() => _tab = i),
                    children: [
                      _KeepAlive(child: _ChatsTab(onNew: _openPeople)),
                      _KeepAlive(child: _GroupsTab(onCreate: _createGroup)),
                      _KeepAlive(child: _PeopleTab(isWifi: widget.kind != TransportKind.bluetooth)),
                    ],
                  ),
                ),
              ],
            );
          }
          final showNav = _ready && running;
          return Scaffold(
            backgroundColor: p.bg,
            body: Column(
              children: [
                _TopBar(kind: widget.kind, onBack: _leave),
                Expanded(child: body),
              ],
            ),
            floatingActionButton: !showNav || _tab == 2
                ? null
                : FloatingActionButton.extended(
                    onPressed: _tab == 0 ? _openPeople : _createGroup,
                    backgroundColor: p.accent,
                    foregroundColor: p.onAccent,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    icon: Icon(_tab == 0 ? Icons.edit_rounded : Icons.group_add_rounded),
                    label: Text(
                      _tab == 0 ? context.l10n.newChat : context.l10n.newGroup,
                      style: const TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700),
                    ),
                  ),
            bottomNavigationBar: !showNav
                ? null
                : NavigationBar(
                    selectedIndex: _tab,
                    onDestinationSelected: _goTo,
                    backgroundColor: p.surface,
                    indicatorColor: p.accentSoft,
                    surfaceTintColor: Colors.transparent,
                    height: 68,
                    destinations: [
                      NavigationDestination(
                        icon: _NavIcon(Icons.chat_bubble_outline_rounded, _hub.totalUnread),
                        selectedIcon: _NavIcon(Icons.chat_bubble_rounded, _hub.totalUnread, selected: true),
                        label: context.l10n.tabChats,
                      ),
                      NavigationDestination(
                        icon: _NavIcon(Icons.groups_outlined, _hub.groupRequests),
                        selectedIcon: _NavIcon(Icons.groups_rounded, _hub.groupRequests, selected: true),
                        label: context.l10n.tabGroups,
                      ),
                      NavigationDestination(
                        icon: const _NavIcon(Icons.radar_rounded, 0),
                        selectedIcon: const _NavIcon(Icons.radar_rounded, 0, selected: true),
                        label: context.l10n.tabNearby,
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// بيحافظ على الصفحة (ومكان السكرول) وإنت بتسحب لصفحة تانية.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon(this.icon, this.count, {this.selected = false});

  final IconData icon;
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final i = Icon(icon, color: selected ? p.accent : p.textMuted);
    if (count <= 0) return i;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: p.accent,
      textColor: p.onAccent,
      child: i,
    );
  }
}

/// الشريط اللي فوق: رجوع • الاسم وحالة الشبكة • الإعدادات.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.kind, required this.onBack});

  final TransportKind kind;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hub = ChatHub.instance;
    final n = hub.people.length;
    final running = hub.running && hub.link?.phase == LinkPhase.running;
    final wifi = kind != TransportKind.bluetooth;
    return Padding(
      padding: EdgeInsetsDirectional.only(top: MediaQuery.paddingOf(context).top + 6, start: 4, end: 10, bottom: 6),
      child: Row(
        children: [
          IconButton(tooltip: context.l10n.back, onPressed: onBack, icon: const BackButtonIcon()),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.appTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25)),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: !running
                            ? p.warning
                            : n > 0
                                ? p.success
                                : p.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(wifi ? Icons.wifi_rounded : Icons.bluetooth_rounded, size: 14, color: p.textMuted),
                    if (kind == TransportKind.both) Icon(Icons.bluetooth_rounded, size: 14, color: p.textMuted),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        !running
                            ? context.l10n.preparing
                            : n == 0
                                ? context.l10n.searchingPeople
                                : context.l10n.peopleNearby(n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: context.l10n.settingsTitle,
            style: IconButton.styleFrom(backgroundColor: p.surface, foregroundColor: p.text),
            onPressed: () => SettingsScreen.open(context),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
    );
  }
}

/// مشاكل الشبكة (واي فاي مقفول، خدمات Google ناقصة...) مع زر الحل.
class _LinkProblems extends StatelessWidget {
  const _LinkProblems({required this.link});

  final MeshLink link;

  @override
  Widget build(BuildContext context) {
    final l = link;
    // الاتنين مع بعض: كل وسيلة بمشاكلها (واحدة تقع والتانية تكمّل)
    if (l is DualLink) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [_LinkProblems(link: l.wifi), _LinkProblems(link: l.bluetooth)],
      );
    }
    final failed = l.phase == LinkPhase.failed;
    final noNetwork = l is LanLink && l.phase == LinkPhase.running && !l.hasNetwork;
    if (l.error == null && !noNetwork) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: l.error != null
          ? ChatErrorCard(
              error: l.error!,
              onDismiss: failed ? null : l.clearError,
              actions: [
                FilledButton.icon(
                  onPressed: l.retry,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(context.l10n.tryAgain),
                ),
              ],
            )
          : ChatErrorCard(
              error: ChatError.noNetwork,
              actions: [
                FilledButton.icon(
                  onPressed: SystemBridge.openWifiSettings,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                  icon: const Icon(Icons.wifi_rounded, size: 18),
                  label: Text(context.l10n.openWifi),
                ),
              ],
            ),
    );
  }
}

String _timeLabel(DateTime t) {
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  if (t.year == now.year && t.month == now.month && t.day == now.day) return '${two(t.hour)}:${two(t.minute)}';
  if (now.difference(t).inDays < 1) return tr.yesterday;
  return '${t.day}/${t.month}';
}

/// صف محادثة في القايمة.
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({super.key, required this.conversation});

  final Conversation conversation;

  Future<void> _actions(BuildContext context) async {
    final hub = ChatHub.instance;
    final c = conversation;
    final p = context.palette;
    final action = await showActionSheet<String>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(c.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded),
            title: Text(c.pinned ? context.l10n.unpin : context.l10n.pin),
            onTap: () => Navigator.pop(ctx, 'pin'),
          ),
          ListTile(
            leading: Icon(c.muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
            title: Text(c.muted ? context.l10n.unmuteNotifications : context.l10n.muteNotifications),
            onTap: () => Navigator.pop(ctx, 'mute'),
          ),
          ListTile(
            leading: Icon(c.saved ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined),
            title: Text(c.saved ? context.l10n.unsaveChat : context.l10n.saveChat),
            onTap: () => Navigator.pop(ctx, 'save'),
          ),
          ListTile(
            leading: Icon(c.isGroup ? Icons.logout_rounded : Icons.delete_outline_rounded, color: p.danger),
            title: Text(c.isGroup ? context.l10n.leaveGroup : context.l10n.deleteChat, style: TextStyle(color: p.danger)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'pin') {
      await hub.setPinned(c, !c.pinned);
      return;
    }
    if (action == 'mute') {
      await toggleMute(context, c);
      return;
    }
    if (action == 'save') {
      await hub.setSaved(c, !c.saved);
      if (context.mounted) showToast(context, c.saved ? context.l10n.chatSavedToast : context.l10n.chatUnsavedToast);
      return;
    }
    final ok = await confirmDialog(
      context,
      title: c.isGroup ? context.l10n.leaveGroupTitle(c.title) : context.l10n.deleteChatTitle(c.title),
      message: context.l10n.messagesErasedBody,
      confirm: c.isGroup ? context.l10n.leave : context.l10n.deleteAction,
      destructive: true,
    );
    if (!ok) return;
    if (c is GroupChat) {
      await hub.leaveGroup(c);
    } else if (c is DirectChat) {
      await hub.deleteDirect(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = conversation;
    final last = c.lastMessage;
    final direct = c is DirectChat ? c : null;
    final group = c is GroupChat ? c : null;
    final typing = c.session.peerTyping;
    final mention = c.unread > 0 && group != null && (last?.mentionsMe ?? false);

    String preview;
    if (typing) {
      final names = c.session.typingNames;
      preview = names.isEmpty ? context.l10n.typing : context.l10n.nameTyping(names.first);
    } else if (last == null) {
      preview = group != null ? context.l10n.groupOfMode(groupModeLabel(group.info.mode)) : context.l10n.tapToStart;
    } else {
      final text = ChatSession.previewOf(last);
      preview = last.kind == MessageKind.mine
          ? context.l10n.youPrefix(text)
          : (group != null && last.sender != null ? '${last.sender}: $text' : text);
    }
    final requests = group?.requests.length ?? 0;

    return InkWell(
      onTap: () => ChatPage.open(context, c),
      onLongPress: () => _actions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            Avatar(
              name: c.title,
              color: c.color,
              avatarHash: c.avatar,
              cartoon: c.cartoon,
              size: 54,
              online: direct?.online,
              icon: group != null ? Icons.groups_rounded : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      if (group != null && group.info.mode != GroupMode.open) ...[
                        const SizedBox(width: 5),
                        Icon(Icons.lock_rounded, size: 13, color: p.textMuted),
                      ],
                      if (c.saved) ...[
                        const SizedBox(width: 5),
                        Icon(Icons.bookmark_rounded, size: 14, color: p.textMuted),
                      ],
                      if (c.muted) ...[
                        const SizedBox(width: 5),
                        Icon(Icons.notifications_off_rounded, size: 14, color: p.textMuted),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: typing ? p.accent : (c.unread > 0 ? p.text : p.textMuted),
                      fontWeight: c.unread > 0 ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (last != null)
                  Text(
                    _timeLabel(last.time),
                    style: TextStyle(color: c.unread > 0 ? p.accent : p.textMuted, fontSize: 12),
                  ),
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c.pinned) ...[
                      Icon(Icons.push_pin_rounded, size: 15, color: p.textMuted),
                      const SizedBox(width: 4),
                    ],
                    if (mention) ...[
                      Icon(Icons.alternate_email_rounded, size: 17, color: p.accent),
                      const SizedBox(width: 4),
                    ],
                    if (c.unread > 0)
                      CountBadge(c.unread)
                    else if (requests > 0)
                      Icon(Icons.person_add_alt_1_rounded, size: 18, color: p.accent)
                    else
                      const SizedBox(height: 22),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatsTab extends StatelessWidget {
  const _ChatsTab({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    // المحادثات الخاصة والجروبات اللي إنت فيها مع بعض (المتثبتة فوق، وبعدها الأحدث)
    final chats = ChatHub.instance.conversations;
    if (chats.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: context.l10n.noChatsTitle,
        message: context.l10n.noChatsBody,
        action: SizedBox(
          width: 230,
          child: PrimaryButton(label: context.l10n.startNewChat, icon: Icons.edit_rounded, height: 50, onPressed: onNew),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      itemCount: chats.length,
      itemBuilder: (_, i) => _ConversationTile(key: ValueKey(chats[i].id), conversation: chats[i]),
    );
  }
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final hub = ChatHub.instance;
    final mine = hub.groupChats;
    final nearby = hub.nearbyGroups;
    if (mine.isEmpty && nearby.isEmpty) {
      return EmptyState(
        icon: Icons.groups_outlined,
        title: context.l10n.noGroupsTitle,
        message: context.l10n.noGroupsBody,
        action: SizedBox(
          width: 200,
          child: PrimaryButton(label: context.l10n.createGroup, icon: Icons.group_add_rounded, height: 50, onPressed: onCreate),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 0, bottom: 96),
      children: [
        if (mine.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: SectionLabel(context.l10n.myGroups)),
          for (final g in mine) _ConversationTile(key: ValueKey(g.id), conversation: g),
        ],
        if (nearby.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: SectionLabel(context.l10n.groupsAround)),
          for (final g in nearby)
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: _NearbyGroupCard(group: g)),
        ],
      ],
    );
  }
}

/// جروب ظاهر حواليك: اضغط عشان تدخل / تطلب.
class _NearbyGroupCard extends StatelessWidget {
  const _NearbyGroupCard({required this.group});

  final NearbyGroup group;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hub = ChatHub.instance;
    final g = group;
    return AppCard(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                onTap: () => joinGroupFlow(context, g.ad),
                child: Row(
                  children: [
                    Avatar(
                      name: g.ad.name,
                      color: int.parse(g.ad.id.substring(0, 6), radix: 16),
                      size: 50,
                      icon: Icons.groups_rounded,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.ad.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(groupModeIcon(g.ad.mode), size: 13, color: p.textMuted),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${groupModeLabel(g.ad.mode)} • ${context.l10n.membersNearby(g.members)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: p.textMuted, fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: hub.pendingJoins.contains(g.ad.id) ? p.surfaceAlt : p.accentSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        hub.pendingJoins.contains(g.ad.id)
                            ? context.l10n.waiting
                            : g.ad.mode == GroupMode.ask
                                ? context.l10n.requestJoin
                                : context.l10n.join,
                        style: TextStyle(
                          color: hub.pendingJoins.contains(g.ad.id) ? p.textMuted : p.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
  }
}

class _PeopleTab extends StatefulWidget {
  const _PeopleTab({required this.isWifi});

  final bool isWifi;

  @override
  State<_PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<_PeopleTab> {
  final _ip = TextEditingController();
  bool _manual = false;
  bool _dialing = false;

  @override
  void dispose() {
    _ip.dispose();
    super.dispose();
  }

  Future<void> _connectManual(LanLink lan) async {
    final ip = _ip.text.trim();
    if (InternetAddress.tryParse(ip) == null) {
      showToast(context, context.l10n.ipFormat, error: true);
      return;
    }
    hideKeyboard();
    setState(() => _dialing = true);
    final ok = await lan.connectToAddress(ip);
    if (!mounted) return;
    setState(() => _dialing = false);
    showToast(context, ok ? context.l10n.ipConnected : context.l10n.errNoReplyTitle, error: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hub = ChatHub.instance;
    final people = hub.people;
    final groups = hub.nearbyGroups;
    final link = hub.link;
    final lan = link is LanLink
        ? link
        : link is DualLink && link.wifi is LanLink
            ? link.wifi as LanLink
            : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        if (people.isEmpty) ...[
          const SizedBox(height: 18),
          Center(child: RadarPulse(icon: widget.isWifi ? Icons.wifi_rounded : Icons.bluetooth_searching_rounded)),
          const SizedBox(height: 14),
          Text(
            context.l10n.searchingPeople,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            widget.isWifi
                ? context.l10n.searchWifiHint
                : context.l10n.searchBtHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textMuted, height: 1.7),
          ),
        ] else ...[
          SectionLabel(context.l10n.peopleTapToTalk(people.length)),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < people.length; i++) ...[
                  if (i > 0) Divider(indent: 76, color: p.border),
                  _PersonRow(node: people[i]),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.hub_outlined, size: 16, color: p.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.meshHint,
                    style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (groups.isNotEmpty) ...[
          SectionLabel(context.l10n.groupsAroundCount(groups.length)),
          for (final g in groups)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: _NearbyGroupCard(group: g)),
        ],
        if (lan != null && lan.hasNetwork) ...[
          const SizedBox(height: 14),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: _manual
                ? AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(context.l10n.connectByAddress, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.connectByAddressHint(lan.localAddresses.join(context.l10n.listSeparator)),
                          style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.6),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _ip,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(hintText: context.l10n.otherDeviceAddress),
                          onSubmitted: (_) => _connectManual(lan),
                        ),
                        const SizedBox(height: 10),
                        PrimaryButton(
                          label: context.l10n.connect,
                          icon: Icons.link_rounded,
                          height: 48,
                          loading: _dialing,
                          onPressed: () => _connectManual(lan),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _manual = true),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: Text(context.l10n.someoneMissing),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.node});

  final MeshNode node;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final n = node;
    final relays = n.hops - 1;
    return InkWell(
      onTap: () {
        final chat = ChatHub.instance.openDirect(n.id);
        if (chat != null) ChatPage.open(context, chat);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Avatar(name: n.name, color: n.color, avatarHash: n.avatar, cartoon: n.cartoon, size: 48, online: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(relays == 0 ? Icons.near_me_rounded : Icons.hub_outlined, size: 12.5, color: p.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        relays == 0
                            ? context.l10n.connectedDirectly
                            : context.l10n.viaRelays(relays),
                        style: TextStyle(color: p.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chat_bubble_outline_rounded, color: p.accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _RequirementsView extends StatelessWidget {
  const _RequirementsView({required this.requirements, required this.onFix});

  final List<Requirement>? requirements;
  final ValueChanged<Requirement> onFix;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reqs = requirements;
    if (reqs == null) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(context.l10n.oneStepTitle, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          context.l10n.oneStepBody,
          style: TextStyle(color: p.textMuted, height: 1.6),
        ),
        const SizedBox(height: 18),
        for (final r in reqs) ...[
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(icon: r.icon, color: r.ok ? p.success : p.accent, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(r.why, style: TextStyle(color: p.textMuted, fontSize: 13, height: 1.55)),
                      if (r.state == RequirementState.blocked) ...[
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.permissionBlockedHint,
                          style: TextStyle(color: p.warning, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (r.ok)
                  Icon(Icons.check_circle_rounded, color: p.success)
                else
                  FilledButton(
                    onPressed: () => onFix(r),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(r.fixLabel),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
