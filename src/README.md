# Shop Contract Documentation

Comprehensive documentation for the Shop smart contract implementation.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Constructor Parameters](#constructor-parameters)
- [Functions](#functions)
- [Events](#events)
- [Errors](#errors)
- [Security](#security)
- [Usage Examples](#usage-examples)

## Overview

The Shop contract implements a secure e-commerce system with:

- Fixed-price purchases with tax calculation
- Time-bound refund policy
- Two-step ownership transfer mechanism
- Smart withdrawal system with refund period protection

**Solidity Version**: 0.8.30
**License**: MIT

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

// State Management
uint256 lastBuy;                       // Timestamp of last purchase
bool partialWithdrawal;                // Has partial withdrawal occurred
bool public shopClosed;                // Is shop accepting purchases
```

### Order Structure

```solidity
struct Order {
    address buyer;      // Buyer's address
    uint256 nonce;      // Buyer's purchase nonce
    uint256 amount;     // Base price (excluding tax)
    uint256 date;       // Purchase timestamp
}
```

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
- Refund amount: `price * refundRate / refundBase` = 0.005 ETH

## Functions

### Customer Functions

#### `buy() payable`

Purchase an item by sending exact ETH amount.

**Requirements:**

- Shop must be open
- Must send exact `price + tax` amount

**State Changes:**

- Increments buyer's nonce
- Creates order with unique ID
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

#### `refund(bytes32 orderId) external`

Request a refund for a previous purchase.

**Requirements:**

- Caller must be original buyer
- Must be within refund window
- Order must not already be refunded

**State Changes:**

- Marks order as refunded
- Transfers ETH to buyer
- Emits `RefundProcessed` event

**Reverts:**

- `InvalidRefundBenefiary()` - Not buyer or order doesn't exist
- `RefundPolicyExpired()` - Outside refund window
- `DuplicateRefundClaim()` - Already refunded
- `TransferFailed()` - ETH transfer failed

```solidity
bytes32 orderId = keccak256(abi.encode(msg.sender, nonce));
shop.refund(orderId);
```

### Owner Functions

#### `withdraw() onlyOwner`

Withdraw accumulated funds with refund period protection.

**Logic:**

```
IF lastBuy + REFUND_POLICY < block.timestamp:
    // Full withdrawal (no recent purchases)
    Transfer entire balance
    Reset partialWithdrawal flag
ELSE:
    // Partial withdrawal (recent purchases exist)
    IF partialWithdrawal == true:
        Revert (already withdrew once this period)
    ELSE:
        Set partialWithdrawal = true
        Transfer (balance * REFUND_RATE / REFUND_BASE)
```

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
event BuyOrder(bytes32 orderId, uint256 amount);
event RefundProcessed(bytes32 orderId, uint256 amount);
event ShopOpen(uint256 timestamp);
event ShopClosed(uint256 timestamp);
event OwnershipTransferInitiated(address indexed previousOwner, address indexed newOwner);
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
```

## Errors

All errors use gas-efficient custom error pattern (no string messages):

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
```

## Security

### Implemented Protections

#### 1. Reentrancy Protection

Follows checks-effects-interactions (CEI) pattern:

```solidity
// ✅ Good: State changes before external call
refunds[orderId] = true;
(bool success,) = payable(msg.sender).call{value: refundAmount}("");
if (!success) revert TransferFailed();
```

#### 2. Two-Step Ownership Transfer

Prevents accidental ownership loss:

```solidity
// Step 1: Owner proposes
shop.transferOwnership(payable(newOwner));

// Step 2: New owner accepts
shop.acceptOwnership();
```

#### 3. Input Validation

All constructor parameters validated:

```solidity
if (price == 0) revert InvalidConstructorParameters();
if (taxBase == 0) revert InvalidConstructorParameters();
if (tax > taxBase) revert InvalidConstructorParameters();
// ... more validations
```

#### 4. Custom Errors

Gas-efficient error handling (~50% cheaper than `require()`):

```solidity
// ❌ Old: require(success, "Transfer failed");  // ~1,500 gas
// ✅ New: if (!success) revert TransferFailed(); // ~300 gas
```

#### 5. Exact Payment Requirement

Prevents overpayment fund locking:

```solidity
if (msg.value < expectedTotal) revert InsuffientAmount();
if (msg.value > expectedTotal) revert ExcessAmount();
```

#### 6. Modern Transfer Pattern

Uses `.call()` instead of deprecated `.transfer()`:

```solidity
(bool success,) = payable(recipient).call{value: amount}("");
if (!success) revert TransferFailed();
```

### Known Limitations

1. **Fixed Price**: Cannot change price after deployment
2. **Single Product**: Only supports one product type
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
uint256 nonce = shop.nonces(customer) - 1; // Last purchase nonce
bytes32 orderId = keccak256(abi.encode(customer, nonce));

// 4. Customer requests refund (within 24 hours)
shop.refund(orderId);

// 5. Owner manages shop
shop.closeShop();  // Close temporarily
shop.openShop();   // Reopen

// 6. Owner withdraws funds
// Wait 24 hours after last purchase for full withdrawal
vm.warp(block.timestamp + 24 hours + 1);
shop.withdraw();

// 7. Transfer ownership
shop.transferOwnership(payable(newOwner));
// New owner accepts (from newOwner account)
shop.acceptOwnership();
```

### Edge Cases

#### Refund Timing

```solidity
// Purchase at T=0
shop.buy{value: 0.011 ether}();

// Refund at T=24h-1s ✅ Valid
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
shop.withdraw(); // ✅ Partial withdrawal (50%)
shop.withdraw(); // ❌ Reverts: WaitUntilRefundPeriodPassed

// Scenario 2: No recent purchase (>24h ago)
vm.warp(block.timestamp + 24 hours + 1);
shop.withdraw(); // ✅ Full withdrawal (100%)
shop.withdraw(); // ✅ Works (transfers 0 ETH)
```

#### Multiple Purchases

```solidity
// User can make multiple purchases
shop.buy{value: 0.011 ether}(); // nonce = 0, orderId = hash(user, 0)
shop.buy{value: 0.011 ether}(); // nonce = 1, orderId = hash(user, 1)
shop.buy{value: 0.011 ether}(); // nonce = 2, orderId = hash(user, 2)

// Each order has unique ID and can be refunded independently
bytes32 orderId0 = keccak256(abi.encode(user, 0));
bytes32 orderId1 = keccak256(abi.encode(user, 1));

shop.refund(orderId0); // ✅ Refund first purchase
shop.refund(orderId1); // ✅ Refund second purchase
shop.refund(orderId0); // ❌ Reverts: DuplicateRefundClaim
```

## Testing

The contract includes 54 comprehensive tests covering:

- [x] Purchase flow (valid/invalid amounts)
- [x] Refund system (timing, authorization, duplicates)
- [x] Withdrawal system (full/partial, restrictions)
- [x] Shop state management
- [x] Ownership transfer (all scenarios)
- [x] Constructor validation (all parameters)
- [x] Access control
- [x] Event emissions
- [x] Edge cases

Run tests:

```bash
forge test -vv                               # All tests with output
forge test --match-test test_refund -vvvv    # Specific test with traces
forge test --gas-report                      # Gas usage report
```

---

**For implementation details, see [Shop.sol](Shop.sol)**
