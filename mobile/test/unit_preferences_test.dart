import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karipa/services/unit_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('metric and imperial conversions retain canonical values', () async {
    final units = UnitPreferences();
    await units.setSystem(UnitSystem.imperial);

    expect(units.distanceFromKm(1.609344), closeTo(1, 0.000001));
    expect(units.distanceToKm(1), closeTo(1.609344, 0.000001));
    expect(units.heightFromCm(30.48), closeTo(1, 0.000001));
    expect(units.heightToCm(1), closeTo(30.48, 0.000001));
    expect(units.weightFromKg(1), closeTo(2.2046226218, 0.000001));
    expect(units.weightToKg(2.2046226218), closeTo(1, 0.000001));
    expect(units.speedFromKmh(1.609344), closeTo(1, 0.000001));
    expect(units.formatPace(6), '09:39 /mi');
  });

  test('unit preference is persisted', () async {
    final units = UnitPreferences();
    await units.setSystem(UnitSystem.imperial);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('unitSystem'), 'imperial');

    final restored = UnitPreferences();
    await restored.initialized;
    expect(restored.system, UnitSystem.imperial);
  });
}
