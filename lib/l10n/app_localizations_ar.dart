// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get confirm => 'تأكيد';

  @override
  String get cancel => 'إلغاء';

  @override
  String get ok => 'حسناً';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get stopSavingTitle => 'توقف حفظ المحادثات؟';

  @override
  String get stopSavingBody =>
      'المحادثات المحفوظة هتتمسح من تخزين الموبايل (ما عدا اللي اخترت تحفظها بنفسك من جوه المحادثة).';

  @override
  String get stopSavingConfirm => 'وقّف الحفظ';

  @override
  String get savingOnToast => 'المحادثات هتتحفظ على الموبايل (مشفّرة)';

  @override
  String get savingOffToast => 'المحادثات مش هتتحفظ';

  @override
  String get lockOnToast => 'القفل اتفعّل';

  @override
  String get lockOffToast => 'القفل اتشال';

  @override
  String get bioConfirmTitle => 'تأكيد البصمة';

  @override
  String get bioConfirmSubtitle => 'عشان تفتح Wasl بيها';

  @override
  String get wipeTitle => 'مسح كل المحادثات؟';

  @override
  String get wipeBody =>
      'كل الرسايل والملفات المحفوظة هتتمسح من موبايلك نهائياً. بروفايلك والجروبات اللي إنت فيها هيفضلوا.';

  @override
  String get wipeConfirm => 'امسح الكل';

  @override
  String get wipeDone => 'اتمسح كل حاجة';

  @override
  String get blockedTitle => 'المحظورين';

  @override
  String get blockedEmpty => 'مفيش حد محظور.';

  @override
  String get blockedNone => 'مفيش حد';

  @override
  String personShort(Object id) {
    return 'شخص ($id)';
  }

  @override
  String get unblock => 'إلغاء الحظر';

  @override
  String get editProfileHint => 'تعديل الاسم والصورة واللون';

  @override
  String get privacy => 'الخصوصية';

  @override
  String get saveChats => 'حفظ المحادثات على الموبايل';

  @override
  String get saveChatsOn =>
      'الرسايل بتتحفظ مشفّرة وبتلاقيها لما تفتح التطبيق تاني.';

  @override
  String get saveChatsOff =>
      'مقفول: المحادثات بتتمسح لما تقفل التطبيق. تقدر تحفظ محادثة معينة من جواها.';

  @override
  String get appLock => 'قفل التطبيق برقم سري';

  @override
  String get appLockOn => 'متفعّل — اضغط عشان تشيله';

  @override
  String get appLockOff => 'اختياري. من غيره التطبيق بيفتح على طول.';

  @override
  String get unlockWithFingerprint => 'فتح بالبصمة';

  @override
  String get autoLock => 'القفل التلقائي';

  @override
  String get autoLockSub => 'بعد ما تسيب التطبيق';

  @override
  String get lockNow => 'على طول';

  @override
  String get lockMinute => 'دقيقة';

  @override
  String get lock5 => '5 دقايق';

  @override
  String get lock15 => '15 دقيقة';

  @override
  String get wipeAll => 'مسح كل المحادثات';

  @override
  String get appearance => 'المظهر';

  @override
  String get themeAuto => 'تلقائي';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'غامق';

  @override
  String get appColor => 'لون التطبيق';

  @override
  String get language => 'اللغة';

  @override
  String get languageAuto => 'تلقائي';

  @override
  String get languageAutoHint =>
      'تلقائي: زي لغة الموبايل (عربي لو الموبايل عربي، غير كده إنجليزي).';

  @override
  String get about => 'عن التطبيق';

  @override
  String aboutTagline(Object license) {
    return 'شات من غير إنترنت • مفتوح المصدر ($license)';
  }

  @override
  String get sourceCode => 'الكود على GitHub';

  @override
  String get linkCopied => 'اتنسخ اللينك';

  @override
  String get noBrowser => 'مفيش متصفح يفتح اللينك — اتنسخ بداله';

  @override
  String get howItWorks => 'إزاي Wasl بيشتغل؟';

  @override
  String get howItWorksSub => 'من غير إنترنت ومن غير سيرفر';

  @override
  String get howNoInternetTitle => 'من غير إنترنت ولا سيرفر';

  @override
  String get howNoInternetBody =>
      'الموبايلات بتكلم بعض مباشرة بالبلوتوث أو على نفس الواي فاي / الهوت سبوت. مفيش حساب ولا رقم موبايل.';

  @override
  String get howMeshTitle => 'شبكة Mesh';

  @override
  String get howMeshBody =>
      'كل موبايل عليه Wasl بيوصّل للي حواليه، فرسالتك تقدر تعدّي على كذا موبايل لحد ما توصل لحد بعيد عنك.';

  @override
  String get howEncryptionTitle => 'تشفير تلقائي';

  @override
  String get howEncryptionBody =>
      'الشات الخاص مشفّر من طرف لطرف بمفاتيح بتتولّد لوحدها — من غير كلمة سر. الموبايلات اللي في النص بتوصّل بس ومبتقراش حاجة.';

  @override
  String get howBothTitle => 'الاتنين مع بعض';

  @override
  String get howBothBody =>
      'لو شغّلت الواي فاي والبلوتوث سوا موبايلك بيبقى كوبري: اللي على هوت سبوت يوصل للي على هوت سبوت تاني عن طريق البلوتوث. المكالمات والفيديو بيفضلوا جوه نفس الشبكة.';

  @override
  String get howGroupsTitle => 'الجروبات';

  @override
  String get howGroupsBody =>
      'عام: أي حد قريب يدخل ويقرا. بكلمة سر أو بطلب انضمام: محدش يقرا غير الأعضاء. الجروب بيفضل ظاهر طول ما فيه عضو قريب.';

  @override
  String get howAdminTitle => 'إدارة الجروب';

  @override
  String get howAdminBody =>
      'صاحب الجروب بيعيّن مديرين، والمدير يشيل أعضاء ويمسح رسايلهم. في جروب \"بطلب انضمام\" المفتاح بيتغير لما حد يتشال فمبيقراش الجديد؛ في العام وبكلمة السر الإزالة حظر بتطبّقه التطبيقات.';

  @override
  String get howNotifTitle => 'الإشعارات';

  @override
  String get howNotifBody =>
      'الإشعار فيه اسم اللي بعت ونص الرسالة. لو مفعّل قفل التطبيق بيبقى \"رسالة جديدة\" بس، وعلى شاشة قفل الموبايل النص مبيظهرش أبداً. تقدر تكتم أي محادثة.';

  @override
  String get howSaveTitle => 'الحفظ اختياري';

  @override
  String get howSaveBody =>
      'الافتراضي إن المحادثات مبتتحفظش وبتتمسح مع قفل التطبيق. لو فعّلت الحفظ بتتخزن مشفّرة على موبايلك بس.';

  @override
  String get howSafetyTitle => 'رمز الأمان';

  @override
  String get howSafetyBody =>
      'لو عايز تتأكد 100% إنك بتكلم الشخص الصح، قارنوا رمز الأمان (6 أرقام) من قايمة المحادثة. اختياري.';

  @override
  String get pinWrong => 'الرقم غلط';

  @override
  String get pinMismatch => 'الرقمين مش زي بعض — ابدأ تاني';

  @override
  String get pinEnterCurrent => 'اكتب الرقم السري الحالي';

  @override
  String get pinChoose => 'اختار رقم سري (4 لـ 8 أرقام)';

  @override
  String get pinRepeat => 'اكتبه تاني للتأكيد';

  @override
  String get colorIndigo => 'نيلي';

  @override
  String get colorTeal => 'فيروزي';

  @override
  String get colorEmerald => 'أخضر';

  @override
  String get colorCoral => 'مرجاني';

  @override
  String get colorAmber => 'كهرماني';

  @override
  String get colorSky => 'سماوي';

  @override
  String get colorPink => 'وردي';

  @override
  String get colorGraphite => 'رمادي';

  @override
  String get errRejectedTitle => 'الطرف التاني رفض الاتصال';

  @override
  String get errRejectedHint =>
      'اطلب منه يقبل الطلب لما يظهر عنده، وجرّب تاني.';

  @override
  String get errPeerGoneTitle => 'الجهاز التاني مش ظاهر دلوقتي';

  @override
  String get errPeerGoneHint =>
      'اتأكد إنه لسه فاتح شاشة الدردشة وقريب منك (أقل من 10 متر تقريباً).';

  @override
  String get errReconnectTitle => 'معرفناش نرجّع الاتصال';

  @override
  String get errReconnectHint =>
      'غالباً الجهاز التاني بعد أو قفل الشاشة. افتحوا الدردشة على الجهازين وابدأوا تاني.';

  @override
  String get errNoNetworkTitle => 'مش متوصل بأي شبكة';

  @override
  String get errNoNetworkHint =>
      'شغّل الواي فاي واتوصل بشبكة، أو افتح نقطة اتصال (Hotspot) من الإعدادات وخلّي التاني يتوصل بيها.';

  @override
  String get errHandshakeTitle => 'معرفناش نأمّن الاتصال';

  @override
  String get errHandshakeHint =>
      'حصل خطأ أثناء تبادل مفاتيح التشفير. تأكد إن الجهازين عليهم آخر نسخة من Wasl وجرّب تاني.';

  @override
  String get errNoPlayTitle => 'الدردشة القريبة محتاجة خدمات Google Play';

  @override
  String get errNoPlayHint =>
      'الجهاز ده مفيهوش خدمات Google أو محتاجة تحديث. حدّث \"خدمات Google Play\" من المتجر، أو استخدم الدردشة عبر الواي فاي.';

  @override
  String get errPermissionTitle => 'ناقص إذن';

  @override
  String get errPermissionHint =>
      'التطبيق محتاج إذن \"الأجهزة القريبة\" عشان يلاقي الجهاز التاني. اسمح بيه وجرّب تاني.';

  @override
  String get errRadioTitle => 'البلوتوث أو الواي فاي مش مستجيب';

  @override
  String get errRadioHint =>
      'اقفل البلوتوث وافتحه تاني (ولو ينفع الواي فاي كمان)، وبعدين جرّب. لو المشكلة استمرت اعمل ريستارت للموبايل.';

  @override
  String get errAlreadyConnectedTitle => 'فيه اتصال قديم لسه مفتوح';

  @override
  String get errAlreadyConnectedHint =>
      'اقفل شاشة الدردشة على الجهازين وافتحها تاني.';

  @override
  String get errTimeoutTitle => 'الاتصال أخد وقت أطول من اللازم';

  @override
  String get errTimeoutHint => 'قرّب الجهازين من بعض وجرّب تاني.';

  @override
  String get errGenericTitle => 'حصلت مشكلة في الاتصال';

  @override
  String get errGenericHint =>
      'جرّب تقفل الدردشة وتفتحها تاني على الجهازين. لو المشكلة فضلت، اقفل البلوتوث وافتحه.';

  @override
  String get errRefusedTitle => 'الجهاز التاني مش مستني اتصال';

  @override
  String get errRefusedHint =>
      'اتأكد إنه داس \"استضافة\" وإن العنوان مكتوب صح.';

  @override
  String get errNoReplyTitle => 'مفيش رد من العنوان ده';

  @override
  String get errNoReplyHint =>
      'الجهازين لازم يكونوا على نفس شبكة الواي فاي (أو واحد فاتح Hotspot والتاني متوصل بيه). بعض الراوترات العامة بتمنع الأجهزة تكلم بعض.';

  @override
  String get errUnreachableTitle => 'مش متوصل بشبكة';

  @override
  String get errUnreachableHint =>
      'شغّل الواي فاي واتوصل بنفس الشبكة اللي عليها الجهاز التاني.';

  @override
  String get errFailedTitle => 'تعذّر الاتصال';

  @override
  String get errFailedHint => 'اتأكد من العنوان وإن الجهازين على نفس الشبكة.';

  @override
  String get errLanStartTitle => 'معرفناش نبدأ على الشبكة';

  @override
  String get errLanStartHint =>
      'اقفل التطبيق وافتحه تاني. لو المشكلة فضلت اعمل ريستارت للواي فاي.';

  @override
  String get copiedSecure => 'تم النسخ — هيتمسح من الحافظة بعد 30 ثانية';

  @override
  String get notDelivered => 'موصلتش';

  @override
  String get lockBioTitle => 'افتح Wasl';

  @override
  String get lockBioSubtitle => 'بصمتك بدل الرقم السري';

  @override
  String get lockIncomingCall => 'مكالمة واردة — افتح القفل';

  @override
  String get lockEnterPin => 'اكتب الرقم السري';

  @override
  String get lockWrongPin => 'الرقم غلط — جرّب تاني';

  @override
  String get unknownName => 'مجهول';

  @override
  String get otherSide => 'الطرف الآخر';

  @override
  String get hello => 'أهلاً';

  @override
  String get transportHeadline => 'هتتكلم\nإزاي النهارده؟';

  @override
  String get transportSub => 'من غير إنترنت في الحالتين، وكل حاجة مشفّرة.';

  @override
  String get bluetooth => 'بلوتوث';

  @override
  String get bluetoothDesc =>
      'للناس القريبة منك من غير أي شبكة. الرسايل بتعدّي من موبايل لموبايل فبتوصل لأبعد.';

  @override
  String get tagNoNetwork => 'من غير شبكة';

  @override
  String get wifi => 'واي فاي';

  @override
  String get wifiDesc =>
      'نفس الواي فاي أو هوت سبوت من موبايل. أسرع بكتير، وفيه فيديو ومكالمات صوت وصورة.';

  @override
  String get tagFaster => 'أسرع';

  @override
  String get tagCalls => 'مكالمات';

  @override
  String get tagVideo => 'فيديو';

  @override
  String get both => 'الاتنين مع بعض';

  @override
  String get bothDesc =>
      'موبايلك يبقى كوبري: يوصّل اللي على الواي فاي أو الهوت سبوت باللي على البلوتوث، فكذا شبكة تبقى شبكة واحدة.';

  @override
  String get tagBridge => 'كوبري';

  @override
  String get tagRange => 'أوسع مدى';

  @override
  String get tagBattery => 'بطارية أكتر';

  @override
  String get photoUnusable => 'معرفناش نستخدم الصورة دي — جرّب صورة تانية';

  @override
  String get galleryFailed => 'معرفناش نفتح المعرض';

  @override
  String get nameTooShort => 'اكتب اسم من حرفين على الأقل';

  @override
  String get profileSaveFailed => 'معرفناش نحفظ البروفايل';

  @override
  String get profile => 'البروفايل';

  @override
  String get appTitle => 'وَصْل';

  @override
  String get createProfile => 'اعمل بروفايلك';

  @override
  String get createProfileSub =>
      'اسم وصورة يشوفهم الناس اللي حواليك. من غير رقم موبايل ولا إيميل ولا إنترنت — كل حاجة على موبايلك بس.';

  @override
  String get removePhoto => 'شيل الصورة';

  @override
  String get yourName => 'اسمك';

  @override
  String get profileColor => 'لون البروفايل';

  @override
  String get orCartoon => 'أو اختار أفاتار كرتوني';

  @override
  String get letsStart => 'يلا نبدأ';

  @override
  String get save => 'حفظ';

  @override
  String get reqNearbyTitle => 'إذن الأجهزة القريبة';

  @override
  String get reqNearbyWhy =>
      'عشان Wasl يلاقي الموبايلات القريبة ويتصل بيها بالبلوتوث. مش بيستخدم موقعك.';

  @override
  String get reqWifiTitle => 'إذن أجهزة الواي فاي القريبة';

  @override
  String get reqWifiWhy =>
      'بيخلي الرسايل تتنقل أسرع بالواي فاي المباشر لما الجهازين قريبين.';

  @override
  String get reqLocationTitle => 'إذن الموقع';

  @override
  String reqLocationWhy(Object version) {
    return 'أندرويد $version بيشترط إذن الموقع لأي بحث عن أجهزة قريبة. Wasl مش بيقرا موقعك ولا بيحفظه.';
  }

  @override
  String get android11OrOlder => '11 وأقدم';

  @override
  String get reqBluetoothTitle => 'تشغيل البلوتوث';

  @override
  String get reqBluetoothWhy => 'الجهازين بيلاقوا بعض عن طريق البلوتوث.';

  @override
  String get reqGpsTitle => 'تشغيل خدمة الموقع (GPS)';

  @override
  String get reqGpsWhy =>
      'في الإصدار ده من أندرويد البحث عن الأجهزة مش بيشتغل غير والموقع شغال.';

  @override
  String get openSettings => 'افتح الإعدادات';

  @override
  String get allow => 'اسمح';

  @override
  String get turnOn => 'شغّل';

  @override
  String get callIncomingVideo => 'مكالمة فيديو واردة';

  @override
  String get callIncomingVoice => 'مكالمة صوتية واردة';

  @override
  String get callRinging => 'بيرن...';

  @override
  String get callConnecting => 'جاري التوصيل...';

  @override
  String get callEnded => 'المكالمة خلصت';

  @override
  String get cameraOff => 'الكاميرا مقفولة';

  @override
  String get me => 'أنا';

  @override
  String get e2eEncrypted => 'مشفّرة من طرف لطرف';

  @override
  String get decline => 'رفض';

  @override
  String get accept => 'قبول';

  @override
  String get flipCamera => 'قلب الكاميرا';

  @override
  String get camera => 'الكاميرا';

  @override
  String get mute => 'كتم';

  @override
  String get muted => 'مكتوم';

  @override
  String get speaker => 'السماعة';

  @override
  String get earpiece => 'الأذن';

  @override
  String get callBusy => 'فيه مكالمة شغالة بالفعل';

  @override
  String get notConnectedNow => 'مش متصل دلوقتي';

  @override
  String get callNoAnswer => 'مفيش رد';

  @override
  String get callConnectFailed => 'معرفناش نوصّل المكالمة';

  @override
  String get callStartFailed => 'معرفناش نشغّل المكالمة';

  @override
  String get callMediaFailed => 'معرفناش نشغّل الميكروفون/الكاميرا';

  @override
  String get callRejected => 'اترفضت';

  @override
  String get callMissed => 'فاتتك مكالمة';

  @override
  String get callPeerRejected => 'الطرف التاني رفض المكالمة';

  @override
  String get callPeerBusy => 'الطرف التاني في مكالمة تانية';

  @override
  String get callPeerHungUp => 'الطرف التاني قفل المكالمة';

  @override
  String get callProblem => 'حصلت مشكلة في المكالمة';

  @override
  String get callIceFailed => 'الاتصال فشل — اتأكدوا إنكم على نفس الشبكة';

  @override
  String get micDeniedForever =>
      'إذن الميكروفون مرفوض — فعّله من إعدادات التطبيق';

  @override
  String get micNeededCall => 'محتاجين إذن الميكروفون عشان المكالمة';

  @override
  String get camDeniedForever =>
      'إذن الكاميرا مرفوض — فعّله من إعدادات التطبيق';

  @override
  String get camNeededCall => 'محتاجين إذن الكاميرا عشان مكالمة الفيديو';

  @override
  String get callDropped => 'الاتصال قطع';

  @override
  String get chatEnded => 'المحادثة انتهت';

  @override
  String get micNeededRecord => 'محتاجين إذن الميكروفون عشان نسجّل';

  @override
  String get micStartFailed => 'معرفناش نشغّل الميكروفون';

  @override
  String get holdToRecord => 'اضغط على الميكروفون واستمر ضاغط عشان تسجّل';

  @override
  String get recordFailed => 'التسجيل مكملش — جرّب تاني';

  @override
  String get emojiNoRecents => 'الإيموجي اللي بتستخدمها هتظهر هنا';

  @override
  String get emojiSearch => 'دوّر على إيموجي (بالإنجليزي)';

  @override
  String get keyboard => 'الكيبورد';

  @override
  String get emoji => 'إيموجي';

  @override
  String get messageHint => 'رسالة';

  @override
  String get waitingConnection => 'مستني الاتصال...';

  @override
  String get attachments => 'مرفقات';

  @override
  String get photoHoldVideo => 'صورة (اضغط مطولاً للفيديو)';

  @override
  String get photo => 'صورة';

  @override
  String get delete => 'امسح';

  @override
  String get slideToCancel => 'اسحب للإلغاء';

  @override
  String get theOtherSide => 'الطرف التاني';

  @override
  String get forwarded => 'محوّلة';

  @override
  String get edited => 'معدّلة';

  @override
  String get you => 'انت';

  @override
  String compareSafety(Object name) {
    return 'قارن رمز الأمان مع $name';
  }

  @override
  String get compareSafetyHint =>
      'تأكيد إضافي (اختياري): لو نفس الرقم ظاهر على الموبايل التاني يبقى متأكدين ١٠٠٪ إن محدش في النص.';

  @override
  String get different => 'مختلف';

  @override
  String get matches => 'متطابق';

  @override
  String get attachDocument => 'مستند';

  @override
  String get attachCamera => 'كاميرا';

  @override
  String get attachGallery => 'المعرض';

  @override
  String get attachAudio => 'صوت';

  @override
  String get videoWifiOnlyHint =>
      'الفيديو متاح في دردشة الواي فاي / الهوت سبوت (البلوتوث أبطأ من كده).';

  @override
  String get video => 'فيديو';

  @override
  String get videoWifiOnly => 'الفيديو متاح في دردشة الواي فاي بس';

  @override
  String get cameraPermission =>
      'محتاجين إذن الكاميرا — فعّله من إعدادات التطبيق';

  @override
  String get cameraFailed => 'معرفناش نفتح الكاميرا';

  @override
  String get videoWifiOnlyPhotosSent =>
      'الفيديو متاح في دردشة الواي فاي بس — اتبعتت الصور بس';

  @override
  String get videoCompressFailed => 'معرفناش نضغط الفيديو — هيتبعت زي ما هو';

  @override
  String get preparingVideo => 'بنجهّز الفيديو';

  @override
  String get preparingVideoBody =>
      'بنصغّره عشان يشتغل على أي موبايل ويتبعت أسرع.';

  @override
  String get filesFailed => 'معرفناش نفتح الملفات';

  @override
  String fileTooBig(Object size) {
    return 'الملف أكبر من $size';
  }

  @override
  String get readFileFailed => 'معرفناش نقرا الملف';

  @override
  String get sendFailedRetry => 'موصلش — ابعته تاني';

  @override
  String get fileIncomplete => 'الملف موصلش كامل';

  @override
  String get file => 'ملف';

  @override
  String waitingReconnectPct(Object pct) {
    return 'مستني الاتصال يرجع... $pct%';
  }

  @override
  String pctOfSize(Object pct, Object size) {
    return '$pct% من $size';
  }

  @override
  String waitingConnectionPct(Object pct) {
    return 'مستني الاتصال... $pct%';
  }

  @override
  String get cancelSending => 'إلغاء الإرسال';

  @override
  String get cancelReceiving => 'إلغاء الاستلام';

  @override
  String get saveToDownloads => 'حفظ في التنزيلات';

  @override
  String get noAppToOpen =>
      'مفيش تطبيق على الموبايل يفتح النوع ده — احفظه أو شاركه';

  @override
  String get storagePermission => 'محتاجين إذن التخزين عشان نحفظ الملف';

  @override
  String get savedToDownloads => 'اتحفظ في التنزيلات ← Wasl';

  @override
  String get saveFileFailed => 'معرفناش نحفظ الملف';

  @override
  String get tapToOpen => 'اضغط عشان تفتحه';

  @override
  String get photosPermission => 'محتاجين إذن الوصول للصور';

  @override
  String get savedToGallery => 'اتحفظ في المعرض';

  @override
  String get openWithOtherApp => 'افتح بتطبيق تاني';

  @override
  String get saveToGallery => 'حفظ في المعرض';

  @override
  String get share => 'مشاركة';

  @override
  String get videoCantPlay =>
      'الفيديو وصل سليم، بس المشغّل اللي جوه التطبيق مش قادر يشغّل النوع ده.';

  @override
  String get saveItToGallery => 'احفظه في المعرض';

  @override
  String get groupNobodyReachable => 'مفيش حد من الجروب واصلين له دلوقتي';

  @override
  String get videoWifiOnlyShort => 'الفيديو متاح في الواي فاي بس';

  @override
  String get fileEmpty => 'الملف فاضي';

  @override
  String get notAValidVideo => 'الملف ده مش فيديو سليم — اختاره تاني من المعرض';

  @override
  String groupMaxSize(Object size) {
    return 'أقصى حجم في الجروبات $size';
  }

  @override
  String get sendFileFailed => 'معرفناش نبعت الملف';

  @override
  String get connectionStoppedEarly => 'الاتصال وقف قبل ما يكمل';

  @override
  String memberJoined(Object name) {
    return '$name دخل الجروب';
  }

  @override
  String memberLeft(Object name) {
    return '$name خرج من الجروب';
  }

  @override
  String get arrivedIncomplete => 'وصل ناقص';

  @override
  String get arrivedCorrupt => 'وصل مختلف عن الأصلي';

  @override
  String get sendingStoppedEarly => 'الإرسال وقف قبل ما يكمل';

  @override
  String joinAccepted(Object group) {
    return 'اتقبلت في \"$group\" 🎉';
  }

  @override
  String joinRejected(Object group) {
    return 'طلبك لدخول \"$group\" اترفض';
  }

  @override
  String get leaveTitle => 'تقفل الاتصال؟';

  @override
  String get leaveBodyUnsaved =>
      'هتبقى مش ظاهر للناس، والمحادثات اللي مش محفوظة هتتمسح.';

  @override
  String get leaveBody => 'هتبقى مش ظاهر للناس لحد ما تدخل تاني.';

  @override
  String get disconnect => 'اقفل';

  @override
  String get newChat => 'محادثة جديدة';

  @override
  String get newGroup => 'جروب جديد';

  @override
  String get tabChats => 'المحادثات';

  @override
  String get tabGroups => 'الجروبات';

  @override
  String get tabNearby => 'القريبين';

  @override
  String get back => 'رجوع';

  @override
  String get preparing => 'بنجهّز...';

  @override
  String get searchingPeople => 'بندوّر على ناس حواليك';

  @override
  String peopleNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شخص قريب',
      few: '$count أشخاص قريبين',
      two: '$count أشخاص قريبين',
      one: '$count شخص قريب',
    );
    return '$_temp0';
  }

  @override
  String get tryAgain => 'حاول تاني';

  @override
  String get openWifi => 'افتح الواي فاي';

  @override
  String get yesterday => 'أمس';

  @override
  String get unpin => 'إلغاء التثبيت';

  @override
  String get pin => 'تثبيت فوق';

  @override
  String get unmuteNotifications => 'إلغاء كتم الإشعارات';

  @override
  String get muteNotifications => 'كتم الإشعارات';

  @override
  String get unsaveChat => 'إلغاء حفظ المحادثة';

  @override
  String get saveChat => 'حفظ المحادثة على الموبايل';

  @override
  String get leaveGroup => 'الخروج من الجروب';

  @override
  String get deleteChat => 'حذف المحادثة';

  @override
  String get chatSavedToast => 'المحادثة بتتحفظ على الموبايل';

  @override
  String get chatUnsavedToast => 'المحادثة مبقتش بتتحفظ';

  @override
  String leaveGroupTitle(Object name) {
    return 'الخروج من \"$name\"؟';
  }

  @override
  String deleteChatTitle(Object name) {
    return 'حذف المحادثة مع $name؟';
  }

  @override
  String get messagesErasedBody => 'الرسايل هتتمسح من موبايلك.';

  @override
  String get leave => 'خروج';

  @override
  String get deleteAction => 'حذف';

  @override
  String get typing => 'بيكتب...';

  @override
  String nameTyping(Object name) {
    return '$name بيكتب...';
  }

  @override
  String groupOfMode(Object mode) {
    return 'جروب $mode';
  }

  @override
  String get tapToStart => 'اضغط وابدأ الكلام';

  @override
  String youPrefix(Object text) {
    return 'إنت: $text';
  }

  @override
  String get noChatsTitle => 'لسه مفيش محادثات';

  @override
  String get noChatsBody =>
      'اختار حد أو جروب من القريبين وابدأ الكلام. التشفير بيتعمل تلقائي من غير كلمة سر.';

  @override
  String get startNewChat => 'ابدأ محادثة جديدة';

  @override
  String get noGroupsTitle => 'مفيش جروبات حواليك';

  @override
  String get noGroupsBody =>
      'اعمل جروب عام لأي حد قريب، أو خاص بكلمة سر أو بموافقتك. الجروب بيظهر للكل طول ما فيه عضو قريب.';

  @override
  String get createGroup => 'اعمل جروب';

  @override
  String get myGroups => 'جروباتي';

  @override
  String get groupsAround => 'جروبات حواليك';

  @override
  String groupsAroundCount(Object count) {
    return 'جروبات حواليك ($count)';
  }

  @override
  String membersNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أعضاء قريبين',
      one: '$count عضو قريب',
    );
    return '$_temp0';
  }

  @override
  String get waiting => 'مستني';

  @override
  String get requestJoin => 'اطلب';

  @override
  String get join => 'ادخل';

  @override
  String get ipFormat => 'اكتب العنوان بالشكل ده: 192.168.1.5';

  @override
  String get ipConnected => 'اتوصلنا — هيظهر في القايمة دلوقتي';

  @override
  String get searchWifiHint =>
      'أي حد فاتح Wasl على نفس الواي فاي (أو متوصل بالهوت سبوت بتاعك) هيظهر هنا لوحده.';

  @override
  String get searchBtHint =>
      'أي حد قريب فاتح Wasl على البلوتوث هيظهر هنا لوحده. البحث بياخد من ثواني لدقيقة.';

  @override
  String peopleTapToTalk(Object count) {
    return 'أشخاص — اضغط على أي حد عشان تكلمه ($count)';
  }

  @override
  String get meshHint =>
      'الأجهزة بتوصّل لبعض: ممكن تكلم حد بعيد عنك عن طريق موبايلات في النص، ومحدش منهم يقدر يقرا رسايلك.';

  @override
  String get connectByAddress => 'اتصال بالعنوان';

  @override
  String connectByAddressHint(Object addresses) {
    return 'لو الشبكة مانعة الاكتشاف التلقائي (زي بعض شبكات الكافيهات). عنوانك: $addresses';
  }

  @override
  String get listSeparator => ' ، ';

  @override
  String get otherDeviceAddress => 'عنوان الجهاز التاني';

  @override
  String get connect => 'اتصل';

  @override
  String get someoneMissing => 'حد مش ظاهر؟ اتصل بعنوانه';

  @override
  String get connectedDirectly => 'متصل بيك مباشرة';

  @override
  String viaRelays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أجهزة',
      two: 'جهازين',
      one: 'جهاز واحد',
    );
    return 'عن طريق $_temp0 في النص';
  }

  @override
  String get oneStepTitle => 'خطوة واحدة قبل ما نبدأ';

  @override
  String get oneStepBody =>
      'البلوتوث بيشتغل من غير إنترنت، وعشان الموبايلات تلاقي بعض محتاجين الحاجات دي:';

  @override
  String get permissionBlockedHint =>
      'الإذن ده اترفض قبل كده — فعّله من الإعدادات ← الأذونات.';

  @override
  String get modeOpen => 'عام';

  @override
  String get modePassword => 'بكلمة سر';

  @override
  String get modeAsk => 'بطلب انضمام';

  @override
  String get groupNameNeeded => 'اكتب اسم للجروب';

  @override
  String get passwordTooShort => 'كلمة السر 4 حروف على الأقل';

  @override
  String get createGroupFailed => 'معرفناش نعمل الجروب';

  @override
  String get modeOpenExplain => 'أي حد قريب يشوف الجروب ويدخل على طول.';

  @override
  String get modePasswordExplain =>
      'الجروب ظاهر، بس محدش يدخل ولا يقرا غير اللي معاه كلمة السر.';

  @override
  String get modeAskExplain => 'اللي عايز يدخل يبعتلك طلب، وإنت توافق أو ترفض.';

  @override
  String get groupName => 'اسم الجروب';

  @override
  String get groupPassword => 'كلمة سر الجروب';

  @override
  String get createGroupButton => 'إنشاء الجروب';

  @override
  String get joinGroupFailed => 'معرفناش ندخل الجروب';

  @override
  String get requestPendingTitle => 'الطلب لسه مستني';

  @override
  String get requestPendingBody => 'صاحب الجروب لسه مردّش على طلبك.';

  @override
  String get cancelRequest => 'إلغاء الطلب';

  @override
  String get keepWaiting => 'هستنى';

  @override
  String requestJoinTitle(Object name) {
    return 'طلب انضمام لـ \"$name\"';
  }

  @override
  String get requestJoinBody =>
      'هنبعت طلب لصاحب الجروب، وأول ما يوافق هتدخل تلقائياً.';

  @override
  String get sendRequest => 'ابعت الطلب';

  @override
  String get requestSent => 'الطلب اتبعت — مستنيين الموافقة';

  @override
  String get privateGroupPassword =>
      'الجروب ده خاص — اكتب كلمة السر عشان تدخل.';

  @override
  String get password => 'كلمة السر';

  @override
  String get enter => 'دخول';

  @override
  String get roleOwner => 'صاحب الجروب';

  @override
  String get roleAdmin => 'مدير';

  @override
  String get member => 'عضو';

  @override
  String get onlineNow => 'متصل دلوقتي';

  @override
  String get privateMessage => 'رسالة خاصة';

  @override
  String get privateMessageSub => 'مشفّرة بينكم انتوا الاتنين بس';

  @override
  String get voiceCall => 'مكالمة صوتية';

  @override
  String get mention => 'منشن';

  @override
  String get removeAdmin => 'شيله من الإدارة';

  @override
  String get makeAdmin => 'خليه مدير';

  @override
  String get removeFromGroup => 'شيله من الجروب';

  @override
  String get unban => 'رجّعه للجروب';

  @override
  String get block => 'حظر';

  @override
  String get blockSub => 'مش هتشوف رسايله في أي مكان';

  @override
  String kickTitle(Object name) {
    return 'تشيل $name من الجروب؟';
  }

  @override
  String get kickAsk =>
      'مفتاح الجروب هيتغير، فمش هيقدر يقرا أي رسالة جديدة ولا يدخل تاني غير بموافقة.';

  @override
  String get kickPassword =>
      'رسايله مش هتظهر لحد ومش هيقدر يبعت. بس هو لسه عارف كلمة السر — لو عايز تمنعه يقرا خالص اعمل جروب جديد بكلمة تانية.';

  @override
  String get kickOpen =>
      'رسايله مش هتظهر لحد ومش هيقدر يبعت. الجروب العام أي حد قريب يقدر يقراه.';

  @override
  String get kickConfirm => 'شيله';

  @override
  String kicked(Object name) {
    return '$name اتشال من الجروب';
  }

  @override
  String unbanned(Object name) {
    return '$name يقدر يدخل الجروب تاني';
  }

  @override
  String blockTitle(Object name) {
    return 'حظر $name؟';
  }

  @override
  String get blockBody =>
      'مش هيقدر يبعتلك رسايل ولا هتشوف رسايله في الجروبات. تقدر تلغي الحظر من الإعدادات.';

  @override
  String get groupInfo => 'معلومات الجروب';

  @override
  String get notInGroup => 'مبقتش في الجروب ده';

  @override
  String get rename => 'تغيير الاسم';

  @override
  String get youOwnIt => 'إنت صاحبه';

  @override
  String ownedBy(Object name) {
    return 'صاحبه $name';
  }

  @override
  String joinRequests(Object count) {
    return 'طلبات انضمام ($count)';
  }

  @override
  String get removedBefore => 'اتشال من الجروب قبل كده';

  @override
  String onlineCount(Object count) {
    return 'متصلين دلوقتي ($count)';
  }

  @override
  String get youName => 'إنت';

  @override
  String get ownerHint =>
      'اضغط على أي عضو: رسالة خاصة، تخليه مدير، أو تشيله من الجروب. إنت صاحب الجروب ومحدش يقدر يشيلك.';

  @override
  String get adminHint =>
      'إنت مدير: تقدر تشيل الأعضاء، تمسح رسايلهم، وتغيّر اسم الجروب.';

  @override
  String get memberHint =>
      'اضغط على أي عضو عشان تكلمه شات خاص — مشفّر بينكم انتوا الاتنين بس، حتى باقي الجروب مش بيشوفه.';

  @override
  String bannedCount(Object count) {
    return 'اتشالوا من الجروب ($count)';
  }

  @override
  String get letBack => 'رجّعه';

  @override
  String get groupMessagesErased => 'رسايل الجروب هتتمسح من موبايلك.';

  @override
  String get callStartNow => 'معرفناش نبدأ المكالمة دلوقتي';

  @override
  String get messageGone => 'الرسالة دي مبقتش موجودة';

  @override
  String get noForwardTarget => 'مفيش محادثة متصلة دلوقتي تحوّل ليها';

  @override
  String get forwardTo => 'تحويل لـ';

  @override
  String get group => 'جروب';

  @override
  String get privateChat => 'محادثة خاصة';

  @override
  String forwardedTo(Object name) {
    return 'اتحوّلت لـ $name';
  }

  @override
  String get statusSending => 'بتتبعت...';

  @override
  String get statusSentGroup => 'اتبعتت';

  @override
  String get statusSent => 'اتبعتت ولسه موصلتش';

  @override
  String get statusDeliveredGroup => 'حد قراها';

  @override
  String get statusDelivered => 'وصلت';

  @override
  String get statusReadGroup => 'كل المتصلين قروها';

  @override
  String get statusRead => 'اتقرت';

  @override
  String get statusFailed => 'متبعتتش';

  @override
  String get messageInfo => 'معلومات الرسالة';

  @override
  String readByCount(Object count) {
    return 'قروها ($count)';
  }

  @override
  String get nobodyYet => 'لسه محدش';

  @override
  String onlineNotReadCount(Object count) {
    return 'متصلين ولسه مقروهاش ($count)';
  }

  @override
  String get codeMismatchTitle => 'الرمز مختلف؟';

  @override
  String get codeMismatchBody =>
      'ده معناه إن ممكن حد منتحل شخصية الطرف التاني. متبعتش حاجة حساسة، واحظره من القايمة لو مش متأكد منه.';

  @override
  String get unsaveChatTitle => 'إلغاء حفظ المحادثة؟';

  @override
  String get unsaveChatBody =>
      'الرسايل هتتمسح من تخزين الموبايل، وهتفضل قدامك لحد ما تقفل التطبيق بس.';

  @override
  String get unsaveConfirm => 'إلغاء الحفظ';

  @override
  String get chatSavedEncryptedToast => 'المحادثة بتتحفظ على الموبايل (مشفّرة)';

  @override
  String get clearTitle => 'مسح الرسايل؟';

  @override
  String get clearBody => 'الرسايل هتتمسح من عندك بس.';

  @override
  String get clear => 'مسح';

  @override
  String get blockDirectBody =>
      'مش هيقدر يبعتلك رسايل ولا هيظهر في القريبين. تقدر تلغي الحظر من الإعدادات.';

  @override
  String get deleteChatQ => 'حذف المحادثة؟';

  @override
  String get deleteChatBody => 'المحادثة ورسايلها هتتمسح من موبايلك.';

  @override
  String get otherEmoji => 'إيموجي تاني';

  @override
  String get reply => 'رد';

  @override
  String get forward => 'تحويل';

  @override
  String get copy => 'نسخ';

  @override
  String privateMessageTo(Object name) {
    return 'رسالة خاصة لـ $name';
  }

  @override
  String mentionName(Object name) {
    return 'منشن لـ $name';
  }

  @override
  String get edit => 'تعديل';

  @override
  String get deleteForBoth => 'حذف عندي وعنده';

  @override
  String get deleteForAll => 'حذف عند الكل';

  @override
  String get deleteForAllAdmin => 'حذف عند الكل (إنت مدير)';

  @override
  String get deleteForMe => 'حذف عندي بس';

  @override
  String get editMessage => 'تعديل الرسالة';

  @override
  String typingOne(Object name) {
    return '$name بيكتب';
  }

  @override
  String typingTwo(Object a, Object b) {
    return '$a و$b بيكتبوا';
  }

  @override
  String typingMany(Object count) {
    return '$count بيكتبوا';
  }

  @override
  String get chatClosed => 'المحادثة اتقفلت';

  @override
  String get noMembersNearby => 'مفيش حد من الأعضاء قريب دلوقتي';

  @override
  String membersOnline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أعضاء متصلين دلوقتي',
      one: '$count عضو متصلين دلوقتي',
    );
    return '$_temp0';
  }

  @override
  String get blocked => 'محظور';

  @override
  String get encryptedVerified => 'مشفّرة • الرمز متأكد';

  @override
  String get securing => 'بنأمّن الاتصال...';

  @override
  String get connecting => 'جاري الاتصال...';

  @override
  String get videoCall => 'مكالمة فيديو';

  @override
  String get joinRequestsTooltip => 'طلبات انضمام';

  @override
  String get searchChat => 'بحث في المحادثة';

  @override
  String get membersAndInfo => 'الأعضاء ومعلومات الجروب';

  @override
  String get safetyCodeOptional => 'رمز الأمان (اختياري)';

  @override
  String get clearMessages => 'مسح الرسايل';

  @override
  String peerOfflineWifi(Object name) {
    return '$name مش على الشبكة دلوقتي. أول ما يفتح التطبيق على نفس الواي فاي هتقدر تكلمه.';
  }

  @override
  String peerOfflineBt(Object name) {
    return '$name مش قريب دلوقتي. أول ما يقرب ويفتح التطبيق هتقدر تكلمه.';
  }

  @override
  String get noDeviceNearby =>
      'مفيش أي جهاز قريب دلوقتي — الرسايل بتتبعت لما يبقى فيه حد واصلين له.';

  @override
  String get cancelSendingQ => 'إلغاء الإرسال؟';

  @override
  String get cancelReceivingQ => 'إلغاء الاستلام؟';

  @override
  String get cancelSendingBody =>
      'الملف هيتشال من المحادثة عندك وعند الطرف التاني.';

  @override
  String get cancelReceivingBody => 'الملف هيتشال من عندك ومش هيكمّل.';

  @override
  String get cancelTransfer => 'إلغاء النقل';

  @override
  String get notificationsBack => 'الإشعارات رجعت للمحادثة دي';

  @override
  String get muteHour => 'ساعة';

  @override
  String get mute8Hours => '8 ساعات';

  @override
  String get muteWeek => 'أسبوع';

  @override
  String get muteAlways => 'دايماً';

  @override
  String get mutedGroupToast => 'اتكتم — المنشن بس هو اللي هيبعتلك إشعار';

  @override
  String get mutedToast => 'إشعارات المحادثة دي اتكتمت';

  @override
  String get closeSearch => 'قفل البحث';

  @override
  String get searchInChat => 'دوّر في المحادثة';

  @override
  String get none => 'مفيش';

  @override
  String get older => 'الأقدم';

  @override
  String get newer => 'الأحدث';

  @override
  String get startGroupTalk => 'ابدأ الكلام في الجروب';

  @override
  String get sayHello => 'قول أهلاً 👋';

  @override
  String get emptyGroupEnc =>
      'رسايل الجروب مشفّرة بمفتاحه ومبتعدّيش على أي سيرفر.';

  @override
  String get emptyDirectEnc =>
      'الرسايل مشفّرة من طرف لطرف تلقائياً — من غير كلمة سر ومن غير إنترنت.';

  @override
  String get emptySaved => 'المحادثة دي بتتحفظ على موبايلك.';

  @override
  String get emptyNotSaved => 'المحادثة دي مش بتتحفظ: هتتمسح لما تقفل التطبيق.';

  @override
  String get notFinished => 'مكملش';

  @override
  String get chatEncryptedSystem => 'المحادثة مشفرة من طرف لطرف 🔒';

  @override
  String get safetyVerifiedSystem => 'تم التحقق من رمز الأمان ✓';

  @override
  String get previewPhoto => '📷 صورة';

  @override
  String get previewVideo => '🎥 فيديو';

  @override
  String get previewVoice => '🎤 رسالة صوتية';

  @override
  String previewFile(Object name) {
    return '📄 $name';
  }

  @override
  String sizeGb(Object n) {
    return '$n جيجا';
  }

  @override
  String sizeMb(Object n) {
    return '$n ميجا';
  }

  @override
  String get readFileFromPhoneFailed => 'معرفناش نقرا الملف من الموبايل';

  @override
  String get peerGotCorrupt => 'وصل بايظ عند التاني — ابعته تاني';

  @override
  String get peerCanceledReceive => 'التاني لغى الاستلام';

  @override
  String get personNearby => 'شخص قريب';

  @override
  String get groupCreatedOpen => 'الجروب اتعمل — أي حد قريب يقدر يدخل';

  @override
  String get groupCreatedPassword => 'الجروب اتعمل — الدخول بكلمة السر';

  @override
  String get groupCreatedAsk => 'الجروب اتعمل — الدخول بموافقتك';

  @override
  String get networkNotRunning => 'الشبكة مش شغالة';

  @override
  String get wrongPassword => 'كلمة السر غلط';

  @override
  String get groupNeedsApproval => 'الجروب ده محتاج موافقة صاحبه';

  @override
  String get ownerOffline => 'صاحب الجروب مش متصل دلوقتي — جرّب لما يكون قريب';

  @override
  String get sendRequestFailed => 'معرفناش نبعت الطلب';

  @override
  String get notAllowed => 'مش من صلاحياتك';

  @override
  String get noConnectionNow => 'مفيش اتصال دلوقتي';

  @override
  String youKicked(Object name) {
    return 'شلت $name من الجروب';
  }

  @override
  String get ownerOnly => 'صاحب الجروب بس اللي يقدر يعمل كده';

  @override
  String get maxAdmins => 'وصلت لأقصى عدد مديرين';

  @override
  String youMadeAdmin(Object name) {
    return 'خليت $name مدير';
  }

  @override
  String youRemovedAdmin(Object name) {
    return 'شلت $name من الإدارة';
  }

  @override
  String get adminsOnlyRename => 'المديرين بس اللي يقدروا يغيّروا الاسم';

  @override
  String youRenamed(Object name) {
    return 'غيّرت اسم الجروب لـ \"$name\"';
  }

  @override
  String removedFromGroupNotice(Object name) {
    return 'اتشلت من جروب \"$name\"';
  }

  @override
  String byKicked(Object by, Object who) {
    return '$by شال $who من الجروب';
  }

  @override
  String get youBecameAdmin => 'بقيت مدير في الجروب';

  @override
  String becameAdmin(Object name) {
    return '$name بقى مدير';
  }

  @override
  String get youNoLongerAdmin => 'مبقتش مدير في الجروب';

  @override
  String noLongerAdmin(Object name) {
    return '$name مبقاش مدير';
  }

  @override
  String byRenamed(Object by, Object name) {
    return '$by غيّر اسم الجروب لـ \"$name\"';
  }

  @override
  String mentionedYou(Object text) {
    return 'منشن ليك: $text';
  }

  @override
  String reactedOn(Object emoji, Object text) {
    return 'تفاعل بـ $emoji على: \"$text\"';
  }
}
