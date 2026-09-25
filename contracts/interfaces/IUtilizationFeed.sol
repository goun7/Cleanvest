// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IUtilizationFeed - Aave Utilization Oracle Arayuzu
/// @notice Aave V3 pool utilization (bps cinsinden) okur.
/// @dev Harici Chainlink-style feed. Uniswap TWAP YASAK - dairesel fiyat.
///      Utilization > %92 (9200 bps) ise Cleanvest'te devre-kesici tetiklenir:
///      anlik itfa T+2 kuyruguna duser (sosyellesme riski).
interface IUtilizationFeed {
    /// @return utilizationBps Aave pool utilization, 0-10000 (0=%0, 10000=%100)
    function utilizationBps() external view returns (uint256);
}
