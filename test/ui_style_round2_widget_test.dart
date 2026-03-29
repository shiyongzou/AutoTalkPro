import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_ai_sales_desktop/app/ui/app_theme.dart';
import 'package:tg_ai_sales_desktop/app/ui/app_widgets.dart';

void main() {
  testWidgets('AppSurfaceCard follows theme surface and corner token', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: AppSurfaceCard(child: Text('content'))),
      ),
    );

    final context = tester.element(find.byType(AppSurfaceCard));
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    final card = tester.widget<Card>(
      find.descendant(
        of: find.byType(AppSurfaceCard),
        matching: find.byType(Card),
      ),
    );
    final borderRadius = switch (card.shape) {
      RoundedRectangleBorder(:final borderRadius) => borderRadius,
      _ => null,
    };

    expect(card.color, tokens.surfaceElevated);
    expect(borderRadius, isA<BorderRadius>());
    expect((borderRadius! as BorderRadius).topLeft.x, tokens.cornerMd);
  });

  testWidgets('AppMetricTile uses warning tone token for value color', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppMetricTile(
            label: '风险占比',
            value: '42%',
            tone: AppStatusTone.warning,
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(AppMetricTile));
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final valueText = tester.widget<Text>(find.text('42%'));

    expect(valueText.style?.color, tokens.warning);
    expect(valueText.style?.fontWeight, FontWeight.w700);
  });
}
