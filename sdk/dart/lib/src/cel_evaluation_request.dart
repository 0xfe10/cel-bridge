/// One item in [CelRuntime.evaluateRequests].
///
/// Exactly one of [source] or [programId] must be set.
final class CelEvaluationRequest {
  const CelEvaluationRequest({
    required this.id,
    this.source,
    this.programId,
    this.variables = const {},
    this.expectedResultType,
  });

  final String id;
  final String? source;
  final String? programId;
  final Map<String, Object?> variables;
  final Object? expectedResultType;
}
