import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLocaleOverrideProvider =
    NotifierProvider<AppLocaleOverrideNotifier, Locale?>(
      AppLocaleOverrideNotifier.new,
    );

class AppLocaleOverrideNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  void setLocale(Locale? locale) {
    state = locale;
  }
}

