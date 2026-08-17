import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _timeout = Duration(seconds: 60);

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError('usage: dart run bin/web_smoke_runner.dart <url>');
  }

  final portSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = portSocket.port;
  await portSocket.close();
  final profile = await Directory.systemTemp.createTemp('cel_bridge_chrome_');
  final chrome = Platform.environment['CHROME_BIN'] ?? 'google-chrome';
  final process = await Process.start(chrome, [
    '--headless',
    '--no-sandbox',
    '--disable-gpu',
    '--disable-dev-shm-usage',
    '--remote-allow-origins=*',
    '--remote-debugging-port=$port',
    '--user-data-dir=${profile.path}',
    'about:blank',
  ]);
  unawaited(process.stderr.drain<void>());
  WebSocket? socket;
  try {
    final webSocketUrl = await _findPage(port);
    socket = await WebSocket.connect(webSocketUrl);
    final cdp = _Cdp(socket);
    await cdp.command('Page.enable');
    await cdp.command('Runtime.enable');
    await cdp.command('Page.navigate', {'url': args.single});

    final deadline = DateTime.now().add(_timeout);
    String lastText = 'loading';
    while (DateTime.now().isBefore(deadline)) {
      final state = await _readOutput(cdp);
      lastText = state.text;
      if (state.ready) {
        stdout.writeln(state.text);
        return;
      }
      if (state.error) {
        throw StateError('browser smoke failed: ${state.text}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('browser smoke timed out with output: $lastText');
  } finally {
    await socket?.close();
    process.kill();
    await process.exitCode.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return process.exitCode;
      },
    );
    try {
      await profile.delete(recursive: true);
    } catch (_) {
      // Chrome can keep a profile file open briefly after its process exits.
    }
  }
}

Future<String> _findPage(int port) async {
  final deadline = DateTime.now().add(_timeout);
  while (DateTime.now().isBefore(deadline)) {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/json/list'),
      );
      final response = await request.close();
      final targets = jsonDecode(await response.transform(utf8.decoder).join());
      if (targets is List) {
        for (final target in targets) {
          if (target is Map && target['type'] == 'page') {
            final url = target['webSocketDebuggerUrl'];
            if (url is String) return url;
          }
        }
      }
    } catch (_) {
      // Chrome may need a few milliseconds to bind its DevTools endpoint.
    } finally {
      client.close(force: true);
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Chrome DevTools endpoint did not become ready');
}

Future<_OutputState> _readOutput(_Cdp cdp) async {
  final response = await cdp.command('Runtime.evaluate', {
    'expression': '''(() => {
      const output = document.querySelector('#output');
      return JSON.stringify({
        text: output?.textContent ?? '',
        ready: output?.dataset.ready === 'true',
        error: output?.dataset.error === 'true'
      });
    })()''',
    'returnByValue': true,
  });
  final result = response['result'];
  final nested = result is Map ? result['result'] : null;
  final value = nested is Map ? nested['value'] : null;
  if (value is! String) throw StateError('browser output is not a string');
  final decoded = jsonDecode(value);
  if (decoded is! Map) {
    throw StateError('browser output state is not an object');
  }
  return _OutputState(
    decoded['text'] as String? ?? '',
    decoded['ready'] == true,
    decoded['error'] == true,
  );
}

final class _OutputState {
  const _OutputState(this.text, this.ready, this.error);

  final String text;
  final bool ready;
  final bool error;
}

final class _Cdp {
  _Cdp(this.socket) : _messages = StreamIterator<dynamic>(socket);

  final WebSocket socket;
  final StreamIterator<dynamic> _messages;
  var _nextId = 0;

  Future<Map<String, dynamic>> command(
    String method, [
    Map<String, Object?> params = const <String, Object?>{},
  ]) async {
    final id = ++_nextId;
    socket.add(jsonEncode({'id': id, 'method': method, 'params': params}));
    while (await _messages.moveNext()) {
      final message = jsonDecode(_messages.current as String);
      if (message is Map && message['id'] == id) {
        if (message['error'] != null) {
          throw StateError('Chrome DevTools error: ${message['error']}');
        }
        return Map<String, dynamic>.from(message);
      }
    }
    throw StateError('Chrome DevTools connection closed');
  }
}
