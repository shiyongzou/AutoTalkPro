import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_ai_sales_desktop/app/ui/app_theme.dart';
import 'package:tg_ai_sales_desktop/app/ui/app_widgets.dart';

void main() {
  testWidgets('theme exposes design tokens and button radius', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            final tokens = theme.extension<AppThemeTokens>();
            expect(tokens, isNotNull);
            expect(tokens!.cornerMd, 12);
            expect(tokens.spaceXl, 24);

            final shape = theme.filledButtonTheme.style?.shape?.resolve({});
            final rounded = shape as RoundedRectangleBorder;
            final radius = rounded.borderRadius as BorderRadius;
            expect(radius.topLeft.x, 8);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('status tag uses success tone color token', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppStatusTag(label: 'Healthy', tone: AppStatusTone.success),
        ),
      ),
    );

    final context = tester.element(find.byType(AppStatusTag));
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final container = tester.widget<Container>(
      find.byKey(const ValueKey('app_status_tag_container')),
    );
    final decoration = container.decoration as BoxDecoration;

    expect(find.text('Healthy'), findsOneWidget);
    expect(decoration.color, tokens.success.withValues(alpha: 0.14));
  });

  testWidgets('navigation rail uses indicator color token', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            final tokens = theme.extension<AppThemeTokens>()!;
            expect(
              theme.navigationRailTheme.indicatorColor,
              tokens.navIndicator,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
}
