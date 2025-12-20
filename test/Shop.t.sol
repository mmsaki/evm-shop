// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Shop, Transaction} from "../src/Shop.sol";

contract Setup is Test {
    Shop public shop;
    uint256 immutable PRICE = 1e16;
    uint256 immutable TAX = 1e13;
    uint16 immutable REFUND_RATE = 500;
    uint16 immutable REFUND_BASE = 1000;
    uint256 immutable REFUND_POLICY = 24 hours;

    address user1 = makeAddr("user");
    address user2 = makeAddr("user");
    address owner = makeAddr("owner");

    function setUp() public virtual {
        vm.deal(address(this), 100 ether);
        topUp(user1, 10 ether);
        topUp(user2, 10 ether);
        topUp(owner, 10 ether);
        deploy();
    }

    function deploy() internal useCaller(owner) {
        shop = new Shop(PRICE, TAX, REFUND_RATE, REFUND_BASE, REFUND_POLICY);
    }

    function topUp(address user, uint256 amount) internal {
        deal(user, amount);
    }

    modifier useCaller(address user) {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }

    modifier makeOrder(address user) {
        vm.startPrank(user);
        shop.buy{value: PRICE + TAX}();
        _;
        vm.stopPrank();
    }
}

contract CounterTest is Setup {
    using Transaction for uint256;

    function setUp() public virtual override {
        super.setUp();
    }

    function test_owner() public view {
        assertEq(shop.owner(), owner);
    }

    function test_initial_nonce() public useCaller(user1) {
        assertEq(shop.nonces(user1), 0);
    }

    function test_buy_without_tax() public useCaller(user1) {
        vm.expectRevert(Shop.MissingTax.selector);
        shop.buy{value: PRICE}();
    }

    function test_buy_correct_amount() public useCaller(user1) {
        assertEq(shop.nonces(user1), 0);
        shop.buy{value: PRICE + TAX}();
        assertEq(shop.nonces(user1), 1);
        assertEq(address(shop).balance, PRICE + TAX);
    }

    function test_refund() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, shop.nonces(user1) - 1));
        shop.refund(orderId);
        assertEq(address(shop).balance, TAX + PRICE - PRICE.getRefund(REFUND_RATE, REFUND_BASE));
        assertEq(shop.nonces(user1), 1);
        assertEq(shop.refunds(orderId), true);
    }

    function test_withdrawal() public useCaller(owner) {
        shop.withdraw();
        assertEq(address(shop).balance, 0);
    }

    function test_buy_when_shop_closed() public useCaller(owner) {
        shop.closeShop();
        vm.startPrank(user1);
        vm.expectRevert(Shop.ShopIsClosed.selector);
        shop.buy{value: PRICE + TAX}();
        vm.stopPrank();
    }

    function test_refund_after_policy() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        vm.warp(block.timestamp + REFUND_POLICY + 1);
        vm.expectRevert();
        shop.refund(orderId);
    }

    function test_multiple_buys() public useCaller(user1) {
        shop.buy{value: PRICE + TAX}();
        assertEq(shop.nonces(user1), 1);
        shop.buy{value: PRICE + TAX}();
        assertEq(shop.nonces(user1), 2);
        assertEq(address(shop).balance, 2 * (PRICE + TAX));
    }

    function test_withdrawal_before_policy() public makeOrder(user1) {
        uint256 initialBalance = address(owner).balance;
        uint256 shopBalance = address(shop).balance;
        vm.startPrank(owner);
        shop.withdraw();
        vm.stopPrank();
        uint256 expectedPartial = shopBalance * REFUND_RATE / REFUND_BASE;
        assertEq(address(shop).balance, shopBalance - expectedPartial);
        assertEq(address(owner).balance, initialBalance + expectedPartial);
    }

    function test_full_withdrawal_after_policy() public makeOrder(user1) {
        vm.warp(block.timestamp + REFUND_POLICY + 1);
        uint256 initialBalance = address(owner).balance;
        uint256 shopBalance = address(shop).balance;
        vm.startPrank(owner);
        shop.withdraw();
        vm.stopPrank();
        assertEq(address(shop).balance, 0);
        assertEq(address(owner).balance, initialBalance + shopBalance);
    }

    function test_second_full_withdrawal() public makeOrder(user1) {
        vm.warp(block.timestamp + REFUND_POLICY + 1);
        vm.startPrank(owner);
        shop.withdraw(); // First full withdrawal
        shop.withdraw(); // Second full withdrawal, transfers 0
        vm.stopPrank();
    }

    function test_unauthorized_open_shop() public useCaller(user1) {
        vm.expectRevert(Shop.UnauthorizedAccess.selector);
        shop.openShop();
    }

    function test_unauthorized_close_shop() public useCaller(user1) {
        vm.expectRevert(Shop.UnauthorizedAccess.selector);
        shop.closeShop();
    }

    function test_open_close_shop() public {
        // Assuming shop starts open, but let's test closing and opening
        vm.startPrank(owner);
        shop.closeShop();
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(Shop.ShopIsClosed.selector);
        shop.buy{value: PRICE + TAX}();
        vm.stopPrank();

        vm.startPrank(owner);
        shop.openShop();
        vm.stopPrank();

        vm.startPrank(user1);
        shop.buy{value: PRICE + TAX}(); // Should work now
        vm.stopPrank();
    }

    function test_buy_event() public useCaller(user1) {
        vm.expectEmit(true, false, false, false);
        emit Shop.BuyOrder(bytes32(0), PRICE + TAX);
        shop.buy{value: PRICE + TAX}();
    }

    function test_refund_event() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        shop.refund(orderId);
    }

    function test_shop_closed_event() public useCaller(owner) {
        vm.expectEmit(true, false, false, false);
        emit Shop.ShopClosed(block.timestamp);
        shop.closeShop();
    }

    function test_shop_open_event() public useCaller(owner) {
        shop.closeShop();
        vm.expectEmit(true, false, false, false);
        emit Shop.ShopOpen(block.timestamp);
        shop.openShop();
    }

    function test_refund_wrong_buyer() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        vm.startPrank(user2);
        shop.refund(orderId);
        vm.stopPrank();
    }

    function test_double_refund() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        shop.refund(orderId);
        vm.expectRevert();
        shop.refund(orderId);
    }
}
