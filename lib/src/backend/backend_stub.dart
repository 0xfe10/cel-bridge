import '../cel_exception.dart';
import '../cel_runtime_options.dart';
import 'backend_api.dart';

Future<CelBackend> createBackend(CelRuntimeOptions options) {
  throw const CelBridgeException(
    code: 'internal_error',
    message: 'cel_bridge has no backend for this platform',
  );
}
