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
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: ActivitySelectionSurface(
        selected: selected,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              minHeight: 108, minWidth: AppSizes.touchTarget),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _ActivityIcon(icon: icon),
                  const Spacer(),
                  ActivitySelectionIndicator(selected: selected),
                ]),
                const SizedBox(height: AppSpacing.sm),
                Text(label,
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600)),
                if (description != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(description!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityIcon extends StatelessWidget {
  const _ActivityIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          shape: BoxShape.circle),
      child:
          Icon(icon, size: 30, color: Theme.of(context).colorScheme.onSurface));
}

/// Shared selected treatment for the activity and recording-mode controls.
class ActivitySelectionSurface extends StatelessWidget {
  const ActivitySelectionSurface(
      {super.key,
      required this.selected,
      required this.onTap,
      required this.child});
  final bool selected;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surface = theme.brightness == Brightness.light
        ? scheme.surface
        : scheme.surfaceContainer;
    final radius = BorderRadius.circular(AppRadii.panel);
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  scheme.primary.withValues(alpha: 0.08), surface)
              : surface,
          borderRadius: radius,
          border: Border.all(
              width: 1.5,
              color: selected
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.16))),
      child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, borderRadius: radius, child: child)),
    );
  }
}

class ActivitySelectionIndicator extends StatelessWidget {
  const ActivitySelectionIndicator({super.key, required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
        child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? scheme.primary : null,
                border: Border.all(
                    color:
                        selected ? scheme.onPrimary : scheme.onSurfaceVariant)),
            child: selected
                ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                : null));
  }
}
