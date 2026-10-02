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

#[cfg(feature = "proof")]
pub mod proof;

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

    // ============================================================
    // MANIPULASYON TESPITI — emir_degistirme / spoofing / replay
    // (GOREV: "manipulasyon tespiti" — bu katmanin gercek yuzeyi)
    // ============================================================

    /// Manipulasyon: operator bir emrin MIKTARINI degistirse kok degismeli.
    /// Bu, "operator emirleri degistiremez" invariantidir.
    #[test]
    fn tampered_amount_changes_root() {
        let base = Order::new(1_000, addr(1), 1);
        let tampered = Order::new(1_001, addr(1), 1); // +1 birim
        let a = MerkleTree::build(&[base]).unwrap();
        let b = MerkleTree::build(&[tampered]).unwrap();
        assert_ne!(a.root(), b.root(), "miktar degisimi koku degistirmeli");
    }

    /// Manipulasyon: operator kullanici ADRESINI degistirse kok degismeli
    /// (spoofing — "bu kullanici yapmisti" saldirisi).
    #[test]
    fn tampered_user_changes_root() {
        let base = Order::new(1_000, addr(1), 1);
        let spoofed = Order::new(1_000, addr(2), 1); // ayni miktar, farkli kullanici
        let a = MerkleTree::build(&[base]).unwrap();
        let b = MerkleTree::build(&[spoofed]).unwrap();
        assert_ne!(a.root(), b.root(), "kullanici degisimi koku degistirmeli");
    }

    /// Manipulasyon: operator NONCE'u degistirse kok degismeli
    /// (replay korumasi — ayni emir tekrar oynatilamaz).
    #[test]
    fn tampered_nonce_changes_root() {
        let base = Order::new(1_000, addr(1), 1);
        let replayed = Order::new(1_000, addr(1), 2); // ayni emir, farkli nonce
        let a = MerkleTree::build(&[base]).unwrap();
        let b = MerkleTree::build(&[replayed]).unwrap();
        assert_ne!(a.root(), b.root(), "nonce degisimi koku degistirmeli");
    }

    /// Manipulasyon: emir SIRASI degisirse kok degismeli
    /// (batch siralamasi manipulasyonu).
    #[test]
    fn reordered_orders_change_root() {
        let o1 = Order::new(1_000, addr(1), 1);
        let o2 = Order::new(2_000, addr(2), 2);
        let forward = MerkleTree::build(&[o1.clone(), o2.clone()]).unwrap();
        let reversed = MerkleTree::build(&[o2, o1]).unwrap();
        assert_ne!(forward.root(), reversed.root(), "sira degisimi koku degistirmeli");
    }

    /// Invariant: yaprak hash'i emir alanlarindan deterministik
    /// (ayni emir her zaman ayni yaprak — yeniden hesaplanabilirlik).
    #[test]
    fn leaf_hash_deterministic_and_order_sensitive() {
        let o = Order::new(1_000, addr(5), 42);
        let h1 = o.leaf_hash();
        let h2 = Order::new(1_000, addr(5), 42).leaf_hash();
        assert_eq!(h1, h2, "deterministik");
        // Alanlarin sirasi onemli (amount/user/nonce)
        assert_ne!(h1, Order::new(42, addr(5), 1_000).leaf_hash());
    }

    /// Sinir durumu: sifir adres ve sifir miktar gecerli yaprak uretmeli
    /// (abi.encode sag-hizalama adres icin).
    #[test]
    fn zero_address_and_amount_produce_valid_leaf() {
        let o = Order::new(0, [0u8; 20], 0);
        let h = o.leaf_hash();
        // Bos olmamali (keccak hicbir zaman tum sifir olamaz)
        assert_ne!(h, [0u8; 32]);
    }

    /// Sinir durumu: maksimum u128 degerleri tasmamali
    /// (uint256 Solidity'de 32 bayt — u128 her zaman sigar).
    #[test]
    fn max_u128_amount_produces_valid_leaf() {
        let o = Order::new(u128::MAX, [0xff; 20], u128::MAX);
        let h = o.leaf_hash();
        assert_ne!(h, [0u8; 32]);
        // Tekrar uret — deterministik
        assert_eq!(h, Order::new(u128::MAX, [0xff; 20], u128::MAX).leaf_hash());
    }

    /// Derinlik: 17 emir (5 seviye) — tum kanitlar dogrulanmali
    /// (buyuk batch'lerde agac kurulumu ve kanit dogrulama).
    #[test]
    fn deep_tree_all_proofs_verify() {
        let orders: Vec<Order> = (0..17)
            .map(|i| Order::new(100 * (i + 1) as u128, addr((i % 250) as u8 + 1), i as u128))
            .collect();
        let tree = MerkleTree::build(&orders).unwrap();
        assert_eq!(tree.leaf_count(), 17);
        for i in 0..orders.len() {
            let proof = tree.prove(i).unwrap();
            assert!(
                verify(&orders[i].leaf_hash(), &proof, &tree.root()),
                "yaprak {i} kaniti dogrulanmali"
            );
        }
    }

    /// Manipulasyon: kanittan sibling siralamasi bozulursa reddedilmeli
    /// (sag/sol konumunun onemi).
    #[test]
    fn flipped_sibling_position_rejected() {
        let orders = vec![
            Order::new(1, addr(1), 1),
            Order::new(2, addr(2), 2),
        ];
        let tree = MerkleTree::build(&orders).unwrap();
        let proof = tree.prove(0).unwrap();
        let mut flipped = proof.clone();
        for (_s, is_right) in &mut flipped.siblings {
            *is_right = !*is_right;
        }
        assert!(!verify(&orders[0].leaf_hash(), &flipped, &tree.root()));
    }

    // ============================================================
    // CONSERVATION (ERC-4626 analog) — hicbir yaprak kaybolmaz
    // ============================================================

    /// Conservation: buyuk agacta TUM yapraklar kanitlanabilir.
    /// Hicbir emir "kaybolamaz" — her yaprak kok icin inclusion kanitlidir.
    #[test]
    fn conservation_every_leaf_provable_in_large_tree() {
        let n = 100;
        let orders: Vec<Order> = (0..n)
            .map(|i| Order::new(100 * (i + 1) as u128, addr((i % 250) as u8 + 1), i as u128))
            .collect();
        let tree = MerkleTree::build(&orders).unwrap();
        for i in 0..n {
            let proof = tree.prove(i).expect("her yaprak icin kanit olmali");
            assert!(
                verify(&orders[i].leaf_hash(), &proof, &tree.root()),
                "yaprak {i} kok icin kanitlanmali"
            );
        }
    }

    /// Conservation: yaprak sayisi kurulumdan sonra ayni kalmali
    /// (yaprak eklenmez, cikarilmaz, kaybolmaz).
    #[test]
    fn conservation_leaf_count_preserved() {
        for n in [1usize, 2, 3, 7, 16, 31, 64] {
            let orders: Vec<Order> = (0..n)
                .map(|i| Order::new((i + 1) as u128, addr(1), i as u128))
                .collect();
            let tree = MerkleTree::build(&orders).unwrap();
            assert_eq!(tree.leaf_count(), n, "yaprak sayisi {n} korunmali");
        }
    }

    // ============================================================
    // NO-FREEZE (ERC-4626 analog) — kanit her zaman uretilebilir
    // ============================================================

    /// No-freeze: her index icin kanit vardir, kapı/yumusama yok.
    /// Ayrica kanit derinligi log2(n) ile uyumludur (agac dengeli buyur).
    #[test]
    fn no_freeze_proof_available_and_logarithmic() {
        for n in [2usize, 3, 5, 17, 64, 129] {
            let orders: Vec<Order> = (0..n)
                .map(|i| Order::new((i + 1) as u128, addr((i % 250) as u8 + 1), i as u128))
                .collect();
            let tree = MerkleTree::build(&orders).unwrap();
            for i in 0..n {
                let proof = tree.prove(i).expect("kanit donmeli (no-freeze)");
                assert!(proof.siblings.len() <= 32, "derinlik makul olmali");
            }
            // Beklenen seviye sayisi = ceil(log2(n)); tek yaprak icin 0
            let expected = (n as f64).log2().ceil() as usize;
            assert_eq!(
                tree.prove(0).unwrap().siblings.len(),
                expected.max(1).saturating_sub(usize::from(n == 1)),
                "n={n} icin kanit derinligi {expected} olmali"
            );
        }
    }

    // ============================================================
    // WASH TRADE TESPITI — ayni (user, amount, nonce) duplicate
    // ============================================================

    /// Wash trade: ayni emrin IKI kere girilmesi ayni yaprak uretir.
    /// Settlement katmani bunu duplicate olarak reddetmelidir — bu test,
    /// duplicate tespiti icin yaprak hash'inin stabil oldugunu kanitlar.
    #[test]
    fn wash_trade_duplicate_order_produces_identical_leaf() {
        let a = Order::new(1_000, addr(5), 42);
        let b = Order::new(1_000, addr(5), 42); // birebir ayni
        assert_eq!(
            a.leaf_hash(),
            b.leaf_hash(),
            "ayni emir ayni yaprak (duplicate tespit edilebilir)"
        );
        // Iki kere girilen emir agacta iki ornek olarak durur; her ikisi de
        // ayni yapraktir ve kanitlari ayni yapraka cozulur
        let twice = MerkleTree::build(&[a.clone(), b]).unwrap();
        assert_eq!(twice.leaf_count(), 2);
        let leaf = a.leaf_hash();
        assert!(verify(&leaf, &twice.prove(0).unwrap(), &twice.root()));
        assert!(verify(&leaf, &twice.prove(1).unwrap(), &twice.root()));
    }

    /// Wash trade: ayni user + ayni nonce ama FARKLI miktar → farkli yaprak.
    /// Bu, settlement'in "her user+nonce tek emir" kuralini uygulamasinin
    /// yaprak seviyesinde gorulmesini saglar.
    #[test]
    fn wash_trade_same_user_nonce_different_amount_diverges() {
        let o1 = Order::new(1_000, addr(5), 42);
        let o2 = Order::new(2_000, addr(5), 42); // ayni user+nonce, farkli miktar
        assert_ne!(o1.leaf_hash(), o2.leaf_hash());
        let t1 = MerkleTree::build(&[o1]).unwrap();
        let t2 = MerkleTree::build(&[o2]).unwrap();
        assert_ne!(t1.root(), t2.root(), "wash-trade varyanti farkli kok");
    }

    // ============================================================
    // LAYERING — ayni user'dan coklu katmanli emirler
    // ============================================================

    /// Layering: ayni user'dan 20 farkli miktarli emir (katmanlama).
    /// Hepsinin yapragi farklidir ve hepsi kanitlanabilir — settlement
    /// bunlari tek user'in manipulasyon girisimi olarak denetleyebilir.
    #[test]
    fn layering_same_user_many_amounts_all_provable() {
        let user = addr(7);
        let orders: Vec<Order> = (0..20)
            .map(|i| Order::new(100 * (i + 1) as u128, user, i as u128))
            .collect();
        let tree = MerkleTree::build(&orders).unwrap();
        // Her katmanin yapragi farkli
        let mut leaves: Vec<_> = orders.iter().map(|o| o.leaf_hash()).collect();
        leaves.sort_unstable();
        leaves.dedup();
        assert_eq!(leaves.len(), 20, "her katman farkli yaprak");
        // Hepsinin kaniti gecerli
        for i in 0..20 {
            assert!(verify(
                &orders[i].leaf_hash(),
                &tree.prove(i).unwrap(),
                &tree.root()
            ));
        }
    }

    // ============================================================
    // DONATION ATTACK (ERC-4626 analog — semantic)
    // vault kodu bu crate'te DEGIL; Merkle kok-commitment uzerinde
    // ayni saldiri/kalkan semantiğini test ederiz.
    // ============================================================

    /// Donation analog: agac kurulduktan sonra beklenmedik yaprak
    /// ("bagis") eklenirse kok degisir. Kullanici onceden commit ettigi
    /// kok ile korunur — bagisli agacin kaniti eski kole reddedilir
    /// (depositWithMin'in "min shares out" kalkaninin karsiligi).
    #[test]
    fn donation_analog_post_build_leaf_addition_changes_root() {
        let base = vec![
            Order::new(1_000, addr(1), 1),
            Order::new(2_000, addr(2), 2),
        ];
        let committed = MerkleTree::build(&base).unwrap();
        let committed_root = committed.root();

        // "Bagis" — beklenmedik emir eklenirse kok degismeli
        let mut donated = base.clone();
        donated.push(Order::new(9_999, addr(9), 9));
        let donated_tree = MerkleTree::build(&donated).unwrap();
        assert_ne!(committed_root, donated_tree.root(), "bagis koku degistirmeli");

        // Kullanici commit edilen kole guvenir: bagisli agacin
        // gecerli kaniti bile eski kole karsi reddedilir
        let proof = donated_tree.prove(0).unwrap();
        assert!(
            !verify(&donated[0].leaf_hash(), &proof, &committed_root),
            "bagisli kanit commit edilen koke reddedilmeli (kullanici korundu)"
        );
        // Ama kendi kokune karsi gecerli (agac tutarli)
        assert!(verify(&donated[0].leaf_hash(), &proof, &donated_tree.root()));
    }

    /// Donation analog: kok manipule edilirse TUM gecerli kanitlar reddedilir.
    /// Saldirdan onceki depositorlarin "min-out" beklentisi gibi — kurtarma
    /// (slippage) ile degil, katii redd ile korunur.
    #[test]
    fn donation_analog_tampered_root_rejects_valid_proofs() {
        let orders: Vec<Order> = (0..4)
            .map(|i| Order::new((i + 1) as u128, addr((i + 1) as u8), i as u128))
            .collect();
        let tree = MerkleTree::build(&orders).unwrap();

        let mut tampered = tree.root();
        tampered[31] ^= 0x01; // 1 bit bile degisse
        for i in 0..orders.len() {
            let proof = tree.prove(i).unwrap();
            assert!(
                !verify(&orders[i].leaf_hash(), &proof, &tampered),
                "manipule kok {i}. yapragin gecerli kanitini reddetmeli"
            );
            assert!(verify(&orders[i].leaf_hash(), &proof, &tree.root()));
        }
    }

    // ============================================================
    // ROUNDING — yaprak eslemede yukari yuvarlama (tek kalan)
    // ============================================================

    /// Rounding: tek kalan yaprak KENDISIYLE eslesir (ceil(5/2)=3 ebeveyn).
    /// Bu "yukari yuvarlama"dir; kanit hala gecerlidir ve sibling == leaf.
    #[test]
    fn rounding_odd_leaf_self_pairing_proofs_verify() {
        // 5 yaprak: 5. (index 4) seviye 0'da tek kalir
        let orders: Vec<Order> = (0..5)
            .map(|i| Order::new((i + 1) as u128, addr((i + 1) as u8), i as u128))
            .collect();
        let tree = MerkleTree::build(&orders).unwrap();

        let last = orders[4].leaf_hash();
        let proof = tree.prove(4).unwrap();
        // En alt seviyedeki sibling, yaprak tek kaldigi icin kendisidir
        assert_eq!(
            proof.siblings[0].0, last,
            "tek kalan yapragin sibling'i kendisi olmali (self-pairing)"
        );
        assert!(verify(&last, &proof, &tree.root()));
        // Diger (eslesen) yapraklar da gecerli
        for i in 0..4 {
            assert!(verify(&orders[i].leaf_hash(), &tree.prove(i).unwrap(), &tree.root()));
        }
    }

    /// Rounding: her seviye oncekinin yarisi yukari yuvarlanir —
    /// n yaprak -> ceil(n/2) ebeveyn, kok seviyesinde 1.
    #[test]
    fn rounding_levels_shrink_by_half_rounded_up() {
        for n in [1usize, 2, 3, 4, 5, 7, 8, 15, 16, 17, 31] {
            let orders: Vec<Order> = (0..n)
                .map(|i| Order::new((i + 1) as u128, addr(1), i as u128))
                .collect();
            let tree = MerkleTree::build(&orders).unwrap();
            assert_eq!(tree.leaf_count(), n);
            for w in tree.levels.windows(2) {
                let expected = (w[0].len() + 1) / 2; // ceil(yari)
                assert_eq!(
                    w[1].len(), expected,
                    "n={n}: {} yapraktan {} ebeveyn (ceil) olmali",
                    w[0].len(), expected
                );
            }
            assert_eq!(tree.levels.last().unwrap().len(), 1, "n={n}: kok 1 olmali");
        }
    }

    // ============================================================
    // WASH TRADE (derinlestirme) — batch duplicate tespiti
    // ============================================================

    /// Wash trade: ayni emirden N tane iceren batch — leaf set 1, ama
    /// leaf_count N. Settlement bu "1 uniq emir" bilgisini kullanarak
    /// wash-trade batch'ini reddedebilir.
    #[test]
    fn wash_trade_duplicate_batch_detected_via_leaf_set() {
        let dupe = Order::new(500, addr(3), 7);
        let batch = vec![dupe.clone(), dupe.clone(), dupe.clone()];
        let tree = MerkleTree::build(&batch).unwrap();

        assert_eq!(tree.leaf_count(), 3, "3 emir agacta 3 yaprak");
        let mut uniq: Vec<_> = batch.iter().map(|o| o.leaf_hash()).collect();
        uniq.sort_unstable();
        uniq.dedup();
        assert_eq!(
            uniq.len(), 1,
            "3 duplicate emir -> 1 uniq yaprak (wash trade tespit edilebilir)"
        );
    }

    /// Wash trade: karisik batch (A,A,B,B,C) — uniq 3, duplicate 2.
    /// Duplicate'ler agacin gecerliligini bozmaz; settlement uniq
    /// sayisindan wash-trade oranini cikarabilir.
    #[test]
    fn wash_trade_mixed_batch_duplicate_counts_match() {
        let a = Order::new(100, addr(1), 1);
        let b = Order::new(200, addr(2), 2);
        let c = Order::new(300, addr(3), 3);
        let batch = vec![a.clone(), a.clone(), b.clone(), b.clone(), c.clone()];
        let tree = MerkleTree::build(&batch).unwrap();

        assert_eq!(tree.leaf_count(), 5);
        let mut uniq: Vec<_> = batch.iter().map(|o| o.leaf_hash()).collect();
        uniq.sort_unstable();
        uniq.dedup();
        assert_eq!(uniq.len(), 3, "A,A,B,B,C -> 3 uniq emir (2 duplicate)");
        assert_eq!(batch.len() - uniq.len(), 2, "duplicate sayisi 2");

        // Duplicate'ler disinda hepsi kanitlanabilir (agac tutarli)
        for i in 0..batch.len() {
            assert!(
                verify(&batch[i].leaf_hash(), &tree.prove(i).unwrap(), &tree.root()),
                "yaprak {i} kanitlanmali (duplicate'ler dahil)"
            );
        }
    }
}
