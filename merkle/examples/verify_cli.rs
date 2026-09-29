//! # `cleanvest verify proof.json` — Bağımsız Kanıt Doğrulayıcı
//!
//! Operatöre **güvenmeden** bir Cleanvest emir kanıtını doğrular.
//!
//! ## Kullanım
//!
//! ```bash
//! cargo run --release --features proof --example verify_cli -- proof.json
//! ```
//!
//! veya derlenmiş binary ile:
//! ```bash
//! merkle/target/release/examples/verify_cli proof.json
//! ```
//!
//! ## Ne doğrulanır?
//!
//! 1. **Yaprak yeniden hesaplanır** — `keccak256(abi.encode(amount, user, nonce))`
//!    JSON'daki emir alanlarından baştan üretilir.
//! 2. **EIP-191 imzası** — `recover_signer(leaf, sig) == user`.
//! 3. **Merkle inclusion** — `verify(leaf, proof, root)`.
//!
//! ## Dürüst sınırlar
//!
//! - Bu araç **kriptografik** doğrulama yapar; **zincir-üstü** durumu
//!   bilmez. JSON'daki `root` operatörün iddiasıdır.
//! - Kökü zincirden okumak için (opsiyonel):
//!   `cast call $SETTLEMENT "orderCommitmentRoot()(bytes32)" --rpc-url $RPC`
//!   ve `verifySignedOrder` fonksiyonu ile aynı baytları verin.

use std::env;
use std::process::ExitCode;

use cleanvest_merkle::proof::{ProofJson, ProofResult};

fn main() -> ExitCode {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.is_empty() {
        eprintln!("Kullanim: verify_cli <proof.json> [--quiet]");
        eprintln!("");
        eprintln!("Ornek:");
        eprintln!("  verify_cli proof.json");
        return ExitCode::from(2);
    }
    let path = &args[0];
    let quiet = args.iter().any(|a| a == "--quiet");

    let contents = match std::fs::read_to_string(path) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("HATA: {path} okunamadi: {e}");
            return ExitCode::from(2);
        }
    };

    let proof = match ProofJson::from_str(&contents) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("HATA: kanit ayristirilamadi: {e}");
            return ExitCode::from(2);
        }
    };

    // Ozet baslik
    if !quiet {
        println!("=== Cleanvest Bagimsiz Kanit Dogrulamasi ===");
        println!("dosya          : {path}");
        if let Some(chain) = proof.chain_id {
            println!("chainId        : {chain}");
        }
        if let Some(b) = &proof.batch_id {
            println!("batchId        : {b}");
        }
        if let Some(s) = &proof.settlement {
            println!("settlement     : {s}");
        }
        println!("");
    }

    match proof.verify() {
        ProofResult::Valid { leaf, digest } => {
            if !quiet {
                println!("[GECTI] 1/3 Yaprak yeniden hesaplandi (emir alanlarindan)");
                println!("        leaf    = 0x{}", hex::encode(leaf));
                println!("[GECTI] 2/3 EIP-191 imza gecerli (imzalayan = kullanici)");
                println!("        digest  = 0x{}", hex::encode(digest));
                println!("[GECTI] 3/3 Merkle inclusion gecerli (yaprak kokte)");
                println!("        root    = 0x{}", hex::encode(proof.root));
                println!("");
                println!("KANIT GECTI — kullanici imzasi -> yaprak -> kok zinciri dogrulandi.");
                println!("");
                println!("Son adim (insan): kok'u zincir-ustu orderCommitmentRoot ile");
                println!("karsilastirin:");
                println!("  cast call <settlement> \"orderCommitmentRoot()(bytes32)\" --rpc-url <rpc>");
            } else {
                println!("VALID");
            }
            ExitCode::SUCCESS
        }
        ProofResult::InvalidSignature { recovered } => {
            eprintln!("[BASARISIZ] 2/3 EIP-191 imza gecerli DEGIL");
            if let Some(r) = recovered {
                eprintln!("  geri kazanilan adres : 0x{}", hex::encode(r));
                eprintln!("  iddia edilen kullanici: 0x{}", hex::encode(proof.order.user));
            } else {
                eprintln!("  imzadan adres geri kazanilamadi (hatali imza)");
            }
            ExitCode::from(1)
        }
        ProofResult::MerkleInclusionFailed => {
            eprintln!("[BASARISIZ] 3/3 Merkle inclusion gecerli DEGIL");
            eprintln!("  yaprak, iddia edilen kokte bulunamadi");
            eprintln!("  (bozuk kanit veya kok operator tarafindan degistirilmis olabilir)");
            ExitCode::from(1)
        }
        ProofResult::Malformed(msg) => {
            eprintln!("[BASARISIZ] kanit bicimsiz: {msg}");
            ExitCode::from(2)
        }
    }
}
