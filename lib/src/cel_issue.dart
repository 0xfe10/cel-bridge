final class CelIssue {
  const CelIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.line = 0,
    this.column = 0,
  });

  factory CelIssue.fromJson(Object? json) {
    final value = _object(json, 'issue');
    return CelIssue(
      severity: _string(value['severity'], 'issue.severity'),
      code: _string(value['code'], 'issue.code'),
      message: _string(value['message'], 'issue.message'),
      line: _integer(value['line'], 'issue.line', optional: true),
      column: _integer(value['column'], 'issue.column', optional: true),
    );
  }

  final String severity;
  final String code;
  final String message;
  final int line;
  final int column;
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  throw FormatException('$name must be an object');
}

String _string(Object? value, String name) {
  if (value is String) {
    return value;
  }
  throw FormatException('$name must be a string');
}

int _integer(Object? value, String name, {bool optional = false}) {
  if (value == null && optional) {
    return 0;
  }
  if (value is int) {
    return value;
  }
  throw FormatException('$name must be an integer');
}
