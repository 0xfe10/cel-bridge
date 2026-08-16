import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';

import 'package:cel_bridge/src/artifact.dart';

void main() {
  test('uses release target names accepted by the build hook', () {
    expect(
      artifactTargets.map((target) => target.name),
      containsAll(<String>[
        'linux-x86_64',
        'android-arm64-v8a',
        'ios-arm64',
        'windows-x86_64',
      ]),
    );
  });

  test('does not advertise deferred desktop ARM targets', () {
    expect(
      () => ArtifactTarget.parse('linux-aarch64'),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => ArtifactTarget.parse('windows-arm64'),
      throwsA(isA<ArgumentError>()),
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
