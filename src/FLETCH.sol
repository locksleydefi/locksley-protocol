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
 *         Max supply: 1,000,000,000 FLETCH (1 billion × 10¹⁸).
 *         Emissions schedule: 0.5 FLETCH/block, halved every 30 days (locked).
 */
contract FLETCH is ERC20, ERC20Permit, Ownable {

    /// @notice Maximum total supply: 1 billion × 10¹⁸
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;

    /// @notice Maps vault address → whether it is allowed to mint FLETCH
    mapping(address => bool) public vaults;

    /// @notice Emitted when a vault's minting permission is updated
    event VaultUpdated(address indexed vault, bool allowed);

    /// @notice Emitted when new FLETCH is minted
    event Minted(address indexed to, uint256 amount, address indexed vault);

    /// @notice Emitted when max supply is hit
    event MaxSupplyReached(address indexed vault, uint256 amountAttempted, uint256 amountMinted);

    constructor(address initialOwner)
        ERC20("FLETCH", "FLETCH")
        ERC20Permit("FLETCH")
        Ownable(initialOwner)
    {
        // No pre-mint — pure emission token for fair launch
    }

    /**
     * @notice Called by an authorized vault to mint FLETCH as staking rewards.
     *         Capped at MAX_SUPPLY — never exceeds 1 billion FLETCH.
     * @param to     Address receiving the FLETCH.
     * @param amount Amount to mint.
     */
    function mint(address to, uint256 amount) external {
        require(vaults[msg.sender], "FLETCH: caller is not an authorized vault");
        uint256 currentSupply = totalSupply();
        if (currentSupply + amount > MAX_SUPPLY) {
            // Mint up to max supply only
            uint256 canMint = MAX_SUPPLY - currentSupply;
            if (canMint > 0) {
                _mint(to, canMint);
                emit Minted(to, canMint, msg.sender);
                emit MaxSupplyReached(msg.sender, amount, canMint);
            } else {
                emit MaxSupplyReached(msg.sender, amount, 0);
            }
        } else {
            _mint(to, amount);
            emit Minted(to, amount, msg.sender);
        }
    }

    /**
     * @notice Called by owner to burn FLETCH (e.g. for token burns or corrections).
     * @param from   Address to burn from.
     * @param amount Amount to burn.
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    /**
     * @notice Authorize or revoke a vault's right to mint FLETCH.
     * @param vault   Contract address of the vault.
     * @param allowed True = allow, False = revoke.
     */
    function setVault(address vault, bool allowed) external onlyOwner {
        vaults[vault] = allowed;
        emit VaultUpdated(vault, allowed);
    }

    /**
     * @notice Owner-only mint. Capped at MAX_SUPPLY.
     *         Use for airdrops or seeding before vault launch.
     * @param to     Address receiving the FLETCH.
     * @param amount Amount to mint.
     */
    function ownerMint(address to, uint256 amount) external onlyOwner {
        uint256 currentSupply = totalSupply();
        if (currentSupply + amount > MAX_SUPPLY) {
            uint256 canMint = MAX_SUPPLY - currentSupply;
            if (canMint > 0) {
                _mint(to, canMint);
                emit Minted(to, canMint, address(0));
            }
        } else {
            _mint(to, amount);
            emit Minted(to, amount, address(0));
        }
    }
}
