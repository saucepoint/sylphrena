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

    // happy path
    function testFlow() public {
        (address spren, uint256 salt) = stormfather.spawn(0);
        vm.prank(alice);
        (bool sent,) = address(spren).call{value: 0.01 ether}("");
        assertEq(sent, true);
        assertEq(address(spren).balance, 0.01 ether);

        stormfather.addRadiant(address(charlie), salt);

        vm.prank(bob);
        stormfather.oathBreak(salt);

        assertEq(address(alice).balance, (1 ether - 0.01 ether));
        assertEq(address(bob).balance, 0);
        assertEq(address(charlie).balance, 0.01 ether);
    }

    // happy path, where the same recipient is added twice
    // and funded using two different EOAs
    function testFlow2() public {
        // destination for charlie
        (, uint256 salt) = fundedSpren();

        stormfather.oathBreak(salt);

        (, salt) = fundedSpren();
        stormfather.oathBreak(salt);

        assertEq(address(alice).balance, (1 ether - 0.02 ether));
        assertEq(address(bob).balance, 0);
        assertEq(address(charlie).balance, 0.02 ether);
    }

    // happy path, but with many inbound and outbound sources
    function testFlowMany() public {
        uint160 i = 1;
        uint256[21] memory salts;

        // fund & register 20 recipients
        for (i; i < 21;) {
            address funder = address(i);
            address recipient = address(i * 10);

            // fund the EOA
            vm.warp(block.timestamp + 1);
            (address spren, uint256 salt) = stormfather.spawn(block.timestamp);
            salts[i] = salt;
            vm.deal(funder, 0.01 ether);
            vm.prank(funder);
            (bool sent,) = address(spren).call{value: 0.01 ether}("");
            assertEq(sent, true);
            assertEq(address(spren).balance, 0.01 ether);
            assertEq(funder.balance, 0);

            // add the recipient
            stormfather.addRadiant(recipient, salt);

            unchecked {
                ++i;
            }
        }

        // oath break all 20 radiants
        for (i = 1; i < 21;) {
            stormfather.oathBreak(salts[i]);
            unchecked {
                ++i;
            }
        }

        // verify balances
        for (i = 1; i < 21;) {
            assertEq(address(i * 10).balance, 0.01 ether);
            unchecked {
                ++i;
            }
        }
    }

    // cannot register the an address using the same salt twice
    function testDoubleRegisterRevert() public {
        (, uint256 salt) = fundedSpren();

        address beef = address(0xbeef);
        vm.expectRevert("already used");
        stormfather.addRadiant(beef, salt);
    }

    // cannot break an oath twice
    function testDoubleUnbondRevert() public {
        (, uint256 salt) = fundedSpren();

        // fund and register another spren
        fundedSpren();

        // break the oath
        vm.prank(bob);
        stormfather.oathBreak(salt);

        // try to break the oath again
        // reverts on create2
        vm.expectRevert();
        stormfather.oathBreak(salt);
    }

    // ----------------------------------------
    // Helpers
    // ----------------------------------------
    function fundedSpren() public returns (address, uint256) {
        vm.warp(block.timestamp + 1);
        (address spren, uint256 salt) = stormfather.spawn(block.timestamp);
        vm.prank(alice);
        (bool sent,) = address(spren).call{value: 0.01 ether}("");
        assertEq(sent, true);
        assertEq(address(spren).balance, 0.01 ether);

        stormfather.addRadiant(address(charlie), salt);
        return (spren, salt);
    }
}
