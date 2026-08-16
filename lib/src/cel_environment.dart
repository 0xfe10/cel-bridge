final class CelEnvironment {
  const CelEnvironment({required this.variables, this.schemaVersion = 1});

  final int schemaVersion;
  final Map<String, Object?> variables;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'variables': variables,
  };
}
