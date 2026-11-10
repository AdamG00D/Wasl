import 'dart:io';

import '../../features/chat/core/chat_session.dart';
import '../../features/groups/group.dart';
import 'vault.dart';

/// بيانات محادثة محفوظة (من غير الرسايل نفسها).
class StoredChat {
  StoredChat({
    required this.id,
    required this.isGroup,
    required this.name,
    this.color = 0,
    this.avatar,
    this.cartoon,
    this.publicKey,
    this.saveOverride,
    this.unread = 0,
    this.verifiedKey,
    this.lastActivity = 0,
  });

  final String id;
  final bool isGroup;
  String name;
  int color;
  String? avatar;
  int? cartoon;

  /// مفتاح هوية الشخص (Base64) — للمحادثات الخاصة.
  String? publicKey;

  /// اختيار المستخدم للمحادثة دي بالذات (null = زي الإعداد العام).
  bool? saveOverride;
  int unread;
  String? verifiedKey;
  int lastActivity;

  Map<String, dynamic> toJson() => {
        'id': id,
        'g': isGroup,
        'name': name,
        'color': color,
        'avatar': ?avatar,
        'cartoon': ?cartoon,
        'pk': ?publicKey,
        'save': ?saveOverride,
        'unread': unread,
        'vk': ?verifiedKey,
        'la': lastActivity,
      };

  static StoredChat? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      return StoredChat(
        id: raw['id'] as String,
        isGroup: raw['g'] == true,
        name: '${raw['name'] ?? ''}',
        color: (raw['color'] as num?)?.toInt() ?? 0,
        avatar: raw['avatar'] as String?,
        cartoon: (raw['cartoon'] as num?)?.toInt(),
        publicKey: raw['pk'] as String?,
        saveOverride: raw['save'] as bool?,
        unread: (raw['unread'] as num?)?.toInt() ?? 0,
        verifiedKey: raw['vk'] as String?,
        lastActivity: (raw['la'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// اختيارات المستخدم لمحادثة: تثبيت فوق وكتم الإشعارات.
class ChatPrefs {
  ChatPrefs({this.pinned = false, this.mutedUntil = 0});

  bool pinned;

  /// 0 = مش مكتومة • -1 = مكتومة دايماً • غير كده = لحد الوقت ده (ملي ثانية).
  int mutedUntil;

  bool get isDefault => !pinned && mutedUntil == 0;

  Map<String, dynamic> toJson() => {if (pinned) 'pin': true, if (mutedUntil != 0) 'mute': mutedUntil};

  static ChatPrefs fromJson(Map<dynamic, dynamic> raw) =>
      ChatPrefs(pinned: raw['pin'] == true, mutedUntil: (raw['mute'] as num?)?.toInt() ?? 0);
}

/// المحادثات المحفوظة على الجهاز (مشفّرة) + الجروبات اللي أنا فيها + المحظورين.
///
/// المحادثة بتتكتب هنا بس لو المستخدم مفعّل الحفظ (من الإعدادات أو للمحادثة نفسها).
class ChatStore {
  ChatStore._();
  static final ChatStore instance = ChatStore._();

  static const _indexFile = 'chats/index.bin';
  static const _groupsFile = 'groups.bin';
  static const _blockedFile = 'blocked.bin';
  static const _prefsFile = 'chat_prefs.bin';

  final Map<String, StoredChat> index = {};
  final Map<String, GroupInfo> groups = {};
  final Set<String> blocked = {};

  /// تثبيت / كتم لكل محادثة (اللي ليها اختيار بس).
  final Map<String, ChatPrefs> prefs = {};
  bool _loaded = false;
  Future<void> _writes = Future.value();

  Vault get _vault => Vault.instance;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final idx = await _vault.readJson(_indexFile);
    if (idx is List) {
      for (final e in idx) {
        final c = StoredChat.fromJson(e);
        if (c != null) index[c.id] = c;
      }
    }
    final gs = await _vault.readJson(_groupsFile);
    if (gs is List) {
      for (final e in gs) {
        final g = GroupInfo.fromJson(e);
        if (g != null) groups[g.id] = g;
      }
    }
    final bl = await _vault.readJson(_blockedFile);
    if (bl is List) blocked.addAll(bl.whereType<String>());
    final pr = await _vault.readJson(_prefsFile);
    if (pr is Map) {
      for (final e in pr.entries) {
        if (e.key is String && _safeId(e.key as String) && e.value is Map) {
          prefs[e.key as String] = ChatPrefs.fromJson(e.value as Map);
        }
      }
    }
  }

  /// للاختبارات.
  void reset() {
    index.clear();
    groups.clear();
    blocked.clear();
    prefs.clear();
    _loaded = false;
  }

  // الكتابات بالترتيب (عشان ملف ميتكتبش فوق نسخة أحدث منه)
  Future<void> _queue(Future<void> Function() job) {
    final next = _writes.then((_) => job());
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> saveIndex() =>
      _queue(() => _vault.writeJson(_indexFile, [for (final c in index.values) c.toJson()]));

  Future<void> saveGroups() =>
      _queue(() => _vault.writeJson(_groupsFile, [for (final g in groups.values) g.toJson()]));

  Future<void> saveBlocked() => _queue(() => _vault.writeJson(_blockedFile, blocked.toList()));

  Future<void> savePrefs() {
    prefs.removeWhere((_, p) => p.isDefault);
    return _queue(() => _vault.writeJson(_prefsFile, {for (final e in prefs.entries) e.key: e.value.toJson()}));
  }

  static bool _safeId(String id) => RegExp(r'^[0-9a-f]{16}$').hasMatch(id);

  /// فولدر الملفات الثابت لمحادثة محفوظة.
  Directory mediaDir(String id) => Directory('${_vault.dir.path}/media/$id');

  Future<List<ChatMessage>> loadMessages(String id) async {
    if (!_safeId(id)) return [];
    final raw = await _vault.readJson('chats/$id.bin');
    if (raw is! List) return [];
    return [
      for (final e in raw)
        if (ChatMessage.fromJson(e) case final ChatMessage m) m,
    ];
  }

  Future<void> saveMessages(String id, List<ChatMessage> messages) {
    if (!_safeId(id)) return Future.value();
    final data = [
      for (final m in messages)
        if (m.kind != MessageKind.system) m.toJson(),
    ];
    return _queue(() => _vault.writeJson('chats/$id.bin', data));
  }

  /// يمسح المحادثة المحفوظة (الرسايل والملفات) من الجهاز.
  Future<void> deleteChat(String id) {
    if (!_safeId(id)) return Future.value();
    index.remove(id);
    return _queue(() async {
      await _vault.delete('chats/$id.bin');
      try {
        final d = mediaDir(id);
        if (await d.exists()) await d.delete(recursive: true);
      } catch (_) {}
      await _vault.writeJson(_indexFile, [for (final c in index.values) c.toJson()]);
    });
  }

  /// يمسح الملفات المؤقتة اللي فضلت من تشغيل قبل كده.
  static Future<void> cleanTemp(Directory temp) async {
    try {
      await for (final e in temp.list()) {
        final name = e.path.split('/').last;
        if (e is Directory && (name.startsWith('wasl_chat_') || name == 'wasl_voice' || name == 'wasl_out')) {
          await e.delete(recursive: true);
        }
      }
    } catch (_) {}
  }
}
