import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  try {
    final root = _root(args);
    final schemaRoot = Directory('${root.path}/protocol/schema');
    for (final name in [
      'environment.schema.json',
      'response.schema.json',
      'value.schema.json',
      'type.schema.json',
    ]) {
      final schema = _object(
        jsonDecode(await File('${schemaRoot.path}/$name').readAsString()),
        name,
      );
      _require(schema, r'$schema', name);
      _require(schema, r'$id', name);
      if (!schema.containsKey('type') && !schema.containsKey(r'$ref')) {
        throw StateError('$name must declare a type or reference');
      }
    }

    final conformance = _list(
      jsonDecode(
        await File(
          '${root.path}/protocol/testdata/conformance_cases.json',
        ).readAsString(),
      ),
      'conformance cases',
    );
    if (conformance.isEmpty) throw StateError('conformance cases are empty');
    for (final item in conformance) {
      final value = _object(item, 'conformance case');
      _string(value['name'], 'conformance.name');
      _string(value['source'], 'conformance.source');
      _environment(value['environment']);
      _value(value['expected']);
    }

    final errors = _list(
      jsonDecode(
        await File(
          '${root.path}/protocol/testdata/error_cases.json',
        ).readAsString(),
      ),
      'error cases',
    );
    if (errors.isEmpty) throw StateError('error cases are empty');
    for (final item in errors) {
      final value = _object(item, 'error case');
      _string(value['name'], 'error.name');
      final operation = _string(value['operation'], 'error.operation');
      if (operation != 'validate' && operation != 'evaluate') {
        throw StateError('unsupported error operation $operation');
      }
      _string(value['source'], 'error.source');
      _string(value['expectedCode'], 'error.expectedCode');
      _environment(value['environment']);
    }
    final typeContract = _list(
      jsonDecode(
        await File(
          '${root.path}/protocol/testdata/type_contract_cases.json',
        ).readAsString(),
      ),
      'type contract cases',
    );
    if (typeContract.isEmpty) throw StateError('type contract cases are empty');
    for (final item in typeContract) {
      final value = _object(item, 'type contract case');
      _string(value['name'], 'typeContract.name');
      _string(value['source'], 'typeContract.source');
      final operation = _string(value['operation'], 'typeContract.operation');
      if (operation != 'validate' && operation != 'evaluate') {
        throw StateError('unsupported type contract operation $operation');
      }
      _environment(value['environment']);
      if (value.containsKey('expectedResultType')) {
        _expectedType(value['expectedResultType']);
      }
      if (value.containsKey('resultType')) {
        _type(value['resultType']);
      }
      if (value.containsKey('expected')) {
        _value(value['expected']);
      }
    }
    final evaluateRequests = _list(
      jsonDecode(
        await File(
          '${root.path}/protocol/testdata/evaluate_requests_cases.json',
        ).readAsString(),
      ),
      'evaluate requests cases',
    );
    if (evaluateRequests.isEmpty) {
      throw StateError('evaluate requests cases are empty');
    }
    for (final item in evaluateRequests) {
      final value = _object(item, 'evaluate requests case');
      _string(value['name'], 'evaluateRequests.name');
      _environment(value['environment']);
      final requests = _list(value['requests'], 'evaluateRequests.requests');
      if (requests.isEmpty) {
        throw StateError('evaluateRequests.requests must not be empty');
      }
      final ids = <String>{};
      for (final request in requests) {
        final item = _object(request, 'evaluateRequests.request');
        final id = _string(item['id'], 'evaluateRequests.request.id');
        ids.add(id);
        if (item.containsKey('source') && item['source'] != null) {
          _string(item['source'], 'evaluateRequests.request.source');
        }
        if (item.containsKey('expectedResultType')) {
          _expectedType(item['expectedResultType']);
        }
      }
      if (value['ok'] == false) {
        _string(value['expectedCode'], 'evaluateRequests.expectedCode');
        continue;
      }
      if (value['ok'] != true) {
        throw StateError('evaluateRequests.ok must be a boolean');
      }
      if (ids.length != requests.length) {
        // Duplicate ids are allowed only as a whole-batch failure case.
        throw StateError(
          'evaluateRequests successful cases must use unique request ids',
        );
      }
      final results = _list(value['results'], 'evaluateRequests.results');
      if (results.length != requests.length) {
        throw StateError('evaluateRequests.results length must match requests');
      }
      for (final result in results) {
        final item = _object(result, 'evaluateRequests.result');
        _string(item['id'], 'evaluateRequests.result.id');
        if (item['ok'] == false) {
          _string(item['expectedCode'], 'evaluateRequests.result.expectedCode');
          continue;
        }
        if (item['ok'] != true) {
          throw StateError('evaluateRequests.result.ok must be a boolean');
        }
        _value(item['expected']);
      }
    }

    stdout.writeln(
      'protocol version 1 verified: '
      '${conformance.length} conformance case(s), ${errors.length} error case(s), '
      '${typeContract.length} type contract case(s), '
      '${evaluateRequests.length} evaluate requests case(s)',
    );
  } catch (error) {
    stderr.writeln('verify_protocol: $error');
    exitCode = 1;
  }
}

Directory _root(List<String> args) {
  final index = args.indexOf('--root');
  if (index != -1) {
    if (index + 1 >= args.length) {
      throw ArgumentError('--root requires a value');
    }
    return Directory(args[index + 1]).absolute;
  }
  return repositoryRoot();
}

Directory repositoryRoot() {
  final candidate = File.fromUri(Platform.script).absolute.parent.parent.parent;
  if (File('${candidate.path}/go.mod').existsSync()) return candidate;
  throw StateError(
    'pass --root <repository> when running outside the checkout',
  );
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  throw StateError('$name must be an object');
}

List<Object?> _list(Object? value, String name) {
  if (value is List) return value;
  throw StateError('$name must be an array');
}

String _string(Object? value, String name) {
  if (value is String && value.isNotEmpty) return value;
  throw StateError('$name must be a non-empty string');
}

void _require(Map<String, Object?> value, String key, String name) {
  if (!value.containsKey(key)) throw StateError('$name is missing $key');
}

void _environment(Object? raw) {
  final value = _object(raw, 'environment');
  if (value['schemaVersion'] != 1) {
    throw StateError('environment.schemaVersion must be 1');
  }
  final variables = _object(value['variables'], 'environment.variables');
  for (final entry in variables.entries) {
    _string(entry.key, 'environment variable name');
    _type(entry.value);
  }
}

void _expectedType(Object? raw) {
  if (raw is String) {
    _type({'type': raw});
    return;
  }
  _type(raw);
}

void _type(Object? raw) {
  final value = _object(raw, 'type specification');
  final kind = _string(value['type'], 'type specification.type');
  const scalar = {
    'null',
    'bool',
    'int',
    'uint',
    'double',
    'string',
    'bytes',
    'timestamp',
    'duration',
    'dyn',
  };
  if (scalar.contains(kind)) return;
  if (kind == 'list') {
    _type(value['element']);
    return;
  }
  if (kind == 'map') {
    _type(value['key']);
    _type(value['value']);
    return;
  }
  throw StateError('unsupported type $kind');
}

void _value(Object? raw) {
  final value = _object(raw, 'CEL value');
  if (value.containsKey(r'$cel_bridge') && value[r'$cel_bridge'] != true) {
    throw StateError('CEL value marker must be true when present');
  }
  final kind = _string(value['kind'], 'CEL value.kind');
  if (kind == 'list') {
    for (final item in _list(value['items'], 'CEL value.items')) {
      _value(item);
    }
    return;
  }
  if (kind == 'map') {
    for (final item in _list(value['entries'], 'CEL value.entries')) {
      final entry = _object(item, 'map entry');
      _value(entry['key']);
      _value(entry['value']);
    }
    return;
  }
  const kinds = {
    'null',
    'bool',
    'int',
    'uint',
    'double',
    'string',
    'bytes',
    'timestamp',
    'duration',
  };
  if (!kinds.contains(kind)) throw StateError('unsupported CEL value $kind');
  if (kind != 'null' && !value.containsKey('value')) {
    throw StateError('$kind CEL value is missing value');
  }
}
