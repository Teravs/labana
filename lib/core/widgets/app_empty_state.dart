import 'package:flutter/material.dart';

/// Komponen empty state visual terpusat yang reusable.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 38, color: colorScheme.primary),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withAlpha(170),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onActionPressed != null) ...[
                const SizedBox(height: 24),
                if (actionLabel!.startsWith('+'))
                  FilledButton(
                    onPressed: onActionPressed,
                    child: Text(actionLabel!),
                  )
                else
                  FilledButton.icon(
                    onPressed: onActionPressed,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(actionLabel!),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
