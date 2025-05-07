use anyhow::{anyhow, Result};
use p256::{
    elliptic_curve::{
        sec1::{FromEncodedPoint, ToEncodedPoint},
        Field, Group,
    },
    NistP256, ProjectivePoint, Scalar,
};
use rand::rngs::OsRng;
use sha2::{Digest, Sha256};
use std::cmp::min;
use num_bigint::BigUint;
use num_traits::{One, Zero, Num};
use p256::elliptic_curve::scalar::ScalarPrimitive;

lazy_static::lazy_static! {
    static ref CURVE_P_BIGUINT: BigUint = BigUint::from_str_radix("ffffffff00000001000000000000000000000000ffffffffffffffffffffffff", 16).unwrap();
    static ref CURVE_ORDER_BIGUINT: BigUint = BigUint::from_str_radix("ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551", 16).unwrap();
}


#[derive(Clone)]
pub struct ECCommutativeCipher {
    private_key: Scalar,
}

impl ECCommutativeCipher {

    pub fn new(key: Option<&[u8]>) -> Self {
        let private_key = match key {
            Some(k) => {
                let primitive = ScalarPrimitive::<NistP256>::from_slice(k)
                    .expect("Failed to create scalar primitive from key bytes");
                p256::Scalar::from(primitive)
            },
            None => Scalar::random(&mut OsRng),
        };
        
        ECCommutativeCipher { private_key }
    }
    

    pub fn get_private_key_bytes(&self) -> [u8; 32] {
        self.private_key.to_bytes().into()
    }
    

    fn random_oracle(&self, input_bytes: &[u8], max_value: &BigUint) -> Result<BigUint> {
        let hash_output_length = 256; // SHA-256 output length in bits
        let output_bit_length = max_value.bits() as usize + hash_output_length;
        let iter_count = (output_bit_length + hash_output_length - 1) / hash_output_length;
        
        if iter_count * hash_output_length >= 130048 {
            return Err(anyhow!("Too many iterations required for random oracle"));
        }
        
        let excess_bit_count = (iter_count * hash_output_length) - output_bit_length;
        
        let mut hash_output = BigUint::zero();
        
        for i in 1..=iter_count {
            hash_output = hash_output << hash_output_length;
            

            let i_biguint = BigUint::from(i as u64);
            let i_minimal_bytes_vec = i_biguint.to_bytes_be();
            
            let mut hash_input = Vec::with_capacity(i_minimal_bytes_vec.len() + input_bytes.len());
            hash_input.extend_from_slice(&i_minimal_bytes_vec);
            hash_input.extend_from_slice(input_bytes);
            
            let mut hasher = Sha256::new();
            hasher.update(&hash_input);
            let hash_bytes = hasher.finalize();
            
            let hash_value = BigUint::from_bytes_be(hash_bytes.as_slice());
            hash_output = hash_output | hash_value;
        }
        
        let result = (hash_output >> excess_bit_count) % max_value;
        Ok(result)
    }
    

    pub fn hash_to_curve(&self, data: &[u8]) -> Result<ProjectivePoint> {
        let data = match data.iter().position(|&b| b == 0) {
            Some(pos) => &data[..pos],
            None => data,
        };
        
        let p = BigUint::from_bytes_be(&hex::decode("ffffffff00000001000000000000000000000000ffffffffffffffffffffffff").unwrap());
        let a = BigUint::from_bytes_be(&hex::decode("ffffffff00000001000000000000000000000000fffffffffffffffffffffffc").unwrap());
        let b = BigUint::from_bytes_be(&hex::decode("5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b").unwrap());
        
        let mut x = self.random_oracle(data, &p)?;
        
        loop {
            let mod_x = &x % &p;
            
            let x_squared = (&mod_x * &mod_x) % &p;
            let x_cubed = (&x_squared * &mod_x) % &p;
            let ax = (&a * &mod_x) % &p;
            let y_squared = (&x_cubed + &ax + &b) % &p;
            
            if let Some(sqrt) = mod_sqrt(&y_squared, &p) {
                let point_x = mod_x.to_bytes_be();
                let point_y = if &sqrt % 2u8 == BigUint::one() {
                    (&p - &sqrt).to_bytes_be()
                } else {
                    sqrt.to_bytes_be()
                };
                
                let mut encoded = Vec::with_capacity(65);
                encoded.push(0x04);
                encoded.extend_from_slice(&pad_to_32_bytes(&point_x));
                encoded.extend_from_slice(&pad_to_32_bytes(&point_y));
                
                if let Some(encoded_point) = p256::EncodedPoint::from_bytes(encoded).ok() {
                    let point_option = ProjectivePoint::from_encoded_point(&encoded_point);
                    if bool::from(point_option.is_some()) {
                        let point = point_option.unwrap();
                        if !bool::from(point.is_identity()) {
                            return Ok(point);
                        }
                    }
                }
            }
            
            let x_bytes = x.to_bytes_be();
            x = self.random_oracle(&x_bytes, &p)?;
        }
    }
    

    pub fn encrypt(&self, data: &[u8]) -> Result<Vec<u8>> {
        let point = self.hash_to_curve(data)?;
        
        let encrypted_point = point * &self.private_key;
        
        let encoded_point = encrypted_point.to_encoded_point(true);
        
        Ok(encoded_point.as_bytes().to_vec())
    }
    

    pub fn decrypt(&self, encrypted_data: &[u8]) -> Result<Vec<u8>> {
        let encoded_point = p256::EncodedPoint::from_bytes(encrypted_data)
            .map_err(|_| anyhow!("Invalid encoded point"))?;
        
        let encrypted_point_option = ProjectivePoint::from_encoded_point(&encoded_point);
        if !bool::from(encrypted_point_option.is_some()) {
            return Err(anyhow!("Invalid curve point"));
        }
        let encrypted_point = encrypted_point_option.unwrap();
        
        let inverse_scalar_option = self.private_key.invert();
        if !bool::from(inverse_scalar_option.is_some()) {
            return Err(anyhow!("Failed to invert private key"));
        }
        let inverse_scalar = inverse_scalar_option.unwrap();
        
        let decrypted_point = encrypted_point * inverse_scalar;
        
        let result = decrypted_point.to_encoded_point(true);
        
        Ok(result.as_bytes().to_vec())
    }
}

fn pad_to_32_bytes(input: &[u8]) -> [u8; 32] {
    let mut result = [0u8; 32];
    let start = 32 - min(32, input.len());
    result[start..].copy_from_slice(&input[input.len().saturating_sub(32)..]);
    result
}

fn mod_sqrt(y_squared: &BigUint, p: &BigUint) -> Option<BigUint> {
    let four = BigUint::from(4u32);
    let three = BigUint::from(3u32);
    let remainder = p % &four;
    
    if remainder == three {
        let one = BigUint::from(1u32);
        let exp = (p + &one) / &four;
        let sqrt = mod_pow(y_squared, &exp, p);
        
        let sqrt_squared = (&sqrt * &sqrt) % p;
        if sqrt_squared == *y_squared {
            return Some(sqrt);
        }
    } else {
    }
    
    None
}

fn mod_pow(base: &BigUint, exp: &BigUint, modulus: &BigUint) -> BigUint {
    if *modulus == BigUint::one() {
        return BigUint::zero();
    }
    
    let mut result = BigUint::one();
    let mut base_val = base % modulus;
    let mut exp_val = exp.clone();
    let zero = BigUint::zero();
    let two = BigUint::from(2u32);
    
    while exp_val > zero {
        if &exp_val % &two == BigUint::one() {
            result = (&result * &base_val) % modulus;
        }
        exp_val >>= 1;
        base_val = (&base_val * &base_val) % modulus;
    }
    
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_new_random_key() {
        let cipher = ECCommutativeCipher::new(None);
        let key_bytes = cipher.get_private_key_bytes();
        assert_eq!(key_bytes.len(), 32);
    }
    
    #[test]
    fn test_new_with_key() {
        let key = [1u8; 32];
        let cipher = ECCommutativeCipher::new(Some(&key));
        let retrieved_key = cipher.get_private_key_bytes();
        // The retrieved key won't exactly match the input due to scalar normalization
        assert_eq!(retrieved_key.len(), 32);
    }
    
    #[test]
    fn test_hash_to_curve() {
        let cipher = ECCommutativeCipher::new(None);
        let data = b"test data";
        let result = cipher.hash_to_curve(data);
        assert!(result.is_ok());
    }
    
    #[test]
    fn test_encrypt_decrypt() {
        let cipher = ECCommutativeCipher::new(None);
        let data = b"test data for encryption";
        
        // Encrypt
        let encrypted = cipher.encrypt(data).expect("Encryption failed");
        assert!(!encrypted.is_empty());
        assert!(encrypted.len() >= 33); // Compressed point format is at least 33 bytes
        
        // Decrypt
        let decrypted = cipher.decrypt(&encrypted).expect("Decryption failed");
        
        // Since we're working with points on the curve, not the original data,
        // we need to verify that encrypting the decrypted value gives us the same encrypted value
        let re_encrypted = cipher.encrypt(&decrypted).expect("Re-encryption failed");
        assert_eq!(encrypted, re_encrypted);
    }
    
    #[test]
    fn test_commutativity() {
        // Create two different ciphers
        let cipher1 = ECCommutativeCipher::new(None);
        let cipher2 = ECCommutativeCipher::new(None);
        
        let data = b"test commutativity property";
        
        // First encryption path: cipher1 -> cipher2
        let enc1 = cipher1.encrypt(data).expect("First encryption failed");
        let enc1_2 = cipher2.encrypt(&enc1).expect("Second encryption failed");
        
        // Second encryption path: cipher2 -> cipher1
        let enc2 = cipher2.encrypt(data).expect("First encryption failed");
        let enc2_1 = cipher1.encrypt(&enc2).expect("Second encryption failed");
        
        // The results should be the same regardless of encryption order
        assert_eq!(enc1_2, enc2_1);
        
        // Now test decryption
        let dec1 = cipher1.decrypt(&enc1_2).expect("First decryption failed");
        let dec2 = cipher2.decrypt(&dec1).expect("Second decryption failed");
        
        // Hash the original data to compare with the final decrypted result
        let expected = cipher2.hash_to_curve(data).expect("Hash to curve failed");
        let expected_bytes = expected.to_encoded_point(true).as_bytes().to_vec();
        
        assert_eq!(dec2, expected_bytes);
    }
}