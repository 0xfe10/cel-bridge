use crate::error::CelBridgeError;
use crate::ffi;
use crate::value::CelValue;
use crate::wire::{CelIssue, CelValidationResult};
use serde_json::{Map, Value, json};
use std::collections::BTreeMap;

const PROTOCOL_VERSION: u64 = 1;
const MAX_BATCH_EXPRESSIONS: usize = 256;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CelRuntimeInfo {
    pub protocol_version: u64,
    pub runtime_version: String,
    pub cel_go_version: String,
    pub features: BTreeMap<String, bool>,
    pub abi_version: Option<u64>,
    pub profiles: Vec<String>,
    pub limits: BTreeMap<String, i64>,
}

#[derive(Clone, Debug, Default)]
pub struct RequestOptions<'a> {
    pub expected_result_type: Option<&'a Value>,
    pub deadline_ms: Option<i64>,
}

#[derive(Clone, Debug)]
pub struct EvaluationRequest {
    pub id: String,
    pub source: Option<String>,
    pub program_id: Option<String>,
    pub variables: Value,
    pub expected_result_type: Option<Value>,
}

#[derive(Clone, Debug)]
pub struct RequestResult {
    pub id: String,
    pub result: Result<CelValue, CelBridgeError>,
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

    pub fn with_profile(profile: &str) -> Result<Self, CelBridgeError> {
        let options = encode_json(&json!({ "profile": profile }))?;
        decode_created(&ffi::create(&options)?)?;
        Self::new()
    }

    pub fn info(&self) -> &CelRuntimeInfo {
        &self.info
    }

    pub fn validate(
        &self,
        environment: &Value,
        source: &str,
    ) -> Result<CelValidationResult, CelBridgeError> {
        self.validate_with(environment, source, RequestOptions::default())
    }

    pub fn validate_with(
        &self,
        environment: &Value,
        source: &str,
        options: RequestOptions<'_>,
    ) -> Result<CelValidationResult, CelBridgeError> {
        let environment = encode_json(environment)?;
        let options = encode_options(options)?;
        let raw = ffi::validate_options(&environment, source, &options)?;
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
        self.evaluate_with(environment, source, variables, RequestOptions::default())
    }

    pub fn evaluate_with(
        &self,
        environment: &Value,
        source: &str,
        variables: &Value,
        options: RequestOptions<'_>,
    ) -> Result<CelValue, CelBridgeError> {
        let environment = encode_json(environment)?;
        let variables = encode_json(variables)?;
        let options = encode_options(options)?;
        let raw = ffi::evaluate_options(&environment, source, &variables, &options)?;
        decode_value_response(&raw)
    }

    pub fn evaluate_many<S: AsRef<str>>(
        &self,
        environment: &Value,
        sources: &[S],
        variables: &Value,
    ) -> Result<Vec<Result<CelValue, CelBridgeError>>, CelBridgeError> {
        if sources.len() > MAX_BATCH_EXPRESSIONS {
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

    pub fn evaluate_requests(
        &self,
        environment: &Value,
        requests: &[EvaluationRequest],
        options: RequestOptions<'_>,
    ) -> Result<Vec<RequestResult>, CelBridgeError> {
        if requests.len() > MAX_BATCH_EXPRESSIONS {
            return Err(CelBridgeError::new(
                "invalid_request",
                "batch exceeds 256 expressions",
            ));
        }
        if requests.is_empty() {
            return Ok(Vec::new());
        }
        let mut seen = std::collections::BTreeSet::new();
        for request in requests {
            if request.id.trim().is_empty() {
                return Err(CelBridgeError::new(
                    "invalid_request",
                    "request id is required",
                ));
            }
            if !seen.insert(request.id.as_str()) {
                return Err(CelBridgeError::new(
                    "invalid_request",
                    format!("duplicate request id {}", request.id),
                ));
            }
            let has_source = request
                .source
                .as_ref()
                .is_some_and(|value| !value.trim().is_empty());
            let has_program = request
                .program_id
                .as_ref()
                .is_some_and(|value| !value.trim().is_empty());
            if has_source == has_program {
                return Err(CelBridgeError::new(
                    "invalid_request",
                    "request must include exactly one of source or programId",
                ));
            }
        }
        let payload = encode_json(&Value::Array(requests.iter().map(request_json).collect()))?;
        let environment = encode_json(environment)?;
        let options = encode_options(options)?;
        let raw = ffi::evaluate_requests(&environment, &payload, &options)?;
        let response = response(&raw)?;
        if !response["ok"].as_bool().unwrap_or(false) {
            return Err(error_from_response(&response));
        }
        let items = response["result"].as_array().ok_or_else(|| {
            CelBridgeError::new("protocol_mismatch", "request batch result must be a list")
        })?;
        items.iter().map(decode_request_item).collect()
    }

    pub fn prepare(
        &self,
        environment: &Value,
        source: &str,
        options: RequestOptions<'_>,
    ) -> Result<String, CelBridgeError> {
        let environment = encode_json(environment)?;
        let options = encode_options(options)?;
        let raw = ffi::prepare(&environment, source, &options)?;
        let response = response(&raw)?;
        if !response["ok"].as_bool().unwrap_or(false) {
            return Err(error_from_response(&response));
        }
        response["result"]["programId"]
            .as_str()
            .map(str::to_string)
            .ok_or_else(|| {
                CelBridgeError::new(
                    "protocol_mismatch",
                    "prepare result.programId must be a string",
                )
            })
    }

    pub fn evaluate_program(
        &self,
        program_id: &str,
        variables: &Value,
        options: RequestOptions<'_>,
    ) -> Result<CelValue, CelBridgeError> {
        let variables = encode_json(variables)?;
        let options = encode_options(options)?;
        let raw = ffi::evaluate_program(program_id, &variables, &options)?;
        decode_value_response(&raw)
    }

    pub fn release_program(&self, program_id: &str) -> Result<(), CelBridgeError> {
        decode_ack(&ffi::release_program(program_id)?)
    }

    pub fn close(&self) -> Result<(), CelBridgeError> {
        decode_ack(&ffi::close()?)
    }

    pub fn recreate(&self, profile: Option<&str>) -> Result<CelRuntimeInfo, CelBridgeError> {
        let options = match profile {
            Some(profile) => encode_json(&json!({ "profile": profile }))?,
            None => String::new(),
        };
        decode_created(&ffi::create(&options)?)
    }
}

fn request_json(request: &EvaluationRequest) -> Value {
    let mut object = Map::new();
    object.insert("id".into(), json!(request.id));
    if let Some(source) = &request.source {
        object.insert("source".into(), json!(source));
    }
    if let Some(program_id) = &request.program_id {
        object.insert("programId".into(), json!(program_id));
    }
    object.insert("variables".into(), request.variables.clone());
    if let Some(expected) = &request.expected_result_type {
        object.insert("expectedResultType".into(), expected.clone());
    }
    Value::Object(object)
}

fn encode_json(value: &Value) -> Result<String, CelBridgeError> {
    serde_json::to_string(value)
        .map_err(|error| CelBridgeError::new("invalid_request", error.to_string()))
}

fn encode_options(options: RequestOptions<'_>) -> Result<String, CelBridgeError> {
    let mut object = Map::new();
    if let Some(expected) = options.expected_result_type {
        object.insert("expectedResultType".into(), expected.clone());
    }
    if let Some(deadline_ms) = options.deadline_ms {
        object.insert("deadlineMs".into(), json!(deadline_ms));
    }
    if object.is_empty() {
        Ok(String::new())
    } else {
        encode_json(&Value::Object(object))
    }
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

fn decode_value_response(raw: &str) -> Result<CelValue, CelBridgeError> {
    let response = response(raw)?;
    if !response["ok"].as_bool().unwrap_or(false) {
        return Err(error_from_response(&response));
    }
    CelValue::from_json(&response["result"])
        .map_err(|error| CelBridgeError::new("protocol_mismatch", error))
}

fn decode_ack(raw: &str) -> Result<(), CelBridgeError> {
    let response = response(raw)?;
    if !response["ok"].as_bool().unwrap_or(false) {
        return Err(error_from_response(&response));
    }
    Ok(())
}

fn decode_created(raw: &str) -> Result<CelRuntimeInfo, CelBridgeError> {
    let value: Value = serde_json::from_str(raw)
        .map_err(|error| CelBridgeError::new("protocol_mismatch", error.to_string()))?;
    if value.get("ok") == Some(&Value::Bool(false)) {
        return Err(error_from_response(&value));
    }
    decode_info(&value)
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

fn decode_request_item(item: &Value) -> Result<RequestResult, CelBridgeError> {
    let id = item["id"]
        .as_str()
        .ok_or_else(|| {
            CelBridgeError::new("protocol_mismatch", "request result.id must be a string")
        })?
        .to_string();
    let ok = item["ok"].as_bool().ok_or_else(|| {
        CelBridgeError::new("protocol_mismatch", "request result.ok must be a boolean")
    })?;
    let result = if ok {
        Ok(CelValue::from_json(&item["result"])
            .map_err(|error| CelBridgeError::new("protocol_mismatch", error))?)
    } else {
        Err(error_from_response(item))
    };
    Ok(RequestResult { id, result })
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
    let profiles = match info.get("profiles") {
        None => Vec::new(),
        Some(Value::Array(items)) => items
            .iter()
            .map(|item| {
                item.as_str().map(str::to_string).ok_or_else(|| {
                    CelBridgeError::new("protocol_mismatch", "profile must be a string")
                })
            })
            .collect::<Result<_, _>>()?,
        Some(_) => {
            return Err(CelBridgeError::new(
                "protocol_mismatch",
                "runtime profiles must be an array",
            ));
        }
    };
    let limits = match info.get("limits") {
        None => BTreeMap::new(),
        Some(Value::Object(items)) => items
            .iter()
            .map(|(key, value)| {
                value
                    .as_i64()
                    .map(|value| (key.clone(), value))
                    .ok_or_else(|| {
                        CelBridgeError::new(
                            "protocol_mismatch",
                            format!("runtime limit {key} must be integer"),
                        )
                    })
            })
            .collect::<Result<_, _>>()?,
        Some(_) => {
            return Err(CelBridgeError::new(
                "protocol_mismatch",
                "runtime limits must be an object",
            ));
        }
    };
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
        abi_version: info.get("abiVersion").and_then(Value::as_u64),
        profiles,
        limits,
    })
}
