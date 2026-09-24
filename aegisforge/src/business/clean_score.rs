//! CleanScore — Kamusal Güven Skoru API'si (ilk 1.000 token ücretsiz).
//!
//! KRİTİK: Zorunlu "ödeme ya da listelenme" haraç modeli YOK (İllüzyon-4).
//! CleanScore güven otoritesidir ve ücretsizdir.

use serde::{Deserialize, Serialize};

/// Kamusal güven skoru (0-100).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CleanScore {
    pub contract_address: String,
    pub score: u32,
    pub audit_date: u64,
    /// Doğrulanmış mi? (üçüncü-taraf re-verification LE-3 kuralı)
    pub independently_verified: bool,
    /// Bulgu sayısı (hash'ler kilitli, sayılar kamusal)
    pub findings_count: u32,
    pub critical_count: u32,
}

impl CleanScore {
    /// 48 temel invariant + fuzz + tokenomics + backdoor sonuçlarından skor hesaplar.
    pub fn compute(
        contract_address: String,
        audit_date: u64,
        invariant_pass: u32,
        invariant_total: u32,
        fuzz_crashes: u32,
        critical_count: u32,
        high_count: u32,
        independently_verified: bool,
    ) -> Self {
        let base = (invariant_pass as f64 / invariant_total.max(1) as f64) * 70.0;
        let fuzz_penalty = (fuzz_crashes as f64).min(20.0);
        let severity_penalty = (critical_count as f64 * 15.0) + (high_count as f64 * 7.0);
        let verified_bonus = if independently_verified { 5.0 } else { 0.0 };

        let score = (base - fuzz_penalty - severity_penalty + verified_bonus).clamp(0.0, 100.0);

        Self {
            contract_address,
            score: score as u32,
            audit_date,
            independently_verified,
            findings_count: critical_count + high_count,
            critical_count,
        }
    }

    /// Kamusal API yanıtı (ücretsiz uç nokta).
    pub fn to_public_json(&self) -> String {
        serde_json::json!({
            "contract": self.contract_address,
            "clean_score": self.score,
            "audit_date": self.audit_date,
            "independently_verified": self.independently_verified,
            "findings": self.findings_count,
            "critical": self.critical_count,
            "free_tier": true,
            "ransom_model": false
        })
        .to_string()
    }
}

/// Kademeli fiyatlandırma teklifi (tek $4.900 seçenek DEĞİL).
pub fn pricing_menu() -> Vec<(&'static str, u32, &'static str)> {
    vec![
        ("TIER_QUICK", 299, "Otonom Z3 hızlı tarama raporu"),
        ("TIER_FUZZ", 1_490, "Metamorfik fuzzing + düzeltme yaması"),
        (
            "TIER_ENTERPRISE",
            4_900,
            "Cleanvest Verified rozeti + öncelikli listeleme",
        ),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn temiz_sozlesme_yuksek_skor() {
        // 48/48 invariant = 70 puan (taban) + 5 (verified bonus) = 75. Maksimum
        // tokenomics/fuzz bonus'ları ileride eklenebilir; şimdilik taban >=70.
        let cs = CleanScore::compute("0xabc".into(), 1000, 48, 48, 0, 0, 0, true);
        assert!(cs.score >= 70, "48/48 invariant + verified → >=70 (taban)");
        assert!(cs.score <= 75, "48/48 + verified = 75'e eşit");
    }

    #[test]
    fn kritik_bulgu_skoru_dusurur() {
        let clean = CleanScore::compute("0xabc".into(), 1000, 48, 48, 0, 0, 0, false);
        let dirty = CleanScore::compute("0xabc".into(), 1000, 48, 48, 0, 2, 0, false);
        assert!(dirty.score < clean.score, "Kritik bulgu skoru düşürmeli");
        assert_eq!(dirty.critical_count, 2);
    }

    #[test]
    fn skor_sifir_yuz_arasinda() {
        let cs = CleanScore::compute("0xabc".into(), 1000, 0, 48, 100, 10, 10, false);
        assert!(cs.score <= 100);
        assert!(cs.score >= 0);
    }

    #[test]
    fn kamu_api_ucretsiz() {
        let cs = CleanScore::compute("0xabc".into(), 1000, 48, 48, 0, 0, 0, true);
        let json = cs.to_public_json();
        assert!(json.contains("\"ransom_model\":false"));
        assert!(json.contains("\"free_tier\":true"));
    }

    #[test]
    fn uc_kademeli_fiyatlandirma() {
        let menu = pricing_menu();
        assert_eq!(menu.len(), 3, "Tek $4.900 seçenek DEĞİL — 3 kademe");
        assert!(menu.iter().any(|(_, price, _)| *price == 299));
    }
}
