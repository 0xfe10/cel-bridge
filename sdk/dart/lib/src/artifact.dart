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
    for (final target in [...artifactTargets, ...rustArtifactTargets]) {
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
    name: 'ios-arm64-simulator',
    goos: 'ios',
    goarch: 'arm64',
    libraryName: 'libcel_bridge.a',
    staticLinking: true,
  ),
  ArtifactTarget(
    name: 'ios-x86_64-simulator',
    goos: 'ios',
    goarch: 'amd64',
    libraryName: 'libcel_bridge.a',
    staticLinking: true,
  ),
];

const rustArtifactTargets = <ArtifactTarget>[
  ArtifactTarget(
    name: 'rust-linux-x86_64',
    goos: 'linux',
    goarch: 'amd64',
    libraryName: 'libcel_bridge.a',
    staticLinking: true,
  ),
  ArtifactTarget(
    name: 'rust-linux-aarch64',
    goos: 'linux',
    goarch: 'arm64',
    libraryName: 'libcel_bridge.a',
    staticLinking: true,
  ),
  ArtifactTarget(
    name: 'rust-macos-x86_64',
    goos: 'darwin',
    goarch: 'amd64',
    libraryName: 'libcel_bridge.a',
    staticLinking: true,
  ),
  ArtifactTarget(
    name: 'rust-macos-arm64',
    goos: 'darwin',
    goarch: 'arm64',
    libraryName: 'libcel_bridge.a',
    staticLinking: true,
  ),
  ArtifactTarget(
    name: 'rust-windows-x86_64',
    goos: 'windows',
    goarch: 'amd64',
    libraryName: 'cel_bridge.dll',
    staticLinking: false,
  ),
  ArtifactTarget(
    name: 'rust-android-arm64-v8a',
    goos: 'android',
    goarch: 'arm64',
    libraryName: 'libcel_bridge.so',
    staticLinking: false,
  ),
  ArtifactTarget(
    name: 'rust-android-armeabi-v7a',
    goos: 'android',
    goarch: 'arm',
    libraryName: 'libcel_bridge.so',
    staticLinking: false,
  ),
  ArtifactTarget(
    name: 'rust-android-x86_64',
    goos: 'android',
    goarch: 'amd64',
    libraryName: 'libcel_bridge.so',
    staticLinking: false,
  ),
  ArtifactTarget(
    name: 'rust-ios-arm64',
    goos: 'ios',
    goarch: 'arm64',
    libraryName: 'libcel_bridge.a',
    staticLinking: true,
  ),
  ArtifactTarget(
    name: 'rust-ios-arm64-simulator',
    goos: 'ios',
    goarch: 'arm64',
    libraryName: 'libcel_bridge.a',
    staticLinking: true,
  ),
  ArtifactTarget(
    name: 'rust-ios-x86_64-simulator',
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

Directory repositoryRoot(List<String> args) {
  final explicit = parseOption(args, 'root');
  if (explicit != null) return Directory(explicit).absolute;
  final script = File.fromUri(Platform.script).absolute;
  final candidate = script.parent.parent.parent;
  if (File(_join(candidate.path, 'go.mod')).existsSync()) return candidate;
  throw StateError(
    'could not resolve the repository root; pass --root <directory>',
  );
}

Future<ArtifactBuild> buildNativeArtifact({
  required Directory root,
  required ArtifactTarget target,
  required Directory output,
  bool archive = true,
}) async {
  final rawDirectory = Directory(_join(output.path, target.name))
    ..createSync(recursive: true);
  final rawFile = File(_join(rawDirectory.path, target.libraryName));
  final environment = <String, String>{
    ...Platform.environment,
    'CGO_ENABLED': '1',
    'GOOS': target.goos,
    'GOARCH': target.goarch,
  };
  if (target.goos == 'ios') {
    environment.addAll(await _iosCompilerEnvironment(target));
  } else if (target.goos == 'darwin') {
    environment.addAll(await _macosCompilerEnvironment());
  }
  final result = await Process.run(
    'go',
    [
      'build',
      '-trimpath',
      '-buildmode=${target.staticLinking ? 'c-archive' : 'c-shared'}',
      '-o',
      rawFile.path,
      './runtime/cmd/native',
    ],
    workingDirectory: root.path,
    environment: environment,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'Go build failed for ${target.name}: ${result.stdout}\n${result.stderr}',
    );
  }
  if (!rawFile.existsSync()) {
    throw StateError('Go build did not produce ${rawFile.path}');
  }
  final importLibrary = target.goos == 'windows' && target.name.startsWith('rust-')
      ? await _buildWindowsImportLibrary(root, rawFile)
      : null;
  await File(
    '${rawFile.path}.sha256',
  ).writeAsString('${await sha256File(rawFile)}\n', flush: true);
  final archiveFile = archive
      ? File(_join(output.path, _archiveName(target, packageVersion(root))))
      : null;
  if (archiveFile != null) {
    final files = <String, List<int>>{
      target.libraryName: await rawFile.readAsBytes(),
      if (importLibrary != null)
        importLibrary.uri.pathSegments.last: await importLibrary.readAsBytes(),
    };
    await archiveFile.writeAsBytes(
      archiveBytes(files, target.archiveExtension == 'zip'),
      flush: true,
    );
  }
  return ArtifactBuild(target: target, rawFile: rawFile, archive: archiveFile);
}

Future<File> _buildWindowsImportLibrary(Directory root, File dll) async {
  final definition = File(_join(root.path, 'abi/cel_bridge.def'));
  if (!definition.existsSync()) {
    throw StateError(
      'Windows import definition is missing: ${definition.path}',
    );
  }
  final output = File(_join(dll.parent.path, 'cel_bridge.lib'));
  final commands = <(String, List<String>)>[
    (
      'lib.exe',
      ['/DEF:${definition.path}', '/MACHINE:X64', '/OUT:${output.path}'],
    ),
    (
      'llvm-dlltool',
      ['-m', 'i386:x86-64', '-d', definition.path, '-l', output.path],
    ),
  ];
  final failures = <String>[];
  for (final (executable, arguments) in commands) {
    try {
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: root.path,
      );
      if (result.exitCode == 0 &&
          output.existsSync() &&
          output.lengthSync() > 0) {
        return output;
      }
      failures.add('$executable: ${result.stderr}'.trim());
    } catch (error) {
      failures.add('$executable: $error');
    }
  }
  throw StateError(
    'could not create cel_bridge.lib; install MSVC lib.exe or llvm-dlltool '
    '(${failures.join('; ')})',
  );
}

Future<Map<String, String>> _iosCompilerEnvironment(
  ArtifactTarget target,
) async {
  final simulator = target.name.endsWith('-simulator');
  final sdk = simulator ? 'iphonesimulator' : 'iphoneos';
  final sdkPath = await _xcrun(['--sdk', sdk, '--show-sdk-path']);
  final compiler = await _xcrun(['--sdk', sdk, '--find', 'clang']);
  final architecture = target.goarch == 'amd64' ? 'x86_64' : target.goarch;
  final triple = '$architecture-apple-ios${simulator ? '-simulator' : ''}';
  final flags = '-isysroot $sdkPath -target $triple';
  return {
    'CC': compiler,
    'SDKROOT': sdkPath,
    'CGO_CFLAGS_ALLOW': r'-target|-isysroot',
    'CGO_LDFLAGS_ALLOW': r'-target|-isysroot',
    'CGO_CFLAGS': _appendFlags(Platform.environment['CGO_CFLAGS'], flags),
    'CGO_LDFLAGS': _appendFlags(Platform.environment['CGO_LDFLAGS'], flags),
  };
}

Future<Map<String, String>> _macosCompilerEnvironment() async {
  final sdkPath = await _xcrun(['--sdk', 'macosx', '--show-sdk-path']);
  final compiler = await _xcrun(['--sdk', 'macosx', '--find', 'clang']);
  final flags = '-isysroot $sdkPath';
  return {
    'CC': compiler,
    'SDKROOT': sdkPath,
    'CGO_CFLAGS_ALLOW': r'-isysroot',
    'CGO_LDFLAGS_ALLOW': r'-isysroot',
    'CGO_CFLAGS': _appendFlags(Platform.environment['CGO_CFLAGS'], flags),
    'CGO_LDFLAGS': _appendFlags(Platform.environment['CGO_LDFLAGS'], flags),
  };
}

Future<String> _xcrun(List<String> args) async {
  final result = await Process.run('xcrun', args);
  if (result.exitCode != 0) {
    throw StateError('xcrun ${args.join(' ')} failed: ${result.stderr}');
  }
  final value = result.stdout.toString().trim();
  if (value.isEmpty) {
    throw StateError('xcrun ${args.join(' ')} returned no value');
  }
  return value;
}

String _appendFlags(String? existing, String flags) => [
  if (existing != null && existing.trim().isNotEmpty) existing.trim(),
  flags,
].join(' ');

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
    [
      'build',
      '-a',
      '-trimpath',
      '-buildvcs=false',
      '-ldflags=-buildid=cel-bridge-v${packageVersion(root)}',
      '-o',
      wasm.path,
      './runtime/cmd/wasm',
    ],
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
    final target = match.group(1)!;
    final rust = target.startsWith('rust-');
    final platform = rust ? target.substring(5) : target;
    final os = platform.split('-').first;
    entries.add({
      'target': target,
      'consumer': rust ? 'rust' : 'dart',
      'os': os == 'wasm' ? 'web' : os,
      'architecture': _artifactArchitecture(platform),
      'linkage': _artifactLinkage(platform, rust),
      'file': name,
      'sha256': await sha256File(file),
      'size': await file.length(),
    });
  }
  return {
    'manifestVersion': 2,
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

String _artifactArchitecture(String target) {
  if (target == 'wasm') return 'wasm';
  if (target == 'ios-xcframework' || target == 'macos-universal') {
    return 'universal';
  }
  final separator = target.indexOf('-');
  return separator == -1 ? target : target.substring(separator + 1);
}

String _artifactLinkage(String target, bool rust) {
  if (target == 'wasm') return 'wasm';
  if (target == 'ios-xcframework') return 'static';
  if (rust && (target.startsWith('linux-') || target.startsWith('macos-'))) {
    return 'static';
  }
  if (rust && target.startsWith('ios-')) return 'static';
  return 'dynamic';
}

String _archiveName(ArtifactTarget target, String version) =>
    'cel-bridge-${target.name}-v$version.${target.archiveExtension}';

String _join(String parent, String child) =>
    '$parent${Platform.pathSeparator}$child';
