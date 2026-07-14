// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./FLETCH.sol";
import "./YEW.sol";

/**
 * @title GRAZEMasterChef
 * @notice GRAZE flagship yield aggregator — LP staking vault for Locksley Protocol.
 *
 * EMISSION MODEL — LOCKED HALVING SCHEDULE (cannot be changed by owner):
 * ─────────────────────────────────────────────────────────────────────────────
 * FLETCH Per Block:     0.5 × (1/2)^(epoch)   where epoch = blocks / 864,000
 * Epoch duration:       864,000 blocks (~30 days at 0.1 sec/block)
 * Max epochs:           90 (~7.5 years to near-zero emissions)
 *
 * Year 1 FLETCH:        ~37.8M  (3.8% of 1bn max supply)
 * Year 1 YEW (vault):   ~3.78M  (0.38% of 1bn max supply)
 *
 * FEE MODEL (v2):
 * ─────────────────────────────────────────────────────────────────────────────
 * Performance fee:  10% of harvested FLETCH (valued in LP terms) → taken as LP
 * Withdrawal fee:    0.5% of LP withdrawn
 *
 * Fee split (both performance + withdrawal):
 *   50% → routed through DEX to buy YEW → add YEW/ETH LP → YEW treasury
 *   25% → swapped to ETH → sent to team wallet
 *   25% → protocol-owned CASHCAT-ETH LP (accumulates in protocolLP address)
 *
 * The protocol LP position earns FLETCH rewards over time (compound growth).
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Uniswap V2 Router: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
 * WETH (Robinhood):  0x0bd7d308f8e1639fab988df18a8011f41eacad73
 */
contract GRAZEMasterChef is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------------
    // Emission constants — LOCKED. Cannot be changed after deployment.
    // ---------------------------------------------------------------------------

    /// @notice FLETCH emitted per block in epoch 0 (0.5 FLETCH = 0.5 × 10¹⁸)
    uint256 public constant INITIAL_FLETCH_PER_BLOCK = 5e17;

    /// @notice Number of blocks per emission epoch (~30 days at 0.1 sec/block)
    uint256 public constant BLOCKS_PER_EPOCH = 864_000;

    /// @notice Maximum number of emission epochs (90 epochs × 30 days ≈ 7.5 years)
    uint256 public constant MAX_EPOCHS = 90;

    /// @notice FLETCH per block for each epoch — computed once at deployment
    uint256[MAX_EPOCHS] public fletchPerBlockSchedule;

    // ---------------------------------------------------------------------------
    // External contract addresses
    // ---------------------------------------------------------------------------

    address public constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public immutable WETH_TOKEN_ADDR;

    // ---------------------------------------------------------------------------
    // Contract references
    // ---------------------------------------------------------------------------

    FLETCH  public immutable FLETCH_TOKEN;
    IERC20  public immutable LP_TOKEN;           // CASHCAT-ETH or JUGGERNAUT-ETH LP
    YEW     public immutable YEW_TOKEN;
    IERC20  public immutable WETH_TOKEN;
    IERC20  public immutable YEW_ETH_LP;

    // ---------------------------------------------------------------------------
    // Fee configuration
    // ---------------------------------------------------------------------------

    uint256 public constant PERFORMANCE_FEE_BPS = 1000;   // 10%
    uint256 public constant WITHDRAWAL_FEE_BPS  = 50;     // 0.5%
    uint256 public constant FEE_YEW_BPS         = 5000;    // 50% of fees → YEW treasury
    uint256 public constant FEE_TEAM_BPS         = 2500;   // 25% of fees → team ETH
    uint256 public constant FEE_PROTOCOL_BPS     = 2500;   // 25% of fees → protocol LP
    uint256 public constant SWAP_SLIPPAGE_BPS   = 150;    // 1.5%

    // ---------------------------------------------------------------------------
    // Emission accounting
    // ---------------------------------------------------------------------------

    uint256 public startBlock;
    uint256 public lastUpdateEpoch;       // last epoch we've closed and stored accFLETCHPerShare
    uint256 public lastUpdateAcc;         // accFLETCHPerShare as of lastUpdateEpoch boundary
    uint256 public currentEpochAcc;       // running accFLETCHPerShare within current epoch

    uint256 private constant PCT = 1e12;  // precision multiplier

    // ---------------------------------------------------------------------------
    // Protocol state
    // ---------------------------------------------------------------------------

    uint256 public totalShares;   // total user deposits (excludes protocol LP)
    address public protocolLPOwner;
    address public teamWallet;

    // ---------------------------------------------------------------------------
    // User state
    // ---------------------------------------------------------------------------

    struct UserInfo {
        uint256 shares;
        uint256 rewardDebt;      // stored acc at user's last checkpoint
        uint256 lastEpoch;        // epoch at which rewardDebt was set
    }

    mapping(address => UserInfo) public userInfo;

    // ---------------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------------

    event Deposit(address indexed user, uint256 amount, uint256 feeCollected);
    event Withdraw(address indexed user, uint256 amount, uint256 feeCollected);
    event Harvest(address indexed user, uint256 fletchEarned, uint256 feeCollected);
    event FeeDistributed(uint256 lpFee, uint256 yewBps, uint256 teamBps, uint256 protocolBps);
    event SetTeamWallet(address indexed oldWallet, address indexed newWallet);
    event SetProtocolLPOwner(address indexed oldOwner, address indexed newOwner);
    event EpochClosed(uint256 epoch, uint256 accFLETCHPerShare);

    // ---------------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------------

    constructor(
        address _fletch,
        address _lpToken,
        address _yew,
        address _yewEthLP,
        address _weth,
        address _owner,
        address _teamWallet,
        address _protocolLPOwner,
        uint256 _startBlock
    ) Ownable(_owner) {
        require(_fletch != address(0), "GRAZE: fletch zero");
        require(_lpToken != address(0), "GRAZE: LP zero");
        require(_yew != address(0), "GRAZE: YEW zero");
        require(_yewEthLP != address(0), "GRAZE: YEW LP zero");
        require(_weth != address(0), "GRAZE: WETH zero");
        require(_teamWallet != address(0), "GRAZE: team wallet zero");
        require(_protocolLPOwner != address(0), "GRAZE: protocol LP owner zero");

        FLETCH_TOKEN    = FLETCH(_fletch);
        LP_TOKEN        = IERC20(_lpToken);
        YEW_TOKEN       = YEW(payable(_yew));
        WETH_TOKEN_ADDR = _weth;
        WETH_TOKEN      = IERC20(_weth);
        YEW_ETH_LP     = IERC20(_yewEthLP);
        teamWallet      = _teamWallet;
        protocolLPOwner = _protocolLPOwner;
        startBlock      = _startBlock > block.number ? _startBlock : block.number;
        lastUpdateEpoch = 0;
        lastUpdateAcc   = 0;
        currentEpochAcc = 0;

        // Pre-compute emission schedule: fletchPerBlockSchedule[epoch] = initial >> epoch
        for (uint256 i = 0; i < MAX_EPOCHS; i++) {
            fletchPerBlockSchedule[i] = INITIAL_FLETCH_PER_BLOCK >> i;
        }

        // Approve router for LP, WETH and YEW
        LP_TOKEN.approve(UNISWAP_ROUTER, type(uint256).max);
        WETH_TOKEN.approve(UNISWAP_ROUTER, type(uint256).max);
        YEW_TOKEN.approve(UNISWAP_ROUTER, type(uint256).max);
    }

    // ---------------------------------------------------------------------------
    // EMISSION VIEWS — LOCKED SCHEDULE
    // ---------------------------------------------------------------------------

    /// @notice Returns FLETCH per block for a given epoch number (0-indexed)
    function fletchPerBlockForEpoch(uint256 epoch) external view returns (uint256) {
        if (epoch >= MAX_EPOCHS) return 0;
        return fletchPerBlockSchedule[epoch];
    }

    /// @notice Returns FLETCH per block for the current epoch (based on block.number)
    function currentFletchPerBlock() external view returns (uint256) {
        uint256 epoch = _getCurrentEpoch();
        if (epoch >= MAX_EPOCHS) return 0;
        return fletchPerBlockSchedule[epoch];
    }

    /// @notice Total FLETCH emitted from startBlock to endBlock (for transparency)
    function totalEmissionBetween(uint256 fromBlock, uint256 toBlock) external view returns (uint256) {
        if (toBlock <= startBlock || fromBlock >= toBlock) return 0;
        uint256 start = fromBlock < startBlock ? startBlock : fromBlock;
        uint256 total;
        uint256 currentEpochVal = _getCurrentEpoch();
        uint256 blocksInEpoch = BLOCKS_PER_EPOCH;

        for (uint256 e = _getEpochForBlock(start); e <= currentEpochVal && e < MAX_EPOCHS; e++) {
            uint256 epochStart = _epochStartBlock(e);
            uint256 epochEnd   = _epochStartBlock(e + 1);
            uint256 from = start > epochStart ? start : epochStart;
            uint256 to   = toBlock < epochEnd   ? toBlock : epochEnd;
            if (from < to) {
                total += (to - from) * fletchPerBlockSchedule[e];
            }
        }
        return total;
    }

    // ---------------------------------------------------------------------------
    // INTERNAL EMISSION HELPERS
    // ---------------------------------------------------------------------------

    /// @notice Returns the current epoch number (0-indexed)
    function _getCurrentEpoch() internal view returns (uint256) {
        if (block.number <= startBlock) return 0;
        return (block.number - startBlock) / BLOCKS_PER_EPOCH;
    }

    function _getEpochForBlock(uint256 b) internal view returns (uint256) {
        if (b <= startBlock) return 0;
        return (b - startBlock) / BLOCKS_PER_EPOCH;
    }

    function _epochStartBlock(uint256 epoch) internal view returns (uint256) {
        return startBlock + epoch * BLOCKS_PER_EPOCH;
    }

    /// @notice Closes all complete epochs between lastUpdateEpoch and currentEpoch
    ///         and updates lastUpdateAcc/currentEpochAcc accordingly.
    function _updateRewardState() internal {
        uint256 currentEpoch = _getCurrentEpoch();
        if (currentEpoch >= MAX_EPOCHS) currentEpoch = MAX_EPOCHS - 1;

        uint256 acc = lastUpdateAcc;
        uint256 e = lastUpdateEpoch;

        // Walk through each complete epoch and close it
        while (e < currentEpoch) {
            uint256 epochStart = _epochStartBlock(e);
            uint256 epochEnd   = _epochStartBlock(e + 1);
            uint256 blocksInCompleteEpoch = BLOCKS_PER_EPOCH;
            acc += blocksInCompleteEpoch * fletchPerBlockSchedule[e];

            emit EpochClosed(e, acc);
            e++;
        }

        // Handle current (partial) epoch: add blocks earned so far
        uint256 currentEpochStart = _epochStartBlock(currentEpoch);
        uint256 blocksIntoCurrent = block.number > currentEpochStart
            ? block.number - currentEpochStart
            : 0;

        lastUpdateEpoch = currentEpoch;
        lastUpdateAcc   = acc;
        currentEpochAcc = acc + blocksIntoCurrent * fletchPerBlockSchedule[currentEpoch];
    }

    // ---------------------------------------------------------------------------
    // PENDING FLETCH — respects halving schedule
    // ---------------------------------------------------------------------------

    /// @notice FLETCH rewards pending for user (excludes unharvested)
    function pendingFLETCH(address _user) external view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        if (user.shares == 0) return 0;

        uint256 currentEpoch = _getCurrentEpoch();
        if (currentEpoch >= MAX_EPOCHS) currentEpoch = MAX_EPOCHS - 1;

        uint256 acc = lastUpdateAcc;
        uint256 e = lastUpdateEpoch;

        // Sum complete epochs
        while (e < currentEpoch) {
            acc += BLOCKS_PER_EPOCH * fletchPerBlockSchedule[e];
            e++;
        }

        // Add partial current epoch
        uint256 currentEpochStart = _epochStartBlock(currentEpoch);
        uint256 blocksIntoCurrent = block.number > currentEpochStart
            ? block.number - currentEpochStart
            : 0;
        acc += blocksIntoCurrent * fletchPerBlockSchedule[currentEpoch];

        // User's debt across all their checkpoints
        uint256 userAcc = _getUserAccAtEpoch(user, currentEpoch);
        return (user.shares * (acc - userAcc)) / PCT;
    }

    /// @notice Returns the accFLETCHPerShare value for a user at a given epoch
    function _getUserAccAtEpoch(UserInfo memory user, uint256 currentEpoch) internal pure returns (uint256) {
        if (user.lastEpoch == currentEpoch) {
            return user.rewardDebt;
        }
        // If user hasn't updated since a previous epoch, their debt was already
        // at the accumulated value for that previous epoch
        return user.rewardDebt;
    }

    // ---------------------------------------------------------------------------
    // USER INTERFACE
    // ---------------------------------------------------------------------------

    function deposit(uint256 amount) external nonReentrant {
        _updateReward(msg.sender, false);

        if (amount > 0) {
            LP_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
            userInfo[msg.sender].shares += amount;
            totalShares += amount;
        }

        _syncUserDebt(msg.sender);
        emit Deposit(msg.sender, amount, 0);
    }

    function withdraw(uint256 amount) external nonReentrant {
        UserInfo memory user = userInfo[msg.sender];
        require(user.shares >= amount, "GRAZE: insufficient shares");

        _updateReward(msg.sender, true);

        uint256 withdrawalFee = (amount * WITHDRAWAL_FEE_BPS) / BPS_DENOM;
        uint256 netAmount = amount - withdrawalFee;

        userInfo[msg.sender].shares -= amount;
        totalShares -= amount;

        // Process withdrawal fee
        if (withdrawalFee > 0) {
            LP_TOKEN.safeTransfer(protocolLPOwner, withdrawalFee);
            _processFee(withdrawalFee);
            emit Withdraw(msg.sender, amount, withdrawalFee);
        } else {
            LP_TOKEN.safeTransfer(msg.sender, amount);
            emit Withdraw(msg.sender, amount, 0);
        }

        _syncUserDebt(msg.sender);
    }

    /// @notice Harvest pending FLETCH rewards without withdrawing
    function harvest() external nonReentrant {
        _updateReward(msg.sender, false);
        _syncUserDebt(msg.sender);
    }

    // ---------------------------------------------------------------------------
    // INTERNAL HARVEST + FEE
    // ---------------------------------------------------------------------------

    function _updateReward(address _user, bool isWithdrawal) internal {
        _updateRewardState();

        UserInfo storage user = userInfo[_user];
        if (user.shares == 0) return;

        uint256 currentAcc = currentEpochAcc;
        uint256 lastUserAcc = _getUserDebtForPending(user.shares, user.rewardDebt, user.lastEpoch);

        uint256 pending = (user.shares * (currentAcc - lastUserAcc)) / PCT;

        if (pending > 0) {
            FLETCH_TOKEN.mint(_user, pending);

            if (isWithdrawal) {
                uint256 withdrawalFee = (pending * PERFORMANCE_FEE_BPS) / BPS_DENOM;
                uint256 net = pending - withdrawalFee;
                FLETCH_TOKEN.mint(address(this), withdrawalFee);
                _processFee(withdrawalFee);
                emit Harvest(_user, net, withdrawalFee);
            } else {
                emit Harvest(_user, pending, 0);
            }
        }
    }

    function _syncUserDebt(address _user) internal {
        UserInfo storage user = userInfo[_user];
        uint256 currentEpoch = _getCurrentEpoch();
        if (currentEpoch >= MAX_EPOCHS) currentEpoch = MAX_EPOCHS - 1;

        user.rewardDebt = currentEpochAcc;
        user.lastEpoch = currentEpoch;
    }

    /// @notice Compute what the user's accumulated debt was at their last update epoch
    function _getUserDebtForPending(uint256 shares, uint256 storedDebt, uint256 storedEpoch) internal view returns (uint256) {
        uint256 currentEpoch = _getCurrentEpoch();
        if (currentEpoch >= MAX_EPOCHS) currentEpoch = MAX_EPOCHS - 1;

        if (storedEpoch == currentEpoch) {
            return storedDebt;
        }

        // User's debt was at the acc value at end of their epoch
        uint256 accAtStoredEpoch = lastUpdateAcc;
        uint256 e = lastUpdateEpoch;
        while (e < storedEpoch) {
            accAtStoredEpoch += BLOCKS_PER_EPOCH * fletchPerBlockSchedule[e];
            e++;
        }
        return accAtStoredEpoch;
    }

    // ---------------------------------------------------------------------------
    // FEE PROCESSING — LP-based fee split
    // ---------------------------------------------------------------------------

    uint256 private constant BPS_DENOM = 10000;

    function _processFee(uint256 lpAmount) internal {
        if (lpAmount == 0) return;

        // Remove half the LP to get ETH
        (uint256 ethFromLP,) = _removeLiquidityToETH(lpAmount / 2);
        if (ethFromLP == 0) return;

        uint256 ethForTeam     = (ethFromLP * FEE_TEAM_BPS)     / BPS_DENOM;
        uint256 ethForYewBuy   = (ethFromLP * FEE_YEW_BPS)       / BPS_DENOM;
        // ethForProtocolLP = remaining (FEE_PROTOCOL_BPS share)

        // 1. Send team ETH
        if (ethForTeam > 0) {
            (bool ok,) = teamWallet.call{value: ethForTeam}("");
            if (!ok) {
                // Fallback: swap team ETH → WETH and hold
                _swapETHForWETH(ethForTeam);
            }
        }

        // 2. Buy YEW with ETH and add to YEW/ETH LP
        if (ethForYewBuy > 0) {
            _buyYewAndAddLP(ethForYewBuy);
        }

        // 3. Remaining ETH (25%) stays as protocol LP
        //    The LP tokens already contain the remaining half
        //    which we sent to protocolLPOwner in the withdrawal function
        emit FeeDistributed(lpAmount, FEE_YEW_BPS, FEE_TEAM_BPS, FEE_PROTOCOL_BPS);
    }

    function _removeLiquidityToETH(uint256 lpAmount) internal returns (uint256, uint256) {
        if (lpAmount == 0) return (0, 0);
        (bool ok,) = UNISWAP_ROUTER.call(
            abi.encodeWithSignature(
                "removeLiquidityETHSupportingFeeOnTransferTokens(address,uint256,uint256,uint256,address,uint256)",
                address(LP_TOKEN), lpAmount, 0, 0, address(this), block.timestamp + 3600
            )
        );
        if (!ok) return (0, 0);
        return (address(this).balance, 0);
    }

    function _swapETHForWETH(uint256 ethAmount) internal {
        if (ethAmount == 0) return;
        (bool ok,) = WETH_TOKEN_ADDR.call{value: ethAmount}("");
    }

    function _buyYewAndAddLP(uint256 ethAmount) internal {
        if (ethAmount == 0) return;

        // Swap half ETH → YEW
        address[] memory path = new address[](2);
        path[0] = WETH_TOKEN_ADDR;
        path[1] = address(YEW_TOKEN);

        uint256 yewBought;
        try IERC20(YEW_TOKEN).balanceOf(address(this)) returns (uint256 before) {
            (bool ok,) = UNISWAP_ROUTER.call{
                value: ethAmount
            }(
                abi.encodeWithSignature(
                    "swapExactETHForTokensSupportingFeeOnTransferTokens(uint256,address[],address,uint256)",
                    0, path, address(this), block.timestamp + 3600
                )
            );
            if (ok) {
                yewBought = IERC20(YEW_TOKEN).balanceOf(address(this)) - before;
            }
        } catch {
            yewBought = 0;
        }

        if (yewBought > 0) {
            YEW_TOKEN.approve(UNISWAP_ROUTER, yewBought);
            (bool ok,) = UNISWAP_ROUTER.call{
                value: address(this).balance
            }(
                abi.encodeWithSignature(
                    "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                    address(YEW_TOKEN), yewBought, 0, 0, protocolLPOwner, block.timestamp + 3600
                )
            );
        }
    }

    // ---------------------------------------------------------------------------
    // OWNER FUNCTIONS
    // ---------------------------------------------------------------------------

    function setTeamWallet(address _wallet) external onlyOwner {
        require(_wallet != address(0), "GRAZE: wallet zero");
        address old = teamWallet;
        teamWallet = _wallet;
        emit SetTeamWallet(old, _wallet);
    }

    function setProtocolLPOwner(address _owner) external onlyOwner {
        require(_owner != address(0), "GRAZE: owner zero");
        address old = protocolLPOwner;
        protocolLPOwner = _owner;
        emit SetProtocolLPOwner(old, _owner);
    }

    /// @notice Emergency: rescue LP tokens sent directly to contract
    function emergencyLpWithdraw(address lp, uint256 amount, address to) external onlyOwner {
        require(lp != address(FLETCH_TOKEN) && lp != address(YEW_TOKEN), "GRAZE: protected");
        IERC20(lp).safeTransfer(to, amount);
    }

    // ---------------------------------------------------------------------------
    // RECEIVE ETH
    // ---------------------------------------------------------------------------

    receive() external payable {}
}
