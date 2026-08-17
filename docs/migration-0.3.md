# Migrating to v0.3.0

`v0.3.0` changes how native runtime artifacts are named and described. The C
ABI and JSON protocol remain compatible: `protocolVersion` is still `1`.

## One runtime for every language

All native libraries in a release are built from the Go runtime. Dart, Rust,
and any other binding select and use the same compatible library for their
target. Release assets are therefore identified by operating system,
architecture, and linkage instead of by a language consumer.

The default Dart and Rust builds download the matching artifact from the
GitHub Release and verify its byte size and SHA-256 digest against the release
manifest. Explicit Dart preparation and Rust builds use the same environment
variable to request local Go compilation:

```bash
export CEL_BRIDGE_BUILD_FROM_SOURCE=1
```

Source mode requires the Go toolchain and a source checkout containing the
runtime. It does not download a native library.

Dart's automatic native-assets hook cannot read custom environment variables.
For an ordinary Dart or Flutter build, configure
`hooks.user_defines.cel_bridge.build_from_source: true` in `pubspec.yaml`
instead. On iOS, source mode must additionally provide the locally built
XCFramework through `CEL_BRIDGE_IOS_XCFRAMEWORK_PATH`, because CocoaPods links
the static iOS runtime outside the Dart native-assets hook. These build-system
constraints do not change the runtime: both SDKs still consume a Go-built
library with the same C ABI.

## Manifest v3

The release manifest now uses `manifestVersion: 3`. Each artifact entry has
this shape:

```json
{
  "id": "linux-x86_64-static",
  "os": "linux",
  "architecture": "x86_64",
  "linkage": "static",
  "format": "tar.gz",
  "libraries": ["libcel_bridge.a"],
  "file": "cel-bridge-linux-x86_64-static-v0.3.0.tar.gz",
  "sha256": "...",
  "size": 123
}
```

The v2 `consumer` field has been removed. Artifact IDs and filenames no longer
use a `rust-` prefix.

## Artifact filename changes

Linux and macOS filenames now state whether the library is dynamic or static.
The language-prefixed duplicates have been removed.

| v0.2.0 asset | v0.3.0 asset |
|---|---|
| `cel-bridge-linux-x86_64-v0.2.0.tar.gz` | `cel-bridge-linux-x86_64-dynamic-v0.3.0.tar.gz` |
| `cel-bridge-linux-aarch64-v0.2.0.tar.gz` | `cel-bridge-linux-aarch64-dynamic-v0.3.0.tar.gz` |
| `cel-bridge-rust-linux-x86_64-v0.2.0.tar.gz` | `cel-bridge-linux-x86_64-static-v0.3.0.tar.gz` |
| `cel-bridge-rust-linux-aarch64-v0.2.0.tar.gz` | `cel-bridge-linux-aarch64-static-v0.3.0.tar.gz` |
| `cel-bridge-macos-x86_64-v0.2.0.tar.gz` | `cel-bridge-macos-x86_64-dynamic-v0.3.0.tar.gz` |
| `cel-bridge-macos-arm64-v0.2.0.tar.gz` | `cel-bridge-macos-arm64-dynamic-v0.3.0.tar.gz` |
| `cel-bridge-rust-macos-x86_64-v0.2.0.tar.gz` | `cel-bridge-macos-x86_64-static-v0.3.0.tar.gz` |
| `cel-bridge-rust-macos-arm64-v0.2.0.tar.gz` | `cel-bridge-macos-arm64-static-v0.3.0.tar.gz` |
| `cel-bridge-rust-windows-x86_64-v0.2.0.zip` and `cel-bridge-windows-x86_64-v0.2.0.zip` | `cel-bridge-windows-x86_64-v0.3.0.zip` |
| Dart and Rust Android assets for each ABI | One `cel-bridge-android-<abi>-v0.3.0.tar.gz` per ABI |
| Dart and Rust iOS assets | `cel-bridge-ios-xcframework-v0.3.0.zip` |

The Windows archive contains both `cel_bridge.dll` and the MSVC-compatible
`cel_bridge.lib` import library. The iOS XCFramework contains the device and
universal simulator static-library slices used by both SDKs.

## Migrating a release mirror

A mirror must publish the v3 manifest and every filename referenced by it
without renaming files. Do not copy v2 manifest entries or retain the
language-prefixed names as v3 entries. Keep the normal version directory
layout:

```text
<release-root>/v0.3.0/cel-bridge-manifest-v0.3.0.json
<release-root>/v0.3.0/cel-bridge-linux-x86_64-dynamic-v0.3.0.tar.gz
<release-root>/v0.3.0/cel-bridge-linux-x86_64-static-v0.3.0.tar.gz
...
```

For Rust, `CEL_BRIDGE_RELEASE_BASE_URL` is the root before `/v0.3.0`. For the
Dart native-assets hook, `release_base_url` is the version directory containing
the manifest. See the Dart and Rust integration guides for the complete mirror
configuration and checksum controls.

Existing `v0.2.0` releases and assets remain immutable. Consumers pinned to
`v0.2.0` continue to use manifest v2 and its original filenames.
