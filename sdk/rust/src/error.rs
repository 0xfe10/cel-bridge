use crate::wire::CelIssue;
use serde_json::Value;
use std::collections::BTreeMap;
use std::error::Error;
use std::fmt;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CelBridgeError {
    pub code: String,
    pub message: String,
    pub issues: Vec<CelIssue>,
    pub details: BTreeMap<String, Value>,
}

impl CelBridgeError {
    pub(crate) fn new(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
            issues: Vec::new(),
            details: BTreeMap::new(),
        }
    }

    pub(crate) fn with_issues(
        code: impl Into<String>,
        message: impl Into<String>,
        issues: Vec<CelIssue>,
    ) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
            issues,
            details: BTreeMap::new(),
        }
    }

    pub(crate) fn with_details(
        code: impl Into<String>,
        message: impl Into<String>,
        details: BTreeMap<String, Value>,
    ) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
            issues: Vec::new(),
            details,
        }
    }
}

impl fmt::Display for CelBridgeError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}: {}", self.code, self.message)
    }
}

impl Error for CelBridgeError {}
