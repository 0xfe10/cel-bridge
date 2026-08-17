use base64::{Engine as _, engine::general_purpose::STANDARD};
use serde_json::{Map, Value};

#[derive(Clone, Debug)]
pub enum CelValue {
    Null,
    Bool(bool),
    Int(i64),
    Uint(u64),
    Double(f64),
    String(String),
    Bytes(Vec<u8>),
    Timestamp(String),
    Duration(String),
    List(Vec<CelValue>),
    Map(Vec<CelMapEntry>),
}

#[derive(Clone, Debug, PartialEq)]
pub struct CelMapEntry {
    pub key: CelValue,
    pub value: CelValue,
}

impl PartialEq for CelValue {
    fn eq(&self, other: &Self) -> bool {
        match (self, other) {
            (Self::Null, Self::Null) => true,
            (Self::Bool(left), Self::Bool(right)) => left == right,
            (Self::Int(left), Self::Int(right)) => left == right,
            (Self::Uint(left), Self::Uint(right)) => left == right,
            (Self::Double(left), Self::Double(right)) => {
                (left.is_nan() && right.is_nan()) || left == right
            }
            (Self::String(left), Self::String(right)) => left == right,
            (Self::Bytes(left), Self::Bytes(right)) => left == right,
            (Self::Timestamp(left), Self::Timestamp(right)) => left == right,
            (Self::Duration(left), Self::Duration(right)) => left == right,
            (Self::List(left), Self::List(right)) => left == right,
            (Self::Map(left), Self::Map(right)) => left == right,
            _ => false,
        }
    }
}

impl CelValue {
    pub fn from_json(value: &Value) -> Result<Self, String> {
        let object = value
            .as_object()
            .ok_or_else(|| "CEL value must be an object".to_string())?;
        let kind = object
            .get("kind")
            .and_then(Value::as_str)
            .ok_or_else(|| "CEL value.kind must be a string".to_string())?;
        match kind {
            "null" => Ok(Self::Null),
            "bool" => Ok(Self::Bool(
                required(object, "value")?
                    .as_bool()
                    .ok_or_else(|| "bool.value must be a boolean".to_string())?,
            )),
            "int" => Ok(Self::Int(
                required_string(object, "value")?
                    .parse()
                    .map_err(|_| "int.value is outside the signed 64-bit range".to_string())?,
            )),
            "uint" => Ok(Self::Uint(
                required_string(object, "value")?
                    .parse()
                    .map_err(|_| "uint.value is outside the unsigned 64-bit range".to_string())?,
            )),
            "double" => Ok(Self::Double(parse_double(required_string(
                object, "value",
            )?)?)),
            "string" => Ok(Self::String(required_string(object, "value")?.to_string())),
            "bytes" => Ok(Self::Bytes(
                STANDARD
                    .decode(required_string(object, "value")?)
                    .map_err(|error| format!("invalid bytes.value: {error}"))?,
            )),
            "timestamp" => Ok(Self::Timestamp(
                required_string(object, "value")?.to_string(),
            )),
            "duration" => Ok(Self::Duration(
                required_string(object, "value")?.to_string(),
            )),
            "list" => Ok(Self::List(
                required(object, "items")?
                    .as_array()
                    .ok_or_else(|| "list.items must be an array".to_string())?
                    .iter()
                    .map(Self::from_json)
                    .collect::<Result<_, _>>()?,
            )),
            "map" => Ok(Self::Map(
                required(object, "entries")?
                    .as_array()
                    .ok_or_else(|| "map.entries must be an array".to_string())?
                    .iter()
                    .map(|entry| {
                        let entry = entry
                            .as_object()
                            .ok_or_else(|| "map entry must be an object".to_string())?;
                        Ok(CelMapEntry {
                            key: Self::from_json(required(entry, "key")?)?,
                            value: Self::from_json(required(entry, "value")?)?,
                        })
                    })
                    .collect::<Result<_, String>>()?,
            )),
            other => Err(format!("unsupported CEL value kind {other}")),
        }
    }

    pub fn to_json(&self) -> Value {
        let mut object = Map::new();
        object.insert("kind".to_string(), Value::String(self.kind().to_string()));
        match self {
            Self::Null => {}
            Self::Bool(value) => {
                object.insert("value".to_string(), Value::Bool(*value));
            }
            Self::Int(value) => {
                object.insert("value".to_string(), Value::String(value.to_string()));
            }
            Self::Uint(value) => {
                object.insert("value".to_string(), Value::String(value.to_string()));
            }
            Self::Double(value) => {
                object.insert("value".to_string(), Value::String(format_double(*value)));
            }
            Self::String(value) => {
                object.insert("value".to_string(), Value::String(value.clone()));
            }
            Self::Bytes(value) => {
                object.insert("value".to_string(), Value::String(STANDARD.encode(value)));
            }
            Self::Timestamp(value) | Self::Duration(value) => {
                object.insert("value".to_string(), Value::String(value.clone()));
            }
            Self::List(values) => {
                object.insert(
                    "items".to_string(),
                    Value::Array(values.iter().map(Self::to_json).collect()),
                );
            }
            Self::Map(entries) => {
                object.insert(
                    "entries".to_string(),
                    Value::Array(
                        entries
                            .iter()
                            .map(|entry| {
                                serde_json::json!({
                                    "key": entry.key.to_json(),
                                    "value": entry.value.to_json(),
                                })
                            })
                            .collect(),
                    ),
                );
            }
        }
        Value::Object(object)
    }

    fn kind(&self) -> &'static str {
        match self {
            Self::Null => "null",
            Self::Bool(_) => "bool",
            Self::Int(_) => "int",
            Self::Uint(_) => "uint",
            Self::Double(_) => "double",
            Self::String(_) => "string",
            Self::Bytes(_) => "bytes",
            Self::Timestamp(_) => "timestamp",
            Self::Duration(_) => "duration",
            Self::List(_) => "list",
            Self::Map(_) => "map",
        }
    }
}

fn required<'a>(object: &'a Map<String, Value>, name: &str) -> Result<&'a Value, String> {
    object
        .get(name)
        .ok_or_else(|| format!("CEL value is missing {name}"))
}

fn required_string<'a>(object: &'a Map<String, Value>, name: &str) -> Result<&'a str, String> {
    required(object, name)?
        .as_str()
        .ok_or_else(|| format!("{name} must be a string"))
}

fn parse_double(value: &str) -> Result<f64, String> {
    match value {
        "NaN" => Ok(f64::NAN),
        "Infinity" | "+Infinity" => Ok(f64::INFINITY),
        "-Infinity" => Ok(f64::NEG_INFINITY),
        other => other
            .parse()
            .map_err(|_| format!("invalid double value {other}")),
    }
}

fn format_double(value: f64) -> String {
    if value.is_nan() {
        "NaN".to_string()
    } else if value == f64::INFINITY {
        "Infinity".to_string()
    } else if value == f64::NEG_INFINITY {
        "-Infinity".to_string()
    } else {
        value.to_string()
    }
}
