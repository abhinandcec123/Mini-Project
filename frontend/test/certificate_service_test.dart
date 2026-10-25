import 'package:flutter_test/flutter_test.dart';
import 'package:lifepulse_ai/services/certificate_service.dart';

void main() {
  test('builds a PDF from an approved donation certificate', () async {
    final bytes = await CertificateService.buildPdf({
      'id': 42,
      'donor_name': 'Test Donor',
      'hospital_name': 'Test Hospital',
      'donation_date': '2026-10-21T10:00:00',
      'units_donated': 1,
    });

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
