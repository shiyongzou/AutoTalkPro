import 'package:flutter/material.dart';

import 'app_theme.dart';

enum AppStatusTone { neutral, success, warning, danger }

class AppPanelHeader extends StatelessWidget {
  const AppPanelHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final trailingWidgets = trailing == null
        ? const <Widget>[]
        : <Widget>[trailing!];

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null) ...[
                  SizedBox(height: tokens.spaceXs),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          ...trailingWidgets,
        ],
      ),
    );
  }
}

class AppStatusTag extends StatelessWidget {
  const AppStatusTag({
    required this.label,
    this.tone = AppStatusTone.neutral,
    super.key,
  });

  final String label;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    final (fg, bg) = switch (tone) {
      AppStatusTone.success => (
        tokens.success,
        tokens.success.withValues(alpha: 0.14),
      ),
      AppStatusTone.warning => (
        tokens.warning,
        tokens.warning.withValues(alpha: 0.16),
      ),
      AppStatusTone.danger => (
        tokens.danger,
        tokens.danger.withValues(alpha: 0.16),
      ),
      AppStatusTone.neutral => (
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.surfaceContainerHighest,
      ),
    };

    return Container(
      key: const ValueKey('app_status_tag_container'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(tokens.cornerSm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    return Card(
      color: tokens.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cornerMd),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppMetricTile extends StatelessWidget {
  const AppMetricTile({
    required this.label,
    required this.value,
    this.tone = AppStatusTone.neutral,
    super.key,
  });

  final String label;
  final String value;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    final accent = switch (tone) {
      AppStatusTone.success => tokens.success,
      AppStatusTone.warning => tokens.warning,
      AppStatusTone.danger => tokens.danger,
      AppStatusTone.neutral => theme.colorScheme.primary,
    };

    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          SizedBox(height: tokens.spaceXs),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
