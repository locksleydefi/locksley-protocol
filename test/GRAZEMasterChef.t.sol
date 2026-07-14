// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {FLETCH} from "../src/FLETCH.sol";
import {YEW} from "../src/YEW.sol";
import {GRAZEMasterChef} from "../src/GRAZEMasterChef.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GRAZEMasterChefTest is Test {
    FLETCH          public fletch;
    YEW             public yew;
    GRAZEMasterChef public chef;
    IERC20 public lpToken;
    IERC20 public yewEthLP;  // Mock YEW/ETH LP token

    address alice = address(0xA11CE);
    address owner;

    function setUp() public {
        owner = address(this);

        // Deploy mock tokens
        lpToken  = IERC20(address(new MockERC20("CASHCAT-ETH LP", "CASHCAT-ETH-LP", 18)));
        yewEthLP = IERC20(address(new MockERC20("YEW-ETH LP", "YEW-ETH-LP", 18)));

        fletch = new FLETCH(owner);
        yew    = new YEW(owner);

        chef = new GRAZEMasterChef(
            address(fletch),
            address(lpToken),
            address(yew),
            address(yewEthLP),   // YEW/ETH LP token
            owner,
            block.number + 10
        );

        fletch.setVault(address(chef), true);

        MockERC20(address(lpToken)).mint(alice, 1000e18);
        vm.prank(alice);
        lpToken.approve(address(chef), type(uint256).max);
    }

    // ---------------------------------------------------------------------------
    // Basic deployment
    // ---------------------------------------------------------------------------

    function test_Deploy() public {
        assertEq(address(chef.FLETCH_TOKEN()), address(fletch));
        assertEq(address(chef.LP_TOKEN()), address(lpToken));
        assertEq(address(chef.YEW_TOKEN()), address(yew));
        assertEq(address(chef.YEW_ETH_LP()), address(yewEthLP));
        assertEq(chef.totalLpStaked(), 0);
    }

    // ---------------------------------------------------------------------------
    // Deposit / Withdraw
    // ---------------------------------------------------------------------------

    function test_Deposit() public {
        vm.prank(alice);
        chef.deposit(100e18);
        (uint256 aliceShares,) = chef.userInfo(alice);
        assertEq(aliceShares, 100e18);
        assertEq(chef.totalLpStaked(), 100e18);
    }

    function test_Withdraw() public {
        vm.prank(alice);
        chef.deposit(100e18);
        vm.prank(alice);
        chef.withdraw(50e18);
        (uint256 aliceShares,) = chef.userInfo(alice);
        assertEq(aliceShares, 50e18);
        assertEq(chef.totalLpStaked(), 50e18);
    }

    // ---------------------------------------------------------------------------
    // Rewards (without fee swap — harvest with performFeeSwap=false)
    // ---------------------------------------------------------------------------

    function test_RewardsAccumulate_withoutSwap() public {
        vm.prank(alice);
        chef.deposit(100e18);
        vm.roll(block.number + 100);
        vm.prank(alice);
        // deposit() triggers _harvest(..., false) — no fee swap
        chef.deposit(0);
        assertGt(fletch.balanceOf(alice), 0);
    }

    // ---------------------------------------------------------------------------
    // Performance fee collected by chef (for later LP creation)
    // ---------------------------------------------------------------------------

    function test_PerformanceFeeCollected() public {
        vm.prank(alice);
        chef.deposit(100e18);
        vm.roll(block.number + 100);

        // FLETCH total supply before harvest
        uint256 fletchBefore = fletch.totalSupply();

        vm.prank(alice);
        chef.deposit(0);  // triggers _harvest(alice, false)

        // 10% fee is retained in chef as FLETCH
        uint256 fletchInChef = fletch.balanceOf(address(chef));
        // 10% of ~100 blocks × 1 FLETCH/block = ~10 FLETCH in fees
        assertGt(fletchInChef, 0, "Chef should hold performance fee FLETCH");
        // Alice got ~90 FLETCH (90% of rewards after fee)
        assertGt(fletch.balanceOf(alice), 0);
    }

    // ---------------------------------------------------------------------------
    // Owner controls
    // ---------------------------------------------------------------------------

    function test_OwnerCanSetRate() public {
        chef.setFletchPerBlock(2e18);
        assertEq(chef.fletchPerBlock(), 2e18);
    }

    function test_NonOwnerCannotSetRate() public {
        vm.prank(alice);
        vm.expectRevert();
        chef.setFletchPerBlock(2e18);
    }

    function test_EmergencyLpWithdraw() public {
        // Fund contract with LP tokens
        MockERC20(address(lpToken)).mint(address(chef), 50e18);

        uint256 before = lpToken.balanceOf(alice);
        chef.emergencyLpWithdraw(alice, 25e18);
        assertEq(lpToken.balanceOf(alice), before + 25e18);
    }

    // ---------------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------------

    function test_Constants() public {
        assertEq(chef.PERFORMANCE_FEE_BPS(), 1000);    // 10%
        assertEq(chef.SWAP_SLIPPAGE_BPS(), 150);        // 1.5%
        assertEq(chef.UNISWAP_ROUTER(), 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    }
}

// ---------------------------------------------------------------------------
// Minimal mock ERC20
// ---------------------------------------------------------------------------
contract MockERC20 {
    string public name;
    string public symbol;
    uint8  public decimals;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name; symbol = _symbol; decimals = _decimals;
    }

    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }

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
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "insufficient allowance");
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
