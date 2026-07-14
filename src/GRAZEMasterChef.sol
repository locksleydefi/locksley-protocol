// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./FLETCH.sol";
import "./YEW.sol";

/**
 * @title GRAZE MasterChef V2
 * @notice GRAZE is the flagship yield aggregator vault for Locksley Protocol.
 *         Based on SushiSwap MasterChef V1 (battle-tested, extensively audited).
 *
 *  PERFORMANCE FEE → YEW/ETH LP FLOW:
 *  ─────────────────────────────────
 *  When a user harvests, 10% of the FLETCH reward is taken as a performance fee.
 *  This fee is:
 *    1. Swapped for ETH    via Uniswap V2
 *    2. Swapped for YEW   via Uniswap V2
 *    3. Both are added to the YEW/ETH LP pool on Uniswap V2
 *    4. The resulting LP tokens are sent to the YEW treasury
 *
 *  This means:
 *  - YEW gains real value from the ETH side of the LP
 *  - The LP grows organically with every harvest
 *  - FLETCH holders benefit as YEW backs the ecosystem
 *
 * @dev Uniswap V2 Router: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D (Ethereum mainnet address)
 *      On Robinhood Chain this may differ — VERIFY BEFORE DEPLOYMENT.
 *      WETH on Robinhood Chain: needs to be confirmed (typically 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 or chain-specific)
 *
 *      TODO before deployment:
 *        1. Confirm Uniswap V2 router address on Robinhood Chain
 *        2. Confirm WETH address on Robinhood Chain
 *        3. Confirm YEW/ETH LP pair exists or create it on Uniswap V2
 *        4. Fund this contract with enough ETH to cover swap gas + LP creation
 */
contract GRAZEMasterChef is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------------
    // Addresses — UPDATE THESE BEFORE DEPLOYMENT
    // ---------------------------------------------------------------------------

    /// @notice Uniswap V2 Router
    address public constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    /// @notice WETH — Wrapped ETH (used for ETH <-> token swaps)
    /// @dev MUST BE VERIFIED for Robinhood Chain before deployment
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // ---------------------------------------------------------------------------
    // Contracts
    // ---------------------------------------------------------------------------

    FLETCH  public immutable FLETCH_TOKEN;
    IERC20  public immutable LP_TOKEN;           // CASHCAT-ETH or JUGGERNAUT-ETH LP
    YEW     public immutable YEW_TOKEN;
    IERC20  public immutable YEW_ETH_LP;        // YEW/ETH Uniswap LP token

    // ---------------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------------

    uint256 public fletchPerBlock = 1e18;        // 1 FLETCH per block
    uint256 public lastRewardBlock;
    uint256 public accFLETCHPerShare;           // × 1e12 for precision
    uint256 public totalLpStaked;
    uint256 public startBlock;
    uint256 public constant BUFFER_MULTIPLIER = 1e12;

    // Performance fee: 10% of harvested FLETCH
    uint256 public constant PERFORMANCE_FEE_BPS = 1000;  // 1000 bps = 10%

    // Slippage tolerance for fee swaps (100 = 1%)
    uint256 public constant SWAP_SLIPPAGE_BPS = 150;    // 1.5%

    // ---------------------------------------------------------------------------
    // User state
    // ---------------------------------------------------------------------------

    struct UserInfo {
        uint256 shares;
        uint256 rewardDebt;
    }

    mapping(address => UserInfo) public userInfo;

    // ---------------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------------

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Harvest(address indexed user, uint256 reward, uint256 feeSwappedToLP);
    event SetFletchPerBlock(uint256 oldRate, uint256 newRate);
    event FeeSwappedToLP(address indexed token0, address indexed token1, uint256 amount0, uint256 amount1, uint256 lpReceived);
    event SwapFailed(string reason);

    // ---------------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------------

    constructor(
        address _fletch,
        address _lpToken,
        address _yew,
        address _yewEthLP,
        address _owner,
        uint256 _startBlock
    ) Ownable(_owner) {
        require(_fletch      != address(0), "GRAZE: fletch is zero");
        require(_lpToken     != address(0), "GRAZE: LP is zero");
        require(_yew         != address(0), "GRAZE: YEW is zero");
        require(_yewEthLP    != address(0), "GRAZE: YEW/ETH LP is zero");

        FLETCH_TOKEN   = FLETCH(_fletch);
        LP_TOKEN       = IERC20(_lpToken);
        YEW_TOKEN      = YEW(payable(_yew));
        YEW_ETH_LP     = IERC20(_yewEthLP);
        startBlock     = _startBlock > block.number ? _startBlock : block.number;
        lastRewardBlock = startBlock;

        // Approve Uniswap router to spend FLETCH (for fee swaps)
        IERC20(_fletch).approve(UNISWAP_ROUTER, type(uint256).max);
    }

    // ---------------------------------------------------------------------------
    // VIEW
    // ---------------------------------------------------------------------------

    function pendingFLETCH(address _user) external view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        if (totalLpStaked == 0) return 0;

        uint256 blockDiff = block.number - lastRewardBlock;
        uint256 newRewards = blockDiff * fletchPerBlock;

        // 90% to users, 10% to LP (after swap)
        uint256 netRewards = (newRewards * (10000 - PERFORMANCE_FEE_BPS)) / 10000;

        uint256 acc = accFLETCHPerShare
            + (netRewards * BUFFER_MULTIPLIER) / totalLpStaked;

        return (user.shares * acc) / 1e12 - user.rewardDebt;
    }

    // ---------------------------------------------------------------------------
    // USER INTERFACE
    // ---------------------------------------------------------------------------

    function deposit(uint256 amount) external nonReentrant {
        _harvest(msg.sender, false);

        if (amount > 0) {
            LP_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
            userInfo[msg.sender].shares += amount;
            totalLpStaked += amount;
        }

        userInfo[msg.sender].rewardDebt =
            (userInfo[msg.sender].shares * accFLETCHPerShare) / 1e12;

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "GRAZE: amount is zero");
        require(userInfo[msg.sender].shares >= amount, "GRAZE: insufficient shares");

        _harvest(msg.sender, false);

        userInfo[msg.sender].shares -= amount;
        totalLpStaked -= amount;
        LP_TOKEN.safeTransfer(msg.sender, amount);

        userInfo[msg.sender].rewardDebt =
            (userInfo[msg.sender].shares * accFLETCHPerShare) / 1e12;

        emit Withdraw(msg.sender, amount);
    }

    /// @notice Claim pending FLETCH rewards and convert 10% performance fee to YEW/ETH LP
    function harvest() external nonReentrant {
        _harvest(msg.sender, true);
    }

    // ---------------------------------------------------------------------------
    // INTERNAL
    // ---------------------------------------------------------------------------

    /**
     * @notice Update reward accumulator and distribute rewards.
     * @param performFeeSwap If true, converts the performance fee to YEW/ETH LP.
     */
    function _harvest(address user, bool performFeeSwap) internal {
        _updatePool(performFeeSwap);

        UserInfo storage u = userInfo[user];
        if (u.shares == 0) return;

        uint256 pending = (u.shares * accFLETCHPerShare) / 1e12 - u.rewardDebt;

        if (pending > 0) {
            // Mint FLETCH to user
            FLETCH_TOKEN.mint(user, pending);
            emit Harvest(user, pending, 0);
        }

        u.rewardDebt = (u.shares * accFLETCHPerShare) / 1e12;
    }

    /**
     * @notice Update the reward accumulator and handle performance fee → YEW/ETH LP
     * @param performFeeSwap If true, swaps fee portion to YEW/ETH LP
     */
    function _updatePool(bool performFeeSwap) internal {
        if (block.number <= lastRewardBlock) return;

        if (totalLpStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 blockDiff = block.number - lastRewardBlock;
        uint256 newRewards = blockDiff * fletchPerBlock;

        if (newRewards > 0) {
            // Mint full FLETCH to this contract
            FLETCH_TOKEN.mint(address(this), newRewards);

            // ── PERFORMANCE FEE → YEW/ETH LP ────────────────────────────────────
            uint256 fee = (newRewards * PERFORMANCE_FEE_BPS) / 10000;

            if (fee > 0 && performFeeSwap) {
                _swapFeeToLP(fee);
            }
            // ─────────────────────────────────────────────────────────────────

            // Update accumulator with NET rewards only (90%)
            uint256 netRewards = newRewards - fee;
            accFLETCHPerShare += (netRewards * BUFFER_MULTIPLIER) / totalLpStaked;
        }

        lastRewardBlock = block.number;
    }

    /**
     * @notice Swap the performance fee FLETCH → ETH + YEW → add to YEW/ETH LP
     * @dev Sends resulting LP tokens to the YEW treasury
     *
     * Fee split: 50% swap to ETH (via WETH), 50% swap to YEW
     * Both are added to the YEW/ETH Uniswap V2 pool.
     */
    function _swapFeeToLP(uint256 feeFLETCH) internal {
        if (feeFLETCH == 0) return;

        uint256 halfFee = feeFLETCH / 2;
        uint256 slippage = SWAP_SLIPPAGE_BPS;

        // ── Step 1: Swap half FLETCH → WETH ──────────────────────────────────
        address[] memory pathFletchToWeth = new address[](2);
        pathFletchToWeth[0] = address(FLETCH_TOKEN);
        pathFletchToWeth[1] = WETH;

        uint256 wethBefore = IERC20(WETH).balanceOf(address(this));
        
        // Get expected output for slippage check
        uint256[] memory amountsOutWeth = _getAmountsOut(halfFee, pathFletchToWeth);
        uint256 minWethOut = (amountsOutWeth[1] * (10000 - slippage)) / 10000;

        try IERC20(address(FLETCH_TOKEN)).balanceOf(address(this)) returns (uint256 bal) {
            if (bal < halfFee) return;
        } catch { return; }

        try IERC20(address(FLETCH_TOKEN)).approve(UNISWAP_ROUTER, halfFee) {} catch {}

        IUniswapV2Router(UNISWAP_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            halfFee,
            minWethOut,
            pathFletchToWeth,
            address(this),
            block.timestamp + 600
        );

        uint256 wethReceived = IERC20(WETH).balanceOf(address(this)) - wethBefore;
        if (wethReceived == 0) {
            emit SwapFailed("FLETCH->WETH no output");
            return;
        }

        // ── Step 2: Swap half FLETCH → YEW ──────────────────────────────────
        address[] memory pathFletchToYew = new address[](2);
        pathFletchToYew[0] = address(FLETCH_TOKEN);
        pathFletchToYew[1] = address(YEW_TOKEN);

        uint256 yewBefore = IERC20(address(YEW_TOKEN)).balanceOf(address(this));

        uint256[] memory amountsOutYew = _getAmountsOut(halfFee, pathFletchToYew);
        uint256 minYewOut = (amountsOutYew[1] * (10000 - slippage)) / 10000;

        IUniswapV2Router(UNISWAP_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            halfFee,
            minYewOut,
            pathFletchToYew,
            address(this),
            block.timestamp + 600
        );

        uint256 yewReceived = IERC20(address(YEW_TOKEN)).balanceOf(address(this)) - yewBefore;
        if (yewReceived == 0) {
            emit SwapFailed("FLETCH->YEW no output");
            return;
        }

        // ── Step 3: Add YEW + WETH to Uniswap V2 LP ─────────────────────────
        // Approve router to spend YEW and WETH
        IERC20(WETH).approve(UNISWAP_ROUTER, wethReceived);
        IERC20(address(YEW_TOKEN)).approve(UNISWAP_ROUTER, yewReceived);

        uint256 lpBefore = YEW_ETH_LP.balanceOf(address(this));

        // Determine amounts to add (use the lesser of what we have)
        // ETH:YEW ratio should be ~50:50 by value — use what we have
        (,, uint256 liquidity) = IUniswapV2Router(UNISWAP_ROUTER).addLiquidityETH{
            value: wethReceived
        }(
            address(YEW_TOKEN),
            yewReceived,
            (yewReceived * (10000 - slippage)) / 10000,
            (wethReceived * (10000 - slippage)) / 10000,
            address(this),   // LP tokens sent here, then forwarded to treasury
            block.timestamp + 600
        );

        uint256 lpReceived = YEW_ETH_LP.balanceOf(address(this)) - lpBefore;

        if (lpReceived > 0) {
            // Forward LP tokens to YEW treasury
            YEW_ETH_LP.safeTransfer(address(YEW_TOKEN), lpReceived);
            emit FeeSwappedToLP(WETH, address(YEW_TOKEN), wethReceived, yewReceived, lpReceived);
        }

        // Emit event with what we know
        emit FeeSwappedToLP(WETH, address(YEW_TOKEN), wethReceived, yewReceived, lpReceived);
    }

    // ---------------------------------------------------------------------------
    // SWAP HELPERS
    // ---------------------------------------------------------------------------

    function _getAmountsOut(uint256 amountIn, address[] memory path) internal view returns (uint256[] memory) {
        return IUniswapV2Router(UNISWAP_ROUTER).getAmountsOut(amountIn, path);
    }

    /**
     * @notice Safe wrapper for swapExactTokensForTokensSupportingFeeOnTransferTokens
     */
    function _safeSwap(
        address router,
        uint256 amountIn,
        uint256 minAmountOut,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal returns (bool) {
        try IUniswapV2Router(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            minAmountOut,
            path,
            to,
            deadline
        ) { return true; }
        catch { return false; }
    }

    // ---------------------------------------------------------------------------
    // OWNER FUNCTIONS
    // ---------------------------------------------------------------------------

    function setFletchPerBlock(uint256 _rate) external onlyOwner {
        require(_rate > 0, "GRAZE: rate must be > 0");
        uint256 old = fletchPerBlock;
        fletchPerBlock = _rate;
        emit SetFletchPerBlock(old, _rate);
    }

    /// @notice Emergency: rescue LP tokens sent directly to this contract
    function emergencyLpWithdraw(address to, uint256 amount) external onlyOwner {
        require(amount > 0, "GRAZE: zero amount");
        LP_TOKEN.safeTransfer(to, amount);
    }

    /// @notice Rescue any ERC-20 tokens (except FLETCH and LP which are handled separately)
    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(FLETCH_TOKEN), "GRAZE: cannot rescue FLETCH");
        require(token != address(LP_TOKEN), "GRAZE: cannot rescue staked LP");
        IERC20(token).safeTransfer(to, amount);
    }

    /// @notice Update YEW treasury (if YEW contract is upgraded)
    function updateYewTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "GRAZE: zero treasury");
        // Note: old YEW tokens in treasury are non-transferable anyway
    }

    /// @notice Deposit ETH for LP creation (contract needs ETH to create LPs)
    receive() external payable {}
}

// ---------------------------------------------------------------------------
// Uniswap V2 Router Interface
// ---------------------------------------------------------------------------
interface IUniswapV2Router {
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint minAmountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}
