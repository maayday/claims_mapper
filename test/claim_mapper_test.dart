import 'package:test/test.dart' as t;        // namespaced test helpers
import 'package:mocktail/mocktail.dart';

import 'package:claims_mapper/claim_mapper.dart';
import 'package:claims_mapper/errors.dart';
import 'package:claims_mapper/logger.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  late MockLogger logger;
  late ClaimMapper mapper;

  // mocktail needs a fallback value for non-nullable named parameter {context: Map<String, Object?>}
  t.setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  t.setUp(() {
    logger = MockLogger();
    mapper = ClaimMapper(logger: logger);
  });

  t.group('ClaimMapper', () {
    t.test('happy path maps and normalizes', () {
      final json = {
        'claimId': 'CLM-001',
        'memberId': 'M123',
        'providerNpi': '1000000004',
        'cptCodes': '99213, 97110',
        'icdCodes': ['e119', 'M545'],
        'dateOfService': '2024-01-15',
        'totalCharge': '\$1,234.56',
        'cob': {'sequence': 2, 'otherPayerId': 'PAYER-XYZ', 'otherPayerPaid': '25.75'},
      };

      final claim = mapper.map(json);

      t.expect(claim.claimId, 'CLM-001');
      t.expect(claim.memberId, 'M123');
      t.expect(claim.providerNpi, '1000000004');
      t.expect(claim.cptCodes, ['99213', '97110']);
      t.expect(claim.icdCodes, ['E11.9', 'M54.5']);
      t.expect(claim.dateOfService, DateTime.utc(2024, 1, 15)); // UTC midnight
      t.expect(claim.totalChargeCents, 123456);                 // $1234.56 -> 123456 cents

      t.expect(claim.cob, t.isNotNull);
      t.expect(claim.cob!.sequence, 2);
      t.expect(claim.cob!.otherPayerId, 'PAYER-XYZ');
      t.expect(claim.cob!.otherPayerPaidCents, 2575);
    });

    t.test('CPT normalization enforces 5 digits', () {
      final json = {
        'claimId': 'C1',
        'memberId': 'M1',
        'providerNpi': '1000000004',
        'cptCodes': ['99-213', '97110 '],
        'icdCodes': 'E11.9',
        'dateOfService': '2024-02-01',
        'totalCharge': 10,
      };

      final claim = mapper.map(json);
      t.expect(claim.cptCodes, ['99213', '97110']);
    });

    t.test('ICD-10 normalization uppercases and inserts dot after 3rd char', () {
      final json = {
        'claimId': 'C2',
        'memberId': 'M2',
        'providerNpi': '1000000004',
        'cptCodes': ['99213'],
        'icdCodes': ['e119', 'm545', 'E11.9'],
        'dateOfService': '2024-02-02',
        'totalCharge': '100.00',
      };

      final claim = mapper.map(json);
      t.expect(claim.icdCodes, ['E11.9', 'M54.5', 'E11.9']);
    });

    t.test('invalid NPI throws InvalidNpiError', () {
      final json = {
        'claimId': 'C3',
        'memberId': 'M3',
        'providerNpi': '1234567890', // bad check digit
        'cptCodes': ['99213'],
        'icdCodes': ['E119'],
        'dateOfService': '2024-02-03',
        'totalCharge': 50,
      };

      t.expect(() => mapper.map(json), t.throwsA(t.isA<InvalidNpiError>()));
    });

    t.test('missing required field throws MissingFieldError', () {
      final json = {
        // 'claimId' missing
        'memberId': 'M4',
        'providerNpi': '1000000004',
        'cptCodes': ['99213'],
        'icdCodes': ['E119'],
        'dateOfService': '2024-02-04',
        'totalCharge': 10,
      };

      t.expect(() => mapper.map(json), t.throwsA(t.isA<MissingFieldError>()));
    });

    t.test('date formats accepted: ISO, YYYY-MM-DD, MM/DD/YYYY', () {
      final iso = {
        'claimId': 'D1',
        'memberId': 'M',
        'providerNpi': '1000000004',
        'cptCodes': ['99213'],
        'icdCodes': ['E119'],
        'dateOfService': '2024-02-05T10:30:00Z',
        'totalCharge': 1,
      };
      final ymd = {
        'claimId': 'D2',
        'memberId': 'M',
        'providerNpi': '1000000004',
        'cptCodes': ['99213'],
        'icdCodes': ['E119'],
        'dateOfService': '2024-02-06',
        'totalCharge': 1,
      };
      final mdy = {
        'claimId': 'D3',
        'memberId': 'M',
        'providerNpi': '1000000004',
        'cptCodes': ['99213'],
        'icdCodes': ['E119'],
        'dateOfService': '02/07/2024',
        'totalCharge': 1,
      };

      t.expect(mapper.map(iso).dateOfService, DateTime.utc(2024, 2, 5));
      t.expect(mapper.map(ymd).dateOfService, DateTime.utc(2024, 2, 6));
      t.expect(mapper.map(mdy).dateOfService, DateTime.utc(2024, 2, 7));
    });

    t.test('money parsing handles strings and numbers; invalid/negative rejected', () {
      final ok1 = {
        'claimId': 'M1',
        'memberId': 'M',
        'providerNpi': '1000000004',
        'cptCodes': ['99213'],
        'icdCodes': ['E119'],
        'dateOfService': '2024-02-08',
        'totalCharge': '\$1,000.25', // -> 100025
      };
      final ok2 = {
        'claimId': 'M2',
        'memberId': 'M',
        'providerNpi': '1000000004',
        'cptCodes': ['99213'],
        'icdCodes': ['E119'],
        'dateOfService': '2024-02-09',
        'totalCharge': 10.01, // -> 1001
      };
      final badStr = {
        'claimId': 'M3',
        'memberId': 'M',
        'providerNpi': '1000000004',
        'cptCodes': ['99213'],
        'icdCodes': ['E119'],
        'dateOfService': '2024-02-10',
        'totalCharge': 'abc',
      };
      final negative = {
        'claimId': 'M4',
        'memberId': 'M',
        'providerNpi': '1000000004',
        'cptCodes': ['99213'],
        'icdCodes': ['E119'],
        'dateOfService': '2024-02-11',
        'totalCharge': -1,
      };

      t.expect(mapper.map(ok1).totalChargeCents, 100025);
      t.expect(mapper.map(ok2).totalChargeCents, 1001);

      t.expect(() => mapper.map(badStr), t.throwsA(t.isA<InvalidAmountError>()));
      t.expect(() => mapper.map(negative), t.throwsA(t.isA<InvalidAmountError>()));
    });

    t.test('COB: present without sequence -> dropped with warning', () {
      final json = {
        'claimId': 'COB1',
        'memberId': 'M',
        'providerNpi': '1000000004',
        'cptCodes': ['99213'],
        'icdCodes': ['E119'],
        'dateOfService': '2024-02-12',
        'totalCharge': 1,
        'cob': {'otherPayerId': 'X', 'otherPayerPaid': '5.00'} // missing 'sequence'
      };

      final claim = mapper.map(json);
      t.expect(claim.cob, t.isNull);

      verify(() => logger.warn(
            any(that: t.contains('COB present but missing sequence')),
            context: any(named: 'context'),
          )).called(1);
    });

    t.test('COB: invalid otherPayerPaid -> warning, field dropped', () {
      final json = {
        'claimId': 'COB2',
        'memberId': 'M',
        'providerNpi': '1000000004',
        'cptCodes': ['99213'],
        'icdCodes': ['E119'],
        'dateOfService': '2024-02-13',
        'totalCharge': 1,
        'cob': {'sequence': 2, 'otherPayerId': 'PAY', 'otherPayerPaid': 'abc'},
      };

      final claim = mapper.map(json);
      t.expect(claim.cob, t.isNotNull);
      t.expect(claim.cob!.sequence, 2);
      t.expect(claim.cob!.otherPayerId, 'PAY');
      t.expect(claim.cob!.otherPayerPaidCents, t.isNull);

      verify(() => logger.warn(
            any(that: t.contains('Invalid COB otherPayerPaid; dropping')),
            context: any(named: 'context'),
          )).called(1);
    });

    t.test('logger warnings: coerced non-string claimId & dropped non-string CPT element', () {
      final json = {
        'claimId': 222,               // coerced to "222"
        'memberId': 'M',
        'providerNpi': '2234567891',  // valid NPI
        'cptCodes': ['99213', 97110], // 97110 (int) dropped
        'icdCodes': 'E11.9',
        'dateOfService': '01/20/2024',
        'totalCharge': 100.25,
      };

      final claim = mapper.map(json);
      t.expect(claim.claimId, '222');
      t.expect(claim.cptCodes, ['99213']); // int element dropped

      verify(() => logger.warn(
            any(that: t.contains('Coerced non-string into string for claimId')),
            context: any(named: 'context'),
          )).called(1);

      verify(() => logger.warn(
            any(that: t.contains('Dropped non-string code element')),
            context: any(named: 'context'),
          )).called(1);
    });

    t.test('empty CPT or ICD throws InvalidCodeError', () {
      final emptyCpt = {
        'claimId': 'E1',
        'memberId': 'M',
        'providerNpi': '1000000004',
        'cptCodes': <String>[],
        'icdCodes': ['E119'],
        'dateOfService': '2024-02-14',
        'totalCharge': 1,
      };
      final emptyIcd = {
        'claimId': 'E2',
        'memberId': 'M',
        'providerNpi': '1000000004',
        'cptCodes': ['99213'],
        'icdCodes': '',
        'dateOfService': '2024-02-15',
        'totalCharge': 1,
      };

      t.expect(() => mapper.map(emptyCpt), t.throwsA(t.isA<InvalidCodeError>()));
      t.expect(() => mapper.map(emptyIcd), t.throwsA(t.isA<InvalidCodeError>()));
    });
  });
}
