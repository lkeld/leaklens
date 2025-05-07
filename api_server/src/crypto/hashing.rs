use sha2::{Digest, Sha256};
use scrypt::{scrypt, Params};
use anyhow::{Context, Result};

pub const USERNAME_SALT: [u8; 32] = [
    0xC4, 0x94, 0xA3, 0x95, 0xF8, 0xC0, 0xE2, 0x3E,
    0xA9, 0x23, 0x04, 0x78, 0x70, 0x2C, 0x72, 0x18,
    0x56, 0x54, 0x99, 0xB3, 0xE9, 0x21, 0x18, 0x6C,
    0x21, 0x1A, 0x01, 0x22, 0x3C, 0x45, 0x4A, 0xFA
];

pub const PASSWORD_SALT: [u8; 32] = [
    0x30, 0x76, 0x2A, 0xD2, 0x3F, 0x7B, 0xA1, 0x9B,
    0xF8, 0xE3, 0x42, 0xFC, 0xA1, 0xA7, 0x8D, 0x06,
    0xE6, 0x6B, 0xE4, 0xDB, 0xB8, 0x4F, 0x81, 0x53,
    0xC5, 0x03, 0xC8, 0xDB, 0xBD, 0xDE, 0xA5, 0x20
];


pub fn extract_username_from_email(email: &str) -> String {
    match email.split('@').next() {
        Some(username) => username.to_string(),
        None => email.to_string(),
    }
}


pub fn username_hash_prefix(username: &str) -> Vec<u8> {
    let mut hasher = Sha256::new();
    hasher.update(username.as_bytes());
    hasher.update(&USERNAME_SALT);
    
    let hash = hasher.finalize();
    
    // take the first 4 bytes and mask the last byte
    let mut result = hash[0..4].to_vec();
    result[3] &= 0b11000000;
    
    result
}


pub fn scrypt_hash_username_and_password(username: &str, password: &str) -> Result<Vec<u8>> {
    let username_to_hash = extract_username_from_email(username);
    
    let username_password = [username_to_hash.as_bytes(), password.as_bytes()].concat();
    let salt = [username_to_hash.as_bytes(), &PASSWORD_SALT].concat();
    
    let params = Params::new(12, 8, 1, 32).context("Failed to create scrypt parameters")?;
    
    let mut output = vec![0u8; 32];
    scrypt(&username_password, &salt, &params, &mut output)
        .context("Failed to compute scrypt hash")?;
    
    Ok(output)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_username_hash_prefix() {
        let username = "test@example.com";
        let prefix = username_hash_prefix(username);
        assert_eq!(prefix.len(), 4);
        assert_eq!(prefix[3] & 0b00111111, 0);
    }

    #[test]
    fn test_scrypt_hash_username_and_password() {
        let username = "test@example.com";
        let password = "password123";
        
        let result = scrypt_hash_username_and_password(username, password);
        assert!(result.is_ok());
        
        let hash = result.unwrap();
        assert_eq!(hash.len(), 32);
    }
    
    #[test]
    fn test_extract_username_from_email() {
        assert_eq!(extract_username_from_email("test@example.com"), "test");
        assert_eq!(extract_username_from_email("user.name@domain.co.uk"), "user.name");
        assert_eq!(extract_username_from_email("username"), "username"); // not an email
    }
}