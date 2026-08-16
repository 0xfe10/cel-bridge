use cel_bridge::{CelRuntime, CelValue};
use serde_json::Value;

#[test]
fn matches_shared_conformance_cases() {
    let cases: Vec<Value> = serde_json::from_str(include_str!(
        "../../../protocol/testdata/conformance_cases.json"
    ))
    .expect("shared conformance JSON should parse");
    let runtime = CelRuntime::new().expect("runtime should link");
    for case in cases {
        let value = runtime
            .evaluate(
                &case["environment"],
                case["source"].as_str().unwrap(),
                &case["variables"],
            )
            .unwrap_or_else(|error| panic!("{}: {error}", case["name"]));
        let expected = CelValue::from_json(&case["expected"])
            .unwrap_or_else(|error| panic!("{}: {error}", case["name"]));
        assert_eq!(value, expected, "{}", case["name"]);
    }
}
