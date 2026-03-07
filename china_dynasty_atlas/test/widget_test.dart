import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:china_dynasty_atlas/main.dart';

void main() {
  testWidgets('app loads dynasty atlas shell', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ChinaDynastyAtlasApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('中国王朝图谱'), findsOneWidget);
    expect(find.text('时间轴'), findsOneWidget);
  });
}
