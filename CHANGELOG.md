# Changelog

## 0.5.1

- Align install examples and example versions with the release tag.
- Expand shared CEL fixtures for values, macros, errors, and `evaluateRequests`.
- Document that Aviary keeps its own cross-language business fixtures.

## 0.5.0

- Validation now returns a stable `resultType`.
- Added optional `expectedResultType` for validate and evaluate.
- Added `result_type_mismatch` without coercing or defaulting values.
- Generic variable names are uninterpreted; Aviary scopes stay outside the runtime.
- Added per-request `evaluateRequests` / `EvaluateRequests` with independent variables.
- Added prepared programs: `prepare`, `evaluateProgram`, and `releaseProgram`.
- Added wall-clock `deadlineMs`, runtime profiles, compile singleflight, and `Close`/`Create`.
- ABI version is `4`. Length-delimited `cel_bridge_call_v2` is available; NUL-terminated symbols remain.
- Added stable codes `parse_error`, `missing_variable`, `deadline_exceeded`, `program_not_found`, `program_limit_exceeded`, `runtime_closed`, and `backpressure_limit_exceeded`.

## 0.4.1

- Publish the GitHub Release as soon as artifacts are ready. Post-publish
  consumer checks continue afterwards and open an issue on failure.

## 0.4.0

- Added a Go compiled-program LRU cache so repeated evaluate calls skip Compile.
- Added a persistent Dart native worker isolate for desktop and Android.
- Added `evaluateMany` / `EvaluateMany` / `cel_bridge_evaluate_many` for batched evaluation.
- Kept the existing single-expression C ABI and SDK APIs unchanged.

## 0.2.0

- Reorganized the repository into runtime, ABI, protocol, SDK, example, and tool directories.
- Added the Rust SDK with safe FFI, typed values, shared conformance cases, and native target support.
- Added Linux AArch64 Dart artifacts and Rust runtime artifacts for supported native platforms.
- Versioned release manifest v2 with consumer, linkage, size, and SHA-256 metadata.
- Added Draft Release consumer checks and v0.2.0 migration documentation.

## 0.1.0

- Initial CEL bridge runtime and JSON protocol.
