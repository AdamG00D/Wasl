import 'package:flutter/material.dart';

import '../../core/profile/profile.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../hub/chat_hub.dart';
import '../settings/settings_screen.dart';
import 'home_screen.dart';

/// أول صفحة بعد البروفايل: بلوتوث ولا واي فاي؟
class TransportScreen extends StatelessWidget {
  const TransportScreen({super.key});

  void _open(BuildContext context, TransportKind kind) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'home'),
      builder: (_) => HomeScreen(kind: kind),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: ProfileStore.instance,
          builder: (context, _) {
            final me = ProfileStore.instance.current!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
              children: [
                Row(
                  children: [
                    Avatar(name: me.name, color: me.color, avatarHash: me.avatarHash, cartoon: me.cartoon, size: 50),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('أهلاً', style: TextStyle(color: p.textMuted, fontSize: 13, height: 1.2)),
                          Text(
                            me.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.4),
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
                const SizedBox(height: 40),
                const Text(
                  'هتتكلم\nإزاي النهارده؟',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'من غير إنترنت في الحالتين، وكل حاجة مشفّرة.',
                  style: TextStyle(color: p.textMuted, fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 28),
                _Choice(
                  icon: Icons.bluetooth_rounded,
                  title: 'بلوتوث',
                  subtitle: 'للناس القريبة منك من غير أي شبكة. الرسايل بتعدّي من موبايل لموبايل فبتوصل لأبعد.',
                  tags: const ['من غير شبكة', 'Mesh'],
                  gradient: [p.accent, p.second],
                  onTap: () => _open(context, TransportKind.bluetooth),
                ),
                const SizedBox(height: 14),
                _Choice(
                  icon: Icons.wifi_rounded,
                  title: 'واي فاي',
                  subtitle: 'نفس الواي فاي أو هوت سبوت من موبايل. أسرع بكتير، وفيه فيديو ومكالمات صوت وصورة.',
                  tags: const ['أسرع', 'مكالمات', 'فيديو'],
                  gradient: [p.second, p.accent],
                  onTap: () => _open(context, TransportKind.wifi),
                ),
                const SizedBox(height: 14),
                _Choice(
                  icon: Icons.hub_rounded,
                  title: 'الاتنين مع بعض',
                  subtitle:
                      'موبايلك يبقى كوبري: يوصّل اللي على الواي فاي أو الهوت سبوت باللي على البلوتوث، فكذا شبكة تبقى شبكة واحدة.',
                  tags: const ['كوبري', 'أوسع مدى', 'بطارية أكتر'],
                  gradient: [p.accent, Color.lerp(p.accent, p.second, 0.5)!],
                  onTap: () => _open(context, TransportKind.both),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> tags;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = Palette.onColor(gradient.first);
    return Material(
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              PositionedDirectional(
                end: -24,
                bottom: -30,
                child: Icon(icon, size: 150, color: fg.withValues(alpha: 0.10)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: fg.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(icon, color: fg, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(title, style: TextStyle(color: fg, fontSize: 24, fontWeight: FontWeight.w700)),
                        ),
                        Icon(Icons.arrow_back_rounded, color: fg),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(subtitle, style: TextStyle(color: fg.withValues(alpha: 0.88), height: 1.65, fontSize: 14.5)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final t in tags)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: fg.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(t, style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
