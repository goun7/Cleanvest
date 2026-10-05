// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title MEVShield — Commit-Reveal MEV Koruması
/// @author Cleanvest
/// @notice README dürüst sınır #3'ün KAPANMASI: "MEV'den tam bağışık DEĞİL"
///         ifadesi artık DARALTILMIŞTIR. Batch-önü (pre-batch) sıralama
///         sömürüsü artık yapısal olarak ENGELLENİR.
///
/// @dev AKADEMİK TEMEL (docs/arastirma/02, 2026-09-29 ile güncel):
///      NeurIPS 2026 bulgusu: sandwich saldırıları için "alt-sınır gizliliği"
///      (sub-threshold privacy) YETERLİDİR — yani tam gizlilik (zk) şart
///      değildir; saldırganın emir miktarını GÖRMESİNİ engellemek yeter.
///      Commit-reveal tam olarak bunu sağlar:
///        1. Solver batch'I GİZLİ bir hash'e commit eder (miktar görülmez)
///        2. Bu commit KİLİTLİDİR — sonradan değiştirilemez
///        3. Reveal aşamasında batch içeriği açılır; zincir commit'le uyuşmak
///           ZORUNDADIR (uyumsuz = revert)
///      Böylece MEV bot'u commit sırasında emirleri GÖREMEZ (front-run yok),
///      reveal'dan sonra ise değiştiremez (back-run değil, kilitli taahhüt).
///
///      KALAN DÜRÜST SINIR (küçüldü, kapanmadı): batch'ler ARASI kuyruk
///      sırası hâlâ hash-time-lock'a bağlıdır. Tam bağışıklık için
///      şifreli-mempool (ShieldedMempool) gerekir — ekosistem projesi.
library MEVShield {
    /// @notice Commit-reveal penceresi: minimum batch sayısı reveal öncesi.
    /// @dev 1 = bir sonraki batch'te reveal edilebilir. Daha fazla = daha
    ///      güçlü ama daha yavaş. 1, T_BATCH_MS=400ms ile uyumludur.
    uint256 public constant MIN_COMMIT_AGE = 1;

    /// @notice Commit durumu.
    enum CommitState {
        None, // commit yok
        Committed, // hash kilitli, reveal bekliyor
        Revealed // açıldı ve settle edildi
    }

    /// @notice Bir batch'in commit-reveal durumu.
    struct CommitRecord {
        CommitState state;
        bytes32 commitmentHash; // keccak256(batchId || root || price || volume)
        uint256 committedAtBatch; // hangi batch sırasında commit edildi
        address committer; // solver (sorumlu)
    }

    /// @notice Commit hash'ini hesaplar (solver ve zincir-üstü ile birebir).
    /// @dev Açık API: herkes commit'in doğruluğunu bağımsız hesaplayabilir.
    function computeCommitment(
        bytes32 batchId,
        bytes32 orderCommitmentRoot,
        uint256 clearingPrice,
        uint256 totalVolume
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(batchId, orderCommitmentRoot, clearingPrice, totalVolume));
    }

    /// @notice Commit geçerli mi? (state + hash + yaş kontrolü)
    /// @dev REVERT yerine bool döner — çağıran karar versin (esnek API).
    function canReveal(
        CommitRecord memory rec,
        bytes32 batchId,
        bytes32 orderCommitmentRoot,
        uint256 clearingPrice,
        uint256 totalVolume,
        uint256 currentBatchSeq
    ) internal pure returns (bool) {
        if (rec.state != CommitState.Committed) return false;
        if (
            rec.commitmentHash
                != computeCommitment(batchId, orderCommitmentRoot, clearingPrice, totalVolume)
        ) {
            return false;
        }
        // Yaş kontrolü: en az MIN_COMMIT_AGE batch geçmeli
        if (currentBatchSeq < rec.committedAtBatch + MIN_COMMIT_AGE) return false;
        return true;
    }

    /// @notice Commit sonrası state güncellemesi.
    function markCommitted(
        CommitRecord memory rec,
        bytes32 commitmentHash,
        uint256 batchSeq,
        address committer
    ) internal pure returns (CommitRecord memory) {
        rec.state = CommitState.Committed;
        rec.commitmentHash = commitmentHash;
        rec.committedAtBatch = batchSeq;
        rec.committer = committer;
        return rec;
    }

    /// @notice Reveal sonrası state güncellemesi.
    function markRevealed(CommitRecord memory rec) internal pure returns (CommitRecord memory) {
        rec.state = CommitState.Revealed;
        return rec;
    }
}
