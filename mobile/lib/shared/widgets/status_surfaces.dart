import 'package:flutter/material.dart';

enum AppStatusTone { success, info, warning, error, neutral }

class AppStatusPalette {
  const AppStatusPalette({
    required this.background,
    required this.foreground,
    required this.border,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final IconData icon;

  static AppStatusPalette resolve(BuildContext context, AppStatusTone tone) {
    final scheme = Theme.of(context).colorScheme;

    switch (tone) {
      case AppStatusTone.success:
        return const AppStatusPalette(
          background: Color(0xFFEAF8F0),
          foreground: Color(0xFF067647),
          border: Color(0xFFCDEAD7),
          icon: Icons.check_circle_outline_rounded,
        );
      case AppStatusTone.info:
        return const AppStatusPalette(
          background: Color(0xFFEAF1FF),
          foreground: Color(0xFF2F6BFF),
          border: Color(0xFFD7E4FF),
          icon: Icons.info_outline_rounded,
        );
      case AppStatusTone.warning:
        return const AppStatusPalette(
          background: Color(0xFFFFF4D8),
          foreground: Color(0xFFC27B00),
          border: Color(0xFFF6E2A6),
          icon: Icons.warning_amber_rounded,
        );
      case AppStatusTone.error:
        return AppStatusPalette(
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
          border: scheme.error.withValues(alpha: 0.16),
          icon: Icons.error_outline_rounded,
        );
      case AppStatusTone.neutral:
        return const AppStatusPalette(
          background: Color(0xFFF7F8FC),
          foreground: Color(0xFF667085),
          border: Color(0xFFE7EBF3),
          icon: Icons.inbox_outlined,
        );
    }
  }
}

class AppInlineNotice extends StatelessWidget {
  const AppInlineNotice({
    super.key,
    required this.message,
    this.tone = AppStatusTone.info,
    this.margin,
  });

  final String message;
  final AppStatusTone tone;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final palette = AppStatusPalette.resolve(context, tone);

    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(palette.icon, size: 18, color: palette.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class AppEmptyStateCard extends StatelessWidget {
  const AppEmptyStateCard({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = AppStatusPalette.resolve(context, AppStatusTone.neutral);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: palette.foreground),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

void showAppStatusSnackBar(
  BuildContext context, {
  required String message,
  AppStatusTone tone = AppStatusTone.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final palette = AppStatusPalette.resolve(context, tone);
  final messenger = ScaffoldMessenger.maybeOf(context);

  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.background,
      content: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: palette.foreground),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: palette.border),
      ),
      action: actionLabel == null || onAction == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction),
    ),
  );
}
