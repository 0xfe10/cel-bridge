# Migrating to v0.2.0

Version `0.2.0` keeps the Dart public API and wire protocol stable while
reorganizing the repository and adding the Rust SDK.

## Dart dependency path

The Dart package moved from the repository root to `sdk/dart`.

Before:

```yaml
dependencies:
  cel_bridge:
    git:
      url: https://github.com/0xfe10/cel-bridge.git
      ref: v0.1.0
```

After:

```yaml
dependencies:
  cel_bridge:
    git:
      url: https://github.com/0xfe10/cel-bridge.git
      ref: v0.2.0
      path: sdk/dart
```

For a local checkout, change a root path dependency to
`path: ../cel-bridge/sdk/dart` (adjust the relative path for the application).
Run `dart pub get` or `flutter pub get` after changing the dependency.

## Runtime and protocol versions

- Dart package, Go runtime, and Rust crate version: `0.2.0`;
- Git tag: `v0.2.0`;
- wire `protocolVersion`: still `1`;
- `v0.1.0` Release assets and tag remain available.

The SDK performs a runtime handshake. Do not mix a `0.2.0` SDK with a
`0.1.0` native library or Wasm file.

## Artifact manifest v2

The release artifact manifest changed from version 1 to version 2. Each entry
now identifies its consumer and linkage:

```json
{
  "target": "rust-linux-x86_64",
  "consumer": "rust",
  "os": "linux",
  "architecture": "x86_64",
  "linkage": "static",
  "file": "cel-bridge-rust-linux-x86_64-v0.2.0.tar.gz",
  "sha256": "...",
  "size": 123456
}
```

The Dart build hook selects `consumer: dart`; the Rust build script selects
`consumer: rust`. Existing custom mirrors must publish the v2 manifest and all
required archives with their original filenames.

## Rust SDK

Rust consumers can add `cel-bridge = "0.2.0"` after crates.io publication, or
use the `v0.2.0` Git tag with `package = "cel-bridge"` during the transition.
The crate uses the same Go evaluator, C ABI, and JSON protocol as Dart.

Rust source builds require Go 1.26. The default Rust build consumes a fixed
release artifact and does not require a Go toolchain. Rust Web/Wasm and `no_std`
are not part of this release.

See [`docs/rust.md`](rust.md) for platform packaging and environment variables.

## Migration checklist

1. Change the Dart Git dependency to `ref: v0.2.0` and `path: sdk/dart`.
2. Remove any hard-coded `v0.1.0` artifact URLs from build configuration.
3. If using a mirror, generate and serve `cel-bridge-manifest-v0.2.0.json`.
4. Keep `protocolVersion` at `1`.
5. Run a native `CelRuntime.initialize()` and evaluation test.
6. Run the Flutter example or the application's platform integration test.
7. Confirm `runtime.info.runtimeVersion == '0.2.0'`.

No application source changes are required for the Dart API itself.
