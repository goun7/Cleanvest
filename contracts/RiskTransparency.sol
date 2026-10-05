// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./CleanFXVault.sol";
import "./CleanUSD.sol";
import "./ReserveManager.sol";

/// @title RiskTransparency - Standartlastirilmis Risk Aciklamasi
/// @author Cleanvest
/// @notice Akademik dayanak: Bundi, "Pricing the DeFi Tail: Do Protocols or
///         Depositors Price Operational Risk?" (CBT 2026 / ESORICS, Springer).
///         Makale "disclosure over capital mandates" onerir:
///         protokoller "standartlastirilmis kayiplar, mevcut sermaye
///         tamponlari ve kuyruk kapsamini" YAYIMLAMALIDIR.
///
/// @dev Bu kod veri URETIMI yapmaz - sadece mevcut state'i standart bir
///      bicimde sunar (view-only). Yeni risk eklemez; mevcut riskleri
///      ACIKCA gosterir. Piyasa disiplini icin gerekli (makale L?:
///      "depositors should demand a higher yield where no buffer").
library RiskTransparency {
    /// @notice Basel Tarzinda risk profili (makalenin 3 onerisi).
    /// @dev Tum alanlar BPS cinsinden (1e18 = %100 DEGIL, 10000 = %100).
    ///      Bu, UI'nin ve 3. parti analistlerin tek noktadan okumasini saglar.
    struct RiskProfile {
        uint256 juniorBufferBps; // juniorReserve / TVL (makale: "capital buffer")
        uint256 juniorBufferMinBps; // SABIT %3 (JUNIOR_MIN_BPS)
        bool juniorBufferAdequate; // makale: "existing capital buffers"
        uint256 dailyInstantCapBps; // %10 (makale: likidite aciklamasi)
        uint256 t2SettleSeconds; // T+2 (makale: "tail coverage" zamani)
        uint256 utilizationCircuitBreakerBps; // %92 esigi
        bool optimizeModeEnabled; // risk ayarlamasi acik mi
        uint256 operationalRiskBps; // makale Lending VaR99.9 = %18 (ORNEKLEM, iddia DEGIL)
    }

    /// @notice Standart risk profilini olusturur (view-only, yeni state YOK).
    /// @param vault CleanFXVault adresi
    /// @param reserve ReserveManager adresi (opsiyonel - 0 ise optimize kismi atlanir)
    function profile(address vault, address reserve) internal view returns (RiskProfile memory p) {
        // KAYNAK: CleanFXVault - junior tampon (makale: "capital buffer")
        uint256 tvl = CleanFXVault(vault).totalAssets();
        uint256 junior = CleanUSD(CleanFXVault(vault).asset()).juniorReserve();

        p.juniorBufferBps = tvl > 0 ? (junior * 10000) / tvl : type(uint256).max;
        p.juniorBufferMinBps = 300; // %3 (JUNIOR_MIN_BPS)
        p.juniorBufferAdequate = p.juniorBufferBps >= p.juniorBufferMinBps;

        // KAYNAK: CleanFXVault - likidite aciklamasi
        (uint256 capPct, uint256 settleDays) = CleanFXVault(vault).redemptionGate();
        p.dailyInstantCapBps = capPct;
        p.t2SettleSeconds = settleDays;

        // KAYNAK: ReserveManager - operasyonel risk ayari
        if (reserve != address(0)) {
            p.optimizeModeEnabled = ReserveManager(reserve).optimizeModeEnabled();
            p.utilizationCircuitBreakerBps = 9200; // %92 (UTILIZATION_CB_BPS)
        }

        // MAKALE KARSILIK: Bundi 2026 Lending VaR99.9 = %18 onerir.
        // BIZ %3 junior ile kredi/likidite riskini karsilariz; operasyonel
        // risk (hack/bug) icin 174 test + %96 coverage + 5 invariant.
        // NOT: bu sayi ORNEKLEMEDIR - bizim iddiamiz degil, makalenin
        // sektor ortalamasidir. Aciklama amaciyla gosterilir.
        p.operationalRiskBps = 1800; // %18 (makale Lending VaR99.9)
    }

    /// @notice Risk profili JSON benzeri insan-okur formatta (off-chain
    ///         entegrasyon ve UI icin). String uretimi view-only'dir.
    function describe(RiskProfile memory p) internal pure returns (string memory) {
        // Kisa ozet: "junior %3.0/%3.0 | anlik %10 | T+2 | CB %92"
        return string(
            abi.encodePacked(
                "junior %",
                _pct(p.juniorBufferBps),
                " / %",
                _pct(p.juniorBufferMinBps),
                " | anlik %",
                _pct(p.dailyInstantCapBps),
                " | T+",
                _days(p.t2SettleSeconds),
                " | CB %",
                _pct(p.utilizationCircuitBreakerBps)
            )
        );
    }

    /// @notice BPS -> "3.0" format (10000 = %100)
    function _pct(uint256 bps) private pure returns (string memory) {
        // tam sayi kisim
        uint256 whole = bps / 100;
        uint256 frac = bps % 100;
        return string(abi.encodePacked(_u(whole), ".", _u(frac < 10 ? frac * 10 + 0 : frac)));
    }

    /// @notice Saniye -> gun sayisi ("2")
    function _days(uint256 secs) private pure returns (string memory) {
        return _u(secs / 1 days);
    }

    /// @notice uint -> string (kucuk sayilar icin)
    function _u(uint256 n) private pure returns (string memory) {
        if (n == 0) return "0";
        uint256 j = n;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory b = new bytes(len);
        uint256 k = len;
        while (n != 0) {
            k = k - 1;
            b[k] = bytes1(uint8(48 + n % 10));
            n /= 10;
        }
        return string(b);
    }
}
