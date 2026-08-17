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
