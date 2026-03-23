import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_l10n.dart';
import 'screens/atlas_home_page.dart';
import 'state/app_settings.dart';

void main() {
  runApp(const ChinaDynastyAtlasApp());
}

class ChinaDynastyAtlasApp extends StatelessWidget {
  const ChinaDynastyAtlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _AppRoot());
  }
}

class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9B5B32),
      brightness: Brightness.light,
    );
    final localeOverride = ref.watch(appLocaleOverrideProvider);

    return MaterialApp(
      onGenerateTitle: (context) => AppL10n.of(context).appTitle,
      title: 'China Dynasty Atlas',
      debugShowCheckedModeBanner: false,
      locale: localeOverride,
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF7F1E4),
        cardTheme: const CardThemeData(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        useMaterial3: true,
      ),
      home: const AtlasHomePage(),
    );
  }
}
