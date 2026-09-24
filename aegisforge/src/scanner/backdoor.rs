//! Kademe 4 — Sinsi Kod ve Arka Kapı Dedektörü.
//!
//! Statik imza taraması: blacklist(), pause(), gizli transfer vergisi,
//! honeypot fonksiyonları. Bu kademe ücretsiz çalışır (CleanScore'a besler).

use crate::scanner::{Finding, Severity, Tier};

/// Sinsi kod imzaları — Solidity function selector'ları.
const BACKDOOR_SIGNATURES: &[&str] = &[
    "blacklist(",
    "addToBlacklist(",
    "setBlacklist(",
    "pause(",
    "setPaused(",
    "togglePause(",
    "freeze(",
    "setFeeOnTransfer(",
    "setTransferFee(",
    "setTaxRate(",
    "setMaxTxAmount(",
    "setSwapEnabled(",
    "setTradingEnabled(",
    "multiTransfer(",
    "withdrawAll(",
    "emergencyWithdraw(",
    "selfDestruct(",
    "kill(",
];

/// Sözleşme kaynak kodunda sinsi kod imzalarını tarar.
///
/// # Arguments
/// * `source` - Solidity kaynak kodu
/// * `bytecode` - Derlenmiş bytecode (hash taahhüdü için)
/// * `timestamp` - Unix zaman damgası
pub fn detect_backdoors(
    source: &str,
    bytecode: &[u8],
    timestamp: u64,
) -> Vec<Finding> {
    let mut findings = Vec::new();
    let lowered = source.to_lowercase();

    for sig in BACKDOOR_SIGNATURES {
        if lowered.contains(sig) {
            // Exploit payload: imzayı çağıran bir işlem izi
            let payload = format!("call {} -> kullanıcı bakiyeleri donurulabilir", sig);
            let pov = crate::oracle::seal_pov_hash(payload.as_bytes(), bytecode, timestamp);

            findings.push(Finding {
                severity: if sig.contains("blacklist") || sig.contains("freeze") {
                    Severity::High
                } else {
                    Severity::Medium
                },
                vulnerability_type: format!("BACKDOOR_FUNCTION:{}", sig),
                pov_hash: crate::oracle::pov_hash_hex(&pov),
                remediation_locked: true,
                unlock_tier: Tier::Quick,
            });
        }
    }

    findings
}

/// Honeypot tespiti: satın almayı serbest bırakıp satışı engelleyen modeller.
pub fn detect_honeypot(source: &str, bytecode: &[u8], timestamp: u64) -> Vec<Finding> {
    let mut findings = Vec::new();
    let lowered = source.to_lowercase();

    // Klasik honeypot: sell devre dışı ama buy açık
    let sell_blocked = lowered.contains("sellingenabled = false") || lowered.contains("!sell");
    let buy_open = lowered.contains("buyenabled = true") || lowered.contains("tradingenabled");

    if sell_blocked && buy_open {
        let payload = b"honeypot: buy allowed, sell blocked -> funds locked";
        let pov = crate::oracle::seal_pov_hash(payload, bytecode, timestamp);

        findings.push(Finding {
            severity: Severity::Critical,
            vulnerability_type: "HONEYPOT_SELL_BLOCKED".to_string(),
            pov_hash: crate::oracle::pov_hash_hex(&pov),
            remediation_locked: true,
            unlock_tier: Tier::Fuzz,
        });
    }

    findings
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn blacklist_tespit() {
        let source = "function blacklist(address user) external onlyOwner { _blacklist[user] = true; }";
        let findings = detect_backdoors(source, b"0x6080", 1000);
        assert_eq!(findings.len(), 1);
        assert_eq!(findings[0].severity, Severity::High);
        assert!(findings[0].remediation_locked);
    }

    #[test]
    fn temiz_sozlesme() {
        let source = "function transfer(address to, uint256 amount) external returns (bool) { }";
        let findings = detect_backdoors(source, b"0x6080", 1000);
        assert!(findings.is_empty(), "Temiz sözleşmede bulgu olmamalı");
    }

    #[test]
    fn honeypot_tespit() {
        let source = "bool sellingEnabled = false; bool buyEnabled = true;";
        let findings = detect_honeypot(source, b"0x6080", 1000);
        assert_eq!(findings.len(), 1);
        assert_eq!(findings[0].severity, Severity::Critical);
    }

    #[test]
    fn pov_hash_kilitli_payload() {
        // Bulgunun payload'u görünür DEĞİL — yalnızca hash
        let findings = detect_backdoors(
            "function pause() external onlyOwner { _paused = true; }",
            b"0x6080",
            1000,
        );
        let f = &findings[0];
        assert_eq!(f.pov_hash.len(), 64, "Hex hash 64 karakter");
        // Payload metni finding'de YOK (kilitli)
        assert!(!format!("{:?}", f).contains("call pause"));
    }
}
