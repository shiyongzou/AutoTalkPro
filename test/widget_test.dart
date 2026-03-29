import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tg_ai_sales_desktop/app/app_context.dart';
import 'package:tg_ai_sales_desktop/main.dart';

void _setDesktopSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1600, 1000);
}

void _resetSurface(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  testWidgets('desktop app smoke test', (WidgetTester tester) async {
    _setDesktopSurface(tester);
    addTearDown(() => _resetSurface(tester));

    final appContext = await AppContext.testing();
    await tester.pumpWidget(TgAiSalesApp(contextOverride: appContext));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

    await appContext.database.close();
  });
}
