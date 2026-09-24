//! 4 Kademeli Güvenlik Süzgeci — AegisForge çekirdek tarama motoru.
//!
//! Kademeler (master şartname PROJE 5):
//! 1. AutoVerus Z3 SMT sembolik kanı (48 temel invariant)
//! 2. AegisForge metamorfik fuzzing (reentrancy, flash loan; 10.000 mutasyon)
//! 3. Tokenomics/likidite sağlığı (ilk 10 balina <%30, likidite kilidi, vesting)
//! 4. Sinsi kod: blacklist(), pause(), gizli transfer vergisi, honeypot

pub mod backdoor;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum Severity {
    Critical,
    High,
    Medium,
    Low,
    Info,
}

impl Severity {
    pub fn as_str(&self) -> &'static str {
        match self {
            Severity::Critical => "CRITICAL",
            Severity::High => "HIGH",
            Severity::Medium => "MEDIUM",
            Severity::Low => "LOW",
            Severity::Info => "INFO",
        }
    }
}

/// Kademeli fiyatlandırma (tek $4.900 seçenek DEĞİL — İllüzyon-3 düzeltmesi).
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum Tier {
    /// $299 — Otonom Z3 hızlı tarama raporu
    Quick,
    /// $1.490 — Metamorfik fuzzing + düzeltme yaması
    Fuzz,
    /// $4.900 — Cleanvest Verified rozeti + öncelikli listeleme
    Enterprise,
}

impl Tier {
    pub fn price_usd(&self) -> u32 {
        match self {
            Tier::Quick => 299,
            Tier::Fuzz => 1_490,
            Tier::Enterprise => 4_900,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Tier::Quick => "TIER_QUICK",
            Tier::Fuzz => "TIER_FUZZ",
            Tier::Enterprise => "TIER_ENTERPRISE",
        }
    }
}

/// Tek bir güvenlik bulgusu. DİKKAT: satır numarası ve exploit payload'u
/// ücret ödenene kadar kilitli — bu yapı yalnızca hash'i taşır.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Finding {
    pub severity: Severity,
    pub vulnerability_type: String,
    /// Kriptografik taahhüt hash'i (SHA256). Payload KİLİTLİ.
    pub pov_hash: String,
    /// Ücret ödenene kadar kilitli
    pub remediation_locked: bool,
    pub unlock_tier: Tier,
}

/// Tarama raporu (CLI JSON şeması — master şartname §PROJE 5.3).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScanReport {
    pub contract_address: String,
    pub audit_timestamp: u64,
    pub clean_score: u32,
    pub pov_findings: Vec<Finding>,
    pub tier: Tier,
}
