import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color? color;
  final bool prominent;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.color,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = PathCraftColors.of(context);
    final fill =
        prominent ? tokens.metricPanel : theme.colorScheme.surfaceContainerLow;
    final ink = prominent ? tokens.onMetricPanel : theme.colorScheme.onSurface;
    final accent = KaripaPalette.approvedOr(color, tokens.accent);

    return Semantics(
      label: '$label: $value${unit == null ? '' : ' $unit'}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadii.panel),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(AppRadii.control)),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Icon(icon,
                        size: AppSizes.compactIcon,
                        color: KaripaPalette.onFill(accent)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(label,
                  style: theme.textTheme.labelMedium?.copyWith(color: ink)),
              const SizedBox(height: AppSpacing.sm),
              Text(value,
                  style: (prominent
                          ? theme.textTheme.displayMedium
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(
                    color: ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              if (unit != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(unit!,
                    style: theme.textTheme.bodySmall?.copyWith(color: ink)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
