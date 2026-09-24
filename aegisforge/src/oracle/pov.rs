//! PoV Hash Taahhüdü — Deterministik kriptografik kanıt.
//!
//! KRİTİK: Bu bir ZK-SNARK DEĞİLDİR. Master şartname v1.2'nin açık kuralı:
//! "ZK-SNARK ifadesi YASAK — PoV_Hash deterministik bir Hash Taahhüdüdür."
//!
//! PoV_Hash = SHA256(ExploitPayload || ContractBytecode || Timestamp)
//!
//! Satır numarası ve istismar yükü ücret ödenene kadar kilitli tutulur.

use sha2::{Digest, Sha256};

/// Deterministik PoV hash taahhüdü üretir.
///
/// # Arguments
/// * `exploit_payload` - Açığı tetikleyen istismar işlem izi
/// * `contract_bytecode` - Hedef sözleşmenin bytecode'u
/// * `timestamp` - Unix zaman damgası
pub fn seal_pov_hash(
    exploit_payload: &[u8],
    contract_bytecode: &[u8],
    timestamp: u64,
) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(exploit_payload);
    hasher.update(contract_bytecode);
    hasher.update(timestamp.to_le_bytes());
    let result = hasher.finalize();
    let mut out = [0u8; 32];
    out.copy_from_slice(&result);
    out
}

/// PoV hash'ini hex formatında döndürür (zincirde mühürleme için).
pub fn pov_hash_hex(pov: &[u8; 32]) -> String {
    hex::encode(pov)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pov_hash_deterministic() {
        let payload = b"exploit_call_data";
        let bytecode = b"0x6080604052";
        let ts = 1774438800u64;

        let h1 = seal_pov_hash(payload, bytecode, ts);
        let h2 = seal_pov_hash(payload, bytecode, ts);
        assert_eq!(h1, h2, "PoV hash deterministik olmalı");
    }

    #[test]
    fn pov_hash_farkli_payload_farkli_hash() {
        let bytecode = b"0x6080604052";
        let ts = 1774438800u64;

        let h1 = seal_pov_hash(b"payload_a", bytecode, ts);
        let h2 = seal_pov_hash(b"payload_b", bytecode, ts);
        assert_ne!(h1, h2, "Farklı payload → farklı hash");
    }

    #[test]
    fn pov_hash_farkli_timestamp_farkli_hash() {
        let payload = b"exploit";
        let bytecode = b"0x6080604052";

        let h1 = seal_pov_hash(payload, bytecode, 1000);
        let h2 = seal_pov_hash(payload, bytecode, 2000);
        assert_ne!(h1, h2, "Farklı timestamp → farklı hash (mühür)");
    }

    #[test]
    fn pov_hex_formati() {
        let pov = [0u8; 32];
        let hex_str = pov_hash_hex(&pov);
        assert_eq!(hex_str.len(), 64);
        assert!(hex_str.chars().all(|c| c.is_ascii_hexdigit()));
    }
}
