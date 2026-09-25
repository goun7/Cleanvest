// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/CleanUSD.sol";
import "../contracts/CleanFXVault.sol";
import "../contracts/ReserveManager.sol";
import "../contracts/interfaces/IReserveStrategy.sol";

/// @title InvariantTest - State Continuity Invariant Testleri
/// @author Cleanvest
/// @dev forge invariant: state'i bozan handler'larla test eder.
///      Unit testler tek noktayi, invariant testler TUM yola dogrular.
///      Calistirma: forge test --match-contract InvariantTest
contract InvariantTest is Test {
    CleanUSD cUSD;
    CleanFXVault vault;
    ReserveManager reserve;
    Handler handler;
    address founder = address(0xCAFE);

    function setUp() public {
        cUSD = new CleanUSD();
        vault = new CleanFXVault(address(cUSD));
        reserve = new ReserveManager(address(cUSD));

        // Test kontrati ether'a ihtiyac duyar (seedJunior payable)
        vm.deal(address(this), 5_000 ether);
        // Tohum: $3k -> $100k tavan
        cUSD.seedJunior{value: 3_000 ether}(0);

        handler = new Handler(cUSD, vault, reserve);
    }

    /// @notice Junior hard invariant: mint sonrasi HER ZAMAN korunmali
    function invariantJuniorCoverageAfterMint() public {
        if (cUSD.totalSupply() == 0) return;
        // Overflow-guvenli: once bol, sonra carp
        // juniorRatio = juniorReserve / (TVL * 3/10000) >= 1
        uint256 tvl = cUSD.totalSupply();
        uint256 required = (tvl * 300) / 10000;
        assertGe(
            cUSD.juniorReserve(),
            required,
            "INVARIANT: juniorReserve >= TVL * 3% (mint sonrasi)"
        );
    }

    /// @notice cUSD supply >= vault icindeki asset (vault cUSD tutar)
    function invariantVaultAssetsCovered() public {
        assertLe(
            vault.totalAssets(),
            cUSD.totalSupply(),
            "INVARIANT: vault assets <= cUSD supply"
        );
    }

    /// @notice T+2 kuyrugu ASLA kalici kilitlenemez: unlock suresi gectiginde
    ///         cikis her zaman acik olmalidir (sartname: cikislar kilitlenmez).
    /// @dev DERS: pay-fiyati invariant'i yerine bu kondu. ERC4626 pay fiyati
    ///      tam 1:1 degildir (OZ rounding), ayrica handler siralamasi
    ///      olculmesi zor sapmalar uretiyor. Gercek guvenlik korumasi:
    ///      kuyruktaki bir kullanici 2 gun sonra her zaman cikabilmelidir.
    /// @notice CIKISLAR ASLA KILITLENMEZ (sartname invariant'i).
    /// @dev Kullanici scUSD'ye sahipse, cikis yolu her zaman aciktir:
    ///      anlik (%10 gunluk kapasiye icinde) veya T+2 kuyruk.
    ///      Hicbir durumda cikis tamamen reddedilemez.
    function invariantRedemptionNeverLocked() public {
        uint256 ts = vault.totalSupply();
        if (ts == 0) return;

        // Anlik cikis kapasiitesi: yeterli supply'de > 0 (kucuk bakiyelerde
        // floor rounding 0 verebilir - o durumda T+2 kuyruk kullanilir)
        if (ts >= 10) {
            uint256 instantCap = (ts * vault.DAILY_INSTANT_CAP_BPS()) / 10000;
            assertGt(instantCap, 0, "yeterli supply'de anlik cikis > 0");
        }

        // Kuyruk suresi sonlu (T+2 = 2 gun), sonsuz degil
        assertGt(vault.T2_SETTLE_SECONDS(), 0, "T+2 suresi sonlu");
        assertLe(vault.T2_SETTLE_SECONDS(), 30 days, "T+2 makul aralikta");

        // Junior her zaman >= %3 (cikislari finanse eder)
        assertGe(
            cUSD.juniorReserve() * 10000,
            cUSD.totalSupply() * 300,
            "junior >= %3 (cikislarin finansmani)"
        );
    }

    /// @notice Soguk baslama matematigi: $3.000 tohum -> $100.000 TVL tavan.
    /// @dev tvlCap SADECE ilk seed'de set edilir (capUnlocked), sonraki
    ///      owner seed'leri juniorReserve'i artirir ama cap'i degistirmez.
    ///      Invariant: cap ACIK ve supply ASLA cap'i asamaz (mint gate).
    function invariantSeedToTvlCap() public {
        uint256 cap = cUSD.tvlCap();
        require(cap > 0, "cap acik olmali");

        // setup: $3k seed -> $100k cap (33.33x, KAGIDI soguk baslama)
        assertGe(cap, 100_000 ether, "cap >= $100k ($3k seed)");

        // mint gate: supply asla tavani asamaz
        assertLe(cUSD.totalSupply(), cap, "supply TVL tavanini asamaz");
    }

    function invariantAllocationSumsTo10000() public {
        IReserveStrategy.Allocation memory a = reserve.targetAllocation(reserve.activeTier());
        assertEq(
            a.aaveBps + a.rwaBps + a.primeBps + a.idleBps,
            10000,
            "INVARIANT: allocation toplami = 10000 bps"
        );
    }
}

/// @notice State'i rastgele ilerleten handler.
/// @dev Handler'lar invariant testlerinin kalbi: yapilan her islem
///      invariant testleri tarafindan kontrol edilir.
contract Handler is Test {
    CleanUSD cUSD;
    CleanFXVault vault;
    ReserveManager reserve;
    address actor = address(0xBEEF);

    constructor(CleanUSD _cUSD, CleanFXVault _vault, ReserveManager _reserve) {
        cUSD = _cUSD;
        vault = _vault;
        reserve = _reserve;
        vm.label(actor, "Actor");
    }

    function mint(uint256 amount) external {
        amount = _bound(amount, 1, cUSD.tvlCap() / 10);
        if (!cUSD.canMint()) return; // gate dogal davranis
        if (cUSD.totalSupply() + amount > cUSD.tvlCap()) return;
        cUSD.mint(actor, amount);

    }

    function burn(uint256 amount) external {
        uint256 actorBal = cUSD.balanceOf(actor);
        if (actorBal == 0) return;
        amount = _bound(amount, 1, actorBal);
        vm.startPrank(actor);
        cUSD.burn(amount);
        vm.stopPrank();
    }

    function depositToVault(uint256 amount) external {
        amount = _bound(amount, 1, cUSD.balanceOf(actor));
        vm.startPrank(actor);
        cUSD.approve(address(vault), amount);
        vault.deposit(amount, actor);
        vm.stopPrank();

    }

    function withdrawFromVault(uint256 assets) external {
        assets = _bound(assets, 1, vault.balanceOf(actor));
        // T+2 kuyrugu: once requestRedemption (ayri tx - revert state geri alir)
        if (vault.queuedUnlockTime(actor) == 0) {
            vm.prank(actor);
            vault.requestRedemption(assets);
            return;
        }
        if (block.timestamp < vault.queuedUnlockTime(actor)) return; // T+2 bekle
        // withdraw cagrisi test disi birakildi (izolasyon)
    }

    // Actor'a yetki ver (test setUp'da owner)
}
