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
        assertEq(address(shop).balance, TOTAL - TOTAL.getRefund(REFUND_RATE, REFUND_BASE));
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
        uint256 expectedRefund = TOTAL.getRefund(REFUND_RATE, REFUND_BASE);

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
        // Test that contract rejects direct ETH transfers
        (bool success,) = address(shop).call{ value: 1 ether }("");
        assertFalse(success);
        assertEq(address(shop).balance, 0);
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
        assertEq(shop.totalConfirmedAmount(), TOTAL);
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

        // During refund period, confirmed funds are locked
        vm.startPrank(owner);
        shop.withdraw();
        vm.stopPrank();

        // No funds should be withdrawn (all are confirmed, 0 unconfirmed)
        assertEq(owner.balance, ownerBalanceBefore);
        assertEq(address(shop).balance, shopBalanceBefore);
        assertEq(shop.totalConfirmedAmount(), TOTAL); // Should remain unchanged
        assertTrue(shop.partialWithdrawal()); // Partial withdrawal flag is set even if nothing withdrawn
    }

    function test_refund_after_confirm_succeeds() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));
        shop.confirmReceived(orderId);

        uint256 shopBalanceBefore = address(shop).balance;
        uint256 userBalanceBefore = user1.balance;

        shop.refund(orderId);

        uint256 expectedRefund = TOTAL.getRefund(REFUND_RATE, REFUND_BASE);
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

        assertEq(shop.totalConfirmedAmount(), TOTAL);

        shop.confirmReceived(orderId2);

        assertEq(shop.totalConfirmedAmount(), 2 * TOTAL);

        // Warp past refund period to allow withdrawal of confirmed funds
        vm.warp(block.timestamp + REFUND_POLICY + 1);

        uint256 shopBalanceBefore = address(shop).balance;
        vm.startPrank(owner);
        shop.withdraw();
        vm.stopPrank();

        // After refund period, all funds should be withdrawable
        assertEq(address(shop).balance, 0);
        assertEq(shop.totalConfirmedAmount(), 0);
    }

    // ============ Accounting Security Tests ============

    function test_accounting_confirmed_amount_includes_tax() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));

        // Confirm the order
        shop.confirmReceived(orderId);

        // totalConfirmedAmount should include both PRICE and TAX
        assertEq(shop.totalConfirmedAmount(), TOTAL);
        assertEq(shop.totalConfirmedAmount(), PRICE + TAX_AMOUNT);

        // Verify the order stores the full amount
        Transaction.Order memory order = shop.getOrder(orderId);
        assertEq(order.amount, TOTAL);
    }

    function test_accounting_refund_includes_tax() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));

        uint256 userBalanceBefore = user1.balance;
        uint256 expectedRefund = TOTAL * REFUND_RATE / REFUND_BASE;

        // Refund should be calculated on TOTAL (PRICE + TAX), not just PRICE
        shop.refund(orderId);

        assertEq(user1.balance, userBalanceBefore + expectedRefund);
        // User should get back 50% of what they paid (including tax)
        assertEq(expectedRefund, (PRICE + TAX_AMOUNT) * REFUND_RATE / REFUND_BASE);
    }

    function test_accounting_direct_eth_transfer_reverts() public {
        // Attempt to send ETH directly to the contract
        (bool success,) = address(shop).call{ value: 1 ether }("");
        assertFalse(success);

        // Contract balance should remain 0
        assertEq(address(shop).balance, 0);
    }

    function test_accounting_withdrawal_calculation_with_confirmed() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));

        // Confirm the order
        shop.confirmReceived(orderId);

        uint256 contractBalance = address(shop).balance;
        assertEq(contractBalance, TOTAL);
        assertEq(shop.totalConfirmedAmount(), TOTAL);

        // unconfirmedAmount should be 0, not TAX_AMOUNT (the old bug)
        uint256 unconfirmedAmount = contractBalance - shop.totalConfirmedAmount();
        assertEq(unconfirmedAmount, 0);

        // Warp past refund period to allow confirmed funds withdrawal
        vm.warp(block.timestamp + REFUND_POLICY + 1);

        // Owner should be able to withdraw the full TOTAL amount
        vm.startPrank(owner);
        uint256 ownerBalanceBefore = owner.balance;
        shop.withdraw();
        vm.stopPrank();

        assertEq(owner.balance, ownerBalanceBefore + TOTAL);
        assertEq(address(shop).balance, 0);
    }

    function test_accounting_multiple_confirmations_track_correctly() public useCaller(user1) {
        // Make 3 orders
        shop.buy{ value: TOTAL }();
        bytes32 orderId1 = keccak256(abi.encode(user1, uint256(0)));

        shop.buy{ value: TOTAL }();
        bytes32 orderId2 = keccak256(abi.encode(user1, uint256(1)));

        shop.buy{ value: TOTAL }();
        bytes32 orderId3 = keccak256(abi.encode(user1, uint256(2)));

        // Confirm first order
        shop.confirmReceived(orderId1);
        assertEq(shop.totalConfirmedAmount(), TOTAL);

        // Confirm second order
        shop.confirmReceived(orderId2);
        assertEq(shop.totalConfirmedAmount(), 2 * TOTAL);

        // Confirm third order
        shop.confirmReceived(orderId3);
        assertEq(shop.totalConfirmedAmount(), 3 * TOTAL);

        // Contract balance should equal totalConfirmedAmount
        assertEq(address(shop).balance, 3 * TOTAL);
        assertEq(address(shop).balance, shop.totalConfirmedAmount());
    }

    function test_accounting_refund_after_confirmation_decreases_confirmed_amount() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));

        // Confirm order
        shop.confirmReceived(orderId);
        assertEq(shop.totalConfirmedAmount(), TOTAL);

        // Refund the confirmed order
        shop.refund(orderId);

        // totalConfirmedAmount should decrease back to 0
        assertEq(shop.totalConfirmedAmount(), 0);
    }

    function test_accounting_withdrawal_with_mixed_confirmed_unconfirmed() public useCaller(user1) {
        // Make 2 orders
        shop.buy{ value: TOTAL }();
        bytes32 orderId1 = keccak256(abi.encode(user1, uint256(0)));

        shop.buy{ value: TOTAL }();

        // Confirm only the first order
        shop.confirmReceived(orderId1);

        // totalConfirmedAmount = TOTAL, total balance = 2 * TOTAL
        assertEq(shop.totalConfirmedAmount(), TOTAL);
        assertEq(address(shop).balance, 2 * TOTAL);

        // Unconfirmed amount should be exactly TOTAL
        uint256 unconfirmed = address(shop).balance - shop.totalConfirmedAmount();
        assertEq(unconfirmed, TOTAL);

        // Owner withdraws before refund period
        vm.startPrank(owner);
        uint256 ownerBalanceBefore = owner.balance;
        shop.withdraw();
        vm.stopPrank();

        // Should withdraw: ONLY partial unconfirmed (TOTAL * 50%)
        // Confirmed funds are locked during refund period
        uint256 expectedWithdrawal = TOTAL * REFUND_RATE / REFUND_BASE;
        assertEq(owner.balance, ownerBalanceBefore + expectedWithdrawal);

        // Contract should retain: confirmed (TOTAL) + refundable unconfirmed portion
        uint256 expectedRemaining = TOTAL + (TOTAL * (REFUND_BASE - REFUND_RATE) / REFUND_BASE);
        assertEq(address(shop).balance, expectedRemaining);
    }

    // ============ Refund Period Protection Tests ============

    function test_refund_protection_confirmed_funds_locked_during_period() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));

        // User confirms order
        shop.confirmReceived(orderId);
        assertEq(shop.totalConfirmedAmount(), TOTAL);

        // Owner attempts to withdraw during refund period
        vm.startPrank(owner);
        uint256 ownerBalanceBefore = owner.balance;
        shop.withdraw();
        vm.stopPrank();

        // Confirmed funds should remain locked
        assertEq(owner.balance, ownerBalanceBefore); // No withdrawal
        assertEq(address(shop).balance, TOTAL); // All funds remain
        assertEq(shop.totalConfirmedAmount(), TOTAL); // Tracking unchanged
    }

    function test_refund_protection_confirmed_funds_available_after_period() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));

        // User confirms order
        shop.confirmReceived(orderId);
        assertEq(shop.totalConfirmedAmount(), TOTAL);

        // Warp past refund period
        vm.warp(block.timestamp + REFUND_POLICY + 1);

        // Owner withdraws after refund period
        vm.startPrank(owner);
        uint256 ownerBalanceBefore = owner.balance;
        shop.withdraw();
        vm.stopPrank();

        // All funds should be withdrawn
        assertEq(owner.balance, ownerBalanceBefore + TOTAL);
        assertEq(address(shop).balance, 0);
        assertEq(shop.totalConfirmedAmount(), 0);
    }

    function test_refund_protection_user_can_refund_confirmed_order() public makeOrder(user1) {
        bytes32 orderId = keccak256(abi.encode(user1, uint256(0)));

        // User confirms order
        shop.confirmReceived(orderId);
        assertEq(shop.totalConfirmedAmount(), TOTAL);

        // Owner attempts withdrawal (nothing happens since all confirmed)
        vm.startPrank(owner);
        shop.withdraw();
        vm.stopPrank();

        // User can still refund the confirmed order
        vm.startPrank(user1);
        uint256 userBalanceBefore = user1.balance;
        shop.refund(orderId);

        // User receives refund successfully
        uint256 expectedRefund = TOTAL * REFUND_RATE / REFUND_BASE;
        assertEq(user1.balance, userBalanceBefore + expectedRefund);
        assertEq(shop.totalConfirmedAmount(), 0); // Decreased after refund
        vm.stopPrank();
    }

    function test_refund_protection_prevents_double_withdrawal_issue() public useCaller(user1) {
        // User1 makes and confirms order
        shop.buy{ value: TOTAL }();
        bytes32 orderId1 = keccak256(abi.encode(user1, uint256(0)));
        shop.confirmReceived(orderId1);

        // User2 makes and confirms order
        vm.startPrank(user2);
        shop.buy{ value: TOTAL }();
        bytes32 orderId2 = keccak256(abi.encode(user2, uint256(0)));
        shop.confirmReceived(orderId2);
        vm.stopPrank();

        assertEq(shop.totalConfirmedAmount(), 2 * TOTAL);

        // Owner withdraws during refund period (nothing happens)
        vm.prank(owner);
        shop.withdraw();
        assertEq(shop.totalConfirmedAmount(), 2 * TOTAL); // Still tracked

        // User1 refunds
        vm.prank(user1);
        shop.refund(orderId1);
        assertEq(shop.totalConfirmedAmount(), TOTAL); // Correctly decreased

        // User2 can also refund without underflow
        vm.prank(user2);
        shop.refund(orderId2);
        assertEq(shop.totalConfirmedAmount(), 0); // Correctly decreased to 0
    }

    function test_refund_protection_mixed_scenario() public {
        // Make 3 orders as user1
        vm.startPrank(user1);
        shop.buy{ value: TOTAL }();
        bytes32 orderId1 = keccak256(abi.encode(user1, uint256(0)));

        shop.buy{ value: TOTAL }();
        bytes32 orderId2 = keccak256(abi.encode(user1, uint256(1)));

        shop.buy{ value: TOTAL }();
        bytes32 orderId3 = keccak256(abi.encode(user1, uint256(2)));

        // Confirm only orders 1 and 2
        shop.confirmReceived(orderId1);
        shop.confirmReceived(orderId2);
        vm.stopPrank();

        // totalConfirmedAmount = 2 * TOTAL, unconfirmed = TOTAL
        assertEq(shop.totalConfirmedAmount(), 2 * TOTAL);
        assertEq(address(shop).balance, 3 * TOTAL);

        // Owner withdraws during refund period
        vm.startPrank(owner);
        uint256 ownerBalanceBefore = owner.balance;
        shop.withdraw();
        vm.stopPrank();

        // Should only withdraw partial unconfirmed amount
        uint256 expectedWithdrawal = TOTAL * REFUND_RATE / REFUND_BASE;
        assertEq(owner.balance, ownerBalanceBefore + expectedWithdrawal);

        // Confirmed amount tracking should be intact
        assertEq(shop.totalConfirmedAmount(), 2 * TOTAL);

        // Users can refund their confirmed orders
        vm.startPrank(user1);
        shop.refund(orderId1);
        assertEq(shop.totalConfirmedAmount(), TOTAL);

        shop.refund(orderId2);
        assertEq(shop.totalConfirmedAmount(), 0);

        // User can also refund unconfirmed order
        shop.refund(orderId3);
        vm.stopPrank();

        // No underflow or accounting errors occurred
        assertTrue(true);
    }
}
