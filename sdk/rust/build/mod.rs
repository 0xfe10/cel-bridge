mod artifact;
mod source;
mod target;

use std::env;

pub fn run() -> Result<(), String> {
    for name in [
        "CEL_BRIDGE_ARTIFACT_DIR",
        "CEL_BRIDGE_BUILD_FROM_SOURCE",
        "CEL_BRIDGE_RUNTIME_SOURCE",
        "CEL_BRIDGE_RELEASE_BASE_URL",
        "CEL_BRIDGE_ALLOW_INSECURE_RELEASE_BASE",
    ] {
        println!("cargo:rerun-if-env-changed={name}");
    }
    if env::var_os("DOCS_RS").is_some() {
        println!("cargo:rustc-cfg=cel_bridge_docs_rs");
        return Ok(());
    }

    let triple = env::var("TARGET").map_err(|error| error.to_string())?;
    let target = target::from_triple(&triple)?;
    println!("cargo:rerun-if-changed=../../VERSION");
    println!("cargo:rerun-if-changed=../../go.mod");
    println!("cargo:rerun-if-changed=../../go.sum");
    println!("cargo:rerun-if-changed=../../abi/cel_bridge.h");
    println!("cargo:rerun-if-changed=../../abi/cel_bridge.def");
    println!("cargo:rerun-if-changed=../../runtime");

    let out_dir = std::path::PathBuf::from(
        env::var_os("OUT_DIR").ok_or_else(|| "OUT_DIR is not set".to_string())?,
    );
    let library = if let Some(directory) = env::var_os("CEL_BRIDGE_ARTIFACT_DIR") {
        artifact::from_directory(directory.as_ref(), &target, &out_dir)?
    } else if is_true("CEL_BRIDGE_BUILD_FROM_SOURCE") {
        let manifest_dir = env::var_os("CARGO_MANIFEST_DIR")
            .ok_or_else(|| "CARGO_MANIFEST_DIR is not set".to_string())?;
        let root = source::runtime_root(manifest_dir.as_ref())?;
        source::build(&root, &target, &out_dir)?
    } else {
        artifact::from_release(&target, &out_dir)?
    };

    println!("cargo:rustc-link-search=native={}", out_dir.display());
    if target.static_linking {
        println!("cargo:rustc-link-lib=static=cel_bridge");
        if target.goos == "linux" {
            for library in ["pthread", "dl", "m"] {
                println!("cargo:rustc-link-lib=dylib={library}");
            }
        }
    } else {
        println!("cargo:rustc-link-lib=dylib=cel_bridge");
    }
    println!(
        "cargo:rustc-env=CEL_BRIDGE_NATIVE_LIBRARY={}",
        library.display()
    );
    Ok(())
}

fn is_true(name: &str) -> bool {
    matches!(
        env::var(name).ok().as_deref(),
        Some("1") | Some("true") | Some("TRUE")
    )
}
