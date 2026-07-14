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

    address alice = address(0xA11CE);
    address owner;

    function setUp() public {
        owner = address(this);
        lpToken = IERC20(address(new MockERC20("LP", "LP", 18)));
        fletch = new FLETCH(owner);
        yew    = new YEW(owner);

        chef = new GRAZEMasterChef(
            address(fletch),
            address(lpToken),
            address(yew),
            owner,
            block.number + 10
        );

        fletch.setVault(address(chef), true);
        MockERC20(address(lpToken)).mint(alice, 1000e18);
        vm.prank(alice);
        lpToken.approve(address(chef), type(uint256).max);
    }

    function test_Deploy() public {
        assertEq(address(chef.FLETCH_TOKEN()), address(fletch));
        assertEq(address(chef.LP_TOKEN()), address(lpToken));
        assertEq(chef.totalLpStaked(), 0);
    }

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

    function test_RewardsAccumulate() public {
        vm.prank(alice);
        chef.deposit(100e18);
        vm.roll(block.number + 100);
        vm.prank(alice);
        chef.harvest();
        assertGt(fletch.balanceOf(alice), 0);
    }

    function test_PerformanceFeeToYEW() public {
        vm.prank(alice);
        chef.deposit(100e18);
        vm.roll(block.number + 100);
        vm.prank(alice);
        chef.harvest();
        assertGt(fletch.balanceOf(address(yew)), 0);
    }

    function test_OwnerCanSetRate() public {
        chef.setFletchPerBlock(2e18);
        assertEq(chef.fletchPerBlock(), 2e18);
    }

    function test_NonOwnerCannotSetRate() public {
        vm.prank(alice);
        vm.expectRevert();
        chef.setFletchPerBlock(2e18);
    }
}

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
        require(allowance[from][msg.sender] >= amount);
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }
}
