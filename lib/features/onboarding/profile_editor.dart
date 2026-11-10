import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/platform/system_bridge.dart';
import '../../core/profile/profile.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/cartoon_avatar.dart';
import '../../widgets/feedback.dart';
import '../../widgets/focus_guard.dart';
import '../../widgets/ui.dart';

/// إنشاء البروفايل (أول مرة) أو تعديله (من الإعدادات).
class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key, this.onDone});

  /// أول مرة: بيتنادى بعد إنشاء البروفايل. لو null الشاشة بتقفل نفسها بعد الحفظ.
  final VoidCallback? onDone;

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final _existing = ProfileStore.instance.current;
  late final _name = TextEditingController(text: _existing?.name ?? '');
  late int _color = _existing?.color ?? (DateTime.now().millisecondsSinceEpoch % avatarColors.length);

  /// صورة جديدة اتختارت (مصغّرة وجاهزة).
  File? _picked;
  bool _removed = false;
  bool _busy = false;

  /// الأفاتار الكرتوني المختار (null = من غير).
  late int? _cartoon = _existing?.cartoon;

  bool get _isNew => _existing == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    hideKeyboard();
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x == null) return;
      // صورة صغيرة عشان تتبعت بسهولة للناس اللي حواليك
      File? out;
      for (final (side, quality) in const [(256, 72), (200, 60), (144, 50)]) {
        final path = await SystemBridge.compressImage(x.path, maxSide: side, quality: quality);
        if (path == null) break;
        final f = File(path);
        if (await f.length() <= Avatars.maxBytes) {
          out = f;
          break;
        }
      }
      if (!mounted) return;
      if (out == null) {
        showToast(context, 'معرفناش نستخدم الصورة دي — جرّب صورة تانية', error: true);
        return;
      }
      setState(() {
        _picked = out;
        _removed = false;
        _cartoon = null; // الصورة بتاخد مكان الأفاتار الكرتوني
      });
    } catch (_) {
      if (mounted) showToast(context, 'معرفناش نفتح المعرض', error: true);
    }
  }

  Future<void> _save() async {
    final name = Profile.cleanName(_name.text);
    if (name.length < 2) {
      showToast(context, 'اكتب اسم من حرفين على الأقل', error: true);
      return;
    }
    hideKeyboard();
    setState(() => _busy = true);
    final store = ProfileStore.instance;
    try {
      if (_isNew) {
        await store.create(name: name, color: _color, avatarFile: _picked?.path, cartoon: _cartoon);
      } else {
        await store.update(
          name: name,
          color: _color,
          avatarFile: _picked?.path ?? (_removed ? '' : null),
          cartoon: _cartoon ?? 0,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showToast(context, 'معرفناش نحفظ البروفايل', error: true);
      }
      return;
    }
    if (!mounted) return;
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasPhoto = _picked != null || (!_removed && _existing?.avatarHash != null);
    return Scaffold(
      backgroundColor: p.bg,
      appBar: _isNew ? null : AppBar(title: const Text('البروفايل')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            if (_isNew) ...[
              const SizedBox(height: 28),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(gradient: p.accentGradient, borderRadius: BorderRadius.circular(16)),
                    child: Icon(Icons.hub_rounded, color: p.onAccent),
                  ),
                  const SizedBox(width: 12),
                  const Text('وَصْل', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 26),
              const Text('اعمل بروفايلك', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.3)),
              const SizedBox(height: 8),
              Text(
                'اسم وصورة يشوفهم الناس اللي حواليك. من غير رقم موبايل ولا إيميل ولا إنترنت — كل حاجة على موبايلك بس.',
                style: TextStyle(color: p.textMuted, height: 1.7, fontSize: 15),
              ),
              const SizedBox(height: 30),
            ] else
              const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: _busy ? null : _pick,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ListenableBuilder(
                      listenable: _name,
                      builder: (_, _) => Avatar(
                        name: _name.text,
                        color: _color,
                        size: 116,
                        file: _picked,
                        avatarHash: _removed || _picked != null ? null : _existing?.avatarHash,
                        cartoon: _cartoon,
                      ),
                    ),
                    PositionedDirectional(
                      end: -6,
                      bottom: -6,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.bg, width: 3),
                        ),
                        child: Icon(Icons.photo_camera_rounded, color: p.onAccent, size: 19),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (hasPhoto)
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _picked = null;
                    _removed = true;
                  }),
                  style: TextButton.styleFrom(foregroundColor: p.textMuted),
                  child: const Text('شيل الصورة'),
                ),
              )
            else
              const SizedBox(height: 22),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              maxLength: 24,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'اسمك',
                prefixIcon: Icon(Icons.person_outline_rounded),
                counterText: '',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 22),
            Text('لون البروفايل', style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < avatarColors.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _color = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: avatarColors[i],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: _color == i ? p.text : Colors.transparent, width: 2.5),
                      ),
                      child: _color == i ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'أو اختار أفاتار كرتوني',
              style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 1; i <= CartoonAvatars.count; i++)
                  GestureDetector(
                    onTap: () => setState(() {
                      // ضغطة تانية على نفس الأفاتار بتشيله
                      _cartoon = _cartoon == i ? null : i;
                      if (_cartoon != null) {
                        _picked = null;
                        _removed = true;
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(color: _cartoon == i ? p.accent : Colors.transparent, width: 2.5),
                      ),
                      child: Avatar(name: '', color: _color, cartoon: i, size: 50),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 34),
            PrimaryButton(
              label: _isNew ? 'يلا نبدأ' : 'حفظ',
              icon: _isNew ? Icons.arrow_back_rounded : Icons.check_rounded,
              loading: _busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
