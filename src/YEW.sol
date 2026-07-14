// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title YEW — Treasury Token
 * @notice YEW is the treasury token for Locksley Protocol.
 *         - Fixed supply: 10,000,000 (10M)
 *         - 100% to community treasury at launch
 *         - No mint function — supply is fixed forever
 *
 *         The YEW treasury (this contract) receives:
 *           - YEW/ETH LP tokens from GRAZE performance fees
 *           - ETH from team fee share
 *           - Any rescued tokens
 */
contract YEW is ERC20, Ownable {
    using SafeERC20 for IERC20;

    /// @notice Total supply is fixed at 10,000,000
    uint256 public constant MAX_SUPPLY = 10_000_000 * 1e18;

    constructor(address initialOwner)
        ERC20("YEW Treasury Token", "YEW")
        Ownable(initialOwner)
    {
        // 100% of supply to deployer (community treasury / Liquidity Bootstrap)
        _mint(initialOwner, MAX_SUPPLY);
    }

    /// @notice YEW cannot be minted after launch — supply is fixed
    function mint(address to, uint256 amount) external onlyOwner {
        revert("YEW: no minting after launch");
    }

    /// @notice Sweep accidental ERC20 transfers to owner
    function sweepToken(IERC20 token, address to) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "YEW: nothing to sweep");
        token.safeTransfer(to, balance);
        emit SweepToken(address(token), balance);
    }

    /// @notice Sweep ETH held by YEW treasury
    function sweepETH(address payable to) external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "YEW: nothing to sweep");
        to.transfer(balance);
    }

    event SweepToken(address indexed token, uint256 amount);
}
