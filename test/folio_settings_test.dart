import 'package:flutter_test/flutter_test.dart';
import 'package:folio/features/settings/domain/folio_settings.dart';

void main() {
  group('FolioSettings summaryTextDirection', () {
    test('defaults to ltr', () {
      const settings = FolioSettings();
      expect(settings.summaryTextDirection, 'ltr');
      expect(settings.summaryIsRtl, isFalse);
    });

    test('round-trips rtl through json', () {
      final settings = const FolioSettings().copyWith(summaryTextDirection: 'rtl');
      final restored = FolioSettings.fromJson(settings.toJson());
      expect(restored.summaryTextDirection, 'rtl');
      expect(restored.summaryIsRtl, isTrue);
    });

    test('normalizes invalid direction to ltr', () {
      final restored = FolioSettings.fromJson({
        'summaryTextDirection': 'sideways',
      });
      expect(restored.summaryTextDirection, 'ltr');
    });
  });
}
