//! # Bağımsız Kanıt Formatı (`proof.json`)
//!
//! Cleanvest'in "sıfır manipülasyon" iddiasının **doğrulanabilir** kısmı.
//! Bir kullanıcı, batch'le ilgili kanıtı alır ve **operatöre güvenmeden**
//! üç şeyi bağımsız olarak doğrular:
//!
//! 1. **Yaprak yeniden hesaplanır** — `leaf = keccak256(abi.encode(amount, user, nonce))`
//!    JSON'daki emir alanlarından baştan üretilir; operatörün "bu yaprak"
//!    demesine gerek yoktur.
//! 2. **İmza doğrulanır** — EIP-191 `recover_signer(leaf, sig) == user`.
//!    Operatör yaprağı dolduramaz; yalnızca imzalayan kullanıcıya ait
//!    yapraklar kabul edilir.
//! 3. **Merkle inclusion doğrulanır** — `verify(leaf, proof, root)`.
//!    Yaprak, iddia edilen kökün içinde olmalıdır.
//!
//! Bu üçü birleştiğinde: **kullanıcı imzası → yaprak → kök** zinciri
//! tamamen bağımsız olarak yeniden hesaplanabilir. Kök zincir-üstü
//! `orderCommitmentRoot` ile karşılaştırıldığında (örn. `cast call`),
//! uyuşmazlık kanıtlanmış manipülasyondur.
//!
//! ## Kanıt formatı
//!
//! ```json
//! {
//!   "order": { "amount": "1000", "user": "0xf39F...2266", "nonce": "1" },
//!   "signature": "0x<65 bayt>",
//!   "root": "0x<32 bayt>",
//!   "proofBytes": "0x<33 bayt/seviye>",
//!   "chainId": 31337,
//!   "batchId": "0x...",
//!   "settlement": "0x..."
//! }
//! ```
//!
//! `proofBytes`, zincir-üstü `CleanvestSettlement.verifyMerkleProof`'a
//! **aynı** bayt dizisi olarak verilebilir: her seviye 32 bayt kardeş +
//! 1 bayt konum (düşük bit: 1 = kardeş sağda, 0 = solda).
//!
//! ## Güvenlik notları (dürüst sınırlar)
//!
//! - Bu doğrulama **emrin imzalandığını ve kökte bulunduğunu** kanıtlar.
//!   Emrin **yerine getirildiğini** kanıtlamaz.
//! - Kök, zincir-üstü `orderCommitmentRoot` ile karşılaştırılmalıdır.
//!   JSON'daki `root` yalnızca operatörün iddiasıdır; **kanıtı**
//!   zincirden okumak gerekir (bkz. `verify_cli --rpc`).

use serde::{Deserialize, Serialize};

use crate::signed::recover_signer;
use crate::{keccak256, Address, Order, Proof};

/// Doğrulanacak emir. Alanlar JSON'da **dizgi** olarak gelir (büyük sayılar
/// için güvenli); `amount`/`nonce` isteğe bağlı olarak sayı da olabilir.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct OrderJson {
    /// 6 ondalıklı USDC temel birim (uint256). **Dizgi olarak** saklanır
    /// (büyük sayıların JS/JSON'da hassasiyet kaybını önler); sayı da kabul
    /// edilir.
    #[serde(with = "u128_string")]
    pub amount: u128,
    /// 20 bayt EVM adresi, "0x" önekli hex dizgisi.
    #[serde(with = "address_hex")]
    pub user: Address,
    /// Tek-seferlik sayı (front-run koruması). Dizgi olarak saklanır.
    #[serde(with = "u128_string")]
    pub nonce: u128,
}

/// Bağımsız doğrulanabilir kanıt.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProofJson {
    /// Emir — yaprak bunun üzerinden **yeniden hesaplanır**.
    pub order: OrderJson,
    /// EIP-191 imzası: r(32) + s(32) + v(1); v: 27 veya 28.
    #[serde(with = "bytes65_hex")]
    pub signature: [u8; 65],
    /// İddia edilen Merkle kökü. **Kökü zincirden okumak güvenli olur.**
    #[serde(with = "bytes32_hex")]
    pub root: [u8; 32],
    /// Merkle sibling kanıtı — zincir-üstü `verifyMerkleProof` ile aynı bayt.
    /// Her 33 bayt: sibling(32) + konum(1).
    #[serde(with = "bytes_hex")]
    pub proof_bytes: Vec<u8>,
    /// (Opsiyonel) Zincir kimliği — kanıtın hangi ağa ait olduğu.
    pub chain_id: Option<u64>,
    /// (Opsiyonel) Batch tanımlayıcısı.
    pub batch_id: Option<String>,
    /// (Opsiyonel) Settlement kontrat adresi — zincirden kökü okumak için.
    pub settlement: Option<String>,
}

/// Doğrulama sonucu — hangi adımın geçtiğini/kaldığını açıkça belirtir.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProofResult {
    /// Her şey geçti: imza + Merkle inclusion.
    Valid {
        /// Yeniden hesaplanan yaprak hash (zincirle karşılaştırmak için).
        leaf: [u8; 32],
        /// EIP-191 özeti (imza bunun üzerinedir).
        digest: [u8; 32],
    },
    /// İmza geçersiz (yanlış imza veya yanlış imzalayan).
    InvalidSignature { recovered: Option<Address> },
    /// İmza geçerli ama yaprak kökte değil.
    MerkleInclusionFailed,
    /// Kanıt biçimsiz (hatalı uzunluk, bozuk hex, ...).
    Malformed(String),
}

impl ProofJson {
    /// **Tam kanıt zincirini** bağımsız olarak doğrular.
    ///
    /// 1. Yaprak hash'i emir alanlarından **yeniden hesaplanır**
    ///    (`keccak256(abi.encode(amount, user, nonce))`).
    /// 2. EIP-191 imzası doğrulanır: `recover_signer(leaf, sig) == order.user`.
    /// 3. `proof_bytes`, kardeş listesine ayrılır ve köre karşı doğrulanır.
    ///
    /// Bu fonksiyon **ağ bağlantısı gerektirmez** — yalnızca kriptografi.
    pub fn verify(&self) -> ProofResult {
        // 1. Yaprak yeniden hesapla (operatöre güvenme)
        let order = Order::new(self.order.amount, self.order.user, self.order.nonce);
        let leaf = order.leaf_hash();

        // 2. İmza doğrula (ağaçtan bağımsız)
        let recovered = recover_signer(&leaf, &self.signature);
        match recovered {
            Some(addr) if addr == self.order.user => {}
            _ => {
                return ProofResult::InvalidSignature { recovered };
            }
        };

        // 3. proof_bytes -> Proof { siblings, is_right }
        let proof = match parse_proof_bytes(&self.proof_bytes) {
            Some(p) => p,
            None => return ProofResult::Malformed("proofBytes uzunlugu 33'in kati olmali".into()),
        };

        // 4. Merkle inclusion
        if !crate::verify(&leaf, &proof, &self.root) {
            return ProofResult::MerkleInclusionFailed;
        }

        // digest'i raporlamak için yeniden hesapla (recover_signer zaten hesapladı)
        let mut buf = [0u8; 28 + 32];
        buf[..28].copy_from_slice(b"\x19Ethereum Signed Message:\n32");
        buf[28..].copy_from_slice(&leaf);
        let digest = keccak256(&buf);

        ProofResult::Valid { leaf, digest }
    }

    /// proof.json dizgisini ayrıştır.
    pub fn from_str(s: &str) -> Result<Self, String> {
        serde_json::from_str(s).map_err(|e| format!("JSON ayristirma hatasi: {e}"))
    }

    /// Kanıtı JSON olarak üret (prove_cli için).
    pub fn to_string_pretty(&self) -> Result<String, String> {
        serde_json::to_string_pretty(self).map_err(|e| format!("JSON yazma hatasi: {e}"))
    }
}

/// `proof_bytes`'ı kardeş listesine çevirir. Her 33 bayt:
/// sibling(32) + konum(1, düşük bit: 1 = sağda).
///
/// **Boş kanıt geçerlidir** — tek yapraklı ağaçta seviye yoktur ve
/// doğrulama `leaf == root` kontrolüne indirgenir.
pub fn parse_proof_bytes(bytes: &[u8]) -> Option<Proof> {
    if bytes.is_empty() {
        // Tek yaprak: sibling yok, leaf dogrudan kokle karsilastirilir.
        return Some(Proof { siblings: Vec::new() });
    }
    if bytes.len() % 33 != 0 {
        return None;
    }
    let mut siblings = Vec::with_capacity(bytes.len() / 33);
    for chunk in bytes.chunks_exact(33) {
        let mut sibling = [0u8; 32];
        sibling.copy_from_slice(&chunk[..32]);
        let is_right = (chunk[32] & 0x01) == 0x01;
        siblings.push((sibling, is_right));
    }
    Some(Proof { siblings })
}

/// Kardeş listesini `proof_bytes`'a çevirir (on-chain format ile birebir).
pub fn encode_proof_bytes(proof: &Proof) -> Vec<u8> {
    let mut out = Vec::with_capacity(proof.siblings.len() * 33);
    for (sibling, is_right) in &proof.siblings {
        out.extend_from_slice(sibling);
        out.push(if *is_right { 0x01 } else { 0x00 });
    }
    out
}

// ============================================================
// Serde yardımcıları
// ============================================================

pub fn deserialize_u128_loose<'de, D>(deserializer: D) -> Result<u128, D::Error>
where
    D: serde::Deserializer<'de>,
{
    use serde::de::Error;
    #[derive(Deserialize)]
    #[serde(untagged)]
    enum NumOrStr {
        Str(String),
        Num(u128),
    }
    match NumOrStr::deserialize(deserializer)? {
        NumOrStr::Num(n) => Ok(n),
        NumOrStr::Str(s) => {
            let s = s.trim();
            let s = s.strip_prefix("0x").unwrap_or(s);
            u128::from_str_radix(s, 10).map_err(|_| {
                Error::custom(format!("sayi ayristirilamadi (onluk bekleniyor): {s}"))
            })
        }
    }
}

/// amount/nonce: **dizgi olarak** serialize eder (büyük sayı güvenliği),
/// dizgi VEYA sayı olarak deserialize eder.
mod u128_string {
    use super::*;
    use serde::{Deserializer, Serializer};

    pub fn serialize<S: Serializer>(n: &u128, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&n.to_string())
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<u128, D::Error> {
        super::deserialize_u128_loose(d)
    }
}

mod address_hex {
    use super::*;
    use serde::{Deserializer, Serializer};

    pub fn serialize<S: Serializer>(a: &Address, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&format!("0x{}", hex::encode(a)))
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<Address, D::Error> {
        let s = String::deserialize(d)?;
        parse_address(&s).map_err(serde::de::Error::custom)
    }
}

/// "0x..." önekli 20 bayt adresi ayrıştır.
pub fn parse_address(s: &str) -> Result<Address, String> {
    let s = s.strip_prefix("0x").unwrap_or(s);
    let bytes = hex::decode(s).map_err(|e| format!("adres hex hatasi: {e}"))?;
    if bytes.len() != 20 {
        return Err(format!("adres 20 bayt olmali, {} bayt", bytes.len()));
    }
    let mut a = [0u8; 20];
    a.copy_from_slice(&bytes);
    Ok(a)
}

mod bytes65_hex {
    use super::*;
    use serde::{Deserializer, Serializer};

    pub fn serialize<S: Serializer>(b: &[u8; 65], s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&format!("0x{}", hex::encode(b)))
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<[u8; 65], D::Error> {
        let s = String::deserialize(d)?;
        parse_fixed_bytes::<65>(&s).map_err(serde::de::Error::custom)
    }
}

mod bytes32_hex {
    use super::*;
    use serde::{Deserializer, Serializer};

    pub fn serialize<S: Serializer>(b: &[u8; 32], s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&format!("0x{}", hex::encode(b)))
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<[u8; 32], D::Error> {
        let s = String::deserialize(d)?;
        parse_fixed_bytes::<32>(&s).map_err(serde::de::Error::custom)
    }
}

mod bytes_hex {
    use super::*;
    use serde::{Deserializer, Serializer};

    pub fn serialize<S: Serializer>(b: &[u8], s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&format!("0x{}", hex::encode(b)))
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<Vec<u8>, D::Error> {
        let s = String::deserialize(d)?;
        let s = s.strip_prefix("0x").unwrap_or(&s);
        hex::decode(s).map_err(|e| serde::de::Error::custom(format!("hex hatasi: {e}")))
    }
}

/// "0x..." önekli sabit uzunluklu bayt dizisini ayrıştır.
pub fn parse_fixed_bytes<const N: usize>(s: &str) -> Result<[u8; N], String> {
    let s = s.strip_prefix("0x").unwrap_or(s);
    let bytes = hex::decode(s).map_err(|e| format!("hex hatasi: {e}"))?;
    if bytes.len() != N {
        return Err(format!("{N} bayt bekleniyor, {} bayt", bytes.len()));
    }
    let mut out = [0u8; N];
    out.copy_from_slice(&bytes);
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::signed::{
        eth_signed_message_hash, SignedLeaf, SignedMerkleTree, SignedProof,
    };
    use crate::verify;
    use k256::ecdsa::SigningKey;

    /// Standart anvil test anahtarı (account #0). MAINNET anahtarı DEĞİL.
    const ANVIL_KEY: [u8; 32] = [
        0xac, 0x09, 0x74, 0xbe, 0xc3, 0x9a, 0x17, 0xe3,
        0x6b, 0xa4, 0xa6, 0xb4, 0xd2, 0x38, 0xff, 0x94,
        0x4b, 0xac, 0xb4, 0x78, 0xcb, 0xed, 0x5e, 0xfc,
        0xae, 0x78, 0x4d, 0x7b, 0xf4, 0xf2, 0xff, 0x80,
    ];
    const ANVIL_ADDR: Address = [
        0xf3, 0x9F, 0xd6, 0xe5, 0x1a, 0xad, 0x88, 0xF6,
        0xF4, 0xce, 0x6a, 0xB8, 0x82, 0x72, 0x79, 0xcf,
        0xFF, 0xb9, 0x22, 0x66,
    ];

    fn sign_with_test_key(leaf: &[u8; 32], key_bytes: &[u8; 32]) -> [u8; 65] {
        let digest = eth_signed_message_hash(leaf);
        let signing_key = SigningKey::from_slice(key_bytes).unwrap();
        let (sig, recid) = signing_key.sign_prehash_recoverable(&digest);
        let mut out = [0u8; 65];
        let sb = sig.to_bytes();
        out[..32].copy_from_slice(&sb[..32]);
        out[32..64].copy_from_slice(&sb[32..]);
        out[64] = 27 + u8::try_from(recid).unwrap_or(0);
        out
    }

    /// **Tam JSON gidiş-dönüş testi:** kanıt üret → serialize → parse →
    /// bağımsız doğrula. Bu, "herkes tarafından yeniden hesaplanabilir"
    /// iddiasının otomatik kanıtıdır.
    #[test]
    fn proof_json_roundtrip_verifies() {
        let orders = vec![
            Order::new(1_000, ANVIL_ADDR, 1),
            Order::new(2_000, ANVIL_ADDR, 2),
            Order::new(3_000, ANVIL_ADDR, 3),
        ];
        let leaves: Vec<SignedLeaf> = orders
            .iter()
            .map(|o| {
                let sig = sign_with_test_key(&o.leaf_hash(), &ANVIL_KEY);
                SignedLeaf::new(o.clone(), sig)
            })
            .collect();

        let tree = SignedMerkleTree::build_signed(&leaves).unwrap();
        let signed_proof: SignedProof = tree.prove_signed(1).unwrap();

        // proof_bytes üret (on-chain format ile birebir)
        let proof_bytes = encode_proof_bytes(&signed_proof.merkle);

        let pj = ProofJson {
            order: OrderJson {
                amount: 2_000,
                user: ANVIL_ADDR,
                nonce: 2,
            },
            signature: signed_proof.signature,
            root: tree.root(),
            proof_bytes,
            chain_id: Some(31337),
            batch_id: Some("batch-test".into()),
            settlement: None,
        };

        // Serialize → parse → doğrula
        let json = pj.to_string_pretty().unwrap();
        let parsed = ProofJson::from_str(&json).unwrap();
        assert_eq!(parsed, pj, "JSON gidiş-dönüş bozulmamali");

        let result = parsed.verify();
        match &result {
            ProofResult::Valid { leaf, .. } => {
                assert_eq!(leaf, &orders[1].leaf_hash(), "yaprak yeniden hesaplandi");
            }
            r => panic!("kanit gecerli olmali: {r:?}"),
        }
    }

    /// Yanlış imza → reddedilmeli.
    #[test]
    fn proof_json_bad_signature_rejected() {
        let order = Order::new(1_000, ANVIL_ADDR, 1);
        let mut sig = sign_with_test_key(&order.leaf_hash(), &ANVIL_KEY);
        sig[5] ^= 0xff; // imzayı boz

        let pj = ProofJson {
            order: OrderJson { amount: 1_000, user: ANVIL_ADDR, nonce: 1 },
            signature: sig,
            root: [0u8; 32], // kök önemsiz — imza adımında reddedilir
            proof_bytes: vec![],
            chain_id: None,
            batch_id: None,
            settlement: None,
        };
        assert!(matches!(pj.verify(), ProofResult::InvalidSignature { .. }));
    }

    /// İmza geçerli, kök yanlış → Merkle reddedilmeli.
    #[test]
    fn proof_json_bad_root_rejected() {
        let order = Order::new(1_000, ANVIL_ADDR, 1);
        let sig = sign_with_test_key(&order.leaf_hash(), &ANVIL_KEY);
        let tree =
            SignedMerkleTree::build_signed(&[SignedLeaf::new(order.clone(), sig)]).unwrap();

        let pj = ProofJson {
            order: OrderJson { amount: 1_000, user: ANVIL_ADDR, nonce: 1 },
            signature: sig,
            root: {
                let mut r = tree.root();
                r[0] ^= 0xff;
                r
            },
            proof_bytes: encode_proof_bytes(&tree.prove_signed(0).unwrap().merkle),
            chain_id: None,
            batch_id: None,
            settlement: None,
        };
        assert_eq!(pj.verify(), ProofResult::MerkleInclusionFailed);
    }

    /// proof_bytes uzunluğu bozuksa Malformed dönmeli.
    #[test]
    fn proof_json_malformed_length() {
        let order = Order::new(1_000, ANVIL_ADDR, 1);
        let sig = sign_with_test_key(&order.leaf_hash(), &ANVIL_KEY);
        let pj = ProofJson {
            order: OrderJson { amount: 1_000, user: ANVIL_ADDR, nonce: 1 },
            signature: sig,
            root: [0u8; 32],
            proof_bytes: vec![0u8; 20], // 33'in katı değil
            chain_id: None,
            batch_id: None,
            settlement: None,
        };
        assert!(matches!(pj.verify(), ProofResult::Malformed(_)));
    }

    /// amount dizgi olarak gelmeli (büyük sayılar için).
    #[test]
    fn amount_as_string_parses() {
        let json = r#"{"amount":"1000","user":"0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266","nonce":"7"}"#;
        let o: OrderJson = serde_json::from_str(json).unwrap();
        assert_eq!(o.amount, 1000);
        assert_eq!(o.nonce, 7);
        assert_eq!(o.user, ANVIL_ADDR);
    }

    // ============================================================
    // JSON MANIPULASYONU — operator'in kaniti degistirmesi
    // (GOREV: "manipulasyon tespiti" — bagimsiz dogrulama katmani)
    // ============================================================

    /// Manipulasyon: operator JSON'daki MIKTARI degistirirse
    /// yaprak yeniden hesaplanir → imza yaprakla uyusmaz → InvalidSignature.
    /// Bu DAHA GUZELDIR: Merkle adimina ulasmadan reddeder (fail-early).
    #[test]
    fn json_tampered_amount_detected() {
        let order = Order::new(1_000, ANVIL_ADDR, 1);
        let sig = sign_with_test_key(&order.leaf_hash(), &ANVIL_KEY);
        let tree =
            SignedMerkleTree::build_signed(&[SignedLeaf::new(order, sig)]).unwrap();
        let real_root = tree.root();
        let proof_bytes = encode_proof_bytes(&tree.prove_signed(0).unwrap().merkle);

        // Operator JSON'da 1_000 → 9_000 yazar
        let tampered = ProofJson {
            order: OrderJson { amount: 9_000, user: ANVIL_ADDR, nonce: 1 },
            signature: sign_with_test_key(&Order::new(1_000, ANVIL_ADDR, 1).leaf_hash(), &ANVIL_KEY),
            root: real_root,
            proof_bytes,
            chain_id: None,
            batch_id: None,
            settlement: None,
        };
        // Imza gercek emre ait (1_000); JSON 9_000 → yaprak degisir →
        // imza yaprakla uyusmaz → InvalidSignature (Merkle'den ONCE reddet)
        assert!(matches!(tampered.verify(), ProofResult::InvalidSignature { .. }));
    }

    /// Manipulasyon: operator JSON'daki ADRESI degistirirse
    /// imza adresi uyusmaz → InvalidSignature.
    #[test]
    fn json_tampered_user_detected() {
        let order = Order::new(1_000, ANVIL_ADDR, 1);
        let sig = sign_with_test_key(&order.leaf_hash(), &ANVIL_KEY);

        let mut other = [0u8; 20];
        other[19] = 0x42;
        let tampered = ProofJson {
            order: OrderJson { amount: 1_000, user: other, nonce: 1 },
            signature: sig,
            root: [0u8; 32],
            proof_bytes: vec![],
            chain_id: None,
            batch_id: None,
            settlement: None,
        };
        assert!(matches!(tampered.verify(), ProofResult::InvalidSignature { .. }));
    }

    /// Manipulasyon: operator NONCE degistirirse
    /// yaprak degisir → imza uyusmaz → InvalidSignature (fail-early).
    #[test]
    fn json_tampered_nonce_detected() {
        let order = Order::new(1_000, ANVIL_ADDR, 5);
        let sig = sign_with_test_key(&order.leaf_hash(), &ANVIL_KEY);
        let tree =
            SignedMerkleTree::build_signed(&[SignedLeaf::new(order, sig)]).unwrap();

        let tampered = ProofJson {
            order: OrderJson { amount: 1_000, user: ANVIL_ADDR, nonce: 99 },
            signature: sign_with_test_key(&Order::new(1_000, ANVIL_ADDR, 5).leaf_hash(), &ANVIL_KEY),
            root: tree.root(),
            proof_bytes: vec![], // tek yaprak: bos kanit gecerli
            chain_id: None,
            batch_id: None,
            settlement: None,
        };
        // Imza nonce=5 emrine ait; JSON nonce=99 → farkli yaprak →
        // imza uyusmaz (Merkle'den ONCE reddet)
        assert!(matches!(tampered.verify(), ProofResult::InvalidSignature { .. }));
    }

    /// Invariant: encode → parse roundtrip proof'u korumali
    /// (on-chain format ile birebiligidin kaniti).
    #[test]
    fn proof_bytes_encode_parse_roundtrip() {
        let orders: Vec<Order> = (0..5)
            .map(|i| Order::new(500 * (i + 1) as u128, ANVIL_ADDR, i as u128))
            .collect();
        let leaves: Vec<SignedLeaf> = orders
            .iter()
            .map(|o| SignedLeaf::new(o.clone(), sign_with_test_key(&o.leaf_hash(), &ANVIL_KEY)))
            .collect();
        let tree = SignedMerkleTree::build_signed(&leaves).unwrap();

        for i in 0..orders.len() {
            let proof = tree.prove_signed(i).unwrap().merkle;
            let bytes = encode_proof_bytes(&proof);
            let parsed = parse_proof_bytes(&bytes).unwrap();
            assert_eq!(parsed.siblings.len(), proof.siblings.len());
            for (a, b) in parsed.siblings.iter().zip(&proof.siblings) {
                assert_eq!(a.0, b.0, "sibling hash {i} korunmali");
                assert_eq!(a.1, b.1, "sibling konumu {i} korunmali");
            }
            // Roundtrip kaniti hala dogrulamali
            assert!(verify(&orders[i].leaf_hash(), &parsed, &tree.root()));
        }
    }

    /// Sinir: tek yaprakli agac — BOS proof_bytes gecerli
    /// (leaf dogrudan root'a esit).
    #[test]
    fn single_leaf_empty_proof_bytes_valid() {
        let order = Order::new(1_000, ANVIL_ADDR, 1);
        let sig = sign_with_test_key(&order.leaf_hash(), &ANVIL_KEY);
        let tree =
            SignedMerkleTree::build_signed(&[SignedLeaf::new(order, sig)]).unwrap();

        let pj = ProofJson {
            order: OrderJson { amount: 1_000, user: ANVIL_ADDR, nonce: 1 },
            signature: sign_with_test_key(&Order::new(1_000, ANVIL_ADDR, 1).leaf_hash(), &ANVIL_KEY),
            root: tree.root(),
            proof_bytes: vec![], // bos = tek yaprak
            chain_id: None,
            batch_id: None,
            settlement: None,
        };
        assert!(matches!(pj.verify(), ProofResult::Valid { .. }));
    }

    /// Manipulasyon: proof_bytes icinde konum biti cevrilirse reddet
    /// (sibling sirasinin onemi — on-chain ile birebir).
    #[test]
    fn proof_bytes_flipped_position_rejected() {
        let orders = vec![
            Order::new(1_000, ANVIL_ADDR, 1),
            Order::new(2_000, ANVIL_ADDR, 2),
        ];
        let leaves: Vec<SignedLeaf> = orders
            .iter()
            .map(|o| SignedLeaf::new(o.clone(), sign_with_test_key(&o.leaf_hash(), &ANVIL_KEY)))
            .collect();
        let tree = SignedMerkleTree::build_signed(&leaves).unwrap();
        let proof = tree.prove_signed(0).unwrap().merkle;
        let mut bytes = encode_proof_bytes(&proof);
        bytes[32] ^= 0x01; // konum bitini cevir

        let ok = verify(&orders[0].leaf_hash(), &parse_proof_bytes(&bytes).unwrap(), &tree.root());
        assert!(!ok, "cevrilmis konum REDDEDILMELI");
    }

    /// Buyuk degerler: u128::MAX dizgisi kayipsiz ayristirilmali
    /// (JSON sayi hassasiyet kaybini onler).
    #[test]
    fn u128_max_as_string_roundtrips() {
        let json = format!(
            r#"{{"amount":"{}","user":"0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266","nonce":"{}"}}"#,
            u128::MAX, u64::MAX
        );
        let o: OrderJson = serde_json::from_str(&json).unwrap();
        assert_eq!(o.amount, u128::MAX);
        assert_eq!(o.nonce, u64::MAX as u128);
    }

    /// Parse hatasi: gecersiz hex adres reddedilmeli (Malformed degil,
    /// serde hatasi — guvenli reddir).
    #[test]
    fn invalid_hex_address_rejected() {
        let json = r#"{"amount":"1","user":"0xZZZZ","nonce":"1"}"#;
        assert!(serde_json::from_str::<OrderJson>(json).is_err());
    }
}
