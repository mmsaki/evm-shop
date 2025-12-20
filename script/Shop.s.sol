// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { Shop } from "../src/Shop.sol";

contract CounterScript is Script {
    Shop public shop;

    // Price: 0.01 ETH (1e16 wei)
    uint256 immutable PRICE = 1e16;

    // Tax: 10% (100/1000 = 0.10 = 10%)
    // TAX must be <= TAX_BASE to prevent over 100% tax
    uint16 immutable TAX = 100;
    uint16 immutable TAX_BASE = 1000;

    // Refund: 50% (500/1000 = 0.50 = 50%)
    // REFUND_RATE must be <= REFUND_BASE to prevent over 100% refund
    uint16 immutable REFUND_RATE = 500;
    uint16 immutable REFUND_BASE = 1000;

    // Refund policy: 24 hours
    uint256 immutable REFUND_POLICY = 24 hours;

    function setUp() public { }

    function run() public {
        vm.startBroadcast();
        shop = new Shop(PRICE, TAX, TAX_BASE, REFUND_RATE, REFUND_BASE, REFUND_POLICY);
        vm.stopBroadcast();
    }
}
