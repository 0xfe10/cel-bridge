use super::target::Target;
use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;

pub fn emit_rerun_inputs(root: &Path) {
    for path in [
        root.join("VERSION"),
        root.join("go.mod"),
        root.join("go.sum"),
        root.join("abi/cel_bridge.h"),
        root.join("abi/cel_bridge.def"),
        root.join("runtime"),
    ] {
        println!("cargo:rerun-if-changed={}", path.display());
    }
}

pub fn runtime_root(manifest_dir: &Path) -> Result<PathBuf, String> {
    if let Some(value) = env::var_os("CEL_BRIDGE_RUNTIME_SOURCE") {
        let path = PathBuf::from(value);
        if path.join("go.mod").is_file() {
            return Ok(path);
        }
        if path.join("../go.mod").is_file() {
            return path
                .parent()
                .map(Path::to_path_buf)
                .ok_or_else(|| "runtime source has no repository parent".to_string());
        }
        return Err(format!(
            "CEL_BRIDGE_RUNTIME_SOURCE is not a repository root: {}",
            path.display()
        ));
    }
    let root = manifest_dir
        .join("../..")
        .canonicalize()
        .map_err(|error| format!("cannot locate repository root: {error}"))?;
    if !root.join("go.mod").is_file() {
        return Err(
            "source builds require a repository checkout; set CEL_BRIDGE_RUNTIME_SOURCE"
                .to_string(),
        );
    }
    Ok(root)
}

pub fn build(root: &Path, target: &Target, out_dir: &Path) -> Result<PathBuf, String> {
    let version = Command::new("go")
        .args(["version"])
        .output()
        .map_err(|error| format!("cannot run go version: {error}"))?;
    let version_text = format!(
        "{}{}",
        String::from_utf8_lossy(&version.stdout),
        String::from_utf8_lossy(&version.stderr)
    );
    if !version_text.contains("go1.26") {
        return Err(format!("source build requires Go 1.26, got {version_text}"));
    }
    let output = out_dir.join(target.library);
    let mode = if target.static_linking {
        "c-archive"
    } else {
        "c-shared"
    };
    let output_name = output
        .to_str()
        .ok_or_else(|| "invalid output path".to_string())?;
    let mut command = Command::new("go");
    command
        .args([
            "build",
            "-trimpath",
            &format!("-buildmode={mode}"),
            "-o",
            output_name,
            "./runtime/cmd/native",
        ])
        .current_dir(root)
        .env("CGO_ENABLED", "1")
        .env("GOOS", target.goos)
        .env("GOARCH", target.goarch);
    for (name, value) in compiler_environment(target)? {
        command.env(name, value);
    }
    let result = command
        .output()
        .map_err(|error| format!("cannot run Go build: {error}"))?;
    if !result.status.success() {
        return Err(format!(
            "Go {} build failed: {}{}",
            target.name,
            String::from_utf8_lossy(&result.stdout),
            String::from_utf8_lossy(&result.stderr)
        ));
    }
    if !output.is_file() {
        return Err(format!("Go build did not produce {}", output.display()));
    }
    if let Some(import_library) = target.import_library {
        create_windows_import_library(root, out_dir.join(import_library))?;
    }
    Ok(output)
}

fn create_windows_import_library(root: &Path, output: PathBuf) -> Result<(), String> {
    let definition = root.join("abi/cel_bridge.def");
    if !definition.is_file() {
        return Err(format!(
            "Windows import definition is missing: {}",
            definition.display()
        ));
    }
    let commands = [
        (
            "lib.exe",
            vec![
                format!("/DEF:{}", definition.display()),
                "/MACHINE:X64".to_string(),
                format!("/OUT:{}", output.display()),
            ],
        ),
        (
            "llvm-dlltool",
            vec![
                "-m".to_string(),
                "i386:x86-64".to_string(),
                "-d".to_string(),
                definition.display().to_string(),
                "-l".to_string(),
                output.display().to_string(),
            ],
        ),
    ];
    let mut failures = Vec::new();
    for (executable, arguments) in commands {
        match Command::new(executable)
            .args(&arguments)
            .current_dir(root)
            .output()
        {
            Ok(result) if result.status.success() && output.is_file() => {
                if output.metadata().map(|value| value.len()).unwrap_or(0) > 0 {
                    return Ok(());
                }
                failures.push(format!("{executable}: generated an empty library"));
            }
            Ok(result) => failures.push(format!(
                "{executable}: {}",
                String::from_utf8_lossy(&result.stderr)
            )),
            Err(error) => failures.push(format!("{executable}: {error}")),
        }
    }
    Err(format!(
        "could not create {} ({})",
        output.display(),
        failures.join("; ")
    ))
}

fn compiler_environment(target: &Target) -> Result<Vec<(&'static str, String)>, String> {
    if target.goos == "darwin" {
        let sdk = xcrun(&["--sdk", "macosx", "--show-sdk-path"])?;
        let compiler = xcrun(&["--sdk", "macosx", "--find", "clang"])?;
        return Ok(vec![
            ("CC", compiler),
            ("SDKROOT", sdk.clone()),
            ("CGO_CFLAGS_ALLOW", "-isysroot".to_string()),
            ("CGO_LDFLAGS_ALLOW", "-isysroot".to_string()),
            ("CGO_CFLAGS", format!("-isysroot {sdk}")),
            ("CGO_LDFLAGS", format!("-isysroot {sdk}")),
        ]);
    }
    if matches!(target.goos, "linux" | "android")
        && let Some(compiler) = env::var_os("CEL_BRIDGE_CROSS_CC")
    {
        return Ok(vec![("CC", compiler.to_string_lossy().into_owned())]);
    }
    if target.goos != "ios" {
        return Ok(Vec::new());
    }
    let simulator = target.name.ends_with("-simulator");
    let sdk_name = if simulator {
        "iphonesimulator"
    } else {
        "iphoneos"
    };
    let sdk = xcrun(&["--sdk", sdk_name, "--show-sdk-path"])?;
    let compiler = xcrun(&["--sdk", sdk_name, "--find", "clang"])?;
    let architecture = if target.goarch == "amd64" {
        "x86_64"
    } else {
        target.goarch
    };
    let triple = if simulator {
        format!("{architecture}-apple-ios-simulator")
    } else {
        format!("{architecture}-apple-ios")
    };
    let flags = format!("-isysroot {sdk} -target {triple}");
    Ok(vec![
        ("CC", compiler),
        ("SDKROOT", sdk),
        ("CGO_CFLAGS_ALLOW", "-target|-isysroot".to_string()),
        ("CGO_LDFLAGS_ALLOW", "-target|-isysroot".to_string()),
        ("CGO_CFLAGS", flags.clone()),
        ("CGO_LDFLAGS", flags),
    ])
}

fn xcrun(args: &[&str]) -> Result<String, String> {
    let output = Command::new("xcrun")
        .args(args)
        .output()
        .map_err(|error| format!("cannot run xcrun: {error}"))?;
    if !output.status.success() {
        return Err(format!(
            "xcrun failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ));
    }
    let value = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if value.is_empty() {
        return Err("xcrun returned no value".to_string());
    }
    Ok(value)
}
