import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:china_dynasty_atlas/main.dart';
import 'package:china_dynasty_atlas/screens/atlas_home_page.dart';

void main() {
  testWidgets('app loads dynasty atlas shell', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ChinaDynastyAtlasApp());
    await tester.pump();

    expect(find.byType(AtlasHomePage), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));

    final hasAtlasTitle = find.text('中国王朝图谱').evaluate().isNotEmpty;
    final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    expect(hasAtlasTitle || hasLoading, isTrue);
  });
}
