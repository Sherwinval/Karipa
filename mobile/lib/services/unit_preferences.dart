import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UnitSystem { metric, imperial }

class UnitPreferences extends ChangeNotifier {
  static const _storageKey = 'unitSystem';
  static const _kilometersPerMile = 1.609344;
  UnitSystem _system = UnitSystem.metric;
  late final Future<void> _initialization;

  UnitPreferences() {
    _initialization = _load();
  }

  Future<void> get initialized => _initialization;
  UnitSystem get system => _system;
  bool get isImperial => _system == UnitSystem.imperial;
  String get distanceUnit => isImperial ? 'mi' : 'km';
  String get heightUnit => isImperial ? 'ft' : 'cm';
  String get weightUnit => isImperial ? 'lb' : 'kg';
  String get speedUnit => isImperial ? 'mph' : 'km/h';
  String get paceUnit => isImperial ? '/mi' : '/km';

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);
    if (stored == 'imperial') {
      _system = UnitSystem.imperial;
      notifyListeners();
    }
  }

  Future<void> setSystem(UnitSystem system) async {
    await _initialization;
    if (_system == system) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      system == UnitSystem.imperial ? 'imperial' : 'metric',
    );
    _system = system;
    notifyListeners();
  }

  double distanceFromKm(double kilometers) =>
      isImperial ? kilometers / _kilometersPerMile : kilometers;

  double distanceToKm(double distance) =>
      isImperial ? distance * _kilometersPerMile : distance;

  double heightFromCm(double centimeters) =>
      isImperial ? centimeters / 30.48 : centimeters;

  double heightToCm(double height) =>
      isImperial ? height * 30.48 : height;

  double weightFromKg(double kilograms) =>
      isImperial ? kilograms * 2.2046226218 : kilograms;

  double weightToKg(double weight) =>
      isImperial ? weight / 2.2046226218 : weight;

  double speedFromKmh(double kilometersPerHour) =>
      isImperial ? kilometersPerHour / _kilometersPerMile : kilometersPerHour;

  double paceFromMinutesPerKm(double minutesPerKm) =>
      isImperial ? minutesPerKm * _kilometersPerMile : minutesPerKm;

  String formatDistance(double kilometers, {int decimals = 2}) =>
      '${distanceFromKm(kilometers).toStringAsFixed(decimals)} $distanceUnit';

  String formatSpeed(double kilometersPerHour, {int decimals = 1}) =>
      '${speedFromKmh(kilometersPerHour).toStringAsFixed(decimals)} $speedUnit';

  String formatPace(double minutesPerKm) {
    if (!minutesPerKm.isFinite || minutesPerKm <= 0) return '--:-- $paceUnit';
    final totalSeconds = (paceFromMinutesPerKm(minutesPerKm) * 60).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')} $paceUnit';
  }
}
