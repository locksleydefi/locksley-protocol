// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {YEW} from "../src/YEW.sol";
import {YEWVaultChef} from "../src/YEWVaultChef.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract YEWVaultChefTest is Test {
    YEW           public yew;
    YEWVaultChef  public chef;
    IERC20 public lpToken;
    MockWETH public weth;

    address alice = address(0xA11CE);
    address owner;
    address treasury = address(uint160(1));

    function setUp() public {
        owner = address(this);

        weth = new MockWETH();
        lpToken = IERC20(address(new MockERC20("FLETCH-ETH LP", "FLETCH-ETH-LP", 18)));

        yew   = new YEW(owner);
        chef  = new YEWVaultChef(
            address(yew),
            address(lpToken),
            address(weth),
            owner,
            treasury,
            block.number + 10
        );

        yew.setVault(address(chef), true);

        MockERC20(address(lpToken)).mint(alice, 1000e18);
        vm.prank(alice);
        lpToken.approve(address(chef), type(uint256).max);
    }

    function test_Deploy() public {
        assertEq(address(chef.YEW_TOKEN()), address(yew));
        assertEq(address(chef.LP_TOKEN()), address(lpToken));
        assertEq(chef.totalShares(), 0);
        assertEq(chef.treasuryWallet(), treasury);
    }

    function test_Deposit() public {
        vm.prank(alice);
        chef.deposit(100e18);
        (uint256 aliceShares,,) = chef.userInfo(alice);
        assertEq(aliceShares, 100e18);
        assertEq(chef.totalShares(), 100e18);
    }

    function test_Withdraw() public {
        vm.prank(alice);
        chef.deposit(100e18);
        vm.prank(alice);
        chef.withdraw(50e18);
        (uint256 aliceShares,,) = chef.userInfo(alice);
        assertEq(aliceShares, 50e18);
        assertEq(chef.totalShares(), 50e18);
    }

    function test_RewardsAccumulate() public {
        vm.prank(alice);
        chef.deposit(100e18);
        vm.roll(block.number + 100);
        vm.prank(alice);
        chef.harvest();
        assertGt(yew.balanceOf(alice), 0);
    }

    function test_YewPerBlockScheduleIsPopulated() public {
        uint256 rate0 = chef.yewPerBlockSchedule(0);
        uint256 rate1 = chef.yewPerBlockSchedule(1);

        assertEq(rate0, 5e16);    // 0.05 YEW
        assertEq(rate1, 5e16 / 2); // 0.025 YEW
    }

    function test_CurrentRateIsCorrect() public {
        uint256 rate = chef.currentYewPerBlock();
        assertEq(rate, 5e16); // epoch 0
    }

    function test_SetTreasuryWallet() public {
        chef.setTreasuryWallet(alice);
        assertEq(chef.treasuryWallet(), alice);
    }

    function test_Constants() public {
        assertEq(chef.BLOCKS_PER_EPOCH(), 864_000);
        assertEq(chef.INITIAL_YEW_PER_BLOCK(), 5e16);
    }
}

contract MockWETH {
    string public name     = "Wrapped Ether";
    string public symbol  = "WETH";
    uint8  public decimals = 18;

    function deposit() external payable {}
    function transfer(address to, uint256) external returns (bool) { return true; }
    function balanceOf(address) external view returns (uint256) { return address(this).balance; }
    function approve(address, uint256) external returns (bool) { return true; }
    function allowance(address, address) external view returns (uint256) { return type(uint256).max; }
    receive() external payable {}
}

contract MockERC20 {
    string  public name;
    string  public symbol;
    uint8   public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name     = _name;
        symbol   = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply   += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to]         += amount;
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "ERC20: insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to]   += amount;
        return true;
    }
}
