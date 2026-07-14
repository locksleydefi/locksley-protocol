// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {FLETCH} from "../src/FLETCH.sol";
import {YEW} from "../src/YEW.sol";
import {GRAZEVault} from "../src/GRAZEVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GRAZETest is Test {
    FLETCH   public fletch;
    YEW      public yew;
    GRAZEVault public vault;

    IERC20  public stakingToken; // Mock LP token

    address public alice = address(0xA11CE);
    address public bob   = address(0xB0B);
    address public owner = address(0x0000000000000000000000000000000000000001);

    function setUp() public {
        // Deploy mock LP token (ERC20 for testing)
        stakingToken = IERC20(address(new MockERC20("LP Token", "LP", 18)));

        // Deploy protocol contracts
        fletch = new FLETCH(owner);
        yew    = new YEW(owner);

        vault = new GRAZEVault(
            address(stakingToken),
            address(fletch),
            address(yew),
            owner
        );

        // Authorize vault to mint FLETCH
        fletch.setVault(address(vault), true);

        // Fund Alice and Bob with LP tokens for testing
        MockERC20(address(stakingToken)).mint(alice, 1000e18);
        MockERC20(address(stakingToken)).mint(bob,   1000e18);

        // Approve vault to spend LP
        vm.prank(alice);
        stakingToken.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        stakingToken.approve(address(vault), type(uint256).max);
    }

    // -------------------------------------------------------------------------
    // Basic Deployment Tests
    // -------------------------------------------------------------------------

    function test_VaultDeployed() public {
        assertEq(address(vault.stakingToken()), address(stakingToken));
        assertEq(address(vault.fletch()),      address(fletch));
        assertEq(address(vault.yew()),         address(yew));
        assertEq(vault.totalShares(), 0);
    }

    function test_FLETCHMintOnlyByVault() public {
        vm.prank(alice);
        vm.expectRevert("FLETCH: caller is not an authorized vault");
        fletch.mint(alice, 1e18);
    }

    // -------------------------------------------------------------------------
    // Deposit Tests
    // -------------------------------------------------------------------------

    function test_DepositSingleUser() public {
        uint256 depositAmount = 100e18;

        vm.prank(alice);
        vault.deposit(depositAmount);

        assertEq(vault.shares(alice), depositAmount - (depositAmount * 50 / 10000));
        // 0.5% fee: 100e18 * 50/10000 = 0.5e18 → net = 99.5e18
        assertEq(vault.totalShares(), 99.5e18);
    }

    function test_DepositTransfersLP() public {
        uint256 aliceBalBefore = stakingToken.balanceOf(alice);

        vm.prank(alice);
        vault.deposit(100e18);

        uint256 aliceBalAfter = stakingToken.balanceOf(alice);
        assertEq(aliceBalBefore - aliceBalAfter, 100e18);
    }

    function test_MultipleUsersDeposit() public {
        vm.prank(alice);
        vault.deposit(100e18); // 99.5e18 shares after fee

        vm.prank(bob);
        vault.deposit(100e18); // 99.5e18 shares after fee

        assertEq(vault.totalShares(), 199e18); // 99.5 + 99.5
    }

    // -------------------------------------------------------------------------
    // Reward / Harvest Tests
    // -------------------------------------------------------------------------

    function test_NoRewardsBeforeHarvest() public {
        vm.prank(alice);
        vault.deposit(100e18);

        vm.prank(alice);
        vault.harvest();

        // rewardRate = 0 by default, so no rewards
        assertEq(vault.getPendingFLETCH(alice), 0);
    }

    function test_RewardsAccumulateAfterRateSet() public {
        // Alice deposits
        vm.prank(alice);
        vault.deposit(100e18);

        // Owner sets reward rate
        vm.prank(owner);
        vault.setRewardRate(1e18); // 1 FLETCH per second

        // Fast-forward 10 seconds
        vm.warp(block.timestamp + 10);

        // Harvest
        vm.prank(alice);
        vault.harvest();

        // 10 seconds × 1 FLETCH/sec = 10 FLETCH minted to vault
        uint256 vaultBal = fletch.balanceOf(address(vault));
        assertEq(vaultBal, 10e18);
    }

    function test_PerformanceFeeToYEW() public {
        vm.prank(alice);
        vault.deposit(100e18);

        vm.prank(owner);
        vault.setRewardRate(1e18); // 1 FLETCH/sec

        vm.warp(block.timestamp + 10);
        vm.prank(alice);
        vault.harvest();

        // 10 FLETCH minted
        // 10% to YEW = 1 FLETCH
        // 90% to stakers = 9 FLETCH
        uint256 yewBal = fletch.balanceOf(address(yew));
        assertEq(yewBal, 1e18); // 10% performance fee
    }

    function test_ClaimFLETCH() public {
        vm.prank(alice);
        vault.deposit(100e18);

        vm.prank(owner);
        vault.setRewardRate(1e18);
        vm.warp(block.timestamp + 10);
        vm.prank(alice);
        vault.harvest();

        uint256 balBefore = fletch.balanceOf(alice);
        vm.prank(alice);
        vault.claimFLETCH();
        uint256 balAfter = fletch.balanceOf(alice);

        // 9 FLETCH net rewards (after 10% fee)
        assertEq(balAfter - balBefore, 9e18);
    }

    // -------------------------------------------------------------------------
    // Withdraw Tests
    // -------------------------------------------------------------------------

    function test_WithdrawReturnsLP() public {
        uint256 aliceShares = 99.5e18; // after 0.5% fee on 100e18 deposit

        vm.prank(alice);
        vault.deposit(100e18);

        uint256 lpBalBefore = stakingToken.balanceOf(alice);
        vm.prank(alice);
        vault.withdraw(aliceShares);
        uint256 lpBalAfter = stakingToken.balanceOf(alice);

        assertEq(lpBalAfter - lpBalBefore, aliceShares);
    }

    function test_WithdrawBurnsShares() public {
        vm.prank(alice);
        vault.deposit(100e18);

        vm.prank(alice);
        vault.withdraw(99.5e18);

        assertEq(vault.shares(alice), 0);
        assertEq(vault.totalShares(), 0);
    }

    function test_CannotWithdrawMoreThanOwned() public {
        vm.prank(alice);
        vault.deposit(100e18);

        vm.prank(alice);
        vm.expectRevert("GRAZE: insufficient shares");
        vault.withdraw(100e18 + 1);
    }

    // -------------------------------------------------------------------------
    // Fee Tests
    // -------------------------------------------------------------------------

    function test_WithdrawalFeeGoesToYEW() public {
        vm.prank(alice);
        vault.deposit(100e18); // 0.5% fee = 0.5 LP to YEW

        uint256 yewBal = stakingToken.balanceOf(address(yew));
        assertEq(yewBal, 0.5e18);
    }

    function test_OwnerCanUpdateFees() public {
        vm.prank(owner);
        vault.setFees(500, 100); // 5% perf, 1% withdrawal

        assertEq(vault.performanceFeeNumerator(), 500);
        assertEq(vault.withdrawalFeeNumerator(), 100);
    }

    function test_CannotSetFeeTooHigh() public {
        vm.prank(owner);
        vm.expectRevert("GRAZE: perf fee max 20%");
        vault.setFees(3000, 100); // 30% — too high

        vm.prank(owner);
        vm.expectRevert("GRAZE: wdw fee max 5%");
        vault.setFees(1000, 1000); // 10% — too high
    }
}

// -------------------------------------------------------------------------
// Mock ERC20 for testing (replaces stakingToken)
// -------------------------------------------------------------------------

contract MockERC20 {
    string public name;
    string public symbol;
    uint8  public decimals;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name     = _name;
        symbol   = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "insufficient balance");
        require(allowance[from][msg.sender] >= amount, "insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to]   += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }
}
