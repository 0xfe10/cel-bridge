import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';

import 'package:cel_bridge/src/artifact.dart';

void main() {
  test('uses release target names accepted by the build hook', () {
    expect(
      artifactTargets.map((target) => target.name),
      containsAll(<String>[
        'linux-x86_64-dynamic',
        'linux-x86_64-static',
        'linux-aarch64-dynamic',
        'linux-aarch64-static',
        'android-arm64-v8a',
        'ios-arm64',
        'windows-x86_64',
      ]),
    );
    expect(
      artifactTargets.map((target) => target.name),
      isNot(contains('rust-linux-x86_64')),
    );
  });

  test('publishes runtime artifacts without language-specific targets', () {
    expect(
      releaseArtifactSpecs.map((artifact) => artifact.id),
      containsAll(<String>[
        'android-arm64-v8a',
        'ios-xcframework',
        'linux-x86_64-dynamic',
        'linux-x86_64-static',
        'windows-x86_64',
      ]),
    );
    expect(
      releaseArtifactSpecs.any((artifact) => artifact.id.startsWith('rust-')),
      isFalse,
    );
  });

  test('does not advertise deferred Windows ARM targets', () {
    expect(
      () => ArtifactTarget.parse('windows-arm64'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('uses the package-local artifact cache consumed by the hook', () {
    expect(
      artifactCacheDirectory(Uri.file('/packages/cel_bridge/'), '0.3.1'),
      Uri.file('/packages/cel_bridge/.dart_tool/cel_bridge/artifacts/0.3.1/'),
    );
  });

  test('archives files at safe root paths', () {
    final bytes = archiveBytes({
      'libcel_bridge.so': <int>[1, 2, 3],
    }, false);
    final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    expect(archive.files, hasLength(1));
    expect(archive.files.single.name, 'libcel_bridge.so');
    expect(
      archive.files.single.readBytes(),
      Uint8List.fromList(<int>[1, 2, 3]),
    );
  });
}
