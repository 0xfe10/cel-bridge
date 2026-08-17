use super::target::Target;
use flate2::read::GzDecoder;
use sha2::{Digest, Sha256};
use std::env;
use std::fs;
use std::io::{Cursor, Read};
use std::path::{Component, Path, PathBuf};
use tar::Archive;
use zip::ZipArchive;

pub fn from_directory(
    directory: &Path,
    target: &Target,
    out_dir: &Path,
) -> Result<PathBuf, String> {
    let candidates = [
        directory.join(target.name).join(target.library),
        directory.join(target.library),
    ];
    let source = candidates
        .iter()
        .find(|path| path.is_file())
        .ok_or_else(|| {
            format!(
                "artifact directory has no {} for {}",
                target.library, target.name
            )
        })?;
    println!("cargo:rerun-if-changed={}", source.display());
    let output = out_dir.join(target.library);
    fs::copy(source, &output).map_err(|error| format!("copy artifact: {error}"))?;
    if let Some(import_library) = target.import_library {
        let import_source = source
            .parent()
            .ok_or_else(|| "artifact has no parent directory".to_string())?
            .join(import_library);
        if !import_source.is_file() {
            return Err(format!(
                "artifact directory has no {} for {}",
                import_library, target.name
            ));
        }
        println!("cargo:rerun-if-changed={}", import_source.display());
        fs::copy(&import_source, out_dir.join(import_library))
            .map_err(|error| format!("copy import library: {error}"))?;
    }
    Ok(output)
}

pub fn from_release(target: &Target, out_dir: &Path) -> Result<PathBuf, String> {
    let base = env::var("CEL_BRIDGE_RELEASE_BASE_URL")
        .unwrap_or_else(|_| "https://github.com/0xfe10/cel-bridge/releases/download".to_string());
    let local_http = is_local_http_url(&base);
    if !base.starts_with("https://")
        && !(is_true("CEL_BRIDGE_ALLOW_INSECURE_RELEASE_BASE") && local_http)
    {
        return Err("release base URL must use HTTPS".to_string());
    }
    let version = env!("CARGO_PKG_VERSION");
    let manifest_name = format!("cel-bridge-manifest-v{version}.json");
    let manifest_url = format!("{}/v{version}/{manifest_name}", base.trim_end_matches('/'));
    let manifest = get(&manifest_url, local_http)?;
    let manifest: serde_json::Value = serde_json::from_slice(&manifest)
        .map_err(|error| format!("invalid release manifest: {error}"))?;
    if manifest["manifestVersion"] != 3
        || manifest["runtimeVersion"] != version
        || manifest["protocolVersion"] != 1
    {
        return Err("release manifest version does not match this crate".to_string());
    }
    let entries = manifest["artifacts"]
        .as_array()
        .ok_or_else(|| "release manifest artifacts is not an array".to_string())?;
    let entry = entries
        .iter()
        .find(|entry| entry["id"] == target.artifact)
        .ok_or_else(|| format!("release manifest has no {} entry", target.artifact))?;
    let file = entry["file"]
        .as_str()
        .ok_or("release manifest file is not a string")?;
    if Path::new(file).components().any(|component| {
        matches!(
            component,
            Component::ParentDir | Component::RootDir | Component::Prefix(_)
        )
    }) {
        return Err("release artifact filename is unsafe".to_string());
    }
    let bytes = get(
        &format!("{}/v{version}/{file}", base.trim_end_matches('/')),
        local_http,
    )?;
    let expected = entry["sha256"]
        .as_str()
        .ok_or("release manifest sha256 is not a string")?;
    let expected_size = entry["size"]
        .as_u64()
        .ok_or("release manifest size is not an integer")?;
    if expected_size != bytes.len() as u64 {
        return Err(format!(
            "release artifact size mismatch: expected {expected_size}, got {}",
            bytes.len()
        ));
    }
    let actual = hex_sha256(&bytes);
    if actual != expected {
        return Err(format!("release artifact checksum mismatch: {actual}"));
    }
    let output = out_dir.join(target.library);
    extract(file, &bytes, target.library, target.archive_prefix, &output)?;
    if let Some(import_library) = target.import_library {
        extract(
            file,
            &bytes,
            import_library,
            target.archive_prefix,
            &out_dir.join(import_library),
        )?;
    }
    Ok(output)
}

fn get(url: &str, local_http: bool) -> Result<Vec<u8>, String> {
    let response = ureq::AgentBuilder::new()
        .https_only(!local_http)
        .redirects(if local_http { 0 } else { 5 })
        .build()
        .get(url)
        .call()
        .map_err(|error| format!("download {url}: {error}"))?;
    let mut bytes = Vec::new();
    response
        .into_reader()
        .read_to_end(&mut bytes)
        .map_err(|error| format!("read {url}: {error}"))?;
    Ok(bytes)
}

fn is_local_http_url(url: &str) -> bool {
    let Some(authority) = url.strip_prefix("http://") else {
        return false;
    };
    let authority = authority.split('/').next().unwrap_or(authority);
    let host = authority.rsplit('@').next().unwrap_or(authority);
    let host = host.split(':').next().unwrap_or(host);
    host == "localhost" || host == "127.0.0.1"
}

fn extract(
    archive_name: &str,
    bytes: &[u8],
    library_name: &str,
    required_prefix: Option<&str>,
    output: &Path,
) -> Result<(), String> {
    if archive_name.ends_with(".zip") {
        let mut archive = ZipArchive::new(Cursor::new(bytes))
            .map_err(|error| format!("read zip archive: {error}"))?;
        for index in 0..archive.len() {
            let mut file = archive
                .by_index(index)
                .map_err(|error| format!("read zip entry: {error}"))?;
            let name = file.name().to_string();
            validate_entry(&name)?;
            if required_prefix.is_none_or(|prefix| name.starts_with(prefix))
                && Path::new(&name)
                    .file_name()
                    .and_then(|value| value.to_str())
                    == Some(library_name)
            {
                let mut content = Vec::new();
                file.read_to_end(&mut content)
                    .map_err(|error| format!("read zip library: {error}"))?;
                fs::write(output, content).map_err(|error| format!("write library: {error}"))?;
                return Ok(());
            }
        }
    } else if archive_name.ends_with(".tar.gz") {
        let decoder = GzDecoder::new(Cursor::new(bytes));
        let mut archive = Archive::new(decoder);
        for entry in archive
            .entries()
            .map_err(|error| format!("read tar archive: {error}"))?
        {
            let mut entry = entry.map_err(|error| format!("read tar entry: {error}"))?;
            let path = entry
                .path()
                .map_err(|error| format!("read tar path: {error}"))?
                .to_path_buf();
            let name = path.to_string_lossy().into_owned();
            validate_entry(&name)?;
            if required_prefix.is_none_or(|prefix| name.starts_with(prefix))
                && path.file_name().and_then(|value| value.to_str()) == Some(library_name)
            {
                let mut content = Vec::new();
                entry
                    .read_to_end(&mut content)
                    .map_err(|error| format!("read tar library: {error}"))?;
                fs::write(output, content).map_err(|error| format!("write library: {error}"))?;
                return Ok(());
            }
        }
    } else {
        return Err(format!("unsupported release archive {archive_name}"));
    }
    Err(format!("archive does not contain {library_name}"))
}

fn validate_entry(name: &str) -> Result<(), String> {
    let path = Path::new(name);
    if path.components().any(|component| {
        matches!(
            component,
            Component::ParentDir | Component::RootDir | Component::Prefix(_)
        )
    }) {
        return Err(format!("archive entry is unsafe: {name}"));
    }
    Ok(())
}

fn hex_sha256(bytes: &[u8]) -> String {
    let digest = Sha256::digest(bytes);
    digest.iter().map(|byte| format!("{byte:02x}")).collect()
}

fn is_true(name: &str) -> bool {
    matches!(
        env::var(name).ok().as_deref(),
        Some("1") | Some("true") | Some("TRUE")
    )
}
