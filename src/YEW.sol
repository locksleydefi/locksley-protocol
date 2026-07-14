// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title YEW
 * @notice YEW is the treasury token for Locksley Protocol.
 *         Every harvest on GRAZE vaults buys YEW from fees and adds it to
 *         the YEW/ETH LP — providing automatic buy pressure.
 *
 *         Max supply: 1,000,000,000 YEW (1 billion × 10¹⁸).
 *         Emissions schedule: 0.05 YEW/block, halved every 30 days (locked).
 *
 *         YEW is minted exclusively by YEWVaultChef (set once via setVault).
 */
contract YEW is ERC20, Ownable {

    /// @notice Maximum total supply: 1 billion × 10¹⁸
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;

    /// @notice Maps contract address → whether it is allowed to mint YEW
    mapping(address => bool) public minters;

    /// @notice Emitted when minting permission is updated
    event MinterUpdated(address indexed vault, bool allowed);

    /// @notice Emitted when new YEW is minted
    event Minted(address indexed to, uint256 amount);

    /// @notice Emitted when max supply is reached
    event MaxSupplyReached(address indexed caller, uint256 attempted, uint256 minted);

    constructor(address initialOwner)
        ERC20("YEW", "YEW")
        Ownable(initialOwner)
    {
        // YEW supply starts at 0 — all minted by YEWVaultChef over time
    }

    /// @notice Mint YEW — callable only by authorized minter contracts
    /// @dev Set the minter via setVault() after deploying YEWVaultChef
    function mint(address to, uint256 amount) external {
        require(minters[msg.sender], "YEW: caller is not an authorized minter");
        uint256 currentSupply = totalSupply();
        if (currentSupply + amount > MAX_SUPPLY) {
            uint256 canMint = MAX_SUPPLY - currentSupply;
            if (canMint > 0) {
                _mint(to, canMint);
                emit Minted(to, canMint);
                emit MaxSupplyReached(msg.sender, amount, canMint);
            } else {
                emit MaxSupplyReached(msg.sender, amount, 0);
            }
        } else {
            _mint(to, amount);
            emit Minted(to, amount);
        }
    }

    /// @notice Authorize or revoke a contract's right to mint YEW
    /// @dev Only YEW owner (James) can call this
    function setVault(address vault, bool allowed) external onlyOwner {
        minters[vault] = allowed;
        emit MinterUpdated(vault, allowed);
    }
}
