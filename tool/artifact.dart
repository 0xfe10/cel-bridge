import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

const protocolVersion = 1;

final class ArtifactTarget {
  const ArtifactTarget({
    required this.name,
    required this.goos,
    required this.goarch,
    required this.libraryName,
    required this.staticLinking,
  });

  final String name;
  final String goos;
  final String goarch;
  final String libraryName;
  final bool staticLinking;

  String get archiveExtension => goos == 'windows' ? 'zip' : 'tar.gz';

  static ArtifactTarget parse(String name) {
    for (final target in artifactTargets) {
      if (target.name == name) return target;
    }
    throw ArgumentError('unsupported artifact target $name');
  }
}

const artifactTargets = <ArtifactTarget>[
  ArtifactTarget(
    name: 'linux-x86_64',
    goos: 'linux',
    goarch: 'amd64',
    libraryName: 'libcel_bridge.so',
    staticLinking: false,
  ),
  ArtifactTarget(
    name: 'linux-aarch64',
    goos: 'linux',
    goarch: 'arm64',
    libraryName: 'libcel_bridge.so',
    staticLinking: false,
  ),
  ArtifactTarget(
    name: 'macos-x86_64',
    goos: 'darwin',
    goarch: 'amd64',
    libraryName: 'libcel_bridge.dylib',
    staticLinking: false,
  ),
  ArtifactTarget(
    name: 'macos-arm64',
    goos: 'darwin',
    goarch: 'arm64',
    libraryName: 'libcel_bridge.dylib',
    staticLinking: false,
  ),
  ArtifactTarget(
    name: 'windows-x86_64',
    goos: 'windows',
    goarch: 'amd64',
    libraryName: 'cel_bridge.dll',
    staticLinking: false,
  ),
  ArtifactTarget(
    name: 'windows-arm64',
    goos: 'windows',
    goarch: 'arm64',
    libraryName: 'cel_bridge.dll',
    staticLinking: false,
  ),
  ArtifactTarget(
    name: 'android-arm64-v8a',
    goos: 'android',
    goarch: 'arm64',
    libraryName: 'libcel_bridge.so',
    staticLinking: false,
  ),
  ArtifactTarget(
    name: 'android-armeabi-v7a',
    goos: 'android',
    goarch: 'arm',
    libraryName: 'libcel_bridge.so',
    staticLinking: false,
  ),
  ArtifactTarget(
    name: 'android-x86_64',
    goos: 'android',
    goarch: 'amd64',
    libraryName: 'libcel_bridge.so',
    staticLinking: false,
  ),
  ArtifactTarget(
    name: 'ios-arm64',
    goos: 'ios',
    goarch: 'arm64',
    libraryName: 'libcel_bridge.a',
    staticLinking: true,
  ),
  ArtifactTarget(
    name: 'ios-x86_64',
    goos: 'ios',
    goarch: 'amd64',
    libraryName: 'libcel_bridge.a',
    staticLinking: true,
  ),
];

final class ArtifactBuild {
  const ArtifactBuild({
    required this.target,
    required this.rawFile,
    this.archive,
  });

  final ArtifactTarget target;
  final File rawFile;
  final File? archive;
}

final class WasmBuild {
  const WasmBuild({required this.wasm, required this.wasmExec, this.archive});

  final File wasm;
  final File wasmExec;
  final File? archive;
}

String packageVersion(Directory root) =>
    File(_join(root.path, 'VERSION')).readAsStringSync().trim();

String celGoVersion(Directory root) {
  final source = File(_join(root.path, 'go.mod')).readAsStringSync();
  final match = RegExp(
    r'github\.com/google/cel-go\s+(\S+)',
    multiLine: true,
  ).firstMatch(source);
  if (match == null) throw StateError('go.mod has no cel-go version');
  return match.group(1)!;
}

String? parseOption(List<String> args, String name) {
  final index = args.indexOf('--$name');
  if (index == -1) return null;
  if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
    throw ArgumentError('--$name requires a value');
  }
  return args[index + 1];
}

bool hasOption(List<String> args, String name) => args.contains('--$name');

Future<ArtifactBuild> buildNativeArtifact({
  required Directory root,
  required ArtifactTarget target,
  required Directory output,
  bool archive = true,
}) async {
  final rawDirectory = Directory(_join(output.path, target.name))
    ..createSync(recursive: true);
  final rawFile = File(_join(rawDirectory.path, target.libraryName));
  final result = await Process.run(
    'go',
    [
      'build',
      '-trimpath',
      '-buildmode=${target.staticLinking ? 'c-archive' : 'c-shared'}',
      '-o',
      rawFile.path,
      './cmd/cel-bridge-native',
    ],
    workingDirectory: root.path,
    environment: {
      ...Platform.environment,
      'CGO_ENABLED': '1',
      'GOOS': target.goos,
      'GOARCH': target.goarch,
    },
  );
  if (result.exitCode != 0) {
    throw StateError(
      'Go build failed for ${target.name}: ${result.stdout}\n${result.stderr}',
    );
  }
  if (!rawFile.existsSync()) {
    throw StateError('Go build did not produce ${rawFile.path}');
  }
  final archiveFile = archive
      ? File(_join(output.path, _archiveName(target, packageVersion(root))))
      : null;
  if (archiveFile != null) {
    await archiveFile.writeAsBytes(
      archiveBytes({
        target.libraryName: await rawFile.readAsBytes(),
      }, target.archiveExtension == 'zip'),
      flush: true,
    );
  }
  return ArtifactBuild(target: target, rawFile: rawFile, archive: archiveFile);
}

Future<WasmBuild> buildWasmArtifact({
  required Directory root,
  required Directory output,
  bool archive = true,
}) async {
  final rawDirectory = Directory(_join(output.path, 'wasm'))
    ..createSync(recursive: true);
  final wasm = File(_join(rawDirectory.path, 'cel_bridge.wasm'));
  final result = await Process.run(
    'go',
    ['build', '-trimpath', '-o', wasm.path, './cmd/cel-bridge-wasm'],
    workingDirectory: root.path,
    environment: {
      ...Platform.environment,
      'CGO_ENABLED': '0',
      'GOOS': 'js',
      'GOARCH': 'wasm',
    },
  );
  if (result.exitCode != 0) {
    throw StateError(
      'Go Wasm build failed: ${result.stdout}\n${result.stderr}',
    );
  }
  final goRootResult = await Process.run('go', ['env', 'GOROOT']);
  if (goRootResult.exitCode != 0) {
    throw StateError('could not locate Go GOROOT: ${goRootResult.stderr}');
  }
  final wasmExec = File(
    _join(goRootResult.stdout.toString().trim(), 'lib/wasm/wasm_exec.js'),
  );
  if (!wasm.existsSync() || !wasmExec.existsSync()) {
    throw StateError('Go Wasm output or wasm_exec.js is missing');
  }
  final copiedExec = File(_join(rawDirectory.path, 'wasm_exec.js'));
  await wasmExec.copy(copiedExec.path);
  final archiveFile = archive
      ? File(
          _join(output.path, 'cel-bridge-wasm-v${packageVersion(root)}.tar.gz'),
        )
      : null;
  if (archiveFile != null) {
    await archiveFile.writeAsBytes(
      archiveBytes({
        'cel_bridge.wasm': await wasm.readAsBytes(),
        'wasm_exec.js': await copiedExec.readAsBytes(),
      }, false),
      flush: true,
    );
  }
  return WasmBuild(wasm: wasm, wasmExec: copiedExec, archive: archiveFile);
}

Uint8List archiveBytes(Map<String, List<int>> files, bool zip) {
  final archive = Archive();
  for (final entry
      in files.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key))) {
    if (entry.key.isEmpty ||
        entry.key.startsWith('/') ||
        entry.key.split('/').contains('..')) {
      throw ArgumentError('archive entry has an unsafe path: ${entry.key}');
    }
    archive.add(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  if (zip) return ZipEncoder().encodeBytes(archive);
  return GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive));
}

Future<String> sha256File(File file) async {
  return sha256.convert(await file.readAsBytes()).toString();
}

Future<Map<String, Object?>> manifest({
  required Directory root,
  required Iterable<File> archives,
}) async {
  final version = packageVersion(root);
  final entries = <Map<String, Object?>>[];
  for (final file
      in archives.toList()
        ..sort((left, right) => left.path.compareTo(right.path))) {
    final name = file.uri.pathSegments.last;
    final match = RegExp(
      r'^cel-bridge-(.+)-v(.+)\.(tar\.gz|zip)$',
    ).firstMatch(name);
    if (match == null || match.group(2) != version) continue;
    entries.add({
      'target': match.group(1)!,
      'architecture': match
          .group(1)!
          .substring(match.group(1)!.indexOf('-') + 1),
      'file': name,
      'sha256': await sha256File(file),
      'size': await file.length(),
    });
  }
  return {
    'manifestVersion': 1,
    'runtimeVersion': version,
    'protocolVersion': protocolVersion,
    'goVersion': await goVersion(),
    'celGoVersion': celGoVersion(root),
    'artifacts': entries,
  };
}

Future<String> goVersion() async {
  final result = await Process.run('go', ['version']);
  if (result.exitCode != 0) throw StateError('could not run go version');
  final match = RegExp(
    r'go(\d+(?:\.\d+){1,2})',
  ).firstMatch(result.stdout.toString());
  if (match == null) throw StateError('could not parse go version');
  return match.group(1)!;
}

String manifestFileName(String version) => 'cel-bridge-manifest-v$version.json';

String _archiveName(ArtifactTarget target, String version) =>
    'cel-bridge-${target.name}-v$version.${target.archiveExtension}';

String _join(String parent, String child) =>
    '$parent${Platform.pathSeparator}$child';
