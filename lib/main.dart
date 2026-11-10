import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config.dart';
import 'core/nav.dart';
import 'core/profile/profile.dart';
import 'core/settings/app_settings.dart';
import 'core/storage/vault.dart';
import 'core/theme/app_theme.dart';
import 'features/home/transport_screen.dart';
import 'features/hub/chat_hub.dart';
import 'features/lock/app_lock.dart';
import 'features/onboarding/profile_editor.dart';
import 'widgets/focus_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await AppSettings.instance.load();
  await Vault.instance.init();
  await ProfileStore.instance.load();
  ChatHub.cleanLeftovers();
  AppLock.instance.start();
  runApp(const WaslApp());
}

class WaslApp extends StatelessWidget {
  const WaslApp({super.key});

  static final _focusGuard = FocusGuard();

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        navigatorKey: rootNavigatorKey,
        navigatorObservers: [_focusGuard],
        theme: AppTheme.build(settings.accent, Brightness.light),
        darkTheme: AppTheme.build(settings.accent, Brightness.dark),
        themeMode: settings.themeMode,
        themeAnimationDuration: const Duration(milliseconds: 300),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _Start(),
      ),
    );
  }
}

/// أول شاشة: القفل (لو متفعّل) ← إنشاء البروفايل (أول مرة) ← اختيار بلوتوث/واي فاي.
class _Start extends StatefulWidget {
  const _Start();

  @override
  State<_Start> createState() => _StartState();
}

class _StartState extends State<_Start> {
  bool _unlocked = !AppSettings.instance.lockEnabled;

  @override
  void initState() {
    super.initState();
    AppLock.instance.lockedAtStart();
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) return LockScreen(onUnlocked: () => setState(() => _unlocked = true));
    if (ProfileStore.instance.current == null) {
      return ProfileEditor(onDone: () => setState(() {}));
    }
    return const TransportScreen();
  }
}
