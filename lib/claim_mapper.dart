// lib/claim_mapper.dart
//
// Maps loosely-structured JSON into a strict, normalized Claim model.
// Validates CPT (Current Procedural Terminology), ICD (International
// Classification of Diseases), NPI (National Provider Identifier), COB
// (Coordination of Benefits), dates, and money amounts.

import 'claim.dart';
import 'errors.dart';
import 'logger.dart';

class ClaimMapper {
  final Logger logger;
  ClaimMapper({Logger? logger}) : logger = logger ?? NoopLogger();

  /// Public entry point: convert input JSON into a normalized Claim.
  Claim map(Map<String, Object?> json) {
    // Required scalar fields
    final claimId = _requireString(json, 'claimId');
    final memberId = _requireString(json, 'memberId');

    // NPI (National Provider Identifier) – 10 digits with a checksum.
    final rawNpi = _requireString(json, 'providerNpi');
    final npi = _normalizeNpi(rawNpi);

    // CPT (procedure) codes: allow ["99213","97110"] or "99213, 97110"
    final cptCodes = _parseCodes(json['cptCodes'], fieldName: 'cptCodes')
        .map(_normalizeCpt)
        .toList();

    if (cptCodes.isEmpty) {
      // Not strictly required in all real systems, but for demo we enforce >=1
      throw InvalidCodeError('CPT', '<empty>');
    }

    // ICD (diagnosis) codes: allow ["E119","M545"] or "E11.9, M54.5"
    final icdCodes = _parseCodes(json['icdCodes'], fieldName: 'icdCodes')
        .map(_normalizeIcd10)
        .toList();

    if (icdCodes.isEmpty) {
      // Same reasoning as CPT above for demo strictness
      throw InvalidCodeError('ICD', '<empty>');
    }

    // Date of service – accept common formats and normalize to UTC midnight
    final dos = _requireString(json, 'dateOfService');
    final dateOfService = _parseDateToUtcMidnight(dos);

    // Money – store cents as int to avoid floating point errors
    final totalChargeRaw = json['totalCharge'];
    final totalChargeCents = _parseMoneyToCents(totalChargeRaw, field: 'totalCharge');

    // Optional COB (Coordination of Benefits)
    final cob = _parseCob(json['cob']);

    return Claim(
      claimId: claimId,
      memberId: memberId,
      providerNpi: npi,
      cptCodes: cptCodes,
      icdCodes: icdCodes,
      dateOfService: dateOfService,
      totalChargeCents: totalChargeCents,
      cob: cob,
    );
  }

  // ---------- helpers: required fields & basic types ----------

  String _requireString(Map<String, Object?> json, String field) {
    if (!json.containsKey(field)) {
      throw MissingFieldError(field, context: {'json': json});
    }
    final v = json[field];
    if (v is String && v.trim().isNotEmpty) return v.trim();

    // Be helpful: if the source sends an int/double for an id field, coerce and warn.
    if (v is num) {
      final s = v.toString();
      logger.warn('Coerced non-string into string for $field', context: {'value': v});
      return s;
    }

    throw TypeMismatchError(field, 'String (non-empty)', v);
  }

  // ---------- helpers: codes (CPT / ICD) ----------

  List<String> _parseCodes(Object? raw, {required String fieldName}) {
    if (raw == null) return <String>[];

    if (raw is String) {
      return raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    if (raw is List) {
      final out = <String>[];
      for (final item in raw) {
        if (item is String && item.trim().isNotEmpty) {
          out.add(item.trim());
        } else {
          // CHANGE: warn for BOTH non-string AND null elements (unified message)
          logger.warn(
            'Dropped non-string code element',
            context: {'field': fieldName, 'value': item},
          );
        }
      }
      return out;
    }

    throw TypeMismatchError(fieldName, 'String or List<String>', raw);
  }

  String _normalizeCpt(String raw) {
    // CPT: five numeric digits; ignore modifiers for simplicity in this demo.
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 5) {
      throw InvalidCodeError('CPT', raw);
    }
    return digits;
  }

  String _normalizeIcd10(String raw) {
    // ICD-10: uppercase, remove dot, then reinsert after 3rd char.
    // Example: 'e119' -> 'E11.9'; 'M545' -> 'M54.5'
    var code = raw.toUpperCase().replaceAll('.', '').trim();

    // Minimal shape check: first char A-Z, total length 3..7 alphanum
    if (!RegExp(r'^[A-Z][A-Z0-9]{2,6}$').hasMatch(code)) {
      throw InvalidCodeError('ICD', raw);
    }

    // Reinsert dot after the 3rd character if length > 3
    if (code.length > 3) {
      code = '${code.substring(0, 3)}.${code.substring(3)}';
    }
    return code;
  }

  // ---------- helpers: NPI (National Provider Identifier) ----------

  String _normalizeNpi(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 10) {
      throw InvalidNpiError(raw);
    }
    if (!_isValidNpiChecksum(digits)) {
      throw InvalidNpiError(raw);
    }
    return digits;
  }

  bool _isValidNpiChecksum(String tenDigits) {
    // NPI uses a Luhn check with an '80840' prefix applied to the first 9 digits.
    // Reference idea: compute Luhn on '80840' + first9, compare to last digit.
    final first9 = tenDigits.substring(0, 9);
    final check = int.parse(tenDigits[9]);

    final base = '80840$first9';
    final sum = _luhnSum(base);
    final expectedCheck = (10 - (sum % 10)) % 10;
    return expectedCheck == check;
  }

  int _luhnSum(String digits) {
    // Standard Luhn: from right, double every second digit; if >9 subtract 9; sum all.
    var sum = 0;
    var doubleIt = true; // start from rightmost, next to rightmost is doubled
    for (int i = digits.length - 1; i >= 0; i--) {
      var d = int.parse(digits[i]);
      if (doubleIt) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      doubleIt = !doubleIt;
    }
    return sum;
  }

  // ---------- helpers: dates ----------

  DateTime _parseDateToUtcMidnight(String raw) {
    // 1) Try built-in ISO-8601 parser
    final iso = DateTime.tryParse(raw);
    if (iso != null) {
      // normalize to date-only at UTC midnight
      return DateTime.utc(iso.year, iso.month, iso.day);
    }

    // 2) Try YYYY-MM-DD
    final ymd = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (ymd != null) {
      final y = int.parse(ymd.group(1)!);
      final m = int.parse(ymd.group(2)!);
      final d = int.parse(ymd.group(3)!);
      return DateTime.utc(y, m, d);
    }

    // 3) Try MM/DD/YYYY
    final mdy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(raw);
    if (mdy != null) {
      final m = int.parse(mdy.group(1)!);
      final d = int.parse(mdy.group(2)!);
      final y = int.parse(mdy.group(3)!);
      return DateTime.utc(y, m, d);
    }

    throw InvalidDateError(raw);
  }

  // ---------- helpers: money ----------

  int _parseMoneyToCents(Object? raw, {required String field}) {
    if (raw == null) throw MissingFieldError(field);

    if (raw is num) {
      final cents = (raw * 100).round();
      if (cents < 0) throw InvalidAmountError(field, raw);
      return cents;
    }

    if (raw is String) {
      // Remove currency symbols and commas then parse as decimal
      final cleaned = raw.replaceAll(RegExp(r'[,\s\$]'), '');
      final value = num.tryParse(cleaned);
      if (value == null) throw InvalidAmountError(field, raw);
      final cents = (value * 100).round();
      if (cents < 0) throw InvalidAmountError(field, raw);
      return cents;
    }

    throw TypeMismatchError(field, 'num or String', raw);
  }

  // ---------- helpers: COB (Coordination of Benefits) ----------

  CoordinationOfBenefits? _parseCob(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) {
      throw TypeMismatchError('cob', 'Map', raw);
    }

    // sequence: primary=1, secondary=2, etc.
    final seqRaw = raw['sequence'];
    if (seqRaw == null) {
      // If COB block present but missing sequence, warn and drop COB entirely.
      logger.warn('COB present but missing sequence; dropping COB', context: {'cob': raw});
      return null;
    }
    final sequence = switch (seqRaw) {
      int v => v,
      String s when int.tryParse(s) != null => int.parse(s),
      _ => throw TypeMismatchError('cob.sequence', 'int or numeric string', seqRaw),
    };
    if (sequence < 1) {
      throw InvalidAmountError('cob.sequence', sequence);
    }

    // otherPayerId: optional string
    String? otherPayerId;
    final opi = raw['otherPayerId'];
    if (opi != null) {
      if (opi is String && opi.trim().isNotEmpty) {
        otherPayerId = opi.trim();
      } else {
        logger.warn('Dropped non-string otherPayerId', context: {'value': opi});
      }
    }

    // otherPayerPaid: optional money -> cents
    int? otherPayerPaidCents;
    if (raw.containsKey('otherPayerPaid')) {
      try {
        otherPayerPaidCents = _parseMoneyToCents(raw['otherPayerPaid'], field: 'cob.otherPayerPaid');
      } on ClaimMappingError catch (e) {
        // For demo: if invalid paid amount, warn and continue without it.
        logger.warn('Invalid COB otherPayerPaid; dropping', context: {'error': e.toString()});
      }
    }

    return CoordinationOfBenefits(
      sequence: sequence,
      otherPayerId: otherPayerId,
      otherPayerPaidCents: otherPayerPaidCents,
    );
  }
}
