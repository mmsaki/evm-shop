// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Shop} from "../src/Shop.sol";

contract CounterScript is Script {
    Shop public shop;
    uint256 immutable PRICE = 1 ** 16;
    uint16 immutable TAX = 100;
    uint16 immutable TAX_BASE = 1000;
    uint16 immutable REFUND_BASE = 500;
    uint16 immutable REFUND_RATE = 1000;
    uint256 immutable REFUND_POLICY = 24 hours;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        shop = new Shop(PRICE, TAX, TAX_BASE, REFUND_RATE, REFUND_BASE, REFUND_POLICY);
        vm.stopBroadcast();
    }
}
