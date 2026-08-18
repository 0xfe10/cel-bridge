use crate::error::CelBridgeError;
use crate::ffi;
use crate::value::CelValue;
use crate::wire::{CelIssue, CelValidationResult};
use serde_json::Value;

const PROTOCOL_VERSION: u64 = 1;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CelRuntimeInfo {
    pub protocol_version: u64,
    pub runtime_version: String,
    pub cel_go_version: String,
    pub features: std::collections::BTreeMap<String, bool>,
}

pub struct CelRuntime {
    info: CelRuntimeInfo,
}

impl CelRuntime {
    pub fn new() -> Result<Self, CelBridgeError> {
        let raw = ffi::runtime_info()?;
        let value: Value = serde_json::from_str(&raw)
            .map_err(|error| CelBridgeError::new("protocol_mismatch", error.to_string()))?;
        let info = decode_info(&value)?;
        if info.protocol_version != PROTOCOL_VERSION {
            return Err(CelBridgeError::new(
                "protocol_mismatch",
                format!(
                    "expected protocol {PROTOCOL_VERSION}, got {}",
                    info.protocol_version
                ),
            ));
        }
        if info.runtime_version != env!("CARGO_PKG_VERSION") {
            return Err(CelBridgeError::new(
                "runtime_mismatch",
                format!(
                    "expected runtime {}, got {}",
                    env!("CARGO_PKG_VERSION"),
                    info.runtime_version
                ),
            ));
        }
        Ok(Self { info })
    }

    pub fn info(&self) -> &CelRuntimeInfo {
        &self.info
    }

    pub fn validate(
        &self,
        environment: &Value,
        source: &str,
    ) -> Result<CelValidationResult, CelBridgeError> {
        let environment = encode_json(environment)?;
        let raw = ffi::validate(&environment, source)?;
        let response = response(&raw)?;
        if !response["ok"].as_bool().unwrap_or(false) {
            return Err(error_from_response(&response));
        }
        serde_json::from_value(response["result"].clone()).map_err(|error| {
            CelBridgeError::new(
                "protocol_mismatch",
                format!("invalid validation result: {error}"),
            )
        })
    }

    pub fn evaluate(
        &self,
        environment: &Value,
        source: &str,
        variables: &Value,
    ) -> Result<CelValue, CelBridgeError> {
        let environment = encode_json(environment)?;
        let variables = encode_json(variables)?;
        let raw = ffi::evaluate(&environment, source, &variables)?;
        let response = response(&raw)?;
        if !response["ok"].as_bool().unwrap_or(false) {
            return Err(error_from_response(&response));
        }
        CelValue::from_json(&response["result"])
            .map_err(|error| CelBridgeError::new("protocol_mismatch", error))
    }

    pub fn evaluate_many<S: AsRef<str>>(
        &self,
        environment: &Value,
        sources: &[S],
        variables: &Value,
    ) -> Result<Vec<Result<CelValue, CelBridgeError>>, CelBridgeError> {
        if sources.len() > 256 {
            return Err(CelBridgeError::new(
                "invalid_request",
                "batch exceeds 256 expressions",
            ));
        }
        if sources.is_empty() {
            return Ok(Vec::new());
        }
        let environment = encode_json(environment)?;
        let variables = encode_json(variables)?;
        let sources = serde_json::to_string(&sources.iter().map(AsRef::as_ref).collect::<Vec<_>>())
            .map_err(|error| CelBridgeError::new("invalid_request", error.to_string()))?;
        let raw = ffi::evaluate_many(&environment, &sources, &variables)?;
        let response = response(&raw)?;
        if !response["ok"].as_bool().unwrap_or(false) {
            return Err(error_from_response(&response));
        }
        let items = response["result"].as_array().ok_or_else(|| {
            CelBridgeError::new("protocol_mismatch", "batch result must be a list")
        })?;
        items.iter().map(decode_batch_item).collect()
    }
}

fn encode_json(value: &Value) -> Result<String, CelBridgeError> {
    serde_json::to_string(value)
        .map_err(|error| CelBridgeError::new("invalid_request", error.to_string()))
}

fn response(raw: &str) -> Result<Value, CelBridgeError> {
    let value: Value = serde_json::from_str(raw)
        .map_err(|error| CelBridgeError::new("protocol_mismatch", error.to_string()))?;
    if value["protocolVersion"] != PROTOCOL_VERSION {
        return Err(CelBridgeError::new(
            "protocol_mismatch",
            "native response has an unexpected protocol version",
        ));
    }
    if value["ok"].as_bool().is_none() {
        return Err(CelBridgeError::new(
            "protocol_mismatch",
            "native response.ok must be a boolean",
        ));
    }
    Ok(value)
}

fn error_from_response(response: &Value) -> CelBridgeError {
    let error = &response["error"];
    let code = error["code"].as_str().unwrap_or("protocol_mismatch");
    let message = error["message"]
        .as_str()
        .unwrap_or("malformed bridge error");
    let issues = error["issues"]
        .as_array()
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .filter_map(|issue| serde_json::from_value::<CelIssue>(issue).ok())
        .collect();
    CelBridgeError::with_issues(code, message, issues)
}

fn decode_batch_item(item: &Value) -> Result<Result<CelValue, CelBridgeError>, CelBridgeError> {
    let item = response(&item.to_string())?;
    if item["ok"].as_bool().unwrap_or(false) {
        CelValue::from_json(&item["result"])
            .map(Ok)
            .map_err(|error| CelBridgeError::new("protocol_mismatch", error))
    } else {
        Ok(Err(error_from_response(&item)))
    }
}

fn decode_info(value: &Value) -> Result<CelRuntimeInfo, CelBridgeError> {
    let info = value.as_object().ok_or_else(|| {
        CelBridgeError::new("protocol_mismatch", "runtime info must be an object")
    })?;
    let features = info["features"]
        .as_object()
        .ok_or_else(|| {
            CelBridgeError::new("protocol_mismatch", "runtime features must be an object")
        })?
        .iter()
        .map(|(key, value)| {
            value
                .as_bool()
                .map(|value| (key.clone(), value))
                .ok_or_else(|| {
                    CelBridgeError::new(
                        "protocol_mismatch",
                        format!("runtime feature {key} must be boolean"),
                    )
                })
        })
        .collect::<Result<_, _>>()?;
    Ok(CelRuntimeInfo {
        protocol_version: info["protocolVersion"].as_u64().ok_or_else(|| {
            CelBridgeError::new(
                "protocol_mismatch",
                "runtime protocolVersion must be integer",
            )
        })?,
        runtime_version: info["runtimeVersion"]
            .as_str()
            .ok_or_else(|| {
                CelBridgeError::new("protocol_mismatch", "runtimeVersion must be string")
            })?
            .to_string(),
        cel_go_version: info["celGoVersion"]
            .as_str()
            .ok_or_else(|| CelBridgeError::new("protocol_mismatch", "celGoVersion must be string"))?
            .to_string(),
        features,
    })
}
