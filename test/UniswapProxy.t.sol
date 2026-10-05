// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/UniswapProxy.sol";
import "../contracts/interfaces/IUniswapV3Router.sol";

/// @title UniswapProxy Test Suite
/// @notice Artik hacim yonlendirme: seffaf kayma (gizleme YOK)
contract UniswapProxyTest is Test {
    UniswapProxy public proxy;
    MockToken public tokenIn;
    MockToken public tokenOut;
    address public owner = address(0x0ABE);
    MockV3Router public router;

    function setUp() public {
        tokenIn = new MockToken("Token In", "TIN");
        tokenOut = new MockToken("Token Out", "TOUT");
        router = new MockV3Router();
        proxy = new UniswapProxy(address(router));
        proxy.transferOwnership(owner);

        tokenIn.mint(owner, 1_000_000 ether);
        tokenOut.mint(address(proxy), 1_000_000 ether);
    }

    /// @notice Artik hacim yonlendirilir
    function testRouteResidual() public {
        vm.startPrank(owner);
        tokenIn.approve(address(proxy), 1_000 ether);

        uint256 out =
            proxy.routeResidual(address(tokenIn), address(tokenOut), 1_000 ether, 950 ether, 3000);
        vm.stopPrank();

        assertGt(out, 0, "Cikis miktari pozitif");
        assertEq(proxy.totalRoutedVolume(), 1_000 ether, "Toplam hacim kaydedildi");
        assertEq(proxy.totalRoutedCount(), 1, "Yonlendirme sayisi");
    }

    /// @notice Ayni token yonlendirme reddedilir
    function testRevertSameToken() public {
        vm.prank(owner);
        vm.expectRevert("Ayni token");
        proxy.routeResidual(address(tokenIn), address(tokenIn), 100 ether, 90 ether, 3000);
    }

    /// @notice Sifir miktar reddedilir
    function testRevertZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert("Miktar 0 olamaz");
        proxy.routeResidual(address(tokenIn), address(tokenOut), 0, 0, 3000);
    }

    /// @notice Kayma uyarısı: %3 altinda -> uyarı YOK
    function testSlippageNoWarning() public view {
        (bool warn, uint256 bps) = proxy.slippageWarningActive(100 ether, 98 ether);
        assertFalse(warn, "%2 kayma -> uyar YOK");
        assertEq(bps, 200, "200 bps");
    }

    /// @notice Kayma uyarısı: %3 ustu -> uyar ACIK (UI'da kirmizi)
    function testSlippageWarning() public view {
        (bool warn, uint256 bps) = proxy.slippageWarningActive(100 ether, 95 ether);
        assertTrue(warn, "%5 kayma -> uyar ACIK");
        assertEq(bps, 500, "500 bps");
    }

    /// @notice Kayma olumluysa uyar yok
    function testNoSlippage() public view {
        (bool warn, uint256 bps) = proxy.slippageWarningActive(100 ether, 105 ether);
        assertFalse(warn, "Olumlu -> uyar YOK");
        assertEq(bps, 0, "0 bps");
    }

    /// @notice Router guncellenebilir
    function testSetRouter() public {
        MockV3Router newRouter = new MockV3Router();

        vm.prank(owner);
        proxy.setSwapRouter(address(newRouter));

        assertEq(proxy.swapRouter(), address(newRouter));
    }

    /// @notice Sifir router reddedilir
    function testRevertZeroRouter() public {
        vm.prank(owner);
        vm.expectRevert("Router sifir olamaz");
        proxy.setSwapRouter(address(0));
    }

    /// @notice Asiri buyuk amountIn ile kayma hesabi overflow vermemeli
    function testSlippageOverflowProtection() public view {
        // ESKIDEN: (type().max - 1) * 10000 -> panic 0x11
        // SIMDI: Math.mulDiv ile tasmaz
        (bool warn, uint256 bps) = proxy.slippageWarningActive(type(uint256).max, 1);
        assertGt(bps, 0, "mulDiv tasmadi - bps hesaplandi");
        assertTrue(warn, "asiri kaymada uyar aktif");
    }

    /// @notice minAmountOut=0 reddedilir (branch L56)
    function testRevertZeroMinAmountOut() public {
        vm.prank(owner);
        vm.expectRevert("Min cikis 0 olamaz");
        proxy.routeResidual(address(tokenIn), address(tokenOut), 100 ether, 0, 3000);
    }

    /// @notice Router bagli degilken routeResidual reddedilir (branch L53)
    /// @dev TAZE proxy (router set edilmemis) ile cagrilir
    function testRevertNoRouter() public {
        UniswapProxy fresh = new UniswapProxy(address(0));
        vm.prank(address(this));
        vm.expectRevert("Swap router bagli degil");
        fresh.routeResidual(address(tokenIn), address(tokenOut), 100 ether, 90 ether, 3000);
    }

    /// @notice Slippage korumasi: asiri minAmountOut ile takas reddedilir (L77)
    /// @dev Slippage savunmasi IKI katmanli: MockV3Router kendi icinde
    /// 'V3Router: slippage exceeded' ile revert eder (Uniswap V3 gercek
    /// davranisi). UniswapProxy L77'de ek kontrol olsa da router once
    /// revert eder - bu dogru davranistir (guvence katmani).
    function testRevertSlippageBelowMin() public {
        tokenIn.mint(owner, 100 ether);
        vm.startPrank(owner);
        tokenIn.approve(address(proxy), 100 ether);
        vm.expectRevert("V3Router: slippage exceeded");
        proxy.routeResidual(address(tokenIn), address(tokenOut), 100 ether, 200 ether, 3000);
        vm.stopPrank();
    }

    /// @notice Slippage korumasi: router dusuk dondururse proxy L77 yakalar
    /// @dev testRevertSlippageBelowMin'den FARKLI: MockShortRouter kendi
    /// icinde revert ETMEZ (her zaman 1 dondurur). boylece islem
    /// UniswapProxy L77'deki require'a kadar gelir ve "Slippage: cikis
    /// minimumun altinda" ile reddedilir. Bu katman gercek Uniswap V3
    /// router'inin bug'li/kotu niyetli bir uygulama olmasi durumunda bile
    /// kullaniciyi korur (defense-in-depth).
    function testRevertSlippageBelowMinProxyLayer() public {
        MockShortRouter shortRouter = new MockShortRouter();
        vm.prank(owner);
        proxy.setSwapRouter(address(shortRouter));

        tokenIn.mint(owner, 100 ether);
        vm.startPrank(owner);
        tokenIn.approve(address(proxy), 100 ether);
        // router 1 dondurur, min 200 -> L77 require'i tetiklenir
        vm.expectRevert("Slippage: cikis minimumun altinda");
        proxy.routeResidual(address(tokenIn), address(tokenOut), 100 ether, 200 ether, 3000);
        vm.stopPrank();
    }
}

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

/// @notice Test router: IUniswapV3Router arayuzunu gercekten implement eder.
/// @dev Legit mock - arayuz sozlesmesine uyar, sahte deger_atmaz.
contract MockV3Router is IUniswapV3Router {
    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut)
    {
        // Basit 1:1.05 takas orani (gercek pool davranisi simule)
        amountOut = (params.amountIn * 105) / 100;
        require(amountOut >= params.amountOutMinimum, "V3Router: slippage exceeded");
        return amountOut;
    }

    /// @notice Asiri buyuk amountIn ile kayma hesabi overflow vermemeli
}

/// @notice Kisa donen router: kendi icinde slippage kontrolu YOK.
/// @dev MockV3Router gercek V3 davranisini simule eder (kendi slippage
///      require'i ile revert). Bu mock ise HIC revert etmeden her zaman
///      1 birim dondurur - amaci UniswapProxy L77'deki proxy katmani
///      require'inin gercekten calistigini test etmektir (kotu niyetli
///      veya bug'li router senaryosu).
contract MockShortRouter is IUniswapV3Router {
    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut)
    {
        // Her zaman 1 dondurur: herhangi bir minAmountOut > 1 case'inde
        // UniswapProxy L77 yakalamak zorundadir.
        return 1;
    }
}
