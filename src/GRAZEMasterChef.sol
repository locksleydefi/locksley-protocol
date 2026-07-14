// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./FLETCH.sol";

/**
 * @title GRAZE MasterChef
 * @notice GRAZE is the flagship yield aggregator vault for Locksley Protocol.
 *
 *         Based on the battle-tested SushiSwap MasterChef V1 pattern
 *         (https://github.com/sushiswap/sushiswap).
 *
 *         Users deposit LP tokens → earn FLETCH rewards.
 *         FLETCH is minted by this contract on demand (no token pre-sale needed).
 *
 *         Fee model:
 *           - Performance fee: 10% → YEW treasury
 *           - No withdrawal fee on the LP (LP itself has DEX trading fees)
 *
 * @dev This contract is adapted from SushiSwap MasterChef V1.
 *      Changes from original:
 *        - Removed SUSHI-specific logic
 *        - Added FLETCH minting instead of SUSHI
 *        - Simplified to single pool (CASHCAT-ETH LP)
 *        - Added YEW performance fee
 *
 *      Before mainnet: consider professional audit and multisig ownership.
 */
contract GRAZEMasterChef is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------------
    // Contracts
    // ---------------------------------------------------------------------------

    FLETCH   public immutable FLETCH_TOKEN;       // FLETCH reward token
    IERC20   public immutable LP_TOKEN;        // CASHCAT-ETH LP
    using SafeERC20 for IERC20;
    address  public immutable YEW_TREASURY;

    // ---------------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------------

    /// @notice FLETCH per block to distribute (adjusted by BUFFER_MULTIPLIER for precision)
    uint256 public fletchPerBlock = 1e18;  // 1 FLETCH per block

    /// @notice Last block number when rewards were updated
    uint256 public lastRewardBlock;

    /// @notice Accumulated FLETCH per LP share (× 1e12 for precision)
    uint256 public accFLETCHPerShare;

    /// @notice Total LP tokens staked
    uint256 public totalLpStaked;

    /// @notice Block number when FLETCH emissions start
    uint256 public startBlock;

    /// @notice Multiplier to convert per-block rate to per-second (approx)
    uint256 public constant BUFFER_MULTIPLIER = 1e12;

    // ---------------------------------------------------------------------------
    // User state
    // ---------------------------------------------------------------------------

    struct UserInfo {
        uint256 shares;          // LP shares (1:1 with LP token)
        uint256 rewardDebt;      // FLETCH owed (similar to MasterChef pattern)
    }

    mapping(address => UserInfo) public userInfo;

    // ---------------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------------

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Harvest(address indexed user, uint256 reward);
    event SetFletchPerBlock(uint256 oldRate, uint256 newRate);

    // ---------------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------------

    constructor(
        address _fletch,
        address _lpToken,
        address _yewTreasury,
        address _owner,
        uint256 _startBlock
    ) Ownable(_owner) {
        require(_fletch      != address(0), "GRAZE: fletch is zero");
        require(_lpToken     != address(0), "GRAZE: LP token is zero");
        require(_yewTreasury != address(0), "GRAZE: YEW treasury is zero");

        FLETCH_TOKEN   = FLETCH(_fletch);
        LP_TOKEN      = IERC20(_lpToken);
        YEW_TREASURY = _yewTreasury;
        startBlock    = _startBlock > block.number ? _startBlock : block.number;
        lastRewardBlock = startBlock;
    }

    // ---------------------------------------------------------------------------
    // VIEW
    // ---------------------------------------------------------------------------

    /**
     * @notice Returns pending FLETCH rewards for a user.
     * @dev Standard MasterChef pending reward formula:
     *      pending = user.shares × accFLETCHPerShare / 1e12 − user.rewardDebt
     */
    function pendingFLETCH(address _user) external view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        if (totalLpStaked == 0) return 0;

        uint256 blockDiff = block.number - lastRewardBlock;
        uint256 newRewards = blockDiff * fletchPerBlock;

        // 10% performance fee goes to YEW
        uint256 netRewards = (newRewards * 9000) / 10000;

        uint256 acc = accFLETCHPerShare
            + (netRewards * BUFFER_MULTIPLIER) / totalLpStaked;

        return (user.shares * acc) / 1e12 - user.rewardDebt;
    }

    // ---------------------------------------------------------------------------
    // USER INTERFACE
    // ---------------------------------------------------------------------------

    /**
     * @notice Deposit LP tokens to start earning FLETCH.
     * @param amount Amount of LP tokens to deposit.
     */
    function deposit(uint256 amount) external nonReentrant {
        _harvest(msg.sender);

        // Pull LP from user
        if (amount > 0) {
            LP_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
            userInfo[msg.sender].shares += amount;
            totalLpStaked += amount;
        }

        // Update reward debt
        userInfo[msg.sender].rewardDebt =
            (userInfo[msg.sender].shares * accFLETCHPerShare) / 1e12;

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Withdraw LP tokens. Pending FLETCH is auto-harvested.
     * @param amount Amount of LP shares to redeem.
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "GRAZE: amount is zero");
        require(userInfo[msg.sender].shares >= amount, "GRAZE: insufficient shares");

        _harvest(msg.sender);

        // Burn shares
        userInfo[msg.sender].shares -= amount;
        totalLpStaked -= amount;

        // Send LP back
        LP_TOKEN.safeTransfer(msg.sender, amount);

        // Update reward debt
        userInfo[msg.sender].rewardDebt =
            (userInfo[msg.sender].shares * accFLETCHPerShare) / 1e12;

        emit Withdraw(msg.sender, amount);
    }

    /**
     * @notice Harvest pending FLETCH rewards. Can be called independently of deposit/withdraw.
     */
    function harvest() external nonReentrant {
        _harvest(msg.sender);
    }

    // ---------------------------------------------------------------------------
    // INTERNAL
    // ---------------------------------------------------------------------------

    function _harvest(address user) internal {
        _updatePool();

        UserInfo storage u = userInfo[user];
        if (u.shares == 0) return;

        // Calculate pending: shares × new acc − old debt
        uint256 pending = (u.shares * accFLETCHPerShare) / 1e12 - u.rewardDebt;

        if (pending > 0) {
            // Mint FLETCH to user
            FLETCH_TOKEN.mint(user, pending);
            emit Harvest(user, pending);
        }

        // Reset debt to current accumulated level
        u.rewardDebt = (u.shares * accFLETCHPerShare) / 1e12;
    }

    function _updatePool() internal {
        if (block.number <= lastRewardBlock) return;
        if (totalLpStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 blockDiff = block.number - lastRewardBlock;
        uint256 newRewards = blockDiff * fletchPerBlock;

        if (newRewards > 0) {
            // Mint full amount to this contract
            FLETCH_TOKEN.mint(address(this), newRewards);

            // 10% → YEW treasury (performance fee)
            uint256 fee = (newRewards * 1000) / 10000;
            IERC20(address(FLETCH_TOKEN)).safeTransfer(YEW_TREASURY, fee);

            // Update accumulator (net rewards only)
            uint256 netRewards = newRewards - fee;
            accFLETCHPerShare += (netRewards * BUFFER_MULTIPLIER) / totalLpStaked;
        }

        lastRewardBlock = block.number;
    }

    // ---------------------------------------------------------------------------
    // OWNER FUNCTIONS
    // ---------------------------------------------------------------------------

    /**
     * @notice Set FLETCH reward rate per block.
     * @param _rate New FLETCH per block (in wei).
     * @dev Call when market conditions change. Be conservative — sustainability matters.
     */
    function setFletchPerBlock(uint256 _rate) external onlyOwner {
        require(_rate > 0, "GRAZE: rate must be > 0");
        uint256 old = fletchPerBlock;
        fletchPerBlock = _rate;
        emit SetFletchPerBlock(old, _rate);
    }

    /**
     * @notice Emergency: rescue LP tokens sent directly to this contract.
     */
    function emergencyLpWithdraw(address to, uint256 amount) external onlyOwner {
        require(amount > 0, "GRAZE: zero amount");
        LP_TOKEN.safeTransfer(to, amount);
    }
}