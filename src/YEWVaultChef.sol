// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./YEW.sol";

/**
 * @title YEWVaultChef
 * @notice Staking vault for FLETCH-ETH LP — earns YEW rewards.
 *
 * YEW EMISSION MODEL — LOCKED HALVING SCHEDULE (cannot be changed by owner):
 * ─────────────────────────────────────────────────────────────────────────────
 * YEW Per Block:       0.05 × (1/2)^(epoch)   where epoch = blocks / 864,000
 * Epoch duration:       864,000 blocks (~30 days at 0.1 sec/block)
 * Max epochs:           90
 *
 * Rate is 10x less than GRAZE FLETCH rate (0.05 vs 0.5) — intentional design.
 * Year 1 YEW:          ~3.78M  (0.38% of 1bn max supply)
 *
 * Uniswap V2 Router:   0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
 * WETH (Robinhood):    0x0bd7d308f8e1639fab988df18a8011f41eacad73
 */
contract YEWVaultChef is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------------
    // Emission constants — LOCKED. Cannot be changed after deployment.
    // ---------------------------------------------------------------------------

    /// @notice YEW emitted per block in epoch 0 (0.05 YEW = 5 × 10¹⁶)
    uint256 public constant INITIAL_YEW_PER_BLOCK = 5e16;

    /// @notice Number of blocks per emission epoch (~30 days at 0.1 sec/block)
    uint256 public constant BLOCKS_PER_EPOCH = 864_000;

    /// @notice Maximum number of emission epochs
    uint256 public constant MAX_EPOCHS = 90;

    /// @notice YEW per block for each epoch — computed once at deployment
    uint256[MAX_EPOCHS] public yewPerBlockSchedule;

    // ---------------------------------------------------------------------------
    // External contract addresses
    // ---------------------------------------------------------------------------

    address public constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public immutable WETH_TOKEN_ADDR;

    // ---------------------------------------------------------------------------
    // Contract references
    // ---------------------------------------------------------------------------

    YEW     public immutable YEW_TOKEN;
    IERC20  public immutable LP_TOKEN;   // FLETCH-ETH LP (staked here)
    IERC20  public immutable WETH_TOKEN;

    // ---------------------------------------------------------------------------
    // Emission accounting
    // ---------------------------------------------------------------------------

    uint256 public startBlock;
    uint256 public lastUpdateEpoch;
    uint256 public lastUpdateAcc;
    uint256 public currentEpochAcc;

    uint256 private constant PCT = 1e12;

    // ---------------------------------------------------------------------------
    // Protocol state
    // ---------------------------------------------------------------------------

    uint256 public totalShares;
    address public treasuryWallet;

    // ---------------------------------------------------------------------------
    // User state
    // ---------------------------------------------------------------------------

    struct UserInfo {
        uint256 shares;
        uint256 rewardDebt;
        uint256 lastEpoch;
    }

    mapping(address => UserInfo) public userInfo;

    // ---------------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------------

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount, uint256 yewEarned);
    event Harvest(address indexed user, uint256 yewEarned);
    event SetTreasuryWallet(address indexed oldWallet, address indexed newWallet);
    event EpochClosed(uint256 epoch, uint256 accYEWPerShare);

    // ---------------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------------

    constructor(
        address _yew,
        address _lpToken,
        address _weth,
        address _owner,
        address _treasuryWallet,
        uint256 _startBlock
    ) Ownable(_owner) {
        require(_yew != address(0), "YEW_VAULT: YEW zero");
        require(_lpToken != address(0), "YEW_VAULT: LP zero");
        require(_weth != address(0), "YEW_VAULT: WETH zero");
        require(_treasuryWallet != address(0), "YEW_VAULT: treasury zero");

        YEW_TOKEN     = YEW(payable(_yew));
        LP_TOKEN      = IERC20(_lpToken);
        WETH_TOKEN_ADDR = _weth;
        WETH_TOKEN    = IERC20(_weth);
        treasuryWallet = _treasuryWallet;
        startBlock    = _startBlock > block.number ? _startBlock : block.number;
        lastUpdateEpoch = 0;
        lastUpdateAcc   = 0;
        currentEpochAcc = 0;

        // Pre-compute emission schedule: yewPerBlockSchedule[epoch] = initial >> epoch
        for (uint256 i = 0; i < MAX_EPOCHS; i++) {
            yewPerBlockSchedule[i] = INITIAL_YEW_PER_BLOCK >> i;
        }

        LP_TOKEN.approve(UNISWAP_ROUTER, type(uint256).max);
    }

    // ---------------------------------------------------------------------------
    // EMISSION VIEWS
    // ---------------------------------------------------------------------------

    function yewPerBlockForEpoch(uint256 epoch) external view returns (uint256) {
        if (epoch >= MAX_EPOCHS) return 0;
        return yewPerBlockSchedule[epoch];
    }

    function currentYewPerBlock() external view returns (uint256) {
        uint256 epoch = _getCurrentEpoch();
        if (epoch >= MAX_EPOCHS) return 0;
        return yewPerBlockSchedule[epoch];
    }

    // ---------------------------------------------------------------------------
    // INTERNAL HELPERS
    // ---------------------------------------------------------------------------

    function _getCurrentEpoch() internal view returns (uint256) {
        if (block.number <= startBlock) return 0;
        return (block.number - startBlock) / BLOCKS_PER_EPOCH;
    }

    function _epochStartBlock(uint256 epoch) internal view returns (uint256) {
        return startBlock + epoch * BLOCKS_PER_EPOCH;
    }

    function _updateRewardState() internal {
        uint256 currentEpoch = _getCurrentEpoch();
        if (currentEpoch >= MAX_EPOCHS) currentEpoch = MAX_EPOCHS - 1;

        uint256 acc = lastUpdateAcc;
        uint256 e = lastUpdateEpoch;

        while (e < currentEpoch) {
            acc += BLOCKS_PER_EPOCH * yewPerBlockSchedule[e];
            emit EpochClosed(e, acc);
            e++;
        }

        uint256 currentEpochStart = _epochStartBlock(currentEpoch);
        uint256 blocksIntoCurrent = block.number > currentEpochStart
            ? block.number - currentEpochStart
            : 0;

        lastUpdateEpoch = currentEpoch;
        lastUpdateAcc   = acc;
        currentEpochAcc = acc + blocksIntoCurrent * yewPerBlockSchedule[currentEpoch];
    }

    // ---------------------------------------------------------------------------
    // PENDING YEW
    // ---------------------------------------------------------------------------

    function pendingYEW(address _user) external view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        if (user.shares == 0) return 0;

        uint256 currentEpoch = _getCurrentEpoch();
        if (currentEpoch >= MAX_EPOCHS) currentEpoch = MAX_EPOCHS - 1;

        uint256 acc = lastUpdateAcc;
        uint256 e = lastUpdateEpoch;

        while (e < currentEpoch) {
            acc += BLOCKS_PER_EPOCH * yewPerBlockSchedule[e];
            e++;
        }

        uint256 currentEpochStart = _epochStartBlock(currentEpoch);
        uint256 blocksIntoCurrent = block.number > currentEpochStart
            ? block.number - currentEpochStart
            : 0;
        acc += blocksIntoCurrent * yewPerBlockSchedule[currentEpoch];

        return (user.shares * (acc - user.rewardDebt)) / PCT;
    }

    // ---------------------------------------------------------------------------
    // USER INTERFACE
    // ---------------------------------------------------------------------------

    function deposit(uint256 amount) external nonReentrant {
        _updateReward(msg.sender);

        if (amount > 0) {
            LP_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
            userInfo[msg.sender].shares += amount;
            totalShares += amount;
        }

        _syncUserDebt(msg.sender);
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.shares >= amount, "YEW_VAULT: insufficient shares");

        _updateReward(msg.sender);

        user.shares -= amount;
        totalShares -= amount;
        LP_TOKEN.safeTransfer(msg.sender, amount);

        _syncUserDebt(msg.sender);
        emit Withdraw(msg.sender, amount, 0);
    }

    function harvest() external nonReentrant {
        _updateReward(msg.sender);
        _syncUserDebt(msg.sender);
    }

    // ---------------------------------------------------------------------------
    // INTERNAL REWARD
    // ---------------------------------------------------------------------------

    function _updateReward(address _user) internal {
        _updateRewardState();

        UserInfo storage user = userInfo[_user];
        if (user.shares == 0) return;

        uint256 pending = (user.shares * (currentEpochAcc - user.rewardDebt)) / PCT;

        if (pending > 0) {
            YEW_TOKEN.mint(_user, pending);
            emit Harvest(_user, pending);
        }
    }

    function _syncUserDebt(address _user) internal {
        UserInfo storage user = userInfo[_user];
        user.rewardDebt = currentEpochAcc;
        user.lastEpoch = _getCurrentEpoch();
    }

    // ---------------------------------------------------------------------------
    // OWNER
    // ---------------------------------------------------------------------------

    function setTreasuryWallet(address _wallet) external onlyOwner {
        require(_wallet != address(0), "YEW_VAULT: wallet zero");
        address old = treasuryWallet;
        treasuryWallet = _wallet;
        emit SetTreasuryWallet(old, _wallet);
    }

    function emergencyLpWithdraw(address lp, uint256 amount, address to) external onlyOwner {
        require(lp != address(YEW_TOKEN), "YEW_VAULT: protected");
        IERC20(lp).safeTransfer(to, amount);
    }

    receive() external payable {}
}
