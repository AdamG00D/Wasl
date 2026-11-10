import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/platform/system_bridge.dart';
import '../../core/theme/app_theme.dart';
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
      showToast(context, ok ? 'اتقبلت في "${ad.name}" 🎉' : 'طلبك لدخول "${ad.name}" اترفض', error: !ok);
    });
    _noticeSub = _hub.notices.listen((text) {
      if (mounted) showToast(context, text, error: true);
    });
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
        title: 'تقفل الاتصال؟',
        message: unsaved
            ? 'هتبقى مش ظاهر للناس، والمحادثات اللي مش محفوظة هتتمسح.'
            : 'هتبقى مش ظاهر للناس لحد ما تدخل تاني.',
        confirm: 'اقفل',
        destructive: unsaved,
      );
      if (!ok) return;
    }
    _leaving = true;
    await _hub.stop();
    if (mounted) Navigator.of(context).pop();
  }

  void _openPeople() => setState(() => _tab = 2);

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
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      _ChatsTab(onNew: _openPeople),
                      _GroupsTab(onCreate: _createGroup),
                      _PeopleTab(isWifi: widget.kind != TransportKind.bluetooth),
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
                      _tab == 0 ? 'محادثة جديدة' : 'جروب جديد',
                      style: const TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700),
                    ),
                  ),
            bottomNavigationBar: !showNav
                ? null
                : NavigationBar(
                    selectedIndex: _tab,
                    onDestinationSelected: (i) => setState(() => _tab = i),
                    backgroundColor: p.surface,
                    indicatorColor: p.accentSoft,
                    surfaceTintColor: Colors.transparent,
                    height: 68,
                    destinations: [
                      NavigationDestination(
                        icon: _NavIcon(Icons.chat_bubble_outline_rounded, _hub.directUnread),
                        selectedIcon: _NavIcon(Icons.chat_bubble_rounded, _hub.directUnread, selected: true),
                        label: 'المحادثات',
                      ),
                      NavigationDestination(
                        icon: _NavIcon(Icons.groups_outlined, _hub.groupUnread),
                        selectedIcon: _NavIcon(Icons.groups_rounded, _hub.groupUnread, selected: true),
                        label: 'الجروبات',
                      ),
                      const NavigationDestination(
                        icon: _NavIcon(Icons.radar_rounded, 0),
                        selectedIcon: _NavIcon(Icons.radar_rounded, 0, selected: true),
                        label: 'القريبين',
                      ),
                    ],
                  ),
          );
        },
      ),
    );
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
          IconButton(tooltip: 'رجوع', onPressed: onBack, icon: const BackButtonIcon()),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('وَصْل', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25)),
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
                            ? 'بنجهّز...'
                            : n == 0
                                ? 'بندوّر على ناس حواليك'
                                : '$n ${n == 1 ? 'شخص قريب' : n <= 10 ? 'أشخاص قريبين' : 'شخص قريب'}',
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
            tooltip: 'الإعدادات',
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
                  label: const Text('حاول تاني'),
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
                  label: const Text('افتح الواي فاي'),
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
  if (now.difference(t).inDays < 1) return 'أمس';
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
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(c.saved ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined),
                title: Text(c.saved ? 'إلغاء حفظ المحادثة' : 'حفظ المحادثة على الموبايل'),
                onTap: () => Navigator.pop(ctx, 'save'),
              ),
              ListTile(
                leading: Icon(c.isGroup ? Icons.logout_rounded : Icons.delete_outline_rounded, color: p.danger),
                title: Text(c.isGroup ? 'الخروج من الجروب' : 'حذف المحادثة', style: TextStyle(color: p.danger)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'save') {
      await hub.setSaved(c, !c.saved);
      if (context.mounted) showToast(context, c.saved ? 'المحادثة بتتحفظ على الموبايل' : 'المحادثة مبقتش بتتحفظ');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: c.isGroup ? 'الخروج من "${c.title}"؟' : 'حذف المحادثة مع ${c.title}؟',
      message: 'الرسايل هتتمسح من موبايلك.',
      confirm: c.isGroup ? 'خروج' : 'حذف',
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
    final typing = direct != null && c.session.peerTyping;

    String preview;
    if (typing) {
      preview = 'بيكتب...';
    } else if (last == null) {
      preview = group != null ? 'جروب ${groupModeLabel(group.info.mode)}' : 'اضغط وابدأ الكلام';
    } else {
      final text = ChatSession.previewOf(last);
      preview = last.kind == MessageKind.mine
          ? 'إنت: $text'
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
      ),
    );
  }
}

class _ChatsTab extends StatelessWidget {
  const _ChatsTab({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final chats = ChatHub.instance.directChats;
    if (chats.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'لسه مفيش محادثات',
        message: 'اختار حد من القريبين وابدأ الكلام. التشفير بيتعمل تلقائي من غير كلمة سر.',
        action: SizedBox(
          width: 230,
          child: PrimaryButton(label: 'ابدأ محادثة جديدة', icon: Icons.edit_rounded, height: 50, onPressed: onNew),
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
    final p = context.palette;
    final hub = ChatHub.instance;
    final mine = hub.groupChats;
    final nearby = hub.nearbyGroups;
    if (mine.isEmpty && nearby.isEmpty) {
      return EmptyState(
        icon: Icons.groups_outlined,
        title: 'مفيش جروبات حواليك',
        message: 'اعمل جروب عام لأي حد قريب، أو خاص بكلمة سر أو بموافقتك. الجروب بيظهر للكل طول ما فيه عضو قريب.',
        action: SizedBox(
          width: 200,
          child: PrimaryButton(label: 'اعمل جروب', icon: Icons.group_add_rounded, height: 50, onPressed: onCreate),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 0, bottom: 96),
      children: [
        if (mine.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: SectionLabel('جروباتي')),
          for (final g in mine) _ConversationTile(key: ValueKey(g.id), conversation: g),
        ],
        if (nearby.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: SectionLabel('جروبات حواليك')),
          for (final g in nearby)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: AppCard(
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
                                  '${groupModeLabel(g.ad.mode)} • ${g.members} ${g.members == 1 ? 'عضو قريب' : 'أعضاء قريبين'}',
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
                            ? 'مستني'
                            : g.ad.mode == GroupMode.ask
                                ? 'اطلب'
                                : 'ادخل',
                        style: TextStyle(
                          color: hub.pendingJoins.contains(g.ad.id) ? p.textMuted : p.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
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
      showToast(context, 'اكتب العنوان بالشكل ده: 192.168.1.5', error: true);
      return;
    }
    hideKeyboard();
    setState(() => _dialing = true);
    final ok = await lan.connectToAddress(ip);
    if (!mounted) return;
    setState(() => _dialing = false);
    showToast(context, ok ? 'اتوصلنا — هيظهر في القايمة دلوقتي' : 'مفيش رد من العنوان ده', error: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hub = ChatHub.instance;
    final people = hub.people;
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
          const Text(
            'بندوّر على ناس حواليك',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            widget.isWifi
                ? 'أي حد فاتح Wasl على نفس الواي فاي (أو متوصل بالهوت سبوت بتاعك) هيظهر هنا لوحده.'
                : 'أي حد قريب فاتح Wasl على البلوتوث هيظهر هنا لوحده. البحث بياخد من ثواني لدقيقة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textMuted, height: 1.7),
          ),
        ] else ...[
          SectionLabel('اضغط على أي حد عشان تكلمه (${people.length})'),
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
                    'الأجهزة بتوصّل لبعض: ممكن تكلم حد بعيد عنك عن طريق موبايلات في النص، ومحدش منهم يقدر يقرا رسايلك.',
                    style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
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
                        const Text('اتصال بالعنوان', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          'لو الشبكة مانعة الاكتشاف التلقائي (زي بعض شبكات الكافيهات). عنوانك: ${lan.localAddresses.join(' ، ')}',
                          style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.6),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _ip,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(hintText: 'عنوان الجهاز التاني'),
                          onSubmitted: (_) => _connectManual(lan),
                        ),
                        const SizedBox(height: 10),
                        PrimaryButton(
                          label: 'اتصل',
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
                      label: const Text('حد مش ظاهر؟ اتصل بعنوانه'),
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
                            ? 'متصل بيك مباشرة'
                            : 'عن طريق ${relays == 1 ? 'جهاز واحد' : relays == 2 ? 'جهازين' : '$relays أجهزة'} في النص',
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
        const Text('خطوة واحدة قبل ما نبدأ', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          'البلوتوث بيشتغل من غير إنترنت، وعشان الموبايلات تلاقي بعض محتاجين الحاجات دي:',
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
                          'الإذن ده اترفض قبل كده — فعّله من الإعدادات ← الأذونات.',
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
