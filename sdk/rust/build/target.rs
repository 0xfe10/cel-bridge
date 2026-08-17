#[derive(Clone, Debug)]
pub struct Target {
    pub name: &'static str,
    pub goos: &'static str,
    pub goarch: &'static str,
    pub library: &'static str,
    pub import_library: Option<&'static str>,
    pub static_linking: bool,
}

pub fn from_triple(triple: &str) -> Result<Target, String> {
    let target = match triple {
        "x86_64-unknown-linux-gnu" => Target {
            name: "linux-x86_64",
            goos: "linux",
            goarch: "amd64",
            library: "libcel_bridge.a",
            import_library: None,
            static_linking: true,
        },
        "aarch64-unknown-linux-gnu" => Target {
            name: "linux-aarch64",
            goos: "linux",
            goarch: "arm64",
            library: "libcel_bridge.a",
            import_library: None,
            static_linking: true,
        },
        "x86_64-apple-darwin" => Target {
            name: "macos-x86_64",
            goos: "darwin",
            goarch: "amd64",
            library: "libcel_bridge.a",
            import_library: None,
            static_linking: true,
        },
        "aarch64-apple-darwin" => Target {
            name: "macos-arm64",
            goos: "darwin",
            goarch: "arm64",
            library: "libcel_bridge.a",
            import_library: None,
            static_linking: true,
        },
        "x86_64-pc-windows-msvc" => Target {
            name: "windows-x86_64",
            goos: "windows",
            goarch: "amd64",
            library: "cel_bridge.dll",
            import_library: Some("cel_bridge.lib"),
            static_linking: false,
        },
        "aarch64-linux-android" => Target {
            name: "android-arm64-v8a",
            goos: "android",
            goarch: "arm64",
            library: "libcel_bridge.so",
            import_library: None,
            static_linking: false,
        },
        "armv7-linux-androideabi" => Target {
            name: "android-armeabi-v7a",
            goos: "android",
            goarch: "arm",
            library: "libcel_bridge.so",
            import_library: None,
            static_linking: false,
        },
        "x86_64-linux-android" => Target {
            name: "android-x86_64",
            goos: "android",
            goarch: "amd64",
            library: "libcel_bridge.so",
            import_library: None,
            static_linking: false,
        },
        "aarch64-apple-ios" => Target {
            name: "ios-arm64",
            goos: "ios",
            goarch: "arm64",
            library: "libcel_bridge.a",
            import_library: None,
            static_linking: true,
        },
        "aarch64-apple-ios-sim" => Target {
            name: "ios-arm64-simulator",
            goos: "ios",
            goarch: "arm64",
            library: "libcel_bridge.a",
            import_library: None,
            static_linking: true,
        },
        "x86_64-apple-ios" => Target {
            name: "ios-x86_64-simulator",
            goos: "ios",
            goarch: "amd64",
            library: "libcel_bridge.a",
            import_library: None,
            static_linking: true,
        },
        other => return Err(format!("unsupported Rust target {other}")),
    };
    Ok(target)
}
