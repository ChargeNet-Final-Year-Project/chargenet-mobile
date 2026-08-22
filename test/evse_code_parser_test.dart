import 'package:chargenet_mobile/features/charging/evse_code_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvseCodeParser', () {
    test('accepts a bare uid, trimming and upper-casing it', () {
      expect(EvseCodeParser.parse('VLT-SGB-01'), 'VLT-SGB-01');
      expect(EvseCodeParser.parse('vlt-sgb-01'), 'VLT-SGB-01');
      expect(EvseCodeParser.parse('  vlt-sgb-01\n'), 'VLT-SGB-01');
    });

    test('reads the ChargeNet deep link', () {
      expect(EvseCodeParser.parse('chargenet://evse/VLT-SGB-01'), 'VLT-SGB-01');
      expect(EvseCodeParser.parse('chargenet://evse/vlt-sgb-01'), 'VLT-SGB-01');
    });

    test('reads an /evse/<uid> path out of an https link', () {
      expect(
        EvseCodeParser.parse('https://chargenet.my/evse/VLT-SGB-01'),
        'VLT-SGB-01',
      );
      expect(
        EvseCodeParser.parse('https://chargenet.my/evse/VLT-SGB-01?utm=qr'),
        'VLT-SGB-01',
      );
      expect(
        EvseCodeParser.parse('https://chargenet.my/evse/vlt-sgb-01#top'),
        'VLT-SGB-01',
      );
    });

    test('rejects links that do not point at an EVSE', () {
      expect(EvseCodeParser.parse('chargenet://station/VLT-SGB-01'), isNull);
      expect(EvseCodeParser.parse('chargenet://evse/'), isNull);
      expect(EvseCodeParser.parse('https://chargenet.my/stations/12'), isNull);
      expect(EvseCodeParser.parse('https://example.com/pricing'), isNull);
      expect(EvseCodeParser.parse('https://'), isNull);
    });

    test('rejects empty, malformed and clearly not-a-code input', () {
      expect(EvseCodeParser.parse(null), isNull);
      expect(EvseCodeParser.parse(''), isNull);
      expect(EvseCodeParser.parse('   '), isNull);
      expect(EvseCodeParser.parse('AB'), isNull);
      expect(EvseCodeParser.parse('VLT/SGB/01'), isNull);
      expect(EvseCodeParser.parse('VLT SGB 01'), isNull);
      expect(EvseCodeParser.parse('VLT-SGB-01!'), isNull);
      expect(EvseCodeParser.parse('not a charge point'), isNull);
    });

    test('isValidUid mirrors what parse returns', () {
      expect(EvseCodeParser.isValidUid('VLT-SGB-01'), isTrue);
      expect(EvseCodeParser.isValidUid('vlt-sgb-01'), isTrue);
      expect(EvseCodeParser.isValidUid('vlt-sgb-01!'), isFalse);
    });
  });
}
