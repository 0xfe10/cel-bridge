import '../cel_runtime_options.dart';
import 'backend_api.dart';
import 'backend_stub.dart'
    if (dart.library.io) 'backend_native.dart'
    if (dart.library.js_interop) 'backend_web.dart'
    as implementation;

export 'backend_api.dart';

Future<CelBackend> createBackend(CelRuntimeOptions options) {
  return implementation.createBackend(options);
}
