use cel_bridge::{CelRuntime, CelValue, EvaluationRequest, RequestOptions};
use serde_json::Value;

#[test]
fn matches_shared_evaluate_requests_cases() {
    let cases: Vec<Value> = serde_json::from_str(include_str!(
        "../../../protocol/testdata/evaluate_requests_cases.json"
    ))
    .expect("shared evaluateRequests JSON should parse");
    let runtime = CelRuntime::new().expect("runtime should link");
    for case in cases {
        let name = case["name"].as_str().unwrap();
        let requests: Vec<EvaluationRequest> = case["requests"]
            .as_array()
            .expect("requests")
            .iter()
            .map(|request| EvaluationRequest {
                id: request["id"].as_str().unwrap().to_string(),
                source: request
                    .get("source")
                    .and_then(Value::as_str)
                    .map(str::to_string),
                program_id: request
                    .get("programId")
                    .and_then(Value::as_str)
                    .map(str::to_string),
                variables: request
                    .get("variables")
                    .cloned()
                    .unwrap_or_else(|| serde_json::json!({})),
                expected_result_type: request.get("expectedResultType").cloned(),
            })
            .collect();
        if case["ok"] == false {
            let error = runtime
                .evaluate_requests(&case["environment"], &requests, RequestOptions::default())
                .expect_err("case should fail");
            assert_eq!(error.code, case["expectedCode"], "{name}");
            continue;
        }

        let results = runtime
            .evaluate_requests(&case["environment"], &requests, RequestOptions::default())
            .unwrap_or_else(|error| panic!("{name}: {error}"));
        let expected = case["results"].as_array().expect("results");
        assert_eq!(results.len(), expected.len(), "{name}");
        for (got, want) in results.iter().zip(expected) {
            assert_eq!(got.id, want["id"].as_str().unwrap(), "{name}");
            if want["ok"] == false {
                let error = got.result.as_ref().expect_err("item should fail");
                assert_eq!(error.code, want["expectedCode"], "{name}");
                continue;
            }
            let value = got
                .result
                .as_ref()
                .unwrap_or_else(|error| panic!("{name}: {error}"));
            let expected_value = CelValue::from_json(&want["expected"])
                .unwrap_or_else(|error| panic!("{name}: {error}"));
            assert_eq!(value, &expected_value, "{name}");
        }
    }
}
