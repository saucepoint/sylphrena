// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Stormfather.sol";

contract StormfatherTest is Test {
    Stormfather public stormfather;
    address alice = address(0xbeef);
    address bob = address(0xdead);
    address charlie = address(0xfeed);

    function setUp() public {
        stormfather = new Stormfather();

        vm.deal(alice, 1 ether);
    }

    function testFlow() public {
        (address spren, uint256 salt) = stormfather.spawn(charlie);
        vm.prank(alice);
        (bool sent,) = address(spren).call{value: 0.01 ether}("");
        assertEq(sent, true);
        assertEq(address(spren).balance, 0.01 ether);

        stormfather.addOathBreaker(address(charlie), salt);

        vm.prank(bob);
        stormfather.oathBreak(salt);

        assertEq(address(alice).balance, (1 ether - 0.01 ether));
        assertEq(address(bob).balance, 0);
        assertEq(address(charlie).balance, 0.01 ether);
    }
}
