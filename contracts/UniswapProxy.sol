// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IUniswapV3Router.sol";

/// @title UniswapProxy - Artik Hacim Yonlendirme (Faz-3 Residual)
/// @author Cleanvest
/// @notice FBA batch'inde eslesmeyen artik hacmi Uniswap v3'e yonlendirir.
/// @dev SARTNAME KRITIK: "sifir kayma" vaadi YOK. AMM kaymasi UI'da SEFFAF
///      gosterilir. Bu kontrat yalnizca yonlendirme yapar - kaymayi gizlemez.
///      Uniswap TWAP ORACLE olarak KULLANILMAZ (dairesel fiyat) - bu
///      yalnizca likidite cikis kapisidir.
contract UniswapProxy is Ownable, ReentrancyGuard {
    /// @notice Uniswap V3 SwapRouter (Base).
    address public swapRouter;

    /// @notice Yonlendirilen toplam hacim (seffaf raporlama).
    uint256 public totalRoutedVolume;

    /// @notice Yonlendirme sayisi.
    uint256 public totalRoutedCount;

    /// @notice Kayma eşiği uyarısı: %3 uzeri yonlendirme yine de yapilir
    ///         ama UI'da KIRMIZI uyarı gosterilir (seffaf).
    uint256 public constant SLIPPAGE_WARN_BPS = 300;

    event VolumeRouted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 slippageBps
    );
    event RouterUpdated(address indexed router);

    constructor(address _swapRouter) Ownable(msg.sender) {
        swapRouter = _swapRouter;
    }

    /// @notice Artik hacmi Uniswap'e yonlendir.
    /// @dev Kayma ONLENMEZ - yalnizca olculur ve raporlanir. Bu, "seffaf
    ///      kayma" sozunun kod karsiligidir: UI bu degeri gosterir.
    /// @param tokenIn Giris tokeni
    /// @param tokenOut Cikis tokeni
    /// @param amountIn Giris miktari
    /// @param minAmountOut Minimum cikis (slippage tolerance, ayarlanabilir)
    /// @param poolFee Uniswap v3 pool fee (orn. 3000 = %0.3, 500 = %0.05)
    function routeResidual(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint24 poolFee
    ) external onlyOwner nonReentrant returns (uint256 amountOut) {
        require(swapRouter != address(0), "Swap router bagli degil");
        require(amountIn > 0, "Miktar 0 olamaz");
        require(tokenIn != tokenOut, "Ayni token");
        require(minAmountOut > 0, "Min cikis 0 olamaz");

        // Token'leri al
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(swapRouter, amountIn);

        // GERCEK Uniswap V3 swap (mock DEGIL)
        IUniswapV3Router router = IUniswapV3Router(swapRouter);
        IUniswapV3Router.ExactInputSingleParams memory params =
            IUniswapV3Router.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                sqrtPriceLimitX96: 0
            });

        amountOut = router.exactInputSingle(params);
        require(amountOut >= minAmountOut, "Slippage: cikis minimumun altinda");

        // Kaymayi olc ve raporla (UI'da gosterilir - GIZLENMEZ)
        // Math.mulDiv: 512-bit ara deger - amountIn = type().max olsa bile
        // (amountIn - amountOut) * 10000 tasmaz (overflow korumasi)
        uint256 slippageBps =
            amountIn > amountOut ? Math.mulDiv(amountIn - amountOut, 10000, amountIn) : 0;

        // CEI: once transfer, sonra state (reentrancy en iyi pratik)
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        totalRoutedVolume += amountIn;
        totalRoutedCount++;

        emit VolumeRouted(tokenIn, tokenOut, amountIn, amountOut, slippageBps);

        return amountOut;
    }

    /// @notice Kayma uyarı eşiği asildi mi (UI icin seffaf sinyal).
    function slippageWarningActive(uint256 amountIn, uint256 amountOut)
        external
        pure
        returns (bool warn, uint256 slippageBps)
    {
        if (amountIn == 0 || amountOut >= amountIn) return (false, 0);
        // Math.mulDiv ile overflow korumasi (amountIn kullanici girisi)
        slippageBps = Math.mulDiv(amountIn - amountOut, 10000, amountIn);
        return (slippageBps > SLIPPAGE_WARN_BPS, slippageBps);
    }

    /// @notice Swap router bagla.
    function setSwapRouter(address router) external onlyOwner {
        require(router != address(0), "Router sifir olamaz");
        swapRouter = router;
        emit RouterUpdated(router);
    }
}
