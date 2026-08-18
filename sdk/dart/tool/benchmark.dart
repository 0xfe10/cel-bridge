import 'package:cel_bridge/cel_bridge.dart';
import 'package:cel_bridge/src/backend/ffi/native_worker.dart';

const _environment = <String, Object?>{
  'schemaVersion': 1,
  'variables': {
    'age': {'type': 'int'},
  },
};

Future<void> main() async {
  final runtime = await CelRuntime.initialize();
  await _time('runtimeInfo', () async {
    // ignore: unused_local_variable
    final _ = runtime.info.runtimeVersion;
  });
  await _time('evaluate simple', () async {
    await runtime.evaluate(
      environment: _environment,
      source: 'age >= 18',
      variables: {'age': 20},
    );
  });
  await _time('evaluate 30 serial', () async {
    for (var i = 0; i < 30; i++) {
      await runtime.evaluate(
        environment: _environment,
        source: 'age >= $i',
        variables: {'age': 20},
      );
    }
  });
  await _time('evaluate 30 concurrent', () async {
    await Future.wait([
      for (var i = 0; i < 30; i++)
        runtime.evaluate(
          environment: _environment,
          source: 'age >= $i',
          variables: {'age': 20},
        ),
    ]);
  });
  await _time('evaluateMany 30', () async {
    await runtime.evaluateMany(
      environment: _environment,
      sources: [for (var i = 0; i < 30; i++) 'age >= $i'],
      variables: {'age': 20},
    );
  });
  await _time('100 updates x 30 evaluateMany', () async {
    final sources = [for (var i = 0; i < 30; i++) 'age >= $i'];
    for (var update = 0; update < 100; update++) {
      await runtime.evaluateMany(
        environment: _environment,
        sources: sources,
        variables: {'age': update},
      );
    }
  });
  await closeNativeWorkerForTesting();
}

Future<void> _time(String name, Future<void> Function() action) async {
  final sw = Stopwatch()..start();
  await action();
  sw.stop();
  stdoutWrite('$name: ${sw.elapsedMicroseconds} us');
}

void stdoutWrite(String line) {
  // ignore: avoid_print
  print(line);
}
