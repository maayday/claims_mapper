import 'package:claims_mapper/claim_mapper.dart';
import 'package:claims_mapper/errors.dart';
import 'package:claims_mapper/logger.dart';

void main() {
  final mapper = ClaimMapper(logger: ConsoleLogger());

  final samples = {
    'badNpi': {
      'claimId': 'X1', 'memberId': 'M', 'providerNpi': '1234567890', // bad checksum
      'cptCodes': ['99213'], 'icdCodes': ['E119'], 'dateOfService': '2024-02-01', 'totalCharge': 10
    },
    'badIcd': {
      'claimId': 'X2', 'memberId': 'M', 'providerNpi': '1000000004',
      'cptCodes': ['99213'], 'icdCodes': ['11E'], // invalid shape
      'dateOfService': '2024-02-01', 'totalCharge': 10
    },
    'missingField': {
      // claimId missing
      'memberId': 'M', 'providerNpi': '1000000004',
      'cptCodes': ['99213'], 'icdCodes': ['E119'], 'dateOfService': '2024-02-01', 'totalCharge': 10
    },
    'badAmount': {
      'claimId': 'X4', 'memberId': 'M', 'providerNpi': '1000000004',
      'cptCodes': ['99213'], 'icdCodes': ['E119'], 'dateOfService': '2024-02-01', 'totalCharge': '-1.00'
    },
    'badDate': {
      'claimId': 'X5', 'memberId': 'M', 'providerNpi': '1000000004',
      'cptCodes': ['99213'], 'icdCodes': ['E119'], 'dateOfService': '31-02-2024', 'totalCharge': 10
    },
  };

  samples.forEach((name, payload) {
    print('\n== $name ==');
    try {
      final claim = mapper.map(payload);
      print('Mapped OK: $claim');
    } on InvalidNpiError catch (e) {
      print('InvalidNpiError: ${e.message} | context=${e.context}');
    } on InvalidCodeError catch (e) {
      print('InvalidCodeError: ${e.message} | context=${e.context}');
    } on MissingFieldError catch (e) {
      print('MissingFieldError: ${e.message} | context=${e.context}');
    } on InvalidAmountError catch (e) {
      print('InvalidAmountError: ${e.message} | context=${e.context}');
    } on InvalidDateError catch (e) {
      print('InvalidDateError: ${e.message} | context=${e.context}');
    } on ClaimMappingError catch (e) {
      print('ClaimMappingError: ${e.message} | context=${e.context}');
    }
  });
}
