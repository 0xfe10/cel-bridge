import 'cel_exception.dart';
import 'cel_value.dart';

/// One result from [CelRuntime.evaluateRequests], identified by the request id.
sealed class CelRequestResult {
  const CelRequestResult(this.id);

  final String id;
}

final class CelRequestSuccess extends CelRequestResult {
  const CelRequestSuccess(super.id, this.value);

  final CelValue value;
}

final class CelRequestFailure extends CelRequestResult {
  const CelRequestFailure(super.id, this.error);

  final CelBridgeException error;
}
