# sylphrena
Pseudonymous transfers of Ether tokens with low-traceability by using `create2` &amp; `selfdestruct`

Named after the spren from the Stormlight Archive series. Functions are intentionally (but poorly) lore-driven to encourage stronger understanding of smart contract behavior.

---

# Use Case: Anonymous Transfers

Alice wants to send Charlie some ether tokens but wants to conceal the transfer such that Charlie cannot trace the funds back to Alice’s EOA.

# Guide

1. Alice sends Ether to a designated EOA address, referred to as the *escrow address* (the address eventually gets bytecode via CREATE2)
2. Alice (using a different wallet) registers Charlie as a recipient, and adds his address to the pool of other recipients
3. Bob, *permissionlessly*, calls a function which deploys a self-destructible contract to one of the escrow EOAs. The escrow contract is atomically SELFDESTRUCT'd and funds are sent to Charlie's address


```solidity
// obtain an address, that initially appears as an EOA
(address escrow, uint256 salt) = getAddress()

// alice sends money to the escrow EOA
(bool sent,) = address(escrow).call{value: 0.01 ether}("");

// alice registers Charlie as a recipient
// (alice preferably uses a different EOA)
addRecipient(address(charlie), salt)

// Bob, an external party, calls this function to route the transfer to charlie
function route(uint256 salt) external {
    // deploys bytecode to the escrow EOA, converting it
    // to a contract with self destruct functionality
    address escrow = create2(..., salt);

    // contract pseudo-randomly picks charlie as a recipient
    // the pseudo-random selection is used to mask intention
    address charlie = popRandomRecipient();

    // selfdestruct the newly created contract, and direct the funds to charlie
    Escrow(escrow).destroy(charlie);
}
```

There's some traceability in this single-party example, but with many inbound/outbound addresses you can achieve pseudonymity through obfuscation. The EOAs holding the funds (which get self-destructed) can be shuffled so Alice's funds never have a direct trace to Charlie's address.

# **Concerns**

**Footguns galore**! Whole lotta footguns here:
* *loss of funds* -- if EOAs are under-funded or over-funded, the escrow will not deploy & self destruct. Funds will be frozen in the EOA

* *loss of funds* -- if the salt returned by `spawn()` is lost, the funder cannot provide a recipient. Funds will be frozen in the EOA

* *loss of privacy* -- if no one calls `oathBreak()` with your salt, you may be forced to call it yourself, which will publicly signal your involvment with the Sylphrena contracts

* ***loss of decentralization*** -- to preserve privacy and maintain low-traceability, salts need to be managed off-chain. Managing salts on-chain could open the door for explicit or programmatic traceability
    * off-chain management of salts inherently implies some governing entity. This can lead to both censorship and privacy leaks


# Acknowledgements

* Tornado Cash
* [Philogy's Blind Auctions with CREATE2](https://github.com/Philogy/create2-vickrey-contracts)

# Disclaimer

The code is not deployed anywhere, except for Ethereum Goerli.

The code is not battletested, and offers no guarantees of anonymity. *Treat the code as a foundational starting point for a production-ready version, hence the MIT License*.

**I have no interest in supporting this code any further, as I am not looking to battle policymakers (and/or go to prison)**

# Testnet Execution

This example does not capture obfuscation since the funds directly flow from Alice's escrow to Charlie. With a sufficient pool of escrows & recipients, the entities can be shuffled to avoid having a direct flow of funds.

* [Stormfather Contract](https://goerli.etherscan.io/address/0xda2157f40723d2bdccbb81bafdf29c617cadf829)
* [Alice sends ether to the escrow](https://goerli.etherscan.io/tx/0xb9f549d4a5680029bc38ba65aebbf9fa142a02ef3a427a05e2fca063e6bc2d9c)
* [Alice registers Charlie as a recipient](https://goerli.etherscan.io/tx/0x2b471f41fc7714e203e3fee33d6cdc066950eef132805371357d00899912635a)
* [Bob executes the CREATE2 & SELFDESTRUCT](https://goerli.etherscan.io/tx/0xbe83009a2837f431d58a73825092c8dd50bc122d8b84619ded61ea24ba3fef97)
* [Charlie holds 0.01 ether](https://goerli.etherscan.io/address/0xc00f3d428fbce1bb38e616392350b5e461d9cabd)