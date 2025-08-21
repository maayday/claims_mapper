// lib/claim.dart

/// A normalized, internal representation of a claim.
/// Keep this strict and predictable so the rest of your system is simple.
class Claim {
  /// Our unique claim identifier (from source).
  final String claimId;

  /// Member/patient identifier.
  final String memberId;

  /// Billing provider NPI (10 digits).
  final String providerNpi;

  /// CPT/HCPCS procedure codes, normalized (e.g., '99213', '97110').
  final List<String> cptCodes;

  /// ICD-10 diagnosis codes, normalized (e.g., 'E11.9', 'M54.5').
  final List<String> icdCodes;

  /// Date of service (start). Normalized to UTC midnight for consistency.
  final DateTime dateOfService;

  /// Total charge in minor units (cents). Using int avoids floating point errors.
  final int totalChargeCents;

  /// Optional Coordination of Benefits info (other payers, primary/secondary, etc.).
  final CoordinationOfBenefits? cob;

  Claim({
    required this.claimId,
    required this.memberId,
    required this.providerNpi,
    required this.cptCodes,
    required this.icdCodes,
    required this.dateOfService,
    required this.totalChargeCents,
    this.cob,
  });

  @override
  String toString() =>
      'Claim(claimId=$claimId, memberId=$memberId, providerNpi=$providerNpi, '
      'cpt=${cptCodes.join(',')}, icd=${icdCodes.join(',')}, '
      'dos=$dateOfService, chargeCents=$totalChargeCents, cob=$cob)';
}

/// Coordination of Benefits (simplified for demo).
/// In real systems this can be much richer; here we capture the essentials.
class CoordinationOfBenefits {
  /// 1 = primary, 2 = secondary, etc.
  final int sequence;

  /// Other payer’s identifier (could be payer id or plan id).
  final String? otherPayerId;

  /// Amount that other payer already paid, in cents.
  final int? otherPayerPaidCents;

  CoordinationOfBenefits({
    required this.sequence,
    this.otherPayerId,
    this.otherPayerPaidCents,
  });

  @override
  String toString() =>
      'COB(sequence=$sequence, otherPayerId=$otherPayerId, otherPayerPaidCents=$otherPayerPaidCents)';
}
