import 'package:cel_bridge/cel_bridge.dart';
import 'package:test/test.dart';

const _environment = <String, Object?>{
  'schemaVersion': 1,
  'variables': {
    'age': {'type': 'int'},
    'enabled': {'type': 'bool'},
  },
};

void main() {
  test('evaluateRequests keeps per-item variables and order', () async {
    final runtime = await CelRuntime.initialize();
    final results = await runtime.evaluateRequests(
      environment: _environment,
      requests: const [
        CelEvaluationRequest(
          id: 'adult',
          source: 'age >= 18',
          variables: {'age': 20},
          expectedResultType: 'bool',
        ),
        CelEvaluationRequest(
          id: 'child',
          source: 'age >= 18',
          variables: {'age': 7},
          expectedResultType: 'bool',
        ),
        CelEvaluationRequest(
          id: 'bad',
          source: 'missing == 1',
          variables: {'age': 20},
        ),
      ],
    );
    expect(results, hasLength(3));
    expect(results[0], isA<CelRequestSuccess>());
    expect(results[0].id, 'adult');
    expect(
      ((results[0] as CelRequestSuccess).value as CelBoolValue).value,
      isTrue,
    );
    expect(
      ((results[1] as CelRequestSuccess).value as CelBoolValue).value,
      isFalse,
    );
    expect((results[2] as CelRequestFailure).error.code, 'compile_error');
  });

  test('evaluateRequests rejects duplicate ids before native', () async {
    final runtime = await CelRuntime.initialize();
    expect(
      () => runtime.evaluateRequests(
        environment: _environment,
        requests: const [
          CelEvaluationRequest(id: 'a', source: 'true'),
          CelEvaluationRequest(id: 'a', source: 'false'),
        ],
      ),
      throwsA(
        isA<CelBridgeException>().having(
          (error) => error.code,
          'code',
          'invalid_request',
        ),
      ),
    );
  });

  test('prepare evaluateProgram and releaseProgram', () async {
    final runtime = await CelRuntime.initialize();
    final programId = await runtime.prepare(
      environment: _environment,
      source: 'enabled',
      expectedResultType: 'bool',
    );
    expect(programId, isNotEmpty);
    final value = await runtime.evaluateProgram(
      programId: programId,
      variables: {'enabled': true},
    );
    expect((value as CelBoolValue).value, isTrue);
    await runtime.releaseProgram(programId);
    expect(
      () => runtime.evaluateProgram(
        programId: programId,
        variables: {'enabled': true},
      ),
      throwsA(
        isA<CelBridgeException>().having(
          (error) => error.code,
          'code',
          'program_not_found',
        ),
      ),
    );
  });

  test('evaluateRequests can use a prepared program id', () async {
    final runtime = await CelRuntime.initialize();
    final programId = await runtime.prepare(
      environment: _environment,
      source: 'age > 0',
      expectedResultType: 'bool',
    );
    final results = await runtime.evaluateRequests(
      environment: _environment,
      requests: [
        CelEvaluationRequest(
          id: 'one',
          programId: programId,
          variables: {'age': 2},
        ),
      ],
    );
    expect(results, hasLength(1));
    expect(results.single, isA<CelRequestSuccess>());
    await runtime.releaseProgram(programId);
  });

  test('deadlineMs 0 fails before evaluation', () async {
    final runtime = await CelRuntime.initialize();
    expect(
      () => runtime.evaluate(
        environment: _environment,
        source: 'true',
        variables: const {},
        deadlineMs: 0,
      ),
      throwsA(
        isA<CelBridgeException>().having(
          (error) => error.code,
          'code',
          'deadline_exceeded',
        ),
      ),
    );
  });

  test('runtime info reports ABI capabilities', () async {
    final runtime = await CelRuntime.initialize();
    expect(runtime.info.abiVersion, 4);
    expect(runtime.info.features['perRequestBatch'], isTrue);
    expect(runtime.info.features['preparedPrograms'], isTrue);
    expect(runtime.info.features['deadlines'], isTrue);
    expect(runtime.info.profiles, containsAll(['default', 'safe', 'trusted']));
    expect(runtime.info.limits['maxBatchSize'], 256);
  });
}
