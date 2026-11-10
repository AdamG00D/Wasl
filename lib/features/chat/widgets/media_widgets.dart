import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../core/platform/system_bridge.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/feedback.dart';
import '../core/chat_link.dart';
import '../core/chat_session.dart';
import '../voice/voice.dart';

/// قائمة المرفقات (زي الواتساب): مستند، كاميرا، المعرض، صوت.
Future<void> showAttachSheet(BuildContext context, ChatLink link, {ReplyInfo? reply, VoidCallback? onSent}) async {
  final p = context.palette;
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 8,
              runSpacing: 18,
              children: [
                _AttachItem(icon: Icons.insert_drive_file_rounded, label: 'مستند', color: Color(0xFF7F66FF), value: 'doc'),
                _AttachItem(icon: Icons.photo_camera_rounded, label: 'كاميرا', color: Color(0xFFFF2E74), value: 'camera'),
                _AttachItem(icon: Icons.photo_library_rounded, label: 'المعرض', color: Color(0xFFC861FA), value: 'gallery'),
                _AttachItem(icon: Icons.headphones_rounded, label: 'صوت', color: Color(0xFFFF7F21), value: 'audio'),
              ],
            ),
            if (!link.supportsVideo) ...[
              const SizedBox(height: 14),
              Text(
                'الفيديو متاح في دردشة الواي فاي / الهوت سبوت (البلوتوث أبطأ من كده).',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textMuted, fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case 'doc':
      await _sendDocument(context, link, reply: reply, onSent: onSent);
    case 'audio':
      await _sendDocument(context, link, reply: reply, onSent: onSent, audio: true);
    case 'gallery':
      await _sendGallery(context, link, reply: reply, onSent: onSent);
    case 'camera':
      var video = false;
      if (link.supportsVideo) {
        final pick = await showModalBottomSheet<bool>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded),
                  title: const Text('صورة'),
                  onTap: () => Navigator.pop(ctx, false),
                ),
                ListTile(
                  leading: const Icon(Icons.videocam_rounded),
                  title: const Text('فيديو'),
                  onTap: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ),
        );
        if (pick == null) return;
        video = pick;
      }
      if (context.mounted) await sendFromCamera(context, link, video: video, reply: reply, onSent: onSent);
  }
}

class _AttachItem extends StatelessWidget {
  const _AttachItem({required this.icon, required this.label, required this.color, required this.value});

  final IconData icon;
  final String label;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pop(context, value),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// الكاميرا: صورة (أو فيديو في الواي فاي).
Future<void> sendFromCamera(
  BuildContext context,
  ChatLink link, {
  bool video = false,
  ReplyInfo? reply,
  VoidCallback? onSent,
}) async {
  if (video && !link.supportsVideo) {
    showToast(context, 'الفيديو متاح في دردشة الواي فاي بس', error: true);
    return;
  }
  final st = await Permission.camera.request();
  if (!st.isGranted) {
    if (context.mounted) showToast(context, 'محتاجين إذن الكاميرا — فعّله من إعدادات التطبيق', error: true);
    if (st.isPermanentlyDenied) await openAppSettings();
    return;
  }
  XFile? file;
  try {
    final picker = ImagePicker();
    file = video
        ? await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 10))
        : await picker.pickImage(source: ImageSource.camera, imageQuality: 82, maxWidth: 2048, maxHeight: 2048);
  } catch (_) {
    if (context.mounted) showToast(context, 'معرفناش نفتح الكاميرا', error: true);
    return;
  }
  if (file == null || !context.mounted) return;
  var source = File(file.path);
  if (video) {
    final ready = await prepareVideo(context, source);
    if (ready == null || !context.mounted) return;
    source = ready;
  }
  final error = await link.session.sendMedia(source, video ? MediaKind.video : MediaKind.image, reply: reply);
  if (error != null) {
    if (context.mounted) showToast(context, error, error: true);
  } else {
    onSent?.call();
  }
}

const _videoExts = {'mp4', 'mov', '3gp', 'mkv', 'webm', 'avi', 'm4v', '3g2', 'ts'};

/// المعرض: صور وفيديوهات (أكتر من واحدة مع بعض).
///
/// ⚠️ منطلبش من مكتبة الاختيار تصغّر الصور: لما بتختار حاجة واحدة، المكتبة مش
/// بتعرف إنها فيديو و"بتصغّرها" كصورة، فبيتبعت أول فريم بس بامتداد mp4.
/// بنعرف النوع من محتوى الملف نفسه، والصور بنصغّرها إحنا.
Future<void> _sendGallery(BuildContext context, ChatLink link, {ReplyInfo? reply, VoidCallback? onSent}) async {
  List<XFile> files;
  try {
    files = await ImagePicker().pickMultipleMedia(limit: 20);
  } catch (_) {
    if (context.mounted) showToast(context, 'معرفناش نفتح المعرض', error: true);
    return;
  }
  if (files.isEmpty) return;
  var first = true;
  var skippedVideo = false;
  for (final f in files) {
    final file = File(f.path);
    final ext = f.path.contains('.') ? f.path.split('.').last.toLowerCase() : '';
    final sniffed = await ChatSession.sniffKind(file);
    final video = sniffed == MediaKind.video ||
        (sniffed == null && (_videoExts.contains(ext) || (f.mimeType?.startsWith('video/') ?? false)));
    if (video && !link.supportsVideo) {
      skippedVideo = true;
      continue;
    }
    var source = file;
    if (!video) {
      final small = await SystemBridge.compressImage(f.path);
      if (small != null) source = File(small);
    } else {
      if (!context.mounted) return;
      final ready = await prepareVideo(context, file);
      if (ready == null) return; // اتلغى
      source = ready;
    }
    if (!context.mounted) return;
    final error = await link.session.sendMedia(
      source,
      video ? MediaKind.video : MediaKind.image,
      reply: first ? reply : null,
    );
    if (error != null) {
      if (context.mounted) showToast(context, error, error: true);
      return;
    }
    if (first) onSent?.call();
    first = false;
  }
  if (skippedVideo && context.mounted) {
    showToast(context, 'الفيديو متاح في دردشة الواي فاي بس — اتبعتت الصور بس', error: true);
  }
}

/// يجهّز الفيديو قبل الإرسال: لو كبير أو بترميز تقيل بنضغطه (زي الواتساب) عشان
/// يشتغل على أي جهاز — مش كل الموبايلات/التابلت تقدر تشغّل فيديو 1080×2340 مثلاً.
/// null = المستخدم لغى.
Future<File?> prepareVideo(BuildContext context, File file) async {
  if (!await SystemBridge.videoNeedsCompression(file.path)) return file;
  if (!context.mounted) return null;
  final result = await showDialog<_VideoPrepResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CompressDialog(path: file.path),
  );
  if (result == null || result.canceled) return null;
  if (result.path == null) {
    if (context.mounted) showToast(context, 'معرفناش نضغط الفيديو — هيتبعت زي ما هو', error: true);
    return file;
  }
  return File(result.path!);
}

class _VideoPrepResult {
  const _VideoPrepResult({this.path, this.canceled = false});
  final String? path;
  final bool canceled;
}

class _CompressDialog extends StatefulWidget {
  const _CompressDialog({required this.path});

  final String path;

  @override
  State<_CompressDialog> createState() => _CompressDialogState();
}

class _CompressDialogState extends State<_CompressDialog> {
  Timer? _poll;
  int _progress = -1;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    SystemBridge.compressVideo(widget.path).then((out) {
      if (!mounted || _done) return;
      _done = true;
      Navigator.pop(context, _VideoPrepResult(path: out));
    });
    _poll = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      final v = await SystemBridge.videoProgress();
      if (mounted && v != _progress) setState(() => _progress = v);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: Icon(Icons.movie_creation_rounded, color: p.accent, size: 32),
        title: const Text('بنجهّز الفيديو', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'بنصغّره عشان يشتغل على أي موبايل ويتبعت أسرع.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress < 0 ? null : _progress / 100,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(_progress < 0 ? '...' : '$_progress%', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _done = true;
              SystemBridge.cancelVideoCompression();
              Navigator.pop(context, const _VideoPrepResult(canceled: true));
            },
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }
}

/// مستند أو ملف صوت.
Future<void> _sendDocument(
  BuildContext context,
  ChatLink link, {
  ReplyInfo? reply,
  VoidCallback? onSent,
  bool audio = false,
}) async {
  final session = link.session;
  PlatformFile? picked;
  try {
    picked = await FilePicker.pickFile(type: audio ? FileType.audio : FileType.any);
  } catch (_) {
    if (context.mounted) showToast(context, 'معرفناش نفتح الملفات', error: true);
    return;
  }
  if (picked == null) return;
  final length = await picked.length() ?? 0;
  if (length > session.maxFileBytes) {
    if (context.mounted) showToast(context, 'الملف أكبر من ${_formatSize(session.maxFileBytes)}', error: true);
    return;
  }
  File source;
  final path = picked.path;
  if (path != null) {
    source = File(path);
  } else {
    // أندرويد بيدّي رابط (content://) — بننسخه الأول عشان نقدر نقسّمه ونكمّل منه لو الاتصال وقع
    try {
      final dir = await Directory(
        '${(await getTemporaryDirectory()).path}/wasl_out/${DateTime.now().microsecondsSinceEpoch}',
      ).create(recursive: true);
      source = File('${dir.path}/${picked.name.replaceAll(RegExp(r'[\\/]'), '_')}');
      final sink = source.openWrite();
      await sink.addStream(picked.xFile.openRead());
      await sink.close();
    } catch (_) {
      if (context.mounted) showToast(context, 'معرفناش نقرا الملف', error: true);
      return;
    }
  }
  final error = await session.sendMedia(source, MediaKind.file, name: picked.name, reply: reply);
  if (error != null) {
    if (context.mounted) showToast(context, error, error: true);
  } else {
    onSent?.call();
  }
}

String _formatSize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// محتوى فقاعة فيها صورة أو فيديو أو ملف.
class MediaBubbleContent extends StatelessWidget {
  const MediaBubbleContent({super.key, required this.message, this.onCancel});

  final ChatMessage message;

  /// إلغاء الإرسال/الاستلام (زرار ✕ أثناء النقل).
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final media = message.media!;
    final mine = message.kind == MessageKind.mine;
    final transferring = message.transferring;
    const width = 230.0;

    if (media.kind == MediaKind.file) {
      return _FileContent(message: message, onCancel: onCancel);
    }
    if (media.kind == MediaKind.voice) {
      return VoiceBubbleContent(message: message, onCancel: onCancel);
    }

    Widget content;
    if (media.failed && !(mine && media.path != null)) {
      content = _Placeholder(
        width: width,
        child: _FailedLabel(mine: mine, reason: media.failReason),
      );
    } else if (media.path == null) {
      content = _Placeholder(
        width: width,
        child: _Progress(progress: media.progress, size: media.size, paused: media.paused),
      );
    } else if (media.kind == MediaKind.image) {
      content = Image.file(
        File(media.path!),
        width: width,
        fit: BoxFit.cover,
        cacheWidth: 700,
        errorBuilder: (_, _, _) => const _Placeholder(width: width, child: Icon(Icons.broken_image_rounded)),
      );
    } else {
      content = _VideoThumb(path: media.path!, width: width);
    }

    return GestureDetector(
      onTap: media.ready && !transferring ? () => MediaViewer.open(context, media) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ConstrainedBox(constraints: const BoxConstraints(maxHeight: 320), child: content),
            if (transferring && media.path != null)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Center(
                    child: _Progress(progress: media.progress, size: media.size, light: true, paused: media.paused),
                  ),
                ),
              ),
            if (mine && media.failed && media.path != null)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(child: _FailedLabel(mine: true, light: true, reason: media.failReason)),
                ),
              ),
            if (transferring && onCancel != null)
              PositionedDirectional(
                top: 6,
                end: 6,
                child: _CancelButton(onPressed: onCancel!),
              ),
          ],
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.close_rounded, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class _FailedLabel extends StatelessWidget {
  const _FailedLabel({required this.mine, this.light = false, this.reason});

  final bool mine;
  final bool light;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline_rounded, color: light ? Colors.white : p.danger, size: 30),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            reason ?? (mine ? 'موصلش — ابعته تاني' : 'الملف موصلش كامل'),
            textAlign: TextAlign.center,
            style: TextStyle(color: light ? Colors.white : p.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// فقاعة ملف (PDF وغيره): أيقونة + اسم + حجم، والضغط بيفتحه.
class _FileContent extends StatelessWidget {
  const _FileContent({required this.message, this.onCancel});

  final ChatMessage message;
  final VoidCallback? onCancel;

  static IconData iconFor(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf_rounded,
      'doc' || 'docx' || 'txt' || 'rtf' || 'odt' => Icons.description_rounded,
      'xls' || 'xlsx' || 'csv' || 'ods' => Icons.table_chart_rounded,
      'ppt' || 'pptx' || 'odp' => Icons.slideshow_rounded,
      'zip' || 'rar' || '7z' || 'tar' || 'gz' => Icons.folder_zip_rounded,
      'mp3' || 'wav' || 'm4a' || 'ogg' || 'aac' || 'opus' => Icons.audio_file_rounded,
      'apk' => Icons.android_rounded,
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'heic' => Icons.image_rounded,
      'mp4' || 'mkv' || 'mov' || '3gp' || 'webm' => Icons.movie_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = message;
    final media = m.media!;
    final mine = m.kind == MessageKind.mine;
    final fg = mine ? p.onAccent : p.text;
    final name = media.name ?? 'ملف';
    final transferring = m.transferring;

    String detail;
    if (media.failed) {
      detail = media.failReason ?? (mine ? 'موصلش — ابعته تاني' : 'الملف موصلش كامل');
    } else if (transferring) {
      detail = media.paused
          ? 'مستني الاتصال يرجع... ${(media.progress * 100).round()}%'
          : '${(media.progress * 100).round()}% من ${_formatSize(media.size)}';
    } else {
      final ext = name.contains('.') ? name.split('.').last.toUpperCase() : '';
      detail = '${_formatSize(media.size)}${ext.isEmpty || ext.length > 6 ? '' : ' • $ext'}';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: media.ready && !transferring ? () => openChatFile(context, media) : null,
      child: Container(
        width: 250,
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
        decoration: BoxDecoration(
          color: (mine ? Colors.black : p.accent).withValues(alpha: mine ? 0.10 : 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (mine ? Colors.white : p.accent).withValues(alpha: mine ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    media.failed ? Icons.error_outline_rounded : iconFor(name),
                    color: media.failed && !mine ? p.danger : (mine ? fg : p.accent),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 14, height: 1.35),
                      ),
                      const SizedBox(height: 2),
                      Text(detail, style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 11.5)),
                    ],
                  ),
                ),
                if (transferring && onCancel != null)
                  IconButton(
                    tooltip: mine ? 'إلغاء الإرسال' : 'إلغاء الاستلام',
                    visualDensity: VisualDensity.compact,
                    onPressed: onCancel,
                    icon: Icon(Icons.close_rounded, color: fg),
                  )
                else if (media.ready && !mine)
                  IconButton(
                    tooltip: 'حفظ في التنزيلات',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => saveChatFile(context, media),
                    icon: Icon(Icons.download_rounded, color: p.accent),
                  ),
              ],
            ),
            if (transferring) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: media.progress <= 0 ? null : media.progress,
                  minHeight: 4,
                  color: mine ? fg : p.accent,
                  backgroundColor: (mine ? fg : p.accent).withValues(alpha: 0.2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// يفتح الملف بالتطبيق المناسب على الموبايل.
Future<void> openChatFile(BuildContext context, ChatMedia media) async {
  // الاسم بيحدد النوع للتطبيق التاني (فيديو/PDF...) — للصور والفيديو بناخده من الامتداد
  final ok = await SystemBridge.openFile(media.path!, media.name ?? media.path!.split('/').last);
  if (!ok && context.mounted) {
    showToast(context, 'مفيش تطبيق على الموبايل يفتح النوع ده — احفظه أو شاركه', error: true);
  }
}

/// يحفظ نسخة في فولدر التنزيلات (Download/Wasl).
Future<void> saveChatFile(BuildContext context, ChatMedia media) async {
  // أندرويد 9 وأقدم محتاج إذن التخزين
  if (await SystemBridge.sdkInt() < 29) {
    final st = await Permission.storage.request();
    if (!st.isGranted) {
      if (context.mounted) showToast(context, 'محتاجين إذن التخزين عشان نحفظ الملف', error: true);
      return;
    }
  }
  final ok = await SystemBridge.saveToDownloads(media.path!, media.name ?? media.path!.split('/').last);
  if (context.mounted) {
    showToast(context, ok ? 'اتحفظ في التنزيلات ← Wasl' : 'معرفناش نحفظ الملف', error: !ok);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 170,
      color: context.palette.surfaceAlt,
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.progress,
    required this.size,
    this.light = false,
    this.paused = false,
  });

  final double progress;
  final int size;
  final bool light;

  /// الاتصال وقف — هيكمّل لما يرجع.
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = light ? Colors.white : p.accent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 46,
          height: 46,
          child: CircularProgressIndicator(
            value: progress <= 0 ? null : progress,
            strokeWidth: 3,
            color: color,
            backgroundColor: color.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          paused ? 'مستني الاتصال... ${(progress * 100).round()}%' : '${(progress * 100).round()}% • ${_formatSize(size)}',
          style: TextStyle(
            color: light ? Colors.white : p.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// أول فريم من الفيديو + زرار تشغيل.
class _VideoThumb extends StatefulWidget {
  const _VideoThumb({required this.path, required this.width});

  final String path;
  final double width;

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  VideoPlayerController? _c;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.file(File(widget.path));
    _c = c;
    c
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((_) {
          if (mounted) setState(() => _error = true);
        });
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    final ratio = ready && c.value.aspectRatio > 0
        ? c.value.aspectRatio
        : 16 / 9;
    return SizedBox(
      width: widget.width,
      height: (widget.width / ratio).clamp(120, 320).toDouble(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            )
          else
            ColoredBox(
              color: Colors.black,
              child: _error
                  ? const Align(
                      alignment: Alignment(0, 0.7),
                      child: Text(
                        'اضغط عشان تفتحه',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    )
                  : null,
            ),
          const Center(
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Color(0x99000000),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
          if (ready)
            PositionedDirectional(
              bottom: 8,
              end: 10,
              child: Text(
                _formatDuration(c.value.duration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// عرض الصورة/الفيديو بملء الشاشة + حفظ ومشاركة.
class MediaViewer extends StatefulWidget {
  const MediaViewer({super.key, required this.media});

  final ChatMedia media;

  static Future<void> open(BuildContext context, ChatMedia media) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => MediaViewer(media: media)),
      );

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  VideoPlayerController? _video;

  /// المشغّل اللي جوه التطبيق مقدرش يشغّل الفيديو (نوع ترميز مش مدعوم مثلاً).
  bool _videoError = false;

  bool get _isVideo => widget.media.kind == MediaKind.video;

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      final c = VideoPlayerController.file(File(widget.media.path!));
      _video = c;
      c
          .initialize()
          .then((_) {
            if (!mounted) return;
            setState(() {});
            c.play();
          })
          .catchError((_) {
            if (mounted) setState(() => _videoError = true);
          });
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        if (mounted) {
          showToast(context, 'محتاجين إذن الوصول للصور', error: true);
        }
        return;
      }
      if (_isVideo) {
        await Gal.putVideo(widget.media.path!);
      } else {
        await Gal.putImage(widget.media.path!);
      }
      if (mounted) showToast(context, 'اتحفظ في المعرض');
    } catch (_) {
      if (mounted) showToast(context, 'معرفناش نحفظ الملف', error: true);
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(widget.media.path!)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black38,
        actions: [
          if (_isVideo)
            IconButton(
              tooltip: 'افتح بتطبيق تاني',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => openChatFile(context, widget.media),
            ),
          IconButton(
            tooltip: 'حفظ في المعرض',
            icon: const Icon(Icons.download_rounded),
            onPressed: _save,
          ),
          IconButton(
            tooltip: 'مشاركة',
            icon: const Icon(Icons.share_rounded),
            onPressed: _share,
          ),
        ],
      ),
      body: Center(
        child: !_isVideo
            ? InteractiveViewer(
                maxScale: 5,
                child: Image.file(File(widget.media.path!)),
              )
            : _videoError
            ? Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.movie_filter_rounded, color: Colors.white70, size: 54),
                    const SizedBox(height: 14),
                    const Text(
                      'الفيديو وصل سليم، بس المشغّل اللي جوه التطبيق مش قادر يشغّل النوع ده.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 15.5, height: 1.6),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => openChatFile(context, widget.media),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('افتح بتطبيق تاني'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _save,
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('احفظه في المعرض'),
                    ),
                  ],
                ),
              )
            : v == null || !v.value.isInitialized
            ? const CircularProgressIndicator(color: Colors.white)
            : GestureDetector(
                onTap: () => v.value.isPlaying ? v.pause() : v.play(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: v.value.aspectRatio,
                      child: VideoPlayer(v),
                    ),
                    if (!v.value.isPlaying)
                      const CircleAvatar(
                        radius: 34,
                        backgroundColor: Color(0x99000000),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: v != null && v.value.isInitialized
          ? SafeArea(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      IconButton(
                        color: Colors.white,
                        icon: Icon(
                          v.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        onPressed: () =>
                            v.value.isPlaying ? v.pause() : v.play(),
                      ),
                      Text(
                        _formatDuration(v.value.position),
                        style: const TextStyle(color: Colors.white),
                      ),
                      Expanded(
                        child: VideoProgressIndicator(
                          v,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      Text(
                        _formatDuration(v.value.duration),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
