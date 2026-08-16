use cel_bridge::CelRuntime;
use serde_json::Value;

#[test]
fn matches_shared_error_codes() {
    let cases: Vec<Value> =
        serde_json::from_str(include_str!("../../../protocol/testdata/error_cases.json"))
            .expect("shared error JSON should parse");
    let runtime = CelRuntime::new().expect("runtime should link");
    for case in cases {
        let expected = case["expectedCode"].as_str().unwrap();
        if case["operation"] == "validate" {
            let result = runtime
                .validate(&case["environment"], case["source"].as_str().unwrap())
                .unwrap();
            assert_eq!(result.issues[0].code, expected, "{}", case["name"]);
        } else {
            let error = runtime
                .evaluate(
                    &case["environment"],
                    case["source"].as_str().unwrap(),
                    &case["variables"],
                )
                .expect_err("case should fail");
            assert_eq!(error.code, expected, "{}", case["name"]);
        }
    }
}
