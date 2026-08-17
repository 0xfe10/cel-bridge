use cel_bridge::{CelRuntime, CelValue};
use serde_json::json;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let runtime = CelRuntime::new()?;
    let environment = json!({
        "schemaVersion": 1,
        "variables": {
            "age": {"type": "int"},
            "country": {"type": "string"}
        }
    });
    let source = r#"age >= 18 && country == "CN""#;
    let validation = runtime.validate(&environment, source)?;
    if !validation.valid {
        for issue in validation.issues {
            eprintln!("{}:{} {}", issue.line, issue.column, issue.message);
        }
        return Ok(());
    }
    let value = runtime.evaluate(&environment, source, &json!({"age": 20, "country": "CN"}))?;
    assert_eq!(value, CelValue::Bool(true));
    println!("runtime: {}", runtime.info().runtime_version);
    println!("result: {:?}", value);
    Ok(())
}
