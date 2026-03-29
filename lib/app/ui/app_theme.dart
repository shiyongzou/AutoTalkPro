import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.navBackground,
    required this.navIndicator,
    required this.surfaceMuted,
    required this.surfaceElevated,
    required this.success,
    required this.warning,
    required this.danger,
    required this.cornerSm,
    required this.cornerMd,
    required this.cornerLg,
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
  });

  final Color navBackground;
  final Color navIndicator;
  final Color surfaceMuted;
  final Color surfaceElevated;
  final Color success;
  final Color warning;
  final Color danger;

  final double cornerSm;
  final double cornerMd;
  final double cornerLg;

  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;

  @override
  AppThemeTokens copyWith({
    Color? navBackground,
    Color? navIndicator,
    Color? surfaceMuted,
    Color? surfaceElevated,
    Color? success,
    Color? warning,
    Color? danger,
    double? cornerSm,
    double? cornerMd,
    double? cornerLg,
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
  }) {
    return AppThemeTokens(
      navBackground: navBackground ?? this.navBackground,
      navIndicator: navIndicator ?? this.navIndicator,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      cornerSm: cornerSm ?? this.cornerSm,
      cornerMd: cornerMd ?? this.cornerMd,
      cornerLg: cornerLg ?? this.cornerLg,
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) {
      return this;
    }
    return AppThemeTokens(
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
      navIndicator: Color.lerp(navIndicator, other.navIndicator, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      cornerSm: lerpDouble(cornerSm, other.cornerSm, t)!,
      cornerMd: lerpDouble(cornerMd, other.cornerMd, t)!,
      cornerLg: lerpDouble(cornerLg, other.cornerLg, t)!,
      spaceXs: lerpDouble(spaceXs, other.spaceXs, t)!,
      spaceSm: lerpDouble(spaceSm, other.spaceSm, t)!,
      spaceMd: lerpDouble(spaceMd, other.spaceMd, t)!,
      spaceLg: lerpDouble(spaceLg, other.spaceLg, t)!,
      spaceXl: lerpDouble(spaceXl, other.spaceXl, t)!,
    );
  }
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2455F5),
      brightness: Brightness.light,
    );
    const tokens = AppThemeTokens(
      navBackground: Color(0xFFF5F7FB),
      navIndicator: Color(0xFFE3EBFF),
      surfaceMuted: Color(0xFFF3F5FA),
      surfaceElevated: Color(0xFFFFFFFF),
      success: Color(0xFF198754),
      warning: Color(0xFFE39A1C),
      danger: Color(0xFFDC3545),
      cornerSm: 8,
      cornerMd: 12,
      cornerLg: 16,
      spaceXs: 4,
      spaceSm: 8,
      spaceMd: 12,
      spaceLg: 16,
      spaceXl: 24,
    );
    return _buildTheme(scheme, tokens);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5D8CFF),
      brightness: Brightness.dark,
    );
    const tokens = AppThemeTokens(
      navBackground: Color(0xFF121826),
      navIndicator: Color(0xFF24314A),
      surfaceMuted: Color(0xFF1A2233),
      surfaceElevated: Color(0xFF161F30),
      success: Color(0xFF2FB878),
      warning: Color(0xFFE8B74A),
      danger: Color(0xFFFF6B77),
      cornerSm: 8,
      cornerMd: 12,
      cornerLg: 16,
      spaceXs: 4,
      spaceSm: 8,
      spaceMd: 12,
      spaceLg: 16,
      spaceXl: 24,
    );
    return _buildTheme(scheme, tokens);
  }

  static ThemeData _buildTheme(ColorScheme scheme, AppThemeTokens tokens) {
    final baseText = scheme.brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;
    final textTheme = baseText.copyWith(
      displaySmall: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
      headlineSmall: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
      titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      titleSmall: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
      bodyMedium: const TextStyle(fontSize: 15, height: 1.5),
      bodySmall: const TextStyle(fontSize: 13, height: 1.4),
      labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      labelMedium: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      labelSmall: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      visualDensity: VisualDensity.compact,
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      extensions: [tokens],
      scaffoldBackgroundColor: scheme.surface,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.navBackground,
        indicatorColor: tokens.navIndicator,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
        groupAlignment: -1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: tokens.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cornerMd),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.cornerSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.cornerSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: tokens.surfaceMuted,
        // 确保夜间模式下文字和hint可见
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 14),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.cornerSm),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.cornerSm),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.cornerSm),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cornerSm),
        ),
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cornerSm),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.55),
        thickness: 1,
      ),
    );
  }
}
