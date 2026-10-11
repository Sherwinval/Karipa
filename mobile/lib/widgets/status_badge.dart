import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;

  const StatusBadge({super.key, required this.text, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final fill = KaripaPalette.approvedOr(color, KaripaPalette.stone);
    final ink = KaripaPalette.onFill(fill);
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(color: ink),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSizes.compactIcon, color: ink),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                  child: Text(text,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: ink))),
            ],
          ),
        ),
      ),
    );
  }
}
