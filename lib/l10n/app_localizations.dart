import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In ar, this message translates to:
  /// **'حسناً'**
  String get ok;

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// No description provided for @stopSavingTitle.
  ///
  /// In ar, this message translates to:
  /// **'توقف حفظ المحادثات؟'**
  String get stopSavingTitle;

  /// No description provided for @stopSavingBody.
  ///
  /// In ar, this message translates to:
  /// **'المحادثات المحفوظة هتتمسح من تخزين الموبايل (ما عدا اللي اخترت تحفظها بنفسك من جوه المحادثة).'**
  String get stopSavingBody;

  /// No description provided for @stopSavingConfirm.
  ///
  /// In ar, this message translates to:
  /// **'وقّف الحفظ'**
  String get stopSavingConfirm;

  /// No description provided for @savingOnToast.
  ///
  /// In ar, this message translates to:
  /// **'المحادثات هتتحفظ على الموبايل (مشفّرة)'**
  String get savingOnToast;

  /// No description provided for @savingOffToast.
  ///
  /// In ar, this message translates to:
  /// **'المحادثات مش هتتحفظ'**
  String get savingOffToast;

  /// No description provided for @lockOnToast.
  ///
  /// In ar, this message translates to:
  /// **'القفل اتفعّل'**
  String get lockOnToast;

  /// No description provided for @lockOffToast.
  ///
  /// In ar, this message translates to:
  /// **'القفل اتشال'**
  String get lockOffToast;

  /// No description provided for @bioConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد البصمة'**
  String get bioConfirmTitle;

  /// No description provided for @bioConfirmSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'عشان تفتح Wasl بيها'**
  String get bioConfirmSubtitle;

  /// No description provided for @wipeTitle.
  ///
  /// In ar, this message translates to:
  /// **'مسح كل المحادثات؟'**
  String get wipeTitle;

  /// No description provided for @wipeBody.
  ///
  /// In ar, this message translates to:
  /// **'كل الرسايل والملفات المحفوظة هتتمسح من موبايلك نهائياً. بروفايلك والجروبات اللي إنت فيها هيفضلوا.'**
  String get wipeBody;

  /// No description provided for @wipeConfirm.
  ///
  /// In ar, this message translates to:
  /// **'امسح الكل'**
  String get wipeConfirm;

  /// No description provided for @wipeDone.
  ///
  /// In ar, this message translates to:
  /// **'اتمسح كل حاجة'**
  String get wipeDone;

  /// No description provided for @blockedTitle.
  ///
  /// In ar, this message translates to:
  /// **'المحظورين'**
  String get blockedTitle;

  /// No description provided for @blockedEmpty.
  ///
  /// In ar, this message translates to:
  /// **'مفيش حد محظور.'**
  String get blockedEmpty;

  /// No description provided for @blockedNone.
  ///
  /// In ar, this message translates to:
  /// **'مفيش حد'**
  String get blockedNone;

  /// No description provided for @personShort.
  ///
  /// In ar, this message translates to:
  /// **'شخص ({id})'**
  String personShort(Object id);

  /// No description provided for @unblock.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الحظر'**
  String get unblock;

  /// No description provided for @editProfileHint.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الاسم والصورة واللون'**
  String get editProfileHint;

  /// No description provided for @privacy.
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية'**
  String get privacy;

  /// No description provided for @saveChats.
  ///
  /// In ar, this message translates to:
  /// **'حفظ المحادثات على الموبايل'**
  String get saveChats;

  /// No description provided for @saveChatsOn.
  ///
  /// In ar, this message translates to:
  /// **'الرسايل بتتحفظ مشفّرة وبتلاقيها لما تفتح التطبيق تاني.'**
  String get saveChatsOn;

  /// No description provided for @saveChatsOff.
  ///
  /// In ar, this message translates to:
  /// **'مقفول: المحادثات بتتمسح لما تقفل التطبيق. تقدر تحفظ محادثة معينة من جواها.'**
  String get saveChatsOff;

  /// No description provided for @appLock.
  ///
  /// In ar, this message translates to:
  /// **'قفل التطبيق برقم سري'**
  String get appLock;

  /// No description provided for @appLockOn.
  ///
  /// In ar, this message translates to:
  /// **'متفعّل — اضغط عشان تشيله'**
  String get appLockOn;

  /// No description provided for @appLockOff.
  ///
  /// In ar, this message translates to:
  /// **'اختياري. من غيره التطبيق بيفتح على طول.'**
  String get appLockOff;

  /// No description provided for @unlockWithFingerprint.
  ///
  /// In ar, this message translates to:
  /// **'فتح بالبصمة'**
  String get unlockWithFingerprint;

  /// No description provided for @autoLock.
  ///
  /// In ar, this message translates to:
  /// **'القفل التلقائي'**
  String get autoLock;

  /// No description provided for @autoLockSub.
  ///
  /// In ar, this message translates to:
  /// **'بعد ما تسيب التطبيق'**
  String get autoLockSub;

  /// No description provided for @lockNow.
  ///
  /// In ar, this message translates to:
  /// **'على طول'**
  String get lockNow;

  /// No description provided for @lockMinute.
  ///
  /// In ar, this message translates to:
  /// **'دقيقة'**
  String get lockMinute;

  /// No description provided for @lock5.
  ///
  /// In ar, this message translates to:
  /// **'5 دقايق'**
  String get lock5;

  /// No description provided for @lock15.
  ///
  /// In ar, this message translates to:
  /// **'15 دقيقة'**
  String get lock15;

  /// No description provided for @wipeAll.
  ///
  /// In ar, this message translates to:
  /// **'مسح كل المحادثات'**
  String get wipeAll;

  /// No description provided for @appearance.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get appearance;

  /// No description provided for @themeAuto.
  ///
  /// In ar, this message translates to:
  /// **'تلقائي'**
  String get themeAuto;

  /// No description provided for @themeLight.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ar, this message translates to:
  /// **'غامق'**
  String get themeDark;

  /// No description provided for @appColor.
  ///
  /// In ar, this message translates to:
  /// **'لون التطبيق'**
  String get appColor;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @languageAuto.
  ///
  /// In ar, this message translates to:
  /// **'تلقائي'**
  String get languageAuto;

  /// No description provided for @languageAutoHint.
  ///
  /// In ar, this message translates to:
  /// **'تلقائي: زي لغة الموبايل (عربي لو الموبايل عربي، غير كده إنجليزي).'**
  String get languageAutoHint;

  /// No description provided for @about.
  ///
  /// In ar, this message translates to:
  /// **'عن التطبيق'**
  String get about;

  /// No description provided for @aboutTagline.
  ///
  /// In ar, this message translates to:
  /// **'شات من غير إنترنت • مفتوح المصدر ({license})'**
  String aboutTagline(Object license);

  /// No description provided for @sourceCode.
  ///
  /// In ar, this message translates to:
  /// **'الكود على GitHub'**
  String get sourceCode;

  /// No description provided for @linkCopied.
  ///
  /// In ar, this message translates to:
  /// **'اتنسخ اللينك'**
  String get linkCopied;

  /// No description provided for @noBrowser.
  ///
  /// In ar, this message translates to:
  /// **'مفيش متصفح يفتح اللينك — اتنسخ بداله'**
  String get noBrowser;

  /// No description provided for @howItWorks.
  ///
  /// In ar, this message translates to:
  /// **'إزاي Wasl بيشتغل؟'**
  String get howItWorks;

  /// No description provided for @howItWorksSub.
  ///
  /// In ar, this message translates to:
  /// **'من غير إنترنت ومن غير سيرفر'**
  String get howItWorksSub;

  /// No description provided for @howNoInternetTitle.
  ///
  /// In ar, this message translates to:
  /// **'من غير إنترنت ولا سيرفر'**
  String get howNoInternetTitle;

  /// No description provided for @howNoInternetBody.
  ///
  /// In ar, this message translates to:
  /// **'الموبايلات بتكلم بعض مباشرة بالبلوتوث أو على نفس الواي فاي / الهوت سبوت. مفيش حساب ولا رقم موبايل.'**
  String get howNoInternetBody;

  /// No description provided for @howMeshTitle.
  ///
  /// In ar, this message translates to:
  /// **'شبكة Mesh'**
  String get howMeshTitle;

  /// No description provided for @howMeshBody.
  ///
  /// In ar, this message translates to:
  /// **'كل موبايل عليه Wasl بيوصّل للي حواليه، فرسالتك تقدر تعدّي على كذا موبايل لحد ما توصل لحد بعيد عنك.'**
  String get howMeshBody;

  /// No description provided for @howEncryptionTitle.
  ///
  /// In ar, this message translates to:
  /// **'تشفير تلقائي'**
  String get howEncryptionTitle;

  /// No description provided for @howEncryptionBody.
  ///
  /// In ar, this message translates to:
  /// **'الشات الخاص مشفّر من طرف لطرف بمفاتيح بتتولّد لوحدها — من غير كلمة سر. الموبايلات اللي في النص بتوصّل بس ومبتقراش حاجة.'**
  String get howEncryptionBody;

  /// No description provided for @howBothTitle.
  ///
  /// In ar, this message translates to:
  /// **'الاتنين مع بعض'**
  String get howBothTitle;

  /// No description provided for @howBothBody.
  ///
  /// In ar, this message translates to:
  /// **'لو شغّلت الواي فاي والبلوتوث سوا موبايلك بيبقى كوبري: اللي على هوت سبوت يوصل للي على هوت سبوت تاني عن طريق البلوتوث. المكالمات والفيديو بيفضلوا جوه نفس الشبكة.'**
  String get howBothBody;

  /// No description provided for @howGroupsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الجروبات'**
  String get howGroupsTitle;

  /// No description provided for @howGroupsBody.
  ///
  /// In ar, this message translates to:
  /// **'عام: أي حد قريب يدخل ويقرا. بكلمة سر أو بطلب انضمام: محدش يقرا غير الأعضاء. الجروب بيفضل ظاهر طول ما فيه عضو قريب.'**
  String get howGroupsBody;

  /// No description provided for @howAdminTitle.
  ///
  /// In ar, this message translates to:
  /// **'إدارة الجروب'**
  String get howAdminTitle;

  /// No description provided for @howAdminBody.
  ///
  /// In ar, this message translates to:
  /// **'صاحب الجروب بيعيّن مديرين، والمدير يشيل أعضاء ويمسح رسايلهم. في جروب \"بطلب انضمام\" المفتاح بيتغير لما حد يتشال فمبيقراش الجديد؛ في العام وبكلمة السر الإزالة حظر بتطبّقه التطبيقات.'**
  String get howAdminBody;

  /// No description provided for @howNotifTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get howNotifTitle;

  /// No description provided for @howNotifBody.
  ///
  /// In ar, this message translates to:
  /// **'الإشعار فيه اسم اللي بعت ونص الرسالة. لو مفعّل قفل التطبيق بيبقى \"رسالة جديدة\" بس، وعلى شاشة قفل الموبايل النص مبيظهرش أبداً. تقدر تكتم أي محادثة.'**
  String get howNotifBody;

  /// No description provided for @howSaveTitle.
  ///
  /// In ar, this message translates to:
  /// **'الحفظ اختياري'**
  String get howSaveTitle;

  /// No description provided for @howSaveBody.
  ///
  /// In ar, this message translates to:
  /// **'الافتراضي إن المحادثات مبتتحفظش وبتتمسح مع قفل التطبيق. لو فعّلت الحفظ بتتخزن مشفّرة على موبايلك بس.'**
  String get howSaveBody;

  /// No description provided for @howSafetyTitle.
  ///
  /// In ar, this message translates to:
  /// **'رمز الأمان'**
  String get howSafetyTitle;

  /// No description provided for @howSafetyBody.
  ///
  /// In ar, this message translates to:
  /// **'لو عايز تتأكد 100% إنك بتكلم الشخص الصح، قارنوا رمز الأمان (6 أرقام) من قايمة المحادثة. اختياري.'**
  String get howSafetyBody;

  /// No description provided for @pinWrong.
  ///
  /// In ar, this message translates to:
  /// **'الرقم غلط'**
  String get pinWrong;

  /// No description provided for @pinMismatch.
  ///
  /// In ar, this message translates to:
  /// **'الرقمين مش زي بعض — ابدأ تاني'**
  String get pinMismatch;

  /// No description provided for @pinEnterCurrent.
  ///
  /// In ar, this message translates to:
  /// **'اكتب الرقم السري الحالي'**
  String get pinEnterCurrent;

  /// No description provided for @pinChoose.
  ///
  /// In ar, this message translates to:
  /// **'اختار رقم سري (4 لـ 8 أرقام)'**
  String get pinChoose;

  /// No description provided for @pinRepeat.
  ///
  /// In ar, this message translates to:
  /// **'اكتبه تاني للتأكيد'**
  String get pinRepeat;

  /// No description provided for @colorIndigo.
  ///
  /// In ar, this message translates to:
  /// **'نيلي'**
  String get colorIndigo;

  /// No description provided for @colorTeal.
  ///
  /// In ar, this message translates to:
  /// **'فيروزي'**
  String get colorTeal;

  /// No description provided for @colorEmerald.
  ///
  /// In ar, this message translates to:
  /// **'أخضر'**
  String get colorEmerald;

  /// No description provided for @colorCoral.
  ///
  /// In ar, this message translates to:
  /// **'مرجاني'**
  String get colorCoral;

  /// No description provided for @colorAmber.
  ///
  /// In ar, this message translates to:
  /// **'كهرماني'**
  String get colorAmber;

  /// No description provided for @colorSky.
  ///
  /// In ar, this message translates to:
  /// **'سماوي'**
  String get colorSky;

  /// No description provided for @colorPink.
  ///
  /// In ar, this message translates to:
  /// **'وردي'**
  String get colorPink;

  /// No description provided for @colorGraphite.
  ///
  /// In ar, this message translates to:
  /// **'رمادي'**
  String get colorGraphite;

  /// No description provided for @errRejectedTitle.
  ///
  /// In ar, this message translates to:
  /// **'الطرف التاني رفض الاتصال'**
  String get errRejectedTitle;

  /// No description provided for @errRejectedHint.
  ///
  /// In ar, this message translates to:
  /// **'اطلب منه يقبل الطلب لما يظهر عنده، وجرّب تاني.'**
  String get errRejectedHint;

  /// No description provided for @errPeerGoneTitle.
  ///
  /// In ar, this message translates to:
  /// **'الجهاز التاني مش ظاهر دلوقتي'**
  String get errPeerGoneTitle;

  /// No description provided for @errPeerGoneHint.
  ///
  /// In ar, this message translates to:
  /// **'اتأكد إنه لسه فاتح شاشة الدردشة وقريب منك (أقل من 10 متر تقريباً).'**
  String get errPeerGoneHint;

  /// No description provided for @errReconnectTitle.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نرجّع الاتصال'**
  String get errReconnectTitle;

  /// No description provided for @errReconnectHint.
  ///
  /// In ar, this message translates to:
  /// **'غالباً الجهاز التاني بعد أو قفل الشاشة. افتحوا الدردشة على الجهازين وابدأوا تاني.'**
  String get errReconnectHint;

  /// No description provided for @errNoNetworkTitle.
  ///
  /// In ar, this message translates to:
  /// **'مش متوصل بأي شبكة'**
  String get errNoNetworkTitle;

  /// No description provided for @errNoNetworkHint.
  ///
  /// In ar, this message translates to:
  /// **'شغّل الواي فاي واتوصل بشبكة، أو افتح نقطة اتصال (Hotspot) من الإعدادات وخلّي التاني يتوصل بيها.'**
  String get errNoNetworkHint;

  /// No description provided for @errHandshakeTitle.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نأمّن الاتصال'**
  String get errHandshakeTitle;

  /// No description provided for @errHandshakeHint.
  ///
  /// In ar, this message translates to:
  /// **'حصل خطأ أثناء تبادل مفاتيح التشفير. تأكد إن الجهازين عليهم آخر نسخة من Wasl وجرّب تاني.'**
  String get errHandshakeHint;

  /// No description provided for @errNoPlayTitle.
  ///
  /// In ar, this message translates to:
  /// **'الدردشة القريبة محتاجة خدمات Google Play'**
  String get errNoPlayTitle;

  /// No description provided for @errNoPlayHint.
  ///
  /// In ar, this message translates to:
  /// **'الجهاز ده مفيهوش خدمات Google أو محتاجة تحديث. حدّث \"خدمات Google Play\" من المتجر، أو استخدم الدردشة عبر الواي فاي.'**
  String get errNoPlayHint;

  /// No description provided for @errPermissionTitle.
  ///
  /// In ar, this message translates to:
  /// **'ناقص إذن'**
  String get errPermissionTitle;

  /// No description provided for @errPermissionHint.
  ///
  /// In ar, this message translates to:
  /// **'التطبيق محتاج إذن \"الأجهزة القريبة\" عشان يلاقي الجهاز التاني. اسمح بيه وجرّب تاني.'**
  String get errPermissionHint;

  /// No description provided for @errRadioTitle.
  ///
  /// In ar, this message translates to:
  /// **'البلوتوث أو الواي فاي مش مستجيب'**
  String get errRadioTitle;

  /// No description provided for @errRadioHint.
  ///
  /// In ar, this message translates to:
  /// **'اقفل البلوتوث وافتحه تاني (ولو ينفع الواي فاي كمان)، وبعدين جرّب. لو المشكلة استمرت اعمل ريستارت للموبايل.'**
  String get errRadioHint;

  /// No description provided for @errAlreadyConnectedTitle.
  ///
  /// In ar, this message translates to:
  /// **'فيه اتصال قديم لسه مفتوح'**
  String get errAlreadyConnectedTitle;

  /// No description provided for @errAlreadyConnectedHint.
  ///
  /// In ar, this message translates to:
  /// **'اقفل شاشة الدردشة على الجهازين وافتحها تاني.'**
  String get errAlreadyConnectedHint;

  /// No description provided for @errTimeoutTitle.
  ///
  /// In ar, this message translates to:
  /// **'الاتصال أخد وقت أطول من اللازم'**
  String get errTimeoutTitle;

  /// No description provided for @errTimeoutHint.
  ///
  /// In ar, this message translates to:
  /// **'قرّب الجهازين من بعض وجرّب تاني.'**
  String get errTimeoutHint;

  /// No description provided for @errGenericTitle.
  ///
  /// In ar, this message translates to:
  /// **'حصلت مشكلة في الاتصال'**
  String get errGenericTitle;

  /// No description provided for @errGenericHint.
  ///
  /// In ar, this message translates to:
  /// **'جرّب تقفل الدردشة وتفتحها تاني على الجهازين. لو المشكلة فضلت، اقفل البلوتوث وافتحه.'**
  String get errGenericHint;

  /// No description provided for @errRefusedTitle.
  ///
  /// In ar, this message translates to:
  /// **'الجهاز التاني مش مستني اتصال'**
  String get errRefusedTitle;

  /// No description provided for @errRefusedHint.
  ///
  /// In ar, this message translates to:
  /// **'اتأكد إنه داس \"استضافة\" وإن العنوان مكتوب صح.'**
  String get errRefusedHint;

  /// No description provided for @errNoReplyTitle.
  ///
  /// In ar, this message translates to:
  /// **'مفيش رد من العنوان ده'**
  String get errNoReplyTitle;

  /// No description provided for @errNoReplyHint.
  ///
  /// In ar, this message translates to:
  /// **'الجهازين لازم يكونوا على نفس شبكة الواي فاي (أو واحد فاتح Hotspot والتاني متوصل بيه). بعض الراوترات العامة بتمنع الأجهزة تكلم بعض.'**
  String get errNoReplyHint;

  /// No description provided for @errUnreachableTitle.
  ///
  /// In ar, this message translates to:
  /// **'مش متوصل بشبكة'**
  String get errUnreachableTitle;

  /// No description provided for @errUnreachableHint.
  ///
  /// In ar, this message translates to:
  /// **'شغّل الواي فاي واتوصل بنفس الشبكة اللي عليها الجهاز التاني.'**
  String get errUnreachableHint;

  /// No description provided for @errFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال'**
  String get errFailedTitle;

  /// No description provided for @errFailedHint.
  ///
  /// In ar, this message translates to:
  /// **'اتأكد من العنوان وإن الجهازين على نفس الشبكة.'**
  String get errFailedHint;

  /// No description provided for @errLanStartTitle.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نبدأ على الشبكة'**
  String get errLanStartTitle;

  /// No description provided for @errLanStartHint.
  ///
  /// In ar, this message translates to:
  /// **'اقفل التطبيق وافتحه تاني. لو المشكلة فضلت اعمل ريستارت للواي فاي.'**
  String get errLanStartHint;

  /// No description provided for @copiedSecure.
  ///
  /// In ar, this message translates to:
  /// **'تم النسخ — هيتمسح من الحافظة بعد 30 ثانية'**
  String get copiedSecure;

  /// No description provided for @notDelivered.
  ///
  /// In ar, this message translates to:
  /// **'موصلتش'**
  String get notDelivered;

  /// No description provided for @lockBioTitle.
  ///
  /// In ar, this message translates to:
  /// **'افتح Wasl'**
  String get lockBioTitle;

  /// No description provided for @lockBioSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'بصمتك بدل الرقم السري'**
  String get lockBioSubtitle;

  /// No description provided for @lockIncomingCall.
  ///
  /// In ar, this message translates to:
  /// **'مكالمة واردة — افتح القفل'**
  String get lockIncomingCall;

  /// No description provided for @lockEnterPin.
  ///
  /// In ar, this message translates to:
  /// **'اكتب الرقم السري'**
  String get lockEnterPin;

  /// No description provided for @lockWrongPin.
  ///
  /// In ar, this message translates to:
  /// **'الرقم غلط — جرّب تاني'**
  String get lockWrongPin;

  /// No description provided for @unknownName.
  ///
  /// In ar, this message translates to:
  /// **'مجهول'**
  String get unknownName;

  /// No description provided for @otherSide.
  ///
  /// In ar, this message translates to:
  /// **'الطرف الآخر'**
  String get otherSide;

  /// No description provided for @hello.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً'**
  String get hello;

  /// No description provided for @transportHeadline.
  ///
  /// In ar, this message translates to:
  /// **'هتتكلم\nإزاي النهارده؟'**
  String get transportHeadline;

  /// No description provided for @transportSub.
  ///
  /// In ar, this message translates to:
  /// **'من غير إنترنت في الحالتين، وكل حاجة مشفّرة.'**
  String get transportSub;

  /// No description provided for @bluetooth.
  ///
  /// In ar, this message translates to:
  /// **'بلوتوث'**
  String get bluetooth;

  /// No description provided for @bluetoothDesc.
  ///
  /// In ar, this message translates to:
  /// **'للناس القريبة منك من غير أي شبكة. الرسايل بتعدّي من موبايل لموبايل فبتوصل لأبعد.'**
  String get bluetoothDesc;

  /// No description provided for @tagNoNetwork.
  ///
  /// In ar, this message translates to:
  /// **'من غير شبكة'**
  String get tagNoNetwork;

  /// No description provided for @wifi.
  ///
  /// In ar, this message translates to:
  /// **'واي فاي'**
  String get wifi;

  /// No description provided for @wifiDesc.
  ///
  /// In ar, this message translates to:
  /// **'نفس الواي فاي أو هوت سبوت من موبايل. أسرع بكتير، وفيه فيديو ومكالمات صوت وصورة.'**
  String get wifiDesc;

  /// No description provided for @tagFaster.
  ///
  /// In ar, this message translates to:
  /// **'أسرع'**
  String get tagFaster;

  /// No description provided for @tagCalls.
  ///
  /// In ar, this message translates to:
  /// **'مكالمات'**
  String get tagCalls;

  /// No description provided for @tagVideo.
  ///
  /// In ar, this message translates to:
  /// **'فيديو'**
  String get tagVideo;

  /// No description provided for @both.
  ///
  /// In ar, this message translates to:
  /// **'الاتنين مع بعض'**
  String get both;

  /// No description provided for @bothDesc.
  ///
  /// In ar, this message translates to:
  /// **'موبايلك يبقى كوبري: يوصّل اللي على الواي فاي أو الهوت سبوت باللي على البلوتوث، فكذا شبكة تبقى شبكة واحدة.'**
  String get bothDesc;

  /// No description provided for @tagBridge.
  ///
  /// In ar, this message translates to:
  /// **'كوبري'**
  String get tagBridge;

  /// No description provided for @tagRange.
  ///
  /// In ar, this message translates to:
  /// **'أوسع مدى'**
  String get tagRange;

  /// No description provided for @tagBattery.
  ///
  /// In ar, this message translates to:
  /// **'بطارية أكتر'**
  String get tagBattery;

  /// No description provided for @photoUnusable.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نستخدم الصورة دي — جرّب صورة تانية'**
  String get photoUnusable;

  /// No description provided for @galleryFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نفتح المعرض'**
  String get galleryFailed;

  /// No description provided for @nameTooShort.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم من حرفين على الأقل'**
  String get nameTooShort;

  /// No description provided for @profileSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نحفظ البروفايل'**
  String get profileSaveFailed;

  /// No description provided for @profile.
  ///
  /// In ar, this message translates to:
  /// **'البروفايل'**
  String get profile;

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'وَصْل'**
  String get appTitle;

  /// No description provided for @createProfile.
  ///
  /// In ar, this message translates to:
  /// **'اعمل بروفايلك'**
  String get createProfile;

  /// No description provided for @createProfileSub.
  ///
  /// In ar, this message translates to:
  /// **'اسم وصورة يشوفهم الناس اللي حواليك. من غير رقم موبايل ولا إيميل ولا إنترنت — كل حاجة على موبايلك بس.'**
  String get createProfileSub;

  /// No description provided for @removePhoto.
  ///
  /// In ar, this message translates to:
  /// **'شيل الصورة'**
  String get removePhoto;

  /// No description provided for @yourName.
  ///
  /// In ar, this message translates to:
  /// **'اسمك'**
  String get yourName;

  /// No description provided for @profileColor.
  ///
  /// In ar, this message translates to:
  /// **'لون البروفايل'**
  String get profileColor;

  /// No description provided for @orCartoon.
  ///
  /// In ar, this message translates to:
  /// **'أو اختار أفاتار كرتوني'**
  String get orCartoon;

  /// No description provided for @letsStart.
  ///
  /// In ar, this message translates to:
  /// **'يلا نبدأ'**
  String get letsStart;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @reqNearbyTitle.
  ///
  /// In ar, this message translates to:
  /// **'إذن الأجهزة القريبة'**
  String get reqNearbyTitle;

  /// No description provided for @reqNearbyWhy.
  ///
  /// In ar, this message translates to:
  /// **'عشان Wasl يلاقي الموبايلات القريبة ويتصل بيها بالبلوتوث. مش بيستخدم موقعك.'**
  String get reqNearbyWhy;

  /// No description provided for @reqWifiTitle.
  ///
  /// In ar, this message translates to:
  /// **'إذن أجهزة الواي فاي القريبة'**
  String get reqWifiTitle;

  /// No description provided for @reqWifiWhy.
  ///
  /// In ar, this message translates to:
  /// **'بيخلي الرسايل تتنقل أسرع بالواي فاي المباشر لما الجهازين قريبين.'**
  String get reqWifiWhy;

  /// No description provided for @reqLocationTitle.
  ///
  /// In ar, this message translates to:
  /// **'إذن الموقع'**
  String get reqLocationTitle;

  /// No description provided for @reqLocationWhy.
  ///
  /// In ar, this message translates to:
  /// **'أندرويد {version} بيشترط إذن الموقع لأي بحث عن أجهزة قريبة. Wasl مش بيقرا موقعك ولا بيحفظه.'**
  String reqLocationWhy(Object version);

  /// No description provided for @android11OrOlder.
  ///
  /// In ar, this message translates to:
  /// **'11 وأقدم'**
  String get android11OrOlder;

  /// No description provided for @reqBluetoothTitle.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل البلوتوث'**
  String get reqBluetoothTitle;

  /// No description provided for @reqBluetoothWhy.
  ///
  /// In ar, this message translates to:
  /// **'الجهازين بيلاقوا بعض عن طريق البلوتوث.'**
  String get reqBluetoothWhy;

  /// No description provided for @reqGpsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل خدمة الموقع (GPS)'**
  String get reqGpsTitle;

  /// No description provided for @reqGpsWhy.
  ///
  /// In ar, this message translates to:
  /// **'في الإصدار ده من أندرويد البحث عن الأجهزة مش بيشتغل غير والموقع شغال.'**
  String get reqGpsWhy;

  /// No description provided for @openSettings.
  ///
  /// In ar, this message translates to:
  /// **'افتح الإعدادات'**
  String get openSettings;

  /// No description provided for @allow.
  ///
  /// In ar, this message translates to:
  /// **'اسمح'**
  String get allow;

  /// No description provided for @turnOn.
  ///
  /// In ar, this message translates to:
  /// **'شغّل'**
  String get turnOn;

  /// No description provided for @callIncomingVideo.
  ///
  /// In ar, this message translates to:
  /// **'مكالمة فيديو واردة'**
  String get callIncomingVideo;

  /// No description provided for @callIncomingVoice.
  ///
  /// In ar, this message translates to:
  /// **'مكالمة صوتية واردة'**
  String get callIncomingVoice;

  /// No description provided for @callRinging.
  ///
  /// In ar, this message translates to:
  /// **'بيرن...'**
  String get callRinging;

  /// No description provided for @callConnecting.
  ///
  /// In ar, this message translates to:
  /// **'جاري التوصيل...'**
  String get callConnecting;

  /// No description provided for @callEnded.
  ///
  /// In ar, this message translates to:
  /// **'المكالمة خلصت'**
  String get callEnded;

  /// No description provided for @cameraOff.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا مقفولة'**
  String get cameraOff;

  /// No description provided for @me.
  ///
  /// In ar, this message translates to:
  /// **'أنا'**
  String get me;

  /// No description provided for @e2eEncrypted.
  ///
  /// In ar, this message translates to:
  /// **'مشفّرة من طرف لطرف'**
  String get e2eEncrypted;

  /// No description provided for @decline.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get decline;

  /// No description provided for @accept.
  ///
  /// In ar, this message translates to:
  /// **'قبول'**
  String get accept;

  /// No description provided for @flipCamera.
  ///
  /// In ar, this message translates to:
  /// **'قلب الكاميرا'**
  String get flipCamera;

  /// No description provided for @camera.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا'**
  String get camera;

  /// No description provided for @mute.
  ///
  /// In ar, this message translates to:
  /// **'كتم'**
  String get mute;

  /// No description provided for @muted.
  ///
  /// In ar, this message translates to:
  /// **'مكتوم'**
  String get muted;

  /// No description provided for @speaker.
  ///
  /// In ar, this message translates to:
  /// **'السماعة'**
  String get speaker;

  /// No description provided for @earpiece.
  ///
  /// In ar, this message translates to:
  /// **'الأذن'**
  String get earpiece;

  /// No description provided for @callBusy.
  ///
  /// In ar, this message translates to:
  /// **'فيه مكالمة شغالة بالفعل'**
  String get callBusy;

  /// No description provided for @notConnectedNow.
  ///
  /// In ar, this message translates to:
  /// **'مش متصل دلوقتي'**
  String get notConnectedNow;

  /// No description provided for @callNoAnswer.
  ///
  /// In ar, this message translates to:
  /// **'مفيش رد'**
  String get callNoAnswer;

  /// No description provided for @callConnectFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نوصّل المكالمة'**
  String get callConnectFailed;

  /// No description provided for @callStartFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نشغّل المكالمة'**
  String get callStartFailed;

  /// No description provided for @callMediaFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نشغّل الميكروفون/الكاميرا'**
  String get callMediaFailed;

  /// No description provided for @callRejected.
  ///
  /// In ar, this message translates to:
  /// **'اترفضت'**
  String get callRejected;

  /// No description provided for @callMissed.
  ///
  /// In ar, this message translates to:
  /// **'فاتتك مكالمة'**
  String get callMissed;

  /// No description provided for @callPeerRejected.
  ///
  /// In ar, this message translates to:
  /// **'الطرف التاني رفض المكالمة'**
  String get callPeerRejected;

  /// No description provided for @callPeerBusy.
  ///
  /// In ar, this message translates to:
  /// **'الطرف التاني في مكالمة تانية'**
  String get callPeerBusy;

  /// No description provided for @callPeerHungUp.
  ///
  /// In ar, this message translates to:
  /// **'الطرف التاني قفل المكالمة'**
  String get callPeerHungUp;

  /// No description provided for @callProblem.
  ///
  /// In ar, this message translates to:
  /// **'حصلت مشكلة في المكالمة'**
  String get callProblem;

  /// No description provided for @callIceFailed.
  ///
  /// In ar, this message translates to:
  /// **'الاتصال فشل — اتأكدوا إنكم على نفس الشبكة'**
  String get callIceFailed;

  /// No description provided for @micDeniedForever.
  ///
  /// In ar, this message translates to:
  /// **'إذن الميكروفون مرفوض — فعّله من إعدادات التطبيق'**
  String get micDeniedForever;

  /// No description provided for @micNeededCall.
  ///
  /// In ar, this message translates to:
  /// **'محتاجين إذن الميكروفون عشان المكالمة'**
  String get micNeededCall;

  /// No description provided for @camDeniedForever.
  ///
  /// In ar, this message translates to:
  /// **'إذن الكاميرا مرفوض — فعّله من إعدادات التطبيق'**
  String get camDeniedForever;

  /// No description provided for @camNeededCall.
  ///
  /// In ar, this message translates to:
  /// **'محتاجين إذن الكاميرا عشان مكالمة الفيديو'**
  String get camNeededCall;

  /// No description provided for @callDropped.
  ///
  /// In ar, this message translates to:
  /// **'الاتصال قطع'**
  String get callDropped;

  /// No description provided for @chatEnded.
  ///
  /// In ar, this message translates to:
  /// **'المحادثة انتهت'**
  String get chatEnded;

  /// No description provided for @micNeededRecord.
  ///
  /// In ar, this message translates to:
  /// **'محتاجين إذن الميكروفون عشان نسجّل'**
  String get micNeededRecord;

  /// No description provided for @micStartFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نشغّل الميكروفون'**
  String get micStartFailed;

  /// No description provided for @holdToRecord.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على الميكروفون واستمر ضاغط عشان تسجّل'**
  String get holdToRecord;

  /// No description provided for @recordFailed.
  ///
  /// In ar, this message translates to:
  /// **'التسجيل مكملش — جرّب تاني'**
  String get recordFailed;

  /// No description provided for @emojiNoRecents.
  ///
  /// In ar, this message translates to:
  /// **'الإيموجي اللي بتستخدمها هتظهر هنا'**
  String get emojiNoRecents;

  /// No description provided for @emojiSearch.
  ///
  /// In ar, this message translates to:
  /// **'دوّر على إيموجي (بالإنجليزي)'**
  String get emojiSearch;

  /// No description provided for @keyboard.
  ///
  /// In ar, this message translates to:
  /// **'الكيبورد'**
  String get keyboard;

  /// No description provided for @emoji.
  ///
  /// In ar, this message translates to:
  /// **'إيموجي'**
  String get emoji;

  /// No description provided for @messageHint.
  ///
  /// In ar, this message translates to:
  /// **'رسالة'**
  String get messageHint;

  /// No description provided for @waitingConnection.
  ///
  /// In ar, this message translates to:
  /// **'مستني الاتصال...'**
  String get waitingConnection;

  /// No description provided for @attachments.
  ///
  /// In ar, this message translates to:
  /// **'مرفقات'**
  String get attachments;

  /// No description provided for @photoHoldVideo.
  ///
  /// In ar, this message translates to:
  /// **'صورة (اضغط مطولاً للفيديو)'**
  String get photoHoldVideo;

  /// No description provided for @photo.
  ///
  /// In ar, this message translates to:
  /// **'صورة'**
  String get photo;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'امسح'**
  String get delete;

  /// No description provided for @slideToCancel.
  ///
  /// In ar, this message translates to:
  /// **'اسحب للإلغاء'**
  String get slideToCancel;

  /// No description provided for @theOtherSide.
  ///
  /// In ar, this message translates to:
  /// **'الطرف التاني'**
  String get theOtherSide;

  /// No description provided for @forwarded.
  ///
  /// In ar, this message translates to:
  /// **'محوّلة'**
  String get forwarded;

  /// No description provided for @edited.
  ///
  /// In ar, this message translates to:
  /// **'معدّلة'**
  String get edited;

  /// No description provided for @you.
  ///
  /// In ar, this message translates to:
  /// **'انت'**
  String get you;

  /// No description provided for @compareSafety.
  ///
  /// In ar, this message translates to:
  /// **'قارن رمز الأمان مع {name}'**
  String compareSafety(Object name);

  /// No description provided for @compareSafetyHint.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد إضافي (اختياري): لو نفس الرقم ظاهر على الموبايل التاني يبقى متأكدين ١٠٠٪ إن محدش في النص.'**
  String get compareSafetyHint;

  /// No description provided for @different.
  ///
  /// In ar, this message translates to:
  /// **'مختلف'**
  String get different;

  /// No description provided for @matches.
  ///
  /// In ar, this message translates to:
  /// **'متطابق'**
  String get matches;

  /// No description provided for @attachDocument.
  ///
  /// In ar, this message translates to:
  /// **'مستند'**
  String get attachDocument;

  /// No description provided for @attachCamera.
  ///
  /// In ar, this message translates to:
  /// **'كاميرا'**
  String get attachCamera;

  /// No description provided for @attachGallery.
  ///
  /// In ar, this message translates to:
  /// **'المعرض'**
  String get attachGallery;

  /// No description provided for @attachAudio.
  ///
  /// In ar, this message translates to:
  /// **'صوت'**
  String get attachAudio;

  /// No description provided for @videoWifiOnlyHint.
  ///
  /// In ar, this message translates to:
  /// **'الفيديو متاح في دردشة الواي فاي / الهوت سبوت (البلوتوث أبطأ من كده).'**
  String get videoWifiOnlyHint;

  /// No description provided for @video.
  ///
  /// In ar, this message translates to:
  /// **'فيديو'**
  String get video;

  /// No description provided for @videoWifiOnly.
  ///
  /// In ar, this message translates to:
  /// **'الفيديو متاح في دردشة الواي فاي بس'**
  String get videoWifiOnly;

  /// No description provided for @cameraPermission.
  ///
  /// In ar, this message translates to:
  /// **'محتاجين إذن الكاميرا — فعّله من إعدادات التطبيق'**
  String get cameraPermission;

  /// No description provided for @cameraFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نفتح الكاميرا'**
  String get cameraFailed;

  /// No description provided for @videoWifiOnlyPhotosSent.
  ///
  /// In ar, this message translates to:
  /// **'الفيديو متاح في دردشة الواي فاي بس — اتبعتت الصور بس'**
  String get videoWifiOnlyPhotosSent;

  /// No description provided for @videoCompressFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نضغط الفيديو — هيتبعت زي ما هو'**
  String get videoCompressFailed;

  /// No description provided for @preparingVideo.
  ///
  /// In ar, this message translates to:
  /// **'بنجهّز الفيديو'**
  String get preparingVideo;

  /// No description provided for @preparingVideoBody.
  ///
  /// In ar, this message translates to:
  /// **'بنصغّره عشان يشتغل على أي موبايل ويتبعت أسرع.'**
  String get preparingVideoBody;

  /// No description provided for @filesFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نفتح الملفات'**
  String get filesFailed;

  /// No description provided for @fileTooBig.
  ///
  /// In ar, this message translates to:
  /// **'الملف أكبر من {size}'**
  String fileTooBig(Object size);

  /// No description provided for @readFileFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نقرا الملف'**
  String get readFileFailed;

  /// No description provided for @sendFailedRetry.
  ///
  /// In ar, this message translates to:
  /// **'موصلش — ابعته تاني'**
  String get sendFailedRetry;

  /// No description provided for @fileIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'الملف موصلش كامل'**
  String get fileIncomplete;

  /// No description provided for @file.
  ///
  /// In ar, this message translates to:
  /// **'ملف'**
  String get file;

  /// No description provided for @waitingReconnectPct.
  ///
  /// In ar, this message translates to:
  /// **'مستني الاتصال يرجع... {pct}%'**
  String waitingReconnectPct(Object pct);

  /// No description provided for @pctOfSize.
  ///
  /// In ar, this message translates to:
  /// **'{pct}% من {size}'**
  String pctOfSize(Object pct, Object size);

  /// No description provided for @waitingConnectionPct.
  ///
  /// In ar, this message translates to:
  /// **'مستني الاتصال... {pct}%'**
  String waitingConnectionPct(Object pct);

  /// No description provided for @cancelSending.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الإرسال'**
  String get cancelSending;

  /// No description provided for @cancelReceiving.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الاستلام'**
  String get cancelReceiving;

  /// No description provided for @saveToDownloads.
  ///
  /// In ar, this message translates to:
  /// **'حفظ في التنزيلات'**
  String get saveToDownloads;

  /// No description provided for @noAppToOpen.
  ///
  /// In ar, this message translates to:
  /// **'مفيش تطبيق على الموبايل يفتح النوع ده — احفظه أو شاركه'**
  String get noAppToOpen;

  /// No description provided for @storagePermission.
  ///
  /// In ar, this message translates to:
  /// **'محتاجين إذن التخزين عشان نحفظ الملف'**
  String get storagePermission;

  /// No description provided for @savedToDownloads.
  ///
  /// In ar, this message translates to:
  /// **'اتحفظ في التنزيلات ← Wasl'**
  String get savedToDownloads;

  /// No description provided for @saveFileFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نحفظ الملف'**
  String get saveFileFailed;

  /// No description provided for @tapToOpen.
  ///
  /// In ar, this message translates to:
  /// **'اضغط عشان تفتحه'**
  String get tapToOpen;

  /// No description provided for @photosPermission.
  ///
  /// In ar, this message translates to:
  /// **'محتاجين إذن الوصول للصور'**
  String get photosPermission;

  /// No description provided for @savedToGallery.
  ///
  /// In ar, this message translates to:
  /// **'اتحفظ في المعرض'**
  String get savedToGallery;

  /// No description provided for @openWithOtherApp.
  ///
  /// In ar, this message translates to:
  /// **'افتح بتطبيق تاني'**
  String get openWithOtherApp;

  /// No description provided for @saveToGallery.
  ///
  /// In ar, this message translates to:
  /// **'حفظ في المعرض'**
  String get saveToGallery;

  /// No description provided for @share.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get share;

  /// No description provided for @videoCantPlay.
  ///
  /// In ar, this message translates to:
  /// **'الفيديو وصل سليم، بس المشغّل اللي جوه التطبيق مش قادر يشغّل النوع ده.'**
  String get videoCantPlay;

  /// No description provided for @saveItToGallery.
  ///
  /// In ar, this message translates to:
  /// **'احفظه في المعرض'**
  String get saveItToGallery;

  /// No description provided for @groupNobodyReachable.
  ///
  /// In ar, this message translates to:
  /// **'مفيش حد من الجروب واصلين له دلوقتي'**
  String get groupNobodyReachable;

  /// No description provided for @videoWifiOnlyShort.
  ///
  /// In ar, this message translates to:
  /// **'الفيديو متاح في الواي فاي بس'**
  String get videoWifiOnlyShort;

  /// No description provided for @fileEmpty.
  ///
  /// In ar, this message translates to:
  /// **'الملف فاضي'**
  String get fileEmpty;

  /// No description provided for @notAValidVideo.
  ///
  /// In ar, this message translates to:
  /// **'الملف ده مش فيديو سليم — اختاره تاني من المعرض'**
  String get notAValidVideo;

  /// No description provided for @groupMaxSize.
  ///
  /// In ar, this message translates to:
  /// **'أقصى حجم في الجروبات {size}'**
  String groupMaxSize(Object size);

  /// No description provided for @sendFileFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نبعت الملف'**
  String get sendFileFailed;

  /// No description provided for @connectionStoppedEarly.
  ///
  /// In ar, this message translates to:
  /// **'الاتصال وقف قبل ما يكمل'**
  String get connectionStoppedEarly;

  /// No description provided for @memberJoined.
  ///
  /// In ar, this message translates to:
  /// **'{name} دخل الجروب'**
  String memberJoined(Object name);

  /// No description provided for @memberLeft.
  ///
  /// In ar, this message translates to:
  /// **'{name} خرج من الجروب'**
  String memberLeft(Object name);

  /// No description provided for @arrivedIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'وصل ناقص'**
  String get arrivedIncomplete;

  /// No description provided for @arrivedCorrupt.
  ///
  /// In ar, this message translates to:
  /// **'وصل مختلف عن الأصلي'**
  String get arrivedCorrupt;

  /// No description provided for @sendingStoppedEarly.
  ///
  /// In ar, this message translates to:
  /// **'الإرسال وقف قبل ما يكمل'**
  String get sendingStoppedEarly;

  /// No description provided for @joinAccepted.
  ///
  /// In ar, this message translates to:
  /// **'اتقبلت في \"{group}\" 🎉'**
  String joinAccepted(Object group);

  /// No description provided for @joinRejected.
  ///
  /// In ar, this message translates to:
  /// **'طلبك لدخول \"{group}\" اترفض'**
  String joinRejected(Object group);

  /// No description provided for @leaveTitle.
  ///
  /// In ar, this message translates to:
  /// **'تقفل الاتصال؟'**
  String get leaveTitle;

  /// No description provided for @leaveBodyUnsaved.
  ///
  /// In ar, this message translates to:
  /// **'هتبقى مش ظاهر للناس، والمحادثات اللي مش محفوظة هتتمسح.'**
  String get leaveBodyUnsaved;

  /// No description provided for @leaveBody.
  ///
  /// In ar, this message translates to:
  /// **'هتبقى مش ظاهر للناس لحد ما تدخل تاني.'**
  String get leaveBody;

  /// No description provided for @disconnect.
  ///
  /// In ar, this message translates to:
  /// **'اقفل'**
  String get disconnect;

  /// No description provided for @newChat.
  ///
  /// In ar, this message translates to:
  /// **'محادثة جديدة'**
  String get newChat;

  /// No description provided for @newGroup.
  ///
  /// In ar, this message translates to:
  /// **'جروب جديد'**
  String get newGroup;

  /// No description provided for @tabChats.
  ///
  /// In ar, this message translates to:
  /// **'المحادثات'**
  String get tabChats;

  /// No description provided for @tabGroups.
  ///
  /// In ar, this message translates to:
  /// **'الجروبات'**
  String get tabGroups;

  /// No description provided for @tabNearby.
  ///
  /// In ar, this message translates to:
  /// **'القريبين'**
  String get tabNearby;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @preparing.
  ///
  /// In ar, this message translates to:
  /// **'بنجهّز...'**
  String get preparing;

  /// No description provided for @searchingPeople.
  ///
  /// In ar, this message translates to:
  /// **'بندوّر على ناس حواليك'**
  String get searchingPeople;

  /// No description provided for @peopleNearby.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{{count} شخص قريب} =2{{count} أشخاص قريبين} few{{count} أشخاص قريبين} other{{count} شخص قريب}}'**
  String peopleNearby(int count);

  /// No description provided for @tryAgain.
  ///
  /// In ar, this message translates to:
  /// **'حاول تاني'**
  String get tryAgain;

  /// No description provided for @openWifi.
  ///
  /// In ar, this message translates to:
  /// **'افتح الواي فاي'**
  String get openWifi;

  /// No description provided for @yesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get yesterday;

  /// No description provided for @unpin.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التثبيت'**
  String get unpin;

  /// No description provided for @pin.
  ///
  /// In ar, this message translates to:
  /// **'تثبيت فوق'**
  String get pin;

  /// No description provided for @unmuteNotifications.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء كتم الإشعارات'**
  String get unmuteNotifications;

  /// No description provided for @muteNotifications.
  ///
  /// In ar, this message translates to:
  /// **'كتم الإشعارات'**
  String get muteNotifications;

  /// No description provided for @unsaveChat.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء حفظ المحادثة'**
  String get unsaveChat;

  /// No description provided for @saveChat.
  ///
  /// In ar, this message translates to:
  /// **'حفظ المحادثة على الموبايل'**
  String get saveChat;

  /// No description provided for @leaveGroup.
  ///
  /// In ar, this message translates to:
  /// **'الخروج من الجروب'**
  String get leaveGroup;

  /// No description provided for @deleteChat.
  ///
  /// In ar, this message translates to:
  /// **'حذف المحادثة'**
  String get deleteChat;

  /// No description provided for @chatSavedToast.
  ///
  /// In ar, this message translates to:
  /// **'المحادثة بتتحفظ على الموبايل'**
  String get chatSavedToast;

  /// No description provided for @chatUnsavedToast.
  ///
  /// In ar, this message translates to:
  /// **'المحادثة مبقتش بتتحفظ'**
  String get chatUnsavedToast;

  /// No description provided for @leaveGroupTitle.
  ///
  /// In ar, this message translates to:
  /// **'الخروج من \"{name}\"؟'**
  String leaveGroupTitle(Object name);

  /// No description provided for @deleteChatTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف المحادثة مع {name}؟'**
  String deleteChatTitle(Object name);

  /// No description provided for @messagesErasedBody.
  ///
  /// In ar, this message translates to:
  /// **'الرسايل هتتمسح من موبايلك.'**
  String get messagesErasedBody;

  /// No description provided for @leave.
  ///
  /// In ar, this message translates to:
  /// **'خروج'**
  String get leave;

  /// No description provided for @deleteAction.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get deleteAction;

  /// No description provided for @typing.
  ///
  /// In ar, this message translates to:
  /// **'بيكتب...'**
  String get typing;

  /// No description provided for @nameTyping.
  ///
  /// In ar, this message translates to:
  /// **'{name} بيكتب...'**
  String nameTyping(Object name);

  /// No description provided for @groupOfMode.
  ///
  /// In ar, this message translates to:
  /// **'جروب {mode}'**
  String groupOfMode(Object mode);

  /// No description provided for @tapToStart.
  ///
  /// In ar, this message translates to:
  /// **'اضغط وابدأ الكلام'**
  String get tapToStart;

  /// No description provided for @youPrefix.
  ///
  /// In ar, this message translates to:
  /// **'إنت: {text}'**
  String youPrefix(Object text);

  /// No description provided for @noChatsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لسه مفيش محادثات'**
  String get noChatsTitle;

  /// No description provided for @noChatsBody.
  ///
  /// In ar, this message translates to:
  /// **'اختار حد أو جروب من القريبين وابدأ الكلام. التشفير بيتعمل تلقائي من غير كلمة سر.'**
  String get noChatsBody;

  /// No description provided for @startNewChat.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ محادثة جديدة'**
  String get startNewChat;

  /// No description provided for @noGroupsTitle.
  ///
  /// In ar, this message translates to:
  /// **'مفيش جروبات حواليك'**
  String get noGroupsTitle;

  /// No description provided for @noGroupsBody.
  ///
  /// In ar, this message translates to:
  /// **'اعمل جروب عام لأي حد قريب، أو خاص بكلمة سر أو بموافقتك. الجروب بيظهر للكل طول ما فيه عضو قريب.'**
  String get noGroupsBody;

  /// No description provided for @createGroup.
  ///
  /// In ar, this message translates to:
  /// **'اعمل جروب'**
  String get createGroup;

  /// No description provided for @myGroups.
  ///
  /// In ar, this message translates to:
  /// **'جروباتي'**
  String get myGroups;

  /// No description provided for @groupsAround.
  ///
  /// In ar, this message translates to:
  /// **'جروبات حواليك'**
  String get groupsAround;

  /// No description provided for @groupsAroundCount.
  ///
  /// In ar, this message translates to:
  /// **'جروبات حواليك ({count})'**
  String groupsAroundCount(Object count);

  /// No description provided for @membersNearby.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{{count} عضو قريب} other{{count} أعضاء قريبين}}'**
  String membersNearby(int count);

  /// No description provided for @waiting.
  ///
  /// In ar, this message translates to:
  /// **'مستني'**
  String get waiting;

  /// No description provided for @requestJoin.
  ///
  /// In ar, this message translates to:
  /// **'اطلب'**
  String get requestJoin;

  /// No description provided for @join.
  ///
  /// In ar, this message translates to:
  /// **'ادخل'**
  String get join;

  /// No description provided for @ipFormat.
  ///
  /// In ar, this message translates to:
  /// **'اكتب العنوان بالشكل ده: 192.168.1.5'**
  String get ipFormat;

  /// No description provided for @ipConnected.
  ///
  /// In ar, this message translates to:
  /// **'اتوصلنا — هيظهر في القايمة دلوقتي'**
  String get ipConnected;

  /// No description provided for @searchWifiHint.
  ///
  /// In ar, this message translates to:
  /// **'أي حد فاتح Wasl على نفس الواي فاي (أو متوصل بالهوت سبوت بتاعك) هيظهر هنا لوحده.'**
  String get searchWifiHint;

  /// No description provided for @searchBtHint.
  ///
  /// In ar, this message translates to:
  /// **'أي حد قريب فاتح Wasl على البلوتوث هيظهر هنا لوحده. البحث بياخد من ثواني لدقيقة.'**
  String get searchBtHint;

  /// No description provided for @peopleTapToTalk.
  ///
  /// In ar, this message translates to:
  /// **'أشخاص — اضغط على أي حد عشان تكلمه ({count})'**
  String peopleTapToTalk(Object count);

  /// No description provided for @meshHint.
  ///
  /// In ar, this message translates to:
  /// **'الأجهزة بتوصّل لبعض: ممكن تكلم حد بعيد عنك عن طريق موبايلات في النص، ومحدش منهم يقدر يقرا رسايلك.'**
  String get meshHint;

  /// No description provided for @connectByAddress.
  ///
  /// In ar, this message translates to:
  /// **'اتصال بالعنوان'**
  String get connectByAddress;

  /// No description provided for @connectByAddressHint.
  ///
  /// In ar, this message translates to:
  /// **'لو الشبكة مانعة الاكتشاف التلقائي (زي بعض شبكات الكافيهات). عنوانك: {addresses}'**
  String connectByAddressHint(Object addresses);

  /// No description provided for @listSeparator.
  ///
  /// In ar, this message translates to:
  /// **' ، '**
  String get listSeparator;

  /// No description provided for @otherDeviceAddress.
  ///
  /// In ar, this message translates to:
  /// **'عنوان الجهاز التاني'**
  String get otherDeviceAddress;

  /// No description provided for @connect.
  ///
  /// In ar, this message translates to:
  /// **'اتصل'**
  String get connect;

  /// No description provided for @someoneMissing.
  ///
  /// In ar, this message translates to:
  /// **'حد مش ظاهر؟ اتصل بعنوانه'**
  String get someoneMissing;

  /// No description provided for @connectedDirectly.
  ///
  /// In ar, this message translates to:
  /// **'متصل بيك مباشرة'**
  String get connectedDirectly;

  /// No description provided for @viaRelays.
  ///
  /// In ar, this message translates to:
  /// **'عن طريق {count, plural, =1{جهاز واحد} =2{جهازين} other{{count} أجهزة}} في النص'**
  String viaRelays(int count);

  /// No description provided for @oneStepTitle.
  ///
  /// In ar, this message translates to:
  /// **'خطوة واحدة قبل ما نبدأ'**
  String get oneStepTitle;

  /// No description provided for @oneStepBody.
  ///
  /// In ar, this message translates to:
  /// **'البلوتوث بيشتغل من غير إنترنت، وعشان الموبايلات تلاقي بعض محتاجين الحاجات دي:'**
  String get oneStepBody;

  /// No description provided for @permissionBlockedHint.
  ///
  /// In ar, this message translates to:
  /// **'الإذن ده اترفض قبل كده — فعّله من الإعدادات ← الأذونات.'**
  String get permissionBlockedHint;

  /// No description provided for @modeOpen.
  ///
  /// In ar, this message translates to:
  /// **'عام'**
  String get modeOpen;

  /// No description provided for @modePassword.
  ///
  /// In ar, this message translates to:
  /// **'بكلمة سر'**
  String get modePassword;

  /// No description provided for @modeAsk.
  ///
  /// In ar, this message translates to:
  /// **'بطلب انضمام'**
  String get modeAsk;

  /// No description provided for @groupNameNeeded.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم للجروب'**
  String get groupNameNeeded;

  /// No description provided for @passwordTooShort.
  ///
  /// In ar, this message translates to:
  /// **'كلمة السر 4 حروف على الأقل'**
  String get passwordTooShort;

  /// No description provided for @createGroupFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نعمل الجروب'**
  String get createGroupFailed;

  /// No description provided for @modeOpenExplain.
  ///
  /// In ar, this message translates to:
  /// **'أي حد قريب يشوف الجروب ويدخل على طول.'**
  String get modeOpenExplain;

  /// No description provided for @modePasswordExplain.
  ///
  /// In ar, this message translates to:
  /// **'الجروب ظاهر، بس محدش يدخل ولا يقرا غير اللي معاه كلمة السر.'**
  String get modePasswordExplain;

  /// No description provided for @modeAskExplain.
  ///
  /// In ar, this message translates to:
  /// **'اللي عايز يدخل يبعتلك طلب، وإنت توافق أو ترفض.'**
  String get modeAskExplain;

  /// No description provided for @groupName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الجروب'**
  String get groupName;

  /// No description provided for @groupPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة سر الجروب'**
  String get groupPassword;

  /// No description provided for @createGroupButton.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الجروب'**
  String get createGroupButton;

  /// No description provided for @joinGroupFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش ندخل الجروب'**
  String get joinGroupFailed;

  /// No description provided for @requestPendingTitle.
  ///
  /// In ar, this message translates to:
  /// **'الطلب لسه مستني'**
  String get requestPendingTitle;

  /// No description provided for @requestPendingBody.
  ///
  /// In ar, this message translates to:
  /// **'صاحب الجروب لسه مردّش على طلبك.'**
  String get requestPendingBody;

  /// No description provided for @cancelRequest.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get cancelRequest;

  /// No description provided for @keepWaiting.
  ///
  /// In ar, this message translates to:
  /// **'هستنى'**
  String get keepWaiting;

  /// No description provided for @requestJoinTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب انضمام لـ \"{name}\"'**
  String requestJoinTitle(Object name);

  /// No description provided for @requestJoinBody.
  ///
  /// In ar, this message translates to:
  /// **'هنبعت طلب لصاحب الجروب، وأول ما يوافق هتدخل تلقائياً.'**
  String get requestJoinBody;

  /// No description provided for @sendRequest.
  ///
  /// In ar, this message translates to:
  /// **'ابعت الطلب'**
  String get sendRequest;

  /// No description provided for @requestSent.
  ///
  /// In ar, this message translates to:
  /// **'الطلب اتبعت — مستنيين الموافقة'**
  String get requestSent;

  /// No description provided for @privateGroupPassword.
  ///
  /// In ar, this message translates to:
  /// **'الجروب ده خاص — اكتب كلمة السر عشان تدخل.'**
  String get privateGroupPassword;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة السر'**
  String get password;

  /// No description provided for @enter.
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get enter;

  /// No description provided for @roleOwner.
  ///
  /// In ar, this message translates to:
  /// **'صاحب الجروب'**
  String get roleOwner;

  /// No description provided for @roleAdmin.
  ///
  /// In ar, this message translates to:
  /// **'مدير'**
  String get roleAdmin;

  /// No description provided for @member.
  ///
  /// In ar, this message translates to:
  /// **'عضو'**
  String get member;

  /// No description provided for @onlineNow.
  ///
  /// In ar, this message translates to:
  /// **'متصل دلوقتي'**
  String get onlineNow;

  /// No description provided for @privateMessage.
  ///
  /// In ar, this message translates to:
  /// **'رسالة خاصة'**
  String get privateMessage;

  /// No description provided for @privateMessageSub.
  ///
  /// In ar, this message translates to:
  /// **'مشفّرة بينكم انتوا الاتنين بس'**
  String get privateMessageSub;

  /// No description provided for @voiceCall.
  ///
  /// In ar, this message translates to:
  /// **'مكالمة صوتية'**
  String get voiceCall;

  /// No description provided for @mention.
  ///
  /// In ar, this message translates to:
  /// **'منشن'**
  String get mention;

  /// No description provided for @removeAdmin.
  ///
  /// In ar, this message translates to:
  /// **'شيله من الإدارة'**
  String get removeAdmin;

  /// No description provided for @makeAdmin.
  ///
  /// In ar, this message translates to:
  /// **'خليه مدير'**
  String get makeAdmin;

  /// No description provided for @removeFromGroup.
  ///
  /// In ar, this message translates to:
  /// **'شيله من الجروب'**
  String get removeFromGroup;

  /// No description provided for @unban.
  ///
  /// In ar, this message translates to:
  /// **'رجّعه للجروب'**
  String get unban;

  /// No description provided for @block.
  ///
  /// In ar, this message translates to:
  /// **'حظر'**
  String get block;

  /// No description provided for @blockSub.
  ///
  /// In ar, this message translates to:
  /// **'مش هتشوف رسايله في أي مكان'**
  String get blockSub;

  /// No description provided for @kickTitle.
  ///
  /// In ar, this message translates to:
  /// **'تشيل {name} من الجروب؟'**
  String kickTitle(Object name);

  /// No description provided for @kickAsk.
  ///
  /// In ar, this message translates to:
  /// **'مفتاح الجروب هيتغير، فمش هيقدر يقرا أي رسالة جديدة ولا يدخل تاني غير بموافقة.'**
  String get kickAsk;

  /// No description provided for @kickPassword.
  ///
  /// In ar, this message translates to:
  /// **'رسايله مش هتظهر لحد ومش هيقدر يبعت. بس هو لسه عارف كلمة السر — لو عايز تمنعه يقرا خالص اعمل جروب جديد بكلمة تانية.'**
  String get kickPassword;

  /// No description provided for @kickOpen.
  ///
  /// In ar, this message translates to:
  /// **'رسايله مش هتظهر لحد ومش هيقدر يبعت. الجروب العام أي حد قريب يقدر يقراه.'**
  String get kickOpen;

  /// No description provided for @kickConfirm.
  ///
  /// In ar, this message translates to:
  /// **'شيله'**
  String get kickConfirm;

  /// No description provided for @kicked.
  ///
  /// In ar, this message translates to:
  /// **'{name} اتشال من الجروب'**
  String kicked(Object name);

  /// No description provided for @unbanned.
  ///
  /// In ar, this message translates to:
  /// **'{name} يقدر يدخل الجروب تاني'**
  String unbanned(Object name);

  /// No description provided for @blockTitle.
  ///
  /// In ar, this message translates to:
  /// **'حظر {name}؟'**
  String blockTitle(Object name);

  /// No description provided for @blockBody.
  ///
  /// In ar, this message translates to:
  /// **'مش هيقدر يبعتلك رسايل ولا هتشوف رسايله في الجروبات. تقدر تلغي الحظر من الإعدادات.'**
  String get blockBody;

  /// No description provided for @groupInfo.
  ///
  /// In ar, this message translates to:
  /// **'معلومات الجروب'**
  String get groupInfo;

  /// No description provided for @notInGroup.
  ///
  /// In ar, this message translates to:
  /// **'مبقتش في الجروب ده'**
  String get notInGroup;

  /// No description provided for @rename.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الاسم'**
  String get rename;

  /// No description provided for @youOwnIt.
  ///
  /// In ar, this message translates to:
  /// **'إنت صاحبه'**
  String get youOwnIt;

  /// No description provided for @ownedBy.
  ///
  /// In ar, this message translates to:
  /// **'صاحبه {name}'**
  String ownedBy(Object name);

  /// No description provided for @joinRequests.
  ///
  /// In ar, this message translates to:
  /// **'طلبات انضمام ({count})'**
  String joinRequests(Object count);

  /// No description provided for @removedBefore.
  ///
  /// In ar, this message translates to:
  /// **'اتشال من الجروب قبل كده'**
  String get removedBefore;

  /// No description provided for @onlineCount.
  ///
  /// In ar, this message translates to:
  /// **'متصلين دلوقتي ({count})'**
  String onlineCount(Object count);

  /// No description provided for @youName.
  ///
  /// In ar, this message translates to:
  /// **'إنت'**
  String get youName;

  /// No description provided for @ownerHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على أي عضو: رسالة خاصة، تخليه مدير، أو تشيله من الجروب. إنت صاحب الجروب ومحدش يقدر يشيلك.'**
  String get ownerHint;

  /// No description provided for @adminHint.
  ///
  /// In ar, this message translates to:
  /// **'إنت مدير: تقدر تشيل الأعضاء، تمسح رسايلهم، وتغيّر اسم الجروب.'**
  String get adminHint;

  /// No description provided for @memberHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على أي عضو عشان تكلمه شات خاص — مشفّر بينكم انتوا الاتنين بس، حتى باقي الجروب مش بيشوفه.'**
  String get memberHint;

  /// No description provided for @bannedCount.
  ///
  /// In ar, this message translates to:
  /// **'اتشالوا من الجروب ({count})'**
  String bannedCount(Object count);

  /// No description provided for @letBack.
  ///
  /// In ar, this message translates to:
  /// **'رجّعه'**
  String get letBack;

  /// No description provided for @groupMessagesErased.
  ///
  /// In ar, this message translates to:
  /// **'رسايل الجروب هتتمسح من موبايلك.'**
  String get groupMessagesErased;

  /// No description provided for @callStartNow.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نبدأ المكالمة دلوقتي'**
  String get callStartNow;

  /// No description provided for @messageGone.
  ///
  /// In ar, this message translates to:
  /// **'الرسالة دي مبقتش موجودة'**
  String get messageGone;

  /// No description provided for @noForwardTarget.
  ///
  /// In ar, this message translates to:
  /// **'مفيش محادثة متصلة دلوقتي تحوّل ليها'**
  String get noForwardTarget;

  /// No description provided for @forwardTo.
  ///
  /// In ar, this message translates to:
  /// **'تحويل لـ'**
  String get forwardTo;

  /// No description provided for @group.
  ///
  /// In ar, this message translates to:
  /// **'جروب'**
  String get group;

  /// No description provided for @privateChat.
  ///
  /// In ar, this message translates to:
  /// **'محادثة خاصة'**
  String get privateChat;

  /// No description provided for @forwardedTo.
  ///
  /// In ar, this message translates to:
  /// **'اتحوّلت لـ {name}'**
  String forwardedTo(Object name);

  /// No description provided for @statusSending.
  ///
  /// In ar, this message translates to:
  /// **'بتتبعت...'**
  String get statusSending;

  /// No description provided for @statusSentGroup.
  ///
  /// In ar, this message translates to:
  /// **'اتبعتت'**
  String get statusSentGroup;

  /// No description provided for @statusSent.
  ///
  /// In ar, this message translates to:
  /// **'اتبعتت ولسه موصلتش'**
  String get statusSent;

  /// No description provided for @statusDeliveredGroup.
  ///
  /// In ar, this message translates to:
  /// **'حد قراها'**
  String get statusDeliveredGroup;

  /// No description provided for @statusDelivered.
  ///
  /// In ar, this message translates to:
  /// **'وصلت'**
  String get statusDelivered;

  /// No description provided for @statusReadGroup.
  ///
  /// In ar, this message translates to:
  /// **'كل المتصلين قروها'**
  String get statusReadGroup;

  /// No description provided for @statusRead.
  ///
  /// In ar, this message translates to:
  /// **'اتقرت'**
  String get statusRead;

  /// No description provided for @statusFailed.
  ///
  /// In ar, this message translates to:
  /// **'متبعتتش'**
  String get statusFailed;

  /// No description provided for @messageInfo.
  ///
  /// In ar, this message translates to:
  /// **'معلومات الرسالة'**
  String get messageInfo;

  /// No description provided for @readByCount.
  ///
  /// In ar, this message translates to:
  /// **'قروها ({count})'**
  String readByCount(Object count);

  /// No description provided for @nobodyYet.
  ///
  /// In ar, this message translates to:
  /// **'لسه محدش'**
  String get nobodyYet;

  /// No description provided for @onlineNotReadCount.
  ///
  /// In ar, this message translates to:
  /// **'متصلين ولسه مقروهاش ({count})'**
  String onlineNotReadCount(Object count);

  /// No description provided for @codeMismatchTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرمز مختلف؟'**
  String get codeMismatchTitle;

  /// No description provided for @codeMismatchBody.
  ///
  /// In ar, this message translates to:
  /// **'ده معناه إن ممكن حد منتحل شخصية الطرف التاني. متبعتش حاجة حساسة، واحظره من القايمة لو مش متأكد منه.'**
  String get codeMismatchBody;

  /// No description provided for @unsaveChatTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء حفظ المحادثة؟'**
  String get unsaveChatTitle;

  /// No description provided for @unsaveChatBody.
  ///
  /// In ar, this message translates to:
  /// **'الرسايل هتتمسح من تخزين الموبايل، وهتفضل قدامك لحد ما تقفل التطبيق بس.'**
  String get unsaveChatBody;

  /// No description provided for @unsaveConfirm.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الحفظ'**
  String get unsaveConfirm;

  /// No description provided for @chatSavedEncryptedToast.
  ///
  /// In ar, this message translates to:
  /// **'المحادثة بتتحفظ على الموبايل (مشفّرة)'**
  String get chatSavedEncryptedToast;

  /// No description provided for @clearTitle.
  ///
  /// In ar, this message translates to:
  /// **'مسح الرسايل؟'**
  String get clearTitle;

  /// No description provided for @clearBody.
  ///
  /// In ar, this message translates to:
  /// **'الرسايل هتتمسح من عندك بس.'**
  String get clearBody;

  /// No description provided for @clear.
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get clear;

  /// No description provided for @blockDirectBody.
  ///
  /// In ar, this message translates to:
  /// **'مش هيقدر يبعتلك رسايل ولا هيظهر في القريبين. تقدر تلغي الحظر من الإعدادات.'**
  String get blockDirectBody;

  /// No description provided for @deleteChatQ.
  ///
  /// In ar, this message translates to:
  /// **'حذف المحادثة؟'**
  String get deleteChatQ;

  /// No description provided for @deleteChatBody.
  ///
  /// In ar, this message translates to:
  /// **'المحادثة ورسايلها هتتمسح من موبايلك.'**
  String get deleteChatBody;

  /// No description provided for @otherEmoji.
  ///
  /// In ar, this message translates to:
  /// **'إيموجي تاني'**
  String get otherEmoji;

  /// No description provided for @reply.
  ///
  /// In ar, this message translates to:
  /// **'رد'**
  String get reply;

  /// No description provided for @forward.
  ///
  /// In ar, this message translates to:
  /// **'تحويل'**
  String get forward;

  /// No description provided for @copy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get copy;

  /// No description provided for @privateMessageTo.
  ///
  /// In ar, this message translates to:
  /// **'رسالة خاصة لـ {name}'**
  String privateMessageTo(Object name);

  /// No description provided for @mentionName.
  ///
  /// In ar, this message translates to:
  /// **'منشن لـ {name}'**
  String mentionName(Object name);

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @deleteForBoth.
  ///
  /// In ar, this message translates to:
  /// **'حذف عندي وعنده'**
  String get deleteForBoth;

  /// No description provided for @deleteForAll.
  ///
  /// In ar, this message translates to:
  /// **'حذف عند الكل'**
  String get deleteForAll;

  /// No description provided for @deleteForAllAdmin.
  ///
  /// In ar, this message translates to:
  /// **'حذف عند الكل (إنت مدير)'**
  String get deleteForAllAdmin;

  /// No description provided for @deleteForMe.
  ///
  /// In ar, this message translates to:
  /// **'حذف عندي بس'**
  String get deleteForMe;

  /// No description provided for @editMessage.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الرسالة'**
  String get editMessage;

  /// No description provided for @typingOne.
  ///
  /// In ar, this message translates to:
  /// **'{name} بيكتب'**
  String typingOne(Object name);

  /// No description provided for @typingTwo.
  ///
  /// In ar, this message translates to:
  /// **'{a} و{b} بيكتبوا'**
  String typingTwo(Object a, Object b);

  /// No description provided for @typingMany.
  ///
  /// In ar, this message translates to:
  /// **'{count} بيكتبوا'**
  String typingMany(Object count);

  /// No description provided for @chatClosed.
  ///
  /// In ar, this message translates to:
  /// **'المحادثة اتقفلت'**
  String get chatClosed;

  /// No description provided for @noMembersNearby.
  ///
  /// In ar, this message translates to:
  /// **'مفيش حد من الأعضاء قريب دلوقتي'**
  String get noMembersNearby;

  /// No description provided for @membersOnline.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{{count} عضو متصلين دلوقتي} other{{count} أعضاء متصلين دلوقتي}}'**
  String membersOnline(int count);

  /// No description provided for @blocked.
  ///
  /// In ar, this message translates to:
  /// **'محظور'**
  String get blocked;

  /// No description provided for @encryptedVerified.
  ///
  /// In ar, this message translates to:
  /// **'مشفّرة • الرمز متأكد'**
  String get encryptedVerified;

  /// No description provided for @securing.
  ///
  /// In ar, this message translates to:
  /// **'بنأمّن الاتصال...'**
  String get securing;

  /// No description provided for @connecting.
  ///
  /// In ar, this message translates to:
  /// **'جاري الاتصال...'**
  String get connecting;

  /// No description provided for @videoCall.
  ///
  /// In ar, this message translates to:
  /// **'مكالمة فيديو'**
  String get videoCall;

  /// No description provided for @joinRequestsTooltip.
  ///
  /// In ar, this message translates to:
  /// **'طلبات انضمام'**
  String get joinRequestsTooltip;

  /// No description provided for @searchChat.
  ///
  /// In ar, this message translates to:
  /// **'بحث في المحادثة'**
  String get searchChat;

  /// No description provided for @membersAndInfo.
  ///
  /// In ar, this message translates to:
  /// **'الأعضاء ومعلومات الجروب'**
  String get membersAndInfo;

  /// No description provided for @safetyCodeOptional.
  ///
  /// In ar, this message translates to:
  /// **'رمز الأمان (اختياري)'**
  String get safetyCodeOptional;

  /// No description provided for @clearMessages.
  ///
  /// In ar, this message translates to:
  /// **'مسح الرسايل'**
  String get clearMessages;

  /// No description provided for @peerOfflineWifi.
  ///
  /// In ar, this message translates to:
  /// **'{name} مش على الشبكة دلوقتي. أول ما يفتح التطبيق على نفس الواي فاي هتقدر تكلمه.'**
  String peerOfflineWifi(Object name);

  /// No description provided for @peerOfflineBt.
  ///
  /// In ar, this message translates to:
  /// **'{name} مش قريب دلوقتي. أول ما يقرب ويفتح التطبيق هتقدر تكلمه.'**
  String peerOfflineBt(Object name);

  /// No description provided for @noDeviceNearby.
  ///
  /// In ar, this message translates to:
  /// **'مفيش أي جهاز قريب دلوقتي — الرسايل بتتبعت لما يبقى فيه حد واصلين له.'**
  String get noDeviceNearby;

  /// No description provided for @cancelSendingQ.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الإرسال؟'**
  String get cancelSendingQ;

  /// No description provided for @cancelReceivingQ.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الاستلام؟'**
  String get cancelReceivingQ;

  /// No description provided for @cancelSendingBody.
  ///
  /// In ar, this message translates to:
  /// **'الملف هيتشال من المحادثة عندك وعند الطرف التاني.'**
  String get cancelSendingBody;

  /// No description provided for @cancelReceivingBody.
  ///
  /// In ar, this message translates to:
  /// **'الملف هيتشال من عندك ومش هيكمّل.'**
  String get cancelReceivingBody;

  /// No description provided for @cancelTransfer.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء النقل'**
  String get cancelTransfer;

  /// No description provided for @notificationsBack.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات رجعت للمحادثة دي'**
  String get notificationsBack;

  /// No description provided for @muteHour.
  ///
  /// In ar, this message translates to:
  /// **'ساعة'**
  String get muteHour;

  /// No description provided for @mute8Hours.
  ///
  /// In ar, this message translates to:
  /// **'8 ساعات'**
  String get mute8Hours;

  /// No description provided for @muteWeek.
  ///
  /// In ar, this message translates to:
  /// **'أسبوع'**
  String get muteWeek;

  /// No description provided for @muteAlways.
  ///
  /// In ar, this message translates to:
  /// **'دايماً'**
  String get muteAlways;

  /// No description provided for @mutedGroupToast.
  ///
  /// In ar, this message translates to:
  /// **'اتكتم — المنشن بس هو اللي هيبعتلك إشعار'**
  String get mutedGroupToast;

  /// No description provided for @mutedToast.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات المحادثة دي اتكتمت'**
  String get mutedToast;

  /// No description provided for @closeSearch.
  ///
  /// In ar, this message translates to:
  /// **'قفل البحث'**
  String get closeSearch;

  /// No description provided for @searchInChat.
  ///
  /// In ar, this message translates to:
  /// **'دوّر في المحادثة'**
  String get searchInChat;

  /// No description provided for @none.
  ///
  /// In ar, this message translates to:
  /// **'مفيش'**
  String get none;

  /// No description provided for @older.
  ///
  /// In ar, this message translates to:
  /// **'الأقدم'**
  String get older;

  /// No description provided for @newer.
  ///
  /// In ar, this message translates to:
  /// **'الأحدث'**
  String get newer;

  /// No description provided for @startGroupTalk.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الكلام في الجروب'**
  String get startGroupTalk;

  /// No description provided for @sayHello.
  ///
  /// In ar, this message translates to:
  /// **'قول أهلاً 👋'**
  String get sayHello;

  /// No description provided for @emptyGroupEnc.
  ///
  /// In ar, this message translates to:
  /// **'رسايل الجروب مشفّرة بمفتاحه ومبتعدّيش على أي سيرفر.'**
  String get emptyGroupEnc;

  /// No description provided for @emptyDirectEnc.
  ///
  /// In ar, this message translates to:
  /// **'الرسايل مشفّرة من طرف لطرف تلقائياً — من غير كلمة سر ومن غير إنترنت.'**
  String get emptyDirectEnc;

  /// No description provided for @emptySaved.
  ///
  /// In ar, this message translates to:
  /// **'المحادثة دي بتتحفظ على موبايلك.'**
  String get emptySaved;

  /// No description provided for @emptyNotSaved.
  ///
  /// In ar, this message translates to:
  /// **'المحادثة دي مش بتتحفظ: هتتمسح لما تقفل التطبيق.'**
  String get emptyNotSaved;

  /// No description provided for @notFinished.
  ///
  /// In ar, this message translates to:
  /// **'مكملش'**
  String get notFinished;

  /// No description provided for @chatEncryptedSystem.
  ///
  /// In ar, this message translates to:
  /// **'المحادثة مشفرة من طرف لطرف 🔒'**
  String get chatEncryptedSystem;

  /// No description provided for @safetyVerifiedSystem.
  ///
  /// In ar, this message translates to:
  /// **'تم التحقق من رمز الأمان ✓'**
  String get safetyVerifiedSystem;

  /// No description provided for @previewPhoto.
  ///
  /// In ar, this message translates to:
  /// **'📷 صورة'**
  String get previewPhoto;

  /// No description provided for @previewVideo.
  ///
  /// In ar, this message translates to:
  /// **'🎥 فيديو'**
  String get previewVideo;

  /// No description provided for @previewVoice.
  ///
  /// In ar, this message translates to:
  /// **'🎤 رسالة صوتية'**
  String get previewVoice;

  /// No description provided for @previewFile.
  ///
  /// In ar, this message translates to:
  /// **'📄 {name}'**
  String previewFile(Object name);

  /// No description provided for @sizeGb.
  ///
  /// In ar, this message translates to:
  /// **'{n} جيجا'**
  String sizeGb(Object n);

  /// No description provided for @sizeMb.
  ///
  /// In ar, this message translates to:
  /// **'{n} ميجا'**
  String sizeMb(Object n);

  /// No description provided for @readFileFromPhoneFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نقرا الملف من الموبايل'**
  String get readFileFromPhoneFailed;

  /// No description provided for @peerGotCorrupt.
  ///
  /// In ar, this message translates to:
  /// **'وصل بايظ عند التاني — ابعته تاني'**
  String get peerGotCorrupt;

  /// No description provided for @peerCanceledReceive.
  ///
  /// In ar, this message translates to:
  /// **'التاني لغى الاستلام'**
  String get peerCanceledReceive;

  /// No description provided for @personNearby.
  ///
  /// In ar, this message translates to:
  /// **'شخص قريب'**
  String get personNearby;

  /// No description provided for @groupCreatedOpen.
  ///
  /// In ar, this message translates to:
  /// **'الجروب اتعمل — أي حد قريب يقدر يدخل'**
  String get groupCreatedOpen;

  /// No description provided for @groupCreatedPassword.
  ///
  /// In ar, this message translates to:
  /// **'الجروب اتعمل — الدخول بكلمة السر'**
  String get groupCreatedPassword;

  /// No description provided for @groupCreatedAsk.
  ///
  /// In ar, this message translates to:
  /// **'الجروب اتعمل — الدخول بموافقتك'**
  String get groupCreatedAsk;

  /// No description provided for @networkNotRunning.
  ///
  /// In ar, this message translates to:
  /// **'الشبكة مش شغالة'**
  String get networkNotRunning;

  /// No description provided for @wrongPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة السر غلط'**
  String get wrongPassword;

  /// No description provided for @groupNeedsApproval.
  ///
  /// In ar, this message translates to:
  /// **'الجروب ده محتاج موافقة صاحبه'**
  String get groupNeedsApproval;

  /// No description provided for @ownerOffline.
  ///
  /// In ar, this message translates to:
  /// **'صاحب الجروب مش متصل دلوقتي — جرّب لما يكون قريب'**
  String get ownerOffline;

  /// No description provided for @sendRequestFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفناش نبعت الطلب'**
  String get sendRequestFailed;

  /// No description provided for @notAllowed.
  ///
  /// In ar, this message translates to:
  /// **'مش من صلاحياتك'**
  String get notAllowed;

  /// No description provided for @noConnectionNow.
  ///
  /// In ar, this message translates to:
  /// **'مفيش اتصال دلوقتي'**
  String get noConnectionNow;

  /// No description provided for @youKicked.
  ///
  /// In ar, this message translates to:
  /// **'شلت {name} من الجروب'**
  String youKicked(Object name);

  /// No description provided for @ownerOnly.
  ///
  /// In ar, this message translates to:
  /// **'صاحب الجروب بس اللي يقدر يعمل كده'**
  String get ownerOnly;

  /// No description provided for @maxAdmins.
  ///
  /// In ar, this message translates to:
  /// **'وصلت لأقصى عدد مديرين'**
  String get maxAdmins;

  /// No description provided for @youMadeAdmin.
  ///
  /// In ar, this message translates to:
  /// **'خليت {name} مدير'**
  String youMadeAdmin(Object name);

  /// No description provided for @youRemovedAdmin.
  ///
  /// In ar, this message translates to:
  /// **'شلت {name} من الإدارة'**
  String youRemovedAdmin(Object name);

  /// No description provided for @adminsOnlyRename.
  ///
  /// In ar, this message translates to:
  /// **'المديرين بس اللي يقدروا يغيّروا الاسم'**
  String get adminsOnlyRename;

  /// No description provided for @youRenamed.
  ///
  /// In ar, this message translates to:
  /// **'غيّرت اسم الجروب لـ \"{name}\"'**
  String youRenamed(Object name);

  /// No description provided for @removedFromGroupNotice.
  ///
  /// In ar, this message translates to:
  /// **'اتشلت من جروب \"{name}\"'**
  String removedFromGroupNotice(Object name);

  /// No description provided for @byKicked.
  ///
  /// In ar, this message translates to:
  /// **'{by} شال {who} من الجروب'**
  String byKicked(Object by, Object who);

  /// No description provided for @youBecameAdmin.
  ///
  /// In ar, this message translates to:
  /// **'بقيت مدير في الجروب'**
  String get youBecameAdmin;

  /// No description provided for @becameAdmin.
  ///
  /// In ar, this message translates to:
  /// **'{name} بقى مدير'**
  String becameAdmin(Object name);

  /// No description provided for @youNoLongerAdmin.
  ///
  /// In ar, this message translates to:
  /// **'مبقتش مدير في الجروب'**
  String get youNoLongerAdmin;

  /// No description provided for @noLongerAdmin.
  ///
  /// In ar, this message translates to:
  /// **'{name} مبقاش مدير'**
  String noLongerAdmin(Object name);

  /// No description provided for @byRenamed.
  ///
  /// In ar, this message translates to:
  /// **'{by} غيّر اسم الجروب لـ \"{name}\"'**
  String byRenamed(Object by, Object name);

  /// No description provided for @mentionedYou.
  ///
  /// In ar, this message translates to:
  /// **'منشن ليك: {text}'**
  String mentionedYou(Object text);

  /// No description provided for @reactedOn.
  ///
  /// In ar, this message translates to:
  /// **'تفاعل بـ {emoji} على: \"{text}\"'**
  String reactedOn(Object emoji, Object text);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
