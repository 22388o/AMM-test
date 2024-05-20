// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleAMM {
    address public token1;
    address public token2;
    uint256 public reserve1;
    uint256 public reserve2;
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;
    uint256 public feePercent = 3; // Fee percentage (e.g., 0.3%)

    constructor(address _token1, address _token2) {
        token1 = _token1;
        token2 = _token2;
    }

    function _safeTransfer(address token, address to, uint256 amount) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }

    function addLiquidity(uint256 amount1, uint256 amount2) public returns (uint256) {
        _safeTransfer(token1, address(this), amount1);
        _safeTransfer(token2, address(this), amount2);

        uint256 liquidityMinted;
        if (totalLiquidity == 0) {
            liquidityMinted = sqrt(amount1 * amount2);
        } else {
            liquidityMinted = min((amount1 * totalLiquidity) / reserve1, (amount2 * totalLiquidity) / reserve2);
        }

        liquidity[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;
        reserve1 += amount1;
        reserve2 += amount2;

        return liquidityMinted;
    }

    function removeLiquidity(uint256 amount) public returns (uint256, uint256) {
        uint256 amount1 = (amount * reserve1) / totalLiquidity;
        uint256 amount2 = (amount * reserve2) / totalLiquidity;

        liquidity[msg.sender] -= amount;
        totalLiquidity -= amount;
        reserve1 -= amount1;
        reserve2 -= amount2;

        _safeTransfer(token1, msg.sender, amount1);
        _safeTransfer(token2, msg.sender, amount2);

        return (amount1, amount2);
    }

    function swap(uint256 amountIn, address fromToken, address toToken) public returns (uint256 amountOut) {
        require((fromToken == token1 && toToken == token2) || (fromToken == token2 && toToken == token1), "Invalid tokens");

        bool isToken1 = fromToken == token1;
        uint256 reserveIn = isToken1 ? reserve1 : reserve2;
        uint256 reserveOut = isToken1 ? reserve2 : reserve1;

        uint256 amountInWithFee = amountIn * (1000 - feePercent);
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);

        _safeTransfer(fromToken, address(this), amountIn);
        _safeTransfer(toToken, msg.sender, amountOut);

        if (isToken1) {
            reserve1 += amountIn;
            reserve2 -= amountOut;
        } else {
            reserve2 += amountIn;
            reserve1 -= amountOut;
        }
    }

    function sqrt(uint256 x) private pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function min(uint256 x, uint256 y) private pure returns (uint256) {
        return x < y ? x : y;
    }
}
