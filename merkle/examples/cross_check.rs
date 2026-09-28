//! Çapraz doğrulama: Rust Merkle kökü ile Solidity `computeRoot` birebir mi?
//!
//! Çalıştırma: `cargo run --quiet --example cross_check`
//!
//! Bu örnek, sabit bir emir listesi için kök üretir ve hex olarak basar.
//! Değer, `CleanvestSettlement.computeRoot` (Solidity testi) ile
//! karşılaştırılır — birebir eşleşmelidir.

use cleanvest_merkle::{Order, MerkleTree};

fn addr(n: u8) -> [u8; 20] {
    let mut a = [0u8; 20];
    a[19] = n;
    a
}

fn main() {
    // test/CleanvestSettlement.t.sol::testComputeRootOddLeaves ile AYNI emirler
    let orders = vec![
        Order::new(1, addr(1), 1),
        Order::new(2, addr(2), 2),
        Order::new(3, addr(3), 3),
    ];

    let tree = MerkleTree::build(&orders).expect("agac kurulmali");
    let root = tree.root();

    println!("leaf_count   = {}", tree.leaf_count());
    println!("root_hex     = 0x{}", hex::encode(root));

    // Her yaprak icin kanit ve Rust-ici dogrulama
    for (i, o) in orders.iter().enumerate() {
        let proof = tree.prove(i).expect("kanit uretilmeli");
        let ok = cleanvest_merkle::verify(&o.leaf_hash(), &proof, &root);
        println!(
            "proof[{}]     = siblings={} valid_rust={}",
            i,
            proof.siblings.len(),
            ok
        );
    }

    // Yanlis kanit reddi
    let p0 = tree.prove(0).unwrap();
    let bad = Order::new(9999, addr(9), 9).leaf_hash();
    println!("wrong_leaf   = rejected={}", !cleanvest_merkle::verify(&bad, &p0, &root));

    println!("\nSolidity ile karsilastir: testComputeRootOddLeaves == bu root_hex");
}
