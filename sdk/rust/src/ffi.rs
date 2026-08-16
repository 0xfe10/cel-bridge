use crate::CelBridgeError;
use std::ffi::{CStr, CString, c_char};

unsafe extern "C" {
    fn cel_bridge_runtime_info() -> *mut c_char;
    fn cel_bridge_validate(environment_json: *const c_char, source: *const c_char) -> *mut c_char;
    fn cel_bridge_evaluate(
        environment_json: *const c_char,
        source: *const c_char,
        variables_json: *const c_char,
    ) -> *mut c_char;
    fn cel_bridge_free(value: *mut c_char);
}

struct NativeString(*mut c_char);

impl NativeString {
    fn text(self) -> Result<String, CelBridgeError> {
        if self.0.is_null() {
            return Err(CelBridgeError::new(
                "runtime_error",
                "native runtime returned a null string",
            ));
        }
        // The Go ABI returns an allocated NUL-terminated UTF-8 string owned by
        // this wrapper until NativeString drops it.
        let value = unsafe { CStr::from_ptr(self.0) };
        let text = value.to_str().map_err(|_| {
            CelBridgeError::new("protocol_mismatch", "native runtime returned invalid UTF-8")
        })?;
        Ok(text.to_string())
    }
}

impl Drop for NativeString {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe { cel_bridge_free(self.0) };
        }
    }
}

fn input(value: &str) -> Result<CString, CelBridgeError> {
    CString::new(value).map_err(|_| {
        CelBridgeError::new(
            "invalid_request",
            "native runtime inputs must not contain NUL bytes",
        )
    })
}

pub fn runtime_info() -> Result<String, CelBridgeError> {
    NativeString(unsafe { cel_bridge_runtime_info() }).text()
}

pub fn validate(environment: &str, source: &str) -> Result<String, CelBridgeError> {
    let environment = input(environment)?;
    let source = input(source)?;
    NativeString(unsafe { cel_bridge_validate(environment.as_ptr(), source.as_ptr()) }).text()
}

pub fn evaluate(
    environment: &str,
    source: &str,
    variables: &str,
) -> Result<String, CelBridgeError> {
    let environment = input(environment)?;
    let source = input(source)?;
    let variables = input(variables)?;
    NativeString(unsafe {
        cel_bridge_evaluate(environment.as_ptr(), source.as_ptr(), variables.as_ptr())
    })
    .text()
}
