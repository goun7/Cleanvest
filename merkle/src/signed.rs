//! # İmzalı Yapraklar (Signed Leaves) — EIP-191 personal_sign
//!
//! Güvenlik açığının **tam kapanması**: kök artık yalnızca ağaç yapısını
//! doğrulamaz; her yaprağın **kullanıcı tarafından imzalandığını** da
//! doğrular. Böylece kök üreticisi "bu kullanıcı emri" diyerek rastgele
//! yaprak dolduramaz.
//!
//! ## Şema
//!
//! 1. Yaprak hash: `leaf = keccak256(abi.encode(amount, user, nonce))`
//!    (ağaçtan bağımsız hesaplanır)
//! 2. İmza özeti: `digest = keccak256("\x19Ethereum Signed Message:\n32" || leaf)`
//!    — bu, EIP-191 personal_sign standardıdır; cüzdanlar `signMessage`
//!    ile bu özeti üretir
//! 3. Kullanıcı `digest`'i imzalar → 65 bayt (r 32 + s 32 + v 1)
//! 4. Doğrulama: `ecrecover(digest, v, r, s) == user`
//!
//! ## Solidity ile birebir
//!
//! `CleanvestSettlement.verifyLeafSignature`:
//! ```solidity
//! ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", leaf)), v, r, s) == signer
//! ```
//!
//! Rust tarafı aynı `keccak256` (tiny-keccak, EVM ile birebir) ve aynı
//! recovery (k256, secp256k1) kullanır — cross-check testleri ile
//! kanıtlanmıştır.

use k256::ecdsa::{RecoveryId, Signature, VerifyingKey};
use k256::elliptic_curve::sec1::ToEncodedPoint;

use crate::{keccak256, Address, Order};

/// EIP-191 imza özeti: `keccak256("\x19Ethereum Signed Message:\n32" || hash)`.
///
/// Solidity `toEthSignedMessageHash` ile birebir aynı çıktı.
pub fn eth_signed_message_hash(hash: &[u8; 32]) -> [u8; 32] {
    let mut buf = [0u8; 28 + 32];
    buf[..28].copy_from_slice(b"\x19Ethereum Signed Message:\n32");
    buf[28..].copy_from_slice(hash);
    keccak256(&buf)
}

/// 65 bayt imzayı (r, s, v) ayrıştırır.
///
/// `v` EIP-191 standardında 27 veya 28'dir; k256 0/1 bekler.
pub fn split_signature(sig: &[u8; 65]) -> ([u8; 32], [u8; 32], u8) {
    let mut r = [0u8; 32];
    let mut s = [0u8; 32];
    r.copy_from_slice(&sig[..32]);
    s.copy_from_slice(&sig[32..64]);
    let v = sig[64];
    (r, s, v)
}

/// k256 recovery için v değerini 27/28 → 0/1'e çevirir.
fn recovery_id_from_v(v: u8) -> Option<RecoveryId> {
    let recid_byte = if v >= 27 { v - 27 } else { v };
    if recid_byte > 1 {
        return None;
    }
    RecoveryId::try_from(recid_byte).ok()
}

/// İmzadan imzalayan adresi geri kazanır (ecrecover).
///
/// `leaf` parametresi **ağaçtan bağımsızdır** — yalnızca yaprak hash'ine
/// imza doğrulanır. Bu, "kullanıcı imzası" ile "ağaç yapısı" doğrulamasını
/// birbirinden ayırır (açığın tam kapanması için gereklidir).
///
/// Solidity `recoverSigner` ile birebir aynı hesap.
pub fn recover_signer(leaf: &[u8; 32], sig: &[u8; 65]) -> Option<Address> {
    let (r, s, v) = split_signature(sig);
    let recid = recovery_id_from_v(v)?;

    let signature = Signature::from_slice(&<[u8; 64]>::try_from({
        let mut combined = [0u8; 64];
        combined[..32].copy_from_slice(&r);
        combined[32..].copy_from_slice(&s);
        combined
    }).ok()?).ok()?;

    // EIP-191 digest (personal_sign) — birebir Solidity toEthSignedMessageHash
    let digest = eth_signed_message_hash(leaf);

    // k256 recovery — prehash byte'larini dogrudan ver (Digest trait gerekmez)
    let vk = VerifyingKey::recover_from_prehash(&digest, &signature, recid).ok()?;

    // Adres = keccak256(pubkey_x || pubkey_y)[12..]
    // to_encoded_point(false) = sıkıştırılmamış: 0x04 || x(32) || y(32)
    let encoded = vk.to_sec1_point(false);
    let bytes = encoded.as_bytes();
    if bytes.len() != 65 || bytes[0] != 0x04 {
        return None;
    }
    let hashed = keccak256(&bytes[1..]);
    let mut addr = [0u8; 20];
    addr.copy_from_slice(&hashed[12..]);
    Some(addr)
}

/// İmzalı yaprak: emir + 65 bayt imza.
#[derive(Debug, Clone)]
pub struct SignedLeaf {
    pub order: Order,
    /// r(32) + s(32) + v(1). v: 27 veya 28 (EIP-191).
    pub signature: [u8; 65],
}

impl SignedLeaf {
    pub fn new(order: Order, signature: [u8; 65]) -> Self {
        Self { order, signature }
    }

    /// Yaprak hash'i (imzadan bağımsız): `keccak256(abi.encode(amount, user, nonce))`.
    pub fn leaf_hash(&self) -> [u8; 32] {
        self.order.leaf_hash()
    }

    /// İmzayı doğrular: `recover_signer(leaf, sig) == user`.
    pub fn verify_signature(&self) -> bool {
        match recover_signer(&self.leaf_hash(), &self.signature) {
            Some(recovered) => recovered == self.order.user,
            None => false,
        }
    }
}

/// İmzalı Merkle ağacı. Önce tüm imzalar doğrulanır, sonra ağaç kurulur.
#[derive(Debug, Clone)]
pub struct SignedMerkleTree {
    tree: crate::MerkleTree,
    leaves: Vec<SignedLeaf>,
}

/// İmzalı kanıt: Merkle sibling path + yaprak imzası.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SignedProof {
    pub merkle: crate::Proof,
    pub signature: [u8; 65],
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SignedBuildError {
    /// Boş ağaç.
    Empty,
    /// `index`'teki yaprağın imzası geçersiz (yanlış imza veya yanlış imzalayan).
    InvalidSignature(usize),
}

impl SignedMerkleTree {
    /// İmzalı yapraklardan ağaç kurar. **Önce her imza doğrulanır** —
    /// tek bir geçersiz imza tüm kurulumu reddeder (fail-closed).
    pub fn build_signed(leaves: &[SignedLeaf]) -> Result<Self, SignedBuildError> {
        if leaves.is_empty() {
            return Err(SignedBuildError::Empty);
        }
        // Ağaçtan BAĞIMSIZ imza doğrulama (açığın tam kapanması)
        for (i, leaf) in leaves.iter().enumerate() {
            if !leaf.verify_signature() {
                return Err(SignedBuildError::InvalidSignature(i));
            }
        }

        let orders: Vec<Order> = leaves.iter().map(|l| l.order.clone()).collect();
        let tree = crate::MerkleTree::build(&orders).map_err(|_| SignedBuildError::Empty)?;

        Ok(SignedMerkleTree {
            tree,
            leaves: leaves.to_vec(),
        })
    }

    /// Merkle kökü — `orderCommitmentRoot`.
    pub fn root(&self) -> [u8; 32] {
        self.tree.root()
    }

    /// `index`'teki yaprak için imzalı kanıt (Merkle path + imza).
    pub fn prove_signed(&self, index: usize) -> Option<SignedProof> {
        let merkle = self.tree.prove(index)?;
        Some(SignedProof {
            merkle,
            signature: self.leaves[index].signature,
        })
    }

    /// Yaprak sayısı.
    pub fn leaf_count(&self) -> usize {
        self.tree.leaf_count()
    }
}

/// İmzalı kanıtın tam doğrulanması: **hem imza hem Merkle inclusion**.
///
/// Bu, tam kanıt zinciridir: kullanıcı imzası → yaprak → kök.
/// Solidity `verifySignedOrder` ile birebir aynı mantık.
pub fn verify_signed(
    leaf: &[u8; 32],
    sig: &[u8; 65],
    signer: &Address,
    proof: &crate::Proof,
    root: &[u8; 32],
) -> bool {
    // 1. İmza doğrula (ağaçtan bağımsız)
    let recovered = match recover_signer(leaf, sig) {
        Some(addr) => addr,
        None => return false,
    };
    if &recovered != signer {
        return false;
    }
    // 2. Merkle inclusion doğrula
    crate::verify(leaf, proof, root)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{keccak256, MerkleTree, Order};
    use k256::ecdsa::SigningKey;
    use k256::SecretKey;

    fn addr(n: u8) -> Address {
        let mut a = [0u8; 20];
        a[19] = n;
        a
    }

    /// Bilinen anvil test anahtarından imza üretir (PRIVATE_KEY DEĞİL —
    /// bu test anahtarı, nonce'si 0xd7e... olan standart anvil hesabı).
    fn sign_with_test_key(leaf: &[u8; 32], key_bytes: &[u8; 32]) -> [u8; 65] {
        let digest = eth_signed_message_hash(leaf);
        let signing_key = SigningKey::from_slice(key_bytes).unwrap();
        // sign_prehash_recoverable: önceden hash'lenmiş özeti imzalar
        // (sign_recoverable Sha256 kullanır — EIP-191 keccak ile ÇAKIŞIR)
        let (sig, recid) = signing_key.sign_prehash_recoverable(&digest);
        let mut out = [0u8; 65];
        let sig_bytes = sig.to_bytes();
        out[..32].copy_from_slice(&sig_bytes[..32]);
        out[32..64].copy_from_slice(&sig_bytes[32..]);
        out[64] = 27 + u8::try_from(recid).unwrap_or(0);
        out
    }

    /// Standart anvil test anahtarı (account #0). Bu MAINNET anahtarı DEĞİL —
    /// `anvil --mnemonic "test test ... junk"` ile üretilir, public'tir.
    const ANVIL_KEY: [u8; 32] = [
        0xac, 0x09, 0x74, 0xbe, 0xc3, 0x9a, 0x17, 0xe3,
        0x6b, 0xa4, 0xa6, 0xb4, 0xd2, 0x38, 0xff, 0x94,
        0x4b, 0xac, 0xb4, 0x78, 0xcb, 0xed, 0x5e, 0xfc,
        0xae, 0x78, 0x4d, 0x7b, 0xf4, 0xf2, 0xff, 0x80,
    ];

    /// ANVIL_KEY'in adresi (anvil çıktısı ile bilinen değer).
    const ANVIL_ADDR: Address = [
        0xf3, 0x9F, 0xd6, 0xe5, 0x1a, 0xad, 0x88, 0xF6,
        0xF4, 0xce, 0x6a, 0xB8, 0x82, 0x72, 0x79, 0xcf,
        0xFF, 0xb9, 0x22, 0x66,
    ];

    #[test]
    fn eth_signed_message_hash_matches_solidity() {
        // Solidity: keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash))
        let leaf = keccak256(b"test-leaf");
        let digest = eth_signed_message_hash(&leaf);
        // Referans: hash(prefix || leaf) — birebir
        let mut buf = [0u8; 60];
        buf[..28].copy_from_slice(b"\x19Ethereum Signed Message:\n32");
        buf[28..].copy_from_slice(&leaf);
        assert_eq!(digest, keccak256(&buf));
    }

    #[test]
    fn signed_tree_build_validates_signatures() {
        let order = Order::new(1000, ANVIL_ADDR, 1);
        let leaf = order.leaf_hash();
        let sig = sign_with_test_key(&leaf, &ANVIL_KEY);

        let signed = SignedLeaf::new(order, sig);
        assert!(signed.verify_signature(), "Gecerli imza dogrulanmali");

        let tree = SignedMerkleTree::build_signed(&[signed]).unwrap();
        assert_eq!(tree.leaf_count(), 1);
    }

    #[test]
    fn wrong_signature_rejected() {
        let order = Order::new(1000, ANVIL_ADDR, 1);
        let mut sig = sign_with_test_key(&order.leaf_hash(), &ANVIL_KEY);
        // İmzayı boz
        sig[10] ^= 0xff;

        let signed = SignedLeaf::new(order, sig);
        assert!(!signed.verify_signature(), "YANLIS imza REDDEDILMELI");

        let result = SignedMerkleTree::build_signed(&[signed]);
        assert_eq!(result.unwrap_err(), SignedBuildError::InvalidSignature(0));
    }

    #[test]
    fn wrong_signer_rejected() {
        // ANVIL_KEY ile imzala ama user = FARKLI adres
        let order = Order::new(1000, addr(9), 1);
        let sig = sign_with_test_key(&order.leaf_hash(), &ANVIL_KEY);

        let signed = SignedLeaf::new(order, sig);
        assert!(!signed.verify_signature(), "YANLIS imzalayan REDDEDILMELI");

        let result = SignedMerkleTree::build_signed(&[signed]);
        assert_eq!(result.unwrap_err(), SignedBuildError::InvalidSignature(0));
    }

    #[test]
    fn empty_signed_tree_rejected() {
        assert_eq!(
            SignedMerkleTree::build_signed(&[]).unwrap_err(),
            SignedBuildError::Empty
        );
    }

    #[test]
    fn signed_proof_full_verification() {
        // İki imzalı yaprak: tam kanıt zinciri
        let o0 = Order::new(1000, ANVIL_ADDR, 1);
        let o1 = Order::new(2000, ANVIL_ADDR, 2);
        let s0 = sign_with_test_key(&o0.leaf_hash(), &ANVIL_KEY);
        let s1 = sign_with_test_key(&o1.leaf_hash(), &ANVIL_KEY);

        let leaves = vec![
            SignedLeaf::new(o0.clone(), s0),
            SignedLeaf::new(o1.clone(), s1),
        ];
        let tree = SignedMerkleTree::build_signed(&leaves).unwrap();
        let root = tree.root();

        // Her yaprak için tam kanıt
        for i in 0..2 {
            let proof = tree.prove_signed(i).unwrap();
            assert!(verify_signed(
                &leaves[i].order.leaf_hash(),
                &proof.signature,
                &leaves[i].order.user,
                &proof.merkle,
                &root,
            ), "Tam kanit zinciri dogrulanmali");
        }
    }

    #[test]
    fn signed_proof_wrong_root_rejected() {
        let o0 = Order::new(1000, ANVIL_ADDR, 1);
        let s0 = sign_with_test_key(&o0.leaf_hash(), &ANVIL_KEY);
        let tree = SignedMerkleTree::build_signed(&[SignedLeaf::new(o0, s0)]).unwrap();

        let mut bad_root = tree.root();
        bad_root[0] ^= 0xff;
        let proof = tree.prove_signed(0).unwrap();
        // İmza geçerli ama kök yanlış → reddedilmeli
        assert!(!verify_signed(
            &keccak256(b"x"),
            &proof.signature,
            &ANVIL_ADDR,
            &proof.merkle,
            &bad_root,
        ));
    }

    #[test]
    fn unsigned_tree_still_works() {
        // Mevcut (imzasız) API geriye dönük uyumlu kalmali
        let orders = vec![Order::new(1, addr(1), 1), Order::new(2, addr(2), 2)];
        let tree = MerkleTree::build(&orders).unwrap();
        assert_eq!(tree.leaf_count(), 2);
    }
}
