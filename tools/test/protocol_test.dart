import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';

void main() {
  test('shared protocol fixtures are valid JSON arrays', () {
    for (final name in ['conformance_cases.json', 'error_cases.json']) {
      final file = File('../protocol/testdata/$name');
      final value = jsonDecode(file.readAsStringSync());
      expect(value, isA<List>(), reason: name);
      expect((value as List), isNotEmpty, reason: name);
    }
  });

  test('protocol schemas declare the protocol contract', () {
    for (final name in [
      'environment.schema.json',
      'response.schema.json',
      'value.schema.json',
    ]) {
      final value =
          jsonDecode(File('../protocol/schema/$name').readAsStringSync())
              as Map;
      expect(value[r'$schema'], isA<String>(), reason: name);
      expect(value[r'$id'], isA<String>(), reason: name);
    }
  });

  test('environment schema matches runtime type rules', () {
    final schema = _schema('environment.schema.json');
    expect(
      schema.validate({
        'schemaVersion': 1,
        'variables': {
          'items': {
            'type': 'list',
            'element': {
              'type': 'map',
              'key': {'type': 'string'},
              'value': {'type': 'dyn'},
            },
          },
        },
      }).isValid,
      isTrue,
    );
    for (final value in [
      {
        'schemaVersion': 1,
        'variables': {
          'items': {'type': 'list'},
        },
      },
      {
        'schemaVersion': 1,
        'variables': {
          'name': {
            'type': 'string',
            'element': {'type': 'int'},
          },
        },
      },
      {
        'schemaVersion': 1,
        'variables': {
          'items': {
            'type': 'map',
            'key': {'type': 'double'},
            'value': {'type': 'string'},
          },
        },
      },
    ]) {
      expect(schema.validate(value).isValid, isFalse, reason: '$value');
    }
  });

  test('value schema enforces tagged value shapes', () {
    final schema = _schema('value.schema.json');
    expect(
      schema.validate({
        'kind': 'map',
        'entries': [
          {
            'key': {'kind': 'int', 'value': '1'},
            'value': {
              r'$cel_bridge': true,
              'kind': 'list',
              'items': [
                {'kind': 'bool', 'value': true},
              ],
            },
          },
        ],
      }).isValid,
      isTrue,
    );
    for (final value in [
      {'kind': 'int', 'value': 1},
      {'kind': 'uint', 'value': '-1'},
      {'kind': 'null', 'value': null},
      {'kind': 'bool', 'value': true, 'extra': true},
      {r'$cel_bridge': false, 'kind': 'string', 'value': 'bad marker'},
    ]) {
      expect(schema.validate(value).isValid, isFalse, reason: '$value');
    }
  });
}

JsonSchema _schema(String name) => JsonSchema.create(
  jsonDecode(File('../protocol/schema/$name').readAsStringSync()),
);
