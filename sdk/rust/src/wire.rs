use serde::Deserialize;

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

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
pub struct CelValidationResult {
    pub valid: bool,
    pub issues: Vec<CelIssue>,
}
