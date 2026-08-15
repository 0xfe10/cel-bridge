abstract interface class CelBackend {
  Future<String> runtimeInfo();

  Future<String> validate(String environmentJson, String source);

  Future<String> evaluate(
    String environmentJson,
    String source,
    String variablesJson,
  );
}
