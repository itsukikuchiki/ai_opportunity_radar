import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? summary;
  final String? preferenceText;
  final VoidCallback? onTapPreference;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.summary,
    this.preferenceText,
    this.onTapPreference,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (summary != null && summary!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary!,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (preferenceText != null && preferenceText!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTapPreference,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        preferenceText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (onTapPreference != null) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
