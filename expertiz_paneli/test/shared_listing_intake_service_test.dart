import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak_sistemleri/services/shared_listing_intake_service.dart';

void main() {
  group('SharedListingIntakeService', () {
    test('builds mobile share payload from sahibinden url', () {
      final payload = SharedListingIntakeService.buildPayload(
        'https://www.sahibinden.com/ilan/vasita-otomobil-test-123',
      );

      expect(payload['source'], 'mobile_share');
      expect(payload['url'], 'https://www.sahibinden.com/ilan/vasita-otomobil-test-123');
    });

    test('builds mobile share payload from arabam url', () {
      final payload = SharedListingIntakeService.buildPayload(
        'https://www.arabam.com/ilan/12345',
      );

      expect(payload['source'], 'mobile_share');
      expect(payload['url'], 'https://www.arabam.com/ilan/12345');
    });

    test('trims whitespace from url', () {
      final payload = SharedListingIntakeService.buildPayload(
        '  https://www.sahibinden.com/ilan/1  ',
      );

      expect(payload['url'], 'https://www.sahibinden.com/ilan/1');
    });

    test('returns valid payload for plain url text', () {
      final payload = SharedListingIntakeService.buildPayload(
        'https://www.sahibinden.com/ilan/1',
      );

      expect(payload['source'], 'mobile_share');
      expect(payload['url'], 'https://www.sahibinden.com/ilan/1');
    });

    test('_extractUrl extracts url from text with extra content', () {
      final payload = SharedListingIntakeService.buildPayload(
        'Check this car: https://www.sahibinden.com/ilan/1',
      );

      expect(payload['url'], 'https://www.sahibinden.com/ilan/1');
    });
  });
}
