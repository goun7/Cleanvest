//! # Kanıt üretici (prove_cli)
//!
//! İmzalı emirlerden Merkle ağacı kurar ve bağımsız doğrulanabilir bir
//! `proof.json` üretir. Bu, `verify_cli` ile doğrulanan dosyadır —
//! **gidiş-dönüşün test edilmesini** sağlar.
//!
//! ## Kullanım
//!
//! ```bash
//! # orders.json:
//! # [
//! #   {"amount":"1000","user":"0xf39F...2266","nonce":"1","signature":"0x..."},
//! #   ...
//! # ]
//! cargo run --release --features proof --example prove_cli -- \
//!     --orders orders.json --index 0 --out proof.json
//! ```
//!
//! ## Güvenlik notu
//!
//! Bu araç **test ve demo amaçlıdır**. Üretimde kök, zincir-üstü
//! `orderCommitmentRoot` olarak yayınlanır ve kanıtlar operatör tarafından
//! üretilir. Önemli olan, üretilen kanıtın `verify_cli` ile bağımsız
//! doğrulanabilmesidir.

use std::process::ExitCode;

use cleanvest_merkle::proof::{encode_proof_bytes, OrderJson, ProofJson};
use cleanvest_merkle::signed::{SignedLeaf, SignedMerkleTree};
use cleanvest_merkle::Order;
use serde::Deserialize;

/// Girdi: imzalı emir listesi.
#[derive(Debug, Deserialize)]
struct SignedOrderJson {
    #[serde(deserialize_with = "cleanvest_merkle::proof::deserialize_u128_loose")]
    amount: u128,
    user: String,
    #[serde(deserialize_with = "cleanvest_merkle::proof::deserialize_u128_loose")]
    nonce: u128,
    signature: String,
}

fn main() -> ExitCode {
    let mut orders_path: Option<String> = None;
    let mut index: usize = 0;
    let mut out_path: String = "proof.json".to_string();
    let mut chain_id: Option<u64> = None;
    let mut settlement: Option<String> = None;

    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "--orders" => orders_path = args.next(),
            "--index" => {
                index = args.next().and_then(|s| s.parse().ok()).unwrap_or(0);
            }
            "--out" => out_path = args.next().unwrap_or_else(|| "proof.json".to_string()),
            "--chain-id" => chain_id = args.next().and_then(|s| s.parse().ok()),
            "--settlement" => settlement = args.next(),
            "-h" | "--help" => {
                eprintln!("Kullanim: prove_cli --orders orders.json --index 0 --out proof.json");
                return ExitCode::from(2);
            }
            _ => {
                eprintln!("Bilinmeyen arguman: {a}");
                return ExitCode::from(2);
            }
        }
    }

    let orders_path = match orders_path {
        Some(p) => p,
        None => {
            eprintln!("HATA: --orders gerekli");
            return ExitCode::from(2);
        }
    };

    let contents = match std::fs::read_to_string(&orders_path) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("HATA: {orders_path} okunamadi: {e}");
            return ExitCode::from(2);
        }
    };

    let signed_orders: Vec<SignedOrderJson> = match serde_json::from_str(&contents) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("HATA: orders.json ayristirilamadi: {e}");
            return ExitCode::from(2);
        }
    };

    if signed_orders.is_empty() {
        eprintln!("HATA: bos emir listesi");
        return ExitCode::from(2);
    }
    if index >= signed_orders.len() {
        eprintln!("HATA: index {index} sinir disi ({} emir var)", signed_orders.len());
        return ExitCode::from(2);
    }

    // İmzalı yaprakları kur
    let mut leaves = Vec::with_capacity(signed_orders.len());
    for so in &signed_orders {
        let user = match cleanvest_merkle::proof::parse_address(&so.user) {
            Ok(a) => a,
            Err(e) => {
                eprintln!("HATA: gecersiz adres {}: {e}", so.user);
                return ExitCode::from(2);
            }
        };
        let signature = match cleanvest_merkle::proof::parse_fixed_bytes::<65>(&so.signature) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("HATA: gecersiz imza: {e}");
                return ExitCode::from(2);
            }
        };
        let order = Order::new(so.amount, user, so.nonce);
        leaves.push(SignedLeaf::new(order, signature));
    }

    // Ağacı kur — tüm imzalar DOGRULANIR; tek geçersiz imza reddeder
    let tree = match SignedMerkleTree::build_signed(&leaves) {
        Ok(t) => t,
        Err(e) => {
            eprintln!("HATA: agac kurulamadi (gecersiz imza?): {e:?}");
            return ExitCode::from(1);
        }
    };

    let signed_proof = match tree.prove_signed(index) {
        Some(p) => p,
        None => {
            eprintln!("HATA: kanit uretilemedi (index {index})");
            return ExitCode::from(1);
        }
    };

    let target = &signed_orders[index];
    let pj = ProofJson {
        order: OrderJson {
            amount: target.amount,
            user: cleanvest_merkle::proof::parse_address(&target.user).unwrap(),
            nonce: target.nonce,
        },
        signature: signed_proof.signature,
        root: tree.root(),
        proof_bytes: encode_proof_bytes(&signed_proof.merkle),
        chain_id,
        batch_id: None,
        settlement,
    };

    match pj.to_string_pretty() {
        Ok(json) => {
            if let Err(e) = std::fs::write(&out_path, format!("{json}\n")) {
                eprintln!("HATA: {out_path} yazilamadi: {e}");
                return ExitCode::from(2);
            }
            println!("Kanal yazildi: {out_path}");
            println!("  yaprak index : {index} / {}", tree.leaf_count() - 1);
            println!("  kok          : 0x{}", hex::encode(tree.root()));
            println!("  proof seviye : {}", signed_proof.merkle.siblings.len());
            println!("");
            println!("Dogrulamak icin:");
            println!("  verify_cli {out_path}");
        }
        Err(e) => {
            eprintln!("HATA: JSON uretilemedi: {e}");
            return ExitCode::from(2);
        }
    }

    ExitCode::SUCCESS
}
