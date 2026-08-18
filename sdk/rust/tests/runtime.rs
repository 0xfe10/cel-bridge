use cel_bridge::{CelRuntime, CelValue};
use serde_json::json;

fn assert_send_sync<T: Send + Sync>() {}

#[test]
fn evaluates_a_boolean_expression() {
    let runtime = CelRuntime::new().expect("runtime should link");
    let value = runtime
        .evaluate(
            &json!({"schemaVersion": 1, "variables": {}}),
            "1 + 1 == 2",
            &json!({}),
        )
        .expect("evaluation should succeed");
    assert_eq!(value, CelValue::Bool(true));
}

#[test]
fn exposes_runtime_info() {
    let runtime = CelRuntime::new().expect("runtime should link");
    assert_eq!(runtime.info().protocol_version, 1);
    assert_eq!(runtime.info().runtime_version, env!("CARGO_PKG_VERSION"));
}

#[test]
fn runtime_is_send_and_sync() {
    assert_send_sync::<CelRuntime>();
}

#[test]
fn rejects_nul_in_source_before_ffi() {
    let runtime = CelRuntime::new().expect("runtime should link");
    let error = runtime
        .validate(&json!({"schemaVersion": 1, "variables": {}}), "true\0")
        .expect_err("NUL input should be rejected");
    assert_eq!(error.code, "invalid_request");
}

#[test]
fn evaluates_a_batch_with_partial_failure() {
    let runtime = CelRuntime::new().expect("runtime should link");
    let results = runtime
        .evaluate_many(
            &json!({"schemaVersion": 1, "variables": {"age": {"type": "int"}}}),
            &["age >= 18", "missing == 1", "age >= 21"],
            &json!({"age": 20}),
        )
        .expect("batch request should succeed");
    assert!(results[0].is_ok());
    assert_eq!(results[1].as_ref().unwrap_err().code, "compile_error");
    assert!(results[2].is_ok());
}

#[test]
fn rejects_oversized_batches() {
    let runtime = CelRuntime::new().expect("runtime should link");
    let sources = vec!["true"; 257];
    let error = runtime
        .evaluate_many(
            &json!({"schemaVersion": 1, "variables": {}}),
            &sources,
            &json!({}),
        )
        .expect_err("oversized batch should be rejected");
    assert_eq!(error.code, "invalid_request");
}
