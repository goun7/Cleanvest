// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/CleanvestSettlement.sol";

/// @title Replay Protection Test Suite (DAR görev, 2026-09-29)
/// @notice README dürüst sınırı #2'nin kapanması: zincir-üstü nonce takibi.
///         Artık aynı (user, nonce) ikinci kez KULLANILAMAZ — fail-closed.
///         4 test: mutlu yol, replay red, kullanıcı izolasyonu, nonce boşluğu.
contract ReplayProtectionTest is Test {
    CleanvestSettlement public settlement;
    address public owner = address(0x0ABE);
    address public solver = address(0x5010);

    bytes32 constant BATCH_ID = keccak256("replay-batch-1");

    function setUp() public {
        settlement = new CleanvestSettlement();
        settlement.transferOwnership(owner);

        vm.prank(owner);
        settlement.registerSolver(solver);

        _settleBatch();
    }

    /// @dev Test batch'ini üretir ve kesinleştirir (nonce tüketimi öncesi zorunlu).
    function _settleBatch() internal {
        ICleanvestSettlement.MatchedBatch memory batch = ICleanvestSettlement.MatchedBatch({
            batchId: BATCH_ID,
            orderCommitmentRoot: keccak256("replay-root"),
            clearingPrice: 1_000 ether,
            totalVolume: 10_000 ether,
            solverSignature: ""
        });
        bytes memory p = abi.encode(
            keccak256(
                abi.encode(
                    batch.batchId, batch.orderCommitmentRoot, batch.clearingPrice, batch.totalVolume
                )
            )
        );
        vm.prank(solver);
        settlement.executeBatchSettlement(batch, p);
    }

    /// @dev Tek bir (user, nonce) tüketir.
    function _consume(address user, uint256 nonce) internal {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000;
        address[] memory users = new address[](1);
        users[0] = user;
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = nonce;

        vm.prank(solver);
        settlement.consumeNonces(amounts, users, nonces, BATCH_ID);
    }

    /// @dev Beklenen-revert testleri icin dizileri olusturur (external call
    ///      test frame'inde yapilir — helper frame'inde degil).
    function _order(address user, uint256 nonce)
        internal
        pure
        returns (uint256[] memory amounts, address[] memory users, uint256[] memory nonces)
    {
        amounts = new uint256[](1);
        amounts[0] = 1000;
        users = new address[](1);
        users[0] = user;
        nonces = new uint256[](1);
        nonces[0] = nonce;
    }

    // ============================================================
    // 1) MUTLU YOL — nonce kullan -> işlem geçerli, zincirde işaretli
    // ============================================================

    /// @notice İlk kez kullanılan nonce geçerlidir ve kamusal olarak işaretlenir.
    function testNonceFirstUseValid() public {
        assertFalse(settlement.isNonceConsumed(address(0xA11CE), 1), "once kullanilmamis olmali");

        _consume(address(0xA11CE), 1);

        assertTrue(settlement.isNonceConsumed(address(0xA11CE), 1), "nonce 1 artik tuketildi");
        // Farklı nonce aynı kullanıcıda hâlâ serbest
        assertFalse(settlement.isNonceConsumed(address(0xA11CE), 2), "nonce 2 hala serbest");
    }

    // ============================================================
    // 2) REPLAY — aynı nonce ikinci kez -> REVERT (ReplayDetected)
    // ============================================================

    /// @notice Aynı (user, nonce) ikinci kez reddedilir; revert verisi
    ///         saldırının KANITIDIR (kim, hangi nonce).
    function testReplaySameNonceRejected() public {
        _consume(address(0xA11CE), 42);

        // Replay girişimi — aynı imzalı yaprak yeniden oynatılıyor
        (uint256[] memory a, address[] memory u, uint256[] memory n) = _order(address(0xA11CE), 42);
        vm.prank(solver);
        vm.expectRevert(abi.encodeWithSelector(ReplayDetected.selector, address(0xA11CE), 42));
        settlement.consumeNonces(a, u, n, BATCH_ID);

        // Durum değişmedi: hâlâ tüketili (idempotent başarısızlık)
        assertTrue(settlement.isNonceConsumed(address(0xA11CE), 42), "durum degismedi");
    }

    // ============================================================
    // 3) KULLANICI İZOLASYONU — farklı kullanıcı, aynı nonce -> geçerli
    // ============================================================

    /// @notice Nonce alanı kullanıcıya özeldir: Alice'in nonce=1 ve Bob'un
    ///         nonce=1 birbirini etkilemez (replay anahtarı = (user, nonce)).
    function testSameNonceDifferentUsersIsolated() public {
        _consume(address(0xA11CE), 1);
        _consume(address(0xB0B), 1);

        assertTrue(settlement.isNonceConsumed(address(0xA11CE), 1), "Alice nonce 1");
        assertTrue(settlement.isNonceConsumed(address(0xB0B), 1), "Bob nonce 1 (izole)");

        // Alice'in nonce=1'i Bob'u etkilemedi; Bob tekrar deneyince reddedilir
        (uint256[] memory a, address[] memory u, uint256[] memory n) = _order(address(0xB0B), 1);
        vm.prank(solver);
        vm.expectRevert(abi.encodeWithSelector(ReplayDetected.selector, address(0xB0B), 1));
        settlement.consumeNonces(a, u, n, BATCH_ID);
    }

    // ============================================================
    // 4) TAHRİR — nonce'ı atla (1 -> 3) -> sıralı zorunluluk YOK
    // ============================================================

    /// @notice Sıralı nonce zorunluluğu yoktur (bashlike batch topolojisi):
    ///         1 atlanıp 3 kullanılabilir; atlanan 2 hâlâ geçerlidir.
    ///         Zorunluluk OLSAYDI batch'ler sıralı gelmediğinde tümü reddedilirdi.
    function testNonceGapAcceptedNoOrdering() public {
        _consume(address(0xA11CE), 1);
        _consume(address(0xA11CE), 3); // 2 atlandı

        assertTrue(settlement.isNonceConsumed(address(0xA11CE), 1), "nonce 1");
        assertTrue(settlement.isNonceConsumed(address(0xA11CE), 3), "nonce 3 (bosluklu)");
        assertFalse(settlement.isNonceConsumed(address(0xA11CE), 2), "nonce 2 hala serbest");

        // Atlanan nonce hâlâ kullanılabilir (geç gelen batch)
        _consume(address(0xA11CE), 2);
        assertTrue(
            settlement.isNonceConsumed(address(0xA11CE), 2), "geciken nonce 2 artik tuketildi"
        );
    }
}
