# Changelog

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
