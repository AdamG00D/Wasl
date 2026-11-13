import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// النصوص جوه الشاشات: `context.l10n.x` — بتتبني تاني لوحدها لما اللغة تتغير.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// النصوص في الكود اللي ملوش context (الـ hub، الجلسة، رسايل النظام، الأخطاء).
AppLocalizations get tr => L10n.current;

class L10n {
  L10n._();

  static const supported = [Locale('ar'), Locale('en')];

  static AppLocalizations current = lookupAppLocalizations(const Locale('ar'));

  /// العربي لو لغة الجهاز عربي، وأي لغة تانية إنجليزي.
  static Locale resolve(Locale? device) =>
      device?.languageCode == 'ar' ? const Locale('ar') : const Locale('en');

  /// [code]: 'ar' / 'en' أو null = لغة الجهاز.
  static Locale pick(String? code, Locale? device) => code == null ? resolve(device) : Locale(code);

  /// بيرجّع true لو اللغة اتغيرت فعلاً.
  static bool use(Locale locale) {
    if (current.localeName == locale.languageCode) return false;
    current = lookupAppLocalizations(locale);
    return true;
  }
}
