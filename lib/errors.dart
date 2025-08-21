// lib/errors.dart

/// Base class for anything that goes wrong while mapping JSON -> Claim.
abstract class ClaimMappingError implements Exception {
  final String message;
  final Map<String, Object?> context;

  ClaimMappingError(this.message, {this.context = const {}});

  @override
  String toString() => '$runtimeType: $message | context=$context';
}

/// Thrown when a required field is missing from the input JSON.
class MissingFieldError extends ClaimMappingError {
  MissingFieldError(String fieldName, {Map<String, Object?> context = const {}})
      : super('Missing required field: $fieldName', context: context);
}

/// Thrown when a field exists but has the wrong type (e.g., expected String, got int).
class TypeMismatchError extends ClaimMappingError {
  TypeMismatchError(String fieldName, String expectedType, Object? actual,
      {Map<String, Object?> context = const {}})
      : super(
          'Type mismatch for $fieldName. Expected $expectedType, got ${actual.runtimeType}',
          context: {'field': fieldName, 'expected': expectedType, 'actual': actual, ...context},
        );
}

/// Thrown when the NPI does not pass basic validation.
class InvalidNpiError extends ClaimMappingError {
  InvalidNpiError(String npi, {Map<String, Object?> context = const {}})
      : super('Invalid NPI: $npi', context: {'npi': npi, ...context});
}

/// Thrown when codes (CPT or ICD) are malformed or unsupported.
class InvalidCodeError extends ClaimMappingError {
  InvalidCodeError(String codeType, String code, {Map<String, Object?> context = const {}})
      : super('Invalid $codeType code: $code', context: {'type': codeType, 'code': code, ...context});
}

/// Thrown when dates cannot be parsed/normalized.
class InvalidDateError extends ClaimMappingError {
  InvalidDateError(String raw, {Map<String, Object?> context = const {}})
      : super('Invalid date: $raw', context: {'raw': raw, ...context});
}

/// Thrown when currency amounts are malformed (e.g., negative, NaN).
class InvalidAmountError extends ClaimMappingError {
  InvalidAmountError(String fieldName, Object? raw, {Map<String, Object?> context = const {}})
      : super('Invalid amount for $fieldName: $raw', context: {'field': fieldName, 'raw': raw, ...context});
}
