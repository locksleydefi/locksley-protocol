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
    IERC20 public yewEthLP;
    MockWETH public weth;

    address alice = address(0xA11CE);
    address bob   = address(0xB0B);
    address owner;
    address teamWallet = address(uint160(1));
    address protoLP    = address(uint160(2));

    function setUp() public {
        owner = address(this);

        // Deploy mock WETH first (since tests run against anvil, not mainnet)
        weth = new MockWETH();

        lpToken  = IERC20(address(new MockERC20("CASHCAT-ETH LP", "CASHCAT-ETH-LP", 18)));
        yewEthLP = IERC20(address(new MockERC20("YEW-ETH LP", "YEW-ETH-LP", 18)));

        fletch = new FLETCH(owner);
        yew    = new YEW(owner);

        // 8 constructor args: fletch, lp, yew, yewEthLP, owner, teamWallet, protoLP, startBlock
        chef = new GRAZEMasterChef(
            address(fletch),
            address(lpToken),
            address(yew),
            address(yewEthLP),
            address(weth),
            owner,
            teamWallet,
            protoLP,
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
        assertEq(chef.totalShares(), 0);
        assertEq(chef.teamWallet(), teamWallet);
        assertEq(chef.protocolLPOwner(), protoLP);
    }

    // ---------------------------------------------------------------------------
    // Deposit / Withdraw
    // ---------------------------------------------------------------------------

    function test_Deposit() public {
        vm.prank(alice);
        chef.deposit(100e18);
        (uint256 aliceShares,) = chef.userInfo(alice);
        assertEq(aliceShares, 100e18);
        assertEq(chef.totalShares(), 100e18);
    }

    function test_Withdraw() public {
        vm.prank(alice);
        chef.deposit(100e18);
        vm.prank(alice);
        chef.withdraw(50e18);
        (uint256 aliceShares,) = chef.userInfo(alice);
        assertEq(aliceShares, 50e18);
        assertEq(chef.totalShares(), 50e18);
    }

    // ---------------------------------------------------------------------------
    // Rewards
    // ---------------------------------------------------------------------------

    function test_RewardsAccumulate() public {
        vm.prank(alice);
        chef.deposit(100e18);
        vm.roll(block.number + 100);
        vm.prank(alice);
        chef.harvest();
        assertGt(fletch.balanceOf(alice), 0);
    }

    // ---------------------------------------------------------------------------
    // Performance fee collected
    // ---------------------------------------------------------------------------

    function test_PerformanceFeeCollected() public {
        vm.prank(alice);
        chef.deposit(100e18);
        vm.roll(block.number + 100);

        vm.prank(alice);
        chef.harvest();

        // FLETCH minted to alice (90%) + to chef as fee (10%)
        assertGt(fletch.balanceOf(alice), 0, "alice should have FLETCH");
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

    function test_SetTeamWallet() public {
        chef.setTeamWallet(bob);
        assertEq(chef.teamWallet(), bob);
    }

    function test_EmergencyLpWithdraw() public {
        MockERC20(address(lpToken)).mint(address(chef), 50e18);
        uint256 before = lpToken.balanceOf(alice);
        chef.emergencyLpWithdraw(alice, 25e18);
        assertEq(lpToken.balanceOf(alice), before + 25e18);
    }

    // ---------------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------------

    function test_Constants() public {
        assertEq(chef.PERFORMANCE_FEE_BPS(), 1000);   // 10%
        assertEq(chef.WITHDRAWAL_FEE_BPS(), 50);      // 0.5%
        assertEq(chef.FEE_YEW_BPS(), 5000);           // 50%
        assertEq(chef.FEE_TEAM_BPS(), 2500);          // 25%
        assertEq(chef.FEE_PROTOCOL_BPS(), 2500);      // 25%
    }
}

// ---------------------------------------------------------------------------
// Mock ERC20
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
        require(balanceOf[msg.sender] >= amount);
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount);
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount);
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function totalSupply() external view returns (uint256) {
        return type(uint256).max;
    }
}

// ---------------------------------------------------------------------------
// Mock WETH (for test environment)
// ---------------------------------------------------------------------------
contract MockWETH {
    string public name     = "Wrapped Ether";
    string public symbol   = "WETH";
    uint8  public decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount);
        balanceOf[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount);
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function totalSupply() external view returns (uint256) {
        return type(uint256).max;
    }
}
