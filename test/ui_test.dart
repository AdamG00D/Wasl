import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasl/core/nav.dart';
import 'package:wasl/core/profile/profile.dart';
import 'package:wasl/core/settings/app_settings.dart';
import 'package:wasl/core/storage/chat_store.dart';
import 'package:wasl/core/storage/vault.dart';
import 'package:wasl/core/theme/app_theme.dart';
import 'package:wasl/features/chat/chat_page.dart';
import 'package:wasl/features/chat/core/chat_session.dart';
import 'package:wasl/features/groups/group_ui.dart';
import 'package:wasl/features/home/home_screen.dart';
import 'package:wasl/features/home/transport_screen.dart';
import 'package:wasl/features/hub/chat_hub.dart';
import 'package:wasl/features/onboarding/profile_editor.dart';
import 'package:wasl/features/settings/settings_screen.dart';
import 'package:wasl/mesh/mesh_router.dart';

Widget app(Widget home, {Brightness brightness = Brightness.light}) => MaterialApp(
      navigatorKey: rootNavigatorKey,
      theme: AppTheme.build(AccentTheme.all.first, brightness),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

/// اختبارات دخان للشاشات: بتتبني من غير أخطاء على مقاس موبايل، فاتح وغامق.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('wasl_ui_');
    await AppSettings.instance.load();
    await Vault.instance.init(root: tmp);
    ChatStore.instance.reset();
  });

  tearDownAll(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('إنشاء البروفايل أول مرة', (tester) async {
    phone(tester);
    var done = false;
    await tester.pumpWidget(app(ProfileEditor(onDone: () => done = true)));
    expect(find.text('اعمل بروفايلك'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'آدم');
    await tester.scrollUntilVisible(find.text('يلا نبدأ'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('يلا نبدأ'));
    for (var i = 0; i < 20 && !done; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(done, isTrue);
    expect(ProfileStore.instance.current!.name, 'آدم');
    expect(ProfileStore.instance.current!.id.length, 16);
  });

  for (final b in Brightness.values) {
    testWidgets('اختيار بلوتوث/واي فاي + الإعدادات (${b.name})', (tester) async {
      phone(tester);
      await tester.pumpWidget(app(const TransportScreen(), brightness: b));
      expect(find.text('بلوتوث'), findsOneWidget);
      expect(find.text('واي فاي'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('حفظ المحادثات على الموبايل'), findsOneWidget);
      // الافتراضي: الحفظ مقفول والقفل مقفول
      expect(AppSettings.instance.saveChats, isFalse);
      expect(AppSettings.instance.lockEnabled, isFalse);
      await tester.scrollUntilVisible(find.text('إزاي Wasl بيشتغل؟'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('إزاي Wasl بيشتغل؟'));
      await tester.pumpAndSettle();
      expect(find.text('شبكة Mesh'), findsOneWidget);
    });
  }

  testWidgets('الرئيسية على الواي فاي: جروب جديد وشاشة المحادثة', (tester) async {
    phone(tester);
    final hub = ChatHub.instance;
    await tester.runAsync(() => hub.start(TransportKind.wifi));
    addTearDown(() => tester.runAsync(hub.stop));
    await tester.pumpWidget(app(const HomeScreen(kind: TransportKind.wifi)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('لسه مفيش محادثات'), findsOneWidget);
    expect(find.text('ابدأ محادثة جديدة'), findsOneWidget);

    // القريبين
    await tester.tap(find.text('القريبين'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('بندوّر على ناس حواليك'), findsWidgets);

    // الجروبات ← جروب جديد بكلمة سر
    await tester.tap(find.text('الجروبات'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('مفيش جروبات حواليك'), findsOneWidget);
    late GroupChat g;
    await tester.runAsync(() async {
      g = await hub.createGroup(name: 'الشلة', mode: GroupMode.password, password: 'سر1234');
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('الشلة'), findsOneWidget);
    expect(hub.groupChats.single.info.mode, GroupMode.password);

    // شاشة الجروب
    g.session.messages.addAll([
      ChatMessage(id: 'a', text: 'أهلاً بيكم', kind: MessageKind.mine),
      ChatMessage(
        id: 'b',
        text: 'منوّرين',
        kind: MessageKind.theirs,
        sender: 'منى',
        senderId: 'aaaaaaaaaaaaaaaa',
        reply: const ReplyInfo(id: 'a', preview: 'أهلاً بيكم', toMine: true, author: 'آدم'),
      ),
    ]);
    await tester.pumpWidget(app(ChatPage(conversation: g)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('منوّرين'), findsOneWidget);
    expect(find.text('منى'), findsOneWidget);
    expect(find.text('الشلة'), findsOneWidget);

    // معلومات الجروب
    await tester.pumpWidget(app(GroupInfoScreen(group: g)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('إنت صاحبه'), findsOneWidget);

    // نافذة إنشاء جروب
    await tester.pumpWidget(app(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(onPressed: () => showCreateGroupSheet(context), child: const Text('open')),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('بطلب انضمام'), findsOneWidget);
    await tester.tap(find.text('بكلمة سر'));
    await tester.pumpAndSettle();
    expect(find.text('كلمة سر الجروب'), findsOneWidget);
  });
}
