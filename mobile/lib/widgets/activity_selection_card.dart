import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Takes the existing activity label/icon and callback; does not select a mode.
class ActivitySelectionCard extends StatelessWidget {
  final String label;
  final String? description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const ActivitySelectionCard(
      {super.key,
      required this.label,
      required this.icon,
      required this.selected,
      required this.onTap,
      this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fill = selected ? scheme.primary : scheme.surfaceContainerLow;
    final ink = selected ? scheme.onPrimary : scheme.onSurface;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.panel),
      side: BorderSide(color: scheme.outline, width: selected ? 2 : 1),
    );
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Material(
        color: fill,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
                minHeight: AppSizes.buttonHeight,
                minWidth: AppSizes.touchTarget),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, color: ink),
                    const Spacer(),
                    if (selected) Icon(Icons.check_circle, color: ink),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  Text(label,
                      style: theme.textTheme.titleMedium?.copyWith(color: ink)),
                  if (description != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(description!,
                        style: theme.textTheme.bodySmall?.copyWith(color: ink)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
