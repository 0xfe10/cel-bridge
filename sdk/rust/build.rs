#[path = "build/mod.rs"]
mod build;

fn main() {
    if let Err(error) = build::run() {
        panic!("failed to prepare cel-bridge runtime: {error}");
    }
}
