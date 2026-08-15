import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';

const _runtimeVersion = '0.1.0';
const _protocolVersion = 1;
const _releaseBase =
    'https://github.com/0xfe10/cel-bridge/releases/download/v$_runtimeVersion';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final code = input.config.code;
    final target = _target(code.targetOS, code.targetArchitecture);
    final sourceBuild = _asBool(input.userDefines['build_from_source']);
    final libraryName = _libraryName(code.targetOS, target.staticLinking);
    final assetPath = input.outputDirectory.resolve(libraryName);
    final versionFile = File.fromUri(input.packageRoot.resolve('VERSION'));
    output.dependencies.add(versionFile.uri);

    if (sourceBuild) {
      await _buildFromSource(input, target, assetPath, libraryName);
      output.dependencies.add(input.packageRoot);
    } else {
      await _downloadArtifact(input, output, target, libraryName, assetPath);
    }

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'cel_bridge',
        file: assetPath,
        linkMode: target.staticLinking
            ? StaticLinking()
            : DynamicLoadingBundled(),
      ),
    );
  });
}

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is String) return value == '1' || value.toLowerCase() == 'true';
  return false;
}

_Target _target(OS os, Architecture architecture) {
  final arch = switch (architecture.name) {
    'arm' => 'arm',
    'arm64' => 'arm64',
    'ia32' => '386',
    'riscv64' => 'riscv64',
    'x64' => 'amd64',
    final value => throw UnsupportedError('unsupported architecture $value'),
  };
  final goos = switch (os) {
    OS.android => 'android',
    OS.iOS => 'ios',
    OS.linux => 'linux',
    OS.macOS => 'darwin',
    OS.windows => 'windows',
    final value => throw UnsupportedError(
      'unsupported operating system $value',
    ),
  };
  return _Target(
    os: os,
    goos: goos,
    goarch: arch,
    name: '${os.name}-$arch',
    staticLinking: os == OS.iOS,
  );
}

String _libraryName(OS os, bool staticLinking) {
  if (staticLinking) return 'libcel_bridge.a';
  return switch (os) {
    OS.windows => 'cel_bridge.dll',
    OS.macOS => 'libcel_bridge.dylib',
    _ => 'libcel_bridge.so',
  };
}

Future<void> _downloadArtifact(
  BuildInput input,
  BuildOutputBuilder output,
  _Target target,
  String libraryName,
  Uri assetPath,
) async {
  final manifestUri = Uri.parse(
    '$_releaseBase/cel-bridge-manifest-v$_runtimeVersion.json',
  );
  final localDirectory = input.userDefines.path('artifact_directory');
  if (localDirectory != null) {
    output.dependencies.add(localDirectory);
    final localFile = File.fromUri(
      Directory.fromUri(localDirectory).uri.resolve(libraryName),
    );
    if (!localFile.existsSync()) {
      throw StateError('local artifact directory has no $libraryName');
    }
    await localFile.copy(assetPath.toFilePath());
    return;
  }
  final manifest = await _getJson(manifestUri);
  if (manifest['manifestVersion'] != 1 ||
      manifest['runtimeVersion'] != _runtimeVersion ||
      manifest['protocolVersion'] != _protocolVersion) {
    throw StateError(
      'release manifest does not match cel_bridge $_runtimeVersion',
    );
  }
  final artifacts = manifest['artifacts'];
  if (artifacts is! List) {
    throw StateError('release manifest artifacts is not a list');
  }
  Map<String, Object?>? artifact;
  for (final item in artifacts) {
    if (item is Map && item['target'] == target.name) {
      artifact = item.map((key, value) => MapEntry(key.toString(), value));
      break;
    }
  }
  if (artifact == null) {
    throw StateError('release has no native artifact for ${target.name}');
  }
  final file = _requiredString(artifact['file'], 'artifact.file');
  final expectedHash = _requiredString(artifact['sha256'], 'artifact.sha256');
  final expectedSize = artifact['size'];
  if (expectedSize is! int) throw StateError('artifact.size is not an integer');
  final archiveUri = Uri.parse('$_releaseBase/$file');
  final archivePath = input.outputDirectory.resolve(file);
  final archiveFile = File.fromUri(archivePath);
  final bytes = await _download(archiveUri);
  if (bytes.length != expectedSize) {
    throw StateError('artifact size mismatch for $archiveUri');
  }
  if (sha256.convert(bytes).toString() != expectedHash) {
    throw StateError('artifact SHA-256 mismatch for $archiveUri');
  }
  await archiveFile.writeAsBytes(bytes, flush: true);
  final library = _extractLibrary(bytes, file, libraryName);
  await File.fromUri(assetPath).writeAsBytes(library, flush: true);
}

Future<void> _buildFromSource(
  BuildInput input,
  _Target target,
  Uri assetPath,
  String libraryName,
) async {
  final go = await Process.run('go', ['version']);
  final version = '${go.stdout}\n${go.stderr}';
  if (!RegExp(r'go1\.26(?:\.|\s)').hasMatch(version)) {
    throw StateError('source build requires Go 1.26; got ${version.trim()}');
  }
  final staticLinking = target.staticLinking;
  final result = await Process.run(
    'go',
    [
      'build',
      '-trimpath',
      '-buildmode=${staticLinking ? 'c-archive' : 'c-shared'}',
      '-o',
      assetPath.toFilePath(),
      './cmd/cel-bridge-native',
    ],
    workingDirectory: input.packageRoot.toFilePath(),
    environment: {
      ...Platform.environment,
      'CGO_ENABLED': '1',
      'GOOS': target.goos,
      'GOARCH': target.goarch,
    },
  );
  if (result.exitCode != 0) {
    throw StateError(
      'Go source build failed for ${target.name}: '
      '${result.stdout}\n${result.stderr}',
    );
  }
  if (!File.fromUri(assetPath).existsSync()) {
    throw StateError('Go source build did not produce $libraryName');
  }
}

Future<Map<String, Object?>> _getJson(Uri uri) async {
  final bytes = await _download(uri);
  final value = jsonDecode(utf8.decode(bytes));
  if (value is! Map) {
    throw StateError('JSON manifest at $uri is not an object');
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

Future<Uint8List> _download(Uri uri) async {
  if (uri.scheme != 'https') {
    throw StateError('artifact URL must use HTTPS: $uri');
  }
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(
        'download failed with HTTP ${response.statusCode}: $uri',
      );
    }
    return Uint8List.fromList(
      await response.fold<List<int>>([], (all, chunk) {
        all.addAll(chunk);
        return all;
      }),
    );
  } finally {
    client.close(force: true);
  }
}

Uint8List _extractLibrary(
  List<int> bytes,
  String archiveName,
  String libraryName,
) {
  final archive = archiveName.endsWith('.zip')
      ? ZipDecoder().decodeBytes(bytes)
      : TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
  for (final file in archive.files) {
    final normalized = file.name.replaceAll('\\', '/');
    final segments = normalized.split('/');
    if (segments.any((segment) => segment == '..') ||
        normalized.startsWith('/')) {
      throw StateError('archive contains an unsafe path: ${file.name}');
    }
    if (!file.isFile || segments.last != libraryName) continue;
    final content = file.readBytes();
    if (content == null) {
      throw StateError('archive entry has no content: ${file.name}');
    }
    return content;
  }
  throw StateError('archive does not contain $libraryName');
}

String _requiredString(Object? value, String name) {
  if (value is String && value.isNotEmpty) return value;
  throw StateError('$name must be a non-empty string');
}

final class _Target {
  const _Target({
    required this.os,
    required this.goos,
    required this.goarch,
    required this.name,
    required this.staticLinking,
  });

  final OS os;
  final String goos;
  final String goarch;
  final String name;
  final bool staticLinking;
}
