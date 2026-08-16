use crate::wire::CelIssue;
use std::error::Error;
use std::fmt;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CelBridgeError {
    pub code: String,
    pub message: String,
    pub issues: Vec<CelIssue>,
}

impl CelBridgeError {
    pub(crate) fn new(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
            issues: Vec::new(),
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
        }
    }
}

impl fmt::Display for CelBridgeError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}: {}", self.code, self.message)
    }
}

impl Error for CelBridgeError {}
