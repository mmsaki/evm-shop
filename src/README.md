# Shop Contract Documentation

Comprehensive technical documentation for the Shop smart contract implementation.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Constructor Parameters](#constructor-parameters)
- [Functions](#functions)
- [Events](#events)
- [Errors](#errors)
- [Security](#security)
- [Usage Examples](#usage-examples)
- [Testing](#testing)

## Overview

The Shop contract implements a trust-minimized e-commerce system with:

- **Fixed-price purchases** with automatic tax calculation
- **Time-bound refund policy** with 24-hour guarantee
- **Buyer confirmation system** for faster seller liquidity
- **Two-step ownership transfer** mechanism
- **Smart withdrawal system** with refund period protection
- **Game theory-aligned incentives** that protect buyers

**Solidity Version**: 0.8.30
**License**: MIT
**Tests**: 74/74 passing ✅

## Architecture

### State Variables

```solidity
// Immutable Configuration (set once at deployment)
uint256 immutable PRICE;              // Base price per item
uint16 immutable TAX;                 // Tax rate numerator
uint16 immutable TAX_BASE;            // Tax rate denominator
uint16 immutable REFUND_RATE;         // Refund percentage numerator
uint16 immutable REFUND_BASE;         // Refund percentage denominator
uint256 immutable REFUND_POLICY;      // Refund window in seconds

// Ownership
address payable public owner;          // Current owner
address payable public pendingOwner;   // Pending owner (two-step transfer)

// Orders & Refunds
mapping(bytes32 => Transaction.Order) public orders;    // orderId => Order
mapping(address => uint256) public nonces;              // buyer => nonce
mapping(bytes32 => bool) public refunds;                // orderId => refunded
mapping(bytes32 => bool) public paid;                   // orderId => paid (unused)

// State Management
uint256 lastBuy;                       // Timestamp of last purchase
bool public partialWithdrawal;         // Has partial withdrawal occurred
bool public shopClosed;                // Is shop accepting purchases
uint256 public totalConfirmedAmount;   // Sum of confirmed orders ⭐ NEW
```

### Order Structure

```solidity
struct Order {
    address buyer;      // Buyer's address
    uint256 nonce;      // Buyer's purchase nonce
    uint256 amount;     // TOTAL amount paid (PRICE + TAX) ⭐ UPDATED
    uint256 date;       // Purchase timestamp
    bool confirmed;     // Whether buyer confirmed receipt ⭐ NEW
}
```

**Key Change:** `amount` now stores the **full amount paid** including TAX, not just the base PRICE.

### Order ID Generation

```solidity
bytes32 orderId = keccak256(abi.encode(buyer, nonce));
```

Each order has a unique ID based on the buyer's address and their purchase nonce.

## Constructor Parameters

### Parameter Validation

All parameters are validated to prevent misconfiguration:

| Parameter | Type | Validation | Description |
|-----------|------|------------|-------------|
| `price` | `uint256` | `> 0` | Base price per item in wei |
| `tax` | `uint16` | `≤ taxBase` | Tax percentage numerator |
| `taxBase` | `uint16` | `> 0` | Tax percentage denominator |
| `refundRate` | `uint16` | `≤ refundBase` | Refund percentage numerator |
| `refundBase` | `uint16` | `> 0` | Refund percentage denominator |
| `refundPolicy` | `uint256` | `> 0` | Refund window in seconds |

### Example Configuration

```solidity
new Shop(
    1e16,       // 0.01 ETH price
    100,        // 10% tax (100/1000)
    1000,       // Tax base
    500,        // 50% refund (500/1000)
    1000,       // Refund base
    24 hours    // 24-hour refund window
);
```

**Calculations:**
- Total cost: `price + (price * tax / taxBase)` = 0.011 ETH
- Refund amount: `totalPaid * refundRate / refundBase` = 0.0055 ETH (50% of total)

## Functions

### Customer Functions

#### `buy() payable`

Purchase an item by sending exact ETH amount.

**Requirements:**
- Shop must be open
- Must send exact `price + tax` amount

**State Changes:**
- Increments buyer's nonce
- Creates order with **total amount (PRICE + TAX)** ⭐ UPDATED
- Updates `lastBuy` timestamp
- Emits `BuyOrder` event

**Reverts:**
- `ShopIsClosed()` - Shop closed
- `MissingTax()` - Sent exact price without tax
- `InsuffientAmount()` - Sent less than required
- `ExcessAmount()` - Sent more than required

```solidity
// Calculate required amount
uint256 expectedTotal = PRICE.addTax(TAX, TAX_BASE);

// Purchase
shop.buy{value: expectedTotal}();
```

#### `confirmReceived(bytes32 orderId) external` ⭐ NEW

Confirm receipt of service or product.

**Purpose:**
- Signal to owner that service was received
- Allows owner faster access to funds (after refund period)
- Buyer can still refund within 24 hours!

**Requirements:**
- Caller must be original buyer
- Order must exist
- Must not already be confirmed

**State Changes:**
- Sets `order.confirmed = true`
- Adds `order.amount` to `totalConfirmedAmount`
- Emits `OrderConfirmed` event

**Reverts:**
- `InvalidOrder()` - Order doesn't exist
- `InvalidRefundBenefiary()` - Not the buyer
- `OrderAlreadyConfirmed()` - Already confirmed

```solidity
bytes32 orderId = keccak256(abi.encode(msg.sender, nonce));
shop.confirmReceived(orderId);
```

#### `refund(bytes32 orderId) external`

Request a refund for a previous purchase.

**Requirements:**
- Caller must be original buyer
- Must be within refund window (24 hours)
- Order must not already be refunded

**State Changes:**
- Marks order as refunded
- If confirmed, **decreases `totalConfirmedAmount`** ⭐ UPDATED
- Transfers **50% of total amount** (includes TAX) ⭐ UPDATED
- Emits `RefundProcessed` event

**Reverts:**
- `InvalidRefundBenefiary()` - Not buyer or order doesn't exist
- `RefundPolicyExpired()` - Outside refund window
- `DuplicateRefundClaim()` - Already refunded
- `TransferFailed()` - ETH transfer failed

```solidity
bytes32 orderId = keccak256(abi.encode(msg.sender, nonce));
shop.refund(orderId);  // Get 50% of (PRICE + TAX) back
```

#### `getOrder(bytes32 orderId) external view returns (Order memory)`

View order details.

```solidity
Transaction.Order memory order = shop.getOrder(orderId);
// Returns: buyer, nonce, amount, date, confirmed
```

### Owner Functions

#### `withdraw() onlyOwner` ⭐ UPDATED

Withdraw accumulated funds with refund period protection.

**Logic:**

```
┌─────────────────────────────────────────┐
│ lastBuy + REFUND_POLICY < now?          │
│                                         │
│   YES                    NO             │
│    ↓                      ↓             │
│ FULL MODE          PARTIAL MODE         │
│                                         │
│ • Withdraw all     • Only 50% of       │
│ • Reset confirmed    unconfirmed       │
│ • Reset flags      • Once per period   │
│                    • Confirmed LOCKED  │
└─────────────────────────────────────────┘
```

**Full Withdrawal Mode:**
```solidity
// No orders in last 24 hours
withdrawable = entire contract balance
totalConfirmedAmount = 0  // Reset
partialWithdrawal = false // Reset
```

**Partial Withdrawal Mode:**
```solidity
// Orders within last 24 hours
confirmedAmount = totalConfirmedAmount  // LOCKED!
unconfirmedAmount = balance - confirmedAmount
withdrawable = unconfirmedAmount * 50%  // Only 50% of unconfirmed
partialWithdrawal = true                // Can't withdraw again
// Don't touch totalConfirmedAmount
```

**Key Protection:** Confirmed funds are **locked** during refund period, ensuring buyers can always refund.

**Reverts:**
- `UnauthorizedAccess()` - Not owner
- `WaitUntilRefundPeriodPassed()` - Second partial withdrawal attempt
- `TransferFailed()` - ETH transfer failed

#### `openShop() onlyOwner`

Open the shop for purchases.

**State Changes:**
- Sets `shopClosed = false`
- Emits `ShopOpen` event (only if was closed)

#### `closeShop() onlyOwner`

Close the shop to prevent new purchases.

**State Changes:**
- Sets `shopClosed = true`
- Emits `ShopClosed` event

**Strategic Use:** Close shop to access full withdrawal after 24 hours.

### Ownership Management

#### `transferOwnership(address payable newOwner) onlyOwner`

**Step 1 of 2**: Initiate ownership transfer.

**Requirements:**
- `newOwner` cannot be zero address
- `newOwner` cannot be current owner

**State Changes:**
- Sets `pendingOwner = newOwner`
- Emits `OwnershipTransferInitiated` event

#### `acceptOwnership()`

**Step 2 of 2**: Accept pending ownership transfer.

**Requirements:**
- Caller must be `pendingOwner`
- `pendingOwner` must not be zero address

**State Changes:**
- Sets `owner = pendingOwner`
- Resets `pendingOwner = address(0)`
- Emits `OwnershipTransferred` event

#### `cancelOwnershipTransfer() onlyOwner`

Cancel a pending ownership transfer.

**Requirements:**
- Must have pending transfer

**State Changes:**
- Resets `pendingOwner = address(0)`
- Emits `OwnershipTransferInitiated(owner, address(0))`

## Events

```solidity
event BuyOrder(bytes32 indexed orderId, uint256 amount);
event RefundProcessed(bytes32 indexed orderId, uint256 amount);
event OrderConfirmed(bytes32 indexed orderId);              // ⭐ NEW
event ShopOpen(uint256 timestamp);
event ShopClosed(uint256 timestamp);
event OwnershipTransferInitiated(address indexed previousOwner, address indexed newOwner);
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
```

## Errors

All errors use gas-efficient custom error pattern:

```solidity
error ExcessAmount();                    // Overpayment
error InsuffientAmount();                // Underpayment
error DuplicateRefundClaim();            // Already refunded
error RefundPolicyExpired();             // Outside refund window
error InvalidRefundBenefiary();          // Invalid refund claimant
error ShopIsClosed();                    // Shop not accepting purchases
error UnauthorizedAccess();              // Not authorized
error MissingTax();                      // Exact price sent (no tax)
error WaitUntilRefundPeriodPassed();     // Multiple partial withdrawals
error InvalidConstructorParameters();     // Invalid deployment params
error InvalidPendingOwner();             // Invalid transfer target
error NoPendingOwnershipTransfer();      // No pending transfer
error TransferFailed();                  // ETH transfer failed
error OrderAlreadyConfirmed();           // Already confirmed      ⭐ NEW
error InvalidOrder();                    // Order doesn't exist   ⭐ NEW
```

## Security

### Critical Security Fixes (Version 1.0.0)

#### ✅ Fixed: TAX Included in Order Amounts

**Before (Vulnerable):**
```solidity
orders[orderId] = Order(..., PRICE, ...);  // Missing TAX!
```

**After (Fixed):**
```solidity
orders[orderId] = Order(..., expectedTotal, ...);  // Includes TAX ✅
```

**Impact:** Eliminates accounting mismatch between payments and tracking.

#### ✅ Fixed: Refund Calculation Includes TAX

**Before (Vulnerable):**
```solidity
refundAmount = PRICE.getRefund(...);  // Only refunds based on PRICE
```

**After (Fixed):**
```solidity
refundAmount = order.amount.getRefund(...);  // Refunds include TAX ✅
```

**Impact:** Buyers get fair refunds on total amount paid.

#### ✅ Fixed: Refund Period Protection

**Before (Vulnerable):**
```solidity
withdrawable = confirmedAmount;  // Owner could withdraw immediately!
totalConfirmedAmount = 0;        // Reset on every withdrawal
```

**After (Fixed):**
```solidity
// During refund period: Confirmed funds LOCKED
if (lastBuy + REFUND_POLICY >= now) {
    withdrawable = 0;  // From confirmed funds
    withdrawable = unconfirmedAmount * 50%;  // Only from unconfirmed
}
```

**Impact:** Guarantees buyers can always refund within 24 hours.

#### ✅ Fixed: Direct ETH Transfer Blocking

**Added:**
```solidity
receive() external payable {
    revert("Direct transfers not allowed");
}
```

**Impact:** Prevents accounting manipulation via direct transfers.

### Implemented Protections

#### 1. Reentrancy Protection

Follows checks-effects-interactions (CEI) pattern:

```solidity
// ✅ Correct order
// 1. Checks
if (order.buyer != msg.sender) revert InvalidRefundBenefiary();

// 2. Effects
refunds[orderId] = true;
if (order.confirmed) {
    totalConfirmedAmount -= order.amount;
}

// 3. Interactions
(bool success,) = payable(msg.sender).call{value: refundAmount}("");
if (!success) revert TransferFailed();
```

#### 2. Arithmetic Safety

- Solidity 0.8.30 built-in overflow/underflow protection
- All calculations validated in 74 comprehensive tests

#### 3. Two-Step Ownership Transfer

Prevents accidental ownership loss:

```solidity
// Step 1: Owner proposes
shop.transferOwnership(payable(newOwner));

// Step 2: New owner accepts
shop.acceptOwnership();
```

#### 4. Input Validation

All constructor parameters validated:

```solidity
if (price == 0) revert InvalidConstructorParameters();
if (taxBase == 0) revert InvalidConstructorParameters();
if (tax > taxBase) revert InvalidConstructorParameters();
if (refundBase == 0) revert InvalidConstructorParameters();
if (refundRate > refundBase) revert InvalidConstructorParameters();
if (refundPolicy == 0) revert InvalidConstructorParameters();
```

#### 5. Custom Errors

Gas-efficient error handling (~50% cheaper than `require()`):

```solidity
// ❌ Old: require(success, "Transfer failed");  // ~1,500 gas
// ✅ New: if (!success) revert TransferFailed(); // ~300 gas
```

#### 6. Exact Payment Requirement

Prevents overpayment fund locking:

```solidity
if (msg.value < expectedTotal) revert InsuffientAmount();
if (msg.value > expectedTotal) revert ExcessAmount();
```

#### 7. Modern Transfer Pattern

Uses `.call()` instead of deprecated `.transfer()`:

```solidity
(bool success,) = payable(recipient).call{value: amount}("");
if (!success) revert TransferFailed();
```

### Game Theory Protection

The system creates natural buyer protection through economics:

**The "Popular Shop" Effect:**
```solidity
// Every purchase updates lastBuy
lastBuy = block.timestamp;

// Continuous orders = lastBuy keeps updating
// Owner stuck in PARTIAL mode = funds locked
// All buyers protected by perpetual refund coverage
```

**Result:**
- Popular shop = maximum buyer safety
- Owner must choose: Growth or Liquidity
- Economics align with good behavior

See [BUYER_GUIDE.md](../BUYER_GUIDE.md) and [OWNER_GUIDE.md](../OWNER_GUIDE.md) for detailed analysis.

### Known Limitations

1. **Immutable Parameters**: Cannot change price, tax, or refund policy after deployment
2. **Single Product**: Only supports one product type per contract
3. **No Batch Operations**: No batch purchase/refund functions
4. **Owner Fund Lock**: If owner becomes reverting contract, use ownership transfer

## Usage Examples

### Complete Workflow

```solidity
// 1. Deploy contract
Shop shop = new Shop(
    1e16,      // 0.01 ETH
    100,       // 10% tax
    1000,      // tax base
    500,       // 50% refund
    1000,      // refund base
    24 hours   // refund window
);

// 2. Customer purchases
uint256 total = 0.011 ether; // price + tax
shop.buy{value: total}();

// 3. Get order ID
uint256 nonce = shop.nonces(customer) - 1;
bytes32 orderId = keccak256(abi.encode(customer, nonce));

// 4. Customer confirms receipt (optional)
shop.confirmReceived(orderId);

// 5. Customer requests refund (within 24 hours, even after confirming!)
shop.refund(orderId);  // Gets 50% of 0.011 ETH = 0.0055 ETH back

// 6. Owner manages shop
shop.closeShop();  // Close temporarily
shop.openShop();   // Reopen

// 7. Owner withdraws funds
// During refund period: Only partial unconfirmed amounts
shop.withdraw();  // Gets 50% of unconfirmed funds

// After refund period: Full withdrawal
vm.warp(block.timestamp + 24 hours + 1);
shop.withdraw();  // Gets everything

// 8. Transfer ownership
shop.transferOwnership(payable(newOwner));
// New owner accepts (from newOwner account)
shop.acceptOwnership();
```

### Edge Cases

#### Confirmed Order Withdrawal Protection

```solidity
// User buys and confirms
shop.buy{value: 0.011 ether}();
bytes32 orderId = keccak256(abi.encode(user, 0));
shop.confirmReceived(orderId);

// totalConfirmedAmount = 0.011 ETH

// Owner tries to withdraw immediately
shop.withdraw();
// → Owner gets 0 ETH (all funds are confirmed and locked!)

// User can still refund within 24 hours
shop.refund(orderId);  // ✅ Works! Gets 0.0055 ETH back
// totalConfirmedAmount decreases to 0

// After 24 hours, owner can withdraw
vm.warp(block.timestamp + 24 hours + 1);
shop.withdraw();  // ✅ Gets remaining funds
```

#### Mixed Confirmed/Unconfirmed Orders

```solidity
// User1 buys and confirms
shop.buy{value: 0.011 ether}();
shop.confirmReceived(orderIdUser1);

// User2 buys but doesn't confirm
shop.buy{value: 0.011 ether}();

// Contract: 0.022 ETH
// - Confirmed: 0.011 ETH (locked)
// - Unconfirmed: 0.011 ETH

// Owner withdraws
shop.withdraw();
// → Gets 0.0055 ETH (50% of unconfirmed only)
// → Confirmed 0.011 ETH stays locked
// → User1 can still refund their confirmed order!
```

#### Refund Timing

```solidity
// Purchase at T=0
shop.buy{value: 0.011 ether}();

// Refund at T=23h59m59s ✅ Valid
vm.warp(block.timestamp + 24 hours - 1);
shop.refund(orderId); // Success

// Refund at T=24h ✅ Valid (< not <=)
vm.warp(block.timestamp + 24 hours);
shop.refund(orderId); // Success

// Refund at T=24h+1s ❌ Expired
vm.warp(block.timestamp + 24 hours + 1);
shop.refund(orderId); // Reverts: RefundPolicyExpired
```

#### Withdrawal Restrictions

```solidity
// Scenario 1: Recent purchase (within 24h)
shop.buy{value: 0.011 ether}();
shop.withdraw(); // ✅ Partial withdrawal (50% of unconfirmed)
shop.withdraw(); // ❌ Reverts: WaitUntilRefundPeriodPassed

// Scenario 2: No recent purchase (>24h ago)
vm.warp(block.timestamp + 24 hours + 1);
shop.withdraw(); // ✅ Full withdrawal (100%)
shop.withdraw(); // ✅ Works (transfers 0 ETH if balance is 0)
```

#### Multiple Purchases with Confirmations

```solidity
// User makes 3 purchases
shop.buy{value: 0.011 ether}(); // orderId0
shop.buy{value: 0.011 ether}(); // orderId1
shop.buy{value: 0.011 ether}(); // orderId2

// Confirms first two
shop.confirmReceived(orderId0);
shop.confirmReceived(orderId1);

// totalConfirmedAmount = 0.022 ETH
// unconfirmed = 0.011 ETH

// Owner withdraws
shop.withdraw();
// → Gets 0.0055 ETH (50% of unconfirmed)
// → 0.022 ETH confirmed stays locked

// Users can refund their confirmed orders
shop.refund(orderId0);  // ✅ Works
shop.refund(orderId1);  // ✅ Works
// totalConfirmedAmount now = 0
```

## Testing

The contract includes **74 comprehensive tests** covering:

### Test Categories

- ✅ **Basic Operations** (15 tests)
  - Buy, refund, withdrawal flows
  - Shop open/close
  - Nonce tracking

- ✅ **Constructor Validation** (8 tests)
  - Parameter validation
  - Misconfiguration prevention

- ✅ **Ownership Transfer** (11 tests)
  - 2-step transfer process
  - Authorization checks
  - Edge cases

- ✅ **Confirmation System** (5 tests) ⭐ NEW
  - Confirm receipt
  - Double confirmation prevention
  - Access control

- ✅ **Accounting Security** (7 tests) ⭐ NEW
  - TAX inclusion validation
  - Refund calculation correctness
  - Direct transfer rejection
  - Withdrawal math verification

- ✅ **Refund Period Protection** (5 tests) ⭐ NEW
  - Confirmed funds locked during period
  - Available after period
  - User can still refund confirmed orders
  - Prevents double withdrawal issue
  - Mixed scenario handling

- ✅ **Edge Cases** (23 tests)
  - Multiple orders
  - Expired refunds
  - Insufficient amounts
  - Unauthorized access
  - Time-based scenarios

### Run Tests

```bash
# All tests
forge test

# Verbose output
forge test -vv

# Specific test
forge test --match-test test_accounting_confirmed_amount_includes_tax -vvvv

# Gas report
forge test --gas-report

# Coverage
forge coverage
```

### Test Results

```
Ran 74 tests for test/Shop.t.sol:CounterTest
[PASS] 74 tests ✅
Suite result: ok. 74 passed; 0 failed; 0 skipped
```

---

## Documentation Links

- **[Main README](../README.md)** - Project overview and quick start
- **[Buyer's Guide](../BUYER_GUIDE.md)** - Complete guide for customers
- **[Owner's Guide](../OWNER_GUIDE.md)** - Complete guide for shop operators

---

**For implementation, see [Shop.sol](Shop.sol)**

*Last Updated: 2025-12-20*
*Version: 1.0.0*
