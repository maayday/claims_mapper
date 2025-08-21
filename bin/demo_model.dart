import 'package:claims_mapper/claim_mapper.dart';
import 'package:claims_mapper/logger.dart';

void main() {
  final mapper = ClaimMapper(logger: NoopLogger()); // silent output here

  final claim = mapper.map({
    'claimId': 'CLM-ABC',
    'memberId': 'MEM-9',
    'providerNpi': '1000000004',    // valid NPI (National Provider Identifier)
    'cptCodes': ['99-213', '97110'],// CPT = Current Procedural Terminology
    'icdCodes': ['e119'],           // ICD-10 = International Classification of Diseases
    'dateOfService': '2024-06-01',
    'totalCharge': 250.75,          // -> 25075 cents
    'cob': {'sequence': 1, 'otherPayerId': 'PAYER-A', 'otherPayerPaid': '10.00'}
  });

  print('claimId: ${claim.claimId}');
  print('memberId: ${claim.memberId}');
  print('providerNpi: ${claim.providerNpi}');
  print('cptCodes: ${claim.cptCodes}');          // -> ['99213','97110']
  print('icdCodes: ${claim.icdCodes}');          // -> ['E11.9']
  print('dateOfService (UTC): ${claim.dateOfService.toUtc()}');
  print('totalChargeCents: ${claim.totalChargeCents}');

  if (claim.cob != null) {
    print('COB.sequence: ${claim.cob!.sequence}');                  // 1=primary
    print('COB.otherPayerId: ${claim.cob!.otherPayerId}');
    print('COB.otherPayerPaidCents: ${claim.cob!.otherPayerPaidCents}');
  } else {
    print('COB: null');
  }
}
