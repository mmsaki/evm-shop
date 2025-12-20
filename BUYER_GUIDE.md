# 🛍️ Shop Contract - Buyer's Guide

**Welcome to the Shop!** This guide explains how to safely buy, confirm, and refund orders on this smart contract-based shop.

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [How to Buy](#how-to-buy)
3. [Understanding Your Order](#understanding-your-order)
4. [Confirming Receipt](#confirming-receipt)
5. [Requesting Refunds](#requesting-refunds)
6. [Timeline & Deadlines](#timeline--deadlines)
7. [Your Protections](#your-protections)
8. [Frequently Asked Questions](#frequently-asked-questions)
9. [Technical Reference](#technical-reference)

---

## 🚀 Quick Start

### What You Need to Know:
- **Price:** Fixed price per item (set by shop owner)
- **Tax:** Additional tax charged on top of price
- **Refund Policy:** 24-hour refund window from time of purchase
- **Refund Amount:** 50% of total amount paid (price + tax)
- **Your Rights:** Refund available even after confirming receipt (within 24 hours)

### Three Steps:
1. **Buy** → Pay price + tax to place order
2. **Confirm** (optional) → Confirm you received the service/item
3. **Refund** (if needed) → Get 50% back within 24 hours

---

## 🛒 How to Buy

### Step 1: Check the Shop Status
```solidity
bool isOpen = shop.shopClosed();
```
- Shop must be **open** to place orders
- If closed, wait for owner to reopen

### Step 2: Calculate Total Cost
```solidity
// Example: Price = 0.01 ETH, Tax = 10%
uint256 price = shop.PRICE();          // 0.01 ETH
uint256 tax = shop.TAX();              // 100 (basis points)
uint256 taxBase = shop.TAX_BASE();     // 1000

// Total = Price + (Price × Tax / TaxBase)
// Total = 0.01 + (0.01 × 100 / 1000) = 0.011 ETH
```

### Step 3: Call `buy()` Function
```solidity
shop.buy{value: TOTAL}();
```

**Important:**
- ✅ You **MUST** send exactly `PRICE + TAX`
- ❌ Sending only `PRICE` will revert (missing tax)
- ❌ Sending too much or too little will revert
- ❌ Direct ETH transfers to contract are blocked

### What Happens:
1. Your payment is stored in the contract
2. An order ID is generated: `keccak256(abi.encode(yourAddress, nonce))`
3. Your nonce increments (for multiple orders)
4. 24-hour refund timer starts **from this moment**

---

## 📦 Understanding Your Order

### Finding Your Order ID

After buying, calculate your order ID:
```solidity
uint256 nonce = shop.nonces(yourAddress);
bytes32 orderId = keccak256(abi.encode(yourAddress, nonce - 1));
```

**Note:** Use `nonce - 1` because the nonce incremented after your purchase.

### Viewing Your Order
```solidity
(
    address buyer,
    uint256 nonce,
    uint256 amount,      // Total paid (price + tax)
    uint256 date,        // Purchase timestamp
    bool confirmed       // Whether you confirmed receipt
) = shop.orders(orderId);
```

### Multiple Orders
You can place multiple orders! Each gets a unique order ID based on:
- Your address
- Your current nonce (increments with each purchase)

**Example:**
- First order: `orderId = hash(yourAddress, 0)`
- Second order: `orderId = hash(yourAddress, 1)`
- Third order: `orderId = hash(yourAddress, 2)`

---

## ✅ Confirming Receipt

### Why Confirm?
Confirming tells the contract: *"I received the service/item successfully."*

**Benefits:**
- Shows good faith to the shop owner
- Owner gets faster access to funds (after 24-hour policy)
- You can **still refund** within 24 hours!

### How to Confirm
```solidity
shop.confirmReceived(orderId);
```

### Rules:
- ✅ Only the buyer can confirm their own order
- ✅ Can confirm immediately or wait
- ✅ Can still refund after confirming (within 24 hours)
- ❌ Cannot confirm twice (reverts with `OrderAlreadyConfirmed`)

### What Happens:
1. Your order is marked as `confirmed = true`
2. The amount is added to `totalConfirmedAmount`
3. Owner can withdraw confirmed funds after refund period expires

---

## 💸 Requesting Refunds

### Your Refund Rights

**You can refund within 24 hours of purchase, even if you confirmed receipt!**

### Refund Amount
You receive **50% of the total amount you paid** (price + tax).

**Example:**
- You paid: 0.011 ETH (0.01 price + 0.001 tax)
- Refund rate: 50%
- You receive: 0.0055 ETH

### How to Request Refund
```solidity
shop.refund(orderId);
```

### Refund Eligibility

✅ **You CAN refund if:**
- Within 24 hours of purchase
- You are the buyer of the order
- You haven't already refunded this order
- The order exists

❌ **You CANNOT refund if:**
- More than 24 hours passed since purchase
- You already refunded this order
- You're trying to refund someone else's order

### What Happens:
1. Your refund request is validated
2. If confirmed order: `totalConfirmedAmount` decreases
3. 50% of your total payment is sent back to you
4. Order is marked as refunded (can't refund again)

---

## ⏰ Timeline & Deadlines

### Critical Time Window: **24 Hours**

```
Time 0: You buy
│
├─ Minute 1-1439: ✅ Can refund (50% back)
├─ Hour 23:59:59: ✅ Last second to refund
│
└─ Hour 24:00:01: ❌ Refund window closed
```

### Example Timeline

**Monday 10:00 AM** - You buy
- Order placed
- Total paid: 0.011 ETH
- Refund deadline: Tuesday 10:00 AM

**Monday 3:00 PM** - You confirm receipt (optional)
- Order marked as confirmed
- Can still refund until Tuesday 10:00 AM

**Tuesday 9:59 AM** - You request refund
- ✅ Within 24-hour window
- Receive: 0.0055 ETH (50%)

**Tuesday 10:01 AM** - Trying to refund
- ❌ Refund window expired
- Transaction reverts with `RefundPolicyExpired`

---

## 🛡️ Your Protections

### 1. **Guaranteed Refund Availability**

The contract **guarantees** you can refund within 24 hours:

**How?**
- Confirmed funds are **locked** during refund period
- Owner cannot withdraw your confirmed funds for 24 hours
- Even if you confirm, funds stay locked until refund window expires
- Owner can only do partial withdrawals of unconfirmed funds

**What This Means:**
- ✅ Your 50% refund is always available (within 24 hours)
- ✅ Owner cannot "rug pull" confirmed orders
- ✅ Contract enforces this at the code level

### 2. **No Direct Transfer Manipulation**

The contract blocks direct ETH transfers:
```solidity
receive() external payable {
    revert("Direct transfers not allowed");
}
```

**Why?**
- Prevents accounting manipulation
- All funds enter through `buy()` only
- Transparent and predictable accounting

### 3. **Accurate Accounting**

Every amount includes tax:
- Orders store full amount paid (price + tax)
- Refunds calculated on full amount
- `totalConfirmedAmount` tracks full amounts
- No hidden accounting bugs

### 4. **One Refund Per Order**

You cannot double-refund:
```solidity
if (refunds[orderId]) revert DuplicateRefundClaim();
```

This protects both you and the shop owner from accounting errors.

---

## ❓ Frequently Asked Questions

### **Q: Can I refund after confirming receipt?**
**A:** Yes! You have 24 hours from purchase, even if you confirmed.

### **Q: Why do I only get 50% back?**
**A:** This is the shop's refund policy. It balances buyer protection with seller costs. You're informed of this upfront.

### **Q: What if the shop closes while I'm waiting?**
**A:** You can still refund! Shop status doesn't affect your refund rights. Your 24-hour window is based on your purchase time.

### **Q: Can the owner steal my funds?**
**A:** No! During the 24-hour refund period:
- Confirmed funds are locked
- Owner can only withdraw partial unconfirmed amounts (once)
- Your refund is guaranteed by the smart contract

### **Q: What if I buy multiple items?**
**A:** Each purchase creates a separate order with its own:
- Order ID
- 24-hour refund window
- Confirmation status
- You can refund each order independently

### **Q: How do I calculate my refund deadline?**
**A:** Check your order's `date` field:
```solidity
(,,, uint256 purchaseTime,) = shop.orders(orderId);
uint256 deadline = purchaseTime + 24 hours;

if (block.timestamp <= deadline) {
    // You can still refund
}
```

### **Q: Can I refund if the transaction reverts?**
**A:** Check why it reverted:
- `RefundPolicyExpired`: Too late (>24 hours)
- `DuplicateRefundClaim`: Already refunded
- `InvalidRefundBenefiary`: Wrong buyer or invalid order

### **Q: What happens if I send the wrong amount?**
**A:** The transaction reverts with:
- `MissingTax`: Sent only price (forgot tax)
- `InsuffientAmount`: Sent less than price + tax
- `ExcessAmount`: Sent more than price + tax

### **Q: Is my order ID private?**
**A:** No. Order IDs are deterministic and publicly visible:
```
orderId = keccak256(abi.encode(yourAddress, nonce))
```
Anyone can calculate your order IDs if they know your address and nonce.

---

## 🔧 Technical Reference

### Contract Functions (Buyer Interface)

#### `buy()`
Places a new order.
```solidity
function buy() public payable
```
- **Requires:** `msg.value == PRICE + TAX`
- **Reverts if:** Shop closed, wrong amount
- **Emits:** `BuyOrder(orderId, amount)`

#### `confirmReceived(orderId)`
Confirms receipt of service/item.
```solidity
function confirmReceived(bytes32 orderId) external
```
- **Requires:** You are the buyer, not already confirmed
- **Reverts if:** Invalid order, already confirmed, wrong buyer
- **Emits:** `OrderConfirmed(orderId)`

#### `refund(orderId)`
Requests a refund.
```solidity
function refund(bytes32 orderId) external
```
- **Requires:** Within 24 hours, you are the buyer
- **Returns:** 50% of total paid
- **Reverts if:** Expired, already refunded, wrong buyer
- **Emits:** `RefundProcessed(orderId, amount)`

#### `getOrder(orderId)`
Views order details.
```solidity
function getOrder(bytes32 orderId) external view returns (Order memory)
```
- **Returns:** Order struct with all details

#### `nonces(address)`
Gets your current nonce.
```solidity
function nonces(address buyer) public view returns (uint256)
```
- **Returns:** Number of orders you've placed

### Order Structure
```solidity
struct Order {
    address buyer;      // Your address
    uint256 nonce;      // Order sequence number
    uint256 amount;     // Total paid (PRICE + TAX)
    uint256 date;       // Purchase timestamp
    bool confirmed;     // Whether you confirmed receipt
}
```

### Contract Variables

| Variable | Description | Type |
|----------|-------------|------|
| `PRICE` | Base price per item | `uint256` (immutable) |
| `TAX` | Tax rate (basis points) | `uint16` (immutable) |
| `TAX_BASE` | Tax denominator | `uint16` (immutable) |
| `REFUND_RATE` | Refund percentage | `uint16` (immutable) |
| `REFUND_BASE` | Refund denominator | `uint16` (immutable) |
| `REFUND_POLICY` | Refund window (seconds) | `uint256` (immutable) |
| `shopClosed` | Whether shop is closed | `bool` |
| `totalConfirmedAmount` | Sum of confirmed orders | `uint256` |

### Events

```solidity
event BuyOrder(bytes32 indexed orderId, uint256 amount);
event OrderConfirmed(bytes32 indexed orderId);
event RefundProcessed(bytes32 indexed orderId, uint256 amount);
event ShopOpen(uint256 timestamp);
event ShopClosed(uint256 timestamp);
```

### Error Codes

| Error | Meaning |
|-------|---------|
| `ShopIsClosed` | Shop is closed, cannot buy |
| `MissingTax` | Sent only PRICE without TAX |
| `InsuffientAmount` | Sent less than PRICE + TAX |
| `ExcessAmount` | Sent more than PRICE + TAX |
| `RefundPolicyExpired` | More than 24 hours since purchase |
| `DuplicateRefundClaim` | Already refunded this order |
| `InvalidRefundBenefiary` | Not the buyer or invalid order |
| `OrderAlreadyConfirmed` | Cannot confirm twice |
| `InvalidOrder` | Order doesn't exist |

---

## 🎓 Understanding the Owner's Withdrawal System

This section helps you understand **why your refunds are guaranteed**.

### How Owner Withdrawals Work

The owner **cannot** freely withdraw your funds during the 24-hour refund period.

**Rules:**
1. **During Refund Period** (within 24 hours of last purchase):
   - Owner can only withdraw 50% of **unconfirmed** amounts
   - Owner can only do this **once** per period
   - **Confirmed funds are locked** (including yours if you confirmed)

2. **After Refund Period** (24+ hours since last purchase):
   - Owner can withdraw everything
   - Shop must have no recent orders

### Why This Protects You

**Scenario 1: You confirm immediately**
```
You buy and confirm → Owner cannot touch your funds for 24 hours
Hour 23 → You change your mind and refund → ✅ Funds available
```

**Scenario 2: Active shop with many orders**
```
Monday: 10 people buy
Tuesday: 10 more people buy (lastBuy updated)
Wednesday: 10 more people buy (lastBuy updated)
...continuous orders...

→ Owner can never do full withdrawal while shop is active
→ All confirmed funds stay locked
→ Everyone can always refund within their 24-hour window
```

**Scenario 3: Shop closes for withdrawal**
```
Friday 11 PM: Last order placed
Saturday: Shop closes, no new orders
Sunday 11 PM+: 24 hours passed, owner can withdraw all

BUT: That Friday 11 PM buyer had until Saturday 11 PM to refund
→ They were protected during their window
```

### Key Insight: The "Popular Shop" Advantage

**The more popular the shop, the safer you are!**

Here's why this system is brilliant for buyers:

#### The `lastBuy` Timer Explained

Every time **anyone** buys, the contract updates:
```solidity
lastBuy = block.timestamp;  // Updated to current time
```

The owner can only do a full withdrawal when:
```solidity
if (lastBuy + REFUND_POLICY < block.timestamp) {
    // More than 24 hours since LAST purchase
    // Owner can withdraw everything
}
```

#### Scenario Analysis

**🔴 Inactive Shop (Low Protection)**
```
Monday 9 AM: You buy
Tuesday 9 AM: Refund period expires for you
Tuesday 10 AM: No new orders, owner can withdraw
```
- You had 24 hours of protection
- After your window, owner got access quickly

**🟢 Popular Active Shop (Maximum Protection)**
```
Monday 9 AM: You buy (lastBuy = Monday 9 AM)
Monday 10 AM: Someone else buys (lastBuy = Monday 10 AM)
Monday 11 AM: Another buyer (lastBuy = Monday 11 AM)
...continuous orders throughout the day...
Tuesday 9 AM: Your refund period expires
Tuesday 10 AM: More orders keep coming (lastBuy keeps updating)
Wednesday, Thursday, Friday: Continuous orders...

→ Owner can NEVER do full withdrawal while orders continue
→ All confirmed funds stay locked indefinitely
→ Every buyer always has funds available for their 24-hour window
```

#### Why This Design is Genius

**For Buyers:**
- ✅ Popular shops = stronger guarantees
- ✅ Your refund is **always** available within your 24-hour window
- ✅ Owner cannot drain funds while shop is actively selling
- ✅ The busier the shop, the safer you are

**For Owner:**
- They must choose: **Growth vs. Liquidity**

  **Option A: Keep shop open (grow the business)**
  - Continuous sales = continuous locked liquidity
  - Can only withdraw 50% of unconfirmed amounts (once per period)
  - Builds up treasury over time
  - Must be patient for big paydays

  **Option B: Close shop periodically (access funds)**
  - Close shop for a day
  - Wait 24 hours after last order
  - Withdraw everything
  - Reopen and repeat

  **Option C: Close only when truly needed**
  - Run shop for months, building huge balance
  - Close for a week when need funds
  - Withdraw accumulated amount
  - Reopen with capital

#### Real-World Example

**Busy Coffee Shop (On-Chain)**
```
Week 1: 100 orders/day, shop stays open
- Daily revenue: 1 ETH
- Week total: 7 ETH in contract
- Owner withdraws: ~3.5 ETH (50% of unconfirmed, once)
- Locked: 3.5 ETH (for refund protection)

Week 2-4: Shop stays open continuously
- More revenue accumulating
- Owner getting partial withdrawals
- Significant funds locked (this is GOOD for buyers!)

Month 2: Owner needs to buy new equipment
- Closes shop on Sunday night
- Monday: Waits 24 hours
- Tuesday: Withdraws accumulated ~20 ETH
- Wednesday: Reopens with capital to invest
```

**What this means for you as a buyer:**
- While shop is busy, your refund is **guaranteed** by game theory
- Owner has economic incentive to keep shop open (more sales)
- But keeping shop open = your funds stay protected
- Owner must plan withdrawal windows = can't impulsively drain funds

#### The "Patient Owner" Dynamic

This system naturally selects for **trustworthy, patient owners**:

**Bad Owner Behavior** (Discouraged)
```
❌ Open shop
❌ Get lots of orders
❌ Try to drain funds immediately
→ Can't! Funds locked during refund period
→ Must close shop and wait
→ Loses revenue while waiting
→ Bad business strategy
```

**Good Owner Behavior** (Encouraged)
```
✅ Open shop
✅ Build reputation
✅ Continuous sales grow balance
✅ Accept locked liquidity as cost of business
✅ Plan strategic withdrawal windows
✅ Or simply accumulate and withdraw when needed
→ Builds trust with buyers
→ Maximizes revenue
→ Everyone wins
```

#### Mathematical Guarantee

The contract enforces this at the code level:

```solidity
// During refund period
uint256 confirmedAmount = totalConfirmedAmount;  // Locked!
uint256 unconfirmedAmount = balance - confirmedAmount;
withdrawable = unconfirmedAmount * REFUND_RATE / REFUND_BASE;  // Only 50% of unconfirmed

// partialWithdrawal flag prevents repeated draining
if (partialWithdrawal) {
    revert WaitUntilRefundPeriodPassed();
}
```

**This guarantees:**
1. Confirmed funds cannot be touched during refund periods
2. Even unconfirmed funds are only 50% accessible (once)
3. Owner must wait for full withdrawal
4. Your refund is mathematically certain

---

### The Bottom Line

**"This is good in a way since it guarantees funds always available for users to be refunded and owner can be patient."**

The system creates a natural tension that **strongly favors buyer protection**:
- Active shop = locked funds = maximum safety for all buyers
- Owner wanting more liquidity = must close shop = loses revenue
- Owner's best strategy = be patient and trustworthy
- Your refund rights are enforced by economics AND code

You're not trusting the owner to "be nice" - you're protected by the **game theory** of the system itself. 🎯

---

## 📞 Support & Contract Info

### Contract Address
- **Mainnet:** [To be deployed]
- **Testnet:** [To be deployed]

### Shop Parameters
Check current parameters:
```solidity
PRICE:         shop.PRICE()
TAX:           shop.TAX()
TAX_BASE:      shop.TAX_BASE()
REFUND_RATE:   shop.REFUND_RATE()
REFUND_BASE:   shop.REFUND_BASE()
REFUND_POLICY: shop.REFUND_POLICY()
```

### Security Audits
- ✅ Comprehensive test suite (74 tests)
- ✅ Accounting vulnerabilities patched
- ✅ Refund protection implemented
- ✅ Reentrancy protection (CEI pattern)

### Source Code
- **Repository:** [GitHub link]
- **License:** MIT
- **Solidity Version:** 0.8.30

---

## ⚠️ Important Disclaimers

1. **24-Hour Deadline is Strict:** No exceptions. Plan accordingly.
2. **50% Refund is Final:** You cannot appeal for more.
3. **Blockchain Irreversibility:** Transactions cannot be reversed. Double-check before confirming.
4. **Gas Fees:** You pay gas for buy, confirm, and refund transactions.
5. **Smart Contract Risk:** While audited, use at your own risk.
6. **No Customer Service:** This is a smart contract. No human can override the rules.

---

## 🎉 Welcome to Trustless Commerce!

This shop operates entirely on-chain with transparent, verifiable rules. No human can change the terms after deployment. What you see in the code is what you get.

**Enjoy your purchase! 🛍️**

---

*Last Updated: 2025-12-20*
*Contract Version: 1.0.0*
*Documentation Version: 1.0.0*
