// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
// BRACED import (2026-09-30): her iki kontrat da en üst düzeyde
// `error InvalidSignatureS();` tanımlar — tüm-dosya import'u isim
// çakışması ("Identifier already declared") yaratır; bu yüzden yalnızca
// tip adları içe aktarılır. Davranış veya test içeriği DEĞİŞMEZ.
import {ProofOfLiabilities} from "../contracts/ProofOfLiabilities.sol";
import {CleanvestSettlement} from "../contracts/CleanvestSettlement.sol";

/// @title Domain Separation Test Suite (DAR görev, 2026-09-29)
/// @notice README dürüst sınırının kapanması: imzanın **alan-ayrımı (domain
///         separation)** artık MEVCUTTUR — EIP-712 ile. İmza
///         (name, version, chainId, verifyingContract) alanına bağlıdır:
///         aynı imza başka bir kontratta (cross-contract) veya başka bir
///         zincirde (cross-chain) GEÇERLİ DEĞİLDİR.
/// @dev 5 test: mutlu yol (PoL + Settlement), cross-contract saldırı RED,
///      cross-chain saldırı RED, domain tahriri RED, legacy EIP-199 yolu
///      hâlâ çalışıyor (geriye dönük uyum).
contract DomainSeparationTest is Test {
    ProofOfLiabilities public pol;
    CleanvestSettlement public settlement;

    /// @notice Standart anvil test anahtarı #0 (test-only, PUBLIC).
    ///         anvil --mnemonic "test test ... junk" ile üretilir.
    ///         PRIVATE_KEY DEĞİL — mainnet değeri YOK.
    uint256 constant ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address constant ANVIL_ADDR = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    /// @notice Anvil varsayılan zincir kimliği (forge test).
    uint256 constant ANVIL_CHAIN_ID = 31337;

    /// @notice Test yaprakları (tek-yapraklı ağaç: kök = yaprak, proof = "").
    uint256 constant BALANCE = 1_000 ether;
    uint256 constant AMOUNT = 500 ether;
    uint256 constant NONCE = 7;

    function setUp() public {
        pol = new ProofOfLiabilities();
        settlement = new CleanvestSettlement();
    }

    // ============================================================
    // YARDIMCILAR
    // ============================================================

    /// @dev Özet üzerine EIP-712 imzası üretir (vm.sign özeti OLDUĞU GİBİ
    ///      imzalar; EIP-191 sarmalama YAPMAZ — özet "\x19\x01" önekini
    ///      taşır). Geri dönüş: r(32) + s(32) + v(1) = 65 bayt.
    function _signDigest(bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ANVIL_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @dev Legacy EIP-191 imzası (geriye dönük uyum testi için).
    function _signEip191(bytes32 hash) internal pure returns (bytes memory) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        return _signDigest(digest);
    }

    /// @dev PoL'de domain-aware fail-closed yayın yapar; epoch döner.
    function _publishDomainPoL() internal returns (uint256 epoch) {
        address[] memory users = new address[](1);
        users[0] = ANVIL_ADDR;
        uint256[] memory balances = new uint256[](1);
        balances[0] = BALANCE;
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = _signDigest(pol.liabilityDomainDigest(ANVIL_ADDR, BALANCE, 1));

        pol.publishLiabilitiesFromSignedLeavesWithDomain(users, balances, sigs);
        return 1;
    }

    // ============================================================
    // 1) MUTLU YOL — doğru domain + doğru imza → GEÇERLİ (PoL + Settlement)
    // ============================================================

    /// @notice Doğru domain (bu kontrat, bu zincir) ile imzalanmış yaprak
    ///         hem PoL'de hem de Settlement'te GEÇERLİDİR.
    function testDomainAwareHappyPath() public {
        assertEq(block.chainid, ANVIL_CHAIN_ID, "anvil zincir kimligi bekleniyor");

        // --- ProofOfLiabilities ---
        uint256 epoch = _publishDomainPoL();
        bytes32 root = pol.epochRoot(epoch);

        // domain-aware doğrulama: imza geçerli + Merkle inclusion geçerli
        assertTrue(
            pol.verifyLiabilityWithDomain(ANVIL_ADDR, BALANCE, epoch, _signDigest(
                pol.liabilityDomainDigest(ANVIL_ADDR, BALANCE, epoch)), ""),
            "PoL: dogru domain imzasi gecerli olmali"
        );

        // domain separator kamusal ve deterministik
        bytes32 sep = pol.domainSeparator();
        assertNotEq(sep, bytes32(0), "domain separator sifir olamaz");
        assertEq(pol.domainSeparator(), sep, "domain separator deterministik");

        // --- CleanvestSettlement ---
        bytes32 leaf = settlement.leafHash(AMOUNT, ANVIL_ADDR, NONCE);
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;

        assertTrue(
            settlement.verifySignedOrderWithDomain(
                AMOUNT,
                ANVIL_ADDR,
                NONCE,
                _signDigest(settlement.orderDomainDigest(AMOUNT, ANVIL_ADDR, NONCE)),
                "",
                settlement.computeRoot(leaves)
            ),
            "Settlement: dogru domain imzasi gecerli olmali"
        );
    }

    // ============================================================
    // 2) CROSS-CONTRACT SALDIRISI — aynı imza, farklı verifyingContract → RED
    // ============================================================

    /// @notice Saldırı: polA için üretilmiş bir imza, polB'de (farklı adres)
    ///         yeniden gösterilir. Domain separator farklı olduğundan
    ///         özet farklıdır → ecrecover farklı adres → REVERT.
    ///         Bu, README sınırının TAM kanıtıdır: "bir imzadan ikinci bir
    ///         gösterim" artık MÜMKÜN DEĞİLDİR.
    function testCrossContractReplayReverted() public {
        // polA'da domain-aware yayın yap (imzalar polA'nın adresine bağlı)
        uint256 epoch = _publishDomainPoL();
        bytes32 root = pol.epochRoot(epoch);
        bytes memory sigA = _signDigest(pol.liabilityDomainDigest(ANVIL_ADDR, BALANCE, epoch));

        // AYNI kökü ikinci bir kontratta yayınla (adres farklı!)
        ProofOfLiabilities polB = new ProofOfLiabilities();
        // legacy kök yayın yoluyla aynı epoch/kökü kur (yaprak algoritması aynı)
        polB.publishLiabilities(root, BALANCE, 1);

        // Saldırı: polA'nın imzasını polB'de göster
        vm.expectRevert("EIP-712 domain imzasi gecersiz");
        polB.verifyLiabilityWithDomain(ANVIL_ADDR, BALANCE, epoch, sigA, "");

        // İyi-cüzdan kanıtı: polB için doğru domain imzası hâlâ geçerli
        bytes memory sigB = _signDigest(polB.liabilityDomainDigest(ANVIL_ADDR, BALANCE, epoch));
        assertTrue(
            polB.verifyLiabilityWithDomain(ANVIL_ADDR, BALANCE, epoch, sigB, ""),
            "polB kendi domain imzasi gecerli (saldiri onu etkilemedi)"
        );

        // Domain separator'ları gerçekten farklı (adres bağlı)
        assertNotEq(pol.domainSeparator(), polB.domainSeparator(), "ayri kontratlar ayri domain");

        // --- Settlement için aynı saldırı ---
        bytes32 leaf = settlement.leafHash(AMOUNT, ANVIL_ADDR, NONCE);
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;
        bytes32 sRoot = settlement.computeRoot(leaves);
        bytes memory sSig = _signDigest(settlement.orderDomainDigest(AMOUNT, ANVIL_ADDR, NONCE));

        CleanvestSettlement settlementB = new CleanvestSettlement();
        assertFalse(
            settlementB.verifySignedOrderWithDomain(AMOUNT, ANVIL_ADDR, NONCE, sSig, "", sRoot),
            "Settlement: baska kontratin imzasi REDDEDILMELI"
        );
    }

    // ============================================================
    // 3) CROSS-CHAIN SALDIRISI — aynı imza, farklı chainId → RED
    // ============================================================

    /// @notice Saldırı: zincir 31337'de üretilmiş imza, zincir 1'de
    ///         (farklı chainId) yeniden gösterilir. Domain separator
    ///         block.chainid içerir → özet farklı → REVERT.
    function testCrossChainReplayReverted() public {
        uint256 epoch = _publishDomainPoL();
        bytes memory sig = _signDigest(pol.liabilityDomainDigest(ANVIL_ADDR, BALANCE, epoch));

        // Zincir kimliğini değiştir (anvil'de mainnet fork simülasyonu)
        vm.chainId(1);
        assertEq(block.chainid, 1, "zincir kimligi degisti");

        // Saldırı: 31337'nin imzası zincir 1'de reddedilir
        vm.expectRevert("EIP-712 domain imzasi gecersiz");
        pol.verifyLiabilityWithDomain(ANVIL_ADDR, BALANCE, epoch, sig, "");

        // Eski zincir kimliğine dön
        vm.chainId(ANVIL_CHAIN_ID);
        assertTrue(
            pol.verifyLiabilityWithDomain(ANVIL_ADDR, BALANCE, epoch, sig, ""),
            "orijinal zincirde imza gecerli (eski duruma donus temiz)"
        );
    }

    // ============================================================
    // 4) TAHRİR — domain'i değiştir (versiyon) → RED
    // ============================================================

    /// @notice Domain'in herhangi bir alanı değişirse imza GEÇERSİZDİR.
    /// @dev Sürüm "1" yerine "2" (veya yanlış name) ile imzalanmış bir
    ///      imza, kontratın gerçek domain'iyle uyuşmaz → REVERT.
    ///      Bu, domain-separator'un bütünlüğünü kanıtlar.
    function testDomainTamperRejected() public {
        uint256 epoch = _publishDomainPoL();

        // Tahrir edilmiş domain: versiyon "2" (gerçek "1")
        bytes32 tamperedDomain = keccak256(
            abi.encode(
                // EIP712Domain typehash (ProofOfLiabilities ile aynı sabit)
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Cleanvest-ProofOfLiabilities")),
                keccak256(bytes("2")), // <-- TAHRİR: sürüm 2
                block.chainid,
                address(pol)
            )
        );
        bytes32 structHash = pol.liabilityLeafStructHash(ANVIL_ADDR, BALANCE, epoch);
        bytes32 tamperedDigest = keccak256(abi.encodePacked("\x19\x01", tamperedDomain, structHash));

        // Tahrir edilmiş domain imzası REDDEDİLİR
        vm.expectRevert("EIP-712 domain imzasi gecersiz");
        pol.verifyLiabilityWithDomain(ANVIL_ADDR, BALANCE, epoch, _signDigest(tamperedDigest), "");

        // Name tahriri de reddedilir
        bytes32 nameTampered = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Cleanvest-Evil")), // <-- TAHRİR: name
                keccak256(bytes("1")),
                block.chainid,
                address(pol)
            )
        );
        bytes32 evilDigest = keccak256(
            abi.encodePacked("\x19\x01", nameTampered, structHash)
        );
        vm.expectRevert("EIP-712 domain imzasi gecersiz");
        pol.verifyLiabilityWithDomain(ANVIL_ADDR, BALANCE, epoch, _signDigest(evilDigest), "");
    }

    // ============================================================
    // 5) LEGACY YOL — EIP-191 imzaları hâlâ çalışıyor (geriye dönük uyum)
    // ============================================================

    /// @notice EIP-712 eklenmesi LEGACY yolu KIRMAZ: eski EIP-191 imzaları
    ///         hem PoL'de (publishLiabilitiesFromSignedLeaves +
    ///         verifyLiability) hem de Settlement'te (verifySignedOrder)
    ///         çalışmaya devam eder. Bu, R9-2 tarzı geriye dönük uyumdur.
    function testLegacyEip191PathStillWorks() public {
        // --- PoL legacy: EIP-191 imzalı fail-closed yayın ---
        address[] memory users = new address[](1);
        users[0] = ANVIL_ADDR;
        uint256[] memory balances = new uint256[](1);
        balances[0] = BALANCE;
        bytes[] memory sigs = new bytes[](1);
        bytes32 legacyLeaf = keccak256(abi.encode(ANVIL_ADDR, BALANCE, 1));
        sigs[0] = _signEip191(legacyLeaf);

        pol.publishLiabilitiesFromSignedLeaves(users, balances, sigs);
        assertEq(pol.currentEpoch(), 1, "legacy PoL yayini basarili");
        assertTrue(pol.epochSignatureEnforced(1), "legacy yol da fail-closed isaretli");

        // legacy verifyLiability hâlâ EIP-191 ile çalışır
        assertTrue(
            pol.verifyLiability(ANVIL_ADDR, BALANCE, 1, _signEip191(legacyLeaf), ""),
            "PoL legacy EIP-191 dogrulama hala gecerli"
        );

        // --- Settlement legacy: EIP-191 verifySignedOrder ---
        bytes32 leaf = settlement.leafHash(AMOUNT, ANVIL_ADDR, NONCE);
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;

        assertTrue(
            settlement.verifySignedOrder(leaf, _signEip191(leaf), ANVIL_ADDR, "", settlement.computeRoot(leaves)),
            "Settlement legacy EIP-191 dogrulama hala gecerli"
        );

        // ÇAPRAZ-UYUMSUZLUK KANITI: EIP-712 imzası legacy yolda GEÇERSİZ
        // (alan-ayrımı olmayan legacy özet, domain özetiyle uyuşmaz) ve
        // legacy EIP-191 imzası domain-aware yolda GEÇERSİZDİR.
        assertFalse(
            settlement.verifySignedOrder(leaf, _signDigest(
                settlement.orderDomainDigest(AMOUNT, ANVIL_ADDR, NONCE)), ANVIL_ADDR, "",
                settlement.computeRoot(leaves)),
            "EIP-712 imzasi legacy EIP-191 yolunda GECERSIZ olmali"
        );
        assertFalse(
            settlement.verifySignedOrderWithDomain(
                AMOUNT, ANVIL_ADDR, NONCE, _signEip191(leaf), "",
                settlement.computeRoot(leaves)),
            "legacy EIP-191 imzasi domain-aware yolda GECERSIZ olmali"
        );
    }
}
