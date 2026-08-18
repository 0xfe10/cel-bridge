import 'cel_exception.dart';
import 'cel_value.dart';

sealed class CelBatchResult {
  const CelBatchResult();
}

final class CelBatchSuccess extends CelBatchResult {
  const CelBatchSuccess(this.value);

  final CelValue value;
}

final class CelBatchFailure extends CelBatchResult {
  const CelBatchFailure(this.error);

  final CelBridgeException error;
}
