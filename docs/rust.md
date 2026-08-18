# cel-bridge Rust Integration Guide

The Rust SDK is a typed client for the Go `cel-go` runtime. Rust does not
implement CEL compilation or evaluation. It encodes requests, calls the shared
C ABI, and decodes the versioned JSON protocol.

## Add the crate

After the crate is published, use the release version:

```toml
[dependencies]
cel-bridge = "0.5.1"
serde_json = "1.0"
```

Until then, use the release tag and repository path:

```toml
[dependencies]
cel-bridge = { git = "https://github.com/0xfe10/cel-bridge.git", tag = "v0.5.1", package = "cel-bridge" }
serde_json = "1.0"
```

The repository's runnable Rust example is in
[`examples/rust-cli`](../examples/rust-cli).

## Minimal API

```rust
use cel_bridge::{CelRuntime, CelValue};
use serde_json::json;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let runtime = CelRuntime::new()?;
    let environment = json!({
        "schemaVersion": 1,
        "variables": {"age": {"type": "int"}}
    });

    let validation = runtime.validate(&environment, "age >= 18")?;
    if !validation.valid {
        for issue in validation.issues {
            eprintln!("{}: {}", issue.code, issue.message);
        }
        return Ok(());
    }

    let value = runtime.evaluate(
        &environment,
        "age >= 18",
        &json!({"age": 20}),
    )?;
    assert_eq!(value, CelValue::Bool(true));

    let batch = runtime.evaluate_many(
        &environment,
        &["age >= 18", "age >= 21"],
        &json!({"age": 20}),
    )?;
    assert!(batch[0].is_ok());

    let program_id = runtime.prepare(
        &environment,
        "age >= 18",
        cel_bridge::RequestOptions {
            expected_result_type: Some(&json!("bool")),
            ..cel_bridge::RequestOptions::default()
        },
    )?;
    let prepared = runtime.evaluate_program(
        &program_id,
        &json!({"age": 20}),
        cel_bridge::RequestOptions::default(),
    )?;
    assert_eq!(prepared, CelValue::Bool(true));
    runtime.release_program(&program_id)?;
    Ok(())
}
```

`CelRuntime::new()` performs the protocol and runtime version handshake.
Initialize one runtime per service or application component and reuse it for
multiple calls. `validate` returns a `CelValidationResult` for source and type
errors. `evaluate` returns a `CelValue` or a `CelBridgeError`. `evaluate_many`
returns one result per source and keeps going when a single expression fails.

## Values and errors

`CelValue` preserves the wire representation instead of relying on lossy JSON
numbers:

- `Null`, `Bool`, `Int(i64)`, and `Uint(u64)`;
- `Double(f64)`, including `NaN` and infinities;
- `String`, `Bytes`, `Timestamp`, and `Duration`;
- recursive `List(Vec<CelValue>)` and `Map(Vec<CelMapEntry>)`.

Branch on `CelBridgeError.code`, not on the diagnostic message. Important codes
include `invalid_request`, `invalid_environment`, `compile_error`,
`evaluation_error`, `cost_limit_exceeded`, `protocol_mismatch`,
`runtime_mismatch`, and `native_library_load_failed`. Validation issues include
source line and column information when the Go runtime provides it.

## Platform support

| Rust target | Runtime artifact | Linkage |
| --- | --- | --- |
| Linux x86_64 / AArch64 | `libcel_bridge.a` | static |
| macOS x86_64 / arm64 | `libcel_bridge.a` | static |
| Windows x86_64 | `cel_bridge.dll` | dynamic |
| Android arm64-v8a / armeabi-v7a / x86_64 | `libcel_bridge.so` | dynamic |
| iOS device arm64 and simulators | `libcel_bridge.a` | static |

Rust Web/Wasm is not provided. The crate uses `std`; `no_std` is not a supported
configuration. Web applications should use the Dart SDK and Go Wasm backend.

## Runtime artifact modes

### Fixed Release artifacts

The default build downloads the exact `v0.5.1` runtime artifact for Cargo's
target, then verifies its size and SHA-256 against the release manifest.
Consumers do not need a Go installation in this mode.

The default GitHub layout is:

```text
https://github.com/0xfe10/cel-bridge/releases/download/
  v0.5.1/cel-bridge-manifest-v0.5.1.json
```

For an internal mirror, set the release-download root, not the version
directory:

```bash
export CEL_BRIDGE_RELEASE_BASE_URL=https://artifacts.example.com/cel-bridge/download
cargo build
```

The build script appends `/v0.5.1/<file>`. HTTPS is required. HTTP is accepted
only when `CEL_BRIDGE_ALLOW_INSECURE_RELEASE_BASE=1` is explicitly set for a
localhost test fixture.

### Build from source

Repository development can use the Go runtime directly:

```bash
CEL_BRIDGE_BUILD_FROM_SOURCE=1 \
  cargo test --manifest-path sdk/rust/Cargo.toml
```

When the crate is outside the checkout, set the repository root explicitly:

```bash
CEL_BRIDGE_BUILD_FROM_SOURCE=1 \
CEL_BRIDGE_RUNTIME_SOURCE=/absolute/path/to/cel-bridge \
  cargo test
```

Source builds require Go 1.26 and a C toolchain. Android builds also require
the NDK compiler for the selected ABI. macOS and iOS source builds use `xcrun`
to select the correct SDK, clang, sysroot, and target triple.

### Local prebuilt artifacts

Use an extracted library when testing a locally built release-shaped artifact:

```bash
CEL_BRIDGE_ARTIFACT_DIR=/absolute/path/to/linux-x86_64-static \
  cargo run --manifest-path examples/rust-cli/Cargo.toml
```

The directory must contain the library expected by the Cargo target, for
example `libcel_bridge.a` on Linux or `libcel_bridge.so` on Android. The build
script never accepts an archive path as a library path; extract the archive
first.

## Android packaging

The Cargo build links the Rust consumer against the ABI-matching Go shared
library. The application must package that same library for the device ABI:

```text
app/src/main/jniLibs/arm64-v8a/libcel_bridge.so
app/src/main/jniLibs/armeabi-v7a/libcel_bridge.so
app/src/main/jniLibs/x86_64/libcel_bridge.so
```

Use the shared `cel-bridge-android-*-v0.5.1.tar.gz` runtime artifacts or build
the matching Go shared library from source. Dart and Rust use the same Android
`.so`. Do not put a Linux or desktop library in an
Android ABI directory. The repository's Rust smoke harness is in
[`sdk/rust/tests-platform/android`](../sdk/rust/tests-platform/android).

## iOS linking

iOS uses a Go static archive because Go does not provide the dynamic code-asset
shape required by the Flutter iOS hook. The shared
`cel-bridge-ios-xcframework-v0.5.1.zip` contains device and universal simulator
slices. Rust selects the matching slice from that same XCFramework and thins
the universal simulator archive to Cargo's target architecture; Flutter uses
the XCFramework through CocoaPods.

The Rust iOS smoke harness is in
[`sdk/rust/tests-platform/ios`](../sdk/rust/tests-platform/ios). Device and
simulator architectures must be built separately; never mix a simulator
archive into a device target.

## Windows deployment

Windows uses `cel_bridge.dll` plus the MSVC-compatible `cel_bridge.lib` import
library. The build script extracts both files; keep the DLL beside the final
executable or in a directory on the process DLL search path. The release
artifact is `cel-bridge-windows-x86_64-v0.5.1.zip`. Both files must match
the executable's architecture and the Rust target's linker/toolchain.

## Verify an integration

Run the source-mode test suite from the repository root:

```bash
go test ./...
CEL_BRIDGE_BUILD_FROM_SOURCE=1 cargo test --manifest-path sdk/rust/Cargo.toml
CEL_BRIDGE_BUILD_FROM_SOURCE=1 cargo run --manifest-path examples/rust-cli/Cargo.toml
```

For a release consumer test, download the Draft/Release manifest and artifacts,
serve them from a local HTTPS or explicitly allowed localhost mirror, and run
the Rust fixture:

```bash
CEL_BRIDGE_RELEASE_BASE_URL=http://127.0.0.1:8126 \
CEL_BRIDGE_ALLOW_INSECURE_RELEASE_BASE=1 \
cargo run --manifest-path tools/fixtures/rust-release-consumer/Cargo.toml
```

The fixture checks a real CEL evaluation through the downloaded Go runtime
artifact; it does not use the source build fallback.
