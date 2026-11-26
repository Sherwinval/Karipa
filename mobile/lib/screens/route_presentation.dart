import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/route_model.dart';
import '../services/unit_preferences.dart';
import '../theme/design_tokens.dart';

String routeActivityLabel(String activity) => activity.isEmpty
    ? 'Activity'
    : '${activity[0].toUpperCase()}${activity.substring(1).toLowerCase()}';

String? routeShapeLabel(PathRoute route) {
  final isLoop = route.features['isLoop'];
  if (isLoop == true) return 'Loop';
  // The service also normalizes missing loop flags to false.
  if (isLoop == false &&
      route.name
          .trim()
          .toLowerCase()
          .startsWith('valhalla generated out-and-back')) {
    return 'Out-and-back';
  }
  return null;
}

String routeDisplayName(PathRoute route) {
  final name = route.name.trim();
  final normalized = name.toLowerCase();
  if (name.isNotEmpty &&
      normalized != 'valhalla route' &&
      !normalized.startsWith('valhalla generated ')) {
    return name;
  }
  final shape = routeShapeLabel(route);
  return shape == null ? 'Generated route' : '$shape route';
}

String routeTargetComparison(
  PathRoute route,
  UnitPreferences units, {
  double? requestedTargetKm,
  bool targetFirst = false,
}) {
  final targetKm = requestedTargetKm ?? route.targetDistanceKm;
  if (targetKm <= 0) return 'Requested target unavailable';

  final target = units.formatDistance(targetKm);
  final deltaKm = route.distanceKm - targetKm;
  if (deltaKm == 0) return 'Matches your $target target';

  final deviationKm = targetKm == route.targetDistanceKm
      ? route.absoluteDistanceDeviationKm
      : deltaKm.abs();
  final deviation =
      units.distanceFromKm(deviationKm).toStringAsFixed(2) == '0.00'
          ? 'less than 0.01 ${units.distanceUnit}'
          : units.formatDistance(deviationKm);
  if (targetFirst) {
    return 'Target $target · $deviation ${deltaKm > 0 ? 'longer' : 'shorter'}';
  }
  final comparison = '${deviation[0].toUpperCase()}${deviation.substring(1)}';
  return '$comparison ${deltaKm > 0 ? 'above' : 'below'} your $target target';
}

double routePageInset(double width) => math.max(
      AppSpacing.pageMargin(width),
      (width - AppSizes.contentMaxWidth) / 2,
    );

AppBar routeAppBar(BuildContext context, String title, {Widget? action}) {
  final theme = Theme.of(context);
  final titleStyle =
      theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge;
  final textScaler = MediaQuery.textScalerOf(context);
  final titleSpacing =
      textScaler.scale(16) > 22 ? AppSpacing.xs : AppSpacing.lg;
  final actionWidth =
      action == null ? 0.0 : AppSizes.touchTarget + AppSpacing.sm;
  final availableWidth = MediaQuery.sizeOf(context).width -
      MediaQuery.paddingOf(context).horizontal -
      AppSizes.buttonHeight -
      actionWidth -
      2 * titleSpacing;
  final titleLayout = TextPainter(
    text: TextSpan(text: title, style: titleStyle),
    textScaler: textScaler,
    textDirection: Directionality.of(context),
  )..layout(maxWidth: math.max(1, availableWidth));
  final toolbarHeight = math.max(
    AppSizes.buttonHeight,
    titleLayout.height + 2 * AppSpacing.xs,
  );
  titleLayout.dispose();

  return AppBar(
    toolbarHeight: toolbarHeight,
    titleSpacing: titleSpacing,
    title: Text(title, softWrap: true, overflow: TextOverflow.visible),
    actionsPadding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
    actions: action == null
        ? null
        : [SizedBox.square(dimension: AppSizes.touchTarget, child: action)],
  );
}
