// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/UniswapProxy.sol";

/// @title UniswapProxy Test Suite
/// @notice Artik hacim yonlendirme: seffaf kayma (gizleme YOK)
contract UniswapProxyTest is Test {
    UniswapProxy public proxy;
    MockToken public tokenIn;
    MockToken public tokenOut;
    address public owner = address(0x0ABE);
    address public router = address(0x5047);

    function setUp() public {
        tokenIn = new MockToken("Token In", "TIN");
        tokenOut = new MockToken("Token Out", "TOUT");
        proxy = new UniswapProxy(router);
        proxy.transferOwnership(owner);

        tokenIn.mint(owner, 1_000_000 ether);
        tokenOut.mint(address(proxy), 1_000_000 ether);
    }

    /// @notice Artik hacim yonlendirilir
    function testRouteResidual() public {
        vm.startPrank(owner);
        tokenIn.approve(address(proxy), 1_000 ether);

        uint256 out = proxy.routeResidual(address(tokenIn), address(tokenOut), 1_000 ether, 950 ether);
        vm.stopPrank();

        assertGt(out, 0, "Cikis miktari pozitif");
        assertEq(proxy.totalRoutedVolume(), 1_000 ether, "Toplam hacim kaydedildi");
        assertEq(proxy.totalRoutedCount(), 1, "Yonlendirme sayisi");
    }

    /// @notice Ayni token yonlendirme reddedilir
    function testRevertSameToken() public {
        vm.prank(owner);
        vm.expectRevert("Ayni token");
        proxy.routeResidual(address(tokenIn), address(tokenIn), 100 ether, 90 ether);
    }

    /// @notice Sifir miktar reddedilir
    function testRevertZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert("Miktar 0 olamaz");
        proxy.routeResidual(address(tokenIn), address(tokenOut), 0, 0);
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
        address newRouter = address(0xBEEF);

        vm.prank(owner);
        proxy.setSwapRouter(newRouter);

        assertEq(proxy.swapRouter(), newRouter);
    }

    /// @notice Sifir router reddedilir
    function testRevertZeroRouter() public {
        vm.prank(owner);
        vm.expectRevert("Router sifir olamaz");
        proxy.setSwapRouter(address(0));
    }
}

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
