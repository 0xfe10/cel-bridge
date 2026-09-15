final class CelRuntimeLimits {
  const CelRuntimeLimits({
    this.maxCompiledPrograms,
    this.maxBatchExpressions,
    this.maxPreparedPrograms,
  });

  final int? maxCompiledPrograms;
  final int? maxBatchExpressions;
  final int? maxPreparedPrograms;

  Map<String, int> toJson() => {
    'maxCompiledPrograms': ?maxCompiledPrograms,
    'maxBatchExpressions': ?maxBatchExpressions,
    'maxPreparedPrograms': ?maxPreparedPrograms,
  };
}
