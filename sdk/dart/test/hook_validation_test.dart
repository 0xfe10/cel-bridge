import 'package:test/test.dart';

import '../hook/build.dart';

void main() {
  test('accepts only the expected release artifact filename', () {
    expect(
      validateReleaseArtifactFile(
        file: 'cel-bridge-linux-x86_64-dynamic-v0.3.2.tar.gz',
        artifactId: 'linux-x86_64-dynamic',
        version: '0.3.2',
        format: 'tar.gz',
      ),
      'cel-bridge-linux-x86_64-dynamic-v0.3.2.tar.gz',
    );
  });

  test('rejects path traversal and absolute artifact filenames', () {
    for (final file in [
      '../pubspec.yaml',
      '/tmp/cel-bridge-linux-x86_64-dynamic-v0.3.2.tar.gz',
      r'..\pubspec.yaml',
      'cel-bridge-linux-x86_64-dynamic-v0.3.2.tar.gz/../../pubspec.yaml',
    ]) {
      expect(
        () => validateReleaseArtifactFile(
          file: file,
          artifactId: 'linux-x86_64-dynamic',
          version: '0.3.2',
          format: 'tar.gz',
        ),
        throwsA(isA<StateError>()),
      );
    }
  });

  test('does not allow an HTTPS download to redirect to HTTP', () {
    expect(
      () => validateArtifactDownloadUri(
        Uri.parse('http://127.0.0.1:8125/artifact'),
        allowInsecure: true,
        requireHttps: true,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('allows HTTP only for explicit localhost testing', () {
    expect(
      () => validateArtifactDownloadUri(
        Uri.parse('http://127.0.0.1:8125/artifact'),
        allowInsecure: true,
        requireHttps: false,
      ),
      returnsNormally,
    );
    expect(
      () => validateArtifactDownloadUri(
        Uri.parse('http://example.com/artifact'),
        allowInsecure: true,
        requireHttps: false,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
