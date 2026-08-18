# cel_bridge

`cel_bridge` is a Dart and Flutter client for the cel-bridge Go CEL runtime.
It uses the native C ABI on desktop and mobile platforms and Go Wasm on Web.
The Dart package does not implement CEL evaluation.

```dart
import 'package:cel_bridge/cel_bridge.dart';

final runtime = await CelRuntime.initialize();
final result = await runtime.evaluate(
  environment: const {
    'schemaVersion': 1,
    'variables': {'age': {'type': 'int'}},
  },
  source: 'age >= 18',
  variables: {'age': 20},
);
```

Pin the `v0.5.1` Git tag until the package is published:

```yaml
dependencies:
  cel_bridge:
    git:
      url: https://github.com/0xfe10/cel-bridge.git
      ref: v0.5.1
      path: sdk/dart
```

See the repository's Dart integration guide for platform setup, source builds,
Web hosting, typed values, errors, and the Flutter example.
