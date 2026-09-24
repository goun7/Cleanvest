//! AegisForge — Bağımsız B2B Akıllı Sözleşme Denetim Motoru
//!
//! Çekirdek ilke: **Deterministik Hash Taahhüdü** (ZK-SNARK DEĞİL!).
//! PoV_Hash = SHA256(ExploitPayload || ContractBytecode || Timestamp)
//!
//! Yasak: "ZK-SNARK" ifadesi kullanılamaz (master şartname v1.2).

pub mod business;
pub mod oracle;
pub mod scanner;

pub use scanner::{Finding, Severity, Tier, ScanReport};
