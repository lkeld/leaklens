fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=proto/leak_detection_api.proto");
    
    prost_build::compile_protos(
        &["proto/leak_detection_api.proto"],
        &["proto/"],
    )?;
    
    Ok(())
}