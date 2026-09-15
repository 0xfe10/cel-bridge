# Migrating to cel-bridge 0.7

Version `0.7.0` intentionally breaks the raw `evaluateRequests` wire payload.
The runtime version is `0.7.0`; protocol version remains `1` and ABI version
remains `4` because exported function signatures and response envelopes do not
change.

## Required upgrade

Upgrade the runtime and the Dart or Rust SDK together. A `0.7.0` runtime rejects
the former top-level request array, and a `0.7.0` SDK requires the matching
runtime version during initialization. There is no legacy fallback.

SDK callers continue passing `CelEvaluationRequest` or `EvaluationRequest`
lists. No application-specific variable names or manual chunking are required.
The SDK:

1. validates ids and source/program selection across the complete logical list;
2. compares arbitrary top-level variable keys by JSON value;
3. hoists values shared by every request in a physical batch;
4. splits by runtime-reported request count, source bytes, and encoded UTF-8
   envelope bytes;
5. combines results in original order under one overall deadline.

Direct ABI or Wasm callers must send:

```json
{
  "sharedVariables": {"anyCommonKey": "any JSON value"},
  "requests": [
    {
      "id": "condition-1",
      "source": "value > 0",
      "variables": {"value": 1},
      "expectedResultType": "bool"
    }
  ]
}
```

Request variables override the shared object at the top level. The runtime does
not inspect the meaning of a key. A physical envelope over the advertised limit
returns `batch_payload_too_large` with `actualBytes`, `maxBytes`, and `retryable`
details. An individual logical request that cannot fit returns
`request_payload_too_large` from the SDK. Oversized merged variables return
`variables_too_large` on that request result.
