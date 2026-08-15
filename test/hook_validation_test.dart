import 'package:test/test.dart';

import '../hook/build.dart';

void main() {
  test('accepts only the expected release artifact filename', () {
    expect(
      validateReleaseArtifactFile(
        file: 'cel-bridge-linux-x86_64-v0.1.0.tar.gz',
        target: 'linux-x86_64',
        version: '0.1.0',
        goos: 'linux',
      ),
      'cel-bridge-linux-x86_64-v0.1.0.tar.gz',
    );
  });

  test('rejects path traversal and absolute artifact filenames', () {
    for (final file in [
      '../pubspec.yaml',
      '/tmp/cel-bridge-linux-x86_64-v0.1.0.tar.gz',
      r'..\pubspec.yaml',
      'cel-bridge-linux-x86_64-v0.1.0.tar.gz/../../pubspec.yaml',
    ]) {
      expect(
        () => validateReleaseArtifactFile(
          file: file,
          target: 'linux-x86_64',
          version: '0.1.0',
          goos: 'linux',
        ),
        throwsA(isA<StateError>()),
      );
    }
  });
}
