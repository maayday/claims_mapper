# claims_mapper

**Map messy Claim JSON → a strict, validated Claim model (Dart).**  
A tiny Dart library that turns messy claim JSON into a strict, validated model. It normalizes CPT (procedure) and ICD-10 (diagnosis) codes, validates NPI (provider ID via Luhn), parses COB (payer sequence + amounts), coerces money to integer cents, and normalizes dates to UTC midnight. Failures raise typed errors; recoverable issues emit logger warnings (mocked with mocktail). The repo includes a full unit test suite and GitHub Actions CI running analyzer + tests on every push..

---

## Highlights

- **CPT normalization** — *Current Procedural Terminology* codes → 5 digits (e.g., `99-213` → `99213`)
- **ICD-10 normalization** — *International Classification of Diseases, 10th Revision* codes → uppercase with a dot after the 3rd character (e.g., `e119` → `E11.9`)
- **NPI validation** — *National Provider Identifier* (10 digits) with **Luhn** checksum
- **Money as cents** — parse numbers/strings (e.g., `$1,234.56`) into integer cents to avoid floating-point issues
- **Dates normalized** — accepted formats → **UTC midnight** for deterministic tests
- **COB parsing** — *Coordination of Benefits* block (sequence, other payer id, other payer paid) with smart warnings
- **Typed errors** — precise exceptions for missing fields, code/date/money validation, and type mismatches
- **Logger** — warnings for recoverable issues (swap in your own logger or use the included console/no-op)

---

## Quick Start (30 seconds)

```bash
dart pub get
dart analyze
dart test -r expanded
dart run bin/try_mapper.dart

## License
MIT — see `LICENSE`.
