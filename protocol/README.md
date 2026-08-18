# cel-bridge wire protocol

The protocol is the language-neutral contract between the Go runtime and every
SDK. Protocol version `1` remains stable across the `v0.2.0` directory and SDK
changes.

The evaluator is always Go plus `cel-go`. Dart and Rust encode requests, call
the native C ABI or Go Wasm entry point, and decode these JSON values. They do
not implement CEL compilation or evaluation.

## Files

- `schema/environment.schema.json` describes declared CEL variables.
- `schema/value.schema.json` describes the tagged `CelValue` representation.
- `schema/type.schema.json` describes `resultType` and `expectedResultType`.
- `schema/response.schema.json` describes success and failure envelopes.
- `testdata/conformance_cases.json` contains successful evaluation cases.
- `testdata/error_cases.json` contains stable error-code cases.
- `testdata/type_contract_cases.json` contains result-type and expected-type cases.
- `testdata/evaluate_requests_cases.json` contains per-request batch cases.

The Go, Dart, and Rust test suites read the same files. `tools/bin/verify_protocol.dart`
performs the repository-level structural check used by CI.

These fixtures are the generic CEL and runtime contract. Identifiers such as
`age`, `enabled`, and `count` are uninterpreted. Product schemas, default
values, publication snapshots, and visibility rules belong in the calling
application. Aviary must keep its own cross-Rust/Dart business fixtures; it
may reuse this JSON shape, but those cases do not belong in cel-bridge.

## Requests

The native and Wasm APIs accept UTF-8 JSON strings. A validation request needs
an environment and CEL source. An evaluation request additionally needs a JSON
object containing variables. `cel_bridge_evaluate_many` accepts a JSON array of
source strings with one shared environment and one shared variables object.
`cel_bridge_evaluate_requests` accepts a JSON array of `{id, source|programId,
variables, expectedResultType?}` objects; each item has its own variables.
Duplicate or empty ids fail the whole batch with `invalid_request`.

Optional request options may be passed to `cel_bridge_validate_options`,
`cel_bridge_evaluate_options`, `cel_bridge_evaluate_requests`,
`cel_bridge_prepare`, and `cel_bridge_evaluate_program`, or as extra Wasm string
arguments. The old two- and three-argument entry points remain and behave as
empty options. The ABI version is `4`.

`cel_bridge_call_v2` is a length-delimited JSON dispatcher (`{op, ...}`). The
NUL-terminated symbols remain the SDK default.

`cel_bridge_evaluate` remains the single-expression ABI. `cel_bridge_evaluate_many`
evaluates up to 256 sources, preserves source order, and returns an array of
per-expression response envelopes. A malformed batch, invalid environment, or
invalid variables object fails the whole request. Compile, evaluation, cost, and
per-source size errors stay attached to the matching item.

`cel_bridge_evaluate_requests` returns `{id, ok, result?, error?}` items, not
nested protocol envelopes. Per-item compile or evaluation failures do not cancel
siblings. A wall-clock `deadlineMs` of `0` fails items that have not started
with `deadline_exceeded`; in-flight `cel-go` evaluation is not interrupted.

Prepared programs are created with `cel_bridge_prepare` (`{programId}`),
evaluated with `cel_bridge_evaluate_program`, and released with
`cel_bridge_release_program`. Capacity exhaustion returns `program_limit_exceeded`.
Unknown ids return `program_not_found`. `cel_bridge_close` disposes the process
runtime (`runtime_closed` afterwards); `cel_bridge_create` replaces it.

```json
{
  "protocolVersion": 1,
  "ok": true,
  "result": [
    {"protocolVersion": 1, "ok": true, "result": {"kind": "bool", "value": true}},
    {
      "protocolVersion": 1,
      "ok": false,
      "error": {"code": "compile_error", "message": "...", "issues": []}
    }
  ]
}
```

```json
{
  "schemaVersion": 1,
  "variables": {
    "age": {"type": "int"},
    "country": {"type": "string"}
  }
}
```

Variable names use CEL identifier rules. The supported type names are:

`null`, `bool`, `int`, `uint`, `double`, `string`, `bytes`, `timestamp`,
`duration`, `dyn`, `list`, and `map`.

Lists have an `element` type. Maps have `key` and `value` types. Map keys are
limited to `bool`, `int`, `uint`, and `string`, matching CEL's supported key
types and the runtime's tagged input representation.

## JSON input values

Plain JSON values are accepted for ordinary booleans, strings, arrays, objects,
and finite numbers. JSON numbers are decoded as CEL `int`, `uint`, or `double`
when their value fits the corresponding CEL range. Use a tagged value when the
wire representation must be unambiguous or when JSON has no native form.

The tagged marker is `$cel_bridge: true`:

```json
{"$cel_bridge": true, "kind": "int", "value": "9223372036854775807"}
```

Supported tagged values are:

| Kind | Wire field | Notes |
| --- | --- | --- |
| `null` | none | JSON `null` |
| `bool` | boolean `value` | |
| `int` | decimal string `value` | signed 64-bit |
| `uint` | decimal string `value` | unsigned 64-bit |
| `double` | string `value` | finite decimal, `NaN`, `Infinity`, or `-Infinity` |
| `string` | string `value` | |
| `bytes` | base64 string `value` | standard base64 |
| `timestamp` | RFC 3339 string `value` | normalized to UTC |
| `duration` | CEL duration string `value` | normalized seconds and nanoseconds |
| `list` | array `items` | each item is a JSON or tagged value |
| `map` | array `entries` | each entry has `key` and `value` |

Map entries are arrays instead of JSON objects so non-string CEL keys remain
representable and ordering can be made deterministic.

## Response envelope

Every native and Wasm operation returns an object with `protocolVersion` and
`ok`.

Successful validation:

```json
{
  "protocolVersion": 1,
  "ok": true,
  "result": {
    "valid": true,
    "resultType": {"type": "bool"},
    "issues": []
  }
}
```

`resultType` uses the stable type encoding below. Compile failures omit
`resultType`. Callers may also send request options JSON:

```json
{"expectedResultType": "bool"}
```

`expectedResultType` may be a scalar type name or a nested type object. A
static mismatch fails validation with `valid: false` and issue code
`result_type_mismatch`, and fails evaluation with the same error code. When
the static type is `dyn`, evaluation checks the runtime value and still
returns `result_type_mismatch` instead of coercing or defaulting.

Type objects are:

```json
{"type": "bool"}
{"type": "null"}
{"type": "dyn"}
{"type": "list", "element": {"type": "int"}}
{"type": "map", "key": {"type": "string"}, "value": {"type": "dyn"}}
```

Unknown or imprecise CEL types are encoded as `dyn`. The runtime does not
rewrite caller variables, inject defaults, or treat names such as `session`,
`tenant`, or `component` differently from any other identifier.

Successful evaluation returns a tagged value in `result`:

```json
{
  "protocolVersion": 1,
  "ok": true,
  "result": {"kind": "bool", "value": true}
}
```

Failures use a stable machine-readable `code`. Messages are diagnostic text
and must not be used for program control.

```json
{
  "protocolVersion": 1,
  "ok": false,
  "error": {
    "code": "evaluation_error",
    "message": "...",
    "issues": []
  }
}
```

Validation problems are normally successful requests with `result.valid: false`
and one or more issues. Transport, malformed input, environment, evaluation,
limit, and protocol failures use the error envelope.

Issue fields are `severity`, `code`, and `message`; `line` and `column` are
one-based source locations when available. Known issue codes include
`undeclared_reference`, `parse_error`, `type_error`, and `compile_error`.

Known response error codes include:

- `invalid_request`
- `invalid_environment`
- `parse_error`
- `compile_error`
- `evaluation_error`
- `missing_variable`
- `result_type_mismatch`
- `cost_limit_exceeded`
- `deadline_exceeded`
- `program_not_found`
- `program_limit_exceeded`
- `runtime_closed`
- `source_too_large`
- `variables_too_large`
- `output_too_large`
- `unsupported_value`
- `protocol_mismatch`
- `runtime_mismatch`
- `internal_error`

SDKs may add a more specific code only when the runtime and shared tests define
it. They must preserve the original code when mapping an error.

## Limits

The default runtime limits are intentionally finite:

- source: 64 KiB;
- environment: 64 KiB;
- variables: 1 MiB;
- type nesting: 16 levels;
- value nesting: 32 levels;
- collection items: 4096;
- CEL evaluation cost: 100,000;
- reported issues: 32;
- encoded response: 1 MiB.

Limits are runtime safety boundaries, not part of CEL semantics. A limit error
must use a stable code and must not be silently converted into a successful
result by an SDK.

## Compatibility rules

1. Keep `protocolVersion` at `1` for compatible additions.
2. Add new tagged kinds only with a schema, Go encoder/decoder behavior, Dart
   and Rust decoding behavior, and shared conformance cases.
3. Never change a stable error code because a diagnostic message changed.
4. Keep integers as decimal strings in tagged values to avoid JavaScript and
   JSON number precision loss.
5. Keep map entries ordered deterministically in encoded results.
6. Treat unknown response fields as forward-compatible unless a schema requires
   strict rejection; reject unknown request fields at trust boundaries.

Any incompatible wire change requires a new protocol version and an explicit
SDK migration plan.
