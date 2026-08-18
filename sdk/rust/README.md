# cel-bridge Rust SDK

This crate is a typed Rust client for the Go cel-go runtime. It uses the same
C ABI and JSON protocol as the Dart SDK; it never evaluates CEL itself.

The default build consumes a fixed release artifact. Repository development can
use the real Go runtime directly:

    CEL_BRIDGE_BUILD_FROM_SOURCE=1 cargo test --manifest-path sdk/rust/Cargo.toml

The public API is CelRuntime, CelValue, CelValidationResult, CelBridgeError,
and `evaluate_many`. Rust Web/Wasm and no_std are intentionally not supported in
this release. See docs/rust.md for platform packaging and release details.
