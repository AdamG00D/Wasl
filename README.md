<p align="center">
  <img src="docs/images/banner.png" alt="وَصْل — شات مشفّر من غير إنترنت ولا سيرفر" width="100%">
</p>

<p align="center">
  <a href="https://github.com/AdamG00D/Wasl/actions/workflows/ci.yml"><img src="https://github.com/AdamG00D/Wasl/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/AdamG00D/Wasl/releases/latest"><img src="https://img.shields.io/github/v/release/AdamG00D/Wasl?label=release" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="GPL-3.0"></a>
  <img src="https://img.shields.io/badge/Android-7%2B-3DDC84?logo=android&logoColor=white" alt="Android 7+">
</p>

# Wasl — وَصْل

شات مشفّر **من غير إنترنت ومن غير سيرفر**: الموبايلات بتكلم بعض مباشرة بالبلوتوث أو على نفس الواي فاي / الهوت سبوت،
والرسايل بتعدّي من موبايل لموبايل (Mesh) فبتوصل لأبعد من مدى موبايلك. أندرويد — Flutter — واجهة عربي.

> **English:** Wasl is an offline, serverless, end-to-end encrypted chat app for Android (Flutter, Arabic UI).
> Nearby phones talk over Bluetooth (Google Nearby Connections) or the same Wi-Fi / hotspot and relay for each
> other as a mesh. See [docs/PROTOCOL.md](docs/PROTOCOL.md) for the wire protocol and
> [SECURITY.md](SECURITY.md) for the threat model. Contributions are welcome — [CONTRIBUTING.md](CONTRIBUTING.md).

## المميزات

- بروفايل من غير رقم موبايل ولا إيميل: اسم + لون + صورة أو أفاتار كرتوني.
- **شات خاص** مشفّر من طرف لطرف تلقائياً (من غير كلمة سر)، ورمز أمان اختياري للتأكد.
- **جروبات**: عام / بكلمة سر / بطلب انضمام — بمديرين، إزالة أعضاء، ومسح رسايل.
- **Mesh**: لحد 6 قفزات. وتقدر تشغّل الواي فاي والبلوتوث سوا فموبايلك يبقى كوبري بين شبكتين.
- صور، ملفات، فويس، رد، تعديل، حذف عند الكل، تفاعل بالإيموجي، منشن، تحويل، بحث، علامات القراءة و"بيكتب...".
- مكالمات صوت وفيديو على الواي فاي.
- إشعارات بشكل تطبيقات الشات، كتم وتثبيت للمحادثات.
- حفظ المحادثات **اختياري** (الافتراضي: لأ) ومشفّر بمفتاح جوه Android Keystore. قفل برقم سري / بصمة.
- مفيش أي اتصال بالإنترنت، ومفيش تحليلات ولا إعلانات.

## التحميل

نزّل `Wasl_1.1.apk` من [آخر إصدار](https://github.com/AdamG00D/Wasl/releases/latest) وسطّبه (أندرويد 7 أو أحدث).
لو الموبايل رفض، اسمح بالتثبيت من مصادر غير معروفة. وتقدر تتأكد من الملف بالبصمة المكتوبة جنبه (`.sha256`).

## التشغيل من الكود

محتاج [Flutter](https://docs.flutter.dev/get-started/install) (stable، Dart ≥ 3.9) و JDK 17 أو أحدث.

```bash
flutter pub get
flutter analyze        # لازم: No issues found!
flutter test           # الشبكة، التشفير، الجروبات، التخزين، الواجهة
flutter run            # على موبايل أندرويد (البلوتوث مبيشتغلش على المحاكي)
```

من غير مفتاح التوقيع المشروع بيتبني عادي وبيتوقّع بمفتاح الـ debug. الإصدار الرسمي بيتبني بـ
`./scripts/build_release.sh` (محتاج المفتاح في `../Signing_Key/` — برا المستودع ومبيترفعش أبداً).

عشان تجرّب محتاج موبايلين: الاتنين على نفس الواي فاي (أو واحد فاتح هوت سبوت والتاني داخل عليه)، أو الاتنين
بلوتوث وجنب بعض.

## المشروع من جوه

| المكان | فيه إيه |
|---|---|
| `lib/mesh/` | وسايل الربط (واي فاي / بلوتوث / الاتنين) وموجّه الشبكة |
| `lib/features/chat/core/` | القناة المشفّرة، الجلسة، نقل الملفات |
| `lib/features/groups/` | الجروبات: المفاتيح، الجلسة، أوامر الإدارة |
| `lib/features/hub/chat_hub.dart` | بيربط كل حاجة: الشبكة، المحادثات، الحفظ، الإشعارات |
| `lib/core/` | التشفير، البروفايل، التخزين المشفّر، الإعدادات، الثيم |
| `android/…/kotlin/` | الإشعارات، الخدمة، Keystore، التشفير السريع، الضغط |
| `test/` | اختبارات بشبكة وهمية في الذاكرة (من غير موبايلات) |

التفاصيل الكاملة والقواعد اللي الكود ماشي عليها في [AGENTS.md](AGENTS.md)، والبروتوكول في
[docs/PROTOCOL.md](docs/PROTOCOL.md).

## المساهمة والأمان

- عايز تساهم؟ اقرا [CONTRIBUTING.md](CONTRIBUTING.md).
- لقيت ثغرة؟ **متفتحش issue علني** — اتبع [SECURITY.md](SECURITY.md).
- حدود الأمان المعروفة مكتوبة بصراحة في [SECURITY.md](SECURITY.md) — اقراها قبل ما تعتمد على التطبيق في حاجة حساسة.

## الترخيص

Wasl برنامج حر تحت رخصة **GNU GPL v3.0 أو أحدث** — النص الكامل في [LICENSE](LICENSE).

Copyright © 2026 Adam Ghanem and Wasl contributors.

إذن إضافي (حسب البند 7 من GPLv3): مسموح تربط البرنامج ده بمكتبات Google Play Services (اللي Nearby Connections
جزء منها) وتوزّع الناتج، من غير ما ده يخلّي المكتبات دي خاضعة للرخصة.

الخط [IBM Plex Sans Arabic](https://github.com/IBM/plex) تحت رخصة SIL Open Font License 1.1.
