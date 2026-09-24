// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ICleanvestSettlement — Cleanvest HEX Batch Settlement Interface
/// @notice Budish FBA (400ms) batch netting + RFQ solver settlement layer.
/// @dev Kanonik arayüz — master şartname v1.2. `orderCommitmentRoot` ZORUNLUDUR
///      (front-run/race kalkanı: kullanıcı emir taahhüdü Merkle kökü).
interface ICleanvestSettlement {
    struct MatchedBatch {
        bytes32 batchId;
        bytes32 orderCommitmentRoot; // Kullanıcı emir taahhüdü Merkle kökü (front-run/race kalkısı)
        uint256 clearingPrice; // Tek orta takas fiyatı (Uniform Clearing Price)
        uint256 totalVolume;
        bytes solverSignature; // RFQ çözücü imzası (artık hacim varsa)
    }

    /// @notice Bir FBA batch'ini zincir üstünde kesinleştirir.
    /// @param batch Eşleşen batch meta verisi
    /// @param proof ZK/Validium kesinleştirme kanıtı
    function executeBatchSettlement(MatchedBatch calldata batch, bytes calldata proof) external;

    /// @notice Batch'in geçerlilik kuralı: anti-collusion bound.
    /// @dev P_best <= P_oracle * (1 + eps_bound(dQ)) olmalıdır. eps_bound boyut-farklıdır:
    ///      eps_bound(dQ) = eps0 + kappa * (dQ / L_onchain), eps0 = 0.15%.
    ///      Düz 0.15% KULLANILMAZ — kendi büyük emirlerimizi kronik reddeder.
    function antiCollusionBound(uint256 deltaQ, uint256 liquidityOnchain) external view returns (uint256 epsBound);

    /// @notice Soğuk başlangıç emir tavanı (Faz 3 açılışında $5.000/emir).
    /// @dev Tahta likiditesi arttıkça tavan otomatik kalkar (lift trigger).
    function orderSizeCap() external view returns (uint256);
}
