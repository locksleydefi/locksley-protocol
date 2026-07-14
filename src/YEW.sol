// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title YEW
 * @notice YEW is the treasury token for Locksley Protocol.
 *         Fees collected by GRAZE vaults are sent here.
 *         YEW can be used to:
 *           - Buy FLETCH from the market to reward stakers
 *           - Hold as protocol runway
 *           - Distribute to FLETCH-ETH LP providers
 *
 *         The YEW contract also wraps received ERC20 tokens so the
 *         treasury can easily convert fee tokens into FLETCH.
 */
contract YEW is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Emitted when a token is swept to the treasury owner
    event SweepToken(address indexed token, uint256 amount);

    /// @notice Emitted when ETH is received
    event ReceivedETH(address indexed from, uint256 amount);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @notice Allow the YEW treasury to receive native ETH (for ETH refunds, etc.)
     */
    receive() external payable {
        emit ReceivedETH(msg.sender, msg.value);
    }

    /**
     * @notice Sweep accidental ERC20 transfers to YEW.
     *         Use this to rescue tokens sent to the treasury by mistake.
     * @param token  Address of the token to sweep.
     * @param to     Address to send the tokens to.
     */
    function sweepToken(IERC20 token, address to) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "YEW: nothing to sweep");
        token.safeTransfer(to, balance);
        emit SweepToken(address(token), balance);
    }

    /**
     * @notice Sweep ETH held by YEW to an address.
     * @param to Address to send the ETH to.
     */
    function sweepETH(address payable to) external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "YEW: nothing to sweep");
        to.transfer(balance);
    }

    /**
     * @notice Report profit for analytics purposes (no on-chain effect).
     *         Can be called by anyone — purely for indexer/tracking purposes.
     * @param profit Amount of profit reported.
     * @param source Source of the profit (vault address as string).
     */
    function reportProfit(uint256 profit, string calldata source) external {
        // Intentionally left empty — useful for off-chain tracking
        // Events can be indexed by block explorers for dashboards
        emit ProfitReported(profit, source, msg.sender);
    }

    event ProfitReported(uint256 profit, string source, address reporter);
}
