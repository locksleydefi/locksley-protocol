// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./FLETCH.sol";

/**
 * @title GRAZE Vault
 * @notice GRAZE is the flagship yield aggregator vault for Locksley Protocol.
 *
 *         Users deposit LP tokens and earn FLETCH rewards.
 *         Rewards are minted by this vault and distributed to stakers.
 *         Users claim their pending FLETCH by calling claimFLETCH().
 *
 *         Fee structure:
 *           - Performance fee: 10% of harvested yield → sent to YEW treasury
 *           - Withdrawal fee: 0.5% of withdrawn LP → sent to YEW treasury
 *
 *         Reward math (MasterChef-style):
 *           - accFLETCHPerShare accumulates per second based on rewardRate
 *           - pendingFLETCH[user] = shares[user] × accFLETCHPerShare − userRewardDebt[user]
 *           - User's debt is updated on every deposit/withdraw/claim
 *
 * @dev MVP: single reward token (FLETCH) and single staking token (LP).
 *       Future: upgradeable to support multiple LPs and reward tokens.
 */
contract GRAZEVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------------
    // Immutable config
    // ---------------------------------------------------------------------------

    IERC20  public immutable stakingToken;  // LP token users deposit
    FLETCH  public immutable fletch;          // Reward token
    address public immutable yew;             // YEW treasury (receives fees)

    // ---------------------------------------------------------------------------
    // Reward accounting
    // ---------------------------------------------------------------------------

    /// @notice Accumulated FLETCH per share (multiplied by 1e12 for precision)
    uint256 public accFLETCHPerShare;

    /// @notice Last block.timestamp rewards were updated
    uint256 public lastRewardTime;

    /// @notice FLETCH per second distributed (in wei). Set by owner after launch.
    uint256 public rewardRate;

    // ---------------------------------------------------------------------------
    // Staker accounting
    // ---------------------------------------------------------------------------

    uint256 public totalShares;

    mapping(address => uint256) public shares;
    /// @notice Reward debt — used to calculate pending rewards correctly
    mapping(address => uint256) public rewardDebt;

    // ---------------------------------------------------------------------------
    // Fee config
    // ---------------------------------------------------------------------------

    uint256 public performanceFeeNumerator  = 1000;  // 1000/10000 = 10%
    uint256 public withdrawalFeeNumerator    = 50;    // 50/10000   = 0.5%
    uint256 public constant FEE_DIVISOR      = 10000;

    // ---------------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------------

    event Deposit(address indexed user, uint256 amount, uint256 sharesMinted);
    event Withdraw(address indexed user, uint256 lpReturned, uint256 sharesBurned, uint256 feePaid);
    event ClaimFLETCH(address indexed user, uint256 amount);
    event Harvest(address indexed harvester, uint256 rewardMinted, uint256 feeToYEW);
    event UpdateFees(uint256 performanceFeeNumerator, uint256 withdrawalFeeNumerator);
    event SetRewardRate(uint256 oldRate, uint256 newRate);

    // ---------------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------------

    constructor(
        address _stakingToken,
        address _fletch,
        address _yew,
        address _owner
    ) Ownable(_owner) {
        require(_stakingToken != address(0), "GRAZE: zero staking token");
        require(_fletch    != address(0), "GRAZE: zero fletch");
        require(_yew       != address(0), "GRAZE: zero yew");
        stakingToken = IERC20(_stakingToken);
        fletch       = FLETCH(_fletch);
        yew          = _yew;
        lastRewardTime = block.timestamp;
    }

    // ---------------------------------------------------------------------------
    // VIEW
    // ---------------------------------------------------------------------------

    /**
     * @notice Returns pending FLETCH rewards for a user.
     */
    function pendingFLETCH(address user) external view returns (uint256) {
        uint256 _shares = shares[user];
        if (_shares == 0) return 0;
        uint256 _acc = accFLETCHPerShare;
        uint256 _last = lastRewardTime;
        uint256 _rate = rewardRate;
        uint256 _total = totalShares;

        uint256 timeElapsed = block.timestamp - _last;
        uint256 newRewards  = timeElapsed * _rate;

        uint256 newAcc = _total > 0
            ? _acc + (newRewards * 1e12) / _total
            : _acc;

        return (_shares * newAcc) / 1e12 - rewardDebt[user];
    }

    // ---------------------------------------------------------------------------
    // USER INTERFACE
    // ---------------------------------------------------------------------------

    /**
     * @notice Deposit LP tokens. Automatically claims pending FLETCH first.
     * @param amount Amount of LP tokens to deposit.
     */
    function deposit(uint256 amount) external nonReentrant {
        _updateRewards(msg.sender);
        _deposit(amount);
    }

    /**
     * @notice Withdraw LP tokens. Automatically claims pending FLETCH first.
     * @param sharesToRedeem Number of shares to redeem (1:1 with LP).
     */
    function withdraw(uint256 sharesToRedeem) external nonReentrant {
        require(sharesToRedeem > 0, "GRAZE: zero amount");
        require(shares[msg.sender] >= sharesToRedeem, "GRAZE: insufficient shares");
        _updateRewards(msg.sender);
        _withdraw(sharesToRedeem);
    }

    /**
     * @notice Claim pending FLETCH rewards without touching your deposit.
     */
    function claimFLETCH() external nonReentrant {
        _updateRewards(msg.sender);
        uint256 pending = pendingFLETCH(msg.sender);
        require(pending > 0, "GRAZE: nothing to claim");
        rewardDebt[msg.sender] = (shares[msg.sender] * accFLETCHPerShare) / 1e12;
        fletch.transfer(msg.sender, pending);
        emit ClaimFLETCH(msg.sender, pending);
    }

    /**
     * @notice Harvest and compound rewards. Callable by anyone (keeper/public).
     *         10% performance fee is sent to YEW treasury.
     */
    function harvest() external nonReentrant {
        _updateRewards(msg.sender);
        uint256 vaultBalance = fletch.balanceOf(address(this));

        if (totalShares == 0) {
            lastRewardTime = block.timestamp;
            return;
        }

        // Mint new rewards for stakers
        uint256 timeElapsed = block.timestamp - lastRewardTime;
        uint256 newRewards  = timeElapsed * rewardRate;

        if (newRewards > 0) {
            fletch.mint(address(this), newRewards);

            // Performance fee: 10% to YEW
            uint256 fee = (newRewards * performanceFeeNumerator) / FEE_DIVISOR;
            uint256 netReward = newRewards - fee;

            if (fee > 0) {
                fletch.transfer(yew, fee);
            }

            emit Harvest(msg.sender, netReward, fee);
        }

        lastRewardTime = block.timestamp;
    }

    // ---------------------------------------------------------------------------
    // INTERNAL HELPERS
    // ---------------------------------------------------------------------------

    function _deposit(uint256 amount) internal {
        require(amount > 0, "GRAZE: zero amount");

        // Pull LP tokens from user
        uint256 before = stakingToken.balanceOf(address(this));
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = stakingToken.balanceOf(address(this)) - before;

        // Apply withdrawal fee on deposit: 0.5%
        uint256 fee = (received * withdrawalFeeNumerator) / FEE_DIVISOR;
        uint256 net = received - fee;

        if (fee > 0) {
            stakingToken.safeTransfer(yew, fee);
        }

        // Mint shares 1:1
        uint256 sharesToMint = net;
        shares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;

        // Update reward debt
        rewardDebt[msg.sender] = (shares[msg.sender] * accFLETCHPerShare) / 1e12;

        emit Deposit(msg.sender, net, sharesToMint);
    }

    function _withdraw(uint256 sharesToRedeem) internal {
        uint256 lpAmount = sharesToRedeem;

        // Burn shares
        shares[msg.sender] -= sharesToRedeem;
        totalShares -= sharesToRedeem;

        // Send LP to user
        stakingToken.safeTransfer(msg.sender, lpAmount);

        // Update reward debt
        rewardDebt[msg.sender] = (shares[msg.sender] * accFLETCHPerShare) / 1e12;

        emit Withdraw(msg.sender, lpAmount, sharesToRedeem, 0);
    }

    /**
     * @notice Update accFLETCHPerShare and lastRewardTime.
     *         Also updates the user's pendingFLETCH tracker (transferred to rewardDebt).
     */
    function _updateRewards(address user) internal {
        uint256 _totalShares = totalShares;
        uint256 _last = lastRewardTime;
        uint256 _rate = rewardRate;

        // Nothing staked yet
        if (_totalShares == 0) {
            lastRewardTime = block.timestamp;
            return;
        }

        // Calculate new rewards since last update
        uint256 timeElapsed = block.timestamp - _last;
        if (timeElapsed == 0) return;

        uint256 newRewards = timeElapsed * _rate;
        if (newRewards > 0) {
            // Mint rewards to vault
            fletch.mint(address(this), newRewards);

            // Update accumulator
            accFLETCHPerShare += (newRewards * 1e12) / _totalShares;
        }

        lastRewardTime = block.timestamp;

        // Update caller's pending → move into rewardDebt
        if (user != address(0) && shares[user] > 0) {
            // pending was already computed as shares * old acc / 1e12 - rewardDebt
            // after updating acc we just reset their debt to the new value
            rewardDebt[user] = (shares[user] * accFLETCHPerShare) / 1e12;
        }
    }

    // ---------------------------------------------------------------------------
    // OWNER FUNCTIONS
    // ---------------------------------------------------------------------------

    /**
     * @notice Set the FLETCH reward rate per second (wei).
     *         Called by owner after launch to start emissions.
     * @param _rate FLETCH per second (e.g. 1e18 = 1 FLETCH/sec across all stakers).
     */
    function setRewardRate(uint256 _rate) external onlyOwner {
        // Update rewards before changing rate
        if (totalShares > 0) {
            _updateRewards(address(0));
        }
        uint256 oldRate = rewardRate;
        rewardRate = _rate;
        lastRewardTime = block.timestamp;
        emit SetRewardRate(oldRate, _rate);
    }

    /**
     * @notice Update fee configuration.
     * @param _performanceFee  Out of FEE_DIVISOR (10000). 1000 = 10%.
     * @param _withdrawalFee  Out of FEE_DIVISOR (10000). 50 = 0.5%.
     */
    function setFees(uint256 _performanceFee, uint256 _withdrawalFee) external onlyOwner {
        require(_performanceFee <= 2000, "GRAZE: perf fee max 20%");
        require(_withdrawalFee   <= 500,  "GRAZE: wdw fee max 5%");
        performanceFeeNumerator = _performanceFee;
        withdrawalFeeNumerator   = _withdrawalFee;
        emit UpdateFees(_performanceFee, _withdrawalFee);
    }

    /**
     * @notice Emergency: rescue LP tokens sent directly to the vault.
     *         Should only be used in emergencies.
     */
    function emergencyWithdrawLPs(address to, uint256 amount) external onlyOwner {
        require(amount > 0, "GRAZE: zero amount");
        stakingToken.safeTransfer(to, amount);
    }
}
