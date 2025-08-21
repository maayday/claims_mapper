import 'package:claims_mapper/claim_mapper.dart';
import 'package:claims_mapper/logger.dart';

void main() {
  // ConsoleLogger prints WARN/INFO/ERROR; NoopLogger is silent.
  final mapper = ClaimMapper(logger: ConsoleLogger());

  final json = {
    'claimId': 'CLM-001',
    'memberId': 'M123',
    'providerNpi': '1000000004',    // NPI = National Provider Identifier
    'cptCodes': '99213, 97110',     // CPT = Current Procedural Terminology (procedure codes)
    'icdCodes': ['e119', 'M545'],   // ICD-10 = International Classification of Diseases
    'dateOfService': '2024-01-15',  // normalized to UTC midnight
    'totalCharge': '\$1,234.56',    // parsed to 123456 cents
    'cob': {                        // COB = Coordination of Benefits
      'sequence': 2,                // 1=primary, 2=secondary, ...
      'otherPayerId': 'PAYER-XYZ',
      'otherPayerPaid': '25.75'     // -> 2575 cents
    },
  };

  final claim = mapper.map(json);
  print(claim);
}
