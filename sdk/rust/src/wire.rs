use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
pub struct CelIssue {
    pub severity: String,
    pub code: String,
    pub message: String,
    #[serde(default)]
    pub line: u32,
    #[serde(default)]
    pub column: u32,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub struct CelTypeRef {
    #[serde(rename = "type")]
    pub type_name: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub element: Option<Box<CelTypeRef>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub key: Option<Box<CelTypeRef>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub value: Option<Box<CelTypeRef>>,
}

impl CelTypeRef {
    pub fn named(type_name: impl Into<String>) -> Self {
        Self {
            type_name: type_name.into(),
            element: None,
            key: None,
            value: None,
        }
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
pub struct CelValidationResult {
    pub valid: bool,
    #[serde(default, rename = "resultType")]
    pub result_type: Option<CelTypeRef>,
    pub issues: Vec<CelIssue>,
}
