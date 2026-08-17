# iOS Rust smoke harness

The harness builds the Rust consumer as a static library for device and
simulator targets. An Xcode test host links this library with the Go
libcel_bridge.a XCFramework and calls cel_bridge_rust_smoke. The function
returns zero only after a real CelRuntime evaluates 1 + 1 == 2.

Build checks from the repository root:

    export CEL_BRIDGE_BUILD_FROM_SOURCE=1
    cargo build --manifest-path sdk/rust/tests-platform/ios/Cargo.toml \
      --target aarch64-apple-ios --release
    cargo build --manifest-path sdk/rust/tests-platform/ios/Cargo.toml \
      --target aarch64-apple-ios-sim --release
    cargo build --manifest-path sdk/rust/tests-platform/ios/Cargo.toml \
      --target x86_64-apple-ios --release

The simulator test host must link the simulator archive; the device build must
link the device archive. iOS never downloads a runtime library at application
startup.
