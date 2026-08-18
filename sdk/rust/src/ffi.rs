use crate::CelBridgeError;
use std::ffi::{CStr, CString, c_char};

unsafe extern "C" {
    fn cel_bridge_runtime_info() -> *mut c_char;
    fn cel_bridge_validate_options(
        environment_json: *const c_char,
        source: *const c_char,
        options_json: *const c_char,
    ) -> *mut c_char;
    fn cel_bridge_evaluate_options(
        environment_json: *const c_char,
        source: *const c_char,
        variables_json: *const c_char,
        options_json: *const c_char,
    ) -> *mut c_char;
    fn cel_bridge_evaluate_many(
        environment_json: *const c_char,
        sources_json: *const c_char,
        variables_json: *const c_char,
    ) -> *mut c_char;
    fn cel_bridge_evaluate_requests(
        environment_json: *const c_char,
        requests_json: *const c_char,
        options_json: *const c_char,
    ) -> *mut c_char;
    fn cel_bridge_prepare(
        environment_json: *const c_char,
        source: *const c_char,
        options_json: *const c_char,
    ) -> *mut c_char;
    fn cel_bridge_evaluate_program(
        program_id: *const c_char,
        variables_json: *const c_char,
        options_json: *const c_char,
    ) -> *mut c_char;
    fn cel_bridge_release_program(program_id: *const c_char) -> *mut c_char;
    fn cel_bridge_close() -> *mut c_char;
    fn cel_bridge_create(options_json: *const c_char) -> *mut c_char;
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

pub fn validate_options(
    environment: &str,
    source: &str,
    options: &str,
) -> Result<String, CelBridgeError> {
    let environment = input(environment)?;
    let source = input(source)?;
    let options = input(options)?;
    NativeString(unsafe {
        cel_bridge_validate_options(environment.as_ptr(), source.as_ptr(), options.as_ptr())
    })
    .text()
}

pub fn evaluate_options(
    environment: &str,
    source: &str,
    variables: &str,
    options: &str,
) -> Result<String, CelBridgeError> {
    let environment = input(environment)?;
    let source = input(source)?;
    let variables = input(variables)?;
    let options = input(options)?;
    NativeString(unsafe {
        cel_bridge_evaluate_options(
            environment.as_ptr(),
            source.as_ptr(),
            variables.as_ptr(),
            options.as_ptr(),
        )
    })
    .text()
}

pub fn evaluate_many(
    environment: &str,
    sources: &str,
    variables: &str,
) -> Result<String, CelBridgeError> {
    let environment = input(environment)?;
    let sources = input(sources)?;
    let variables = input(variables)?;
    NativeString(unsafe {
        cel_bridge_evaluate_many(environment.as_ptr(), sources.as_ptr(), variables.as_ptr())
    })
    .text()
}

pub fn evaluate_requests(
    environment: &str,
    requests: &str,
    options: &str,
) -> Result<String, CelBridgeError> {
    let environment = input(environment)?;
    let requests = input(requests)?;
    let options = input(options)?;
    NativeString(unsafe {
        cel_bridge_evaluate_requests(environment.as_ptr(), requests.as_ptr(), options.as_ptr())
    })
    .text()
}

pub fn prepare(environment: &str, source: &str, options: &str) -> Result<String, CelBridgeError> {
    let environment = input(environment)?;
    let source = input(source)?;
    let options = input(options)?;
    NativeString(unsafe {
        cel_bridge_prepare(environment.as_ptr(), source.as_ptr(), options.as_ptr())
    })
    .text()
}

pub fn evaluate_program(
    program_id: &str,
    variables: &str,
    options: &str,
) -> Result<String, CelBridgeError> {
    let program_id = input(program_id)?;
    let variables = input(variables)?;
    let options = input(options)?;
    NativeString(unsafe {
        cel_bridge_evaluate_program(program_id.as_ptr(), variables.as_ptr(), options.as_ptr())
    })
    .text()
}

pub fn release_program(program_id: &str) -> Result<String, CelBridgeError> {
    let program_id = input(program_id)?;
    NativeString(unsafe { cel_bridge_release_program(program_id.as_ptr()) }).text()
}

pub fn close() -> Result<String, CelBridgeError> {
    NativeString(unsafe { cel_bridge_close() }).text()
}

pub fn create(options: &str) -> Result<String, CelBridgeError> {
    let options = input(options)?;
    NativeString(unsafe { cel_bridge_create(options.as_ptr()) }).text()
}
