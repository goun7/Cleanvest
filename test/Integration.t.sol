// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/CleanUSD.sol";
import "../contracts/CleanFXVault.sol";
import "../contracts/ReserveManager.sol";
import "../contracts/CleanvestSettlement.sol";
import "../contracts/ListingGate.sol";
import "../contracts/UniswapProxy.sol";
import "../contracts/interfaces/ICleanvestSettlement.sol";
import "../contracts/interfaces/IReserveStrategy.sol";

/// @title Integration Test - Uctan Uca Cleanvest Ekosistemi
/// @notice 6 sozlesmenin birlikte calistigini kanitlar.
/// @dev Senaryo: USDC/ETH -> cUSD mint -> scUSD vault -> reserve -> tier ->
///      redeem -> settlement batch -> listing gate -> PoV taahhudu
contract IntegrationTest is Test {
    // --- Ana sozlesmeler ---
    CleanUSD public cUSD;
    CleanFXVault public vault; // asset = cUSD
    ReserveManager public reserve;
    CleanvestSettlement public settlement;
    ListingGate public gate;
    UniswapProxy public proxy;

    // --- Aktorler ---
    address public founder = address(0xF0D5000);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public oracle = address(0xA615);
    address public solver = address(0x5010);
    address public router = address(0x5047);

    function setUp() public {
        vm.deal(founder, 1_000_000 ether);

        // 1. Temel: CleanUSD (sabit $1.00, REBASE YOK)
        cUSD = new CleanUSD();
        cUSD.transferOwnership(founder);

        // 2. Vault: asset = cUSD (kullanici cUSD yatirir, scUSD alir)
        vault = new CleanFXVault(address(cUSD));
        vault.transferOwnership(founder);

        // 3. Reserve: Aave katmani
        reserve = new ReserveManager(address(cUSD));
        reserve.transferOwnership(founder);

        // 4. Settlement: HEX borsa
        settlement = new CleanvestSettlement();
        settlement.transferOwnership(founder);

        // 5. Listing gate
        gate = new ListingGate();
        gate.transferOwnership(founder);

        // 6. Uniswap proxy
        proxy = new UniswapProxy(router);
        proxy.transferOwnership(founder);

        // Aktorleri fundla
        vm.deal(alice, 1_000_000 ether);
        vm.deal(bob, 1_000_000 ether);
    }

    // =================================================================
    // SENARYO 1: Yield Akisi (Faz-2) - cUSD -> scUSD -> reserve -> redeem
    // =================================================================

    /// @notice Tam yield dongusu: seed -> mint -> deposit -> tier -> redeem
    /// @notice Batch icin gecerli kanit uretir.
    function _makeProof(
        bytes32 batchId,
        bytes32 commitmentRoot,
        uint256 clearingPrice,
        uint256 totalVolume
    ) internal pure returns (bytes memory) {
        return abi.encode(
            keccak256(abi.encode(batchId, commitmentRoot, clearingPrice, totalVolume))
        );
    }

    function testFullYieldFlow() public {
        // Founder tohum: $3.000 -> $100.000 TVL tavan
        vm.prank(founder);
        cUSD.seedJunior{value: 3_000 ether}(0);
        assertEq(cUSD.tvlCap(), 100_000 ether, "3k/0.03 = 100k TVL tavan");

        // Alice cUSD mint'ler (ETH ile $1.00 sabit)
        vm.prank(alice);
        cUSD.mint(alice, 50_000 ether);
        assertEq(cUSD.balanceOf(alice), 50_000 ether, "Alice 50k cUSD");

        // Alice cUSD'yi vault'a yatirir -> scUSD alir
        vm.startPrank(alice);
        cUSD.approve(address(vault), 50_000 ether);
        uint256 shares = vault.deposit(50_000 ether, alice);
        assertGt(shares, 0, "scUSD alindi");
        assertEq(vault.balanceOf(alice), shares, "scUSD bakiye");
        vm.stopPrank();

        // Vault tier'i: TVL 50k < 250k -> Tier0
        assertTrue(
            uint256(vault.activeTier()) == uint256(IReserveStrategy.ReserveTier.Tier0),
            "50k TVL -> Tier0"
        );

        // Getiri egrisi pozitif
        assertGt(vault.currentSeniorYield(), 0, "Tier0 getirisi pozitif");

        // Alice scUSD'yi cUSD'ye cevirir (gunluk %10 kota icinde anlik)
        // Kota: 50k * %10 = 5k. Kucuk bir kismi anlik cek.
        uint256 smallShares = shares / 10;
        vm.startPrank(alice);
        uint256 redeemed = vault.redeem(smallShares, alice, alice);
        assertGt(redeemed, 0, "Redeem basarili");
        assertGt(cUSD.balanceOf(alice), 0, "cUSD geri alindi");
        vm.stopPrank();

        // REBASE YOK: cUSD supply degismedi, getiri yalniz scUSD'de
        assertEq(cUSD.totalSupply(), 50_000 ether, "cUSD supply sabit (REBASE YOK)");
    }

    /// @notice Junior invariant mint'i durdurur
    function testJuniorInvariantStopsMint() public {
        vm.prank(founder);
        cUSD.seedJunior{value: 3_000 ether}(0);

        // TVL tavan 100k; 100k'yi asarsan mint durmali
        vm.prank(alice);
        cUSD.mint(alice, 100_000 ether);
        assertEq(cUSD.totalSupply(), 100_000 ether, "Tam tavan OK");

        // Tavani asma reddedilmeli (junior <%3)
        vm.expectRevert();
        vm.prank(alice);
        cUSD.mint(alice, 1);
    }

    /// @notice Optimize modu feed bagli degilken ACILAMAZ (tum katmanda)
    function testOptimizeGateAcrossStack() public {
        vm.prank(founder);
        vm.expectRevert("OPTIMIZE: utilization feed bagli degil");
        reserve.setOptimizeMode(true);

        // Feed baglayinca acilir
        vm.startPrank(founder);
        reserve.setAaveUtilizationFeed(address(0xFEED));
        reserve.setOptimizeMode(true);
        vm.stopPrank();

        assertTrue(
            uint256(reserve.activeTier()) == uint256(IReserveStrategy.ReserveTier.TierOptimize)
        );
    }

    // =================================================================
    // SENARYO 2: Borsa Akisi (Faz-3) - emir tavani -> batch -> residual
    // =================================================================

    /// @notice Settlement + residual akisi
    function testExchangeFlow() public {
        // Solver kaydet
        vm.prank(founder);
        settlement.registerSolver(solver);

        // Emir tavan check: $5.000 soguk baslangic
        settlement.enforceOrderSize(5_000 ether); // tam sinir OK
        assertEq(settlement.orderSizeCap(), 5_000 ether, "Soguk tavan $5.000");

        // Batch settle et (orderCommitmentRoot ZORUNLU)
        bytes32 batchId = keccak256("integration-batch");
        ICleanvestSettlement.MatchedBatch memory batch = ICleanvestSettlement.MatchedBatch({
            batchId: batchId,
            orderCommitmentRoot: keccak256("merkle-integration"),
            clearingPrice: 1_000 ether,
            totalVolume: 300_000 ether, // > $250k -> lift trigger
            solverSignature: ""
        });

        vm.prank(solver);
        settlement.executeBatchSettlement(
            batch,
            _makeProof(
                batch.batchId, batch.orderCommitmentRoot, batch.clearingPrice, batch.totalVolume
            )
        );

        assertTrue(settlement.isBatchSettled(batchId), "Batch kesinlesti");

        // Lift trigger: 300k > 250k -> tavan kaldirildi
        assertTrue(settlement.sizeCapLifted(), "Lift trigger tetiklendi");
        assertEq(settlement.orderSizeCap(), type(uint256).max, "Tavansiz");
    }

    /// @notice Residual hacim Uniswap'e gider, kayma SEFFAF
    function testResidualRoutingTransparent() public {
        // Kayma uyar kontrolu: %5 -> UI kirmizi
        (bool warn, uint256 bps) = proxy.slippageWarningActive(100 ether, 95 ether);
        assertTrue(warn, "%5 kayma -> uyar ACIK (seffaf)");
        assertEq(bps, 500, "500 bps");
    }

    // =================================================================
    // SENARYO 3: Listing Akisi (Faz-1) - basvuru -> audit -> PoV -> tier
    // =================================================================

    /// @notice Proje listeleme: ucretsiz basvuru -> audit -> PoV -> upgrade
    function testListingFlow() public {
        vm.prank(founder);
        gate.setCleanAuditOracle(oracle);

        address projectToken = address(0x7047);

        // Basvuru UCRETSIZ (harc YOK)
        assertEq(gate.applicationFee(), 0, "Basvuru ucretsiz");
        bytes32 appId = gate.applyForListing(projectToken, "Integration Token");

        // CleanAudit audit: 85 skor -> Verified
        vm.startPrank(oracle);
        gate.recordAuditResultForToken(appId, projectToken, true, 85, 0, 0, 1, 2, 3, false);

        // PoV taahhudunu muhurla
        bytes32 povHash = keccak256("aegisforge-pov-v1-integration");
        gate.sealPovCommitment(appId, povHash, block.timestamp, 3, 45);
        vm.stopPrank();

        assertTrue(gate.isVerified(projectToken), "85 skor -> Verified");

        // Kamusal CleanScore okuma (ucretsiz)
        ListingGate.CleanScoreRecord memory rec = gate.getCleanScore(projectToken);
        assertEq(rec.score, 85, "Skor 85");
        assertEq(rec.findingsHigh, 0, "High yok");

        // PoV bagimsiz dogrulama
        assertTrue(
            gate.verifyPovCommitment(appId, povHash, block.timestamp), "PoV taahhudu dogrulandi"
        );

        // Tier upgrade: Scan -> FuzzPatch (ileri yonlu)
        vm.prank(oracle);
        gate.upgradeAuditTier(projectToken, ListingGate.AuditTier.FuzzPatch);

        assertTrue(
            uint256(gate.getAuditTier(projectToken)) == uint256(ListingGate.AuditTier.FuzzPatch)
        );
        assertTrue(gate.fullAuditAvailable(projectToken), "FuzzPatch tam audit");
    }

    // =================================================================
    // INVARIANT: Yasaklar tum stack'te gecerli
    // =================================================================

    /// @notice REBASE YOK: cUSD supply getiri tarafindan degismez
    function testNoRebaseAcrossStack() public {
        vm.prank(founder);
        cUSD.seedJunior{value: 3_000 ether}(0);

        vm.prank(alice);
        cUSD.mint(alice, 10_000 ether);
        uint256 supplyBefore = cUSD.totalSupply();

        // Vault'a yatir
        vm.startPrank(alice);
        cUSD.approve(address(vault), 10_000 ether);
        vault.deposit(10_000 ether, alice);
        vm.stopPrank();

        // cUSD supply DEGISMEDI (getiri scUSD'de birikir)
        assertEq(cUSD.totalSupply(), supplyBefore, "REBASE YOK: cUSD sabit");
    }

    /// @notice FULL-STACK CIKIS: deposit -> requestRedemption -> redeem -> cUSD
    /// @dev En kritik kullanici yolculugu - ana para cikisi.
    ///      Onceden TAM test edilmemisti (sadece parcalari vardi).
    function testFullStackExitFlow() public {
        vm.prank(founder);
        cUSD.seedJunior{value: 3_000 ether}(0);

        // 1. Alice cUSD mint eder (fiyat -> cUSD)
        vm.prank(alice);
        cUSD.mint(alice, 10_000 ether);
        uint256 cusdBefore = cUSD.balanceOf(alice);

        // 2. Vault'a yatir (cUSD -> scUSD)
        vm.startPrank(alice);
        cUSD.approve(address(vault), 10_000 ether);
        vault.deposit(10_000 ether, alice);
        vm.stopPrank();

        // 3. CIKIS: requestRedemption (kuyruk-onceligi ZORUNLU)
        vm.startPrank(alice);
        vault.requestRedemption(10_000 ether);

        // 4. T+2 bekleme suresi
        vm.warp(block.timestamp + 3 days);

        // 5. redeem -> cUSD geri
        uint256 shares = vault.convertToShares(10_000 ether);
        vault.redeem(shares, alice, alice);
        vm.stopPrank();

        // INVARIANT: cUSD geri dondu (cikis kilitlenmedi)
        assertEq(cUSD.balanceOf(alice), cusdBefore, "Full-stack cikis: cUSD geri donmeli");

        // INVARIANT: vault balance sifirlandi
        assertEq(vault.balanceOf(alice), 0, "Cikis sonrasi scUSD sifir olmali");
    }

    /// @notice Tum fiyatlar seffaf (gizli degil)
    /// @dev Fiyatlar docs/40 (2026-09-27) ile guncellendi
    function testTransparentPricing() public {
        (uint256 scan, uint256 scanHuman, uint256 fuzz, uint256 prio) = gate.getPriceCard();
        assertEq(scan, 199, "Scan $199");
        assertEq(scanHuman, 399, "ScanHuman $399");
        assertEq(fuzz, 990, "FuzzPatch $990");
        assertEq(prio, 4900, "Priority $4.900");
    }
}
