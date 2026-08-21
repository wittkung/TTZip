// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#[cfg(test)]
mod tests {
    use super::super::*;

    #[test]
    fn test_zipcrypto_initial_state() {
        let keys = ZipCryptoKeys::new();
        assert_eq!(keys.key0, ZIPCRYPTO_KEY0_INIT);
        assert_eq!(keys.key1, ZIPCRYPTO_KEY1_INIT);
        assert_eq!(keys.key2, ZIPCRYPTO_KEY2_INIT);
    }

    #[test]
    fn test_zipcrypto_password_derivation_deterministic() {
        let keys1 = ZipCryptoKeys::from_password(b"TTZipSecretPassword2026");
        let keys2 = ZipCryptoKeys::from_password(b"TTZipSecretPassword2026");
        assert_eq!(keys1.key0, keys2.key0);
        assert_eq!(keys1.key1, keys2.key1);
        assert_eq!(keys1.key2, keys2.key2);
    }

    #[test]
    fn test_zipcrypto_encrypt_decrypt_roundtrip() {
        let password = b"P@ssw0rd!#123";
        let original = b"Hello world! This is a high-performance TTZip ZipCrypto test payload.";

        let mut encrypted = original.to_vec();
        zipcrypto_encrypt_slice(password, &mut encrypted);

        // Encrypted buffer must differ from plaintext
        assert_ne!(&encrypted[..], &original[..]);

        let mut decrypted = encrypted.clone();
        zipcrypto_decrypt_slice(password, &mut decrypted);

        assert_eq!(&decrypted[..], &original[..]);
    }

    #[test]
    fn test_zipcrypto_stream_copy_roundtrip() {
        let password = b"StreamPassword";
        let original = vec![0xABu8; 4096];
        let mut encrypted = vec![0u8; 4096];
        let mut decrypted = vec![0u8; 4096];

        let mut enc_keys = ZipCryptoKeys::from_password(password);
        enc_keys.encrypt_copy(&original, &mut encrypted);
        assert_ne!(encrypted, original);

        let mut dec_keys = ZipCryptoKeys::from_password(password);
        dec_keys.decrypt_copy(&encrypted, &mut decrypted);
        assert_eq!(decrypted, original);
    }

    #[test]
    fn test_zipcrypto_batch4_matches_scalar() {
        let passwords = [
            b"pass1".as_slice(),
            b"pass2".as_slice(),
            b"pass3".as_slice(),
            b"pass4".as_slice(),
        ];
        let mut batch = ZipCryptoBatch4::from_passwords(passwords);
        let mut scalar_keys = [
            ZipCryptoKeys::from_password(passwords[0]),
            ZipCryptoKeys::from_password(passwords[1]),
            ZipCryptoKeys::from_password(passwords[2]),
            ZipCryptoKeys::from_password(passwords[3]),
        ];

        for lane in 0..4 {
            assert_eq!(batch.key0[lane], scalar_keys[lane].key0);
            assert_eq!(batch.key1[lane], scalar_keys[lane].key1);
            assert_eq!(batch.key2[lane], scalar_keys[lane].key2);
        }

        let test_plain = [0x11, 0x22, 0x33, 0x44];
        let cipher_batch = batch.encrypt_bytes_4way(test_plain);

        for lane in 0..4 {
            let cipher_scalar = scalar_keys[lane].encrypt_byte(test_plain[lane]);
            assert_eq!(cipher_batch[lane], cipher_scalar);
        }

        let mut dec_batch = ZipCryptoBatch4::from_passwords(passwords);
        let plain_recovered = dec_batch.decrypt_bytes_4way(cipher_batch);
        assert_eq!(plain_recovered, test_plain);
    }
}
