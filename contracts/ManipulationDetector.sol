// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ManipulationDetector — Zincir-üstü Manipülasyon Tespit Motoru
/// @author Cleanvest
/// @notice README dürüst sınır #5'in KAPANMASI: "manipülasyon tespit etmez"
///         artık geçerli DEĞİLDİR. Bu kütüphane, akademik literatürde
///         doğrulanmış ÜÇ tespit sinyalini zincir-üstü veriden hesaplar.
///
/// @dev AKADEMİK TEMEL (docs/arastirma/01, 2026-09-29 ile güncel):
///      1. **İşlem-sayısı/hacim orantısızlığı** — Zwydak et al. (Entropy 2026,
///         28(7), 804; arXiv:2607.13916): Bitget'te Mayıs 2025 ortasından
///         itibaren işlem SAYISI keskin artarken hacim/getiri orantılı
///         artmamış; düşük hacimli sayısız işlem + zayıf otokorelasyon +
///         azalmış multifraktal organizasyon = yapay işlem imzası.
///         => `volumePerTx` düşüşü wash-trade sinyalidir.
///      2. **Manipulation-as-a-Service** — Szwajcok et al. (CCS'26,
///         arXiv:2609.10246): manipülasyon dışarıdan SATIN ALINABİLİR bir
///         hizmettir; STRATEJİK aktörler borsa arayüzünü atlar.
///         => tespit, yalnızca operatörü değil KULLANICI tarafını da
///            denetlemelidir (imzalı emirler + rate-limit).
///      3. **Birleşimsel (complexity) ölçütler** — tekil eşikler yetersiz;
///         çok-sinyalli sürekli denetim gerekir (ManiScope, arXiv:2607.11451).
///         => bu yüzden TEK bir bool değil, 0-100 Risk SKORU döner.
///
///      ÖNEMLİ DÜRÜSTLÜK SINIRI: bu motor BİR HEURİSTİKTİR. Sonuç bir
///      "manipülasyon kanıtı" DEĞİL, bir **risk skorudur**. Zwydak et al.
///      kendi bulguları için wash-trade KANITI olmadığını açıkça belirtir —
///      biz de aynı disiplini koruruz: yüksek skor = İNCELEME GEREKTİREN
///      sinyal, otomatik dondurma DEĞİL. Nihai yargı insanındır
///      (docs/29_INSAN_KARARLARI.md).
library ManipulationDetector {
    // ============================================================
    // EŞİKLER (akademik bulgulara göre seçilmiştir, sabit-kodlu)
    // ============================================================

    /// @notice volumePerTx düşüşü: işlemsayısı↑ / hacim≈sabit oranı.
    /// @dev 3 = hacim/işlem medianın 3 katı DÜŞÜK olması sinyaldir.
    uint256 public constant VOLUME_PER_TX_DROP = 3;

    /// @notice Round-trip (A→B→A) tespiti: aynı adres çiftinin bir batch
    ///         içindeki karşılıklı hacmi, batch hacminin %40'ını aşarsa.
    uint256 public constant ROUND_TRIP_BPS = 4000; // %40

    /// @notice Aynı çiftin bir batch içinde tekrar sayısı (wash-trade imzası).
    uint256 public constant MAX_PAIR_REPEATS = 5;

    /// @notice Yüksek risk skoru eşiği (incelenmeli).
    uint256 public constant HIGH_RISK_THRESHOLD = 70;

    /// @notice Maksimum risk skoru (100).
    uint256 public constant MAX_SCORE = 100;

    /// @notice Batch içi tekil işlem çifti kaydı.
    struct TradePair {
        address maker;
        address taker;
        uint256 volume;
        uint256 count;
    }

    /// @notice Batch'in manipülasyon analiz sonucu.
    /// @dev Tüm alanlar KAMUSALDUR — zincir-üstü veriden üretilir.
    struct DetectionResult {
        uint256 riskScore; // 0-100 (0 = temiz, 100 = yüksek risk)
        bool volumePerTxDrop; // işlem sayısı↑ / hacim≈sabit (Zwydak sinyali)
        bool roundTripDetected; // A→B→A karşılıklı hacim eşiği aştı
        bool pairFlooding; // aynı çift tekrarı > MAX_PAIR_REPEATS
        uint256 volumePerTx; // hacim/işlem sayısı (1e18 = 1 USD)
        uint256 medianVolumePerTx; // önceki batch'lerin medyanı (baseline)
        uint256 pairCount; // tekil işlem çifti sayısı
        uint256 topPairShareBps; // en büyük çiftin batch'teki payı (bps)
    }

    /// @notice Önceki batch'lerin hacim/işlem istatistikleri (baseline).
    struct Baseline {
        uint256 totalVolume;
        uint256 totalTx;
        uint256 batchCount;
        uint256 lastVolumePerTx;
    }

    // ============================================================
    // ANA ANALİZ — batch içi işlem çiftlerinden risk skoru üret
    // ============================================================

    /// @notice Bir batch'in işlem çiftlerini analiz eder, risk skoru üretir.
    /// @dev Tüm sinyaller zincir-üstü veriden; harici oracle YOKTUR.
    /// @param pairs Batch içindeki işlem çiftleri (maker/taker/volume)
    /// @param totalVolume Batch toplam hacmi (1e18 = 1 USD)
    /// @param baseline Önceki batch'lerin hacim/işlem istatistiği
    function analyze(TradePair[] memory pairs, uint256 totalVolume, Baseline memory baseline)
        internal
        pure
        returns (DetectionResult memory r)
    {
        uint256 n = pairs.length;
        r.pairCount = n;

        // --- Sinyal 1: hacim/işlem orantısızlığı (Zwydak et al. 2026) ---
        uint256 txCount = 0;
        for (uint256 i = 0; i < n; i++) {
            txCount += pairs[i].count;
        }
        r.volumePerTx = txCount == 0 ? 0 : totalVolume / txCount;
        r.medianVolumePerTx = baseline.lastVolumePerTx;

        if (baseline.lastVolumePerTx > 0 && r.volumePerTx > 0) {
            // İşlem sayısı arttı ama hacim/işlem DÜŞTÜ: wash-trade imzası
            // Eşik: medianın 1/3'üne düşmüşse sinyal
            if (r.volumePerTx * VOLUME_PER_TX_DROP < baseline.lastVolumePerTx) {
                r.volumePerTxDrop = true;
            }
        }

        // --- Sinyal 2: round-trip (A→B→A) — en büyük çiftin payı ---
        uint256 topVolume = 0;
        uint256 topShareBps = 0;
        for (uint256 i = 0; i < n; i++) {
            if (pairs[i].volume > topVolume) {
                topVolume = pairs[i].volume;
                topShareBps = totalVolume == 0 ? 0 : (pairs[i].volume * 10_000) / totalVolume;
            }
        }
        r.topPairShareBps = topShareBps;
        if (topShareBps > ROUND_TRIP_BPS) {
            r.roundTripDetected = true;
        }

        // --- Sinyal 3: çift seli (aynı çiftin tekrarı) ---
        for (uint256 i = 0; i < n; i++) {
            if (pairs[i].count > MAX_PAIR_REPEATS) {
                r.pairFlooding = true;
                break;
            }
        }

        // --- Risk skoru: her sinyal ağırlıklı katkı sağlar ---
        // volumePerTxDrop: +40 (en güçlü akademik sinyal)
        // roundTrip: +35 (klasık wash-trade yapısı)
        // pairFlooding: +25 (düşük maliyetli spam)
        // Maksimum 100 (doyma)
        uint256 score = 0;
        if (r.volumePerTxDrop) score += 40;
        if (r.roundTripDetected) score += 35;
        if (r.pairFlooding) score += 25;
        if (score > MAX_SCORE) score = MAX_SCORE;
        r.riskScore = score;

        return r;
    }

    /// @notice Risk skoru yüksek mi? (incelenmeli — otomatik yaptırım DEĞİL)
    function isHighRisk(DetectionResult memory r) internal pure returns (bool) {
        return r.riskScore >= HIGH_RISK_THRESHOLD;
    }

    /// @notice Baseline'ı batch sonrası günceller (kayar pencere).
    /// @dev Basit üssel-kayar ortalama: yeni = (eski*7 + yeni*3) / 10.
    function updateBaseline(Baseline memory b, uint256 volume, uint256 txCount)
        internal
        pure
        returns (Baseline memory)
    {
        uint256 newPerTx = txCount == 0 ? b.lastVolumePerTx : volume / txCount;
        return Baseline({
            totalVolume: b.totalVolume + volume,
            totalTx: b.totalTx + txCount,
            batchCount: b.batchCount + 1,
            lastVolumePerTx: (b.lastVolumePerTx * 7 + newPerTx * 3) / 10
        });
    }

    /// @notice Tespit sonucunu insan-okunur etikete çevirir.
    /// @dev Satışta kullanılır: "temiz" / "düşük" / "orta" / "yüksek".
    function riskLabel(DetectionResult memory r) internal pure returns (string memory) {
        if (r.riskScore >= 70) return "YUKSEK";
        if (r.riskScore >= 40) return "ORTA";
        if (r.riskScore > 0) return "DUSUK";
        return "TEMIZ";
    }
}
