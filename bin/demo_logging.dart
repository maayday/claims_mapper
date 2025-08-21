import 'package:claims_mapper/claim_mapper.dart';
import 'package:claims_mapper/logger.dart';

void main() {
  final mapper = ClaimMapper(logger: ConsoleLogger());

  final cases = [
    {
      'title': 'coerce claimId + drop non-string CPT element',
      'json': {
        'claimId': 222,               // coerced to "222"
        'memberId': 'M',
        'providerNpi': '2234567891',  // valid NPI
        'cptCodes': ['99213', 97110], // 97110 (int) dropped
        'icdCodes': 'E11.9',
        'dateOfService': '01/20/2024',
        'totalCharge': 100.25,
      }
    },
    {
      'title': 'COB missing sequence -> drop COB (warn)',
      'json': {
        'claimId': 'COB1', 'memberId': 'M', 'providerNpi': '1000000004',
        'cptCodes': ['99213'], 'icdCodes': ['E119'],
        'dateOfService': '2024-02-12', 'totalCharge': 1,
        'cob': { 'otherPayerId': 'X', 'otherPayerPaid': '5.00' } // no 'sequence'
      }
    },
    {
      'title': 'COB invalid otherPayerPaid -> drop field (warn)',
      'json': {
        'claimId': 'COB2', 'memberId': 'M', 'providerNpi': '1000000004',
        'cptCodes': ['99213'], 'icdCodes': ['E119'],
        'dateOfService': '2024-02-13', 'totalCharge': 1,
        'cob': { 'sequence': 2, 'otherPayerId': 'PAY', 'otherPayerPaid': 'abc' }
      }
    },
  ];

  for (final c in cases) {
    print('\n== ${c['title']} ==');
    final claim = mapper.map(c['json'] as Map<String, Object?>);
    print('Mapped: $claim');
  }

  // Show silent mode:
  final silent = ClaimMapper(logger: NoopLogger());
  print('\n== silent mode (NoopLogger) ==');
  final claimSilent = silent.map({
    'claimId': 333, // would warn in console mode, but this time it's silent
    'memberId': 'M', 'providerNpi': '2234567891',
    'cptCodes': ['99213', 97110], 'icdCodes': 'E11.9',
    'dateOfService': '01/20/2024', 'totalCharge': 100.25,
  });
  print('Mapped (no warnings printed): $claimSilent');
}
