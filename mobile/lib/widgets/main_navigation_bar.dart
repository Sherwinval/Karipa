import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class MainNavigationBar extends StatelessWidget {
  const MainNavigationBar(
      {super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _destinations = [
    ('Home', Icons.dashboard_outlined, Icons.dashboard),
    ('Leaderboard', Icons.leaderboard_outlined, Icons.leaderboard),
    ('History', Icons.history_outlined, Icons.history),
    ('Profile', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall!.copyWith(
      fontSize: 12,
      letterSpacing: 0,
    );
    return Material(
      color: scheme.surface,
      shape: Border(
          top: BorderSide(
              color: Color.alphaBlend(
                  scheme.onSurface.withValues(alpha: 0.16), scheme.surface))),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widestLabel = TextPainter(
              text: TextSpan(text: _destinations[1].$1, style: labelStyle),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final useTwoRows =
                widestLabel.width + AppSpacing.sm > constraints.maxWidth / 4;
            widestLabel.dispose();
            if (useTwoRows) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _row(context, labelStyle, 0, 2),
                  _row(context, labelStyle, 2, 4),
                ],
              );
            }
            return _row(context, labelStyle, 0, _destinations.length);
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, TextStyle style, int start, int end) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = start; index < end; index++)
            Expanded(child: _destination(context, index, style)),
        ],
      ),
    );
  }

  Widget _destination(BuildContext context, int index, TextStyle style) {
    final (label, icon, selectedIcon) = _destinations[index];
    final selected = index == currentIndex;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: () => onTap(index),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: selected
                      ? ShapeDecoration(
                          color: scheme.primary, shape: const StadiumBorder())
                      : null,
                  child: Icon(selected ? selectedIcon : icon,
                      size: AppSizes.compactIcon,
                      color: selected
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(label,
                    textAlign: TextAlign.center,
                    style: style.copyWith(
                      color:
                          selected ? scheme.onSurface : scheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w800 : null,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
