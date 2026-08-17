use cel_bridge::{CelRuntime, CelValue};
use serde_json::json;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let runtime = CelRuntime::new()?;
    let value = runtime.evaluate(
        &json!({"schemaVersion": 1, "variables": {}}),
        "1 + 1 == 2",
        &json!({}),
    )?;
    if value != CelValue::Bool(true) {
        return Err("unexpected Android smoke result".into());
    }
    println!("cel-bridge Android smoke passed");
    Ok(())
}
