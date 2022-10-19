// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Spren {
    address immutable stormFather;

    constructor(address _stormFather) {
        stormFather = _stormFather;
    }

    function unbond(address oathBreaker) external {
        require(msg.sender == stormFather, "only stormfather can unbond");
        selfdestruct(payable(oathBreaker));
    }
}
