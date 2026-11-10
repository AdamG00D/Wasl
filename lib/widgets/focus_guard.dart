import 'package:flutter/widgets.dart';

/// يقفل الكيبورد صح: بيفك التركيز من خانة الكتابة **وبيمسح ذاكرة الصفحة** ليها.
///
/// `FocusScope.of(context).unfocus()` بيقفل الكيبورد بس الصفحة بتفضل فاكرة آخر
/// خانة، فأول ما أي نافذة فوقها تتقفل (تأكيد، QR، قائمة...) Flutter بيرجّع
/// التركيز للخانة دي والكيبورد يفتح لوحده. هنا بنفك التركيز من الخانة نفسها
/// فالصفحة بتنساها.
void hideKeyboard() {
  final focus = FocusManager.instance.primaryFocus;
  if (focus != null && focus is! FocusScopeNode) focus.unfocus();
}

/// يمنع الكيبورد إنه يفتح لوحده لما ترجع لصفحة — في التطبيق كله.
///
/// أول ما أي صفحة أو نافذة أو قائمة تفتح، بنقفل الكيبورد ونمسح "الذاكرة"
/// بتاعة الصفحة اللي تحتها، فلما النافذة تتقفل الكيبورد ميرجعش.
class FocusGuard extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => hideKeyboard();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => hideKeyboard();
}
