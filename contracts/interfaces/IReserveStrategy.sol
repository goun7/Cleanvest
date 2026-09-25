// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IReserveStrategy - Cleanvest Reserve Katmani Arayuzu
/// @notice 3 kademeli reserve yonetimi: Aave V3 / OUSG / BUIDL / Prime / idle.
/// @dev Master sartname v1.2: SAFE mod (12% idle) varsayilan. OPTIMIZE mod
///      Aave utilization feed'i baglanana kadar ACILAMAZ.
interface IReserveStrategy {
    /// @notice Reserve kompozisyon kademesi.
    enum ReserveTier {
        Tier0,      // TVL < $250k: %73 Aave / %12 idle / %15 Prime
        Tier1,      // $250k-$12.5M: %40 OUSG / %33 Aave / %12 idle / %15 Prime
        Tier2,      // >= $12.5M: %40 BUIDL / %33 Aave / %12 idle / %15 Prime
        TierOptimize // OPTIMIZE: %40 OUSG / %42 Aave / %3 float / %15 Prime
    }

    /// @notice Bir kadememin hedef dagilimi (bps cinsinden, toplam 10000).
    struct Allocation {
        uint16 aaveBps;      // Aave V3 USDC Base
        uint16 rwaBps;       // OUSG (Tier1) veya BUIDL (Tier2), Tier0'da 0
        uint16 primeBps;     // Aave Prime USDC
        uint16 idleBps;      // Idle USDC (SAFE modda %12)
    }

    /// @notice TVL'e gore aktif kademe.
    function activeTier() external view returns (ReserveTier tier);

    /// @notice Verilen kademenin hedef dagilimi (bps).
    function targetAllocation(ReserveTier tier) external pure returns (Allocation memory);

    /// @notice Mevcut dagilimi kademeye gore rebalans et.
    function rebalance() external;

    /// @notice Aave V3 pool'a USDC supply (yield kazanir).
    function supplyToAave(uint256 amount) external;

    /// @notice Aave V3 pool'dan USDC cek (itfa icin likidite).
    function withdrawFromAave(uint256 amount) external;

    /// @notice Aave utilization devre-kesici tetiklendi mi (OPTIMIZE mod).
    function utilizationCircuitBreakerActive() external view returns (bool);
}
