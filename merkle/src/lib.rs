//! # Cleanvest Emir Taahhudu Merkle Üreticisi
//!
//! `CleanvestSettlement.orderCommitmentRoot` için gerçek Merkle ağacı kurar.
//!
//! ## Güvenlik açığı kapanması
//!
//! **Öncesi:** `orderCommitmentRoot = keccak256("merkle-orders-1")` sabitti —
//! kökü üreten kimse yoktu, zincire sıfır-olmayan her değer yazılabilirdi
//! (`ICleanvestSettlement.sol:11` "kullanıcı emir taahhüdü Merkle kökü"
//! iddiası uygulanmamıştı).
//!
//! **Sonrası:** bu crate gerçek kullanıcı emirlerinden Merkle kökü üretir;
//! `prove()` ile her yaprak için **inclusion kanıtı** (sibling path) verilir;
//! `CleanvestSettlement.verifyMerkleProof` köre karşı doğrular.
//!
//! ## Solidity ile uyumluluk (birebir)
//!
//! Yaprak: `keccak256(abi.encode(amount, user, nonce))` — Solidity
//! `abi.encode` = 32 baytlık paketleme (uint256, address, uint256).
//!
//! İç düğüm: `keccak256(abi.encode(a, b))` — **daima iki 32-baytlık eleman**,
//! çift yapraklı (double-leaf) ağaç. Tekil kalan yaprak **kopyalanmaz**;
//! `keccak256(abi.encode(leaf, leaf))` ile kendi ile eşleştirilir.
//!
//! Keccak, `tiny-keccak` ile EVM `keccak256` ile birebir aynıdır
//! (testlerle kanıtlanmış known-vector'ler).
//!
//! ## Örnek
//!
//! ```
//! use cleanvest_merkle::{Order, MerkleTree};
//!
//! let orders = vec![
//!     Order::new(1_000, [0u8; 20], 1),
//!     Order::new(2_000, [0u8; 20], 2),
//! ];
//! let tree = MerkleTree::build(&orders).unwrap();
//! let _root = tree.root();                 // -> orderCommitmentRoot
//! let _proof = tree.prove(0).unwrap();     // -> sibling path
//! ```

#![forbid(unsafe_code)]

pub mod signed;

use tiny_keccak::{Hasher, Keccak};

/// Keccak-256 — EVM `keccak256` ile birebidir (tiny-keccak).
pub fn keccak256(data: &[u8]) -> [u8; 32] {
    let mut out = [0u8; 32];
    let mut k = Keccak::v256();
    k.update(data);
    k.finalize(&mut out);
    out
}

// ============================================================
// Solidity abi.encode uyumlu paketleme
// ============================================================

/// EVM adresi (20 bayt). Hizalama için 32 baytın **sağ** tarafında durur
/// (Solidity `abi.encode` adresleri sağa hizalar).
pub type Address = [u8; 20];

/// 32 baytlık sola-hizalı uint256 (Solidity `abi.encode` uint256 davranışı).
fn left_pad_32(bytes: &[u8]) -> [u8; 32] {
    debug_assert!(bytes.len() <= 32, "uint256 32 bayti asar");
    let mut out = [0u8; 32];
    let n = bytes.len().min(32);
    out[32 - n..].copy_from_slice(&bytes[..n]);
    out
}

/// `keccak256(abi.encode(a, b))` — iki 32 baytlık eleman.
fn hash_pair(a: &[u8; 32], b: &[u8; 32]) -> [u8; 32] {
    let mut buf = [0u8; 64];
    buf[..32].copy_from_slice(a);
    buf[32..].copy_from_slice(b);
    keccak256(&buf)
}

// ============================================================
// Order (emir) — yaprak verisi
// ============================================================

/// Bir kullanıcı emri. Yaprak hash: `keccak256(abi.encode(amount, user, nonce))`.
///
/// - `amount`: 6 ondalıklı USDC miktarı (temel birim) — Solidity uint256
/// - `user`:   alıcı/satıcı adresi (20 bayt, sağa hizalı)
/// - `nonce`:  front-run koruması için tek-seferlik sayı (uint256)
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Order {
    pub amount: u128,
    pub user: Address,
    pub nonce: u128,
}

impl Order {
    pub fn new(amount: u128, user: Address, nonce: u128) -> Self {
        Self { amount, user, nonce }
    }

    /// Bu emrin Merkle yaprak hash'i: `keccak256(abi.encode(amount, user, nonce))`.
    ///
    /// Solidity karşılığı:
    /// ```solidity
    /// keccak256(abi.encode(amount, user, nonce))
    /// ```
    /// (uint256, address, uint256) → 96 bayt paket.
    pub fn leaf_hash(&self) -> [u8; 32] {
        let mut buf = [0u8; 96];
        // amount: uint256 (32 bayt, sola hizalı büyük-tamam)
        buf[0..32].copy_from_slice(&left_pad_32(&self.amount.to_be_bytes()));
        // user: address (20 bayt, 12 bayt sıfır dolgu + sağa hizalı)
        buf[32 + 12..32 + 32].copy_from_slice(&self.user);
        // nonce: uint256
        buf[64..96].copy_from_slice(&left_pad_32(&self.nonce.to_be_bytes()));
        keccak256(&buf)
    }
}

// ============================================================
// Merkle ağacı — çift yapraklı (double-leaf)
// ============================================================

/// Merkle ağacı. Çift yapraklıdır: her seviyede elemanlar ikili eşleştirilir;
/// **tek kalan yaprak kendisiyle eşleştirilir** (`hash_pair(x, x)`).
///
/// Bu davranış `CleanvestSettlement.verifyMerkleProof` ile **birebir** aynı
/// olmalıdır — ağacı kurma ve doğrulama aynı kuralı paylaşır.
#[derive(Debug, Clone)]
pub struct MerkleTree {
    /// Tüm seviyeler; `levels[0]` = yapraklar, son seviye = kök.
    levels: Vec<Vec<[u8; 32]>>,
}

/// Merkle inclusion kanıtı (sibling path).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Proof {
    /// Kardeş hash + konum: `true` = sibling sağda (acc önce gelir),
    /// `false` = sibling solda (sibling önce gelir). Köke doğru sıralı.
    pub siblings: Vec<([u8; 32], bool)>,
}

/// Ağaç kurulum hataları.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BuildError {
    /// Boş ağacın kökü tanımsızdır (zincir `bytes32(0)`'ı zaten reddeder).
    Empty,
}

impl MerkleTree {
    /// Emir listesinden Merkle ağacını kurar.
    pub fn build(orders: &[Order]) -> Result<Self, BuildError> {
        if orders.is_empty() {
            return Err(BuildError::Empty);
        }

        let mut levels: Vec<Vec<[u8; 32]>> = Vec::new();
        let leaves: Vec<[u8; 32]> = orders.iter().map(|o| o.leaf_hash()).collect();
        levels.push(leaves);

        while levels.last().unwrap().len() > 1 {
            let current = levels.last().unwrap();
            let mut next: Vec<[u8; 32]> = Vec::with_capacity((current.len() + 1) / 2);
            let mut i = 0;
            while i < current.len() {
                if i + 1 < current.len() {
                    next.push(hash_pair(&current[i], &current[i + 1]));
                    i += 2;
                } else {
                    // Tek kalan: kendisiyle eşleştir (double-leaf kuralı)
                    next.push(hash_pair(&current[i], &current[i]));
                    i += 1;
                }
            }
            levels.push(next);
        }

        Ok(MerkleTree { levels })
    }

    /// Merkle kökü — bu, `orderCommitmentRoot`'dur.
    pub fn root(&self) -> [u8; 32] {
        *self.levels.last().unwrap().last().unwrap()
    }

    /// `index`'teki yaprak için inclusion kanıtı üretir.
    pub fn prove(&self, index: usize) -> Option<Proof> {
        let leaves = &self.levels[0];
        if index >= leaves.len() {
            return None;
        }

        let mut siblings: Vec<([u8; 32], bool)> = Vec::new();
        let mut idx = index;
        for level in 0..self.levels.len() - 1 {
            let current = &self.levels[level];
            let (sibling, is_right) = if idx % 2 == 0 {
                if idx + 1 < current.len() {
                    (current[idx + 1], true) // sibling sağda
                } else {
                    (current[idx], true) // tek kalan → acc iki kez
                }
            } else {
                (current[idx - 1], false) // sibling solda
            };
            siblings.push((sibling, is_right));
            idx /= 2;
        }

        Some(Proof { siblings })
    }

    /// Yaprak sayısı.
    pub fn leaf_count(&self) -> usize {
        self.levels[0].len()
    }
}

/// Kanıtın köre karşı doğrulanması — Solidity `verifyMerkleProof` ile
/// **birebir aynı algoritma** (çift-yapraklı, sibling sıralı).
///
/// `leaf`'ten başlar; her seviyede `acc = hash(acc, sibling)` uygular
/// ve sonucu `root` ile karşılaştırır. Bu sadeleştirilmiş doğrulayıcı,
/// kardeşlerin **sırasını** ağaç kurulum sırasından alır — tıpkı
/// Solidity tarafındaki `leafIndex` tabanlı doğrulamanın yaptığı gibi.
pub fn verify(leaf: &[u8; 32], proof: &Proof, root: &[u8; 32]) -> bool {
    let mut acc = *leaf;
    for (sibling, is_right) in &proof.siblings {
        acc = if *is_right {
            hash_pair(&acc, sibling)   // (acc, sibling)
        } else {
            hash_pair(sibling, &acc)   // (sibling, acc)
        };
    }
    acc == *root
}

#[cfg(test)]
mod tests {
    use super::*;

    fn addr(n: u8) -> Address {
        let mut a = [0u8; 20];
        a[19] = n;
        a
    }

    #[test]
    fn keccak_known_vector_empty() {
        // Keccak-256("") = c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
        let h = keccak256(b"");
        assert_eq!(
            hex::encode(h),
            "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
        );
    }

    #[test]
    fn keccak_known_vector_abc() {
        // Keccak-256("abc")
        let h = keccak256(b"abc");
        assert_eq!(
            hex::encode(h),
            "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45"
        );
    }

    #[test]
    fn single_order_root_equals_leaf() {
        let tree = MerkleTree::build(&[Order::new(1000, addr(1), 1)]).unwrap();
        assert_eq!(tree.root(), Order::new(1000, addr(1), 1).leaf_hash());
    }

    #[test]
    fn empty_tree_errors() {
        assert_eq!(MerkleTree::build(&[]).unwrap_err(), BuildError::Empty);
    }

    #[test]
    fn odd_leaf_count_proofs_verify() {
        // 3 yaprak: tek kalan kendisiyle eşleştirilir
        let orders = vec![
            Order::new(1, addr(1), 1),
            Order::new(2, addr(2), 2),
            Order::new(3, addr(3), 3),
        ];
        let tree = MerkleTree::build(&orders).unwrap();
        assert_eq!(tree.leaf_count(), 3);
        for i in 0..3 {
            let proof = tree.prove(i).unwrap();
            assert!(verify(&orders[i].leaf_hash(), &proof, &tree.root()));
        }
    }

    #[test]
    fn even_leaf_count_proofs_verify() {
        let orders: Vec<Order> = (0..6)
            .map(|i| Order::new(100 * (i + 1) as u128, addr(i as u8 + 1), i as u128 + 1))
            .collect();
        let tree = MerkleTree::build(&orders).unwrap();
        for i in 0..orders.len() {
            let proof = tree.prove(i).unwrap();
            assert!(verify(&orders[i].leaf_hash(), &proof, &tree.root()));
        }
    }

    #[test]
    fn wrong_proof_rejected() {
        let orders = vec![
            Order::new(1, addr(1), 1),
            Order::new(2, addr(2), 2),
            Order::new(3, addr(3), 3),
        ];
        let tree = MerkleTree::build(&orders).unwrap();
        let proof = tree.prove(0).unwrap();
        // Farklı yaprak ile aynı kanıt REDDEDİLMELİ
        assert!(!verify(&Order::new(99, addr(9), 9).leaf_hash(), &proof, &tree.root()));
    }

    #[test]
    fn wrong_root_rejected() {
        let tree = MerkleTree::build(&[Order::new(1, addr(1), 1)]).unwrap();
        let proof = tree.prove(0).unwrap();
        let mut bad = tree.root();
        bad[0] ^= 0xff;
        assert!(!verify(&Order::new(1, addr(1), 1).leaf_hash(), &proof, &bad));
    }

    #[test]
    fn deterministic_root() {
        let orders = vec![Order::new(5, addr(1), 1), Order::new(5, addr(1), 1)];
        assert_eq!(
            MerkleTree::build(&orders).unwrap().root(),
            MerkleTree::build(&orders).unwrap().root()
        );
    }

    #[test]
    fn different_orders_different_roots() {
        let a = MerkleTree::build(&[Order::new(1, addr(1), 1)]).unwrap();
        let b = MerkleTree::build(&[Order::new(2, addr(1), 1)]).unwrap();
        assert_ne!(a.root(), b.root());
    }

    #[test]
    fn prove_out_of_range_is_none() {
        let tree = MerkleTree::build(&[Order::new(1, addr(1), 1)]).unwrap();
        assert!(tree.prove(5).is_none());
    }
}
