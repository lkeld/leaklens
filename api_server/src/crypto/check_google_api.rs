use anyhow::Result;
use hex;
use sha2::{Digest, Sha256};
use tracing::{debug, info};

use crate::crypto::ecc_cipher::ECCommutativeCipher;
use crate::crypto::hashing::{extract_username_from_email, scrypt_hash_username_and_password, username_hash_prefix};
use crate::proto::{LookupSingleLeakRequest, LookupSingleLeakResponse};


#[allow(dead_code)]
pub fn process_credential(raw_username: &str, password: &str) -> (String, String) {
    let username = extract_username_from_email(raw_username);
    debug!("Processed username '{}' from '{}'", username, raw_username);
    (username, password.to_string())
}


#[allow(dead_code)]
pub fn get_reference_lookup(username: &str, password: &str) -> Result<(LookupSingleLeakRequest, bool)> {
    let (processed_username, processed_password) = process_credential(username, password);
    
    let prefix = username_hash_prefix(&processed_username);
    debug!("Username hash prefix: {}", hex::encode(&prefix));
    
    let lookup_hash = scrypt_hash_username_and_password(&processed_username, &processed_password)?;
    
    let lookup_hash = match lookup_hash.iter().position(|&b| b == 0) {
        Some(pos) => &lookup_hash[..pos],
        None => &lookup_hash[..],
    };
    debug!("Scrypt hash: {}", hex::encode(lookup_hash));
    
    let cipher = ECCommutativeCipher::new(None);
    let encrypted_lookup_hash = cipher.encrypt(lookup_hash)?;
    debug!("Encrypted lookup hash: {}", hex::encode(&encrypted_lookup_hash));
    
    let mut request = LookupSingleLeakRequest::default();
    request.username_hash_prefix = prefix;
    request.username_hash_prefix_length = 26; // Fixed value per protocol
    request.encrypted_lookup_hash = encrypted_lookup_hash;
    
    let expected_is_leaked = true;
    
    Ok((request, expected_is_leaked))
}


#[allow(dead_code)]
pub fn create_lookup_request(
    username: &str, 
    password: &str, 
    cipher: &ECCommutativeCipher
) -> Result<LookupSingleLeakRequest> {
    let (processed_username, processed_password) = process_credential(username, password);
    
    let prefix = username_hash_prefix(&processed_username);
    
    let lookup_hash = scrypt_hash_username_and_password(&processed_username, &processed_password)?;
    
    let lookup_hash = match lookup_hash.iter().position(|&b| b == 0) {
        Some(pos) => &lookup_hash[..pos],
        None => &lookup_hash[..],
    };
    
    let encrypted_lookup_hash = cipher.encrypt(lookup_hash)?;
    
    let mut request = LookupSingleLeakRequest::default();
    request.username_hash_prefix = prefix;
    request.username_hash_prefix_length = 26; // Fixed value per protocol
    request.encrypted_lookup_hash = encrypted_lookup_hash;
    
    Ok(request)
}


pub fn check_credential_leaked(
    response: &LookupSingleLeakResponse,
    decrypted_hash: &[u8]
) -> Result<bool> {
    if response.encrypted_leak_match_prefix.is_empty() {
        debug!("No leak match prefixes returned - credential not found in database");
        return Ok(false);
    }
    
    debug!("Checking if credential is leaked with {} prefixes", response.encrypted_leak_match_prefix.len());
    debug!("Decrypted hash: {}", hex::encode(decrypted_hash));
    

    
    let mut hasher1 = Sha256::new();
    hasher1.update(&[0x02]);
    hasher1.update(&decrypted_hash[1..]);
    let hash1 = hasher1.finalize().to_vec();
    
    let mut hasher2 = Sha256::new();
    hasher2.update(&[0x03]);
    hasher2.update(&decrypted_hash[1..]);
    let hash2 = hasher2.finalize().to_vec();
    
    debug!("Hash1: {}", hex::encode(&hash1));
    debug!("Hash2: {}", hex::encode(&hash2));
    

    for (i, prefix) in response.encrypted_leak_match_prefix.iter().enumerate() {
        debug!("Checking prefix {}: {}", i, hex::encode(prefix));
        
        if prefix.len() <= hash1.len() && hash1.starts_with(prefix) {
            debug!("Found match with hash1 variant");
            return Ok(true);
        }
        if prefix.len() <= hash2.len() && hash2.starts_with(prefix) {
            debug!("Found match with hash2 variant");
            return Ok(true);
        }
    }
    
    debug!("No matches found among {} potential leak prefixes", response.encrypted_leak_match_prefix.len());
    Ok(false)
}


pub fn debug_response_check(
    response: &LookupSingleLeakResponse,
    decrypted_hash: &[u8]
) -> Result<bool> {
    info!("Debug response check - decrypted hash: {}", hex::encode(decrypted_hash));
    info!("Prefixes count: {}", response.encrypted_leak_match_prefix.len());
    
    if response.encrypted_leak_match_prefix.is_empty() {
        info!("No leak match prefixes returned - credential not found in database");
        return Ok(false);
    }
    

    
    let mut hasher1 = Sha256::new();
    hasher1.update(&[0x02]);
    hasher1.update(&decrypted_hash[1..]);
    let hash1 = hasher1.finalize().to_vec();
    info!("Hash1: {}", hex::encode(&hash1));

    let mut hasher2 = Sha256::new();
    hasher2.update(&[0x03]);
    hasher2.update(&decrypted_hash[1..]);
    let hash2 = hasher2.finalize().to_vec();
    info!("Hash2: {}", hex::encode(&hash2));
    
    for (i, prefix) in response.encrypted_leak_match_prefix.iter().enumerate() {
        info!("Prefix {}: {}", i, hex::encode(prefix));
        
        let hash1_matches = prefix.len() <= hash1.len() && hash1.starts_with(prefix);
        info!("Hash1 match: {}", hash1_matches);
        
        let hash2_matches = prefix.len() <= hash2.len() && hash2.starts_with(prefix);
        info!("Hash2 match: {}", hash2_matches);
        
        if hash1_matches || hash2_matches {
            info!("Found match!");
            return Ok(true);
        }
    }
    
    info!("No matches found");
    Ok(false)
} 