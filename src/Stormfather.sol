// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Spren} from "./Spren.sol";

contract Stormfather {
    // number of unpaid recipients
    uint256 private oathBreakerCount;

    // an unordered list of recipients for the funds
    mapping(uint256 => address) private oathBreakers;

    // tracks if a salt has been used to register an oathbreaker
    // (prevents reusage attacks)
    mapping(bytes32 => bool) private used;

    // Exact amount that must be held by the Spren in order to register and pay out
    // !! More funds CANNOT be sent after registration !!
    // @dev: Possible to extend this into a mapping or an array to support different pools?
    uint256 public constant amount = 0.01 ether;

    // ----------------------------------------------------------
    // Primary (External) Functions
    // ----------------------------------------------------------

    /**
     * @notice Get an EOA address to send funds to
     * @param seed uint256 any number to be used as a seed for pseudo RNG
     */
    function spawn(uint256 seed) external view returns (address spren, uint256 salt) {
        salt = _rng(seed);
        spren = _getAddress(salt);
    }

    /**
     * @notice Add an address to the set of recipients, which are chosen at random
     * @dev TODO: Stronger permissions are required here. Anyone with a valid salt will
     * be able to register an address as a recipient. Attackers can recieve funds from
     * the escrow EOAs by registering their own address as a recipient.
     * @param radiant address of a new recipient
     * @param salt uint256, the salt returned by spawn(), which can deploy via CREATE2. also used as a soft-verification
     */
    function addRadiant(address radiant, uint256 salt) external {
        // TODO: verify caller has permission to the system, could a merkle proof work here?
        // TODO: is there a way to handle permissions (and proper checks) without need of a salt?

        // TODO: should we be worried about collision here?
        require(!used[keccak256(abi.encodePacked(salt))], "already used");

        // mark the salt as used to prevent reusage attacks
        // (use a hash to hide the salt)
        used[keccak256(abi.encodePacked(salt))] = true;

        // soft-check that the owner of the salt has provided funds to the escrow
        address spren = _getAddress(salt);
        require(address(spren).balance == amount, "invalid salt");

        // register the recipient to be randomly chosen
        oathBreakers[oathBreakerCount] = radiant;
        unchecked {
            ++oathBreakerCount;
        }
    }

    /**
     * @notice Atomically deploys Spren to the EOA and self-destructs it. Directs the funds to a random recipient (oathBreaker)
     * @param salt uint256 - the salt used in CREATE2 to deploy to a funded EOA. Should be provided from an off-chain source
     */
    function oathBreak(uint256 salt) external {
        require(oathBreakerCount != 0, "no oaths");
        address spren;
        bytes memory _data = _getBytecode();

        assembly {
            spren := create2(0, add(0x20, _data), mload(_data), salt)
            if iszero(extcodesize(spren)) { revert(0, 0) }
        }
        // @dev TODO: this introduces a footgun where funds are unrecoverable if the spren is under or over funded
        // up to intreptation for how this should be handled
        require(address(spren).balance == amount, "invalid salt");
        Spren(spren).unbond(_pop());
    }

    // ----------------------------------------------------------
    // Utility (Private) Functions
    // ----------------------------------------------------------
    /**
     * @notice Pseudo RNG
     * @param seed uint256 a random seed
     */
    function _rng(uint256 seed) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, block.coinbase, seed)));
    }

    /**
     * @notice gets the bytecode of the Spren contract. Required for create2 & deterministic address generation
     */
    function _getBytecode() private view returns (bytes memory) {
        return abi.encodePacked(type(Spren).creationCode, abi.encode(address(this)));
    }

    /**
     * @notice Deterministically generate an EOA address which can be upgraded to a Spren contract
     */
    function _getAddress(uint256 salt) private view returns (address) {
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(_getBytecode())))))
        );
    }

    /**
     * @notice Randomly select (and pop) an address from the unordered list of recipients
     */
    function _pop() private returns (address popped) {
        uint256 num = _rng(uint256(keccak256(abi.encode(block.timestamp)))) % oathBreakerCount;
        uint256 last;
        unchecked {
            last = oathBreakerCount - 1;
        }
        popped = oathBreakers[num];

        // sanity check, might be overkill
        require(popped != address(0x0), "null address");

        oathBreakers[num] = oathBreakers[last];

        // this might use unnecessary gas, but for the sake of "privacy" lets clear it out
        delete oathBreakers[last];

        unchecked {
            --oathBreakerCount;
        }
    }
}
