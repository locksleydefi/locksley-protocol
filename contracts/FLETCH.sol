// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FLETCH
 * @notice FLETCH is the reward token for Locksley Protocol's GRAZE vaults.
 *         It is minted only by authorized vault contracts.
 *         FLETCH has value because the YEW treasury accumulates fees
 *         and uses them to buy/hold FLETCH — creating a revenuebacked token.
 */
contract FLETCH is ERC20, ERC20Permit, Ownable {

    /// @notice Maps vault address → whether it is allowed to mint FLETCH
    mapping(address => bool) public vaults;

    /// @notice Emitted when a vault's minting permission is updated
    event VaultUpdated(address indexed vault, bool allowed);

    /// @notice Emitted when new FLETCH is minted
    event Minted(address indexed to, uint256 amount, address indexed vault);

    constructor(address initialOwner)
        ERC20("FLETCH", "FLETCH")
        ERC20Permit("FLETCH")
        Ownable(initialOwner)
    {
        // Owner can pre-mint for airdrops or initial seeding before vaults go live
        // _mint(msg.sender, 1_000_000 * 10 ** decimals()); // optional initial supply
    }

    /**
     * @notice Called by an authorized vault to mint FLETCH as staking rewards.
     * @param to    Address receiving the FLETCH.
     * @param amount Amount to mint.
     */
    function mint(address to, uint256 amount) external {
        require(vaults[msg.sender], "FLETCH: caller is not an authorized vault");
        _mint(to, amount);
        emit Minted(to, amount, msg.sender);
    }

    /**
     * @notice Called by owner to burn FLETCH (e.g. for token burns or corrections).
     * @param from  Address to burn from.
     * @param amount Amount to burn.
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    /**
     * @notice Authorize or revoke a vault's right to mint FLETCH.
     * @param vault  Contract address of the vault.
     * @param allowed True = allow, False = revoke.
     */
    function setVault(address vault, bool allowed) external onlyOwner {
        vaults[vault] = allowed;
        emit VaultUpdated(vault, allowed);
    }

    /**
     * @notice Owner-only mint (for airdrops, team allocation, etc.)
     *         Can only be used before vaults are authorized, or can be
     *         used alongside vaults for airdrops.
     * @param to     Address receiving the FLETCH.
     * @param amount Amount to mint.
     */
    function ownerMint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit Minted(to, amount, address(0));
    }
}
