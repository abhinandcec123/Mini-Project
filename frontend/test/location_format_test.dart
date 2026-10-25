import 'package:flutter_test/flutter_test.dart';
import 'package:lifepulse_ai/utils/location_format.dart';

void main() {
  test('shows identical pins without a rounded zero distance', () {
    expect(formatDistanceKm(0), 'Same pin');
  });

  test('shows short distances in meters', () {
    expect(formatDistanceKm(0.005), '5 m');
  });
}
