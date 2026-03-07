import 'package:flutter/material.dart';

import 'screens/atlas_home_page.dart';

void main() {
  runApp(const ChinaDynastyAtlasApp());
}

class ChinaDynastyAtlasApp extends StatelessWidget {
  const ChinaDynastyAtlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9B5B32),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: '中国王朝图谱',
      debugShowCheckedModeBanner: false,
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
