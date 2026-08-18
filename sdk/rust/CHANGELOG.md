# Changelog

## 0.5.0

- Added `RequestOptions` / `validate_with` / `evaluate_with` for `expectedResultType`.
- `CelValidationResult` now includes `result_type`.
- Added `evaluate_requests`, `prepare`, `evaluate_program`, `release_program`, and `close`/`recreate`.

## 0.4.1

- Point default runtime artifact downloads at the `v0.4.1` GitHub Release.

## 0.4.0

- Added `CelRuntime::evaluate_many` for partial-failure batch evaluation.

## 0.3.2

- Republished the shared runtime artifacts with slow-emulator release validation.

## 0.3.1

- Thin universal iOS simulator archives to Cargo's target architecture.

## 0.3.0

- Added the Rust SDK surface and native runtime linkage.
- Shared Android, Windows, and iOS runtime artifacts with other SDKs.
- Updated native artifact downloads to release manifest version 3.

## 0.2.0

- Added source, prebuilt-release, and local-artifact build modes.
- Added shared protocol conformance and native platform smoke harnesses.
