use cel_bridge::{CelRuntime, CelValue};
use serde_json::json;

#[unsafe(no_mangle)]
pub extern "C" fn cel_bridge_rust_smoke() -> i32 {
    let result = (|| -> Result<(), Box<dyn std::error::Error>> {
        let runtime = CelRuntime::new()?;
        let value = runtime.evaluate(
            &json!({"schemaVersion": 1, "variables": {}}),
            "1 + 1 == 2",
            &json!({}),
        )?;
        if value != CelValue::Bool(true) {
            return Err("unexpected iOS smoke result".into());
        }
        Ok(())
    })();
    if result.is_ok() { 0 } else { 1 }
}
