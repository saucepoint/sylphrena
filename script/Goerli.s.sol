// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/Stormfather.sol";

contract GoerliScript is Script {
    Stormfather stormfather;
    function setUp() public {
    }

    function run() public {
        // users of the system
        uint256 deployer = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 alice = vm.envUint("ALICE_PRIVATE_KEY");
        uint256 bob = vm.envUint("BOB_PRIVATE_KEY");
        address charlie = vm.envAddress("CHARLIE_ADDRESS");

        // Deploy the storm father contract
        vm.startBroadcast(deployer);
        stormfather = new Stormfather();
        vm.stopBroadcast();

        // get an escrow EOA
        (address spren, uint256 salt) = stormfather.spawn(0);

        // Alice sends 0.01 ether to the escrow EOA
        vm.startBroadcast(alice);
        (bool sent,) = address(spren).call{value: 0.01 ether}("");
        require(sent, "failed transfer");

        // Alice registers charlie as a recipient
        stormfather.addRadiant(address(charlie), salt);
        vm.stopBroadcast();

        // Bob routes the funds to charlie via CREATE2 and SELFDESTRUCT
        vm.startBroadcast(bob);
        stormfather.oathBreak(salt);
        vm.stopBroadcast();
    }
}
