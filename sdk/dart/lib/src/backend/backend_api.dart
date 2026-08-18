abstract interface class CelBackend {
  Future<String> runtimeInfo();

  Future<String> validate(
    String environmentJson,
    String source, [
    String optionsJson = '',
  ]);

  Future<String> evaluate(
    String environmentJson,
    String source,
    String variablesJson, [
    String optionsJson = '',
  ]);

  Future<String> evaluateMany(
    String environmentJson,
    String sourcesJson,
    String variablesJson,
  );

  Future<String> evaluateRequests(
    String environmentJson,
    String requestsJson, [
    String optionsJson = '',
  ]);

  Future<String> prepare(
    String environmentJson,
    String source, [
    String optionsJson = '',
  ]);

  Future<String> evaluateProgram(
    String programId,
    String variablesJson, [
    String optionsJson = '',
  ]);

  Future<String> releaseProgram(String programId);

  Future<String> close();

  Future<String> create([String optionsJson = '']);
}
