// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Spren} from "./Spren.sol";

contract Stormfather {
    // an unordered list of destinations for the funds
    mapping(uint256 => address) private oathBreakers;
    uint256 private oathBreakerCount;

    uint256 constant public amount = 0.01 ether;

    function rng(uint256 seed) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, seed)));
    }

    function _getAddress(uint256 salt) private view returns (address) {
        bytes memory bytecode = type(Spren).creationCode;
        return address(uint160(uint256(keccak256(
                abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))
        ))));
    }

    function _pop(uint256 salt) private returns (address popped) {
        uint256 num = rng(salt) % oathBreakerCount;
        popped = oathBreakers[num];
        oathBreakers[num] = oathBreakers[oathBreakerCount - 1];
        delete oathBreakers[oathBreakerCount];
        unchecked { --oathBreakerCount; }
    }

    /**
     * @notice Get an address to send funds to
     */
    function spawn(address finalDestination) external view returns (address spren, uint256 salt) {
        unchecked {
            salt = rng(uint256(keccak256(abi.encodePacked(finalDestination))));
            spren = _getAddress(salt);
        }
    }

    /**
     * @notice Add an address to the unordered queue
     */
    function addOathBreaker(address oathBreaker, uint256 salt) external {
        // TODO: verify user has permission to the system
        address spren = _getAddress(salt);
        require(address(spren).balance == amount, "invalid salt");
        oathBreakers[oathBreakerCount] = oathBreaker;
        unchecked { ++oathBreakerCount; }
    }


    /**
     * Breaks the oath and sends the funds to a random oath breaker
     */
    function oathBreak(uint256 salt) external {
        address spren;
        bytes memory _data = type(Spren).creationCode;
        assembly {
            spren := create2(0, add(0x20, _data), mload(_data), salt)
            if iszero(extcodesize(spren)) { revert(0, 0) }
        }
        require(address(spren).balance == amount, "invalid salt");
        Spren(spren).unbond(_pop(salt));
    }


}
