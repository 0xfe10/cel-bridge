# Changelog

## 0.5.0

- `CelRuntime.validate` and `evaluate` accept optional `expectedResultType`.
- `CelValidationResult.resultType` reports the static CEL type.
- Added `evaluateRequests`, `prepare`, `evaluateProgram`, `releaseProgram`, and `dispose`.
- Native worker pending requests are limited to 256 (`backpressure_limit_exceeded`).

## 0.4.1

- Point default Web artifacts at the `v0.4.1` GitHub Release.

## 0.4.0

- Added `CelRuntime.evaluateMany` for partial-failure batch evaluation.
- Reused one native worker isolate instead of spawning an isolate per call.

## 0.3.2

- Republished the shared runtime artifacts with slow-emulator release validation.

## 0.3.1

- Published the shared runtime artifact model after cross-SDK release testing.

## 0.3.0

- Replaced language-specific native archives with shared runtime artifacts.
- Updated native artifact downloads to release manifest version 3.

## 0.2.0

- Moved the package to `sdk/dart` in the monorepo.
- Added Linux AArch64 release artifact support.
- Updated native artifact downloads to release manifest version 2.

## 0.1.0

- Initial Dart and Flutter SDK release.
