use cel_bridge::{CelRuntime, CelValue, RequestOptions};
use serde_json::Value;

#[test]
fn matches_shared_type_contract_cases() {
    let cases: Vec<Value> = serde_json::from_str(include_str!(
        "../../../protocol/testdata/type_contract_cases.json"
    ))
    .expect("shared type contract JSON should parse");
    let runtime = CelRuntime::new().expect("runtime should link");
    for case in cases {
        let name = case["name"].as_str().unwrap();
        let options = RequestOptions {
            expected_result_type: case.get("expectedResultType"),
            ..RequestOptions::default()
        };
        if case["operation"] == "validate" {
            let result = runtime
                .validate_with(
                    &case["environment"],
                    case["source"].as_str().unwrap(),
                    options,
                )
                .unwrap_or_else(|error| panic!("{name}: {error}"));
            assert_eq!(result.valid, case["valid"].as_bool().unwrap(), "{name}");
            if let Some(expected) = case.get("resultType") {
                let actual = serde_json::to_value(&result.result_type)
                    .expect("result type should serialize");
                assert_eq!(actual, *expected, "{name}");
            }
            if let Some(code) = case["expectedCode"].as_str() {
                assert_eq!(result.issues[0].code, code, "{name}");
            }
            continue;
        }

        let variables = case
            .get("variables")
            .cloned()
            .unwrap_or_else(|| serde_json::json!({}));
        if case["ok"] == false {
            let error = runtime
                .evaluate_with(
                    &case["environment"],
                    case["source"].as_str().unwrap(),
                    &variables,
                    options,
                )
                .expect_err("case should fail");
            assert_eq!(error.code, case["expectedCode"], "{name}");
            continue;
        }

        let value = runtime
            .evaluate_with(
                &case["environment"],
                case["source"].as_str().unwrap(),
                &variables,
                options,
            )
            .unwrap_or_else(|error| panic!("{name}: {error}"));
        let expected = CelValue::from_json(&case["expected"])
            .unwrap_or_else(|error| panic!("{name}: {error}"));
        assert_eq!(value, expected, "{name}");
    }
}
