import 'dart:convert';

import 'package:cel_bridge/cel_bridge.dart';
import 'package:flutter/material.dart';

import 'workbench_theme.dart';
import 'workbench_widgets.dart';

const _defaultEnvironment = '''{
  "schemaVersion": 1,
  "variables": {
    "age": {"type": "int"},
    "country": {"type": "string"}
  }
}''';

const _defaultVariables = '''{
  "age": 20,
  "country": "CN"
}''';

const _defaultSource = 'age >= 18 && country in ["CN", "SG"]';
const _wasmUrl = String.fromEnvironment('CEL_BRIDGE_WASM_URL');
const _wasmExecUrl = String.fromEnvironment('CEL_BRIDGE_WASM_EXEC_URL');
const _wasmIntegrity = String.fromEnvironment('CEL_BRIDGE_WASM_INTEGRITY');
const _wasmExecIntegrity = String.fromEnvironment(
  'CEL_BRIDGE_WASM_EXEC_INTEGRITY',
);

final class CelBridgeExampleApp extends StatelessWidget {
  const CelBridgeExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cel-bridge workbench',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: workbenchOrange,
          brightness: Brightness.light,
          surface: workbenchSurface,
        ),
        scaffoldBackgroundColor: workbenchCanvas,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: workbenchInk, height: 1.35),
          bodySmall: TextStyle(color: workbenchMutedInk, height: 1.3),
          titleLarge: TextStyle(
            color: workbenchInk,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF0F4F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: workbenchLine),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: workbenchLine),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: workbenchOrange, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      home: const _Workbench(),
    );
  }
}

final class _Workbench extends StatefulWidget {
  const _Workbench();

  @override
  State<_Workbench> createState() => _WorkbenchState();
}

final class _WorkbenchState extends State<_Workbench> {
  late final Future<CelRuntime> _runtime;
  late final TextEditingController _source;
  late final TextEditingController _environment;
  late final TextEditingController _variables;

  CelValidationResult? _validation;
  CelValue? _evaluation;
  CelBridgeException? _error;
  String? _inputError;
  Duration? _lastDuration;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _runtime = CelRuntime.initialize(
      options: _wasmUrl.isEmpty
          ? const CelRuntimeOptions()
          : CelRuntimeOptions(
              wasmUrl: _wasmUrl,
              wasmExecUrl: _wasmExecUrl,
              wasmIntegrity: _wasmIntegrity.isEmpty ? null : _wasmIntegrity,
              wasmExecIntegrity: _wasmExecIntegrity.isEmpty
                  ? null
                  : _wasmExecIntegrity,
            ),
    );
    _source = TextEditingController(text: _defaultSource);
    _environment = TextEditingController(text: _defaultEnvironment);
    _variables = TextEditingController(text: _defaultVariables);
  }

  @override
  void dispose() {
    _source.dispose();
    _environment.dispose();
    _variables.dispose();
    super.dispose();
  }

  Future<void> _validate() => _run(evaluate: false);

  Future<void> _evaluate() => _run(evaluate: true);

  Future<void> _run({required bool evaluate}) async {
    setState(() {
      _busy = true;
      _error = null;
      _inputError = null;
      _validation = null;
      _evaluation = null;
      _lastDuration = null;
    });
    final started = Stopwatch()..start();
    try {
      final runtime = await _runtime;
      final environment = _jsonObject(_environment.text, 'environment');
      final variables = _jsonObject(_variables.text, 'variables');
      if (evaluate) {
        final value = await runtime.evaluate(
          environment: environment,
          source: _source.text,
          variables: variables,
        );
        if (!mounted) return;
        setState(() {
          _evaluation = value;
          _lastDuration = started.elapsed;
        });
      } else {
        final validation = await runtime.validate(
          environment: environment,
          source: _source.text,
        );
        if (!mounted) return;
        setState(() {
          _validation = validation;
          _lastDuration = started.elapsed;
        });
      }
    } on CelBridgeException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _lastDuration = started.elapsed;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _inputError = error.message;
        _lastDuration = started.elapsed;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? 34 : 18,
                24,
                wide ? 34 : 18,
                34,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1380),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WorkbenchHeader(runtime: _runtime),
                      const SizedBox(height: 24),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _inputs()),
                            const SizedBox(width: 18),
                            Expanded(child: _outputs()),
                          ],
                        )
                      else ...[
                        _inputs(),
                        const SizedBox(height: 18),
                        _outputs(),
                      ],
                      const SizedBox(height: 18),
                      WorkbenchFooter(runtime: _runtime),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _inputs() {
    return WorkbenchPanel(
      key: const ValueKey('input-panel'),
      title: 'Expression bench',
      marker: 'INPUT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkbenchFieldCaption(
            'CEL SOURCE',
            hint: 'the rule to validate and evaluate',
          ),
          const SizedBox(height: 7),
          WorkbenchCodeField(
            key: const ValueKey('source-field'),
            controller: _source,
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 20),
          const WorkbenchFieldCaption(
            'ENVIRONMENT JSON',
            hint: 'declared variables and CEL types',
          ),
          const SizedBox(height: 7),
          WorkbenchCodeField(
            key: const ValueKey('environment-field'),
            controller: _environment,
            minLines: 7,
            maxLines: 12,
          ),
          const SizedBox(height: 20),
          const WorkbenchFieldCaption(
            'VARIABLES JSON',
            hint: 'runtime values supplied to evaluation',
          ),
          const SizedBox(height: 7),
          WorkbenchCodeField(
            key: const ValueKey('variables-field'),
            controller: _variables,
            minLines: 5,
            maxLines: 9,
          ),
          if (_inputError != null) ...[
            const SizedBox(height: 12),
            WorkbenchMessageLine(
              icon: Icons.warning_amber_rounded,
              color: workbenchOrange,
              text: _inputError!,
            ),
          ],
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('validate-button'),
                onPressed: _busy ? null : () => _validate(),
                icon: const Icon(Icons.rule_rounded, size: 17),
                label: const Text('Validate'),
              ),
              FilledButton.icon(
                key: const ValueKey('evaluate-button'),
                onPressed: _busy ? null : () => _evaluate(),
                style: FilledButton.styleFrom(
                  backgroundColor: workbenchOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(_busy ? 'Running…' : 'Evaluate'),
              ),
              Text(
                'COST-LIMITED',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: workbenchMutedInk,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _outputs() {
    return WorkbenchPanel(
      key: const ValueKey('output-panel'),
      title: 'Runtime trace',
      marker: 'OUTPUT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<CelRuntime>(
            future: _runtime,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const WorkbenchRuntimeLine(loading: true);
              }
              if (snapshot.hasError) {
                return WorkbenchRuntimeLine(error: snapshot.error.toString());
              }
              return WorkbenchRuntimeLine(info: snapshot.data!.info);
            },
          ),
          const SizedBox(height: 22),
          WorkbenchResultBlock(
            key: const ValueKey('validation-result'),
            label: 'VALIDATION',
            accent: workbenchTeal,
            child: _validationView(),
          ),
          const SizedBox(height: 16),
          WorkbenchResultBlock(
            key: const ValueKey('evaluation-result'),
            label: 'EVALUATION',
            accent: workbenchOrange,
            child: _evaluationView(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            WorkbenchResultBlock(
              label: 'BRIDGE ERROR',
              accent: workbenchOrange,
              child: WorkbenchMessageLine(
                icon: Icons.error_outline_rounded,
                color: workbenchOrange,
                text: '${_error!.code}: ${_error!.message}',
              ),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              const WorkbenchMetric(
                label: 'PROTOCOL',
                value: '$wireProtocolVersion',
              ),
              const SizedBox(width: 26),
              WorkbenchMetric(
                label: 'LAST CALL',
                value: _lastDuration == null
                    ? '—'
                    : '${_lastDuration!.inMicroseconds} μs',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _validationView() {
    final result = _validation;
    if (result == null) {
      return const WorkbenchWaitingText('Run Validate to inspect the rule.');
    }
    if (result.valid) {
      return const WorkbenchMessageLine(
        icon: Icons.check_circle_rounded,
        color: workbenchTeal,
        text: 'Expression is valid for this environment.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WorkbenchMessageLine(
          icon: Icons.warning_amber_rounded,
          color: workbenchOrange,
          text: 'Expression needs attention.',
        ),
        const SizedBox(height: 10),
        for (final issue in result.issues)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${issue.line}:${issue.column}  ${issue.message}',
              style: const TextStyle(
                color: workbenchMutedInk,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _evaluationView() {
    final value = _evaluation;
    if (value == null) {
      return const WorkbenchWaitingText('Run Evaluate to produce a value.');
    }
    return SelectableText(
      _displayValue(value),
      style: const TextStyle(
        color: workbenchInk,
        fontFamily: 'monospace',
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

Map<String, Object?> _jsonObject(String raw, String name) {
  final value = jsonDecode(raw);
  if (value is! Map) throw FormatException('$name must be a JSON object');
  return value.map((key, value) => MapEntry(key.toString(), value));
}

String _displayValue(CelValue value) {
  return switch (value) {
    CelBoolValue(:final value) => value.toString(),
    CelIntValue(:final value) => value.toString(),
    CelUintValue(:final value) => value.toString(),
    CelStringValue(:final value) => '"$value"',
    _ => jsonEncode(value.toJson()),
  };
}
