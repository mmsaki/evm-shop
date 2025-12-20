// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { Shop, Transaction } from "../src/Shop.sol";

contract Setup is Test {
    Shop public shop;
    uint256 immutable PRICE = 1e16;
    uint16 immutable TAX = 100; // 10% in basis points
    uint16 immutable TAX_BASE = 1000;
    uint256 immutable TAX_AMOUNT = PRICE * TAX / TAX_BASE;
    uint256 immutable TOTAL = PRICE + TAX_AMOUNT;
    uint16 immutable REFUND_RATE = 500;
    uint16 immutable REFUND_BASE = 1000;
    uint256 immutable REFUND_POLICY = 24 hours;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address owner = makeAddr("owner");

    function setUp() public virtual {
        vm.deal(address(this), 100 ether);
        topUp(user1, 10 ether);
        topUp(user2, 10 ether);
        topUp(owner, 10 ether);
        deploy();
    }

    function deploy() internal useCaller(owner) {
        shop = new Shop(PRICE, TAX, TAX_BASE, REFUND_RATE, REFUND_BASE, REFUND_POLICY);
    }

    function topUp(
        address user,
        uint256 amount
    ) internal {
        deal(user, amount);
    }

    modifier useCaller(
        address user
    ) {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }

    modifier makeOrder(
        address user
    ) {
        vm.startPrank(user);
        shop.buy{ value: TOTAL }();
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
        shop.buy{ value: PRICE }();
    }

    function test_buy_correct_amount() public useCaller(user1) {
        assertEq(shop.nonces(user1), 0);
        shop.buy{ value: TOTAL }();
        assertEq(shop.nonces(user1), 1);
        assertEq(address(shop).balance, TOTAL);
    }

    function test_refund() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, shop.nonces(user1) - 1));
        shop.refund(orderId);
        assertEq(address(shop).balance, TOTAL - PRICE.getRefund(REFUND_RATE, REFUND_BASE));
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
        shop.buy{ value: TOTAL }();
        vm.stopPrank();
    }

    function test_refund_after_policy() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        vm.warp(block.timestamp + REFUND_POLICY + 1);
        vm.expectRevert();
        shop.refund(orderId);
    }

    function test_multiple_buys() public useCaller(user1) {
        shop.buy{ value: TOTAL }();
        assertEq(shop.nonces(user1), 1);
        shop.buy{ value: TOTAL }();
        assertEq(shop.nonces(user1), 2);
        assertEq(address(shop).balance, 2 * TOTAL);
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
        shop.buy{ value: TOTAL }();
        vm.stopPrank();

        vm.startPrank(owner);
        shop.openShop();
        vm.stopPrank();

        vm.startPrank(user1);
        shop.buy{ value: TOTAL }(); // Should work now
        vm.stopPrank();
    }

    function test_buy_event() public useCaller(user1) {
        vm.expectEmit(true, false, false, false);
        emit Shop.BuyOrder(bytes32(0), TOTAL);
        shop.buy{ value: TOTAL }();
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
        vm.expectRevert();
        shop.refund(orderId);
        vm.stopPrank();
    }

    function test_double_refund() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        shop.refund(orderId);
        vm.expectRevert(Shop.DuplicateRefundClaim.selector);
        shop.refund(orderId);
    }

    function test_buy_with_excess_amount() public useCaller(user1) {
        vm.expectRevert(Shop.ExcessAmount.selector);
        shop.buy{ value: TOTAL + 1 }();
    }

    function test_buy_with_insufficient_amount() public useCaller(user1) {
        vm.expectRevert(Shop.InsuffientAmount.selector);
        shop.buy{ value: TOTAL - 1 }();
    }

    function test_refund_nonexistent_order() public useCaller(user1) {
        bytes32 fakeOrderId = keccak256(abi.encode(user1, uint256(999)));
        vm.expectRevert(Shop.InvalidRefundBenefiary.selector);
        shop.refund(fakeOrderId);
    }

    function test_unauthorized_withdrawal() public useCaller(user1) {
        vm.expectRevert(Shop.UnauthorizedAccess.selector);
        shop.withdraw();
    }

    function test_refund_expires_at_exact_policy_time() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        vm.warp(block.timestamp + REFUND_POLICY);
        // At exactly REFUND_POLICY time, should still work (< not <=)
        shop.refund(orderId);
    }

    function test_refund_expired_one_second_after() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        vm.warp(block.timestamp + REFUND_POLICY + 1);
        vm.expectRevert(Shop.RefundPolicyExpired.selector);
        shop.refund(orderId);
    }

    function test_partial_withdrawal_only_once() public makeOrder(user1) {
        vm.startPrank(owner);
        shop.withdraw(); // First partial withdrawal
        vm.expectRevert(Shop.WaitUntilRefundPeriodPassed.selector);
        shop.withdraw(); // Second partial withdrawal should fail
        vm.stopPrank();
    }

    function test_multiple_orders_same_user() public useCaller(user1) {
        shop.buy{ value: TOTAL }();
        bytes32 orderId1 = keccak256(abi.encode(user1, uint256(0)));

        shop.buy{ value: TOTAL }();
        bytes32 orderId2 = keccak256(abi.encode(user1, uint256(1)));

        // Both orders should have different IDs
        assertTrue(orderId1 != orderId2);

        // Should be able to refund both
        shop.refund(orderId1);
        shop.refund(orderId2);

        assertTrue(shop.refunds(orderId1));
        assertTrue(shop.refunds(orderId2));
    }

    function test_shop_opens_only_when_closed() public useCaller(owner) {
        // Opening already open shop should not emit event
        shop.openShop(); // No event expected since shop is already open

        shop.closeShop();
        vm.expectEmit(true, false, false, false);
        emit Shop.ShopOpen(block.timestamp);
        shop.openShop(); // Should emit event
    }

    function test_balance_after_refund() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        uint256 userBalanceBefore = user1.balance;
        uint256 shopBalanceBefore = address(shop).balance;
        uint256 expectedRefund = PRICE.getRefund(REFUND_RATE, REFUND_BASE);

        shop.refund(orderId);

        assertEq(user1.balance, userBalanceBefore + expectedRefund);
        assertEq(address(shop).balance, shopBalanceBefore - expectedRefund);
    }

    function test_nonce_increments_correctly() public useCaller(user1) {
        assertEq(shop.nonces(user1), 0);
        shop.buy{ value: TOTAL }();
        assertEq(shop.nonces(user1), 1);
        shop.buy{ value: TOTAL }();
        assertEq(shop.nonces(user1), 2);
        shop.buy{ value: TOTAL }();
        assertEq(shop.nonces(user1), 3);
    }

    function test_receive_function() public {
        // Test that contract can receive ETH directly
        (bool success,) = address(shop).call{ value: 1 ether }("");
        assertTrue(success);
        assertEq(address(shop).balance, 1 ether);
    }

    // ============ Constructor Validation Tests ============

    function test_constructor_rejects_zero_price() public {
        vm.startPrank(owner);
        vm.expectRevert(Shop.InvalidConstructorParameters.selector);
        new Shop(0, TAX, TAX_BASE, REFUND_RATE, REFUND_BASE, REFUND_POLICY);
        vm.stopPrank();
    }

    function test_constructor_rejects_zero_tax_base() public {
        vm.startPrank(owner);
        vm.expectRevert(Shop.InvalidConstructorParameters.selector);
        new Shop(PRICE, TAX, 0, REFUND_RATE, REFUND_BASE, REFUND_POLICY);
        vm.stopPrank();
    }

    function test_constructor_rejects_tax_greater_than_base() public {
        vm.startPrank(owner);
        vm.expectRevert(Shop.InvalidConstructorParameters.selector);
        new Shop(PRICE, 1001, 1000, REFUND_RATE, REFUND_BASE, REFUND_POLICY);
        vm.stopPrank();
    }

    function test_constructor_rejects_zero_refund_base() public {
        vm.startPrank(owner);
        vm.expectRevert(Shop.InvalidConstructorParameters.selector);
        new Shop(PRICE, TAX, TAX_BASE, REFUND_RATE, 0, REFUND_POLICY);
        vm.stopPrank();
    }

    function test_constructor_rejects_refund_rate_greater_than_base() public {
        vm.startPrank(owner);
        vm.expectRevert(Shop.InvalidConstructorParameters.selector);
        new Shop(PRICE, TAX, TAX_BASE, 1001, 1000, REFUND_POLICY);
        vm.stopPrank();
    }

    function test_constructor_rejects_zero_refund_policy() public {
        vm.startPrank(owner);
        vm.expectRevert(Shop.InvalidConstructorParameters.selector);
        new Shop(PRICE, TAX, TAX_BASE, REFUND_RATE, REFUND_BASE, 0);
        vm.stopPrank();
    }

    function test_constructor_accepts_tax_equal_to_base() public {
        vm.startPrank(owner);
        // 100% tax is technically valid (though unusual)
        Shop testShop = new Shop(PRICE, 1000, 1000, REFUND_RATE, REFUND_BASE, REFUND_POLICY);
        assertEq(address(testShop.owner()), owner);
        vm.stopPrank();
    }

    function test_constructor_accepts_refund_rate_equal_to_base() public {
        vm.startPrank(owner);
        // 100% refund is valid
        Shop testShop = new Shop(PRICE, TAX, TAX_BASE, 1000, 1000, REFUND_POLICY);
        assertEq(address(testShop.owner()), owner);
        vm.stopPrank();
    }

    function test_constructor_prevents_misconfiguration() public {
        vm.startPrank(owner);
        // This would have been the bug: swapping REFUND_RATE and REFUND_BASE
        // would create 200% refund (1000/500 = 2.0 = 200%)
        vm.expectRevert(Shop.InvalidConstructorParameters.selector);
        new Shop(PRICE, TAX, TAX_BASE, 1000, 500, REFUND_POLICY); // Swapped!
        vm.stopPrank();
    }

    // ============ Ownership Transfer Tests ============

    function test_transfer_ownership_success() public {
        address newOwner = makeAddr("newOwner");

        // Step 1: Current owner initiates transfer
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, false);
        emit Shop.OwnershipTransferInitiated(owner, newOwner);
        shop.transferOwnership(payable(newOwner));
        assertEq(shop.pendingOwner(), newOwner);
        assertEq(shop.owner(), owner); // Owner hasn't changed yet
        vm.stopPrank();

        // Step 2: New owner accepts ownership
        vm.startPrank(newOwner);
        vm.expectEmit(true, true, false, false);
        emit Shop.OwnershipTransferred(owner, newOwner);
        shop.acceptOwnership();
        assertEq(shop.owner(), newOwner);
        assertEq(shop.pendingOwner(), address(0)); // Pending owner cleared
        vm.stopPrank();
    }

    function test_transfer_ownership_unauthorized_initiate() public {
        address newOwner = makeAddr("newOwner");

        vm.startPrank(user1);
        vm.expectRevert(Shop.UnauthorizedAccess.selector);
        shop.transferOwnership(payable(newOwner));
        vm.stopPrank();
    }

    function test_transfer_ownership_unauthorized_accept() public {
        address newOwner = makeAddr("newOwner");

        // Owner initiates transfer
        vm.prank(owner);
        shop.transferOwnership(payable(newOwner));

        // Random user tries to accept
        vm.startPrank(user1);
        vm.expectRevert(Shop.UnauthorizedAccess.selector);
        shop.acceptOwnership();
        vm.stopPrank();
    }

    function test_transfer_ownership_to_zero_address() public {
        vm.startPrank(owner);
        vm.expectRevert(Shop.InvalidPendingOwner.selector);
        shop.transferOwnership(payable(address(0)));
        vm.stopPrank();
    }

    function test_transfer_ownership_to_same_owner() public {
        vm.startPrank(owner);
        vm.expectRevert(Shop.InvalidPendingOwner.selector);
        shop.transferOwnership(payable(owner));
        vm.stopPrank();
    }

    function test_cancel_ownership_transfer() public {
        address newOwner = makeAddr("newOwner");

        // Initiate transfer
        vm.startPrank(owner);
        shop.transferOwnership(payable(newOwner));
        assertEq(shop.pendingOwner(), newOwner);

        // Cancel transfer
        shop.cancelOwnershipTransfer();
        assertEq(shop.pendingOwner(), address(0));
        assertEq(shop.owner(), owner);
        vm.stopPrank();
    }

    function test_cancel_ownership_transfer_when_none_pending() public {
        vm.startPrank(owner);
        vm.expectRevert(Shop.NoPendingOwnershipTransfer.selector);
        shop.cancelOwnershipTransfer();
        vm.stopPrank();
    }

    function test_cancel_ownership_transfer_unauthorized() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        shop.transferOwnership(payable(newOwner));

        vm.startPrank(user1);
        vm.expectRevert(Shop.UnauthorizedAccess.selector);
        shop.cancelOwnershipTransfer();
        vm.stopPrank();
    }

    function test_accept_ownership_when_none_pending() public {
        vm.startPrank(user1);
        vm.expectRevert(Shop.UnauthorizedAccess.selector);
        shop.acceptOwnership();
        vm.stopPrank();
    }

    function test_new_owner_can_use_owner_functions() public {
        address newOwner = makeAddr("newOwner");
        topUp(newOwner, 10 ether);

        // Transfer ownership
        vm.prank(owner);
        shop.transferOwnership(payable(newOwner));

        vm.prank(newOwner);
        shop.acceptOwnership();

        // New owner can now use owner functions
        vm.startPrank(newOwner);
        shop.closeShop();
        assertTrue(shop.shopClosed());

        shop.openShop();
        assertFalse(shop.shopClosed());
        vm.stopPrank();

        // Old owner cannot use owner functions
        vm.startPrank(owner);
        vm.expectRevert(Shop.UnauthorizedAccess.selector);
        shop.closeShop();
        vm.stopPrank();
    }

    function test_overwrite_pending_owner() public {
        address newOwner1 = makeAddr("newOwner1");
        address newOwner2 = makeAddr("newOwner2");

        vm.startPrank(owner);

        // Set first pending owner
        shop.transferOwnership(payable(newOwner1));
        assertEq(shop.pendingOwner(), newOwner1);

        // Overwrite with second pending owner
        shop.transferOwnership(payable(newOwner2));
        assertEq(shop.pendingOwner(), newOwner2);

        vm.stopPrank();

        // First pending owner cannot accept
        vm.startPrank(newOwner1);
        vm.expectRevert(Shop.UnauthorizedAccess.selector);
        shop.acceptOwnership();
        vm.stopPrank();

        // Second pending owner can accept
        vm.prank(newOwner2);
        shop.acceptOwnership();
        assertEq(shop.owner(), newOwner2);
    }

    function test_new_owner_can_withdraw() public {
        // Make an order first
        vm.startPrank(user1);
        shop.buy{ value: TOTAL }();
        vm.stopPrank();

        address newOwner = makeAddr("newOwner");
        topUp(newOwner, 10 ether);

        // Transfer ownership
        vm.prank(owner);
        shop.transferOwnership(payable(newOwner));

        vm.prank(newOwner);
        shop.acceptOwnership();

        // Warp past refund policy
        vm.warp(block.timestamp + REFUND_POLICY + 1);

        // New owner can withdraw
        uint256 shopBalance = address(shop).balance;
        uint256 newOwnerBalanceBefore = newOwner.balance;

        vm.prank(newOwner);
        shop.withdraw();

        assertEq(newOwner.balance, newOwnerBalanceBefore + shopBalance);
        assertEq(address(shop).balance, 0);
    }

    // ============ Confirmation Tests ============

    function test_confirm_received() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        shop.confirmReceived(orderId);
        assertTrue(shop.getOrder(orderId).confirmed);
        assertEq(shop.totalConfirmedAmount(), PRICE);
    }

    function test_confirm_received_event() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        vm.expectEmit(true, false, false, false);
        emit Shop.OrderConfirmed(orderId);
        shop.confirmReceived(orderId);
    }

    function test_confirm_received_wrong_buyer() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        vm.startPrank(user2);
        vm.expectRevert(Shop.InvalidRefundBenefiary.selector);
        shop.confirmReceived(orderId);
        vm.stopPrank();
    }

    function test_confirm_received_invalid_order() public useCaller(user1) {
        bytes32 fakeOrderId = keccak256(abi.encode(user1, uint256(999)));
        vm.expectRevert(Shop.InvalidOrder.selector);
        shop.confirmReceived(fakeOrderId);
    }

    function test_confirm_received_already_confirmed() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        shop.confirmReceived(orderId);
        vm.expectRevert(Shop.OrderAlreadyConfirmed.selector);
        shop.confirmReceived(orderId);
    }

    function test_withdraw_confirmed_order() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        shop.confirmReceived(orderId);

        uint256 ownerBalanceBefore = owner.balance;
        uint256 shopBalanceBefore = address(shop).balance;
        vm.startPrank(owner);
        shop.withdraw();
        vm.stopPrank();

        uint256 expectedWithdrawn = PRICE + (shopBalanceBefore - PRICE) * REFUND_RATE / REFUND_BASE; // confirmed + partial unconfirmed
        assertEq(owner.balance, ownerBalanceBefore + expectedWithdrawn);
        assertEq(address(shop).balance, shopBalanceBefore - expectedWithdrawn);
        assertEq(shop.totalConfirmedAmount(), 0);
        assertTrue(shop.partialWithdrawal());
    }

    function test_refund_after_confirm_succeeds() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        shop.confirmReceived(orderId);

        uint256 shopBalanceBefore = address(shop).balance;
        uint256 userBalanceBefore = user1.balance;

        shop.refund(orderId);

        uint256 expectedRefund = PRICE.getRefund(REFUND_RATE, REFUND_BASE);
        assertEq(user1.balance, userBalanceBefore + expectedRefund);
        assertEq(address(shop).balance, shopBalanceBefore - expectedRefund);
        assertEq(shop.totalConfirmedAmount(), 0); // Should be subtracted
        assertTrue(shop.refunds(orderId));
    }

    function test_multiple_orders_confirmation() public useCaller(user1) {
        shop.buy{ value: TOTAL }();
        bytes32 orderId1 = keccak256(abi.encode(user1, uint256(0)));

        shop.buy{ value: TOTAL }();
        bytes32 orderId2 = keccak256(abi.encode(user1, uint256(1)));

        shop.confirmReceived(orderId1);

        assertEq(shop.totalConfirmedAmount(), PRICE);

        shop.confirmReceived(orderId2);

        assertEq(shop.totalConfirmedAmount(), 2 * PRICE);

        uint256 shopBalanceBefore = address(shop).balance;
        vm.startPrank(owner);
        shop.withdraw();
        vm.stopPrank();

        uint256 expectedWithdrawn = 2 * PRICE + (shopBalanceBefore - 2 * PRICE) * REFUND_RATE / REFUND_BASE;
        assertEq(address(shop).balance, shopBalanceBefore - expectedWithdrawn);
        assertEq(shop.totalConfirmedAmount(), 0);
    }
}
